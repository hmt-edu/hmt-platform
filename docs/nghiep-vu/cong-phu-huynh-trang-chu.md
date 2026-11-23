# Cổng Phụ huynh: trang chủ PH-01 (migration 646)

Hàm `app.ph_home()`: một lần gọi cho cả màn Trang chủ, chỉ xem.

- Ai gọi: phụ huynh đăng nhập `/ph` (các hồ sơ cùng số điện thoại, một tài khoản thấy nhiều con). Nhân viên, tài khoản khoá, phiên bị thu hồi: danh sách rỗng.
- Kết quả: `children` (id, tên, mã lớp đang học, giờ còn, giờ còn thấp, ngày hết dự kiến, buổi gần nhất, số nhận xét mới trong 14 ngày), `attention` (giờ còn thấp; đề nghị, khiếu nại chưa đóng kèm bước 1 đến 3).
- Luật: R-GD-13 (ngưỡng giờ còn thấp, dùng chung công thức `ph_hours_orders`); R-DD-02 (trạng thái buổi theo ô giáo viên); công tắc Học tập theo cơ sở; không lộ ghi chú nội bộ, người xử lý.
- Kiểm thử: `supabase/tests/database/646_ph_trang_chu.test.sql`.
