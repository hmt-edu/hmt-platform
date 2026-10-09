# HMT Platform: luật làm việc cho Claude Code

Đọc file này và `docs/spec/` trước mỗi việc. Spec trong `docs/spec/` là chép từ tài liệu gốc của anh Trường; lệch nhau hoặc thiếu thì hỏi, không đoán.

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
- Thiết kế để nằm trong giới hạn gói Free: Supabase (DB 500 MB, tải ra 5 GB/tháng, 2 project), Cloudflare Pages, GitHub Free (phút Actions có hạn: CI gọn, có cache).
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
- Mã nghiệp vụ theo `docs/spec/02-chuan-ma-va-danh-muc.md`, cấp bằng hàm + sequence trong DB, không cho sửa.

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

## Giao diện
- Chữ trên giao diện bằng tiếng Việt; tên biến, bảng, hàm bằng tiếng Anh.
- Hệ thống thiết kế HMT (Claude Design làm): cam `#EF6925`, nền tối `#211C16`. Chưa có thì dùng component trung tính, không tự chế phong cách.
- Cổng CRM ưu tiên máy tính; cổng Giáo viên, Học tập ưu tiên điện thoại.

## Quy trình git và đưa lên chạy thật
- Nhánh riêng (`feat/…`, `fix/…`) → PR → CI xanh → gộp `main` → môi trường thử nghiệm tự cập nhật → anh Trường thử. Commit nhỏ, thông điệp rõ.
- Claude Code dùng tài khoản GitHub `hmt-vanhanh` (chủ repo `hmt-platform`) trên máy Mac của anh Trường.
- Repo `hmt-deploy` nằm ở **một tài khoản GitHub khác** chỉ anh Trường dùng; tài khoản đó không bao giờ đăng nhập trên máy Mac này (cả `gh`, git lẫn trình duyệt mà Claude Code điều khiển).
- **Bản chạy thật chỉ được cập nhật từ repo `hmt-deploy`** mà chỉ anh Trường có quyền: khoá của bản chạy thật nằm ở đó, anh bấm chạy workflow (chọn tag/commit của `hmt-platform` đã qua thử nghiệm). Claude Code không có và không xin khoá chạy thật.
- Sao lưu bản chạy thật mỗi đêm cũng chạy từ `hmt-deploy`: xuất DB, mã hoá, đẩy lên Google Drive của `lead.vanhanh.hmt@gmail.com`.
- **Khoá chạy thật không bao giờ nằm trên máy Mac**: không `supabase login`, không `wrangler login` bằng tài khoản thật; chuỗi kết nối DB prod và token Cloudflare prod chỉ dán thẳng vào GitHub Secrets của `hmt-deploy` trên web. Lấy token rclone xong thì xoá `~/.config/rclone/rclone.conf`.
- Claude Code không đọc, không xin, không tìm khoá chạy thật trên máy.
- Claude Code chỉ gộp PR khi CI xanh **và** anh Trường đã OK (comment "OK" trên PR hoặc nhắn trong chat).
- Khôi phục thử bản sao lưu: anh Trường tự chạy vào DB Docker tạm trên máy anh, xong xoá; Claude Code không chạy.

## Lệnh hay dùng
(Bổ sung sau bước 1.)
