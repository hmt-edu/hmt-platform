# So canvas KH-01..KH-07 (Code D, 19/11/2026)

Cách so: lấy chữ trong các khung `KH01*..KH07*` (canvas 9933) và dò xem có trong mã `src/` không (không phân biệt hoa thường); bỏ tên người, số liệu minh hoạ. Chưa chụp màn hình so từng điểm ảnh (Tester 2 so trên staging). Dưới đây là các cụm chữ canvas có mà mã KHÔNG có; có thể mã dùng chữ khác cho cùng ý, cần mở màn để xác nhận.

| Màn | Kết quả | Cụm chữ canvas chưa thấy trong mã |
|---|---|---|
| KH-01 Danh sách phụ huynh | Gần đúng | Trạng thái trống: «Chưa có phụ huynh nào», «Hồ sơ phụ huynh tự sinh khi có cơ hội mới ở phân hệ Tuyển sinh.» |
| KH-02 Phụ huynh (bản ghi) | **Lệch** | «Ticket mở» (nút liên kết), «Ghi nhận liên hệ», khối «ĐƠN ĐĂNG KÝ VÀ GHI DANH» kèm dòng «Đơn hàng của phụ huynh này. Bấm mã đơn để mở bản ghi (màn BH-05).», «tự tính từ lớp chính của các con» (cơ sở phụ trách), chỉ báo «Sức khoẻ» (Vàng), «Quỹ giờ chưa dùng», «Còn công nợ» |
| KH-03 Sửa phụ huynh | **Lệch** | Báo lỗi tổng «Còn 2 ô bắt buộc chưa điền: Họ tên, Số điện thoại. Điền xong rồi bấm Lưu.», lỗi từng ô «Bắt buộc nhập họ tên / số điện thoại», cảnh báo trùng «Số điện thoại đã có ở phụ huynh khác: …» |
| KH-04 Danh sách học sinh | Đúng về chữ | Chữ canvas có trong mã (phần thiếu là tên mẫu) |
| KH-05 Học sinh (hồ sơ 360°) | **Lệch** | Khối «TÀI KHOẢN APP HỌC SINH» (Chưa cấp, «Chưa cấp tài khoản», «Không hiển thị · bấm “Đặt lại mật khẩu” để tạo mới»), khối «TICKET CHĂM SÓC ĐỊNH KỲ», «Tạo tự động từ phiếu test», chỉ báo «Sức khoẻ» |
| KH-06 Sửa học sinh | **Lệch** | «Tự điền từ ngày sinh nếu có.» (ô Khối), danh sách khối «Lớp 2..12» dạng chữ, khối tài khoản app như KH-05 |
| KH-07 Gộp / liên quan | Chưa rõ | Các khung KH07 trùng khung KH02 (hồ sơ phụ huynh) với chỉ báo «Sức khoẻ», cần rà cùng KH-02 |

**Việc cần quyết định:** «Sức khoẻ» (Vàng) và «Tài khoản app học sinh» là khái niệm chưa có trong luật (`docs/spec`) hay DB (cấp tài khoản học sinh thuộc QT-13/giai đoạn 4). Làm theo luật: ghi «canvas vênh luật» tới khi anh chốt. Phần chữ trạng thái trống, báo lỗi biểu mẫu (KH-01, KH-03) là việc nhỏ có thể sửa ngay.
