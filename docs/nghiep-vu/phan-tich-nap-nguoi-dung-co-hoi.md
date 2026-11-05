# Phân tích T4b, T4c: nạp Người dùng (Edge Function) và Cơ hội

**Chờ anh Trường duyệt, chưa viết mã.** Luật gốc: `docs/spec/04` R-V2-29 đến R-V2-34. File mẫu: `_inbox/HMT5_FILE_MAU_NAP_DU_LIEU_GIA.xlsx` (tab `00_NGUOIDUNG`, `05_COHOI`). Khung chung đã có từ T4a (`docs/nghiep-vu/nap-du-lieu.md`): xem trước rồi nạp, `HOP_LE` / `TRUNG` / `LOI`, không in họ tên, SĐT, email, mã cũ (chỉ số dòng và chữ cái đầu), `legacy_ref`, nạp lại bỏ qua dòng trùng.

Đo tốc độ trên DB local: nạp 500 phụ huynh mất khoảng 0,4 giây, 500 học sinh khoảng 0,4 giây. Giới hạn 8 giây của lời gọi từ trình duyệt không phải vấn đề với 1000 dòng một lần.

## T4b. Người dùng (cần Edge Function)

### Vì sao Edge Function
Tạo tài khoản phải ghi vào bảng đăng nhập của Supabase (Auth), cần khoá `service_role` mà giao diện không được giữ. Hiện đã có hàm `admin-users` (tạo từng người, kiểm quyền Admin hai bước, hoàn tác khi lỗi). Em đề xuất thêm hàm **`import-users`** dùng lại đúng khuôn đó, chạy theo lô.

### Luồng
1. Giao diện gửi các dòng (JSON) kèm `commit = false` (xem trước) hoặc `true` (nạp).
2. Hàm kiểm Admin đã xác thực hai bước (như `admin-users`).
3. **Xem trước:** một hàm DB mới `app.import_users_check(hàng)` kiểm từng dòng, không tạo gì: vai trò có trong danh mục, mã cơ sở có thật, `quan_ly` là tên đăng nhập có trong cùng file hoặc đã có, email đúng dạng, trùng tên đăng nhập hoặc email thì `TRUNG`.
4. **Nạp:** với từng dòng hợp lệ: tạo người dùng Auth (đã xác nhận, không gửi thư), gọi `admin_create_account` (hàm DB đã có), gắn vai trò, gắn quản lý trực tiếp (`manager_id`, hai lượt: tạo hết rồi mới gắn quản lý để quản lý đứng sau người được quản lý cũng gắn được). Lỗi ở dòng nào thì xoá người dùng Auth vừa tạo của dòng đó (như `admin-users`).
5. Kết quả mỗi dòng: số dòng, chữ cái đầu của họ tên, trạng thái, câu lỗi. **Không có email trong kết quả và nhật ký.**

### Quy tắc theo cột
| Cột | Luật |
|---|---|
| `username` | Duy nhất, không đổi. DB chưa có cột tên đăng nhập (đăng nhập bằng email, anh đã chốt giữ). Em lưu vào `legacy_ref` của tài khoản để các loại nạp sau (Cơ hội, Phiếu test) đổi "người phụ trách = username" thành tài khoản. |
| `email` | Email đăng nhập. Trống thì dùng email quy ước theo tên đăng nhập. **Câu hỏi 1.** |
| `ho_ten`, `ma_nv` | Họ tên hiển thị; `ma_nv` vào `staff_code`. |
| `vai_tro` | Một trong ADMIN, BRANCH_MANAGER, SALES, MARKETER, MARKETING_MANAGER, TEACHER, CSKH, ACCOUNTANT (đã có đủ trong DB sau T1). Ngoài danh mục thì `LOI`. |
| `co_so_truy_cap` | **Câu hỏi 2.** |
| `quan_ly` | Tên đăng nhập quản lý trực tiếp, gắn vào `manager_id`. Trống thì Trưởng cơ sở duyệt (luật hiện có). Không có trong file lẫn hệ thống thì `LOI`. |
| `trang_thai` | Đang làm: mở. Nghỉ phép, Đã nghỉ: vẫn nạp, **khoá tài khoản** (như nút Khoá hiện có, lý do ghi "Nạp dữ liệu cũ"). |

### Mật khẩu (không mang mật khẩu cũ sang)
Mỗi tài khoản mới có **mật khẩu tạm ngẫu nhiên** (đúng chính sách độ dài, chữ và số) và `must_change_password = true`. Mật khẩu tạm chỉ **trả về một lần** cho trình duyệt của Admin trong lượt nạp, để anh tải file (tên đăng nhập, mật khẩu tạm) giao cho từng người; **không lưu ở máy chủ, không vào nhật ký, không gửi email**. Người dùng đổi mật khẩu ở lần đăng nhập đầu. **Câu hỏi 3.**

### Phạm vi
Chỉ Admin. Môi trường thử chỉ dùng người dùng giả (email `@example.com` trong file mẫu). Người dùng thật chỉ nạp ở bản chạy thật do anh làm.

## T4c. Cơ hội

### Điều cần biết về cấu trúc
- Mỗi cơ hội **bắt buộc có lead gốc** (`lead_id`), phụ huynh, cơ sở, người phụ trách, nguồn ba tầng (loại, nguồn, kênh). Vì vậy một dòng nạp cơ hội tạo **ba thứ trong một giao dịch**: phụ huynh (nếu chưa có), lead (nhóm con C4D "Tạo cơ hội thành công"), cơ hội ở giai đoạn thẳng từ file.
- Cơ hội giữ danh sách em (`prospect_student`, tối đa 5 em).

