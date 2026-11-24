# LMS giao bài (GV-17), phần DB: migration 597

Hàm và bảng của phần giao bài. Đề xuất đã duyệt (Chat 02:29): `de-xuat-db-lms-gv17-gv18.md`. Lưu tệp theo phương án B (chưa bật R2): bảng tệp có sẵn cột `storage_key`, chưa có hàm ghi tệp. Phần chấm bài (migration 598) và nộp bài của học sinh (HT-05) làm sau.

## Bảng (RLS bật, đọc theo phạm vi buổi giao `app.session_visible`, ghi chỉ qua hàm)
`lms_assignment` (bài giao, chụp hạn, hai công tắc lúc giao, `version`), `lms_assignment_target` (em nhận bài), `lms_assignment_file` (tệp đề, ≤ 10 MB), `lms_submission` (bài nộp, một dòng mỗi em mỗi bài), `lms_submission_file` (trang bài nộp, ≤ 20 trang). Không xoá cứng: Gỡ bài = `DA_GO`.

## Hàm (đều kiểm quyền Điểm danh theo ma trận sẵn có, Q14, và công tắc tính năng HOC_TAP)
| Hàm | Làm gì | Lỗi chính |
|---|---|---|
| `app.lms_create_assignment(p_data jsonb)` | Giao bài cho cả lớp hoặc từng em; hạn mặc định = giờ vào buổi sau (R-LMS-01) | `HMT_LMS_CAN_HAN_NOP` (không có buổi sau, Q10), `HMT_LMS_HAN_TRONG_QUA_KHU`, `HMT_LMS_THIEU_TIEU_DE`, `HMT_LMS_THIEU_MO_TA`, `HMT_LMS_CHUA_CHON_EM`, `HMT_LMS_EM_KHONG_TRONG_LOP` (Q11), `HMT_LMS_BUOI_KHONG_GIAO_DUOC` |
| `app.lms_update_assignment(p_id, p_data, p_version)` | Sửa; đã có em nộp thì khoá tiêu đề, mô tả, chỉ đổi hạn và công tắc (Q2) | `HMT_XUNG_DOT`, `HMT_LMS_DA_CO_BAI_NOP`, `HMT_LMS_DA_GO` |
| `app.lms_withdraw_assignment(p_id, p_version)` | Gỡ bài, chỉ khi chưa em nào nộp (Q2) | `HMT_LMS_DA_CO_BAI_NOP`, `HMT_LMS_DA_GO`, `HMT_XUNG_DOT` |
| `app.lms_list_assignments(p_class_id, p_limit, p_offset)` | «Bài đã giao» của lớp: số em nhận, đã nộp, đã chấm; phân trang máy chủ ≤ 100 | `HMT_KHONG_CO_QUYEN` |

Mặc định công tắc: Cho nộp lại BẬT, Nhận bài muộn TẮT (Q4). Chưa gửi thông báo cho em nhận khi sửa (làm cùng cổng học sinh).

## Ghi chú quyền cần Chat biết
Ma trận hiện có cho vai SALES (Xem, theo cơ sở) và MARKETING (Xem, toàn hệ thống) quyền Xem Điểm danh, nên cùng phạm vi đó đọc được bài giao (tiêu đề, mô tả), giống như đọc buổi học. Giáo viên chỉ đọc bài của lớp mình dạy. Nếu muốn chặn Sale, Marketing đọc bài giao thì cần mã quyền riêng (ngoài Q14), xin Chat quyết.

