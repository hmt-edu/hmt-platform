---
title: Tạo lead nhanh
group: vai
slug: tu-van-ts1
order: 41
role: Tư vấn tuyển sinh
portals: [crm]
priority: P1
flow: ts1
screens: [TS-01, TS-03]
checked: 2026-11-24
---

# Tạo lead nhanh

**Làm xong bạn có:** một lead mới có mã, đang ở giai đoạn «C1 Data mới».
**Ai làm:** Tư vấn tuyển sinh, CSKH. **Màn:** Tuyển sinh → Lead.

> Video: [VIDEO: ts1]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

## Trước khi bắt đầu, kiểm
- [ ] Ô cơ sở ở thanh trên đúng cơ sở của khách.
- [ ] Bạn có họ tên phụ huynh và số điện thoại (đủ 10 số, bắt đầu bằng 0).
- [ ] Bạn biết khách biết đến trung tâm qua đâu (để chọn «Source»).

## Luật cần nhớ (lời thường)
- Lead mới luôn bắt đầu ở «C1 Data mới». Bạn không chọn giai đoạn lúc tạo; ô «Sub-stage» ghi «Chưa có».
- Một số điện thoại chỉ nên có một hồ sơ. Nếu hệ thống báo số đã có, xem bài «Cảnh báo trùng số điện thoại khi tạo lead».

## Các bước
1. Vào **Lead**, bấm **«Tạo»**.
   *Bạn thấy:* trang lead mới, các khối «Thông tin phụ huynh», «Thông tin học sinh», «Nhu cầu»; ô «Sub-stage» ghi «Chưa có».
   [ẢNH: ts03-ts1-b1]
2. Điền «Họ tên» và «Số điện thoại» (hai ô bắt buộc). Nhập xong số điện thoại, bấm ra ngoài ô.
   *Bạn thấy:* số mới thì không có gì hiện thêm. Nếu hiện khung vàng «Số điện thoại này đã có trong hệ thống», dừng lại và làm theo bài «Cảnh báo trùng số điện thoại khi tạo lead».
3. Điền thêm nếu biết: «Tên học sinh», «Năm sinh» (4 chữ số), «Trường học», «Nhu cầu».
   *Bạn thấy:* các ô nhận chữ; «Tên học sinh» và «Năm sinh» ghi «bắt buộc từ L5» (chưa cần ở lead).
4. Ở khối «Nguồn và phụ trách»: chọn «Cơ sở», «Nhân sự phụ trách» (có thể chọn «Bạn»), «Source». Nếu Source có kênh con thì chọn thêm «Sub-source». «Chiến dịch» chọn nếu có.
   *Bạn thấy:* ô nào còn thiếu thì viền báo đỏ khi lưu.
   [ẢNH: ts03-ts1-b5]
5. Bấm **«Lưu»**.
   *Bạn thấy:* thông báo «Đã tạo lead LD-…», trang chuyển sang lead vừa tạo, giai đoạn «C1 Data mới».

⚠ **Mã lead cấp một lần, không sửa được.** Tạo nhầm khách thì nhờ Admin dùng «Huỷ lead nhập nhầm», không tự xoá được.

## Sau bước này
- **Ai làm tiếp:** bạn gọi khách và đổi giai đoạn (bài «Chăm sóc lead»); cần hẹn thì «Lên lịch hẹn» (bài «Lịch hẹn»).
- **Bạn xem ở đâu:** Lead → ô tìm, gõ tên hoặc số điện thoại; hoặc lọc «của tôi».

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Gõ sai họ tên, nguồn, nhu cầu | bấm «Sửa», đổi, «Lưu» |
| Tạo trùng một khách | báo Trưởng cơ sở hoặc CSKH dùng «Gộp trùng» ở menu «Hành động» |
| Tạo nhầm hoàn toàn | nhờ Admin «Huỷ lead nhập nhầm» (cần lý do) |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Nhập họ tên phụ huynh.» | ô «Họ tên» trống | điền họ tên |
| «Số điện thoại cần đủ 10 số, bắt đầu bằng 0.» | số sai dạng | nhập lại, bỏ dấu cách thừa |
| «Chọn source.» / «Chọn sub-source.» | thiếu nguồn | chọn ở khối «Nguồn và phụ trách» |
| «Chọn nhân sự phụ trách.» / «Chọn cơ sở.» | thiếu người hoặc cơ sở | chọn đủ hai ô |
| «Cơ sở văn phòng (Hội sở) không có lead.» (HMT_CO_SO_VAN_PHONG) | đang chọn cơ sở văn phòng | chọn một cơ sở có học sinh |

## Hỏi đáp
- **Hai anh em của cùng một phụ huynh thì tạo mấy lead?** Một lead, ghi học sinh đầu. Em còn lại thêm khi tạo cơ hội.
- **Khách không cho số điện thoại?** Hệ thống bắt buộc có số. Hỏi lại khách, không nhập số giả.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản `sale.cs5` (hoặc `cskh.cs5`) trên môi trường thử.
- **Dùng:** Menu tài khoản → «Dữ liệu mẫu của tôi» tạo bộ mẫu; thử tạo lead mới với một số chưa có trong bộ. Số mẫu dùng dải 0999 000 xxx, không dùng số thật.

## Tự kiểm: bạn làm được khi
- [ ] Có một lead «[MẪU]» của bạn ở «C1 Data mới».
- [ ] Bạn biết nhìn khung vàng sau khi nhập số điện thoại, và dừng lại khi nó hiện.
