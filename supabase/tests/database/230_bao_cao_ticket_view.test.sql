-- Migration 230 (Code D): view báo cáo ticket report.ticket_summary (BC-10, R-CS-12). Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@as230.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@as230.hoamatoan.invalid',
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
create temp table tk (key text primary key, id uuid);
grant all on tk to public;
create function pg_temp.k(p_key text) returns uuid language sql stable as $$ select id from tk where key = p_key $$;
grant execute on function pg_temp.k(text) to public;
insert into tk select 'kn', (app.create_ticket(pg_temp.mk('KN', 'KN_02_02')) ->> 'id')::uuid;
insert into tk select 'dn', (app.create_ticket(pg_temp.mk('DN', 'DN_02_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501')))) ->> 'id')::uuid;
insert into tk select 'qh', (app.create_ticket(pg_temp.mk('DN', 'DN_02_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501')))) ->> 'id')::uuid;

-- ================= Dòng cơ bản =================
select is((select count(*)::int from report.ticket_summary), 3, 'Mỗi ticket một dòng');
select is((select ticket_type from report.ticket_summary where ticket_id = pg_temp.k('kn')), 'KN', 'Loại ticket');
select ok((select group_code is not null from report.ticket_summary where ticket_id = pg_temp.k('kn')), 'Có mã nhóm (nhóm cha của nhóm con)');
select ok((select business_type is not null from report.ticket_summary where ticket_id = pg_temp.k('dn')), 'Nhóm con có nghiệp vụ đi kèm thì hiện business_type (lý do chuyển lớp, bảo lưu, hoàn tiền...)');
select ok(not (select response_overdue_open from report.ticket_summary where ticket_id = pg_temp.k('kn')), 'Ticket mới chưa quá hạn phản hồi');
select ok(not (select resolve_overdue_open from report.ticket_summary where ticket_id = pg_temp.k('kn')), 'Ticket mới chưa quá hạn xử lý');
select is((select resolve_hours from report.ticket_summary where ticket_id = pg_temp.k('kn')), null, 'Chưa xử lý thì chưa có giờ xử lý');

-- ================= Đúng hạn (giả lập thời điểm bằng quyền chủ) =================
select pg_temp.sudo($$update app.ticket set first_response_at = response_due_at - interval '1 hour' where id = pg_temp.k('kn')$$);
select ok((select response_on_time from report.ticket_summary where ticket_id = pg_temp.k('kn')), 'Phản hồi đầu trước hạn: đúng hạn phản hồi');
select pg_temp.sudo($$update app.ticket set first_response_at = response_due_at + interval '1 hour' where id = pg_temp.k('dn')$$);
select ok(not (select response_on_time from report.ticket_summary where ticket_id = pg_temp.k('dn')), 'Phản hồi đầu sau hạn: không đúng hạn');
select pg_temp.sudo($$update app.ticket set status_code = 'DA_XU_LY', resolved_at = created_at + interval '5 hours', resolve_due_at = created_at + interval '10 hours' where id = pg_temp.k('kn')$$);
select ok((select resolve_on_time from report.ticket_summary where ticket_id = pg_temp.k('kn')), 'Xử lý xong trước hạn: đúng hạn xử lý');
select is((select round(resolve_hours::numeric, 1) from report.ticket_summary where ticket_id = pg_temp.k('kn')), 5.0::numeric, 'Giờ xử lý = thời gian từ tạo đến xử lý xong');
select ok(not (select resolve_overdue_open from report.ticket_summary where ticket_id = pg_temp.k('kn')), 'Ticket đã xử lý không tính quá hạn đang mở');
select pg_temp.sudo($$update app.ticket set resolve_due_at = now() - interval '1 hour', response_due_at = now() - interval '2 hours' where id = pg_temp.k('qh')$$);
select ok((select resolve_overdue_open from report.ticket_summary where ticket_id = pg_temp.k('qh')), 'Ticket đang mở qua hạn xử lý: quá hạn đang mở');
select ok((select response_overdue_open from report.ticket_summary where ticket_id = pg_temp.k('qh')), 'Ticket chưa phản hồi qua hạn phản hồi: quá hạn đang mở');
select pg_temp.sudo($$update app.ticket set status_code = 'DA_HUY', cancel_reason = 'Giả' where id = pg_temp.k('qh')$$);
select ok(not (select resolve_overdue_open or response_overdue_open from report.ticket_summary where ticket_id = pg_temp.k('qh')), 'Ticket huỷ không tính quá hạn');

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((select count(*)::int from report.ticket_summary), 0, 'RLS: CSKH cơ sở khác không thấy ticket CS5 (security_invoker)');
select ok(not has_table_privilege('authenticated', 'report.ticket_summary', 'insert') and not has_table_privilege('authenticated', 'report.ticket_summary', 'update'), 'Chặn: không cấp quyền ghi vào view');

select * from finish();
rollback;
