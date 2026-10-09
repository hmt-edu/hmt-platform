# Làm sạch dữ liệu cũ và đối chiếu mã

Ghi lại các chỗ đã sửa khi nạp danh mục từ `docs/seed/` (Config cũ) vào migration
`20261010000003_danh_muc_du_lieu.sql`. Chốt với anh Trường ngày 10/10/2026.
Dùng bảng đối chiếu ở cuối file khi chuyển dữ liệu thật từ Sheet sang.

## Chung
- File cũ dùng kết thúc dòng Windows (CRLF); có cột ghép thừa (`Stage` = mã + ": " + tên). Chỉ lấy mã và tên.
- Danh mục cũ không có mã thì tự đặt mã viết hoa, không dấu, nối bằng `_` (vd `Facebook Ads` → `FACEBOOK_ADS`).
- Tên cũ (nếu có) giữ ở cột `legacy_ref` của mục để tìm và đối chiếu.

## Nguồn (old_sources.csv) → 3 tầng loại / nguồn / kênh
- 6 loại: Marketing, Telemarketing, Event, Referral, Upsale, Ban Giám Đốc.
- 11 nguồn; Hotline, Walk-in, Zalo giữ dưới Marketing; "Ban Giám Đốc" là nguồn thật (khách do BGĐ giới thiệu).
- 14 kênh; tên kênh bỏ phần lặp tên nguồn (`Facebook Ads: Chat` → `Chat`, mã `FACEBOOK_ADS_CHAT`).
- Tên tiếng Anh giữ nguyên.

## Giai đoạn lead (old_lead_stages.csv)
- Giữ nguyên mã `C1`–`C4`, mục con `C2A`…`C4D` (15 mục con). `C1` không có mục con.

## Giai đoạn cơ hội (old_opportunity_stages.csv)
- `L2A` đổi tên thành "Không nghe máy" (cũ trùng tên với `L2B` "Không liên lạc được"; khớp `C2A` bên lead).
- Bỏ `L3H` cũ "Không có nhu cầu về địa điểm" (gần trùng `L3G` "Không phù hợp về địa điểm"); không tạo.
- `L3I` cũ "Không nghe máy nhiều lần" đổi mã thành `L3H` (khớp `C3H` bên lead); không còn `L3I`.
- Mã con nhảy chữ (L5: `…I, K, N, M, O`; L7 thiếu `J`) giữ nguyên để khớp dữ liệu cũ; thứ tự theo file.
- Còn 49 mục con.

## Tình trạng test và lý do huỷ test (old_student_test_status.csv)
File gộp 2 danh sách khác nhau, đã tách:
- Tình trạng test → danh mục hệ thống `TEST_STATUS`: `DRAFT` Nháp, `TESTING` Đang test, `TEACHER_REVIEW` Chờ giáo viên nhận xét,
  `COMPLETED` Hoàn thành, `CANCELLED` Đã huỷ, `REJECTED` Từ chối (tên tiếng Anh cũ ở `legacy_ref`).
- Lý do huỷ test → danh mục mở `TEST_CANCEL_REASON`, 11 lý do; mã lý do = mã giai đoạn con cơ hội tương ứng (`L5C`…`L5O`),
  mỗi lý do nối (`linked_item_id`) với giai đoạn con đó.

## Loại hoạt động (old_activity_types.csv)
Theo chốt: Gọi điện (`GOI_DIEN`, cũ Call), Zalo, Email, Gặp trực tiếp, SMS, Nhắc thu tiền (`NHAC_THU_TIEN`, cũ "Thu tiền").

## Tỉnh, phường (old_wards.csv)
- 34 tỉnh, thành: nạp tên tỉnh. Phường/xã chỉ nạp cho Hà Nội.
- Hà Nội: file cũ có 110 tên; danh sách chính thức sau sắp xếp 2025 (Nghị quyết 1656/NQ-UBTVQH15, hiệu lực 01/07/2025)
  có **126 đơn vị: 51 phường, 75 xã**. Đã đối chiếu 2 nguồn độc lập (Wikipedia tiếng Việt, LuatVietnam) khớp nhau.
  Nạp đủ 126 theo danh sách chính thức; tên lưu kèm loại, vd "Phường Ba Đình", "Xã Sóc Sơn".

**Có trong file cũ nhưng không có trong danh sách chính thức (15, không nạp):**
Chúc Sơn, Hải Bối, Vĩnh Ngọc, Thư Phú, Dương Xá, Kiên Thành, Trâu Quỳ, Yên Viên, Đông Xuân, Hoàng Vân, Tân Minh,
Minh Quang, Thạch Hòa, Hương Ngải, Vân Phúc.

**Có trong danh sách chính thức nhưng thiếu ở file cũ (31, đã nạp thêm):**
Phường Định Công, Phường Hoàng Liệt, Phường Khương Đình, Phường Phương Liệt, Phường Tây Tựu, Phường Thanh Xuân,
Phường Xuân Phương; Xã An Khánh, Xã Bát Tràng, Xã Bất Bạt, Xã Chuyên Mỹ, Xã Cổ Đô, Xã Đại Xuyên, Xã Hòa Phú, Xã Hòa Xá,
Xã Hồng Sơn, Xã Hưng Đạo, Xã Hương Sơn, Xã Kiều Phú, Xã Minh Châu, Xã Mỹ Đức, Xã Phú Cát, Xã Phú Nghĩa, Xã Phúc Sơn,
Xã Phượng Dực, Xã Sơn Đồng, Xã Tây Phương, Xã Ứng Hòa, Xã Ứng Thiên, Xã Vân Đình, Xã Vĩnh Thanh.

Khi chuyển dữ liệu thật: địa chỉ ghi tên phường cũ (trước 01/07/2025) hoặc tên trong 15 tên trên phải gán lại sang phường/xã mới.

## Vai trò, ma trận quyền (old_roles.csv, old_permission_matrix.csv)
Chưa nạp: thuộc bước 3. Lệch spec 03 đã thấy: thiếu `TA`, `STUDENT`, `PARENT`; `TEACHER` ghi "Giáo viên chấm thi".

## Bảng đối chiếu mã cũ → mới (dùng khi chuyển dữ liệu)
| Danh mục | Mã cũ | Mã mới | Ghi chú |
|---|---|---|---|
| Giai đoạn con cơ hội | `L3H` (Không có nhu cầu về địa điểm) | `L3G` | Gộp vào "Không phù hợp về địa điểm" |
| Giai đoạn con cơ hội | `L3I` (Không nghe máy nhiều lần) | `L3H` | Đổi mã |
| Giai đoạn con cơ hội | `L2A` | `L2A` | Giữ mã, đổi tên "Không nghe máy" |
| Điểm danh | `X`, `x` | `CO_MAT` | |
| Điểm danh | `P`, `p` | `VANG_CO_PHEP` | |
| Điểm danh | `KP` | `VANG_KHONG_PHEP` | |
| Điểm danh | `N` | (không phải điểm danh) | Buổi Huỷ cả lớp, không tính phí |
| Loại hoạt động | `Call` / `Thu tiền` | `GOI_DIEN` / `NHAC_THU_TIEN` | |
| Tình trạng test | `Draft`… `Rejected` | `DRAFT`… `REJECTED` | |
