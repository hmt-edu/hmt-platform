# CS-10 Chuyển phí: xem trước bảng tính và kiểm đơn nhận (migration 621)

Code D, 23/11/2026, thẻ D-23-08 (Chat chốt 02:52). Luật: R-TIEN-32, R-TIEN-33, R-GD-16, R-V2-24. Khung: `CSN06d_chuyen_phi_em`, `_gia`, `_phu_huynh`.

| Hàm | Ai | Việc |
| --- | --- | --- |
| `compute_fee_transfer(ghi danh, phụ huynh nhận, đơn nhận)` | Nội bộ | Giờ mua, giờ đã học, giá sau chiết khấu, đã đóng, giá trị chuyển, giờ tặng huỷ; có đơn nhận thì thêm giá trị đơn và phụ huynh đóng thêm. Lỗi `HMT_CHUYEN_PHI_DON_SAI` (đơn không của phụ huynh nhận, khác cơ sở hoặc đã huỷ), `HMT_CHUYEN_PHI_AM` (giá trị chuyển lớn hơn giá trị đơn nhận). |
| `preview_fee_transfer(...)` | Ticket · Sửa | Bọc hàm trên cho giao diện. |
| `list_fee_transfer_orders(ghi danh, phụ huynh nhận)` | Ticket · Sửa | Đơn chọn làm đơn nhận. |
| `create_ticket_task` (bản 618) | như cũ | Phiếu Chuyển phí kiểm `kind_code` (`SANG_MON`, `SANG_GOI`, `SANG_ANH_CHI_EM`) và `order_id` (nếu có). |

Chỗ cần biết: đơn nhận chỉ để tham khảo. **Thực hiện vẫn như migration 567** (chuyển số dư cho phụ huynh nhận), CHƯA trừ vào đơn và chưa kiểm lại đơn nhận lúc thực hiện. Câu báo lỗi «Giá trị chuyển lớn hơn giá trị đơn nhận…» là đề xuất, chờ anh xem.
