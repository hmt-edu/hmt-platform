# Cổng Giáo viên: hàm và chính sách của lane E (migration 500 trở đi)

Cập nhật theo CLAUDE.md mục 8. Hàm ở schema `app`, giao diện gọi qua `rpc`. Mọi hàm đều chỉ đọc trừ khi ghi rõ.

| Migration | Hàm / chính sách | Làm gì | Ai gọi | Luật |
|---|---|---|---|---|
| 500 | `app.teacher_my_pending_tests(p_limit)` | Danh sách phiếu kiểm tra đầu vào ở trạng thái Chờ giáo viên chấm mà người gọi là giáo viên chấm; cũ nhất trước; tối đa 100 dòng. Mục «Phiếu test chờ chấm» của GV-12. | Người có quyền Xem phiếu kiểm tra (giáo viên) | R-CRM-11, R-GV-08, R-GV-13 |
| 500 | `app.teacher_test_sheet(p_id)` | Đọc một phiếu cho màn GV-15 (tên em, môn, khối, hình thức, cấp độ đề, giờ làm, phòng, kết quả đã nhập, danh mục trình độ và phân loại). Không có điện thoại, phụ huynh, học phí. Chỉ phiếu của chính giáo viên chấm, ở trạng thái Chờ chấm hoặc Hoàn thành; còn lại cùng một lỗi `HMT_KHONG_CO_QUYEN`. | Giáo viên chấm của phiếu | R-CRM-11, R-GV-08, R-GV-13 |
| 500 | (ghi dùng lại) `app.enter_test_result`, `app.complete_student_test` | GV-15: «Lưu» là lưu nháp; «Trả về sale» là lưu rồi hoàn thành. Hai hàm tự kiểm quyền Sửa và trạng thái. | Giáo viên chấm | R-CRM-10, R-CRM-11 |
| 501 | `app.student_assigned_to_me(p_student_id)` | Đúng khi em đang ghi danh (chưa kết thúc) ở lớp mà người gọi được phân công. Dùng trong RLS. | Chính sách RLS | R-GV-13, R-GV-08 |
| 501 | Chính sách `student_read` (bảng `app.student`) | TOAN_HE_THONG thấy hết; DUOC_PHAN_CONG (giáo viên, trợ giảng) chỉ thấy em lớp mình; phạm vi khác (CO_SO) như cũ. Sửa lỗi giáo viên đọc mọi học sinh cơ sở (Soát Q9). | Mọi người đã đăng nhập | R-GV-13 |
| 502 | `app.can_see_note_target` (nhánh STUDENT) | DUOC_PHAN_CONG chỉ thấy ghi chú của em lớp mình (Soát G1). | Chính sách ghi chú | R-GV-13 |

Màn: GV-12 mục phiếu test (`/gv/viec-can-lam`), GV-15 (`/gv/phieu-test/:testId`). Chưa làm: ô «Lớp đề xuất» của GV-15 (bảng phiếu chưa có cột).
