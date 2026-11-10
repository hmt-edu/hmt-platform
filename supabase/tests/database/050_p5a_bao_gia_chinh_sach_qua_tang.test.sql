-- P5a-DB1d (migration 058): app.list_applicable_gift_policies (hộp Chọn chính sách quà tặng, R-TIEN-30). Phần dựng dữ liệu giống 044.

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

-- ================= list_applicable_gift_policies =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
create function pg_temp.gp() returns jsonb language sql as $$ select app.list_applicable_gift_policies(pg_temp.oid('0900009001')) $$;
create function pg_temp.gcodes(p jsonb) returns text[] language sql as $$ select coalesce(array_agg(x ->> 'code' order by x ->> 'code'), '{}') from jsonb_array_elements(p) x $$;
grant execute on function pg_temp.gp(), pg_temp.gcodes(jsonb) to public;
select is(pg_temp.gcodes(pg_temp.gp()), array['QUA_TAI_LIEU'], 'Quà tặng: chính sách hiệu lực hôm nay (mẫu của seed)');
select is(pg_temp.gp() -> 0 ->> 'name', 'Tặng bộ tài liệu Toán', 'Quà tặng: có tên chính sách');
select is((pg_temp.gp() -> 0 ->> 'max_quantity')::numeric, 1::numeric, 'Quà tặng: mức số lượng tối đa');
select is((pg_temp.gp() -> 0 ->> 'requires_approval')::boolean, false, 'Quà tặng: không cần duyệt');
select is(pg_temp.gp() -> 0 -> 'gift_package' ->> 'code', 'TL-MATOAN', 'Quà tặng: gói quà (mã)');
select is(pg_temp.gp() -> 0 -> 'gift_package' ->> 'unit_code', 'BO', 'Quà tặng: gói quà tài liệu tính theo bộ');
select ok(pg_temp.gp() -> 0 ? 'id' and pg_temp.gp() -> 0 -> 'gift_package' ? 'id', 'Quà tặng: có id để gửi lên khi lưu dòng');
-- Chính sách không áp dụng không hiện: hết hạn, chưa tới ngày, đã ngừng, cơ sở khác, gói quà ngừng bán.
select pg_temp.sudo($$insert into app.gift_policy (code, name, gift_package_id, max_quantity, valid_from, valid_to)
  select 'QUA_HET_HAN', 'Hết hạn', id, 1, date '2025-01-01', date '2025-12-31' from app.sales_package where code = 'TL-MATOAN'$$);
select pg_temp.sudo($$insert into app.gift_policy (code, name, gift_package_id, max_quantity, valid_from)
  select 'QUA_CHUA_TOI', 'Chưa tới ngày', id, 1, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 5 from app.sales_package where code = 'TL-MATOAN'$$);
select pg_temp.sudo($$insert into app.gift_policy (code, name, gift_package_id, max_quantity, valid_from, is_active)
  select 'QUA_NGUNG', 'Đã ngừng', id, 1, date '2026-01-01', false from app.sales_package where code = 'TL-MATOAN'$$);
select pg_temp.sudo($$insert into app.gift_policy (code, name, gift_package_id, max_quantity, valid_from, branch_ids)
  select 'QUA_CS5', 'Chỉ CS5', id, 2, date '2026-01-01', array[(select id from app.branch where code = 'CS5')] from app.sales_package where code = 'TL-MATOAN'$$);
select is(pg_temp.gcodes(pg_temp.gp()), array['QUA_TAI_LIEU'], 'Quà tặng: hết hạn, chưa tới ngày, đã ngừng, cơ sở khác đều không hiện');
-- Chính sách riêng theo cơ sở hiện đúng cơ sở; nhiều chính sách xếp theo mã; có cờ cần duyệt.
select pg_temp.sudo($$insert into app.gift_policy (code, name, gift_package_id, max_quantity, valid_from, requires_approval)
  select 'QUA_BO_DE', 'Tặng bộ đề', id, 3, date '2026-01-01', true from app.sales_package where code = 'TL-MATOAN'$$);
