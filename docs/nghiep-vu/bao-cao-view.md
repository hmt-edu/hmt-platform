# View báo cáo (migration 214)

Code D, 16/11/2026. Luật: R-BC-01, 02, 04, 05; R-DD-02. Chat chốt 16/11 05:35: view trong schema `report`, `security_invoker` (RLS bảng gốc áp theo người đọc), đọc qua vai trò sẵn có, **không** tạo vai trò DB cho Looker (anh Trường quyết sau, đã ghi `VIEC-ANH.md`).

| View                          | Màn   | Nội dung                                                                                                      |
| ----------------------------- | ----- | ------------------------------------------------------------------------------------------------------------- |
| `report.enrollment_unit_price` | (nền) | Đơn giá ghi nhận của ghi danh có dòng đơn = tiền đã thu ÷ (giờ mua + giờ tặng)                               |
| `report.lead_funnel`          | BC-02 | Theo tháng, cơ sở, nguồn, chiến dịch, người phụ trách: số lead, số cơ hội, số cơ hội chốt (L8)               |
| `report.revenue_by_session`   | BC-03 | Mỗi dòng trừ giờ của buổi chính/củng cố: giờ, đơn giá, doanh thu (trống nếu chưa có giá), cơ sở nơi buổi diễn ra |
| `report.hours_fund`           | BC-04 | Mỗi ghi danh còn hiệu lực: giờ đã cấp, giờ còn, giờ còn quy ra tiền, tiền đã thu                             |
| `report.class_attendance`     | BC-06 | Mỗi lớp: sĩ số hiện tại, tối đa, số lượt có mặt và vắng ở buổi Done (ô giáo viên quyết định, R-DD-02)        |

Chưa làm: BC-05 tái tục (chưa có bảng phiếu tái tục), BC-07 BTVN, BC-10 ticket (chờ #18). Chọn tự động cùng quy tắc chọn đơn giá của `report_overview` (xem `bao-cao-tong-quan.md`): chờ Chat xác nhận. Quyền xem: view chỉ trả hàng mà người đọc xem được ở bảng gốc; chưa có chặn riêng theo quyền Báo cáo.

## Bổ sung: BC-10 ticket (migration 230)

`report.ticket_summary`: mỗi ticket một dòng, kèm loại, nhóm cha (`group_code`), nghiệp vụ đi kèm (`business_type`: chuyển lớp, bảo lưu, hoàn phí... cho báo cáo lý do), tháng tạo, người phụ trách, người bị khiếu nại, cờ `response_on_time`, `resolve_on_time`, `response_overdue_open`, `resolve_overdue_open` (không tính ticket huỷ) và `resolve_hours`. Looker Studio hoặc màn BC-10 tự gộp theo loại, nhóm, cơ sở, tháng, người (R-CS-12). Đọc qua RLS của bảng `ticket` (`security_invoker`).

## Bổ sung: BC-07 BTVN (migration 233)

`report.homework_summary`: mỗi dòng gộp theo cơ sở, lớp, giáo viên của buổi giao bài, học sinh, tháng giao bài. Hai chỉ số **tách riêng** (R-GV-12): tỉ lệ làm bài = (Đã chấm + Làm chưa xong) ÷ (Đã chấm + Làm chưa xong + Không làm), không tính Không áp dụng, Nộp sau chưa tính tới khi cập nhật; điểm trung bình chỉ tính bài Đã chấm và Làm chưa xong (Không làm không thành điểm 0). Cột `completion_rate_percent`, `avg_score` để trống khi không có mẫu. Gộp tiếp theo lớp, giáo viên, cơ sở bằng cách **cộng các cột đếm** (`required_count`, `done_count`, `score_sum`, `score_count`), không lấy trung bình của tỉ lệ.
