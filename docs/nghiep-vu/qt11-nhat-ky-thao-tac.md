# QT-11 Nhật ký thao tác (migration 550)

Hàm `app.list_audit_log(p_filters, p_limit, p_offset)`: chỉ người có Quản trị · Xem (Admin, đã xác thực hai bước); đọc, không ghi (S03-12). Mới nhất trước, phân trang ở máy chủ. Bộ lọc: `table`, `action` (I, U, D), `actor`, `record_id`, `from`, `to` (mốc `to` loại trừ). Loại thao tác lạ báo `HMT_LOC_KHONG_HOP_LE`. Kết quả `{total, rows}`; mỗi dòng có tên bảng, người thao tác, nội dung đổi `{cột: [cũ, mới]}`.

Chỉ mục thêm: `audit_log_at_idx (at desc, id desc)` cho sắp xếp và lọc ngày; `audit_log_actor_idx (actor, at desc)` cho lọc người thao tác.

Màn: `/crm/quan-tri/nhat-ky` (khuôn K03, chỉ đọc). pgTAP: `supabase/tests/database/550_qt11_list_audit_log.test.sql`.
