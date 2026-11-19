-- C69 (migration 435): Group By ở máy chủ cho Khoản tiền vào (money_in_group_counts) và Công nợ (receivable_group_counts): đếm theo tình trạng, cơ sở, hai cấp, bộ lọc; chặn trường lạ, trùng cấp, không quyền. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('gv5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@c69.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@c69.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code) select id, case when key = 'admin' then 'ADMIN' else 'TEACHER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

-- Dữ liệu giả (replica để khỏi dựng chuỗi đơn, phiếu): khoản tiền vào 3 ở CS5 (hai ngày khác nhau) và 1 ở CS1; một đơn Đã duyệt CS5 có hai đợt, đợt 1 quá hạn, đợt 2 chưa đến hạn.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHC69D', 'Phụ huynh giả C69D', '0900069004', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$set local session_replication_role = 'replica'$$);
select pg_temp.sudo($$insert into app.sales_order (code, branch_id, parent_id, status_code, priced_on, total_amount, renewal_ticket_id)
  values ('DHC69D', (select id from app.branch where code = 'CS5'), (select id from app.parent where code = 'PHC69D'), 'DA_DUYET', current_date, 2000000, gen_random_uuid())$$);
select pg_temp.sudo($$insert into app.sales_order_installment (order_id, branch_id, seq, due_days, amount, due_date)
  select o.id, o.branch_id, v.seq, 0, 1000000, current_date + v.shift from app.sales_order o, (values (1, -10), (2, 60)) v (seq, shift) where o.code = 'DHC69D'$$);
select pg_temp.sudo($$insert into app.money_in (code, receipt_id, order_id, parent_id, branch_id, amount, created_at)
  select v.c, gen_random_uuid(), (select id from app.sales_order where code = 'DHC69D'), (select id from app.parent where code = 'PHC69D'), (select id from app.branch where code = v.b), 100000, now() - make_interval(days => v.d)
    from (values ('KTVC69-1', 'CS5', 0), ('KTVC69-2', 'CS5', 0), ('KTVC69-3', 'CS5', 3), ('KTVC69-4', 'CS1', 0)) v (c, b, d)$$);
select pg_temp.sudo($$set local session_replication_role = 'origin'$$);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
-- Khoản tiền vào
select is((app.money_in_group_counts('{"q": "KTVC69"}'::jsonb, array['branch']) ->> 'total')::int, 4, 'TC-08 Group By cơ sở: tổng 4 khoản giả');
select is(jsonb_array_length(app.money_in_group_counts('{"q": "KTVC69"}'::jsonb, array['day']) -> 'groups'), 2, 'TC-08 Group By ngày: hai ngày khác nhau (3 ngày trước và hôm nay)');
select is((select g ->> 'l1' from jsonb_array_elements(app.money_in_group_counts('{"q": "KTVC69"}'::jsonb, array['branch']) -> 'groups') g where g ->> 'k1' = (select id::text from app.branch where code = 'CS1')), (select code || ' ' || name from app.branch where code = 'CS1'), 'TC-08 Nhãn nhóm cơ sở = mã và tên');
select is(pg_temp.err($$select app.money_in_group_counts('{}'::jsonb, array['status'])$$), 'HMT_NHOM_SAI', 'TC-08 Chặn: trường nhóm không cho phép');
select is(pg_temp.err($$select app.money_in_group_counts('{}'::jsonb, array['day', 'day'])$$), 'HMT_NHOM_SAI', 'TC-08 Chặn: hai cấp giống nhau');
-- Công nợ
select is((app.receivable_group_counts(jsonb_build_object('q', 'DHC69D'), array['status']) ->> 'total')::int, 2, 'TC-13 Group By tình trạng: hai đợt còn nợ');
select is((select g ->> 'l1' from jsonb_array_elements(app.receivable_group_counts(jsonb_build_object('q', 'DHC69D'), array['status']) -> 'groups') g where g ->> 'k1' = 'QUA_HAN'), 'Quá hạn', 'TC-13 Đợt 1 nằm nhóm Quá hạn');
select is(jsonb_array_length(app.receivable_group_counts(jsonb_build_object('q', 'DHC69D'), array['branch', 'status']) -> 'groups'), 2, 'TC-13 Hai cấp cơ sở, tình trạng: hai nhóm lá');
select is((app.receivable_group_counts(jsonb_build_object('q', 'DHC69D', 'status', jsonb_build_array('QUA_HAN')), array['branch']) ->> 'total')::int, 1, 'TC-13 Bộ lọc tình trạng áp dụng cho số đếm');
select is(pg_temp.err($$select app.receivable_group_counts('{}'::jsonb, array['day'])$$), 'HMT_NHOM_SAI', 'TC-13 Chặn: trường nhóm không cho phép');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$select app.money_in_group_counts('{}'::jsonb, array['branch'])$$), 'HMT_KHONG_CO_QUYEN', 'TC-08 Chặn: giáo viên không có quyền xem sổ');
select is(pg_temp.err($$select app.receivable_group_counts('{}'::jsonb, array['branch'])$$), 'HMT_KHONG_CO_QUYEN', 'TC-13 Chặn: giáo viên không có quyền xem công nợ');

select * from finish();
rollback;
