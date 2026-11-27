# Đào tạo D1: Lớp, Ghi danh, Sổ giờ, Buổi học, Điểm danh (DB)

> **26/11/2026, anh Trường chốt luật điểm danh và Done buổi mới (CHƯA làm trong mã):** R-DD-02 đến R-DD-06, R-GIO-06, R-GIO-07, R-GIO-09 đến R-GIO-12, R-GV-05, R-V2-35 (và làm rõ R-GV-04, R-V2-20: mã đã tính em Đi muộn) trong `docs/spec/04-luat-nghiep-vu.md`. Phần dưới mô tả mã đang chạy. Những chỗ mã sẽ phải đổi: điều kiện Done xét thêm hai cột khớp; chép ô giáo viên sang ô vận hành; dấu Đúng/Trễ hạn tách khỏi lúc Done; Done tay, nhập thay, Done hàng loạt; cờ vắng và báo cáo chỉ đọc cột giáo viên.

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
| `preview_class_end_date(cơ sở, ngày bắt đầu, số buổi, khung giờ)`     | Lớp học · Xem, cơ sở của lớp      | R-LOP-09, 12, 13 (chỉ đọc, không ghi; migration 574) |
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

**Tự Done không nuốt lỗi (P7, migration 128).** `app.auto_complete_sessions()` vẫn bắt lỗi từng buổi (một buổi lỗi không chặn buổi khác) nhưng ghi vào bảng `app.session_auto_done_error`: MỘT dòng mỗi buổi gồm mã lỗi (`HMT_*` hoặc sqlstate), câu lỗi, số lần thử (`attempts`, tăng mỗi lượt chạy mà buổi vẫn lỗi), lần đầu, lần cuối. Lần chạy sau vẫn thử lại buổi đó; Done được thì `resolved_at` có giá trị và số lần thử dừng. Chỉ Quản trị đọc được bảng (RLS); không đổi luật trừ giờ. Xem lỗi chưa hết: `select * from app.session_auto_done_error where resolved_at is null order by last_error_at desc`.

## D1e: nạp dữ liệu đào tạo (migration 105)

`app.import_training_records(loại, hàng, nạp thật, tên file)` (Admin, cùng hợp đồng với `app.import_records`): loại LOP, GHI_DANH, BUOI_HOC, DIEM_DANH. Xem trước hoàn tác; nạp thật ghi nhật ký. Báo cáo có `summary.errors_by_type` (mã lỗi → số dòng) và `summary.classes_without_teacher`. Lớp nạp chỉ sinh buổi từ `opening_balance_date` (Q-199). Mỗi ghi danh một dòng Số dư đầu kỳ mang ngày chốt (`hour_ledger.entry_date`, Q-177). Buổi, điểm danh cũ vào `legacy_session_record`, `legacy_attendance_record` (chỉ đọc); `app.legacy_hours_reconciliation(mã lớp cũ, chỉ dòng lệch)` so giờ đã học ghi trong file với điểm danh cũ. Luật R-V2-30, R-V2-32, R-V2-33, Q-186..188, Q-199, Q-200.

## Cụm Ghi danh: hàm đọc và chọn lớp (migration 113, 114; GD-01, GD-02, GD-03, GD-04, GD-06, BH-08)

Luật: R-GD-05 (hàng chờ CHỈ ghi danh Chờ xếp lớp), R-GD-04 (sổ giờ chỉ thêm), R-GD-06, R-GD-08, R-GD-14, R-GD-15 (xếp lớp, ngày vào lớp, lớp luân phiên không báo trùng), R-GD-18 (chuyển phí kèm mã ticket), R-GV-13 (giáo viên không đọc ghi danh, sổ giờ). Giao diện không tính giờ; số do hàm trả.

