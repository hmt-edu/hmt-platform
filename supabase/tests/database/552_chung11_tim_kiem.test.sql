-- CHUNG-11 app.search_records (migration 552): tìm nhiều loại, không dấu, theo SĐT/mã; RLS cắt theo cơ sở. Dữ liệu giả.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh5'), ('cskh1');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@tk.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@tk.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' else 'CSKH' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHTK501', 'Phụ huynh Đặng Tìm Kiếm', '0900552001', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  values ('HSTK501', (select id from app.parent where code = 'PHTK501'), 'Học sinh Lê Tìm Kiếm', 2013, (select id from app.branch where code = 'CS5'))$$);
grant execute on all functions in schema pg_temp to public;
set local role authenticated;

-- Luật S03-15: CSKH cơ sở 5 tìm không dấu ra học sinh và phụ huynh của cơ sở mình.
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is((select count(*)::int from app.search_records('hoc sinh le tim kiem') where entity_type = 'STUDENT'), 1, 'Tìm kiếm: học sinh, gõ không dấu');
select is((select title from app.search_records('0900552001') where entity_type = 'PARENT'), 'Phụ huynh Đặng Tìm Kiếm', 'Tìm kiếm: phụ huynh theo số điện thoại');
select is((select count(*)::int from app.search_records('HSTK501') where entity_type = 'STUDENT'), 1, 'Tìm kiếm: theo mã học sinh');

-- Luật S03-15: chữ quá ngắn thì không tìm.
select is((select count(*)::int from app.search_records('l')), 0, 'Tìm kiếm: một ký tự không tìm');

-- Luật R-CRM-26: hồ sơ phụ huynh, học sinh dùng chung toàn hệ thống, CSKH cơ sở khác vẫn tìm thấy.
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((select count(*)::int from app.search_records('tim kiem') where entity_type = 'PARENT'), 1, 'Tìm kiếm: hồ sơ dùng chung, CSKH cơ sở khác vẫn thấy phụ huynh (R-CRM-26)');

select * from finish();
rollback;
