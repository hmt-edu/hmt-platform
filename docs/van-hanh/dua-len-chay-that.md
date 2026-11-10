# Đưa bản mới lên chạy thật: từng bước cho anh Trường (Q-196)

Viết 10/11/2026. Đã đọc `deploy/.github/workflows/deploy-production.yml`, `backup.yml`, `.github/workflows/deploy-staging.yml` và `deploy/README.md`. Phần nào chỉ suy ra thì ghi rõ "suy ra".

**Luật an toàn: không chạy Deploy production khi chưa có OK của Chat và anh. Claude Code không có quyền chạy workflow này và không xin khoá chạy thật.**

## Trả lời bốn câu

1. **Deploy production kích hoạt thế nào.** Chỉ chạy tay (`workflow_dispatch`): repo `hmt-deploy` > Actions > Deploy production > Run workflow > dán tag hoặc mã commit. Gộp vào `main` **không** tự đưa lên chạy thật; gộp vào `main` chỉ tự đưa lên **thử nghiệm** (`hmt-staging`). Đã đọc workflow.
2. **Có áp migration lên DB chạy thật không.** Có. Bước "Áp migration lên hmt-prod" chạy `supabase db push` bằng `PROD_DB_URL`: áp mọi file migration trong bản được chọn mà DB chạy thật chưa có, theo thứ tự số. Không có seed. Migration lỗi thì dừng, giao diện không được đưa lên. Đã đọc workflow.
   - **Migration số mấy trên chạy thật:** em **không xem được** DB chạy thật. Theo `docs/TIEN-DO.md` (ghi 05/11) bản chạy thật còn ở tag `staging-20261010-1642-75637cf`, tức rất cũ so với bản hiện tại. Đây là suy ra từ tài liệu, chưa kiểm. Cách kiểm chắc chắn: Supabase `hmt-prod` > SQL Editor > `select max(version) from supabase_migrations.schema_migrations;` (chỉ đọc).
