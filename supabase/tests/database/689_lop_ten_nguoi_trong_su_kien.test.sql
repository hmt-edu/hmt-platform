-- D-26-09 (migration 689): hồ sơ lớp trả tên người làm ở mỗi sự kiện (events[].actor_name). Dữ liệu giả; chèn thẳng với trigger tắt.
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
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, role_code text not null, branch_code text not null, id uuid not null default gen_random_uuid());
insert into u (key, role_code, branch_code) values ('bm1', 'BRANCH_MANAGER', 'CS1'), ('bm5', 'BRANCH_MANAGER', 'CS5');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d2609.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d2609.hoamatoan.invalid', b.id, false from u join app.branch b on b.code = u.branch_code;
insert into app.user_role (user_id, role_code) select id, role_code from u;

set local session_replication_role = 'replica';
create temp table ids as select gen_random_uuid() as c;
grant select on ids to authenticated;
insert into app.class (id, code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, status_code, start_date, total_sessions)
select ids.c, 'CS1-D2609-001', b.id, '2627', 'TOAN', 'K08', 'CB', 'A', 'TU_CHOI', current_date, 8 from ids, app.branch b where b.code = 'CS1';
insert into app.class_event (class_id, branch_id, event_code, from_status, to_status, note, created_by)
select ids.c, b.id, 'TU_CHOI', 'DA_TRINH', 'TU_CHOI', 'Lý do giả', (select id from u where key = 'bm1') from ids, app.branch b where b.code = 'CS1';
insert into app.class_event (class_id, branch_id, event_code, from_status, to_status, created_by, created_at)
select ids.c, b.id, 'TAO', null, 'NHAP', null, now() - interval '1 day' from ids, app.branch b where b.code = 'CS1';
set local session_replication_role = 'origin';

select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
set local role authenticated;
select is(app.get_class_record((select c from ids)) -> 'events' -> 0 ->> 'actor_name', 'Giả bm1', 'Sự kiện từ chối ghi tên người từ chối');
select is(app.get_class_record((select c from ids)) -> 'events' -> 0 ->> 'note', 'Lý do giả', 'Lý do từ chối giữ nguyên');
select is(app.get_class_record((select c from ids)) -> 'events' -> 1 ->> 'actor_name', null, 'Sự kiện không có người làm thì tên trống');
reset role;
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.get_class_record((select c from ids))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: quản lý cơ sở khác không xem hồ sơ lớp, không lộ tên');
reset role;

select * from finish();
rollback;
