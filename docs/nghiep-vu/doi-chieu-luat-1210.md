# Đối chiếu luật 12/10/2026 với code đã có

Lập khi gộp tài liệu 12/10 vào `docs/spec/` (04, 02, 06) và `docs/design/`. **Chưa sửa code.** Anh Trường đã chốt mọi điểm vênh
(mục A) và đồng ý thứ tự làm ở mục B, D, E (12/10).
Mỗi dòng: chỗ vênh, file liên quan, nên sửa ở bước nào. Sửa xong dòng nào thì xoá dòng đó; hết thì xoá file.

## A. Đã chốt 12/10 (các điểm hai nguồn nói khác nhau)

| # | Điểm vênh | Anh Trường chốt | Tài liệu đã sửa | Việc code phát sinh |
|---|---|---|---|---|
| A1 | Admin duyệt thay việc tiền | **Việc tiền** (duyệt phiếu thu, đảo khoản, phiếu chi): giữ chốt 10/10, Admin không duyệt trực tiếp; kế toán vắng thì gán tạm vai trò Kế toán, có nhật ký, **có thời hạn**. **Việc không dính tiền** (yêu cầu buổi, đơn, lớp, ticket): Admin làm thay trực tiếp, lịch sử ghi "Admin duyệt thay" | R-HT-01 (spec 04) | Ma trận quyền hiện tại đã đúng. Mới: B17, B18, B19 |
| A2 | Cơ sở có thêm được trên giao diện không | Theo spec 06: danh mục khoá, **không thêm, không ngừng** trên giao diện; sửa được tên hiển thị, địa chỉ, hotline; phòng học thêm, sửa, ngừng được; mở cơ sở mới qua migration | spec 06 #1, QT-08, `docs/TIEN-DO.md` | B20 |
| A3 | Màn CHUNG-08 báo "tài khoản bị khoá" | Giữ chốt 10/10: đăng nhập không lộ trạng thái khoá. CHUNG-08 là thông báo chung "Không đăng nhập được", kèm hướng dẫn liên hệ quản trị | CHUNG-08 | Code đăng nhập đã đúng; bước 4 dựng màn theo câu mới |
| A4 | Mã dự phòng hai bước | **Bỏ mã dự phòng.** Mỗi người đăng ký tối đa **2 thiết bị TOTP**. Admin đặt lại hai bước cho người khác ở QT-02. Admin mất cả hai thiết bị: khôi phục bằng workflow `bootstrap-admin` ở hmt-deploy | CHUNG-02, CHUNG-03, CHUNG-13; `docs/van-hanh/so-tay-van-hanh.md` | B16, B21, B22 |
| A5 | 143 hay 126 phường, xã | Dùng số đã nạp trong repo (126) | spec 06 #29 | Không |
| A6 | Loại hoạt động | **Giữ 6 mục đã nạp** (Gọi điện, Zalo, Email, Gặp trực tiếp, SMS, Nhắc thu tiền) | spec 06 #16 | Không |
| A7 | Ai cấp tài khoản học sinh | CSKH quản lý tài khoản học sinh cơ sở mình **từ giai đoạn 4**. Bước 4: màn QT-13 chỉ Admin dùng | QT-13 | B24 (giai đoạn 4) |
| A8 | File luật cho thiết kế, bảng mã `S02-*`, `S03-*` | Đưa vào `docs/design/luat-cho-thiet-ke.md` và `docs/design/ma-luat-S02-S03.md`, có link trong bản đồ màn hình | `docs/design/` | Không |
| — | Tên giai đoạn con khác spec 06 | **Giữ tên đã nạp trong repo**; chỉ đổi hai chỗ: "opp" thành "cơ hội" ở C4C, C4D; L5B thành "Đã xếp lịch test" | spec 06 mục 1.2, 1.3 | Xem B10 |
| — | Khoảng cho phép, ghi đè theo cơ sở của tham số | **Khoảng cho phép giữ như cơ sở dữ liệu**; "ghi đè theo cơ sở" theo spec 06; thêm 3 tham số mới với khoảng của spec 06 | spec 06 mục 2 | B13, B14, bảng C |

