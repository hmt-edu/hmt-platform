# So canvas nhóm A (Code D, 19/11/2026): màn có khung, chưa kiểm

Cách so: lấy chữ trong khung canvas 9933 (`TC10*`, `TC11*`, `TC17*`) và dò xem có trong mã không; chỗ không khớp đọc tiếp mã. Bỏ qua tên người, số liệu minh hoạ, mục menu.

| Màn | Kết quả | Ghi chú |
|---|---|---|
| TC-10 Danh sách phiếu chi | Đúng | Chữ canvas có trong mã; phần thiếu chỉ là tên người, số mẫu |
| TC-11 Phiếu chi (bản ghi, bảng tính hoàn) | **Lệch** | Canvas có thêm: «Đơn hàng», «Cơ sở thu tiền», **«Hình thức chi», «Tài khoản nhận», «Ngày chi dự kiến»**, cột **«Cách tính»** của bảng tính hoàn (ví dụ «48 giờ × 220.000 đ = 10.560.000 đ, chiết khấu 10%») và thanh tình trạng Nháp, Đã trình, Đã duyệt với nút Duyệt, Từ chối. Mã: tình trạng Chờ chi, Đã chi (một bước kế toán ghi nhận chi), bảng tính hoàn có Khoản và Số tiền, phần cách tính gộp vào tên khoản. Hình thức chi, tài khoản nhận, ngày chi dự kiến chưa có dữ liệu trong `app.payment_voucher` (chỉ có `pay_note`); thanh Nháp, Đã trình, Đã duyệt khác luật hiện hành (R-TIEN-34: phiếu chi sinh từ ticket hoàn đã duyệt, Kế toán ghi nhận chi). Cần anh/Chat chốt: thêm các trường, hay giữ luật hiện hành và nhờ Design sửa khung |
| TC-17 Phiếu thu (bản ghi) | Chưa so (thuộc phiếu thu, lane B/C) | Chữ canvas lệch với mã: «Khoản tiền», «Nơi nhận tiền», «Phân bổ vào đơn», «Dồn trước», «khoá khi rời Nháp», «Admin không duyệt ở bước quản lý» |
| TC-13 Công nợ | Đúng | Chữ canvas có trong mã; phần thiếu chỉ là tên và số mẫu |
| QT-02 Người dùng (hành động đặt lại mật khẩu) | Đúng | Đã làm #172; chữ thiếu chỉ là tên mẫu |
| QT-03 Tạo người dùng, Sửa email | Gần đúng | Thiếu hai dòng gợi ý: nút «Thêm vai trò» và «Được chọn nhiều vai trò»; thông báo trùng email, trùng tên đăng nhập của canvas («Email này đã có ở tài khoản …», «Tên đăng nhập này đã có người dùng (…)») khác chữ máy chủ trả. Việc nhỏ: chỉnh chữ biểu mẫu |
| CH-03 Bảng giá | Khác có chủ đích | Canvas dc47 vẽ «bản bảng giá có ngày hiệu lực» (Sắp hiệu lực, So sánh với bản trước, Sao chép từ bản 2); mã làm bảng giá theo gói (anh chốt 06/11). Không sửa |
| TC-03 Đơn hàng (bản ghi), TC-07 Phiếu thu (bản in) | Chưa so (lane B, C) | Chữ canvas có phần không có trong mã (khối «Tiền về các dòng đơn», «Bằng chữ», «Khổ giấy», «Lịch đóng tiền từng đợt»…): lane phụ trách rà |
