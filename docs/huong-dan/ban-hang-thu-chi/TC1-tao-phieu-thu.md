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

## Trước khi bắt đầu, kiểm
- [ ] Đơn đang **«Đã duyệt»** (nút «Tạo phiếu thu» mờ nếu chưa).
- [ ] Bạn đã nhận tiền thật và có chứng từ (ảnh chuyển khoản, biên lai ngân hàng).
- [ ] Bạn biết khoản này thuộc **đợt** nào của điều khoản thanh toán (xem tab «Thanh toán» của đơn: đợt, hạn đóng, còn phải thu).

## Cần nhớ
- Phiếu thu đi **hai bước duyệt**: quản lý, rồi Kế toán. Hai bước do **hai người khác nhau**, và bạn không duyệt phiếu của chính mình.
- Số tiền không được vượt phần còn phải thu của đơn.
- Khi Kế toán duyệt, hệ thống tự sinh **khoản tiền vào** và, nếu tổng tiền vào đạt cọc tối thiểu, sinh **ghi danh**. Bạn không tạo tay hai thứ này.

## Các bước
1. Ở đơn «Đã duyệt» bấm **«Tạo phiếu thu»**. *Bạn thấy:* hộp «Tạo phiếu thu» có «Số tiền» (gợi ý phần còn thu) và «Hình thức». [CHƯA CHỤP: chờ tài khoản staging]
2. Nhập «Số tiền», chọn «Hình thức», bấm **«Tạo phiếu nháp»**. *Bạn thấy:* phiếu mới, tình trạng Nháp. [CHƯA CHỤP]
3. Trong phiếu điền ngày nhận, mã giao dịch, đính chứng từ; ở «Chia tiền vào dòng đơn» chia khoản vào đúng các dòng đơn (tổng chia bằng tổng phiếu). [CHƯA CHỤP]
4. Bấm **«Trình quản lý»**. *Bạn thấy:* tình trạng thành Đã gửi, phiếu chờ quản lý duyệt. [CHƯA CHỤP]

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
| Chia tiền không khớp tổng | tổng chia khác số tiền phiếu | chỉnh lại phần chia |

## Hỏi đáp
- **Vì sao chưa có ghi danh sau khi kế toán duyệt?** Tổng tiền đã vào chưa đạt cọc tối thiểu; thu thêm phiếu nữa.
- **Phụ huynh đóng nhiều đợt?** Mỗi lần nhận tiền lập một phiếu thu.

## Tập trên dữ liệu mẫu
- **Cần:** 3 tài khoản: bạn, quản lý duyệt, Kế toán.
- **Dùng:** đơn «Đã duyệt» «[MẪU] …» trong «Dữ liệu mẫu của tôi» (bộ mẫu có 2 đơn đã duyệt).