select is(pg_temp.gcodes(pg_temp.gp()), array['QUA_BO_DE', 'QUA_TAI_LIEU'], 'Quà tặng: nhiều chính sách xếp theo mã');
select is((select (x ->> 'requires_approval')::boolean from jsonb_array_elements(pg_temp.gp()) x where x ->> 'code' = 'QUA_BO_DE'), true, 'Quà tặng: chính sách cần duyệt mang cờ để hiện chip');
-- Gói quà đã ngừng bán thì chính sách không hiện.
select pg_temp.sudo($$update app.sales_package set is_active = false where code = 'TL-MATOAN'$$);
select is(pg_temp.gcodes(pg_temp.gp()), '{}'::text[], 'Quà tặng: gói quà đã ngừng bán thì không hiện chính sách');
select pg_temp.sudo($$update app.sales_package set is_active = true where code = 'TL-MATOAN'$$);
-- Phạm vi và quyền.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.gcodes(app.list_applicable_gift_policies(pg_temp.oid('0900009099'))), array['QUA_BO_DE', 'QUA_CS5', 'QUA_TAI_LIEU'], 'Quà tặng: Sale CS5 thấy thêm chính sách riêng của CS5 ở cơ hội CS5');
select is(pg_temp.err($$select app.list_applicable_gift_policies(pg_temp.oid('0900009001'))$$), 'HMT_KHONG_CO_QUYEN', 'Quà tặng: Sale CS5 không dùng cho cơ hội CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.list_applicable_gift_policies(pg_temp.oid('0900009001'))$$), 'HMT_KHONG_CO_QUYEN', 'Quà tặng: Kế toán không có quyền lập báo giá');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.list_applicable_gift_policies(pg_temp.oid('0900009001'))$$), 'HMT_KHONG_CO_QUYEN', 'Quà tặng: học sinh không có quyền');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.list_applicable_gift_policies('00000000-0000-0000-0000-000000000000')$$), 'HMT_KHONG_TIM_THAY', 'Quà tặng: cơ hội không có');
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select is(pg_temp.err($$select app.list_applicable_gift_policies(pg_temp.oid('0900009001'))$$), 'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì không liệt kê chính sách quà tặng');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select pg_temp.sudo($$update app.opportunity set record_status = 'DA_GOP', merged_into_id = pg_temp.oid('0900009001') where id = pg_temp.oid('0900009002')$$);
select is(pg_temp.err($$select app.list_applicable_gift_policies(pg_temp.oid('0900009002'))$$), 'HMT_BAN_GHI_DA_GOP', 'Quà tặng: cơ hội đã gộp thì chặn');

-- ================= Xem thử dòng quà (xác nhận hợp đồng cho giao diện) =================
select pg_temp.sudo($$update app.opportunity set record_status = 'DANG_DUNG', merged_into_id = null where id = pg_temp.oid('0900009002')$$);
create function pg_temp.giftline(p_qty numeric) returns jsonb language sql as $$
  select jsonb_build_object('kind', 'GIFT', 'prospect_student_id', pg_temp.ps('0900009001', 1), 'gift_policy_id', (select id from app.gift_policy where code = 'QUA_TAI_LIEU'), 'quantity', p_qty) $$;
grant execute on function pg_temp.giftline(numeric) to public;
select is(app.preview_quotation_lines(pg_temp.oid('0900009001'), jsonb_build_array(pg_temp.giftline(1))) -> 'lines' -> 0 ->> 'line_total', '0', 'Xem thử dòng quà: thành tiền 0 đ');
select is(app.preview_quotation_lines(pg_temp.oid('0900009001'), jsonb_build_array(pg_temp.giftline(1))) -> 'lines' -> 0 ->> 'unit_price', '0', 'Xem thử dòng quà: đơn giá 0 đ');
select is(app.preview_quotation_lines(pg_temp.oid('0900009001'), jsonb_build_array(pg_temp.giftline(1))) -> 'lines' -> 0 ->> 'over_cap', 'false', 'Xem thử dòng quà: không tính vào trần chiết khấu');
select is(pg_temp.msg($$select app.preview_quotation_lines(pg_temp.oid('0900009001'), jsonb_build_array(pg_temp.giftline(1), pg_temp.giftline(5)))$$), 'Dòng 2: số lượng quà không quá 1.', 'Xem thử dòng quà: lỗi vượt mức nêu đúng dòng, đúng câu của thiết kế');
select is(app.preview_quotation_lines(pg_temp.oid('0900009001'), jsonb_build_array(pg_temp.giftline(1))) -> 'lines' -> 0 ? 'discount_percent', true, 'Xem thử: mỗi dòng trả discount_percent và gift_percent để hiện tổng chiết khấu quy ra %');
select is(app.preview_quotation_lines(pg_temp.oid('0900009001'), jsonb_build_array(pg_temp.giftline(1))) -> 'lines' -> 0 ? 'gift_percent', true, 'Xem thử: có gift_percent');

select * from finish();
rollback;
