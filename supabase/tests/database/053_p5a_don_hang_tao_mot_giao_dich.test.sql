-- P5a-DB-O1b (migration 061, Đ256, Đ260): find_student_match (tách từ find_or_create_student), preview_order_students, tạo đơn kèm điều khoản trong MỘT giao dịch. Phần dựng dữ liệu giống 044.

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

create temp table pvx (k text primary key, r jsonb);
grant all on pvx to public;
create function pg_temp.parent_of(p_phone text) returns uuid language sql stable as $$ select parent_id from app.opportunity where id = pg_temp.oid(p_phone) $$;
create function pg_temp.pre(p_key text) returns jsonb language sql as $$ select app.preview_order_students(pg_temp.o(p_key)) $$;
create function pg_temp.outcomes(p_key text) returns text[] language sql as $$
  select array_agg(x ->> 'outcome' order by (x ->> 'line_no')::int) from jsonb_array_elements(pg_temp.pre(p_key) -> 'lines') x $$;
grant execute on function pg_temp.parent_of(text), pg_temp.pre(text), pg_temp.outcomes(text) to public;
select pg_temp.sudo($$create function pg_temp.pr(p_phone text) returns uuid language sql stable security definer as 'select parent_id from app.opportunity where id = pg_temp.oid(p_phone)'$$);

-- ================= find_student_match (R-CRM-27) =================
select pg_temp.sudo($$create function pg_temp.fsm(p_phone text, p_name text, p_year integer) returns uuid language sql stable security definer as
  'select app.find_student_match(pg_temp.pr(p_phone), p_name, p_year)'$$);
select pg_temp.sudo($$create function pg_temp.foc(p_phone text, p_name text, p_year integer) returns uuid language sql security definer as
  'select app.find_or_create_student(pg_temp.pr(p_phone), p_name, p_year, null, null, null, null, (select id from app.branch where code = ''CS1''))'$$);
select pg_temp.sudo($$grant execute on function pg_temp.fsm(text, text, integer), pg_temp.foc(text, text, integer), pg_temp.pr(text) to public$$);
select is(pg_temp.fsm('0900009001', 'Em Một', 2012), null, 'find_student_match: chưa có hồ sơ thì null');
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select app.issue_person_code('HS'), parent_id, 'Em Một', 2012, branch_id from app.opportunity where id = pg_temp.oid('0900009001')$$);
select isnt(pg_temp.fsm('0900009001', 'Em Một', 2012), null, 'find_student_match: khớp theo phụ huynh, tên và năm sinh');
select is(pg_temp.fsm('0900009001', 'em một', 2012), pg_temp.fsm('0900009001', 'Em Một', 2012), 'find_student_match: tên chuẩn hoá (hoa thường) vẫn khớp');
select is(pg_temp.fsm('0900009001', 'Em Một', 2013), null, 'find_student_match: khác năm sinh thì không khớp');
select is(pg_temp.fsm('0900009002', 'Em Một', 2012), null, 'find_student_match: phụ huynh khác thì không khớp');
-- Hồ sơ đã gộp trả bản giữ lại (R-CRM-25).
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select app.issue_person_code('HS'), parent_id, 'Em Gộp', 2011, branch_id from app.opportunity where id = pg_temp.oid('0900009002')$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id, merged_into_id, record_status)
  select app.issue_person_code('HS'), parent_id, 'Em Gộp', 2011, branch_id, (select id from app.student where full_name = 'Em Gộp' and merged_into_id is null limit 1), 'DA_GOP'
    from app.opportunity where id = pg_temp.oid('0900009002')$$);
