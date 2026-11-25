---
id: tc1
ten: Tạo phiếu thu từ đơn hàng (đợt, hạn, hình thức)
vai: [tu-van, cskh]
phan_he: thu-chi
ma_man: [TC-01, TC-02, TC-03]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Tạo phiếu thu từ đơn hàng

**Làm xong bạn có:** một phiếu thu đã gửi quản lý, ghi đúng khoản phụ huynh đã đóng.
**Ai làm:** Tư vấn tuyển sinh, CSKH có quyền lập phiếu thu. **Màn:** Đơn hàng → bản ghi đơn «Đã duyệt» → «Tạo phiếu thu».

> Video: [VIDEO: tc1]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

## Trước khi bắt đầu, kiểm
- [ ] Đơn đang **«Đã duyệt»** (nút «Tạo phiếu thu» mờ nếu chưa).
- [ ] Bạn đã nhận tiền thật (và có mã giao dịch nếu chuyển khoản).
- [ ] Bạn biết khoản này thuộc **đợt** nào của điều khoản thanh toán (xem tab «Thanh toán» của đơn: đợt, hạn đóng, còn phải thu).

## Cần nhớ
- Phiếu thu đi **hai bước duyệt**: quản lý, rồi Kế toán. Hai bước do **hai người khác nhau**, và bạn không duyệt phiếu của chính mình.
- Số tiền không được vượt phần còn phải thu của đơn.
- Khi Kế toán duyệt, hệ thống tự sinh **khoản tiền vào** và, nếu tổng tiền vào đạt cọc tối thiểu, sinh **ghi danh**. Bạn không tạo tay hai thứ này.

## Các bước
1. Ở đơn «Đã duyệt» bấm **«Tạo phiếu thu»** (cạnh nút «Cho học trước»). [ẢNH: tc1-b1]
2. Ở hộp «Tạo phiếu thu» (ghi rõ «Đơn DH-…»): «Số tiền» đã gợi ý sẵn theo đợt kế tiếp của điều khoản thanh toán (ví dụ đợt 1 là 880.000 đ), bạn sửa lại đúng số phụ huynh thật sự đóng. Chọn «Hình thức» (Tiền mặt, Chuyển khoản, Quẹt thẻ), bấm **«Tạo phiếu nháp»**. [ẢNH: tc1-b2]
   *Bạn thấy:* thông báo «Đã tạo phiếu thu nháp PT-…», trang phiếu thu tình trạng **Nháp**.
3. Trong phiếu, kiểm và điền: «Ngày nhận», «Mã giao dịch» (nếu chuyển khoản), «Người nhận tiền», «Cơ sở thu tiền», «Tài khoản nhận» (bấm **Sửa** nếu cần đổi). «Chia tiền vào dòng đơn» để trống thì hệ thống chia theo tỉ lệ giữa các dòng đơn; muốn dồn vào dòng nào thì chọn dòng đó. [ẢNH: tc1-b3]
4. Bấm **«Trình quản lý»**. Cạnh nút có dòng «Người duyệt: …» cho biết ai sẽ duyệt. [ẢNH: tc1-b4]
   *Bạn thấy:* tình trạng thành **Đã gửi**, dòng «Đã trình, chờ quản lý duyệt. Trong lúc chờ không sửa được; còn Huỷ được khi phiếu chưa duyệt.» [ẢNH: tc1-b5]

Ở CS5, bạn **không đưa biên nhận in cho phụ huynh** ở bước này; nút «In biên nhận» chỉ dùng khi quản lý cơ sở yêu cầu.

## Sau bước này
- **Ai làm tiếp:** quản lý duyệt (bài «Duyệt phiếu thu: bước quản lý»), rồi Kế toán (bài «Kế toán duyệt phiếu thu»).
- **Bạn xem ở đâu:** **Phiếu thu**, lọc theo tình trạng.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Phiếu còn Nháp | sửa thẳng, hoặc **«Huỷ phiếu thu»** (có lý do) |
| Bị quản lý từ chối | phiếu về Nháp: sửa theo lý do, trình lại |
| **Bị Kế toán từ chối** | phiếu về Nháp; trình lại thì **đi lại từ bước quản lý** |
| Phiếu đã duyệt | không sửa; nhờ Kế toán hoàn tác khoản tiền vào (bài «Khoản tiền vào và hoàn tác») |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì |
|---|---|---|
| Báo ở ô «Số tiền» | vượt phần còn phải thu | nhập lại số ≤ còn phải thu |
| Báo lỗi ở phần chia tiền | số chia vào dòng đơn không hợp lệ | để trống ô chia (hệ thống chia tỉ lệ) hoặc chỉnh lại |

## Hỏi đáp
- **Vì sao chưa có ghi danh sau khi kế toán duyệt?** Tổng tiền đã vào chưa đạt cọc tối thiểu; thu thêm phiếu nữa.
- **Phụ huynh đóng nhiều đợt?** Mỗi lần nhận tiền lập một phiếu thu.

## Tập trên dữ liệu mẫu
- **Cần:** 3 tài khoản: bạn, quản lý duyệt, Kế toán.
- **Dùng:** đơn «Đã duyệt» «[MẪU] …» trong «Dữ liệu mẫu của tôi» (bộ mẫu có 2 đơn đã duyệt).
