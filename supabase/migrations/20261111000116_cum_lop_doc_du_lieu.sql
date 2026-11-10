-- Cụm Lớp (Code 2, 10/11/2026): hàm đọc cho LOP-01 (danh sách lớp), LOP-02 (hồ sơ lớp), LOP-08 (lịch tuần cơ sở).
-- Luật: R-LOP-01 (tình trạng duyệt), R-LOP-05 (tình trạng vận hành), R-LOP-08/09 (cảnh báo trùng, chỉ cảnh báo), R-LOP-14 (nhóm lớp), R-LOP-15 (tìm theo mã cũ).
-- Phạm vi theo quyền Lớp học · Xem: toàn hệ thống / cơ sở mình / lớp được phân công. Danh sách phân trang ở máy chủ (mặc định list_page_size_default, tối đa list_page_size_max).
-- Chỉ đọc; ghi vẫn qua các hàm của migration 100 (create_class, save_class_info, save_class_timetable, transition_class).

-- app.list_classes(bộ lọc, sắp xếp, limit, offset): danh sách lớp. Bộ lọc: status[] (tình trạng duyệt), operating[] (tình trạng vận hành),
-- branch_id, subject_code, grade_code, class_type_code, search (mã lớp hoặc mã cũ, không dấu). Sắp xếp: code_asc (mặc định), code_desc, start_desc.
-- Kết quả: {total, rows[]}; mỗi dòng có sĩ số, chỗ còn lại (null = không giới hạn), tên nhóm lớp.
create or replace function app.list_classes(p_filters jsonb default '{}'::jsonb, p_sort text default 'code_asc',
                                            p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('CLASS', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_operating text[] := array(select jsonb_array_elements_text(p_filters -> 'operating'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_subject text := nullif(p_filters ->> 'subject_code', '');
  v_grade text := nullif(p_filters ->> 'grade_code', '');
  v_type text := nullif(p_filters ->> 'class_type_code', '');
  v_search text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lớp học.');
  end if;
  with f as not materialized (
    select c.*, app.class_operating_status(c.id) as operating_status
      from app.class c
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and c.branch_id = v_my_branch)
            or (v_scope = 'DUOC_PHAN_CONG' and app.is_assigned_to_class(c.id)))
       and (cardinality(v_status) = 0 or c.status_code = any (v_status))
       and (v_branch is null or c.branch_id = v_branch)
       and (v_subject is null or c.subject_code = v_subject)
       and (v_grade is null or c.grade_code = v_grade)
       and (v_type is null or c.class_type_code = v_type)
       and (v_search is null or c.search_text like '%' || v_search || '%')
  ), g as (
    select * from f where cardinality(v_operating) = 0 or f.operating_status = any (v_operating)
  ), page as (
    select * from g
     order by case when p_sort = 'code_desc' then g.code end desc,
              case when p_sort = 'start_desc' then g.start_date end desc,
              g.code
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from g),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'legacy_ref', p.legacy_ref,
             'branch_id', p.branch_id, 'branch_code', b.code,
             'subject_code', p.subject_code, 'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = p.subject_code),
             'grade_code', p.grade_code,
             'class_type_code', p.class_type_code, 'class_type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_TYPE' and ci.code = p.class_type_code),
             'level_code', p.level_code, 'level_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'LEVEL' and ci.code = p.level_code),
             'status_code', p.status_code, 'status_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_STATUS' and ci.code = p.status_code),
             'operating_status', p.operating_status,
             'max_students', p.max_students,
             'enrolled', (select count(*) from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                           where ec.class_id = p.id and ec.end_date is null and e.status_code in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU')),
             'seats_left', app.class_seats_left(p.id),
             'start_date', p.start_date, 'expected_end_date', p.expected_end_date, 'total_sessions', p.total_sessions,
             'group_name', (select cg.display_name from app.class_group cg where cg.id = p.group_id),
             -- Lịch học và giáo viên theo khung giờ đang dùng (khung LOP-01: cột Lịch học, Giáo viên).
             'schedule', coalesce((select jsonb_agg(jsonb_build_object('weekday', sl.weekday, 'start_time', sl.start_time, 'end_time', sl.end_time) order by sl.weekday, sl.start_time)
                                     from app.class_slot sl where sl.class_id = p.id and sl.is_active), '[]'::jsonb),
             'teacher_names', (select string_agg(distinct app.staff_display_name(sl.teacher_id), ', ') from app.class_slot sl
                                where sl.class_id = p.id and sl.is_active and sl.teacher_id is not null))
             order by case when p_sort = 'code_desc' then p.code end desc, case when p_sort = 'start_desc' then p.start_date end desc, p.code), '[]'::jsonb))
    into v_result
    from page p join app.branch b on b.id = p.branch_id;
  return v_result;
end;
$$;

