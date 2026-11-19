# Cổng Giáo viên và cấu hình rubric: hàm và chính sách của lane E (migration 500 đến 511; 508 huỷ lead xem `tuyen-sinh.md`)

Cập nhật theo CLAUDE.md mục 8. Hàm ở schema `app`, giao diện gọi qua `rpc`. Hàm chỉ đọc trừ khi cột «Làm gì» ghi là ghi, sửa, tạo.

| Migration | Hàm / chính sách | Làm gì | Ai gọi | Luật |
|---|---|---|---|---|
| 500 | `app.teacher_my_pending_tests(p_limit)` | Danh sách phiếu kiểm tra đầu vào ở trạng thái Chờ giáo viên chấm mà người gọi là giáo viên chấm; cũ nhất trước; tối đa 100 dòng. Mục «Phiếu test chờ chấm» của GV-12. | Người có quyền Xem phiếu kiểm tra (giáo viên) | R-CRM-11, R-GV-08, R-GV-13 |
| 500 | `app.teacher_test_sheet(p_id)` | Đọc một phiếu cho màn GV-15 (tên em, môn, khối, hình thức, cấp độ đề, giờ làm, phòng, kết quả đã nhập, danh mục trình độ và phân loại). Không có điện thoại, phụ huynh, học phí. Chỉ phiếu của chính giáo viên chấm, ở trạng thái Chờ chấm hoặc Hoàn thành; còn lại cùng một lỗi `HMT_KHONG_CO_QUYEN`. | Giáo viên chấm của phiếu | R-CRM-11, R-GV-08, R-GV-13 |
| 500 | (ghi dùng lại) `app.enter_test_result`, `app.complete_student_test` | GV-15: «Lưu» là lưu nháp; «Trả về sale» là lưu rồi hoàn thành. Hai hàm tự kiểm quyền Sửa và trạng thái. | Giáo viên chấm | R-CRM-10, R-CRM-11 |
| 501 | `app.student_assigned_to_me(p_student_id)` | Đúng khi em đang ghi danh (chưa kết thúc) ở lớp mà người gọi được phân công. Dùng trong RLS. | Chính sách RLS | R-GV-13, R-GV-08 |
| 501 | Chính sách `student_read` (bảng `app.student`) | TOAN_HE_THONG thấy hết; DUOC_PHAN_CONG (giáo viên, trợ giảng) chỉ thấy em lớp mình; phạm vi khác (CO_SO) như cũ. Sửa lỗi giáo viên đọc mọi học sinh cơ sở (Soát Q9). | Mọi người đã đăng nhập | R-GV-13 |
| 502 | `app.can_see_note_target` (nhánh STUDENT) | DUOC_PHAN_CONG chỉ thấy ghi chú của em lớp mình (Soát G1). | Chính sách ghi chú | R-GV-13 |

