-- P5a-DB1b-1 (đơn hàng, phần bảng và hàm ghi): QĐ-Đ201 đến Đ205; R-TIEN-02, 03, 06, 07, 14, 35, 37, 38; R-GD-06, R-GD-08; R-CRM-16, 27;
-- R-HT-01, R-HT-06. Mỗi luật có ca đúng và ca bị chặn; mỗi vai đọc, ghi trong và ngoài phạm vi.
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

-- ================= R-CRM-16: chưa L8 không tạo được đơn =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900009009'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900009009', 1), 'LC-TOAN-K09', 'OFF', 10)))$$),
          'HMT_CHUA_O_L8', 'R-CRM-16: cơ hội chưa L8 thì không tạo đơn thẳng');
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900009002'), '[]'::jsonb)$$), 'HMT_DON_KHONG_DONG', 'Đơn không có dòng thì chặn');
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900009002'),
          jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 10)))$$), 'HMT_EM_NGOAI_DANH_SACH', 'Đ83: em của cơ hội khác thì chặn');
select is(pg_temp.err($$select app.create_order_from_opportunity('00000000-0000-0000-0000-000000000000', '[]'::jsonb)$$), 'HMT_DON_KHONG_DONG', 'Không dòng báo trước khi tìm cơ hội');

-- ================= Đơn thẳng từ cơ hội: tính theo giá ngày tạo (R-TIEN-14, Đ201); làm tròn (R-TIEN-37) =================
select is(pg_temp.err($$select pg_temp.mk('a1', '0900009001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 10)))$$), null, 'Tạo đơn thẳng từ cơ hội L8: được');
select ok((select code from os where key = 'a1') ~ '^DH-CS1-\d{4}-\d{4}$', 'Mã DH-CS1-AAMM-STT cấp lúc tạo');
select is(pg_temp.st('a1'), 'NHAP', 'Đơn mới là Nháp');
select is((select total_amount from app.sales_order where id = pg_temp.o('a1')), 2200000::bigint, 'Tổng đơn tính ở máy chủ (10 giờ × 220.000)');
select is((select array[o.branch_id = op.branch_id, o.parent_id = op.parent_id, o.quotation_id is null] from app.sales_order o
            join app.opportunity op on op.id = o.opportunity_id where o.id = pg_temp.o('a1')), array[true, true, true], 'Đơn lấy cơ sở và phụ huynh của cơ hội, không có báo giá');
select is((select num_nonnulls(opportunity_id, renewal_ticket_id)::int from app.sales_order where id = pg_temp.o('a1')), 1, 'Đ187: đúng một gốc');
select is(pg_temp.ev('a1'), 'TAO', 'Lịch sử ghi việc tạo đơn');
-- Giá đổi trước khi tạo: đơn thẳng lấy giá hiệu lực ngày tạo đơn.
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'ONL', 130000, (now() at time zone 'Asia/Ho_Chi_Minh')::date from app.sales_package where code = 'LC-TOAN-K09'$$);
select pg_temp.mk('a2', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'ONL', 10)));
select is((select unit_price from app.sales_order_line where order_id = pg_temp.o('a2')), 130000::bigint, 'Đ201: đơn thẳng tính theo giá hiệu lực ngày tạo đơn (130.000)');
-- Làm tròn (R-TIEN-37): 0,33 giờ giảm 3,33%.
select pg_temp.mk('r1', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 0.33, jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 3.33)))));
select is((select array[gross_amount::text, discount_amount::text, line_total::text] from app.sales_order_line where order_id = pg_temp.o('r1')),
          array['72600', '2417', '70183'], 'R-TIEN-37: chiết khấu làm tròn xuống (2.417), thành tiền sau chiết khấu = thành tiền − chiết khấu');
select pg_temp.mk('r2', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 0.5)));
select is((select gross_amount from app.sales_order_line where order_id = pg_temp.o('r2')), 110000::bigint, 'R-TIEN-37: 0,5 giờ × 220.000 = 110.000 đ');
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'ONL', 100001, (now() at time zone 'Asia/Ho_Chi_Minh')::date from app.sales_package where code = 'VIP-TOAN-K03K07'$$);
select pg_temp.mk('r3', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'VIP-TOAN-K03K07', 'ONL', 0.5)));
select is((select gross_amount from app.sales_order_line where order_id = pg_temp.o('r3')), 50001::bigint, 'R-TIEN-37: 0,5 × 100.001 = 50.000,5 làm tròn nửa đồng lên = 50.001');
select is((select search_text like '%don hai%' from app.sales_order where id = pg_temp.o('a2')), true, 'Ô tìm kiếm của đơn có tên phụ huynh');

-- ================= Quyền và công tắc =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900009001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 5)))$$),
          'HMT_KHONG_CO_QUYEN', 'Sale CS5 không tạo đơn cho cơ hội CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900009001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 5)))$$),
          'HMT_KHONG_CO_QUYEN', 'Kế toán không có quyền Tạo đơn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900009001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 5)))$$),
          'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì không tạo đơn');
