-- Migration 457 (Code D): P1 của Soát ở chính sách RLS: không còn chính sách nào so với auth.uid() trần (CLAUDE.md, hiệu năng).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is((select count(*)::int from pg_policies
            where schemaname = 'app' and qual ~* 'auth\.uid\(\)' and qual !~* 'select auth\.uid\(\)'), 0,
          'Không còn chính sách RLS nào dùng auth.uid() không bọc (select ...)');
select is((select count(*)::int from pg_policies
            where schemaname = 'app' and with_check ~* 'auth\.uid\(\)' and with_check !~* 'select auth\.uid\(\)'), 0,
          'Không còn with check nào dùng auth.uid() không bọc (select ...)');
-- Nghĩa không đổi: bốn chính sách vẫn còn đủ.
select is((select count(*)::int from pg_policies where schemaname = 'app'
            and policyname in ('user_account_read', 'user_role_read', 'notification_read_own', 'saved_filter_read')), 4, 'Bốn chính sách đã sửa vẫn tồn tại');

select * from finish();
rollback;
