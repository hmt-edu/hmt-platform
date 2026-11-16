# Nạp dữ liệu cũ theo loại (màn Nhập, chỉ Admin)

Luật: `docs/spec/04` mục 14, R-V2-29 đến R-V2-34 (anh Trường chốt 04/11/2026, Đ285). File mẫu dữ liệu giả `HMT5_FILE_MAU_NAP_DU_LIEU_GIA.xlsx` nằm trong `_inbox/` (không commit). Thứ tự nạp: Người dùng, Lớp, **Phụ huynh, Học sinh**, Ghi danh, Số dư, Cơ hội, Phiếu test. T4a (migration 068) làm Phụ huynh và Học sinh; T4b (migration 069, Edge Function `import-users`) làm Người dùng; các loại còn lại làm ở các bước sau.

## Quy tắc chung (mọi loại)
- Giao diện đọc file, gửi tối đa `import_max_rows` hàng (Cài đặt, mặc định 300 từ migration 216, 1 đến 5000) dạng JSON; quá thì chặn cả lô.
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
- Loại nạp hiện có (theo thứ tự trên màn): Người dùng (gọi Edge Function `import-users`), **Cơ hội** (T4c, gọi `app.import_records`, báo cáo theo giai đoạn, số dòng thiếu thông tin em, số dòng gắn vào phụ huynh có sẵn), Phụ huynh, Học sinh. Phiếu test thêm khi có file thật (T4d).
- File: **CSV UTF-8** (mỗi tab của file mẫu một file), dòng đầu là tên cột như trong file mẫu; dấu "," hoặc ";". Thiếu cột bắt buộc thì chặn ngay ở bước tải file, nêu tên cột; cột lạ bị bỏ qua và liệt kê. Quá `import_max_rows` dòng thì chặn cả file.
- Bước 1 Tải file; bước 2 Xem trước (cùng hàm với nạp thật, `commit = false`): ô đếm Hợp lệ, Trùng, Lỗi bấm để lọc; bảng 50 dòng mỗi trang, mỗi dòng chỉ có số dòng, chữ cái đầu tên, kết quả, câu giải thích (không họ tên, SĐT, email).
- Nạp thật rồi hộp kết quả: số dòng nạp, trùng, lỗi; nút **Tải dòng lỗi và trùng** (file gốc kèm cột `ket_qua`, `ly_do`, Admin sửa rồi nạp lại; dòng đã nạp báo trùng, bỏ qua). Người dùng: nút **Tải file mật khẩu tạm** (hiện một lần, chưa tải thì chưa đóng được hộp).
- Kiểm thử: Vitest `importFile.test.ts`; Playwright `e2e/nhap-du-lieu.spec.ts` (nạp Phụ huynh thật; Người dùng chỉ kiểm bước tải file vì Edge Function không chạy ở môi trường kiểm thử).
## Cơ hội (tab `05_COHOI`, T4c, migration 072)
Loại nạp `CO_HOI` của `app.import_records`. Mỗi dòng tạo **ba thứ trong một giao dịch**: phụ huynh (nếu SĐT chưa có), lead gốc (C4, nhóm con C4D "Tạo cơ hội thành công") và cơ hội ở giai đoạn thẳng từ file (bỏ qua luật chuyển giai đoạn; chỉ hàm nạp làm vậy). Cơ hội nạp **riêng được**, không cần hồ sơ học sinh: các em chỉ là chữ trong danh sách em của lead và cơ hội (tối đa 5).
- Cột: `ma_cu` (SĐT, khoá một SĐT một cơ hội), `ngay_tao` (yyyy-mm-dd), `ho_ten_ph`, `sdt_ph`, `sdt_2`, `danh_sach_em` (cách nhau dấu chấm phẩy), **`nam_sinh`** (năm sinh từng em, cùng thứ tự, tuỳ chọn; **file mẫu hiện chưa có cột này**), `khoi`, `truong`, `dia_chi`, `nhu_cau`, `nguon_goc`, `nguon`, `medium` (tên hoặc mã cũ trong danh mục nguồn ba tầng, ví dụ "Facebook Ads: Inbox"), `co_so`, `nguoi_phu_trach` (tên đăng nhập = `legacy_ref` của tài khoản: nạp Người dùng trước), `nguoi_phu_trach_goc`, `tinh_trang_cu`, `giai_doan` (L1 đến L8), `nhom_con`, `ghi_chu`. Cột `nguon_tab`, `nguon_dong`, `da_la_phu_huynh` bỏ qua.
- Luật: trùng `ma_cu` thì TRUNG, bỏ qua, không ghi đè. SĐT phụ huynh trùng hồ sơ có sẵn (số chính hoặc số thứ hai) thì **gắn vào phụ huynh đó kèm cảnh báo** (có mã hồ sơ), chưa có thì tạo phụ huynh mới và đánh dấu `opportunity_import = true`. **Ngoại lệ R-CRM-03 CHỈ cho lượt nạp (anh chốt 05/11):** từ L5 trở lên thiếu tên và/hoặc năm sinh em đầu thì **vẫn nạp**, đánh dấu `student_info_missing` ("thiếu thông tin em (dữ liệu cũ)") kèm cảnh báo; năm sinh **không suy từ khối** (để trống, giữ nguyên cột `khoi` ở ghi chú); số dạng năm hoặc chữ "tuổi" trong `nhu_cau`, `ghi_chu` không dùng. Cơ hội có dấu **phải bổ sung tên và năm sinh em đầu trước khi sang bước tiếp theo** (`change_opportunity_stage` báo `HMT_THIEU_THONG_TIN_EM`); **đóng cơ hội** (khách không mua, ngừng chăm sóc: nhóm con L7M đến L7S) **luôn được**, kể cả còn dấu (anh chốt 05/11) **hoặc ghi danh** (chặn khi làm Ghi danh); đủ tên và năm sinh thì dấu tự gỡ. Luật R-CRM-03 giữ nguyên cho cơ hội tạo mới. Cơ hội L7, L8 ghi lý do bỏ qua test `NAP_CU` "Nạp dữ liệu cũ" (danh mục 33, trạng thái Ngừng). Người phụ trách phải cùng cơ sở; tài khoản đã khoá vẫn nhận cơ hội cũ, kèm cảnh báo. Nguồn có kênh thì bắt buộc có `medium`.
- Ngày tạo cũ ở **cột riêng** `legacy_created_at` của lead và cơ hội; `created_at` vẫn là lúc ghi thật. Mã cũ vào `legacy_ref`.
- Ghi chú gắn cơ hội: ghi chú gốc, "Tình trạng cũ", "Khối", "Người phụ trách gốc" (mỗi phần một dòng).
- **Báo cáo sau nạp (chỉ số lượng):** kết quả có khoá `summary`: `by_stage` (số cơ hội theo giai đoạn), `missing_student_info` (số dòng đánh dấu thiếu thông tin em), `attached_parent` (số dòng gắn vào phụ huynh có sẵn).
- **Cách nối Phụ huynh, Học sinh nạp sau (anh chốt 05/11; làm ở lượt nạp Phụ huynh, Học sinh):** (1) **Phụ huynh nối theo số điện thoại**: dòng Phụ huynh gặp phụ huynh `opportunity_import = true` cùng SĐT (chính hoặc thứ hai) thì bổ sung ô trống và mã cũ vào hồ sơ đó, không tạo trùng, không ghi đè. (2) **Em nối theo tên và năm sinh nếu có**: dòng Học sinh khớp phụ huynh theo SĐT, rồi tìm em cùng tên (chuẩn hoá) và cùng năm sinh trong các cơ hội của phụ huynh đó; **nếu em của cơ hội thiếu năm sinh thì nối theo tên** trong các cơ hội của phụ huynh đó. (3) **Khớp mơ hồ** (nhiều em có thể khớp) thì **không tự nối**, liệt kê để anh chọn (kết quả báo số dòng mơ hồ, không in họ tên). Em nối xong thì gắn `student_id` vào dòng em của cơ hội.
- Kiểm thử: `supabase/tests/database/063_t4c_nap_co_hoi.test.sql`.

