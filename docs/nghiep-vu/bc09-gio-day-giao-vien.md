# BC-09 Giờ dạy giáo viên, phần đọc (migration 555, Code F)

`app.report_teaching_hours(tháng, cơ sở, số dòng, bỏ qua)` → `{month, total, totals{hours, teachers, assistants, by_type}, rows[{user_id, code, name, role, branch_code, hours, by_type{CHINH, CUNG_CO, HOC_BU, BO_TRO}}]}`.
Quyền Báo cáo · Xem (Kế toán, Admin toàn hệ thống; Trưởng cơ sở chỉ cơ sở mình). Phân trang ở máy chủ, xếp theo mã người dùng.
Luật R-GV-14: buổi Done, mọi loại buổi (gồm Học bổ trợ, R-BUOI-05), theo thời lượng buổi, tính cho người dạy thật (giáo viên và trợ giảng); huỷ (kể cả có tính phí) không tính; tháng theo ngày buổi diễn ra.
**Chưa làm: «Chốt tháng»** (chốt cả hệ thống một lần, khoá, không mở lại, không chốt tháng chưa kết thúc; anh Trường chốt 18/11). Cần bảng chốt và hàm riêng; làm ở PR sau khi Chat giao thẻ.
Hiệu năng: dùng `class_session_date_idx`; 150.000 buổi, 15.000 buổi trong tháng: 100 ms.
