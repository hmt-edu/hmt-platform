# HMT Platform: luật làm việc cho Claude Code

Đầu mỗi phiên đọc tối đa ba file: docs/TIEN-DO.md, docs/quy-trinh-phoi-hop.md, docs/quy-tac-cung-cho-code.md. Các file khác (docs/ke-hoach/ke-hoach-17-11.md, docs/nhat-ky/) đọc khi việc cần.

File anh Trường đưa vào nằm trong `_inbox/` (không bao giờ commit; dùng xong thì xoá file). Gói thiết kế hiện hành (P0 khuôn chung, P1 đăng nhập, P2 cấu hình và phân quyền) ở `design/hmt-p0-p2/` (đọc `00_DOC_TRUOC.md` trước). Danh sách canvas và gói thiết kế hiện hành (bản nào thắng, khung nháp không làm, ghi chú cho code) nằm ở `design/CANVAS-HIEN-HANH.md`: đọc khi làm giao diện. Khi các nguồn vênh nhau: quyết định nghiệp vụ anh Trường chốt 04/11/2026 (mục 14 của `docs/spec/04`, Đ285) > luật (`docs/spec/` 04, 02, 06) > `docs/design/quyet-dinh-thiet-ke-13-10.md` (quyết định thiết kế 13/10) > bản canvas anh Trường đã chốt với Design (Đ271) > `docs/design/ban-do-man-hinh.md` > gói thiết kế `design/hmt-p0-p2/`; làm theo luật, ghi chỗ vênh vào PR, không tự chọn. Khi bản canvas anh Trường đã chốt với Design khác gói thiết kế và bản đồ màn hình thì bản canvas thắng; luật và quyết định thiết kế vẫn ở trên.

Đọc file này và `docs/spec/` trước mỗi việc; làm giao diện thì đọc thêm `docs/design/ban-do-man-hinh.md` (bản đồ màn hình). Spec trong `docs/spec/` là chép từ tài liệu gốc của anh Trường; lệch nhau hoặc thiếu thì hỏi, không đoán.

## Người làm việc cùng
- Anh Trường (Trưởng phòng vận hành HMT, Admin hệ thống). Trao đổi bằng tiếng Việt, ngắn gọn, không thuật ngữ thừa.
- **Phân tích và đề xuất trước, anh OK mới code** với mọi thay đổi lớn hơn sửa lỗi nhỏ.
- Đọc code, đọc dữ liệu trước khi kết luận. Không chắc thì nói không chắc.
- Báo cáo cuối việc: làm gì, anh cần kiểm gì, còn gì chưa xong. Không kể lại từng bước.

## Tuyệt đối không
- `git push --force` lên `main`; gộp PR khi kiểm thử trượt.
- Chạy migration hay sửa tay cơ sở dữ liệu **chạy thật**. Chạy thật chỉ được cập nhật qua quy trình duyệt trên GitHub.
- Đưa khoá, mật khẩu, `service_role` key, file `.env*` (trừ `.env.example`) vào repo.
- Đưa khoá secret/`service_role` vào code giao diện; tắt RLS trên bảng nào.
- Đưa dữ liệu thật (tên, số điện thoại học sinh, phụ huynh) vào môi trường thử nghiệm, local, kiểm thử, hay vào log.
- Mang mật khẩu từ hệ thống cũ sang.
- Viết cứng con số hay danh sách nghiệp vụ trong code (xem mục Cấu hình).
- Dùng `alert`, `confirm`, `prompt` của trình duyệt.

## Chi phí
- **Ưu tiên gói miễn phí, kể cả khi chạy thật.** Không thêm dịch vụ, gói trả phí hay thứ gì phát sinh tiền khi chưa hỏi anh Trường.
- Thiết kế để nằm trong giới hạn gói Free: Supabase (DB 500 MB, tải ra 5 GB/tháng, 2 project), Cloudflare Pages, GitHub Free (repo công khai: CI GitHub miễn phí, không giới hạn phút; vẫn giữ CI gọn, có cache).
- Ghi gọn nhật ký thao tác (chỉ trường đổi), không lưu file trong Supabase Storage (file để Cloudflare R2, giai đoạn 4).

