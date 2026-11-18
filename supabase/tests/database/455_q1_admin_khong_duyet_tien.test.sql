-- Migration 455 (Code D): Q1 của Soát, Admin không thể được cấp Kế toán · Duyệt qua ma trận (R-HT-01). Dữ liệu giả.
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
create function pg_temp.cell(p_role text, p_module text, p_action text, p_scope text) returns jsonb language sql as $$
  select jsonb_build_object('role', p_role, 'module', p_module, 'action', p_action, 'scope', p_scope);
$$;
create function pg_temp.save(p_cells jsonb) returns integer language sql as $$
  select app.save_permission_matrix(app.permission_current_version(), p_cells);
$$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$ begin execute p_sql; end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p455.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p455.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales', 'SALES')) as v (key, role) on v.key = u.key;
create temp table base as select app.permission_current_version() as v;
grant select on base to authenticated;

select is((select count(*)::int from app.permission where role_code = 'ADMIN' and module_code = 'ACCOUNTING' and action_code = 'DUYET' and is_active), 0, 'Ban đầu: Admin không có Kế toán · Duyệt');
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'permission_matrix_edit_enabled'$$);
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
-- Tái hiện lỗ của Soát: cờ bật, Admin lưu ô ADMIN × ACCOUNTING × DUYET.
select is(pg_temp.err($$select pg_temp.save(jsonb_build_array(pg_temp.cell('ADMIN', 'ACCOUNTING', 'DUYET', 'TOAN_HE_THONG')))$$), 'HMT_ADMIN_KHONG_DUYET_TIEN',
          'Chặn: Admin không lưu được ô ADMIN × Kế toán · Duyệt qua ma trận');
select is((select count(*)::int from app.permission where role_code = 'ADMIN' and module_code = 'ACCOUNTING' and action_code = 'DUYET' and is_active), 0, 'Lần lưu bị hoàn tác: Admin vẫn không có quyền');
-- Không chặn nhầm: ô khác vẫn lưu được.
select is(pg_temp.save(jsonb_build_array(pg_temp.cell('SALES', 'LEAD', 'HUY', 'CO_SO'))) > 0, true, 'Đúng: ô khác vẫn lưu được');

select * from finish();
rollback;
