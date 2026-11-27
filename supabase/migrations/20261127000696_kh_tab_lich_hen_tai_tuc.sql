-- D-27-04 PR E (Chat duyệt 27/11/2026; migration 696; rủi ro VỪA). Hồ sơ 360°: tab «Lịch hẹn», «Tái tục» và khối «Hoạt động sắp tới» của hồ sơ
-- phụ huynh, học sinh (canvas a8d7: KH02_lich_hen, KH02_tai_tuc, KH05_lich_hen, KH05_tai_tuc). Hai hàm chỉ đọc, phân trang ở máy chủ.
-- Phạm vi giống màn danh sách: Toàn hệ thống hoặc Cơ sở mình (list_appointments; chính sách upsale_ticket_read).

-- app.record_appointment_ids: lịch hẹn liên quan một phụ huynh (lịch gắn thẳng, gắn con, gắn cơ hội hoặc lead của cơ hội, gắn phiếu kiểm tra của con)
-- hoặc một học sinh (gắn thẳng, gắn phiếu kiểm tra của em). Mỗi nguồn một nhánh để dùng đúng chỉ mục. Hàm trong.
create or replace function app.record_appointment_ids(p_parent_id uuid, p_student_id uuid)
returns table (id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  with kids as (
    select s.id from app.student s where s.parent_id = p_parent_id
    union all select p_student_id where p_student_id is not null
  ), opps as (
    select o.id, o.lead_id from app.opportunity o where o.parent_id = p_parent_id
  )
  select a.id from app.appointment a where a.parent_id = p_parent_id
  union select a.id from app.appointment a where a.student_id in (select k.id from kids k)
  union select a.id from app.appointment a where a.student_test_id in (select t.id from app.student_test t where t.student_id in (select k.id from kids k))
  union select a.id from app.appointment a where a.opportunity_id in (select o.id from opps o)
  union select a.id from app.appointment a where a.lead_id in (select o.lead_id from opps o where o.lead_id is not null);
$$;

-- app.list_record_appointments: lịch hẹn của hồ sơ. Ai gọi: người có Lịch hẹn · Xem. Đầu vào: p_filters {parent_id | student_id, status[]};
-- p_sort time_asc | time_desc. Kết quả {total, rows}.
create or replace function app.list_record_appointments(
  p_filters jsonb, p_sort text default 'time_desc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('APPOINTMENT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_result jsonb;
begin
  if coalesce(v_scope, '') not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lịch hẹn.');
  end if;
  with f as (
    select a.*
      from app.appointment a
      join app.record_appointment_ids((p_filters ->> 'parent_id')::uuid, (p_filters ->> 'student_id')::uuid) r on r.id = a.id
     where (v_scope = 'TOAN_HE_THONG' or a.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or a.status = any (v_status))
  ), page as (
    select * from f
     order by case when p_sort = 'time_desc' then f.scheduled_at end desc, f.scheduled_at, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'activity_code', p.activity_code, 'scheduled_at', p.scheduled_at, 'title', p.title, 'status', p.status,
             'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id), 'is_auto_reminder', p.is_auto_reminder,
             'branch_id', p.branch_id,
             'lead_id', p.lead_id, 'opportunity_id', p.opportunity_id, 'student_test_id', p.student_test_id,
             'parent_id', p.parent_id, 'student_id', p.student_id,
             'record_code', coalesce(l.code, o.code, t.code, ap.code, ast.code),
             -- Học sinh liên quan (cột «Học sinh» của tab phụ huynh): lịch gắn em, hoặc phiếu kiểm tra của em.
             'student_name', coalesce(ast.full_name, (select s.full_name from app.student s where s.id = t.student_id)))
             order by case when p_sort = 'time_desc' then p.scheduled_at end desc, p.scheduled_at, p.id), '[]'::jsonb))
    into v_result
    from page p
    left join app.lead l on l.id = p.lead_id
    left join app.opportunity o on o.id = p.opportunity_id
    left join app.student_test t on t.id = p.student_test_id
    left join app.parent ap on ap.id = p.parent_id
    left join app.student ast on ast.id = p.student_id;
  return v_result;
end;
$$;

-- app.list_record_upsale: phiếu tái tục của một phụ huynh hoặc học sinh. Ai gọi: người có Tái tục · Xem. Đầu vào: p_filters {parent_id | student_id}.
-- Phiếu đang mở đứng trước. «absences»: số buổi vắng trong cửa sổ cờ rủi ro (R-GD-13, như bản ghi phiếu tái tục). Kết quả {total, rows}.
create or replace function app.list_record_upsale(
  p_filters jsonb, p_sort text default 'open_first', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('UPSALE', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_parent uuid := (p_filters ->> 'parent_id')::uuid;
  v_student uuid := (p_filters ->> 'student_id')::uuid;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phiếu tái tục.');
  end if;
  with f as (
    select u.* from app.upsale_ticket u
     where (u.parent_id = v_parent or u.student_id = v_student)
       and (v_scope = 'TOAN_HE_THONG' or u.branch_id = v_my_branch)
  ), page as (
    select * from f order by (f.closed_at is not null), f.created_at desc, f.id limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'student_name', s.full_name,
             'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = c.subject_catalog and ci.code = c.subject_code),
             'class_code', c.code, 'hours_left', p.hours_left, 'expected_end_date', p.expected_end_date,
             'stage_code', p.stage_code,
             'stage_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'UPSALE_STAGE' and ci.code = p.stage_code),
             'owner_name', app.staff_display_name(p.owner_id), 'risk', p.risk_flag,
             'absences', (select count(*) from app.session_attendance sa join app.class_session cs on cs.id = sa.session_id
                           where sa.student_id = p.student_id and cs.class_id = p.class_id and sa.is_active
                             and coalesce(sa.teacher_status_code, sa.ops_status_code) in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')
                             and cs.session_date > v_today - app.get_setting_int('absence_risk_window_days', p.branch_id)::integer))
             order by (p.closed_at is not null), p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.student s on s.id = p.student_id
    join app.class c on c.id = p.class_id;
  return v_result;
end;
$$;

revoke execute on function app.record_appointment_ids(uuid, uuid) from public, anon, authenticated;
revoke execute on function app.list_record_appointments(jsonb, text, integer, integer), app.list_record_upsale(jsonb, text, integer, integer) from public, anon;
grant execute on function app.list_record_appointments(jsonb, text, integer, integer), app.list_record_upsale(jsonb, text, integer, integer) to authenticated;
