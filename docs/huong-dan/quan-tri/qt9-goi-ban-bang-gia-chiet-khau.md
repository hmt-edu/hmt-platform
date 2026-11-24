---
id: qt9
ten: Gói bán, bảng giá, chiết khấu, điều khoản thanh toán
vai: [quan-tri]
phan_he: cau-hinh
ma_man: [CH-01, CH-02, CH-03, CH-04, CH-09]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Gói bán, bảng giá có ngày hiệu lực, chiết khấu, điều khoản thanh toán

**Làm xong bạn có:** gói bán có giá theo ngày hiệu lực, chính sách chiết khấu và điều khoản chia đợt để nhân viên chọn khi lập báo giá, đơn.
**Ai làm:** Admin (quyền Cấu hình bán hàng). **Màn:** menu **Cấu hình** → **Gói bán**, **Bảng giá**, **Chính sách chiết khấu**, **Điều khoản thanh toán**.

> Video: [VIDEO: qt9]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

Bài này gồm bốn việc nhỏ cùng chủ đề. **Bài dài hơn 7 bước, nên tách** thành bốn bài khi làm video: (A) Gói bán, (B) Bảng giá, (C) Chiết khấu, (D) Điều khoản thanh toán. Ở dưới mỗi việc có tối đa 7 bước.

⚠ **Đây là thao tác thật trên môi trường đang dùng.** Giá và chính sách ảnh hưởng đơn mới ngay khi tới ngày hiệu lực. Tập thì chỉ tập trên staging.

## Trước khi bắt đầu, kiểm
- [ ] Bạn là Admin (hoặc vai có quyền Cấu hình bán hàng; vai chỉ xem thì không có nút tạo, sửa).
- [ ] Bạn biết **ngày hiệu lực** của giá hoặc chính sách mới.
- [ ] Bạn đã thống nhất mức giá, mức chiết khấu với người có thẩm quyền; số trong ví dụ chỉ để tập.

## Luật cần nhớ (lời thường)
- **Giá và chính sách chỉ thêm mới, không sửa lại**. Muốn đổi giá: thêm giá mới với ngày hiệu lực mới. Đơn đã lập **giữ giá lúc tạo**, không tính lại.
- **Không xoá**: gói, chính sách, điều khoản chỉ **Ngừng** (hoặc «Ngừng bán»). Ngừng thì không hiện ở ô chọn mới; đơn cũ giữ nguyên.
- **Mã gói** tự ghép theo Loại-Môn-Khối (khối từ - khối đến nếu nhiều khối), **không chứa hình thức** (offline, online). Mã, loại, môn, khối không đổi sau khi tạo; chỉ đổi được «Tên gói» và «Mã cũ (Sheet)».
- **Gói không có số giờ**: số giờ nhập khi lập dòng đơn. Giá tính theo giờ; dịch vụ tính theo tháng, tài liệu theo bộ; dịch vụ, tài liệu **không có giá online**.
- **Giá để trống = không bán hình thức đó** từ ngày hiệu lực. Khác với «Chưa có giá» (chờ cập nhật, chưa phải ngừng bán).
- **Chiết khấu**: có kiểu phần trăm hoặc giờ tặng; nhiều chiết khấu trên một dòng thì cộng dồn, tổng không quá trần (đổi trần ở Tham số nghiệp vụ); vượt trần cần quản lý cơ sở duyệt. Quà tặng (tài liệu, dịch vụ giá 0 đ) không tính vào trần.
- **Điều khoản thanh toán** đã tạo **không sửa được**; muốn đổi thì «Tạo bản mới». Lịch đóng dùng để theo dõi công nợ, nhắc hạn; **không chặn học**.

## A. Gói bán (menu Cấu hình → Gói bán)
1. Bấm «Tạo gói».
   *Bạn thấy:* hộp «Tạo gói bán» có «Loại gói», «Môn», «Khối từ», «Khối đến», «Tên gói», «Mã cũ (Sheet)».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b1]
2. Chọn «Loại gói» (Lớp chung, VIP, Kèm riêng, Dịch vụ, Tài liệu…); gói tính theo giờ thì chọn «Môn», «Khối từ», «Khối đến» (bằng khối từ nếu một khối). Gói dịch vụ hoặc tài liệu thì điền «Tên viết tắt trong mã» (ví dụ CSGK).
   *Bạn thấy:* ô «Mã gói» tự hiện mã ghép, không sửa được.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b2]
