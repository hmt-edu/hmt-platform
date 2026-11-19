# QT-09 Lịch sử thay đổi tham số

Hàm `app.list_setting_history(p_key, p_limit, p_offset)` (migration 480): chỉ người có Quản trị · Xem (Admin, đã xác thực hai bước); đọc, không ghi (S03-12). Mới nhất trước, phân trang ở máy chủ; `p_key` trống = mọi tham số.

- Dòng hiện: lần đổi giá trị chung (`setting_def.value`), lần tạo, đổi giá trị, bỏ hoặc bật lại ghi đè theo cơ sở (`setting_branch`). Kết quả: `{total, rows:[{id, at, setting_key, branch_code, action, old_value, new_value, actor_name}]}`.
- Nhật ký chỉ ghi «đã tạo» khi tạo ghi đè, nên dòng tạo ghi đè không có giá trị mới (giao diện hiện «—»). Lần khai báo ban đầu bằng migration không có dòng nhật ký.
- Không thêm chỉ mục: dùng `audit_log_record_idx` và `audit_log_at_idx` (migration 550).

Màn: `/crm/quan-tri/tham-so` (QT-09): nút «Lịch sử» ở mỗi dòng xem một tham số; nút «Lịch sử thay đổi» ở đầu trang xem mọi tham số (canvas `QT09_lich_su` chỉ vẽ hộp theo một tham số). So canvas QT09_lich_su: khớp cột Lúc, Ai sửa, Phạm vi, Giá trị cũ, Giá trị mới, phân trang, nút Đóng. pgTAP: `supabase/tests/database/480_qt09_list_setting_history.test.sql`.
