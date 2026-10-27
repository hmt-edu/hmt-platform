-- P5a-DB1b-2 (đơn hàng, hàm đọc và xuất): get_order, list_orders, export_orders; Đ105 (Xuất), Đ106, R-TIEN-02, 06, 07; R-HT-06.
-- Mỗi vai đọc trong và ngoài phạm vi; bộ lọc, phân trang, sắp xếp, xuất có nhật ký.
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
  select jsonb_build_object('parent_name', 'Chị Đơn Hàng', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('bm1b'), ('sales1'), ('sales1b'), ('sales1c'), ('cskh1'), ('sales5'), ('bm5'), ('ke'), ('hs');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999998' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm1b', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales1c', 'CS1'),
                      ('cskh1', 'CS1'), ('sales5', 'CS5'), ('bm5', 'CS5'), ('ke', 'CS1'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm1b', 'BRANCH_MANAGER'), ('sales1', 'SALES'),
  ('sales1b', 'SALES'), ('sales1c', 'SALES'), ('cskh1', 'CSKH'), ('sales5', 'SALES'), ('bm5', 'BRANCH_MANAGER'),
  ('ke', 'ACCOUNTANT'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- Bán hàng bật ở CS1 cho bài (Đ173); seed thường chỉ bật CS5.
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$create function pg_temp.pkg(p_code text) returns uuid language sql stable security definer as 'select id from app.sales_package where code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.pol(p_code text) returns uuid language sql stable security definer as 'select id from app.discount_policy where code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.term(p_code text) returns uuid language sql stable security definer as 'select id from app.payment_term where code = p_code and version = 1'$$);
select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as 'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone order by o.code limit 1'$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable security definer as 'select id from app.lead where parent_phone = p_phone order by code limit 1'$$);
select pg_temp.sudo($$create function pg_temp.ps(p_phone text, p_pos integer) returns uuid language sql stable security definer as
  'select ps.id from app.prospect_student ps where ps.opportunity_id = pg_temp.oid(p_phone) and ps.position = p_pos'$$);
select pg_temp.sudo($$grant execute on function pg_temp.pkg(text), pg_temp.pol(text), pg_temp.term(text), pg_temp.oid(text), pg_temp.lid(text),
  pg_temp.ps(text, integer) to public$$);
-- Một dòng nhập cho đơn thẳng từ cơ hội.
create function pg_temp.line(p_ps uuid, p_pkg text, p_mode text, p_qty numeric, p_disc jsonb default '[]'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('kind', 'ENROL', 'prospect_student_id', p_ps, 'package_id', pg_temp.pkg(p_pkg), 'delivery_mode_code', p_mode,
                            'quantity', p_qty, 'discounts', p_disc) $$;
grant execute on function pg_temp.line(uuid, text, text, numeric, jsonb) to public;
create function pg_temp.disc(p_policy text, p_value numeric default null) returns jsonb language sql as $$
  select jsonb_build_object('policy_id', pg_temp.pol(p_policy), 'value', p_value) $$;
grant execute on function pg_temp.disc(text, numeric) to public;
create temp table os (key text primary key, id uuid, code text);
grant all on os to public;
create temp table qs (key text primary key, id uuid, code text);
grant all on qs to public;
create function pg_temp.o(p_key text) returns uuid language sql stable as $$ select id from os where key = p_key $$;
create function pg_temp.q(p_key text) returns uuid language sql stable as $$ select id from qs where key = p_key $$;
grant execute on function pg_temp.o(text), pg_temp.q(text) to public;
-- Tạo đơn thẳng và nhớ theo khoá.
create function pg_temp.mk(p_key text, p_phone text, p_lines jsonb) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := app.create_order_from_opportunity(pg_temp.oid(p_phone), p_lines);
  insert into os values (p_key, (r ->> 'id')::uuid, r ->> 'code');
  return r;
end $$;
grant execute on function pg_temp.mk(text, text, jsonb) to public;
-- Trạng thái, người duyệt, các giá trị khác của đơn (đọc bằng quyền chủ).
select pg_temp.sudo($$create function pg_temp.st(p_key text) returns text language sql stable security definer as 'select status_code from app.sales_order where id = pg_temp.o(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.ev(p_key text) returns text language sql stable security definer as
  'select string_agg(event_code, '','' order by seq) from app.sales_order_event where order_id = pg_temp.o(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.qlive(p uuid) returns boolean language sql stable security definer as 'select app.quotation_has_live_order(p)'$$);
select pg_temp.sudo($$create function pg_temp.qconv(p uuid) returns boolean language sql stable security definer as 'select app.quotation_converted(p)'$$);
select pg_temp.sudo($$create function pg_temp.docs(p uuid) returns text[] language sql stable security definer as 'select app.opportunity_sales_documents(p)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.st(text), pg_temp.ev(text), pg_temp.qlive(uuid), pg_temp.qconv(uuid), pg_temp.docs(uuid) to public$$);

-- ================= Dựng dữ liệu =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
select app.set_manager(pg_temp.uid('sales1c'), pg_temp.uid('cskh1'));
select app.set_manager(pg_temp.uid('cskh1'), pg_temp.uid('bm1'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009001', '{"parent_name": "Chị Đơn Một", "student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900009002', '{"parent_name": "Chị Đơn Hai", "student_name": "Em Bốn", "student_birth_year": 2010}'));
select app.create_lead(pg_temp.lead_data('0900009003', '{"parent_name": "Chị Sinh Đôi", "student_name": "Em Sinh Đôi", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900009009', '{"parent_name": "Chị Chưa L8", "student_name": "Em Chín", "student_birth_year": 2012}'));
select pg_temp.claims(pg_temp.uid('sales1c'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009004', '{"parent_name": "Chị Quản Lý Thiếu Quyền", "student_name": "Em Năm", "student_birth_year": 2011}'));
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009006', '{"parent_name": "Chị Không Quản Lý", "student_name": "Em Sáu", "student_birth_year": 2011}'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009005', '{"parent_name": "Chị Tự Duyệt", "student_name": "Em Bảy", "student_birth_year": 2011}'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009099', '{"parent_name": "Chị Đơn CS5", "student_name": "Em Tám", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900009001'));
select app.create_opportunity(pg_temp.lid('0900009002'));
select app.create_opportunity(pg_temp.lid('0900009003'));
select app.create_opportunity(pg_temp.lid('0900009009'));
select pg_temp.claims(pg_temp.uid('sales1c'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900009004'));
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900009006'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900009005'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900009099'));
-- Em thứ hai (đủ), em thứ ba (thiếu năm sinh) của cơ hội 1; hai em trùng tên và năm sinh ở cơ hội 3 (KD6).
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Hai', 2014 from app.opportunity o where o.id = pg_temp.oid('0900009001')$$);
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name)
  select o.id, o.branch_id, 3, 'Em Ba' from app.opportunity o where o.id = pg_temp.oid('0900009001')$$);
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Sinh Đôi', 2012 from app.opportunity o where o.id = pg_temp.oid('0900009003')$$);
-- Các cơ hội đã thanh toán thật (L8), trừ 0900009009 giữ ở L1 (R-CRM-16).
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in
  (pg_temp.oid('0900009001'), pg_temp.oid('0900009002'), pg_temp.oid('0900009003'), pg_temp.oid('0900009004'),
   pg_temp.oid('0900009005'), pg_temp.oid('0900009006'), pg_temp.oid('0900009099'))$$);


-- ================= Dữ liệu: ba đơn CS1 ở ba trạng thái + một đơn huỷ + một đơn CS5 + một đơn từ báo giá =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('n1', '0900009001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_6_THANG'))),
                                                          pg_temp.line(pg_temp.ps('0900009001', 2), 'LC-TOAN-K09', 'OFF', 5)));
select pg_temp.mk('n2', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 20)));
select app.save_order(pg_temp.o('n2'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('n2'));
select pg_temp.mk('n3', '0900009003', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009003', 1), 'LC-TOAN-K09', 'OFF', 30)));
select app.save_order(pg_temp.o('n3'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('n3'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_order(pg_temp.o('n3'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('n4', '0900009004', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009004', 1), 'LC-TOAN-K09', 'OFF', 12)));
select app.cancel_order(pg_temp.o('n4'), 'KHAC', 'Nhập nhầm');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select pg_temp.mk('n5', '0900009099', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009099', 1), 'LC-TOAN-K09', 'OFF', 8)));
-- Đơn từ báo giá.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
insert into qs select 'q1', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009005'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009005', 1), 'LC-TOAN-K09', 'OFF', 6))) as r) x;
select app.send_quotation(pg_temp.q('q1'));
insert into os select 'n6', (r ->> 'id')::uuid, r ->> 'code' from (select app.create_order_from_quotation(pg_temp.q('q1')) as r) x;

-- Thời điểm tạo khác nhau theo số thứ tự mã (cùng một giao dịch nên now() trùng): số lớn hơn là mới hơn.
select pg_temp.sudo($$alter table app.sales_order disable trigger sales_order_fill_standard$$);
select pg_temp.sudo($$update app.sales_order set created_at = now() - (10 - right(code, 4)::int) * interval '1 hour' where code like 'DH-%'$$);
select pg_temp.sudo($$alter table app.sales_order enable trigger sales_order_fill_standard$$);

-- ================= get_order =================
select is(app.get_order(pg_temp.o('n1')) ->> 'code', (select code from os where key = 'n1'), 'get_order: trả mã đơn');
select is(app.get_order(pg_temp.o('n1')) ->> 'status', 'Nháp', 'get_order: tên trạng thái từ danh mục');
select is(jsonb_array_length(app.get_order(pg_temp.o('n1')) -> 'lines'), 2, 'get_order: hai dòng');
select is(app.get_order(pg_temp.o('n1')) -> 'lines' -> 0 ->> 'student_name', 'Em Một', 'get_order: tên em của dòng 1');
select is(app.get_order(pg_temp.o('n1')) -> 'lines' -> 1 ->> 'student_name', 'Em Hai', 'get_order: tên em của dòng 2');
select is(app.get_order(pg_temp.o('n1')) -> 'lines' -> 0 -> 'discounts' -> 0 ->> 'policy_code', 'GIAM_6_THANG', 'get_order: chiết khấu của dòng');
select is(app.get_order(pg_temp.o('n1')) -> 'lines' -> 0 ->> 'student_complete', 'true', 'get_order: em đủ thông tin');
select is(app.get_order(pg_temp.o('n1')) ->> 'has_incomplete_students', 'false', 'get_order: không có em thiếu thông tin');
select is(app.get_order(pg_temp.o('n1')) ->> 'parent_name', 'Chị Đơn Một', 'get_order: tên phụ huynh');
select is(app.get_order(pg_temp.o('n1')) ->> 'parent_phone', '0900009001', 'get_order: số điện thoại phụ huynh');
select is(app.get_order(pg_temp.o('n1')) ->> 'created_by_name', 'Giả sales1', 'get_order: người lập');
select ok(app.get_order(pg_temp.o('n1')) ? 'search_text' = false, 'get_order: không lộ ô tìm kiếm');
select is(app.get_order(pg_temp.o('n1')) ->> 'opportunity_code', (select code from app.opportunity where id = pg_temp.oid('0900009001')), 'get_order: mã cơ hội gốc');
select is(app.get_order(pg_temp.o('n1')) ->> 'quotation_code', null, 'get_order: đơn thẳng không có báo giá');
select is(app.get_order(pg_temp.o('n6')) ->> 'quotation_code', (select code from qs where key = 'q1'), 'get_order: đơn từ báo giá nêu mã báo giá');
select is(jsonb_array_length(app.get_order(pg_temp.o('n1')) -> 'installments'), 0, 'get_order: chưa chọn điều khoản thì chưa có lịch đóng tiền');
select is(jsonb_array_length(app.get_order(pg_temp.o('n2')) -> 'installments'), 3, 'get_order: lịch đóng tiền theo điều khoản ba đợt');
select is((select sum((x ->> 'amount')::bigint) from jsonb_array_elements(app.get_order(pg_temp.o('n2')) -> 'installments') x), 4400000::numeric, 'get_order: tổng các đợt bằng tổng đơn');
select is(app.get_order(pg_temp.o('n2')) ->> 'status', 'Đã trình', 'get_order: đơn Đã trình');
select is(app.get_order(pg_temp.o('n2')) ->> 'approver_name', 'Giả bm1', 'get_order: người duyệt đã chốt');
select is(app.get_order(pg_temp.o('n2')) ->> 'payment_term_name', (select name from app.payment_term where code = 'CHIA_3_DOT' and version = 1), 'get_order: tên điều khoản thanh toán');
select is(jsonb_array_length(app.get_order(pg_temp.o('n2')) -> 'events'), 2, 'get_order: lịch sử có tạo và trình');
select is(app.get_order(pg_temp.o('n2')) -> 'events' -> 0 ->> 'event_code', 'TAO', 'get_order: lịch sử đúng thứ tự (tạo trước)');
select is(app.get_order(pg_temp.o('n2')) -> 'events' -> 1 ->> 'event_code', 'TRINH', 'get_order: lịch sử đúng thứ tự (trình sau)');
select is(app.get_order(pg_temp.o('n2')) -> 'events' -> 1 ->> 'actor_name', 'Giả sales1', 'get_order: lịch sử ghi người thực hiện');
select is(app.get_order(pg_temp.o('n3')) ->> 'approved_by_name', 'Giả bm1', 'get_order: đơn Đã duyệt nêu người duyệt');
select is((select count(*)::int from jsonb_array_elements(app.get_order(pg_temp.o('n3')) -> 'installments') x where x ->> 'due_date' is not null), 3, 'get_order: đơn Đã duyệt có hạn đóng từng đợt');
select is(app.get_order(pg_temp.o('n4')) ->> 'cancel_reason', 'Khác', 'get_order: đơn huỷ nêu lý do');
select is(app.get_order(pg_temp.o('n4')) ->> 'cancel_note', 'Nhập nhầm', 'get_order: đơn huỷ nêu ghi chú');
select is(app.get_order(pg_temp.o('n4')) -> 'lines' -> 0 ->> 'is_live', 'false', 'get_order: dòng đơn huỷ không còn sống');
select is(pg_temp.err($$select app.get_order('00000000-0000-0000-0000-000000000000')$$), 'HMT_KHONG_TIM_THAY', 'get_order: đơn không có');
-- Phạm vi đọc.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.get_order(pg_temp.o('n1'))$$), 'HMT_KHONG_CO_QUYEN', 'get_order: Sale CS5 không đọc đơn CS1');
select is(pg_temp.err($$select app.get_order(pg_temp.o('n5'))$$), null, 'get_order: Sale CS5 đọc đơn cơ sở mình');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.get_order(pg_temp.o('n1'))$$), null, 'get_order: CSKH CS1 đọc đơn CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.get_order(pg_temp.o('n5'))$$), null, 'get_order: Kế toán đọc đơn mọi cơ sở');
select pg_temp.claims(pg_temp.uid('ke'), 'aal1');
select is(pg_temp.err($$select app.get_order(pg_temp.o('n5'))$$), 'HMT_KHONG_CO_QUYEN', 'get_order: Kế toán chưa xác thực hai bước (aal1) không đọc được');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.get_order(pg_temp.o('n1'))$$), 'HMT_KHONG_CO_QUYEN', 'get_order: học sinh không đọc đơn');
-- Đ173/Đ181: hàm đọc không chặn theo công tắc Bán hàng.
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.get_order(pg_temp.o('n1'))$$), null, 'Đ181: tắt Bán hàng vẫn đọc được bản ghi đơn');
select is(pg_temp.err($$select app.list_orders()$$), null, 'Đ181: tắt Bán hàng vẫn đọc được danh sách đơn');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);

