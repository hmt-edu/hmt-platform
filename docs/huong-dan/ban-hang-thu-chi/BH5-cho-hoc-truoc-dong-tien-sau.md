---
id: bh5
ten: Bật «Cho học trước, đóng tiền sau»
vai: [truong-co-so]
phan_he: ban-hang
ma_man: [BH-09]
uu_tien: P2
cap_nhat: 2026-11-24
---

# Bật «Cho học trước, đóng tiền sau»

**Làm xong bạn có:** em được học ngay các buổi đầu dù phụ huynh chưa đóng tiền; hệ thống tạo sẵn ghi danh, quỹ giờ được âm tới hạn mức.
**Ai làm:** Trưởng cơ sở (người có quyền duyệt đơn). **Màn:** Đơn hàng → mở đơn «Đã duyệt» → nút «Cho học trước».

## Trước khi bắt đầu, kiểm
- [ ] Đơn **«Đã duyệt»** và **chưa có đồng nào đã thu** (bật khi đã có tiền vào thì bị chặn).
- [ ] Phụ huynh đã cam kết đóng tiền; bạn chịu trách nhiệm về khoản học trước.
- [ ] Bạn biết **hạn mức**: số buổi em được học trước khi đóng tiền. Hộp bật sẽ nêu rõ (ví dụ 2 buổi).
- [ ] Tính năng này do Admin bật cho cơ sở. Không thấy nút «Cho học trước» ở đơn đủ điều kiện thì nhờ Admin kiểm.

## Cần nhớ
- Học vượt hạn mức thì em **bị loại khỏi danh sách các buổi sau**, và vận hành, sale nhận cảnh báo.
- Khi thu tiền, các buổi đã học vẫn tính là đã học và **trừ vào giờ được cấp**; không học miễn phí.
- Đơn đã bật cho học trước mà em đã học thì **không huỷ đơn được**: phải thu tiền, hoặc làm ticket «Dừng học» (bài «Huỷ đơn hàng»). Phụ huynh chưa đóng đồng nào thì không có tiền để hoàn: «Hoàn phí» bị chặn (HMT_HOAN_PHI_KHONG_CON_TIEN), chỉ «Dừng học» được.
- Chỉ làm trên máy tính, không có trên điện thoại.

## Các bước
1. Mở đơn «Đã duyệt» chưa thu. Cạnh nút «Tạo phiếu thu» có nút **«Cho học trước»**, bấm vào đó. [ẢNH: bh5-b1]
   *Bạn thấy:* hộp «Bật cho học trước, đóng tiền sau», ghi «Đơn hàng DH-…» và «Hạn mức học trước … buổi», kèm đoạn giải thích. [ẢNH: bh5-b2]
2. Đọc lại hạn mức rồi bấm **«Bật»** (hoặc «Huỷ» nếu thôi).
   *Bạn thấy:* thông báo «Đã bật cho học trước.»; ô «Ghi danh» trên đầu đơn có số lớn hơn 0; nút đổi thành **«Tắt cho học trước»**. [ẢNH: bh5-b3]

## Tắt lại khi cần
1. Bấm **«Tắt cho học trước»**. Hộp «Tắt cho học trước» nhắc: chỉ tắt được khi mọi ghi danh còn quỹ giờ không âm. [ẢNH: bh5-b4]
2. Bấm **«Tắt»**. *Bạn thấy:* «Đã tắt cho học trước.».
- Em đã học trước (quỹ giờ âm) thì **không tắt được**: thu tiền trước.

## Sau bước này
- **Ai làm tiếp:** Tư vấn, CSKH xếp lớp cho ghi danh (bài «Xếp lớp cho ghi danh chờ xếp lớp»); phụ huynh đóng tiền: lập **phiếu thu** như bình thường (bài «Tạo phiếu thu từ đơn hàng»).
- **Bạn xem ở đâu:** **Ghi danh** (danh sách, số giờ), và «Ghi danh» trên đầu đơn.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Bật nhầm đơn | bấm «Tắt cho học trước» ngay, khi em chưa học buổi nào |
| Em đã học trước mà muốn dừng | thu tiền trước, hoặc làm ticket «Dừng học» (chưa đóng đồng nào thì không hoàn phí được) |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì |
|---|---|---|
| Cho học trước, đóng tiền sau chưa được bật cho cơ sở này. | Admin chưa bật tính năng cho cơ sở | nhờ Admin |
| Chỉ bật cho học trước trên đơn đã duyệt. | đơn chưa duyệt hoặc đã huỷ | duyệt đơn trước |
| Đơn đã có tiền vào, không bật cho học trước (ghi danh tạo theo tiền đã thu). | đã có phiếu thu được duyệt | không cần bật; ghi danh tạo theo tiền đã thu |
| Có ghi danh đã học trước (quỹ giờ âm): thu tiền trước khi tắt cho học trước. | em đã học vượt phần đã đóng | thu tiền rồi tắt |

## Hỏi đáp
- **Nút «Cho học trước» đâu rồi?** Chỉ hiện ở đơn «Đã duyệt» chưa thu, với người có quyền duyệt đơn; hoặc tính năng chưa bật cho cơ sở.
- **Hạn mức đổi được không?** Hạn mức là tham số của cơ sở do Admin chỉnh; bạn không tự đổi.
- **Phụ huynh không đóng tiền thì sao?** Bạn làm ticket «Dừng học» (chưa đóng đồng nào thì không có gì để hoàn, nên không dùng «Hoàn phí»); không tự xoá ghi danh.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản Trưởng cơ sở.
- **Dùng:** đơn **«Đã duyệt»**, «Chưa thu» của «[MẪU] …» trong «Dữ liệu mẫu của tôi»; bật rồi tắt lại ngay khi tập.
