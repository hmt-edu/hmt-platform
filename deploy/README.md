# hmt-deploy

Repo riêng tư của anh Trường (tài khoản GitHub `truongcx-95`), chỉ dùng trên trình duyệt. Repo này giữ khoá của **bản chạy thật** và làm 3 việc:

| Workflow              | Khi nào chạy           | Làm gì                                                                                                              |
| --------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------- |
| **Deploy production** | Anh bấm tay            | Kiểm bản được chọn đã qua thử nghiệm, áp migration lên DB `hmt-prod`, đưa giao diện lên Cloudflare Pages `hmt-prod` |
| **Backup production** | 02:05 mỗi đêm (giờ VN) | Xuất DB chạy thật, mã hoá, đẩy lên Google Drive; giữ project không bị tạm dừng                                      |
| **Usage report**      | 08:30 sáng thứ Hai     | Tạo một issue "Báo cáo sử dụng tuần …" (GitHub tự gửi email cho anh)                                                |

Code nằm ở repo `hmt-edu/hmt-platform`; repo này chỉ đọc code đó bằng `PLATFORM_READ_TOKEN`.

## Bốn luật bảo mật

0. **Supabase chạy thật (`hmt-prod`)** nằm ở organization **HMT Prod** của tài khoản Supabase `[email chạy thật]` (email + xác thực hai bước). Chuỗi kết nối DB, khoá của `hmt-prod` lấy từ tài khoản này, chỉ trên trình duyệt.
1. **Khoá chạy thật không bao giờ nằm trên máy Mac.** Không chạy `supabase login` hay `wrangler login` bằng tài khoản thật. Chuỗi kết nối DB `hmt-prod` và token Cloudflare chạy thật chỉ dán thẳng vào GitHub Secrets của repo này trên web.
2. **Lấy token rclone xong thì xoá file cấu hình rclone** (xem mục Google Drive bên dưới): `rm ~/.config/rclone/rclone.conf`.
3. **Claude Code không đọc, không xin, không tìm khoá chạy thật.** Không dán khoá vào khung chat.
4. **Repo này nằm ở tài khoản `truongcx-95`, tài khoản này không bao giờ đăng nhập trên máy Mac Claude Code làm việc** (không `gh`, không git, không lưu trong Keychain).

## Cài đặt một lần: Secrets và Variables

Vào repo `hmt-deploy` > **Settings** > **Secrets and variables** > **Actions**.

### Secrets (tab Secrets > New repository secret)

| Tên                                        | Lấy ở đâu                                                                                                                                                                                                                                                                                                                                                        |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `PLATFORM_READ_TOKEN`                      | Đã đặt. Token fine-grained do `hmt-vanhanh` tạo (hết hạn 07/11/2027), chỉ đọc repo `hmt-platform` (Contents: Read, Actions: Read). Làm mới hằng năm, xem cuối file                                                                                                                                                                                               |
| `PROD_DB_URL`                              | Supabase > project `hmt-prod` > nút **Connect** > **Session pooler** > chép URI, thay `[YOUR-PASSWORD]` bằng mật khẩu DB. Mật khẩu có ký tự đặc biệt (`@ : / ? #`…) thì đổi mật khẩu chỉ gồm chữ và số cho dễ. Dùng Session pooler vì máy GitHub không nối được kiểu Direct                                                                                      |
| `CLOUDFLARE_API_TOKEN`                     | Cloudflare (tài khoản chạy thật) > ảnh đại diện > **My Profile** > **API Tokens** > **Create Token** > **Create Custom Token**: quyền _Account / Cloudflare Pages / Edit_, Account Resources chọn đúng tài khoản này. Tài khoản chạy thật đăng ký bằng `[email chạy thật]`. Chỉ copy ô token (chuỗi liền, không dấu cách), **không** copy ô lệnh `curl` bên dưới |
| `CLOUDFLARE_ACCOUNT_ID`                    | Cloudflare > **Workers & Pages** > cột phải, dòng **Account ID**                                                                                                                                                                                                                                                                                                 |
| `GDRIVE_CLIENT_ID`, `GDRIVE_CLIENT_SECRET` | Google Cloud Console, xem mục Google Drive                                                                                                                                                                                                                                                                                                                       |
| `PROD_SUPABASE_ACCESS_TOKEN`               | Supabase **tài khoản `[tài khoản chạy thật]`** > Account > **Access Tokens** > Generate new token: chọn **chỉ project `hmt-prod`**, quyền **Edge Functions: Read-write**. Để triển khai Edge Function (đăng nhập). Dán thẳng vào đây, không lưu trên máy Mac                                                                                                     |
| `GDRIVE_TOKEN`                             | Dòng `token = {...}` lấy bằng rclone, xem mục Google Drive                                                                                                                                                                                                                                                                                                       |

