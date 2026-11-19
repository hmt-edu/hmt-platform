# Prompt cho Design: khuôn «Bảng xem trước hàng loạt có phân trang và loại trừ» (KH-08 Lên khối đầu năm học)

Soạn 19/11/2026 (Code E, thẻ E40). Màn KH-08 (`docs/design/ban-do-man-hinh.md`, mức C, Hộp thoại · K08, máy tính, chỉ Admin) chưa có khung: K08 chỉ có tóm tắt, lý do, cảnh báo, lỗi chặn, xác nhận; không có danh sách xem trước hàng loạt.

## Việc cần vẽ
Một hộp thoại lớn (rộng, cao tối đa 80% màn) cho thao tác **Lên khối đầu năm học**: tăng khối thêm 1 cho học sinh đang học khi sang năm học mới.

1. **Đầu hộp:** tiêu đề «Lên khối đầu năm học», ô chọn **Năm học** (ví dụ 2026-2027), dòng tóm tắt đếm: «N học sinh sẽ lên khối, M em loại trừ, K em khối 12 không tăng, J em chưa có khối».
2. **Bảng xem trước** (khuôn bảng K03 thu gọn): mỗi dòng một học sinh, các cột **riêng, không gộp thông tin**: Mã HS · Họ tên · Cơ sở · Khối hiện tại · Khối mới · Lớp đang học · Ghi chú (vd «Khối 12: không tăng», «Chưa có khối»). Ô tick ở đầu dòng **Loại trừ** (mặc định không tick); tick cả trang, bỏ tick cả trang; giữ lựa chọn khi sang trang.
3. **Phân trang máy chủ** (50 dòng mỗi trang, tối đa 100), tìm theo tên hoặc mã, lọc theo cơ sở và khối. Trạng thái đang tải, trống («Không có học sinh đang học»), lỗi mạng có nút Thử lại.
4. **Chân hộp:** cảnh báo không chặn («Thao tác ghi cho từng em vào nhật ký, chỉ chạy một lần mỗi năm học»), ô xác nhận bắt buộc (gõ lại năm học hoặc tick «Tôi đã kiểm danh sách»), nút «Huỷ» và «Lên khối N em» (nút hiện số em, mờ khi N = 0).
5. **Các trạng thái cần có khung:** mặc định, đang tải xem trước, đã loại trừ vài em, lỗi (đã chạy cho năm học này: «Năm học 2026-2027 đã lên khối ngày …»), xác nhận thành công (toast + số em), không có quyền (chỉ Admin).
6. **Điện thoại:** không cần (Quản trị chỉ máy tính).

## Ràng buộc
- Chữ giao diện tiếng Việt; nhãn «Filters», «Group By» giữ tiếng Anh theo khuôn K03 nếu dùng thanh lọc.
- Số liệu trong khung là dữ liệu giả; không chép vào code.
- Dùng token và thành phần của hệ thống HMT (cam #EF6925, nền tối #211C16), không tự chế kiểu hộp thoại mới ngoài K08 và bảng K03.

## Tài liệu liên quan
`docs/design/ban-do-man-hinh.md` dòng KH-08 và CHUNG-20; `app.student.grade` (khối 1 đến 12, migration 65). Phía DB (xem trước phân trang, áp dụng một giao dịch, loại trừ, chặn chạy lại theo năm học) làm sau khi có khung, do Code E.
