---
id: tc8
ten: Đối soát thu tiền với sao kê
vai: [ke-toan]
phan_he: thu-chi
ma_man: [TC-15]
uu_tien: P2
cap_nhat: 2026-11-24
---

# Đối soát thu tiền với sao kê

**Làm xong bạn có:** những phiếu thu bạn đã thấy trên sao kê ngân hàng (hoặc đã đếm tiền mặt) được đánh dấu **«Đã khớp»**, phần còn lại là «Chưa khớp» để theo dõi.
**Ai làm:** Kế toán (và Admin). **Màn:** Kế toán → **Đối soát thu tiền**.

## Trước khi bắt đầu, kiểm
- [ ] Bạn có sao kê ngân hàng của ngày cần đối soát (và sổ tiền mặt nếu có thu tiền mặt).
- [ ] Các phiếu thu cần đối soát đã được duyệt: màn này chỉ liệt kê phiếu thu **«Đã duyệt»**.

## Cần nhớ
- Đánh dấu khớp **không đổi tiền, không đổi sổ**. Chỉ ghi nhận bạn đã đối chiếu với sao kê. Làm nhầm thì bỏ đánh dấu được.
- Màn mở sẵn với bộ lọc «Thời gian: Tuần này». Muốn xem ngày khác thì đổi bộ lọc.
- Người không phải Kế toán hoặc Admin thấy câu «Bạn không có quyền xem đối soát thu tiền».

## Các bước
1. Mở **Đối soát thu tiền**. [ẢNH: tc8-b1]
   *Bạn thấy:* bốn ô tổng hợp: «Tổng tiền thu», «Đã khớp sao kê», «Chưa khớp», «Số phiếu chưa khớp»; bên dưới là bảng phiếu thu (Phiếu thu, Ngày, Cơ sở thu, Người nhận tiền, Phụ huynh, Hình thức, Tài khoản nhận, Mã giao dịch, Số tiền, Sao kê).
2. Lọc cho gọn: bấm **Filters** để lọc theo «Sao kê» (Đã khớp, Chưa khớp), «Hình thức», «Tài khoản nhận», «Cơ sở»; hoặc đổi «Thời gian». Đối chiếu từng dòng với sao kê: **mã giao dịch** là chỗ dễ khớp nhất.
3. Tích ô chọn ở đầu dòng cho các phiếu **đã thấy trên sao kê**, rồi bấm **«Đánh dấu đã khớp»**. [ẢNH: tc8-b2]
4. Trong hộp «Đánh dấu đã khớp sao kê» (ghi «N phiếu thu đã chọn»): nếu muốn ghi luôn tài khoản nhận thì chọn «Tài khoản nhận (tuỳ chọn)», để «Giữ nguyên» nếu không. Bấm **«Đánh dấu đã khớp»**. [ẢNH: tc8-b3]
   *Bạn thấy:* thông báo «Đã đánh dấu khớp N phiếu.»; «Đã khớp sao kê» tăng, «Chưa khớp» và «Số phiếu chưa khớp» giảm. [ẢNH: tc8-b4]

## Sau bước này
- **Ai làm tiếp:** phiếu «Chưa khớp» còn lại: hỏi người nhận tiền (cột «Người nhận tiền») hoặc ngân hàng; khi thấy trên sao kê thì quay lại đánh dấu.
- **Bạn xem ở đâu:** chính màn này, lọc «Sao kê: Chưa khớp» để thấy phần cần theo dõi.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Đánh dấu nhầm phiếu | tích lại phiếu đó, bấm **«Bỏ đánh dấu khớp»**, xác nhận «Bỏ đánh dấu»; thông báo «Đã bỏ đánh dấu N phiếu.» |
| Gán nhầm tài khoản nhận | tích phiếu, bấm «Đánh dấu đã khớp» lần nữa và chọn đúng tài khoản |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì |
|---|---|---|
| Bạn không có quyền xem đối soát thu tiền | tài khoản không phải Kế toán hoặc Admin | dùng tài khoản Kế toán, hoặc nhờ quản trị viên |
| Không có phiếu thu nào trong khoảng đã lọc | khoảng thời gian chưa có phiếu đã duyệt | đổi «Thời gian» hoặc bỏ bớt bộ lọc |
| Báo lỗi trong hộp khi xác nhận | mất mạng, hoặc không còn quyền | đọc câu báo, bấm lại; không được thì báo quản lý |

## Hỏi đáp
- **Phiếu Nháp hoặc chưa duyệt có trong danh sách không?** Không. Chỉ phiếu «Đã duyệt».
- **Đánh dấu khớp có làm thay đổi số dư hay khoản tiền vào không?** Không, đây chỉ là ghi dấu đối soát.
- **Có xuất danh sách ra Excel không?** Màn hiện chưa có nút xuất; dùng bảng trên màn để đối chiếu.
- **Một phiếu có thể đánh dấu cả loạt không?** Được, tích nhiều dòng rồi bấm một lần.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản Kế toán.
- **Dùng:** phiếu «Đã duyệt» «[MẪU] …» trong «Dữ liệu mẫu của tôi»; đánh dấu khớp rồi **bỏ đánh dấu** để trả lại như cũ.
