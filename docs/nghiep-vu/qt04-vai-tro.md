# QT-04 Vai trò, danh sách và mô tả (migration 183, chỉ đọc)

Trang `/crm/quan-tri/vai-tro` (chỉ Admin, máy tính), luật S03-06: các vai trò hệ thống và phạm vi mặc định, kèm cổng vào (CRM, Giáo viên, Học tập; «chỉ xem» với cổng chỉ xem), hai bước (bắt buộc hay không), nhóm tự đăng xuất, số người đang dùng và số ô quyền đang bật; nút «Mở ma trận» sang QT-05 (`?vai-tro=<mã>`).
Hàm `app.list_roles_summary()` (migration 183): chỉ người có Quản trị · Xem; đọc, không ghi; mỗi lần gọi một câu trả về cả 12 vai trò. Số người đếm theo `user_role` đang bật và tài khoản không bị khoá.
**Không làm:** thêm, sửa, ngừng vai trò (vai trò là danh mục hệ thống; thêm vai trò mới đi qua migration và QT-05). **Thiếu khuôn:** không có khung canvas riêng cho QT-04 (BAN-DO-VIEC ghi «Thiếu khung canvas»); dựng từ khuôn K10 và thành phần dùng chung, chữ lấy từ bản đồ màn hình.
**Liên quan:** QT-05 (PR #43) đọc `?vai-tro=` để chọn sẵn vai trò; chưa có trong #43, thêm ở PR sau khi #43 vào `main`.
