-- QT-04 danh sách vai trò (migration 183): chỉ Admin xem; mỗi vai trò kèm số người đang dùng và số ô quyền; không ghi gì.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p183.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p183.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales', 'SALES')) as v (key, role) on v.key = u.key;

set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select is(jsonb_array_length(app.list_roles_summary()), (select count(*)::int from app.role), 'Admin thấy mọi vai trò');
select is(app.list_roles_summary() -> 0 ->> 'code', (select code from app.role order by sort_order limit 1), 'Sắp theo thứ tự hiển thị');
select is((select (e ->> 'users')::int from jsonb_array_elements(app.list_roles_summary()) e where e ->> 'code' = 'ADMIN'),
          (select count(*)::int from app.user_role ur join app.user_account ua on ua.id = ur.user_id where ur.role_code = 'ADMIN' and ur.is_active and not ua.is_locked),
          'Số người của vai trò ADMIN đúng (gồm tài khoản giả của bài)');
select is((select (e ->> 'cells')::int from jsonb_array_elements(app.list_roles_summary()) e where e ->> 'code' = 'SALES'),
          (select count(*)::int from app.permission where role_code = 'SALES' and is_active), 'Số ô quyền đang bật của SALES đúng');
select is((select e -> 'portals' from jsonb_array_elements(app.list_roles_summary()) e where e ->> 'code' = 'TEACHER'), '["gv"]'::jsonb, 'Cổng của giáo viên là gv');
select pg_temp.claims((select id from u where key = 'sales'), 'aal1');
select is(pg_temp.err($$select app.list_roles_summary()$$), 'HMT_KHONG_CO_QUYEN', 'Sale không xem được danh sách vai trò');
select * from finish();
rollback;
