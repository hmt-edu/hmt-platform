-- Code D (24/11/2026), thẻ D-23-38 (1): kênh tiếp nhận «Phụ huynh không đồng ý» là kênh hệ thống (do app.ph_reject_proposal ghi, migration 643),
-- không cho chọn tay ở màn Tạo ticket (CS-01).
-- Làm gì: đặt cột applies_to của mục này là {HE_THONG}. Màn Tạo ticket chỉ liệt kê kênh để trống applies_to hoặc có TICKET_TAY, nên mục này biến mất
-- khỏi ô chọn; ticket cũ vẫn hiện tên kênh (tên tra theo mã, không lọc). Các kênh khác để trống applies_to, không đổi.
-- Không tạo bảng, không đổi hàm. Chỉ mục: không cần (cập nhật một dòng theo khoá catalog_code + code đã có chỉ mục duy nhất).
select set_config('hmt.migration', 'on', false);

update app.catalog_item
   set applies_to = '{HE_THONG}'
 where catalog_code = 'TICKET_CHANNEL' and code = 'PH_KHONG_DONG_Y';
