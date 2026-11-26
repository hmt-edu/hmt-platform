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

Tham số mới (ghi đè được theo cơ sở): `work_now_window_hours` (mặc định 2), `work_soon_days` (mặc định 3). Hai tham số này đọc theo **cơ sở của người xem**.

Chưa làm (PR sau): «Để sau» (`work_snooze`), lead chưa liên hệ, cơ hội lâu không hoạt động, chưa báo phụ huynh, vắng liên tiếp, ticket, công nợ, báo giá sắp hết hạn.
