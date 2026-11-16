# Chống dò mật khẩu: Turnstile, giới hạn theo IP (làm một lần cho mỗi project)

Lớp bảo vệ chính khi đăng nhập là **Turnstile** (chống máy tự động), **giới hạn đăng nhập theo IP** của Supabase Auth và
**xác thực hai bước** (ADMIN, Kế toán). Khoá tạm của HMT (sai 10 lần khoá 15 phút) chỉ là lớp thứ hai: người gọi thẳng
Supabase Auth bằng khoá công khai thì không bị đếm lần sai (xem `docs/nghiep-vu/phan-quyen.md`, mục Soát bảo mật).
Vì vậy hai project đều **phải** bật Turnstile và giới hạn theo IP.

Turnstile phải bật ở **hai chỗ**:

- **Supabase Auth** (Attack Protection): chặn người gọi thẳng Supabase Auth.
- **Edge Function `login`** (khoá bí mật `HMT_TURNSTILE_SECRET`): Function gọi Supabase Auth bằng khoá secret, mà Supabase
  Auth **bỏ qua** Turnstile với lời gọi bằng khoá secret, nên Function tự kiểm mã. Thiếu khoá này thì Function từ chối mọi
  lần đăng nhập (không lặng lẽ bỏ qua).

Làm lần lượt: thử nghiệm (`hmt-staging`) trước, chạy thật (`hmt-prod`) sau. Có bước dán khoá bí mật: dán thẳng vào ô trên
web, không dán vào chat, không chụp màn hình lúc khoá đang hiện.

|                                    | Thử nghiệm                                                                     | Chạy thật                                                                         |
| ---------------------------------- | ------------------------------------------------------------------------------ | --------------------------------------------------------------------------------- |
| Tài khoản Cloudflare               | `[email vận hành]+staging`                                           | `[email chạy thật]`                                                         |
| Tên widget Turnstile               | `hmt-staging`                                                                  | `hmt-prod`                                                                        |
| Hostname                           | `hmt-staging.pages.dev`                                                        | `hmt-prod.pages.dev` (thêm tên miền riêng khi có)                                 |
| Tài khoản Supabase                 | TÀI KHOẢN CHỦ DỰ ÁN (GitHub)                                                         | `[tài khoản chạy thật]` (email + hai bước)                                                |
| Site key (công khai) dán vào       | `hmt-platform` > Variables > `VITE_TURNSTILE_SITE_KEY`                         | `hmt-deploy` > Variables > `VITE_TURNSTILE_SITE_KEY`                              |
| Secret key cho Edge Function       | `hmt-platform` > Secrets > `STAGING_TURNSTILE_SECRET` (CI tự đặt vào Function) | Supabase `hmt-prod` > Edge Functions > Secrets > `HMT_TURNSTILE_SECRET`           |
| Khoá secret Supabase cho Function  | `hmt-platform` > Secrets > `STAGING_SUPABASE_SECRET_KEY` (CI tự đặt)           | Supabase `hmt-prod` > Edge Functions > Secrets > `HMT_SECRET_KEY` (`sb_secret_…`) |

## Bước 1. Tạo widget Turnstile (Cloudflare, miễn phí)

1. Đăng nhập Cloudflare đúng tài khoản ở bảng trên > menu trái **Turnstile** > **Add widget**.
2. Widget name, Hostname: theo bảng. Widget mode: **Managed**. Pre-clearance: **No**. Bấm **Create**.
3. Màn hình hiện **Site key** và **Secret key**. Mở lại được bất cứ lúc nào: Turnstile > bấm tên widget > Settings.

## Bước 2. Site key vào GitHub (công khai), rồi build lại trang

Repo theo bảng > **Settings** > **Secrets and variables** > **Actions** > tab **Variables** > `VITE_TURNSTILE_SITE_KEY` > dán
Site key > lưu. Sau đó build lại trang (thử nghiệm: chạy lại **Deploy staging**; chạy thật: lần **Deploy production** kế tiếp)
để trang đăng nhập hiện ô xác minh. **Làm bước này trước bước 3**: bật Turnstile khi trang chưa có ô xác minh thì không ai
đăng nhập được.

## Bước 3. Secret key vào Edge Function (⚠️ khoá bí mật)

Theo dòng "Secret key cho Edge Function" trong bảng:

- Thử nghiệm: `hmt-platform` > Secrets > **New repository secret** > `STAGING_TURNSTILE_SECRET` > dán Secret key. CI đặt vào
  Function ở lần Deploy staging kế tiếp, rồi tự kiểm "mã chống máy giả bị chặn".
- Chạy thật: Supabase `hmt-prod` > **Edge Functions** > **Secrets** > thêm `HMT_TURNSTILE_SECRET` = Secret key.

## Bước 4. Bật Turnstile trong Supabase Auth (⚠️ khoá bí mật)

1. Supabase đúng tài khoản > project theo bảng > **Authentication** > **Attack Protection**.
2. Bật **Enable Captcha protection**. Provider: **Turnstile by Cloudflare**.
3. Ô **Captcha secret**: dán Secret key (cùng khoá ở bước 3) > **Save changes**.

Kết quả đúng: gọi thẳng Supabase Auth không có mã bị chặn (`captcha_failed`); trang đăng nhập có ô xác minh, đăng nhập được.

## Bước 5. Hạ giới hạn đăng nhập theo IP, bật nhận IP thật

1. Supabase > project > **Authentication** > **Rate Limits**.
2. Mục giới hạn đăng nhập (**sign-ups and sign-ins**, tính theo 5 phút, mỗi IP): đặt **20** > **Save**.

3. Cùng trang, phần **IP Address Forwarding**: bật **Enable IP address forwarding** > **Save changes**. Thiếu bước này thì
   Supabase Auth không nhận IP thật do Edge Function chuyển sang (`Sb-Forwarded-For`), tính mọi lần đăng nhập là của một IP
   máy chủ, và giới hạn trên áp chung cho cả trung tâm.

Vì sao 20: mặc định 30. Nhân viên một cơ sở dùng chung một đường mạng (cùng IP) nên đặt quá thấp thì đầu giờ nhiều
người đăng nhập cùng lúc sẽ bị chặn. 20 lần mỗi 5 phút đủ cho một cơ sở, vẫn làm chậm việc dò mật khẩu. Nếu cơ sở báo bị
chặn đầu giờ thì nâng lên 30.

## Bước 6 (chỉ chạy thật). Các khoá khác của Edge Function

Supabase `hmt-prod` > **Edge Functions** > **Secrets**, thêm:

- `HMT_ALLOWED_ORIGINS` = `https://hmt-prod.pages.dev` (sau này thêm tên miền riêng, cách nhau dấu phẩy).
- `HMT_SECRET_KEY` = một khoá secret riêng tạo ở **Project Settings** > **API Keys** > **Secret keys** (tên `hmt_prod_edge`,
  bắt đầu bằng `sb_secret_`). Để Function chuyển IP thật của người dùng sang Supabase Auth; thiếu thì mọi lần đăng nhập bị
  tính chung một IP và giới hạn theo IP chặn nhầm cả hệ thống.

Bản thử nghiệm do CI tự đặt, không cần làm tay.