## Chốt chặn tên đăng nhập khi nạp Người dùng (migration 078, anh chốt 06/11: Q-24)

- Bước kiểm `import_users_resolve` coi dòng là **TRUNG** (bỏ qua, báo) khi tên đăng nhập đã có ở cột `username` (không phân biệt hoa thường) hoặc ở `legacy_ref` của một tài khoản nhân sự. Nhờ vậy Admin đầu tiên tạo bằng Bootstrap rồi đặt tên đăng nhập bằng `set_username` không bị nạp thêm tài khoản thứ hai. Ràng buộc duy nhất của `username` (migration 074) vẫn là chốt cuối.
- Quản lý trực tiếp (`quan_ly`) tra theo cả `username` lẫn `legacy_ref`.
- File nạp 108 người: bộ chuyển loại mọi người trạng thái Đã nghỉ (Q-04, Q-26; người Nghỉ phép vẫn nạp) và dòng ADMIN của anh Trường, tên đăng nhập `<tên đăng nhập Admin>` (Q-24, Admin đầu tiên tạo bằng Bootstrap trên bản chạy thật).

## Ghi danh: vá và chặn cả loại (Code B, 15/11/2026, migration 150)
Hàm nạp chung của các loại đào tạo là `app.import_training_records(loại, hàng, nạp thật, tên file)` (loại `LOP`, `GHI_DANH`, `BUOI_HOC`, `DIEM_DANH`). Kiểm thử: `supabase/tests/database/150_nap_ghi_danh_va.test.sql` và `106_...`.
- **Chặn cả loại ngay trong hàm (R-V2-30):** nạp thật `GHI_DANH` còn một dòng lỗi thì không ghi dòng nào; kết quả `mode = CHAN_CA_LOAI`, `imported = 0`; nhật ký nạp ghi lần này với 0 dòng nạp. Trước đây chỉ nút Nạp ở giao diện bị khoá.
- `tinh_trang_moi` trống: **Chờ xếp lớp** kèm cảnh báo. "Đã xếp lớp" (có trong danh mục, mã `DA_XEP_LOP`) được **đổi sang trạng thái cuối** vì ghi danh nạp thẳng trạng thái đang học: **Đang học** nếu có `ngay_vao_lop`, không thì **Chờ xếp lớp**, kèm cảnh báo (Chat chốt H1, 15/11).
- `gio_con_lai` âm: lỗi `HMT_NAP_GIO_AM` (Q-253).
- `gio_con_lai` bằng 0: vẫn sinh dòng "Số dư đầu kỳ" 0 giờ (Q-177). Ràng buộc sổ giờ nới chỉ cho loại `DAU_KY`; mọi loại dòng khác vẫn cấm 0 giờ.
- Cột script không dùng: `sdt_ph`, `ho_ten_hs`, `mon`, `loai_lop`, `hinh_thuc` (Offline/Online, chưa có chỗ lưu), `tinh_trang_cu`, `ngay_chot`, `lich_hoc`.

