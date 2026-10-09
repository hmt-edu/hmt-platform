-- Kiểm thử RLS và quyền cho app.system_info, app.heartbeat, public.system_status().
begin;

create extension if not exists pgtap with schema extensions;

select plan(20);

-- --- Cấu trúc: RLS bật, heartbeat không có policy -------------------------
select ok(
  (select relrowsecurity from pg_catalog.pg_class where oid = 'app.system_info'::regclass),
  'RLS bật trên app.system_info'
);
select ok(
  (select relrowsecurity from pg_catalog.pg_class where oid = 'app.heartbeat'::regclass),
  'RLS bật trên app.heartbeat'
);
select is(
  (select count(*)::int from pg_catalog.pg_policies where schemaname = 'app' and tablename = 'heartbeat'),
  0,
  'app.heartbeat không có policy nào'
);

-- --- anon -------------------------------------------------------------------
set local role anon;

select is(
  (select count(*)::int from app.system_info),
  1,
  'anon đọc được đúng 1 dòng app.system_info'
);
select throws_ok(
  $$insert into app.system_info (id, app_name, schema_version) values (2, 'x', 'x')$$,
  '42501', null, 'anon không thêm được vào app.system_info'
);
select throws_ok(
  $$update app.system_info set app_name = 'x'$$,
  '42501', null, 'anon không sửa được app.system_info'
);
select throws_ok(
  $$delete from app.system_info$$,
  '42501', null, 'anon không xoá được app.system_info'
);
select throws_ok(
  $$select * from app.heartbeat$$,
  '42501', null, 'anon không đọc được app.heartbeat'
);
select throws_ok(
  $$select app.heartbeat()$$,
  '42501', null, 'anon không gọi được app.heartbeat()'
);
select is(
  public.system_status() ->> 'app_name',
  'HMT Platform',
  'anon gọi được public.system_status()'
);

reset role;

-- --- authenticated ----------------------------------------------------------
set local role authenticated;

select is(
  (select count(*)::int from app.system_info),
  1,
  'authenticated đọc được đúng 1 dòng app.system_info'
);
select throws_ok(
  $$insert into app.system_info (id, app_name, schema_version) values (2, 'x', 'x')$$,
  '42501', null, 'authenticated không thêm được vào app.system_info'
);
select throws_ok(
  $$update app.system_info set app_name = 'x'$$,
  '42501', null, 'authenticated không sửa được app.system_info'
);
select throws_ok(
  $$delete from app.system_info$$,
  '42501', null, 'authenticated không xoá được app.system_info'
);
select throws_ok(
  $$select * from app.heartbeat$$,
  '42501', null, 'authenticated không đọc được app.heartbeat'
);
select throws_ok(
  $$select app.heartbeat()$$,
  '42501', null, 'authenticated không gọi được app.heartbeat()'
);
select is(
  public.system_status() ->> 'app_name',
  'HMT Platform',
  'authenticated gọi được public.system_status()'
);

reset role;

-- --- postgres (CI) ----------------------------------------------------------
select lives_ok(
  $$select app.heartbeat()$$,
  'postgres gọi được app.heartbeat()'
);
select is(
  (select count(*)::int from app.heartbeat),
  1,
  'app.heartbeat có đúng 1 dòng sau khi gọi'
);
select lives_ok(
  $$select app.heartbeat()$$,
  'gọi app.heartbeat() lần hai vẫn chạy (upsert)'
);

select * from finish();

rollback;