select is(pg_temp.err($$select app.save_order(pg_temp.o('a1'), null, pg_temp.term('COC_VA_CHIA_DOT'))$$), 'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì không lưu đơn');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('a1'))$$), 'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì không trình đơn');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('a1'), 'KHACH_DOI_Y')$$), 'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì không huỷ đơn');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);

-- ================= Lưu đơn Nháp: điều khoản, lịch đóng tiền (R-TIEN-07), lớp (R-GD-06, R-GD-08) =================
select is(pg_temp.err($$select app.save_order(pg_temp.o('a1'), null, pg_temp.term('COC_VA_CHIA_DOT'))$$), null, 'Lưu đơn Nháp, chọn điều khoản: được');
select is((select array_agg(amount order by seq) from app.sales_order_installment where order_id = pg_temp.o('a1')), array[1000000, 1200000]::bigint[],
          'R-TIEN-07: lịch đóng tiền tính từ điều khoản (cọc 1.000.000, còn 1.200.000)');
select is((select sum(amount) from app.sales_order_installment where order_id = pg_temp.o('a1')), 2200000::numeric, 'Tổng các đợt đúng bằng tổng đơn');
select is((select count(*)::int from app.sales_order_installment where order_id = pg_temp.o('a1') and due_date is not null), 0, 'Hạn đóng tiền chưa chốt khi còn Nháp');
select is(pg_temp.err($$select app.save_order(pg_temp.o('a1'), null, '00000000-0000-0000-0000-000000000000')$$), 'HMT_KHONG_TIM_THAY', 'Điều khoản không có thì báo không tìm thấy');
select pg_temp.mk('a3', '0900009001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 10)));
select is(pg_temp.err($$select app.save_order(pg_temp.o('a3'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 10) || jsonb_build_object('class_id', gen_random_uuid())))$$),
          'HMT_THIEU_NGAY_VAO_LOP', 'R-GD-06: chọn lớp mà không có ngày vào lớp thì chặn');
select is(pg_temp.err($$select app.save_order(pg_temp.o('a3'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 10)
          || jsonb_build_object('class_id', gen_random_uuid(), 'enrol_start_date', current_date + 3)))$$), 'HMT_LOP_KHONG_TIM_THAY',
          'R-GD-08: kiểm lớp khi lưu (lớp không có thì báo không tìm thấy, từ migration 101)');
select is(pg_temp.err($$select app.save_order(pg_temp.o('a3'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 20)))$$), null, 'Đơn thẳng: lưu lại dòng mới (giờ đổi)');
select is((select total_amount from app.sales_order where id = pg_temp.o('a3')), 4400000::bigint, 'Đơn thẳng lưu lại tính lại tổng (20 giờ)');
select is(pg_temp.err($$select app.save_order(pg_temp.o('a3'), '[]'::jsonb)$$), 'HMT_DON_KHONG_DONG', 'Đơn thẳng lưu mà xoá hết dòng thì chặn');
-- Điều khoản không hợp tổng: cọc cố định không nhỏ hơn tổng.
select is(pg_temp.err($$select app.save_order(pg_temp.o('r2'), null, pg_temp.term('COC_VA_CHIA_DOT'))$$), 'HMT_COC_VUOT_DON', 'R-TIEN-07: cọc cố định không nhỏ hơn tổng đơn thì chặn (đơn 110.000 đ)');

-- ================= Trình đơn (R-TIEN-35, R-HT-06, Đ203, Đ205) =================
select is(pg_temp.err($$select app.submit_order(pg_temp.o('a1'))$$), null, 'Sale có quản lý trực tiếp (Trưởng cơ sở): trình được');
select is(pg_temp.st('a1'), 'DA_TRINH', 'Sau trình: Đã trình');
select is((select assigned_approver_id from app.sales_order where id = pg_temp.o('a1')), pg_temp.uid('bm1'), 'R-HT-06: chốt quản lý trực tiếp của NGƯỜI LẬP làm người duyệt');
select is((select approval_route from app.sales_order where id = pg_temp.o('a1')), 'QUAN_LY', 'Đường duyệt QUAN_LY');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('a1'))$$), 'HMT_SAI_TRANG_THAI', 'Trình lần hai thì chặn');
select is(pg_temp.err($$select app.save_order(pg_temp.o('a1'), null, pg_temp.term('CHIA_3_DOT'))$$), 'HMT_DON_DA_KHOA', 'R-TIEN-03: đơn đã trình không lưu lại được');
select throws_ok($$select pg_temp.sudo('update app.sales_order_line set quantity = 99 where order_id = pg_temp.o(''a1'')')$$, null, null, 'Dòng đơn đã trình bị khoá (trigger)');
select throws_ok($$select pg_temp.sudo('delete from app.sales_order_installment where order_id = pg_temp.o(''a1'')')$$, null, null, 'Lịch đóng tiền đơn đã trình bị khoá');
-- Đơn chưa chọn điều khoản.
select pg_temp.mk('b1', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10)));
select is(pg_temp.err($$select app.submit_order(pg_temp.o('b1'))$$), 'HMT_THIEU_DIEU_KHOAN', 'R-TIEN-07: chưa chọn điều khoản thì không trình được');
-- Đơn không dòng.
select pg_temp.sudo($$insert into app.sales_order (code, branch_id, opportunity_id, parent_id, priced_on, payment_term_id)
  select 'DHT-TEST-0001', o.branch_id, o.id, o.parent_id, current_date, pg_temp.term('CHIA_3_DOT') from app.opportunity o where o.id = pg_temp.oid('0900009002')$$);
