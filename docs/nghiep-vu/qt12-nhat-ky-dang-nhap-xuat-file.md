# QT-12 Nhật ký đăng nhập và xuất file (migration 551)

Chỉ Admin (Quản trị · Xem, đã xác thực hai bước); mới nhất trước, phân trang ở máy chủ.

- `app.list_login_events(p_filters, p_limit, p_offset)` (S03-18): lọc `q` (tên đăng nhập), `result`, `from`, `to` (to loại trừ). Mỗi dòng có cờ `temp_locked` (đang khoá tạm).
- `app.list_export_log(...)` (S03-21): lọc `module`, `user`, `from`, `to`.
- `app.unlock_temp_login(p_user_id)`: Admin (Quản trị · Sửa) xoá bộ đếm sai mật khẩu và mốc khoá tạm. Không mở khoá hẳn (màn Người dùng làm).
- Chỉ mục thêm: `login_event_result_idx (result, at desc)`, `export_log_user_idx (user_id, at desc)`.

Màn `/crm/quan-tri/nhat-ky-dang-nhap`: hai tab. pgTAP `551_qt12_nhat_ky_dang_nhap.test.sql`.
