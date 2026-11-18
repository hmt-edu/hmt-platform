-- P5a-DB-O1c (migration 062), chỉ đọc: tổng niêm yết và tổng chiết khấu của báo giá, đơn (R-TIEN-13, R-TIEN-30, R-TIEN-14); người duyệt dự kiến
-- của đơn Nháp (R-HT-06, khớp submit_order); ghi chú và lịch sử của đơn giống hệt báo giá (migration 055, Đ181).
-- Mỗi vai đọc trong và ngoài phạm vi (cơ sở), có ca đúng và ca bị chặn.
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
  r := app.create_order_from_opportunity(pg_temp.oid(p_phone), p_lines, null, true);
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

-- ================= Thêm dữ liệu cho bài O1c =================
-- Đơn do Trưởng cơ sở lập (tự duyệt), đơn do Sale không có quản lý (THIẾU), đơn do Sale có quản lý chưa có quyền Duyệt đơn.
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mk('n8', '0900009005', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009005', 1), 'LC-TOAN-K09', 'OFF', 4)));
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select pg_temp.mk('n7', '0900009006', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009006', 1), 'LC-TOAN-K09', 'OFF', 4)));
select pg_temp.claims(pg_temp.uid('sales1c'), 'aal1');
select pg_temp.mk('n9', '0900009004', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009004', 1), 'LC-TOAN-K09', 'OFF', 4)));
-- Ba báo giá nháp: một dòng không chiết khấu; hai dòng có chiết khấu; như báo giá hai dòng kèm một dòng quà.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
insert into qs select 'qa', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009002'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 20))) as r) x;
insert into qs select 'qb', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009001'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_6_THANG'))),
                    pg_temp.line(pg_temp.ps('0900009001', 2), 'LC-TOAN-K09', 'OFF', 5))) as r) x;
create function pg_temp.giftline(p_qty numeric) returns jsonb language sql as $$
  select jsonb_build_object('kind', 'GIFT', 'prospect_student_id', pg_temp.ps('0900009001', 1), 'gift_policy_id', (select id from app.gift_policy where code = 'QUA_TAI_LIEU'), 'quantity', p_qty) $$;
grant execute on function pg_temp.giftline(numeric) to public;
insert into qs select 'qc', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009001'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_6_THANG'))),
                    pg_temp.line(pg_temp.ps('0900009001', 2), 'LC-TOAN-K09', 'OFF', 5), pg_temp.giftline(1))) as r) x;

create function pg_temp.gq(p_key text) returns jsonb language sql as $$ select app.get_quotation(pg_temp.q(p_key)) $$;
create function pg_temp.go(p_key text) returns jsonb language sql as $$ select app.get_order(pg_temp.o(p_key)) $$;
grant execute on function pg_temp.gq(text), pg_temp.go(text) to public;

-- ================= (1) Tổng niêm yết và tổng chiết khấu: báo giá =================
select is(pg_temp.gq('qa') ->> 'gross_total', '4400000', 'R-TIEN-13: báo giá một dòng 20 giờ x 220.000: tổng niêm yết 4.400.000');
select is(pg_temp.gq('qa') ->> 'discount_total', '0', 'Báo giá không chiết khấu: tổng chiết khấu 0');
select is((pg_temp.gq('qa') ->> 'gross_total')::bigint - (pg_temp.gq('qa') ->> 'discount_total')::bigint, (pg_temp.gq('qa') ->> 'total_amount')::bigint,
  'Báo giá một dòng: tổng niêm yết trừ tổng chiết khấu bằng tổng thành tiền');
select is(jsonb_typeof(pg_temp.gq('qb') -> 'gross_total'), 'number', 'Báo giá: gross_total là số');
select ok((pg_temp.gq('qb') ->> 'discount_total')::bigint > 0, 'Báo giá có chính sách chiết khấu: tổng chiết khấu lớn hơn 0');
select is((pg_temp.gq('qb') ->> 'gross_total')::bigint - (pg_temp.gq('qb') ->> 'discount_total')::bigint, (pg_temp.gq('qb') ->> 'total_amount')::bigint,
  'Báo giá hai dòng có chiết khấu: tổng niêm yết trừ tổng chiết khấu bằng tổng thành tiền');
select is((select sum((l ->> 'gross_amount')::bigint)::text from jsonb_array_elements(pg_temp.gq('qb') -> 'lines') l), pg_temp.gq('qb') ->> 'gross_total',
  'Tổng niêm yết bằng tổng các dòng đã đóng băng (không tính lại)');
