-- Phiếu nghiệp vụ theo từng vai (B17): quản lý cơ sở KHÁC, giáo viên, CSKH cơ sở khác không duyệt, từ chối, huỷ, thực hiện phiếu của CS5; phiếu giữ nguyên trạng thái. Dữ liệu giả (nền như bài 261).
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
insert into u (key) values ('admin'), ('cskh5'), ('cskh1'), ('gv5'), ('gv5b'), ('qlcs5'), ('qlcs1');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@as.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@as.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key in ('cskh1', 'qlcs1') then 'CS1' else 'CS5' end), false from u;
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

-- Phiếu A: Cập nhật hồ sơ, đã trình (Chờ duyệt). Phiếu B: đã duyệt (chờ thực hiện). Phiếu C: Nháp.
create temp table ta (j jsonb);
create temp table tb (j jsonb);
create temp table tc (j jsonb);
create temp table ka (j jsonb);
create temp table kb (j jsonb);
create temp table kc (j jsonb);
grant all on ta, tb, tc, ka, kb, kc to public;
insert into ta select app.create_ticket(pg_temp.mk('DN', 'DN_04_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))));
insert into tb select app.create_ticket(pg_temp.mk('DN', 'DN_04_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))));
insert into tc select app.create_ticket(pg_temp.mk('DN', 'DN_04_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))));
insert into ka select app.create_ticket_task((select (j ->> 'id')::uuid from ta), 'CAP_NHAT_HO_SO', 'Đổi trường A', '{"entity":"STUDENT","changes":{"school":"Trường A"}}'::jsonb);
insert into kb select app.create_ticket_task((select (j ->> 'id')::uuid from tb), 'CAP_NHAT_HO_SO', 'Đổi trường B', '{"entity":"STUDENT","changes":{"school":"Trường B"}}'::jsonb);
insert into kc select app.create_ticket_task((select (j ->> 'id')::uuid from tc), 'CAP_NHAT_HO_SO', 'Đổi trường C', '{"entity":"STUDENT","changes":{"school":"Trường C"}}'::jsonb);
select app.submit_ticket_task((select (j ->> 'id')::uuid from ka));
select app.submit_ticket_task((select (j ->> 'id')::uuid from kb));
select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
select app.approve_ticket_task((select (j ->> 'id')::uuid from kb));
create function pg_temp.st(p_key text) returns text language sql stable as $$
  select status_code from app.ticket_task where id = (select (j ->> 'id')::uuid from ka) and p_key = 'a'
  union all select status_code from app.ticket_task where id = (select (j ->> 'id')::uuid from kb) and p_key = 'b'
  union all select status_code from app.ticket_task where id = (select (j ->> 'id')::uuid from kc) and p_key = 'c' $$;
grant execute on function pg_temp.st(text) to public;
select is(pg_temp.st('a') || '/' || pg_temp.st('b') || '/' || pg_temp.st('c'), 'CHO_DUYET/DA_DUYET/NHAP', 'Nền: phiếu A Chờ duyệt, B Đã duyệt, C Nháp');

-- Quản lý cơ sở KHÁC (CS1): không thấy phiếu CS5 nên mọi thao tác báo lỗi, phiếu giữ nguyên.
select pg_temp.claims(pg_temp.uid('qlcs1'), 'aal1');
select isnt(pg_temp.err($$select app.approve_ticket_task((select (j ->> 'id')::uuid from ka))$$), null, 'Chặn: quản lý cơ sở khác không duyệt phiếu CS5');
select isnt(pg_temp.err($$select app.reject_ticket_task((select (j ->> 'id')::uuid from ka), 'Thiếu giấy tờ')$$), null, 'Chặn: quản lý cơ sở khác không từ chối phiếu CS5');
select isnt(pg_temp.err($$select app.execute_ticket_task((select (j ->> 'id')::uuid from kb))$$), null, 'Chặn: quản lý cơ sở khác không thực hiện phiếu CS5');
select isnt(pg_temp.err($$select app.cancel_ticket_task((select (j ->> 'id')::uuid from kc), 'Nhập nhầm')$$), null, 'Chặn: quản lý cơ sở khác không huỷ phiếu CS5');
select is((select count(*)::int from app.ticket_task where id in ((select (j ->> 'id')::uuid from ka), (select (j ->> 'id')::uuid from kb), (select (j ->> 'id')::uuid from kc))), 0, 'Quản lý cơ sở khác không thấy phiếu CS5 (RLS)');

-- Giáo viên: không có Ticket · Sửa/Duyệt: không thao tác phiếu.
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select isnt(pg_temp.err($$select app.submit_ticket_task((select (j ->> 'id')::uuid from kc))$$), null, 'Chặn: giáo viên không trình phiếu');
select isnt(pg_temp.err($$select app.approve_ticket_task((select (j ->> 'id')::uuid from ka))$$), null, 'Chặn: giáo viên không duyệt phiếu');
select isnt(pg_temp.err($$select app.reject_ticket_task((select (j ->> 'id')::uuid from ka), 'Thiếu giấy tờ')$$), null, 'Chặn: giáo viên không từ chối phiếu');
select isnt(pg_temp.err($$select app.execute_ticket_task((select (j ->> 'id')::uuid from kb))$$), null, 'Chặn: giáo viên không thực hiện phiếu');
select isnt(pg_temp.err($$select app.cancel_ticket_task((select (j ->> 'id')::uuid from kc), 'Nhập nhầm')$$), null, 'Chặn: giáo viên không huỷ phiếu');

-- CSKH cùng cơ sở: không duyệt, không từ chối (không có Ticket · Duyệt).
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select isnt(pg_temp.err($$select app.reject_ticket_task((select (j ->> 'id')::uuid from ka), 'Thiếu giấy tờ')$$), null, 'Chặn: CSKH không từ chối phiếu (không có Ticket · Duyệt)');

-- Sau mọi lần bị chặn, ba phiếu giữ nguyên.
select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
select is(pg_temp.st('a') || '/' || pg_temp.st('b') || '/' || pg_temp.st('c'), 'CHO_DUYET/DA_DUYET/NHAP', 'Phiếu giữ nguyên trạng thái sau khi bị chặn');

select * from finish();
rollback;
