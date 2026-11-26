-- D-26-07 (migration 684): hồ sơ phụ huynh chỉ trả đơn hàng, phiếu thu và số đếm theo quyền Xem của từng phân hệ và phạm vi cơ sở.
-- Dữ liệu giả; chèn thẳng đơn, phiếu thu với trigger tắt vì bài chỉ kiểm quyền đọc.
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
insert into u (key, role_code, branch_code) values
  ('tuvan1', 'SALES', 'CS1'), ('tuvan2', 'SALES', 'CS2'), ('cskh1', 'CSKH', 'CS1'), ('cskh2', 'CSKH', 'CS2'),
  ('ketoan1', 'ACCOUNTANT', 'CS1'), ('truongcs1', 'BRANCH_MANAGER', 'CS1'), ('admin1', 'ADMIN', 'CS1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d2607.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d2607.hoamatoan.invalid', b.id, false from u join app.branch b on b.code = u.branch_code;
insert into app.user_role (user_id, role_code) select id, role_code from u;

insert into app.parent (code, full_name, phone, branch_id)
values ('PHD2607', 'Phụ huynh Giả Quyền', '0991260700', (select id from app.branch where code = 'CS1'));
create temp table ids as select id as p from app.parent where code = 'PHD2607';
grant select on ids to authenticated;

set local session_replication_role = 'replica';
insert into app.sales_order (code, branch_id, opportunity_id, parent_id, priced_on, total_amount)
select 'DH-D2607-' || b.code, b.id, gen_random_uuid(), ids.p, current_date, 1000000 from app.branch b, ids where b.code in ('CS1', 'CS2');
insert into app.receipt (code, order_id, parent_id, branch_id, collect_branch_id, amount, payment_method_code)
select 'PT-D2607-' || b.code, o.id, o.parent_id, b.id, b.id, 500000, 'CHUYEN_KHOAN'
  from app.sales_order o join app.branch b on b.id = o.branch_id where o.code like 'DH-D2607-%';
set local session_replication_role = 'origin';

-- Mã đơn (hoặc phiếu thu) mà một người thấy trên hồ sơ, kèm số đếm: "CS1,CS2|2".
create function pg_temp.seen(p_key text, p_kind text) returns text language plpgsql as $$
declare v jsonb; v_out text;
begin
  perform pg_temp.claims(pg_temp.uid(p_key), 'aal1');
  set local role authenticated;
  v := app.get_parent_record((select p from pg_temp.ids));
  select coalesce(string_agg(right(x ->> 'code', 3), ',' order by right(x ->> 'code', 3)), '') || '|' || (v -> 'counts' ->> p_kind)
    into v_out from jsonb_array_elements(v -> p_kind) x;
  reset role;
  return v_out;
end $$;
grant execute on function pg_temp.seen(text, text) to public;

select is(pg_temp.seen('tuvan1', 'orders'), 'CS1|1', 'Tư vấn CS1: chỉ thấy đơn của cơ sở mình');
select is(pg_temp.seen('tuvan1', 'receipts'), 'CS1|1', 'Tư vấn CS1: chỉ thấy phiếu thu của cơ sở mình');
select is(pg_temp.seen('tuvan2', 'orders'), 'CS2|1', 'Tư vấn CS2: chỉ thấy đơn của cơ sở mình');
select is(pg_temp.seen('tuvan2', 'receipts'), 'CS2|1', 'Tư vấn CS2: chỉ thấy phiếu thu của cơ sở mình');
select is(pg_temp.seen('cskh1', 'orders'), 'CS1|1', 'CSKH CS1: chỉ thấy đơn của cơ sở mình');
select is(pg_temp.seen('cskh1', 'receipts'), 'CS1|1', 'CSKH CS1: chỉ thấy phiếu thu của cơ sở mình');
select is(pg_temp.seen('cskh2', 'orders'), 'CS2|1', 'CSKH CS2: chỉ thấy đơn của cơ sở mình');
select is(pg_temp.seen('cskh2', 'receipts'), 'CS2|1', 'CSKH CS2: chỉ thấy phiếu thu của cơ sở mình');
select is(pg_temp.seen('ketoan1', 'orders'), 'CS1,CS2|2', 'Kế toán: thấy đơn mọi cơ sở');
select is(pg_temp.seen('ketoan1', 'receipts'), 'CS1,CS2|2', 'Kế toán: thấy phiếu thu mọi cơ sở');
select is(pg_temp.seen('admin1', 'orders'), 'CS1,CS2|2', 'Admin: thấy đơn mọi cơ sở');
select is(pg_temp.seen('admin1', 'receipts'), 'CS1,CS2|2', 'Admin: thấy phiếu thu mọi cơ sở');

-- Trưởng cơ sở và mọi vai: hồ sơ phải khớp đúng những gì danh sách đơn, phiếu thu cho thấy (phạm vi lấy từ ma trận quyền).
create function pg_temp.listed(p_key text, p_fn text) returns text language plpgsql as $$
declare v jsonb; v_out text;
begin
  perform pg_temp.claims(pg_temp.uid(p_key), 'aal1');
  set local role authenticated;
  execute format('select app.%I(jsonb_build_object(''parent_id'', (select p from pg_temp.ids)))', p_fn) into v;
  select coalesce(string_agg(right(x ->> 'code', 3), ',' order by right(x ->> 'code', 3)), '') || '|' || (v ->> 'total')
    into v_out from jsonb_array_elements(v -> 'rows') x;
  reset role;
  return v_out;
end $$;
grant execute on function pg_temp.listed(text, text) to public;
select is(pg_temp.seen(key, 'orders'), pg_temp.listed(key, 'list_orders'), key || ': đơn trên hồ sơ khớp danh sách đơn') from u order by key;
select is(pg_temp.seen(key, 'receipts'), pg_temp.listed(key, 'list_receipts'), key || ': phiếu thu trên hồ sơ khớp danh sách phiếu thu') from u order by key;

-- Tắt quyền Xem đơn hàng của Tư vấn: khối đơn rỗng, phiếu thu không đổi, hồ sơ vẫn đọc được.
update app.permission set is_active = false where role_code = 'SALES' and module_code = 'SALES_ORDER' and action_code = 'XEM';
select is(pg_temp.seen('tuvan1', 'orders'), '|0', 'Không có quyền Xem đơn hàng: không thấy đơn, số đếm 0');
select is(pg_temp.seen('tuvan1', 'receipts'), 'CS1|1', 'Không có quyền Xem đơn hàng: quyền phiếu thu không đổi');

-- Tắt quyền Xem phiếu thu của CSKH.
update app.permission set is_active = false where role_code = 'CSKH' and module_code = 'RECEIPT' and action_code = 'XEM';
select is(pg_temp.seen('cskh1', 'receipts'), '|0', 'Không có quyền Xem phiếu thu: không thấy phiếu thu, số đếm 0');
select is(pg_temp.seen('cskh1', 'orders'), 'CS1|1', 'Không có quyền Xem phiếu thu: quyền đơn hàng không đổi');

select * from finish();
rollback;
