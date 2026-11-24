---
id: tc10
ten: Số dư khách hàng và dùng số dư cho đơn mới
vai: [ke-toan, cskh]
phan_he: thu-chi
ma_man: [TC-14, TC-16]
uu_tien: P2
cap_nhat: 2026-11-24
---

# Số dư khách hàng và dùng số dư cho đơn mới

**Làm xong bạn có:** biết phụ huynh còn bao nhiêu tiền dư, và khi phụ huynh mua đơn mới thì **cấn** số dư đó vào đơn thay cho thu tiền lần nữa.
**Ai làm:** xem số dư: Kế toán, Trưởng cơ sở, Admin. **Cấn số dư vào đơn:** Kế toán. **Màn:** Bán hàng và thu chi → **Số dư khách hàng**; cấn ở bản ghi đơn «Đã duyệt» → «Hành động» → «Dùng số dư».

## Trước khi bắt đầu, kiểm
- [ ] Phụ huynh **đang có số dư** (tìm ở danh sách; ô «Số dư» lọc «Còn tiền dư»).
- [ ] Đơn mới đã **«Đã duyệt»** và còn phải thu (chỉ cấn vào đơn Đã duyệt).
- [ ] Tính năng cấn số dư do Admin bật cho cơ sở. Chưa bật thì không có mục «Dùng số dư», hoặc báo «Cấn số dư khách hàng vào đơn chưa được bật cho cơ sở này.»

## Cần nhớ
- Số dư sinh từ **dừng học**, **chuyển phí** hoặc **số dư đầu kỳ**. Bạn không tự cộng số dư bằng tay.
- Cấn số dư **không có phiếu thu**: hệ thống ghi vào đơn như một khoản tiền vào. Kế toán không thu thêm tiền thật cho phần này.
- Số tiền cấn **không vượt** số dư hiện có và **không vượt** phần còn phải thu của đơn.
- Chỉ làm trên máy tính.

## Các bước (xem số dư)
1. Mở **Số dư khách hàng**. Tìm bằng ô «Tìm tên, mã, số điện thoại phụ huynh…» hoặc lọc. Mỗi dòng: phụ huynh, mã phụ huynh, «Số dư (đ)», «Phát sinh gần nhất», «Số dòng sổ», «Cơ sở». Chưa có ai có số dư thì thấy «Chưa có số dư khách hàng nào». [ẢNH: tc10-b1]
2. Bấm tên phụ huynh. *Bạn thấy:* trang lịch sử, ghi «Số dư hiện tại», bảng «Lịch sử sổ số dư» (Ngày, Loại, Số tiền, Học sinh, Ghi danh, Ghi chú). Loại gồm: «Thu thừa đầu kỳ», «Công nợ đầu kỳ», «Từ dừng học», «Dùng cho đơn», «Điều chỉnh». [CHƯA CHỤP: staging CS5 chưa có phụ huynh nào có số dư; sẽ chụp khi có dữ liệu mẫu]

## Các bước (dùng số dư cho đơn mới)
1. Mở đơn **«Đã duyệt»** của phụ huynh đó. Bấm **«Hành động»**, chọn **«Dùng số dư»**. [CHƯA CHỤP: cần phụ huynh có số dư và cờ bật]
2. Hộp «Dùng số dư cho đơn» hiện «Số dư hiện có» và «Còn thu của đơn». Ô «Số tiền dùng» đã điền sẵn mức tối đa dùng được (số nhỏ hơn trong hai số trên). Sửa nếu chỉ dùng một phần. Bấm **«Xác nhận dùng số dư»**.
   *Bạn thấy:* thông báo «Đã dùng … số dư cho đơn DH-…»; «Đã thu» của đơn tăng, «Còn phải thu» giảm; sổ số dư có thêm dòng «Dùng cho đơn».

## Sau bước này
- **Ai làm tiếp:** còn phải thu thì tạo phiếu thu cho phần còn lại (bài «Tạo phiếu thu từ đơn hàng»). Đủ tiền thì ghi danh được tạo theo quy định đã có.
- **Bạn xem ở đâu:** **Khoản tiền vào** (dòng cấn số dư), và lịch sử số dư của phụ huynh.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Cấn nhầm đơn hoặc nhầm số tiền | nhờ Kế toán **hoàn tác khoản tiền vào** (bài «Khoản tiền vào (sổ thu tiền) và hoàn tác khoản»); số dư được trả lại |
| Cấn nhầm vì phụ huynh có phiếu thu khác | xem lại «Còn thu của đơn» trước khi bấm xác nhận |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì |
|---|---|---|
| Tối đa N đ. / Nhập số tiền lớn hơn 0. | số tiền cấn không hợp lệ | nhập số trong giới hạn hiện dưới ô |
| Số tiền cấn vượt số dư khách hàng hiện có. | phụ huynh không còn đủ số dư | giảm số tiền |
| Số tiền cấn vượt phần còn phải thu của đơn. | đơn không còn thu nhiều như vậy | giảm số tiền |
| Chỉ cấn số dư vào đơn Đã duyệt. | đơn chưa duyệt hoặc đã huỷ | duyệt đơn trước |
| Cấn số dư khách hàng vào đơn chưa được bật cho cơ sở này. | Admin chưa bật tính năng | nhờ Admin |
| Bạn không có quyền xem số dư này | tài khoản khác cơ sở hoặc thiếu quyền | nhờ Trưởng cơ sở hoặc Admin |

## Hỏi đáp
- **Phụ huynh dừng học thì tiền đi đâu?** Tiền còn lại của ghi danh dừng học được giữ thành số dư; phụ huynh dùng cho đơn mới, hoặc làm ticket hoàn tiền.
- **Số dư có hết hạn không?** Không. Số dư không hết hạn; sổ số dư chỉ thêm dòng, không sửa, không xoá.
- **Dùng số dư có ra biên nhận không?** Không có phiếu thu nên không có biên nhận in.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản Kế toán.
- **Dùng:** phụ huynh «[MẪU] …» có số dư (nếu bộ mẫu chưa có thì nhờ quản lý tạo; staging CS5 hiện chưa có) và một đơn «Đã duyệt» còn phải thu.
