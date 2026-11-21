-- C95 (migration 604): Group By «Người lập» (Báo giá), «Sale» (Đơn hàng), «Hình thức» (Phiếu chi) và bộ lọc mở nhóm; giữ phạm vi, chặn trường lạ, giáo viên bị chặn. Dựng theo test 432, 433, 436: trùng cấp, không quyền. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@c95.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@c95.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code) select id, case when key = 'admin' then 'ADMIN' else 'TEACHER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

-- Ba đơn giả: hai Nháp, một Đã duyệt, cơ sở CS5; một đơn Nháp cơ sở CS1.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHC95', 'Phụ huynh giả C95', '0900095001', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$insert into app.sales_order (code, branch_id, parent_id, status_code, priced_on, total_amount, renewal_ticket_id)
  select v.c, (select id from app.branch where code = v.b), (select id from app.parent where code = 'PHC95'), v.s, current_date, 1000000, gen_random_uuid()
    from (values ('DHC95-1', 'CS5', 'NHAP'), ('DHC95-2', 'CS5', 'NHAP'), ('DHC95-3', 'CS5', 'DA_DUYET'), ('DHC95-4', 'CS1', 'NHAP')) v (c, b, s)$$);

-- Báo giá giả (bỏ kiểm khoá ngoại bằng replica để khỏi dựng cơ hội): hai Nháp, một Đã gửi (chưa chuyển hết), cơ sở CS5; một Nháp cơ sở CS1.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHC95B', 'Phụ huynh giả C95B', '0900095002', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$set local session_replication_role = 'replica'$$);
select pg_temp.sudo($$insert into app.quotation (code, branch_id, opportunity_id, parent_id, status_code, priced_on, total_amount, valid_until)
  select v.c, (select id from app.branch where code = v.b), gen_random_uuid(), (select id from app.parent where code = 'PHC95B'), v.s, current_date, 1000000, current_date + 7
    from (values ('BGC95-1', 'CS5', 'NHAP'), ('BGC95-2', 'CS5', 'NHAP'), ('BGC95-3', 'CS5', 'DA_GUI'), ('BGC95-4', 'CS1', 'NHAP')) v (c, b, s)$$);
select pg_temp.sudo($$set local session_replication_role = 'origin'$$);

-- Phiếu chi giả (bỏ kiểm khoá ngoại bằng replica để khỏi dựng chuỗi hoàn phí): ba phiếu CS5 (hai Chờ chi, một Đã chi) và một Chờ chi CS1.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHC95E', 'Phụ huynh giả C95E', '0900095005', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$set local session_replication_role = 'replica'$$);
select pg_temp.sudo($$insert into app.refund_request (id, enrollment_id, student_id, branch_id, kind_code, reason_code, hours_refund, paid_amount, hours_used, unit_price_base, unit_price_net, base_amount, fee_percent, fee_amount, refund_amount, status_code, ticket_ref)
  select gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), (select id from app.branch where code = v.b), 'TOAN_BO', 'KHAC', 1, 100000, 0, 100000, 100000, 100000, 0, 0, 100000, 'DA_DUYET', 'DNC95-' || v.c
    from (values (1, 'CS5'), (2, 'CS5'), (3, 'CS5'), (4, 'CS1')) v (c, b)$$);
select pg_temp.sudo($$insert into app.payment_voucher (code, refund_request_id, branch_id, parent_id, amount, status_code, paid_at)
  select 'PCC95-' || substr(r.ticket_ref, 7), r.id, r.branch_id, (select id from app.parent where code = 'PHC95E'), 100000,
         case when r.ticket_ref = 'DNC95-3' then 'DA_CHI' else 'CHO_CHI' end, case when r.ticket_ref = 'DNC95-3' then now() end
    from app.refund_request r where r.ticket_ref like 'DNC95-%'$$);
select pg_temp.sudo($$set local session_replication_role = 'origin'$$);