-- app.get_class_record(lớp): hồ sơ lớp cho LOP-02. Kết quả: thông tin lớp, khung giờ đang dùng (tên giáo viên, trợ giảng, phòng),
-- học sinh đang xếp (dòng xếp lớp mở, giờ còn), số buổi theo tình trạng, tối đa 100 buổi gần nhất đến sắp tới, cảnh báo trùng, lịch sử lớp (20 dòng mới nhất).
-- Quyền: như app.list_classes. Học sinh: chỉ tên, mã, giờ còn; không số điện thoại, phụ huynh (R-GV-13 áp dụng cho giáo viên được phân công).
create or replace function app.get_class_record(p_class_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('CLASS', 'XEM');
  c app.class;
begin
  select * into c from app.class where id = p_class_id;
  if c.id is null
     or v_scope is null
     or (v_scope = 'CO_SO' and c.branch_id is distinct from app.current_branch_id())
     or (v_scope = 'DUOC_PHAN_CONG' and not app.is_assigned_to_class(c.id)) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lớp này hoặc lớp không tồn tại.');
  end if;
  return jsonb_build_object(
    'id', c.id, 'code', c.code, 'legacy_ref', c.legacy_ref,
    'branch_code', (select b.code from app.branch b where b.id = c.branch_id), 'branch_id', c.branch_id,
    'year_code', c.year_code,
    'subject_code', c.subject_code, 'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
    'grade_code', c.grade_code,
    'class_type_code', c.class_type_code, 'class_type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_TYPE' and ci.code = c.class_type_code),
    'level_code', c.level_code, 'level_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'LEVEL' and ci.code = c.level_code),
    'status_code', c.status_code, 'status_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_STATUS' and ci.code = c.status_code),
    'operating_status', app.class_operating_status(c.id),
    'max_students', c.max_students, 'seats_left', app.class_seats_left(c.id),
    'start_date', c.start_date, 'total_sessions', c.total_sessions, 'expected_end_date', c.expected_end_date,
    'curriculum_ref', c.curriculum_ref, 'start_lesson', c.start_lesson, 'cskh_id', c.cskh_id, 'group_id', c.group_id,
    'group_name', (select cg.display_name from app.class_group cg where cg.id = c.group_id),
    'slots', coalesce((select jsonb_agg(jsonb_build_object(
               'id', sl.id, 'weekday', sl.weekday, 'start_time', sl.start_time, 'end_time', sl.end_time,
               'repeat_weeks', sl.repeat_weeks, 'first_date', sl.first_date,
               'teacher_id', sl.teacher_id, 'assistant_id', sl.assistant_id, 'room_id', sl.room_id,
               'teacher_name', app.staff_display_name(sl.teacher_id), 'assistant_name', app.staff_display_name(sl.assistant_id),
               'room_name', (select r.name from app.room r where r.id = sl.room_id)) order by sl.weekday, sl.start_time)
               from app.class_slot sl where sl.class_id = c.id and sl.is_active), '[]'::jsonb),
    'students', coalesce((select jsonb_agg(jsonb_build_object(
               'enrollment_id', e.id, 'enrollment_code', e.code, 'student_id', st.id, 'student_code', st.code, 'full_name', st.full_name,
               'start_date', ec.start_date, 'enrollment_status', e.status_code, 'hours_left', app.enrollment_hours_balance(e.id)) order by st.full_name, st.id)
               from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id join app.student st on st.id = e.student_id
              where ec.class_id = c.id and ec.end_date is null), '[]'::jsonb),
    'session_counts', coalesce((select jsonb_object_agg(x.status_code, x.n) from (
               select s.status_code, count(*) as n from app.class_session s where s.class_id = c.id and s.status_code <> 'DA_THAY' group by s.status_code) x), '{}'::jsonb),
    'sessions', coalesce((select jsonb_agg(jsonb_build_object(
               'id', y.id, 'session_no', y.session_no, 'session_date', y.session_date, 'start_time', y.start_time, 'end_time', y.end_time,
               'status_code', y.status_code, 'type_code', y.type_code, 'teacher_name', app.staff_display_name(y.teacher_id)) order by y.session_date, y.start_time)
               from (select * from app.class_session s where s.class_id = c.id and s.status_code <> 'DA_THAY'
                      order by s.session_date desc, s.start_time desc limit 100) y), '[]'::jsonb), -- allow-number: tối đa 100 buổi hiện trên hồ sơ lớp
    'clash_warnings', app.class_clash_warnings(c.id),
    'events', coalesce((select jsonb_agg(jsonb_build_object('event_code', z.event_code, 'created_at', z.created_at, 'note', z.note) order by z.created_at desc)
               from (select * from app.class_event ev where ev.class_id = c.id order by ev.created_at desc limit 20) z), '[]'::jsonb)); -- allow-number: 20 sự kiện mới nhất
end;
$$;