### Quy tắc theo cột (tab `05_COHOI`)
| Cột | Luật đề xuất |
|---|---|
| `ma_cu` (là SĐT) | Khoá: một SĐT, một cơ hội. Trùng mã cũ đã nạp thì `TRUNG`, bỏ qua, không ghi đè. |
| `sdt_ph`, `sdt_2`, `ho_ten_ph`, `dia_chi` | Phụ huynh khớp theo SĐT chính hoặc thứ hai (hàm có sẵn từ T2). **Câu hỏi 4.** |
| `danh_sach_em`, `khoi`, `truong` | Các em cách nhau dấu chấm phẩy, tối đa 5; tên em trống vẫn nạp (cơ hội chưa có em). |
| `nguon_goc`, `nguon`, `medium` | Loại nguồn, nguồn, kênh: khớp theo tên với danh mục nguồn ba tầng (bỏ dấu, không phân biệt hoa thường); không khớp thì `LOI`. |
| `co_so` | Mã cơ sở có thật, và không phải cơ sở văn phòng. |
| `nguoi_phu_trach` | Tên đăng nhập, tra theo `legacy_ref` của tài khoản (nạp Người dùng trước); không có hoặc khác cơ sở thì `LOI`. `nguoi_phu_trach_goc` chỉ để tra cứu, ghi vào ghi chú. |
| `giai_doan`, `nhom_con` | L1 đến L8 và nhóm con phải khớp danh mục (nhóm con thuộc đúng giai đoạn). Nạp thẳng, **bỏ qua luật chuyển giai đoạn** (chỉ hàm nạp được làm vậy); từ L7 trở lên không có phiếu thì ghi lý do bỏ qua test là "Nạp dữ liệu cũ" (R-V2 mục 14.6). **Câu hỏi 5.** |
| `ngay_tao` | Ngày tạo cũ của cơ hội. **Câu hỏi 6.** |
| `ghi_chu` | Một ghi chú gắn cơ hội (ghi chú lead gốc giữ nguyên cách hiện có). |
| `tinh_trang_cu`, `da_la_phu_huynh` | Chỉ đối soát, không nạp thành cột. |

Lead gốc tạo cùng lúc mang nguồn, người phụ trách, ngày như cơ hội. Mã cơ hội, lead, phụ huynh cấp theo chuẩn mã hiện có (không nhảy số).

### Câu hỏi 5 chi tiết (luật R-CRM-03)
Từ L5 trở lên luật bắt buộc em đầu có tên và năm sinh. Dữ liệu cũ có dòng ở L5 trở lên mà em trống tên hoặc năm sinh (file mẫu nói tên em trống vẫn nạp). Em đề xuất: **dòng nào vi phạm thì `LOI`** kèm lý do, anh sửa trong Sheet rồi nạp lại (đúng luật, không nới).

## Anh đã chốt (05/11/2026, trả lời 7 câu)
1. **Email khi cột `email` trống:** dùng email quy ước `tên đăng nhập@<miền>`, miền là tham số Cài đặt `import_user_email_domain` (môi trường thử dùng miền giả `tam.invalid`), không viết cứng. (Sau đó anh dặn: email người dùng lấy từ file nhân sự; hàng nào thiếu email thì báo anh bổ sung. Xem PR dữ liệu CS5.)
2. **`co_so_truy_cap` nhiều cơ sở:** lấy cơ sở đầu tiên làm cơ sở chính, kèm cảnh báo "chờ danh sách cơ sở" và ghi nguyên chuỗi gốc vào bảng chờ `import_user_branch_pending` để PR danh sách cơ sở theo người (sau 10/11) áp dụng.
3. **Mật khẩu tạm:** trả một lần về trình duyệt Admin để tải file giao người dùng; không lưu ở máy chủ, không vào nhật ký, không gửi email.
4. **Cơ hội có SĐT trùng phụ huynh có sẵn:** gắn vào phụ huynh đó (liên kết, không gộp), kèm cảnh báo; chưa có thì tạo mới.
5. **Dòng L5 trở lên thiếu tên hoặc năm sinh em:** `LOI`, anh sửa Sheet; không nới luật R-CRM-03 cho lượt nạp.
6. **Ngày tạo cũ:** ghi ở **cột riêng**, không ghi đè ngày tạo hệ thống (`created_at`); nhật ký thao tác vẫn ghi giờ nạp thật.
7. **Lý do bỏ qua test "Nạp dữ liệu cũ":** thêm `NAP_CU` ở danh mục 33 trạng thái **Ngừng** (chỉ hàm nạp dùng).

T4b đã làm theo 1 đến 3 (#162, migration 069). T4c làm theo 4 đến 7.

## Trình tự làm sau khi anh duyệt
T4b (hàm DB kiểm, Edge Function `import-users`, bài kiểm pgTAP và Deno) rồi T4c (hàm DB nạp cơ hội, `NAP_CU`, cờ ngày tạo, bài kiểm pgTAP). Phiếu test (T4d) sau Cơ hội. Màn Nhập (T5) dựng khi Design vẽ khuôn "chọn loại nạp" và "xuất dòng lỗi".
