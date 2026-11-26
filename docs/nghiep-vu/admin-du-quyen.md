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

## Phần tiền (anh Trường chốt 26/11 15:35, E-26-05c)
| Chỗ | Admin nay | Vai khác |
|---|---|---|
| Quyền `ACCOUNTING · DUYET`, `RECEIPT · DUYET` | Có, toàn hệ thống | Không đổi; chốt chặn chỉ cho Kế toán và Admin |
| Phiếu thu, thu nợ đầu kỳ | Duyệt cả hai bước, kể cả phiếu mình lập | Hai người khác nhau, không tự duyệt |
| Đảo khoản, phiếu chi, áp số dư, cộng giờ (quyền Kế toán · Duyệt) | Làm được | Chỉ Kế toán |
| Hoàn phí, dừng học | Tự duyệt, duyệt cả hai bước | Như cũ |
| Phiếu nghiệp vụ có cấp Kế toán | Duyệt mọi cấp, kể cả phiếu mình tạo | Như cũ |

Nhật ký: bảng `app.admin_approval_log` (chỉ thêm; người có Quản trị · Xem đọc được) ghi `TU_DUYET` và `HAI_BUOC` theo chứng từ, bước, người. Mọi lần duyệt khác vẫn nằm trong lịch sử chứng từ và nhật ký thao tác như trước. Chưa có màn xem nhật ký này.

Phiếu **không** dính tiền (chuyển cơ sở, bảo lưu, chuyển lớp…) giữ nguyên luật tự duyệt và hai cấp như trước đợt này.