3. Điền «Tên gói» rồi bấm «Tạo gói».
   *Bạn thấy:* «Đã tạo gói <mã>.» và gói trong danh sách (cột «Mã gói», «Tên gói», «Loại gói», «Môn», «Khối», «Trạng thái» = «Đang bán»).
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b3]
4. Muốn đổi tên: bấm «Sửa» ở dòng gói. Muốn ngừng: bấm «Ngừng» rồi «Ngừng bán» trong hộp xác nhận. Muốn bán lại: «Dùng lại».
   *Bạn thấy:* «Đã lưu gói <mã>.», «Đã ngừng bán gói <mã>.» hoặc «Đã dùng lại gói <mã>.»
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b4]

## B. Bảng giá có ngày hiệu lực (menu Cấu hình → Bảng giá)
1. Chọn «Giá hiệu lực tại ngày» để xem bảng giá của một ngày; lọc bằng «Tìm gói», «Loại gói», «Môn», «Khối».
   *Bạn thấy:* bảng «Mã gói», «Tên gói», «Giá offline», «Giá online»; ô chưa có giá hiện chip «Chưa có giá», ô không bán hiện chip «Không bán».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b5]
2. Bấm «Thêm bảng giá mới».
   *Bạn thấy:* hộp «Thêm bảng giá mới»: «Hiệu lực từ», «Giá offline chung», «Giá online chung», bộ lọc gói và bảng «Chọn gói để thêm giá».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b6]
3. Chọn ngày «Hiệu lực từ»; chọn các gói (hoặc «Chọn tất cả theo bộ lọc»); nhập giá chung, và sửa riêng từng gói ở cột «Giá offline mới», «Giá online mới» nếu cần. Ô để trống = không thêm giá; chọn «Không bán hình thức này» = ngừng bán hình thức đó từ ngày hiệu lực.
   *Bạn thấy:* dòng tóm tắt «Bảng này có N dòng giá cho M gói đã chọn.»
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b7]
4. Bấm «Lưu bảng giá mới».
   *Bạn thấy:* «Đã thêm N dòng giá, hiệu lực từ <ngày>.»
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b8]

Thêm giá cho **một** gói: mở gói (bấm dòng ở «Gói bán») → «Thêm giá mới» → chọn «Hình thức» (Offline, Online), nhập «Giá (đồng)», «Hiệu lực từ» → «Thêm». Mục «Giá theo hiệu lực» của gói ghi từng dòng «Đã hiệu lực» hoặc «Chưa tới ngày hiệu lực».

⚠ **Lưu bảng giá không sửa lại được.** Sai giá thì thêm giá mới với ngày hiệu lực mới (có thể ngay hôm nay); không xoá dòng giá cũ.

## C. Chính sách chiết khấu (menu Cấu hình → Chính sách chiết khấu)
1. Mở trang; chọn tab «Chiết khấu» (hoặc «Quà tặng»).
   *Bạn thấy:* bảng chính sách: «Tên chính sách», «Kiểu» (% hoặc Giờ tặng), «Giá trị», «Mức tối đa», «Áp dụng cho», «Hiệu lực từ – đến», «Nhóm gói», «Cơ sở», «Cần duyệt», «Trạng thái».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b9]
2. Bấm «Thêm chiết khấu» (hoặc «Thêm quà tặng»).
   *Bạn thấy:* hộp «Thêm chính sách chiết khấu» với «Tên chính sách», «Kiểu», «Mức tối đa (%)» hoặc «Mức tối đa (giờ)», «Hiệu lực từ», «Hiệu lực đến», «Cơ sở», «Áp dụng cho», «Cần duyệt (quản lý cơ sở duyệt)», «Nhóm gói».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b10]
