# Nạp dữ liệu cũ theo loại (màn Nhập, chỉ Admin)

Luật: `docs/spec/04` mục 14, R-V2-29 đến R-V2-34 (anh Trường chốt 04/11/2026, Đ285). File mẫu dữ liệu giả `HMT5_FILE_MAU_NAP_DU_LIEU_GIA.xlsx` nằm trong `_inbox/` (không commit). Thứ tự nạp: Người dùng, Lớp, **Phụ huynh, Học sinh**, Ghi danh, Số dư, Cơ hội, Phiếu test. T4a (migration 068) làm Phụ huynh và Học sinh; các loại còn lại làm ở các bước sau.

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
