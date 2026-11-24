---
id: tc2
ten: Duyệt phiếu thu: bước quản lý
vai: [truong-co-so]
phan_he: thu-chi
ma_man: [TC-17, TC-02]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Duyệt phiếu thu: bước quản lý

**Làm xong bạn có:** phiếu thu chuyển sang «Chờ kế toán», hoặc về Nháp kèm lý do từ chối.
**Ai làm:** người duyệt bước quản lý: quản lý trực tiếp của người lập phiếu; người lập chưa có quản lý trực tiếp thì Trưởng cơ sở (cơ sở nhiều Trưởng cơ sở thì ai duyệt trước có hiệu lực). **Màn:** Phiếu thu → «Chờ tôi duyệt».

## Trước khi bắt đầu, kiểm
- [ ] Phiếu hiện ở «Việc chờ tôi duyệt» của bạn (tình trạng «Đã gửi»).
- [ ] Bạn **không phải người lập** phiếu này.

## Cần nhớ
- Bước quản lý và bước Kế toán là **hai người khác nhau**; Admin không duyệt thay Kế toán.
- Bạn duyệt là xác nhận phiếu **ghi đúng** số tiền, đúng đơn, đúng phần chia. Việc đối chiếu sao kê là của Kế toán.

## Các bước
1. Vào **Phiếu thu**, lọc **«Chờ tôi duyệt»**, mở phiếu. [CHƯA CHỤP: chờ tài khoản staging]
2. Kiểm «Số tiền», chứng từ đính kèm, «Chia tiền vào dòng đơn» khớp đơn. [CHƯA CHỤP]
3. Đồng ý: duyệt. *Bạn thấy:* phiếu sang «Chờ kế toán». [CHƯA CHỤP]
4. Không đồng ý: bấm **«Từ chối phiếu thu»**, ghi lý do. *Bạn thấy:* phiếu về Nháp, lý do ở dòng thời gian. [CHƯA CHỤP]

## Sau bước này
- **Ai làm tiếp:** Kế toán duyệt bước cuối (bài «Kế toán duyệt phiếu thu»). Bị từ chối thì người lập sửa và trình lại.
- **Bạn xem ở đâu:** **Phiếu thu**, bản ghi phiếu, dòng thời gian.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Duyệt nhầm, Kế toán chưa duyệt | báo Kế toán «Từ chối phiếu thu»; phiếu về Nháp, người lập trình lại |
| Từ chối nhầm | báo người lập trình lại |
| Cần đổi người duyệt (người duyệt vắng) | Admin dùng «Chuyển người duyệt» (Admin chỉ chuyển, không duyệt thay bước quản lý) |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì |
|---|---|---|
| `HMT_KHONG_CO_QUYEN` | bạn không phải người duyệt của phiếu này | chuyển đúng người, hoặc nhờ Admin chuyển người duyệt |
| Người duyệt hai bước trùng nhau | một người không duyệt cả hai bước | nhờ người khác duyệt bước còn lại |

## Hỏi đáp
- **Phiếu không có trong hàng chờ của tôi?** Kiểm ô «Cơ sở» và người lập có quản lý trực tiếp là ai.
- **Tôi có sửa số tiền được không?** Không; từ chối để người lập sửa.

## Tập trên dữ liệu mẫu
- **Cần:** 3 tài khoản (người lập, bạn, Kế toán).
- **Dùng:** phiếu vừa trình ở bài «Tạo phiếu thu từ đơn hàng». Bộ mẫu chỉ có phiếu thu Nháp: tạo phiếu rồi trình để có phiếu chờ duyệt.