-- app.week_sessions(cơ sở, từ ngày, đến ngày, nhóm theo): lịch tuần cơ sở cho LOP-08 (R-LOP-08, R-LOP-13, R-LOP-14).
-- Trả mọi buổi (không huỷ, không bị thay) của cơ sở trong khoảng ngày (tối đa 14 ngày): lớp, giáo viên, trợ giảng, phòng, giờ, tình trạng, nhóm lớp
-- (cùng nhóm cùng màu viền), và cờ trùng phòng / trùng giáo viên ở cấp buổi thật (chỉ cảnh báo, không chặn; lớp luân phiên cùng nhóm không báo trùng).
create or replace function app.week_sessions(p_branch_id uuid, p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('CLASS', 'XEM');
begin
  if v_scope is null
     or (v_scope = 'CO_SO' and p_branch_id is distinct from app.current_branch_id())
     or (v_scope = 'DUOC_PHAN_CONG') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lịch tuần của cơ sở này.');
  end if;
  if p_to < p_from or p_to - p_from > 13 then -- allow-number: tối đa 14 ngày một lần xem lịch tuần
    perform app.raise_error('HMT_THAM_SO_SAI', 'Khoảng ngày xem lịch không hợp lệ (tối đa 14 ngày).');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'session_id', s.id, 'class_id', c.id, 'class_code', c.code, 'group_id', c.group_id,
             'session_date', s.session_date, 'start_time', s.start_time, 'end_time', s.end_time,
             'status_code', s.status_code, 'type_code', s.type_code,
             'teacher_name', app.staff_display_name(s.teacher_id), 'assistant_name', app.staff_display_name(s.assistant_id),
             'room_id', s.room_id, 'room_name', (select r.name from app.room r where r.id = s.room_id),
             'room_clash', s.room_id is not null and exists (
                select from app.class_session o
                 where o.id <> s.id and o.room_id = s.room_id and o.session_date = s.session_date and o.status_code in ('NHAP', 'DA_CHOT', 'DONE')
                   and o.start_time < s.end_time and o.end_time > s.start_time
                   and not (o.class_id in (select c2.id from app.class c2 where c2.group_id is not null and c2.group_id = c.group_id))),
             'teacher_clash', s.teacher_id is not null and exists (
                select from app.class_session o
                 where o.id <> s.id and o.teacher_id = s.teacher_id and o.session_date = s.session_date and o.status_code in ('NHAP', 'DA_CHOT', 'DONE')
                   and o.start_time < s.end_time and o.end_time > s.start_time
                   and not (o.class_id in (select c2.id from app.class c2 where c2.group_id is not null and c2.group_id = c.group_id))))
           order by s.session_date, s.start_time, c.code)
      from app.class_session s join app.class c on c.id = s.class_id
     where s.branch_id = p_branch_id and s.session_date between p_from and p_to and s.status_code in ('NHAP', 'DA_CHOT', 'DONE')), '[]'::jsonb);
end;
$$;

revoke execute on function app.list_classes(jsonb, text, integer, integer), app.get_class_record(uuid), app.week_sessions(uuid, date, date) from public, anon, authenticated;
grant execute on function app.list_classes(jsonb, text, integer, integer), app.get_class_record(uuid), app.week_sessions(uuid, date, date) to authenticated;

-- app.list_class_form_options(cơ sở): các lựa chọn cho biểu mẫu LOP-03: giáo viên (vai trò TEACHER), trợ giảng (TA), CSKH phụ trách (CSKH), phòng học của cơ sở.
-- Quyền: ai mở được lớp ở cơ sở đó (Lớp học · Tạo hoặc Sửa); chỉ trả tài khoản đang hoạt động (không khoá), kèm tên và mã nhân sự.
create or replace function app.list_class_form_options(p_branch_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := coalesce(app.permission_scope('CLASS', 'TAO'), app.permission_scope('CLASS', 'SUA'));
begin
  if v_scope is null or (v_scope = 'CO_SO' and p_branch_id is distinct from app.current_branch_id()) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền tạo hoặc sửa lớp ở cơ sở này.');
  end if;
  return jsonb_build_object(
    'teachers', coalesce((select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.display_name, 'staff_code', u.staff_code) order by u.display_name)
                            from app.user_account u where u.branch_id = p_branch_id and not u.is_locked
                             and exists (select from app.user_role r where r.user_id = u.id and r.is_active and r.role_code = 'TEACHER')), '[]'::jsonb),
    'assistants', coalesce((select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.display_name, 'staff_code', u.staff_code) order by u.display_name)
                            from app.user_account u where u.branch_id = p_branch_id and not u.is_locked
                             and exists (select from app.user_role r where r.user_id = u.id and r.is_active and r.role_code = 'TA')), '[]'::jsonb),
    'cskh', coalesce((select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.display_name, 'staff_code', u.staff_code) order by u.display_name)
                            from app.user_account u where u.branch_id = p_branch_id and not u.is_locked
                             and exists (select from app.user_role r where r.user_id = u.id and r.is_active and r.role_code = 'CSKH')), '[]'::jsonb),
    'rooms', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'name', r.name, 'capacity', r.capacity) order by r.sort_order, r.name)
                            from app.room r where r.branch_id = p_branch_id and r.is_active), '[]'::jsonb),
    'groups', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'grade_code', g.grade_code, 'name', g.display_name) order by g.created_at desc)
                            from app.class_group g where g.branch_id = p_branch_id), '[]'::jsonb));
end;
$$;
revoke execute on function app.list_class_form_options(uuid) from public, anon, authenticated;
grant execute on function app.list_class_form_options(uuid) to authenticated;