3. **Migration 086, 087 lên chạy thật lúc nào.** Chưa lên, và không tự lên. 086 đã vào `main` (PR #205) và đã áp lên thử nghiệm. 087 nằm ở PR #210, chưa gộp. Cả hai chỉ lên chạy thật khi anh chạy Deploy production với tag đã qua thử nghiệm: lúc đó `db push` áp luôn mọi migration còn thiếu giữa bản chạy thật hiện tại và bản được chọn (nhiều file, không chỉ 086, 087).
4. **Sao lưu trước khi deploy.** Workflow Deploy production **không có bước sao lưu**. Đã đọc. Sao lưu chạy riêng bằng workflow **Backup production** của `hmt-deploy` (mỗi đêm 02:05 giờ Việt Nam, và bấm tay được). Cách làm: `supabase db dump` (3 file roles, schema, data) > nén > mã hoá `age` > đẩy lên Google Drive `HMT-backup/`. Chi tiết xem `deploy/README.md` mục Sao lưu.

## Các bước trước ngày deploy

0. **Kiểm production bằng SQL chỉ đọc:** dán `docs/van-hanh/sql-kiem-hmt-prod-chi-doc.sql` vào Supabase `hmt-prod` > SQL Editor > Run; gửi Chat ảnh kết quả (số migration cuối, số dòng các bảng chính, số phiếu làm 043 dừng). File chỉ có SELECT.

1. Chat và anh OK ngày giờ deploy. Không deploy khi đang có người dùng thật thao tác.
2. Trên bản thử nghiệm: `https://hmt-staging.pages.dev` đã thử xong các luồng cần cho bản này.
3. Lấy tag: `hmt-platform` > Actions > lượt **Deploy staging** xanh mới nhất > dòng `Tag: staging-YYYYMMDD-HHMM-xxxxxxx`. Tag phải là commit trên `main` và đã có lượt Deploy staging thành công (workflow tự kiểm, sai thì dừng).
4. **Sao lưu ngay trước khi deploy** (không dùng bản đêm qua):
   1. `hmt-deploy` > Actions > **Backup production** > **Run workflow**.
   2. Chờ xanh (khoảng vài phút).
   3. Mở Google Drive của `[email vận hành]` > `HMT-backup/daily/`: có file `hmt-prod-YYYYMMDD-HHMM.tar.gz.age` mới với giờ vừa chạy, dung lượng khác 0.
   4. Nếu đỏ hoặc không thấy file: **dừng, không deploy**, báo Chat.
5. Kiểm khoá giải mã `age` còn trong trình quản lý mật khẩu của anh (không có khoá này thì bản sao lưu vô dụng). Khôi phục thử: `deploy/README.md` mục "Khôi phục thử".

## Chạy deploy (khi đã OK)

1. `hmt-deploy` > Actions > **Deploy production** > **Run workflow** > ô `ref` dán tag > Run.
2. Chờ đủ bốn bước xanh: Kiểm tra bản được chọn > Build > Áp migration lên hmt-prod > Triển khai Cloudflare Pages (xen thêm bước Edge Function). Đừng huỷ giữa chừng: workflow không huỷ lượt đang chạy vì migration phải chạy trọn.
3. Migration đỏ: dừng, chụp màn hình bước lỗi, báo Chat. Không sửa tay DB chạy thật.
4. Sau khi xanh: mở `https://hmt-prod.pages.dev`, đăng nhập Admin, mở một danh sách, chạy `select max(version) from supabase_migrations.schema_migrations;` so với số migration cuối của bản đã chọn.

## Ai cần quyền gì (suy ra từ cách workflow dùng khoá)

| Việc | Cần | Nằm ở |
|---|---|---|
| Chạy Deploy production, Backup production | Quyền chạy workflow ở `hmt-deploy` (`truongcx-95`) | GitHub, trình duyệt |
| Đọc `hmt-platform` | `PLATFORM_READ_TOKEN` (do `hmt-vanhanh` tạo, hết hạn 07/11/2027) | Secrets `hmt-deploy` |
| Áp migration, sao lưu | `PROD_DB_URL` | Secrets `hmt-deploy` |
| Triển khai Edge Function | `PROD_SUPABASE_ACCESS_TOKEN` (nếu thiếu, bước này bỏ qua kèm cảnh báo) | Secrets `hmt-deploy` |
| Triển khai giao diện | `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` | Secrets `hmt-deploy` |
| Mã hoá, tải sao lưu | `AGE_RECIPIENT` và các khoá Google Drive | Secrets `hmt-deploy`; khoá giải mã `age` chỉ anh giữ |

Claude Code không có quyền nào ở bảng này.

## Danh sách migration sẽ áp (bản 10/11)

Từ tag `staging-20261010-1642-75637cf` (migration cuối 014) đến `main` ngày 10/11 (migration cuối 086): **70 file mới** (015 đến 086, không có 073 và 078), không file nào sửa hoặc xoá; thêm 087 khi PR #210 gộp. Lệnh: `git diff --name-status staging-20261010-1642-75637cf origin/main -- supabase/migrations`. Danh sách đầy đủ kèm mức rủi ro: `~/Desktop/sang-10-11/migration-tu-tag-staging-den-main.txt`. Mức rủi ro lấy từ tìm chữ khoá (suy ra), chưa đọc từng file.

Cần để ý: 016 và 024 tạo extension `unaccent`, `pg_trgm`; **043 xoá cột** của lead và cơ hội sau khi chuyển dữ liệu em sang bảng mới (có chốt dừng nếu còn phiếu kiểm tra chưa gắn em); 065 xoá cột tìm kiếm của phụ huynh rồi dựng lại; nhiều file đổi dữ liệu danh mục. Không thấy đổi kiểu cột, xoá bảng hay đổi tên cột.

## Khi `db push` dừng giữa chừng

Mỗi file migration chạy trong một giao dịch của Supabase CLI (suy ra, chưa kiểm trên chạy thật): file lỗi thì không để lại gì, các file đã xong trước nó vẫn nằm lại trong DB.

1. **Dừng, không bấm chạy lại ngay.** Bước giao diện không chạy khi bước migration đỏ, nên trang thật vẫn là giao diện cũ nhưng DB đã mới một phần.
2. Chụp màn hình bước "Áp migration lên hmt-prod" (tên file lỗi và câu lỗi), gửi Chat.
3. Xem DB đang ở đâu: Supabase `hmt-prod` > SQL Editor > `select max(version) from supabase_migrations.schema_migrations;` (chỉ đọc).
4. **Không sửa tay DB, không sửa file migration đã gộp.** Cách sửa đúng: Claude Code sửa bằng migration mới trên `main`, qua PR, lên staging; rồi anh chạy lại Deploy production với tag mới (workflow áp tiếp từ chỗ dừng).
5. Trong lúc chờ sửa: người dùng vẫn dùng giao diện cũ; kiểm xem màn chính còn mở được. Nếu hỏng, báo Chat để quyết định khôi phục (mục dưới).

## Xác nhận deploy xong

1. Cả bốn bước (và Edge Function nếu có token) xanh; phần tóm tắt lượt chạy ghi giờ migration, giờ triển khai, địa chỉ.
2. Chạy `select max(version) from supabase_migrations.schema_migrations;` phải bằng số migration cuối của bản đã chọn (086, hoặc 087 nếu #210 đã gộp), và `select count(*) from supabase_migrations.schema_migrations;` khớp tổng số file của tag.
3. Mở `https://hmt-prod.pages.dev` (cửa sổ ẩn danh): trang đăng nhập hiện, đăng nhập bằng Admin.
4. Mở lần lượt Lead, Cơ hội, Đơn hàng, Danh mục: danh sách mở được, không báo lỗi đỏ.
5. Tối đó xem lượt Backup production lúc 02:05 xanh (chứng tỏ DB mới vẫn xuất được).
6. Việc xác nhận bằng số thật (bao nhiêu lead, cơ hội) phải do anh xem; Claude Code không có quyền đọc chạy thật.

## Quay lại bằng bản sao lưu

**Đã đọc `deploy/README.md` và hai workflow: hiện chưa có workflow khôi phục lên `hmt-prod`.** "Khôi phục thử" trong README chỉ nạp bản sao lưu vào DB tạm trên máy anh để kiểm. Khôi phục lên chạy thật cần `PROD_DB_URL`, mà khoá này chỉ nằm trong Secrets của `hmt-deploy` và không bao giờ nằm trên máy Mac.

- Quay lại giao diện cũ: chạy Deploy production với tag cũ. Lưu ý migration đã áp **không tự lùi** (không có migration lùi), nên giao diện cũ chạy trên DB mới; chỉ an toàn nếu bản mới không xoá thứ giao diện cũ cần (043 xoá cột, nên **giao diện cũ sẽ hỏng** nếu 043 đã áp).
- Quay lại DB (Q-206, anh OK 10/11): **chưa có workflow khôi phục lên chạy thật, và chưa viết cho lần thử deploy 12/11.** Ở lần thử 12/11 (production chưa có dữ liệu thật) cách xử lý lỗi là **sửa tiến tới**: sửa bằng migration mới, không lùi. Workflow **"Restore production"** (chạy tay, anh duyệt, đọc bản `.age` từ Drive) sẽ viết xong **trước lần deploy production đầu tiên sau 17/11**, vì từ 17/11 production có dữ liệu thật. Cho tới khi có workflow đó, bản sao lưu chỉ để tra cứu.