### Variables (tab Variables > New repository variable)

| Tên                              | Lấy ở đâu                                                                                                                                       |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `VITE_SUPABASE_URL`              | Supabase `hmt-prod` > **Project Settings** > **Data API** > Project URL (`https://….supabase.co`)                                               |
| `VITE_SUPABASE_PUBLISHABLE_KEY`  | Supabase `hmt-prod` > **Project Settings** > **API Keys** > **Publishable key** (`sb_publishable_…`). **Không** dùng Secret key / service_role  |
| `VITE_TURNSTILE_SITE_KEY`        | Cloudflare (tài khoản chạy thật) > **Turnstile** > widget `hmt-prod` > **Site key** (công khai)                                                 |
| `AGE_RECIPIENT`                  | Khoá công khai age (`age1…`), xem mục Khoá mã hoá                                                                                               |
| `PROD_SUPABASE_TOKEN_EXPIRES`    | Ngày hết hạn của `PROD_SUPABASE_ACCESS_TOKEN`, dạng `2027-10-10` (Supabase hiện ngày này lúc tạo token). Báo cáo tuần nhắc khi còn dưới 30 ngày |
| `STAGING_SUPABASE_TOKEN_EXPIRES` | Ngày hết hạn của `SUPABASE_ACCESS_TOKEN` bên `hmt-platform` (thử nghiệm), dạng `2027-10-10`. Chỉ là ngày, không phải khoá                       |

## Đưa một bản lên chạy thật

1. Thử bản đó trên môi trường thử nghiệm (`https://hmt-staging.pages.dev`) cho xong.
2. Lấy tên tag: trong `hmt-platform` > **Actions** > lượt **Deploy staging** xanh mới nhất > phần tóm tắt có dòng `Tag: staging-YYYYMMDD-HHMM-xxxxxxx`. (Hoặc tab **Code** > **Tags**.)
3. Repo `hmt-deploy` > **Actions** > **Deploy production** > **Run workflow** > ô `ref` dán tag > **Run workflow**.
4. Chờ 4 bước xanh: _Kiểm tra bản được chọn_ → _Build_ → _Áp migration lên hmt-prod_ → _Triển khai Cloudflare Pages_. Mở lượt chạy để xem tóm tắt (commit, giờ, địa chỉ).

Bước kiểm tra sẽ dừng và báo lỗi tiếng Việt nếu: tag không tồn tại, commit không nằm trên `main`, hoặc commit chưa từng lên thử nghiệm thành công. Migration lỗi thì giao diện không được đưa lên.

## Chống dò mật khẩu (làm một lần, trước khi cho người dùng đăng nhập)

Bật Turnstile và giới hạn đăng nhập theo IP trong Supabase Auth của `hmt-prod`, đặt `HMT_ALLOWED_ORIGINS` cho Edge Function:
làm theo `docs/van-hanh/chong-do-mat-khau.md` trong repo `hmt-platform` (phần Chạy thật). Khoá tạm của HMT chỉ là lớp thứ hai.

## Tài khoản Admin đầu tiên (làm một lần)

1. Supabase (tài khoản `[tài khoản chạy thật]`) > `hmt-prod` > **Authentication** > **Users** > **Add user** > **Create new user**: gõ email, mật khẩu (trình quản lý mật khẩu tạo), tick **Auto Confirm User**.
2. Repo này > **Actions** > **Bootstrap admin** > **Run workflow**: nhập đúng email đó, tên hiển thị, cơ sở. Workflow chỉ gán vai trò ADMIN, và **từ chối nếu `hmt-prod` đã có ADMIN**.
3. Mở bản chạy thật, đăng nhập bằng email đó, cài xác thực hai bước theo hướng dẫn trên màn hình. Các tài khoản khác tạo trên màn quản trị (bước 4).

## Sao lưu