select is(pg_temp.gq('qc') ->> 'gross_total', pg_temp.gq('qb') ->> 'gross_total', 'R-TIEN-30: dòng quà tặng không vào tổng niêm yết');
select is(pg_temp.gq('qc') ->> 'discount_total', pg_temp.gq('qb') ->> 'discount_total', 'R-TIEN-30: dòng quà tặng không vào tổng chiết khấu');
select is(pg_temp.gq('qc') ->> 'total_amount', pg_temp.gq('qb') ->> 'total_amount', 'R-TIEN-30: dòng quà tặng không đổi tổng thành tiền');
select is(jsonb_array_length(pg_temp.gq('qc') -> 'lines'), 3, 'Báo giá có quà: vẫn trả đủ ba dòng');

-- ================= (1) Tổng niêm yết và tổng chiết khấu: đơn hàng =================
select is((pg_temp.go('n1') ->> 'gross_total')::bigint - (pg_temp.go('n1') ->> 'discount_total')::bigint, (pg_temp.go('n1') ->> 'total_amount')::bigint,
  'Đơn hai dòng có chiết khấu: tổng niêm yết trừ tổng chiết khấu bằng tổng thành tiền');
select ok((pg_temp.go('n1') ->> 'discount_total')::bigint > 0, 'Đơn có chính sách chiết khấu: tổng chiết khấu lớn hơn 0');
select is(pg_temp.go('n2') ->> 'discount_total', '0', 'Đơn không chiết khấu: tổng chiết khấu 0');
select is(pg_temp.go('n2') ->> 'gross_total', '4400000', 'Đơn 20 giờ x 220.000: tổng niêm yết 4.400.000');
select is(pg_temp.go('n6') ->> 'gross_total', pg_temp.gq('q1') ->> 'gross_total', 'R-TIEN-14: đơn sinh từ báo giá giữ đúng tổng niêm yết đã đóng băng của báo giá');
select is(pg_temp.go('n6') ->> 'discount_total', pg_temp.gq('q1') ->> 'discount_total', 'R-TIEN-14: đơn sinh từ báo giá giữ đúng tổng chiết khấu của báo giá');
select is(pg_temp.go('n4') ->> 'gross_total', '2640000', 'Đơn đã huỷ vẫn trả tổng niêm yết (số đã đóng băng)');
-- Không tính lại: đổi số đã lưu ở một dòng thì tổng đổi theo (tổng là cộng các dòng lưu, không dựa vào bảng giá hiện tại).
create temp table base (k text primary key, v bigint);
grant all on base to public;
insert into base select 'n1', (pg_temp.go('n1') ->> 'gross_total')::bigint;
select pg_temp.sudo($$update app.sales_order_line set gross_amount = gross_amount + 1000 where order_id = pg_temp.o('n1') and line_no = 1$$);
select is((pg_temp.go('n1') ->> 'gross_total')::bigint, (select v + 1000 from base where k = 'n1'), 'Tổng niêm yết là tổng số đã lưu ở các dòng, không tính lại theo bảng giá');
select pg_temp.sudo($$update app.sales_order_line set gross_amount = gross_amount - 1000 where order_id = pg_temp.o('n1') and line_no = 1$$);

