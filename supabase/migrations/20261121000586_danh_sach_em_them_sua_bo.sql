-- DANH SÁCH EM của lead và cơ hội: ba hàm Thêm em, Sửa em, Bỏ em (TS-02, TS-06, TS-08, TS-15; canvas 9933; R-CRM-23, R-CRM-26, R-CRM-27, R-CRM-03).
-- Trước đây chỉ có app.set_first_prospect (em đầu). Giao diện thẻ em, hộp «Thêm em» (K08c) gọi ba hàm này; cả ba trả lại DANH SÁCH EM đầy đủ (jsonb như get_lead, get_opportunity) để màn tải lại một lần.
-- Chỉ mục: không thêm. Mọi truy vấn đi qua prospect_student_opp_pos_uidx, prospect_student_lead_pos_uidx (theo hồ sơ cha, position) và khoá chính.

-- Chặn xoá của bảng prospect_student: dòng em chỉ là GHI NHẬN trong danh sách em (R-CRM-23, R-CRM-27), không phải hồ sơ nghiệp vụ; Chat duyệt «Bỏ em» (20/11/2026).
-- Giữ chặn xoá chung (app.tg_block_delete) cho mọi đường khác; chỉ app.remove_prospect_student mở cờ trong đúng giao dịch của nó. Nhật ký audit_log vẫn ghi dòng bị bỏ (trigger prospect_student_audit).
drop trigger prospect_student_no_delete on app.prospect_student;
create or replace function app.tg_prospect_student_block_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if coalesce(current_setting('hmt.prospect_remove', true), '') = 'on' then
    return old;
  end if;
  perform app.raise_error('HMT_KHONG_XOA', 'Không xoá được bản ghi. Hãy chuyển sang trạng thái Huỷ hoặc Ngừng.');
  return null;
end;
$$;
create trigger prospect_student_no_delete before delete on app.prospect_student
  for each row execute function app.tg_prospect_student_block_delete();

