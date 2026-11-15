-- BUOI-13: app.session_record trả thêm branch_id, teacher_id, assistant_id trong khối session (hộp Đổi giáo viên, dạy thay). Thân hàm giữ nguyên bản migration 123.
-- Quyền gọi giữ nguyên (create or replace không đổi quyền). Người xem vẫn qua kiểm phạm vi như cũ.
create or replace function app.session_record(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_session jsonb;
  v_hours integer;
begin
  -- Luật phạm vi: thao tác của vận hành (giáo viên không mở bản ghi này).
  s := app.assert_session_access(p_id, 'SESSION', 'XEM', true);
  v_hours := app.get_setting_int('teacher_session_complete_hours', s.branch_id);

  select jsonb_build_object(
           'id', s.id, 'status_code', s.status_code, 'status_name', st.name, 'type_code', s.type_code, 'type_name', ty.name, 'session_no', s.session_no,
           'session_date', s.session_date, 'start_time', to_char(s.start_time, 'HH24:MI'), 'end_time', to_char(s.end_time, 'HH24:MI'),
           'class_id', c.id, 'class_code', c.code, 'class_type_code', c.class_type_code, 'subject_name', sub.name, 'branch_code', b.code, 'branch_name', b.name,
           'teacher_name', t.display_name, 'assistant_name', ta.display_name, 'room_name', r.name, 'start_lesson', c.start_lesson,
           'cancel_reason_code', s.cancel_reason_code, 'cancel_reason_name', cr.name, 'cancel_note', s.cancel_note,
           -- BUOI-13: mã cơ sở và người dạy hiện tại để hộp Đổi giáo viên chọn đúng danh sách của cơ sở và chọn sẵn người đang dạy.
           'branch_id', s.branch_id, 'teacher_id', s.teacher_id, 'assistant_id', s.assistant_id)
    into v_session
    from app.class c
    join app.branch b on b.id = s.branch_id
    join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
    join app.catalog_item ty on ty.catalog_code = s.type_catalog and ty.code = s.type_code
    join app.catalog_item st on st.catalog_code = s.status_catalog and st.code = s.status_code
    left join app.user_account t on t.id = s.teacher_id
    left join app.user_account ta on ta.id = s.assistant_id
    left join app.room r on r.id = s.room_id
    left join app.catalog_item cr on cr.catalog_code = s.cancel_reason_catalog and cr.code = s.cancel_reason_code
   where c.id = s.class_id;

  return jsonb_build_object(
    'session', v_session,
    'pending_reason', case when s.status_code = 'DA_CHOT' then app.session_pending_reason(s.id) end,
    'complete_deadline', case when s.status_code = 'DA_CHOT' then app.session_ends_at(s.id) + make_interval(hours => v_hours) end,
    'listed', s.status_code in ('DA_CHOT', 'DONE'),
    -- Luật R-DD-02: hai cột; ô của giáo viên quyết định trạng thái chính thức, cột vận hành chỉ để đối chiếu.
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
               'student_id', st2.id, 'student_code', st2.code, 'full_name', st2.full_name, 'is_trial', sa.is_trial,
               'enrollment_code', e.code, 'ops_status_code', sa.ops_status_code, 'ops_status_name', os.name,
               'teacher_status_code', sa.teacher_status_code, 'teacher_status_name', ts.name,
               'mismatch', sa.ops_status_code is not null and sa.teacher_status_code is not null and sa.ops_status_code <> sa.teacher_status_code)
             order by st2.full_name, st2.id)
        from app.session_attendance sa
        join app.student st2 on st2.id = sa.student_id
        left join app.enrollment e on e.id = sa.enrollment_id
        left join app.catalog_item os on os.catalog_code = sa.ops_status_catalog and os.code = sa.ops_status_code
        left join app.catalog_item ts on ts.catalog_code = sa.teacher_status_catalog and ts.code = sa.teacher_status_code
       where sa.session_id = s.id and sa.is_active), '[]'::jsonb),
    -- Luật R-GIO-02: em không vào danh sách kèm lý do (chưa tới ngày vào lớp, bảo lưu, kết thúc, hết giờ).
    'excluded', coalesce((
      select jsonb_agg(jsonb_build_object('student_id', st2.id, 'student_code', st2.code, 'full_name', st2.full_name, 'reason_code', sa.excluded_reason)
             order by st2.full_name, st2.id)
        from app.session_attendance sa join app.student st2 on st2.id = sa.student_id
       where sa.session_id = s.id and not sa.is_active and sa.excluded_reason is not null), '[]'::jsonb),
    'reviews', coalesce((
      select jsonb_agg(jsonb_build_object('student_id', st2.id, 'full_name', st2.full_name, 'comment', rv.teacher_comment, 'teacher_status_code', sa.teacher_status_code)
             order by st2.full_name, st2.id)
        from app.session_attendance sa
        join app.student st2 on st2.id = sa.student_id
        left join app.session_student_review rv on rv.attendance_id = sa.id
       where sa.session_id = s.id and sa.is_active), '[]'::jsonb));
end;
$$;
