-- C69 (migration 436): Group By ở máy chủ cho danh sách Phiếu chi (voucher_group_counts) và vỏ bọc list_payment_vouchers_grouped: đếm theo tình trạng, cơ sở, hai cấp, bộ lọc; chặn trường lạ, trùng cấp, không quyền. Dữ liệu giả.
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

-- Phiếu chi giả (bỏ kiểm khoá ngoại bằng replica để khỏi dựng chuỗi hoàn phí): ba phiếu CS5 (hai Chờ chi, một Đã chi) và một Chờ chi CS1.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHC69E', 'Phụ huynh giả C69E', '0900069005', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$set local session_replication_role = 'replica'$$);
select pg_temp.sudo($$insert into app.refund_request (id, enrollment_id, student_id, branch_id, kind_code, reason_code, hours_refund, paid_amount, hours_used, unit_price_base, unit_price_net, base_amount, fee_percent, fee_amount, refund_amount, status_code, ticket_ref)
  select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), (select id from app.branch where code = v.b), 'TOAN_BO', 'KHAC', 1, 100000, 0, 100000, 100000, 100000, 0, 0, 100000, 'DA_DUYET', 'DNC69-' || v.c
    from (values (1, 'CS5'), (2, 'CS5'), (3, 'CS5'), (4, 'CS1')) v (c, b)$$);
select pg_temp.sudo($$insert into app.payment_voucher (code, refund_request_id, branch_id, parent_id, amount, status_code, paid_at)
  select 'PCC69-' || substr(r.ticket_ref, 7), r.id, r.branch_id, (select id from app.parent where code = 'PHC69E'), 100000,
         case when r.ticket_ref = 'DNC69-3' then 'DA_CHI' else 'CHO_CHI' end, case when r.ticket_ref = 'DNC69-3' then now() end
    from app.refund_request r where r.ticket_ref like 'DNC69-%'$$);
select pg_temp.sudo($$set local session_replication_role = 'origin'$$);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.voucher_group_counts('{"q": "PCC69"}'::jsonb, array['status']) ->> 'total')::int, 4, 'Group By tình trạng: tổng 4 phiếu chi giả');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.voucher_group_counts('{"q": "PCC69"}'::jsonb, array['status']) -> 'groups') g where g ->> 'k1' = 'CHO_CHI'), 3, 'Nhóm Chờ chi có 3 phiếu');
select is((select g ->> 'l1' from jsonb_array_elements(app.voucher_group_counts('{"q": "PCC69"}'::jsonb, array['status']) -> 'groups') g where g ->> 'k1' = 'DA_CHI'), 'Đã chi', 'Nhãn nhóm Đã chi');
select is(jsonb_array_length(app.voucher_group_counts('{"q": "PCC69"}'::jsonb, array['status', 'branch']) -> 'groups'), 3, 'Hai cấp tình trạng, cơ sở: ba nhóm lá');
select is((app.voucher_group_counts('{"q": "PCC69", "status": ["DA_CHI"]}'::jsonb, array['branch']) ->> 'total')::int, 1, 'Bộ lọc tình trạng áp dụng cho số đếm');
select is((app.list_payment_vouchers_grouped('{"q": "PCC69", "status": ["CHO_CHI"]}'::jsonb, 'created_desc', 50, 0) ->> 'total')::int, 3, 'Vỏ bọc mở nhóm lá trả đúng 3 phiếu Chờ chi');
select is(pg_temp.err($$select app.voucher_group_counts('{}'::jsonb, array['creator'])$$), 'HMT_NHOM_SAI', 'Chặn: trường nhóm không cho phép (hình thức chưa có dữ liệu)');
select is(pg_temp.err($$select app.voucher_group_counts('{}'::jsonb, array['status', 'status'])$$), 'HMT_NHOM_SAI', 'Chặn: hai cấp giống nhau');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$select app.voucher_group_counts('{}'::jsonb, array['status'])$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không có quyền xem phiếu chi');

select * from finish();
rollback;
