---
id: bh7
ten: Ưu đãi linh hoạt (chiết khấu tay trên dòng đơn)
vai: [tu-van, cskh, truong-co-so]
phan_he: ban-hang
ma_man: [BH-05]
uu_tien: P2
cap_nhat: 2026-11-24
---

# Ưu đãi linh hoạt: chiết khấu tay trên dòng đơn

**Làm xong bạn có:** một dòng đơn được giảm thêm một số % do chính bạn nhập, để chốt phụ huynh khi các chính sách cố định chưa đủ.
**Ai làm:** người lập đơn (Tư vấn, CSKH, Trưởng cơ sở). **Màn:** Đơn hàng → mở đơn **Nháp** → «Sửa đơn» → cột «Chiết khấu» của dòng đơn. Báo giá cũng có chip này ở dòng báo giá.

## Trước khi bắt đầu, kiểm
- [ ] Đơn đang **Nháp**. Đơn đã trình hoặc đã duyệt thì khoá, không sửa chiết khấu.
- [ ] Bạn biết **hạn mức** của dòng (mặc định **5%** mỗi dòng; Admin chỉnh trong Cài đặt, trong khoảng 0 đến 20%). Nhập quá thì không lưu được.
- [ ] Phụ huynh đã đồng ý mức giảm. Ưu đãi linh hoạt **không cần lý do**, nhưng hệ thống ghi lại ai nhập bao nhiêu % trên dòng nào.

## Cần nhớ
- Đây là chiết khấu **tự nhập %**. Các chiết khấu khác không tự nhập tự do: «Giảm khi đóng 6 tháng» có mức cố định; «Giảm thương lượng» (tối đa 10%) và «Tặng giờ học» (tối đa 4 giờ) có trần riêng.
- Tổng chiết khấu một dòng (cộng dồn các loại, giờ tặng quy ra %) **chạm trần 20%** thì chỉ cảnh báo, vẫn lưu và trình được; người duyệt sẽ xem xét kỹ.
- Giao diện **không tự tính tiền**: sau khi nhập, bấm **Lưu** thì số tiền mới được tính.

## Các bước
1. Mở đơn Nháp, bấm **«Sửa đơn»**. Ở dòng đơn cần giảm, cột «Chiết khấu», bấm nút **«+ Thêm»**. [ẢNH: bh7-b1]
2. Trong danh sách chọn **«Ưu đãi linh hoạt»**. [ẢNH: bh7-b2]
   *Bạn thấy:* một chip «Ưu đãi linh hoạt» có ô nhập số và dấu %.
3. Gõ số % vào ô trong chip (ví dụ 3). Dưới bảng có dòng «Chưa tính lại, bấm Lưu để cập nhật.»
   *Bạn thấy nếu nhập vượt hạn mức:* chữ đỏ dưới chip «Ưu đãi linh hoạt tối đa 5%» và nút **Lưu mờ**. Sửa số cho nhỏ đi thì chữ đỏ biến mất. [ẢNH: bh7-b3]
4. Bấm **«Lưu»**. [ẢNH: bh7-b4]
   *Bạn thấy:* cột «Tổng %» và «Giảm» cập nhật, «Tổng chiết khấu» và «Thành tiền» của đơn đổi theo. Dòng thời gian có «Ưu đãi linh hoạt N% ở dòng …».

## Sau bước này
- **Ai làm tiếp:** bạn bấm **«Trình duyệt»**; Trưởng cơ sở duyệt (bài «Trình và duyệt, từ chối đơn hàng»).
- **Bạn xem ở đâu:** bản ghi đơn, dòng thời gian bên phải: ai nhập bao nhiêu % trên dòng nào.

## Làm nhầm thì sao
| Nhầm gì | Sửa thế nào |
|---|---|
| Nhập sai % | bấm «Sửa đơn», gõ lại số rồi Lưu |
| Muốn bỏ ưu đãi | bấm **✕** cạnh chip rồi Lưu |
| Đơn đã trình | không sửa được; nhờ người duyệt **Từ chối** để đơn về Nháp rồi sửa |

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì |
|---|---|---|
| Ưu đãi linh hoạt tối đa N% | số bạn gõ vượt hạn mức của dòng | gõ số ≤ N, hoặc nhờ Admin xem lại hạn mức |
| Nút Lưu mờ | còn chữ đỏ ở chip, hoặc đang lưu | đọc chữ đỏ, sửa lại |

## Hỏi đáp
- **Ưu đãi linh hoạt có cộng với chiết khấu khác được không?** Được, nhưng tổng một dòng chạm trần 20% thì có cảnh báo; vẫn lưu được.
- **Sao không tự chọn được lý do?** Loại này không cần lý do. Cần ghi lý do giảm giá thì viết vào «Ghi chú» của đơn.
- **Hạn mức khác nhau giữa các cơ sở không?** Không. Hạn mức dùng chung toàn hệ thống.
- **Có dùng ở báo giá không?** Có, cùng chip «Ưu đãi linh hoạt» ở dòng báo giá.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản Tư vấn hoặc CSKH (người lập).
- **Dùng:** đơn **Nháp** «[MẪU] …» trong «Dữ liệu mẫu của tôi». Thử nhập quá hạn mức để thấy chữ đỏ, rồi sửa lại.
