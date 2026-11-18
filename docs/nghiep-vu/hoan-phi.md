# Hoàn phí: hàm tính tiền (migration 212)

Code D, 16/11/2026. Luật: R-TIEN-28, R-TIEN-31. Chỉ là lõi **tính**; bản ghi yêu cầu hoàn phí, duyệt, phiếu chi (PC), sổ số dư khách hàng làm sau khi ticket (#18) gộp. Đề xuất đầy đủ: `docs/de-xuat/chuyen-lop-hoan-phi.md`.

## Hàm nội bộ (không cấp cho giao diện)

| Hàm                                              | Việc                                                         | Luật                 |
| ------------------------------------------------ | ------------------------------------------------------------ | -------------------- |
| `compute_refund(ghi danh, loại, giờ hoàn)`       | Tính tiền hoàn, trả jsonb; không ghi gì                      | R-TIEN-28, R-TIEN-31 |

- `TOAN_BO`: hoàn = (tiền đã đóng của dòng − giờ đã học × **giá gốc** − tiền gốc các lần hoàn đã duyệt hoặc đã chi, migration 450) − phí xử lý trên số còn lại. Giờ tặng không hoàn.
- `MOT_PHAN`: hoàn = giờ hoàn × **giá sau chiết khấu** (thành tiền dòng ÷ giờ mua) − phí xử lý trên số đó; giờ hoàn không quá giờ còn lại trừ giờ tặng đã cấp (migration 450).
- Phí = tham số `refund_processing_fee_percent` (ghi đè theo cơ sở được), làm tròn đồng. Nơi gọi chụp lại kết quả vào bản ghi, không tính lại sau.
- Lỗi: `HMT_HOAN_PHI_KHONG_CO_DON` (ghi danh nạp cũ không có giá), `HMT_HOAN_PHI_LOAI_SAI`, `HMT_HOAN_PHI_GIO_SAI`, `HMT_HOAN_PHI_KHONG_CON_TIEN`.

## Chỗ tự chọn (chờ Chat xác nhận)

- Phí của hoàn một phần tính trên `giờ hoàn × giá sau chiết khấu` (R-TIEN-31 không nói rõ số nền).
- «Giờ đã học» = tổng giờ trừ theo buổi Done của ghi danh (giờ tặng đã dùng nằm trong đó).
