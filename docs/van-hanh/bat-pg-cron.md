# Bật pg_cron cho lịch tự chốt, tự Done

pg_cron là phần mở rộng của Supabase để hệ thống tự chạy việc theo giờ. Gói Free có sẵn, không tốn thêm tiền. Cần bật một lần cho mỗi môi trường (staging, bản chạy thật) **trước khi** cập nhật lên bản có migration 104.

## Bước làm (staging do TÀI KHOẢN CHỦ DỰ ÁN, bản chạy thật do anh Trường, trên trình duyệt)

1. Mở Supabase của môi trường, vào **Database → Extensions**.
2. Tìm `pg_cron`, bật công tắc (Enable). Giữ schema mặc định.
3. Mở **SQL Editor**, chạy: `select extname from pg_extension where extname = 'pg_cron';`. Phải thấy 1 dòng.
4. Cập nhật hệ thống (migration 104 tự đăng ký hai lịch **nếu pg_cron đã bật trước lúc migration chạy**). Nếu migration báo "Chưa bật được pg_cron", hoặc môi trường đã được cập nhật lên 104 trước khi bạn bật pg_cron (ví dụ staging), làm bước 1 rồi chạy trong SQL Editor: `select app.sync_session_cron();`. Việc này do anh Trường làm tay trên trình duyệt; không có migration nào gọi hàm này thay anh (Chat chốt 10/11).
5. Kiểm: `select jobname, schedule from cron.job;` phải thấy `hmt-auto-close-sessions` (`*/30 * * * *`) và `hmt-auto-complete-sessions` (`*/15 * * * *`).

## Nếu bỏ qua bước 1

Migration 104 không dừng cập nhật: chỉ báo thông báo và bỏ qua việc đăng ký lịch. Lúc đó hệ thống chạy bình thường nhưng buổi học KHÔNG tự chốt, tự Done cho tới khi bật pg_cron và chạy `select app.sync_session_cron();`.

## Đổi chu kỳ

Đổi tham số **Chu kỳ tự Done buổi** (`session_autocomplete_minutes`) hoặc **Tự chốt buổi trước giờ học** (`session_autoclose_before_minutes`) trong Cài đặt, rồi Admin gọi lại `select app.sync_session_cron();`.
