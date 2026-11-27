-- QT-05 chốt an toàn ma trận quyền (migration 182): cờ permission_matrix_edit_enabled (mặc định TẮT), chỉ Admin lưu, ADMIN không tự gỡ quyền Quản trị, mỗi lần lưu ghi lịch sử (ai, lúc nào, trước, sau).
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p182.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p182.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales', 'SALES')) as v (key, role) on v.key = u.key;
create temp table base as select app.permission_current_version() as v;
grant select on base to authenticated;

select is((select value from app.setting_def where key = 'permission_matrix_edit_enabled'), 'false', 'Cờ sửa ma trận quyền mặc định TẮT');

set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
-- Cờ tắt: Admin cũng không lưu được qua API.
select is(pg_temp.err($$select pg_temp.save(jsonb_build_array(pg_temp.cell('SALES', 'LEAD', 'HUY', 'CO_SO')))$$), 'HMT_TINH_NANG_TAT',
          'Cờ tắt: Admin không lưu được ma trận quyền');
select is(app.permission_current_version(), (select v from base), 'Cờ tắt: không tạo phiên bản');

-- Bật cờ (như Admin bật ở Cài đặt tham số).
reset role;
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'permission_matrix_edit_enabled'$$);
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select is(pg_temp.save(jsonb_build_array(pg_temp.cell('SALES', 'LEAD', 'HUY', 'CO_SO'))), (select v + 1 from base), 'Cờ bật: Admin lưu được, phiên bản mới');
select is((select saved_by from app.permission_version where version_no = (select v + 1 from base)), (select id from u where key = 'admin'), 'Lịch sử ghi người lưu');
select ok((select saved_at from app.permission_version where version_no = (select v + 1 from base)) is not null, 'Lịch sử ghi lúc lưu');
select is((select array[from_scope, to_scope] from app.permission_change c join app.permission_version v on v.id = c.version_id
           where v.version_no = (select v + 1 from base) and c.role_code = 'SALES'), array['CUA_TOI', 'CO_SO'], 'Lịch sử ghi giá trị trước và sau');

-- ADMIN không tự gỡ hoặc thu hẹp quyền Quản trị (chống tự khoá).
select is(pg_temp.err($$select pg_temp.save(jsonb_build_array(pg_temp.cell('ADMIN', 'ADMIN', 'SUA', null)))$$), 'HMT_ADMIN_GIU_QUYEN_QUAN_TRI',
          'ADMIN không gỡ được quyền Sửa phân hệ Quản trị của chính mình');
select is(pg_temp.err($$select pg_temp.save(jsonb_build_array(pg_temp.cell('ADMIN', 'ADMIN', 'XEM', 'CO_SO')))$$), 'HMT_ADMIN_GIU_QUYEN_QUAN_TRI',
          'ADMIN không thu hẹp quyền Xem phân hệ Quản trị xuống Cơ sở');
select is(app.permission_current_version(), (select v + 1 from base), 'Lần lưu bị chặn thì không tạo phiên bản');

-- Người không phải Admin không lưu được dù cờ bật.
select pg_temp.claims((select id from u where key = 'sales'), 'aal1');
select is(pg_temp.err($$select pg_temp.save(jsonb_build_array(pg_temp.cell('SALES', 'LEAD', 'SUA', 'CO_SO')))$$), 'HMT_KHONG_CO_QUYEN',
          'Sale không lưu được ma trận quyền');

select * from finish();
rollback;
