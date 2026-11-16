-- Code B (16/11/2026), PR-3 Nạp dữ liệu, migration 164: nâng giới hạn thời gian cho ba hàm nạp hồ sơ hàng loạt.
-- Lý do (đo 16/11/2026 trên DB local, 1000 dòng giả, máy đang tải nặng): xem trước hoặc nạp 1000 dòng mất 3,5 đến 10 giây
-- (Phụ huynh) và 5 đến 22 giây (Học sinh, 22 giây khi thống kê chưa mới). Vai trò «authenticated» của Supabase có statement_timeout = 8 giây,
-- nên một lô gần mức 1000 dòng (tham số import_max_rows, tối đa 5000) có thể bị cắt giữa chừng với lỗi chung, dù không sai dữ liệu.
-- Cách xử lý: đặt statement_timeout riêng cho đúng ba hàm Admin dùng để nạp; không đổi giới hạn của vai trò (các hàm khác vẫn 8 giây).
-- Đã thử: hàm đặt SET statement_timeout = '30s' chạy được 10 giây dưới vai trò authenticated.
-- Không đổi nội dung hàm, không đổi quyền: chỉ thêm cấu hình hàm.
select set_config('hmt.migration', 'on', false);

-- 120 giây: đủ cho 5000 dòng (trần của import_max_rows) trên máy chậm, vẫn đủ ngắn để không treo kết nối mãi.
alter function app.import_records(text, jsonb, boolean, text) set statement_timeout = '120s';
alter function app.import_training_records(text, jsonb, boolean, text) set statement_timeout = '120s';
alter function app.import_leads(jsonb, boolean, jsonb, text) set statement_timeout = '120s';

select set_config('hmt.migration', '', false);
