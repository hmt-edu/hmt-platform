# CH-09 Điều khoản thanh toán (không migration)

Trang `/crm/cau-hinh/dieu-khoan-thanh-toan` (máy tính), canvas 9933 khung `CH09_chinh`, `CH09_loi`. Luật R-TIEN-07 (lịch đóng tiền từng đợt để theo dõi công nợ, không chặn học).
Danh sách điều khoản bên trái (tên, tình trạng, cách chia, bản, ngày hiệu lực), các đợt của điều khoản đang chọn bên phải. Hộp Thêm điều khoản: tên, hiệu lực từ, bảng đợt (đợt 1 chọn % hoặc số tiền cố định; các đợt sau là %), kiểm tổng % trước khi gửi.
Đọc `app.payment_term` kèm `payment_term_installment` (một lần gọi); ghi qua `app.create_payment_term` (Cấu hình bán hàng · Tạo) và `app.set_config_active('PAYMENT_TERM', …)` (Cấu hình bán hàng · Sửa). Điều khoản đã tạo KHÔNG sửa: «Tạo bản mới» dùng lại mã cũ, version + 1; đơn cũ giữ lịch đã sinh.
Mã điều khoản sinh từ tên (hoa, không dấu, gạch dưới); bản mới của điều khoản cũ giữ mã cũ.
**Vênh nhỏ với canvas (làm theo luật DB):** canvas ghi các đợt sau đợt 1 luôn là «% của phần còn lại sau đợt 1». DB (`payment_term_amounts`): đợt 1 là số tiền cố định thì các đợt sau chia phần còn lại; toàn % thì mọi đợt chia theo tổng đơn. Màn ghi nhãn đúng theo DB. Số trong khung canvas là số mẫu, không dùng.
**Chưa làm:** nút «Lịch sử thay đổi» (Nhật ký QT-11 chưa dựng): không hiện nút.
