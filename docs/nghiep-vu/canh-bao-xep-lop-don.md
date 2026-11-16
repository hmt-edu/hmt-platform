# Cảnh báo khi ghi danh từ đơn không xếp được lớp (migration 213)

Code D, 16/11/2026. Q1 trong `SAU-17-11.md`; Chat chốt 16/11 05:35. Luật: R-GD-06, R-GD-08, R-GD-15.

Trước đây, khi duyệt phiếu thu, `create_enrollments_for_order` kiểm lại lớp và ngày vào lớp của dòng đơn; nếu không còn hợp lệ (lớp đầy, ngày không phải buổi sắp tới, trùng giờ) thì ghi danh rơi vào **Chờ xếp lớp** mà không báo gì. Hành vi này **giữ nguyên** (không chặn thu tiền), nhưng nay có cảnh báo:

- Cột `enrollment.placement_warning_code`: mã lỗi `HMT_...` của kiểm lớp (hoặc `KHONG_XEP_DUOC`). Tự xoá khi ghi danh được xếp lớp (trigger trên `enrollment_class`).
- Sự kiện `CANH_BAO_XEP_LOP` trong lịch sử đơn (trạng thái đơn không đổi), hiện ở dòng thời gian đơn hàng là «Chưa xếp được lớp» kèm lời cảnh báo vàng.

Chưa làm: hiện cờ trên danh sách Chờ xếp lớp (GD-06) và trang ghi danh; cột đã sẵn để giao diện đọc.