## Migration 598: chấm bài nộp (GV-18)
Điểm và trạng thái ghi vào `app.homework_result` của **buổi giao** (không bảng điểm thứ hai, Q1); `lms_submission.graded_at` là dấu «đã chấm» (khoá bài nộp, R-LMS-03). Chưa có hàm nộp bài của học sinh (HT-05).
| Hàm | Làm gì | Lỗi chính |
|---|---|---|
| `app.lms_grading_list(p_assignment_id, p_filter)` | Danh sách em của bài: trạng thái nộp (Chưa nộp, Đã nộp, nhãn Nộp muộn), trạng thái chấm; lọc `CHUA_CHAM` / `DA_CHAM`; tiến độ đã chấm x/y | `HMT_THAM_SO_SAI` |
| `app.lms_grading_sheet(p_assignment_id, p_student_id)` | Phiếu chấm một em: các trang bài nộp, điểm hiện có (kèm `version`), các trạng thái được chọn và trạng thái gợi ý (em vắng buổi giao chưa nộp: Không áp dụng, Q6) | `HMT_LMS_EM_KHONG_NHAN_BAI` |
| `app.lms_save_grade(p_assignment_id, p_student_id, p_status, p_score, p_note, p_version)` | Lưu trạng thái, điểm 1–5, ghi chú; Không làm, Nộp sau, Không áp dụng thì bỏ điểm (Q5); em chưa nộp: chỉ Nộp sau, Không làm (vắng: thêm Không áp dụng); «Nộp sau» chưa đóng dấu đã chấm | `HMT_DIEM_KHONG_HOP_LE`, `HMT_LMS_CHUA_NOP_BAI`, `HMT_XUNG_DOT`, `HMT_LMS_DA_GO`, `HMT_LMS_EM_KHONG_NHAN_BAI` |
| `app.lms_reopen_submission(p_assignment_id, p_student_id)` | Mở lại bài đã chấm để em nộp lại (R-LMS-03; UI hỏi xác nhận, Q12); điểm cũ giữ đến khi chấm lại | `HMT_LMS_CHUA_CHAM`, `HMT_LMS_DA_GO` |
| `app.lms_submit_assignment(p_assignment_id, p_file_ids uuid[])` | Học sinh chốt lần nộp (HT-04/HT-05, migration 670): gắn ảnh/tệp đã tải (`stored_file`, thứ tự = số trang) vào bài nộp; ghi `submitted_at`, nhãn `is_late`, tăng `attempt_count`; mỗi lần nộp giữ bộ trang riêng (`lms_submission_file.attempt`, không xoá bộ cũ). Chỉ chính học sinh (phụ huynh, giáo viên, em khác bị chặn); R-LMS-02 quá hạn khi tắt nhận muộn; R-LMS-03 đã chấm khoá, không cho nộp lại; R-LMS-04 tối đa N trang (tham số `file_max_pages_per_submission`, mặc định 20, migration 671) | `HMT_KHONG_CO_QUYEN`, `HMT_TINH_NANG_TAT`, `HMT_LMS_BAI_DA_GO`, `HMT_LMS_QUA_HAN`, `HMT_LMS_KHONG_NOP_LAI`, `HMT_LMS_DA_CHAM`, `HMT_TEP_THIEU`, `HMT_TEP_QUA_NHIEU`, `HMT_TEP_KHONG_HOP_LE` |
Quyền như migration 597: Xem dùng ATTENDANCE Xem, Chấm và Mở lại dùng ATTENDANCE Sửa (Q14), công tắc HOC_TAP.

## EXPLAIN trên dữ liệu giả lớn (21/11/2026, máy local)
Nạp 20.000 bài giao, khoảng 100.000 dòng em nhận bài, khoảng 50.000 bài nộp (dữ liệu giả, chỉ để thử tốc độ). Cả hai câu chính đều dùng chỉ mục, không quét cả bảng lớn:
- **«Bài đã giao» của một lớp** (`lms_list_assignments`, 50 dòng mới nhất kèm số em nhận, đã nộp, đã chấm): dùng `lms_assignment_class_idx (class_id, created_at desc)` và khoá duy nhất `(assignment_id, student_id)` của bảng em nhận, bài nộp; **7,4 ms** thực thi.
- **Danh sách em của một bài** (`lms_grading_list`): dùng khoá duy nhất `(assignment_id, student_id)` của `lms_assignment_target` và `lms_submission`, khoá chính `lms_assignment`; **0,5 ms** thực thi.
