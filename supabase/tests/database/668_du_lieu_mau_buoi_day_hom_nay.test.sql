-- Dữ liệu mẫu đợt 2, buổi dạy hôm nay cho giáo viên và nhận xét chờ gửi (migration 668; E-23-44). Dữ liệu giả.
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
create function pg_temp.items(p_set uuid, p_type text) returns bigint language sql security definer as $$
  select count(*) from app.demo_data_item where set_id = p_set and entity_type = p_type $$;
create function pg_temp.sql_count(p_sql text) returns bigint language plpgsql security definer as $$
declare v bigint; begin execute p_sql into v; return v; end $$;
create function pg_temp.sql_text(p_sql text) returns text language plpgsql security definer as $$
declare v text; begin execute p_sql into v; return v; end $$;
grant execute on function pg_temp.items(uuid, text), pg_temp.sql_count(text), pg_temp.sql_text(text) to public;

-- Hạn mức mặc định sau migration 666 (đọc trước khi bài test đặt lại).

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'demo_data_enabled'$$);
select pg_temp.sudo($$insert into app.deployment_env (env_code) values ('STAGING')$$);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select m, b.id, true from app.branch b, unnest(array['AFTERSALE', 'VAN_HANH_LOP', 'BAO_LUU', 'HOAN_PHI', 'BAN_HANG']) m where b.code = 'CS5' on conflict (module_code, branch_id) do update set enabled = true$$);

insert into s1 select app.create_demo_data_set();

-- Nhận xét chờ gửi (CS-16): CSKH thấy 1 dòng chờ gửi từ bộ mẫu.
select cmp_ok(((app.list_parent_messages('{"status":"CHO_GUI"}'::jsonb, 50, 0)) -> 'counts' ->> 'cho_gui')::bigint, '>=', 1::bigint,
  'CS-16: danh sách nhận xét chờ gửi có dòng từ bộ mẫu');
-- Buổi dạy hôm nay: một buổi mẫu Nháp hôm nay có giáo viên của cơ sở.
select is(pg_temp.sql_count(format($$select count(*) from app.class_session s where s.is_demo and s.status_code = 'NHAP' and s.session_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date and s.teacher_id = %L and s.class_id in (select entity_id from app.demo_data_item where set_id = %L and entity_type = 'CLASS')$$, pg_temp.uid('gv5'), (select id from s1))), 1::bigint,
  'GV-02: có đúng 1 buổi mẫu hôm nay gán cho giáo viên của cơ sở');
select is(pg_temp.sql_count(format($$select count(*) from app.class_session s where s.is_demo and s.status_code = 'NHAP' and s.teacher_id is distinct from %L and s.class_id in (select entity_id from app.demo_data_item where set_id = %L and entity_type = 'CLASS')$$, pg_temp.uid('gv5'), (select id from s1))), 0::bigint,
  'Đúng: các buổi chưa dạy của lớp mẫu đều gán cùng giáo viên');
-- Giáo viên thấy buổi hôm nay qua hàm cổng.
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select cmp_ok(((app.teacher_my_sessions('NGAY')) ->> 'total')::bigint, '>=', 1::bigint, 'GV-02: giáo viên thấy buổi dạy hôm nay của lớp mẫu');
select is(pg_temp.err(format($$select app.demo_make_teaching_today(%L, (select id from app.branch where code = 'CS5'))$$, (select id from s1))), '42501',
  'Luật: hàm con demo_make_teaching_today không cấp cho người dùng');

select * from finish();
rollback;
