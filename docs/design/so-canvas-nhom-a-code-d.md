# So canvas nhóm A (Code D, 19/11/2026): màn có khung, chưa kiểm

Cách so: lấy chữ trong khung canvas 9933 (`TC10*`, `TC11*`, `TC17*`) và dò xem có trong mã không; chỗ không khớp đọc tiếp mã. Bỏ qua tên người, số liệu minh hoạ, mục menu.

| Màn | Kết quả | Ghi chú |
|---|---|---|
| TC-10 Danh sách phiếu chi | Đúng | Chữ canvas có trong mã; phần thiếu chỉ là tên người, số mẫu |
| TC-11 Phiếu chi (bản ghi, bảng tính hoàn) | **Lệch** | Canvas có thêm: «Đơn hàng», «Cơ sở thu tiền», **«Hình thức chi», «Tài khoản nhận», «Ngày chi dự kiến»**, cột **«Cách tính»** của bảng tính hoàn (ví dụ «48 giờ × 220.000 đ = 10.560.000 đ, chiết khấu 10%») và thanh tình trạng Nháp, Đã trình, Đã duyệt với nút Duyệt, Từ chối. Mã: tình trạng Chờ chi, Đã chi (một bước kế toán ghi nhận chi), bảng tính hoàn có Khoản và Số tiền, phần cách tính gộp vào tên khoản. Hình thức chi, tài khoản nhận, ngày chi dự kiến chưa có dữ liệu trong `app.payment_voucher` (chỉ có `pay_note`); thanh Nháp, Đã trình, Đã duyệt khác luật hiện hành (R-TIEN-34: phiếu chi sinh từ ticket hoàn đã duyệt, Kế toán ghi nhận chi). Cần anh/Chat chốt: thêm các trường, hay giữ luật hiện hành và nhờ Design sửa khung |
| TC-17 Phiếu thu (bản ghi) | Chưa so (thuộc phiếu thu, lane B/C) | Chữ canvas lệch với mã: «Khoản tiền», «Nơi nhận tiền», «Phân bổ vào đơn», «Dồn trước», «khoá khi rời Nháp», «Admin không duyệt ở bước quản lý» |
