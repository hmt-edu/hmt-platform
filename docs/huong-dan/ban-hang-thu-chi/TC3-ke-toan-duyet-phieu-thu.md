---
id: tc3
ten: Kế toán duyệt hoặc từ chối phiếu thu
vai: [ke-toan]
phan_he: thu-chi
ma_man: [TC-04, TC-05]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Kế toán duyệt hoặc từ chối phiếu thu

**Làm xong bạn có:** phiếu «Đã duyệt» (hệ thống tự sinh khoản tiền vào và ghi danh) hoặc phiếu về Nháp kèm lý do.
**Ai làm:** Kế toán. Admin hệ thống cũng duyệt được (mỗi lần tự duyệt hoặc duyệt cả hai bước được ghi nhật ký); vai khác không duyệt. **Màn:** **Hàng chờ kế toán duyệt**.

> Video: [VIDEO: tc3]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

## Trước khi bắt đầu, kiểm
- [ ] Bạn có sao kê ngân hàng hoặc chứng từ để đối chiếu.
- [ ] Phiếu đã qua bước quản lý (tình trạng «Chờ kế toán»). Phiếu **Thu nợ đầu kỳ** không qua quản lý: vào thẳng hàng chờ của bạn.
- [ ] Bạn không phải người đã duyệt bước quản lý của phiếu này (chỉ Admin hệ thống được duyệt cả hai bước).

## Các bước
1. Vào **Hàng chờ kế toán duyệt** (menu Bán hàng và thu chi; hoặc **Phiếu thu**, lọc «Chờ kế toán»), bấm mã phiếu. [ẢNH: tc3-b1]
2. Đối chiếu «Số tiền», «Hình thức», «Ngày nhận», «Mã giao dịch», «Tài khoản nhận», «Người nhận tiền», «Cơ sở thu tiền» với sao kê hoặc chứng từ; xem tab «Chia về các dòng đơn». [ẢNH: tc3-b2]
3. Khớp: bấm **«Duyệt phiếu thu»**. Hộp «Duyệt phiếu thu … (kế toán)» nhắc «tiền được ghi nhận và chia về các dòng đơn, sinh khoản tiền vào. Không hoàn tác bằng nút.» Tích ô **«Đã kiểm tra số tiền, hình thức nhận và đơn hàng của phiếu»** rồi bấm **«Xác nhận duyệt»**. [ẢNH: tc3-b3]
   *Bạn thấy:* thông báo «Đã duyệt phiếu thu, tiền đã ghi nhận.», tình trạng **Đã duyệt**, dòng «Tiền đã ghi nhận (KTV-…)», «Đã thu» tăng và «Còn phải thu» giảm. [ẢNH: tc3-b4]
4. Không khớp: bấm **«Từ chối»** (hoặc «Từ chối…» trong hộp) và ghi lý do. *Bạn thấy:* phiếu về Nháp.

**Ghi danh:** chỉ sinh khi tổng tiền đã vào của đơn đạt mức cọc tối thiểu (mặc định 1.000.000 đ). Phiếu 880.000 đ ở trên chưa đủ cọc («Đủ cọc: Không», ghi danh 0): cần thêm phiếu thu nữa.

## Sau bước này
- **Ai làm tiếp:** bị từ chối thì người lập sửa, trình lại và phiếu **đi lại từ bước quản lý**. Đã duyệt thì CSKH xếp lớp cho ghi danh «Chờ xếp lớp».
- **Bạn xem ở đâu:** **Khoản tiền vào**, **Phiếu thu**.

## Lỗi hay gặp
| Mã | Nghĩa là | Làm gì |
|---|---|---|
| `HMT_KHONG_CO_QUYEN` | tài khoản không phải Kế toán hay Admin hệ thống | đăng nhập đúng tài khoản |
| `HMT_CHI_KE_TOAN_DUYET_TIEN` | chỉ Kế toán hoặc Admin hệ thống duyệt tiền | nhờ Kế toán |
| Người duyệt quản lý trùng người duyệt kế toán | hệ thống chặn (trừ Admin hệ thống) | nhờ người khác duyệt |

## Hỏi đáp
- **Duyệt xong vì sao chưa có ghi danh?** Tổng tiền vào của đơn chưa đạt cọc tối thiểu.
- **Phiếu bị từ chối đi đâu?** Về Nháp; lần trình lại đi lại hai bước.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản Kế toán (ketoan.tap, đăng nhập hai bước) và phiếu đã được quản lý duyệt (làm cặp với bài «Duyệt phiếu thu: bước quản lý»).
