-- Thẻ D24 (Code D), migration 464: ba hàm danh sách đọc cỡ trang và trần từ tham số, không ghi cứng 50 và 100. Dữ liệu giả không cần.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select ok((select prosrc ~ 'list_page_size_max' and prosrc !~ 'coalesce\(p_limit, 50\)' from pg_proc where proname = 'list_expiring_enrollments' and pronamespace = 'app'::regnamespace),
          'list_expiring_enrollments đọc cỡ trang và trần từ tham số');
select ok((select prosrc ~ 'list_page_size_max' and prosrc !~ 'coalesce\(p_limit, 50\)' from pg_proc where proname = 'session_day_attendance' and pronamespace = 'app'::regnamespace),
          'session_day_attendance đọc cỡ trang và trần từ tham số');
select ok((select prosrc ~ 'list_page_size_max' and prosrc !~ 'coalesce\(p_limit, 50\)' from pg_proc where proname = 'list_curriculum_frames' and pronamespace = 'app'::regnamespace),
          'list_curriculum_frames đọc cỡ trang và trần từ tham số');
select * from finish();
rollback;
