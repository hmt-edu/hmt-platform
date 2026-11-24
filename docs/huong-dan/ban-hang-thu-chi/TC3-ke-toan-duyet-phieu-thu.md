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
**Ai làm:** Kế toán (chỉ vai Kế toán duyệt tiền; Admin và vai khác không duyệt). **Màn:** **Chờ kế toán duyệt**.

## Trước khi bắt đầu, kiểm
- [ ] Bạn có sao kê ngân hàng hoặc chứng từ để đối chiếu.
- [ ] Phiếu đã qua bước quản lý (tình trạng «Chờ kế toán»).
- [ ] Bạn không phải người đã duyệt bước quản lý của phiếu này.

## Các bước
1. Vào **Chờ kế toán duyệt** (hoặc **Phiếu thu**, lọc «Chờ kế toán duyệt»), mở phiếu. [CHƯA CHỤP: chờ tài khoản staging]
2. Đối chiếu «Số tiền», «Hình thức», «Ngày nhận», «Mã giao dịch», «Người nhận tiền», «Cơ sở thu tiền», ảnh chứng từ; xem «Chia về các dòng đơn». [CHƯA CHỤP]
3. Khớp sao kê: bấm **«Duyệt phiếu thu»**. *Bạn thấy:* phiếu «Đã duyệt»; có khoản tiền vào mới; đủ cọc tối thiểu thì đơn sinh ghi danh. [CHƯA CHỤP]
4. Không khớp: bấm **«Từ chối phiếu thu»**, ghi lý do. *Bạn thấy:* phiếu về Nháp. [CHƯA CHỤP]

⚠ **Duyệt xong không sửa phiếu.** Sai thì hoàn tác khoản tiền vào (bài «Khoản tiền vào và hoàn tác»).

## Sau bước này
- **Ai làm tiếp:** bị từ chối thì người lập sửa, trình lại và phiếu **đi lại từ bước quản lý**. Đã duyệt thì CSKH xếp lớp cho ghi danh «Chờ xếp lớp».
- **Bạn xem ở đâu:** **Khoản tiền vào**, **Phiếu thu**.

## Lỗi hay gặp
| Mã | Nghĩa là | Làm gì |
|---|---|---|
| `HMT_KHONG_CO_QUYEN` | tài khoản không phải Kế toán | đăng nhập đúng tài khoản |
| `HMT_CHI_KE_TOAN_DUYET_TIEN` | chỉ vai Kế toán duyệt tiền | nhờ Kế toán |
| Người duyệt quản lý trùng người duyệt kế toán | hệ thống chặn | nhờ người khác duyệt |

## Hỏi đáp
- **Duyệt xong vì sao chưa có ghi danh?** Tổng tiền vào của đơn chưa đạt cọc tối thiểu.
- **Phiếu bị từ chối đi đâu?** Về Nháp; lần trình lại đi lại hai bước.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản Kế toán (ketoan.cs5) và phiếu đã được quản lý duyệt (làm cặp với bài «Duyệt phiếu thu: bước quản lý»).