-- ================= (2) Người duyệt dự kiến của đơn Nháp (R-HT-06) =================
select is(pg_temp.go('n1') ->> 'expected_route', 'QUAN_LY', 'Đơn Nháp của Sale có quản lý: đường duyệt QUAN_LY');
select is((pg_temp.go('n1') ->> 'expected_approver_id')::uuid, pg_temp.uid('bm1'), 'Đơn Nháp: người duyệt dự kiến là quản lý trực tiếp của người lập');
select is(pg_temp.go('n1') ->> 'expected_approver_name', 'Giả bm1', 'Đơn Nháp: trả tên người duyệt dự kiến');
select is((pg_temp.go('n1') ->> 'expected_approver_can_approve')::boolean, true, 'Đơn Nháp: người duyệt dự kiến có quyền Duyệt đơn ở cơ sở (Đ205)');
select is(pg_temp.go('n8') ->> 'expected_route', 'TU_DUYET', 'R-HT-06: Trưởng cơ sở lập đơn thì đường duyệt TU_DUYET');
select is((pg_temp.go('n8') ->> 'expected_approver_id')::uuid, pg_temp.uid('bm1'), 'R-HT-06: Trưởng cơ sở tự duyệt: người duyệt dự kiến là chính họ');
select pg_temp.sudo($$update app.user_role set is_active = false where role_code = 'BRANCH_MANAGER'$$); -- R-V2-12: cơ sở chưa có Trưởng cơ sở nào thì mới chặn
select is(pg_temp.err($$select pg_temp.go('n7')$$), null, 'Người lập chưa có quản lý trực tiếp: get_order KHÔNG báo lỗi');
select is(pg_temp.go('n7') ->> 'expected_route', 'THIEU', 'Người lập chưa có quản lý trực tiếp: đường duyệt THIEU');
select is(pg_temp.go('n7') -> 'expected_approver_id', 'null'::jsonb, 'Người lập chưa có quản lý trực tiếp: người duyệt dự kiến rỗng');
select is(pg_temp.go('n7') -> 'expected_approver_can_approve', 'null'::jsonb, 'Người lập chưa có quản lý trực tiếp: không có kết luận về quyền duyệt');
select pg_temp.sudo($$update app.user_role set is_active = true where role_code = 'BRANCH_MANAGER'$$);
select is(pg_temp.go('n9') ->> 'expected_route', 'QUAN_LY', 'Sale có quản lý chưa có quyền Duyệt đơn: vẫn QUAN_LY');
select is((pg_temp.go('n9') ->> 'expected_approver_can_approve')::boolean, false, 'Đ205: quản lý dự kiến chưa có quyền Duyệt đơn thì báo can_approve = false');
select is(pg_temp.go('n2') -> 'expected_route', 'null'::jsonb, 'Đơn Đã trình: không trả đường duyệt dự kiến');
select is(pg_temp.go('n3') -> 'expected_approver_id', 'null'::jsonb, 'Đơn Đã duyệt: không trả người duyệt dự kiến');
select is(pg_temp.go('n4') -> 'expected_route', 'null'::jsonb, 'Đơn Huỷ: không trả đường duyệt dự kiến');
-- Khớp submit_order: người duyệt dự kiến trước khi trình đúng bằng người duyệt đã chốt sau khi trình (cùng đầu vào: người LẬP đơn).
create temp table prev (k text primary key, approver uuid, route text);
grant all on prev to public;
insert into prev select 'n1', (pg_temp.go('n1') ->> 'expected_approver_id')::uuid, pg_temp.go('n1') ->> 'expected_route';
insert into prev select 'n8', (pg_temp.go('n8') ->> 'expected_approver_id')::uuid, pg_temp.go('n8') ->> 'expected_route';
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.save_order(pg_temp.o('n1'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('n1'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.save_order(pg_temp.o('n8'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('n8'));
select pg_temp.sudo($$create function pg_temp.assigned(p_key text) returns uuid language sql stable security definer as 'select assigned_approver_id from app.sales_order where id = pg_temp.o(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.route_of(p_key text) returns text language sql stable security definer as 'select approval_route from app.sales_order where id = pg_temp.o(p_key)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.assigned(text), pg_temp.route_of(text) to public$$);
select is(pg_temp.assigned('n1'), (select approver from prev where k = 'n1'), 'R-HT-06: người duyệt dự kiến khớp người submit_order chốt (đơn của Sale)');
select is(pg_temp.route_of('n1'), (select route from prev where k = 'n1'), 'R-HT-06: đường duyệt dự kiến khớp đường submit_order chốt (QUAN_LY)');
select is(pg_temp.assigned('n8'), (select approver from prev where k = 'n8'), 'R-HT-06: người duyệt dự kiến khớp submit_order (Trưởng cơ sở tự duyệt)');
select is(pg_temp.route_of('n8'), (select route from prev where k = 'n8'), 'R-HT-06: đường duyệt dự kiến khớp submit_order (TU_DUYET)');
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select app.save_order(pg_temp.o('n7'), null, pg_temp.term('CHIA_3_DOT'));
select pg_temp.sudo($$update app.user_role set is_active = false where role_code = 'BRANCH_MANAGER'$$); -- R-V2-12: cơ sở chưa có Trưởng cơ sở nào thì mới chặn
select is(pg_temp.err($$select app.submit_order(pg_temp.o('n7'))$$), 'HMT_KHONG_CO_QUAN_LY', 'Đơn THIEU: submit_order chặn đúng điều kiện mà get_order báo trước');
select pg_temp.sudo($$update app.user_role set is_active = true where role_code = 'BRANCH_MANAGER'$$);
-- Người bấm Trình khác người lập: người duyệt vẫn theo người LẬP. Admin (đơn Nháp của Sale) xem trước rồi Admin trình.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('n10', '0900009003', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009003', 1), 'LC-TOAN-K09', 'OFF', 2)));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((pg_temp.go('n10') ->> 'expected_approver_id')::uuid, pg_temp.uid('bm1'), 'Người xem là Trưởng cơ sở, người lập là Sale: người duyệt dự kiến vẫn theo người lập (quản lý của Sale)');
select is(pg_temp.go('n10') ->> 'expected_route', 'QUAN_LY', 'Người xem khác người lập: đường duyệt vẫn theo người lập');
-- Quyền xem và phạm vi của get_order không đổi.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select pg_temp.go('n1')$$), 'HMT_KHONG_CO_QUYEN', 'get_order: Sale CS5 vẫn không xem đơn CS1');
select pg_temp.sudo($$update app.user_role set is_active = false where role_code = 'BRANCH_MANAGER'$$); -- R-V2-12: cơ sở chưa có Trưởng cơ sở nào thì mới chặn
select is(pg_temp.go('n5') ->> 'expected_route', 'THIEU', 'Đơn CS5 của Sale chưa có quản lý: THIEU, không lỗi');
select pg_temp.sudo($$update app.user_role set is_active = true where role_code = 'BRANCH_MANAGER'$$);
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select pg_temp.gq('qa')$$), 'HMT_KHONG_CO_QUYEN', 'get_quotation: học sinh vẫn bị chặn');
select is(pg_temp.err($$select pg_temp.go('n1')$$), 'HMT_KHONG_CO_QUYEN', 'get_order: học sinh vẫn bị chặn');

-- ================= (3) Ghi chú và lịch sử của đơn: giống hệt báo giá (migration 055) =================
-- Bảng đích ghi chú chỉ nhân viên đọc (R2, migration 466): kiểm bằng quyền chủ, rồi trả lại vai trò đang thử.
reset role;
select is((select count(*)::int from app.note_target where entity_type = 'SALES_ORDER'), 1, 'Ghi chú đơn: đã đăng ký loại SALES_ORDER');
set local role authenticated;
create function pg_temp.sees(p_user text, p_type text, p_id uuid) returns boolean language plpgsql as $$
begin
  perform pg_temp.claims(pg_temp.uid(p_user), case when p_user in ('admin', 'ke') then 'aal2' else 'aal1' end);
  return app.can_see_note_target(p_type, p_id);
end $$;
grant execute on function pg_temp.sees(text, text, uuid) to public;
-- Bảng "ai xem ghi chú": mỗi vai, đơn CS1 và báo giá CS1 phải cho cùng kết quả (giống hệt báo giá).
select is(pg_temp.sees('admin', 'SALES_ORDER', pg_temp.o('n6')), true, 'Ghi chú đơn: Admin xem được');
select is(pg_temp.sees('bm1', 'SALES_ORDER', pg_temp.o('n6')), true, 'Ghi chú đơn: Trưởng cơ sở CS1 xem đơn CS1');
select is(pg_temp.sees('sales1', 'SALES_ORDER', pg_temp.o('n6')), true, 'Ghi chú đơn: Sale CS1 xem đơn CS1');
select is(pg_temp.sees('sales1b', 'SALES_ORDER', pg_temp.o('n6')), true, 'Ghi chú đơn: Sale khác CS1 xem đơn CS1 (theo cơ sở, không theo người lập)');
select is(pg_temp.sees('cskh1', 'SALES_ORDER', pg_temp.o('n6')), true, 'Ghi chú đơn: CSKH CS1 xem đơn CS1');
select is(pg_temp.sees('ke', 'SALES_ORDER', pg_temp.o('n6')), true, 'Ghi chú đơn: Kế toán xem');
select is(pg_temp.sees('sales5', 'SALES_ORDER', pg_temp.o('n6')), false, 'Ghi chú đơn: Sale CS5 không xem đơn CS1');
select is(pg_temp.sees('bm5', 'SALES_ORDER', pg_temp.o('n6')), false, 'Ghi chú đơn: Trưởng cơ sở CS5 không xem đơn CS1');
select is(pg_temp.sees('hs', 'SALES_ORDER', pg_temp.o('n6')), false, 'Ghi chú đơn: học sinh không xem');
select is(pg_temp.sees('sales5', 'SALES_ORDER', pg_temp.o('n5')), true, 'Ghi chú đơn: Sale CS5 xem đơn CS5');
select is(pg_temp.sees('sales1', 'SALES_ORDER', pg_temp.o('n5')), false, 'Ghi chú đơn: Sale CS1 không xem đơn CS5');
select is(pg_temp.sees('bm1', 'SALES_ORDER', gen_random_uuid()), false, 'Ghi chú đơn: đơn không có thì không xem được');
select is(
  (select array_agg(pg_temp.sees(k, 'SALES_ORDER', pg_temp.o('n6')) order by k) from unnest(array['admin','bm1','bm5','cskh1','hs','ke','sales1','sales1b','sales5']) k),
  (select array_agg(pg_temp.sees(k, 'QUOTATION', pg_temp.q('q1')) order by k) from unnest(array['admin','bm1','bm5','cskh1','hs','ke','sales1','sales1b','sales5']) k),
  'Ghi chú đơn giống hệt báo giá (migration 055): cùng kết quả cho mọi vai ở cùng cơ sở');
select is(pg_temp.sees('bm1', 'QUOTATION', pg_temp.q('q1')), true, 'Các loại cũ không đổi: báo giá vẫn xem được');
select is(pg_temp.sees('bm1', 'OPPORTUNITY', pg_temp.oid('0900009001')), true, 'Các loại cũ không đổi: cơ hội vẫn xem được');
select is(pg_temp.sees('sales5', 'OPPORTUNITY', pg_temp.oid('0900009001')), false, 'Các loại cũ không đổi: Sale CS5 vẫn không xem cơ hội CS1');
-- Viết và đọc ghi chú qua hàm chung.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.add_note('SALES_ORDER', pg_temp.o('n6'), 'Phụ huynh hẹn đóng tiền thứ sáu')$$), null, 'Ghi chú đơn: người có quyền thêm được');
select is((select count(*)::int from app.record_notes('SALES_ORDER', pg_temp.o('n6'))), 1, 'Ghi chú đơn: đọc lại được');
select is((select body from app.record_notes('SALES_ORDER', pg_temp.o('n6')) limit 1), 'Phụ huynh hẹn đóng tiền thứ sáu', 'Ghi chú đơn: đúng nội dung');
select is(pg_temp.err($$select app.add_note('SALES_ORDER', pg_temp.o('n4'), 'ghi vào đơn đã huỷ')$$), null, 'Ghi chú đơn: đơn đã huỷ vẫn ghi được (như báo giá)');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.add_note('SALES_ORDER', pg_temp.o('n6'), 'ghi trái phép')$$), 'HMT_KHONG_CO_QUYEN', 'Ghi chú đơn: Sale CS5 không ghi vào đơn CS1');
select is(pg_temp.err($$select * from app.record_notes('SALES_ORDER', pg_temp.o('n6'))$$), 'HMT_KHONG_CO_QUYEN', 'Ghi chú đơn: Sale CS5 không đọc ghi chú đơn CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is((select count(*)::int from app.record_notes('SALES_ORDER', pg_temp.o('n6'))), 1, 'Ghi chú đơn: Kế toán đọc được');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select * from app.record_notes('SALES_ORDER', pg_temp.o('n6'))$$), 'HMT_KHONG_CO_QUYEN', 'Ghi chú đơn: học sinh không đọc được');
-- Lịch sử thay đổi của đơn dùng cùng quyền xem (record_history).
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select * from app.record_history('SALES_ORDER', pg_temp.o('n6'))$$), null, 'Lịch sử đơn: người có quyền xem được');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select * from app.record_history('SALES_ORDER', pg_temp.o('n6'))$$), 'HMT_KHONG_CO_QUYEN', 'Lịch sử đơn: Sale CS5 không xem lịch sử đơn CS1');
-- Đ181: tắt Bán hàng ở CS1 vẫn đọc và ghi ghi chú (như báo giá ở migration 055).
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((select count(*)::int from app.record_notes('SALES_ORDER', pg_temp.o('n6'))), 1, 'Đ181: tắt Bán hàng vẫn đọc được ghi chú đơn');
select is(pg_temp.err($$select app.add_note('SALES_ORDER', pg_temp.o('n6'), 'ghi khi tắt Bán hàng')$$), null, 'Đ181: tắt Bán hàng vẫn ghi được ghi chú đơn');
select is(pg_temp.err($$select app.add_note('QUOTATION', pg_temp.q('q1'), 'ghi khi tắt Bán hàng')$$), null, 'Đối chiếu 055: báo giá cũng ghi được khi tắt Bán hàng (đơn giống hệt)');
select is(pg_temp.err($$select pg_temp.go('n1')$$), null, 'Đ181: tắt Bán hàng vẫn đọc được get_order (không chặn)');
select is(pg_temp.err($$select pg_temp.gq('qa')$$), null, 'Đ181: tắt Bán hàng vẫn đọc được get_quotation (không chặn)');

select * from finish();
rollback;