| Hàm | Ai | Việc |
| --- | --- | --- |
| `enrollment_list(bộ lọc, sắp xếp, số dòng, bỏ qua)` | Ghi danh · Xem (toàn hệ thống, cơ sở) | GD-01. Lọc q, status[], branch_id, class_id, student_id, parent_id; sắp code_desc, code_asc, student_asc, student_desc, remaining_asc, remaining_desc; kết quả {total, rows} kèm giờ cấp, đã học, còn lại. |
| `enrollment_group_counts(bộ lọc, trường nhóm[])` | Ghi danh · Xem | Group By ở máy chủ (E65, migration 512): số đếm theo một đến hai trường (hình thức học, lớp hiện tại, tình trạng); cùng phạm vi và bộ lọc với `enrollment_list`, mở nhóm bằng `delivery_mode_code`, `class_id`, `status`, `no_class`. Lỗi `HMT_NHOM_SAI` khi trường lạ, trùng hoặc quá hai cấp. |
| `enrollment_queue(bộ lọc, số dòng, bỏ qua)` | Ghi danh · Sửa | GD-06. Chỉ ghi danh Chờ xếp lớp, cũ nhất trước. |
| `enrollment_record(id)` | Ghi danh · Xem | GD-02. Thông tin, quỹ giờ, dòng xếp lớp kèm giờ đã học tại lớp. Ngày hết giờ dự kiến và hạn gói chưa tính (null). |
| `enrollment_ledger(id, số dòng, bỏ qua)` | Ghi danh · Xem | GD-04. Mọi dòng sổ giờ, mới nhất trước, kèm số dư sau mỗi dòng; chuyển phí nêu mã ticket. |
| `enrollment_matching_classes(gói, cơ sở, học sinh)` | Ghi danh · Sửa hoặc Đơn hàng · Sửa | BH-08, GD-03. Lớp đã duyệt, còn chỗ, đúng môn, khối của gói; kèm lịch, giáo viên, buổi sắp tới, số buổi trùng với lớp em đang học. |
| `enrollment_assign_options(ghi danh)` | Ghi danh · Sửa | GD-03. Ghi danh cùng học sinh đang chờ, lớp phù hợp, nhóm lớp (mỗi ghi danh một lớp trong nhóm, không trùng buổi). |
| `assign_enrollments_to_classes([{enrollment_id, class_id, start_date}])` | Ghi danh · Sửa | GD-03. Xếp nhiều ghi danh một giao dịch, gọi lại `assign_enrollment_class`; một dòng lỗi thì không xếp dòng nào. |
| `set_order_line_class(đơn, số dòng, lớp, ngày)` | Đơn hàng · Sửa | BH-08. Gắn lớp, ngày vào lớp cho dòng đơn Nháp; lớp null = chưa chọn lớp. Ghi nhật ký đơn. |
| `order_line_classes(đơn)` | Đơn hàng · Xem | Mã lớp, ngày vào lớp của từng dòng đơn. |

Chưa làm ở cụm này: Điều chỉnh giờ (GD-05), Tạo ticket (CS-04), ghi chú và hoạt động của ghi danh, hồ sơ học sinh; cột Phiếu thu, Khoản tiền của sổ giờ (sổ giờ chưa lưu liên kết tới phiếu thu).

## GV: dữ liệu đọc cho cổng Giáo viên, nội dung buổi (migration 107)

Luật: R-GV-08, R-GV-13, R-GIO-06, R-GIO-08, R-V2-35, R-V2-37, Q-208. Điều kiện nội dung buổi theo Q-231 (chờ anh "OK ĐƯA VÀO LUẬT", chưa vào spec 04).

