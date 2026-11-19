# Rà UI nhóm Đào tạo với canvas (Code F, 19/11/2026; thẻ F50)

Cách làm: so tiêu đề cột (`<th>`) của khung canvas 9933/9189 với cấu hình cột từng danh sách (không gồm màn Tạo lớp: Code A đang làm).

| Màn | Canvas | Code | Kết quả |
|---|---|---|---|
| GD-01 Ghi danh | Mã, Học sinh, Gói, Hình thức học, Lớp, Giờ cấp, Đã học, Còn lại, Tình trạng | giống hệt | khớp |
| GD-04 Sổ giờ | Ngày, Loại, Lớp, Buổi, Phiếu thu, Khoản tiền, Người điều chỉnh, Lý do, Giờ +/−, Số dư | có Mã ticket thay cho Khoản tiền | lệch nhỏ, chờ Code A (GD-05) |
| GD-06 Hàng chờ xếp lớp | Ghi danh, Học sinh, Môn, Hình thức, Lý do chờ, Chờ từ, Xử lý | giống hệt | khớp |
| GD-07 Sắp hết giờ | Học sinh, Lớp, Ghi danh (n), Giờ còn, Hết giờ dự kiến, Hạn gói (dự báo), Tình trạng, **Phiếu tái tục** | thiếu cột Phiếu tái tục; cột «Ghi danh» liệt kê mã | **lệch**: thêm cột cần hàm DB trả mã phiếu tái tục đang mở (TT-A đã có bảng); xin Chat giao thẻ |
| LOP-01 Lớp | Mã lớp, Môn, Khối, Phân loại, Cơ sở, Hình thức học, Lịch học, Giáo viên, Sĩ số, Bắt đầu, Tình trạng duyệt, Vận hành | thứ tự khác, «Khai giảng» ẩn, thiếu Hình thức học | **đã sửa thứ tự và nhãn «Bắt đầu» (hiện mặc định)** trong PR này; «Hình thức học» chưa có dữ liệu ở danh sách lớp (cần hàm trả) |
| BUOI-01 Buổi học | Giờ, Lớp, Cơ sở, Buổi, Loại, Giáo viên, Phòng, Tình trạng, Ghi chú, Xử lý | thêm cột Ngày | khớp (Ngày cần cho danh sách nhiều ngày) |
| BUOI-10 Yêu cầu buổi | Mã, Loại, Học sinh, Lớp, Ngày đề nghị, Người tạo, Tình trạng, Xử lý | giống | khớp |
| BUOI-12 Buổi chưa hoàn tất | Lớp, Buổi, Giờ học, Giáo viên, Hạn hoàn tất, Xử lý | giống | khớp |
| TS-01 Lead, TS-07 Cơ hội | cột riêng Phụ huynh, SĐT, Source type, Source, Medium, Stage, Sub-stage | đã tách (F40, #260) | khớp |
| TS-11 Lịch hẹn | Loại hoạt động, Tiêu đề, Gắn với, Thời gian, Người phụ trách, Trạng thái | thêm cột Cơ sở | khớp (Cơ sở cần cho nhiều cơ sở) |
| TS-16 Phiếu kiểm tra | Mã PKT, Học sinh, Người tạo, Môn, Hình thức, Cấp độ, Ngày giờ test, Cơ sở test, Người phụ trách, GV chấm, Điểm, Trạng thái, Cơ hội gốc, Cơ sở tạo | thiếu Điểm, Cơ hội gốc, Cơ sở tạo | **lệch**: ba cột thiếu; Điểm cần dữ liệu từ hàm; xin Chat giao thẻ |
| BUOI-11, BUOI-15 | BUOI-11: Học sinh, Lớp, Buổi, Tình trạng, Lý do liên hệ, Xử lý; BUOI-15: Ngày, Giờ, Lớp, Cơ sở, Giáo viên, Tình trạng buổi, Điểm danh, … | bản dựng dùng thẻ và bảng riêng (không K10) | chưa so từng cột: cần ảnh chụp bản dựng, giao Tester |

Chưa kiểm được bằng chương trình: bố cục, nút, trạng thái tải/lỗi/trống từng màn (cần ảnh chụp bản dựng; xin Tester chụp theo bảng này).
