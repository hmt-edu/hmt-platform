-- Migration 701 (Code C, 27/11/2026, C-27-07 mục 4a): hàm đọc cho màn «Điểm danh» (DD1, canvas «Đào tạo — menu và điểm danh»).
-- Dòng theo HỌC SINH của mọi buổi Đã chốt, Done trong khoảng ngày; tab «Cần gọi» cùng khoảng ngày. R-DD-02, R-DD-03, R-HT-07.
-- Màn mới không theo công tắc DIEM_DANH_TRONG_NGAY (anh chốt qua Chat 27/11). Chỉ mục dùng lại: class_session_branch_date_idx,
-- chỉ mục (session_id, …) của session_attendance.

select set_config('hmt.migration', 'on', false);
insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values ('attendance_range_max_days', 'Số ngày tối đa một lần xem Điểm danh', 'INT', 'ngày', 1, 92, '31', false, 'VAN_HANH_LOP', 'R-DD-02',
        'Màn Điểm danh chọn khoảng ngày dài hơn số này thì bị từ chối.')
on conflict (key) do nothing;
select set_config('hmt.migration', '', false);

-- app.attendance_range: khoảng ngày của bộ lọc {from, to}; thiếu thì hôm nay (giờ Việt Nam). Chặn khoảng ngược hoặc quá dài (nội bộ).
create or replace function app.attendance_range(p_filters jsonb, out d_from date, out d_to date)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_max integer := app.get_setting_int('attendance_range_max_days', null)::integer;
begin
  d_from := coalesce(nullif(p_filters ->> 'from', '')::date, v_today);
  d_to := coalesce(nullif(p_filters ->> 'to', '')::date, d_from);
  if d_to < d_from then
    perform app.raise_error('HMT_KHOANG_NGAY', 'Ngày kết thúc phải sau ngày bắt đầu.');
  end if;
  if d_to - d_from + 1 > v_max then
    perform app.raise_error('HMT_KHOANG_NGAY', format('Mỗi lần xem tối đa %s ngày.', v_max));
  end if;
end;
$$;

-- app.attendance_rows: mỗi dòng một học sinh trong danh sách của buổi Đã chốt, Done (nội bộ; nơi gọi đã kiểm quyền và phạm vi cơ sở).
-- effective = cột Giáo viên, trống thì cột Vận hành (R-DD-02 27/11). needs_call = vắng, đi muộn, hoặc chưa ai điểm danh khi buổi đã bắt đầu.
create or replace function app.attendance_rows(p_from date, p_to date, p_branch uuid, p_all_branches boolean)
returns table (
  attendance_id uuid, session_id uuid, student_id uuid, branch_id uuid, class_id uuid, session_date date, start_time time, end_time time,
  session_no integer, session_status text, teacher_id uuid, room_id uuid, ops_status text, teacher_status text, effective text,
  contact_reason_catalog text, contact_reason_code text, ops_note text, needs_call boolean)
language sql
stable
set search_path = ''
as $$
  select sa.id, s.id, sa.student_id, s.branch_id, s.class_id, s.session_date, s.start_time, s.end_time, s.session_no, s.status_code,
         s.teacher_id, s.room_id, sa.ops_status_code, sa.teacher_status_code, coalesce(sa.teacher_status_code, sa.ops_status_code),
         sa.contact_reason_catalog, sa.contact_reason_code, sa.ops_note,
         coalesce(coalesce(sa.teacher_status_code, sa.ops_status_code) in ('DI_MUON', 'VANG_CO_PHEP', 'VANG_KHONG_PHEP'),
                  (s.session_date + s.start_time) <= (now() at time zone 'Asia/Ho_Chi_Minh'))
    from app.class_session s
    join app.session_attendance sa on sa.session_id = s.id and sa.is_active
   where s.session_date between p_from and p_to and s.status_code in ('DA_CHOT', 'DONE')
     and (p_all_branches or s.branch_id = app.current_branch_id())
     and (p_branch is null or s.branch_id = p_branch)
$$;