select is(pg_temp.fsm('0900009002', 'Em Gộp', 2011), (select id from app.student where full_name = 'Em Gộp' and merged_into_id is null), 'R-CRM-25: hồ sơ đã gộp trả bản giữ lại');
-- find_or_create_student: hành vi không đổi.
select is(pg_temp.foc('0900009001', 'Em Một', 2012), pg_temp.fsm('0900009001', 'Em Một', 2012), 'find_or_create_student: đã có thì trả hồ sơ cũ');
select is((select count(*)::int from app.student where full_name = 'Em Một'), 1, 'find_or_create_student: đã có thì không tạo thêm');
insert into pvx select 'moi', to_jsonb(pg_temp.foc('0900009001', 'Em Mới Tinh', 2015));
select is((select count(*)::int from app.student where full_name = 'Em Mới Tinh'), 1, 'find_or_create_student: chưa có thì tạo một hồ sơ mới');
select is(pg_temp.err($$select pg_temp.foc('0900009001', '  ', 2015)$$), 'HMT_THIEU_HOC_SINH', 'find_or_create_student: thiếu tên thì chặn (HMT_THIEU_HOC_SINH)');
select is(pg_temp.err($$select pg_temp.foc('0900009001', 'Em Không Năm', null)$$), 'HMT_THIEU_HOC_SINH', 'find_or_create_student: thiếu năm sinh thì chặn');
select is(pg_temp.err($$select app.find_student_match(pg_temp.pr('0900009001'), 'Em Một', 2012)$$), '42501', 'find_student_match là hàm nội bộ: không gọi được qua rpc');

-- ================= preview_order_students (BH-07) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
-- n1: hai em Em Một (đã có hồ sơ khớp ở trên) và Em Hai (chưa có).
select is(pg_temp.outcomes('n1'), array['DUNG_HO_SO', 'TAO_MOI'], 'BH-07: em khớp hồ sơ có sẵn ghi "dùng hồ sơ", em chưa có ghi "tạo mới"');
select is(pg_temp.pre('n1') -> 'lines' -> 0 ->> 'student_name', 'Em Một', 'Xem trước: nêu tên em');
select is((pg_temp.pre('n1') -> 'lines' -> 0 ->> 'birth_year')::int, 2012, 'Xem trước: nêu năm sinh');
select ok(pg_temp.pre('n1') -> 'lines' -> 0 ->> 'student_code' like 'HS%', 'Xem trước: nêu mã hồ sơ sẽ dùng');
select is(pg_temp.pre('n1') -> 'lines' -> 1 ->> 'student_code', null, 'Xem trước: em sẽ tạo mới chưa có mã');
select is(pg_temp.pre('n1') -> 'duplicates', 'null'::jsonb, 'Xem trước: không có em trùng thì duplicates rỗng');
-- Em đã gắn hồ sơ (n3 đã duyệt).
select is(pg_temp.outcomes('n3'), array['DA_CO_HO_SO'], 'Đơn đã duyệt: em đã gắn hồ sơ học sinh (DA_CO_HO_SO)');
-- Em thiếu năm sinh.
select pg_temp.mk('n10', '0900009001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 3), 'LC-TOAN-K09', 'OFF', 2)));
select is(pg_temp.outcomes('n10'), array['THIEU_THONG_TIN'], 'R-TIEN-35: em thiếu năm sinh ghi THIEU_THONG_TIN (sẽ bị chặn lúc trình)');
-- Hai em trùng họ tên và năm sinh trong một đơn (KD6).
select pg_temp.mk('n11', '0900009003', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009003', 1), 'LC-TOAN-K09', 'OFF', 2), pg_temp.line(pg_temp.ps('0900009003', 2), 'LC-TOAN-K09', 'OFF', 2)));
select is(pg_temp.pre('n11') ->> 'duplicates', 'Em Sinh Đôi (2012)', 'KD6: báo hai em trùng họ tên và năm sinh');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('n11'))$$) is not null, true, 'Duyệt đơn có hai em trùng vẫn bị chặn như trước (order_link_students đổi nơi tìm trùng, hành vi không đổi)');
-- Quyền và phạm vi.
select is(pg_temp.err($$select app.preview_order_students(pg_temp.o('n1'))$$), null, 'Sale xem trước đơn cơ sở mình');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.preview_order_students(pg_temp.o('n1'))$$), 'HMT_KHONG_CO_QUYEN', 'Sale CS5 không xem trước đơn CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.preview_order_students(pg_temp.o('n1'))$$), null, 'Kế toán (xem mọi cơ sở) xem trước được');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.preview_order_students(pg_temp.o('n1'))$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không xem trước đơn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.preview_order_students('00000000-0000-0000-0000-000000000000')$$), 'HMT_KHONG_TIM_THAY', 'Đơn không có: báo không tìm thấy');
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select is(pg_temp.err($$select app.preview_order_students(pg_temp.o('n1'))$$), null, 'Đ181: tắt Bán hàng vẫn xem trước được (hàm đọc thuần)');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);

