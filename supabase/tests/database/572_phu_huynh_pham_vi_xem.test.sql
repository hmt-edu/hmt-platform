-- Rà security definer cụm 2: list_parents, get_parent_record theo phạm vi Xem phụ huynh (migration 572; R-CRM-26, chính sách parent_read).
begin;
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
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
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('sales1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code) select id, 'SALES' from u;
insert into app.parent (code, full_name, phone, branch_id)
values ('PHPV72A', 'Phụ huynh Phạm Vi', '0991720001', (select id from app.branch where code = 'CS2'));
create temp table ids as select (select id from app.parent where code = 'PHPV72A') as p;
grant select on ids to authenticated;

select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.get_parent_record((select p from ids))$$), null, 'Xem phụ huynh toàn hệ thống: đọc được bản ghi');
select ok((app.list_parents('{"search":"PHPV72A"}'::jsonb) ->> 'total')::int >= 1, 'Xem phụ huynh toàn hệ thống: danh sách có phụ huynh');
reset role;

-- Thu hẹp quyền Xem phụ huynh của SALES về phạm vi hẹp (DUOC_PHAN_CONG): không đọc được qua hàm security definer.
update app.permission set scope_code = 'DUOC_PHAN_CONG' where role_code = 'SALES' and module_code = 'PARENT' and action_code = 'XEM' and is_active;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.get_parent_record((select p from ids))$$), 'HMT_KHONG_CO_QUYEN', 'Phạm vi hẹp: không đọc bản ghi phụ huynh');
select is(pg_temp.err($$select app.list_parents('{}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Phạm vi hẹp: không đọc danh sách phụ huynh');
reset role;

-- Phạm vi Cơ sở (khớp RLS parent_read): vẫn đọc được.
update app.permission set scope_code = 'CO_SO' where role_code = 'SALES' and module_code = 'PARENT' and action_code = 'XEM' and is_active;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.get_parent_record((select p from ids))$$), null, 'Phạm vi Cơ sở: vẫn đọc (R-CRM-26 dùng chung)');
reset role;

select * from finish();
rollback;
