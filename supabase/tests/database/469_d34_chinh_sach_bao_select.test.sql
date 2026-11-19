-- Thẻ D34 (Code D), migration 469: hàm quyền trong chính sách RLS viết dạng (select ...) để chạy một lần mỗi câu.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Không còn chính sách nào gọi has_permission, current_user_ready, mfa_satisfied mà không bọc (select ...). Chuỗi trong pg_policies: «( SELECT app.f(...) AS f)».
select is((select count(*)::int from pg_policies
            where schemaname = 'app' and qual ~* 'app\.(has_permission|current_user_ready|mfa_satisfied)\(' and qual !~* 'select app\.(has_permission|current_user_ready|mfa_satisfied)\('), 0,
          'Mọi chính sách bọc has_permission, current_user_ready, mfa_satisfied bằng (select ...)');
select is((select count(*)::int from pg_policies where schemaname = 'app' and policyname in
            ('audit_log_read_admin', 'audited_table_read_admin', 'export_log_read', 'permission_change_read', 'permission_version_read', 'notification_read_own', 'saved_filter_read', 'branch_read')), 8,
          'Các chính sách đã sửa vẫn tồn tại');

select * from finish();
rollback;
