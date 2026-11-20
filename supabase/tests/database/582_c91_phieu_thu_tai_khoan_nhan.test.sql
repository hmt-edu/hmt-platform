-- C91 (migration 582): Tài khoản nhận của phiếu thu (TC-17, TC-02): app.set_receipt_receiving_account và get_receipt.
-- Luật: người lập (phiếu Nháp) hoặc Kế toán (Đã gửi, Chờ kế toán) chọn được; không bắt buộc; danh mục RECEIVING_ACCOUNT; phiếu đã duyệt dùng TC-15. Dữ liệu giả.
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
create function pg_temp.msg(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
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
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Phiếu Thu', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('bm1b'), ('sales1'), ('sales5'), ('ke');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@c91.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@c91.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm1b', 'CS1'), ('sales1', 'CS1'), ('sales5', 'CS5'), ('ke', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm1b', 'BRANCH_MANAGER'), ('sales1', 'SALES'),
  ('sales5', 'SALES'), ('ke', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$create function pg_temp.pkg(p_code text) returns uuid language sql stable security definer as 'select id from app.sales_package where code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.term(p_code text) returns uuid language sql stable security definer as 'select id from app.payment_term where code = p_code and version = 1'$$);
select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as 'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone'$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable security definer as 'select id from app.lead where parent_phone = p_phone order by code limit 1'$$);
select pg_temp.sudo($$create function pg_temp.ps(p_phone text, p_pos integer) returns uuid language sql stable security definer as
  'select ps.id from app.prospect_student ps where ps.opportunity_id = pg_temp.oid(p_phone) and ps.position = p_pos'$$);
select pg_temp.sudo($$grant execute on function pg_temp.pkg(text), pg_temp.term(text), pg_temp.oid(text), pg_temp.lid(text), pg_temp.ps(text, integer) to public$$);
create function pg_temp.line(p_ps uuid, p_pkg text, p_mode text, p_qty numeric) returns jsonb language sql as $$
  select jsonb_build_object('kind', 'ENROL', 'prospect_student_id', p_ps, 'package_id', pg_temp.pkg(p_pkg), 'delivery_mode_code', p_mode,
                            'quantity', p_qty, 'discounts', '[]'::jsonb) $$;
grant execute on function pg_temp.line(uuid, text, text, numeric) to public;
create temp table os (key text primary key, id uuid);
grant all on os to public;
create temp table rs (key text primary key, id uuid);
grant all on rs to public;
create function pg_temp.o(p_key text) returns uuid language sql stable as $$ select id from os where key = p_key $$;
create function pg_temp.r(p_key text) returns uuid language sql stable as $$ select id from rs where key = p_key $$;
grant execute on function pg_temp.o(text), pg_temp.r(text) to public;
-- Tạo phiếu thu, nhớ theo khoá.
create function pg_temp.mkr(p_key text, p_order text, p_data jsonb) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  v := app.create_receipt(pg_temp.o(p_order), p_data);
  insert into rs values (p_key, (v ->> 'id')::uuid);
  return v;
end $$;
grant execute on function pg_temp.mkr(text, text, jsonb) to public;
select pg_temp.sudo($$create function pg_temp.rst(p_key text) returns text language sql stable security definer as 'select status_code from app.receipt where id = pg_temp.r(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.rev(p_key text) returns text language sql stable security definer as
  'select string_agg(event_code, '','' order by seq) from app.receipt_event where receipt_id = pg_temp.r(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.paid(p_key text) returns bigint language sql stable security definer as 'select app.order_paid_amount(pg_temp.o(p_key))'$$);
select pg_temp.sudo($$grant execute on function pg_temp.rst(text), pg_temp.rev(text), pg_temp.paid(text) to public$$);

-- ================= Dựng đơn =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900007001', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900007002', '{"student_name": "Em Hai", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900007001'));
select app.create_opportunity(pg_temp.lid('0900007002'));
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Ba', 2014 from app.opportunity o where o.id = pg_temp.oid('0900007002')$$);
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in (pg_temp.oid('0900007001'), pg_temp.oid('0900007002'))$$);
-- Đơn d1: một dòng 10 giờ × 220.000 = 2.200.000, điều khoản cọc 1.000.000 + 1.200.000. Đơn d2: hai dòng 10 giờ (2.200.000) và 5 giờ (1.100.000) = 3.300.000.
create function pg_temp.mkorder(p_key text, p_phone text, p_lines jsonb, p_term text) returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_order_from_opportunity(pg_temp.oid(p_phone), p_lines, null, true);
  insert into os values (p_key, (v ->> 'id')::uuid);
  perform app.save_order((v ->> 'id')::uuid, null, pg_temp.term(p_term));
end $$;
grant execute on function pg_temp.mkorder(text, text, jsonb, text) to public;
select pg_temp.mkorder('d1', '0900007001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900007001', 1), 'LC-TOAN-K09', 'OFF', 10)), 'COC_VA_CHIA_DOT');
select pg_temp.mkorder('d2', '0900007002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900007002', 1), 'LC-TOAN-K09', 'OFF', 10),
                                                              pg_temp.line(pg_temp.ps('0900007002', 2), 'LC-TOAN-K09', 'OFF', 5)), 'CHIA_3_DOT');

