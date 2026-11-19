# QT-13 Tài khoản học sinh (Code F, 19/11/2026; thẻ F72)

Màn `/crm/quan-tri/tai-khoan-hoc-sinh`: Admin (đã xác thực hai bước) thấy mọi học sinh kèm tình trạng tài khoản đăng nhập app học tập, rồi cấp, đặt lại mật khẩu, khoá. Luật: R-CRM-32 (mật khẩu không bao giờ hiển thị sau lần đầu, chỉ đặt lại để tạo mới), bản đồ màn hình QT-13. Không mang mật khẩu hệ thống cũ sang.

## Hàm DB (migration 567)
| Hàm | Làm gì | Ai gọi |
|---|---|---|
| `app.list_student_accounts(p_filters, p_limit, p_offset)` | Học sinh + tình trạng `CHUA_CAP`, `HOAT_DONG`, `BI_KHOA`; lọc `q` (tên, mã HS, tên phụ huynh), `branch_id`, `state`; phân trang máy chủ, sắp theo mã HS | Admin (Quản trị · Xem, aal2) |
| `app.admin_check_student_account(p_student_code)` | Kiểm em có thật và chưa có tài khoản; trả tên, mã cơ sở. Lỗi `HMT_KHONG_TIM_THAY`, `HMT_TAI_KHOAN_DA_CO` | Edge Function `admin-users` bằng token Admin |

Việc cấp, đặt lại mật khẩu, khoá, mở khoá chạy qua Edge Function `admin-users` (cần khoá secret của Supabase Auth, không nằm ở giao diện). Cấp cho học sinh: máy chủ lấy tên và cơ sở từ hồ sơ học sinh (không tin dữ liệu gửi lên), vai trò luôn `STUDENT`, tên đăng nhập là mã HS, mật khẩu tạm sinh ở máy chủ.

## Giao diện (khuôn K03 + hộp K08, K4g)
Cột: Mã HS, Học sinh, Phụ huynh, Cơ sở, Tài khoản, Đổi mật khẩu lần đầu, Đăng nhập gần nhất. Lọc nhanh Tài khoản (Chưa cấp, Đang dùng, Đã khoá), điều kiện Cơ sở. Nút ở dòng: Cấp tài khoản (em chưa cấp); Đặt lại mật khẩu, Khoá hoặc Mở khoá (em đã có). Chọn nhiều dòng rồi «Cấp tài khoản (n)» để cấp hàng loạt.
- Một em: mật khẩu tạm hiện một lần trong hộp K4g, đóng hộp là mất.
- Hàng loạt: cấp lần lượt từng em (em lỗi ghi lỗi, chạy tiếp); mật khẩu tạm của cả đợt nằm trong **một file CSV tải về một lần** (hệ thống không lưu). **Cần anh quyết:** file này chứa mật khẩu nên Admin phải cất kỹ và in, phát cho phụ huynh rồi xoá; nếu anh muốn cách khác (ví dụ chỉ cấp từng em) thì bỏ nút hàng loạt.

## Hiệu năng
`EXPLAIN ANALYZE` trên 50.000 học sinh giả (transaction rồi huỷ): trang đầu 0,07 ms (index `student_code_key`, `user_account_student_code_key`, nối gộp), tìm theo `search_text` 4,9 ms.
