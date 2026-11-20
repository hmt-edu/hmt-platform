-- TS-06 Tạo cơ hội từ lead: CHỌN EM đưa sang cơ hội, và «Thêm em vào cơ hội cũ» (canvas 9933: TS06_*; R-CRM-23, R-CRM-01).
-- Trước đây app.create_opportunity chỉ chép EM ĐẦU của lead («chọn nhiều em từ lead làm ở DB-2»). Nay:
--  * create_opportunity thêm tham số p_student_ids (id các dòng em của LEAD cần chép): null = chép tất cả em (mặc định chọn hết), mảng rỗng = 0 em (R-CRM-23 «được chọn 0 em»).
--  * em trùng họ tên + năm sinh (hoặc cùng hồ sơ học sinh) chỉ chép MỘT dòng (TS06_them_em «em trùng họ tên và năm sinh gộp một dòng»).
--  * app.add_lead_students_to_opportunity: chép em của lead vào MỘT cơ hội đang có của chính lead đó, bỏ em đã có, vượt tối đa thì chặn (TS06_vuot).
-- Chỉ mục: không thêm; truy vấn đi qua prospect_student_lead_pos_uidx và prospect_student_opp_pos_uidx (theo hồ sơ cha, position).

-- app.prospect_copy_lines(lead, cơ hội, danh sách id | null): hàm trong, chép dòng em của lead sang cơ hội. Trả số dòng đã chép.
-- Luật R-CRM-23: tối đa prospect_max_students em mỗi cơ hội (HMT_EM_TOI_DA); em không thuộc lead là lỗi (HMT_EM_KHONG_THUOC_LEAD);
--   em trùng (cùng hồ sơ học sinh, hoặc cùng họ tên chuẩn hoá + năm sinh) với em đã có trong cơ hội hoặc đã chép trước đó thì bỏ qua.
create or replace function app.prospect_copy_lines(p_lead_id uuid, p_opportunity_id uuid, p_ids uuid[])
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line record;
  v_branch uuid;
  v_max integer;
  v_pos integer;
  v_count integer;
  v_copied integer := 0;
  v_key text;
begin
  select branch_id into v_branch from app.opportunity where id = p_opportunity_id;
  v_max := app.get_setting_int('prospect_max_students', v_branch)::integer;
  -- Luật: mọi id chọn phải là dòng em của lead này.
  if p_ids is not null and (select count(*) from app.prospect_student where lead_id = p_lead_id and id = any (p_ids))
                           <> (select count(distinct x) from unnest(p_ids) x) then
    perform app.raise_error('HMT_EM_KHONG_THUOC_LEAD', 'Có em được chọn không thuộc lead này.');
  end if;
  select coalesce(max(position), 0), count(*) into v_pos, v_count from app.prospect_student where opportunity_id = p_opportunity_id;
  for v_line in
    select ps.*, v.full_name as shown_name, v.birth_year as shown_year
      from app.prospect_student ps
      join app.prospect_student_v v on v.id = ps.id
     where ps.lead_id = p_lead_id and (p_ids is null or ps.id = any (p_ids))
     order by ps.position
  loop
    v_key := coalesce('S:' || v_line.student_id::text,
                      'N:' || app.normalize_person_name(coalesce(v_line.shown_name, '')) || '|' || coalesce(v_line.shown_year::text, ''));
    -- Luật: bỏ em trùng (đã có trong cơ hội, hoặc vừa chép).
    if exists (
      select from app.prospect_student_v o
       where o.opportunity_id = p_opportunity_id
         and coalesce('S:' || o.student_id::text, 'N:' || app.normalize_person_name(coalesce(o.full_name, '')) || '|' || coalesce(o.birth_year::text, '')) = v_key
    ) then
      continue;
    end if;
    -- Luật R-CRM-23: không vượt số em tối đa.
    if v_count >= v_max then
      perform app.raise_error('HMT_EM_TOI_DA', format('Danh sách em của cơ hội đã đủ %s em, không thêm được nữa.', v_max));
    end if;
    v_pos := v_pos + 1;
    v_count := v_count + 1;
    v_copied := v_copied + 1;
    insert into app.prospect_student (opportunity_id, branch_id, position, student_id, full_name, birth_date, birth_year, school, self_rating, goal)
    values (p_opportunity_id, v_branch, v_pos, v_line.student_id, v_line.full_name, v_line.birth_date, v_line.birth_year,
            v_line.school, v_line.self_rating, v_line.goal);
  end loop;
  return v_copied;