## Kiến trúc
- Một ứng dụng **React tĩnh** (Vite, TypeScript strict, React Router), ba cổng: `/crm`, `/gv` (giáo viên), `/hoc` (học tập), đặt trên **Cloudflare Pages**. Không có máy chủ riêng: trình duyệt gọi thẳng Supabase. Một Supabase Postgres.
- Mọi thứ trong code giao diện coi như công khai. Chỉ dùng khoá publishable; khoá secret không bao giờ nằm trong code giao diện hay biến `VITE_*`.
- Việc cần quyền máy chủ (tạo tài khoản, gửi email, đồng bộ Google Sheet, sao lưu): **Supabase Edge Functions** hoặc GitHub Actions. Việc hẹn giờ (tự chốt buổi, nhắc hạn): **pg_cron** trong Postgres.
- Nghiệp vụ tiền, giờ, cấp mã, chuyển trạng thái nằm trong **hàm Postgres** (`security definer` khi cần, kiểm quyền bên trong), mỗi thao tác một giao dịch; giao diện gọi qua `rpc`. Không tính tiền, giờ ở trình duyệt.
- **RLS bật cho mọi bảng.** Quyền đọc từ bảng ma trận quyền qua hàm trợ giúp (ví dụ `app.has_permission(module, action)`, `app.can_see_branch(branch_id)`); không lặp luật quyền rải rác.
- Thay đổi cấu trúc: file trong `supabase/migrations/`, đánh số, chỉ thêm mới, không sửa migration đã gộp. Dữ liệu giả: `supabase/seed.sql`.
- Tiền: `bigint` đồng. Giờ học: `numeric(6,2)`. Thời điểm: `timestamptz` (UTC), hiển thị `Asia/Ho_Chi_Minh`. Ngày học: `date`.
- Bảng nghiệp vụ có: `id uuid`, `created_at`, `created_by`, `updated_at`, `updated_by`, trigger ghi `audit_log` (chỉ thêm, không ai sửa/xoá được). Không xoá cứng: huỷ là đổi trạng thái.
- Bảng nhận dữ liệu từ Sheet có cột `legacy_ref` (mã cũ), có chỉ mục để tìm.
- Mã nghiệp vụ theo `docs/spec/02-chuan-ma-va-danh-muc.md`, cấp bằng hàm + bảng đếm khoá dòng trong DB (không nhảy số), không cho sửa.

## Quy ước viết nghiệp vụ bằng SQL
1. Mỗi hàm một việc, tên nói rõ việc đó; quá ~80 dòng thì tách hàm con.
2. Đầu mỗi hàm có chú thích tiếng Việt: làm gì, ai được gọi, đầu vào, kết quả, các luật áp dụng trỏ về mục trong docs/spec/.
3. Mỗi luật một đoạn code có chú thích riêng; không gộp nhiều luật vào một câu SQL khó đọc.
4. Mỗi luật có kiểm thử pgTAP cho trường hợp đúng và trường hợp bị chặn; tên bài kiểm thử ghi luật bằng tiếng Việt.
5. Lỗi có mã (ví dụ HMT_QUY_GIO_AM) và câu tiếng Việt để giao diện hiện thẳng.
6. Không dùng SQL động trừ khi bắt buộc, có ghi lý do.
7. Luật quá rắc rối cho SQL (nhiều nhánh, tính toán dài, gọi dịch vụ ngoài, chạy lâu): dừng lại, báo anh, đề xuất Edge Function hoặc service riêng.
8. docs/nghiep-vu/ liệt kê các hàm nghiệp vụ, cập nhật trong cùng PR.

## Cấu hình (không viết cứng)
1. **Danh mục**: bảng có `code` (không đổi), `name`, `sort_order`, `is_active`. Không xoá, chỉ Ngừng.
2. **Tham số nghiệp vụ**: bảng cài đặt có `key`, kiểu, đơn vị, `min`/`max`, mô tả, giá trị chung, giá trị ghi đè theo cơ sở. Code đọc qua một hàm (ví dụ `app.get_setting(key, branch_id)`). Cần tham số mới thì thêm migration khai báo kèm giá trị mặc định, không viết số trong code.
3. **Cấu hình có hiệu lực** (giá, gói, chiết khấu, khung, rubric, ma trận quyền): có ngày hiệu lực hoặc phiên bản. **Bản ghi nghiệp vụ chụp lại giá trị lúc tạo** (đơn giá, số giờ, chiết khấu…), không tham chiếu giá trị hiện tại để tính lại.
4. **Luật lõi** (cấu trúc mã, trừ giờ, chuyển trạng thái, tính tiền): trong code, có kiểm thử.
- Công tắc tính năng theo cơ sở: kiểm cả ở giao diện và trong hàm DB.
- Mọi sửa cấu hình ghi nhật ký.