select is(pg_temp.err($$select app.submit_order((select id from app.sales_order where code = 'DHT-TEST-0001'))$$), 'HMT_DON_KHONG_DONG', 'Đơn chưa có dòng thì không trình được');
-- R-TIEN-35: em thiếu năm sinh (Em Ba).
select pg_temp.mk('b2', '0900009001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 10), pg_temp.line(pg_temp.ps('0900009001', 3), 'LC-TOAN-K09', 'OFF', 5)));
select app.save_order(pg_temp.o('b2'), null, pg_temp.term('CHIA_3_DOT'));
select is(pg_temp.err($$select app.submit_order(pg_temp.o('b2'))$$), 'HMT_EM_THIEU_THONG_TIN', 'R-TIEN-35: em thiếu năm sinh thì không trình được');
select ok(pg_temp.msg($$select app.submit_order(pg_temp.o('b2'))$$) like '%Dòng 2: thiếu năm sinh của em%', 'R-TIEN-35: báo đúng dòng, đúng ô thiếu');
-- Người lập không có quản lý (R-HT-06).
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select pg_temp.mk('c1', '0900009006', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009006', 1), 'LC-TOAN-K09', 'OFF', 10)));
select app.save_order(pg_temp.o('c1'), null, pg_temp.term('CHIA_3_DOT'));
select pg_temp.sudo($$update app.user_role set is_active = false where role_code = 'BRANCH_MANAGER'$$); -- R-V2-12: cơ sở chưa có Trưởng cơ sở nào thì mới chặn
select is(pg_temp.err($$select app.submit_order(pg_temp.o('c1'))$$), 'HMT_KHONG_CO_QUAN_LY', 'R-HT-06: không có quản lý trực tiếp (không phải Trưởng cơ sở) thì không trình được');
select pg_temp.sudo($$update app.user_role set is_active = true where role_code = 'BRANCH_MANAGER'$$);
-- Đ205: quản lý đã chốt không có quyền Duyệt đơn.
select pg_temp.claims(pg_temp.uid('sales1c'), 'aal1');
select pg_temp.mk('d1', '0900009004', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009004', 1), 'LC-TOAN-K09', 'OFF', 10)));
select app.save_order(pg_temp.o('d1'), null, pg_temp.term('CHIA_3_DOT'));
select is(pg_temp.err($$select app.submit_order(pg_temp.o('d1'))$$), 'HMT_NGUOI_DUYET_THIEU_QUYEN', 'Đ205: quản lý đã chốt (CSKH) không có quyền Duyệt đơn thì chặn trình');
select ok(pg_temp.msg($$select app.submit_order(pg_temp.o('d1'))$$) like '%chưa có quyền Duyệt đơn hàng%', 'Đ205: câu báo lỗi tiếng Việt nêu thiếu quyền Duyệt');
select is(pg_temp.st('d1'), 'NHAP', 'Đ205: bị chặn thì đơn vẫn Nháp');
-- Trưởng cơ sở lập: tự duyệt (R-HT-06).
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mk('e1', '0900009005', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009005', 1), 'LC-TOAN-K09', 'OFF', 10)));
select app.save_order(pg_temp.o('e1'), null, pg_temp.term('CHIA_3_DOT'));
select is(pg_temp.err($$select app.submit_order(pg_temp.o('e1'))$$), null, 'Trưởng cơ sở lập: trình được');
select is((select approval_route || ':' || (select key from u where id = assigned_approver_id) from app.sales_order where id = pg_temp.o('e1')), 'TU_DUYET:bm1', 'R-HT-06: Trưởng cơ sở tự duyệt (chốt chính mình)');

-- ================= Duyệt đơn (Đ205: có quyền Duyệt VÀ đúng người đã chốt hoặc Admin thay) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('a1'))$$), 'HMT_KHONG_CO_QUYEN', 'Người lập (Sale) không có quyền Duyệt đơn');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('a1'))$$), 'HMT_KHONG_CO_QUYEN', 'Trưởng cơ sở CS5 không duyệt được đơn CS1 (ngoài phạm vi)');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('a1'))$$), 'HMT_KHONG_PHAI_NGUOI_DUYET', 'Đ205: có quyền Duyệt nhưng không phải người đã chốt thì chặn');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('a1'))$$), 'HMT_KHONG_CO_QUYEN', 'Admin chưa xác thực hai bước (aal1) không duyệt được');
-- Đ102: đơn có chính sách cần duyệt thì cần tích đồng ý. Dựng một đơn riêng.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('f1', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 5)))));
select app.save_order(pg_temp.o('f1'), null, pg_temp.term('CHIA_3_DOT'));
select is((select needs_acknowledgement from app.sales_order where id = pg_temp.o('f1')), true, 'Đ102: đơn có chính sách cần duyệt đặt cờ cần tích đồng ý');
select app.submit_order(pg_temp.o('f1'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
-- R-V2-11 (anh chốt 06/11, A4): không còn ô tích đồng ý; vượt trần hoặc chính sách cần duyệt chỉ cảnh báo, duyệt được ngay.
select is(pg_temp.err($$select app.approve_order(pg_temp.o('f1'))$$), null, 'R-V2-11: đơn có cờ cảnh báo duyệt được, không cần tích đồng ý');
select is((select acknowledged from app.sales_order where id = pg_temp.o('f1')), true, 'Ghi đơn có cờ cảnh báo lúc duyệt');
-- Duyệt thường: đơn a1.
select is(pg_temp.err($$select app.approve_order(pg_temp.o('a1'))$$), null, 'Người duyệt đã chốt (có quyền Duyệt): duyệt được');
select is(pg_temp.st('a1'), 'DA_DUYET', 'Sau duyệt: Đã duyệt');
select is((select approved_on_behalf from app.sales_order where id = pg_temp.o('a1')), false, 'Người đã chốt duyệt thì không phải duyệt thay');
select is((select count(*)::int from app.sales_order_installment where order_id = pg_temp.o('a1') and due_date = (now() at time zone 'Asia/Ho_Chi_Minh')::date + due_days), 2, 'R-TIEN-07: chốt hạn đóng từng đợt (ngày duyệt + số ngày)');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('a1'))$$), 'HMT_SAI_TRANG_THAI', 'Duyệt lần hai thì chặn');
-- R-CRM-27: hồ sơ học sinh được tìm hoặc tạo, gắn vào dòng đơn và dòng em.
select ok((select student_id is not null from app.sales_order_line where order_id = pg_temp.o('a1') and line_no = 1), 'R-CRM-27: duyệt đơn gắn hồ sơ học sinh vào dòng đơn');
select ok((select s.code ~ '^HS' from app.sales_order_line l join app.student s on s.id = l.student_id where l.order_id = pg_temp.o('a1') and l.line_no = 1), 'Hồ sơ học sinh có mã HS');
select is((select s.parent_id = o.parent_id from app.sales_order_line l join app.student s on s.id = l.student_id join app.sales_order o on o.id = l.order_id
            where l.order_id = pg_temp.o('a1') and l.line_no = 1), true, 'Hồ sơ học sinh thuộc phụ huynh của đơn');
