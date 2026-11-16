-- PR-3 Nạp dữ liệu (migration 164): ba hàm nạp hàng loạt có statement_timeout riêng, các hàm khác giữ giới hạn của vai trò. Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select ok('statement_timeout=120s' = any (coalesce((select proconfig from pg_proc where oid = 'app.import_records(text,jsonb,boolean,text)'::regprocedure), '{}')),
          'app.import_records có statement_timeout 120 giây (lô 1000 đến 5000 dòng không bị cắt ở 8 giây)');
select ok('statement_timeout=120s' = any (coalesce((select proconfig from pg_proc where oid = 'app.import_training_records(text,jsonb,boolean,text)'::regprocedure), '{}')),
          'app.import_training_records có statement_timeout 120 giây');
select ok('statement_timeout=120s' = any (coalesce((select proconfig from pg_proc where oid = 'app.import_leads(jsonb,boolean,jsonb,text)'::regprocedure), '{}')),
          'app.import_leads có statement_timeout 120 giây');
select ok(not exists (select from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                       where n.nspname = 'app' and p.proname not in ('import_records', 'import_training_records', 'import_leads')
                         and exists (select from unnest(coalesce(p.proconfig, '{}')) c where c like 'statement_timeout=120s')),
          'Chỉ ba hàm nạp có giới hạn 120 giây, hàm khác không bị nới');
select is((select rolconfig from pg_roles where rolname = 'authenticated') @> array['statement_timeout=8s'], true,
          'Vai trò authenticated vẫn giữ giới hạn 8 giây (không nới cho mọi hàm)');
select is(has_function_privilege('anon', 'app.import_records(text,jsonb,boolean,text)', 'execute'), false, 'Quyền gọi không đổi: anon vẫn không gọi được hàm nạp');

select * from finish();
rollback;
