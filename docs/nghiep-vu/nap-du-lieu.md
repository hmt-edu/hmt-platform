# Nạp dữ liệu cũ theo loại (màn Nhập, chỉ Admin)

Luật: `docs/spec/04` mục 14, R-V2-29 đến R-V2-34 (anh Trường chốt 04/11/2026, Đ285). File mẫu dữ liệu giả `HMT5_FILE_MAU_NAP_DU_LIEU_GIA.xlsx` nằm trong `_inbox/` (không commit). Thứ tự nạp: Người dùng, Lớp, **Phụ huynh, Học sinh**, Ghi danh, Số dư, Cơ hội, Phiếu test. T4a (migration 068) làm Phụ huynh và Học sinh; T4b (migration 069, Edge Function `import-users`) làm Người dùng; các loại còn lại làm ở các bước sau.

## Quy tắc chung (mọi loại)
- Giao diện đọc file, gửi tối đa `import_max_rows` hàng (Cài đặt, mặc định 1000, 1 đến 5000) dạng JSON; quá thì chặn cả lô.
- **Xem trước rồi nạp:** cùng một hàm, `p_commit = false` chạy hết rồi hoàn tác nên kết quả luôn khớp nạp thật.
- Mỗi dòng có trạng thái: `HOP_LE` (nạp), `TRUNG` (đã có, bỏ qua, nêu mã hồ sơ có sẵn), `LOI` (kèm câu tiếng Việt). Dòng lỗi và trùng không chặn dòng hợp lệ (nhóm CRM). Nạp lại thì dòng đã nạp thành `TRUNG`: **không ghi đè, không gộp**.
- Mã cũ (`ma_cu`) lưu vào `legacy_ref`, có chỉ mục. Mã mới cấp theo chuẩn mã (`PH`, `HS`).
- **Không in dữ liệu cá nhân:** kết quả, thông báo lỗi và nhật ký nạp không có họ tên, SĐT, mã cũ. Mỗi dòng chỉ có số dòng trong file và chữ cái đầu của tên (không dấu, viết hoa), ví dụ `Dòng 12 (N.)`. Lỗi hệ thống lạ chỉ báo mã lỗi, không chép nội dung. (Nhật ký thao tác `audit_log` của từng hồ sơ mới tạo ghi giá trị như mọi hồ sơ khác trong hệ thống; khác với nhật ký nạp.)
- Nhật ký nạp: `app.import_log` (loại, người nạp, tên file, tổng, số nạp, trùng, lỗi). Admin đọc.

## Hàm
| Hàm | Việc | Quyền |
|---|---|---|
| `app.import_records(loại, hàng, nạp thật?, tên file)` | Chạy cả lô, trả `{mode, kind, total, imported, duplicates, errors, rows[{row, label, initial, status, code, message}]}` | Admin (ADMIN · Tạo, đã xác thực hai bước) |
| `app.import_one_parent`, `app.import_one_student` | Một hàng Phụ huynh, Học sinh (nội bộ) | Không gọi trực tiếp |
| `app.import_text`, `import_initial`, `import_phone`, `import_branch` | Làm sạch ô, chữ cái đầu, SĐT (10 số bắt đầu 0, nhận +84), cơ sở (mã có thật) | Nội bộ |

## Phụ huynh (tab `01_PHUHUYNH`)
Cột: `ma_cu`, `ho_ten`, `sdt`, `sdt_2`, `ho_ten_2` (người thân), `dia_chi`, `co_so`. Cột `nguon_tab`, `nguon_dong` bỏ qua.
- Bắt buộc: mã cũ, họ tên, SĐT (10 số), cơ sở là mã có thật (CS1 đến CS5). SĐT thứ hai nếu có cũng 10 số; trùng số chính thì coi như không có.
- **Trùng mã cũ → TRUNG.** **Trùng SĐT hoặc SĐT thứ hai** với hồ sơ có sẵn (số chính hoặc số thứ hai) hoặc dòng trước trong file → TRUNG, bỏ qua, không tự gộp (gộp làm ở màn Gộp trùng).