| Hàm                                               | Ai                                 | Việc                                                                                                                              |
| ------------------------------------------------- | ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `teacher_my_sessions(chế độ, từ, đến, limit, offset)` | Người là giáo viên hoặc trợ giảng | `NGAY`: buổi trong khoảng ngày (GV-02, GV-03, không buổi huỷ). `CAN_LAM`: buổi đã kết thúc chưa Done, kể cả quá hạn (GV-12). Tối đa 100 dòng |
| `teacher_class_overview(lớp)` | Giáo viên hoặc trợ giảng được phân công lớp (R-GV-08) | GV-11: lớp, lịch học, học sinh (chuyên cần = số buổi có mặt/đi muộn ÷ số buổi đã điểm danh; điểm TB tiêu chí chưa làm tròn, chỉ điểm Đã đánh giá của em có mặt), tối đa 100 buổi mới nhất kèm hạn hoàn tất, nhãn Trễ hạn (chỉ buổi chưa Done mà quá hạn; buổi Done không nhãn, quyết định Chat 13/11) và BTVN. Không có thông tin phụ huynh (R-GV-13) |
| `teacher_session_students(buổi)`                  | Điểm danh · Xem, buổi của mình     | Danh sách em chỉ khi buổi Đã chốt hoặc Done (R-GIO-08); chỉ tên, mã, trạng thái điểm danh (R-GV-13)                                |
| `session_overview(buổi)`                          | như trên                           | Tiến độ cho GV-04: điểm danh, nội dung, BTVN, hạn hoàn tất, lý do chưa Done                                                        |
| `save_session_content(buổi, các dòng, BTVN)`      | Điểm danh · Sửa, buổi của mình     | Lưu cả bộ nội dung một lần; cần ít nhất một dòng; BTVN trống = không giao (R-V2-35); buổi Done thì chặn                            |

Bảng: `session_content` (BTVN giao mới, một dòng mỗi buổi) và `session_content_line` (các dòng nội dung; dòng bị bỏ đặt `is_active = false`).

Điều kiện Done (`session_pending_reason`): buổi thường cần ít nhất một dòng nội dung ở cả hai nhánh Bật và Tắt của `session_done_requires_review`; buổi Kiểm tra không đòi dòng nội dung, chỉ giữ điều kiện cấu hình điểm của D2.

## Cụm Lớp: hàm đọc cho LOP-01, LOP-02, LOP-03, LOP-08 (migration 116)

Luật: R-LOP-01, R-LOP-05, R-LOP-08, R-LOP-14, R-LOP-15. Chỉ đọc; ghi vẫn qua `create_class`, `save_class_info`, `save_class_timetable`, `transition_class` (migration 100). Phạm vi theo quyền Lớp học · Xem (toàn hệ thống, cơ sở mình, lớp được phân công).

| Hàm                                                  | Việc                                                                                                                                  |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `list_classes(bộ lọc, sắp xếp, limit, offset)`       | LOP-01: lọc tình trạng duyệt, vận hành, cơ sở, môn, khối, phân loại; tìm theo mã lớp hoặc mã cũ; sĩ số, chỗ còn lại, lịch học, giáo viên |
| `get_class_record(lớp)`                              | LOP-02: thông tin, khung giờ, học sinh đang xếp (không số điện thoại), đếm buổi, 100 buổi, cảnh báo trùng, 20 sự kiện gần nhất; sự kiện kèm tên người làm (mig 689) |
| `week_sessions(cơ sở, từ ngày, đến ngày)`            | LOP-08: buổi trong tối đa 14 ngày, cờ trùng phòng, trùng giáo viên ở cấp buổi thật (chỉ cảnh báo)                                      |
| `list_class_form_options(cơ sở)`                     | LOP-03: giáo viên, trợ giảng, CSKH, phòng, nhóm lớp của cơ sở                                                                         |

Giao diện: danh sách và Kanban theo bước duyệt (LOP-01), hồ sơ với Trình, Xác nhận, Duyệt, Từ chối, Đưa về Nháp, Đóng, Huỷ (LOP-02, LOP-05, LOP-06), biểu mẫu tạo/sửa có Time Table (LOP-03), lịch tuần (LOP-08). Chưa làm: Hình thức học và Tổ chức lớp (cần cột mới, sau 17/11), Xuất CSV, nút Yêu cầu bổ trợ, bản điện thoại dạng thẻ.

## Cụm Buổi A: các hàm đọc cho BUOI-01, 02, 03, 11 (migration 120)

