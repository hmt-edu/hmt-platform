-- A25 PR2: đưa form nhận xét (review_form) của buổi ra ba hàm giao diện giáo viên đọc, để giao diện chọn form 9 tiêu chí hay form điểm theo review_form
-- thay vì so sánh mã loại buổi KIEM_TRA (có thêm Kiểm tra giữa kỳ, cuối kỳ). Chỉ thêm khoá 'review_form' vào kết quả; mọi luật giữ nguyên bản mới nhất.

-- session_overview: bản ở 20261119000305_a25_loai_buoi_form_nhan_xet.sql.
create or replace function app.session_overview(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  c app.class;
  v_total integer;
  v_marked integer;
  v_homework text;
  v_lines jsonb;
  v_scored integer;
  v_exam jsonb;
  v_present integer;
  v_graded integer;
  v_missing jsonb;
  v_hw jsonb;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select * into c from app.class where id = s.class_id;
  select count(*), count(teacher_status_code) into v_total, v_marked
    from app.session_attendance where session_id = s.id and is_active;
  select coalesce(jsonb_agg(l.line_text order by l.sort_order), '[]'::jsonb) into v_lines
    from app.session_content_line l where l.session_id = s.id and l.is_active;
  select homework_text into v_homework from app.session_content where session_id = s.id;
  -- Buổi Kiểm tra: phạm vi kiến thức, điểm tối đa, cách nhập điểm do vận hành đặt (set_exam_config); giáo viên chỉ xem. Chưa đặt thì null.
  select jsonb_build_object('scope_text', e.scope_text, 'max_score', e.max_score, 'entry_mode', e.entry_mode,
                            'max_memory', e.max_memory, 'max_understand', e.max_understand, 'max_apply', e.max_apply)
    into v_exam from app.session_exam e where e.session_id = s.id;
  -- Số ô nhận xét đã chấm: màn GV-06 báo "sửa nội dung sau khi đã chấm" (điểm 9 tiêu chí không đổi khi sửa dòng nội dung, Q-245).
  select count(*) into v_scored from app.session_review_score where session_id = s.id and state <> 'CHUA_DANH_GIA';
  -- Bước chấm của GV-04 (R-GV-04, R-V2-20): em có mặt (Có mặt, Đi muộn) đã chấm đủ. Buổi thường: mọi tiêu chí đang bật đều có điểm hoặc trạng thái khác "Chưa đánh giá".
  -- Buổi Kiểm tra: đã chấm điểm. Kèm tên tối đa 10 em còn thiếu (giáo viên được thấy tên em trong lớp mình, R-GV-13).
  with present as (
    select sa.id, st.full_name,
           case when app.session_is_exam(s) then exists (select from app.exam_score es where es.attendance_id = sa.id and es.graded)
                else exists (select from app.session_review_criterion rc where rc.session_id = sa.session_id and rc.enabled)
                     and not exists (select from app.session_review_criterion rc
                                      where rc.session_id = sa.session_id and rc.enabled
                                        and not exists (select from app.session_review_score sc
                                                         where sc.attendance_id = sa.id and sc.session_criterion_id = rc.id and sc.state <> 'CHUA_DANH_GIA')) end as complete
      from app.session_attendance sa join app.student st on st.id = sa.student_id
     where sa.session_id = s.id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
  )
  select count(*), count(*) filter (where complete),
         coalesce((select jsonb_agg(m.full_name) from (select full_name from present where not complete order by full_name limit 10) m), '[]'::jsonb) -- allow-number: tối đa 10 tên em còn thiếu hiện trên màn
    into v_present, v_graded, v_missing from present;
  -- Bước chấm BTVN buổi trước (GV-04, GV-08, R-V2-35, R-GV-11): tiến độ do app.homework_progress tính (DAU_LOP, KHONG_GIAO: bỏ qua, không chặn).
  v_hw := app.homework_progress(s.id);
  return jsonb_build_object(
    'session_id', s.id, 'status_code', s.status_code, 'type_code', s.type_code, 'review_form', s.review_form,
    'type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SESSION_TYPE' and ci.code = s.type_code),
    'class_code', c.code,
    'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
    'session_no', s.session_no, 'session_date', s.session_date, 'start_time', s.start_time, 'end_time', s.end_time,
    'attendance_total', v_total, 'attendance_marked', v_marked,
    'content_lines', jsonb_array_length(v_lines), 'has_content', jsonb_array_length(v_lines) > 0,
    'lines', v_lines, 'homework_text', v_homework, 'review_scored', v_scored, 'exam', v_exam,
    'grading_present', v_present, 'grading_done', v_graded, 'grading_missing', v_missing, 'prev_homework_state', v_hw ->> 'state', 'homework_present', (v_hw ->> 'present')::integer, 'homework_done', (v_hw ->> 'done')::integer,
    'homework_missing', v_hw -> 'missing', 'prev_session_no', (v_hw ->> 'prev_session_no')::integer,
    -- Số phiên bản để chặn ghi đè (Q-243): giao diện gửi lại giá trị này khi lưu; 0 = chưa có nội dung nào.
    'content_version', coalesce((select sc.version from app.session_content sc where sc.session_id = s.id), 0),
    'deadline_at', app.session_ends_at(s.id) + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', s.branch_id)::integer),
    'pending_reason', case when s.status_code = 'DONE' then null else app.session_pending_reason(s.id) end,
    -- Dấu Đúng hạn/Trễ hạn do hệ thống đóng lúc Done (R-GV-05); buổi chưa Done hoặc Done trước khi có cột thì null.
    'completion', case when s.completion_stamped_at is null then null
                       else jsonb_build_object('late', s.completion_late, 'late_hours', s.completion_late_hours, 'stamped_at', s.completion_stamped_at) end);
