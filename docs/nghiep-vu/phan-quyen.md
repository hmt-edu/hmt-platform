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
  Không có dòng = không có quyền. Admin sửa qua `app.save_permission_matrix` (từ PR 6d; mỗi lần Lưu một phiên bản, xem mục dưới). Phân hệ Quản trị chỉ ADMIN.
- Nạp từ `docs/seed/old_permission_matrix.csv`, đã sửa:
  - "Delete" cũ → Huỷ (không xoá cứng); phạm vi BRANCH → Cơ sở, ALL → Toàn hệ thống.
  - Trưởng cơ sở được Xuất file mọi phân hệ trong cơ sở, **trừ Phụ huynh, Học sinh (chỉ Admin Xuất, R-CRM-29, phiên bản 4)**; mỗi lần xuất ghi `app.export_log`.
  - CSKH giữ quyền lead, cơ hội như cũ.
  - Giáo viên, trợ giảng: phạm vi Được phân công; chấm phiếu test được giao (SALES, BM giao việc).
  - Thêm TA (quyền như giáo viên), STUDENT (Học tập, chính mình).
  - Tách quyền tiền (R-TIEN-01): **chỉ Kế toán** Duyệt phiếu thu (`RECEIPT`) và kế toán (`ACCOUNTING`: khoản tiền vào,
    đảo khoản, phiếu chi); ADMIN, Trưởng cơ sở không duyệt. Trưởng cơ sở chỉ Xem phân hệ Kế toán; vẫn duyệt đơn hàng.
  - Phiếu tái tục (`UPSALE`) không có bước Duyệt; Trưởng cơ sở Xem, Giao việc, Xuất file (danh sách sắp hết giờ của
    cơ sở mình, chốt 11/10/2026). Đơn hàng sinh từ tái tục duyệt như đơn thường (`SALES_ORDER`).
- Số dòng mặc định (sau PR 6e): ADMIN 160 (trừ Duyệt tiền, Duyệt tái tục; có Xem, Xuất Tài khoản), BRANCH_MANAGER 122, CSKH 51, SALES 43,
  ACCOUNTANT 16, TEACHER 15, TA 15, STUDENT 3.

## Tách phân hệ quyền (PR 6e, anh Trường chốt 12/10 và 16/10)
Trước: cả menu Cấu hình và Quản trị dùng chung quyền "Quản trị · Xem", nên chỉ Admin thấy menu Cấu hình. Sau: Quản trị giữ
nguyên (chỉ Admin), thêm bốn phân hệ quyền (danh mục `PERM_MODULE`):

| Phân hệ | Mục menu | Quyền (ngoài ADMIN, ADMIN đủ 7 hành động toàn hệ thống) |
|---|---|---|
| Cấu hình bán hàng `CONFIG_SALES` | Gói bán, Bảng giá, Chiết khấu, Điều khoản thanh toán, Chiến dịch marketing | Xem, toàn hệ thống: Trưởng cơ sở, Kế toán, Tuyển sinh, CSKH |
| Cấu hình đào tạo `CONFIG_TRAINING` | Khung chương trình, Rubric | Xem, toàn hệ thống: Trưởng cơ sở, CSKH, giáo viên, trợ giảng |
| Ngày nghỉ lễ `HOLIDAY` | Ngày nghỉ lễ | Trưởng cơ sở: Xem, Tạo, Sửa, Huỷ, cơ sở mình. Tuyển sinh, CSKH: Xem, cơ sở mình |
| Lịch hẹn `APPOINTMENT` | Lịch hẹn (nhóm Tuyển sinh) | Trưởng cơ sở: như Cơ hội (đủ 7 hành động, cơ sở mình). Tuyển sinh, CSKH: Xem, Tạo, Sửa, Huỷ, cơ sở mình (mở lại tính là Sửa) |

- Giáo viên, trợ giảng, học sinh, phụ huynh không có Lịch hẹn, Ngày nghỉ lễ; học sinh, phụ huynh không có phân hệ mới nào.
- "Người duyệt ticket" (QT-15) vẫn thuộc Quản trị, chỉ Admin.
- Nạp bằng `app.save_permission_matrix`, nên là phiên bản 2 của ma trận, có danh sách 57 ô.
- **Luật khi viết hàm sửa ngày nghỉ lễ (chưa có hàm):** ngày nghỉ chung (không gắn cơ sở) chỉ Admin sửa; Trưởng cơ sở chỉ
  tạo, sửa, huỷ ngày nghỉ của cơ sở mình; mọi vai trò có quyền Xem thấy cả ngày nghỉ chung.
