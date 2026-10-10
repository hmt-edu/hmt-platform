# HMT Platform

CRM, cổng Giáo viên và cổng Học tập của Hòa Ma Toán: một ứng dụng, một cơ sở dữ liệu, ba cổng (`/crm`, `/gv`, `/hoc`). Luật làm việc: [CLAUDE.md](CLAUDE.md); đặc tả: [docs/spec/](docs/spec/).

## Công nghệ

- React 19 + Vite + TypeScript strict + Tailwind, React Router. Ứng dụng tĩnh trên **Cloudflare Pages** (Free).
- **Supabase** Free (Postgres, Auth), vùng Singapore: `hmt-staging` (thử nghiệm), `hmt-prod` (chạy thật).
- Kiểm thử: Vitest, pgTAP (`supabase test db`), Playwright (máy tính + iPhone).
- CI/CD: GitHub Actions. Bản chạy thật chỉ đưa lên từ repo riêng `hmt-deploy` (xem [deploy/README.md](deploy/README.md)).

## Cài đặt

Cần: Node 24 (`.nvmrc`), Docker Desktop (cho Supabase local).

```sh
npm ci
```

## Chạy local

```sh
npm run db:start          # Supabase local trong Docker (lần đầu tải image hơi lâu)
npx supabase status       # lấy "API URL" và "Publishable key"
cp .env.example .env.local
# điền VITE_SUPABASE_URL, VITE_SUPABASE_PUBLISHABLE_KEY vào .env.local (VITE_APP_ENV=local)
npm run dev               # http://localhost:5173
```

Đăng nhập thử ở local: tạo tài khoản giả (mỗi vai trò một tài khoản, xem `scripts/seed-users.ts`):

```sh
export API_URL=http://127.0.0.1:54321 SECRET_KEY=<Secret key trong supabase status> \
  DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres SEED_PASSWORD=<mật khẩu tự chọn>
npm run db:seed-users     # vd sale.cs5@thu.hoamatoan.invalid, học sinh HS900001
```

`.env.local` không đưa vào repo. Biến `VITE_*` lộ ra trình duyệt: chỉ dùng khoá công khai, không bao giờ dùng secret / service_role.

## Kiểm thử

| Lệnh                     | Làm gì                                                                |
| ------------------------ | --------------------------------------------------------------------- |
| `npm run lint`           | ESLint                                                                |
| `npm run typecheck`      | TypeScript                                                            |
| `npm run test`           | Vitest                                                                |
| `npm run check:hardcode` | Dò số nghiệp vụ viết cứng                                             |
| `npm run format:check`   | Prettier (sửa: `npm run format`)                                      |
| `npm run db:reset`       | Dựng lại DB local từ migration + `supabase/seed.sql`                  |
| `npm run db:test`        | pgTAP (cần `db:start`)                                                |
| `npm run e2e`            | Playwright, tự build và chạy bản preview (cần biến `VITE_*` như trên) |

Lần đầu chạy e2e: `npx playwright install chromium webkit`.

## Bộ dò số viết cứng

`scripts/check-hardcoded.mjs`, cấu hình ở `hardcode-check.config.json`:

- **Vùng strict** (`src/domain/**`, `supabase/functions/**`, thân hàm SQL trong `supabase/migrations/*.sql`): chỉ cho phép các số trong `allowed` (mặc định `0, 1, -1`).
- **Vùng ui** (`src/**` còn lại): chỉ bắt số có giá trị tuyệt đối từ `minAbsValue` (mặc định 100) trở lên.
- Bỏ qua số trong chuỗi, comment, kiểu SQL như `numeric(6,2)`, và file kiểm thử.

Nới / siết: sửa `allowed`, `minAbsValue`, `include`, `exclude` trong file cấu hình (qua PR như code). Một chỗ thật sự cần số thì thêm comment cùng dòng kèm lý do: `// allow-number: <lý do>` (TS) hoặc `-- allow-number: <lý do>` (SQL). Số nghiệp vụ đúng nghĩa thì đưa vào bảng Cài đặt, không dùng lối thoát này.

## Đưa code lên

```
nhánh feat/… → PR → CI xanh → gộp main → thử nghiệm tự cập nhật → anh Trường thử
→ anh bấm "Deploy production" trong hmt-deploy (nhập tag staging-…) → chạy thật
```

