-- Q-262 (Code 2, 10/11/2026): bật công tắc tính năng VAN_HANH_LOP (Vận hành lớp: ghi danh, lớp, buổi, điểm danh) cho cơ sở CS5.
-- Lý do: hàm nạp dữ liệu đào tạo (app.import_training_records) kiểm công tắc của cơ sở trong file; CS5 chạy trước. Nạp 17/11/2026.
-- Cờ lưu ở bảng app.feature_flag (phân hệ × cơ sở). Migration này áp lên MỌI môi trường nó được áp tới: staging khi gộp vào main,
-- bản chạy thật khi anh Trường chạy workflow bản chạy thật. Chỉ bật, chạy lại không lỗi và không nhân đôi dòng.
-- Cơ sở khác KHÔNG bật ở đây; thêm sau khi anh Trường xác nhận cơ sở đó có trong file nạp.
-- Chạy sau migration 109 (GV-06).
--
-- Gộp thêm (Chat duyệt 10/11, Q-198): đặt tham số chung session_done_requires_review = Tắt cho giai đoạn đầu (staging và bản chạy thật).
-- Tắt là GIÁ TRỊ CHUNG: muốn Bật lại phải có migration mới (màn Cài đặt QT-09 làm sau 17/11). Tắt: buổi Done khi giáo viên đã điểm danh xong
-- và (buổi thường) có ít nhất một dòng nội dung buổi (Q-231); giờ vẫn trừ.
insert into app.feature_flag (module_code, branch_id, enabled)
select 'VAN_HANH_LOP', b.id, true
  from app.branch b
 where b.code = 'CS5'
on conflict (module_code, branch_id) do update set enabled = true;

-- Q-198: tham số chung Done buổi cần nhận xét hoặc điểm = Tắt (giá trị chung; không đặt ghi đè theo cơ sở). Chạy lại không lỗi.
update app.setting_def set value = 'false' where key = 'session_done_requires_review';
