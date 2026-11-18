# Đề xuất chặn tài khoản Học sinh đọc cấu hình nội bộ (Soát R2) — CHỜ CHAT DUYỆT, chưa làm

Code D, 18/11/2026 (thẻ D23). Chỉ là đề xuất; không có migration trong PR này.

## Vấn đề (Soát R2)

Chính sách đọc của một nhóm bảng cấu hình chỉ kiểm «đã đăng nhập, đủ bước xác thực» (`current_user_ready()`, `mfa_satisfied()`), không kiểm vai trò. Vì vậy tài khoản Học sinh (cổng `/hoc`) đọc được toàn bộ cấu hình nội bộ: **73 tham số nghiệp vụ** (ngưỡng khoá đăng nhập, luật mật khẩu, phí hoàn, trần chiết khấu…), **578 ô ma trận quyền**, công tắc tính năng, **642 dòng danh mục**, **25 phòng**, định dạng mã, vai trò. Không lộ dữ liệu cá nhân nhưng lộ cách hệ thống tự vệ và chính sách giá cho người ngoài.

## Bảng và chính sách cần đổi (kiểm kê bằng `pg_policies` trên DB local)

| Bảng | Chính sách | Ai cần đọc | Đề xuất |
| --- | --- | --- | --- |
| `permission`, `role` | `permission_read`, `role_read` | nhân viên (menu theo quyền, màn QT-05) | chỉ vai trò có cổng `crm` hoặc `gv`; Học sinh: không |
| `setting_def`, `setting_branch` | `setting_def_read`, `setting_branch_read` | nhân viên (đọc tham số qua hàm `get_setting`) | chỉ nhân viên; Học sinh đọc qua hàm `student_settings()` trả đúng vài khoá cổng cần (chu kỳ tự đăng xuất, giờ hết phiên) |
| `feature_flag` | `feature_flag_read` | nhân viên; cổng `/hoc` cần biết cờ phân hệ học tập | nhân viên đọc đủ; Học sinh chỉ đọc các cờ có tiền tố học tập (qua hàm hẹp) |
| `catalog`, `catalog_item` | `catalog_read`, `catalog_item_read` | nhân viên (nhãn, danh mục chọn); học sinh cần nhãn môn, khối, trạng thái hiển thị | giữ cho nhân viên; Học sinh chỉ đọc các danh mục hiển thị (môn, khối, loại buổi) |
| `code_format` | `code_format_read` | nhân viên | chỉ nhân viên |
| `room` | `room_read` | nhân viên, giáo viên | nhân viên và giáo viên; Học sinh không (chỉ thấy tên phòng trên lịch qua hàm lịch riêng) |
| `branch`, `academic_year`, `holiday` | `branch_read`, `academic_year_read`, `holiday_read` | mọi vai (cơ sở, năm học, ngày nghỉ hiển thị trên lịch) | **giữ** (không nhạy cảm, cổng cần) |
| `note_target` | `note_target_read` | nhân viên | chỉ nhân viên |

## Cách làm đề xuất

1. Thêm hàm trợ giúp `app.is_staff()` (stable, security definer): người dùng có ít nhất một vai trò đang hoạt động mà `portals` chứa `crm` hoặc `gv`. Một nguồn duy nhất, không lặp luật.
2. Một migration (dải 450–499, số báo Chat) `alter policy ... using ((select app.is_staff()) and ...)` cho các bảng trên (giữ điều kiện cũ và thêm `is_staff`), viết `(select …)` để vẫn là initplan. `branch`, `academic_year`, `holiday` không đổi.
3. Hàm hẹp cho Học sinh: `app.student_portal_config()` trả jsonb gồm vài tham số tự đăng xuất và các danh mục nhãn cần cho `/hoc`; cổng `/hoc` gọi qua `rpc`, không đọc bảng trực tiếp.
4. pgTAP: Học sinh đọc `setting_def`, `permission`, `feature_flag`, `catalog_item`, `room` đều 0 dòng; nhân viên mọi vai (Admin, Trưởng cơ sở, Sales, Kế toán, CSKH, Giáo viên, Trợ giảng) vẫn đọc đủ; `branch`, `holiday` Học sinh vẫn đọc; hàm `student_portal_config()` trả đúng các khoá cho Học sinh.

## Ảnh hưởng

- **Cổng `/hoc`:** hiện chỉ có khung và bốn thẻ giữ chỗ; chưa đọc cấu hình nào nên **chưa hỏng gì**. Màn Học tập (GĐ4) phải dùng `student_portal_config()` thay vì đọc bảng.
- **Nhân viên:** không đổi. Cần kiểm kỹ cổng `gv` (giáo viên đọc `room`, `catalog_item`) vì dùng chung bảng.
- **Phụ huynh** (nếu có cổng sau này): cùng luật với Học sinh (ngoài nhân viên).
- Rủi ro: nếu một vai nhân viên quên có `portals` đúng thì mất quyền đọc cấu hình, hỏng menu. Kiểm bằng pgTAP từng vai trước khi gộp.

## Việc cần Chat quyết

1. Đồng ý hướng `is_staff()` theo `portals` (không theo tên vai trò).
2. Danh sách tham số và danh mục Học sinh được đọc (đề xuất tối thiểu ở trên).
3. Làm trước hay cùng đợt cổng Học tập (Soát đề xuất: trước khi phát tài khoản học sinh).
