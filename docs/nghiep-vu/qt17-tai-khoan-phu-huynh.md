# QT-17 Tài khoản phụ huynh (migration 616, CAO)

Phụ huynh đăng nhập bằng **mã PH + mật khẩu trung tâm cấp** (CHUNG-23), như học sinh (QT-13). Quyền: chỉ Admin đã xác thực hai bước (CS để giai đoạn sau, cùng QT-13). Mật khẩu tạm trả một lần ở hộp K4g, không lưu, không gửi email.

## Hàm DB
- `app.list_parent_accounts(p_filters, p_limit, p_offset)`: phụ huynh + tình trạng tài khoản (CHUA_CAP, HOAT_DONG, BI_KHOA) + số con. Lọc `q`, `branch_id`, `state`. Phân trang máy chủ.
- `app.admin_check_parent_account(p_parent_code)`: phụ huynh có thật và chưa có tài khoản (HMT_KHONG_TIM_THAY, HMT_TAI_KHOAN_DA_CO).
- `app.admin_create_account(... , p_parent_code)`: thêm tham số cuối. Vai trò PARENT bắt buộc có mã PH và không gộp vai trò khác (HMT_THIEU_MA_PH).
- `app.first_password_change_required`: phụ huynh theo tham số của học sinh (mặc định không bắt đổi).

## Thay đổi cấu trúc
- `app.user_account.parent_code` (unique, mẫu `PH…`, không đổi sau khi cấp).
- Vai trò PARENT có cổng `ph` (token `hmt_portals`).
- Mọi hàm `app.*` nhận nhân viên bằng `student_code is null` được thêm `and parent_code is null` (SQL động một lần; pgTAP kiểm không sót) để tài khoản phụ huynh không lọt vào danh sách người phụ trách, người dùng, quản lý trực tiếp.

## Edge Function
- `admin-users` `create` với `kind: 'parent'`, `parentCode`: email nội bộ `ph…@phuhuynh.hoamatoan.edu.vn` (không gửi thư), tên và cơ sở lấy từ hồ sơ phụ huynh.
- `login`: nhận mã PH (`normalizeLogin`, `toAuthEmail`).

## Chưa làm (PR giao diện sau)
Màn QT-17 và cổng `ph` ở giao diện (kiểu `Portal`, route, trang đích), gộp với #506.
