-- HT-07 Kết quả học tập (học sinh) và PH-02 Kết quả (phụ huynh): MỘT hàm dùng chung cho hai cổng (kế hoạch A-23-14 mục 3). Chỉ đọc.
-- Quyền: app.portal_require_student (học sinh = chính mình, phụ huynh = con mình, công tắc HOC_TAP), migration 637.

-- app.portal_results(p_student_id)
-- Làm gì: kết quả học tập của một học sinh THEO TỪNG LỚP có điểm danh của em: chuyên cần, BTVN (nếu lớp có), điểm ba nhóm Thái độ, Tiếp thu, Vận dụng theo buổi.
-- Ai gọi: học sinh (chính mình) hoặc phụ huynh (con mình) qua cổng /hoc, /ph.
-- Kết quả: {classes: [{class_id, class_code, subject_name, attendance: {present, total}, homework: {has, done, total, avg_score},
--            sessions: [{session_id, session_no, session_date, thai_do, tiep_thu, van_dung}]}]}
-- Luật:
--  * Chuyên cần (R-DD-02): chỉ tính buổi giáo viên đã điểm danh (ô của giáo viên, không phải ô vận hành); có mặt = CO_MAT hoặc DI_MUON; không tính dòng đã loại khỏi danh sách.
--  * BTVN (R-V2-35): lớp không có dòng kết quả BTVN nào (trừ «Không áp dụng») thì has = false, giao diện ẩn cả phần BTVN. Tỉ lệ làm = số buổi
--    Đã chấm, Làm chưa xong, Nộp sau trên số buổi áp dụng; điểm trung bình lấy từ các buổi có điểm (R-GV-11).
--  * Điểm theo buổi: trung bình các tiêu chí đã đánh giá (DA_DANH_GIA) của từng nhóm THAI_DO, TIEP_THU, VAN_DUNG; nhóm chưa có điểm trả null; em vắng không có dòng điểm.
--  * Số buổi hiện tối đa bằng tham số list_page_size_default mỗi lớp (mới nhất trước); số lớp tối đa list_page_size_max.
create or replace function app.portal_results(p_student_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_session_max integer := app.get_setting_int('list_page_size_default');
  v_class_max integer := app.get_setting_int('list_page_size_max');
  v_classes jsonb;
begin
  -- Luật quyền riêng và công tắc Học tập.
  perform app.portal_require_student(p_student_id);

  select coalesce(jsonb_agg(x.j order by x.class_code), '[]'::jsonb) into v_classes
    from (
      select c.code as class_code,
             jsonb_build_object(
               'class_id', c.id, 'class_code', c.code, 'subject_name', sub.name,
               -- Chuyên cần: buổi giáo viên đã điểm danh.
               'attendance', (select jsonb_build_object(
                                'present', count(*) filter (where a.teacher_status_code in ('CO_MAT', 'DI_MUON')),
                                'total', count(*))
                                from app.session_attendance a
                               where a.student_id = p_student_id and a.class_id = c.id and a.is_active and a.teacher_status_code is not null),
               -- BTVN: lớp không giao thì has = false (R-V2-35).
               'homework', (select jsonb_build_object(
                              'has', count(*) > 0,
                              'done', count(*) filter (where h.status_code in ('DA_CHAM', 'LAM_CHUA_XONG', 'NOP_SAU')),
                              'total', count(*),
                              'avg_score', round(avg(h.score), 1))
                              from app.homework_result h
                              join app.class_session hs on hs.id = h.session_id
                             where h.student_id = p_student_id and hs.class_id = c.id and h.status_code <> 'KHONG_AP_DUNG'),
               -- Điểm theo buổi: mỗi nhóm là trung bình tiêu chí đã đánh giá.
               'sessions', coalesce((select jsonb_agg(s.j order by s.session_date desc, s.session_no desc)
                              from (
                                select cs.session_date, cs.session_no,
                                       jsonb_build_object(
                                         'session_id', cs.id, 'session_no', cs.session_no, 'session_date', cs.session_date,
                                         'thai_do', (select round(avg(sc.score), 1) from app.session_review_score sc
                                                       join app.session_review_criterion cr on cr.id = sc.session_criterion_id
                                                      where sc.attendance_id = a.id and sc.state = 'DA_DANH_GIA' and cr.group_code = 'THAI_DO'),
                                         'tiep_thu', (select round(avg(sc.score), 1) from app.session_review_score sc
                                                       join app.session_review_criterion cr on cr.id = sc.session_criterion_id
                                                      where sc.attendance_id = a.id and sc.state = 'DA_DANH_GIA' and cr.group_code = 'TIEP_THU'),
                                         'van_dung', (select round(avg(sc.score), 1) from app.session_review_score sc
                                                       join app.session_review_criterion cr on cr.id = sc.session_criterion_id
                                                      where sc.attendance_id = a.id and sc.state = 'DA_DANH_GIA' and cr.group_code = 'VAN_DUNG')) as j
                                  from app.session_attendance a
                                  join app.class_session cs on cs.id = a.session_id
                                 where a.student_id = p_student_id and a.class_id = c.id and a.is_active
                                   and a.teacher_status_code in ('CO_MAT', 'DI_MUON')
                                 order by cs.session_date desc, cs.session_no desc
                                 limit v_session_max
                              ) s), '[]'::jsonb)) as j
        from app.class c
        left join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
       where exists (select 1 from app.session_attendance a
                      where a.student_id = p_student_id and a.class_id = c.id and a.is_active and a.teacher_status_code is not null)
       order by c.code
       limit v_class_max
    ) x;
  return jsonb_build_object('classes', v_classes);
end;
$$;
comment on function app.portal_results(uuid) is 'HT-07, PH-02: kết quả học tập của một học sinh theo lớp (chuyên cần, BTVN nếu lớp có, điểm ba nhóm theo buổi); chỉ đọc; quyền theo app.portal_require_student.';

revoke execute on function app.portal_results(uuid) from public, anon;
grant execute on function app.portal_results(uuid) to authenticated;
