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
