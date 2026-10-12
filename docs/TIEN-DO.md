# Tiến độ HMT Platform

Cập nhật: 12/10/2026 (sau PR 4a của bước 4). Người làm tiếp đọc file này trước, rồi CLAUDE.md, `docs/quy-trinh-phoi-hop.md`, `docs/spec/` (01, 02, 03, 04, 06), `docs/design/ban-do-man-hinh.md`, `docs/nghiep-vu/`.

## Đang ở đâu

**Giai đoạn 0 (GĐ0), đang làm bước 4 (khung giao diện ba cổng + màn quản trị). Xong PR 4a; tiếp theo là PR 4b.**

Bước 4 chia bốn PR (anh Trường đã OK kế hoạch 12/10):

| PR | Nội dung | Trạng thái |
|---|---|---|
| 4a | Gói thiết kế vào `design/hmt-platform/`, token, khung ba cổng (CHUNG-10, GV-01, HT-09), đăng nhập và các màn CHUNG-01…09, 13, 16, 17, 24, 25 | Xong |
| 4b | Khuôn dùng chung: bảng danh sách, bộ lọc, bản ghi (thanh trạng thái, nút liên kết, ghi chú + lịch sử), ô tìm kiếm, thông báo, các ô nhập (Combobox, DateRange, MoneyInput…), hộp thoại chặn/xác nhận | Chưa bắt đầu |
| 4c-1 | Tham số, danh mục, cơ sở và phòng học, công tắc tính năng | Chưa bắt đầu |
| 4c-2 | Người dùng, vai trò, ma trận quyền, nhật ký, tài khoản học sinh, CHUNG-20; file workflow khôi phục `bootstrap-admin` soạn ở `docs/hmt-deploy/` | Chưa bắt đầu |

