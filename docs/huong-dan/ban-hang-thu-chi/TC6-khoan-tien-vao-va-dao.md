---
id: tc6
ten: Khoản tiền vào (sổ thu tiền) và hoàn tác khoản
vai: [ke-toan, truong-co-so]
phan_he: thu-chi
ma_man: [TC-08, TC-09]
uu_tien: P1
cap_nhat: 2026-11-24
---

# Khoản tiền vào và hoàn tác khoản

**Làm xong bạn có:** biết tiền đã vào những khoản nào; một khoản sai được hoàn tác bằng khoản âm, không xoá.
**Ai làm:** Kế toán, Trưởng cơ sở xem; hoàn tác do người có quyền (không thấy nút là không có quyền). **Màn:** **Khoản tiền vào**.

## Cần nhớ
- Sổ này **chỉ đọc**: khoản tiền vào do hệ thống tự sinh khi phiếu thu được duyệt. Không ai tạo, sửa hay xoá tay.
- Sửa sai bằng **«Hoàn tác»**: hệ thống thêm một khoản **âm** trỏ về khoản gốc, khoản gốc giữ nguyên và hiện «Đã hoàn tác». Không hoàn tác được hai lần.
- **Bắt buộc chọn lý do hoàn tác**; lý do «Khác» phải ghi chú.
- Giờ đã cấp được **tính lại theo số tiền còn lại**: hoàn tác có thể làm đơn thiếu cọc.

## Các bước
1. Vào **Khoản tiền vào**: các cột «Cơ sở», «Phiếu thu», «Đơn hàng», «Phụ huynh», «Số tiền (đ)», «Ngày», «Loại»… Tìm khoản bằng ô tìm kiếm hoặc bộ lọc; mã khoản có dạng `KTV-…`. [ẢNH: tc6-b1]
2. Cột **«Hoàn tác»** có thể đang ẩn: bấm **«Cột»** và bật «Hoàn tác». Ở dòng khoản sai bấm **«Hoàn tác khoản tiền»**. [ẢNH: tc6-b2]
3. Hộp «Hoàn tác khoản tiền» nêu mã khoản và số tiền. Chọn lý do (ghi chú nếu lý do «Khác»), bấm **«Hoàn tác»** (hoặc «Giữ nguyên» để thôi). *Bạn thấy:* «Đã hoàn tác khoản tiền.»; có thêm một dòng «Khoản đảo âm»; khoản gốc hiện «Đã hoàn tác».

**Không thấy nút «Hoàn tác khoản tiền»?** Tính năng này **tắt mặc định** theo cơ sở (tham số «Cho phép hoàn tác khoản tiền vào»): báo Trưởng cơ sở hoặc Admin bật. Nút cũng chỉ hiện với Kế toán và với khoản chưa hoàn tác. (Bản thử nghiệm đang tắt nên bài chưa có ảnh hộp hoàn tác.)

⚠ **Không xoá được khoản đã hoàn tác.** Muốn ghi lại số đúng thì tạo phiếu thu mới.

## Sau bước này
- **Ai làm tiếp:** người lập phiếu thu tạo phiếu đúng nếu cần; CSKH xem lại ghi danh nếu tiền còn lại không đủ cọc.
- **Bạn xem ở đâu:** **Khoản tiền vào**; **Công nợ** cập nhật còn nợ.

## Lỗi hay gặp
| Thấy câu gì | Nghĩa là | Làm gì |
|---|---|---|
| Không thấy nút «Hoàn tác» | khoản đã hoàn tác, hoặc bạn không có quyền | báo Kế toán |
| Thông báo cơ sở chưa bật tính năng | phân hệ tắt cho cơ sở này | báo Trưởng cơ sở hoặc Admin |

## Hỏi đáp
- **Hoàn tác có trả tiền mặt cho phụ huynh không?** Không. Hoàn tiền thật đi theo ticket hoàn tiền và phiếu chi (bài «Phiếu chi»).
- **Hoàn tác nhầm?** Khoản gốc không khôi phục được: tạo phiếu thu mới.

## Tập trên dữ liệu mẫu
- **Cần:** tài khoản Kế toán. Bộ mẫu chưa có khoản tiền vào: `[CẦN BỔ SUNG]`; tạo bằng cách duyệt phiếu thu mẫu (bài «Kế toán duyệt phiếu thu»).