- Mỗi đêm 02:05: xuất 3 file `roles.sql`, `schema.sql`, `data.sql` → nén → mã hoá bằng `age` → file `hmt-prod-YYYYMMDD-HHMM.tar.gz.age` (giờ VN). Bản chưa mã hoá bị xoá ngay trên máy GitHub.
- Nơi lưu: Google Drive của `[email vận hành]` > **My Drive** > `HMT-backup/daily/`. Ngày 1 hằng tháng thêm một bản vào `HMT-backup/monthly/`.
- Giữ **30 bản hằng ngày** và **12 bản hằng tháng**; bản cũ hơn tự xoá.
- Sao lưu lỗi: GitHub gửi email báo workflow thất bại cho anh.
- **Khoá bí mật age không bao giờ nằm trên Drive hay GitHub.** Chỉ có ở trình quản lý mật khẩu + một bản in cất kỹ. Mất khoá này thì không mở được bản sao lưu nào.

### Khoá mã hoá (làm một lần, trên máy anh)

```sh
brew install age
age-keygen
```

Lệnh in ra 3 dòng (không ghi file). Chép dòng `AGE-SECRET-KEY-1…` vào trình quản lý mật khẩu và in ra giấy; chép giá trị sau `# public key:` (`age1…`) vào Variable `AGE_RECIPIENT`. Xong gõ `clear` để xoá màn hình.

### Google Drive (làm một lần)

1. Đăng nhập `[email vận hành]` vào https://console.cloud.google.com > tạo project `hmt-backup`.
2. **APIs & Services** > **Library** > bật **Google Drive API**.
3. **OAuth consent screen**: loại External, điền tên app, email. Thêm scope `.../auth/drive.file`. **Bấm Publish app (In production)**: để ở chế độ Testing thì token hết hạn sau 7 ngày.
4. **Credentials** > **Create credentials** > **OAuth client ID** > loại **Desktop app**. Chép Client ID và Client secret vào hai Secret `GDRIVE_CLIENT_ID`, `GDRIVE_CLIENT_SECRET`.
5. Trên máy anh: `brew install rclone`, rồi `rclone config` và trả lời: `n` (remote mới) → tên `gdrive` → loại `drive` → dán client_id → dán client_secret → scope chọn **drive.file** → các câu khác Enter → _Use web browser_: `y` → đăng nhập `[email vận hành]` trên trình duyệt → _Shared Drive_: `n` → `y` để lưu → `q`.
6. Chạy `rclone config show gdrive`, chép phần sau `token = ` (một dòng JSON `{"access_token":…}`) vào Secret `GDRIVE_TOKEN`.
7. **Xoá file cấu hình ngay**:
   ```sh
   rm ~/.config/rclone/rclone.conf
   rclone listremotes
   ```
   `rclone listremotes` không in ra gì là đã xoá xong.
8. **Không tự tạo thư mục `HMT-backup` trên Drive.** Quyền `drive.file` chỉ thấy thư mục do chính rclone tạo; lần sao lưu đầu sẽ tự tạo.
9. Chạy thử: **Actions** > **Backup production** > **Run workflow**, rồi mở Drive xem file.

## Khôi phục thử (mỗi tháng, anh tự làm trên máy Mac)

Claude Code không chạy bước này. Cần Docker Desktop đang mở và `age` (`brew install age`). Mất khoảng 10 phút.

```sh
# 1. Thư mục tạm
mkdir -p ~/hmt-restore && cd ~/hmt-restore
# 2. Tải file .age mới nhất trong Drive > HMT-backup/daily vào ~/hmt-restore (bằng trình duyệt)
mv ~/Downloads/hmt-prod-*.tar.gz.age .
# 3. Chép khoá bí mật (AGE-SECRET-KEY-1…) từ trình quản lý mật khẩu, rồi:
pbpaste > key.txt && chmod 600 key.txt && pbcopy < /dev/null
# 4. Giải mã, giải nén
age -d -i key.txt -o backup.tar.gz hmt-prod-*.tar.gz.age
tar -xzf backup.tar.gz
cd hmt-prod-*/
# 5. DB tạm (không mở cổng ra ngoài)
docker run -d --name hmt-restore -e POSTGRES_PASSWORD=khoiphuc-tam postgres:17
sleep 10
docker exec -i hmt-restore psql -U postgres -q -c "create role anon nologin; create role authenticated nologin; create role service_role nologin; create role authenticator noinherit login; create schema extensions;"
# 6. Nạp bản sao lưu
docker exec -i hmt-restore psql -U postgres -q < roles.sql
docker exec -i hmt-restore psql -U postgres -q < schema.sql
docker exec -i hmt-restore psql -U postgres -q -c "set session_replication_role = replica" -f - < data.sql
```