-- ================= Tạo đơn kèm điều khoản trong một giao dịch (Đ260, R-CRM-19) =================
-- Báo giá Đã gửi trên cơ hội L8 (0900009002).
insert into qs select 'q7', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009002'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_6_THANG'))))) as r) x;
select app.send_quotation(pg_temp.q('q7'));
-- Đổi bảng giá SAU khi gửi: hôm nay lên 999.000 (R-TIEN-14: đơn từ báo giá giữ giá đã đóng băng).
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'OFF', 999000, (now() at time zone 'Asia/Ho_Chi_Minh')::date from app.sales_package where code = 'LC-TOAN-K09'
  on conflict (package_id, delivery_mode_code, effective_from) do update set unit_price = 999000$$);
-- Điều khoản sai: không có đơn, mã không nhảy số.
select pg_temp.sudo($$create function pg_temp.dh_count() returns integer language sql security definer as 'select count(*)::int from app.sales_order'$$);
select pg_temp.sudo($$create function pg_temp.dh_seq() returns integer language sql security definer as 'select coalesce(max(right(code, 4)::int), 0) from app.sales_order where code like ''DH-CS1-%'''$$);
select pg_temp.sudo($$grant execute on function pg_temp.dh_count(), pg_temp.dh_seq() to public$$);
insert into pvx select 'truoc', jsonb_build_object('n', pg_temp.dh_count(), 'seq', pg_temp.dh_seq());
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q7'), null, '00000000-0000-0000-0000-000000000000')$$), 'HMT_KHONG_TIM_THAY', 'Đ260: điều khoản không có thì báo lỗi (HMT_KHONG_TIM_THAY)');
select is(pg_temp.dh_count(), ((select r ->> 'n' from pvx where k = 'truoc'))::int, 'Đ260: điều khoản sai thì không có đơn Nháp rác');
select pg_temp.sudo($$update app.payment_term set is_active = false where code = 'COC_VA_CHIA_DOT'$$);
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q7'), null, pg_temp.term('COC_VA_CHIA_DOT'))$$), 'HMT_KHONG_TIM_THAY', 'Điều khoản đã ngừng dùng thì cũng báo lỗi, không tạo đơn');
select pg_temp.sudo($$update app.payment_term set is_active = true where code = 'COC_VA_CHIA_DOT'$$);
select is(pg_temp.dh_count(), ((select r ->> 'n' from pvx where k = 'truoc'))::int, 'Điều khoản ngừng dùng: vẫn không có đơn');
-- Điều khoản đúng: tạo đơn và lịch đợt trong một lần gọi.
insert into os select 'n12', (r ->> 'id')::uuid, r ->> 'code' from (select app.create_order_from_quotation(pg_temp.q('q7'), null, pg_temp.term('CHIA_3_DOT')) as r) x;
select is(pg_temp.dh_seq(), ((select r ->> 'seq' from pvx where k = 'truoc'))::int + 1, 'R-CRM-19: lùi giao dịch (điều khoản sai) không làm nhảy mã đơn; mã kế tiếp liền sau mã cũ');
select is((select payment_term_id from app.sales_order where id = pg_temp.o('n12')), pg_temp.term('CHIA_3_DOT'), 'Tạo kèm điều khoản: đơn có điều khoản');
select is((select count(*)::int from app.sales_order_installment where order_id = pg_temp.o('n12')), 3, 'Tạo kèm điều khoản: sinh đủ ba đợt theo lịch');
select is((select sum(amount) from app.sales_order_installment where order_id = pg_temp.o('n12'))::bigint, (select total_amount from app.sales_order where id = pg_temp.o('n12')), 'Tổng các đợt bằng tổng đơn (R-TIEN-07)');
select is((select status_code from app.sales_order where id = pg_temp.o('n12')), 'NHAP', 'Đơn tạo ra ở trạng thái Nháp');
-- Ảnh chụp giá, chiết khấu, giờ của dòng đơn = của dòng báo giá (R-TIEN-13, R-TIEN-14), không tính lại theo giá 999.000.
select is((select unit_price from app.sales_order_line where order_id = pg_temp.o('n12') limit 1),
          (select unit_price from app.quotation_line where quotation_id = pg_temp.q('q7') limit 1), 'R-TIEN-14: đơn giá của dòng đơn giữ giá đã đóng băng lúc Gửi (không theo bảng giá mới)');
