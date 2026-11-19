# Rà UI «nhóm A» (có khung canvas): Tuyển sinh, Quản trị, Cấu hình (Code F, 19/11/2026; thẻ F67)

Nguồn: `HOP-THU/MAN-CHUA-KIEM.md` nhóm A (luật anh Trường 21:32). Cách làm: lấy chữ trong khung canvas cùng mã màn, bỏ chữ khung chung (menu, thanh trên), tên người và dữ liệu mẫu, tìm phần còn lại trong `src/`. Chỉ so chữ, chưa so ảnh bản dựng; Tester xem lại «Gần đúng».

| Màn | Chỗ canvas có mà code chưa thấy | Kết quả |
|---|---|---|
| QT-02 Người dùng (đặt lại mật khẩu) | hộp «Đặt lại mật khẩu của <tên>?», câu «Mọi phiên đăng nhập bị thu hồi…», «Chỉ Admin được đặt lại mật khẩu. Thao tác ghi nhật ký (không ghi mật khẩu)» | **gần đúng**: hộp có, câu giải thích khác chữ |
| QT-03 Tạo người dùng, sửa email | «Mỗi email chỉ dùng cho một tài khoản», «Tên đăng nhập giữ nguyên. Việc đổi email ghi nhật ký (email cũ, email mới)», «Email này đã có ở tài khoản …» | **gần đúng**: thiếu ba câu chú thích và báo lỗi trùng email theo chữ canvas |
| CH-03 Bảng giá | trạng thái «Sắp hiệu lực», «Bảng trống», nhãn «Không bán online», «Theo bộ tài liệu», «Giá online (đ/giờ)» | **gần đúng**: có giá online, offline; thiếu nhãn trạng thái và hai nhãn dịch vụ |
| TS-02 Lead (tạo) | «Lead này đã có cơ hội» | **gần đúng**: thiếu một câu chặn |
| TS-03 Lead (tạo mới) | «Chọn source type trước», «Tạo chiến dịch mới», «Hệ thống tự tính sau khi lưu» | **gần đúng**: thiếu chữ hướng dẫn |
| TS-04 Giao lead | không thiếu chữ | khớp |
| TS-06 Lead (bản ghi có cơ hội) | «Lead này đã có cơ hội» | **gần đúng** (như TS-02) |
| TS-08 Cơ hội (bản ghi) | «Môn quan tâm», «Lịch rảnh», «Trường đang học» (code có «Trường học», «Học lực tự đánh giá», «Nhu cầu»), «Sửa ở hồ sơ học sinh», câu mất kết nối | **gần đúng**, canvas vênh luật, làm theo luật: R-CRM-23 ghi «khối và môn không nằm trong danh sách em» nên không có «Môn quan tâm»; luật không có «Lịch rảnh» (không có ở docs/spec 04, 02, 06). Để anh duyệt sau; khi anh chốt thêm thì mở thẻ migration và pgTAP |
| TS-09 Đổi giai đoạn | chữ khớp (phần thiếu là của TS-08) | khớp |
| TS-10 Lịch hẹn (hộp) | chỉ khác dữ liệu mẫu | khớp |
| TS-13 Lịch hẹn của cơ hội | chỉ khác dữ liệu mẫu | khớp |
| TS-15 Tạo phiếu kiểm tra | «Mặc định là người tạo phiếu; nhận lịch hẹn nhắc và theo dõi lịch test.», «Chọn Ngày test và Giờ test để bật nút Tạo phiếu.» | **gần đúng**: thiếu hai câu hướng dẫn |
| TS-17 Phiếu kiểm tra (bản ghi) | «Học sinh bắt đầu làm bài», «Phiếu đánh giá», «Bài làm», «(S cao nhất)» | **gần đúng**: có khối «Kết quả», thiếu «Phiếu đánh giá» và «Bài làm»; cần xem ảnh |

Chưa rà (cần xem ảnh hoặc quá nhiều khung): KH-01..07, BH-02, BH-03, BH-09, TC-03, TC-07, CH-05, CH-06 (khung canvas không tách được chữ), TC-10, TC-11, TC-17, GD-05, TT-02, TT-03.
