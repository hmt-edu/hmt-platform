# Việc của tôi: phần DB đợt 1 (migration 679, E-26-04; anh Trường chốt 26/11/2026)

`app.list_my_work(p_filters, p_limit, p_offset)` gom việc đang còn phải làm. Không có bảng việc: đọc thẳng trạng thái, việc gốc xong thì dòng tự mất.

- `p_filters`: `mine` (mặc định `true`; `false` = cả đội), `branch_id`, `owner_id` (lọc người, chỉ khi cả đội).
- Trả `{counts {now, today, soon}, total_cards, cards[{group_key, parent_id, parent_name, phone, urgency, items[]}]}`. Phân trang theo **thẻ**.
- Thẻ: cùng phụ huynh; lead chưa có phụ huynh gom theo số điện thoại; buổi học đứng thẻ riêng.
- Quyền: mỗi tín hiệu kiểm quyền phân hệ của nó, chỉ phạm vi Toàn hệ thống hoặc Cơ sở (như màn danh sách). Xem cả đội theo đúng phạm vi Xem, không có quyền mới.

| Tín hiệu | Điều kiện | Quyền | «Của tôi» | Nhóm gấp |
|---|---|---|---|---|
| `APPOINTMENT` | Chưa làm, tới hạn trong `work_soon_days` ngày. Bỏ lịch nhắc tự sinh của phiếu còn Nháp | Lịch hẹn · Xem | người phụ trách | theo giờ hẹn |
| `TEST` | Phiếu Nháp quá giờ hoặc sắp tới | Phiếu kiểm tra · Xem | người phụ trách | theo giờ test |
| `APPROVAL` | `app.my_approval_items()` | theo hàm đó | luôn là của người gọi; ẩn khi lọc theo người | Hôm nay |
| `SESSION_PENDING` | Buổi Đã chốt đã hết giờ; hạn = giờ hết + `teacher_session_complete_hours` | Buổi học · Xem | giáo viên, trợ giảng, CSKH lớp | theo hạn |
| `SESSION_NO_ATTENDANCE` | Buổi đang diễn ra, chưa điểm danh; công tắc `DIEM_DANH_TRONG_NGAY` | Buổi học · Xem | như trên | Làm ngay |
| `ABSENT_TODAY` | Vắng hôm nay, chưa ghi lý do liên hệ | Điểm danh · Sửa | CSKH lớp | Làm ngay |
| `RENEWAL` | Phiếu tái tục mở, chạm `upsale_hours_left_threshold` hoặc `upsale_days_left_threshold` | Tái tục · Xem | người phụ trách | hết giờ hoặc quá ngày: Làm ngay; còn lại Sắp tới |
| `TICKET_OVERDUE` (699) | Ticket chưa xử lý xong, đã quá hạn xử lý (như `QUA_HAN` ở danh sách ticket) | Ticket · Xem (kể cả phạm vi Được phân công) | người phụ trách | Làm ngay |
| `DEBT_OVERDUE` (699) | Đơn Đã duyệt còn đợt quá hạn chưa thu đủ, một việc mỗi đơn; chưa tính nợ đầu kỳ | Đơn hàng · Xem | người lập đơn | Làm ngay |

Tham số mới (ghi đè được theo cơ sở): `work_now_window_hours` (mặc định 2), `work_soon_days` (mặc định 3). Hai tham số này đọc theo **cơ sở của người xem**.

## «Để sau» (migration 691)

`app.snooze_work(p_signal, p_entity_id, p_until, p_note)` hoãn một việc trong danh sách **của tôi**; trả `{snooze_until, snooze_count, remaining}`. Bảng `app.work_snooze` (mỗi người một dòng cho một việc; chỉ đọc dòng của mình, không ghi thẳng).

| Luật | Lỗi |
|---|---|
| Không hoãn việc chờ duyệt, buổi chưa điểm danh (đang diễn ra hoặc đã hết giờ) | `HMT_VIEC_KHONG_HOAN` |
| Hạn sau lúc bấm, không quá `work_snooze_max_days` ngày (mặc định 3) | `HMT_HAN_DE_SAU_SAI` |
| Mỗi người hoãn một việc không quá `work_snooze_max_times` lần (mặc định 2) | `HMT_HET_LUOT_DE_SAU` |
| Việc phải đang nằm trong danh sách của người gọi (không hoãn hộ) | `HMT_VIEC_KHONG_CON` |

Hai tham số ghi đè được theo cơ sở, đọc theo **cơ sở của việc**. Hoãn theo người dùng: danh sách của tôi ẩn việc đó và không đếm; chế độ cả đội và người phụ trách khác vẫn thấy, mỗi mục có `snoozed_until`.

Chưa làm (PR sau): xem lại và bỏ hoãn việc đã để sau, lead chưa liên hệ, cơ hội lâu không hoạt động, chưa báo phụ huynh, vắng liên tiếp, ticket sắp quá hạn, công nợ nợ đầu kỳ, báo giá sắp hết hạn.

Hai tín hiệu của migration 699 được «Để sau» như các việc thường.

## Giao diện đợt 1 (`/crm/viec-cua-toi`, canvas 1bcc)
Danh sách việc **của tôi**, ba ô đếm, ba nhóm, thẻ theo phụ huynh, phân trang theo thẻ, một lần gọi `list_my_work`; lọc theo cơ sở đang chọn. Mỗi việc có một nút mở màn nơi làm việc đó (việc chờ duyệt đi qua «Việc chờ tôi duyệt»; lịch hẹn mở danh sách lịch hẹn vì lịch hẹn chưa có trang riêng).
Tab **Lịch tuần** (VC06, địa chỉ `?xem=tuan`, cần Lịch hẹn · Xem): lịch hẹn và phiếu Test **của tôi** trong tuần (Chưa làm, Hoàn thành; không hiện lịch Huỷ), qua `list_appointments`; bấm một ô để Hoàn thành, Dời, Huỷ, Mở lại hoặc mở hồ sơ. Nút **Tạo lịch hẹn** ở đầu màn (cần Lịch hẹn · Tạo). Các hộp thao tác dùng chung với màn Lịch hẹn (`useAppointmentActions`).
`/crm/lich-hen` **chưa** chuyển hướng: màn cũ còn giữ danh sách lịch theo từng hồ sơ, Giao hàng loạt, Xuất, Kanban mà canvas 1bcc chưa vẽ.
Chưa dựng: «Để sau» và «Đã để sau», Cả đội, nút Gọi/Hoàn thành/Dời trên dòng, mã phụ huynh trên thẻ, Trang chủ rút gọn.

