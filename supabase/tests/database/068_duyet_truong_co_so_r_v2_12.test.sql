-- R-V2-12 (Q-114, Q-115, Q-117, Q-118, Q-120): người lập chưa có quản lý trực tiếp vẫn trình được, đi tới Trưởng cơ sở của cơ sở (phiếu thu rồi tới Kế toán).
-- Migration 083: approval_route nhận cơ sở, route TRUONG_CS (người chốt để trống), can_approve_as_manager, hàng chờ, get_order, get_receipt.
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai đọc, ghi trong và ngoài cơ sở.
-- Mỗi luật có ca đúng và ca bị chặn; vai đọc, ghi trong và ngoài phạm vi. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('bm1'), ('bm1b'), ('bm5'), ('sales1'), ('sales1b'), ('sales5'), ('ke');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@b2.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@b2.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm1b', 'CS1'), ('bm5', 'CS5'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'), ('ke', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm1b', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('sales1', 'SALES'),
  ('sales1b', 'SALES'), ('sales5', 'SALES'), ('ke', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
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

-- Dựng một đơn Nháp từ cơ hội và lưu điều khoản thanh toán.
create function pg_temp.mkorder(p_key text, p_phone text, p_lines jsonb, p_term text) returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_order_from_opportunity(pg_temp.oid(p_phone), p_lines, null, true);
  insert into os values (p_key, (v ->> 'id')::uuid);
  perform app.save_order((v ->> 'id')::uuid, null, pg_temp.term(p_term));
end $$;
grant execute on function pg_temp.mkorder(text, text, jsonb, text) to public;

-- Giúp đọc route, người chốt, trạng thái của đơn và phiếu (quyền chủ DB).
select pg_temp.sudo($$create function pg_temp.oroute(p_key text) returns text language sql stable security definer as 'select approval_route from app.sales_order where id = pg_temp.o(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.oappr(p_key text) returns uuid language sql stable security definer as 'select assigned_approver_id from app.sales_order where id = pg_temp.o(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.ost(p_key text) returns text language sql stable security definer as 'select status_code from app.sales_order where id = pg_temp.o(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.rroute(p_key text) returns text language sql stable security definer as 'select approval_route from app.receipt where id = pg_temp.r(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.rappr(p_key text) returns uuid language sql stable security definer as 'select assigned_approver_id from app.receipt where id = pg_temp.r(p_key)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oroute(text), pg_temp.oappr(text), pg_temp.ost(text), pg_temp.rroute(text), pg_temp.rappr(text) to public$$);
-- Chỉ bộ giả này là Trưởng cơ sở trong bài (tài khoản giả khác trong DB local không ảnh hưởng).
select pg_temp.sudo($$update app.user_role set is_active = false where role_code = 'BRANCH_MANAGER' and is_active and user_id not in (select id from u)$$);

-- ================= Dựng dữ liệu =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
-- sales1b KHÔNG có quản lý trực tiếp. Cơ sở CS1 có hai Trưởng cơ sở (bm1, bm1b); CS5 có bm5.
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900007101', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900007102', '{"student_name": "Em Hai", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900007103', '{"student_name": "Em Ba", "student_birth_year": 2012}'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900007104', '{"student_name": "Em Bốn", "student_birth_year": 2012}'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900007105', '{"student_name": "Em Năm", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900007101'));
select app.create_opportunity(pg_temp.lid('0900007102'));
select app.create_opportunity(pg_temp.lid('0900007103'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900007104'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900007105'));
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in (pg_temp.oid('0900007101'),
  pg_temp.oid('0900007102'), pg_temp.oid('0900007103'), pg_temp.oid('0900007104'), pg_temp.oid('0900007105'))$$);
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select pg_temp.mkorder('t1', '0900007101', jsonb_build_array(pg_temp.line(pg_temp.ps('0900007101', 1), 'LC-TOAN-K09', 'OFF', 10)), 'CHIA_3_DOT');
select pg_temp.mkorder('t2', '0900007102', jsonb_build_array(pg_temp.line(pg_temp.ps('0900007102', 1), 'LC-TOAN-K09', 'OFF', 10)), 'CHIA_3_DOT');
select pg_temp.mkorder('t3', '0900007103', jsonb_build_array(pg_temp.line(pg_temp.ps('0900007103', 1), 'LC-TOAN-K09', 'OFF', 10)), 'CHIA_3_DOT');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mkorder('q1', '0900007104', jsonb_build_array(pg_temp.line(pg_temp.ps('0900007104', 1), 'LC-TOAN-K09', 'OFF', 10)), 'CHIA_3_DOT');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkorder('b1', '0900007105', jsonb_build_array(pg_temp.line(pg_temp.ps('0900007105', 1), 'LC-TOAN-K09', 'OFF', 10)), 'CHIA_3_DOT');

-- ================= (1) Đơn: người lập không có quản lý trình tới Trưởng cơ sở (R-V2-12, Q-114) =================
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('t1'))$$), null, 'R-V2-12: Sale không có quản lý trực tiếp trình được đơn');
select is(pg_temp.ost('t1'), 'DA_TRINH', 'R-V2-12: đơn thành Đã trình');
select is(pg_temp.oroute('t1'), 'TRUONG_CS', 'R-V2-12: đường duyệt TRUONG_CS');
select is(pg_temp.oappr('t1'), null, 'Q-117: người duyệt không chốt một người (để trống)');
select is(app.get_order(pg_temp.o('t2')) ->> 'expected_route', 'TRUONG_CS', 'R-V2-12: đơn Nháp báo trước đường duyệt TRUONG_CS');
select is(app.get_order(pg_temp.o('t2')) ->> 'expected_block', null, 'R-V2-12: có Trưởng cơ sở nên không còn chặn Trình (hết ca chưa có quản lý)');
-- ================= (2) Hồi quy: có quản lý vẫn đi qua quản lý; Trưởng cơ sở lập vẫn tự duyệt =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('q1'))$$), null, 'Hồi quy: Sale có quản lý trình được');
select is(pg_temp.oroute('q1'), 'QUAN_LY', 'Hồi quy R-HT-06: Sale có quản lý vẫn đi qua quản lý (QUAN_LY)');
select is(pg_temp.oappr('q1'), pg_temp.uid('bm1'), 'Hồi quy R-HT-06: người duyệt chốt là quản lý trực tiếp');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('b1'))$$), null, 'Hồi quy: Trưởng cơ sở trình đơn mình lập');
select is(pg_temp.oroute('b1'), 'TU_DUYET', 'Hồi quy R-HT-06: Trưởng cơ sở lập vẫn tự duyệt (TU_DUYET)');
select is(pg_temp.ost('b1'), 'DA_DUYET', 'Hồi quy R-HT-06: đơn của Trưởng cơ sở tự duyệt ngay');
-- ================= (3) Hàng chờ: mọi Trưởng cơ sở của cơ sở thấy; cơ sở khác không thấy =================
select is((app.list_orders('{"waiting_me": true}') ->> 'total')::int, 2, 'Q-117: Trưởng cơ sở bm1 thấy cả đơn chờ quản lý (q1) và đơn TRUONG_CS (t1)');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is((app.list_orders('{"waiting_me": true}') ->> 'total')::int, 1, 'Q-117: Trưởng cơ sở bm1b thấy đơn TRUONG_CS (t1), không thấy đơn chờ riêng bm1 (q1)');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((app.list_orders('{"waiting_me": true}') ->> 'total')::int, 0, 'R-V2-12: Trưởng cơ sở CS5 không thấy đơn chờ của CS1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('t1'))$$), 'HMT_KHONG_CO_QUYEN', 'R-V2-12: Trưởng cơ sở cơ sở khác không duyệt được đơn TRUONG_CS');
-- Sale thường (cùng cơ sở, không phải Trưởng cơ sở, kể cả người lập đơn) không duyệt được đơn route TRUONG_CS (R-V2-12).
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('t1'))$$), 'HMT_KHONG_CO_QUYEN', 'R-V2-12: Sale thường cùng cơ sở không duyệt được đơn TRUONG_CS');
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('t1'))$$), 'HMT_KHONG_CO_QUYEN', 'R-V2-12: người lập (Sale) không tự duyệt được đơn TRUONG_CS của mình');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is((app.get_order(pg_temp.o('t1')) ->> 'can_approve')::boolean, true, 'R-V2-12: Trưởng cơ sở cùng cơ sở có cờ can_approve');
-- ================= (4) Ai duyệt trước thì có hiệu lực; người sau không còn thấy =================
select is(pg_temp.err($$select app.approve_order(pg_temp.o('t1'))$$), null, 'Q-117: bm1b duyệt đơn TRUONG_CS thành công');
select is(pg_temp.ost('t1'), 'DA_DUYET', 'Q-117: đơn thành Đã duyệt');
select is((select approved_by from app.sales_order where id = pg_temp.o('t1')), pg_temp.uid('bm1b'), 'Q-117: ghi đúng người duyệt thật (bm1b)');
select is((select approved_on_behalf from app.sales_order where id = pg_temp.o('t1')), false, 'Q-117: Trưởng cơ sở duyệt đơn TRUONG_CS không bị tính là duyệt thay');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('t1'))$$), 'HMT_SAI_TRANG_THAI', 'Q-117: bm1 duyệt sau thì gặp lỗi sai trạng thái, không duyệt hai lần');
select is((app.list_orders('{"waiting_me": true}') ->> 'total')::int, 1, 'Q-117: A duyệt thì B không còn thấy đơn đó trong hàng chờ (chỉ còn đơn q1 của riêng bm1)');
-- ================= (5) Admin duyệt thay đơn TRUONG_CS khi vắng (R-HT-01) =================
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select app.submit_order(pg_temp.o('t2'));
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('t2'))$$), null, 'R-HT-01: Admin (aal2) duyệt thay đơn TRUONG_CS');
select is((select approved_on_behalf from app.sales_order where id = pg_temp.o('t2')), true, 'R-HT-01: ghi duyệt thay');
-- ================= (6) Cơ sở chưa có Trưởng cơ sở nào: vẫn chặn, nói rõ lý do (Q-117) =================
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select pg_temp.sudo($$update app.user_role set is_active = false where role_code = 'BRANCH_MANAGER' and user_id in (select id from u where key in ('bm1', 'bm1b'))$$);
select is(pg_temp.err($$select app.submit_order(pg_temp.o('t3'))$$), 'HMT_KHONG_CO_QUAN_LY', 'R-V2-12: cơ sở không có Trưởng cơ sở nào đang hoạt động thì vẫn chặn Trình');
select ok(pg_temp.msg($$select app.submit_order(pg_temp.o('t3'))$$) like '%chưa có Trưởng cơ sở nào%', 'R-V2-12: câu chặn nói rõ cơ sở chưa có Trưởng cơ sở');
select is(app.get_order(pg_temp.o('t3')) ->> 'expected_block', 'KHONG_CO_QUAN_LY', 'R-V2-12: get_order báo trước ca chặn khi cơ sở chưa có Trưởng cơ sở');
select pg_temp.sudo($$update app.user_role set is_active = true where role_code = 'BRANCH_MANAGER' and user_id in (select id from u where key in ('bm1', 'bm1b'))$$);

