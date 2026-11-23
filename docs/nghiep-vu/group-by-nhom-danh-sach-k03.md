# Group By cho các danh sách K03 còn thiếu (migration 614)

Thư Chat 12:18 (đổi số 13:47: 606 thành 614), theo canvas 9933 và `docs/nghiep-vu/doi-chieu-group-by.md`. Một migration gộp, mức CAO theo quy ước; chỉ đọc, không đổi bảng, không thêm chỉ mục. Mọi hàm đếm: tối đa hai cấp khác nhau (Đ35), quyền và bộ lọc giống hàm danh sách tương ứng.

| Màn | Hàm đếm | Trường nhóm | Mở nhóm bằng |
|---|---|---|---|
| KH-04 Học sinh | `app.student_group_counts` | `status` (Tiềm năng, Đang học, Bảo lưu, Dừng học), `grade`, `branch` (cơ sở tiếp nhận) | bộ lọc sẵn của `list_students` |
| LOP-09 Học sinh của lớp | `app.class_student_group_counts(lớp, …)` | `state` (Đang học, Đã rời), `branch` (cơ sở phụ trách), `delivery` | `list_class_students` thêm `branch_id` |
| GD-07 Sắp hết giờ | `app.expiring_group_counts` | `status` (Hết giờ, Sắp hết giờ, Sắp hết hạn gói, Quá hạn gói còn giờ) | bộ lọc sẵn `status` |
| BUOI-12 Buổi chưa Done | `app.session_pending_group_counts` | `teacher` (giáo viên phụ trách) | `session_pending_list` thêm `teacher_id` |
| BUOI-11 Điểm danh trong ngày | `app.absent_today_group_counts` | `status` (Vắng, Chưa tới) | bộ lọc sẵn `kind` |

- GD-07: phần tính tình trạng tách thành `app.expiring_enrollment_rows` (hàm trong) dùng chung cho danh sách và đếm nên hai bên không thể lệch nhau; `list_expiring_enrollments` kết quả không đổi.
- **GD-06 Hàng chờ xếp lớp:** không nằm trong migration này; Code A làm riêng (migration 615, cột «Lý do chờ» thật theo canvas) để hai bên không trùng việc ở cùng danh sách.
- **Không làm:** BUOI-10 Yêu cầu buổi (chưa dùng khuôn K03, cần chuyển khuôn trước), BUOI-13, BUOI-14, TC-09 (hộp thoại K08) và LOP-08 (Lịch K05): không có danh sách để nhóm.
- Bài pgTAP `614a` đến `614f` trừ `614c` (dựng theo test 117, 477, 590, 123, 120): đếm từng nhóm, nhãn, số đếm khớp danh sách, phạm vi, chặn trường lạ, hai cấp trùng, quyền.
