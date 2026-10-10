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
- **Anh Trường đã duyệt giữ bản chính thức 126 đơn vị (10/10/2026).**
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

## Đối chiếu đơn vị cũ → mới ở Hà Nội (Nghị quyết 1656/NQ-UBTVQH15)
Nguyên văn Điều 1 Nghị quyết 1656/NQ-UBTVQH15 ngày 16/06/2025, lấy từ toàn văn đăng trên Cổng Thông tin điện tử Chính phủ
(xaydungchinhsach.chinhphu.vn); cột "Hình thành từ" giữ nguyên văn.
Hiệu lực: chính quyền cấp xã mới hoạt động từ 01/07/2025.

**Cách dùng khi chuyển dữ liệu:** địa chỉ ghi phường/xã/thị trấn cũ thì tìm tên đó ở cột "Hình thành từ".
- Đơn vị cũ nhập **toàn bộ** vào một đơn vị mới: gán thẳng sang đơn vị mới đó.
- Đơn vị cũ bị chia (**một phần** / **phần còn lại**) vào nhiều đơn vị mới: phải xem số nhà, đường, tổ dân phố; không gán tự động được,
  đưa vào danh sách cho CSKH xác nhận với phụ huynh.
- Tên cũ trùng nhau giữa các quận, huyện cũ (Nghị quyết ghi kèm "(quận/huyện …)") thì phải xét theo quận, huyện cũ của địa chỉ.

Bảng tra ngược (đơn vị cũ → đơn vị mới) sẽ dựng và kiểm thử ở bước chuyển dữ liệu, từ đúng bảng dưới đây.

