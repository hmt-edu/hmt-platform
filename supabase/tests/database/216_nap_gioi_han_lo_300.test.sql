-- PR-3 Nạp dữ liệu (migration 216): số dòng tối đa mỗi lần nạp là 300 (mỗi lần gọi dưới hạn 8 giây của vai trò authenticated). Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is((select value from app.setting_def where key = 'import_max_rows'), '300', 'import_max_rows mặc định 300 dòng mỗi lần nạp');
select ok((select value::numeric between min_value and max_value from app.setting_def where key = 'import_max_rows'), 'Giá trị vẫn trong khoảng cho phép của tham số (1 đến 5000)');
select is((select rolconfig @> array['statement_timeout=8s'] from pg_roles where rolname = 'authenticated'), true, 'Vai trò authenticated vẫn có hạn 8 giây (không nới)');
select ok(not exists (select from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                       where n.nspname = 'app' and p.proname like 'import\_%' and exists (select from unnest(coalesce(p.proconfig, '{}')) c where c like 'statement_timeout=%')),
          'Không còn hàm nạp nào đặt statement_timeout riêng (cách đó không có tác dụng với lệnh gọi từ ngoài)');

select * from finish();
rollback;