3. Điền các ô; để trống «Cơ sở» nghĩa là «Tất cả cơ sở»; chọn ít nhất một «Nhóm gói» và một nơi «Áp dụng cho» (Báo giá, Đơn, Phiếu thu). Tick «Áp đúng mức này (nhân viên không nhập)» nếu chính sách cố định, không để nhân viên tự điền. Bấm «Lưu».
   *Bạn thấy:* «Đã lưu chính sách.» và dòng mới ở bảng. Nếu thiếu: «Chưa lưu được: còn N chỗ cần sửa (…).»
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b11]
4. Muốn ngừng: «Ngừng» ở dòng; muốn dùng lại: «Dùng lại». Xem ai sửa gì: «Lịch sử thay đổi».
   *Bạn thấy:* «Đã ngừng chính sách.» / «Đã dùng lại chính sách.»
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b12]

Chính sách có nhãn «Hệ thống» (Ưu đãi linh hoạt) không sửa, không ngừng ở màn này; hạn mức của nó ở Tham số nghiệp vụ.

## D. Điều khoản thanh toán (menu Cấu hình → Điều khoản thanh toán)
1. Bấm «Thêm điều khoản».
   *Bạn thấy:* hộp «Thêm điều khoản thanh toán»: «Tên điều khoản», «Hiệu lực từ», danh sách «Các đợt».
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b13]
2. Với mỗi đợt, chọn «Cách chia» (đợt 1 được chọn «Số tiền cố định», các đợt sau chia phần trăm), điền «Giá trị (%)» hoặc «Số tiền (đ)», «Số ngày đến hạn» (tính từ ngày duyệt đơn); bấm «Thêm đợt» khi cần.
   *Bạn thấy:* các đợt đánh số «Đợt 1», «Đợt 2», … liên tục.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b14]
3. Bấm «Lưu».
   *Bạn thấy:* «Đã lưu điều khoản.»; điều khoản trong danh sách bên trái (ghi dạng «Chia 3 đợt», «Cọc … đ rồi N đợt», «Đóng một lần»), các đợt bên phải.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b15]
4. Muốn đổi: chọn điều khoản, bấm «Tạo bản mới», sửa, «Lưu» (thành «bản 2»). Muốn ngừng: «Ngừng»; dùng lại: «Dùng lại».
   *Bạn thấy:* «bản N» và ngày hiệu lực ở dòng điều khoản; đơn cũ vẫn giữ lịch đóng đã sinh.
   [CHƯA CHỤP: cần staging; ảnh dự kiến quan-tri-qt9-b16]

## Sau bước này
- **Ai làm tiếp:** Tư vấn tuyển sinh, CSKH chọn gói, giá, chiết khấu, điều khoản khi lập báo giá hoặc đơn từ ngày hiệu lực.
- **Bạn xem ở đâu:** mở lại từng màn; mọi sửa cấu hình có trong nhật ký thao tác.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Sai tên gói | «Sửa» ở dòng gói |
| Sai mã, loại, môn hoặc khối của gói | Không đổi được: «Ngừng bán» gói sai, tạo gói mới |
| Sai giá | Thêm giá mới với ngày hiệu lực đúng; không sửa giá cũ. Đơn đã lập vẫn giữ giá cũ |
| Sai chính sách chiết khấu | «Sửa» ở dòng, hoặc «Ngừng» và thêm mới. Loại (% hay giờ tặng) không đổi được |
| Sai điều khoản thanh toán | «Tạo bản mới»; bản cũ «Ngừng» nếu không dùng |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Mã gói này đã có.» (HMT_MA_GOI_TRUNG) | gói đó đã tạo | tìm gói trong danh sách |
| «Khối đến không được nhỏ hơn khối từ.» | chọn khối ngược | đổi lại |
| «Gói này đã có giá cho hình thức này từ ngày đó. Chọn ngày hiệu lực khác.» (HMT_GIA_DA_CO) | trùng ngày hiệu lực | chọn ngày khác |
| «Giá phải lớn hơn 0 (hoặc để trống nếu ngừng bán hình thức này).» (HMT_GIA_SAI) | nhập 0 hoặc số âm | nhập giá đúng, hoặc để trống |
| «Gói đã ngừng, không thêm giá mới.» (HMT_GOI_DA_NGUNG) | gói đã ngừng bán | «Dùng lại» gói trước |
| «Gói dịch vụ, tài liệu không có giá online.» (HMT_GOI_KHONG_CO_ONLINE) | nhập giá online cho dịch vụ, tài liệu | bỏ giá online |
| «Tổng phần trăm các đợt chia theo % phải đúng 100 (đang …).» (HMT_DIEU_KHOAN_SAI) | các đợt % chưa cộng đủ 100 | chỉnh lại |
| «Chỉ đợt 1 được là số tiền cố định.» | đợt sau không chọn được số tiền cố định | đổi sang % |
| «Phần trăm không quá 100.» / «Mức tối đa phải lớn hơn 0.» | mức chiết khấu sai | nhập lại |

