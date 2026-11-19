# D60: QT-17 Tài khoản phụ huynh, CHUNG-18 Xuất file có nhật ký (kiểm code đã có chưa, 19/11/2026)

## CHUNG-18 Xuất file (có nhật ký)
- **Đã có theo từng danh sách:** 14 hàm DB `export_*` gọi `app.log_export(phân hệ, bộ lọc, số dòng)` (kiểm quyền Xuất của phân hệ, ghi `app.export_log`); Admin xem ở QT-12 tab Xuất file (#?, migration 551). Mọi lần xuất đã có nhật ký.
- **Chưa có:** hộp thoại dùng chung «Chọn cột, phạm vi, định dạng» như bản đồ màn hình CHUNG-18 (K08). Mỗi danh sách hiện xuất CSV cố định các cột của nó (ví dụ `EXPORT_COLUMNS` ở Người dùng).
- **Canvas:** CHUNG-18 thuộc «Mức C, không vẽ» (`Chua_ve.dc.html`): không có khung.
- **Đề xuất (cần anh duyệt):** không làm hộp thoại chung vì chưa có khung và nhật ký đã đủ; giữ xuất theo từng danh sách. Nếu anh muốn chọn cột/định dạng thì nhờ Design vẽ khung K08 rồi làm một hộp thoại dùng chung kèm `log_export`.

## QT-17 Tài khoản phụ huynh (cấp, khoá, đặt lại)
- **Chưa có:** không có màn, không có hàm, không có cột nối tài khoản với phụ huynh (`app.user_account` có `student_code` cho học sinh, không có mã/ID phụ huynh). Mẫu gần nhất: QT-13 Tài khoản học sinh (`quan-tri/tai-khoan-hoc-sinh`, khuôn K03).
- **Canvas:** QT-17 thuộc «Giai đoạn 4 (Đợt 5.6), giai đoạn sau», không có khung. Bản đồ màn hình: «Cấp tài khoản theo mã PH khi mở cổng phụ huynh».
- **Chặn:** cách phụ huynh đăng nhập (CHUNG-23: «cách đăng nhập chốt ở GĐ4») chưa chốt, nên chưa biết tên đăng nhập là gì (mã PH? SĐT? email?), mật khẩu tạm, có tự đổi không. Làm trước sẽ phải sửa. **Dừng theo luật «thiếu khuôn thì DỪNG, báo».**
- **Cần anh chốt trước khi làm:** (1) tên đăng nhập của phụ huynh; (2) mỗi phụ huynh một tài khoản, một tài khoản nhiều con; (3) ai cấp (CSKH, Admin) và theo từng người hay hàng loạt; (4) khung Design cho QT-17 (hoặc dùng nguyên khuôn QT-13).
