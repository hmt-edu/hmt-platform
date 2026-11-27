# Thẻ tóm tắt và cờ cảnh báo đầu hồ sơ phụ huynh, học sinh (migration 695; canvas `design/hmt-canvas-a8d7/`)

Chỉ đọc, một lần gọi cho mỗi hồ sơ.

| Hàm | Ai gọi | Trả |
|---|---|---|
| `app.get_parent_summary(phụ huynh)` | Phụ huynh · Xem, phạm vi Toàn hệ thống hoặc Cơ sở (R-CRM-26) | Con đang học, ô tiền, ticket mở và quá hạn, lần liên hệ cuối (tính cả các con), dữ liệu cờ, phiếu tái tục đang mở |
| `app.get_student_summary(học sinh)` | Học sinh · Xem, đúng phạm vi của `get_student_record` | Lớp đang học, buổi kế tiếp, giờ còn lại, chuyên cần, điểm gần nhất, CSKH, ticket, liên hệ, dữ liệu cờ |

Quyền trong thẻ:
- Tổng đã đóng, Số dư: xem được phiếu thu ở cơ sở của phụ huynh. Còn nợ: xem được đơn hàng. Không có quyền thì ô trả rỗng, giao diện ghi «Ẩn».
- Số ngày nợ quá hạn (không kèm tiền) luôn trả để dựng cờ, theo khung `KH02_360_an_tien`.
- Liên hệ chỉ tính ghi chú người gọi đọc được. Người phạm vi «được phân công» (giáo viên) không nhận CSKH, ticket, liên hệ (R-GV-13).

Cờ:
| Cờ | Điều kiện |
|---|---|
| Nợ quá hạn | Có đợt thanh toán của đơn đã duyệt quá ngày hạn mà chưa đủ tiền |
| Ticket quá hạn | Ticket mở quá hạn xử lý, không đang tạm dừng |
| Sắp hết giờ | Hết giờ hoặc sắp hết giờ theo `app.expiring_enrollment_rows` (R-GD-07, kể cả công tắc `SAP_HET_GIO`) |
| Lâu chưa liên hệ | Từ `contact_stale_days` ngày; chưa liên hệ lần nào thì đếm từ ngày tạo hồ sơ |
| Vắng liên tiếp | Từ `absence_streak_sessions` buổi gần nhất đều vắng |
| Thiếu nhận xét | Buổi em có mặt bị Done khi còn thiếu (cờ R-GIO-12) trong `attendance_rate_window_days` ngày |