| Bước GĐ0 | Trạng thái | PR |
|---|---|---|
| 1. Hạ tầng: React/Vite, Supabase, CI, Cloudflare Pages, repo `hmt-deploy`, sao lưu, báo cáo tuần | Xong, đã lên chạy thật | #1 |
| 2. Nền dữ liệu: danh mục, nhật ký thao tác, cấp mã, Cài đặt, công tắc, ghi chú | Xong, đã lên chạy thật | #2–#5 |
| 3. Đăng nhập, phân quyền: Edge Function đăng nhập, 9 vai trò, ma trận quyền, RLS, quản trị tài khoản (hàm + Edge Function), soát bảo mật | Xong, đã lên chạy thật (trừ #12) | #6–#12 |
| 4. Khung giao diện ba cổng + màn quản trị (tài khoản, quyền, danh mục, Cài đặt, nhật ký) | Đang làm: xong 4a, còn 4b, 4c-1, 4c-2 | #15 |
| 5. Khôi phục thử sao lưu, cảnh báo | Chưa bắt đầu | |

Bản chạy thật (`hmt-prod.pages.dev`) đang ở tag `staging-20261010-1642-75637cf` (trước #12). Đã cấu hình Supabase
hmt-prod (schema `app`, hook, Turnstile hai chỗ, IP forwarding, giới hạn 20/5 phút, chặn tự đăng ký, mật khẩu 8 ký tự
chữ + số, TOTP). Đã có Admin đầu tiên là anh Trường (gắn tạm CS5, đã xác thực hai bước).

## PR đang mở

Không có. Mọi PR #1–#15 đã gộp, mỗi commit gộp có link comment "OK" của `caotruong276`.

## Việc dở, việc tiếp theo

1. **Tài liệu 12/10 của anh Trường đã gộp vào repo (PR #14)**: spec 04 (132 luật, §10 Báo cáo, §11 Học tập, §12 Quyền và hệ
   thống), spec 02, mới `docs/spec/06-danh-muc-va-tham-so.md`, `docs/design/ban-do-man-hinh.md`,
   `docs/design/luat-cho-thiet-ke.md`, `docs/design/ma-luat-S02-S03.md`, `docs/van-hanh/so-tay-van-hanh.md`. **Chưa sửa code.** Mọi chỗ luật mới vênh với
   code, kèm bước nên sửa: `docs/nghiep-vu/doi-chieu-luat-1210.md` (mục A: các điểm anh đã chốt 12/10; mục B, C: việc
   phải sửa, phần lớn ở bước 4).
2. **Đưa #12 (CS3 Hội sở) lên chạy thật** khi anh muốn: hmt-deploy > Deploy production, tag
   `staging-20261010-1840-c3bc365`. Cùng lúc chép `deploy/.github/workflows/bootstrap-admin.yml` mới sang hmt-deploy (chỉ đổi
   mô tả ô cơ sở).
3. **Hai bước tối đa 2 thiết bị**: anh Trường đã đặt "Maximum number of per-user MFA factors" = 2 trên cả hmt-staging và
   hmt-prod (12/10; mặc định Supabase là 10). Local đặt trong `supabase/config.toml`.
4. **Bước 4, các PR còn lại** (4b, 4c-1, 4c-2). Đã hứa làm kèm:
   - Màn quản trị tài khoản (tạo, vai trò, cơ sở, khoá/mở, đặt lại mật khẩu) dùng Edge Function `admin-users` có sẵn.
   - Cơ sở là danh mục khoá (chốt 12/10): không thêm, không ngừng trên giao diện; màn QT-08 sửa tên hiển thị, địa chỉ,
     hotline và quản lý phòng học. Mở cơ sở mới qua migration.
   - Các mục "Bước 4" trong `docs/nghiep-vu/doi-chieu-luat-1210.md` (anh đã đồng ý thứ tự): tham số (đổi "ghi đè theo cơ
     sở", 3 tham số mới, giữ khoảng cho phép), khoá danh mục Môn/Khối/Trình độ và mục cha giai đoạn, đổi tên C4C, C4D,
     L5B, lý do khoá tài khoản theo danh mục, hai bước tối đa 2 thiết bị, đặt lại hai bước, vai trò gán tạm có thời hạn,
     hotline cơ sở, công tắc tính năng không có CS3, chế độ khôi phục của workflow `bootstrap-admin`. Màn QT-13 (tài
     khoản học sinh) ở bước 4 chỉ Admin dùng; CSKH từ giai đoạn 4.
5. **Trước GĐ4**: L2 trong `docs/nghiep-vu/phan-quyen.md` (học sinh, phụ huynh chỉ đọc phần của mình). Giai đoạn 3: chốt
   trường dữ liệu giáo viên được xem (đề xuất: không thấy số điện thoại, địa chỉ phụ huynh).
6. **Để sau, khi anh sẵn sàng**: quên mật khẩu qua email (Resend/SMTP + DNS, Edge Function `send-email` đã có), tên miền
   riêng (CNAME `app` → `hmt-prod.pages.dev`), bước 5.

## Quyết định gần đây chưa nằm trong docs/spec

Chi tiết ở `docs/nghiep-vu/phan-quyen.md` (ma trận, soát bảo mật) và `docs/van-hanh/chong-do-mat-khau.md`.

- **Tách môi trường Supabase**: `hmt-staging` ở org HMT (tài khoản `hmt-vanhanh`); `hmt-prod` ở org HMT Prod (tài khoản
  `truongcx.work`, MFA). Không khoá nào trong hmt-platform chạm được hmt-prod; CI kiểm chủ động hai chiều mỗi lần Deploy
  staging (`scripts/check-isolation.sh`).
- **Đăng nhập qua Edge Function `login`**: Function tự kiểm Turnstile (Supabase Auth bỏ qua Turnstile khi gọi bằng khoá
  secret); sai tên, sai mật khẩu, không có tài khoản, bị khoá đều trả cùng một câu; khoá tạm (10 lần sai, 15 phút) chỉ là
  lớp thứ hai, lớp chính là Turnstile, giới hạn theo IP (20/5 phút, IP forwarding bật) và hai bước cho ADMIN, Kế toán.
- **Ma trận quyền**: chỉ Kế toán duyệt phiếu thu, kế toán (ADMIN cũng không); kế toán vắng thì Admin gán tạm vai trò
  ACCOUNTANT (có nhật ký). Trưởng cơ sở: Kế toán chỉ Xem; phiếu tái tục Xem, Giao việc, Xuất file (không có bước Duyệt
  tái tục). Phân hệ mới `ACCOUNT` (xem tài khoản, vai trò, nhật ký đăng nhập).
- **Thu hồi phiên**: khoá, bỏ bớt vai trò, đổi cơ sở thì token cũ mất tác dụng ngay (`session_version`) và phiên Supabase
  bị xoá. Luôn còn ít nhất một ADMIN hoạt động.
- **CS3 = Hội sở**, cơ sở văn phòng (chỉ gắn tài khoản nhân viên). Spec 02 trong repo đã sửa; anh Trường sửa bản gốc.
- **Hàm mới trong schema `app` mặc định không ai chạy được**: mỗi migration phải `GRANT` rõ hàm nào cho ai.
- **Giao diện (từ PR 4a)**: màu, cỡ chữ, khoảng cách chỉ lấy từ `design/hmt-platform/tokens/HMT_DESIGN_TOKENS.css`
  (Tailwind 4, `src/index.css`); thành phần dựng lại trên Radix ở `src/ui/`, giữ tên như gói thiết kế; biểu tượng qua từ
  điển `src/ui/icons.tsx`. Menu CRM (`src/nav/crmMenu.ts`) chỉ khai cấu trúc và quyền cần có; ai thấy mục nào đọc từ ma
  trận quyền và công tắc tính năng trong DB. Khi vênh: spec 04 > bản đồ màn hình > gói thiết kế, ghi vào PR.
- **Đường dẫn**: `/dang-nhap`, `/dang-nhap/hoc-sinh`, `/xac-thuc-hai-buoc`, `/thiet-lap-hai-buoc`, `/quen-mat-khau`,
  `/dat-mat-khau`, `/doi-mat-khau`, `/khong-dang-nhap-duoc`, `/chon-cong`, `/khong-co-quyen`, `/trang-thai` (trang kiểm
  tra kết nối cũ), `/crm/...`, `/gv/...`, `/hoc/...`. Hồ sơ cá nhân: `/<cổng>/tai-khoan`.
- **Quên mật khẩu**: hai màn đã dựng nhưng chưa gửi thư; màn luôn trả cùng một câu và bảo liên hệ quản trị viên.

## Lưu ý cho người làm tiếp

- **Ảnh so sánh với thiết kế**: `SO_SANH=1 npx playwright test e2e/so-sanh.spec.ts --project=may-tinh` ghép ảnh thiết kế
  và bản dựng vào `docs/so-sanh/<MÃ>.jpg`; chạy xong chạy lại `npm run db:seed-users`. Màn mới thì thêm vào kịch bản này.
- **Kiểm thử giao diện**: Playwright hai cỡ `may-tinh` (1440×900) và `dien-thoai` (390×844), mỗi màn gọi
  `expectAccessible` (axe, chặn lỗi nghiêm trọng). Tua thời gian bằng `page.clock`, không sửa tay mốc thời gian.
- **File anh Trường đưa vào** nằm ở `_inbox/` (không commit), dùng xong xoá.
- **Mỗi PR** cập nhật luôn file này (viết như sau khi PR đã gộp).

- **Duyệt PR**: chỉ gộp khi CI xanh **và** có comment "OK" từ `caotruong276` **sau commit cuối**. Trước khi nhắc anh
  duyệt, kiểm comment trên PR trước (anh hay OK sẵn). Gộp squash, ghi link comment OK vào thân commit gộp.
- **Khoá chạy thật**: không bao giờ đọc, xin, tìm. Mọi việc với hmt-prod, Cloudflare thật, `hmt-deploy` do anh làm trên
  trình duyệt; Claude hướng dẫn từng việc một, viết cho người mới, nhắc "không chụp màn hình lúc khoá hiện".
- **Chép file sang hmt-deploy**: `LANG=en_US.UTF-8 pbcopy < deploy/…`, anh dán vào
  `https://github.com/caotruong276/hmt-deploy/edit/main/<đường dẫn>` (file mới: `/new/main?filename=<đường dẫn>`).
- **Mật khẩu chung tài khoản giả** nằm ở secret `STAGING_SEED_PASSWORD` và ứng dụng Mật khẩu của anh (mục
  `hmt-staging.pages.dev`). Không in ra chat; nếu cần tạo mới thì sinh thẳng vào bộ nhớ copy (`pbcopy`).
- **Hạn token**: `SUPABASE_ACCESS_TOKEN` (hmt-platform, chỉ hmt-staging) và `PROD_SUPABASE_ACCESS_TOKEN` (hmt-deploy, chỉ
  Edge Functions của hmt-prod) đều hết hạn 09/10/2027; báo cáo tuần nhắc trước 30 ngày. Token Supabase tối đa 1 năm, chọn
  lùi một ngày nếu báo lỗi.
- **Máy local**: Docker không nằm trong PATH mặc định, thêm `/Applications/Docker.app/Contents/Resources/bin`. Sửa Edge
  Function xong phải `docker restart` container `edge_runtime` mới nạp code mới. Chạy `db:seed-users` trên DB local rồi
  chạy pgTAP vẫn đúng (bài ADMIN cuối cùng đã tự loại ADMIN giả), nhưng `db:reset` cho sạch thì chắc hơn.
- **Chẩn đoán trên thử nghiệm** (không có khoá staging trên máy): tạo nhánh tạm thêm job `workflow_dispatch` vào `ci.yml`
  đọc secret, chạy `gh workflow run ci.yml --ref <nhánh>`, đọc log job, huỷ lượt chạy, xoá nhánh. Không in khoá.
- **File không đưa vào git**: `PROMPT-GD0-BUOC1.md`.