| 503 | `app.review_rubric_version` (bảng) | Phiên bản rubric nhận xét theo BỘ tiêu chí (TOAN gồm Toán, Đại số, Hình học; MON_PHU các môn còn lại); mỗi bộ đúng một bản Đang dùng. Chỉ đọc cho người xem được điểm danh; ghi qua hàm. | RLS đọc (quyền Điểm danh · Xem) | R-GV-01, R-V2-19, S03-10 |
| 503 | `app.review_level_desc` (thêm cột `version_id`) | Mô tả mức 1 đến 5 thuộc một phiên bản; bộ Thái độ (chung mọi môn) nằm ở cả hai bản. | RLS đọc | R-V2-19, Q-190 |
| 503 | `app.open_session_review(buổi)` (viết lại) | Như cũ, thêm chụp phiên bản Đang dùng của bộ môn và mô tả 5 mức vào `session_review_criterion.rubric_version_id`, `level_descs`; sửa rubric sau đó không đổi buổi đã mở. | Giáo viên, trợ giảng của buổi | CH-07 |
| 503 | `app.session_review_sheet(buổi)` (viết lại) | Mô tả mức lấy từ bản chụp của buổi; buổi mở trước CH-07 dùng bản 1 của bộ môn. | Người xem được điểm danh của buổi | R-V2-19, Q-190 |
| 503 | `app.get_rubric(p_subject_set, p_version_id)` | Đọc rubric của một bộ và phiên bản (mặc định bản Đang dùng): danh sách phiên bản, tiêu chí, mô tả 5 mức. | Admin (Quản trị · Xem) | CH-07 |
| 503 | `app.update_review_level_desc(...)` | Sửa một mô tả mức của bản Đang dùng; bản Ngừng chỉ xem (`HMT_RUBRIC_BAN_NGUNG`); không rỗng; mức 1–5. | Admin (Quản trị · Sửa) | CH-07 |
| 503 | `app.create_rubric_version(p_subject_set, p_note)` | Tạo phiên bản mới = sao chép bản Đang dùng, bản cũ chuyển Ngừng; một giao dịch, khoá bản đang dùng. | Admin | CH-07, S03-10 |
| 503 | `app.set_review_criterion_active(id, p_active)` | Ngừng hoặc Dùng lại một tiêu chí (không xoá); mỗi nhóm của mỗi bộ còn ít nhất một tiêu chí (`HMT_RUBRIC_NHOM_TRONG`). Chưa có nút ở giao diện (khung không vẽ). | Admin | CH-07 |
| 504 | `app.update_review_level_descs(p_version_id, p_items)` | Lưu nhiều mô tả mức trong MỘT giao dịch (màn Sửa lưu cả bảng); gọi lại hàm một ô, một ô sai thì quay lại cả lần. | Admin | CH-07 |
| 506 | `app.get_parent_phrases()`, `app.update_parent_phrases(p_items)` | Đọc và sửa 24 câu mẫu lời nhắn phụ huynh (loại buổi × mức 1–4 × 3 câu) của `app.parent_phrase`; chỉ sửa câu có sẵn, không thêm bớt, không để trống. Canvas CH07_cau_mau vẽ theo tiêu chí × mức 1–5 vênh luật: làm theo luật (Chat chốt 18/11). | Admin | R-V2-39 |
| 507 | `app.first_password_change_required(p_account)` | Cờ «phải đổi mật khẩu lần đầu» có hiệu lực không: đúng khi `must_change_password` còn VÀ tham số của loại tài khoản đang Bật (có `student_code` = học sinh, còn lại = nhân viên). Đọc thẳng `setting_def` (quyền chủ DB). Dùng ở `app.current_user_ready` và hook token (`hmt_must_change_password`). | Nội bộ (không cấp cho người dùng) | R-HT-03, CHUNG-07 |
| 507 | Tham số `first_password_change_required_student` (mặc định Tắt), `first_password_change_required_staff` (mặc định Bật) | Học sinh không bắt đổi mật khẩu lần đầu (anh Trường chốt 19/11, E31); nhân viên giữ như cũ. Học sinh tự đổi ở màn tài khoản. Cờ trong bảng giữ nguyên, Bật lại tham số thì áp lại. | Admin đổi ở Tham số nghiệp vụ | R-HT-03 |


Màn CH-07 `/crm/cau-hinh/rubric` (chỉ Admin, máy tính): tab «Mô tả mức» (chọn Môn, Phiên bản; Sửa/Lưu/Huỷ; Tạo phiên bản) và tab «Câu mẫu lời nhắn phụ huynh». Chữ mô tả mức nạp ở migration 103 là chữ mẫu, chờ sheet Rubric chính thức.
| 509 | `app.can_see_note_target` (thêm hai nhánh) + loại ghi chú `ENROLLMENT`, `CLASS_SESSION` | Cột «Ghi chú và hoạt động» cho Ghi danh (GD-02) và Buổi học (BUOI-02): ghi chú, nhắc tên, lịch sử thay đổi | CSKH, Trưởng cơ sở, Admin theo quyền Xem của phân hệ ở cơ sở của bản ghi; giáo viên (được phân công) không đọc | E61, R-GV-13, CHUNG-22 |
| 510 | `app.enrollment_same_class_peers(p_id)` | Chỉ đọc: các ghi danh khác của cùng học sinh ở cùng lớp hiện tại, giờ còn từng ghi danh và tổng giờ còn của lớp (khối «Em có N ghi danh ở lớp này», GD-02) | Người có quyền Ghi danh · Xem trong phạm vi cơ sở; giáo viên không đọc | E63, R-GV-13 |
| 511 | `app.can_see_note_target` (thêm nhánh `CLASS`) + loại ghi chú `CLASS` | Cột «Ghi chú và hoạt động» cho Lớp (LOP-02): ghi chú, nhắc tên, lịch sử thay đổi; sự kiện của lớp (Tạo, Sửa, Trình…) trộn vào dòng thời gian | Người có quyền Lớp · Xem ở cơ sở của lớp; giáo viên (được phân công) không đọc | E64, CHUNG-22 |

Bài pgTAP: `500`, `501`, `502` (lane E giáo viên), `503` (rubric, kèm 504 và 506), `507` (đổi mật khẩu lần đầu theo tham số), `509` (ghi chú ghi danh và buổi), `510` (ghi danh cùng lớp), `511` (ghi chú lớp), `104` (đã sửa để đếm cặp tiêu chí-mức theo phiên bản).

Màn: GV-12 mục phiếu test (`/gv/viec-can-lam`), GV-15 (`/gv/phieu-test/:testId`). Chưa làm: ô «Lớp đề xuất» của GV-15 (bảng phiếu chưa có cột).