select is((select ps.student_id = l.student_id from app.sales_order_line l join app.prospect_student ps on ps.id = l.prospect_student_id
            where l.order_id = pg_temp.o('a1') and l.line_no = 1), true, 'Dòng em của cơ hội gắn cùng hồ sơ học sinh (Đ86)');
-- Khớp lại: đơn khác cùng em dùng đúng hồ sơ cũ (không tạo trùng).
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('g1', '0900009001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 5)));
select app.save_order(pg_temp.o('g1'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('g1'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_order(pg_temp.o('g1'));
select is((select count(distinct l.student_id)::int from app.sales_order_line l where l.order_id in (pg_temp.o('a1'), pg_temp.o('g1'))), 1, 'R-CRM-27: cùng em ở hai đơn dùng chung một hồ sơ học sinh');
-- R-TIEN-35: kiểm lại khi duyệt (em bị xoá năm sinh sau khi trình).
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('h1', '0900009001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 2), 'LC-TOAN-K09', 'OFF', 5)));
select app.save_order(pg_temp.o('h1'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('h1'));
select pg_temp.sudo($$update app.prospect_student set birth_year = null where id = pg_temp.ps('0900009001', 2)$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('h1'))$$), 'HMT_EM_THIEU_THONG_TIN', 'R-TIEN-35: kiểm lại em đủ họ tên, năm sinh cả lúc duyệt');
select is(pg_temp.st('h1'), 'DA_TRINH', 'Bị chặn lúc duyệt thì đơn vẫn Đã trình');
-- KD6: hai em khác dòng danh sách nhưng cùng tên và năm sinh trong một đơn.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('k1', '0900009003', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009003', 1), 'LC-TOAN-K09', 'OFF', 10), pg_temp.line(pg_temp.ps('0900009003', 2), 'LC-TOAN-K09', 'OFF', 10)));
select app.save_order(pg_temp.o('k1'), null, pg_temp.term('CHIA_3_DOT'));
select is(pg_temp.err($$select app.submit_order(pg_temp.o('k1'))$$), null, 'KD6: trình được (chỉ chặn lúc duyệt)');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('k1'))$$), 'HMT_EM_TRUNG_TEN_NAM_SINH', 'KD6: hai em trùng họ tên và năm sinh trong một đơn thì chặn, không tự gộp');
select is((select count(*)::int from app.sales_order_line where order_id = pg_temp.o('k1') and student_id is not null), 0, 'KD6: bị chặn thì không tạo hồ sơ học sinh nào');
-- Một em hai dòng gói (cùng dòng em) không bị coi là trùng.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('k2', '0900009003', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009003', 1), 'LC-TOAN-K09', 'OFF', 10), pg_temp.line(pg_temp.ps('0900009003', 1), 'DV-CSGK', 'OFF', 3)));
select app.save_order(pg_temp.o('k2'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('k2'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('k2'))$$), null, 'Một em mua hai gói trong một đơn không bị coi là trùng');
-- Admin duyệt thay khi vắng (R-HT-01, aal2).
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('m1', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10)));
select app.save_order(pg_temp.o('m1'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('m1'));
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('m1'))$$), null, 'R-HT-01: Admin (aal2) duyệt thay khi vắng được');
select is((select approved_on_behalf from app.sales_order where id = pg_temp.o('m1')), true, 'Ghi "duyệt thay"');
select is((select count(*)::int from app.sales_order_event where order_id = pg_temp.o('m1') and event_code = 'DUYET' and on_behalf), 1, 'Lịch sử ghi duyệt thay');