-- ================= (7) Phiếu thu: Sale không có quản lý gửi tới Trưởng cơ sở rồi Kế toán =================
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select pg_temp.mkr('r1', 't1', '{"amount": 500000, "payment_method_code": "TIEN_MAT"}');
select is(pg_temp.err($$select app.submit_receipt(pg_temp.r('r1'))$$), null, 'R-V2-12: Sale không có quản lý gửi được phiếu thu');
select is(pg_temp.rst('r1'), 'DA_GUI', 'R-V2-12: phiếu thành Đã gửi');
select is(pg_temp.rroute('r1'), 'TRUONG_CS', 'R-V2-12: phiếu thu đi đường TRUONG_CS');
select is(pg_temp.rappr('r1'), null, 'Q-117: phiếu thu không chốt một người duyệt');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(jsonb_array_length(app.list_receipts('{"waiting_manager": true}') -> 'rows'), 1, 'Q-117: Trưởng cơ sở bm1 thấy phiếu TRUONG_CS trong hàng chờ');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(jsonb_array_length(app.list_receipts('{"waiting_manager": true}') -> 'rows'), 1, 'Q-117: Trưởng cơ sở bm1b cũng thấy phiếu đó');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(jsonb_array_length(app.list_receipts('{"waiting_manager": true}') -> 'rows'), 0, 'R-V2-12: Trưởng cơ sở CS5 không thấy phiếu CS1');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.approve_receipt_manager(pg_temp.r('r1'))$$), 'HMT_KHONG_CO_QUYEN', 'R-HT-01: Vai không có quyền duyệt tiền bị chặn ở bước quản lý của phiếu thu TRUONG_CS');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
-- Sale thường (cùng cơ sở, kể cả người lập phiếu) không duyệt được bước quản lý của phiếu route TRUONG_CS (R-V2-12).
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.approve_receipt_manager(pg_temp.r('r1'))$$), 'HMT_KHONG_CO_QUYEN', 'R-V2-12: Sale thường cùng cơ sở không duyệt được phiếu thu TRUONG_CS');
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is(pg_temp.err($$select app.approve_receipt_manager(pg_temp.r('r1'))$$), 'HMT_KHONG_CO_QUYEN', 'R-V2-12: người lập phiếu (Sale) không tự duyệt được bước quản lý của phiếu TRUONG_CS');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(pg_temp.err($$select app.approve_receipt_manager(pg_temp.r('r1'))$$), null, 'Q-117: Trưởng cơ sở bm1b duyệt bước quản lý phiếu thu');
select is(pg_temp.rst('r1'), 'CHO_KE_TOAN', 'R-V2-12: phiếu thu chuyển sang Chờ kế toán');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_receipt_manager(pg_temp.r('r1'))$$), 'HMT_SAI_TRANG_THAI', 'Q-117: bm1 duyệt sau thì gặp lỗi sai trạng thái');
select is(jsonb_array_length(app.list_receipts('{"waiting_manager": true}') -> 'rows'), 0, 'Q-117: phiếu đã duyệt không còn trong hàng chờ của người kia');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.approve_receipt_accounting(pg_temp.r('r1'))$$), null, 'R-V2-12: Kế toán duyệt bước cuối của phiếu TRUONG_CS');
select is(pg_temp.rst('r1'), 'DA_DUYET', 'R-V2-12: phiếu thu Đã duyệt');

select * from finish();
rollback;
