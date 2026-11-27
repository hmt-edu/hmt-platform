---
id: bh4
ten: Trình và duyệt, từ chối đơn hàng
vai: [truong-co-so, tu-van, cskh]
phan_he: ban-hang
ma_man: [BH-07]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Trình và duyệt, từ chối đơn hàng

**Làm xong bạn có:** đơn «Đã duyệt» (hoặc đơn về Nháp kèm lý do từ chối).
**Ai làm:** người lập **trình**; **người duyệt** là quản lý trực tiếp của người lập. Người lập chưa có quản lý trực tiếp thì **Trưởng cơ sở** duyệt (cơ sở nhiều Trưởng cơ sở thì ai duyệt trước có hiệu lực). Trưởng cơ sở lập đơn thì đơn tự qua bước này. Admin duyệt thay khi người duyệt vắng. Cơ sở chưa có Trưởng cơ sở nào thì hệ thống chặn và báo rõ.

> Video: [VIDEO: bh4]
> Video: [VIDEO: bh4b]
> Không xem được video? Làm theo các bước dưới, đủ để làm.

## Trước khi bắt đầu, kiểm
- [ ] Bạn là người duyệt của đơn này: đơn hiện ở **Việc chờ tôi duyệt** của bạn.
- [ ] Đã mở đơn «Đã trình» và đọc đủ: dòng đơn, học sinh, lớp, ngày vào lớp, chiết khấu, điều khoản thanh toán.

## Cần nhớ
- Người lập **không tự duyệt** đơn của mình (trừ Trưởng cơ sở lập đơn).
- Dòng vượt trần chiết khấu 20% được đánh dấu để bạn cân nhắc: chỉ cảnh báo, không chặn.

## Các bước (người duyệt)
1. Vào **Việc chờ tôi duyệt** (hoặc **Đơn hàng**, lọc «Chờ tôi duyệt»), bấm mã đơn để mở. *Bạn thấy:* đơn tình trạng **Đã trình**, thanh trên có hai nút **«Duyệt»** và **«Từ chối»**. [ẢNH: bh4-b1] [ẢNH: bh4-b2]
2. Đọc từng dòng đơn (học sinh, sản phẩm, số giờ, chiết khấu, lớp, ngày vào lớp) và điều khoản thanh toán; dòng vượt trần chiết khấu có cảnh báo vàng.
3. Đồng ý: bấm **«Duyệt»**. Hộp «Duyệt đơn hàng» tóm tắt đơn và nhắc «Duyệt thì đơn tự khoá: không sửa dòng, giá, lớp, ngày vào nữa». Bấm **«Duyệt»** trong hộp để xác nhận. [ẢNH: bh4-b3]
   *Bạn thấy:* thông báo «Đã duyệt đơn hàng.», tình trạng **Đã duyệt · khoá**, dòng thời gian ghi «Duyệt đơn», xuất hiện nút «Tạo phiếu thu». [ẢNH: bh4-b4]
4. Chưa đồng ý: bấm **«Từ chối»** (ở thanh trên hoặc trong hộp Duyệt), chọn lý do (lý do «Khác» phải ghi chú). *Bạn thấy:* đơn về Nháp, lý do nằm ở dòng thời gian.

## Sau bước này
- **Ai làm tiếp:** người lập lập **phiếu thu** khi đơn «Đã duyệt»; bị từ chối thì sửa rồi trình lại.
- **Bạn xem ở đâu:** **Đơn hàng**, bản ghi đơn, dòng thời gian bên phải.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Duyệt nhầm, chưa có phiếu thu | người duyệt đã chốt vào «Hành động» → «Huỷ đơn», chọn lý do |
| Duyệt nhầm, đã có phiếu thu | không huỷ đơn; nhờ CSKH tạo ticket hoàn tiền |
| Từ chối nhầm | báo người lập sửa và trình lại |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì |
|---|---|---|
| `HMT_KHONG_CO_QUYEN` | bạn không phải người duyệt đã chốt lúc trình | chuyển cho đúng người, hoặc nhờ Admin duyệt thay |
| `HMT_KHONG_CO_QUAN_LY` | cơ sở chưa có Trưởng cơ sở để duyệt | báo Admin bổ sung quản lý |

## Hỏi đáp
- **Đơn của tôi không thấy trong hàng chờ?** Kiểm «Cơ sở» ở thanh trên và đơn có đang «Đã trình» không.
- **Ai duyệt đơn của Trưởng cơ sở?** Không ai: đơn tự qua bước duyệt, lịch sử ghi «tự duyệt».

## Tập trên dữ liệu mẫu
- **Cần:** 2 tài khoản (người lập, người duyệt).
- **Dùng:** đơn mẫu vừa được trình (làm bài «Lập đơn hàng» trước).
