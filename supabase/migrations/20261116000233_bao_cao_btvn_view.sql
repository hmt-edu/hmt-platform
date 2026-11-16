-- Migration 233 (Code D, 16/11/2026): view báo cáo BTVN BC-07 (R-GV-12), schema `report`, security_invoker.
-- Hai chỉ số TÁCH RIÊNG, không gộp «Không làm» thành điểm 0 (R-GV-12):
--   Tỉ lệ làm bài = (Đã chấm + Làm chưa xong) ÷ số bài phải làm; số bài phải làm không tính «Không áp dụng»;
--   «Nộp sau» chưa tính (cả tử lẫn mẫu) tới khi cập nhật thành trạng thái cuối.
--   Điểm BTVN trung bình = trung bình điểm các bài Đã chấm và Làm chưa xong.
-- Mỗi dòng gộp theo (cơ sở, lớp, giáo viên của buổi giao bài, học sinh, tháng của buổi giao). Gộp tiếp theo lớp, giáo viên, cơ sở ở người đọc
-- bằng cách cộng các cột đếm (không lấy trung bình của tỉ lệ). Chỉ đọc; RLS bảng gốc áp theo người đọc (Chat chốt 16/11: không tạo vai trò Looker).

create view report.homework_summary with (security_invoker = true) as
select h.branch_id, s.class_id, s.teacher_id, h.student_id,
       (s.session_date - extract(day from s.session_date)::int + 1) as month_start,
       count(*) filter (where h.status_code in ('DA_CHAM', 'LAM_CHUA_XONG', 'KHONG_LAM')) as required_count,
       count(*) filter (where h.status_code in ('DA_CHAM', 'LAM_CHUA_XONG')) as done_count,
       count(*) filter (where h.status_code = 'KHONG_LAM') as not_done_count,
       count(*) filter (where h.status_code = 'NOP_SAU') as late_pending_count,
       count(*) filter (where h.status_code = 'KHONG_AP_DUNG') as not_applicable_count,
       coalesce(sum(h.score) filter (where h.status_code in ('DA_CHAM', 'LAM_CHUA_XONG')), 0) as score_sum,
       count(h.score) filter (where h.status_code in ('DA_CHAM', 'LAM_CHUA_XONG')) as score_count,
       -- Tỉ lệ làm bài và điểm trung bình: trống khi không có mẫu (không bịa 0).
       round(100.0 * count(*) filter (where h.status_code in ('DA_CHAM', 'LAM_CHUA_XONG'))
             / nullif(count(*) filter (where h.status_code in ('DA_CHAM', 'LAM_CHUA_XONG', 'KHONG_LAM')), 0), 1) as completion_rate_percent, -- allow-number: đổi sang phần trăm, làm tròn 1 chữ số
       round(avg(h.score) filter (where h.status_code in ('DA_CHAM', 'LAM_CHUA_XONG')), 2) as avg_score -- allow-number: làm tròn 2 chữ số thập phân của điểm
  from app.homework_result h
  join app.class_session s on s.id = h.session_id
 group by h.branch_id, s.class_id, s.teacher_id, h.student_id, (s.session_date - extract(day from s.session_date)::int + 1);
comment on view report.homework_summary is 'BC-07 (R-GV-12): số bài phải làm, đã làm, không làm, nộp sau chờ, điểm trung bình tách riêng tỉ lệ làm bài. Gộp tiếp bằng cách cộng các cột đếm.';

revoke all on report.homework_summary from public, anon, authenticated;
grant select on report.homework_summary to authenticated;