-- app.attendance_board: tab «Theo buổi». Ai gọi: người có Buổi học · Xem toàn hệ thống hoặc cơ sở mình.
-- Vào: {from, to, branch_id, class_id, quick: CHUA | LECH}. Ra: {total, rows, summary, classes}. Số đếm theo cột Vận hành (cột đang nhập trên màn),
-- tính trên cả khoảng ngày sau lọc cơ sở, lớp, không phụ thuộc lọc nhanh. Dòng xếp theo ngày mới trước, giờ, lớp, tên.
create or replace function app.attendance_board(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.session_read_scope();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_quick text := nullif(p_filters ->> 'quick', '');
  r record;
  v_result jsonb;
begin
  select * into r from app.attendance_range(p_filters);
  with base as materialized (
    select * from app.attendance_rows(r.d_from, r.d_to, nullif(p_filters ->> 'branch_id', '')::uuid, v_scope = 'TOAN_HE_THONG')
  ), f as materialized (
    select * from base where v_class is null or class_id = v_class
  ), per_session as (
    select session_id, count(*) as total, count(ops_status) as marked from f group by session_id
  ), g as (
    select * from f
     where v_quick is null
        or (v_quick = 'CHUA' and ops_status is null)
        or (v_quick = 'LECH' and ops_status <> teacher_status)
  ), page as (
    select g.*, c.code as class_code, st.full_name as student_name
      from g join app.class c on c.id = g.class_id join app.student st on st.id = g.student_id
     order by g.session_date desc, g.start_time, c.code, g.session_id, st.full_name, g.attendance_id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'from', r.d_from, 'to', r.d_to,
    'total', (select count(*) from g),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
               'session_id', p.session_id, 'student_id', p.student_id, 'student_name', p.student_name,
               'session_date', p.session_date, 'start_time', to_char(p.start_time, 'HH24:MI'), 'end_time', to_char(p.end_time, 'HH24:MI'),
               'class_code', p.class_code, 'subject_name', sub.name, 'room_name', rm.name, 'teacher_name', u.display_name,
               'locked', p.session_status = 'DONE', 'session_total', ps.total, 'session_marked', ps.marked,
               'ops_status_code', p.ops_status, 'teacher_status_code', p.teacher_status,
               'contact_reason_code', p.contact_reason_code, 'contact_reason_name', rs.name, 'ops_note', p.ops_note)
             order by p.session_date desc, p.start_time, p.class_code, p.session_id, p.student_name, p.attendance_id)
        from page p
        join per_session ps on ps.session_id = p.session_id
        join app.class c on c.id = p.class_id
        join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
        left join app.room rm on rm.id = p.room_id
        left join app.user_account u on u.id = p.teacher_id
        left join app.catalog_item rs on rs.catalog_code = p.contact_reason_catalog and rs.code = p.contact_reason_code), '[]'::jsonb),
    'summary', (
      select jsonb_build_object(
               'present', count(*) filter (where ops_status = 'CO_MAT'),
               'late', count(*) filter (where ops_status = 'DI_MUON'),
               'absent', count(*) filter (where ops_status in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')),
               'unmarked', count(*) filter (where ops_status is null),
               'to_call', count(*) filter (where needs_call),
               'sessions', count(distinct session_id),
               'incomplete_sessions', count(distinct session_id) filter (where ops_status is null))
        from f),
    'classes', coalesce((
      select jsonb_agg(jsonb_build_object('id', c.id, 'code', c.code) order by c.code)
        from app.class c where c.id in (select class_id from base)), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

-- app.attendance_call_list: tab «Cần gọi». Ai gọi: người có Điểm danh · Sửa toàn hệ thống hoặc cơ sở mình.
-- Vào: {from, to, branch_id, start_time: 'HH:MM', no_reason: true}. Ra: {total, rows, times}.
-- Số điện thoại phụ huynh chỉ trả khi người gọi còn có Phụ huynh · Xem ở cơ sở của buổi (không mở rộng quyền xem phụ huynh).
create or replace function app.attendance_call_list(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ATTENDANCE', 'SUA');
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_time time := nullif(p_filters ->> 'start_time', '')::time;
  v_no_reason boolean := coalesce((p_filters ->> 'no_reason')::boolean, false);
  r record;
  v_result jsonb;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền ghi điểm danh vận hành.');
  end if;
  select * into r from app.attendance_range(p_filters);
  with base as materialized (
    select * from app.attendance_rows(r.d_from, r.d_to, nullif(p_filters ->> 'branch_id', '')::uuid, v_scope = 'TOAN_HE_THONG')
     where needs_call
  ), g as (
    select * from base where (v_time is null or start_time = v_time) and (not v_no_reason or contact_reason_code is null)
  ), page as (
    select g.*, c.code as class_code, st.full_name as student_name, st.parent_id
      from g join app.class c on c.id = g.class_id join app.student st on st.id = g.student_id
     order by g.session_date desc, g.start_time, st.full_name, g.attendance_id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'from', r.d_from, 'to', r.d_to,
    'total', (select count(*) from g),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
               'session_id', p.session_id, 'student_id', p.student_id, 'student_name', p.student_name,
               'session_date', p.session_date, 'start_time', to_char(p.start_time, 'HH24:MI'), 'class_code', p.class_code,
               'locked', p.session_status = 'DONE', 'status_code', p.effective,
               'contact_reason_code', p.contact_reason_code, 'contact_reason_name', rs.name, 'ops_note', p.ops_note,
               'parent_phone', case when app.can_see_branch_wide('PARENT', 'XEM', pa.branch_id) then pa.phone end)
             order by p.session_date desc, p.start_time, p.student_name, p.attendance_id)
        from page p
        join app.parent pa on pa.id = p.parent_id
        left join app.catalog_item rs on rs.catalog_code = p.contact_reason_catalog and rs.code = p.contact_reason_code), '[]'::jsonb),
    'times', coalesce((select jsonb_agg(t.x order by t.x) from (select distinct to_char(start_time, 'HH24:MI') as x from base) t), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

revoke execute on function app.attendance_range(jsonb), app.attendance_rows(date, date, uuid, boolean) from public, anon, authenticated;
revoke execute on function app.attendance_board(jsonb, integer, integer), app.attendance_call_list(jsonb, integer, integer) from public, anon;
grant execute on function app.attendance_board(jsonb, integer, integer), app.attendance_call_list(jsonb, integer, integer) to authenticated;
