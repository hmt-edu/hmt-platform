-- GV-07K (Code 2, 11/11/2026): màn Chấm kiểm tra (nhập điểm buổi Kiểm tra) cho cổng Giáo viên: đọc một lần, lưu một lần (một giao dịch).
-- Luật: R-V2-20 (điểm tổng hoặc 3 nhóm Ghi nhớ, Hiểu, Vận dụng; tổng tự cộng; ô trống là chưa chấm, khác điểm 0), R-GV-04 (em vắng không nhập điểm, không tự nhận 0),
-- R-GV-08 (chỉ buổi của mình), R-GV-13 (không thông tin phụ huynh, học phí). Hàm ghi điểm (set_exam_scores) và nhận xét (set_student_review_note) có từ migration 103.
-- Cấu hình buổi Kiểm tra (phạm vi kiến thức, điểm tối đa, cách nhập) do vận hành đặt (set_exam_config); giáo viên chỉ xem.

-- app.exam_grading_sheet(buổi): dữ liệu màn GV-07K một lần gọi. Ai gọi: người xem được điểm danh của buổi (giáo viên, trợ giảng được phân công, vận hành).
-- Kết quả: session (số buổi, ngày, giờ, mã lớp, môn, tình trạng, loại buổi), exam (phạm vi, điểm tối đa, cách nhập, tối đa 3 nhóm; null nếu chưa đặt),
-- students (mọi em đang trong danh sách buổi: điểm danh, điểm {total, memory, understand, apply, graded}, nhận xét chung, định hướng cải thiện).
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
    'session', jsonb_build_object('session_id', s.id, 'status_code', s.status_code, 'type_code', s.type_code, 'session_no', s.session_no,
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

-- app.save_exam_grading(buổi, điểm, nhận xét): lưu một lần cho cả màn GV-07K, một giao dịch (hoặc lưu hết hoặc không lưu gì).
-- p_scores: [{student_id, total} | {student_id, memory, understand, apply}]; p_notes: [{student_id, comment, improvement}].
-- Các hàm con kiểm quyền (Điểm danh · Sửa, buổi của mình), buổi Đã chốt chưa Done, đúng buổi Kiểm tra, đã đặt cấu hình, em có mặt, điểm trong giới hạn (R-V2-20).
create or replace function app.save_exam_grading(p_session_id uuid, p_scores jsonb, p_notes jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n jsonb;
  v_count integer := 0;
begin
  -- Luôn kiểm buổi (quyền, Đã chốt, đúng loại) dù lô trống.
  perform app.assert_review_writable(p_session_id, true);
  if jsonb_array_length(coalesce(p_scores, '[]'::jsonb)) > 0 then
    v_count := v_count + app.set_exam_scores(p_session_id, p_scores);
  end if;
  for n in select * from jsonb_array_elements(coalesce(p_notes, '[]'::jsonb)) loop
    perform app.set_student_review_note(p_session_id, (n ->> 'student_id')::uuid, n ->> 'comment', n ->> 'improvement');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke execute on function app.exam_grading_sheet(uuid), app.save_exam_grading(uuid, jsonb, jsonb) from public, anon, authenticated;
grant execute on function app.exam_grading_sheet(uuid), app.save_exam_grading(uuid, jsonb, jsonb) to authenticated;
