-- R-CRM-45 (B4): mã lần nhập ghi vào lead khi nhập từ file, lọc «Lần nhập» để huỷ cả lô (migration 711).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
-- Chạy một câu lệnh với quyền chủ DB (dựng dữ liệu thử khi đang đóng vai người dùng).
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Thử Một', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@b711.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@b711.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

select pg_temp.sudo($$create temp table t (k text primary key, id uuid)$$);
select pg_temp.sudo($$grant all on t to public$$);
create function pg_temp.lid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from t where k = p_key); end $$;
grant execute on function pg_temp.lid(text) to public;

create function pg_temp.rows(p_phones text[]) returns jsonb language sql as $$
  select jsonb_agg(pg_temp.lead_data(x)) from unnest(p_phones) x;
$$;
create function pg_temp.f() returns jsonb language sql stable as $$ select jsonb_build_object('import_batch_id', pg_temp.lid('lo')) $$;
grant execute on function pg_temp.rows(text[]), pg_temp.f() to public;

select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
insert into t select 'tay', (app.create_lead(pg_temp.lead_data('0900705001'))->>'id')::uuid;
select is(app.import_leads(pg_temp.rows(array['0900705002', '0900705003']), false) ->> 'imported', '2', 'Xem trước đếm đủ dòng');
select is(app.list_lead_import_batches(), '[]'::jsonb, 'R-CRM-45: xem trước không tạo lần nhập nào');
select is(app.import_leads(pg_temp.rows(array['0900705002', '0900705003', '0900705001']), true, '{}'::jsonb, 'dot-1.csv') ->> 'imported', '2',
          'Nhập thật: hai dòng mới, một dòng trùng bị bỏ');
insert into t select 'lo', (app.list_lead_import_batches() -> 0 ->> 'id')::uuid;
select is(app.list_lead_import_batches() -> 0 ->> 'file_name', 'dot-1.csv', 'Ô chọn «Lần nhập» có tên tệp');
select is(app.list_lead_import_batches() -> 0 ->> 'active_count', '2', 'Đếm lead còn đang dùng của lần nhập');
select is((app.list_leads(pg_temp.f()) ->> 'total')::int, 2, 'R-CRM-45 đúng: lọc «Lần nhập» chỉ ra lead của lần đó');
select is((select count(*)::int from jsonb_array_elements(app.list_leads(pg_temp.f()) -> 'rows') r where r ->> 'id' = pg_temp.lid('tay')::text), 0,
          'R-CRM-45 chặn: lead tạo tay không lọt vào lô');
select is((app.export_leads(pg_temp.f()) ->> 'total')::int, 2, 'Xuất file theo cùng bộ lọc lần nhập');

-- Huỷ cả lô: dùng đường huỷ hàng loạt (R-CRM-45).
select is(app.cancel_wrong_leads(
            (select array_agg((r ->> 'id')::uuid) from jsonb_array_elements(app.list_leads(pg_temp.f()) -> 'rows') r),
            'Nhập nhầm tệp') ->> 'done', '2', 'R-CRM-45 đúng: huỷ cả lô vừa lọc');
select is(app.list_lead_import_batches() -> 0 ->> 'active_count', '0', 'Sau huỷ, lần nhập không còn lead đang dùng');
select is((app.list_leads(pg_temp.f() || '{"trash": true}'::jsonb) ->> 'total')::int, 2, 'Lô đã huỷ xem được trong «Thùng rác»');

-- Phạm vi ô chọn: cơ sở khác không thấy lần nhập; toàn hệ thống thấy.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(app.list_lead_import_batches(), '[]'::jsonb, 'R-HT-01 chặn: cơ sở khác không thấy lần nhập');
select is((app.list_leads(pg_temp.f() || '{"trash": true}'::jsonb) ->> 'total')::int, 0, 'R-HT-01 chặn: lọc mã lô không mở thêm lead cơ sở khác');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(jsonb_array_length(app.list_lead_import_batches()), 1, 'Admin thấy lần nhập của mọi cơ sở');

select * from finish();
rollback;