## Tập trên dữ liệu mẫu
- **Cần:** `bgd.tap` (Admin) trên **staging**.
- **Dùng:** tạo gói tên «[MẪU] gói tập» với môn, khối bất kỳ; thêm giá offline 100.000 đ hiệu lực từ hôm nay (số này chỉ để tập); thêm một chiết khấu 5% tên «[MẪU] tập»; thêm điều khoản «[MẪU] chia 2 đợt» (đợt 1 50%, đợt 2 50%). Sau đó «Ngừng bán» gói mẫu và «Ngừng» chính sách mẫu.
- Chưa có trong bộ mẫu: gói, chính sách dành riêng để tập. Không đụng gói, giá, chính sách thật đang dùng.

## Tự kiểm: bạn làm được khi
- [ ] Bạn tạo được một gói mẫu, thêm được giá có ngày hiệu lực và đọc đúng giá đang hiệu lực.
- [ ] Bạn nói được vì sao đổi giá là thêm giá mới chứ không sửa giá cũ.
- [ ] Bạn tạo được một điều khoản mẫu có tổng phần trăm đúng 100 và nói được cách đổi nó (Tạo bản mới).

**Bước trước:** Công tắc tính năng theo cơ sở (qt6) · **Bước sau:** Lập báo giá, lập đơn hàng (vai Tư vấn tuyển sinh)

## Ghi chú cho người soát (không hiển thị cho người học)
- Vênh bản đồ màn hình (CH-01): «Mã gói Loại-Môn-Khối-Hình thức». Màn và DB hiện: mã Loại-Môn-Khối, không chứa hình thức (hình thức nằm ở bảng giá). Bài theo mã nguồn và DB (HMT_MA_GOI_SAI: «Mã gói phải là … (Loại-Môn-Khối, không chứa hình thức).»).
- Vênh canvas CH-03: canvas vẽ «bản bảng giá»; màn thật làm theo gói (ghi ở đầu PriceListPage.tsx); bài theo màn thật.
- Vênh canvas CH-04: DB chỉ có kiểu % và Giờ tặng, không có «Số tiền cố định»; «Giá trị» và «Mức tối đa» là một (xem ghi chú đầu DiscountPolicyPage.tsx). Bài theo màn thật.
- Vênh nhỏ canvas CH-09: các đợt sau đợt 1 chia theo % của tổng đơn khi đợt 1 là %, chỉ chia «phần còn lại sau đợt 1» khi đợt 1 là số tiền cố định (docs/nghiep-vu/ch09-dieu-khoan-thanh-toan.md). Bài ghi theo luật DB, không nêu cách chia chi tiết.
- Chưa xác nhận trên màn thật: nút «Lịch sử thay đổi» có hiện hay không (doc ch09 ghi nút này của CH-09 chưa làm; nút của CH-04 có trong mã); câu «Mã gói» của nhãn «Ngừng» khi bấm «Ngừng» ở trang bản ghi gói; thứ tự bảng giá theo nhóm.
- Mục «bài nên tách» ghi rõ theo quy cách (tối đa 7 bước): bài gồm bốn việc, tổng 16 bước nhỏ; ghi để Code A chia thành 4 bài (qt9a..qt9d) nếu cần.
- Quyền: Admin có đủ bảy hành động ở phân hệ CONFIG_SALES (migration 20261016000022); trưởng cơ sở chỉ xem.
- Tên các Loại gói lấy từ danh mục: Lớp chung (LC), VIP 1:1 và 1:2 (VIP), VIP nhóm nhỏ (VNN), Kèm riêng (KR), Dịch vụ (DV), Tài liệu (TL); bài chỉ nêu một phần.
