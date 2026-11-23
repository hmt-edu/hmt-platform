-- QT-11 app.list_audit_log (migration 550): chỉ Admin đọc; lọc theo bảng, loại, khoảng ngày; phân trang. Dữ liệu giả.
begin;
-- D41 (migration 472): bài này kiểm luật «Admin, Kế toán phải qua hai bước»; luật chỉ áp khi tham số mfa_required_enabled bật (mặc định tắt), nên bật tham số ở đây.
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
-- 647 (A-23-27): bắt hai bước chỉ còn Admin; bài này vẫn kiểm luật aal2 cho Kế toán nên dựng lại cờ trong giao dịch của bài (hoàn tác khi kết thúc).
do $$ begin perform set_config('hmt.migration', 'on', true); update app.role set require_mfa = true where code = 'ACCOUNTANT'; perform set_config('hmt.migration', '', true); end $$;
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

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@al.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@al.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' else 'CSKH' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- Ba dòng nhật ký giả: hai của bảng đầu tiên (một tạo, một sửa), một của bảng thứ hai.
create temp table t as select id, table_name from app.audited_table order by id limit 2;
insert into app.audit_log (table_id, record_id, action, changes, actor, at)
select (select id from t order by id limit 1), gen_random_uuid(), 'I', null, pg_temp.uid('admin'), now() - interval '3 day'
union all select (select id from t order by id limit 1), gen_random_uuid(), 'U', '{"name":["a","b"]}'::jsonb, pg_temp.uid('admin'), now() - interval '1 day'
union all select (select id from t order by id desc limit 1), gen_random_uuid(), 'U', '{"x":[1,2]}'::jsonb, pg_temp.uid('cskh5'), now();
grant select on t to authenticated;
grant execute on all functions in schema pg_temp to public;

set local role authenticated;

-- Luật S03-12: người không phải Admin bị chặn.
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.list_audit_log()$$), 'HMT_KHONG_CO_QUYEN', 'Nhật ký thao tác: CSKH bị chặn (S03-12)');

-- Admin chưa qua hai bước cũng bị chặn.
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.list_audit_log()$$), 'HMT_KHONG_CO_QUYEN', 'Nhật ký thao tác: Admin chưa xác thực hai bước bị chặn');

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select ok((app.list_audit_log() ->> 'total')::int >= 3, 'Nhật ký thao tác: Admin đã hai bước xem được');
select is(app.list_audit_log(jsonb_build_object('actor', pg_temp.uid('cskh5')) ) ->> 'total', '1', 'Lọc theo người thao tác');
select is(app.list_audit_log(jsonb_build_object('actor', pg_temp.uid('admin'), 'action', 'I')) ->> 'total', '1', 'Lọc theo loại thao tác: tạo');
select is(app.list_audit_log(jsonb_build_object('actor', pg_temp.uid('admin'), 'from', (now() - interval '2 day')::text)) ->> 'total', '1', 'Lọc từ ngày: bỏ dòng cũ hơn mốc');
select is(app.list_audit_log(jsonb_build_object('actor', pg_temp.uid('admin'), 'to', (now() - interval '2 day')::text)) ->> 'total', '1', 'Lọc đến ngày: bỏ dòng mới hơn mốc');
select is(app.list_audit_log(jsonb_build_object('actor', pg_temp.uid('admin'), 'table', (select table_name from t order by id limit 1))) ->> 'total', '2', 'Lọc theo bảng');
select is((app.list_audit_log(jsonb_build_object('actor', pg_temp.uid('admin')), 1, 0) -> 'rows' -> 0 ->> 'action'), 'U', 'Mới nhất trước: dòng đầu là lần sửa');
select is(jsonb_array_length(app.list_audit_log(jsonb_build_object('actor', pg_temp.uid('admin')), 1, 1) -> 'rows'), 1, 'Phân trang: trang hai có một dòng');
select is(app.list_audit_log(jsonb_build_object('actor', pg_temp.uid('cskh5'))) -> 'rows' -> 0 ->> 'actor_name', 'Giả cskh5', 'Có tên người thao tác');
select is(pg_temp.err($$select app.list_audit_log('{"action":"X"}'::jsonb)$$), 'HMT_LOC_KHONG_HOP_LE', 'Loại thao tác lạ bị từ chối');

select * from finish();
rollback;
