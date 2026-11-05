# Sổ tay vận hành

> Địa chỉ email thật của các tài khoản vận hành anh giữ riêng, không ghi trong repo (repo có thể công khai). Các nhãn `[email vận hành]`, `[email chạy thật]`, `[tài khoản chạy thật]`, `[tài khoản Claude N]` trong tài liệu chỉ là tên gọi.

Các việc vận hành hệ thống mà anh Trường (Admin) tự làm. Việc với bản chạy thật làm trên trình duyệt, bằng tài khoản
`[tài khoản chạy thật]` (Supabase, Cloudflare) và `truongcx-95` (GitHub, chủ `hmt-platform` và `hmt-deploy`).

| Việc | Xem ở |
|---|---|
| Đưa một bản lên chạy thật, sao lưu, khôi phục thử, làm mới token | `deploy/README.md` (cũng là README của `hmt-deploy`) |
| Bật Turnstile, giới hạn đăng nhập theo IP, khoá của Edge Function | `docs/van-hanh/chong-do-mat-khau.md` |
| Kế toán vắng: gán tạm vai trò Kế toán | `docs/nghiep-vu/phan-quyen.md` mục "Kế toán vắng" |

## Xác thực hai bước: mất thiết bị

Chốt 12/10/2026: không có mã dự phòng. Mỗi người đăng ký **tối đa 2 thiết bị** (ví dụ điện thoại chính và một máy dự
phòng), nên mất một máy vẫn đăng nhập được bằng máy kia, rồi gỡ máy đã mất trong Hồ sơ cá nhân.

| Ai mất thiết bị | Cách xử lý |
|---|---|
| Kế toán hoặc Admin khác, mất **cả hai** thiết bị | Một Admin vào **Người dùng (QT-02)** > **Đặt lại hai bước**. Người đó đăng nhập lại và đăng ký thiết bị mới. (Màn này làm ở bước 4.) |
| **Admin duy nhất** mất cả hai thiết bị | Chạy workflow **Bootstrap admin** trong `hmt-deploy` ở chế độ khôi phục. (Chế độ này làm ở bước 4; hiện workflow chỉ tạo Admin đầu tiên.) |

**Trong lúc chưa có hai chức năng trên (trước khi xong bước 4):** anh đăng nhập Supabase bằng `[tài khoản chạy thật]` > project
`hmt-prod` > **Authentication** > **Users** > chọn tài khoản > xoá thiết bị hai bước (MFA factor). Người đó đăng nhập lại
sẽ được yêu cầu đăng ký thiết bị mới. Không sửa gì khác trong cơ sở dữ liệu chạy thật.

Nên làm ngay: đăng ký thiết bị thứ hai cho tài khoản Admin (khi bước 4 có chỗ thêm thiết bị).