## Học sinh (tab `02_HOCSINH`)
Cột: `ma_cu`, `ho_ten`, `ngay_sinh` (yyyy-mm-dd), `gioi_tinh` (Nam/Nữ), `sdt_ph`, `truong`, `loai_truong`, `khoi` (1 đến 12), `ghi_chu` (mục tiêu), `co_so`.
- Bắt buộc: mã cũ, họ tên, ngày sinh (có năm sinh), khối 1 đến 12, SĐT phụ huynh, cơ sở có thật. Giới tính Nam/Nữ nếu có.
- `sdt_ph` khớp phụ huynh theo SĐT chính hoặc thứ hai. **Không khớp → LOI**, không tự tạo phụ huynh (nạp Phụ huynh trước).
- **Trùng mã cũ → TRUNG.** Cùng phụ huynh, tên chuẩn hoá và năm sinh với học sinh có sẵn → TRUNG (R-CRM-27).
- Không có cột SĐT học sinh (anh chốt 04/11).

## Kiểm thử
`supabase/tests/database/059_t4a_nap_phu_huynh_hoc_sinh.test.sql` (46 bài): quyền, giới hạn dòng, xem trước không ghi, từng luật đúng và bị chặn, nạp lại không ghi đè, trùng SĐT thứ hai, và bài quét kết quả + nhật ký không chứa họ tên, SĐT, mã cũ.

## Người dùng (tab `00_NGUOIDUNG`, T4b, migration 069)
Tạo tài khoản cần quyền máy chủ nên làm ở **Edge Function `import-users`** (chỉ Admin đã xác thực hai bước, cùng khuôn `admin-users`), gọi các hàm DB bằng token của Admin. Khoá secret chỉ nằm trong secrets của Supabase.

Luồng: (1) `app.import_users_resolve` kiểm từng dòng, không tạo gì (xem trước); (2) nạp thật: tạo người dùng Auth (mật khẩu tạm ngẫu nhiên, đã xác nhận, không gửi thư), `app.import_user_create` (qua `admin_create_account`), gắn quản lý trực tiếp `app.import_user_set_manager` sau khi tạo hết, khoá người nghỉ `app.import_user_lock` sau khi gắn quản lý, `app.import_users_finish` ghi nhật ký. Lỗi ở dòng nào thì gỡ người dùng Auth vừa tạo của dòng đó.

Cột: `username`, `ho_ten`, `ma_nv`, `vai_tro`, `co_so_truy_cap`, `trang_thai`, `email`, `quan_ly`.
- `username` đúng dạng (chữ thường không dấu, số, dấu chấm, gạch), duy nhất; lưu vào `legacy_ref` của tài khoản để các loại nạp sau (Cơ hội, Phiếu test) tra người phụ trách. Trùng trong file là `LOI`; đã có tài khoản cùng tên đăng nhập là `TRUNG`, bỏ qua, không ghi đè.
- `email`: đúng dạng; **trống thì `username@<tên miền>`**, tên miền là tham số Cài đặt `import_user_email_domain` (mặc định là miền giả `tam.invalid`; Admin đặt miền thật ở bản chạy thật, không viết trong repo). Email đã dùng cho người khác là `LOI`.
- `vai_tro`: có trong danh mục, không phải học sinh hay phụ huynh. Mã nhân viên cấp mới theo chuẩn mã (TEACHER thì GV, TA thì TG, còn lại NV); `ma_nv` cũ không lưu (không đúng chuẩn mã).
- `co_so_truy_cap`: một cơ sở thì làm cơ sở chính. **Nhiều cơ sở hoặc ALL: lấy cơ sở đầu làm cơ sở chính (ALL: cơ sở đầu không phải văn phòng), báo cảnh báo (không LOI) và ghi nguyên văn vào `app.import_user_branch_pending`** để áp lại khi làm PR danh sách cơ sở theo người. Mã cơ sở không có thật là `LOI`.
- `quan_ly`: tên đăng nhập có trong file hoặc đã có trong hệ thống, không phải chính mình; gắn vào `manager_id` (luật R-HT-06 kiểm trong `set_manager`).
- `trang_thai`: Đang làm / Nghỉ phép / Đã nghỉ (trống là Đang làm); hai loại sau vẫn nạp, **khoá tài khoản** (lý do "Nạp dữ liệu cũ") và cấm đăng nhập ở Auth.

