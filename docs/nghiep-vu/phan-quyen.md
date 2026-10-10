# Đăng nhập và phân quyền (GĐ0 bước 3): bảng, luật, hàm

Spec: `docs/spec/03-dac-ta-giai-doan-0.md` (Đăng nhập, Phân quyền). Migration `20261010000009`…`012`.
Kiểm thử: `supabase/tests/database/007_phan_quyen.test.sql` (pgTAP), `supabase/functions/_shared/login-rules.test.ts`,
`src/lib/auth/claims.test.ts` (Vitest), `e2e/auth.spec.ts` (Playwright). Chốt với anh Trường 10/10/2026.

## Đăng nhập
- Nhân viên: email + mật khẩu. Học sinh: mã HS + mật khẩu; hệ thống đổi thành email nội bộ
  `<mã HS>@hocsinh.hoamatoan.edu.vn`, **không bao giờ gửi thư** tới địa chỉ này (Edge Function `send-email` bỏ qua).
- Trình duyệt không gọi thẳng Supabase Auth để đăng nhập mà gọi Edge Function `login`:
  1. `app.login_precheck(tên đăng nhập)`: tài khoản bị khoá hay đang khoá tạm thì từ chối.
  2. Gọi Supabase Auth (kèm mã Turnstile chống máy, IP thật của người dùng).
  3. `app.login_record(...)`: ghi `app.login_event` (thành công/sai mật khẩu/bị khoá, IP, trình duyệt);
     sai liên tiếp `login_lock_after_failures` lần thì khoá tạm `login_lock_minutes` phút.
- Không lộ tài khoản: sai tên, sai mật khẩu, tài khoản không có, tài khoản bị khoá đều trả cùng câu
  "Tên đăng nhập hoặc mật khẩu không đúng."; khoá tạm trả "Đăng nhập tạm thời bị chặn, thử lại sau.".
  Tên không có tài khoản cũng bị khoá tạm theo cùng luật (đếm trong `app.login_event`). Tài khoản bị khoá vẫn gọi
  Supabase Auth để thời gian trả lời giống sai mật khẩu, nhưng không bao giờ trả phiên. Lý do thật chỉ ở `app.login_event`.
  Luật nằm ở `decideLogin` (`supabase/functions/_shared/login-rules.ts`).
- Lần đầu đăng nhập bằng mật khẩu tạm (Admin cấp): bắt đổi mật khẩu (`/doi-mat-khau`), rồi
  `app.complete_first_password_change()` (chỉ nhận khi mật khẩu đã thật sự khác mật khẩu tạm).
- ADMIN, ACCOUNTANT bắt buộc xác thực hai bước (TOTP, `/xac-thuc-hai-buoc`); chưa xác thực thì RLS không cho đọc gì.
- Tự đăng xuất khi không thao tác: `staff_idle_logout_minutes`, `teacher_idle_logout_minutes`, `student_idle_logout_minutes`.
- Mật khẩu: tối thiểu `password_min_length`, có chữ và số (`password_require_letter_digit`); Supabase Auth cũng đặt 8 ký tự, chữ + số.
- Quên mật khẩu: code sẵn (`send-email`), chờ cấu hình gửi thư (SMTP/Resend + DNS) mới bật.

## Vai trò và phạm vi
| Vai trò | Phạm vi mặc định | Cổng | Hai bước |
|---|---|---|---|
| ADMIN | Toàn hệ thống | CRM (GV, Học tập: chỉ xem) | Bắt buộc |
| BRANCH_MANAGER | Cơ sở mình | CRM | |
| SALES, CSKH | Cơ sở mình | CRM | |
| ACCOUNTANT | Toàn hệ thống | CRM | Bắt buộc |
| TEACHER, TA | Được phân công | Giáo viên | |
| STUDENT | Chính mình | Học tập | |
| PARENT | (chưa cấp quyền, GĐ4) | | |

Phạm vi xếp từ rộng tới hẹp: Toàn hệ thống > Cơ sở > Được phân công > Của tôi > Chính mình.
Người nhiều vai trò lấy phạm vi rộng nhất trong các vai trò có quyền đó.

## Ma trận quyền `app.permission`
- Một dòng = vai trò × phân hệ (`PERM_MODULE`) × hành động (`PERM_ACTION`: Xem, Tạo, Sửa, Huỷ, Duyệt, Xuất, Giao việc) → phạm vi.
  Không có dòng = không có quyền. Admin sửa qua `app.set_permission` (ghi nhật ký). Phân hệ Quản trị chỉ ADMIN.