-- ================= Từ chối đơn (R-TIEN-06) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('n1', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10)));
select app.save_order(pg_temp.o('n1'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('n1'));
select is(pg_temp.err($$select app.reject_order(pg_temp.o('n1'), 'KHONG_DUNG_CHINH_SACH', 'x')$$), 'HMT_KHONG_CO_QUYEN', 'Người lập không từ chối được đơn của mình');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('n1'), 'KHONG_DUNG_CHINH_SACH', 'x')$$), 'HMT_KHONG_PHAI_NGUOI_DUYET', 'Người không phải người duyệt đã chốt không từ chối được');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('n1'), 'SAI_SO_TIEN', 'x')$$), 'HMT_LY_DO_THIEU', 'Lý do chỉ dành cho phiếu thu thì không dùng cho đơn (Đ103)');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('n1'), 'KHAC', null)$$), 'HMT_LY_DO_THIEU', 'Chọn Khác mà không ghi chú thì chặn (R-HT-04)');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('n1'), 'KHONG_DUNG_CHINH_SACH', 'Giá chưa đúng')$$), null, 'Người duyệt đã chốt từ chối kèm lý do: được');
select is(pg_temp.st('n1'), 'NHAP', 'R-TIEN-06: từ chối đưa đơn về Nháp');
select is((select assigned_approver_id is null and submitted_at is null from app.sales_order where id = pg_temp.o('n1')), true, 'Từ chối xoá người duyệt đã chốt (chốt lại lúc trình lại)');
select is(pg_temp.ev('n1'), 'TAO,TRINH,TU_CHOI', 'Lịch sử giữ lần trình và lần từ chối');
select is((select reason_code from app.sales_order_event where order_id = pg_temp.o('n1') and event_code = 'TU_CHOI'), 'KHONG_DUNG_CHINH_SACH', 'Lịch sử ghi lý do từ chối');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('n1'))$$), null, 'Sửa xong trình lại được');
select is(pg_temp.ev('n1'), 'TAO,TRINH,TU_CHOI,TRINH', 'Trình lại: lịch sử giữ lần từ chối cũ');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('a1'), 'KHONG_DUNG_CHINH_SACH', 'x')$$), 'HMT_KHONG_CO_QUYEN', 'Sale không từ chối đơn');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('a1'), 'KHONG_DUNG_CHINH_SACH', 'x')$$), 'HMT_SAI_TRANG_THAI', 'Chỉ từ chối được đơn Đã trình (đơn đã duyệt thì không)');

