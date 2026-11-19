-- Thẻ D32 (Code D), migration 468: chỉ mục cho khoá ngoại money_in.opening_debt_student_id.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
select ok(exists (select from pg_indexes where schemaname = 'app' and tablename = 'money_in' and indexname = 'money_in_opening_student_idx'),
          'Có chỉ mục cho khoá ngoại opening_debt_student_id của khoản tiền vào');
select * from finish();
rollback;