| STT | Đơn vị mới | Hình thành từ (nguyên văn) |
|---|---|---|
| 1 | Phường Hoàn Kiếm | toàn bộ diện tích tự nhiên, quy mô dân số của các phường Hàng Bạc, Hàng Bồ, Hàng Buồm, Hàng Đào, Hàng Gai, Hàng Mã, Lý Thái Tổ và một phần diện tích tự nhiên, quy mô dân số của các phường Cửa Đông, Cửa Nam, Điện Biên, Đồng Xuân, Hàng Bông, Hàng Trống, Tràng Tiền |
| 2 | Phường Cửa Nam | toàn bộ diện tích tự nhiên, quy mô dân số của các phường Hàng Bài, Phan Chu Trinh, Trần Hưng Đạo, một phần diện tích tự nhiên, quy mô dân số của các phường Cửa Nam, Nguyễn Du, Phạm Đình Hổ và phần còn lại của các phường Hàng Bông, Hàng Trống, Tràng Tiền sau khi sắp xếp theo quy định tại khoản 1 Điều này |
| 3 | Phường Ba Đình | toàn bộ diện tích tự nhiên, quy mô dân số của phường Quán Thánh, phường Trúc Bạch, một phần diện tích tự nhiên, quy mô dân số của các phường Cửa Nam, Điện Biên, Đội Cấn, Kim Mã, Ngọc Hà, một phần diện tích tự nhiên của phường Thụy Khuê, phần còn lại của phường Cửa Đông và phường Đồng Xuân sau khi sắp xếp theo quy định tại khoản 1 Điều này |
| 4 | Phường Ngọc Hà | toàn bộ diện tích tự nhiên, quy mô dân số của phường Vĩnh Phúc, phường Liễu Giai, một phần diện tích tự nhiên, quy mô dân số của các phường Cống Vị, Kim Mã, Ngọc Khánh, Nghĩa Đô, phần còn lại của phường Đội Cấn và phường Ngọc Hà sau khi sắp xếp theo quy định tại khoản 3 Điều này |
| 5 | Phường Giảng Võ | toàn bộ diện tích tự nhiên, quy mô dân số của phường Giảng Võ, một phần diện tích tự nhiên, quy mô dân số của các phường Cát Linh, Láng Hạ, Ngọc Khánh, Thành Công, phần còn lại của phường Cống Vị sau khi sắp xếp theo quy định tại khoản 4 Điều này và phần còn lại của phường Kim Mã sau khi sắp xếp theo quy định tại khoản 3, khoản 4 Điều này |
| 6 | Phường Hai Bà Trưng | toàn bộ diện tích tự nhiên, quy mô dân số của phường Đồng Nhân, phường Phố Huế, một phần diện tích tự nhiên, quy mô dân số của các phường Bạch Đằng, Lê Đại Hành, Nguyễn Du, Thanh Nhàn và phần còn lại của phường Phạm Đình Hổ sau khi sắp xếp theo quy định tại khoản 2 Điều này |
| 7 | Phường Vĩnh Tuy | một phần diện tích tự nhiên, quy mô dân số của các phường Mai Động, Thanh Lương, Vĩnh Hưng và Vĩnh Tuy |
| 8 | Phường Bạch Mai | toàn bộ diện tích tự nhiên, quy mô dân số của các phường Bạch Mai, Bách Khoa, Quỳnh Mai, một phần diện tích tự nhiên, quy mô dân số của các phường Minh Khai (quận Hai Bà Trưng), Đồng Tâm, Lê Đại Hành, Phương Mai, Trương Định và phần còn lại của phường Thanh Nhàn sau khi sắp xếp theo quy định tại khoản 6 Điều này |
| 9 | Phường Đống Đa | toàn bộ diện tích tự nhiên, quy mô dân số của phường Thịnh Quang và một phần diện tích tự nhiên, quy mô dân số của các phường Quang Trung (quận Đống Đa), Láng Hạ, Nam Đồng, Ô Chợ Dừa, Trung Liệt |
| 10 | Phường Kim Liên | toàn bộ diện tích tự nhiên, quy mô dân số của phường Kim Liên, phường Khương Thượng, một phần diện tích tự nhiên, quy mô dân số của các phường Nam Đồng, Phương Liên - Trung Tự, Trung Liệt, phần còn lại của phường Phương Mai sau khi sắp xếp theo quy định tại khoản 8 Điều này và phần còn lại của phường Quang Trung (quận Đống Đa) sau khi sắp xếp theo quy định tại khoản 9 Điều này |
| 11 | Phường Văn Miếu - Quốc Tử Giám | toàn bộ diện tích tự nhiên, quy mô dân số của các phường Khâm Thiên, Thổ Quan, Văn Chương, một phần diện tích tự nhiên, quy mô dân số của các phường Điện Biên, Hàng Bột, Văn Miếu - Quốc Tử Giám, phần còn lại của phường Cửa Nam sau khi sắp xếp theo quy định tại các khoản 1, 2, 3 Điều này, phần còn lại của phường Lê Đại Hành sau khi sắp xếp theo quy định tại khoản 6, khoản 8 Điều này, phần còn lại của phường Nam Đồng sau khi sắp xếp theo quy định tại khoản 9, khoản 10 Điều này, phần còn lại của phường Nguyễn Du sau khi sắp xếp theo quy định tại khoản 2, khoản 6 Điều này và phần còn lại của phường Phương Liên - Trung Tự sau khi sắp xếp theo quy định tại khoản 10 Điều này |
| 12 | Phường Láng | toàn bộ diện tích tự nhiên, quy mô dân số của phường Láng Thượng, phần còn lại của phường Láng Hạ sau khi sắp xếp theo quy định tại khoản 5, khoản 9 Điều này và phần còn lại của phường Ngọc Khánh sau khi sắp xếp theo quy định tại khoản 4, khoản 5 Điều này |
| 13 | Phường Ô Chợ Dừa | phần còn lại của phường Cát Linh sau khi sắp xếp theo quy định tại khoản 5 Điều này, phần còn lại của phường Điện Biên sau khi sắp xếp theo quy định tại các khoản 1, 3, 11 Điều này, phần còn lại của phường Thành Công sau khi sắp xếp theo quy định tại khoản 5 Điều này, phần còn lại của phường Ô Chợ Dừa sau khi sắp xếp theo quy định tại khoản 9 Điều này, phần còn lại của phường Trung Liệt sau khi sắp xếp theo quy định tại khoản 9, khoản 10 Điều này, phần còn lại của phường Hàng Bột và phường Văn Miếu - Quốc Tử Giám sau khi sắp xếp theo quy định tại khoản 11 Điều này |
| 14 | Phường Hồng Hà | toàn bộ diện tích tự nhiên, quy mô dân số của các phường Chương Dương, Phúc Tân, Phúc Xá, một phần diện tích tự nhiên, quy mô dân số của các phường Nhật Tân, Phú Thượng, Quảng An, Thanh Lương, Tứ Liên, Yên Phụ, một phần diện tích tự nhiên của phường Bồ Đề và phường Ngọc Thụy, phần còn lại của phường Bạch Đằng sau khi sắp xếp theo quy định tại khoản 6 Điều này |
| 15 | Phường Lĩnh Nam | một phần diện tích tự nhiên, quy mô dân số của các phường Lĩnh Nam, Thanh Trì, Trần Phú, một phần diện tích tự nhiên của phường Yên Sở và phần còn lại của phường Thanh Lương sau khi sắp xếp theo quy định tại khoản 7, khoản 14 Điều này |
| 16 | Phường Hoàng Mai | một phần diện tích tự nhiên, quy mô dân số của các phường Giáp Bát, Hoàng Liệt, Hoàng Văn Thụ, Lĩnh Nam, Tân Mai, Thịnh Liệt, Tương Mai, Trần Phú, Vĩnh Hưng và Yên Sở |
| 17 | Phường Vĩnh Hưng | một phần diện tích tự nhiên, quy mô dân số của phường Vĩnh Hưng, phần còn lại của phường Lĩnh Nam sau khi sắp xếp theo quy định tại khoản 15, khoản 16 Điều này, phần còn lại của phường Thanh Trì sau khi sắp xếp theo quy định tại khoản 15 Điều này và phần còn lại của phường Vĩnh Tuy sau khi sắp xếp theo quy định tại khoản 7 Điều này |
| 18 | Phường Tương Mai | một phần diện tích tự nhiên, quy mô dân số của phường Giáp Bát, phường Phương Liệt, phần còn lại của phường Mai Động sau khi sắp xếp theo quy định tại khoản 7 Điều này, phần còn lại của các phường Minh Khai (quận Hai Bà Trưng), Đồng Tâm, Trương Định sau khi sắp xếp theo quy định tại khoản 8 Điều này, phần còn lại của các phường Hoàng Văn Thụ, Tân Mai, Tương Mai sau khi sắp xếp theo quy định tại khoản 16 Điều này và phần còn lại của phường Vĩnh Hưng sau khi sắp xếp theo quy định tại các khoản 7, 16, 17 Điều này |
| 19 | Phường Định Công | một phần diện tích tự nhiên, quy mô dân số của các phường Định Công, Hoàng Liệt, Thịnh Liệt, xã Tân Triều, xã Thanh Liệt, một phần diện tích tự nhiên, toàn bộ quy mô dân số của phường Đại Kim và phần còn lại của phường Giáp Bát sau khi sắp xếp theo quy định tại khoản 16, khoản 18 Điều này |
| 20 | Phường Hoàng Liệt | một phần diện tích tự nhiên, quy mô dân số của phường Hoàng Liệt, thị trấn Văn Điển, xã Tam Hiệp (huyện Thanh Trì), xã Thanh Liệt và một phần diện tích tự nhiên của phường Đại Kim |
| 21 | Phường Yên Sở | một phần diện tích tự nhiên, quy mô dân số của phường Thịnh Liệt, phường Yên Sở, xã Tứ Hiệp, phần còn lại của phường Hoàng Liệt sau khi sắp xếp theo quy định tại các khoản 16, 19, 20 Điều này và phần còn lại của phường Trần Phú sau khi sắp xếp theo quy định tại khoản 15, khoản 16 Điều này |
| 22 | Phường Thanh Xuân | một phần diện tích tự nhiên, quy mô dân số của các phường Nhân Chính, Thanh Xuân Bắc, Thanh Xuân Trung, Thượng Đình, Trung Hoà và Trung Văn |
| 23 | Phường Khương Đình | một phần diện tích tự nhiên, quy mô dân số của các phường Hạ Đình, Khương Đình, Khương Trung, một phần diện tích tự nhiên của phường Đại Kim và xã Tân Triều, phần còn lại của phường Thanh Xuân Trung và phường Thượng Đình sau khi sắp xếp theo quy định tại khoản 22 Điều này |
| 24 | Phường Phương Liệt | toàn bộ diện tích tự nhiên, quy mô dân số của phường Khương Mai, phần còn lại của phường Thịnh Liệt sau khi sắp xếp theo quy định tại các khoản 16, 19, 21 Điều này, phần còn lại của phường Phương Liệt sau khi sắp xếp theo quy định tại khoản 18 Điều này, phần còn lại của phường Định Công sau khi sắp xếp theo quy định tại khoản 19 Điều này, phần còn lại của phường Khương Đình và phường Khương Trung sau khi sắp xếp theo quy định tại khoản 23 Điều này |
| 25 | Phường Cầu Giấy | một phần diện tích tự nhiên, quy mô dân số của các phường Dịch Vọng, Dịch Vọng Hậu, Quan Hoa, Mỹ Đình 1, Mỹ Đình 2 và Yên Hòa |
| 26 | Phường Nghĩa Đô | toàn bộ diện tích tự nhiên, quy mô dân số của phường Nghĩa Tân, một phần diện tích tự nhiên, quy mô dân số của các phường Cổ Nhuế 1, Mai Dịch, Nghĩa Đô, Xuân La, Xuân Tảo và phần còn lại của các phường Dịch Vọng, Dịch Vọng Hậu, Quan Hoa sau khi sắp xếp theo quy định tại khoản 25 Điều này |
| 27 | Phường Yên Hòa | một phần diện tích tự nhiên, quy mô dân số của các phường Mễ Trì, Nhân Chính, Trung Hòa và phần còn lại của phường Yên Hòa sau khi sắp xếp theo quy định tại khoản 25 Điều này |
| 28 | Phường Tây Hồ | toàn bộ diện tích tự nhiên, quy mô dân số của phường Bưởi, một phần diện tích tự nhiên, quy mô dân số của phường Phú Thượng và phường Xuân La, phần còn lại của các phường Nhật Tân, Quảng An, Tứ Liên, Yên Phụ sau khi sắp xếp theo quy định tại khoản 14 Điều này, phần còn lại của phường Nghĩa Đô sau khi sắp xếp theo quy định tại khoản 4, khoản 26 Điều này và phần còn lại của phường Thụy Khuê sau khi sắp xếp theo quy định tại khoản 3 Điều này |
| 29 | Phường Phú Thượng | một phần diện tích tự nhiên, quy mô dân số của các phường Đông Ngạc, Xuân La, Xuân Đỉnh, Xuân Tảo và phần còn lại của phường Phú Thượng sau khi sắp xếp theo quy định tại khoản 14, khoản 28 Điều này |
| 30 | Phường Tây Tựu | một phần diện tích tự nhiên, quy mô dân số của phường Minh Khai (quận Bắc Từ Liêm), một phần diện tích tự nhiên, toàn bộ quy mô dân số của phường Tây Tựu và một phần diện tích tự nhiên của xã Kim Chung (huyện Hoài Đức) |
| 31 | Phường Phú Diễn | toàn bộ diện tích tự nhiên, quy mô dân số của phường Phú Diễn và một phần diện tích tự nhiên, quy mô dân số của các phường Cổ Nhuế 1, Mai Dịch, Phúc Diễn |
| 32 | Phường Xuân Đỉnh | một phần diện tích tự nhiên, quy mô dân số của phường Xuân Đỉnh, phần còn lại của phường Cổ Nhuế 1 sau khi sắp xếp theo quy định tại khoản 26, khoản 31 Điều này, phần còn lại của phường Xuân La sau khi sắp xếp theo quy định tại các khoản 26, 28, 29 Điều này và phần còn lại của phường Xuân Tảo sau khi sắp xếp theo quy định tại khoản 26, khoản 29 Điều này |
| 33 | Phường Đông Ngạc | toàn bộ diện tích tự nhiên, quy mô dân số của phường Đức Thắng, một phần diện tích tự nhiên, quy mô dân số của phường Cổ Nhuế 2 và phường Thụy Phương, một phần diện tích tự nhiên của phường Minh Khai (quận Bắc Từ Liêm), phần còn lại của phường Đông Ngạc sau khi sắp xếp theo quy định tại khoản 29 Điều này và phần còn lại của phường Xuân Đỉnh sau khi sắp xếp theo quy định tại khoản 29, khoản 32 Điều này |
| 34 | Phường Thượng Cát | toàn bộ diện tích tự nhiên, quy mô dân số của phường Liên Mạc, phường Thượng Cát, một phần diện tích tự nhiên của phường Minh Khai (quận Bắc Từ Liêm) và phường Tây Tựu, phần còn lại của phường Cổ Nhuế 2 và phường Thụy Phương sau khi sắp xếp theo quy định tại khoản 33 Điều này |
| 35 | Phường Từ Liêm | toàn bộ diện tích tự nhiên, quy mô dân số của phường Cầu Diễn, một phần diện tích tự nhiên, quy mô dân số của phường Mễ Trì và phường Phú Đô, phần còn lại của phường Mai Dịch sau khi sắp xếp theo quy định tại khoản 26, khoản 31 Điều này, phần còn lại của phường Mỹ Đình 1 và phường Mỹ Đình 2 sau khi sắp xếp theo quy định tại khoản 25 Điều này |
| 36 | Phường Xuân Phương | toàn bộ diện tích tự nhiên, quy mô dân số của phường Phương Canh, phường Xuân Phương, một phần diện tích tự nhiên, quy mô dân số của phường Đại Mỗ và phường Tây Mỗ, một phần diện tích tự nhiên của xã Vân Canh, phần còn lại của phường Minh Khai (quận Bắc Từ Liêm) sau khi sắp xếp theo quy định tại các khoản 30, 33, 34 và phần còn lại của phường Phúc Diễn sau khi sắp xếp theo quy định tại khoản 31 Điều này |
| 37 | Phường Tây Mỗ | một phần diện tích tự nhiên, quy mô dân số của phường Đại Mỗ, phường Dương Nội và xã An Khánh, phần còn lại của phường Tây Mỗ sau khi sắp xếp theo quy định tại khoản 36 Điều này |
| 38 | Phường Đại Mỗ | một phần diện tích tự nhiên, quy mô dân số của các phường Dương Nội, Đại Mỗ, Mộ Lao, phần còn lại của phường Mễ Trì sau khi sắp xếp theo quy định tại khoản 27, khoản 35 Điều này, phần còn lại của phường Nhân Chính và phường Trung Hòa sau khi sắp xếp theo quy định tại khoản 22, khoản 27 Điều này, phần còn lại của phường Phú Đô sau khi sắp xếp theo quy định tại khoản 35 Điều này và phần còn lại của phường Trung Văn sau khi sắp xếp theo quy định tại khoản 22 Điều này |
| 39 | Phường Long Biên | một phần diện tích tự nhiên, quy mô dân số của các phường Cự Khối, Phúc Đồng, Thạch Bàn, xã Bát Tràng, một phần diện tích tự nhiên, toàn bộ quy mô dân số của phường Long Biên, một phần diện tích tự nhiên của phường Bồ Đề và phường Gia Thụy |
| 40 | Phường Bồ Đề | toàn bộ diện tích tự nhiên, quy mô dân số của phường Ngọc Lâm, một phần diện tích tự nhiên, quy mô dân số của các phường Đức Giang, Gia Thụy, Thượng Thanh, một phần diện tích tự nhiên của phường Phúc Đồng, phần còn lại của phường Ngọc Thụy sau khi sắp xếp theo quy định tại khoản 14 Điều này, phần còn lại của phường Bồ Đề sau khi sắp xếp theo quy định tại khoản 14, khoản 39 Điều này và phần còn lại của phường Long Biên sau khi sắp xếp theo quy định tại khoản 39 Điều này |
| 41 | Phường Việt Hưng | một phần diện tích tự nhiên, quy mô dân số của các phường Giang Biên, Phúc Đồng, Việt Hưng, một phần diện tích tự nhiên của phường Phúc Lợi, phần còn lại của phường Gia Thụy sau khi sắp xếp theo quy định tại khoản 39, khoản 40 Điều này, phần còn lại của phường Đức Giang và phường Thượng Thanh sau khi sắp xếp theo quy định tại khoản 40 Điều này |
| 42 | Phường Phúc Lợi | một phần diện tích tự nhiên, quy mô dân số của phường Thạch Bàn, xã Cổ Bi, phần còn lại của các phường Giang Biên, Việt Hưng, Phúc Lợi sau khi sắp xếp theo quy định tại khoản 41 Điều này và phần còn lại của phường Phúc Đồng sau khi sắp xếp theo quy định tại các khoản 39, 40, 41 Điều này |
| 43 | Phường Hà Đông | toàn bộ diện tích tự nhiên, quy mô dân số của phường Phúc La, phường Vạn Phúc, một phần diện tích tự nhiên, quy mô dân số của các phường Quang Trung (quận Hà Đông), Đại Mỗ, Hà Cầu, La Khê, Văn Quán và xã Tân Triều, phần còn lại của phường Mộ Lao sau khi sắp xếp theo quy định tại khoản 38 Điều này |
| 44 | Phường Dương Nội | một phần diện tích tự nhiên, quy mô dân số của các phường Dương Nội, Phú La, Yên Nghĩa và xã La Phù, phần còn lại của phường Đại Mỗ sau khi sắp xếp theo quy định tại các khoản 36, 37, 38, 43 Điều này và phần còn lại của phường La Khê sau khi sắp xếp theo quy định tại khoản 43 Điều này |
| 45 | Phường Yên Nghĩa | một phần diện tích tự nhiên, quy mô dân số của phường Đồng Mai và phần còn lại của phường Yên Nghĩa sau khi sắp xếp theo quy định tại khoản 44 Điều này |
| 46 | Phường Phú Lương | toàn bộ diện tích tự nhiên, quy mô dân số của phường Phú Lãm, một phần diện tích tự nhiên, quy mô dân số của phường Kiến Hưng, phường Phú Lương, xã Cự Khê và xã Hữu Hòa |
| 47 | Phường Kiến Hưng | một phần diện tích tự nhiên, quy mô dân số của phường Kiến Hưng, phường Phú Lương, phần còn lại của phường Quang Trung (quận Hà Đông) và phường Hà Cầu sau khi sắp xếp theo quy định tại khoản 43 Điều này, phần còn lại của phường Phú La sau khi sắp xếp theo quy định tại khoản 44 Điều này |
| 48 | Phường Thanh Liệt | một phần diện tích tự nhiên, quy mô dân số của xã Tả Thanh Oai, phần còn lại của phường Đại Kim sau khi sắp xếp theo quy định tại các khoản 19, 20, 23 Điều này, phần còn lại của phường Thanh Xuân Bắc sau khi sắp xếp theo quy định tại khoản 22 Điều này, phần còn lại của phường Hạ Đình sau khi sắp xếp theo quy định tại khoản 23 Điều này, phần còn lại của phường Văn Quán sau khi sắp xếp theo quy định tại khoản 43 Điều này, phần còn lại của xã Thanh Liệt sau khi sắp xếp theo quy định tại khoản 19, khoản 20 Điều này và phần còn lại của xã Tân Triều sau khi sắp xếp theo quy định tại các khoản 19, 23, 43 Điều này |
| 49 | Phường Chương Mỹ | toàn bộ diện tích tự nhiên, quy mô dân số của phường Biên Giang, thị trấn Chúc Sơn, các xã Đại Yên, Ngọc Hòa, Phụng Châu, Tiên Phương, Thuỵ Hương và phần còn lại của phường Đồng Mai sau khi sắp xếp theo quy định tại khoản 45 Điều này |
| 50 | Phường Sơn Tây | toàn bộ diện tích tự nhiên, quy mô dân số của các phường Ngô Quyền, Phú Thịnh, Viên Sơn, xã Đường Lâm, một phần diện tích tự nhiên, quy mô dân số của phường Trung Hưng, phường Sơn Lộc và xã Thanh Mỹ |
| 51 | Phường Tùng Thiện | toàn bộ diện tích tự nhiên, quy mô dân số của phường Xuân Khanh, phường Trung Sơn Trầm, xã Xuân Sơn, phần còn lại của phường Trung Hưng, phường Sơn Lộc và xã Thanh Mỹ sau khi sắp xếp theo quy định tại khoản 50 Điều này |
| 52 | Xã Thanh Trì | một phần diện tích tự nhiên, quy mô dân số của thị trấn Văn Điển, xã Ngũ Hiệp và xã Vĩnh Quỳnh, một phần diện tích tự nhiên, toàn bộ quy mô dân số của xã Yên Mỹ, một phần diện tích tự nhiên của xã Duyên Hà, phần còn lại của xã Tứ Hiệp sau khi sắp xếp theo quy định tại khoản 21 Điều này và phần còn lại của phường Yên Sở sau khi sắp xếp theo quy định tại các khoản 15, 16, 21 Điều này |
| 53 | Xã Đại Thanh | phần còn lại của xã Tam Hiệp (huyện Thanh Trì) sau khi sắp xếp theo quy định tại khoản 20 Điều này, phần còn lại của xã Hữu Hòa sau khi sắp xếp theo quy định tại khoản 46 Điều này, phần còn lại của phường Kiến Hưng sau khi sắp xếp theo quy định tại khoản 46, khoản 47 Điều này, phần còn lại của thị trấn Văn Điển sau khi sắp xếp theo quy định tại khoản 20, khoản 52 Điều này, phần còn lại của xã Tả Thanh Oai sau khi sắp xếp theo quy định tại khoản 48 Điều này và phần còn lại của xã Vĩnh Quỳnh sau khi sắp xếp theo quy định tại khoản 52 Điều này |
| 54 | Xã Nam Phù | toàn bộ diện tích tự nhiên, quy mô dân số của xã Vạn Phúc, một phần diện tích tự nhiên, quy mô dân số của xã Liên Ninh và xã Ninh Sở, một phần diện tích tự nhiên, toàn bộ quy mô dân số của xã Đông Mỹ, một phần diện tích tự nhiên của xã Duyên Thái và phần còn lại của các xã Ngũ Hiệp, Yên Mỹ, Duyên Hà sau khi sắp xếp theo quy định tại khoản 52 Điều này |
| 55 | Xã Ngọc Hồi | toàn bộ diện tích tự nhiên, quy mô dân số của xã Ngọc Hồi, một phần diện tích tự nhiên, quy mô dân số của các xã Duyên Thái, Đại Áng, Khánh Hà và phần còn lại của xã Liên Ninh sau khi sắp xếp theo quy định tại khoản 54 Điều này |
| 56 | Xã Thượng Phúc | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Tân Minh (huyện Thường Tín), Dũng Tiến, Quất Động, Nghiêm Xuyên và Nguyễn Trãi |
| 57 | Xã Thường Tín | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Thường Tín, các xã Tiền Phong (huyện Thường Tín), Hiền Giang, Hòa Bình, Nhị Khê, Văn Bình, Văn Phú, phần còn lại của xã Đại Áng và xã Khánh Hà sau khi sắp xếp theo quy định tại khoản 55 Điều này |
| 58 | Xã Chương Dương | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Chương Dương, Lê Lợi, Thắng Lợi, Tự Nhiên, một phần diện tích tự nhiên, quy mô dân số của xã Tô Hiệu và xã Vạn Nhất |
| 59 | Xã Hồng Vân | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Hà Hồi, Hồng Vân, Liên Phương, Vân Tảo, phần còn lại của xã Duyên Thái sau khi sắp xếp theo quy định tại khoản 54, khoản 55 Điều này, phần còn lại của xã Ninh Sở và xã Đông Mỹ sau khi sắp xếp theo quy định tại khoản 54 Điều này |
| 60 | Xã Phú Xuyên | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Phú Minh, thị trấn Phú Xuyên, các xã Hồng Thái, Minh Cường, Nam Phong, Nam Tiến, Quang Hà, Văn Tự, phần còn lại của xã Tô Hiệu và xã Vạn Nhất sau khi sắp xếp theo quy định tại khoản 58 Điều này |
| 61 | Xã Phượng Dực | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Hoàng Long, Hồng Minh, Phú Túc, Văn Hoàng và Phượng Dực |
| 62 | Xã Chuyên Mỹ | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Tân Dân (huyện Phú Xuyên), Châu Can, Phú Yên, Vân Từ và Chuyên Mỹ |
| 63 | Xã Đại Xuyên | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Bạch Hạ, Khai Thái, Minh Tân, Phúc Tiến, Quang Lãng, Tri Thủy và Đại Xuyên |
| 64 | Xã Thanh Oai | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Kim Bài, các xã Đỗ Động, Kim An, Phương Trung, Thanh Mai và một phần diện tích tự nhiên, quy mô dân số của xã Kim Thư |
| 65 | Xã Bình Minh | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Bích Hòa, Bình Minh, Cao Viên, Thanh Cao, một phần diện tích tự nhiên, quy mô dân số của xã Lam Điền, phần còn lại của xã Cự Khê sau khi sắp xếp theo quy định tại khoản 46 Điều này và phần còn lại của phường Phú Lương sau khi sắp xếp theo quy định tại khoản 46, khoản 47 Điều này |
| 66 | Xã Tam Hưng | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Mỹ Hưng, Thanh Thùy, Thanh Văn và Tam Hưng |
| 67 | Xã Dân Hòa | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Cao Xuân Dương, Hồng Dương, Liên Châu, Tân Ước và Dân Hòa |
| 68 | Xã Vân Đình | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Vân Đình và các xã Cao Sơn Tiến, Phương Tú, Tảo Dương Văn |
| 69 | Xã Ứng Thiên | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Hoa Viên, Liên Bạt, Quảng Phú Cầu và Trường Thịnh |
| 70 | Xã Hòa Xá | toàn bộ diện tích tự nhiên, quy mô dân số của xã Hòa Phú và xã Thái Hòa (huyện Ứng Hòa), xã Bình Lưu Quang, xã Phù Lưu |
| 71 | Xã Ứng Hòa | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Đại Cường, Đại Hùng, Đông Lỗ, Đồng Tân, Kim Đường, Minh Đức, Trầm Lộng và Trung Tú |
| 72 | Xã Mỹ Đức | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Đại Nghĩa và các xã An Phú, Đại Hưng, Hợp Thanh, Phù Lưu Tế |
| 73 | Xã Hồng Sơn | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Phùng Xá (huyện Mỹ Đức), An Mỹ, Hợp Tiến, Lê Thanh, Xuy Xá, Hồng Sơn |
| 74 | Xã Phúc Sơn | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Mỹ Xuyên, Phúc Lâm, Thượng Lâm, Tuy Lai và một phần diện tích tự nhiên, toàn bộ quy mô dân số của xã Đồng Tâm |
| 75 | Xã Hương Sơn | toàn bộ diện tích tự nhiên, quy mô dân số của các xã An Tiến, Hùng Tiến, Vạn Tín và Hương Sơn |
| 76 | Xã Phú Nghĩa | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Đông Phương Yên, Đông Sơn, Thanh Bình, Trung Hòa, Trường Yên và Phú Nghĩa |
| 77 | Xã Xuân Mai | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Xuân Mai, xã Nam Phương Tiến, xã Thủy Xuân Tiên và một phần diện tích tự nhiên, quy mô dân số của xã Tân Tiến |
| 78 | Xã Trần Phú | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Hoàng Văn Thụ, Hữu Văn, Mỹ Lương, Trần Phú, phần còn lại của xã Đồng Tâm sau khi sắp xếp theo quy định tại khoản 74 Điều này và phần còn lại của xã Tân Tiến sau khi sắp xếp theo quy định tại khoản 77 Điều này |
| 79 | Xã Hòa Phú | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Hòa Phú (huyện Chương Mỹ), Đồng Lạc, Hồng Phú, Thượng Vực, Văn Võ và phần còn lại của xã Kim Thư sau khi sắp xếp theo quy định tại khoản 64 Điều này |
| 80 | Xã Quảng Bị | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Hoàng Diệu, Hợp Đồng, Quảng Bị, Tốt Động và phần còn lại của xã Lam Điền sau khi sắp xếp theo quy định tại khoản 65 Điều này |
| 81 | Xã Minh Châu | toàn bộ diện tích tự nhiên, quy mô dân số của xã Minh Châu, một phần diện tích tự nhiên của thị trấn Tây Đằng và xã Chu Minh |
| 82 | Xã Quảng Oai | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Cam Thượng, Đông Quang, Tiên Phong, một phần diện tích tự nhiên, toàn bộ quy mô dân số của xã Thụy An, phần còn lại của thị trấn Tây Đằng và xã Chu Minh sau khi sắp xếp theo quy định tại khoản 81 Điều này |
| 83 | Xã Vật Lại | toàn bộ diện tích tự nhiên, quy mô dân số của xã Thái Hòa và xã Phú Sơn (huyện Ba Vì), các xã Đồng Thái, Phú Châu, Vật Lại |
| 84 | Xã Cổ Đô | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Phú Cường (huyện Ba Vì), Cổ Đô, Phong Vân, Phú Hồng, Phú Đông và Vạn Thắng |
| 85 | Xã Bất Bạt | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Thuần Mỹ, Tòng Bạt, Sơn Đà, một phần diện tích tự nhiên, quy mô dân số của xã Cẩm Lĩnh và xã Minh Quang |
| 86 | Xã Suối Hai | toàn bộ diện tích tự nhiên, quy mô dân số của xã Ba Trại, xã Tản Lĩnh, phần còn lại của xã Thụy An sau khi sắp xếp theo quy định tại khoản 82 và phần còn lại của xã Cẩm Lĩnh sau khi sắp xếp theo quy định tại khoản 85 Điều này |
| 87 | Xã Ba Vì | toàn bộ diện tích tự nhiên, quy mô dân số của xã Ba Vì, xã Khánh Thượng và phần còn lại của xã Minh Quang sau khi sắp xếp theo quy định tại khoản 85 Điều này |
| 88 | Xã Yên Bài | toàn bộ diện tích tự nhiên, quy mô dân số của xã Vân Hòa, xã Yên Bài và một phần diện tích tự nhiên, quy mô dân số của xã Thạch Hòa |
| 89 | Xã Đoài Phương | toàn bộ diện tích tự nhiên, quy mô dân số của xã Kim Sơn, xã Sơn Đông và một phần diện tích tự nhiên, quy mô dân số của xã Cổ Đông |
| 90 | Xã Phúc Thọ | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Phúc Thọ và các xã Long Thượng, Phúc Hòa, Phụng Thượng, Tích Lộc, Trạch Mỹ Lộc |
| 91 | Xã Phúc Lộc | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Nam Hà, Sen Phương, Vân Phúc, Võng Xuyên và Xuân Đình |
| 92 | Xã Hát Môn | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Tam Hiệp (huyện Phúc Thọ), Hiệp Thuận, Liên Hiệp, Ngọc Tảo, Tam Thuấn, Thanh Đa và Hát Môn |
| 93 | Xã Thạch Thất | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Liên Quan và các xã Cẩm Yên, Đại Đồng, Kim Quan, Lại Thượng, Phú Kim |
| 94 | Xã Hạ Bằng | toàn bộ diện tích tự nhiên, quy mô dân số của xã Cần Kiệm, xã Đồng Trúc, một phần diện tích tự nhiên, quy mô dân số của các xã Bình Yên, Hạ Bằng, Tân Xã và một phần diện tích tự nhiên của xã Phú Cát |
| 95 | Xã Tây Phương | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Phùng Xá (huyện Thạch Thất), Hương Ngải, Lam Sơn, Thạch Xá, một phần diện tích tự nhiên, quy mô dân số của xã Quang Trung, một phần diện tích tự nhiên của thị trấn Quốc Oai, xã Ngọc Liệp và xã Phượng Sơn |
| 96 | Xã Hòa Lạc | một phần diện tích tự nhiên, quy mô dân số của xã Tiến Xuân, xã Thạch Hòa, phần còn lại của xã Cổ Đông sau khi sắp xếp theo quy định tại khoản 89 Điều này và phần còn lại của các xã Bình Yên, Hạ Bằng, Tân Xã sau khi sắp xếp theo quy định tại khoản 94 Điều này |
| 97 | Xã Yên Xuân | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Đông Xuân (huyện Quốc Oai), Yên Bình, Yên Trung, phần còn lại của xã Tiến Xuân sau khi sắp xếp theo quy định tại khoản 96 Điều này và phần còn lại của xã Thạch Hòa sau khi sắp xếp theo quy định tại khoản 88, khoản 96 Điều này |
| 98 | Xã Quốc Oai | toàn bộ diện tích tự nhiên, quy mô dân số của xã Thạch Thán, xã Sài Sơn, một phần diện tích tự nhiên của xã Ngọc Mỹ, phần còn lại của thị trấn Quốc Oai và xã Phượng Sơn sau khi sắp xếp theo quy định tại khoản 95 Điều này |
| 99 | Xã Hưng Đạo | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Cộng Hoà, Đồng Quang và Hưng Đạo |
| 100 | Xã Kiều Phú | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Cấn Hữu, Liệp Nghĩa, Tuyết Nghĩa, phần còn lại của xã Ngọc Liệp và xã Quang Trung sau khi sắp xếp theo quy định tại khoản 95 Điều này, phần còn lại của xã Ngọc Mỹ sau khi sắp xếp theo quy định tại khoản 98 Điều này |
| 101 | Xã Phú Cát | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Đông Yên, Hoà Thạch, Phú Mãn và phần còn lại của xã Phú Cát sau khi sắp xếp theo quy định tại khoản 94 Điều này |
| 102 | Xã Hoài Đức | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Trạm Trôi, các xã Di Trạch, Đức Giang, Đức Thượng, một phần diện tích tự nhiên của phường Tây Tựu và xã Tân Lập, phần còn lại của xã Kim Chung (huyện Hoài Đức) sau khi sắp xếp theo quy định tại khoản 30 Điều này |
| 103 | Xã Dương Hòa | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Cát Quế, Dương Liễu, Đắc Sở, Minh Khai và Yên Sở |
| 104 | Xã Sơn Đồng | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Lại Yên, Sơn Đồng, Tiền Yên, một phần diện tích tự nhiên, quy mô dân số của các xã An Khánh, Song Phương, Vân Côn, một phần diện tích tự nhiên của xã An Thượng và phần còn lại của xã Vân Canh sau khi sắp xếp theo quy định tại khoản 36 Điều này |
| 105 | Xã An Khánh | toàn bộ diện tích tự nhiên, quy mô dân số của xã Đông La, phần còn lại của phường Dương Nội sau khi sắp xếp theo quy định tại các khoản 37, 38, 44 Điều này, phần còn lại của xã An Khánh sau khi sắp xếp theo quy định tại khoản 37, khoản 104 Điều này, phần còn lại của xã La Phù sau khi sắp xếp theo quy định tại khoản 44 Điều này và phần còn lại của các xã Song Phương, Vân Côn, An Thượng sau khi sắp xếp theo quy định tại khoản 104 Điều này |
| 106 | Xã Đan Phượng | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Phùng và các xã Đồng Tháp, Song Phượng, Thượng Mỗ, Đan Phượng |
| 107 | Xã Ô Diên | toàn bộ diện tích tự nhiên, quy mô dân số của xã Hạ Mỗ, xã Tân Hội, một phần diện tích tự nhiên, toàn bộ quy mô dân số của các xã Liên Hà (huyện Đan Phượng), Hồng Hà, Liên Hồng, Liên Trung, một phần diện tích tự nhiên của xã Văn Khê, phần còn lại của phường Tây Tựu sau khi sắp xếp theo quy định tại các khoản 30, 34, 102 Điều này và phần còn lại của xã Tân Lập sau khi sắp xếp theo quy định tại khoản 102 Điều này |
| 108 | Xã Liên Minh | toàn bộ diện tích tự nhiên, quy mô dân số của xã Phương Đình, một phần diện tích tự nhiên, toàn bộ quy mô dân số của các xã Trung Châu, Thọ Xuân và Thọ An, một phần diện tích tự nhiên của xã Hồng Hà và xã Tiến Thịnh |
| 109 | Xã Gia Lâm | toàn bộ diện tích tự nhiên, quy mô dân số của xã Dương Xá, xã Kiêu Kỵ, một phần diện tích tự nhiên, toàn bộ quy mô dân số của thị trấn Trâu Quỳ, một phần diện tích tự nhiên, quy mô dân số của phường Thạch Bàn và các xã Phú Sơn (huyện Gia Lâm), Cổ Bi, Đa Tốn, một phần diện tích tự nhiên của xã Bát Tràng |
| 110 | Xã Thuận An | toàn bộ diện tích tự nhiên, quy mô dân số của xã Dương Quang, xã Lệ Chi, một phần diện tích tự nhiên, toàn bộ quy mô dân số của xã Đặng Xá và phần còn lại của xã Phú Sơn (huyện Gia Lâm) sau khi sắp xếp theo quy định tại khoản 109 Điều này |
| 111 | Xã Bát Tràng | toàn bộ diện tích tự nhiên, quy mô dân số của xã Kim Đức, phần còn lại của phường Cự Khối sau khi sắp xếp theo quy định tại khoản 39 Điều này, phần còn lại của phường Thạch Bàn sau khi sắp xếp theo quy định tại các khoản 39, 42, 109 Điều này, phần còn lại của thị trấn Trâu Quỳ và xã Đa Tốn sau khi sắp xếp theo quy định tại khoản 109 Điều này, phần còn lại của xã Bát Tràng sau khi sắp xếp theo quy định tại khoản 39, khoản 109 Điều này |
| 112 | Xã Phù Đổng | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Yên Viên, các xã Ninh Hiệp, Phù Đổng, Thiên Đức, Yên Thường, Yên Viên, phần còn lại của xã Cổ Bi sau khi sắp xếp theo quy định tại khoản 42, khoản 109 Điều này và phần còn lại của xã Đặng Xá sau khi sắp xếp theo quy định tại khoản 110 Điều này |
| 113 | Xã Thư Lâm | toàn bộ diện tích tự nhiên, quy mô dân số của xã Thụy Lâm, xã Vân Hà, một phần diện tích tự nhiên, toàn bộ quy mô dân số của xã Xuân Nộn, một phần diện tích tự nhiên, quy mô dân số của thị trấn Đông Anh và các xã Liên Hà (huyện Đông Anh), Dục Tú, Nguyên Khê, Uy Nỗ, Việt Hùng |
| 114 | Xã Đông Anh | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Cổ Loa, Đông Hội, Mai Lâm, một phần diện tích tự nhiên, quy mô dân số của thị trấn Đông Anh và các xã Tàm Xá, Tiên Dương, Vĩnh Ngọc, Xuân Canh, phần còn lại của các xã Liên Hà (huyện Đông Anh), Dục Tú, Uy Nỗ, Việt Hùng sau khi sắp xếp theo quy định tại khoản 113 Điều này |
| 115 | Xã Phúc Thịnh | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Bắc Hồng, Nam Hồng, Vân Nội, một phần diện tích tự nhiên của xã Vĩnh Ngọc, phần còn lại của xã Nguyên Khê và xã Xuân Nộn sau khi sắp xếp theo quy định tại khoản 113 Điều này, phần còn lại của xã Tiên Dương sau khi sắp xếp theo quy định tại khoản 114 Điều này và phần còn lại của thị trấn Đông Anh sau khi sắp xếp theo quy định tại khoản 113, khoản 114 Điều này |
| 116 | Xã Thiên Lộc | toàn bộ diện tích tự nhiên, quy mô dân số của xã Võng La, một phần diện tích tự nhiên, toàn bộ quy mô dân số của các xã Kim Chung (huyện Đông Anh), Đại Mạch, Kim Nỗ, một phần diện tích tự nhiên của xã Tiền Phong (huyện Mê Linh) và xã Hải Bối |
| 117 | Xã Vĩnh Thanh | phần còn lại của xã Tàm Xá và xã Xuân Canh sau khi sắp xếp theo quy định tại khoản 114 Điều này, phần còn lại của xã Vĩnh Ngọc sau khi sắp xếp theo quy định tại khoản 114, khoản 115 Điều này và phần còn lại của các xã Kim Chung (huyện Đông Anh), Hải Bối, Kim Nỗ sau khi sắp xếp theo quy định tại khoản 116 Điều này |
| 118 | Xã Mê Linh | toàn bộ diện tích tự nhiên, quy mô dân số của xã Tráng Việt, một phần diện tích tự nhiên, quy mô dân số của các xã Tiền Phong (huyện Mê Linh), Văn Khê, Mê Linh, một phần diện tích tự nhiên của xã Đại Thịnh và xã Hồng Hà, phần còn lại của các xã Liên Hà (huyện Đan Phượng), Liên Hồng, Liên Trung sau khi sắp xếp theo quy định tại khoản 107 Điều này, phần còn lại của xã Đại Mạch sau khi sắp xếp theo quy định tại khoản 116 Điều này |
| 119 | Xã Yên Lãng | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Chu Phan, Hoàng Kim, Liên Mạc, một phần diện tích tự nhiên, quy mô dân số của xã Thạch Đà, một phần diện tích tự nhiên của xã Văn Khê, phần còn lại của các xã Tiến Thịnh, Trung Châu, Thọ Xuân, Thọ An sau khi sắp xếp theo quy định tại khoản 108 Điều này và phần còn lại của xã Hồng Hà sau khi sắp xếp theo quy định tại các khoản 107, 108, 118 Điều này |
| 120 | Xã Tiến Thắng | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Tam Đồng, Tiến Thắng, Tự Lập, một phần diện tích tự nhiên, quy mô dân số của các xã Đại Thịnh, Kim Hoa, Thanh Lâm, phần còn lại của xã Văn Khê sau khi sắp xếp theo quy định tại các khoản 107, 118, 119 Điều này và phần còn lại của xã Thạch Đà sau khi sắp xếp theo quy định tại khoản 119 Điều này |
| 121 | Xã Quang Minh | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Chi Đông, thị trấn Quang Minh, phần còn lại của xã Mê Linh sau khi sắp xếp theo quy định tại khoản 118 Điều này, phần còn lại của xã Tiền Phong (huyện Mê Linh) sau khi sắp xếp theo quy định tại khoản 116, khoản 118 Điều này, phần còn lại của xã Đại Thịnh sau khi sắp xếp theo quy định tại khoản 118, khoản 120 Điều này, phần còn lại của xã Kim Hoa và xã Thanh Lâm sau khi sắp xếp theo quy định tại khoản 120 Điều này |
| 122 | Xã Sóc Sơn | toàn bộ diện tích tự nhiên, quy mô dân số của thị trấn Sóc Sơn, xã Tân Minh và xã Đông Xuân (huyện Sóc Sơn), các xã Phù Lỗ, Phù Linh, Tiên Dược, một phần diện tích tự nhiên, toàn bộ quy mô dân số của xã Mai Đình, một phần diện tích tự nhiên của xã Phú Minh và xã Quang Tiến |
| 123 | Xã Đa Phúc | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Bắc Phú, Đức Hoà, Kim Lũ, Tân Hưng, Việt Long, Xuân Giang và Xuân Thu |
| 124 | Xã Nội Bài | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Phú Cường (huyện Sóc Sơn), Hiền Ninh, Thanh Xuân và phần còn lại của các xã Mai Đình, Phú Minh, Quang Tiến sau khi sắp xếp theo quy định tại khoản 122 Điều này |
| 125 | Xã Trung Giã | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Bắc Sơn, Hồng Kỳ, Nam Sơn và Trung Giã |
| 126 | Xã Kim Anh | toàn bộ diện tích tự nhiên, quy mô dân số của các xã Tân Dân (huyện Sóc Sơn), Minh Phú và Minh Trí |