Không đổi luật ghi; chỉ thêm hàm đọc (security definer, kiểm quyền bên trong, phân trang ở máy chủ). Ghi dùng lại hàm D1c: `close_session`, `set_attendance_ops`.

| Hàm | Ai gọi | Việc |
|---|---|---|
| `session_list(bộ lọc, sắp xếp, số dòng, bỏ qua)` | Buổi học · Xem (toàn hệ thống hoặc cơ sở) | BUOI-01: lọc ngày, lớp, giáo viên, cơ sở, tình trạng, mã lớp; cột Ghi chú = lý do chưa Done của buổi Đã chốt |
| `session_group_counts(bộ lọc, trường nhóm[])` | Buổi học · Xem | Group By ở máy chủ (E65, migration 513): số đếm theo một đến hai trường (ngày, lớp, cơ sở, giáo viên, loại buổi, tình trạng); cùng phạm vi và bộ lọc với `session_list`; `session_list` thêm bộ lọc `type_code`, `no_teacher` để mở nhóm. Lỗi `HMT_NHOM_SAI`. |
| `session_record(buổi)` | như trên (không phải giáo viên "được phân công") | BUOI-02: thông tin buổi, danh sách hai cột điểm danh (thẻ Lệch), em không vào danh sách kèm lý do, nhận xét, hạn giáo viên hoàn tất (R-GV-05) |
| `session_ops_sheet(buổi)` | Điểm danh · Sửa (vận hành) | BUOI-03: bảng điểm danh vận hành, danh mục trạng thái và lý do liên hệ |
| `absent_today_list(bộ lọc, số dòng, bỏ qua)` | Điểm danh · Sửa (vận hành) | BUOI-11: em vắng hoặc chưa đến của buổi Đã chốt hôm nay. Quy tắc hiển thị TẠM (Chat 10/11, chưa vào luật): ô giáo viên quyết định; giáo viên đã chọn Có mặt thì không hiện dù vận hành ghi gì; ô vận hành chỉ dùng khi ô giáo viên trống; Chưa đến = buổi đã bắt đầu mà cả hai ô trống |
| `teacher_attendance_sheet(buổi)` (thay bản 111) | giáo viên, trợ giảng được phân công | thêm `contact_reason_name` (lý do liên hệ của vận hành, chỉ xem; không ghi chú tự do, không số điện thoại, phụ huynh) |

Chưa có: lý do huỷ buổi (cụm Buổi B, BUOI-04), "Báo nghỉ trước", dòng thời gian của buổi, ghi lý do hàng loạt, lọc theo giáo viên ở BUOI-01.

## GV-08 · Chấm BTVN buổi trước (migration 121)

Luật: R-GV-10, R-GV-11, R-GV-12, R-GV-08, R-GV-13, R-GIO-06, R-V2-35. Điều kiện chặn Done theo Q-272 (chờ anh "OK ĐƯA VÀO LUẬT", chưa vào spec 04).

| Hàm                                                                     | Ai                                          | Việc                                                                                                                                                                  |
| ----------------------------------------------------------------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `homework_grading_sheet(buổi)`                                          | Điểm danh · Xem, buổi của mình              | Dữ liệu màn GV-08 một lần gọi: trạng thái (`DAU_LOP`, `KHONG_GIAO`, `CAN_CHAM`), BTVN buổi trước, em có mặt kèm kết quả, em vắng buổi này, bài Nộp sau chờ cập nhật |
| `save_homework_grading(buổi, [{student_id, status_code, score, note, expected_version}])` | Điểm danh · Sửa, buổi Đã chốt               | Chấm em có mặt; điểm 1–5 chỉ cho Đã chấm, Làm chưa xong; lệch phiên bản dòng báo `HMT_XUNG_DOT`, cả lô không ghi                                                      |
| `update_late_homework(buổi giao bài, em, trạng thái, điểm, ghi chú, phiên bản)` | Điểm danh · Sửa của buổi giao bài, kể cả khi buổi đã Done | Cập nhật bài đang Nộp sau (hoặc em vắng buổi chấm chưa có dòng) mà không mở lại buổi cũ                                                                      |
| `homework_progress(buổi)`, `previous_session(buổi)`                     | nội bộ                                      | Tiến độ bước chấm BTVN cho `session_overview` và `session_pending_reason`                                                                                            |

