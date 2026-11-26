# Khách hàng: hàm đọc cho KH-01, KH-02, KH-04, KH-05 (migration 117)

Làm bởi Code 2, 11/11/2026. Chỉ đọc, không có Tạo tay (R-CRM-27). Sửa (KH-03, KH-06), Gộp (KH-07), Xuất CSV (R-CRM-29), ticket, tài khoản học tập: để sau 17/11.

| Hàm                                              | Ai (quyền)                                        | Việc                                                                                                                                      |
| ------------------------------------------------ | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `list_parents(bộ lọc, sắp xếp, limit, offset)`   | Phụ huynh · Xem (phạm vi Toàn hệ thống hoặc Cơ sở, mig 573)                                   | KH-01: tìm theo tên, SĐT, mã; lọc tình trạng (có con đang học), cơ sở tiếp nhận; số con; đang học tại                                      |
| `get_parent_record(phụ huynh)`                   | Phụ huynh · Xem (phạm vi Toàn hệ thống hoặc Cơ sở, mig 573)                                   | KH-02: thông tin, các con, 50 đơn hàng và 50 phiếu thu mới nhất, số đếm cho nút liên kết. Đơn, phiếu thu và số đếm của chúng chỉ gồm phần người gọi được xem (mig 684)                                                   |
| `list_students(bộ lọc, sắp xếp, limit, offset)`  | Học sinh · Xem                                    | KH-04: tìm theo tên, mã, mã cũ; lọc tình trạng, cơ sở, khối; lớp đang học; SĐT phụ huynh                                                   |
| `get_student_record(học sinh)`                   | Học sinh · Xem                                    | KH-05: thông tin, ghi danh và lớp, tổng kết điểm danh, 20 buổi gần nhất, điểm kiểm tra, phiếu kiểm tra đầu vào                             |
| `student_status(học sinh)`                       | nội bộ                                            | Tình trạng tính từ ghi danh: Đang học, Bảo lưu, Dừng, Tiềm năng (S02-TT-HS)                                                                |

Phạm vi: vai trò CRM có Học sinh · Xem toàn hệ thống; giáo viên và trợ giảng (phạm vi được phân công) chỉ thấy học sinh trong lớp của mình và **không thấy số điện thoại phụ huynh** (R-GV-13).
Tình trạng học sinh (**quy tắc hiển thị tạm, chưa vào luật**): 1) có ghi danh Chờ xếp lớp, Đã xếp lớp hoặc Đang học → Đang học; 2) không thuộc (1) và có ghi danh Bảo lưu → Bảo lưu; 3) không thuộc (1), (2) và có ghi danh bất kỳ (Hoàn thành, Chuyển lớp, Dừng, Hoàn phí) → Dừng học; 4) chưa có ghi danh → Tiềm năng. "Có con đang học" của phụ huynh dùng cùng nhóm (1).