-- app.prospect_guard(loại, id hồ sơ cha): hàm trong, dùng chung ba hàm dưới. Khoá dòng hồ sơ cha, kiểm quyền Sửa ở cơ sở của hồ sơ, hồ sơ chưa gộp.
-- Trả {branch_id, stage_code, parent_id}. Luật: R-CRM-27 (quyền Sửa lead, cơ hội), hồ sơ đã gộp chỉ xem được.
create or replace function app.prospect_guard(p_entity text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lead app.lead;
  v_opp app.opportunity;
begin
  if p_entity = 'LEAD' then
    select * into v_lead from app.lead where id = p_id for update;
    if v_lead.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead.');
    end if;
    perform app.assert_can('LEAD', 'SUA', v_lead.branch_id);
    if v_lead.record_status = 'DA_GOP' then
      perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Lead này đã gộp vào bản khác, chỉ xem được.');
    end if;
    return jsonb_build_object('branch_id', v_lead.branch_id, 'stage_code', null, 'parent_id', null);
  elsif p_entity = 'OPPORTUNITY' then
    select * into v_opp from app.opportunity where id = p_id for update;
    if v_opp.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
    end if;
    perform app.assert_can('OPPORTUNITY', 'SUA', v_opp.branch_id);
    if v_opp.record_status = 'DA_GOP' then
      perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, chỉ xem được.');
    end if;
    return jsonb_build_object('branch_id', v_opp.branch_id, 'stage_code', v_opp.stage_code, 'parent_id', v_opp.parent_id);
  end if;
  perform app.raise_error('HMT_LOAI_SAI', 'Loại hồ sơ phải là lead hoặc cơ hội.');
  return null;
end;
$$;
revoke execute on function app.prospect_guard(text, uuid) from public, anon, authenticated;

-- app.add_prospect_student(loại, id hồ sơ cha, dữ liệu): Thêm em vào danh sách em của LEAD hoặc OPPORTUNITY.
-- Ai gọi: người có quyền Sửa lead (hoặc cơ hội) ở cơ sở của hồ sơ.
-- Dữ liệu: em mới = full_name (bắt buộc), birth_date, birth_year, school, self_rating, goal; hoặc (chỉ cơ hội) student_id = chọn con có sẵn của phụ huynh.
-- Luật R-CRM-23: tối đa prospect_max_students em (lỗi HMT_EM_TOI_DA); em mới chỉ bắt buộc họ tên (HMT_THIEU_TEN_EM); năm sinh nhập thì 4 chữ số (HMT_NAM_SINH_SAI),
--   bắt buộc từ L5 (R-CRM-03, HMT_THIEU_HOC_SINH); chọn con có sẵn chỉ ở cơ hội (HMT_EM_CHI_O_CO_HOI), con phải thuộc phụ huynh của cơ hội (HMT_EM_KHAC_PHU_HUYNH)
--   và chưa có trong danh sách (HMT_EM_TRUNG). Dòng em chỉ là ghi nhận, không tạo hồ sơ học sinh (R-CRM-27).
create or replace function app.add_prospect_student(p_entity text, p_id uuid, p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_guard jsonb := app.prospect_guard(p_entity, p_id);
  v_branch uuid := (v_guard ->> 'branch_id')::uuid;
  v_stage text := v_guard ->> 'stage_code';
  v_count integer;
  v_max integer := app.get_setting_int('prospect_max_students', (v_guard ->> 'branch_id')::uuid)::integer;
  v_pos integer;
  v_student app.student;
  v_name text := nullif(btrim(coalesce(p_data ->> 'full_name', '')), '');
  v_date date := nullif(p_data ->> 'birth_date', '')::date;
  v_year integer := coalesce(nullif(p_data ->> 'birth_year', '')::integer, extract(year from nullif(p_data ->> 'birth_date', '')::date)::integer);
begin
  -- Luật R-CRM-23: tối đa prospect_max_students em mỗi hồ sơ.
  select count(*), coalesce(max(position), 0) + 1 into v_count, v_pos
    from app.prospect_student where case when p_entity = 'LEAD' then lead_id else opportunity_id end = p_id;
  if v_count >= v_max then
    perform app.raise_error('HMT_EM_TOI_DA', format('Danh sách em đã đủ %s em, không thêm được nữa.', v_max));
  end if;

  if p_data ? 'student_id' then
    -- Luật R-CRM-23: «Chọn con có sẵn» chỉ ở cơ hội.
    if p_entity <> 'OPPORTUNITY' then
      perform app.raise_error('HMT_EM_CHI_O_CO_HOI', 'Lead chỉ thêm em mới; chọn con có sẵn chỉ ở cơ hội.');
    end if;
    select * into v_student from app.student where id = (p_data ->> 'student_id')::uuid;
    if v_student.id is null or v_student.parent_id is distinct from (v_guard ->> 'parent_id')::uuid or v_student.record_status <> 'DANG_DUNG' then
      perform app.raise_error('HMT_EM_KHAC_PHU_HUYNH', 'Chỉ chọn được con đang dùng của phụ huynh trong cơ hội này.');
    end if;
    if exists (select from app.prospect_student where opportunity_id = p_id and student_id = v_student.id) then
      perform app.raise_error('HMT_EM_TRUNG', 'Em này đã có trong danh sách em của cơ hội.');
    end if;
    -- Dòng gắn hồ sơ học sinh: không ghi chữ, đọc thẳng từ hồ sơ (Đ86).
    insert into app.prospect_student (opportunity_id, branch_id, position, student_id) values (p_id, v_branch, v_pos, v_student.id);
  else
    -- Luật R-CRM-23: em mới chỉ bắt buộc họ tên.
    if v_name is null then
      perform app.raise_error('HMT_THIEU_TEN_EM', 'Nhập họ tên của em.');
    end if;
    -- Luật R-CRM-23: năm sinh nhập thì 4 chữ số.
    if v_year is not null and (v_year < 1900 or v_year > extract(year from now())::integer) then -- allow-number: năm sinh tối thiểu như app.student
      perform app.raise_error('HMT_NAM_SINH_SAI', 'Năm sinh phải gồm 4 chữ số và không ở tương lai.');
    end if;
    -- Luật R-CRM-03: từ L5 trở lên bắt buộc năm sinh.
    if p_entity = 'OPPORTUNITY' and app.stage_is_l5_or_later(v_stage) and v_year is null then
      perform app.raise_error('HMT_THIEU_HOC_SINH', 'Từ giai đoạn L5 trở lên mỗi em bắt buộc có tên và năm sinh.');
    end if;
    insert into app.prospect_student (lead_id, opportunity_id, branch_id, position, full_name, birth_date, birth_year, school, self_rating, goal)
    values (case when p_entity = 'LEAD' then p_id end, case when p_entity = 'OPPORTUNITY' then p_id end, v_branch, v_pos,
            v_name, v_date, v_year, nullif(p_data ->> 'school', ''), nullif(p_data ->> 'self_rating', ''), nullif(p_data ->> 'goal', ''));
  end if;
  return case when p_entity = 'LEAD' then app.prospect_students_json(p_id, null) else app.prospect_students_json(null, p_id) end;
end;
$$;
revoke execute on function app.add_prospect_student(text, uuid, jsonb) from public, anon;
grant execute on function app.add_prospect_student(text, uuid, jsonb) to authenticated;

-- app.update_prospect_student(id dòng em, dữ liệu): Sửa một em (khoá nào có thì ghi đè: full_name, birth_date, birth_year, school, self_rating, goal).
-- Ai gọi: người có quyền Sửa hồ sơ cha; dòng đã gắn hồ sơ học sinh thì sửa luôn hồ sơ học sinh và cần thêm quyền Học sinh · Sửa (R-CRM-26, 27).
-- Luật: họ tên không được xoá trống (HMT_THIEU_TEN_EM); năm sinh 4 chữ số (HMT_NAM_SINH_SAI); từ L5 cơ hội bắt buộc tên và năm sinh (R-CRM-03, HMT_THIEU_HOC_SINH).
create or replace function app.update_prospect_student(p_id uuid, p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line app.prospect_student;
  v_cur app.prospect_student_v;
  v_entity text;
  v_parent uuid;
  v_guard jsonb;
  v_student app.student;
  v_name text;
  v_date date;
  v_year integer;
begin
  select * into v_line from app.prospect_student where id = p_id for update;
  if v_line.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy em trong danh sách.');
  end if;
  v_entity := case when v_line.lead_id is not null then 'LEAD' else 'OPPORTUNITY' end;
  v_parent := coalesce(v_line.lead_id, v_line.opportunity_id);
  v_guard := app.prospect_guard(v_entity, v_parent);
  select * into v_cur from app.prospect_student_v where id = p_id;

  -- Ô nào dữ liệu có thì ghi đè, không có thì giữ giá trị hiện tại.
  v_name := case when p_data ? 'full_name' then nullif(btrim(coalesce(p_data ->> 'full_name', '')), '') else v_cur.full_name end;
  v_date := case when p_data ? 'birth_date' then nullif(p_data ->> 'birth_date', '')::date else v_cur.birth_date end;
  v_year := case when p_data ? 'birth_year' then nullif(p_data ->> 'birth_year', '')::integer
                 when p_data ? 'birth_date' and v_date is not null then extract(year from v_date)::integer
                 else v_cur.birth_year end;

  -- Luật R-CRM-23: họ tên không được xoá trống khi sửa.
  if p_data ? 'full_name' and v_name is null then
    perform app.raise_error('HMT_THIEU_TEN_EM', 'Nhập họ tên của em.');
  end if;
  if v_year is not null and (v_year < 1900 or v_year > extract(year from now())::integer) then -- allow-number: năm sinh tối thiểu như app.student
    perform app.raise_error('HMT_NAM_SINH_SAI', 'Năm sinh phải gồm 4 chữ số và không ở tương lai.');
  end if;
  -- Luật R-CRM-03: từ L5 trở lên cơ hội bắt buộc tên và năm sinh của từng em.
  if v_entity = 'OPPORTUNITY' and app.stage_is_l5_or_later(v_guard ->> 'stage_code') and (v_name is null or v_year is null) then
    perform app.raise_error('HMT_THIEU_HOC_SINH', 'Từ giai đoạn L5 trở lên mỗi em bắt buộc có tên và năm sinh.');
  end if;

  if v_line.student_id is not null then
    -- Luật R-CRM-26, 27: đã có hồ sơ học sinh thì sửa luôn hồ sơ đó (cần quyền Học sinh · Sửa); hồ sơ học sinh bắt buộc tên và năm sinh.
    select * into v_student from app.student where id = v_line.student_id;
    perform app.assert_can('STUDENT', 'SUA', v_student.branch_id);
    if v_name is null or v_year is null then
      perform app.raise_error('HMT_THIEU_HOC_SINH', 'Hồ sơ học sinh bắt buộc có tên và năm sinh.');
    end if;
    update app.student set full_name = v_name, birth_date = v_date, birth_year = v_year,
           school = case when p_data ? 'school' then nullif(p_data ->> 'school', '') else v_cur.school end,
           self_rating = case when p_data ? 'self_rating' then nullif(p_data ->> 'self_rating', '') else v_cur.self_rating end,
           goal = case when p_data ? 'goal' then nullif(p_data ->> 'goal', '') else v_cur.goal end
     where id = v_line.student_id;
  else
    update app.prospect_student set full_name = v_name, birth_date = v_date, birth_year = v_year,
           school = case when p_data ? 'school' then nullif(p_data ->> 'school', '') else v_cur.school end,
           self_rating = case when p_data ? 'self_rating' then nullif(p_data ->> 'self_rating', '') else v_cur.self_rating end,
           goal = case when p_data ? 'goal' then nullif(p_data ->> 'goal', '') else v_cur.goal end
     where id = p_id;
  end if;
  return case when v_entity = 'LEAD' then app.prospect_students_json(v_parent, null) else app.prospect_students_json(null, v_parent) end;
end;
$$;
revoke execute on function app.update_prospect_student(uuid, jsonb) from public, anon;
grant execute on function app.update_prospect_student(uuid, jsonb) to authenticated;

-- app.remove_prospect_student(id dòng em): Bỏ một em khỏi danh sách em (chỉ gỡ dòng ghi nhận, không xoá hồ sơ học sinh nếu có).
-- Ai gọi: người có quyền Sửa hồ sơ cha.
-- Luật: em đã dùng ở phiếu kiểm tra, dòng báo giá hoặc dòng đơn thì không bỏ được (HMT_EM_DANG_DUNG); từ L5 cơ hội phải còn ít nhất một em (R-CRM-03, HMT_EM_CUOI).
create or replace function app.remove_prospect_student(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line app.prospect_student;
  v_entity text;
  v_parent uuid;
  v_guard jsonb;
begin
  select * into v_line from app.prospect_student where id = p_id for update;
  if v_line.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy em trong danh sách.');
  end if;
  v_entity := case when v_line.lead_id is not null then 'LEAD' else 'OPPORTUNITY' end;
  v_parent := coalesce(v_line.lead_id, v_line.opportunity_id);
  v_guard := app.prospect_guard(v_entity, v_parent);

  -- Luật: em đã có phiếu kiểm tra, dòng báo giá hoặc dòng đơn thì không bỏ.
  if exists (select from app.student_test where prospect_student_id = p_id)
     or exists (select from app.quotation_line where prospect_student_id = p_id)
     or exists (select from app.sales_order_line where prospect_student_id = p_id) then
    perform app.raise_error('HMT_EM_DANG_DUNG', 'Em này đã có phiếu kiểm tra, báo giá hoặc đơn hàng nên không bỏ được.');
  end if;
  -- Luật R-CRM-03: từ L5 trở lên cơ hội phải còn ít nhất một em.
  if v_entity = 'OPPORTUNITY' and app.stage_is_l5_or_later(v_guard ->> 'stage_code')
     and (select count(*) from app.prospect_student where opportunity_id = v_parent) <= 1 then
    perform app.raise_error('HMT_EM_CUOI', 'Từ giai đoạn L5 trở lên cơ hội phải còn ít nhất một em.');
  end if;
  -- Mở cờ cho trigger chặn xoá, chỉ trong giao dịch này; nhật ký audit_log ghi lại dòng bị bỏ.
  perform set_config('hmt.prospect_remove', 'on', true);
  delete from app.prospect_student where id = p_id;
  perform set_config('hmt.prospect_remove', 'off', true);
  return case when v_entity = 'LEAD' then app.prospect_students_json(v_parent, null) else app.prospect_students_json(null, v_parent) end;
end;
$$;
revoke execute on function app.remove_prospect_student(uuid) from public, anon;
grant execute on function app.remove_prospect_student(uuid) to authenticated;
