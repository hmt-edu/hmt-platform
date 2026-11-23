-- F-23-23 (migration 631): tên hiển thị vai trò SALES là «Tư vấn tuyển sinh»; mã, cổng, phạm vi không đổi.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
select is((select name from app.role where code = 'SALES'), 'Tư vấn tuyển sinh', 'Vai trò SALES hiển thị là «Tư vấn tuyển sinh»');
select is((select default_scope || '/' || portals::text from app.role where code = 'SALES'), 'CO_SO/{crm}', 'Mã SALES, phạm vi cơ sở và cổng crm không đổi');
select is((select count(*)::int from app.role where name = 'Tuyển sinh'), 0, 'Không còn vai trò nào tên cũ «Tuyển sinh»');
select * from finish();
rollback;
