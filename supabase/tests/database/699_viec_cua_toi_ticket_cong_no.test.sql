begin;
-- Migration 699 (E-27-04): «Việc của tôi» thêm ticket quá hạn và công nợ quá hạn. Luật: quyền theo Ticket · Xem và Đơn hàng · Xem, phạm vi cơ sở,
-- «của tôi» là người phụ trách ticket / người lập đơn, tiền đã thu trừ theo thứ tự đợt, «Để sau». Dữ liệu giả.
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
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('sales1'), ('sales5'), ('cskh1'), ('bm1'), ('gv1'), ('kt');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@e699.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@e699.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('sales1', 'CS1'), ('sales5', 'CS5'), ('cskh1', 'CS1'), ('bm1', 'CS1'), ('gv1', 'CS1'), ('kt', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('sales1', 'SALES'), ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('bm1', 'BRANCH_MANAGER'),
                                        ('gv1', 'TEACHER'), ('kt', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
grant execute on function pg_temp.uid(text), pg_temp.cs(text) to public;

create temp table id (key text primary key, id uuid not null default gen_random_uuid());
insert into id (key) values ('p1'), ('tk1'), ('tk2'), ('tk3'), ('tk5'), ('o1'), ('o2'), ('o3'), ('o5');
grant select on id to authenticated;
create function pg_temp.i(p_key text) returns uuid language sql stable as $$ select id from id where key = p_key $$;
create function pg_temp.today() returns date language sql stable as $$ select (now() at time zone 'Asia/Ho_Chi_Minh')::date $$;
grant execute on function pg_temp.i(text), pg_temp.today() to public;

set local session_replication_role = replica;
insert into app.parent (id, code, full_name, phone, branch_id) values (pg_temp.i('p1'), 'PHE699', 'Phụ huynh giả 699', '0900699001', pg_temp.cs('CS1'));
-- tk1 quá hạn đang mở; tk2 còn hạn; tk3 quá hạn nhưng đã xử lý; tk5 quá hạn ở CS5.
insert into app.ticket (id, code, ticket_type, branch_id, title, description, channel_code, category_code, priority_code, status_code, assignee_id, parent_id, response_due_at, resolve_due_at)
select pg_temp.i(v.k), 'TKE699' || v.k, 'DN', pg_temp.cs(v.cs), 'Đề nghị giả ' || v.k, 'Giả', 'X', 'X', 'THUONG', v.st, pg_temp.uid(v.own), pg_temp.i('p1'), now(), now() + v.due::interval
  from (values ('tk1', 'CS1', 'DANG_XU_LY', 'cskh1', '-2 days'), ('tk2', 'CS1', 'DANG_XU_LY', 'cskh1', '2 days'),
               ('tk3', 'CS1', 'DA_XU_LY', 'cskh1', '-2 days'), ('tk5', 'CS5', 'MOI', 'sales5', '-2 days')) v (k, cs, st, own, due);
-- o1: đợt 1 (1.500.000) quá hạn 14 ngày đã thu 1.000.000, đợt 2 chưa tới hạn. o2: đợt quá hạn đã thu đủ. o3: chưa duyệt. o5: CS5.
insert into app.sales_order (id, code, branch_id, renewal_ticket_id, parent_id, status_code, priced_on, total_amount, created_by)
select pg_temp.i(v.k), 'DHE699' || v.k, pg_temp.cs(v.cs), gen_random_uuid(), pg_temp.i('p1'), v.st, pg_temp.today(), 2700000, pg_temp.uid(v.own)
  from (values ('o1', 'CS1', 'DA_DUYET', 'sales1'), ('o2', 'CS1', 'DA_DUYET', 'sales1'), ('o3', 'CS1', 'DA_TRINH', 'sales1'),
               ('o5', 'CS5', 'DA_DUYET', 'sales5')) v (k, cs, st, own);
insert into app.sales_order_installment (order_id, branch_id, seq, due_days, amount, due_date)
select o.id, o.branch_id, v.seq, 0, v.amount, pg_temp.today() + v.shift
  from (values ('o1', 1, 1500000, -14), ('o1', 2, 1200000, 30), ('o2', 1, 400000, -3), ('o3', 1, 400000, -3), ('o5', 1, 400000, -5)) v (k, seq, amount, shift)
  join app.sales_order o on o.id = pg_temp.i(v.k);
insert into app.money_in (code, receipt_id, order_id, parent_id, branch_id, amount)
select 'KTVE699' || v.k, gen_random_uuid(), pg_temp.i(v.k), pg_temp.i('p1'), pg_temp.cs('CS1'), v.amount
  from (values ('o1', 1000000), ('o2', 400000)) v (k, amount);
set local session_replication_role = origin;

create function pg_temp.viec(p_filters jsonb default '{}') returns text language sql stable as $$
  select coalesce(string_agg((x ->> 'signal') || ':' || id.key, ' ' order by x ->> 'signal', id.key), '')
    from jsonb_array_elements(app.list_my_work(p_filters, 100) -> 'cards') c
   cross join lateral jsonb_array_elements(c -> 'items') x
    join id on id.id = (x ->> 'entity_id')::uuid $$;
create function pg_temp.muc(p_key text) returns jsonb language sql stable as $$
  select x from jsonb_array_elements(app.list_my_work('{"mine": false}', 100) -> 'cards') c
   cross join lateral jsonb_array_elements(c -> 'items') x where (x ->> 'entity_id')::uuid = pg_temp.i(p_key) $$;
create function pg_temp.hoan(p_signal text, p_key text) returns text language sql volatile as $$
  select pg_temp.err(format('select app.snooze_work(%L, %L, now() + interval ''1 day'')', p_signal, pg_temp.i(p_key))) $$;
grant execute on function pg_temp.viec(jsonb), pg_temp.muc(text), pg_temp.hoan(text, text) to public;

set local role authenticated;

select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.viec(), 'TICKET_OVERDUE:tk1', 'Người phụ trách thấy ticket quá hạn đang mở; bỏ ticket còn hạn và đã xử lý');

select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.viec(), 'DEBT_OVERDUE:o1', 'Công nợ nhắc người lập đơn; bỏ đợt đã thu đủ và đơn chưa duyệt');
select is(pg_temp.hoan('DEBT_OVERDUE', 'o1'), null, 'Công nợ quá hạn được «Để sau»');
select is(pg_temp.viec(), '', 'Đã để sau thì ẩn khỏi việc của tôi');
select is(pg_temp.hoan('DEBT_OVERDUE', 'o5'), 'HMT_VIEC_KHONG_CON', 'Chặn: không hoãn hộ công nợ của người khác');