-- ================= R-TIEN-02: phiếu thu chỉ tạo từ đơn Đã duyệt =================
select is(pg_temp.err($$select app.create_receipt(pg_temp.o('d1'), '{"amount": 1000000, "payment_method_code": "TIEN_MAT"}')$$),
          'HMT_DON_CHUA_DUYET', 'R-TIEN-02: đơn Nháp chưa tạo được phiếu thu');
select app.submit_order(pg_temp.o('d1'));
select app.submit_order(pg_temp.o('d2'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_order(pg_temp.o('d1'));
select app.approve_order(pg_temp.o('d2'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= Tài khoản nhận (migration 582) =================
select pg_temp.sudo($$insert into app.catalog_item (catalog_code, code, name, sort_order) values ('RECEIVING_ACCOUNT', 'VCB_3456', 'Vietcombank …3456', 1), ('RECEIVING_ACCOUNT', 'TCB_1122', 'Techcombank …1122', 2)$$);
select pg_temp.sudo($$create function pg_temp.racc(p_id uuid) returns text language sql stable security definer as 'select receiving_account_code from app.receipt where id = p_id'$$);
select pg_temp.sudo($$grant execute on function pg_temp.racc(uuid) to public$$);
select pg_temp.mkr('p1', 'd2', '{"amount": 1650000, "payment_method_code": "CHUYEN_KHOAN"}');
-- Người lập chọn khi phiếu Nháp.
select is(pg_temp.racc(pg_temp.r('p1')), null, 'Không bắt buộc: phiếu mới chưa có tài khoản nhận');
select lives_ok($$select app.set_receipt_receiving_account(pg_temp.r('p1'), 'VCB_3456')$$, 'Đúng: người lập chọn tài khoản nhận khi phiếu Nháp');
select is(pg_temp.racc(pg_temp.r('p1')), 'VCB_3456', 'Đã lưu mã tài khoản nhận');
select is(app.get_receipt(pg_temp.r('p1')) ->> 'receiving_account_code', 'VCB_3456', 'get_receipt trả mã tài khoản nhận');
select is(app.get_receipt(pg_temp.r('p1')) ->> 'receiving_account', 'Vietcombank …3456', 'get_receipt trả tên tài khoản nhận');
select lives_ok($$select app.set_receipt_receiving_account(pg_temp.r('p1'), null)$$, 'Đúng: bỏ chọn tài khoản nhận');
select is(pg_temp.racc(pg_temp.r('p1')), null, 'Bỏ chọn thì về trống');
select is(pg_temp.err($$select app.set_receipt_receiving_account(pg_temp.r('p1'), 'KHONG_CO')$$), 'HMT_TAI_KHOAN_NHAN_KHONG_HOP_LE', 'Chặn: tài khoản ngoài danh mục');
select pg_temp.sudo($$update app.catalog_item set is_active = false where catalog_code = 'RECEIVING_ACCOUNT' and code = 'TCB_1122'$$);
select is(pg_temp.err($$select app.set_receipt_receiving_account(pg_temp.r('p1'), 'TCB_1122')$$), 'HMT_TAI_KHOAN_NHAN_KHONG_HOP_LE', 'Chặn: tài khoản đã Ngừng');
select is(pg_temp.err($$select app.set_receipt_receiving_account(gen_random_uuid(), 'VCB_3456')$$), 'HMT_KHONG_TIM_THAY', 'Chặn: phiếu không tồn tại');
-- Người khác (Sale cơ sở khác) bị chặn.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.set_receipt_receiving_account(pg_temp.r('p1'), 'VCB_3456')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Sale cơ sở khác không ghi được');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
-- Đã gửi: người lập hết quyền, Kế toán chọn được.
select lives_ok($$select app.set_receipt_receiving_account(pg_temp.r('p1'), 'VCB_3456')$$, 'Người lập chọn lại khi còn Nháp');
select app.submit_receipt(pg_temp.r('p1'));
select is(pg_temp.err($$select app.set_receipt_receiving_account(pg_temp.r('p1'), null)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: người lập không đổi được sau khi gửi');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select lives_ok($$select app.set_receipt_receiving_account(pg_temp.r('p1'), null)$$, 'Đúng: Kế toán đổi tài khoản nhận khi phiếu Đã gửi');
select is(pg_temp.racc(pg_temp.r('p1')), null, 'Kế toán đã xoá tài khoản nhận');
select lives_ok($$select app.set_receipt_receiving_account(pg_temp.r('p1'), 'VCB_3456')$$, 'Kế toán chọn tài khoản nhận');
-- Phiếu Đã duyệt: khoá.
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_receipt_manager(pg_temp.r('p1'));
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select lives_ok($$select app.set_receipt_receiving_account(pg_temp.r('p1'), 'VCB_3456')$$, 'Kế toán vẫn chọn được khi phiếu Chờ kế toán');
select app.approve_receipt_accounting(pg_temp.r('p1'));
select is(pg_temp.err($$select app.set_receipt_receiving_account(pg_temp.r('p1'), null)$$), 'HMT_PHIEU_THU_DA_KHOA', 'Chặn: phiếu Đã duyệt không đổi ở đây (dùng TC-15)');

select * from finish();
rollback;
