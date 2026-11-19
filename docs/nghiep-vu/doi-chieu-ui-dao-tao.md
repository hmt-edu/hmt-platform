# Rà UI nhóm Đào tạo với canvas (Code F, 19/11/2026; thẻ F50)

Cách làm: so tiêu đề cột (`<th>`) của khung canvas 9933/9189 với cấu hình cột từng danh sách (không gồm màn Tạo lớp: Code A đang làm).

| Màn | Canvas | Code | Kết quả |
|---|---|---|---|
| GD-01 Ghi danh | Mã, Học sinh, Gói, Hình thức học, Lớp, Giờ cấp, Đã học, Còn lại, Tình trạng | giống hệt | khớp |
| GD-04 Sổ giờ | Ngày, Loại, Lớp, Buổi, Phiếu thu, Khoản tiền, Người điều chỉnh, Lý do, Giờ +/−, Số dư | có Mã ticket thay cho Khoản tiền | lệch nhỏ, chờ Code A (GD-05) |
| GD-05 Điều chỉnh giờ (hộp) | nút Cộng giờ/Trừ giờ, «Số giờ», «Lý do», đoạn «Hệ thống ghi thêm một dòng mới… Quỹ sau điều chỉnh: a → b giờ… ticket Chuyển phí (R-GD-18)», nút «Xác nhận» | 20/11: đã thêm đoạn giải thích và dòng quỹ sau điều chỉnh (dự kiến, máy chủ quyết). Còn vênh, chưa làm: ô số có dấu thay cho nút Cộng/Trừ, nút «Thêm dòng điều chỉnh» thay «Xác nhận» (đổi cần sửa bài e2e) | gần đúng |
| GD-06 Hàng chờ xếp lớp | Ghi danh, Học sinh, Môn, Hình thức, Lý do chờ, Chờ từ, Xử lý | giống hệt | khớp |
| GD-07 Sắp hết giờ | Học sinh, Lớp, Ghi danh (n), Giờ còn, Hết giờ dự kiến, Hạn gói (dự báo), Tình trạng, **Phiếu tái tục** | thiếu cột Phiếu tái tục | **đã thêm (F51, migration 561)**: mã phiếu tái tục đang mở, bấm mở phiếu; nhãn «Ghi danh (n)» |
| LOP-01 Lớp | Mã lớp, Môn, Khối, Phân loại, Cơ sở, Hình thức học, Lịch học, Giáo viên, Sĩ số, Bắt đầu, Tình trạng duyệt, Vận hành | thứ tự khác, «Khai giảng» ẩn, thiếu Hình thức học | **đã sửa thứ tự và nhãn «Bắt đầu» (hiện mặc định)** trong PR này; «Hình thức học» chưa có dữ liệu ở danh sách lớp (cần hàm trả) |
| BUOI-01 Buổi học | Giờ, Lớp, Cơ sở, Buổi, Loại, Giáo viên, Phòng, Tình trạng, Ghi chú, Xử lý | thêm cột Ngày | khớp (Ngày cần cho danh sách nhiều ngày) |
| BUOI-10 Yêu cầu buổi | Mã, Loại, Học sinh, Lớp, Ngày đề nghị, Người tạo, Tình trạng, Xử lý | giống | khớp |
| BUOI-12 Buổi chưa hoàn tất | Lớp, Buổi, Giờ học, Giáo viên, Hạn hoàn tất, Xử lý | giống | khớp |
| TS-01 Lead, TS-07 Cơ hội | cột riêng Phụ huynh, SĐT, Source type, Source, Medium, Stage, Sub-stage | đã tách (F40, #260) | khớp |
| TS-11 Lịch hẹn | Loại hoạt động, Tiêu đề, Gắn với, Thời gian, Người phụ trách, Trạng thái | thêm cột Cơ sở | khớp (Cơ sở cần cho nhiều cơ sở) |
| TS-16 Phiếu kiểm tra | Mã PKT, Học sinh, Người tạo, Môn, Hình thức, Cấp độ, Ngày giờ test, Cơ sở test, Người phụ trách, GV chấm, Điểm, Trạng thái, Cơ hội gốc, Cơ sở tạo | thiếu Điểm, Cơ hội gốc, Cơ sở tạo | **đã thêm** (PR khác đã gộp bản có liên kết Cơ hội gốc) |
| BUOI-15 Điểm danh trong ngày | Giờ, Lớp (kèm Buổi, phòng), Cơ sở, Giáo viên, Tình trạng buổi, Điểm danh, VH điểm danh, GV điểm danh, Lưu ý, CSKH, Xử lý | thiếu Tình trạng buổi, CSKH, Xử lý; nhãn «Vận hành», «Giáo viên ghi» | **đã sửa (F51, migration 562)**: thêm ba cột, đổi nhãn theo canvas |
| BUOI-11 Điểm danh vận hành | Học sinh, Lớp, Buổi, Tình trạng, Lý do liên hệ, Xử lý | bản dựng dùng thẻ và bảng riêng (màn buổi vắng hôm nay) | chưa so từng cột: cần ảnh chụp bản dựng, giao Tester |

Chưa kiểm được bằng chương trình: bố cục, nút, trạng thái tải/lỗi/trống từng màn (cần ảnh chụp bản dựng; xin Tester chụp theo bảng này).