Bước 6 sẽ in một số lỗi về `auth`, `storage`, `supabase_functions`, `supabase_vault`, `supabase_realtime`: **bình thường** (đó là phần riêng của Supabase, DB tạm không có). Phần cần kiểm là dữ liệu của hệ thống trong schema `app`:

```sh
docker exec -i hmt-restore psql -U postgres -c "select * from app.system_info;"
docker exec -i hmt-restore psql -U postgres -c "select table_name as bang, (xpath('/row/n/text()', query_to_xml(format('select count(*) as n from app.%I', table_name), false, true, '')))[1]::text::bigint as so_dong from information_schema.tables where table_schema = 'app' and table_type = 'BASE TABLE' order by 1;"
```

So số dòng với Supabase `hmt-prod` > **Table Editor** (lệch vài dòng do dữ liệu mới sau giờ sao lưu là bình thường). Ghi ngày khôi phục thử và kết quả vào sổ tay.

**Dọn ngay sau khi kiểm:**

```sh
docker rm -f -v hmt-restore
cd ~ && rm -rf ~/hmt-restore
```

Khôi phục thật khi có sự cố là việc khác: nạp vào một project Supabase mới theo hướng dẫn chính thức (https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore), có Claude hỗ trợ từng bước nhưng anh tự dán khoá.

## Làm mới PLATFORM_READ_TOKEN (hằng năm)

Báo cáo tuần sẽ cảnh báo khi token còn dưới 30 ngày.

1. Trên trình duyệt, đăng nhập GitHub `hmt-vanhanh` (chủ `hmt-platform`, người tạo token) > ảnh đại diện > **Settings** > **Developer settings** > **Personal access tokens** > **Fine-grained tokens**.
2. Mở token đang dùng > **Regenerate token** (hoặc tạo mới): Expiration 1 năm; Repository access: **Only select repositories** > `hmt-edu/hmt-platform`; Permissions: **Contents: Read-only**, **Actions: Read-only** (Metadata tự thêm).
3. Chép token, vào `hmt-deploy` > **Settings** > **Secrets and variables** > **Actions** > `PLATFORM_READ_TOKEN` > **Update** > dán > lưu. Đóng tab, không lưu token ở đâu khác.
4. Chạy thử **Usage report** (Run workflow): mục PLATFORM_READ_TOKEN phải hiện ngày hết hạn mới.

## Làm mới token Supabase (trước ngày hết hạn)

Báo cáo tuần nhắc khi token còn dưới 30 ngày. Supabase không cho sửa hạn token cũ: tạo token mới rồi xoá token cũ.

- **`PROD_SUPABASE_ACCESS_TOKEN`**: đăng nhập Supabase `[tài khoản chạy thật]` > **Account** > **Access Tokens** > tạo token mới như bảng Secrets ở trên > dán vào secret `PROD_SUPABASE_ACCESS_TOKEN` của repo này > sửa variable `PROD_SUPABASE_TOKEN_EXPIRES` thành ngày hết hạn mới > xoá token cũ trên Supabase.
- **`SUPABASE_ACCESS_TOKEN` (hmt-platform)**: đăng nhập Supabase `hmt-vanhanh` > tạo token mới > dán vào secret `SUPABASE_ACCESS_TOKEN` của `hmt-platform` > sửa variable `STAGING_SUPABASE_TOKEN_EXPIRES` **của repo này** > xoá token cũ.
- Chạy thử **Usage report**: mục Token Supabase phải hiện ngày mới.

## Ghi chú

- Lịch tự chạy chỉ hoạt động trên nhánh `main` của repo này.
- Bản `hmt-platform` chỉ thay đổi tài liệu (`*.md`, `docs/`) không tạo lượt thử nghiệm nên không có tag mới; cứ chọn tag `staging-…` mới nhất.
- Phiên bản công cụ ghim trong workflow: Supabase CLI 2.120.0, wrangler 4.149.0, rclone v1.75.1 (kèm mã băm). Nâng phiên bản thì sửa ở đầu file workflow.