Bảng `homework_result` (một dòng mỗi em mỗi bài BTVN, có `version`). Em vắng buổi giao bài: không có dòng, màn đặt sẵn Không áp dụng và tính là đã có trạng thái. **Bài Nộp sau suy từ điểm danh:** em có mặt ở buổi giao bài, vắng buổi kế tiếp và chưa có dòng nào thì màn GV-08 liệt kê trong «Bài Nộp sau chờ cập nhật» mà không ghi dòng sẵn. Ví dụ: BTVN giao ở buổi 4, em Dũng có mặt buổi 4, vắng có phép buổi 5; ở buổi 5 em Dũng nằm ở mục «Em vắng buổi này», và từ buổi 6 trở đi nằm trong Bài Nộp sau cho tới khi giáo viên cập nhật.

Điều kiện Done: tham số `session_done_requires_review` Bật và buổi trước có giao BTVN thì mọi em có mặt phải có trạng thái BTVN; Tắt thì bước này không chặn.

## GV-07 · Chấm nhận xét từng em (migration 121, bố cục «Theo em»)

Luật: R-V2-19, R-GV-02, R-GV-03, R-GV-04, R-GV-08, R-GV-13. Các hàm ghi (`open_session_review`, `set_review_criteria`, `set_review_scores`, `set_student_review_note`) có từ migration 103; migration 121 thêm hai hàm cho màn.

| Hàm                                                        | Ai                                        | Việc                                                                                                                                              |
| ---------------------------------------------------------- | ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `review_grading_sheet(buổi)`                               | Điểm danh · Xem, buổi của mình            | Một lần gọi cho cả màn: buổi, tiêu chí đã mở (kèm bật/tắt, gợi ý, mô tả 5 mức), mọi em kèm điểm từng tiêu chí, nhận xét, định hướng, điểm trung bình do DB tính |
| `save_review_grading(buổi, công tắc tiêu chí, điểm, nhận xét)` | Điểm danh · Sửa, buổi Đã chốt             | Một giao dịch: mở nhận xét nếu chưa mở, rồi tắt/bật tiêu chí, ghi điểm, ghi nhận xét. Hoặc lưu hết hoặc không lưu gì                                |

Chưa làm (ghi trong báo cáo): «Theo tiêu chí» (chấm theo cột), «Cả lớp», xuất nhận xét (GV07X), màn nhập điểm Kiểm tra (GV-07K), chống ghi đè nhận xét (sau 17/11).

## Cụm Buổi B: huỷ, dời, theo dõi buổi chưa hoàn tất (migration 123)

Thêm cột `cancel_reason_code`, `cancel_note` cho buổi (lưu lý do huỷ; buổi huỷ trước migration 123 để trống). `app.cancel_session` thay bản 102, luật huỷ giữ nguyên, chỉ thêm lưu lý do. `session_list`, `session_record` (migration 120) thay bản mới hiện lý do huỷ.

| Hàm | Ai gọi | Việc |
|---|---|---|
| `session_cancel_preview(buổi)` | Buổi học · Sửa (vận hành) | BUOI-04 xem trước: số buổi và ngày buổi sẽ thêm vào cuối lịch khi trung tâm huỷ (R-BUOI-06). Chỉ đọc |
| `session_move_options(buổi)` | như trên | BUOI-05: phòng đang dùng của cơ sở để chọn |
| `session_move_check(buổi, ngày, giờ, giờ, phòng)` | như trên | BUOI-05 kiểm trùng phòng, giáo viên TRƯỚC khi lưu; chỉ cảnh báo (R-LOP-08). Chỉ đọc |
| `session_pending_list(bộ lọc, số dòng, bỏ qua)` | Buổi học · Xem (toàn hệ thống hoặc cơ sở) | BUOI-12: buổi Đã chốt đã kết thúc mà giáo viên chưa hoàn tất; hạn = giờ kết thúc + `teacher_session_complete_hours` (R-GV-05); lý do chưa Done (R-GIO-06) |
| `remind_teacher_session(buổi)` | Buổi học · Sửa (vận hành) | BUOI-12 "Nhắc GV": ghi một thông báo (loại `NHAC_HOAN_TAT_BUOI`) cho giáo viên của buổi Đã chốt. Cổng giáo viên chưa có chỗ đọc thông báo (làm sau) |

