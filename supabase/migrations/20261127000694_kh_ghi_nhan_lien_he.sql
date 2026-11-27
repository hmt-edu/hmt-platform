-- D-27-04 (Chat duyệt 27/11/2026; migration 694; rủi ro VỪA). PR D hồ sơ 360°: hộp «Ghi nhận liên hệ» (canvas a8d7, KH02_ghi_nhan_lien_he).
-- Làm gì: (1) danh mục CONTACT_CHANNEL, CONTACT_RESULT; (2) cột kênh, kết quả liên hệ trên app.note (R-CRM-30: không có bảng riêng);
-- (3) lịch hẹn gắn thêm được phụ huynh, học sinh (R-CRM-42); (4) app.log_contact; (5) app.record_notes trả thêm kênh, kết quả.
-- Gộp phụ huynh, học sinh: app.merge_move_refs tự chuyển hai khoá ngoại mới của lịch hẹn.
select set_config('hmt.migration', 'on', false);

insert into app.catalog (code, name, kind, description, sort_order)
select v.code, v.name, 'MO', v.description, (select coalesce(max(sort_order), 0) from app.catalog) + v.step
  from (values ('CONTACT_CHANNEL', 'Kênh liên hệ', 'Kênh của một lần ghi nhận liên hệ trên hồ sơ phụ huynh, học sinh.', 1),
               ('CONTACT_RESULT', 'Kết quả liên hệ', 'Kết quả của một lần ghi nhận liên hệ; khác Kết quả cuộc gọi của lịch hẹn.', 2))
       as v (code, name, description, step)
 where not exists (select from app.catalog c where c.code = v.code);
insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('CONTACT_CHANNEL', 'GOI_DIEN', 'Gọi điện', 1),
  ('CONTACT_CHANNEL', 'ZALO', 'Zalo', 2),
  ('CONTACT_CHANNEL', 'GAP_TRUC_TIEP', 'Gặp trực tiếp', 3),
  ('CONTACT_CHANNEL', 'KHAC', 'Khác', 4),
  ('CONTACT_RESULT', 'NGHE_MAY', 'Nghe máy, đã trao đổi', 1),
  ('CONTACT_RESULT', 'KHONG_NGHE_MAY', 'Không nghe máy', 2),
  ('CONTACT_RESULT', 'HEN_GOI_LAI', 'Hẹn gọi lại', 3),
  ('CONTACT_RESULT', 'TU_CHOI', 'Từ chối', 4)
on conflict (catalog_code, code) do nothing;

-- Ghi chú là lần liên hệ khi có đủ kênh và kết quả.
alter table app.note
  add column contact_channel_catalog text not null default 'CONTACT_CHANNEL' check (contact_channel_catalog = 'CONTACT_CHANNEL'),
  add column contact_channel_code text,
  add column contact_result_catalog text not null default 'CONTACT_RESULT' check (contact_result_catalog = 'CONTACT_RESULT'),
  add column contact_result_code text,
  add constraint note_contact_pair check ((contact_channel_code is null) = (contact_result_code is null)),
  add constraint note_contact_channel_fk foreign key (contact_channel_catalog, contact_channel_code) references app.catalog_item (catalog_code, code),
  add constraint note_contact_result_fk foreign key (contact_result_catalog, contact_result_code) references app.catalog_item (catalog_code, code);
comment on column app.note.contact_channel_code is 'Kênh liên hệ (danh mục CONTACT_CHANNEL); null với ghi chú thường.';
comment on column app.note.contact_result_code is 'Kết quả liên hệ (danh mục CONTACT_RESULT); đi cùng kênh.';
-- Chỉ mục (lý do): «Lần liên hệ cuối» và cờ «Lâu chưa liên hệ» (PR C) lấy lần liên hệ mới nhất của một hồ sơ.
create index note_contact_idx on app.note (entity_type, entity_id, created_at desc)
  where contact_channel_code is not null and not is_cancelled;

alter table app.appointment add column parent_id uuid references app.parent (id);
alter table app.appointment add column student_id uuid references app.student (id);
alter table app.appointment drop constraint appointment_one_parent;
alter table app.appointment add constraint appointment_one_parent
  check (num_nonnulls(lead_id, opportunity_id, student_test_id, parent_id, student_id) = 1);