## Phiếu test (tab `06_PHIEUTEST`, migration 151)
Loại `PHIEU_TEST` của `app.import_training_records`. Nhóm CRM: dòng lỗi không chặn dòng đúng; trùng `ma_cu` thì TRUNG (lưu ở `legacy_ref` của phiếu). Kiểm thử: `151_nap_phieu_test.test.sql`.
- Cột nhận: `ma_cu`, `sdt_ph`, `sdt_2`, `ngay_test` (yyyy-mm-dd), `gio_test` (hh:mm, giờ Việt Nam), `ho_ten_hs`, `khoi`, `mon` (trống là Toán), `diem` (dấu phẩy được), `trang_thai_phieu`, `ly_do_huy`, `ghi_chu`. Cột khác bỏ qua.
- Phiếu gắn vào **cơ hội có mã cũ = SĐT** (số chính, không thấy thì `sdt_2`) và vào **em trong danh sách em của cơ hội** (tên chuẩn hoá khớp `ho_ten_hs`, cột `prospect_student_id` bắt buộc). Không thấy cơ hội: LỖI `HMT_NAP_CO_HOI_CHUA_CO`; không thấy em: `HMT_NAP_EM_CHUA_CO`; chưa có hồ sơ học sinh cùng phụ huynh và tên: `HMT_NAP_HOC_SINH_CHUA_CO`. **Không tự tạo cơ hội từ phiếu** (Chat chốt 15/11, H7): dòng lỗi báo số dòng, các dòng khác vẫn nạp.
- Trạng thái (R-V2-31): Hoàn thành **có điểm** → danh mục mới `COMPLETED_LEGACY` "Hoàn thành (dữ liệu cũ)" (trạng thái Ngừng nên Kanban không thêm cột và người dùng không chọn được; phiếu này không hiện ở Kanban, vẫn hiện ở danh sách và hồ sơ), giữ điểm, không đặt trình độ hay xếp loại; Hoàn thành không điểm → Chờ giáo viên chấm; Huỷ cần `ly_do_huy` có trong danh mục lý do huỷ test (`HMT_NAP_LY_DO_HUY_SAI`); Nháp; trống → Nháp kèm cảnh báo. Điểm ngoài 0 đến 10 và giờ sai dạng bị chặn.
- Hình thức test `OFFLINE` và cấp độ đề `CO_BAN` chỉ là giá trị giữ chỗ vì hai cột bắt buộc, script không có hai thông tin này (chờ anh duyệt hoặc thêm mục "Không rõ", ghi ở VIEC-ANH).
- Ghi thẳng bảng: cố ý bỏ qua luật "giờ test ở tương lai" và không tính lại nhóm con L5.

