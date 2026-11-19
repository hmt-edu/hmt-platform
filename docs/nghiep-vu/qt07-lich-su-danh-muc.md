# QT-07 Lịch sử thay đổi danh mục

Hàm `app.list_catalog_history(p_root_code, p_limit, p_offset)` (migration 481): chỉ người có Quản trị · Xem (Admin, đã xác thực hai bước); đọc, không ghi (S03-12). Mới nhất trước, phân trang ở máy chủ. Gồm mục của danh mục gốc và các cấp con (theo `parent_catalog`).

- Dòng hiện: tạo mục, đổi tên, Ngừng/Dùng lại, đổi thứ tự (cột `name`, `is_active`, `sort_order` của `catalog_item`). Mã không đổi, không xoá nên không có dòng Xoá.
- Kết quả: `{total, rows:[{id, at, catalog_code, item_code, item_name, action, changes, actor_name}]}`.
- Không thêm chỉ mục: dùng `audit_log_record_idx` (table_id, record_id, at) và unique (catalog_code, code) có sẵn.

Màn: `/crm/quan-tri/danh-muc` (QT-07): nút «Lịch sử thay đổi» ở đầu trang mở hộp lịch sử của danh mục đang chọn. So canvas: canvas dc47 chỉ vẽ nút «Lịch sử thay đổi» (mờ), không có khung hộp: hộp dựng theo khuôn hộp lịch sử QT09_lich_su (Lúc, Ai sửa, Mục, Thay đổi). pgTAP: `supabase/tests/database/481_qt07_list_catalog_history.test.sql`.