## Kiểm thử
- DB: pgTAP (`supabase test db`) cho RLS và hàm nghiệp vụ. Mỗi vai trò thử đọc, ghi trong và ngoài phạm vi.
- TypeScript: Vitest. Giao diện: Playwright, cỡ máy tính và điện thoại.
- Mỗi lỗi sửa xong phải có bài kiểm thử tái hiện nó.
- CI chạy lint, typecheck, unit, `supabase db reset` + `supabase test db`, Playwright, và bước dò số nghiệp vụ viết cứng. Trượt thì không gộp.

## Hiệu năng (bắt buộc)
- **Chỉ mục:** mỗi bảng nghiệp vụ có chỉ mục cho khoá ngoại và cột lọc, sắp xếp, tìm kiếm. Migration ghi lý do cho từng chỉ mục.
- **Danh sách:** phân trang ở máy chủ, mặc định 50 dòng, tối đa 100. Lọc, sắp xếp, tìm kiếm làm ở DB. Chỉ lấy các cột màn đang hiện. Cấm tải cả bảng về trình duyệt.
- **Gọi dữ liệu:** một màn tải bằng một đến vài lần gọi (rpc hoặc join). Cấm gọi lặp theo từng dòng.
- **RLS:** hàm quyền viết dạng `(select app.has_permission(...))`; cột dùng trong chính sách có chỉ mục. Mỗi PR có bảng mới chạy EXPLAIN cho 2–3 câu chính trên dữ liệu giả lớn và dán kết quả vào PR.
- **Dữ liệu giả lớn:** thêm bộ seed riêng (khoảng 50.000 lead, 20.000 cơ hội) chỉ để thử tốc độ ở local, không nằm trong seed thường, không dùng dữ liệu thật.
- **Giao diện:** tách gói tải theo cổng và theo màn (lazy load). Trang đầu cổng CRM dưới khoảng 250 KB nén. CI có bước dò dung lượng chỉ báo số, không đặt ngưỡng trượt (anh Trường chốt 18/10/2026).
- **Trải nghiệm:** có trạng thái đang tải, khoá nút khi đang lưu, thử lại khi lỗi mạng. Chỉ tải lại phần cần, không tải lại cả trang.
- **Mục tiêu tham chiếu (không phải cứng):** danh sách mở dưới 1 giây, lưu một thao tác dưới 1 giây trên mạng 4G bình thường.
- **Băng thông gói Free:** tải ra 5 GB mỗi tháng. Không lấy cột không dùng.
- **PR:** mẫu mô tả PR thêm dòng "Đã kiểm hiệu năng: chỉ mục, phân trang, EXPLAIN".
- Bước dò dung lượng trong CI: nếu chưa đo được chính xác thì báo anh Trường trước khi đặt ngưỡng, không tự nới.

## Giao diện
- Chữ trên giao diện bằng tiếng Việt; tên biến, bảng, hàm bằng tiếng Anh.
- Ngoại lệ có chủ đích (Đ268): các nhãn "Filters", "Group By", "Favorites", "Save to Favorites" của khuôn K03 giữ tiếng Anh theo khuôn canvas; không dịch.
- Hệ thống thiết kế HMT (Claude Design làm): cam `#EF6925`, nền tối `#211C16`. Chưa có thì dùng component trung tính, không tự chế phong cách.
- Cổng CRM ưu tiên máy tính; cổng Giáo viên, Học tập ưu tiên điện thoại.