end;
$$;
revoke execute on function app.prospect_copy_lines(uuid, uuid, uuid[]) from public, anon, authenticated;

-- app.create_opportunity: thêm p_student_ids (xem đầu file). Các luật khác giữ nguyên như bản trước (migration 48): quyền Tạo cơ hội và Xem lead,
-- lead phải ở C4C hoặc C4D, R-CRM-01 (lead đã có cơ hội thì cảnh báo, xác nhận lần hai), R-CRM-27/28 (phụ huynh theo SĐT), R-CRM-09 (lead về C4D).
-- Bỏ bản ba tham số để không mơ hồ khi gọi.
drop function app.create_opportunity(uuid, jsonb, boolean);
create or replace function app.create_opportunity(p_lead_id uuid, p_data jsonb default '{}'::jsonb, p_confirm_existing boolean default false, p_student_ids uuid[] default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lead app.lead;
  v app.opportunity;
  v_existing text;
  v_parent_id uuid;
  v_parent_code text;
  v_owner uuid;
  v_id uuid;
  v_code text;
  v_overrides jsonb;
begin
  select * into v_lead from app.lead where id = p_lead_id;
  if v_lead.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead.');
  end if;
  -- Luật: quyền tạo cơ hội và xem lead ở cơ sở của lead.
  perform app.assert_can('OPPORTUNITY', 'TAO', v_lead.branch_id);
  perform app.assert_can('LEAD', 'XEM', v_lead.branch_id);
  if v_lead.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Lead này đã gộp vào bản khác, không tạo cơ hội được.');
  end if;
  -- Luật (26/10): lead chỉ tạo được cơ hội khi ở C4C; lead đã ở C4D vẫn tạo thêm được theo R-CRM-01.
  if v_lead.substage_code is null or v_lead.substage_code not in ('C4C', 'C4D') then
    perform app.raise_error('HMT_LEAD_CHUA_DU_DIEU_KIEN',
      'Lead cần ở nhóm con C4C "Đủ điều kiện tạo cơ hội" mới tạo được cơ hội. Đổi giai đoạn của lead trước.');
  end if;

  -- Luật R-CRM-01: lead đã có cơ hội đang dùng thì cảnh báo kèm mã cũ; xác nhận lần hai mới tạo thêm.
  select string_agg(code, ', ' order by created_at) into v_existing
    from app.opportunity where lead_id = p_lead_id and record_status = 'DANG_DUNG';
  if v_existing is not null and not coalesce(p_confirm_existing, false) then
    perform app.raise_error('HMT_LEAD_DA_CO_CO_HOI',
      format('Lead này đã có cơ hội %s. Xác nhận nếu vẫn muốn tạo thêm.', v_existing));
  end if;

  v := jsonb_populate_record(null::app.opportunity, p_data);

  -- Luật: người phụ trách mặc định là người phụ trách lead; giao cho người khác cần quyền Giao việc.
  v_owner := coalesce(v.owner_id, v_lead.owner_id);
  if v_owner <> v_lead.owner_id and v_owner <> auth.uid() then
    perform app.assert_can('OPPORTUNITY', 'GIAO_VIEC', v_lead.branch_id);
  end if;
  perform app.assert_staff_in_branch(v_owner, v_lead.branch_id);
  if coalesce(v.supporter_id, v_lead.supporter_id) is not null then
    perform app.assert_staff_in_branch(coalesce(v.supporter_id, v_lead.supporter_id), v_lead.branch_id);
  end if;

  -- Luật R-CRM-27, 28: phụ huynh có sẵn (lead đã gắn) hoặc khớp theo SĐT; không thì tạo mới. Không ghi đè tên.
  v_parent_id := coalesce(v_lead.parent_id,
    app.find_or_create_parent(v_lead.parent_phone, v_lead.parent_name, v_lead.ward_code, v_lead.province_code,
                              v_lead.address, v_lead.branch_id));
  select code into v_parent_code from app.parent where id = v_parent_id;

  v_code := app.issue_crm_code('CO');
  insert into app.opportunity (
    code, lead_id, parent_id, branch_id, owner_id, supporter_id, need,
    source_type_code, source_code, channel_code, campaign_id, stage_code, substage_code)
  values (
    v_code, p_lead_id, v_parent_id, v_lead.branch_id, v_owner, coalesce(v.supporter_id, v_lead.supporter_id),
    case when p_data ? 'need' then v.need else v_lead.need end,
    v_lead.source_type_code, v_lead.source_code, v_lead.channel_code, v_lead.campaign_id, 'L1', null)
  returning id into v_id;

  -- Luật R-CRM-23 (danh sách em): chép các em được chọn của lead (null = tất cả, mảng rỗng = 0 em); em trùng chỉ chép một dòng.
  perform app.prospect_copy_lines(p_lead_id, v_id, p_student_ids);
  -- Ô học sinh nào p_data có thì ghi đè em đầu (giữ hành vi cũ của các màn gọi kiểu cũ); có ngày sinh mà không có năm sinh thì lấy năm của ngày sinh.
  v_overrides := coalesce((select jsonb_object_agg(k, p_data -> k)
                             from unnest(array['student_name', 'student_birth_date', 'student_birth_year', 'school', 'self_rating', 'goal']) k
                            where p_data ? k), '{}'::jsonb);
  if v_overrides <> '{}'::jsonb then
    perform app.set_first_prospect('OPPORTUNITY', v_id, v_overrides, true);
  end if;

  -- Luật R-CRM-09: lead tự về C4D "Tạo cơ hội thành công" và nhận phụ huynh.
  update app.lead set stage_code = 'C4', substage_code = 'C4D', parent_id = v_parent_id where id = p_lead_id;

  return jsonb_build_object('id', v_id, 'code', v_code, 'parent_id', v_parent_id, 'parent_code', v_parent_code);
end;
$$;
revoke execute on function app.create_opportunity(uuid, jsonb, boolean, uuid[]) from public, anon;
grant execute on function app.create_opportunity(uuid, jsonb, boolean, uuid[]) to authenticated;

-- app.add_lead_students_to_opportunity(cơ hội, danh sách id em của lead | null): «Thêm em vào cơ hội cũ» (TS-06).
-- Ai gọi: người có quyền Sửa cơ hội và Xem lead ở cơ sở của cơ hội. Chỉ cơ hội còn dùng, chưa gộp, và chỉ em của CHÍNH lead đã sinh cơ hội đó.
-- Kết quả: danh sách em đầy đủ của cơ hội (như app.prospect_students_json). Luật: em trùng bỏ qua; vượt prospect_max_students thì chặn cả thao tác (HMT_EM_TOI_DA);
--   từ L5 mỗi em chép sang phải có tên và năm sinh (R-CRM-03, HMT_THIEU_HOC_SINH): em thiếu năm sinh không chép được vào cơ hội ở L5 trở lên.
create or replace function app.add_lead_students_to_opportunity(p_opportunity_id uuid, p_student_ids uuid[] default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_guard jsonb := app.prospect_guard('OPPORTUNITY', p_opportunity_id);
  v_lead_id uuid;
begin
  select lead_id into v_lead_id from app.opportunity where id = p_opportunity_id;
  perform app.assert_can('LEAD', 'XEM', (v_guard ->> 'branch_id')::uuid);
  perform app.prospect_copy_lines(v_lead_id, p_opportunity_id, p_student_ids);
  -- Luật R-CRM-03: từ L5 mỗi em phải có tên và năm sinh, kể cả em vừa chép.
  if app.stage_is_l5_or_later(v_guard ->> 'stage_code')
     and exists (select from app.prospect_student_v v where v.opportunity_id = p_opportunity_id
                  and (coalesce(btrim(v.full_name), '') = '' or v.birth_year is null)) then
    perform app.raise_error('HMT_THIEU_HOC_SINH', 'Từ giai đoạn L5 trở lên mỗi em bắt buộc có tên và năm sinh.');
  end if;
  return app.prospect_students_json(null, p_opportunity_id);
end;
$$;
revoke execute on function app.add_lead_students_to_opportunity(uuid, uuid[]) from public, anon;
grant execute on function app.add_lead_students_to_opportunity(uuid, uuid[]) to authenticated;
