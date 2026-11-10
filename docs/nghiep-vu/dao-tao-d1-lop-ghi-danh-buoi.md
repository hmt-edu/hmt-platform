# Đào tạo D1: Lớp, Ghi danh, Sổ giờ, Buổi học, Điểm danh (DB)

Làm bởi Code 2, 10/11/2026. Migration 100 (Lớp), 101 (Ghi danh, Sổ giờ), 102 (Buổi, Điểm danh, Trừ giờ). **Gộp sau #205 và Q-137.**
Luật: `docs/spec/04` mục 3 (R-GD), 4 (R-LOP), 5 (R-BUOI, R-GIO), 6 (R-DD), 7 (R-GV-08); R-V2-17..21. Chưa có giao diện (D3) và chưa nạp dữ liệu cũ (D1e).

## Bảng

| Bảng                                                          | Việc                                                                                                |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `app.class_group`                                             | Nhóm lớp (R-LOP-14), không có mã riêng                                                              |
| `app.class`                                                   | Lớp; mã cấp bằng `issue_class_code`; tình trạng duyệt `status_code`                                 |
| `app.class_slot`                                              | Khung giờ thời khoá biểu (thứ, giờ, giáo viên, trợ giảng, phòng, lặp mỗi N tuần, ngày buổi đầu)     |
| `app.class_event`                                             | Lịch sử lớp (chỉ thêm)                                                                              |
| `app.class_session`                                           | Buổi học (không có mã cho người đọc, R-BUOI-08)                                                     |
| `app.enrollment`                                              | Ghi danh, mỗi dòng đơn một ghi danh (mã `GD` + 6 số)                                                |
| `app.enrollment_class`                                        | Dòng xếp lớp (lớp, ngày vào, ngày rời); một dòng đang mở                                            |
| `app.hour_ledger`                                             | Sổ giờ, chỉ thêm; số dư luôn tính từ đây                                                            |
| `app.session_attendance`                                      | Điểm danh: mỗi em một dòng mỗi buổi; ô vận hành và ô giáo viên riêng; dòng loại khỏi danh sách có lý do |

## Hàm giao diện được gọi (kiểm quyền bên trong)

| Hàm                                                                   | Ai                                | Luật                                          |
| --------------------------------------------------------------------- | --------------------------------- | --------------------------------------------- |
| `create_class(json)`                                                  | Lớp học · Tạo, cơ sở mình         | R-LOP-06, 08, 13, 14                          |
| `save_class_info(lớp, json)`                                          | Lớp học · Sửa                     | R-LOP-02                                      |
| `save_class_timetable(lớp, khung, ngày áp dụng, xem trước)`           | Lớp học · Sửa                     | R-LOP-02, 10, 13                              |
| `transition_class(lớp, đích, ghi chú)`                                | Sửa / Duyệt / Huỷ theo bước       | R-LOP-01, 02, 03, 04                          |
| `create_class_group(cơ sở, khối, tên)`                                | Lớp học · Tạo                     | R-LOP-14                                      |
| `class_operating_status`, `class_clash_warnings`, `compute_class_schedule` | Đọc                          | R-LOP-05, 08, 09                              |
| `assign_enrollment_class(ghi danh, lớp, ngày vào)`                    | Ghi danh · Sửa                    | R-GD-05, 06, 08, 15                           |
| `adjust_enrollment_hours(ghi danh, giờ, lý do, ghi chú)`              | Ghi danh · Duyệt (Trưởng cơ sở, Admin) | R-GD-04, R-GD-18                         |
| `close_session(buổi)`                                                 | Buổi học · Sửa (không phải GV)    | R-BUOI-02, R-GIO-02, 03, 04                   |
| `set_attendance_teacher(buổi, danh sách)`                             | Giáo viên được phân công          | R-DD-01, 02, R-GIO-08, R-GV-08                |
| `set_attendance_ops(buổi, danh sách)`                                 | Điểm danh · Sửa (không phải GV)   | R-DD-02, 03                                   |
| `cancel_session(buổi, kiểu, lý do, ghi chú)`                          | Buổi học · Sửa (không phải GV)    | R-BUOI-02, 06, 07, 09                         |
| `correct_attendance_after_done(buổi, em, trạng thái, lý do, ghi chú)` | Điểm danh · Duyệt                 | R-GIO-07                                      |
| `move_session`, `change_session_staff`                                | Buổi học · Sửa (không phải GV)    | R-LOP-08, 10, 11                              |
| `session_pending_reason(buổi)`                                        | Đọc                               | R-GIO-06                                      |
| `check_order_line_class(...)`                                         | Dòng đơn (đơn hàng gọi)           | R-GD-08 (thay thân hàm giữ chỗ ở migration 051) |

## Hàm nội bộ (không cấp cho giao diện)

| Hàm                                              | Gọi từ đâu                                                           | Luật                  |
| ------------------------------------------------ | -------------------------------------------------------------------- | --------------------- |
| `create_enrollments_for_order(đơn)`              | **Nơi kế toán duyệt phiếu thu (Code 1, B2) cần gọi sau khi sinh khoản tiền vào** | R-TIEN-20, R-GD-01, 08 |
| `sync_enrollment_hours(đơn)`                     | Như trên (đã gọi trong hàm trên); chạy lại nhiều lần không đổi       | R-TIEN-21, 24, 26     |
| `move_enrollment_class(ghi danh, lớp, ngày, mã ticket)` | Ticket đề nghị đã duyệt (Aftersale A1)                       | R-GD-10               |
| `add_opening_hours(ghi danh, giờ, mã đợt)`       | Hàm nạp dữ liệu (D1e)                                                | R-V2-33               |
| `build_session_roster`, `deduct_session_hours`, `mark_session_done` | Chốt tay/tự chốt; Done                                  | R-GIO-01..06          |
| `auto_close_sessions`, `auto_complete_sessions`  | Lịch hệ thống (pg_cron): **chưa đăng ký lịch**, chờ anh duyệt        | R-GIO-05, 06          |

## Điểm cần anh/Chat biết

- Tham số mới: `class_slot_repeat_weeks_max` (mặc định 4, khoảng 1 đến 8, R-LOP-13).
- Danh mục mới: `CLASS_STATUS`, `SESSION_STATUS` (kèm mã kỹ thuật `DA_THAY`: buổi Nháp bị thay khi sinh lại lịch, không xoá cứng); tình trạng ghi danh thêm `DA_XEP_LOP` (R-GD-05).
- Mã lớp gồm cơ sở, năm, môn, khối, phân loại, trình độ nên các trường đó **không sửa sau khi tạo** (nhầm thì Huỷ rồi tạo lớp mới). Đây là suy ra từ nguyên tắc "mã không đổi", chờ anh xác nhận.
- Khung chương trình (R-LOP-07) mới lưu mã khung và bài bắt đầu dạng chữ, chưa có bảng khung.
- Chưa có: bảo lưu, dừng, hoàn phí, chuyển phí (ticket A1); yêu cầu học bù, củng cố, bổ trợ, học thử; điều kiện nhận xét và BTVN khi Done (D2); đăng ký lịch pg_cron.
