# Đề xuất DB cho LMS: GV-17 Giao bài, GV-18 Chấm bài nộp online (Code E, 21/11/2026)

**Trạng thái: ĐỀ XUẤT, chưa code. Chat duyệt rồi mới làm migration (mức CAO: quyền, dữ liệu học sinh). Số migration từ 597.**
Nguồn: `docs/design/yeu-cau-khung-gv-17-18.md`, canvas bổ sung 20/11 (`GHI_CHU_CHO_CODE.md`, Q1–Q16 Chat đã quyết), `docs/spec/04` R-LMS-01..05, R-GV-10, R-GV-11, R-V2-35.

## 1. Hiện có và còn thiếu
- **Có:** `app.homework_result` (kết quả BTVN từng em theo buổi giao; năm trạng thái, điểm 1–5, `version`), `app.session_content.homework_text` (chữ BTVN, trống = không giao, R-V2-35), module `HOC_TAP` (công tắc tính năng theo cơ sở, mức 4), `app.assert_session_access`, `app.is_assigned_to_class`, `app.session_visible`.
- **Thiếu:** bài giao, người nhận, tệp đề, bài nộp, tệp nộp; hàm giao, sửa, gỡ, nộp, chấm, mở lại; nơi lưu tệp (spec 01: Cloudflare R2, giai đoạn 4; chưa có Edge Function ký địa chỉ tải lên, chưa có tài khoản R2).

## 2. Nguyên tắc
1. **Không tạo bảng điểm thứ hai** (Q1 giữ R-GV-10): trạng thái và điểm chấm ghi vào `homework_result` có sẵn, qua cùng logic kiểm tra của `save_homework_grading` (Q13: thang 1–5, năm trạng thái). Bảng LMS chỉ giữ bài giao và bài nộp.
2. **Quyền:** không thêm mã quyền (Q14). Giao, sửa, chấm dùng `ATTENDANCE` XEM/SUA với phạm vi «được phân công» (giáo viên, trợ giảng của lớp); Gỡ bài, Mở lại theo ma trận hiện có. Mọi hàm kiểm thêm `app.require_feature('HOC_TAP', cơ sở)`.
3. **Chụp cấu hình lúc giao** (CLAUDE.md, cấu hình có hiệu lực): hạn nộp, hai công tắc, danh sách em chụp trong bản ghi bài giao, không tham chiếu cấu hình hiện tại.
4. RLS bật mọi bảng; đọc qua `app.session_visible` / phạm vi lớp; ghi chỉ qua hàm `security definer`. Không xoá cứng (Gỡ bài = đổi trạng thái).
5. Tệp: chỉ lưu **khoá tệp trên R2** (không lưu nội dung trong Supabase Storage); giới hạn 10 MB mỗi tệp, 20 trang mỗi bài nộp (R-LMS-04) kiểm trong hàm.

## 3. Bảng (đều có `id uuid`, `created_at/by`, `updated_at/by`, `audit_log` qua `apply_standard`)
| Bảng | Cột chính | Ghi chú / chỉ mục (lý do) |
|---|---|---|
| `lms_assignment` | `class_id`, `session_id` (buổi giao), `branch_id`, `title`, `description`, `due_at`, `allow_resubmit` (mặc định true, Q4), `allow_late` (mặc định false, Q4), `audience` (`CA_LOP`/`CHON_EM`), `status` (`DANG_GIAO`/`DA_GO`), `version` | chỉ mục lớp, buổi giao, cơ sở (RLS), `(class_id, created_at desc)` cho danh sách «Bài đã giao» |
| `lms_assignment_target` | `assignment_id`, `student_id` | tối thiểu 1 em đang học (Q11); unique `(assignment_id, student_id)`; chỉ mục em (cổng học sinh HT-03 sau này) |
| `lms_assignment_file` | `assignment_id`, `storage_key`, `file_name`, `byte_size`, `mime_type` | `byte_size <= 10 MB` (check); tệp đề bị khoá khi đã có bài nộp (Q2) |
| `lms_submission` | `assignment_id`, `student_id`, `attempt_count`, `submitted_at` (lần nộp gần nhất), `is_late` (nhãn, tính từ `due_at`, R-LMS-02), `graded_at`, `reopened_at`, `version` | unique `(assignment_id, student_id)`; chỉ mục `(assignment_id) where graded_at is null` cho lọc «Chưa chấm» |
| `lms_submission_file` | `submission_id`, `page_no`, `storage_key`, `byte_size`, `mime_type` | tối đa 20 trang; thay thế khi nộp lại (giữ lịch sử qua audit) |

Bài giao liên kết bài tập ở `homework_result` bằng `(buổi giao, em)` như hiện nay: bài LMS giao ở buổi N, chấm ở buổi N+1 (R-GV-10) vẫn ghi vào cùng dòng `homework_result(session_id = buổi giao, student_id)`.