- **Luật mới:** vai trò ADMIN luôn giữ đủ quyền phân hệ Quản trị (7 hành động, toàn hệ thống). Lần lưu nào bỏ hoặc thu hẹp
  thì báo `HMT_ADMIN_GIU_QUYEN_QUAN_TRI`, hoàn tác cả lần lưu; ngay cả sửa trực tiếp bảng quyền cũng bị chặn (trigger).
- Lịch sử phiên bản quyền (`permission_version`, `permission_change`): chặn sửa, xoá, xoá sạch, báo
  `HMT_LICH_SU_QUYEN_CHI_THEM`.

## Ma trận phiên bản 3: Giao việc, Huỷ, Duyệt = gộp trùng (PR P3b1, anh duyệt 17/10)
Nạp 15 ô, phạm vi cơ sở mình, ghi chú của phiên bản: "Duyệt trên Lead, Cơ hội, Phụ huynh, Học sinh = gộp trùng (R-CRM-22)".

| Vai trò | Phân hệ | Hành động thêm |
|---|---|---|
| Tuyển sinh | Lead, Cơ hội | Giao việc, Duyệt |
| Tuyển sinh | Phụ huynh, Học sinh | Duyệt |
| Tuyển sinh | Kiểm tra đầu vào | Huỷ |
| CSKH | Lead, Cơ hội | Giao việc, Duyệt |
| CSKH | Phụ huynh, Học sinh | Duyệt |
| CSKH | Kiểm tra đầu vào | Huỷ, Giao việc |

- **Duyệt** trên Lead, Cơ hội, Phụ huynh, Học sinh = **gộp trùng** (R-CRM-22, R-CRM-25): Tuyển sinh, CSKH, Trưởng cơ sở gộp trong cơ sở
  mình; Admin mọi cơ sở; hai hồ sơ khác cơ sở chỉ Admin. Các phân hệ này chưa có luồng duyệt nào khác.
- Giáo viên, trợ giảng vẫn không Huỷ phiếu kiểm tra (xem lại khi làm cổng giáo viên).

## Ma trận phiên bản 4: Phụ huynh, Học sinh dùng chung (anh duyệt TRƯỚC / SAU 18/10, migration `20261018000029`)
Nạp 17 ô theo R-CRM-26, 27, 29. Ghi chú của phiên bản: "R-CRM-26, 27, 29: hồ sơ phụ huynh, học sinh dùng chung toàn hệ thống, không Tạo tay, chỉ Admin Xuất".

| Thay đổi | Vai trò | TRƯỚC | SAU | Số ô |
|---|---|---|---|---|
| Bỏ Tạo (R-CRM-27) | Tuyển sinh, CSKH, Trưởng cơ sở, Admin | có Tạo | không | 8 |
| Bỏ Xuất (R-CRM-29) | Trưởng cơ sở | Xuất, cơ sở mình | không (chỉ Admin còn Xuất) | 2 |
| Xem toàn hệ thống (R-CRM-26) | Tuyển sinh, CSKH, Trưởng cơ sở | Xem, cơ sở mình | Xem, **toàn hệ thống** (Sửa, Duyệt vẫn cơ sở mình) | 6 |
| Thêm Xem Phụ huynh | Kế toán | không có | Xem, toàn hệ thống | 1 |
| Giữ nguyên | Giáo viên, trợ giảng | Xem Học sinh (được phân công) | không đổi | 0 |

- Hồ sơ phụ huynh, học sinh ở mọi cơ sở đọc được (RLS đọc theo phạm vi của ô Xem); hộp "trùng SĐT" thấy đủ thông tin phụ huynh cơ sở khác. Sửa, Duyệt (gộp trùng) vẫn trong cơ sở mình.
- Hồ sơ chỉ sinh trong hàm nghiệp vụ (R-CRM-27); Admin cũng không còn Tạo ở hai phân hệ này. Luật "ADMIN giữ quyền Quản trị" chỉ bảo vệ phân hệ Quản trị nên không bị ảnh hưởng.
- Kiểm thử: `supabase/tests/database/021_ma_tran_quyen_phien_ban_4.test.sql`; các bài đếm quyền của 017, 018 đã chỉnh theo.


