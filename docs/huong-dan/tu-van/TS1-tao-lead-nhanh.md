---
title: Tạo lead nhanh và xử lý cảnh báo trùng số điện thoại
group: vai
slug: tu-van-ts1
order: 41
role: Tư vấn tuyển sinh
portals: [crm]
priority: P1
flow: ts1
screens: [TS-01, TS-03, TS-14]
checked: 2026-11-24
---

# Tạo lead nhanh và xử lý cảnh báo trùng số điện thoại

**Làm xong bạn có:** một lead mới có mã, đang ở giai đoạn «C1 Data mới», hoặc bạn biết khách này đã có hồ sơ và không tạo trùng.
**Ai làm:** Tư vấn tuyển sinh, CSKH. **Màn:** Tuyển sinh → Lead.

> Video: [VIDEO: tu-van-tong-quan]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

## Trước khi bắt đầu, kiểm
- [ ] Ô cơ sở ở thanh trên đúng cơ sở của khách.
- [ ] Bạn có họ tên phụ huynh và số điện thoại (đủ 10 số, bắt đầu bằng 0).
- [ ] Bạn biết khách biết đến trung tâm qua đâu (để chọn «Source»).

## Luật cần nhớ (lời thường)
- Lead mới luôn bắt đầu ở «C1 Data mới». Bạn không chọn giai đoạn lúc tạo; ô «Sub-stage» ghi «Chưa có».
- Một số điện thoại chỉ nên có một hồ sơ. Hệ thống báo ngay nếu số đã có ở lead hoặc phụ huynh khác.
- Chỉ tạo «Vẫn tạo mới» khi thật sự là khách khác (ví dụ hai phụ huynh dùng chung một số của người nhà).

## Các bước
1. Vào **Lead**, bấm **«Tạo»**.
   *Bạn thấy:* trang lead mới, các khối «Thông tin phụ huynh», «Thông tin học sinh», «Nhu cầu»; ô «Sub-stage» ghi «Chưa có».
   [ẢNH: ts03-ts1-b1]
2. Điền «Họ tên» và «Số điện thoại» (hai ô bắt buộc). Nhập xong số điện thoại, bấm ra ngoài ô.
   *Bạn thấy:* nếu số đã có, ngay dưới ô hiện khung vàng «Số điện thoại này đã có trong hệ thống», kèm nhóm «Lead đã có» hoặc «Phụ huynh đã có» và liên kết «Mở bản ghi trùng». Nếu số mới thì không có gì hiện.
   [ẢNH: ts03-ts1-b2]
3. Nếu có khung vàng: bấm «Mở bản ghi trùng» để xem hồ sơ cũ. Nếu đúng là cùng khách, **không tạo mới**: dùng hồ sơ cũ (xem bài «Chăm sóc lead»). Nếu là khách khác, quay lại và làm tiếp bước 4.
   *Bạn thấy:* hồ sơ lead hoặc phụ huynh cũ.
4. Điền thêm nếu biết: «Tên học sinh», «Năm sinh» (4 chữ số), «Trường học», «Nhu cầu».
   *Bạn thấy:* các ô nhận chữ; «Tên học sinh» và «Năm sinh» ghi «bắt buộc từ L5» (chưa cần ở lead).
5. Ở khối «Nguồn và phụ trách»: chọn «Cơ sở», «Nhân sự phụ trách» (có thể chọn «Bạn»), «Source». Nếu Source có kênh con thì chọn thêm «Sub-source». «Chiến dịch» chọn nếu có.
   *Bạn thấy:* ô nào còn thiếu thì viền báo đỏ khi lưu.
   [ẢNH: ts03-ts1-b5]
6. Bấm **«Lưu»**.
   *Bạn thấy:* nếu số điện thoại chưa có: thông báo «Đã tạo lead LD-…», trang chuyển sang lead vừa tạo. Nếu số đã có: hộp **«Số điện thoại này đã có khách hàng»** với hai nút «Vẫn tạo mới» và «Gắn vào hồ sơ có sẵn».
