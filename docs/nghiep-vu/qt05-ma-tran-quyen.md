# QT-05 Ma trận quyền (migration 182: cờ an toàn)

Trang `/crm/quan-tri/ma-tran-quyen` (chỉ Admin, máy tính), canvas 9933 khung `MaTranQuyen`, `MaTranQuyen_ct`, `MaTranQuyen_ls`. Luật S03-07, S03-10.
Bên trái: các vai trò (đếm số ô đã sửa). Bên phải: lưới phân hệ × hành động của vai trò đang chọn, mỗi ô là một phạm vi dữ liệu (Không có, Toàn hệ thống, Cơ sở mình, Được phân công, Của tôi, Chính mình). Bấm Sửa để đổi (ô đã sửa có viền cam), ghi chú phiên bản tuỳ chọn, Lưu thay đổi.
Lưu qua `app.save_permission_matrix(phiên bản đang xem, danh sách ô đổi, ghi chú)`: DB kiểm phiên bản hiện hành (lỗi `HMT_PHIEN_BAN_CU` khi người khác vừa lưu: hiện câu «Hãy tải lại rồi sửa tiếp»), ô hợp lệ, có ô đổi thật, phân hệ Quản trị chỉ ADMIN. Mỗi lần lưu tạo một phiên bản mới, có hiệu lực ngay, có `permission_change`; màn đọc lại cả quyền của khung (menu, nút).
Lịch sử: 5 phiên bản gần đây kèm tối đa 5 ô đã đổi mỗi phiên bản. Đọc `app.role`, các danh mục `PERM_MODULE`, `PERM_ACTION`, `PERM_SCOPE`, `app.permission` (vài trăm dòng cho cả ma trận, một lần gọi; Admin cần xem toàn bộ), `app.permission_version`, `app.permission_change`.
**Khác khung:** các ô đều sửa được trừ phân hệ Quản trị của vai trò khác Admin (DB chặn); khung vẽ thêm ô mờ «không áp dụng» cho vài cặp (Duyệt ở Phiếu tái tục…), DB không có bảng áp dụng nên màn không làm mờ, DB chấp nhận cấp rồi (luật tiền R-TIEN-01 vẫn do hàm nghiệp vụ kiểm, không do ma trận).
**Chưa làm:** danh sách «Lịch sử thay đổi» đầy đủ phân trang và tên người lưu (cần đọc tài khoản; xem Nhật ký QT-11 chưa dựng); thêm hoặc sửa vai trò (QT-04).
**Rủi ro:** đổi quyền có hiệu lực ngay trên bản chạy thật; màn chỉ Admin, hộp xác nhận là nút «Lưu thay đổi» kèm số ô đã đổi. Cân nhắc thêm hộp xác nhận liệt kê các ô trước khi lưu ở bản sau nếu Chat muốn.

## Bốn điều kiện gộp của Chat (16/11 07:00, mức CAO)
1. **Chỉ Admin lưu, kiểm ở DB:** `save_permission_matrix` gọi `assert_config_writer` (quyền Quản trị · Sửa, đã xác thực hai bước). Có bài pgTAP: Sale bị chặn `HMT_KHONG_CO_QUYEN`.
2. **Không tự khoá hệ thống:** ĐÃ CÓ từ migration 022 (trigger `tg_permission_admin_keeps_admin`: ADMIN luôn giữ đủ quyền phân hệ Quản trị ở toàn hệ thống; lần lưu nào bỏ hoặc thu hẹp thì báo `HMT_ADMIN_GIU_QUYEN_QUAN_TRI`, hoàn tác cả lần lưu). Migration 182 không thêm lại; bài pgTAP 182 thử gỡ và thu hẹp qua hàm lưu.
3. **Lịch sử mỗi lần đổi:** `permission_version` (ai, lúc nào, ghi chú) và `permission_change` (ô, trước, sau); màn hiện 5 phiên bản gần đây.
4. **Cờ tắt mặc định (migration 182):** tham số `permission_matrix_edit_enabled` (BOOL, mặc định `false`, nhóm Đăng nhập và bảo mật). Tắt: `save_permission_matrix` qua API báo `HMT_TINH_NANG_TAT`, màn chỉ xem (ẩn nút Sửa, hiện thông báo). Admin bật ở Cài đặt tham số (QT-09) khi cần đổi quyền, rồi nên tắt lại. Chạy từ migration hoặc SQL Editor của chủ project (không JWT) không bị chặn.
Bốn file pgTAP cũ gọi hàm lưu (007, 015, 016, 018) bật cờ trong giao dịch của bài (một dòng sau `no_plan`), hoàn tác khi kết thúc.
