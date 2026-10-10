# Chống dò mật khẩu: Turnstile, giới hạn theo IP (làm một lần cho mỗi project)

Lớp bảo vệ chính khi đăng nhập là **Turnstile** (chống máy tự động), **giới hạn đăng nhập theo IP** của Supabase Auth và
**xác thực hai bước** (ADMIN, Kế toán). Khoá tạm của HMT (sai 10 lần khoá 15 phút) chỉ là lớp thứ hai: người gọi thẳng
Supabase Auth bằng khoá công khai thì không bị đếm lần sai (xem `docs/nghiep-vu/phan-quyen.md`, mục Soát bảo mật).
Vì vậy hai project đều **phải** bật Turnstile và giới hạn theo IP.

Làm lần lượt: thử nghiệm (`hmt-staging`) trước, chạy thật (`hmt-prod`) sau. Có bước dán khoá bí mật: dán thẳng vào ô trên
web, không dán vào chat, không chụp màn hình lúc khoá đang hiện.

| | Thử nghiệm | Chạy thật |
|---|---|---|
| Tài khoản Cloudflare | `lead.vanhanh.hmt+staging@gmail.com` | `truongcx.work@gmail.com` |
| Tên widget Turnstile | `hmt-staging` | `hmt-prod` |
| Hostname | `hmt-staging.pages.dev` | `hmt-prod.pages.dev` (thêm tên miền riêng khi có) |
| Tài khoản Supabase | `hmt-vanhanh` (GitHub) | `truongcx.work` (email + hai bước) |
| Site key (công khai) dán vào | `hmt-platform` > Variables > `VITE_TURNSTILE_SITE_KEY` | `hmt-deploy` > Variables > `VITE_TURNSTILE_SITE_KEY` |

## Bước 1. Tạo widget Turnstile (Cloudflare, miễn phí)
1. Đăng nhập Cloudflare đúng tài khoản ở bảng trên > menu trái **Turnstile** > **Add widget**.
2. Widget name: theo bảng. Hostname: theo bảng. Widget mode: **Managed**. Bấm **Create**.
3. Màn hình hiện **Site key** và **Secret key**. Để nguyên tab này, làm bước 2 và 3.

## Bước 2. Dán Site key vào GitHub (công khai, không phải bí mật)
Mở repo theo bảng > **Settings** > **Secrets and variables** > **Actions** > tab **Variables** > `VITE_TURNSTILE_SITE_KEY`
(chưa có thì **New repository variable**) > dán Site key > lưu.

## Bước 3. Bật Turnstile trong Supabase Auth (⚠️ có khoá bí mật)
1. Supabase đúng tài khoản > project theo bảng > **Authentication** > **Attack Protection**.
2. Bật **Enable Captcha protection**. Provider: **Cloudflare Turnstile**.
3. Ô **Captcha secret**: quay lại tab Cloudflare, bấm copy **Secret key**, dán vào ô này > **Save**. Đóng tab Cloudflare.

Kết quả đúng: mở trang đăng nhập của môi trường đó, thấy ô xác minh Cloudflare; đăng nhập tài khoản giả được.

## Bước 4. Hạ giới hạn đăng nhập theo IP
1. Supabase > project > **Authentication** > **Rate Limits**.
2. Mục giới hạn đăng nhập (**sign-ups and sign-ins**, tính theo 5 phút, mỗi IP): đặt **20** > **Save**.

Vì sao 20: mặc định 30. Nhân viên một cơ sở dùng chung một đường mạng (cùng IP) nên đặt quá thấp thì đầu giờ nhiều
người đăng nhập cùng lúc sẽ bị chặn. 20 lần mỗi 5 phút đủ cho một cơ sở, vẫn làm chậm việc dò mật khẩu. Nếu cơ sở báo bị
chặn đầu giờ thì nâng lên 30.

## Bước 5 (chỉ chạy thật). Nguồn được gọi Edge Function
Supabase `hmt-prod` > **Edge Functions** > **Secrets** > thêm `HMT_ALLOWED_ORIGINS` = `https://hmt-prod.pages.dev`
(sau này thêm tên miền riêng, cách nhau dấu phẩy). Bản thử nghiệm do CI tự đặt, không cần làm tay.