7. Khi hộp cảnh báo hiện:
   - Cùng một khách: bấm **«Gắn vào hồ sơ có sẵn»** (nút này chỉ có khi số đã thuộc một phụ huynh bạn được xem). Lead mới gắn vào phụ huynh cũ.
   - Khách khác: bấm **«Vẫn tạo mới»**.
   - Chưa chắc: đóng hộp bằng dấu X ở góc; bạn quay lại biểu mẫu, chưa lưu gì.
   *Bạn thấy:* lead được tạo, có mã.
   [ẢNH: ts14-ts1-b7]
   [CHƯA CHỤP: cần chụp trên staging CS5]

⚠ **Mã lead cấp một lần, không sửa được.** Tạo nhầm khách thì nhờ Admin dùng «Huỷ lead nhập nhầm», không tự xoá được.

## Sau bước này
- **Ai làm tiếp:** bạn gọi khách và đổi giai đoạn (bài «Chăm sóc lead»); cần hẹn thì «Lên lịch hẹn» (bài «Lịch hẹn»).
- **Bạn xem ở đâu:** Lead → ô tìm, gõ tên hoặc số điện thoại; hoặc lọc «của tôi».

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Gõ sai họ tên, nguồn, nhu cầu | bấm «Sửa», đổi, «Lưu» |
| Sửa số điện thoại sang số đã có | hộp «Số điện thoại này đã có hồ sơ»: «Vẫn dùng số này» nếu thật sự khác khách, không thì đóng và nhập lại |
| Tạo trùng một khách | báo Trưởng cơ sở hoặc CSKH dùng «Gộp trùng» ở menu «Hành động» |
| Tạo nhầm hoàn toàn | nhờ Admin «Huỷ lead nhập nhầm» (cần lý do) |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Nhập họ tên phụ huynh.» | ô «Họ tên» trống | điền họ tên |
| «Số điện thoại cần đủ 10 số, bắt đầu bằng 0.» | số sai dạng | nhập lại, bỏ dấu cách thừa |
| «Chọn source.» / «Chọn sub-source.» | thiếu nguồn | chọn ở khối «Nguồn và phụ trách» |
| «Chọn nhân sự phụ trách.» / «Chọn cơ sở.» | thiếu người hoặc cơ sở | chọn đủ hai ô |
| «Số điện thoại này đã có hồ sơ. Gắn vào hồ sơ có sẵn hoặc xác nhận vẫn tạo mới.» (HMT_SDT_TRUNG) | máy chủ chặn vì trùng | làm theo bước 7 |
| «Cơ sở văn phòng (Hội sở) không có lead.» (HMT_CO_SO_VAN_PHONG) | đang chọn cơ sở văn phòng | chọn một cơ sở có học sinh |

## Hỏi đáp
- **Hai anh em của cùng một phụ huynh thì tạo mấy lead?** Một lead, ghi học sinh đầu. Em còn lại thêm khi tạo cơ hội.
- **Số điện thoại trùng với lead của sale khác thì sao?** Bạn vẫn thấy cảnh báo; nếu hồ sơ thuộc cơ sở khác bạn không mở được bản ghi trùng, hỏi Trưởng cơ sở.
- **Khách không cho số điện thoại?** Hệ thống bắt buộc có số. Hỏi lại khách, không nhập số giả.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản `sale.cs5` (hoặc `cskh.cs5`) trên môi trường thử.
- **Dùng:** Menu tài khoản → «Dữ liệu mẫu của tôi» tạo bộ mẫu; thử tạo lead mới với số mẫu của bộ để thấy cảnh báo trùng. Số mẫu dùng dải 0999 000 xxx, không dùng số thật.

## Tự kiểm: bạn làm được khi
- [ ] Có một lead «[MẪU]» của bạn ở «C1 Data mới».
- [ ] Bạn nói được khi nào bấm «Gắn vào hồ sơ có sẵn», khi nào «Vẫn tạo mới».