## 4. Hàm (mỗi hàm một việc; lỗi có mã `HMT_…` và câu tiếng Việt)
| Hàm | Làm gì | Luật / quyết định |
|---|---|---|
| `app.lms_create_assignment(p_data jsonb)` | Giao bài: kiểm lớp được phân công, buổi giao thuộc lớp, hạn không trước thời điểm giao, ≥ 1 em đang học; hạn mặc định = giờ vào buổi sau, **không có buổi sau thì bắt buộc nhập hạn tay** (Q10); chụp cấu hình; sinh `lms_assignment_target` | R-LMS-01, Q4, Q10, Q11 |
| `app.lms_update_assignment(p_id, p_data, p_version)` | Sửa: chưa em nào nộp thì sửa tiêu đề, mô tả, hạn, tệp; **có bài nộp** thì tệp cũ khoá, hạn đổi được kèm cảnh báo; chống ghi đè bằng `version` (`HMT_XUNG_DOT`); gửi thông báo cho em nhận (qua `chung12`) | Q2 |
| `app.lms_withdraw_assignment(p_id)` | Gỡ bài (đổi `DA_GO`): **chỉ khi chưa em nào nộp**; quyền theo ma trận | Q2, Q14 |
| `app.lms_list_assignments(p_class_id, p_limit, p_offset)` | «Bài đã giao» của lớp: tiêu đề, hạn, số em đã nộp / tổng, số đã chấm; phân trang máy chủ ≤ 100 | hiệu năng |
| `app.lms_grading_list(p_assignment_id, p_filter)` | Danh sách em của bài: trạng thái nộp (Chưa nộp, Đã nộp; **Nộp muộn là nhãn**), trạng thái chấm, tiến độ x/y; lọc Chưa chấm / Đã chấm | R-LMS-02, Q8 |
| `app.lms_grading_sheet(p_assignment_id, p_student_id)` | Một em: các trang bài nộp (khoá tệp, số lần nộp lại, giờ nộp gần nhất), trạng thái cho phép chọn (em chưa nộp: chỉ Nộp sau hoặc Không làm), em vắng buổi giao: mặc định Không áp dụng, đổi được (Q6) | R-GV-11, Q6 |
| `app.lms_save_grade(p_assignment_id, p_student_id, p_status, p_score, p_note, p_version)` | Ghi vào `homework_result` (cùng kiểm tra điểm theo trạng thái; **chọn Không làm / Nộp sau / Không áp dụng thì bỏ điểm đã chọn**, Q5); đóng dấu `graded_at` (khoá bài nộp, R-LMS-03); `version` chống xung đột | R-GV-11, R-LMS-03, Q5, Q13 |
| `app.lms_reopen_submission(p_assignment_id, p_student_id)` | Mở lại bài đã chấm cho em nộp lại (UI có hộp xác nhận, Q12) | R-LMS-03 |
| `app.lms_submit(p_assignment_id, p_files jsonb)` | **Cổng học sinh HT-03/HT-05: ngoài phạm vi đợt này.** Hàm viết sẵn trong thiết kế để test được `lms_grading_*` với bài nộp giả; chưa gắn giao diện | R-LMS-02..04 |

Tên hàm giao diện gọi qua `rpc`; không tính giờ, hạn, nhãn muộn ở trình duyệt.

## 5. Lưu tệp (cần quyết định)
- **A (đúng spec 01, gói Free):** Edge Function ký địa chỉ tải lên R2 (kiểm quyền giáo viên của lớp, kiểm 10 MB) + địa chỉ xem có hạn; cần anh Trường tạo tài khoản R2 cho staging và dán khoá vào Secrets. Claude Code không giữ khoá.
- **B (tạm):** giao diện hiện «Chưa bật lưu tệp» như `FileUpload` hiện có; GV-17 giao bài chỉ chữ; GV-18 chấm theo bài nộp chữ; cột `storage_key` để sẵn, bật tệp khi có R2.
- **Đề nghị:** làm bảng, hàm, giao diện trước theo B (không phụ thuộc R2), cắm A sau bằng một PR riêng; không đổi cấu trúc DB.

## 6. Thứ tự PR đề nghị
1. (đã gộp #448) thành phần dùng chung: Switch, ProgressBar, FileRow, ChoiceCards, SubmissionViewer.
2. Migration 597+ (bảng + hàm giao, sửa, gỡ, danh sách) + pgTAP quyền theo lớp, đúng/bị chặn mỗi luật; mức CAO.
3. GV-17 giao diện (Bài đã giao, Giao, Sửa, Gỡ) + Vitest + e2e 390 px.
4. Migration (hàm chấm, mở lại) + pgTAP; mức CAO.
5. GV-18 giao diện (danh sách em, chấm bốn bước) + Vitest + e2e.
6. Cắm R2 (nếu chọn A).