## Báo cáo đối soát sau nạp (migration 153)
`app.import_reconciliation_report(mã cơ sở)` (Admin; để trống là mọi cơ sở) trả `parents`, `students`, `enrollments_active`, `classes`, `hours_left`, `opportunities_by_stage` (L1 đến L8), `opportunities_total`. Chỉ đếm hồ sơ nạp từ dữ liệu cũ (có `legacy_ref`); không có tên hay số điện thoại. Dùng để so với tab `DOI_SOAT` của script. Tổng công nợ và tiền thu thừa thêm ở PR Số dư tiền. Kiểm thử: `153_bao_cao_doi_soat_sau_nap.test.sql`.

## File mẫu bẩn
`docs/van-hanh/mau/HMT5_FILE_MAU_NAP_DU_LIEU_GIA_BAN.xlsx`: cùng cấu trúc file mẫu, thêm dòng lỗi cố ý (SĐT thiếu số 0, ngày lẫn định dạng, trùng SĐT, cơ sở viết khác, giờ không khớp, giờ âm...). Tab `KET_QUA_DU_KIEN` ghi kết quả hàm phải báo cho từng dòng. Chỉ dữ liệu giả (SĐT 0900 000 xxx). Dùng cho diễn tập T5.

## Cơ hội: cột `nguon_goc` (migration 155, Chat chốt 15/11)
Cột `nguon_goc` của script là chữ tự do ("Page T9", "BGĐ"), không phải tên loại nguồn trong danh mục. Hàm Cơ hội: nếu khớp tên (hoặc mã) loại nguồn thì dùng; "BGĐ" hoặc "Ban Giám Đốc" thành loại Ban Giám Đốc; mọi giá trị khác, kể cả trống, thành loại **Marketing kèm cảnh báo** "Loại nguồn suy mặc định" (không phải lỗi). Chữ gốc ghi vào ghi chú của cơ hội ("Nguồn gốc (chữ gốc): ..."), không thêm cột. Báo cáo Xem trước và Nạp có `summary.source_type_defaulted` (số dòng suy loại nguồn). Cột `nguon` (nguồn) vẫn phải thuộc loại; sai thì LỖI `HMT_NGUON_SAI`. Kiểm thử: `155_nap_co_hoi_nguon_goc.test.sql`. Anh Trường có thể phản đối quyết định này.

## Giới hạn thời gian và số đo trên dữ liệu giả cỡ lớn (PR-3, migration 216)
Đo 16/11/2026 trên DB local (máy đang tải nặng, nên số có thể cao hơn máy bình thường), toàn dữ liệu giả, hoàn tác sau khi đo:
| Việc (1000 dòng) | Thời gian |
|---|---|
| Xem trước Phụ huynh | 3,5 đến 10 giây |
| Nạp thật Phụ huynh | 5 đến 8 giây |
| Nạp lại cùng file (toàn TRUNG) | 1,7 đến 8 giây |
| Xem trước Học sinh | 5 giây (22 giây khi thống kê bảng phụ huynh chưa cập nhật) |
| Nạp thật Học sinh | 10 đến 20 giây |
| Báo cáo đối soát sau nạp | dưới 0,2 giây |
- **Vấn đề:** vai trò `authenticated` của Supabase có `statement_timeout = 8s`; hạn này bấm giờ cho câu lệnh gọi hàm từ bên ngoài, nên một lô 1000 dòng có thể bị cắt giữa chừng bằng lỗi chung. **Đặt `statement_timeout` riêng cho hàm (`alter function … set`) KHÔNG nới được hạn này** (Tester tái hiện; bản đầu của PR này, migration 164, đã sai và đã bỏ).
- **Xử lý (migration 216):** tham số `import_max_rows` mặc định hạ từ 1000 xuống **300 dòng mỗi lần nạp** (khoảng 6 giây ở mức chậm nhất đã đo). File lớn chia nhiều file; nạp lại không ghi đè (dòng đã nạp thành TRUNG). Chỉnh ở Cài đặt (1 đến 5000) nếu staging đo nhanh hơn. Lô 5000 dòng Học sinh chạy quá 10 phút trong một giao dịch dài (thống kê cũ): không dùng lô lớn.
- **Khuyến nghị khi nạp thật:** mỗi lần nạp tối đa 300 dòng; nạp Phụ huynh xong chờ vài phút (hoặc để hệ thống cập nhật thống kê) rồi mới nạp Học sinh. Loại có luật «một dòng lỗi chặn cả loại» (Lớp, Ghi danh, Số dư) cũng bị giới hạn 300 dòng mỗi lần: chia file theo cơ sở.
- **Chưa làm:** nạp nặng bằng Edge Function (không bị hạn 8 giây của vai trò) hoặc cắt lô tự động ở giao diện; cần Chat/anh quyết. Chưa đo trên staging: nhờ Tester chạy khối đo trên staging.