## Quy trình git và đưa lên chạy thật
- Nhánh riêng (`feat/…`, `fix/…`) → PR → CI xanh → gộp `main` → môi trường thử nghiệm tự cập nhật → anh Trường thử. Commit nhỏ, thông điệp rõ.
- **Đẩy một lần (Đ281, sửa 18/11/2026 theo anh Trường chốt 15:13):** trước khi mở PR hoặc đẩy commit chỉ chạy bộ nhanh trên máy: `npm run lint && npm run typecheck && npm run test && npm run check:hardcode && npm run format:check`. **pgTAP và Playwright do CI GitHub chạy** (repo công khai, miễn phí); không bật `db:start`, `db:reset`, `e2e` chỉ để thử CI. PR có migration hoặc RLS được chạy `db:test` trên máy cho file của mình, LẦN LƯỢT theo khoá `HOP-THU/LUOT-DB.txt` (ghi tên lane, xong xoá dòng và `npm run db:stop`; mỗi lúc một lane giữ DB). Lý do: Docker chỉ có 7,5 GB RAM, không chịu nổi nhiều lane chạy DB cùng lúc. Sửa theo góp ý thì gom lại, đẩy một lần; không đẩy commit chỉ để thử CI. Mô tả PR ghi «pgTAP/e2e: chờ CI». PR chỉ tài liệu không cần kiểm gì thêm.
- `docs/TIEN-DO.md` phải đúng với hiện trạng nhưng **PR có code KHÔNG sửa file này** (tránh xung đột và bắt anh OK lại; anh chốt 05/11). Mỗi tối gom một PR tài liệu riêng cập nhật `docs/TIEN-DO.md` cho mọi PR đã gộp trong ngày (viết như sau khi PR đã gộp; PR này chỉ sửa tài liệu). Việc phát sinh sau khi gộp ghi vào PR tài liệu kế tiếp.
- Chủ repo `hmt-platform`: **TÀI KHOẢN CHỦ DỰ ÁN** (từ 09/11/2026, Q-165; trước đó là TÀI KHOẢN DEPLOY). Claude Code dùng tài khoản này trên máy Mac. Chủ repo `hmt-deploy`: **TÀI KHOẢN DEPLOY** của anh Trường (đăng ký bằng email anh Trường đưa sau), bật xác thực hai bước, **chỉ dùng trên trình duyệt**, không bao giờ đăng nhập trên máy Mac này (`gh`, git, Keychain); TÀI KHOẢN CHỦ DỰ ÁN không có quyền ở `hmt-deploy`. TÀI KHOẢN GỘP của anh Trường là collaborator của `hmt-platform` (giữ), chỉ dùng trên trình duyệt, không đăng nhập trên máy Mac này; TÀI KHOẢN DEPLOY cũng là collaborator của `hmt-platform` (quyền Write). Commit trong `hmt-platform` ghi tên tác giả bằng email noreply của TÀI KHOẢN CHỦ DỰ ÁN, không dùng email của anh Trường. (Chốt 28/10/2026, Đ278, sửa bởi Đ279; chủ `hmt-platform` đổi ngày 09/11/2026, Q-165.)
- Cloudflare: tài khoản **thử nghiệm** đăng ký bằng `[email vận hành]+staging` (token nằm trong Secrets của `hmt-platform`); tài khoản **chạy thật** đăng ký bằng `[email chạy thật]`, chỉ dùng trên trình duyệt, token nằm trong Secrets của `hmt-deploy`.
- Supabase tách theo môi trường (10/10/2026): `hmt-staging` ở organization **HMT** của TÀI KHOẢN CHỦ DỰ ÁN (đăng nhập bằng GitHub); `hmt-prod` ở organization **HMT Prod** do tài khoản Supabase đăng ký bằng `[email chạy thật]` làm chủ (email + xác thực hai bước, chỉ dùng trên trình duyệt, không đăng nhập trên máy Mac). TÀI KHOẢN CHỦ DỰ ÁN không là thành viên HMT Prod.
- **Không khoá nào trong `hmt-platform` được chạm `hmt-prod`.** CI có bài kiểm chủ động: dùng token của `hmt-platform` thử đọc `hmt-prod`, phải bị từ chối.
- `hmt-deploy` đọc `hmt-platform` bằng `PLATFORM_READ_TOKEN`: token fine-grained do TÀI KHOẢN CHỦ DỰ ÁN tạo trên trình duyệt (chủ repo `hmt-platform`; hết hạn 07/11/2027), chỉ đọc đúng repo `hmt-platform`, dán vào Secrets của `hmt-deploy`.
- **Bản chạy thật chỉ được cập nhật từ repo `hmt-deploy`** mà chỉ anh Trường có quyền: khoá của bản chạy thật nằm ở đó, anh bấm chạy workflow (chọn tag/commit của `hmt-platform` đã qua thử nghiệm). Claude Code không có và không xin khoá chạy thật.
- Sao lưu bản chạy thật mỗi đêm cũng chạy từ `hmt-deploy`: xuất DB, mã hoá, đẩy lên Google Drive của `[email vận hành]`.
- **Khoá chạy thật không bao giờ nằm trên máy Mac**: không `supabase login`, không `wrangler login` bằng tài khoản thật; chuỗi kết nối DB prod và token Cloudflare prod chỉ dán thẳng vào GitHub Secrets của `hmt-deploy` trên web. Lấy token rclone xong thì xoá `~/.config/rclone/rclone.conf`.
- Claude Code không đọc, không xin, không tìm khoá chạy thật trên máy.
- **Gộp PR (từ 13/11/2026, Q-42, thay luật 10/10/2026 và Đ279):** chỉ Chat điều phối soát và gộp PR, toàn quyền, theo `docs/hmt/quy-trinh-lam-viec.md` của repo điều phối: base `main`, mergeable clean, CI xanh, đã đọc diff; PR rủi ro cao (migration, quyền, tiền) phải có comment `TESTER ĐẠT <sha>` đúng commit cuối. Gộp xong Chat comment `OK-CHAT <sha>`. Code và tester không tự gộp. Bản chạy thật vẫn chỉ anh Trường deploy.
- Mục nào trong yêu cầu ghi "anh duyệt trước" / "để anh duyệt" thì **dừng, gửi anh, chờ duyệt rồi mới làm/nạp**; không làm trước rồi báo sau.
- Khôi phục thử bản sao lưu: anh Trường tự chạy vào DB Docker tạm trên máy anh, xong xoá; Claude Code không chạy.