Ghi dùng lại hàm D1c: `cancel_session`, `move_session`. Chưa có: ghi chú, dòng thời gian của buổi; "Nhãn bài dời theo" ở xem trước huỷ (buổi chưa có nhãn bài riêng); đổi giáo viên (BUOI-13), thêm học thử (BUOI-06), sửa sau Done (BUOI-14).

## GV-07K · Chấm kiểm tra (migration 124)

Luật: R-V2-20, R-GV-04, R-GV-08, R-GV-13. Các hàm ghi điểm (`set_exam_scores`) và nhận xét (`set_student_review_note`) có từ migration 103; cấu hình buổi Kiểm tra do vận hành đặt (`set_exam_config`).

| Hàm                                              | Ai                                   | Việc                                                                                                                                                  |
| ------------------------------------------------ | ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `exam_grading_sheet(buổi)`                       | Điểm danh · Xem, buổi của mình       | Một lần gọi cho cả màn: buổi, cấu hình (phạm vi, điểm tối đa, cách nhập, tối đa 3 nhóm; null nếu chưa đặt), mọi em kèm điểm danh, điểm, nhận xét       |
| `save_exam_grading(buổi, điểm, nhận xét)`        | Điểm danh · Sửa, buổi Đã chốt       | Một giao dịch: ghi điểm (tổng hoặc 3 nhóm, tổng tự cộng) và nhận xét; em vắng không nhập điểm; ngoài giới hạn hoặc buổi Done thì chặn, không ghi gì |

Chưa làm: sửa điểm sau Done (qua ticket, chỉ quản lý đào tạo), «Theo tiêu chí», «Cả lớp», xuất nhận xét (sau 17/11).

## Hình thức học của lớp, Tổ chức lớp, xem trước ngày kết thúc (migration 574, LOP-02/03, anh Trường chốt 20/11/2026)

- **Hình thức học**: cột `class.delivery_mode_code` (OFF, ONL, OMO; lớp cũ mặc định OFF), danh mục `CLASS_DELIVERY` riêng, KHÔNG thêm OMO vào `STUDY_MODE` (hình thức bán của ghi danh và bảng giá). `create_class` nhận `delivery_mode_code` (mặc định OFF); `save_class_info` sửa được ở Nháp, Từ chối (lớp Đã duyệt bị khoá như các thông tin khác, R-LOP-02); `get_class_record` trả `delivery_mode_code`, `delivery_mode_name`; `enrollment_matching_classes` trả `delivery_mode_code` mỗi lớp. Mã không có trong danh mục: `HMT_DANH_MUC_KHONG_CO`.
- **Xếp lớp lệch hình thức chỉ CẢNH BÁO, không chặn**: ở hộp Xếp lớp (GD-03) lớp Offline nhận ghi danh Online (hoặc ngược lại) hiện dòng nhắc; lớp OMO nhận cả hai. Máy chủ không chặn.
- **Tổ chức lớp** không còn là ô nhập, không cột DB: hiện chữ tự suy từ Phân loại (Lớp riêng = Học riêng, còn lại = Học chung).
- **Tạo lớp còn lại cho nhóm này** (hồ sơ lớp): mở màn Tạo lớp với nhóm, cơ sở, năm, khối, phân loại điền sẵn; môn, trình độ, giáo viên, lịch để trống; mỗi lớp trong nhóm vẫn độc lập (R-LOP-14). Không migration.
- **Xem trước ngày kết thúc dự kiến**: `preview_class_end_date` (security definer, chỉ đọc) tính từ khung giờ đang nhập, dùng `class_normalize_slots` và `compute_class_schedule` như lúc sinh buổi nên bỏ cả ngày nghỉ lễ (R-LOP-12). Trả null khi chưa có khung giờ hoặc số buổi; khung sai báo lỗi có mã như lúc lưu.
- Luật R-LOP-14 «kiểm môn theo khối khi tạo lớp» CHƯA quyết, không làm.
- Kiểm thử: pgTAP `574_lop02_03_hinh_thuc_hoc_xem_truoc.test.sql`; Vitest `classForm.test.ts`, `enrollLogic.test.ts`; e2e `lop.spec.ts`.