-- ================= Chuyển đơn từ báo giá (R-TIEN-14, Đ201, R-TIEN-02) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009010', '{"parent_name": "Chị Từ Báo Giá", "student_name": "Em Một", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900009010'));
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Hai Báo Giá', 2014 from app.opportunity o where o.id = pg_temp.oid('0900009010')$$);
insert into qs select 'q1', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009010'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009010', 1), 'LC-TOAN-K09', 'OFF', 10), pg_temp.line(pg_temp.ps('0900009010', 2), 'LC-TOAN-K09', 'OFF', 5))) as r) x;
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'))$$), 'HMT_BAO_GIA_CHUA_GUI', 'R-TIEN-14: chỉ báo giá Đã gửi mới chuyển đơn (báo giá Nháp bị chặn)');
select app.send_quotation(pg_temp.q('q1'));
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'))$$), 'HMT_CHUA_O_L8', 'R-CRM-16: cơ hội chưa L8 thì không chuyển được báo giá thành đơn');
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id = pg_temp.oid('0900009010')$$);
-- Giá đổi và báo giá quá hạn: đơn vẫn lấy giá đã đóng băng lúc Gửi (Đ201).
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'OFF', 777000, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1 from app.sales_package where code = 'LC-TOAN-K09'$$);
select pg_temp.sudo($$update app.quotation set valid_until = current_date - 30 where id = pg_temp.q('q1')$$);
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'), array[2, 2, 9])$$), 'HMT_DONG_KHONG_CO', 'Số dòng không thuộc báo giá thì chặn');
insert into os select 'p1', (r ->> 'id')::uuid, r ->> 'code' from (select app.create_order_from_quotation(pg_temp.q('q1'), array[1]) as r) x;
select is((select array[unit_price::text, line_total::text, quotation_line_id is not null::text] from app.sales_order_line where order_id = pg_temp.o('p1')),
          array['220000', '2200000', 'true'], 'Đ201, R-TIEN-14: đơn từ báo giá sao nguyên giá đã đóng băng, kể cả khi báo giá quá hạn');
select is((select quotation_id = pg_temp.q('q1') from app.sales_order where id = pg_temp.o('p1')), true, 'Đơn nhớ báo giá gốc');
select is(pg_temp.qlive(pg_temp.q('q1')), true, 'Báo giá có đơn đang sống');
select is(pg_temp.qconv(pg_temp.q('q1')), false, 'Mới chuyển một trong hai dòng: chưa "Đã chuyển đơn"');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'), array[1])$$), 'HMT_DONG_DA_CO_DON', 'R-TIEN-02: dòng đã nằm trong đơn đang sống thì chặn');
select is(pg_temp.err($$select app.reject_quotation(pg_temp.q('q1'), 'KHONG_DUNG_CHINH_SACH', 'x')$$), 'HMT_BAO_GIA_DA_CO_DON', 'Báo giá có đơn sống không từ chối được');
select is(pg_temp.err($$select app.cancel_quotation(pg_temp.q('q1'))$$), 'HMT_BAO_GIA_DA_CO_DON', 'Báo giá có đơn sống không huỷ được');
insert into os select 'p2', (r ->> 'id')::uuid, r ->> 'code' from (select app.create_order_from_quotation(pg_temp.q('q1')) as r) x;
select is((select count(*)::int from app.sales_order_line where order_id = pg_temp.o('p2')), 1, 'Chọn mọi dòng: chỉ lấy dòng còn lại chưa nằm trong đơn sống');
select is(pg_temp.qconv(pg_temp.q('q1')), true, 'R-TIEN-02: mọi dòng nằm trong đơn sống thì báo giá "Đã chuyển đơn"');
select is(app.get_quotation(pg_temp.q('q1')) ->> 'display_status_code', 'DA_CHUYEN_DON', 'Bản ghi báo giá hiện Đã chuyển đơn');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'))$$), 'HMT_KHONG_CO_DONG_DE_CHUYEN', 'Hết dòng để chuyển thì báo rõ');
select is(array(select c from unnest(pg_temp.docs(pg_temp.oid('0900009010'))) c order by c),
          array(select c from unnest(array[(select code from qs where key = 'q1'), (select code from os where key = 'p1'), (select code from os where key = 'p2')]) c order by c),
          'Đ106: giấy tờ của cơ hội gồm báo giá và đơn chưa huỷ');
-- Hai chiều của cờ đang sống (R-TIEN-02): chỉ mục duy nhất từng phần.
select throws_ok($$select pg_temp.sudo('insert into app.sales_order_line (order_id, line_no, quotation_line_id, prospect_student_id, package_id, package_code, package_name,
    package_type_code, delivery_mode_code, unit_code, quantity, unit_price, gross_amount, line_total)
  select o.id, 9, l.quotation_line_id, l.prospect_student_id, l.package_id, l.package_code, l.package_name, l.package_type_code, l.delivery_mode_code,
         l.unit_code, 1, 1, 1, 1 from app.sales_order_line l join app.sales_order o on o.id = pg_temp.o(''p2'') where l.order_id = pg_temp.o(''p1'') limit 1')$$,
          '23505', null, 'Cờ đang sống: hai dòng đơn sống cùng một dòng báo giá bị chỉ mục chặn');