## Kế toán vắng: gán tạm vai trò ACCOUNTANT
ADMIN không có quyền duyệt tiền. Khi kế toán vắng:
1. Admin vào quản trị tài khoản, thêm vai trò `ACCOUNTANT` cho người làm thay (giữ vai trò cũ của họ). Người đó phải
   bật xác thực hai bước (ACCOUNTANT bắt buộc) rồi mới duyệt được.
2. Kế toán về: Admin bỏ vai trò `ACCOUNTANT` của người làm thay; mọi phiên của người đó bị đăng xuất, quyền duyệt mất ngay.
3. Cả hai lần gán, bỏ đều ghi nhật ký thao tác (`app.user_role`: ai, lúc nào); phiếu thu (làm ở giai đoạn sau) sẽ ghi người duyệt.

**Chốt lại 12/10/2026 (R-HT-01):** cách này giữ nguyên, thêm yêu cầu gán tạm **có thời hạn** (hết hạn tự tắt vai trò, thu hồi
phiên). Phần thời hạn chưa có trong code, làm ở bước 4 (mục B17 của `docs/nghiep-vu/doi-chieu-luat-1210.md`).

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
| `app.save_permission_matrix(phiên bản đang xem, danh sách ô đổi, [ghi chú])` | Lưu nhiều ô quyền thành MỘT phiên bản mới, hiệu lực ngay (ô: vai trò, phân hệ, hành động, phạm vi hoặc null = bỏ quyền); ghi chú tuỳ chọn của phiên bản | Admin (màn QT-05) |
| `app.permission_current_version()` | Số phiên bản hiện hành | Màn QT-05 |
| `app.set_permission(vai trò, phân hệ, hành động, phạm vi)` | Sửa một ô; **hàm nội bộ**, giao diện không gọi được (từ PR 6d) | Migration, kết nối thẳng DB |
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
- **T5 xong (10/10/2026, thử trên hmt-staging bằng Edge Function `ip-check`).** `cf-connecting-ip` luôn là IP thật; gửi kèm
  `CF-Connecting-IP` giả thì Cloudflare chặn cả yêu cầu (error 1000). `x-forwarded-for` bị hạ tầng viết lại: giá trị giả bị
  bỏ, phần tử đầu là IP thật. `True-Client-IP`, `Forwarded`, `X-Envoy-External-Address` đi nguyên từ người gọi (giả được),
  HMT không dùng. Kết luận: `clientIp` (ưu tiên `cf-connecting-ip`, rồi phần tử đầu `x-forwarded-for`) đúng trên Supabase,
  không cần sửa. `ip-check` giữ lại để thử lại khi Supabase đổi hạ tầng; chỉ trả lời trên thử nghiệm.

## Phiên bản ma trận quyền (PR 6d)
- `app.permission_version` (số phiên bản liền nhau, người lưu, giờ lưu, số ô đổi) và `app.permission_change` (ô đổi: vai trò,
  phân hệ, hành động, phạm vi cũ → mới; rỗng = không có quyền). Chỉ thêm, không sửa, không xoá; chỉ Quản trị đọc.
- Phiên bản 1 là "Khởi tạo" (ma trận lúc triển khai). Mỗi lần Lưu là một phiên bản, có hiệu lực ngay, không hẹn ngày; lịch sử
  chỉ xem, không khôi phục.
- Lưu gửi kèm số phiên bản đang xem. Có người vừa lưu thì báo `HMT_PHIEN_BAN_CU`, không ghi đè. Không có ô đổi thật thì
  `HMT_KHONG_CO_THAY_DOI`, không tạo phiên bản. Một ô sai thì hoàn tác cả lần lưu.
- Admin không bỏ được quyền Quản trị của vai trò ADMIN (luật thêm ở PR 6e, xem mục Tách phân hệ quyền).

## Việc phải làm trước giai đoạn 4 (học sinh, phụ huynh dùng thật)
- **L2.** Hiện mọi người đã đăng nhập (kể cả học sinh, giáo viên) đọc được toàn bộ ma trận quyền, Cài đặt (trần chiết
  khấu, phí hoàn…), phòng mọi cơ sở, ghi chú phòng và cơ sở của cơ sở mình. Trước GĐ4: học sinh, phụ huynh chỉ đọc danh
  mục cần cho cổng Học tập; không đọc ma trận quyền, Cài đặt nội bộ, ghi chú; giáo viên không đọc ghi chú cơ sở trừ khi
  được cấp. Làm bằng policy theo ma trận (như L1), có bài kiểm thử từng vai trò.