- **R-LOP-14 kiểm môn theo khối (migration 589)**: `create_class` chặn khi tham số `class_subject_grade_check_enabled` bật: khối từ `algebra_geometry_split_grade` trở lên không tạo lớp chung `TOAN`, khối dưới không tạo `DAI`, `HINH`, lớp riêng `LR` được miễn; lỗi `HMT_LOP_MON_SAI_KHOI`. Mặc định TẮT, Admin bật khi go-live. Kiểm thử pgTAP `589_rlop14_kiem_mon_theo_khoi.test.sql`.
- **R-LOP-07 khung chương trình khi trình lớp (migration 689)**: `transition_class` gọi `assert_class_curriculum` khi trình; tham số `class_curriculum_required_enabled` bật thì lớp chung chưa có khung không trình được (`HMT_LOP_THIEU_KHUNG_CHUONG_TRINH`), lớp riêng `LR` được miễn, lưu nháp không bị chặn. Mặc định TẮT, Admin bật khi go-live. Khi bật, nạp lớp từ Sheet và dữ liệu mẫu không có khung cũng bị chặn. Kiểm thử pgTAP `689_rlop07_khung_bat_buoc_khi_trinh.test.sql`.

**Nhãn buổi học bù, bổ trợ (A-23-18, G18, migration 630).** `app.renumber_class_sessions` chỉ đánh «Buổi N» cho buổi mà `app.session_type_numbered(loại)` trả đúng (mọi loại trừ HOC_BU, BO_TRO; củng cố, kiểm tra vẫn chiếm số). Buổi bù, bổ trợ có `session_no` null, giao diện hiện tên loại buổi (danh mục SESSION_TYPE). `session_cancel_preview` và `generate_class_sessions` dùng chung quy tắc này. Trừ giờ, chốt tháng, sổ giờ không dùng `session_no`.

**Done ngay khi giáo viên lưu bước cuối (A-23-12, migration 624, QĐ-Đ294).** `app.complete_session_if_ready(buổi)` (nội bộ, không ai gọi trực tiếp) được `set_attendance_teacher`, `save_session_content`, `save_review_grading`, `save_homework_grading`, `save_exam_grading` gọi ở cuối: khoá buổi; Đã chốt và `session_pending_reason` trống thì gọi `mark_session_done` (trừ giờ một lần, đóng dấu Đúng/Trễ hạn). Chưa đủ, chưa hết giờ hoặc đã Done thì không làm gì. Lỗi (vd. `HMT_QUY_GIO_AM`) được bắt: lưu của giáo viên vẫn thành công, buổi giữ Đã chốt, lỗi ghi `app.session_auto_done_error`. Lịch tự Done vẫn chạy cho buổi còn lại.

**LOP-09 một dòng mỗi em (A-23-13, migration 624).** `app.list_class_students` và `app.class_student_group_counts` chỉ giữ một dòng đang học mỗi em trong lớp (ghi danh cũ nhất); `hours_left` là tổng giờ còn của các ghi danh còn hiệu lực của em trong lớp. Trừ giờ buổi: `build_session_roster` chọn ghi danh cũ nhất đủ giờ cho cả buổi (R-GIO-04).