select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.viec(), '', 'Trưởng cơ sở không phụ trách: việc của mình trống');
select is(pg_temp.viec('{"mine": false}'), 'DEBT_OVERDUE:o1 TICKET_OVERDUE:tk1', 'Cả đội: thấy công nợ và ticket của cơ sở mình, không thấy CS5');
select is(pg_temp.muc('o1') ->> 'why', 'Quá hạn 14 ngày, còn 500.000 đ', 'Số tiền còn lại = đợt quá hạn trừ đã thu, không tính đợt chưa tới hạn');
select is(pg_temp.muc('tk1') ->> 'urgency', 'NOW', 'Ticket quá hạn vào nhóm Làm ngay');
select is(pg_temp.hoan('TICKET_OVERDUE', 'tk1'), 'HMT_VIEC_KHONG_CON', 'Chặn: không hoãn hộ ticket của người khác');

select pg_temp.claims(pg_temp.uid('kt'), 'aal2');
select is(pg_temp.viec(), '', 'Kế toán không nhận nhắc từng khoản công nợ');

select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select ok(pg_temp.viec('{"mine": false}') not like '%DEBT_OVERDUE%', 'Chặn: không có quyền Đơn hàng · Xem thì không thấy công nợ');

select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.hoan('TICKET_OVERDUE', 'tk1'), null, 'Ticket quá hạn được «Để sau»');
select is(pg_temp.viec(), '', 'Ticket đã để sau thì ẩn');
select is(pg_temp.err('select app.work_debts_overdue(false, null)'), '42501', 'Chặn: không gọi thẳng hàm con');

select * from finish();
rollback;
