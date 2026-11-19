# Hiệu năng danh sách lane E (Kho việc #11, 19/11/2026)

Đo ở máy local sau `db:reset`, `db:seed-users`, `db:seed-lon` (25.000 lead, 20.000 cơ hội, 10.000 học sinh, 15.000 phiếu kiểm tra) và `db:seed-lon-lop-buoi` (6.666 ghi danh, 10.000 buổi). Dữ liệu giả; chạy hàm qua `rpc` với claims của vai trò thật (Sale cơ sở 1, CSKH cơ sở 1), RLS bật. Thời gian là một lần gọi, mặc định 50 dòng một trang.

| Danh sách (hàm) | Điều kiện | Thời gian |
|---|---|---|
| Lead (`list_leads`) | mặc định, 25.000 dòng | 131 ms |
| Lead | tìm theo SĐT | 29 ms |
| Lead | lọc Stage C1 (10.000 dòng) | 90 ms |
| Lead | đếm nhóm Group By Stage (`lead_group_counts`) | 44 ms |
| Cơ hội (`list_opportunities`) | mặc định, 10.000 dòng | 126 ms |
| Phiếu kiểm tra (`list_student_tests`) | mặc định, 10.000 dòng | 196 ms |
| Phiếu kiểm tra | lọc trạng thái Nháp | 21 ms |
| Ghi danh (`enrollment_list`) | mặc định, 6.666 dòng | 52 ms |
| Ghi danh | tìm | 62 ms |
| Buổi (`session_list`) | mặc định, 10.000 dòng | 11 ms |
| Buổi | lọc 7 ngày | 10 ms |

Kết luận: cả năm danh sách đều dưới 200 ms trên dữ liệu lớn (mục tiêu tham chiếu dưới 1 giây). Phân trang ở máy chủ: kích thước trang kẹp theo `list_page_size_default` và `list_page_size_max`; không tải cả bảng. Không thêm chỉ mục mới.

Chưa có kế hoạch thực thi (EXPLAIN) từng câu: Supabase local không cho nạp `auto_explain` với vai `authenticated`. Nếu cần, chạy `EXPLAIN (ANALYZE, BUFFERS)` trực tiếp trên câu lõi của hàm bằng quyền chủ DB.