| Workflow             | Khi nào        | Làm gì                                                                                                                                         |
| -------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `ci.yml`             | Mỗi PR         | lint, typecheck, test, check:hardcode, format; Supabase local + pgTAP + Playwright; bản xem trước trên Pages `hmt-staging` (link ghi vào PR)   |
| `deploy-staging.yml` | Gộp vào `main` | Kiểm tra nhanh, `supabase db push` lên `hmt-staging`, đưa giao diện lên `https://hmt-staging.pages.dev`, gắn tag `staging-YYYYMMDD-HHMM-<sha>` |
| `keepalive.yml`      | 08:17 mỗi ngày | Gọi `app.heartbeat()` để `hmt-staging` không bị tạm dừng                                                                                       |

Thay đổi chỉ ở tài liệu (`docs/**`, `*.md`) không chạy CI và không lên thử nghiệm.

### Secrets và variables của repo này

Settings > Secrets and variables > Actions. Tất cả là của **môi trường thử nghiệm**; khoá chạy thật chỉ nằm ở `hmt-deploy`.

| Loại     | Tên                             | Giá trị                                                                                                                                                                                                        |
| -------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Secret   | `STAGING_DB_URL`                | Supabase `hmt-staging` > Connect > **Session pooler** URI (đã điền mật khẩu)                                                                                                                                   |
| Secret   | `CLOUDFLARE_API_TOKEN`          | Token của tài khoản Cloudflare **thử nghiệm**, quyền Account / Cloudflare Pages / Edit                                                                                                                         |
| Secret   | `CLOUDFLARE_ACCOUNT_ID`         | Account ID của tài khoản Cloudflare thử nghiệm                                                                                                                                                                 |
| Variable | `VITE_SUPABASE_URL`             | Project URL của `hmt-staging`                                                                                                                                                                                  |
| Variable | `VITE_SUPABASE_PUBLISHABLE_KEY` | Publishable key của `hmt-staging`                                                                                                                                                                              |
| Variable | `STAGING_READY`                 | Đặt `true` khi đã điền đủ các mục trên                                                                                                                                                                         |
| Secret   | `SUPABASE_ACCESS_TOKEN`         | Token Supabase của tài khoản `hmt-vanhanh` (không còn quyền gì ở `hmt-prod`), để triển khai Edge Function. Ghi ngày hết hạn vào variable `STAGING_SUPABASE_TOKEN_EXPIRES` của `hmt-deploy` (báo cáo tuần nhắc) |
| Secret   | `STAGING_SUPABASE_SECRET_KEY`   | Supabase `hmt-staging` > Project Settings > API Keys > **Secret key** (`sb_secret_…`), để tạo tài khoản giả                                                                                                    |
| Secret   | `STAGING_SEED_PASSWORD`         | Mật khẩu chung của các tài khoản giả trên thử nghiệm (≥ 8 ký tự, có chữ và số)                                                                                                                                 |
| Secret   | `STAGING_TURNSTILE_SECRET`      | Cloudflare (tài khoản thử nghiệm) > Turnstile > widget `hmt-staging` > **Secret key**; CI đặt vào Edge Function `login` (`HMT_TURNSTILE_SECRET`)                                                               |
| Variable | `VITE_TURNSTILE_SITE_KEY`       | Site key Cloudflare Turnstile cho thử nghiệm (công khai)                                                                                                                                                       |
| Variable | `PROD_PROJECT_REF`              | Mã project `hmt-prod` (công khai), để CI kiểm khoá ở đây **không** chạm được bản chạy thật                                                                                                                     |

`STAGING_READY` khác `true` (hoặc chưa đặt): gộp `main` chỉ hiện cảnh báo, không triển khai, không báo lỗi. Đặt `true` rồi mà thiếu secret thì workflow báo lỗi rõ ràng. Thiếu secret Cloudflare hoặc variable thì bản xem trước của PR tự bỏ qua (CI vẫn xanh).

### Chống dò mật khẩu

Turnstile, giới hạn đăng nhập theo IP của Supabase Auth: bật cho cả hai project theo `docs/van-hanh/chong-do-mat-khau.md`.

| Loại     | Tên                          | Lấy ở đâu                                                                                                                                                   |
| -------- | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Variable | `PROD_CLOUDFLARE_ACCOUNT_ID` | Mã tài khoản Cloudflare chạy thật (công khai), để CI kiểm token Cloudflare thử nghiệm **không** đọc được tài khoản chạy thật (`scripts/check-isolation.sh`) |

### Cloudflare Pages và đường dẫn

Ứng dụng là SPA. Cloudflare Pages tự trả `index.html` cho mọi đường dẫn không có file khi bản build **không có `404.html`**, nên `/crm`, `/gv/...` mở thẳng được. Đừng thêm `404.html` vào `public/`; trang 404 do React Router hiển thị.
