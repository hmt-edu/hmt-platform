# Công khai repo `hmt-platform`: danh sách an toàn

Dọn trước khi công khai (cách A): không viết lại lịch sử git; chỉ làm sạch bản hiện tại và đặt luật để từ nay không lộ gì. Tài liệu này là danh sách việc cho người quản trị repo và mọi người làm việc trong repo.

## 1. Không bao giờ commit

- Khoá, mật khẩu, token, chuỗi kết nối DB, `service_role`, khoá secret Supabase (`sb_secret_…`), file `.env*` (chỉ `.env.example` được có, không giá trị thật).
- Dữ liệu thật: tên, số điện thoại, email của học sinh, phụ huynh, nhân viên. Dữ liệu thử, kiểm thử, ví dụ trong tài liệu đều là dữ liệu giả (số `0900 000 xxx`, email `@example.test`, tên giả).
- Tên tài khoản cá nhân và họ tên người trong tài liệu: dùng nhãn vai trò (TÀI KHOẢN DEPLOY, TÀI KHOẢN GỘP, TÀI KHOẢN CHỦ DỰ ÁN, CHỦ DỰ ÁN). Luật làm việc (ví dụ «tài khoản deploy không bao giờ đăng nhập trên máy làm việc») vẫn ghi đủ.
- File cấu hình riêng của máy (`.claude/`, `du-lieu-that/`, `*.local.*`, `_inbox/`) đã nằm trong `.gitignore`; không `git add -f` chúng.

## 2. Secret chỉ ở GitHub Secrets

- Mọi khoá dùng cho CI, triển khai thử nghiệm nằm ở **Settings > Secrets and variables > Actions** của repo, không ở trong mã, workflow hay tài liệu.
- Khoá chạy thật chỉ ở repo triển khai riêng (xem `deploy/README.md`), không ở repo này.
- Giá trị không bí mật nhưng riêng (mã dự án Supabase, tên dự án Cloudflare) đặt ở **Variables** (ví dụ `STAGING_REF` nếu workflow cần), không ghi cứng trong workflow. Hiện workflow `staging-du-lieu-thu.yml` đã bị xoá khỏi nhánh chính (PR #184); nếu dựng lại thì đọc mã dự án từ `vars.STAGING_REF` hoặc từ secret.
- Ai làm: chủ repo tạo biến `STAGING_REF` khi cần (một lần, trên trình duyệt).

## 3. PR từ người ngoài không được dùng secret

- Workflow chạy bằng sự kiện `pull_request` (không phải `pull_request_target`): PR từ fork không nhận secret.
- Bước dùng secret (ví dụ đưa bản xem trước lên Cloudflare) chỉ chạy khi PR cùng repo (`head.repo.full_name == github.repository`) và có nhãn riêng; chỉ người có quyền ghi mới gắn được nhãn.
- Settings > Actions > General: đặt **Fork pull request workflows from outside collaborators** là **Require approval for all outside collaborators** (không để chạy tự động).
- Quyền mặc định của `GITHUB_TOKEN`: **Read repository contents** (đã khai `permissions: {}` ở mức workflow, từng job tự xin tối thiểu).

## 4. Bật bảo vệ của GitHub (anh làm một lần trên trình duyệt)

- **Settings > Code security**: bật **Secret scanning** và **Push protection** (chặn đẩy khi có khoá).
- Bật **Dependabot alerts**; bật **Private vulnerability reporting**.
- Nhánh `main`: bắt buộc PR, bắt buộc kiểm CI trước khi gộp, cấm force push.
- Không tắt RLS của bảng nào; mã giao diện coi như công khai, chỉ dùng khoá publishable.

## 5. Kiểm trước khi bấm Public

- [ ] Quét bản hiện tại: không khoá, token, chuỗi kết nối, email, số điện thoại thật (dùng `git grep` các mẫu `sb_secret_`, `eyJ`, `ghp_`, `github_pat_`, `postgres://`, `@gmail`).
- [ ] Quét lịch sử: công cụ quét bí mật (ví dụ `gitleaks`) trên mọi nhánh và tag; bất kỳ khoá nào từng lọt vào lịch sử phải **xoay (thu hồi và tạo lại)**, vì lịch sử không viết lại.
- [ ] Rà `design/**` và `docs/**`: tên thật, số điện thoại, email trong ảnh chụp hoặc HTML mẫu.
- [ ] Biến `HMT_OK_USER` (tên tài khoản gộp, không ghi trong repo) đã đặt trên máy chạy cổng gộp `scripts/kiem-truoc-khi-gop.sh`.
- [ ] Các biến repo cần có (`STAGING_REF` nếu dùng) đã tạo; secret còn đủ.

## 6. Rà workflow (bản ghi lúc dọn)

- `ci.yml`: sự kiện `pull_request` và chạy tay; không dùng `pull_request_target`; quyền mức workflow rỗng, job xin `contents: read`; bước dùng secret Cloudflare chỉ cho PR cùng repo có nhãn `preview`; có `::add-mask::` cho khoá. Không có bước in secret ra log. Lưu ý: nhãn `labeled` kích chạy lại, nên chỉ người có quyền ghi được gắn nhãn (mặc định của GitHub).
- `deploy-staging.yml`: chỉ chạy khi đẩy vào `main` và chạy tay; quyền mặc định rỗng, riêng job đẩy tag có `contents: write`; secret chỉ qua `env` của bước; có `::add-mask::`. Không có bước in secret.
- `_checks.yml`: workflow tái dùng, `contents: read`.
- Việc cần siết thêm (ngoài PR này): bật các cài đặt ở mục 3 và 4 trên GitHub (không làm được bằng mã).
