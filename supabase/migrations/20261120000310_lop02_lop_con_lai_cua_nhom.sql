-- LOP-02 (KHO dòng 20, F66): app.get_class_record giữ nguyên bản ở 20261111000116_cum_lop_doc_du_lieu.sql, chỉ thêm khoá group_classes (các lớp còn lại của nhóm lớp; chỉ đọc, không đổi quyền).
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
    -- LOP-02 (canvas 9933): «Lớp còn lại của nhóm» = các lớp KHÁC cùng nhóm lớp (R-LOP-14), mỗi lớp độc lập; chỉ liệt kê lớp người xem được (RLS theo cơ sở như danh sách).
    'group_classes', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'code', o.code,
                                  'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = o.subject_code),
                                  'status_code', o.status_code,
                                  'status_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_STATUS' and ci.code = o.status_code),
                                  'teacher_names', (select string_agg(distinct app.staff_display_name(sl.teacher_id), ', ') from app.class_slot sl
                                                     where sl.class_id = o.id and sl.is_active and sl.teacher_id is not null)) order by o.code)
                                 from app.class o
                                where c.group_id is not null and o.group_id = c.group_id and o.id <> c.id
                                  and (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and o.branch_id = app.current_branch_id())
                                       or (v_scope = 'DUOC_PHAN_CONG' and app.is_assigned_to_class(o.id)))), '[]'::jsonb),
    'events', coalesce((select jsonb_agg(jsonb_build_object('event_code', z.event_code, 'created_at', z.created_at, 'note', z.note) order by z.created_at desc)
               from (select * from app.class_event ev where ev.class_id = c.id order by ev.created_at desc limit 20) z), '[]'::jsonb)); -- allow-number: 20 sự kiện mới nhất
end;
$$;