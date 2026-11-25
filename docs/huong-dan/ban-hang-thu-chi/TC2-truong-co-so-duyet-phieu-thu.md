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
**Ai làm:** người duyệt bước quản lý: quản lý trực tiếp của người lập phiếu; người lập chưa có quản lý trực tiếp thì Trưởng cơ sở (cơ sở nhiều Trưởng cơ sở thì ai duyệt trước có hiệu lực). **Màn:** Việc chờ tôi duyệt.

> Video: [VIDEO: tc2]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

## Trước khi bắt đầu, kiểm
- [ ] Phiếu hiện ở «Việc chờ tôi duyệt» của bạn (tình trạng «Đã gửi»); mở phiếu thấy nút «Duyệt (chuyển Kế toán)».
- [ ] Bạn **không phải người lập** phiếu này.

## Cần nhớ
- Bước quản lý và bước Kế toán là **hai người khác nhau**; Admin không duyệt thay Kế toán.
- Bạn duyệt là xác nhận phiếu **ghi đúng** số tiền, đúng đơn, đúng phần chia. Việc đối chiếu sao kê là của Kế toán.

## Các bước
1. Vào **Việc chờ tôi duyệt**, bấm mã phiếu «PT-…» (hoặc **Phiếu thu**, lọc «Chờ tôi duyệt»). [ẢNH: tc2-b1]
2. Mở phiếu: thanh trên có hai nút **«Duyệt (chuyển Kế toán)»** và **«Từ chối»**. Kiểm «Số tiền», «Hình thức», «Ngày nhận», «Người lập», đơn hàng và tab «Chia về các dòng đơn». [ẢNH: tc2-b2]
3. Đồng ý: bấm **«Duyệt (chuyển Kế toán)»**. Hộp «Duyệt phiếu thu … (quản lý)» tóm tắt phiếu; tích ô **«Đã kiểm tra số tiền, hình thức nhận và đơn hàng của phiếu»** rồi bấm **«Xác nhận duyệt»** («Quay lại» để thôi). [ẢNH: tc2-b3]
   *Bạn thấy:* thông báo «Đã duyệt, chuyển Kế toán.», tình trạng **Chờ kế toán**, dòng thời gian ghi «Quản lý duyệt». Chưa sinh khoản tiền vào, chưa cấp giờ: chỉ khi Kế toán duyệt. [ẢNH: tc2-b4]
4. Không đồng ý: bấm **«Từ chối»** (ở thanh trên hoặc nút «Từ chối…» trong hộp duyệt) và ghi lý do. *Bạn thấy:* phiếu về Nháp, lý do ở dòng thời gian.

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
