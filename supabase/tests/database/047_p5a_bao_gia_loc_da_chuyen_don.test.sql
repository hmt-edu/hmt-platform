-- P5a-DB1c-3 (migration 054): bộ lọc "Đã chuyển đơn" (converted) của danh sách và xuất báo giá. Báo giá Đã gửi mà mọi dòng đã lên đơn còn sống.
-- Phần dựng dữ liệu giống 044.
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
-- ================= Dữ liệu thêm: báo giá Đã gửi chưa lên đơn, báo giá Nháp =================
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
insert into qs select 'q2', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009006'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009006', 1), 'LC-TOAN-K09', 'OFF', 4))) as r) x;
select app.send_quotation(pg_temp.q('q2'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
insert into qs select 'q3', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009001'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 3))) as r) x;

create function pg_temp.codes(p jsonb) returns text[] language sql as $$
  select coalesce(array_agg(x ->> 'code' order by x ->> 'code'), '{}') from jsonb_array_elements(p -> 'rows') x $$;
grant execute on function pg_temp.codes(jsonb) to public;
create function pg_temp.qc(p_key text) returns text language sql as $$ select code from qs where key = p_key $$;
grant execute on function pg_temp.qc(text) to public;

-- ================= list_quotations: converted =================
select is(pg_temp.codes(app.list_quotations('{"converted": true}'::jsonb)), array[pg_temp.qc('q1')], 'Lọc Đã chuyển đơn: chỉ báo giá Đã gửi đã lên đơn');
select is(pg_temp.codes(app.list_quotations('{"converted": false}'::jsonb)), (select array_agg(c order by c) from unnest(array[pg_temp.qc('q2'), pg_temp.qc('q3')]) c), 'Lọc chưa chuyển đơn: loại báo giá đã lên đơn');
select is((app.list_quotations('{}'::jsonb) ->> 'total')::int, 3, 'Không lọc converted: đủ ba báo giá');
select is((app.list_quotations('{"converted": null}'::jsonb) ->> 'total')::int, 3, 'converted rỗng: như không lọc');
select is((app.list_quotations('{"converted": true, "mine": true}'::jsonb) ->> 'total')::int, 1, 'Lọc Đã chuyển đơn kết hợp lọc khác (của tôi)');
select is((app.list_quotations('{"converted": true, "status": ["NHAP"]}'::jsonb) ->> 'total')::int, 0, 'Lọc Đã chuyển đơn kết hợp trạng thái Nháp: không có');
select is(app.list_quotations('{"converted": true}'::jsonb) -> 'rows' -> 0 ->> 'display_status_code', 'DA_CHUYEN_DON', 'Dòng lọc Đã chuyển đơn hiện tình trạng Đã chuyển đơn');
select ok(pg_temp.msg($$select app.list_quotations('{"converted": "abc"}'::jsonb)$$) is not null, 'converted sai kiểu thì báo lỗi');
-- Huỷ đơn thì báo giá không còn là Đã chuyển đơn.
select app.cancel_order(pg_temp.o('n6'), 'KHAC', 'Huỷ để thử');
select is((app.list_quotations('{"converted": true}'::jsonb) ->> 'total')::int, 0, 'Đơn đã huỷ: báo giá không còn trong lọc Đã chuyển đơn');
select is((app.list_quotations('{"converted": false}'::jsonb) ->> 'total')::int, 3, 'Đơn đã huỷ: báo giá quay lại nhóm chưa chuyển đơn');
-- Phạm vi: Sale CS5 không thấy báo giá CS1 dù lọc.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((app.list_quotations('{"converted": false}'::jsonb) ->> 'total')::int, 0, 'Sale CS5 lọc chưa chuyển đơn: không thấy báo giá CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is((app.list_quotations('{"converted": false}'::jsonb) ->> 'total')::int, 3, 'Kế toán (xem mọi cơ sở) lọc chưa chuyển đơn: thấy ba báo giá');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.list_quotations('{"converted": true}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không xem báo giá');

-- ================= export_quotations: converted =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.send_quotation(pg_temp.q('q3'));
insert into qs select 'q4', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009005'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009005', 1), 'LC-TOAN-K09', 'OFF', 2))) as r) x;
select app.send_quotation(pg_temp.q('q4'));
insert into os select 'n7', (r ->> 'id')::uuid, r ->> 'code' from (select app.create_order_from_quotation(pg_temp.q('q4')) as r) x;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.export_quotations('{"converted": true}'::jsonb) ->> 'total')::int, 1, 'Xuất lọc Đã chuyển đơn: một báo giá (q4)');
select is(app.export_quotations('{"converted": true}'::jsonb) -> 'rows' -> 0 ->> 'code', pg_temp.qc('q4'), 'Xuất lọc Đã chuyển đơn: đúng mã báo giá');
select is((app.export_quotations('{"converted": false}'::jsonb) ->> 'total')::int, 3, 'Xuất lọc chưa chuyển đơn: ba báo giá còn lại');
select is((app.export_quotations('{}'::jsonb) ->> 'total')::int, 4, 'Xuất không lọc converted: đủ bốn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.export_quotations('{"converted": true}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Sale không được xuất (Đ105), lọc không mở thêm quyền');

select * from finish();
rollback;
