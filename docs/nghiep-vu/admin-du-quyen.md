# Admin hệ thống đủ quyền (anh Trường chốt 25/11 và 26/11/2026; E-26-05)

## Phần không dính tiền (migration 678)
Bảng quyền đã cấp vai Admin mọi phân hệ, mọi hành động, toàn hệ thống; chỉ thiếu hai ô tiền (`ACCOUNTING · DUYET`, `RECEIPT · DUYET`). Chỗ còn chặn Admin là hàm đòi đúng tên vai trò. Nay các hàm đó hỏi qua một hàm trong `app.has_role_or_admin(vai)`: đúng một trong các vai, hoặc là Admin đã qua xác thực hai bước (khi luật hai bước đang bật).

| Hàm | Trước | Nay Admin thêm được | Vai khác |
|---|---|---|---|
| `list_tasks_for_destination`, `get_task_for_destination`, `set_task_destination_class`, `approve_ticket_task` (cấp cơ sở đích, R-CS-07) | Chỉ Trưởng cơ sở | Xem, chọn lớp, duyệt bước cơ sở đích khi chuyển cơ sở, ở mọi cơ sở | Không đổi |
| `create_ticket` loại Ticket giáo viên (AS-05), `teacher_create_ticket` (R-CS-10) | Chỉ Giáo viên, Trợ giảng | Tạo cho lớp bất kỳ ở mọi cơ sở; ticket thuộc cơ sở của lớp | Không đổi |
| `teacher_class_tickets` | Chỉ Giáo viên, Trợ giảng | Xem ticket gắn lớp hoặc do giáo viên báo ở mọi cơ sở | Không đổi |
| `teacher_ticket_options` | Chỉ Giáo viên, Trợ giảng | Mọi lớp đã duyệt của cơ sở đang làm việc (chọn lớp cơ sở khác cần ô chọn cơ sở trên giao diện: chưa có) | Không đổi |

Giữ nguyên với cả Admin: không tự duyệt phiếu mình tạo; một người không duyệt hai cấp của cùng một phiếu.

## Phần tiền (chưa làm, chờ anh chốt)
R-HT-01, migration 455, `can_approve_as_manager` (phiếu thu) và các cấp «Kế toán», «phiếu có cấp kế toán» vẫn chặn Admin như cũ.
