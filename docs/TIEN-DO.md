# Tiến độ HMT Platform

Cập nhật: 12/10/2026. Người làm tiếp đọc file này trước, rồi CLAUDE.md, `docs/spec/`, `docs/nghiep-vu/`.

## Đang ở đâu

**Giai đoạn 0 (GĐ0), xong bước 3. Bước tiếp theo: bước 4 (màn quản trị), chờ anh Trường gửi yêu cầu.**

| Bước GĐ0 | Trạng thái | PR |
|---|---|---|
| 1. Hạ tầng: React/Vite, Supabase, CI, Cloudflare Pages, repo `hmt-deploy`, sao lưu, báo cáo tuần | Xong, đã lên chạy thật | #1 |
| 2. Nền dữ liệu: danh mục, nhật ký thao tác, cấp mã, Cài đặt, công tắc, ghi chú | Xong, đã lên chạy thật | #2–#5 |
| 3. Đăng nhập, phân quyền: Edge Function đăng nhập, 9 vai trò, ma trận quyền, RLS, quản trị tài khoản (hàm + Edge Function), soát bảo mật | Xong, đã lên chạy thật (trừ #12) | #6–#12 |
| 4. Màn quản trị (tài khoản, quyền, danh mục, Cài đặt, nhật ký) | Chưa bắt đầu | |
| 5. Khôi phục thử sao lưu, cảnh báo | Chưa bắt đầu | |

Bản chạy thật (`hmt-prod.pages.dev`) đang ở tag `staging-20261010-1642-75637cf` (trước #12). Đã cấu hình Supabase
hmt-prod (schema `app`, hook, Turnstile hai chỗ, IP forwarding, giới hạn 20/5 phút, chặn tự đăng ký, mật khẩu 8 ký tự
chữ + số, TOTP). Đã có Admin đầu tiên là anh Trường (gắn tạm CS5, đã xác thực hai bước).

## PR đang mở

Không có. Mọi PR #1–#12 đã gộp, mỗi commit gộp có link comment "OK" của `caotruong276`.

## Việc dở, việc tiếp theo

1. **Tài liệu cập nhật 12/10 của anh Trường** nằm ở `_cap-nhat-1210/` (chưa đưa vào git): `02-chuan-ma-va-danh-muc.md`,
   `04-luat-nghiep-vu.md`, `HMT_BAN_DO_MAN_HINH.md`, `HMT_DANH_MUC_VA_THAM_SO.md`. **Chưa xử lý.** Việc đầu tiên: so với
   `docs/spec/` (lưu ý spec 02 trong repo đã sửa mục Cơ sở thành CS3 Hội sở ở #12), báo anh chỗ lệch, anh chốt rồi mới
   chép vào `docs/spec/` bằng PR.
2. **Đưa #12 (CS3 Hội sở) lên chạy thật** khi anh muốn: hmt-deploy > Deploy production, tag
   `staging-20261010-1840-c3bc365`. Cùng lúc chép `deploy/.github/workflows/bootstrap-admin.yml` mới sang hmt-deploy (chỉ đổi
   mô tả ô cơ sở).
3. **Bước 4** (chờ yêu cầu của anh; phân tích, đề xuất trước, anh OK mới code). Đã hứa làm kèm:
   - Màn quản trị tài khoản (tạo, vai trò, cơ sở, khoá/mở, đặt lại mật khẩu) dùng Edge Function `admin-users` có sẵn.
   - Quản lý cơ sở trên giao diện (thêm, đổi tên, thứ tự, Ngừng; mã `CS` + số, không dùng lại; không Ngừng cơ sở còn
     nhân viên hoạt động hoặc lớp đang học). Hiện chỉ thêm được bằng migration.
   - Đổi tài khoản Admin của anh từ CS5 sang CS3 (qua màn quản trị, không sửa tay DB chạy thật).
   - Sau đăng nhập: địa chỉ cũ (`next`) không thuộc cổng được vào thì tự về cổng của mình.
   - Trang Đổi mật khẩu: gắn tên đăng nhập (trường username ẩn, `autocomplete`) để Chrome lưu đúng tài khoản.
   - Giao diện tự đưa về trang đăng nhập khi phiên bị thu hồi (khoá, bỏ vai trò, đổi cơ sở).
4. **Trước GĐ4**: L2 trong `docs/nghiep-vu/phan-quyen.md` (học sinh, phụ huynh chỉ đọc phần của mình). Giai đoạn 3: chốt
   trường dữ liệu giáo viên được xem (đề xuất: không thấy số điện thoại, địa chỉ phụ huynh).
5. **Để sau, khi anh sẵn sàng**: quên mật khẩu qua email (Resend/SMTP + DNS, Edge Function `send-email` đã có), tên miền
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

## Lưu ý cho người làm tiếp

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
- **Thư mục không đưa vào git**: `PROMPT-GD0-BUOC1.md`, `_cap-nhat-1210/`.