- Nạp từ `docs/seed/old_permission_matrix.csv`, đã sửa:
  - "Delete" cũ → Huỷ (không xoá cứng); phạm vi BRANCH → Cơ sở, ALL → Toàn hệ thống.
  - Trưởng cơ sở được Xuất file mọi phân hệ trong cơ sở; mỗi lần xuất ghi `app.export_log`.
  - CSKH giữ quyền lead, cơ hội như cũ.
  - Giáo viên, trợ giảng: phạm vi Được phân công; chấm phiếu test được giao (SALES, BM giao việc).
  - Thêm TA (quyền như giáo viên), STUDENT (Học tập, chính mình).
  - Tách quyền tiền (R-TIEN-01): **chỉ Kế toán** Duyệt phiếu thu (`RECEIPT`) và kế toán (`ACCOUNTING`: khoản tiền vào,
    đảo khoản, phiếu chi); ADMIN, Trưởng cơ sở không duyệt. Trưởng cơ sở chỉ Xem phân hệ Kế toán; vẫn duyệt đơn hàng.
  - Phiếu tái tục (`UPSALE`) không có bước Duyệt; Trưởng cơ sở chỉ Xem, Giao việc. Đơn hàng sinh từ tái tục duyệt như
    đơn thường (`SALES_ORDER`).
- Số dòng mặc định: ADMIN 132 (trừ Duyệt tiền, Duyệt tái tục; có Xem, Xuất Tài khoản), BRANCH_MANAGER 108, CSKH 44, SALES 37, ACCOUNTANT 15,
  TEACHER 14, TA 14, STUDENT 3.

## Kế toán vắng: gán tạm vai trò ACCOUNTANT
ADMIN không có quyền duyệt tiền. Khi kế toán vắng:
1. Admin vào quản trị tài khoản, thêm vai trò `ACCOUNTANT` cho người làm thay (giữ vai trò cũ của họ). Người đó phải
   bật xác thực hai bước (ACCOUNTANT bắt buộc) rồi mới duyệt được.
2. Kế toán về: Admin bỏ vai trò `ACCOUNTANT` của người làm thay; mọi phiên của người đó bị đăng xuất, quyền duyệt mất ngay.
3. Cả hai lần gán, bỏ đều ghi nhật ký thao tác (`app.user_role`: ai, lúc nào); phiếu thu (làm ở giai đoạn sau) sẽ ghi người duyệt.

Admin có thể tự gán `ACCOUNTANT` cho mình; luật "giữ ADMIN cuối cùng" vẫn áp: bỏ `ACCOUNTANT` được, bỏ `ADMIN` mà không
còn ADMIN khác thì bị chặn.

## Token và RLS
- Hook `app.custom_access_token_hook` ghi vào token: vai trò, cơ sở, cổng được vào, cổng chỉ xem, cần hai bước,
  phải đổi mật khẩu. Tài khoản bị khoá: hook từ chối cấp token.
- RLS không tin token cho trạng thái khoá: mỗi lần đọc kiểm `app.user_account` → khoá xong token cũ mất tác dụng ngay.
- Thu hồi phiên: token ghi `hmt_session_version`; RLS so với `app.user_account.session_version`. Khoá, bỏ bớt vai trò,
  đổi cơ sở → `app.revoke_user_sessions` tăng số này (mọi token cũ chết ngay) và xoá phiên ở Supabase Auth
  (không làm mới được, phải đăng nhập lại, lúc đó token mang vai trò, cơ sở mới). Chỉ thêm vai trò thì không đăng xuất.
- Luôn còn ít nhất một ADMIN hoạt động (vai trò ADMIN bật, tài khoản không khoá): trigger chặn khoá hay bỏ vai trò
  ADMIN cuối cùng ở mọi đường sửa (`HMT_ADMIN_CUOI_CUNG`).
- Danh mục, Cài đặt, công tắc: người đã đăng nhập (đủ điều kiện) đọc; ghi chỉ qua hàm, cần `ADMIN/SUA`.
- Nhật ký thao tác: chỉ ADMIN đọc. Tài khoản, vai trò, nhật ký đăng nhập: theo quyền `ACCOUNT · Xem` (ADMIN toàn hệ
  thống, Trưởng cơ sở cơ sở mình). Nhật ký xuất file: ADMIN và người có quyền xem Báo cáo. Không ai sửa, xoá nhật ký.
- Xoá cứng: chỉ ADMIN qua `app.admin_hard_delete` (bản ghi nhập nhầm), bắt buộc lý do, nhật ký chép cả dòng + lý do.

