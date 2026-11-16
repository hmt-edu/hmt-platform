# CH-04 Chính sách chiết khấu và quà tặng (không migration)

Trang `/crm/cau-hinh/chiet-khau` (máy tính), canvas 9933 khung `CH04_chinh`, `CH04_loi`. Luật R-TIEN-29 (chiết khấu: % hoặc giờ tặng, cộng dồn, có trần), R-TIEN-30 (quà tặng giá 0 đ, không vào trần), R-TIEN-14 (Ngừng thì không hiện ở chỗ chọn mới, đơn cũ giữ giá trị đã chụp, không xoá), R-TIEN-36.
Hai tab Chiết khấu và Quà tặng; bảng (tên, kiểu hoặc loại quà, mức tối đa, hiệu lực, nhóm gói, cơ sở, cần duyệt, trạng thái), hộp Thêm và Sửa, Ngừng và Dùng lại. Đọc `app.discount_policy`, `app.gift_policy` (kèm gói quà), danh mục `PACKAGE_TYPE`; ghi qua `app.save_discount_policy`, `app.save_gift_policy`, `app.set_config_active` (quyền Cấu hình bán hàng, DB kiểm).
Mã chính sách sinh từ tên; sửa không đổi mã. Trạng thái theo ngày giờ Việt Nam: Đang áp dụng, Chưa tới hạn, Hết hạn, Ngừng.
Chính sách «Ưu đãi linh hoạt» (hệ thống, R-V2-45) hiện nhãn Hệ thống, không có nút Sửa, Ngừng; hạn mức đổi ở Tham số nghiệp vụ.

**Chỗ vênh canvas (làm theo luật và DB, ghi ở PR):**
- DB chỉ có kiểu % và Giờ tặng; không có kiểu «Số tiền cố định» như khung (R-TIEN-29: % hoặc giờ tặng).
- Khung có hai ô «Giá trị» và «Mức tối đa»; DB chỉ có `max_value` kèm cờ «Áp đúng mức» (`fixed_value`): màn dùng một ô Mức tối đa và ô tích «Áp đúng mức này (nhân viên không nhập)» cho kiểu %.
- Khung có «Áp dụng cho (Báo giá, Đơn, Phiếu thu)»; DB không có cột này nên không hiện.
- Khung bắt «Chọn ít nhất một nhóm gói»; DB cho để trống là mọi nhóm. Màn theo khung (bắt chọn).
- Số trong khung (tên, giá trị, nhóm gói) là số mẫu, không dùng.
**Chưa làm:** nút «Lịch sử thay đổi» (Nhật ký QT-11 chưa dựng): không hiện nút. Bài e2e chưa phủ hộp Thêm quà tặng (bài đã phủ hộp Thêm chiết khấu và các hàm DB đã có pgTAP từ P5a).
