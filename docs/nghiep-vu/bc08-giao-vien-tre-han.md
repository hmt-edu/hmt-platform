# BC-08 Giáo viên trễ hạn hằng tháng, phần DB (migration 554, Code F)

`app.report_teacher_late(tháng, cơ sở, số dòng, bỏ qua)` → `{month, total, rows[{user_id, name, branch_code, late_sessions, late_hours, done_sessions}]}`.
Quyền Báo cáo · Xem (Admin, Kế toán toàn hệ thống; Trưởng cơ sở chỉ cơ sở mình, chọn cơ sở khác bị chặn). Chỉ người có buổi trễ; xếp giờ trễ giảm dần; phân trang ở máy chủ.
Luật: R-GV-05, 06 (dấu Đúng hạn/Trễ hạn do hệ thống đóng lúc Done, migration 135), R-GV-14 (tháng theo ngày buổi diễn ra), chỉ báo cáo, không tính vi phạm.
**Lệch cần Chat chốt (R-GV-09):** luật «tính cho người lưu mục cuối cùng» chưa làm được vì DB không lưu người đóng dấu; bản này tính cho cả giáo viên và trợ giảng của buổi (như GV-16). Cần thêm cột người đóng dấu ở `mark_session_done` (lane Code A/E).
Hiệu năng: dùng chỉ mục `class_session_date_idx`; EXPLAIN 150.000 buổi, 15.000 buổi trong tháng: 30 ms.

**Migration 558 (giao diện):** `report_teacher_late` trả thêm mã người (`code`), vai (`role`: GIAO_VIEN hoặc TRO_GIANG) và `totals {people, late_sessions, late_hours}` toàn tháng (cho ba thẻ tổng). `total` vẫn là số dòng (người × cơ sở) để phân trang. Màn: `/crm/bao-cao/giao-vien-tre-han`.