select pg_temp.sudo($$set local session_replication_role = 'replica'$$);
-- Người lập: admin lập hai đơn Nháp CS5 và đơn CS1, giáo viên giả (gv5) lập đơn Đã duyệt; tương tự báo giá. Phiếu chi: hình thức chi gán sau.
select pg_temp.sudo(format($$update app.sales_order set created_by = %L where code in ('DHC95-1', 'DHC95-2', 'DHC95-4')$$, pg_temp.uid('admin')));
select pg_temp.sudo(format($$update app.sales_order set created_by = %L where code = 'DHC95-3'$$, pg_temp.uid('gv5')));
select pg_temp.sudo(format($$update app.quotation set created_by = %L where code in ('BGC95-1', 'BGC95-2', 'BGC95-4')$$, pg_temp.uid('admin')));
select pg_temp.sudo(format($$update app.quotation set created_by = %L where code = 'BGC95-3'$$, pg_temp.uid('gv5')));
select pg_temp.sudo($$update app.payment_voucher set payment_method_code = 'CHUYEN_KHOAN' where code in ('PCC95-1', 'PCC95-2')$$);
select pg_temp.sudo($$update app.payment_voucher set payment_method_code = 'TIEN_MAT' where code = 'PCC95-3'$$);
select pg_temp.sudo($$set local session_replication_role = 'origin'$$);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
-- ===== BH-06 Đơn hàng: nhóm Sale =====
select is((select (g ->> 'count')::int from jsonb_array_elements(app.order_group_counts('{"q": "DHC95"}'::jsonb, array['sale']) -> 'groups') g where g ->> 'k1' = pg_temp.uid('admin')::text), 3, 'Group By Sale: admin lập 3 đơn');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.order_group_counts('{"q": "DHC95"}'::jsonb, array['sale']) -> 'groups') g where g ->> 'k1' = pg_temp.uid('gv5')::text), 1, 'Group By Sale: người kia lập 1 đơn');
select is((select g ->> 'l1' from jsonb_array_elements(app.order_group_counts('{"q": "DHC95"}'::jsonb, array['sale']) -> 'groups') g where g ->> 'k1' = pg_temp.uid('admin')::text), 'Giả admin', 'Nhãn nhóm Sale là tên người lập');
select is((app.list_orders(jsonb_build_object('q', 'DHC95', 'creator_id', pg_temp.uid('gv5'))) ->> 'total')::int, 1, 'Mở nhóm Sale: list_orders lọc theo creator_id');
select is((app.order_group_counts(jsonb_build_object('q', 'DHC95', 'creator_id', pg_temp.uid('gv5')), array['status']) ->> 'total')::int, 1, 'Số đếm nhóm khớp danh sách với cùng creator_id');
select is(pg_temp.err($$select app.order_group_counts('{}'::jsonb, array['creator'])$$), 'HMT_NHOM_SAI', 'Chặn: Đơn hàng không nhóm theo creator');
-- ===== BH-01 Báo giá: nhóm Người lập =====
select is((select (g ->> 'count')::int from jsonb_array_elements(app.quotation_group_counts(jsonb_build_object('parent_id', (select id from app.parent where code = 'PHC95B')), array['creator']) -> 'groups') g where g ->> 'k1' = pg_temp.uid('admin')::text), 3, 'Group By Người lập: admin lập 3 báo giá');
select is((select g ->> 'l1' from jsonb_array_elements(app.quotation_group_counts(jsonb_build_object('parent_id', (select id from app.parent where code = 'PHC95B')), array['creator']) -> 'groups') g where g ->> 'k1' = pg_temp.uid('gv5')::text), 'Giả gv5', 'Nhãn nhóm Người lập là tên người lập');
select is((app.list_quotations(jsonb_build_object('parent_id', (select id from app.parent where code = 'PHC95B'), 'creator_id', pg_temp.uid('gv5'))) ->> 'total')::int, 1, 'Mở nhóm Người lập: list_quotations lọc theo creator_id');
select is(pg_temp.err($$select app.quotation_group_counts('{}'::jsonb, array['sale'])$$), 'HMT_NHOM_SAI', 'Chặn: Báo giá không nhóm theo sale');
-- ===== TC-10 Phiếu chi: nhóm Hình thức =====
select is((select (g ->> 'count')::int from jsonb_array_elements(app.voucher_group_counts('{"q": "PCC95"}'::jsonb, array['method']) -> 'groups') g where g ->> 'k1' = 'CHUYEN_KHOAN'), 2, 'Group By Hình thức: 2 phiếu chuyển khoản');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.voucher_group_counts('{"q": "PCC95"}'::jsonb, array['method']) -> 'groups') g where g ->> 'k1' = ''), 1, 'Phiếu chưa ghi hình thức vào nhóm «Chưa có»');
select is((select g ->> 'l1' from jsonb_array_elements(app.voucher_group_counts('{"q": "PCC95"}'::jsonb, array['method']) -> 'groups') g where g ->> 'k1' = 'TIEN_MAT'), (select name from app.catalog_item where catalog_code = 'PAYMENT_METHOD' and code = 'TIEN_MAT'), 'Nhãn nhóm là tên hình thức trong danh mục');
select is((app.list_payment_vouchers('{"q": "PCC95", "payment_method": ["CHUYEN_KHOAN"]}'::jsonb) ->> 'total')::int, 2, 'Mở nhóm Hình thức: list_payment_vouchers lọc payment_method');
select is((app.voucher_group_counts('{"q": "PCC95", "payment_method": ["CHUYEN_KHOAN"]}'::jsonb, array['status']) ->> 'total')::int, 2, 'Số đếm nhóm khớp danh sách với cùng payment_method');
select is(pg_temp.err($$select app.voucher_group_counts('{}'::jsonb, array['creator'])$$), 'HMT_NHOM_SAI', 'Chặn: Phiếu chi không nhóm theo creator');
-- ===== Quyền =====
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$select app.order_group_counts('{}'::jsonb, array['sale'])$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không xem được đơn hàng');
select is(pg_temp.err($$select app.quotation_group_counts('{}'::jsonb, array['creator'])$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không xem được báo giá');
select is(pg_temp.err($$select app.voucher_group_counts('{}'::jsonb, array['method'])$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không xem được phiếu chi');

select * from finish();
rollback;
