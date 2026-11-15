-- GV-13 Học sinh (hồ sơ rút gọn cho giáo viên): MỘT hàm đọc cho cổng Giáo viên.
-- Luật: R-GV-13 (giáo viên, trợ giảng chỉ thấy lớp, buổi, học sinh được phân công; hồ sơ học sinh cho giáo viên chỉ gồm điểm danh, điểm tiêu chí, BTVN trong lớp
-- của mình, KHÔNG hiện số điện thoại, học phí, thông tin phụ huynh), R-GV-08 (chỉ lớp được phân công), R-GV-09 (trợ giảng như giáo viên),
-- R-GV-02, R-GV-03, R-GV-04 (điểm tiêu chí chỉ tính ô Đã đánh giá, tiêu chí đang bật, em có mặt), R-GV-11 (trạng thái BTVN).
--
-- app.teacher_student_profile(p_class_id, p_student_id) -> jsonb
-- Ai được gọi: giáo viên hoặc trợ giảng được phân công cho lớp (app.is_assigned_to_class) và có quyền xem lớp; lớp không tồn tại, lớp của người khác hoặc em
-- không thuộc lớp này đều trả cùng một lỗi HMT_KHONG_CO_QUYEN (không lộ sự tồn tại). Một lần gọi, không gọi lặp theo từng buổi.
-- Kết quả: {student: {id, code, full_name}, class: {id, code, subject_name}, branch_name,
--           summary: {marked, present, avg_score}, sessions: [{session_id, session_no, session_date, status_code, attendance_code, attendance_name,
--           criteria: [{name, state, score}], homework: {status_code, status_name, score} | null}]}
-- Các buổi: những buổi (không huỷ) của lớp mà em có dòng điểm danh đang hiệu lực; mới nhất trước; tối đa 50 buổi (trần hiển thị).
create or replace function app.teacher_student_profile(p_class_id uuid, p_student_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c app.class;
  st app.student;
begin
  select * into c from app.class where id = p_class_id;
  select * into st from app.student where id = p_student_id;
  -- Luật R-GV-08, R-GV-13: chỉ lớp được phân công cho người gọi, và em phải có mặt trong lớp đó.
  if c.id is null or st.id is null
     or app.permission_scope('CLASS', 'XEM') is null
     or not app.is_assigned_to_class(c.id)
     or not (exists (select from app.session_attendance sa where sa.class_id = c.id and sa.student_id = st.id)
             or exists (select from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                         where ec.class_id = c.id and e.student_id = st.id)) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem học sinh này hoặc học sinh không thuộc lớp của bạn.');
  end if;
  return jsonb_build_object(
    -- Luật R-GV-13: chỉ tên, mã học sinh; không có số điện thoại, học phí, phụ huynh.
    'student', jsonb_build_object('id', st.id, 'code', st.code, 'full_name', st.full_name),
    'class', jsonb_build_object('id', c.id, 'code', c.code,
              'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code)),
    'branch_name', (select b.name from app.branch b where b.id = c.branch_id),
    'summary', jsonb_build_object(
      'marked', (select count(*) from app.session_attendance sa
                  where sa.class_id = c.id and sa.student_id = st.id and sa.is_active and sa.teacher_status_code is not null),
      'present', (select count(*) from app.session_attendance sa
                   where sa.class_id = c.id and sa.student_id = st.id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')),
      -- Luật R-GV-04: chỉ điểm Đã đánh giá, tiêu chí đang bật, em có mặt; không làm tròn.
      'avg_score', (select avg(sc.score)::numeric
                      from app.session_review_score sc
                      join app.session_review_criterion rc on rc.id = sc.session_criterion_id
                      join app.session_attendance sa on sa.id = sc.attendance_id
                     where sa.class_id = c.id and sa.student_id = st.id and rc.enabled and sc.state = 'DA_DANH_GIA'
                       and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON'))),
    'sessions', coalesce((
      select jsonb_agg(row_json order by session_date desc, start_time desc)
        from (
          select s.session_date, s.start_time,
                 jsonb_build_object(
                   'session_id', s.id, 'session_no', s.session_no, 'session_date', s.session_date, 'status_code', s.status_code,
                   'attendance_code', sa.teacher_status_code,
                   'attendance_name', (select ci.name from app.catalog_item ci
                                        where ci.catalog_code = 'ATTENDANCE_STATUS' and ci.code = sa.teacher_status_code),
                   -- Chỉ em có mặt mới có điểm tiêu chí (R-GV-04): em vắng không chấm.
                   'criteria', case when sa.teacher_status_code in ('CO_MAT', 'DI_MUON') then coalesce((
                                 select jsonb_agg(jsonb_build_object('name', rc.name, 'state', sc.state, 'score', sc.score) order by rc.sort_order, rc.id)
                                   from app.session_review_criterion rc
                                   left join app.session_review_score sc on sc.session_criterion_id = rc.id and sc.attendance_id = sa.id
                                  where rc.session_id = s.id and rc.enabled), '[]'::jsonb)
                                else '[]'::jsonb end,
                   -- Luật R-GV-11: trạng thái BTVN của bài giao ở buổi này (có thể chưa chấm).
                   'homework', (select jsonb_build_object('status_code', hr.status_code, 'score', hr.score,
                                  'status_name', (select ci.name from app.catalog_item ci
                                                   where ci.catalog_code = 'HOMEWORK_STATUS' and ci.code = hr.status_code))
                                  from app.homework_result hr where hr.session_id = s.id and hr.student_id = st.id)
                 ) as row_json
            from app.session_attendance sa
            join app.class_session s on s.id = sa.session_id
           where sa.class_id = c.id and sa.student_id = st.id and sa.is_active
             and s.status_code not in ('HUY_CO_PHI', 'HUY_KHONG_PHI', 'DA_THAY')
           order by s.session_date desc, s.start_time desc
           limit 50 -- allow-number: trần số buổi hiện trên một trang hồ sơ (hiển thị, không phải luật nghiệp vụ)
        ) x), '[]'::jsonb));
end;
$$;

revoke execute on function app.teacher_student_profile(uuid, uuid) from public, anon, authenticated;
grant execute on function app.teacher_student_profile(uuid, uuid) to authenticated;
