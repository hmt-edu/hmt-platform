# D-23-26 · Xem trước tiền trên phiếu Dừng học, Hoàn học phí (migration 632)

Người duyệt (Trưởng cơ sở, Kế toán) thấy số tiền sẽ hoàn hoặc sẽ thành số dư ngay trên phiếu, trước khi duyệt.

| Hàm | Ai gọi | Việc |
|---|---|---|
| `app.preview_stop_task_money(p_task_id)` | Ticket · Xem theo cơ sở của phiếu | Chỉ đọc. Phiếu Dừng học: số dư giữ (`compute_stop_balance`: giờ mua còn lại × giá sau chiết khấu, giờ tặng huỷ) và số hoàn toàn bộ (`compute_refund` TOAN_BO), kèm cách phiếu đã chọn. Phiếu Hoàn học phí: số hoàn theo loại và giờ trong phiếu. Không tính được số hoàn thì trả `refund_error`, không chặn xem phiếu. |

Đề xuất ngắn (theo thẻ): dùng đúng hai hàm tính lúc thực hiện nên số xem trước và số ghi sổ cùng nguồn; giao diện không tính tiền. Số tính lại theo dữ liệu hôm nay; lúc thực hiện hệ thống tính lại và dùng số lúc đó (R-TIEN-28, R-TIEN-33). Hiện ở màn chi tiết phiếu (CS-06) khi phiếu chưa thực hiện, nên cả người duyệt hai cấp đều thấy. Không thêm bảng, cột, chỉ mục.
