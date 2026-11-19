# Mở schema `app` qua Data API (staging, chạy thật)

**Vì sao:** toàn bộ giao diện và Edge Function gọi rpc vào schema `app`. `supabase/config.toml` (`[api] schemas`) chỉ áp ở local; `supabase db push` KHÔNG đổi cài đặt API của project hosted. Nếu `app` chưa nằm trong **Exposed schemas**, mọi lệnh gọi trả `PGRST106` (HTTP 406) và đăng nhập báo «Hệ thống đang lỗi, thử lại sau.» (Edge Function `login` gọi `app.login_precheck`).

**Staging (tự động, từ 19/11/2026):** workflow `deploy-staging.yml` có hai bước mới:
1. «Mở schema app qua Data API»: đọc `GET /v1/projects/<ref>/postgrest`, nếu `db_schema` chưa có `app` thì `PATCH` thêm vào (giữ nguyên schema khác). Idempotent. Cần secret `SUPABASE_ACCESS_TOKEN`.
2. «Kiểm schema app mở qua Data API» (bước cuối): gọi `/rest/v1/catalog` với `Accept-Profile: app` và khoá publishable; mã 406 thì lượt triển khai báo đỏ kèm hướng dẫn.

**Chạy thật (`hmt-deploy`, chỉ anh Trường):** làm một trong hai cách, một lần cho project `hmt-prod`:
- Dashboard: Settings > API > Exposed schemas: thêm `app` (giữ `public`, `graphql_public`), Save.
- Hoặc thêm vào workflow Deploy production bước giống bước 1 và bước 2 ở trên, dùng token và URL của prod. Bản chép ở `deploy/` cần cập nhật cùng.
Quyền truy cập bảng và hàm vẫn do RLS và GRANT quyết định; mở schema chỉ cho phép gọi vào.

**Chẩn đoán nhanh khi đăng nhập báo lỗi hệ thống:** log Edge Function `login` ghi `login_precheck lỗi PGRST106` (chưa mở schema) hoặc mã khác (hàm, quyền).

## Auth Hook «Customize Access Token» và cài đặt Auth khác (thêm 19/11/2026)

`[auth.hook.custom_access_token]` trong `config.toml` cũng chỉ áp ở local. Hosted thiếu hook thì token không có `hmt_roles`: đăng nhập được nhưng không có quyền, giao diện báo lỗi.
- **Staging:** bước «Đồng bộ cài đặt Auth trên hmt-staging» của `deploy-staging.yml` đặt qua Management API (`PATCH /v1/projects/<ref>/config/auth`): hook `pg-functions://postgres/app/custom_access_token_hook`, tắt tự đăng ký và ẩn danh, mật khẩu tối thiểu 8 chữ + số, TOTP tối đa 2 thiết bị, xoay refresh token. Bước cuối «Kiểm đăng nhập thật» đăng nhập bằng `quantri.cs5@thu.hoamatoan.invalid` (mật khẩu seed) và đòi token có `hmt_roles`.
- **Chạy thật (anh Trường, trình duyệt, một lần ở `hmt-prod`):** Authentication > Hooks > Customize Access Token: bật, kiểu Postgres function, chọn `app.custom_access_token_hook`. Authentication > Sign In / Providers: tắt Allow new users to sign up và Anonymous; mật khẩu tối thiểu 8, bắt buộc chữ và số; MFA: TOTP bật, tối đa 2 thiết bị; bật xoay refresh token (reuse interval 10 giây).
- **Không đồng bộ tự động** (khác nhau giữa môi trường): captcha, SMTP, Site URL, redirect URL, giới hạn tần suất.
