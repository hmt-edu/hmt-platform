-- Lịch hẹn bổ sung (anh duyệt 24/10; QĐ-Đ6, Đ33 đến Đ36): dữ liệu cho bốn nút còn lại của màn Lịch hẹn (TS-11).
--   1. app.export_appointments: Xuất danh sách lịch hẹn (phạm vi theo quyền Xuất; ghi nhật ký xuất như các màn khác).
--   2. app.appointment_group_counts: đếm cho Group By một đến hai cấp (Đ35: trạng thái, loại hoạt động, người phụ trách, cơ sở,
--      loại hồ sơ gắn).
--   3. app.assign_appointments: giao người phụ trách cho nhiều lịch hẹn (Đ33, Đ36). Hàm riêng, không mở rộng app.assign_owner,
--      vì assign_owner trả một số nguyên còn lô lịch hẹn cần trả kết quả từng nhóm bị bỏ.
--   4. app.list_appointments (thay thân): thêm bộ lọc `kind` (loại hồ sơ gắn) để mở một nhóm Group By.
--   5. app.reschedule_appointment (thay thân): Đ37, lịch nhắc tự sinh của phiếu không đổi người phụ trách bằng tay.
-- Lịch "Theo người" (Đ34) không cần hàm mới: dòng lịch hẹn đã có người phụ trách.
-- Chỉ mục: không thêm. Mọi bộ lọc dùng cột đã có chỉ mục (appointment_branch_time_idx, appointment_owner_idx,
-- appointment_status_time_idx, appointment_lead_idx, appointment_opportunity_idx, appointment_student_test_idx); các trường nhóm
-- (hoạt động, loại hồ sơ) chỉ nhóm trên tập đã lọc theo cơ sở và thời gian nên không cần chỉ mục riêng (EXPLAIN trong mô tả PR).

