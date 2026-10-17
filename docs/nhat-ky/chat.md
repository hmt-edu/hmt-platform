# Nhật ký Claude Chat (cập nhật 17/10/2026, 18:55)

## Đang làm
- Thiết lập nền tảng phối hợp ba bên qua repo (file này nằm trong PR đó). Anh đã nối GitHub (hmt-vanhanh, chỉ hmt-platform) cho cả ba tài khoản Claude. Anh sắp đổi tài khoản vì hết hạn mức: chat Chat mới đọc file này và `docs/phoi-hop/khoi-dong-chat.md`.

## Đã chốt (chưa vào repo spec)
- Luật `04d` đến `04g` (đang ở `docs/phoi-hop/luat-cho-dua-vao-spec/`): gộp trùng và quyền; mỗi dòng đơn một lớp, một ghi danh, một quỹ giờ; mô hình phụ huynh, học sinh dùng chung; lớp Toán Đại + Hình luân phiên, nhóm lớp, mã cũ.
- Báo giá Toán khối 7+ có hai dòng riêng Đại và Hình (mỗi dòng giờ, giá, chiết khấu riêng); báo giá không chọn học sinh.
- Lịch đóng từng đợt tự sinh từ danh mục "Điều khoản thanh toán" (R-TIEN-07), không nhập tay; tiền phiếu thu tính từ đợt cũ nhất, chỉ để theo dõi công nợ.
- Khuôn in K13 (A4 báo giá, phiếu chi; A5 biên nhận) đã duyệt.
- Phụ huynh không có mã cũ; sửa spec 02 mục "Mã cũ" bỏ `CUST-…`.

## Đang chờ ai
- **Anh Trường:** OK PR #35 (ma trận quyền v3) nếu còn mở; chặn môn theo khối khi tạo lớp (đề xuất chờ duyệt); một phiếu tái tục cho mỗi ghi danh (04e mục 3); xem và sửa canvas P5a; duyệt bảng TRƯỚC / SAU ma trận quyền v4 khi Code gửi.
- **Claude Code:** đưa `04d`–`04g` vào spec 04, spec 02, bản đồ màn hình; thêm danh mục "Điều khoản thanh toán" vào spec 06 (khi anh OK); tạo thư mục `docs/phoi-hop/` và `docs/nhat-ky/` trong PR tài liệu.
- **Claude Design:** P4 xong; P5a xong v6, đang đóng băng, chờ anh sửa BH-03 và TC-07 rồi báo; P5b xong cụm Ghi danh, còn Lớp, Buổi, Tái tục; P5c, P5d chưa bắt đầu. Design cần lưu nguồn lên nhánh `design/luu-nguon-17-10` (xem mục 13 quy trình).

## File và link mới
- Project "HMT - CRM HOÀ MA TOÁN" (tài khoản truongcx.work) giữ bản sao tài liệu; bản đúng là repo. Tài khoản khác không thấy Project này.
- Canvas P4: https://claude.ai/artifact/RkrASNia4wUgbRwXiYRmFY ; canvas P5a (v6): https://claude.ai/artifact/7NZAWMvx8QkYgMArFSkULp ; canvas P5b: xem `design.md`.
- Việc dở nhỏ: bản đồ màn hình ghi nút Xuất cho SA/CS ở BH-01, BH-06, TC-13 (đúng luật: chỉ Trưởng cơ sở, Kế toán, Admin); tìm kiếm KH-01 còn ghi mã PH; prompt `P4-v2` trong Project còn chữ "đã phân bổ" (bản trong repo đã sửa).
