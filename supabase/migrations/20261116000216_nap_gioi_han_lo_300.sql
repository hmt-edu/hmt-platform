-- Code B (16/11/2026), PR-3 Nạp dữ liệu, migration 216 (thay migration 164 cũ đã bỏ): hạ số dòng tối đa mỗi lần nạp để mỗi lần gọi hàm nạp xong dưới hạn 8 giây.
-- Lý do (Tester soát #45 và Code B tái hiện lại): vai trò «authenticated» của Supabase có statement_timeout = 8 giây; hạn này bấm giờ cho câu lệnh gọi hàm từ bên ngoài,
-- nên `alter function … set statement_timeout` KHÔNG nới được (migration 164 cũ sai, đã bỏ). Đo 16/11/2026 trên DB local đang tải nặng: 1000 dòng Học sinh mất 5 đến 22 giây
-- (xem trước) và 10 đến 20 giây (nạp thật), Phụ huynh 3,5 đến 10 giây: có thể vượt 8 giây.
-- Cách xử lý: giảm tham số import_max_rows từ 1000 xuống 300 dòng mỗi lần (≈ 6 giây ở mức chậm nhất đã đo, thường 1 đến 3 giây). File lớn chia nhiều file/lần nạp;
-- hàm nạp đã chịu nạp lại (dòng đã nạp thành TRUNG, không ghi đè). Tham số vẫn chỉnh được ở Cài đặt (1 đến 5000); không đổi code, không đổi hàm.
-- Giá trị 300 là lựa chọn an toàn của Code B, chưa có luật: Chat xác nhận hoặc đổi (hoặc chuyển nạp nặng sang Edge Function, CLAUDE.md nguyên tắc 7).
select set_config('hmt.migration', 'on', false);

update app.setting_def set value = '300' where key = 'import_max_rows';

select set_config('hmt.migration', '', false);
