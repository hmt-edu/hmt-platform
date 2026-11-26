-- Migration 672 (E-26-01, anh Trường OK 26/11/2026): TẠO CƠ HỘI TRỰC TIẾP, KHÔNG QUA LEAD (phần DB).
-- Luật: R-CRM-01 (26/10, QĐ-Đ186: cơ hội còn tạo trực tiếp, không cần lead gốc, với mọi nguồn), R-CRM-23, R-CRM-27, R-CRM-28, spec 06 mục 1.1 và 1.3.
-- «Tạo trực tiếp» = app.opportunity.lead_id TRỐNG (báo cáo dùng điều kiện này; thẻ này không đổi báo cáo).
-- Chỉ mục: không thêm. Kiểm trùng đi qua lead_phone / lead_parent, parent_phone_idx, parent_phone_2_idx, opportunity_parent_idx đã có;
-- opportunity_lead_idx giữ nguyên (dòng lead_id trống không bị truy theo lead).

alter table app.opportunity alter column lead_id drop not null;
comment on column app.opportunity.lead_id is 'Lead gốc. Trống = cơ hội tạo trực tiếp, không qua lead (R-CRM-01).';

-- app.assert_new_source: nguồn của hồ sơ tạo mới. Hàm trong, chỉ hàm nghiệp vụ gọi. Lỗi HMT_THIEU_NGUON, HMT_CHIEN_DICH_SAI.
-- Luật spec 06 mục 1.1 (như app.create_lead): bắt buộc loại nguồn và nguồn; nguồn có kênh con thì bắt buộc kênh; chiến dịch phải đang dùng.
-- Kênh, nguồn có thuộc đúng cấp cha hay không do trigger opportunity_checks kiểm.
create function app.assert_new_source(p_source_type text, p_source text, p_channel text, p_campaign_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_source_type is null or p_source is null then
    perform app.raise_error('HMT_THIEU_NGUON', 'Chọn loại nguồn (Source type) và nguồn (Source).');
  end if;
  if p_channel is null and exists (
       select from app.catalog_item c join app.catalog_item s on s.id = c.parent_id
        where c.catalog_code = 'SOURCE_CHANNEL' and c.is_active and s.catalog_code = 'SOURCE' and s.code = p_source) then
    perform app.raise_error('HMT_THIEU_NGUON', 'Chọn kênh (Medium) của nguồn này.');
  end if;
  if p_campaign_id is not null and not exists (select from app.campaign where id = p_campaign_id and is_active) then
    perform app.raise_error('HMT_CHIEN_DICH_SAI', 'Chiến dịch không có hoặc đã ngừng.');
  end if;
end;
$$;
revoke execute on function app.assert_new_source(text, text, text, uuid) from public, anon, authenticated;

-- app.assert_no_phone_duplicate: số điện thoại đã có lead hoặc cơ hội ĐANG DÙNG thì chặn HMT_SDT_TRUNG, nêu mã bản cũ để mở.
-- Hàm trong. Khớp số chính và số thứ hai (R-V2-04), kể cả hồ sơ gắn với phụ huynh có số đó (phụ huynh đã gộp tính về bản giữ lại).
-- Luật E67 (như app.find_duplicate_contacts): hồ sơ ngoài phạm vi xem KHÔNG lộ mã, chỉ báo «có hồ sơ ngoài phạm vi».
create function app.assert_no_phone_duplicate(p_phones text[], p_parent_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_parents uuid[];
  v_codes text;
  v_hidden boolean;
begin
  select coalesce(array_agg(distinct coalesce(p.merged_into_id, p.id)), '{}') into v_parents
    from app.parent p where p.phone = any (p_phones) or p.phone_2 = any (p_phones) or p.id = p_parent_id;

  select string_agg(d.code, ', ' order by d.code) filter (where d.visible), coalesce(bool_or(not d.visible), false)
    into v_codes, v_hidden
    from (
      select l.code, app.can_see_branch('LEAD', 'XEM', l.branch_id) as visible
        from app.lead l
       where l.record_status = 'DANG_DUNG'
         and l.id in (select x.id from app.lead x where x.parent_phone = any (p_phones)
                      union select x.id from app.lead x where x.parent_phone_2 = any (p_phones)
                      union select x.id from app.lead x where x.parent_id = any (v_parents))
      union all
      select o.code, app.can_see_branch('OPPORTUNITY', 'XEM', o.branch_id)
        from app.opportunity o
       where o.record_status = 'DANG_DUNG' and o.parent_id = any (v_parents)
    ) d;

  if v_codes is not null or v_hidden then
    perform app.raise_error('HMT_SDT_TRUNG', format('Số điện thoại này đã có %s. Mở bản cũ, hoặc xác nhận nếu vẫn muốn tạo mới.',
      concat_ws(' và ', 'hồ sơ ' || v_codes, case when v_hidden then 'hồ sơ ngoài phạm vi của bạn' end)));
  end if;
end;
$$;
revoke execute on function app.assert_no_phone_duplicate(text[], uuid) from public, anon, authenticated;

-- app.create_opportunity_direct: tạo cơ hội không qua lead (R-CRM-01), mọi nguồn.
-- Ai gọi: người có quyền Cơ hội · Tạo ở cơ sở của cơ hội (Tuyển sinh, CSKH, Trưởng cơ sở, Admin theo ma trận quyền);
--   giao người phụ trách khác mình cần Cơ hội · Giao việc; thêm em cần Cơ hội · Sửa (qua app.add_prospect_student).
-- Vào: p_data {parent_name, parent_phone, parent_phone_2, ward_code, province_code, address, branch_id, owner_id, supporter_id, need,
--   source_type_code, source_code, channel_code, campaign_id}; p_students mảng {full_name, birth_date, birth_year, school, self_rating, goal}
--   hoặc {student_id} (con có sẵn); p_confirm_duplicate xác nhận lần hai khi trùng SĐT; p_parent_id phụ huynh có sẵn (khi đó bỏ qua tên, SĐT).
-- Ra: {id, code, parent_id, parent_code}. Giai đoạn đầu L1, không nhóm con (spec 06 mục 1.3); từ L5 phải đủ tên, năm sinh (trigger, R-CRM-03).
create function app.create_opportunity_direct(
  p_data jsonb, p_students jsonb default '[]'::jsonb, p_confirm_duplicate boolean default false, p_parent_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v app.opportunity := jsonb_populate_record(null::app.opportunity, p_data);
  v_parent app.parent;
  v_phone text := app.normalize_phone(p_data ->> 'parent_phone');
  v_phone_2 text := nullif(app.normalize_phone(p_data ->> 'parent_phone_2'), '');
  v_name text := btrim(coalesce(p_data ->> 'parent_name', ''));
  v_student jsonb;
begin
  v.branch_id := coalesce(v.branch_id, app.current_branch_id());
  if v.branch_id is null then
    perform app.raise_error('HMT_THIEU_CO_SO', 'Chọn cơ sở của cơ hội.');
  end if;
  -- Luật: quyền tạo cơ hội ở cơ sở này.
  perform app.assert_can('OPPORTUNITY', 'TAO', v.branch_id);

  -- Luật: phụ huynh có sẵn phải nhìn thấy được (hồ sơ đã gộp thì dùng bản giữ lại, R-CRM-25); mới thì bắt buộc họ tên và SĐT.
  if p_parent_id is not null then
    select r.* into v_parent from app.parent p join app.parent r on r.id = coalesce(p.merged_into_id, p.id) where p.id = p_parent_id;
    if v_parent.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh để gắn vào.');
    end if;
    perform app.assert_can('PARENT', 'XEM', v_parent.branch_id);
    v_phone := v_parent.phone;
    v_phone_2 := v_parent.phone_2;
  elsif v_name = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập họ tên phụ huynh.');
  elsif v_phone !~ '^0[0-9]{9}$' then
    perform app.raise_error('HMT_SDT_SAI', 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.');
  end if;

  -- Luật: người phụ trách mặc định là người tạo; giao cho người khác cần quyền Giao việc.
  v.owner_id := coalesce(v.owner_id, auth.uid());
  if v.owner_id <> auth.uid() then
    perform app.assert_can('OPPORTUNITY', 'GIAO_VIEC', v.branch_id);
  end if;
  perform app.assert_staff_in_branch(v.owner_id, v.branch_id);
  if v.supporter_id is not null then
    perform app.assert_staff_in_branch(v.supporter_id, v.branch_id);
  end if;
  perform app.assert_new_source(v.source_type_code, v.source_code, v.channel_code, v.campaign_id);
  if jsonb_typeof(coalesce(p_students, '[]'::jsonb)) <> 'array' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Danh sách em không đúng định dạng.');
  end if;

  -- Khoá theo số điện thoại tới hết giao dịch: hai lần bấm cùng lúc không tạo hai phụ huynh, lần sau thấy bản của lần trước.
  perform pg_advisory_xact_lock(hashtextextended('opportunity_direct:' || v_phone, 0));
  -- Luật R-CRM-01: trùng SĐT với lead hoặc cơ hội thì cảnh báo kèm mã; xác nhận lần hai mới tạo.
  if not coalesce(p_confirm_duplicate, false) then
    perform app.assert_no_phone_duplicate(array_remove(array[v_phone, v_phone_2], null), v_parent.id);
  end if;

  -- Luật R-CRM-27, 28: phụ huynh khớp theo SĐT, không thì tạo mới ở cơ sở của cơ hội; không ghi đè tên.
  if v_parent.id is null then
    v.parent_id := app.find_or_create_parent(v_phone, v_name, p_data ->> 'ward_code', p_data ->> 'province_code',
                                             p_data ->> 'address', v.branch_id, v_phone_2);
  else
    v.parent_id := v_parent.id;
  end if;

  insert into app.opportunity (
    code, lead_id, parent_id, branch_id, owner_id, supporter_id, need,
    source_type_code, source_code, channel_code, campaign_id, stage_code, substage_code)
  values (
    app.issue_crm_code('CO'), null, v.parent_id, v.branch_id, v.owner_id, v.supporter_id, v.need,
    v.source_type_code, v.source_code, v.channel_code, v.campaign_id, 'L1', null)
  returning * into v;

  -- Luật R-CRM-23: danh sách em theo đúng luật thêm em (tối đa prospect_max_students, em mới bắt buộc họ tên).
  for v_student in select value from jsonb_array_elements(coalesce(p_students, '[]'::jsonb)) loop
    perform app.add_prospect_student('OPPORTUNITY', v.id, v_student);
  end loop;

  select * into v_parent from app.parent where id = v.parent_id;
  return jsonb_build_object('id', v.id, 'code', v.code, 'parent_id', v_parent.id, 'parent_code', v_parent.code);
end;
$$;
revoke execute on function app.create_opportunity_direct(jsonb, jsonb, boolean, uuid) from public, anon;
grant execute on function app.create_opportunity_direct(jsonb, jsonb, boolean, uuid) to authenticated;

-- app.list_opportunities: chép nguyên bản 20261119000422, chỉ đổi nối lead thành left join để không mất cơ hội tạo trực tiếp.
CREATE OR REPLACE FUNCTION app.list_opportunities(p_filters jsonb DEFAULT '{}'::jsonb, p_sort text DEFAULT 'created_desc'::text, p_limit integer DEFAULT NULL::integer, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text := app.permission_scope('OPPORTUNITY', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_channel text[] := array(select jsonb_array_elements_text(p_filters -> 'channel'));
  v_campaign uuid := nullif(p_filters ->> 'campaign_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_support_mine boolean := coalesce((p_filters ->> 'supporter_mine')::boolean, false);
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_next_from timestamptz := nullif(p_filters ->> 'next_from', '')::timestamptz;
  v_next_to timestamptz := nullif(p_filters ->> 'next_to', '')::timestamptz;
  v_next_before timestamptz := nullif(p_filters ->> 'next_before', '')::timestamptz;
  v_no_appt boolean := coalesce((p_filters ->> 'no_appointment')::boolean, false);
  v_only_merged boolean := coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false) or coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_appt text[] := array(select jsonb_array_elements_text(p_filters -> 'appointment'));
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách cơ hội.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang); mặc định Postgres quét cả bảng rồi sắp xếp.
  with f as not materialized (
    select o.*
      from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and o.branch_id = v_my_branch))
       and (case when v_only_merged then o.record_status = 'DA_GOP'
             else (v_merged or o.record_status = 'DANG_DUNG'
                   or (v_q is not null and o.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or o.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or o.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or o.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or o.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or o.channel_code = any (v_channel))
       and (v_campaign is null or o.campaign_id = v_campaign)
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and o.owner_id = auth.uid())
        or ('SUPPORT' = any (v_mine_roles) and o.supporter_id = auth.uid()))
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
       and (v_next_from is null or o.next_appointment_at >= v_next_from)
       and (v_next_to is null or o.next_appointment_at < v_next_to)
       and (v_next_before is null or o.next_appointment_at < v_next_before)
       and (not v_no_appt or o.next_appointment_at is null)
       and (cardinality(v_appt) = 0
        or ('OVERDUE' = any (v_appt) and o.next_appointment_at < v_day_start)
        or ('TODAY' = any (v_appt) and o.next_appointment_at >= v_day_start and o.next_appointment_at < v_day_end)
        or ('UPCOMING' = any (v_appt) and o.next_appointment_at >= v_day_end)
        or ('NONE' = any (v_appt) and o.next_appointment_at is null))
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'next_appointment_asc' then f.next_appointment_at end asc nulls last,
              case when p_sort = 'name_asc' then (app.opp_first(f.id)).full_name end asc nulls last,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'lead_id', p.lead_id, 'lead_code', l.code,
             'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
             'student_name', (app.opp_first(p.id)).full_name, 'student_birth_year', (app.opp_first(p.id)).birth_year,
             'stage_code', p.stage_code, 'substage_code', p.substage_code,
             'source_type_code', p.source_type_code, 'source_code', p.source_code, 'channel_code', p.channel_code,
             'campaign_id', p.campaign_id, 'campaign_name', c.name,
             'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'supporter_id', p.supporter_id, 'supporter_name', app.staff_display_name(p.supporter_id),
             'branch_code', b.code, 'assigned_at', p.assigned_at,
             'next_appointment_at', p.next_appointment_at, 'created_at', p.created_at,
             'record_status', p.record_status, 'merged_into_code', m.code)
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'next_appointment_asc' then p.next_appointment_at end asc nulls last,
                      case when p_sort = 'name_asc' then (app.opp_first(p.id)).full_name end asc nulls last,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent par on par.id = p.parent_id
    left join app.lead l on l.id = p.lead_id
    left join app.opportunity m on m.id = p.merged_into_id
    left join app.campaign c on c.id = p.campaign_id;
  return v_result;
end;
$function$;

-- app.export_opportunities: chép nguyên bản 20261025000043, chỉ đổi nối lead thành left join để không mất cơ hội tạo trực tiếp.
CREATE OR REPLACE FUNCTION app.export_opportunities(p_filters jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text;
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_channel text[] := array(select jsonb_array_elements_text(p_filters -> 'channel'));
  v_campaign uuid := nullif(p_filters ->> 'campaign_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_support_mine boolean := coalesce((p_filters ->> 'supporter_mine')::boolean, false);
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_next_from timestamptz := nullif(p_filters ->> 'next_from', '')::timestamptz;
  v_next_to timestamptz := nullif(p_filters ->> 'next_to', '')::timestamptz;
  v_next_before timestamptz := nullif(p_filters ->> 'next_before', '')::timestamptz;
  v_no_appt boolean := coalesce((p_filters ->> 'no_appointment')::boolean, false);
  v_only_merged boolean := coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false) or coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_appt text[] := array(select jsonb_array_elements_text(p_filters -> 'appointment'));
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Phạm vi dòng lấy từ quyền Xuất (không phải Xem): vai trò Xem toàn hệ thống nhưng Xuất trong cơ sở chỉ xuất được cơ sở mình.
  v_scope := app.permission_scope('OPPORTUNITY', 'XUAT');
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất danh sách cơ hội.');
  end if;
  select count(*) into v_total
    from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (case when v_only_merged then o.record_status = 'DA_GOP'
             else (v_merged or o.record_status = 'DANG_DUNG'
                   or (v_q is not null and o.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or o.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or o.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or o.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or o.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or o.channel_code = any (v_channel))
       and (v_campaign is null or o.campaign_id = v_campaign)
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and o.owner_id = auth.uid())
        or ('SUPPORT' = any (v_mine_roles) and o.supporter_id = auth.uid()))
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
       and (v_next_from is null or o.next_appointment_at >= v_next_from)
       and (v_next_to is null or o.next_appointment_at < v_next_to)
       and (v_next_before is null or o.next_appointment_at < v_next_before)
       and (not v_no_appt or o.next_appointment_at is null)
       and (cardinality(v_appt) = 0
        or ('OVERDUE' = any (v_appt) and o.next_appointment_at < v_day_start)
        or ('TODAY' = any (v_appt) and o.next_appointment_at >= v_day_start and o.next_appointment_at < v_day_end)
        or ('UPCOMING' = any (v_appt) and o.next_appointment_at >= v_day_end)
        or ('NONE' = any (v_appt) and o.next_appointment_at is null));
  with f as (
    select o.*
      from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (case when v_only_merged then o.record_status = 'DA_GOP'
             else (v_merged or o.record_status = 'DANG_DUNG'
                   or (v_q is not null and o.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or o.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or o.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or o.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or o.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or o.channel_code = any (v_channel))
       and (v_campaign is null or o.campaign_id = v_campaign)
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and o.owner_id = auth.uid())
        or ('SUPPORT' = any (v_mine_roles) and o.supporter_id = auth.uid()))
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
       and (v_next_from is null or o.next_appointment_at >= v_next_from)
       and (v_next_to is null or o.next_appointment_at < v_next_to)
       and (v_next_before is null or o.next_appointment_at < v_next_before)
       and (not v_no_appt or o.next_appointment_at is null)
       and (cardinality(v_appt) = 0
        or ('OVERDUE' = any (v_appt) and o.next_appointment_at < v_day_start)
        or ('TODAY' = any (v_appt) and o.next_appointment_at >= v_day_start and o.next_appointment_at < v_day_end)
        or ('UPCOMING' = any (v_appt) and o.next_appointment_at >= v_day_end)
        or ('NONE' = any (v_appt) and o.next_appointment_at is null))
     order by o.created_at desc, o.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', f.code, 'lead', l.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
           'student_name', (app.opp_first(f.id)).full_name, 'student_birth_year', (app.opp_first(f.id)).birth_year, 'school', (app.opp_first(f.id)).school, 'need', f.need,
           'source_type', st.name, 'source', so.name, 'channel', ch.name, 'campaign', ca.name,
           'stage', sg.name, 'substage', ss.name,
           'owner', app.staff_display_name(f.owner_id), 'supporter', app.staff_display_name(f.supporter_id),
           'branch', b.code, 'next_appointment_at', f.next_appointment_at, 'created_at', f.created_at,
           'record_status', f.record_status) order by f.created_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id
    join app.parent par on par.id = f.parent_id
    left join app.lead l on l.id = f.lead_id
    left join app.catalog_item st on st.catalog_code = 'SOURCE_TYPE' and st.code = f.source_type_code
    left join app.catalog_item so on so.catalog_code = 'SOURCE' and so.code = f.source_code
    left join app.catalog_item ch on ch.catalog_code = 'SOURCE_CHANNEL' and ch.code = f.channel_code
    left join app.campaign ca on ca.id = f.campaign_id
    left join app.catalog_item sg on sg.catalog_code = 'OPP_STAGE' and sg.code = f.stage_code
    left join app.catalog_item ss on ss.catalog_code = 'OPP_SUBSTAGE' and ss.code = f.substage_code;
  -- Ghi nhật ký xuất TRƯỚC khi trả dữ liệu (cùng giao dịch): lỗi ở đây thì không có file.
  perform app.log_export('OPPORTUNITY', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$function$;

-- app.add_lead_students_to_opportunity: chép nguyên bản 20261121000595, chỉ đổi thêm chặn cơ hội không có lead gốc.
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
  -- Luật: cơ hội tạo trực tiếp không có lead gốc để chép em.
  if v_lead_id is null then
    perform app.raise_error('HMT_CO_HOI_KHONG_CO_LEAD', 'Cơ hội này không có lead gốc, hãy thêm em trực tiếp.');
  end if;
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