-- Chỉ mục (lý do): khoá ngoại; tab Lịch hẹn của hồ sơ và chuyển dữ liệu khi gộp.
create index appointment_parent_idx on app.appointment (parent_id, scheduled_at) where parent_id is not null;
create index appointment_student_idx on app.appointment (student_id, scheduled_at) where student_id is not null;

-- Loại hồ sơ mà lịch hẹn gắn vào (đúng một cột khác null nên còn lại là học sinh).
create or replace function app.appointment_kind(p_lead uuid, p_opportunity uuid, p_test uuid, p_parent uuid)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when p_lead is not null then 'LEAD' when p_opportunity is not null then 'OPPORTUNITY'
              when p_test is not null then 'STUDENT_TEST' when p_parent is not null then 'PARENT' else 'STUDENT' end;
$$;
revoke execute on function app.appointment_kind(uuid, uuid, uuid, uuid) from public, anon;
grant execute on function app.appointment_kind(uuid, uuid, uuid, uuid) to authenticated;

-- app.list_appointments: chép nguyên bản đang chạy (422), chỉ thêm nhánh phụ huynh, học sinh (R-CRM-42).
create or replace function app.list_appointments(p_filters jsonb DEFAULT '{}'::jsonb, p_sort text DEFAULT 'time_asc'::text, p_limit integer DEFAULT NULL::integer, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_student uuid := nullif(p_filters ->> 'student_id', '')::uuid;
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
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and a.branch_id = v_my_branch))
       and (cardinality(v_status) = 0 or a.status = any (v_status))
       and (cardinality(v_activity) = 0 or a.activity_code = any (v_activity))
       and (v_from is null or a.scheduled_at >= v_from)
       and (v_to is null or a.scheduled_at < v_to)
       and (not v_mine or a.owner_id = auth.uid())
       and (v_lead is null or a.lead_id = v_lead)
       and (v_opp is null or a.opportunity_id = v_opp)
       and (v_test is null or a.student_test_id = v_test)
       and (v_parent is null or a.parent_id = v_parent)
       and (v_student is null or a.student_id = v_student)
       and (v_branch is null or a.branch_id = v_branch)
       and (v_owner is null or a.owner_id = v_owner)
       -- Loại hồ sơ gắn (Đ35, dùng khi mở một nhóm của Group By): LEAD, OPPORTUNITY hoặc STUDENT_TEST.
       and (cardinality(v_kind) = 0
            or app.appointment_kind(a.lead_id, a.opportunity_id, a.student_test_id, a.parent_id) = any (v_kind))
       -- Tìm theo tên, SĐT, mã của hồ sơ gắn (lead hoặc cơ hội): dò hồ sơ bằng chỉ mục trigram trước, rồi nối về lịch hẹn.
       and (v_q is null
            or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
            or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%')
            or a.parent_id in (select pa.id from app.parent pa where pa.search_text like '%' || v_q || '%')
            or a.student_id in (select sa.id from app.student sa where sa.search_text like '%' || v_q || '%'))
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
             'lead_label', l.parent_name || coalesce(' · ' || nullif((app.lead_first(l.id)).full_name, ''), ''),
             'opportunity_id', p.opportunity_id, 'opportunity_code', o.code,
             'student_test_id', p.student_test_id, 'student_test_code', t.code,
             'parent_id', p.parent_id, 'parent_code', ap.code, 'student_id', p.student_id, 'student_code', ast.code, 'is_auto_reminder', p.is_auto_reminder,
             'record_code', coalesce(l.code, o.code, t.code, ap.code, ast.code),
             'record_label', coalesce(l.parent_name || coalesce(' · ' || nullif((app.lead_first(l.id)).full_name, ''), ''),
                                      po.full_name || coalesce(' · ' || nullif((app.opp_first(o.id)).full_name, ''), ''),
                                      ts.full_name || ' · Phiếu kiểm tra',
                                      ap.full_name, ast.full_name),
             'cancel_reason_code', p.cancel_reason_code, 'branch_code', b.code)
             order by case when p_sort = 'time_desc' then p.scheduled_at end desc, p.scheduled_at asc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    left join app.lead l on l.id = p.lead_id
    left join app.opportunity o on o.id = p.opportunity_id
    left join app.parent po on po.id = o.parent_id
    left join app.student_test t on t.id = p.student_test_id
    left join app.student ts on ts.id = t.student_id
    left join app.parent ap on ap.id = p.parent_id
    left join app.student ast on ast.id = p.student_id;
  return v_result;