-- ================= list_orders =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((app.list_orders() ->> 'total')::int, 5, 'list_orders: Sale CS1 thấy 5 đơn của cơ sở mình (không thấy đơn CS5)');
select is(jsonb_array_length(app.list_orders() -> 'rows'), 5, 'list_orders: số dòng trả về');
select is(app.list_orders() -> 'rows' -> 0 ->> 'code', (select code from os where key = 'n6'), 'list_orders: mặc định mới nhất trước');
select is((app.list_orders('{"status": ["DA_DUYET"]}') ->> 'total')::int, 1, 'list_orders: lọc Đã duyệt');
select is((app.list_orders('{"status": ["NHAP", "DA_TRINH"]}') ->> 'total')::int, 3, 'list_orders: lọc nhiều trạng thái (Nháp, Đã trình)');
select is((app.list_orders('{"status": ["HUY"]}') ->> 'total')::int, 1, 'list_orders: lọc Huỷ');
select is(app.list_orders('{"status": ["HUY"]}') -> 'rows' -> 0 ->> 'status', 'Huỷ', 'list_orders: tên trạng thái hiện');
select is((app.list_orders(jsonb_build_object('q', 'Đơn Một')) ->> 'total')::int, 1, 'list_orders: tìm theo tên phụ huynh (không dấu, hoa thường)');
select is((app.list_orders(jsonb_build_object('q', 'em hai')) ->> 'total')::int, 1, 'list_orders: tìm theo tên em');
select is((app.list_orders(jsonb_build_object('q', (select code from os where key = 'n2'))) ->> 'total')::int, 1, 'list_orders: tìm theo mã đơn');
select is((app.list_orders(jsonb_build_object('q', '0900009003')) ->> 'total')::int, 1, 'list_orders: tìm theo số điện thoại');
select is((app.list_orders(jsonb_build_object('q', 'khong co ai ten the')) ->> 'total')::int, 0, 'list_orders: không khớp thì rỗng');
select is((app.list_orders(jsonb_build_object('opportunity_id', pg_temp.oid('0900009001'))) ->> 'total')::int, 1, 'list_orders: lọc theo cơ hội');
select is((app.list_orders(jsonb_build_object('quotation_id', pg_temp.q('q1'))) ->> 'total')::int, 1, 'list_orders: lọc theo báo giá gốc');
select is((app.list_orders('{"mine": true}') ->> 'total')::int, 5, 'list_orders: "của tôi" (sales1 lập cả năm đơn CS1)');
select is((app.list_orders('{"waiting_me": true}') ->> 'total')::int, 0, 'list_orders: Sale không có đơn chờ mình duyệt');
select is((app.list_orders('{"limit_test": 1}', 'created_desc', 2, 0) ->> 'total')::int, 5, 'list_orders: tổng không đổi khi phân trang');
select is(jsonb_array_length(app.list_orders('{}', 'created_desc', 2, 0) -> 'rows'), 2, 'list_orders: trang đầu 2 dòng');
select is(jsonb_array_length(app.list_orders('{}', 'created_desc', 2, 4) -> 'rows'), 1, 'list_orders: trang cuối còn 1 dòng');
select is(app.list_orders('{}', 'total_desc') -> 'rows' -> 0 ->> 'code', (select code from os where key = 'n3'), 'list_orders: sắp xếp tổng tiền giảm dần (đơn 30 giờ lớn nhất)');
select is(app.list_orders('{}', 'created_asc') -> 'rows' -> 0 ->> 'code', (select code from os where key = 'n1'), 'list_orders: sắp xếp cũ nhất trước');
select is(jsonb_array_length(app.list_orders('{}', 'created_desc', 1000, 0) -> 'rows'), 5, 'list_orders: giới hạn trang không vượt tối đa (kiểm gián tiếp)');
select is(app.list_orders('{}') -> 'rows' -> 0 ? 'search_text', false, 'list_orders: không lộ ô tìm kiếm');
select is(app.list_orders(jsonb_build_object('q', 'Đơn Một')) -> 'rows' -> 0 ->> 'student_name', 'Em Một', 'list_orders: tên em của dòng đầu');
select is(app.list_orders(jsonb_build_object('q', 'Đơn Một')) -> 'rows' -> 0 ->> 'line_count', '2', 'list_orders: số dòng của đơn');
select is(app.list_orders(jsonb_build_object('q', (select code from os where key = 'n6'))) -> 'rows' -> 0 ->> 'quotation_code', (select code from qs where key = 'q1'), 'list_orders: đơn từ báo giá nêu mã báo giá');
-- Người duyệt đã chốt thấy đơn chờ mình.
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.list_orders('{"waiting_me": true}') ->> 'total')::int, 1, 'list_orders: Trưởng cơ sở thấy đúng 1 đơn chờ mình duyệt');
select is(app.list_orders('{"waiting_me": true}') -> 'rows' -> 0 ->> 'code', (select code from os where key = 'n2'), 'list_orders: đơn chờ duyệt là đơn Đã trình đã chốt người duyệt');
select is((app.list_orders('{"mine": true}') ->> 'total')::int, 0, 'list_orders: Trưởng cơ sở không lập đơn nào trong dữ liệu này');
-- Phạm vi.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((app.list_orders() ->> 'total')::int, 1, 'list_orders: Sale CS5 chỉ thấy đơn CS5');
select is(app.list_orders(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS1'))) ->> 'total', '0', 'list_orders: Sale CS5 lọc sang cơ sở khác vẫn không thấy');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is((app.list_orders() ->> 'total')::int, 6, 'list_orders: Kế toán thấy đơn mọi cơ sở');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.list_orders()$$), 'HMT_KHONG_CO_QUYEN', 'list_orders: học sinh không có quyền');

-- ================= export_orders (Đ105: Trưởng cơ sở trong cơ sở, Kế toán, Admin) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.export_orders()$$), 'HMT_KHONG_CO_QUYEN', 'Đ105: Sale không xuất được');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.export_orders()$$), 'HMT_KHONG_CO_QUYEN', 'Đ105: CSKH không xuất được');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.export_orders() ->> 'exported')::int, 5, 'Đ105: Trưởng cơ sở xuất đơn cơ sở mình (5)');
select is((app.export_orders() ->> 'total')::int, 5, 'Đ105: tổng khớp danh sách trong cơ sở');
select is(app.export_orders() ->> 'truncated', 'false', 'Xuất: chưa vượt giới hạn');
select is(app.export_orders('{"status": ["DA_DUYET"]}') -> 'rows' -> 0 ->> 'status', 'Đã duyệt', 'Xuất: cùng bộ lọc với danh sách');
select is(app.export_orders('{"status": ["DA_DUYET"]}') -> 'rows' -> 0 ->> 'students', 'Em Sinh Đôi', 'Xuất: nêu tên em');
select ok((select count(*) from app.export_log where module_code = 'SALES_ORDER') >= 4, 'Mỗi lần xuất ghi nhật ký xuất');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((app.export_orders() ->> 'exported')::int, 1, 'Đ105: Trưởng cơ sở CS5 chỉ xuất đơn CS5');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is((app.export_orders() ->> 'exported')::int, 6, 'Đ105: Kế toán xuất toàn hệ thống');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.export_orders() ->> 'exported')::int, 6, 'Đ105: Admin (aal2) xuất toàn hệ thống');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.export_orders()$$), 'HMT_KHONG_CO_QUYEN', 'Admin chưa xác thực hai bước không xuất được');
-- Giới hạn xuất: hạ export_max_rows xuống 2 thì cắt và báo truncated.
select pg_temp.sudo($$update app.setting_def set value = '2' where key = 'export_max_rows'$$);
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is((app.export_orders() ->> 'exported')::int, 2, 'Xuất: không vượt export_max_rows');
select is(app.export_orders() ->> 'truncated', 'true', 'Xuất: báo bị cắt khi vượt giới hạn');
select is((app.export_orders() ->> 'total')::int, 6, 'Xuất: vẫn báo tổng thật');

select * from finish();
rollback;
