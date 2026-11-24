---
title: Cảnh báo trùng số điện thoại khi tạo lead
group: vai
slug: tu-van-ts1b
order: 41
role: Tư vấn tuyển sinh
portals: [crm]
priority: P1
flow: ts1b
screens: [TS-03, TS-14]
checked: 2026-11-24
---

# Cảnh báo trùng số điện thoại khi tạo lead

**Làm xong bạn có:** biết khách này đã có hồ sơ và không tạo trùng, hoặc tạo lead mới có mã khi thật sự là khách khác.
**Ai làm:** Tư vấn tuyển sinh, CSKH. **Màn:** Tuyển sinh → Lead. Đây là trường hợp ngoại lệ của bài «Tạo lead nhanh».

> Làm theo các bước dưới, đủ để làm.

## Trước khi bắt đầu, kiểm
- [ ] Bạn đang ở trang «Tạo lead» và đã nhập họ tên, số điện thoại.

## Luật cần nhớ (lời thường)
- Một số điện thoại chỉ nên có một hồ sơ. Hệ thống báo ngay nếu số đã có ở lead hoặc phụ huynh khác.
- Chỉ tạo «Vẫn tạo mới» khi thật sự là khách khác (ví dụ hai phụ huynh dùng chung một số của người nhà).

## Các bước
1. Nhập «Số điện thoại» rồi bấm ra ngoài ô.
   *Bạn thấy:* ngay dưới ô hiện khung vàng «Số điện thoại này đã có trong hệ thống», kèm nhóm «Lead đã có» hoặc «Phụ huynh đã có» và liên kết «Mở bản ghi trùng».
   [ẢNH: ts03-ts1-b2]
2. Bấm «Mở bản ghi trùng» để xem hồ sơ cũ. Nếu đúng là cùng khách, **không tạo mới**: dùng hồ sơ cũ (xem bài «Chăm sóc lead»). Nếu là khách khác, quay lại biểu mẫu.
   *Bạn thấy:* hồ sơ lead hoặc phụ huynh cũ.
3. Điền các ô còn lại như bài «Tạo lead nhanh» rồi bấm **«Lưu»**.
   *Bạn thấy:* hộp **«Số điện thoại này đã có khách hàng»** với hai nút «Vẫn tạo mới» và «Gắn vào hồ sơ có sẵn».
4. Chọn trong hộp:
   - Cùng một khách: bấm **«Gắn vào hồ sơ có sẵn»** (nút này chỉ có khi số đã thuộc một phụ huynh bạn được xem). Lead mới gắn vào phụ huynh cũ.
   - Khách khác: bấm **«Vẫn tạo mới»**.
   - Chưa chắc: đóng hộp bằng dấu X ở góc; bạn quay lại biểu mẫu, chưa lưu gì.
   *Bạn thấy:* lead được tạo, có mã.
   [ẢNH: ts14-ts1-b7]
   [CHƯA CHỤP: cần chụp trên staging CS5]

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Sửa số điện thoại sang số đã có | hộp «Số điện thoại này đã có hồ sơ»: «Vẫn dùng số này» nếu thật sự khác khách, không thì đóng và nhập lại |
| Tạo trùng một khách | báo Trưởng cơ sở hoặc CSKH dùng «Gộp trùng» ở menu «Hành động» |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì / báo ai |
|---|---|---|
| «Số điện thoại này đã có hồ sơ. Gắn vào hồ sơ có sẵn hoặc xác nhận vẫn tạo mới.» (HMT_SDT_TRUNG) | máy chủ chặn vì trùng | làm theo bước 4 |

## Hỏi đáp
- **Số điện thoại trùng với lead của sale khác thì sao?** Bạn vẫn thấy cảnh báo; nếu hồ sơ thuộc cơ sở khác bạn không mở được bản ghi trùng, hỏi Trưởng cơ sở.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản `sale.cs5` (hoặc `cskh.cs5`) trên môi trường thử.
- **Dùng:** Menu tài khoản → «Dữ liệu mẫu của tôi» tạo bộ mẫu; nhập số mẫu của bộ (dải 0999 000 xxx) để thấy cảnh báo, rồi đóng hộp bằng dấu X, không lưu.

## Tự kiểm: bạn làm được khi
- [ ] Bạn nói được khi nào bấm «Gắn vào hồ sơ có sẵn», khi nào «Vẫn tạo mới».
