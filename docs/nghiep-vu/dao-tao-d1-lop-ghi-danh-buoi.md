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

## D2: nhận xét buổi, buổi Kiểm tra (migration 103, xếp chồng sau #209)

Luật: R-V2-18 (Q-176), R-V2-19, R-V2-20, R-V2-38, R-V2-39; R-GV-01, R-GV-04 đã sửa theo R-V2-19.

| Hàm | Ai | Việc |
| --- | --- | --- |
| `open_session_review(buổi)` | Điểm danh · Sửa (giáo viên được phân công, vận hành) | Chụp 9 tiêu chí của môn cho buổi thường |
| `set_review_criteria(buổi, [{criterion_id, enabled}])` | như trên | Công tắc tiêu chí: tắt = cả lớp Không áp dụng |
| `set_review_scores(buổi, [{student_id, criterion_id, state, score}])` | như trên | Chấm em có mặt: Đã đánh giá 1 đến 5, Chưa đủ căn cứ |
| `set_review_all_class(buổi, tiêu chí, mức)` | như trên | Nút "Cả lớp"; mức mặc định `review_all_class_level` |
| `set_student_review_note(buổi, em, nhận xét, định hướng)` | như trên | Không bắt buộc; giáo viên sửa tới khi Done |
| `set_review_exported(buổi, em, đã xuất)` | Điểm danh · Xem | Cờ Đã xuất (R-V2-38), đặt được cả sau Done |
| `set_exam_config(buổi, phạm vi, tối đa, cách nhập, tối đa 3 nhóm)` | Buổi học · Sửa (không phải giáo viên) | Cấu hình buổi Kiểm tra |
| `set_exam_scores(buổi, [{student_id, total hoặc memory/understand/apply}])` | giáo viên được phân công | Nhập điểm kiểm tra |
| `correct_exam_score_after_done(...)` | Điểm danh · Duyệt | Sửa điểm sau Done, bắt buộc lý do |
| `review_average(dòng điểm danh)`, `parent_message_hint(buổi, em)` | đọc | Trung bình chưa làm tròn; mức 1 đến 4 và 3 câu mẫu |

Điều kiện Done (`session_pending_reason`, tham số `session_done_requires_review`, Q-198: Tắt thì chỉ cần điểm danh xong): buổi thường không còn ô Chưa đánh giá; buổi Kiểm tra không còn em có mặt ở Chưa chấm. Không còn điều kiện BTVN (R-V2-35).
Bộ tiêu chí: Toán, Đại số, Hình học dùng bộ Toán; mọi môn còn lại dùng bộ môn phụ (Q-189); mô tả 5 mức và 24 mẫu câu là dữ liệu (Q-190). `review_criteria_for_subject(môn)` trả tiêu chí của môn; `session_review_sheet(buổi)` trả dữ liệu màn chấm trong một lần gọi.
Chưa có: bài tập về nhà, màn cấu hình đánh giá (CH-07, sau 17/11), ticket sửa nhận xét sau Done.

## Lịch tự chạy (migration 104, PR pg_cron)

`app.sync_session_cron()` (Admin) đăng ký hai lịch pg_cron từ Cài đặt: `hmt-auto-close-sessions` gọi `app.auto_close_sessions()` mỗi `session_autoclose_before_minutes` phút (30), `hmt-auto-complete-sessions` gọi `app.auto_complete_sessions()` mỗi `session_autocomplete_minutes` phút (15). Đổi tham số xong thì gọi lại hàm này. Luật R-GIO-05, R-GIO-06, Q-180.
