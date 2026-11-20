# Xem trước chia tiền phiếu thu (TC-17, migration 578)

Anh Trường chốt 20/11/2026 (Chat 20:38): luật lệch canvas thì theo canvas. Canvas 9933 (`TC17_*`, `TC02_*`) vẽ bảng «Chia tiền vào dòng đơn» có cột Lớp, Giờ cấp, nhãn «Dồn trước» và hiện từ bước Đã trình.

| Hàm | Làm gì | Ai gọi | Luật |
|---|---|---|---|
| `app.compute_money_in_allocation(đơn, số tiền, dòng cấn)` | Tính tiền chia về các dòng đơn, không ghi. Hàm trong, không cấp cho người dùng | `allocate_money_in`, `preview_receipt_allocation` | R-TIEN-22, R-TIEN-23 |
| `app.allocate_money_in(...)` | Ghi tiền chia vào `money_in_allocation` lúc Kế toán duyệt; nay gọi hàm tính chung nên khớp bản xem trước | duyệt phiếu thu | R-TIEN-22, R-TIEN-23 |
| `app.preview_receipt_allocation(phiếu)` | Chỉ đọc. Trả `{actual, note, lines[]}`: mỗi dòng có học sinh, sản phẩm, thành tiền, tiền chia, giờ cấp, giờ dòng, cờ dồn trước | người xem được phiếu thu theo phạm vi cơ sở | R-TIEN-21, R-TIEN-23, R-TIEN-24 |

Giờ cấp của một dòng cho phiếu này = số giờ dòng × tiền chia ÷ thành tiền dòng, làm tròn 2 chữ số (R-TIEN-21). Giờ tặng chỉ cấp khi đơn thu đủ (R-TIEN-24), nên bản xem trước chỉ nói về giờ mua.
Phiếu Nháp, Đã gửi, Chờ kế toán: tính trước (`actual = false`). Đã duyệt: đọc tiền đã chia thật (`actual = true`). Huỷ và thu nợ đầu kỳ không đơn: không có dòng. Số tiền vượt phần còn nhận được: không báo lỗi, `lines` rỗng và `note` giải thích.
Bài pgTAP `578_c87_xem_truoc_chia_tien.test.sql` kiểm bản xem trước khớp tiền ghi thật sau khi duyệt.