-- Huỷ đơn p1: trả dòng về báo giá (is_live tắt), tạo lại được.
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('p1'), 'KHACH_DOI_Y')$$), null, 'Người lập huỷ đơn Nháp của mình: được');
select is((select bool_or(is_live) from app.sales_order_line where order_id = pg_temp.o('p1')), false, 'Huỷ đơn tắt cờ đang sống của dòng');
select is(pg_temp.qconv(pg_temp.q('q1')), false, 'Đơn huỷ trả dòng về báo giá: không còn "Đã chuyển đơn"');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'), array[1])$$), null, 'Sau huỷ, dòng chuyển đơn lại được (chiều ngược của cờ)');
select is(array(select c from unnest(pg_temp.docs(pg_temp.oid('0900009010'))) c where c = (select code from os where key = 'p1')), array[]::text[], 'Đ106: đơn huỷ không còn tính là giấy tờ của cơ hội');
-- Báo giá không phải Đã gửi: Từ chối, Huỷ.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
insert into qs select 'q2', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009010'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009010', 1), 'LC-TOAN-K09', 'OFF', 3))) as r) x;
select app.send_quotation(pg_temp.q('q2'));
select app.reject_quotation(pg_temp.q('q2'), 'KHONG_DUNG_CHINH_SACH', 'x');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q2'))$$), 'HMT_BAO_GIA_CHUA_GUI', 'R-TIEN-14: báo giá Từ chối không chuyển đơn được');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'))$$), 'HMT_KHONG_CO_QUYEN', 'Sale CS5 không chuyển báo giá CS1 thành đơn');

-- ================= Huỷ đơn (R-TIEN-38, Đ202, Đ204) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('x1', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10)));
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x1'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_DUOC_HUY_DON', 'Đ204: Sale không huỷ được đơn Nháp của người khác');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x1'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_DUOC_HUY_DON', 'R-TIEN-38: đơn Nháp chỉ người lập huỷ (Trưởng cơ sở không phải người lập thì không)');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x1'), null)$$), 'HMT_LY_DO_THIEU', 'R-TIEN-38: huỷ phải chọn lý do');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x1'), 'KHAC', null)$$), 'HMT_LY_DO_THIEU', 'R-TIEN-38: lý do Khác bắt buộc ghi chú');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x1'), 'KHONG_CO_LY_DO_NAY')$$), 'HMT_LY_DO_THIEU', 'Lý do ngoài danh mục thì chặn');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x1'), 'KHAC', 'Nhập nhầm cơ hội')$$), null, 'R-TIEN-38: người lập huỷ đơn Nháp của mình, lý do Khác kèm ghi chú');
select is(pg_temp.st('x1'), 'HUY', 'Đơn huỷ có trạng thái Huỷ');
select is((select cancel_reason_code || ':' || cancel_note from app.sales_order where id = pg_temp.o('x1')), 'KHAC:Nhập nhầm cơ hội', 'Ghi lý do và ghi chú huỷ');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x1'), 'KHACH_DOI_Y')$$), 'HMT_SAI_TRANG_THAI', 'Huỷ lần hai thì chặn');
select is(pg_temp.err($$select app.save_order(pg_temp.o('x1'), null, pg_temp.term('CHIA_3_DOT'))$$), 'HMT_DON_DA_KHOA', 'Đơn huỷ không sửa được');
-- Đơn Đã trình: người lập không huỷ; người duyệt đã chốt huỷ; người khác không.
select pg_temp.mk('x2', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10)));
select app.save_order(pg_temp.o('x2'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('x2'));
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x2'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_DUOC_HUY_DON', 'R-TIEN-38: đơn Đã trình thì người lập không huỷ được');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x2'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_DUOC_HUY_DON', 'R-TIEN-38: người không phải người duyệt đã chốt không huỷ được');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x2'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_CO_QUYEN', 'Kế toán không có quyền Huỷ đơn');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
-- Có phiếu thu thì không huỷ (hàm kiểm trả true tạm trong giao dịch thử).
select pg_temp.sudo($$create or replace function app.order_has_receipt(p_order_id uuid) returns boolean language sql stable set search_path = '' as 'select true'$$);
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x2'), 'KHACH_DOI_Y')$$), 'HMT_DON_DA_CO_PHIEU_THU', 'R-TIEN-38: đơn đã có phiếu thu thì không huỷ được');
select is(pg_temp.st('x2'), 'DA_TRINH', 'Bị chặn thì đơn giữ nguyên trạng thái');
select pg_temp.sudo($$create or replace function app.order_has_receipt(p_order_id uuid) returns boolean language sql stable set search_path = '' as 'select false'$$);
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x2'), 'KHACH_DOI_Y')$$), null, 'R-TIEN-38: người duyệt đã chốt huỷ đơn Đã trình (chưa có phiếu thu)');
-- Đơn Đã duyệt: Admin huỷ thay khi vắng; ghi "huỷ thay".
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('a1'), 'CHON_NHAM_GOI_LOP')$$), null, 'Người duyệt đã chốt huỷ đơn Đã duyệt (chưa có phiếu thu)');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('m1'), 'THAY_BANG_DON_KHAC')$$), null, 'R-HT-06: Admin huỷ thay khi vắng được');
select is((select on_behalf from app.sales_order_event where order_id = pg_temp.o('m1') and event_code = 'HUY'), true, 'Lịch sử ghi huỷ thay');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('x3', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10)));
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('x3'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_CO_QUYEN', 'Admin chưa xác thực hai bước không huỷ được');

-- ================= Đ215: không kiểm người lập khi lưu, trình; người duyệt chốt theo người lập; ghi người trình =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('z1', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10)));
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.save_order(pg_temp.o('z1'), null, pg_temp.term('CHIA_3_DOT'))$$), null,
          'Đ215: đồng nghiệp cùng cơ sở có quyền Sửa lưu được đơn Nháp của người khác');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('z1'))$$), null, 'Đ215: đồng nghiệp cùng cơ sở trình được đơn Nháp của người khác');
