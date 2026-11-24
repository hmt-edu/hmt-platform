-- E-23-36: dòng sổ giờ của ghi danh mẫu (buổi mẫu tự Done) mang cờ mẫu và nằm trong bộ (migration 661). Dữ liệu giả.
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

create temp table u (key text primary key, role_code text not null, id uuid not null default gen_random_uuid());
insert into u (key, role_code) values ('admin', 'ADMIN'), ('cskh5', 'CSKH'), ('ketoan', 'ACCOUNTANT'), ('gv5', 'TEACHER'), ('tg5', 'TA');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@dm.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@dm.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code) select id, role_code from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

create temp table s1 (id uuid);
grant all on s1 to public;
-- Đếm bản ghi của một bộ theo loại (đọc trực tiếp, không qua RLS).
create function pg_temp.items(p_set uuid, p_type text) returns bigint language sql security definer as $$
  select count(*) from app.demo_data_item where set_id = p_set and entity_type = p_type $$;
create function pg_temp.sql_count(p_sql text) returns bigint language plpgsql security definer as $$
declare v bigint; begin execute p_sql into v; return v; end $$;
grant execute on function pg_temp.items(uuid, text), pg_temp.sql_count(text) to public;
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'demo_data_enabled'$$);
select pg_temp.sudo($$insert into app.deployment_env (env_code) values ('STAGING')$$);
-- Aftersale bật rõ ràng cho CS5 (không phụ thuộc công tắc mặc định): bộ mẫu có phần ticket.
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code = 'CS5' on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS5' on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$update app.setting_def set value = '5' where key = 'demo_data_max_per_user'$$);
select pg_temp.sudo($$update app.setting_def set value = '20' where key = 'demo_data_max_per_branch'$$);

-- Bộ đầu do CSKH tạo: lead, cơ hội, báo giá, đơn (mảnh F, B) rồi học sinh, lớp, ghi danh, ticket (mảnh C).
insert into s1 select app.create_demo_data_set();
-- Hai ghi danh của bộ: một giữ là ghi danh mẫu, một đổi thành ghi danh thật để thử luật «ghi danh thật không bị gắn cờ».
create temp table en (demo_id uuid, real_id uuid);
grant all on en to public;
select pg_temp.sudo($$insert into en select
  (select entity_id from app.demo_data_item where set_id = (select id from s1) and entity_type = 'ENROLLMENT' order by entity_id limit 1),
  (select entity_id from app.demo_data_item where set_id = (select id from s1) and entity_type = 'ENROLLMENT' order by entity_id desc limit 1)$$);
select pg_temp.sudo($$update app.enrollment set is_demo = false where id = (select real_id from en)$$);

-- Chèn dòng sổ giờ như hàm trừ giờ làm: không đặt is_demo.
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, source_ref, note)
  select e.id, e.branch_id, 'CAP_TANG', 1, 'e-23-36', 'thử' from app.enrollment e where e.id in (select demo_id from en union select real_id from en)$$);

select is(pg_temp.sql_count($$select count(*) from app.hour_ledger where source_ref = 'e-23-36' and is_demo and enrollment_id = (select demo_id from en)$$), 1::bigint,
  'E-23-36: dòng sổ giờ của ghi danh mẫu mang cờ is_demo');
select is(pg_temp.sql_count($$select count(*) from app.demo_data_item i join app.hour_ledger g on g.id = i.entity_id
  where i.entity_type = 'HOUR_LEDGER' and i.set_id = (select id from s1) and g.source_ref = 'e-23-36'$$), 1::bigint,
  'E-23-36: dòng sổ giờ mẫu nằm trong bộ của ghi danh');
select is(pg_temp.sql_count($$select count(*) from app.hour_ledger where source_ref = 'e-23-36' and not is_demo and enrollment_id = (select real_id from en)$$), 1::bigint,
  'E-23-36: dòng sổ giờ của ghi danh thật không bị gắn cờ mẫu');
select is(pg_temp.sql_count($$select count(*) from app.demo_data_item i join app.hour_ledger g on g.id = i.entity_id
  where i.entity_type = 'HOUR_LEDGER' and g.enrollment_id = (select real_id from en) and g.source_ref = 'e-23-36'$$), 0::bigint,
  'E-23-36: dòng sổ giờ của ghi danh thật không vào bộ mẫu nào');

-- Xoá bộ: dòng mẫu thuộc bộ đã xoá (bị ẩn khỏi báo cáo).
select is(pg_temp.err(format($$select app.delete_demo_data_set(%L)$$, (select id from s1))), null, 'E-23-36: chủ bộ xoá được bộ');
select is(pg_temp.sql_count($$select count(*) from app.demo_data_item i join app.demo_data_set d on d.id = i.set_id
  join app.hour_ledger g on g.id = i.entity_id where i.entity_type = 'HOUR_LEDGER' and g.source_ref = 'e-23-36' and d.status_code = 'DA_XOA'$$), 1::bigint,
  'E-23-36: xoá bộ → dòng sổ giờ mẫu thuộc bộ đã xoá');

select * from finish();
rollback;
