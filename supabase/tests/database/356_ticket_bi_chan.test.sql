-- Bài «bị chặn» cho các hàm ticket Aftersale (B11): khách (anon), CSKH cơ sở khác, giáo viên (không có Ticket · Sửa) đều không ghi được vào ticket của cơ sở CS5; ticket giữ nguyên. Dữ liệu giả.
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

-- Ticket mục tiêu: qt1 (Đề nghị Cập nhật thông tin, Mới) và qt2 (Khiếu nại); ghi nhận trạng thái ban đầu để kiểm giữ nguyên.
create temp table base (st text, pr text, cat text, notes int, assignee uuid);
grant all on base to public;
insert into base select status_code, priority_code, category_code, (select count(*)::int from app.ticket_event e where e.ticket_id = t.id and e.event_type = 'GHI_CHU'), assignee_id
  from app.ticket t where id = (select (j ->> 'id')::uuid from qt1);

-- Danh sách các lệnh ghi mà mỗi vai bị chặn thử; mỗi lệnh phải báo lỗi (không null).
create function pg_temp.writes(p_id uuid) returns text[] language sql stable as $$
  select array[
    format($f$select app.add_ticket_note(%L::uuid, 'Ghi chú thử')$f$, p_id),
    format($f$select app.assign_ticket(%L::uuid, 'CSKH_CO_SO', %L::uuid)$f$, p_id, pg_temp.uid('cskh5')),
    format($f$select app.change_ticket_status(%L::uuid, 'DA_GIAO', null, null, null)$f$, p_id),
    format($f$select app.change_ticket_priority(%L::uuid, 'KHAN')$f$, p_id),
    format($f$select app.change_ticket_category(%L::uuid, 'DN_04_01')$f$, p_id),
    format($f$select app.change_ticket_type(%L::uuid, 'DN', 'DN_04_01')$f$, p_id),
    format($f$select app.update_ticket_complaint(%L::uuid, '{"customer_wish":"x"}'::jsonb)$f$, p_id)] $$;
grant execute on function pg_temp.writes(uuid) to public;
create function pg_temp.all_blocked(p_id uuid) returns boolean language plpgsql as $$
declare q text;
begin
  foreach q in array pg_temp.writes(p_id) loop
    if pg_temp.err(q) is null then
      return false;
    end if;
  end loop;
  return true;
end $$;
grant execute on function pg_temp.all_blocked(uuid) to public;
create function pg_temp.unchanged(p_id uuid) returns boolean language sql stable as $$
  select (t.status_code, t.priority_code, t.category_code, t.assignee_id is not distinct from b.assignee)
       = (b.st, b.pr, b.cat, true)
     and (select count(*)::int from app.ticket_event e where e.ticket_id = t.id and e.event_type = 'GHI_CHU') = b.notes
    from app.ticket t, base b where t.id = p_id $$;
grant execute on function pg_temp.unchanged(uuid) to public;

-- CSKH cơ sở khác (CS1): không thấy ticket CS5 nên mọi lệnh ghi bị chặn.
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select ok(pg_temp.all_blocked((select (j ->> 'id')::uuid from qt1)), 'Chặn: CSKH cơ sở khác không ghi được ticket (ghi chú, giao, đổi trạng thái, mức độ, nhóm, loại, khiếu nại)');
select is((select count(*)::int from app.ticket where id = (select (j ->> 'id')::uuid from qt1)), 0, 'CSKH cơ sở khác không thấy ticket (RLS)');
select is(pg_temp.err($$select app.ticket_board('{}'::jsonb, 5)$$) is null and (select count(*)::int from jsonb_array_elements(app.list_tickets('{}'::jsonb, 50, 0) -> 'rows') r where r ->> 'id' = (select j ->> 'id' from qt1)) = 0, true, 'Danh sách ticket của CSKH cơ sở khác không có ticket CS5');

-- Giáo viên: không có Ticket · Sửa nên không ghi được vào ticket (nhóm giáo viên có hàm riêng).
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select ok(pg_temp.all_blocked((select (j ->> 'id')::uuid from qt1)), 'Chặn: giáo viên không ghi được ticket khách hàng qua các hàm CSKH');
select is(pg_temp.err($$select app.save_ticket_category('{}'::jsonb)$$) is not null, true, 'Chặn: giáo viên không sửa danh mục nhóm ticket');
select is(pg_temp.err($$select app.save_ticket_sla('[]'::jsonb, '[]'::jsonb)$$) is not null, true, 'Chặn: giáo viên không sửa SLA');

-- CSKH cùng cơ sở nhưng không phải Admin: không sửa cấu hình nhóm và SLA.
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.save_ticket_category('{}'::jsonb)$$) is not null, true, 'Chặn: CSKH không sửa danh mục nhóm ticket (quyền Admin)');
select is(pg_temp.err($$select app.save_ticket_sla('[]'::jsonb, '[]'::jsonb)$$) is not null, true, 'Chặn: CSKH không sửa SLA (quyền Admin)');

-- Khách (anon): mọi hàm ticket bị từ chối ngay ở quyền gọi hàm.
reset role;
set local role anon;
select is(pg_temp.err($$select app.list_tickets('{}'::jsonb, 50, 0)$$), '42501', 'Chặn: anon không gọi list_tickets');
select is(pg_temp.err($$select app.ticket_board('{}'::jsonb, 5)$$), '42501', 'Chặn: anon không gọi ticket_board');
select is(pg_temp.err(format($f$select app.get_ticket(%L::uuid)$f$, (select j ->> 'id' from qt1))), '42501', 'Chặn: anon không gọi get_ticket');
select is(pg_temp.err($$select app.save_ticket_sla('[]'::jsonb, '[]'::jsonb)$$), '42501', 'Chặn: anon không gọi save_ticket_sla');
select is(pg_temp.err($$select app.save_ticket_category('{}'::jsonb)$$), '42501', 'Chặn: anon không gọi save_ticket_category');
select is(pg_temp.err(format($f$select app.add_ticket_note(%L::uuid, 'x')$f$, (select j ->> 'id' from qt1))), '42501', 'Chặn: anon không gọi add_ticket_note');
select is(pg_temp.err(format($f$select app.change_ticket_status(%L::uuid, 'DA_GIAO', null, null, null)$f$, (select j ->> 'id' from qt1))), '42501', 'Chặn: anon không gọi change_ticket_status');
select is(pg_temp.err($$select app.list_ticket_assignees(null)$$), '42501', 'Chặn: anon không gọi list_ticket_assignees');

-- Sau mọi lần bị chặn, ticket giữ nguyên.
reset role;
select ok(pg_temp.unchanged((select (j ->> 'id')::uuid from qt1)), 'Ticket giữ nguyên trạng thái, mức độ, nhóm, người phụ trách, ghi chú sau khi bị chặn');

select * from finish();
rollback;