## Hai cột điểm danh (migration 685, DD1 phần 1, anh Trường duyệt 26/11)

Luật: R-DD-02 đến R-DD-05.

| Hàm | Thay đổi |
| --- | --- |
| `set_attendance_teacher` | Lưu ô giáo viên thì chép sang ô vận hành khi ô đó trống hoặc còn là ô chép (`ops_source = 'GIAO_VIEN'`); giáo viên bỏ trống thì ô chép trống theo. Ô vận hành tự ghi không bị đè |
| `set_attendance_ops` | Mỗi dòng chỉ ghi khoá được gửi (`status_code`, `contact_reason_code`, `note`). Trạng thái khác giá trị đang có thì thành ô vận hành tự ghi (`ops_source = 'VAN_HANH'`, kèm người và giờ) |
| `write_attendance_ops` | Nội bộ: ghi một dòng phía vận hành |
| `upsale_candidates`, `get_upsale_ticket`, view `report.class_attendance` | Số buổi vắng, chuyên cần chỉ đọc cột giáo viên |

`absent_today_list` và `absent_today_group_counts` (gọi nhắc trong ngày) vẫn đọc cả cột vận hành. Buổi giáo viên đã ghi trước migration này không được chép bù. Điều kiện Done mới (khớp hai cột, Done tay) thuộc phần 2.

## Điều kiện Done, Done tay, Done hàng loạt, nhập thay (C-26-05 PR-DD2, migration 686–688)

Luật R-GIO-06, 07, 09, 11, 12; R-GV-05. Sổ giờ (`deduct_session_hours`) không đổi.

| Hàm | Ai gọi | Làm gì |
|---|---|---|
| `finish_session(buổi)` | Điểm danh · Sửa theo phạm vi (giáo viên, trợ giảng của buổi; vận hành, quản lý cơ sở, Admin) | Done tay. Đủ điều kiện thì Done; chưa đủ thì trả `{done:false, missing:[…]}` |
| `bulk_finish_sessions(buổi[], lý do)` | Điểm danh · Duyệt ở cơ sở của từng buổi | Done hàng loạt; trả `{done, skipped:[{session_id, class_code, session_no, reason}]}`. Số buổi tối đa: tham số `session_bulk_done_max` |
| `enter_for_teacher(buổi, loại, dữ liệu, lý do)` | Điểm danh · Duyệt | Nhập thay `DIEM_DANH`, `NHAN_XET`, `DIEM`, `BTVN` khi buổi chưa Done; ghi `session_proxy_entry` |
| `session_done_info(buổi)` | Buổi · Xem phía vận hành (như `session_record`) | Cho BUOI-02 (mig 692): cách hoàn tất, người bấm, lý do, cờ Thiếu nhận xét, điều còn thiếu, các lượt nhập thay (mig 698: chỉ người có Điểm danh · Duyệt thấy) |

- Điều kiện Done thêm: ô vận hành bằng ô giáo viên ở mọi dòng. `session_pending_reason` trả **mọi** điều còn thiếu, nối bằng dấu cách. Vận hành sửa cho khớp thì Done ngay.
- Dấu Đúng hạn hoặc Trễ hạn đóng khi phần giáo viên đủ (`stamp_teacher_completion`), không chờ khớp; đóng một lần.
- `class_session`: `done_mode` (`TU_DONG`, `TAY`, `HANG_LOAT`), `done_by`, `done_reason`, `done_missing_review` (cờ Thiếu nhận xét).
- Người không phải giáo viên, trợ giảng của buổi không gọi thẳng được hàm ghi điểm danh, nhận xét, điểm, chấm BTVN (`HMT_CAN_NHAP_THAY`).
- Nội bộ: `session_teacher_missing`, `session_review_missing`, `session_missing`, `apply_session_done`, `bulk_finish_one`, `assert_bulk_finish_input`, `assert_teacher_or_proxy`, `apply_proxy_entry`.