**Mật khẩu tạm:** ngẫu nhiên, độ dài theo Cài đặt `import_temp_password_length` (không nhỏ hơn độ dài tối thiểu mật khẩu chung), bắt đổi ở lần đăng nhập đầu. **Trả một lần** trong lần nạp thật về trình duyệt Admin để tải file giao người dùng (tên đăng nhập + mật khẩu tạm); không lưu ở máy chủ, không vào `audit_log` hay nhật ký nạp, không gửi email; phản hồi đặt `Cache-Control: no-store`. Nạp lại cùng file không trả mật khẩu lần hai.

**Không in dữ liệu cá nhân:** kết quả trả về trình duyệt, thông báo lỗi, cảnh báo và nhật ký nạp không có họ tên, email, tên đăng nhập; chỉ số dòng và chữ cái đầu của tên. Cột `resolved` (có email, tên đăng nhập) chỉ dùng trong Edge Function và bị bỏ trước khi trả về.

Kiểm thử: `supabase/tests/database/060_t4b_nap_nguoi_dung.test.sql` (quyền, từng luật kiểm dòng, miền email là tham số, tạo tài khoản, quản lý, khoá, nhật ký, quét không lộ dữ liệu cá nhân), Vitest `supabase/functions/_shared/temp-password.test.ts` (mật khẩu tạm). Đã chạy thử Edge Function trên Supabase local: xem trước, nạp (3 tài khoản, 1 lỗi), nạp lại (0 nạp, 3 bỏ qua, không trả mật khẩu).

## Màn Nhập (QT-18, T5)
Đường dẫn `/crm/quan-tri/nhap-du-lieu`, chỉ Admin. Dựng tối giản theo khuôn hộp nhiều bước K4b ⑤ (Design chưa vẽ, anh chốt 05/11 không chờ). Code: `src/pages/nhap-du-lieu/`.
- Loại nạp hiện có: Người dùng (gọi Edge Function `import-users`), Phụ huynh, Học sinh (gọi `app.import_records`). Cơ hội, Phiếu test thêm khi làm T4c, T4d.
- File: **CSV UTF-8** (mỗi tab của file mẫu một file), dòng đầu là tên cột như trong file mẫu; dấu "," hoặc ";". Thiếu cột bắt buộc thì chặn ngay ở bước tải file, nêu tên cột; cột lạ bị bỏ qua và liệt kê. Quá `import_max_rows` dòng thì chặn cả file.
- Bước 1 Tải file; bước 2 Xem trước (cùng hàm với nạp thật, `commit = false`): ô đếm Hợp lệ, Trùng, Lỗi bấm để lọc; bảng 50 dòng mỗi trang, mỗi dòng chỉ có số dòng, chữ cái đầu tên, kết quả, câu giải thích (không họ tên, SĐT, email).
- Nạp thật rồi hộp kết quả: số dòng nạp, trùng, lỗi; nút **Tải dòng lỗi và trùng** (file gốc kèm cột `ket_qua`, `ly_do`, Admin sửa rồi nạp lại; dòng đã nạp báo trùng, bỏ qua). Người dùng: nút **Tải file mật khẩu tạm** (hiện một lần, chưa tải thì chưa đóng được hộp).
- Kiểm thử: Vitest `importFile.test.ts`; Playwright `e2e/nhap-du-lieu.spec.ts` (nạp Phụ huynh thật; Người dùng chỉ kiểm bước tải file vì Edge Function không chạy ở môi trường kiểm thử).