select is((select assigned_approver_id from app.sales_order where id = pg_temp.o('z1')), pg_temp.uid('bm1'),
          'Đ215: người duyệt vẫn chốt theo NGƯỜI LẬP (quản lý của sales1 là bm1)');
select is((select submitted_by from app.sales_order where id = pg_temp.o('z1')), pg_temp.uid('cskh1'), 'Đ215: ghi người trình (submitted_by)');
select is((select created_by from app.sales_order where id = pg_temp.o('z1')), pg_temp.uid('sales1'), 'Đ215: người lập vẫn là người tạo đơn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('z2', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10)));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.save_order(pg_temp.o('z2'), null, pg_temp.term('CHIA_3_DOT'))$$), 'HMT_KHONG_CO_QUYEN', 'Đ215: khác cơ sở thì vẫn không sửa được (quyền theo cơ sở)');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('z2'))$$), 'HMT_KHONG_CO_QUYEN', 'Đ215: khác cơ sở thì vẫn không trình được');

-- ================= Lịch sử, trạng thái, RLS, nhật ký =================
select throws_ok($$select pg_temp.sudo('update app.sales_order_event set note = ''sửa''')$$, null, null, 'Lịch sử đơn chỉ thêm: không sửa được');
select throws_ok($$select pg_temp.sudo('delete from app.sales_order_event')$$, null, null, 'Lịch sử đơn chỉ thêm: không xoá được');
select throws_ok($$select pg_temp.sudo('update app.sales_order set status_code = ''DA_DUYET'' where id = pg_temp.o(''x3'')')$$, null, null, 'Trạng thái đơn không nhảy từ Nháp sang Đã duyệt');
select throws_ok($$select pg_temp.sudo('update app.sales_order set status_code = ''NHAP'' where id = pg_temp.o(''x1'')')$$, null, null, 'Đơn Huỷ không quay lại');
select throws_ok($$select pg_temp.sudo('update app.sales_order set code = ''DH-SUA'' where id = pg_temp.o(''x3'')')$$, null, null, 'Mã đơn không đổi được');
select throws_ok($$select pg_temp.sudo('insert into app.sales_order (code, branch_id, parent_id, priced_on) select ''DHT-KHONG-GOC'', branch_id, parent_id, current_date from app.sales_order limit 1')$$,
                 '23514', null, 'Đ187: đơn phải có đúng một gốc (không gốc thì bị CHECK chặn)');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select ok((select count(*) from app.sales_order) >= 10, 'Sale CS1 đọc được đơn cơ sở mình');
select is((select count(*)::int from app.sales_order where branch_id <> (select branch_id from app.user_account where id = auth.uid())), 0, 'Sale CS1 không đọc đơn cơ sở khác');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((select count(*)::int from app.sales_order where code like 'DH-CS1-%'), 0, 'Sale CS5 không thấy đơn CS1 (RLS)');
select is((select count(*)::int from app.sales_order_line l join app.sales_order o on o.id = l.order_id where o.code like 'DH-CS1-%'), 0, 'Sale CS5 không thấy dòng đơn CS1');
select is((select count(*)::int from app.sales_order_event where order_id = pg_temp.o('a1')), 0, 'Sale CS5 không thấy lịch sử đơn CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select ok((select count(distinct branch_id) from app.sales_order) >= 1 and (select count(*) from app.sales_order) >= 10, 'Kế toán đọc đơn toàn hệ thống');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is((select count(*)::int from app.sales_order), 0, 'Học sinh không thấy đơn nào');
select throws_ok($$insert into app.sales_order (code, branch_id, parent_id, priced_on, opportunity_id) select 'DH-GHI-TRUC-TIEP', branch_id, parent_id, current_date, opportunity_id from app.sales_order limit 1$$,
                 '42501', null, 'Ghi thẳng vào bảng đơn bị từ chối (chỉ qua hàm)');

select * from finish();
rollback;