create or replace function app.list_appointments(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'time_asc',
  p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('APPOINTMENT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_activity text[] := array(select jsonb_array_elements_text(p_filters -> 'activity'));
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_test uuid := nullif(p_filters ->> 'student_test_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_kind text[] := array(select jsonb_array_elements_text(p_filters -> 'kind'));
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lịch hẹn.');
  end if;
  with f as not materialized (
    select a.*
      from app.appointment a
     where (v_scope = 'TOAN_HE_THONG' or a.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or a.status = any (v_status))
       and (cardinality(v_activity) = 0 or a.activity_code = any (v_activity))
       and (v_from is null or a.scheduled_at >= v_from)
       and (v_to is null or a.scheduled_at < v_to)
       and (not v_mine or a.owner_id = auth.uid())
       and (v_lead is null or a.lead_id = v_lead)
       and (v_opp is null or a.opportunity_id = v_opp)
       and (v_test is null or a.student_test_id = v_test)
       and (v_branch is null or a.branch_id = v_branch)
       and (v_owner is null or a.owner_id = v_owner)
       -- Loại hồ sơ gắn (Đ35, dùng khi mở một nhóm của Group By): LEAD, OPPORTUNITY hoặc STUDENT_TEST.
       and (cardinality(v_kind) = 0
            or (case when a.lead_id is not null then 'LEAD' when a.opportunity_id is not null then 'OPPORTUNITY'
                     else 'STUDENT_TEST' end) = any (v_kind))
       -- Tìm theo tên, SĐT, mã của hồ sơ gắn (lead hoặc cơ hội): dò hồ sơ bằng chỉ mục trigram trước, rồi nối về lịch hẹn.
       and (v_q is null
            or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
            or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%'))
  ),
  page as (
    select * from f
     order by case when p_sort = 'time_desc' then f.scheduled_at end desc,
              f.scheduled_at asc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'activity_code', p.activity_code, 'scheduled_at', p.scheduled_at, 'title', p.title,
             'status', p.status, 'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'lead_id', p.lead_id, 'lead_code', l.code,
             'lead_label', l.parent_name || coalesce(' · ' || nullif(l.student_name, ''), ''),
             'opportunity_id', p.opportunity_id, 'opportunity_code', o.code,
             'student_test_id', p.student_test_id, 'student_test_code', t.code, 'is_auto_reminder', p.is_auto_reminder,
             'record_code', coalesce(l.code, o.code, t.code),
             'record_label', coalesce(l.parent_name || coalesce(' · ' || nullif(l.student_name, ''), ''),
                                      po.full_name || coalesce(' · ' || nullif(o.student_name, ''), ''),
                                      ts.full_name || ' · Phiếu kiểm tra'),
             'cancel_reason_code', p.cancel_reason_code, 'branch_code', b.code)
             order by case when p_sort = 'time_desc' then p.scheduled_at end desc, p.scheduled_at asc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    left join app.lead l on l.id = p.lead_id
    left join app.opportunity o on o.id = p.opportunity_id
    left join app.parent po on po.id = o.parent_id
    left join app.student_test t on t.id = p.student_test_id
    left join app.student ts on ts.id = t.student_id;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Nhãn của một nhóm (Group By lịch hẹn). Hàm nội bộ.
-- Trường: status, activity, owner, branch, kind. Khoá trống là "Chưa có".
-- ---------------------------------------------------------------------------
create or replace function app.appointment_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'status' then case p_key when 'CHUA_LAM' then 'Chưa làm' when 'HOAN_THANH' then 'Hoàn thành'
                                           when 'HUY' then 'Huỷ' else p_key end
    when p_field = 'activity' then coalesce((select name from app.catalog_item where catalog_code = 'ACTIVITY_TYPE' and code = p_key), p_key)
    when p_field = 'owner' then coalesce(app.staff_display_name(p_key::uuid), p_key)
    when p_field = 'branch' then coalesce((select code || ' ' || name from app.branch where id = p_key::uuid), p_key)
    when p_field = 'kind' then case p_key when 'LEAD' then 'Lead' when 'OPPORTUNITY' then 'Cơ hội'
                                          when 'STUDENT_TEST' then 'Phiếu kiểm tra' else p_key end
    else p_key end;
$$;

-- ---------------------------------------------------------------------------
-- Đếm nhóm cho Group By của màn Lịch hẹn (Đ35).
-- Ai gọi: người có quyền Lịch hẹn · Xem (phạm vi như danh sách).
-- Đầu vào: p_filters (cùng bộ lọc như list_appointments, kể cả `kind`), p_fields (một hoặc hai trường khác nhau trong: status,
--   activity, owner, branch, kind).
-- Kết quả: {total, groups: [{k1, l1, k2, l2, count}]}; k là khoá, l là nhãn tiếng Việt.
-- Luật: Group By tối đa hai cấp, hai cấp khác nhau (K1_nhom); trường lạ bị chặn bằng HMT_NHOM_SAI.
-- ---------------------------------------------------------------------------
create or replace function app.appointment_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('APPOINTMENT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_activity text[] := array(select jsonb_array_elements_text(p_filters -> 'activity'));
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_test uuid := nullif(p_filters ->> 'student_test_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_kind text[] := array(select jsonb_array_elements_text(p_filters -> 'kind'));
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  -- Luật: quyền xem lịch hẹn.
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lịch hẹn.');
  end if;
  -- Luật Đ35: chỉ nhóm theo các trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status', 'activity', 'owner', 'branch', 'kind'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (trạng thái, loại hoạt động, người phụ trách, cơ sở, loại hồ sơ).');
  end if;
  with f as not materialized (
    select a.*
      from app.appointment a
     where (v_scope = 'TOAN_HE_THONG' or a.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or a.status = any (v_status))
       and (cardinality(v_activity) = 0 or a.activity_code = any (v_activity))
       and (v_from is null or a.scheduled_at >= v_from)
       and (v_to is null or a.scheduled_at < v_to)
       and (not v_mine or a.owner_id = auth.uid())
       and (v_lead is null or a.lead_id = v_lead)
       and (v_opp is null or a.opportunity_id = v_opp)
       and (v_test is null or a.student_test_id = v_test)
       and (v_branch is null or a.branch_id = v_branch)
       and (v_owner is null or a.owner_id = v_owner)
       and (cardinality(v_kind) = 0
            or (case when a.lead_id is not null then 'LEAD' when a.opportunity_id is not null then 'OPPORTUNITY'
                     else 'STUDENT_TEST' end) = any (v_kind))
       and (v_q is null
            or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
            or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%'))
  ),
  keyed as (
    select case v_f1 when 'status' then f.status when 'activity' then f.activity_code when 'owner' then f.owner_id::text
                     when 'branch' then f.branch_id::text
                     when 'kind' then case when f.lead_id is not null then 'LEAD' when f.opportunity_id is not null then 'OPPORTUNITY'
                                           else 'STUDENT_TEST' end end as k1,
           case v_f2 when 'status' then f.status when 'activity' then f.activity_code when 'owner' then f.owner_id::text
                     when 'branch' then f.branch_id::text
                     when 'kind' then case when f.lead_id is not null then 'LEAD' when f.opportunity_id is not null then 'OPPORTUNITY'
                                           else 'STUDENT_TEST' end end as k2
      from f
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.appointment_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.appointment_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Xuất danh sách lịch hẹn (màn Lịch hẹn, nút Xuất).
-- Ai gọi: người có quyền Lịch hẹn · Xuất (Trưởng cơ sở trong cơ sở mình, Admin mọi cơ sở). Phạm vi dòng lấy từ quyền Xuất.
-- Đầu vào: p_filters (cùng bộ lọc như list_appointments).
-- Kết quả: {total, exported, truncated, rows}; rows có tên danh mục (không phải mã) cho người đọc file; tối đa export_max_rows
--   dòng (giờ hẹn mới nhất trước), quá thì truncated = true.
-- Luật: quyền Xuất; nhật ký xuất (app.log_export: ai xuất, module, bộ lọc, số dòng) ghi trong cùng giao dịch.
-- ---------------------------------------------------------------------------
create or replace function app.export_appointments(p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('APPOINTMENT', 'XUAT');
  v_my_branch uuid := app.current_branch_id();
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_activity text[] := array(select jsonb_array_elements_text(p_filters -> 'activity'));
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_test uuid := nullif(p_filters ->> 'student_test_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_kind text[] := array(select jsonb_array_elements_text(p_filters -> 'kind'));
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Luật: quyền Xuất (phạm vi dòng lấy từ quyền Xuất, không phải Xem).
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất danh sách lịch hẹn.');
  end if;
  select count(*) into v_total
    from app.appointment a
   where (v_scope = 'TOAN_HE_THONG' or a.branch_id = v_my_branch)
     and (cardinality(v_status) = 0 or a.status = any (v_status))
     and (cardinality(v_activity) = 0 or a.activity_code = any (v_activity))
     and (v_from is null or a.scheduled_at >= v_from)
     and (v_to is null or a.scheduled_at < v_to)
     and (not v_mine or a.owner_id = auth.uid())
     and (v_lead is null or a.lead_id = v_lead)
     and (v_opp is null or a.opportunity_id = v_opp)
     and (v_test is null or a.student_test_id = v_test)
     and (v_branch is null or a.branch_id = v_branch)
     and (v_owner is null or a.owner_id = v_owner)
     and (cardinality(v_kind) = 0
          or (case when a.lead_id is not null then 'LEAD' when a.opportunity_id is not null then 'OPPORTUNITY'
                   else 'STUDENT_TEST' end) = any (v_kind))
     and (v_q is null
          or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
          or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%'));
  with f as (
    select a.*
      from app.appointment a
     where (v_scope = 'TOAN_HE_THONG' or a.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or a.status = any (v_status))
       and (cardinality(v_activity) = 0 or a.activity_code = any (v_activity))
       and (v_from is null or a.scheduled_at >= v_from)
       and (v_to is null or a.scheduled_at < v_to)
       and (not v_mine or a.owner_id = auth.uid())
       and (v_lead is null or a.lead_id = v_lead)
       and (v_opp is null or a.opportunity_id = v_opp)
       and (v_test is null or a.student_test_id = v_test)
       and (v_branch is null or a.branch_id = v_branch)
       and (v_owner is null or a.owner_id = v_owner)
       and (cardinality(v_kind) = 0
            or (case when a.lead_id is not null then 'LEAD' when a.opportunity_id is not null then 'OPPORTUNITY'
                     else 'STUDENT_TEST' end) = any (v_kind))
       and (v_q is null
            or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
            or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%'))
     order by a.scheduled_at desc, a.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'kind', case when f.lead_id is not null then 'Lead' when f.opportunity_id is not null then 'Cơ hội' else 'Phiếu kiểm tra' end,
           'record_code', coalesce(l.code, o.code, t.code),
           'record_label', coalesce(l.parent_name || coalesce(' · ' || nullif(l.student_name, ''), ''),
                                    po.full_name || coalesce(' · ' || nullif(o.student_name, ''), ''),
                                    ts.full_name || ' · Phiếu kiểm tra'),
           'activity', ac.name, 'title', f.title, 'scheduled_at', f.scheduled_at,
           'status', app.appointment_group_label('status', f.status),
           'owner', app.staff_display_name(f.owner_id), 'branch', b.code,
           'auto_reminder', f.is_auto_reminder,
           'cancel_reason', cr.name, 'cancel_note', f.cancel_note, 'created_at', f.created_at)
           order by f.scheduled_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id
    left join app.catalog_item ac on ac.catalog_code = 'ACTIVITY_TYPE' and ac.code = f.activity_code
    left join app.catalog_item cr on cr.catalog_code = 'APPOINTMENT_CANCEL_REASON' and cr.code = f.cancel_reason_code
    left join app.lead l on l.id = f.lead_id
    left join app.opportunity o on o.id = f.opportunity_id
    left join app.parent po on po.id = o.parent_id
    left join app.student_test t on t.id = f.student_test_id
    left join app.student ts on ts.id = t.student_id;
  -- Luật: ghi nhật ký xuất (ai, module, bộ lọc, số dòng).
  perform app.log_export('APPOINTMENT', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$$;

-- ---------------------------------------------------------------------------
-- Giao người phụ trách cho nhiều lịch hẹn (màn Lịch hẹn, chọn hàng loạt; QĐ-Đ33, Đ36).
-- Ai gọi: người có quyền Lịch hẹn · Giao việc (Trưởng cơ sở trong cơ sở mình, Admin mọi cơ sở).
-- Đầu vào: p_ids (tối đa list_page_size_max lịch hẹn), p_owner_id (người phụ trách mới).
-- Kết quả: {requested, assigned, skipped, reasons: [{code, message, count, ids}]}: giao phần hợp lệ, KHÔNG im lặng bỏ dòng:
--   mỗi nhóm bị bỏ có mã, câu tiếng Việt, số lượng và danh sách id.
-- Luật:
--   - Đ33, R-CRM-38: chỉ giao được lịch hẹn Chưa làm (Hoàn thành, Huỷ là lịch sử): HMT_LICH_HEN_TRANG_THAI_SAI.
--   - Đ36: lịch nhắc tự sinh của phiếu kiểm tra đi theo người phụ trách phiếu, không giao tay hàng loạt: HMT_LICH_NHAC_THEO_PHIEU.
--   - Người nhận phải là nhân sự đang hoạt động của đúng cơ sở của lịch hẹn (như R-CRM-38 b): HMT_NGUOI_PHU_TRACH_SAI.
--   - Lịch hẹn ngoài cơ sở của người gọi (khi không có phạm vi toàn hệ thống) coi như không thấy: HMT_KHONG_TIM_THAY.
--   - Lịch đã do người này phụ trách: bỏ, không tính là giao: HMT_GIAO_CUNG_NGUOI.
-- Chỉ đổi người phụ trách CỦA LỊCH HẸN: KHÔNG đổi người phụ trách của lead, cơ hội, phiếu mà lịch gắn vào. Mỗi lịch đã giao ghi một
-- dòng ghi chú hệ thống trên hồ sơ gắn (như Dời lịch); nhật ký thao tác của lịch hẹn tự ghi người phụ trách cũ và mới.
-- ---------------------------------------------------------------------------
create or replace function app.assign_appointments(p_ids uuid[], p_owner_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('APPOINTMENT', 'GIAO_VIEC');
  v_my_branch uuid := app.current_branch_id();
  v_max integer := app.get_setting_int('list_page_size_max');
  v_id uuid;
  v_appt app.appointment;
  v_code text;
  v_skipped jsonb := '{}'::jsonb;
  v_reasons jsonb := '[]'::jsonb;
  v_requested integer := 0;
  v_assigned integer := 0;
  v_entity_type text;
  v_entity_id uuid;
  v_old_name text;
  v_new_name text := app.staff_display_name(p_owner_id);
  k text;
begin
  -- Luật: quyền Giao việc trên lịch hẹn.
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền giao việc cho lịch hẹn.');
  end if;
  if coalesce(cardinality(p_ids), 0) = 0 or p_owner_id is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ít nhất một lịch hẹn và người phụ trách mới.');
  end if;
  if cardinality(p_ids) > v_max then
    perform app.raise_error('HMT_QUA_NHIEU_BAN_GHI', 'Giao quá nhiều lịch hẹn một lần, hãy chia nhỏ.');
  end if;

  -- Từng lịch hẹn (khoá theo thứ tự id): xác định lý do bỏ (nếu có) theo thứ tự luật, không có lý do thì giao.
  for v_id in select distinct x from unnest(p_ids) x order by x loop
    v_requested := v_requested + 1;
    select * into v_appt from app.appointment where id = v_id for update;
    v_code := case
      -- Không có, hoặc ngoài cơ sở của người gọi: không lộ sự tồn tại.
      when v_appt.id is null or (v_scope <> 'TOAN_HE_THONG' and v_appt.branch_id is distinct from v_my_branch)
        then 'HMT_KHONG_TIM_THAY'
      -- Luật Đ33, R-CRM-38: chỉ lịch hẹn Chưa làm.
      when v_appt.status <> 'CHUA_LAM' then 'HMT_LICH_HEN_TRANG_THAI_SAI'
      -- Luật Đ36: lịch nhắc tự sinh của phiếu đi theo người phụ trách phiếu.
      when v_appt.is_auto_reminder then 'HMT_LICH_NHAC_THEO_PHIEU'
      when v_appt.owner_id = p_owner_id then 'HMT_GIAO_CUNG_NGUOI'
      -- Luật R-CRM-38 (b): người nhận thuộc đúng cơ sở của lịch hẹn.
      when not exists (select from app.user_account u
                        where u.id = p_owner_id and not u.is_locked and u.student_code is null and u.branch_id = v_appt.branch_id)
        then 'HMT_NGUOI_PHU_TRACH_SAI'
      else null end;
    if v_code is not null then
      v_skipped := jsonb_set(v_skipped, array[v_code], coalesce(v_skipped -> v_code, '[]'::jsonb) || to_jsonb(v_id), true);
      continue;
    end if;
    v_old_name := app.staff_display_name(v_appt.owner_id);
    update app.appointment set owner_id = p_owner_id where id = v_id;
    v_assigned := v_assigned + 1;
    -- Ghi chú hệ thống trên hồ sơ gắn (không đổi người phụ trách của hồ sơ đó).
    select case when v_appt.lead_id is not null then 'LEAD' when v_appt.opportunity_id is not null then 'OPPORTUNITY'
                else 'STUDENT_TEST' end,
           coalesce(v_appt.lead_id, v_appt.opportunity_id, v_appt.student_test_id)
      into v_entity_type, v_entity_id;
    perform app.add_system_note(v_entity_type, v_entity_id,
      format('Giao lịch hẹn "%s" (%s) từ %s sang %s.', v_appt.title,
             to_char(v_appt.scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI'), v_old_name, v_new_name));
  end loop;

  -- Nhóm bị bỏ, theo thứ tự cố định của luật; mỗi nhóm có câu tiếng Việt để giao diện hiện thẳng.
  foreach k in array array['HMT_KHONG_TIM_THAY', 'HMT_LICH_HEN_TRANG_THAI_SAI', 'HMT_LICH_NHAC_THEO_PHIEU',
                           'HMT_GIAO_CUNG_NGUOI', 'HMT_NGUOI_PHU_TRACH_SAI'] loop
    if v_skipped ? k then
      v_reasons := v_reasons || jsonb_build_object(
        'code', k,
        'message', case k
          when 'HMT_KHONG_TIM_THAY' then 'Không tìm thấy lịch hẹn (hoặc lịch hẹn ở cơ sở khác).'
          when 'HMT_LICH_HEN_TRANG_THAI_SAI' then 'Chỉ giao được lịch hẹn chưa làm; lịch đã hoàn thành hoặc huỷ là lịch sử.'
          when 'HMT_LICH_NHAC_THEO_PHIEU' then 'Lịch nhắc tự sinh của phiếu kiểm tra đi theo người phụ trách phiếu; đổi người phụ trách ở phiếu.'
          when 'HMT_GIAO_CUNG_NGUOI' then 'Lịch hẹn đã do người này phụ trách.'
          else 'Người phụ trách phải là nhân sự đang hoạt động của đúng cơ sở của lịch hẹn.' end,
        'count', jsonb_array_length(v_skipped -> k),
        'ids', v_skipped -> k);
    end if;
  end loop;
  return jsonb_build_object('requested', v_requested, 'assigned', v_assigned, 'skipped', v_requested - v_assigned,
                            'reasons', v_reasons);
end;
$$;

-- ---------------------------------------------------------------------------
-- Dời lịch hẹn (thay thân hàm của migration 035; thêm luật Đ37 ngày 24/10).
-- Làm gì: đổi giờ hẹn, có thể kèm đổi người phụ trách của lịch hẹn và ghi chú; ghi ghi chú hệ thống trên hồ sơ gắn.
-- Ai gọi: người có quyền Lịch hẹn · Sửa (đổi người phụ trách cần thêm Giao việc). Đầu vào: id, giờ mới, người phụ trách mới (tuỳ
--   chọn), ghi chú (tuỳ chọn).
-- Luật: R-CRM-38 (a) chỉ lịch Chưa làm; (b) đổi người phụ trách cần Giao việc và người mới thuộc đúng cơ sở; (c) ghi chú dời.
--   Đ37 (mới): LỊCH NHẮC TỰ SINH của phiếu kiểm tra KHÔNG đổi người phụ trách bằng tay (kể cả Trưởng cơ sở có Giao việc), vì nó đi
--   theo người phụ trách phiếu: HMT_LICH_NHAC_THEO_PHIEU. Dời giờ và ghi chú của lịch nhắc vẫn như cũ.
-- ---------------------------------------------------------------------------
create or replace function app.reschedule_appointment(
  p_id uuid, p_scheduled_at timestamptz, p_owner_id uuid default null, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt app.appointment := app.appointment_for_update(p_id, 'SUA');
  v_owner uuid := coalesce(p_owner_id, v_appt.owner_id);
  v_entity_type text;
  v_entity_id uuid;
  v_line text;
begin
  -- Luật R-CRM-38 (a): chỉ lịch hẹn Chưa làm dời được.
  if v_appt.status <> 'CHUA_LAM' then
    perform app.raise_error('HMT_LICH_HEN_TRANG_THAI_SAI', 'Chỉ dời được lịch hẹn chưa làm. Mở lại trước nếu cần dời.');
  end if;
  if p_scheduled_at is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ngày giờ mới của lịch hẹn.');
  end if;
  -- Luật Đ37, R-CRM-38 (ngoại lệ 24/10): lịch nhắc tự sinh của phiếu kiểm tra không đổi người phụ trách bằng tay, kể cả người có
  -- quyền Giao việc (đi theo người phụ trách phiếu). Chỉ chặn việc đổi người; dời giờ, ghi chú vẫn như cũ.
  if v_owner <> v_appt.owner_id and v_appt.is_auto_reminder then
    perform app.raise_error('HMT_LICH_NHAC_THEO_PHIEU',
      'Lịch nhắc tự sinh của phiếu kiểm tra đi theo người phụ trách phiếu: đổi người phụ trách ở phiếu, không đổi ở lịch nhắc.');
  end if;
  -- Luật R-CRM-38 (b): đổi người phụ trách cần quyền Giao việc; người mới thuộc đúng cơ sở của lịch hẹn.
  if v_owner <> v_appt.owner_id then
    perform app.assert_can('APPOINTMENT', 'GIAO_VIEC', v_appt.branch_id);
    perform app.assert_staff_in_branch(v_owner, v_appt.branch_id);
  end if;

  update app.appointment set scheduled_at = p_scheduled_at, owner_id = v_owner where id = p_id;

  -- Luật R-CRM-38 (c): ghi chú dời trên hồ sơ gắn (nhật ký của lịch hẹn đã tự ghi giờ và người phụ trách).
  select case when v_appt.lead_id is not null then 'LEAD' when v_appt.opportunity_id is not null then 'OPPORTUNITY'
              else 'STUDENT_TEST' end,
         coalesce(v_appt.lead_id, v_appt.opportunity_id, v_appt.student_test_id)
    into v_entity_type, v_entity_id;
  v_line := format('Dời lịch hẹn "%s" từ %s sang %s.', v_appt.title,
                   to_char(v_appt.scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI'),
                   to_char(p_scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI'));
  if v_owner <> v_appt.owner_id then
    v_line := v_line || format(' Người phụ trách mới: %s.', app.staff_display_name(v_owner));
  end if;
  if btrim(coalesce(p_note, '')) <> '' then
    v_line := v_line || format(' Ghi chú: %s', btrim(p_note));
  end if;
  perform app.add_system_note(v_entity_type, v_entity_id, v_line);
end;
$$;

revoke execute on function app.appointment_group_label(text, text) from public, anon, authenticated;
revoke execute on function
  app.appointment_group_counts(jsonb, text[]), app.export_appointments(jsonb), app.assign_appointments(uuid[], uuid)
  from public, anon;
grant execute on function
  app.appointment_group_counts(jsonb, text[]), app.export_appointments(jsonb), app.assign_appointments(uuid[], uuid)
  to authenticated;