## Lệnh hay dùng
- `npm ci`: cài phụ thuộc (Node 24, Docker Desktop cho Supabase local).
- `npm run dev`: chạy giao diện (cần `.env.local`, xem `README.md`).
- `npm run db:start` / `npm run db:stop`: bật/tắt Supabase local; `npx supabase status` lấy URL, khoá công khai local.
- `npm run db:reset`: dựng lại DB local từ migration + `supabase/seed.sql`.
- `npm run db:test`: pgTAP (RLS, hàm nghiệp vụ).
- `npm run db:seed-users`: tạo tài khoản giả mỗi vai trò (cần `API_URL`, `SECRET_KEY`, `DB_URL`, `SEED_PASSWORD`, xem `README.md`).
- `npm run lint`, `npm run typecheck`, `npm run test`, `npm run check:hardcode`, `npm run format:check`: bộ kiểm tra nhanh như CI.
- `npm run check:all`: cả bộ kiểm như CI trên máy (nhanh ở trên, `db:reset`, `db:test`, `e2e`); **chỉ Tester hoặc ca đêm chạy khi cần**, không chạy trước mỗi lần đẩy (xem mục Đẩy một lần). Dừng `check:all` giữa chừng thì tắt `vite preview` còn sót ở cổng 4173 (`pkill -f 'vite preview --port 4173'`); `check:all` tự dừng và báo nếu thấy cổng này đang bị giữ.
- `npm run e2e`: Playwright máy tính + iPhone (lần đầu: `npx playwright install chromium webkit`). Cổng xem trước mặc định 4173; hai thư mục làm việc chạy song song thì đặt `E2E_PREVIEW_PORT` khác nhau (ví dụ 4173 và 4273), và mỗi thư mục có Supabase local riêng (`project_id` và cổng khác nhau trong `supabase/config.toml` cục bộ, không commit).
- `npx supabase migration new <ten>`: tạo file migration mới.

## Khi thiếu khuôn giao diện
- Mọi màn dựng từ thành phần và khuôn dùng chung (khuôn P0 trong `design/hmt-p0-p2/`). Không tự sao chép kiểu dáng vào từng màn, không tự chế kiểu hộp thoại hay khuôn mới.
- Màn chỉ khác khuôn ở trường và chữ: tự làm.
- Màn có cấu trúc hoặc cách tương tác mà không khuôn nào có: DỪNG màn đó, ghi vào mô tả PR (tên màn, mã màn trong `docs/design/ban-do-man-hinh.md`, khuôn gần nhất, chỗ còn thiếu) và báo anh. Phần còn lại của PR vẫn làm tiếp. Anh sẽ nhờ Design vẽ thêm khuôn, rồi mới làm tiếp màn đó.
- Nút, trường, chữ lấy đúng theo gói thiết kế. Không thêm nút hay trường không có trong thiết kế.
