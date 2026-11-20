# Đào tạo (Code A): cụm buổi, yêu cầu buổi, cổng giáo viên (migration 134 đến 144)

Cập nhật theo quy ước «docs/nghiep-vu liệt kê các hàm nghiệp vụ, cập nhật cùng PR» (bổ sung một lần cho các PR của Code A đã gộp). Dữ liệu và ví dụ đều giả. Luật: `docs/spec/04-luat-nghiep-vu.md` (mục 3 đến 7), `docs/spec/de-xuat-luat-a.md` (BUOI-15, GD-07 đã chốt).

## Phân hệ (cờ theo cơ sở, mặc định TẮT)

| Mã cờ                  | Bật gì                                                       | Migration |
| ---------------------- | ------------------------------------------------------------ | --------- |
| `YEU_CAU_BUOI`         | Yêu cầu buổi củng cố, học bổ trợ, học bù (BUOI-07..10)      | 139       |
| `SAP_HET_GIO`          | Danh sách dự báo Sắp hết giờ (GD-07)                         | 142       |
| `DIEM_DANH_TRONG_NGAY` | Danh sách theo dõi điểm danh các buổi trong ngày (BUOI-15)   | 143       |
| `HOC_THU`              | Thêm học thử vào buổi Đã chốt (BUOI-06)                       | 145       |
| `AFTERSALE` (đã có)    | Cổng giáo viên tạo và xem ticket (GV-14) qua hàm migration 144 | 156       |

## Hàm giao diện được gọi (kiểm quyền và cờ bên trong)

| Hàm                                                                                    | Ai                                             | Luật                                            |
| -------------------------------------------------------------------------------------- | ---------------------------------------------- | ----------------------------------------------- |
| `change_session_staff(buổi, giáo viên, trợ giảng)` (134), `session_record(buổi)` (136)   | Buổi học · Sửa (BUOI-13)                       | R-GV-14 (giờ dạy tính cho người dạy thật)       |
| `mark_session_done(buổi)`, `session_overview(buổi)` (135)                              | Giáo viên, vận hành                            | R-GV-06 (dấu Đúng hạn, Trễ hạn lúc Done)         |
| `teacher_student_profile(lớp, học sinh)` (137)                                         | Giáo viên, trợ giảng của lớp                   | R-GV-08, GV-13 hồ sơ rút gọn                    |
| `teacher_my_hours(tháng)` (138)                                                        | Giáo viên, trợ giảng (chỉ buổi của mình)       | R-GV-14, GV-16                                  |
| `save_session_request(...)`, `submit_session_request`, `cancel_session_request` (139)  | Buổi học · Tạo (CSKH)                          | R-BUOI-04 củng cố                               |
| `approve_session_request(yêu cầu)`, `reject_session_request(yêu cầu, lý do, ghi chú)`   | Buổi học · Duyệt (Trưởng cơ sở, Admin)         | R-BUOI-03, 04, 05, 10; R-HT-01, 04              |
| `list_session_requests(bộ lọc, giới hạn, vị trí)`                                      | Buổi học · Xem                                 | R-BUOI-03..05; phân trang ở máy chủ             |
| `save_support_request(...)` (140)                                                      | Buổi học · Tạo, tạo từ lớp                     | R-BUOI-05 (không trừ giờ, tính giờ dạy)         |
| `save_makeup_request(...)` (141)                                                       | Buổi học · Tạo, lý do bắt buộc                 | R-BUOI-03 (sinh buổi MỚI loại Học bù)           |
| `build_session_roster(buổi)` (mở rộng ở 140, 141)                                      | Hệ thống khi Chốt danh sách                    | R-GIO-02..04; buổi bổ trợ, học bù chỉ gồm em được chọn |
| `list_expiring_enrollments(bộ lọc, giới hạn, vị trí)` (142, 590: thêm «Sắp hết hạn gói»)                          | Ghi danh · Xem (cơ sở), cờ `SAP_HET_GIO`       | R-GD-07 (hạn gói chỉ dự báo), ngưỡng `upsale_*` |
| `session_day_attendance(bộ lọc, giới hạn, vị trí)` (143)                               | Buổi học · Xem (cơ sở), cờ `DIEM_DANH_TRONG_NGAY` | R-DD-01..03, R-GIO-02..04, R-GIO-08           |
| `add_trial_student(buổi, dòng em của cơ hội)` (145)                                    | Buổi học · Sửa (cơ sở), cờ `HOC_THU`            | R-GD-11, R-GD-17, R-CRM-03, R-CRM-27           |
| `teacher_ticket_options()`, `teacher_create_ticket(dữ liệu)`, `teacher_class_tickets(giới hạn, vị trí)` (144) | Giáo viên, trợ giảng, cờ `AFTERSALE` | R-CS-10, AS-05, AS-09, AS-13                    |

## Bảng thêm

| Bảng                              | Việc                                                                                           | Migration |
| --------------------------------- | ---------------------------------------------------------------------------------------------- | --------- |
| `app.session_request`             | Yêu cầu buổi (củng cố, bổ trợ, học bù); mã `YB-<CS>-<YYMM>-<số>`; RLS đọc theo quyền xem buổi | 139, 140, 141 |
| `app.session_request_student`     | Các em được chọn của yêu cầu bổ trợ, học bù (không xoá cứng: em bị bỏ thì `is_active=false`)    | 140       |

## Việc làm nhanh khi gặp lỗi

- Duyệt yêu cầu báo `HMT_NGAY_BUOI_QUA_KHU`: ngày buổi đã qua, sửa ngày rồi gửi lại.
- Danh sách báo `HMT_TINH_NANG_TAT`: cờ của phân hệ chưa bật ở cơ sở (Cấu hình > Công tắc tính năng, QT-10).
