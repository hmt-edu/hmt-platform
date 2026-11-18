# Bật pg_cron cho lịch tự chốt, tự Done

pg_cron là phần mở rộng của Supabase để hệ thống tự chạy việc theo giờ. Gói Free có sẵn, không tốn thêm tiền. Cần bật một lần cho mỗi môi trường (staging, bản chạy thật) **trước khi** cập nhật lên bản có migration 104.

## Bước làm (staging do hmt-vanhanh, bản chạy thật do anh Trường, trên trình duyệt)

1. Mở Supabase của môi trường, vào **Database → Extensions**.
2. Tìm `pg_cron`, bật công tắc (Enable). Giữ schema mặc định.
3. Mở **SQL Editor**, chạy: `select extname from pg_extension where extname = 'pg_cron';`. Phải thấy 1 dòng.
4. Cập nhật hệ thống (migration 104 tự đăng ký hai lịch **nếu pg_cron đã bật trước lúc migration chạy**). Nếu migration báo "Chưa bật được pg_cron", hoặc môi trường đã được cập nhật lên 104 trước khi bạn bật pg_cron (ví dụ staging), làm bước 1 rồi chạy trong SQL Editor: `select app.sync_session_cron();`. Việc này do anh Trường làm tay trên trình duyệt; không có migration nào gọi hàm này thay anh (Chat chốt 10/11).
5. Kiểm: `select jobname, schedule from cron.job;` phải thấy `hmt-auto-close-sessions` (`*/30 * * * *`) và `hmt-auto-complete-sessions` (`*/15 * * * *`).

## Nếu bỏ qua bước 1

Migration 104 không dừng cập nhật: chỉ báo thông báo và bỏ qua việc đăng ký lịch. Lúc đó hệ thống chạy bình thường nhưng buổi học KHÔNG tự chốt, tự Done cho tới khi bật pg_cron và chạy `select app.sync_session_cron();`.

## Đổi chu kỳ

Đổi tham số **Chu kỳ tự Done buổi** (`session_autocomplete_minutes`) hoặc **Tự chốt buổi trước giờ học** (`session_autoclose_before_minutes`) trong Cài đặt, rồi Admin gọi lại `select app.sync_session_cron();`.

## Kiểm lại trên staging bằng workflow (không cần mở SQL Editor)

Workflow **Kiểm staging** (`.github/workflows/kiem-staging.yml`) chạy bằng tay: vào tab Actions của repo, chọn «Kiểm staging», bấm Run workflow (hoặc `gh workflow run kiem-staging.yml`). Nó KHÔNG chạy theo push hay PR và chỉ dùng secret `STAGING_DB_URL` (staging, không phải hmt-prod).

- **Kiểm chỉ đọc** (`scripts/staging/kiem-chi-doc.sql`): in migration cuối đã áp, các lịch `cron.job` (phải thấy `hmt-auto-close-sessions` và `hmt-auto-complete-sessions`, cột active là `t`) và 10 lần chạy gần nhất trong `cron.job_run_details` (tên job, trạng thái, giờ). Chưa bật pg_cron thì báo «Chưa có pg_cron» thay vì lỗi.
- **Thử trừ giờ** (`scripts/staging/thu-tru-gio.sql`): dựng dữ liệu giả trong MỘT giao dịch, chạy `app.auto_complete_sessions()`, in giờ trước và sau của bốn học sinh (Có mặt, Vắng có phép, Vắng không phép, Đi muộn) cùng một buổi học bù, rồi **hoàn tác** (cuối log có bảng «không còn dữ liệu thử» phải toàn số 0). Lệch luật thì lượt chạy báo đỏ.
- Log Actions của repo công khai: workflow chỉ in số, mã, tên job, trạng thái và dữ liệu giả; không in chuỗi kết nối.