end;
$function$;

-- app.export_appointments: chép nguyên bản đang chạy (43), chỉ thêm nhánh phụ huynh, học sinh (R-CRM-42).
create or replace function app.export_appointments(p_filters jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_student uuid := nullif(p_filters ->> 'student_id', '')::uuid;
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
     and (v_parent is null or a.parent_id = v_parent)
     and (v_student is null or a.student_id = v_student)
     and (v_branch is null or a.branch_id = v_branch)
     and (v_owner is null or a.owner_id = v_owner)
     and (cardinality(v_kind) = 0
          or app.appointment_kind(a.lead_id, a.opportunity_id, a.student_test_id, a.parent_id) = any (v_kind))
     and (v_q is null
          or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
          or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%')
          or a.parent_id in (select pa.id from app.parent pa where pa.search_text like '%' || v_q || '%')
          or a.student_id in (select sa.id from app.student sa where sa.search_text like '%' || v_q || '%'));
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
       and (v_parent is null or a.parent_id = v_parent)
       and (v_student is null or a.student_id = v_student)
       and (v_branch is null or a.branch_id = v_branch)
       and (v_owner is null or a.owner_id = v_owner)
       and (cardinality(v_kind) = 0
            or app.appointment_kind(a.lead_id, a.opportunity_id, a.student_test_id, a.parent_id) = any (v_kind))
       and (v_q is null
            or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
            or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%')
            or a.parent_id in (select pa.id from app.parent pa where pa.search_text like '%' || v_q || '%')
            or a.student_id in (select sa.id from app.student sa where sa.search_text like '%' || v_q || '%'))
     order by a.scheduled_at desc, a.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'kind', app.appointment_group_label('kind', app.appointment_kind(f.lead_id, f.opportunity_id, f.student_test_id, f.parent_id)),
           'record_code', coalesce(l.code, o.code, t.code, ap.code, ast.code),
           'record_label', coalesce(l.parent_name || coalesce(' · ' || nullif((app.lead_first(l.id)).full_name, ''), ''),
                                    po.full_name || coalesce(' · ' || nullif((app.opp_first(o.id)).full_name, ''), ''),
                                    ts.full_name || ' · Phiếu kiểm tra',
                                      ap.full_name, ast.full_name),
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
    left join app.student ts on ts.id = t.student_id
    left join app.parent ap on ap.id = f.parent_id
    left join app.student ast on ast.id = f.student_id;
  -- Luật: ghi nhật ký xuất (ai, module, bộ lọc, số dòng).
  perform app.log_export('APPOINTMENT', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$function$;

-- app.appointment_group_counts: chép nguyên bản đang chạy (41), chỉ thêm nhánh phụ huynh, học sinh (R-CRM-42).
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
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_student uuid := nullif(p_filters ->> 'student_id', '')::uuid;
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
       and (v_parent is null or a.parent_id = v_parent)
       and (v_student is null or a.student_id = v_student)
       and (v_branch is null or a.branch_id = v_branch)
       and (v_owner is null or a.owner_id = v_owner)
       and (cardinality(v_kind) = 0
            or app.appointment_kind(a.lead_id, a.opportunity_id, a.student_test_id, a.parent_id) = any (v_kind))
       and (v_q is null
            or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
            or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%')
            or a.parent_id in (select pa.id from app.parent pa where pa.search_text like '%' || v_q || '%')
            or a.student_id in (select sa.id from app.student sa where sa.search_text like '%' || v_q || '%'))
  ),
  keyed as (
    select case v_f1 when 'status' then f.status when 'activity' then f.activity_code when 'owner' then f.owner_id::text
                     when 'branch' then f.branch_id::text
                     when 'kind' then app.appointment_kind(f.lead_id, f.opportunity_id, f.student_test_id, f.parent_id) end as k1,
           case v_f2 when 'status' then f.status when 'activity' then f.activity_code when 'owner' then f.owner_id::text
                     when 'branch' then f.branch_id::text
                     when 'kind' then app.appointment_kind(f.lead_id, f.opportunity_id, f.student_test_id, f.parent_id) end as k2
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

-- app.appointment_group_label: chép nguyên bản đang chạy (41), chỉ thêm nhánh phụ huynh, học sinh (R-CRM-42).
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
                                          when 'STUDENT_TEST' then 'Phiếu kiểm tra'
                                          when 'PARENT' then 'Phụ huynh' when 'STUDENT' then 'Học sinh' else p_key end
    else p_key end;
$$;

-- app.reschedule_appointment: chép nguyên bản đang chạy (41), chỉ thêm nhánh phụ huynh, học sinh (R-CRM-42).
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
  select app.appointment_kind(v_appt.lead_id, v_appt.opportunity_id, v_appt.student_test_id, v_appt.parent_id),
         coalesce(v_appt.lead_id, v_appt.opportunity_id, v_appt.student_test_id, v_appt.parent_id, v_appt.student_id)
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

-- app.assign_appointments: chép nguyên bản đang chạy (41), chỉ thêm nhánh phụ huynh, học sinh (R-CRM-42).
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
                        where u.id = p_owner_id and not u.is_locked and u.student_code is null and u.parent_code is null and u.branch_id = v_appt.branch_id)
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
    select app.appointment_kind(v_appt.lead_id, v_appt.opportunity_id, v_appt.student_test_id, v_appt.parent_id),
         coalesce(v_appt.lead_id, v_appt.opportunity_id, v_appt.student_test_id, v_appt.parent_id, v_appt.student_id)
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

-- app.add_appointment_note: chép nguyên bản đang chạy (46), chỉ thêm nhánh phụ huynh, học sinh (R-CRM-42).
create or replace function app.add_appointment_note(p_appt app.appointment, p_text text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type text := app.appointment_kind(p_appt.lead_id, p_appt.opportunity_id, p_appt.student_test_id, p_appt.parent_id);
  v_id uuid := coalesce(p_appt.lead_id, p_appt.opportunity_id, p_appt.student_test_id, p_appt.parent_id, p_appt.student_id);
begin
  perform app.add_system_note(v_type, v_id, p_text);
end;
$$;

-- app.complete_appointment: chép nguyên bản đang chạy (628), chỉ thêm nhánh phụ huynh, học sinh (R-CRM-42).
create or replace function app.complete_appointment(
  p_id uuid, p_result_code text default null, p_result_note text default null,
  p_next_at timestamptz default null, p_next_activity_code text default null, p_next_title text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt app.appointment := app.appointment_for_update(p_id, 'SUA');
  v_result text := nullif(btrim(coalesce(p_result_code, '')), '');
  v_note text := nullif(btrim(coalesce(p_result_note, '')), '');
  v_next uuid;
  v_text text;
begin
  -- Luật R-CRM-04: chỉ hoàn thành lịch Chưa làm.
  if v_appt.status <> 'CHUA_LAM' then
    perform app.raise_error('HMT_LICH_HEN_TRANG_THAI_SAI', 'Chỉ hoàn thành được lịch hẹn chưa làm.');
  end if;
  -- Luật TS-13: Gọi điện phải có kết quả khi tham số bật; lịch tự nhắc bỏ qua.
  if v_result is null and v_appt.activity_code = 'GOI_DIEN' and not v_appt.is_auto_reminder
     and app.get_setting_bool('appointment_call_result_required', v_appt.branch_id) then
    perform app.raise_error('HMT_THIEU_KET_QUA', 'Chọn kết quả cuộc gọi trước khi hoàn thành.');
  end if;
  if v_result is not null and not exists (
       select from app.catalog_item c where c.catalog_code = 'APPOINTMENT_RESULT' and c.code = v_result and c.is_active) then
    perform app.raise_error('HMT_KET_QUA_KHONG_HOP_LE', 'Kết quả cuộc gọi không có trong danh mục.');
  end if;
  if v_note is not null and char_length(v_note) > 1000 then -- allow-number: độ dài tối đa ghi chú kết quả, trùng ràng buộc cột
    perform app.raise_error('HMT_GHI_CHU_DAI', 'Ghi chú kết quả quá dài.');
  end if;
  -- Luật: hẹn lần sau phải ở tương lai, gắn cùng hồ sơ (lead, cơ hội, phụ huynh, học sinh); lịch gắn phiếu kiểm tra không có hồ sơ để hẹn tiếp.
  if p_next_at is not null then
    if p_next_at <= now() then
      perform app.raise_error('HMT_HEN_LAN_SAU_QUA_KHU', 'Hẹn lần sau phải sau thời điểm hiện tại.');
    end if;
    if num_nonnulls(v_appt.lead_id, v_appt.opportunity_id, v_appt.parent_id, v_appt.student_id) = 0 then
      perform app.raise_error('HMT_LICH_HEN_KHONG_HEN_LAN_SAU', 'Lịch hẹn này không gắn lead, cơ hội, phụ huynh hay học sinh nên không hẹn lần sau được.');
    end if;
    v_next := app.create_appointment(
      v_appt.lead_id, coalesce(nullif(btrim(coalesce(p_next_activity_code, '')), ''), v_appt.activity_code), p_next_at,
      coalesce(nullif(btrim(coalesce(p_next_title, '')), ''), 'Gọi lại: ' || v_appt.title), null, auth.uid(), v_appt.opportunity_id,
      v_appt.parent_id, v_appt.student_id);
  end if;
  update app.appointment
     set status = 'HOAN_THANH', completed_at = now(), completed_by = auth.uid(),
         result_code = v_result, result_note = v_note, next_appointment_id = v_next
   where id = p_id;
  -- Luật R-CRM-04: ghi lịch sử, không đổi giai đoạn, không tạo việc, không báo ai.
  v_text := format('Hoàn thành lịch hẹn "%s" (hẹn lúc %s).', v_appt.title,
    to_char(v_appt.scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI'));
  if v_result is not null then
    v_text := v_text || format(' Kết quả: %s.', (select c.name from app.catalog_item c where c.catalog_code = 'APPOINTMENT_RESULT' and c.code = v_result));
  end if;
  if v_note is not null then
    v_text := v_text || format(' Ghi chú: %s.', v_note);
  end if;
  if v_next is not null then
    v_text := v_text || format(' Hẹn lần sau lúc %s.', to_char(p_next_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI'));
  end if;
  perform app.add_appointment_note(v_appt, v_text);
end;
$$;

-- app.work_appointments: chép nguyên bản đang chạy (679), chỉ thêm nhánh phụ huynh, học sinh (R-CRM-42).
create or replace function app.work_appointments(p_mine boolean, p_branch uuid, p_until timestamptz, p_window integer)
returns setof app.work_item
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('APPOINTMENT', 'XEM');
  v_my uuid := app.current_branch_id();
  v_me uuid := auth.uid();
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    return;
  end if;
  return query
  select 'APPOINTMENT', 'APPOINTMENT', a.id, coalesce(l.parent_id, o.parent_id, s.parent_id, a.parent_id, st2.parent_id),
         case when coalesce(l.parent_id, o.parent_id, s.parent_id, a.parent_id, st2.parent_id) is null then l.parent_phone end,
         app.work_urgency(a.scheduled_at, p_window), a.title,
         case when a.scheduled_at < now() then 'Lịch hẹn đã quá giờ' else 'Lịch hẹn sắp tới giờ' end,
         a.scheduled_at, 'COMPLETE_APPOINTMENT', a.owner_id, a.branch_id
    from app.appointment a
    left join app.lead l on l.id = a.lead_id
    left join app.opportunity o on o.id = a.opportunity_id
    left join app.student_test t on t.id = a.student_test_id
    left join app.student s on s.id = t.student_id
    left join app.student st2 on st2.id = a.student_id
   where a.status = 'CHUA_LAM' and a.scheduled_at < p_until
     and (v_scope = 'TOAN_HE_THONG' or a.branch_id = v_my)
     and (p_branch is null or a.branch_id = p_branch)
     and (not p_mine or a.owner_id = v_me)
     and not (a.is_auto_reminder and t.status_code = 'DRAFT');
end;
$$;

-- app.create_appointment: chép nguyên bản đang chạy (28), chỉ thêm nhánh phụ huynh, học sinh (R-CRM-42).
drop function app.create_appointment(uuid, text, timestamptz, text, text, uuid, uuid);
create or replace function app.create_appointment(
  p_lead_id uuid, p_activity_code text, p_scheduled_at timestamptz, p_title text,
  p_note text default null, p_owner_id uuid default null, p_opportunity_id uuid default null,
  p_parent_id uuid default null, p_student_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
  v_status text;
  v_owner uuid := coalesce(p_owner_id, auth.uid());
  v_id uuid;
begin
  -- Luật R-CRM-42: lịch hẹn gắn đúng một hồ sơ (lead, cơ hội, phụ huynh hoặc học sinh), không mồ côi, không gắn hai nơi.
  if num_nonnulls(p_lead_id, p_opportunity_id, p_parent_id, p_student_id) <> 1 then
    perform app.raise_error('HMT_LICH_HEN_MO_COI', 'Lịch hẹn phải gắn với đúng một hồ sơ.');
  end if;
  if p_lead_id is not null then
    select branch_id, record_status into v_branch_id, v_status from app.lead where id = p_lead_id;
  elsif p_opportunity_id is not null then
    select branch_id, record_status into v_branch_id, v_status from app.opportunity where id = p_opportunity_id;
  elsif p_parent_id is not null then
    select branch_id, record_status into v_branch_id, v_status from app.parent where id = p_parent_id;
  else
    select branch_id, record_status into v_branch_id, v_status from app.student where id = p_student_id;
  end if;
  if v_branch_id is null then
    perform app.raise_error('HMT_LICH_HEN_MO_COI', 'Lịch hẹn phải gắn với một hồ sơ.');
  end if;
  perform app.assert_can('APPOINTMENT', 'TAO', v_branch_id);
  if v_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Hồ sơ này đã gộp vào bản khác, không thêm lịch hẹn được.');
  end if;
  if v_owner <> auth.uid() then
    perform app.assert_can('APPOINTMENT', 'GIAO_VIEC', v_branch_id);
  end if;
  perform app.assert_staff_in_branch(v_owner, v_branch_id);
  perform app.assert_catalog_code_active('ACTIVITY_TYPE', p_activity_code);
  if p_scheduled_at is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ngày giờ của lịch hẹn.');
  end if;
  if btrim(coalesce(p_title, '')) = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập nội dung lịch hẹn.');
  end if;
  insert into app.appointment (lead_id, opportunity_id, parent_id, student_id, activity_code, scheduled_at, title, note, owner_id, branch_id)
  values (p_lead_id, p_opportunity_id, p_parent_id, p_student_id, p_activity_code, p_scheduled_at, btrim(p_title), p_note, v_owner, v_branch_id)
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function app.create_appointment(uuid, text, timestamptz, text, text, uuid, uuid, uuid, uuid) from public, anon;
grant execute on function app.create_appointment(uuid, text, timestamptz, text, text, uuid, uuid, uuid, uuid) to authenticated;

-- app.log_contact: ghi một lần liên hệ trên hồ sơ phụ huynh hoặc học sinh, kèm hẹn lần sau (tuỳ chọn).
-- Ai gọi: người thêm được ghi chú trên hồ sơ đó (R-CRM-43; kiểm trong app.add_note). Hẹn lần sau cần thêm quyền Lịch hẹn · Tạo.
-- Đầu vào: loại hồ sơ (PARENT, STUDENT), id, kênh, kết quả, nội dung, giờ hẹn lần sau. Kết quả: id ghi chú.
-- Lỗi: HMT_LOAI_BAN_GHI_SAI, HMT_BAN_GHI_DA_GOP, HMT_THIEU_THONG_TIN, HMT_HEN_LAN_SAU_QUA_KHU. Một giao dịch.
create or replace function app.log_contact(
  p_entity_type text, p_entity_id uuid, p_channel_code text, p_result_code text, p_body text,
  p_next_at timestamptz default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note uuid;
begin
  -- Luật R-CRM-43: chỉ hồ sơ phụ huynh, học sinh.
  if p_entity_type is null or p_entity_type not in ('PARENT', 'STUDENT') then
    perform app.raise_error('HMT_LOAI_BAN_GHI_SAI', 'Chỉ ghi nhận liên hệ trên hồ sơ phụ huynh, học sinh.');
  end if;
  if p_channel_code is null or p_result_code is null or btrim(coalesce(p_body, '')) = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn kênh, kết quả và nhập nội dung liên hệ.');
  end if;
  perform app.assert_catalog_code_active('CONTACT_CHANNEL', p_channel_code);
  perform app.assert_catalog_code_active('CONTACT_RESULT', p_result_code);
  -- Quyền: dùng lại luật thêm ghi chú.
  v_note := app.add_note(p_entity_type, p_entity_id, p_body);
  -- Luật: hồ sơ đã gộp chỉ xem.
  if exists (select from app.parent where p_entity_type = 'PARENT' and id = p_entity_id and record_status = 'DA_GOP')
     or exists (select from app.student where p_entity_type = 'STUDENT' and id = p_entity_id and record_status = 'DA_GOP') then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Hồ sơ này đã gộp vào bản khác, không ghi nhận liên hệ được.');
  end if;
  update app.note set contact_channel_code = p_channel_code, contact_result_code = p_result_code where id = v_note;
  -- Luật R-CRM-42: hẹn lần sau là lịch hẹn gắn chính hồ sơ này, người ghi phụ trách. Kênh «Khác» hẹn bằng Gọi điện.
  if p_next_at is not null then
    if p_next_at <= now() then
      perform app.raise_error('HMT_HEN_LAN_SAU_QUA_KHU', 'Hẹn lần sau phải sau thời điểm hiện tại.');
    end if;
    perform app.create_appointment(
      null, case when p_channel_code in ('ZALO', 'GAP_TRUC_TIEP') then p_channel_code else 'GOI_DIEN' end, p_next_at,
      'Liên hệ lại', null, auth.uid(), null,
      case when p_entity_type = 'PARENT' then p_entity_id end,
      case when p_entity_type = 'STUDENT' then p_entity_id end);
  end if;
  return v_note;
end;
$$;
revoke execute on function app.log_contact(text, uuid, text, text, text, timestamptz) from public, anon;
grant execute on function app.log_contact(text, uuid, text, text, text, timestamptz) to authenticated;

-- app.record_notes: như bản 047, trả thêm tên kênh và tên kết quả của lần liên hệ (null với ghi chú thường).
drop function app.record_notes(text, uuid);
create or replace function app.record_notes(p_entity_type text, p_entity_id uuid)
returns table (id uuid, at timestamptz, author_id uuid, author_name text, body text, mention_names text[], source_label text,
               contact_channel text, contact_result text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_lead uuid;
  v_lead_code text;
begin
  -- Luật: không thấy bản ghi thì không đọc được ghi chú của nó.
  if not app.can_see_note_target(p_entity_type, p_entity_id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem ghi chú của bản ghi này.');
  end if;
  -- Luật (26/10): cơ hội hiện thêm ghi chú của lead gốc, nếu người xem thấy được lead đó.
  if p_entity_type = 'OPPORTUNITY' then
    select o.lead_id into v_lead from app.opportunity o where o.id = p_entity_id;
    if v_lead is not null and not app.can_see_note_target('LEAD', v_lead) then
      v_lead := null;
    end if;
    select l.code into v_lead_code from app.lead l where l.id = v_lead;
  end if;
  return query
    select n.id, n.created_at, n.created_by, coalesce(a.display_name, 'Hệ thống'), n.body,
           coalesce((select array_agg(m.display_name order by m.display_name)
                       from app.note_mention nm join app.user_account m on m.id = nm.user_id
                      where nm.note_id = n.id), '{}'),
           case when n.entity_type = 'LEAD' and p_entity_type = 'OPPORTUNITY' then 'Lead ' || v_lead_code end,
           (select c.name from app.catalog_item c where c.catalog_code = n.contact_channel_catalog and c.code = n.contact_channel_code),
           (select c.name from app.catalog_item c where c.catalog_code = n.contact_result_catalog and c.code = n.contact_result_code)
      from app.note n
      left join app.user_account a on a.id = n.created_by
     where not n.is_cancelled
       and ((n.entity_type = p_entity_type and n.entity_id = p_entity_id)
            or (v_lead is not null and n.entity_type = 'LEAD' and n.entity_id = v_lead))
     order by n.created_at desc, n.id;
end;
$$;

revoke execute on function app.record_notes(text, uuid) from public, anon;
grant execute on function app.record_notes(text, uuid) to authenticated;