## B. Dữ liệu, hàm đã có nhưng khác luật mới (sửa bằng migration, không sửa migration cũ)

| # | Nội dung vênh | File | Sửa ở |
|---|---|---|---|
| B1 | Tình trạng ghi danh thiếu **`DA_XEP_LOP` Đã xếp lớp** (R-GD-05); danh mục hệ thống `ENROLLMENT_STATUS` có 7 mục | migration 003; `006_du_lieu_danh_muc.test.sql` | Giai đoạn 2 (ghi danh), hoặc gộp vào đợt danh mục bước 4 |
| B2 | **Mã gói**: `app.build_package_code(loại, môn, khối, hình thức)` trả `LC-TOAN-K09-OFF`; luật mới không có hình thức, có dải khối `K03K07`, và mã `DV-…`, `TL-…` không có môn, khối | `20261010000004_cap_ma.sql`; `004_cap_ma.test.sql`; `docs/nghiep-vu/nen-du-lieu.md` | Giai đoạn 1 (cấu hình bán hàng), trước khi có gói nào |
| B3 | Chưa có danh mục khoá **Loại gói** (`LC`, `VIP`, `VNN`, `KR`, `DV`, `TL`); hàm trên nhận loại bất kỳ viết hoa | như B2 | Giai đoạn 1 |
| B4 | **Loại cấp mã mới** `LD`, `CO`, `PKT`, `GD`, `TT` (6 số, toàn hệ thống) chưa có trong `app.code_format`; `app.issue_person_code` chỉ nhận `HS`, `PH`, `NV`, `GV`, `TG` | `20261010000004_cap_ma.sql` | Giai đoạn 1 (`LD`, `CO`, `PKT`), giai đoạn 2 (`GD`, `TT`) |
| B5 | Chứng từ **`KTV`** (khoản tiền vào, khoản đảo dùng chung dãy) chưa có trong danh mục `DOC_TYPE` (đang có BG, DH, PT, PC, DN, KN) | migration 003, 008 | Giai đoạn 1 |
| B6 | Chứng từ **không ghi CS3** (R-TIEN-34, R-HT-02): `app.issue_document_number` chưa chặn cơ sở văn phòng (mã lớp đã chặn) | `20261010000004_cap_ma.sql`, `20261011000015_hoi_so_cs3.sql` | Giai đoạn 1 |
| B7 | **Công tắc tính năng không có CS3** (R-HT-02): `app.set_feature` chưa chặn cơ sở văn phòng | `20261010000006_cong_tac_tinh_nang.sql` | Bước 4 (QT-10) |
| B8 | Danh mục **Môn, Khối, Trình độ** đang là loại Mở (`MO`); spec 06 ghi **Khoá** | migration 003 | Bước 4 (QT-07) |
| B9 | **Giai đoạn lead, cơ hội**: spec 06 ghi "khoá mục cha" (C1–C4, L1–L8 không thêm, không ngừng), **C4D khoá**; hiện là danh mục Mở, chưa khoá mục nào | migration 003 | Bước 4 (QT-07) |
| B10 | **Tên hiển thị giai đoạn con**: giữ tên đã nạp; chỉ đổi hai chỗ: C4C, C4D dùng "cơ hội" thay "opp"; L5B thành "Đã xếp lịch test" | migration 003 | Bước 4, một migration |
| B11 | **Lý do khoá tài khoản** là danh mục (#32) và "Khác" bắt buộc ghi chú (R-HT-04); `app.admin_set_locked` đang nhận lý do gõ tự do | `20261010000013_bao_ve_admin_thu_hoi_phien.sql`, Edge Function `admin-users` | Bước 4 (QT-02) |
| B12 | Danh mục lý do có **"Khác" bắt buộc ghi chú** (R-HT-04); danh mục #24 có trường **"Áp dụng cho"** (nhiều giá trị): bảng `app.catalog_item` chưa có thuộc tính nào cho hai việc này | `20261010000002_danh_muc.sql` | Bước 4 (thiết kế QT-07), dùng từ giai đoạn 1 |
| B13 | **Tham số**: đổi "ghi đè theo cơ sở" thành Không ở 7 tham số và nhóm SLA; thêm 3 tham số mới; sửa tên hiển thị, mô tả của `session_autoclose_before_minutes` (bảng C). Khoảng cho phép **không đổi** | migration 005, 008, 011 | Bước 4 (QT-09) |
| B14 | `seed.sql` và bài kiểm `005` ghi đè `quotation_validity_days` cho CS5; tham số này không còn được ghi đè | `supabase/seed.sql`, `005_cai_dat_cong_tac_ghi_chu.test.sql` | Cùng B13: đổi sang `max_sessions_ahead` (được ghi đè) |
| B15 | Ma trận quyền: **CSKH huỷ buổi** (R-BUOI-09) nhưng CSKH chưa có `SESSION · Huỷ`; **chốt tháng giờ dạy** (R-GV-14: Kế toán, Admin) chưa có phân hệ/hành động tương ứng | migration 010 | Giai đoạn 2 (buổi học), giai đoạn 3 (giờ dạy) |
| B16 | QT-02 có hành động **"Đặt lại hai bước"**: chưa có hàm (thu hồi phiên đã có) | Edge Function `admin-users` | Bước 4 |
| B17 | Gán tạm vai trò Kế toán **có thời hạn** (A1): bảng `app.user_role` chưa có ngày hết hạn; hết hạn phải tự tắt vai trò và thu hồi phiên | `20261010000009_vai_tro_tai_khoan_quyen.sql`, `20261010000013_bao_ve_admin_thu_hoi_phien.sql`; `docs/nghiep-vu/phan-quyen.md` mục "Kế toán vắng" | Bước 4 (QT-02) |
| B18 | Lịch sử ghi **"Admin duyệt thay"** khi Admin duyệt việc không dính tiền (A1) | Các hàm duyệt (chưa có) | Từ giai đoạn 1, trong từng hàm duyệt |
| B19 | Màn **TC-05, TC-09, TC-11** còn ghi vai trò "KT, AD" và dẫn R-HT-01: Admin chỉ xem, không có nút Duyệt, Đảo, Lập phiếu chi (A1) | `docs/design/ban-do-man-hinh.md` | Bước 4 (khung giao diện), dựng thật ở giai đoạn 1, 2 |
| B20 | Cơ sở sửa được tên hiển thị, địa chỉ, **hotline** (A2): bảng `app.branch` chưa có cột hotline, chưa có hàm cho Admin sửa | `20261010000002_danh_muc.sql` | Bước 4 (QT-08) |
| B21 | Tối đa **2 thiết bị TOTP** mỗi người (A4): Supabase đang cho 10 (`max_enrolled_factors` trong `supabase/config.toml`; trên hmt-staging, hmt-prod đặt ở Authentication > Multi-Factor). Trang hai bước chưa có chỗ thêm, gỡ thiết bị | `supabase/config.toml`, `src/pages/MfaPage.tsx` | Bước 4 (CHUNG-13); anh đổi số trên hai project |
| B22 | **Khôi phục Admin mất cả hai thiết bị** bằng workflow `bootstrap-admin` (A4): workflow hiện từ chối khi đã có ADMIN và không gỡ được thiết bị hai bước | `deploy/.github/workflows/bootstrap-admin.yml` | Bước 4 |
| B24 | **CSKH** cấp, khoá, đặt lại mật khẩu tài khoản **học sinh cơ sở mình** (A7): các hàm `app.admin_*` và Edge Function `admin-users` chỉ cho ADMIN | `20261010000012_quan_tri_tai_khoan.sql`, `20261010000014_sua_loi_soat_bao_mat.sql`, `supabase/functions/admin-users` | **Giai đoạn 4**: thêm quyền trong ma trận (phân hệ `ACCOUNT`), hàm chỉ nhận vai trò STUDENT, đúng cơ sở. Bước 4: QT-13 chỉ Admin |

## C. Tham số: việc phải sửa trong cơ sở dữ liệu (bước 4)

Chốt 12/10: **khoảng cho phép giữ như cơ sở dữ liệu** (spec 06 đã sửa cho khớp). Chỉ sửa ba việc dưới đây.

**1. Đổi "ghi đè theo cơ sở" từ Có thành Không** (theo spec 06): `quotation_validity_days`, `deposit_min_amount`,
`package_default_validity_months`, `reservation_max_months`, `session_autoclose_before_minutes`,
`teacher_session_complete_hours`, `complaint_reopen_max_days`, và 7 tham số `sla_*`. Trước khi đổi, xoá các giá trị ghi đè
đang có của những tham số này (hiện chỉ có dữ liệu giả, B14).

Vẫn được ghi đè: `max_sessions_ahead`, `upsale_hours_left_threshold`, `upsale_days_left_threshold`, `absence_risk_sessions`,
`session_autoclose_scan_hours`. Các tham số tiền, đăng nhập còn lại vốn đã là Không.

**2. Thêm 3 tham số mới**

| Tham số | Mặc định | Khoảng | Ghi đè theo cơ sở | Luật |
|---|---|---|---|---|
| `absence_risk_window_days` | 30 ngày | 7–180 | Có | R-GD-13 |
| `trial_sessions_max_per_opportunity` | 2 buổi | 0–5 | Có | R-GD-17 |
| `complaint_parent_confirm_days` | 3 ngày | 1–14 | Không | R-CS-14 |

**3. Hai chỗ sửa cho đúng nghĩa**

- `session_autoclose_before_minutes`: R-GIO-05 và spec 06 coi đây là **chu kỳ quét** ("mỗi 30 phút quét một lần"); tên hiển thị và
  mô tả trong cơ sở dữ liệu lại ghi "tự chốt **trước giờ học** bao nhiêu phút". Giữ key (đã dùng), sửa tên hiển thị và mô tả.
- Tự đăng xuất giáo viên, học sinh (`teacher_idle_logout_minutes`, `student_idle_logout_minutes`): cơ sở dữ liệu lưu **phút**
  (code `useIdleLogout` đọc phút), màn QT-09 hiện theo **ngày**.

## D. Danh mục trong spec 06 chưa có trong cơ sở dữ liệu (làm mới, không vênh)

| Danh mục spec 06 | Làm ở |
|---|---|
| #8 Loại gói; #14 Hình thức test; #15 Cấp độ đề test; #24 Lý do từ chối; #26 Hình thức thu tiền; #27 Tài khoản nhận tiền (theo cơ sở); #31 Lý do đảo khoản | Giai đoạn 1 |
| #12 Giai đoạn phiếu tái tục; #17 Lý do liên hệ khi điểm danh; #19 Nhóm đề nghị (thêm "Dừng học"); #20 Nhóm khiếu nại; #21 Mức độ khiếu nại; #22 Kênh tiếp nhận; #23 Lý do huỷ buổi; #25 Lý do điều chỉnh giờ; #28 Lý do không tái tục | Giai đoạn 2 |
| #32 Lý do khoá tài khoản | Bước 4 |
| #30 Tên hiển thị các bước trạng thái | Theo từng giai đoạn có trạng thái đó |

Đã có và khớp: #1 Cơ sở (5, CS3 văn phòng), #2 Phòng học, #3 Môn (10), #4 Khối (K02–K12), #5 Phân loại lớp, #6 Trình độ, #7 Hình
thức học (`OFF`, `ONL`), #9 Nguồn lead (6 loại, 11 nguồn, 14 kênh), #10 Giai đoạn lead (4 + 15), #11 Giai đoạn cơ hội (8 + 49),
#13 Lý do huỷ test (11, nối L5C–L5O), #18 Trạng thái BTVN (5).

## E. Luật mới chỉ cần nhớ khi làm (chưa có code liên quan)

Các luật 12/10 còn lại (R-CRM-09…11, R-TIEN-06…08, 15, 29…34, R-GD-05, 13…17, R-LOP-11…12, R-BUOI-09…10, R-GIO-07, R-GV-11,
13…14, R-CS-02, 03, 07, 13…14, R-BC-01…05, R-LMS-01…05, R-HT-02…05) thuộc giai đoạn 1 trở đi, chưa có bảng hay hàm nào để vênh.
