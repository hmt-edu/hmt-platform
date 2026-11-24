-- Dữ liệu mẫu đợt 2, mảnh lead và cơ hội (migration 655; F-23-39). Dữ liệu giả.
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
insert into u (key) values ('admin'), ('cskh5a'), ('cskh5b'), ('cskh1');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@dm.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@dm.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' else 'CSKH' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

create function pg_temp.sets_of(p_user text) returns bigint language plpgsql as $$
begin
  perform pg_temp.claims(pg_temp.uid(p_user), case when p_user = 'admin' then 'aal2' else 'aal1' end);
  return (select count(*) from app.list_demo_data_sets());
end $$;
grant execute on function pg_temp.sets_of(text) to public;

create function pg_temp.audit_n() returns bigint language sql security definer as $$
  select count(*) from app.audit_log a join app.audited_table t on t.id = a.table_id where t.table_name = 'app.demo_data_set' or t.table_name = 'demo_data_set' $$;
grant execute on function pg_temp.audit_n() to public;
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5a'), 'aal1');
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'demo_data_enabled'$$);

-- Luật khoá: công tắc tắt hoặc chạy thật thì không đổ lead.
select is(pg_temp.err($$select app.create_demo_data_set()$$), 'HMT_DEMO_TAT', 'Luật khoá môi trường: chưa có khoá STAGING thì không tạo bộ, không có lead mẫu');
select pg_temp.sudo($$insert into app.deployment_env (env_code) values ('STAGING')$$);
-- Aftersale bật rõ ràng cho CS5 (không phụ thuộc công tắc mặc định): bộ mẫu có phần ticket.
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code = 'CS5' on conflict (module_code, branch_id) do update set enabled = true$$);

create temp table s1 (id uuid);
grant all on s1 to public;
insert into s1 select app.create_demo_data_set();
select is((select count(*) from app.lead where is_demo), 10::bigint, 'Đúng: bộ có 10 lead mẫu đều is_demo (CSKH không có quyền tạo lead vẫn tạo được)');
select is((select count(*) from app.opportunity where is_demo), 4::bigint, 'Đúng: bộ có cơ hội mẫu cho các lead đã tạo cơ hội, đều is_demo');
select is((select count(*) from app.demo_data_item where set_id = (select id from s1) and entity_type = 'LEAD'), 10::bigint, 'Đúng: mỗi lead mẫu có dòng demo_data_item');
select is((select count(*) from app.demo_data_item where set_id = (select id from s1) and entity_type = 'OPPORTUNITY'), 4::bigint, 'Đúng: mỗi cơ hội mẫu có dòng demo_data_item');
select is((select count(distinct stage_code) from app.lead where is_demo), 4::bigint, 'Đúng: lead mẫu trải bốn giai đoạn C1-C4');
select is((select count(*) from app.lead where is_demo and parent_phone !~ '^0999000[0-9]{3}$'), 0::bigint, 'Luật SĐT: mọi lead mẫu dùng dải 0999 000 001-999');
select is((select count(*) from app.lead where is_demo and (parent_name !~ '^\[MẪU\]' or owner_id <> pg_temp.uid('cskh5a'))), 0::bigint, 'Luật nhãn: tên có [MẪU], người phụ trách là người tạo bộ');
select is((select count(*) from app.lead where is_demo and code !~ '^LD[0-9]{6}$'), 0::bigint, 'Luật mã: mã lead cấp bằng bộ đếm như bản thật');
select is((select count(*) from app.lead where is_demo and branch_id <> (select id from app.branch where code = 'CS5')), 0::bigint, 'Đúng: lead mẫu thuộc cơ sở của người tạo bộ');

-- Luật: SĐT không trùng giữa hai bộ.
select pg_temp.sudo($$update app.setting_def set value = '3' where key = 'demo_data_max_per_user'$$);
select is(pg_temp.err($$select app.create_demo_data_set()$$), null, 'Đúng: tạo bộ thứ hai');
select is((select count(distinct parent_phone) from app.lead where is_demo), 20::bigint, 'Luật SĐT: số điện thoại không trùng giữa hai bộ');

-- Luật: hàm con không gọi trực tiếp từ giao diện.
select is(pg_temp.err(format($$select app.demo_make_leads(%L, (select id from app.branch where code = 'CS5'))$$, (select id from s1))), '42501', 'Luật: hàm con demo_make_leads không cấp cho người dùng');
select is(pg_temp.err(format($$select app.demo_tag(%L, 'LEAD', gen_random_uuid())$$, (select id from s1))), '42501', 'Luật: demo_tag không cấp cho người dùng');

select * from finish();
rollback;