select is((select unit_price from app.sales_order_line where order_id = pg_temp.o('n12') limit 1), 220000::bigint, 'Đơn giá vẫn 220.000, không phải 999.000');
select is((select (discount_percent, line_total, gifted_quantity, quantity) from app.sales_order_line where order_id = pg_temp.o('n12') limit 1)::text,
          (select (discount_percent, line_total, gifted_quantity, quantity) from app.quotation_line where quotation_id = pg_temp.q('q7') limit 1)::text, 'Chiết khấu, thành tiền, giờ tặng, số lượng của dòng đơn khớp dòng báo giá');
-- Đơn thẳng từ cơ hội: tính theo giá NGÀY TẠO ĐƠN (999.000), kèm điều khoản.
insert into os select 'n13', (r ->> 'id')::uuid, r ->> 'code' from (select app.create_order_from_opportunity(pg_temp.oid('0900009003'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009003', 1), 'LC-TOAN-K09', 'OFF', 5)), pg_temp.term('CHIA_3_DOT'), true) as r) x;
select is((select unit_price from app.sales_order_line where order_id = pg_temp.o('n13') limit 1), 999000::bigint, 'Đ213: đơn thẳng tính theo giá ngày tạo đơn');
select is((select count(*)::int from app.sales_order_installment where order_id = pg_temp.o('n13')), 3, 'Đơn thẳng tạo kèm điều khoản: sinh đủ ba đợt');
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900009003'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900009003', 1), 'LC-TOAN-K09', 'OFF', 5)), '00000000-0000-0000-0000-000000000000', true)$$), 'HMT_KHONG_TIM_THAY', 'Đơn thẳng: điều khoản sai thì cả giao dịch lùi');
select is((select count(*)::int from app.sales_order where opportunity_id = pg_temp.oid('0900009003')), 3, 'Đơn thẳng: điều khoản sai không để lại đơn Nháp rác (cơ hội này có đúng ba đơn: n3, n11, n13)');
-- Lời gọi cũ (hai tham số) vẫn chạy, không điều khoản.
insert into os select 'n14', (r ->> 'id')::uuid, r ->> 'code' from (select app.create_order_from_opportunity(pg_temp.oid('0900009003'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009003', 1), 'LC-TOAN-K09', 'OFF', 1)), null, true) as r) x;
select is((select payment_term_id from app.sales_order where id = pg_temp.o('n14')), null, 'Lời gọi hai tham số vẫn chạy: không điều khoản, chưa có lịch đợt');
-- save_order dùng chung app.order_apply_term: hành vi không đổi.
select is(pg_temp.err($$select app.save_order(pg_temp.o('n14'), null, '00000000-0000-0000-0000-000000000000')$$), 'HMT_KHONG_TIM_THAY', 'save_order: điều khoản không có vẫn báo lỗi như trước');
select is((app.save_order(pg_temp.o('n14'), null, pg_temp.term('CHIA_3_DOT')) ->> 'id')::uuid, pg_temp.o('n14'), 'save_order: gán điều khoản vẫn được');
select is((select count(*)::int from app.sales_order_installment where order_id = pg_temp.o('n14')), 3, 'save_order: lịch đợt vẫn tính lại sau khi gán điều khoản');
select is(pg_temp.err($$select app.order_apply_term(pg_temp.o('n14'), pg_temp.term('CHIA_3_DOT'))$$), '42501', 'order_apply_term là hàm nội bộ: không gọi được qua rpc');
-- Quyền, phạm vi, công tắc.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q7'), null, pg_temp.term('CHIA_3_DOT'))$$), 'HMT_KHONG_CO_QUYEN', 'Sale CS5 không tạo đơn từ báo giá CS1');
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900009003'), '[]'::jsonb, pg_temp.term('CHIA_3_DOT'))$$) is not null, true, 'Sale CS5 không tạo đơn thẳng cho cơ hội CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q7'), null, pg_temp.term('CHIA_3_DOT'))$$), 'HMT_KHONG_CO_QUYEN', 'Kế toán (không có quyền tạo đơn) bị chặn');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q7'), null, null)$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh bị chặn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q7'), null, pg_temp.term('CHIA_3_DOT'))$$), 'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì không tạo đơn');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);

select * from finish();
rollback;