| Hàm | Làm gì | Ai gọi |
|---|---|---|
| `app.current_roles()`, `app.current_branch_id()` | Vai trò, cơ sở của người đang gọi | RLS, hàm |
| `app.current_user_active()` / `current_user_ready()` | Còn hoạt động / đủ điều kiện (không khoá, đã đổi mật khẩu, đủ hai bước) | RLS |
| `app.mfa_satisfied()` | Vai trò bắt hai bước đã xác thực hai bước | RLS |
| `app.permission_scope(phân hệ, hành động)` | Phạm vi rộng nhất được cấp | RLS, hàm |
| `app.has_permission(phân hệ, hành động)` | Có quyền không | RLS, hàm |
| `app.can_see_branch(phân hệ, hành động, cơ sở)` | Được thao tác dữ liệu cơ sở đó không | RLS |
| `app.set_permission(vai trò, phân hệ, hành động, phạm vi)` | Sửa ma trận (NULL = bỏ quyền) | Admin |
| `app.log_export(phân hệ, bộ lọc, số dòng)` | Ghi nhật ký xuất file | Giao diện trước khi xuất |
| `app.admin_hard_delete(bảng, id, lý do)` | Xoá cứng bản ghi nhập nhầm | Admin |
| `app.login_precheck`, `app.login_record` | Kiểm khoá, ghi lần đăng nhập | Edge Function `login` |
| `app.revoke_user_sessions(người)` | Thu hồi mọi phiên (token cũ chết, xoá phiên Auth) | Hàm quản trị tài khoản |
| `app.active_admin_count()` | Số ADMIN còn hoạt động | Trigger giữ ADMIN cuối cùng |
| `app.remember_temp_password(người)` | Ghi mã băm mật khẩu tạm vào bảng riêng | Hàm quản trị tài khoản |

## Quản trị tài khoản
Edge Function `admin-users` (khoá secret chỉ nằm trong Supabase secrets), gọi bằng token của Admin; mỗi việc gọi hàm DB
kiểm quyền `app.assert_account_admin()`:

| Việc | Hàm DB | Ghi chú |
|---|---|---|
| Tạo tài khoản | `app.admin_create_account` | Cấp mã NV/GV/TG mới hoặc giữ mã cũ; học sinh bắt buộc mã HS; bắt đổi mật khẩu lần đầu |
| Đổi vai trò | `app.admin_set_roles` | Ít nhất một vai trò; bỏ bớt vai trò thì đăng xuất mọi phiên; không bỏ ADMIN cuối cùng |
| Đổi cơ sở | `app.admin_set_branch` | Đăng xuất mọi phiên |
| Khoá / mở khoá | `app.admin_set_locked` | Bắt buộc lý do; không tự khoá mình; không khoá ADMIN cuối cùng; đăng xuất mọi phiên; Supabase Auth cấm đăng nhập |
| Đặt lại mật khẩu | `app.admin_mark_password_reset` | Bắt đổi lần đầu |

Admin đầu tiên của bản chạy thật: anh Trường tạo bằng workflow `bootstrap-admin` ở `hmt-deploy` (xem `deploy/README.md`).

## Tài khoản giả (thử nghiệm, local, CI)
`npm run db:seed-users` (`scripts/seed-users.ts`): 13 tài khoản `@thu.hoamatoan.invalid` ở CS1 và CS5, mỗi vai trò ít nhất
một, thêm `kiem.cs5` (BM + SALES), `khoa.cs5` (bị khoá), học sinh `HS900001` (phải đổi mật khẩu). Mật khẩu chung lấy từ
biến `SEED_PASSWORD`, không ghi trong repo. Script từ chối chạy nếu DB không có dữ liệu giả (chặn chạy nhầm trên bản chạy thật).

## Cần chốt ở giai đoạn 3
- **Giáo viên, trợ giảng xem được trường nào của học sinh, phụ huynh.** Ma trận hiện chỉ cho Xem `STUDENT` trong phạm vi
  Được phân công (học sinh lớp mình), chưa chia theo trường; GĐ0 chưa có bảng học sinh, phụ huynh.
  Đề xuất: giáo viên thấy tên, mã HS, lớp, khối, trường học, ghi chú học tập; **không thấy số điện thoại, địa chỉ,
  email của phụ huynh** (liên lạc phụ huynh qua CSKH). Cách làm: giáo viên đọc qua view hoặc hàm chỉ có các trường được
  phép, không đọc thẳng bảng. Anh chốt khi làm GĐ3.

## Soát bảo mật (10/10/2026)
Soát lần 1 trên PR #7. Mỗi lỗi có bài tái hiện trong `supabase/tests/database/008_soat_bao_mat.test.sql`,
`supabase/functions/_shared/cors-rules.test.ts`, `scripts/check-isolation.test.ts` (trước khi sửa đỏ, sau khi sửa xanh).
Sửa ở migration `20261010000014_sua_loi_soat_bao_mat.sql`.

