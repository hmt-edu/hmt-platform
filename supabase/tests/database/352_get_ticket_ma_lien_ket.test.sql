-- get_ticket (migration 352): class_code, enrollment_code, related_ticket_code cho khung Liên kết của CSN-03. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('cskh5'), ('cskh1'), ('gv5'), ('gv5b'), ('qlcs5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@as.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@as.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' when key like 'cskh%' then 'CSKH' when key like 'gv%' then 'TEACHER' else 'BRANCH_MANAGER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHAS501', 'Phụ huynh giả ticket', '0900002001', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  values ('HSAS501', (select id from app.parent where code = 'PHAS501'), 'Học sinh giả ticket', 2013, (select id from app.branch where code = 'CS5'))$$);
grant execute on all functions in schema pg_temp to public;

create function pg_temp.mk(p_type text, p_cat text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('ticket_type', p_type, 'branch_id', (select id from app.branch where code = 'CS5'), 'title', 'Tiêu đề giả', 'description', 'Mô tả giả',
    'channel_code', 'GOI_DIEN', 'category_code', p_cat, 'parent_id', (select id from app.parent where code = 'PHAS501')) || p_extra $$;
grant execute on function pg_temp.mk(text, text, jsonb) to public;

select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code in ('CS5', 'CS1')
  on conflict (module_code, branch_id) do update set enabled = true$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
create temp table t1 (j jsonb);
grant all on t1 to public;
insert into t1 select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'));

create temp table qt1 (j jsonb);
grant all on qt1 to public;
insert into qt1 select app.create_ticket(pg_temp.mk('DN', 'DN_04_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))));
create temp table qt2 (j jsonb);
grant all on qt2 to public;
insert into qt2 select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'));

select is((app.get_ticket((select (j ->> 'id')::uuid from qt1)) -> 'ticket' ->> 'class_code'), null, 'Chi tiết: ticket không gắn lớp thì class_code rỗng');
select is((app.get_ticket((select (j ->> 'id')::uuid from qt1)) -> 'ticket' ->> 'enrollment_code'), null, 'Chi tiết: ticket không gắn ghi danh thì enrollment_code rỗng');
select is((app.get_ticket((select (j ->> 'id')::uuid from qt1)) -> 'ticket' ->> 'related_ticket_code'), null, 'Chi tiết: ticket không có ticket gốc thì related_ticket_code rỗng');
-- Ticket con (Đề nghị sinh từ Khiếu nại) mang mã ticket gốc.
create temp table qc (j jsonb);
grant all on qc to public;
insert into qc select app.create_ticket(pg_temp.mk('DN', 'DN_04_01', jsonb_build_object('related_ticket_id', (select (j ->> 'id')::uuid from qt2), 'student_id', (select id from app.student where code = 'HSAS501'))));
select is((app.get_ticket((select (j ->> 'id')::uuid from qc)) -> 'ticket' ->> 'related_ticket_code'), (select j ->> 'code' from qt2), 'Chi tiết: ticket con có related_ticket_code đúng mã ticket gốc');
select is((app.get_ticket((select (j ->> 'id')::uuid from qt1)) -> 'ticket' ->> 'student_name'), 'Học sinh giả ticket', 'Các khoá cũ giữ nguyên (student_name vẫn có)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.get_ticket((select (j ->> 'id')::uuid from qt1))$$), 'HMT_KHONG_TIM_THAY', 'CSKH cơ sở khác không mở được ticket (RLS)');

select * from finish();
rollback;
