-- GV-11 (Code 3, 13/11/2026): dữ liệu đọc cho màn Chi tiết lớp của giáo viên (phiếu dieu-phoi-kit#264). CHỈ THÊM MỘT HÀM ĐỌC, không bảng, không đổi RLS.
-- Luật: R-GV-08 (chỉ lớp được phân công), R-GV-09 (trợ giảng như giáo viên), R-GV-13 (không thông tin phụ huynh, học phí), R-GV-03 (điểm không làm tròn trong DB),
-- R-GV-02 (ô trống không phải điểm 0), R-GV-04 (em đổi sang không có mặt thì điểm giữ nhưng không tính), R-GV-05 (hạn hoàn tất buổi).

-- app.teacher_class_overview(lớp): một lần đọc cho cả bốn tab của GV-11.
-- Ai gọi: giáo viên hoặc trợ giảng được phân công lớp (khung giờ hoặc buổi). Người khác: lỗi HMT_KHONG_CO_QUYEN.
-- Kết quả jsonb:
--   class: thông tin lớp (mã, môn, phân loại, trình độ, tổng số buổi).
--   slots: lịch học cố định (thứ, giờ, phòng, giáo viên, trợ giảng).
--   students: em đang xếp lớp (tên, mã); attendance_present / attendance_marked = số buổi có mặt hoặc đi muộn / số buổi đã được điểm danh (trạng thái của giáo viên, R-DD-02);
--             avg_score = trung bình mọi điểm Đã đánh giá ở buổi em có mặt (tiêu chí đang bật), null nếu chưa có điểm, KHÔNG làm tròn (R-GV-03).
--   sessions: tối đa 100 buổi mới nhất (không tính buổi đã bị thay): ngày, giờ, trạng thái, loại, hạn hoàn tất, nhãn đúng hạn/trễ hạn, BTVN giao ở buổi (null = không giao, R-V2-35).
-- Nhãn timeliness (quyết định Chat 13/11, dieu-phoi-kit#260): buổi DONE → null (không nhãn: hệ thống chưa lưu thời điểm chuyển Done, ghi cột đó để SAU 17/11);
--   buổi chưa Done (Nháp, Đã chốt) mà hạn hoàn tất đã qua → 'TRE_HAN'; còn lại null. Không dùng updated_at.
create or replace function app.teacher_class_overview(p_class_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c app.class;
  v_hours integer;
  v_result jsonb;
begin
  select * into c from app.class where id = p_class_id;
  -- Luật R-GV-08: chỉ lớp được phân công cho người gọi (lớp không tồn tại cũng trả cùng một lỗi, không lộ lớp của người khác).
  if c.id is null or app.permission_scope('CLASS', 'XEM') is null or not app.is_assigned_to_class(c.id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lớp này hoặc lớp không tồn tại.');
  end if;
  v_hours := app.get_setting_int('teacher_session_complete_hours', c.branch_id)::integer;
  select jsonb_build_object(
    'class', jsonb_build_object(
      'id', c.id, 'code', c.code, 'total_sessions', c.total_sessions,
      'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
      'class_type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_TYPE' and ci.code = c.class_type_code),
      'level_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'LEVEL' and ci.code = c.level_code)),
    -- Luật R-GV-13: chỉ tên giáo viên, trợ giảng, phòng; không có thông tin phụ huynh.
    'slots', coalesce((select jsonb_agg(jsonb_build_object(
                'weekday', sl.weekday, 'start_time', sl.start_time, 'end_time', sl.end_time,
                'room_name', (select r.name from app.room r where r.id = sl.room_id),
                'teacher_name', app.staff_display_name(sl.teacher_id), 'assistant_name', app.staff_display_name(sl.assistant_id))
                order by sl.weekday, sl.start_time)
                from app.class_slot sl where sl.class_id = c.id and sl.is_active), '[]'::jsonb),
    -- Luật R-GV-13: học sinh chỉ gồm tên, mã, điểm danh, điểm tiêu chí.
    'students', coalesce((select jsonb_agg(jsonb_build_object(
                'student_id', st.id, 'student_code', st.code, 'full_name', st.full_name,
                'attendance_marked', (select count(*) from app.session_attendance sa
                                       where sa.class_id = c.id and sa.student_id = st.id and sa.is_active and sa.teacher_status_code is not null),
                'attendance_present', (select count(*) from app.session_attendance sa
                                        where sa.class_id = c.id and sa.student_id = st.id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')),
                -- Luật R-GV-02, R-GV-03, R-GV-04: chỉ điểm Đã đánh giá, tiêu chí đang bật, em có mặt; không làm tròn.
                'avg_score', (select avg(sc.score)::numeric
                                from app.session_review_score sc
                                join app.session_review_criterion rc on rc.id = sc.session_criterion_id
                                join app.session_attendance sa on sa.id = sc.attendance_id
                               where sa.class_id = c.id and sa.student_id = st.id and rc.enabled and sc.state = 'DA_DANH_GIA'
                                 and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')))
                order by st.full_name, st.id)
                from (select distinct e.student_id from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                       where ec.class_id = c.id and ec.end_date is null) x
                join app.student st on st.id = x.student_id), '[]'::jsonb),
    'sessions', coalesce((select jsonb_agg(jsonb_build_object(
                'id', y.id, 'session_no', y.session_no, 'session_date', y.session_date, 'start_time', y.start_time, 'end_time', y.end_time,
                'status_code', y.status_code, 'type_code', y.type_code,
                'type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SESSION_TYPE' and ci.code = y.type_code),
                'deadline_at', y.deadline_at,
                -- Buổi DONE: null (không dùng updated_at). Chỉ buổi chưa Done mà quá hạn mới có nhãn.
                'timeliness', case when y.status_code in ('NHAP', 'DA_CHOT') and y.deadline_at < now() then 'TRE_HAN' else null end,
                'homework_text', (select sc2.homework_text from app.session_content sc2 where sc2.session_id = y.id))
                order by y.session_date desc, y.start_time desc)
                from (select s.*, app.session_ends_at(s.id) + make_interval(hours => v_hours) as deadline_at
                        from app.class_session s where s.class_id = c.id and s.status_code <> 'DA_THAY'
                       order by s.session_date desc, s.start_time desc limit 100) y), '[]'::jsonb)) -- allow-number: tối đa 100 buổi hiện trên màn lớp (như hồ sơ lớp)
    into v_result;
  return v_result;
end;
$$;

revoke execute on function app.teacher_class_overview(uuid) from public, anon, authenticated;
grant execute on function app.teacher_class_overview(uuid) to authenticated;