| Mã | Lỗi | Cách sửa |
|---|---|---|
| C1 | Mã băm mật khẩu tạm đọc được qua API (Trưởng cơ sở đọc của nhân viên cùng cơ sở), nằm trong nhật ký thao tác | Bảng riêng `app.user_temp_password`, không ai đọc qua API, không ghi nhật ký; ghi qua `app.remember_temp_password` |
| C2 | Gọi thẳng Supabase Auth thì lách khoá tạm | Hook từ chối cấp token khi đang khoá tạm; bật Turnstile, giới hạn theo IP (`docs/van-hanh/chong-do-mat-khau.md`) |
| T1 | ADMIN, Kế toán chưa xác thực hai bước đọc, ghi được ghi chú mọi cơ sở | `can_see_note_target` đòi đủ hai bước như `has_permission` |
| T2 | Tài khoản bị khoá huỷ được ghi chú của mình bằng token cũ | `cancel_note` đòi tài khoản còn dùng được |
| T3 | Hàm mới trong `app` mặc định ai cũng chạy được, kể cả khách | Thu quyền mặc định ở mức toàn cục; hàm nào cần thì `GRANT` rõ |
| T4 | Khi đang khoá tạm, mỗi lời gọi ghi một dòng nhật ký (không qua Turnstile) → làm đầy DB | Mỗi tên đăng nhập chỉ ghi một dòng `KHOA_TAM` mỗi đợt khoá |
| L1 | Quyền xem tài khoản, nhật ký đăng nhập viết cứng vai trò Trưởng cơ sở | Phân hệ mới `ACCOUNT` trong ma trận; policy đọc qua `can_see_branch('ACCOUNT', 'XEM', …)` |
| L4 | Bản chạy thật nhận gọi từ trang xem trước của thử nghiệm | Chỉ bật khi `HMT_ALLOW_STAGING_PREVIEWS=true` (CI đặt cho thử nghiệm) |
| L5 | Bài kiểm cách ly chưa thử token Cloudflare; token hết hạn hay mã project gõ sai vẫn xanh | `scripts/check-isolation.sh`: mỗi khoá thử hai chiều, kiểm mã project có thật |

**S1 (phát hiện trên thử nghiệm sau khi gộp, 10/10/2026).** Edge Function `login` gọi Supabase Auth bằng khoá secret, mà
Supabase Auth bỏ qua Turnstile với lời gọi bằng khoá secret, nên mã chống máy giả vẫn qua. Sửa: Function tự kiểm mã với
Cloudflare (`supabase/functions/_shared/captcha.ts`, gửi kèm IP thật) trước mọi bước khác; mã sai thì dừng, không đếm khoá
tạm, không ghi nhật ký; thiếu khoá `HMT_TURNSTILE_SECRET` thì từ chối đăng nhập. Bài kiểm: `captcha.test.ts`, và bước
"Kiểm Edge Function login chặn mã chống máy giả" trong Deploy staging (gọi bản thử nghiệm thật).

**Khoá tạm là lớp bảo vệ thứ hai.** Khoá công khai (publishable) cho phép gọi thẳng Supabase Auth, không qua Edge
Function `login`, nên lần sai ở đường đó không được đếm, không vào `app.login_event` (gói Free không có hook kiểm mật
khẩu). Lớp chính: **Turnstile** (mỗi lần thử cần một mã chống máy), **giới hạn đăng nhập theo IP** của Supabase Auth, và
**xác thực hai bước** cho ADMIN, Kế toán. Hook chặn cấp token khi đang khoá tạm, nên đoán đúng mật khẩu trong lúc khoá
cũng không vào được.

**Chấp nhận (L3):** `get_setting*`, `feature_enabled` là `security definer`, nên tài khoản bị khoá còn token cũ vẫn đọc
được tham số Cài đặt và công tắc. Lý do chấp nhận: đây là tham số vận hành (số ngày, phần trăm, bật/tắt), không có dữ liệu
cá nhân hay tiền của ai; token cũ hết hạn sau tối đa một giờ và không làm mới được; hàm nghiệp vụ dùng các tham số này sẽ
tự kiểm quyền người gọi.

**Còn phải làm:**
- T5 (trước khi Deploy production): Edge Function `ip-check` (chỉ trả lời trên thử nghiệm, nơi khác 404) cho biết hạ tầng
  Supabase gửi header IP nào. Gọi nó kèm `X-Forwarded-For` giả để xem header nào người gọi không giả được, rồi sửa
  `clientIp` theo kết quả.

## Việc phải làm trước giai đoạn 4 (học sinh, phụ huynh dùng thật)
- **L2.** Hiện mọi người đã đăng nhập (kể cả học sinh, giáo viên) đọc được toàn bộ ma trận quyền, Cài đặt (trần chiết
  khấu, phí hoàn…), phòng mọi cơ sở, ghi chú phòng và cơ sở của cơ sở mình. Trước GĐ4: học sinh, phụ huynh chỉ đọc danh
  mục cần cho cổng Học tập; không đọc ma trận quyền, Cài đặt nội bộ, ghi chú; giáo viên không đọc ghi chú cơ sở trừ khi
  được cấp. Làm bằng policy theo ma trận (như L1), có bài kiểm thử từng vai trò.