end;
$$;

-- review_grading_sheet: bản ở 20261111000121_gv08_cham_btvn.sql.
create or replace function app.review_grading_sheet(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  c app.class;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select * into c from app.class where id = s.class_id;
  return jsonb_build_object(
    'session', jsonb_build_object('session_id', s.id, 'status_code', s.status_code, 'type_code', s.type_code, 'review_form', s.review_form, 'session_no', s.session_no,
                                  'session_date', s.session_date, 'start_time', s.start_time, 'end_time', s.end_time, 'class_code', c.code,
                                  'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code)),
    'criteria', app.session_review_sheet(s.id),
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
               'student_id', sa.student_id, 'full_name', st.full_name, 'attendance_code', sa.teacher_status_code,
               'attendance_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'ATTENDANCE_STATUS' and ci.code = sa.teacher_status_code),
               'scores', coalesce((select jsonb_object_agg(rc.criterion_id::text, jsonb_build_object('state', sc.state, 'score', sc.score))
                                     from app.session_review_score sc join app.session_review_criterion rc on rc.id = sc.session_criterion_id
                                    where sc.attendance_id = sa.id), '{}'::jsonb),
               'comment', sr.teacher_comment, 'improvement', sr.improvement_note,
               'average', app.review_average(sa.id))
             order by st.full_name)
        from app.session_attendance sa join app.student st on st.id = sa.student_id
        left join app.session_student_review sr on sr.attendance_id = sa.id
       where sa.session_id = s.id and sa.is_active), '[]'::jsonb));
end;
$$;

-- exam_grading_sheet: bản ở 20261111000124_gv07k_cham_kiem_tra.sql.
create or replace function app.exam_grading_sheet(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  c app.class;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select * into c from app.class where id = s.class_id;
  return jsonb_build_object(
    'session', jsonb_build_object('session_id', s.id, 'status_code', s.status_code, 'type_code', s.type_code, 'review_form', s.review_form, 'session_no', s.session_no,
                                  'session_date', s.session_date, 'start_time', s.start_time, 'end_time', s.end_time, 'class_code', c.code,
                                  'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code)),
    'exam', (select jsonb_build_object('scope_text', e.scope_text, 'max_score', e.max_score, 'entry_mode', e.entry_mode,
                                       'max_memory', e.max_memory, 'max_understand', e.max_understand, 'max_apply', e.max_apply)
               from app.session_exam e where e.session_id = s.id),
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
               'student_id', sa.student_id, 'full_name', st.full_name, 'attendance_code', sa.teacher_status_code,
               'attendance_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'ATTENDANCE_STATUS' and ci.code = sa.teacher_status_code),
               'score', case when es.attendance_id is null then null
                             else jsonb_build_object('total', es.total_score, 'memory', es.memory_score, 'understand', es.understand_score,
                                                     'apply', es.apply_score, 'graded', es.graded) end,
               'comment', sr.teacher_comment, 'improvement', sr.improvement_note)
             order by st.full_name)
        from app.session_attendance sa join app.student st on st.id = sa.student_id
        left join app.exam_score es on es.attendance_id = sa.id
        left join app.session_student_review sr on sr.attendance_id = sa.id
       where sa.session_id = s.id and sa.is_active), '[]'::jsonb));
end;
$$;
