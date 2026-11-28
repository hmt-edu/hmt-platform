-- B-26-03 PR-DB2 (CAO: tiền, giờ học): dòng tặng. Mức của chính sách Tặng không tính trần; không cộng vào tổng niêm yết;
-- chụp giá niêm yết; được cấp giờ khi đơn thu đủ phần có thu tiền; hoàn tác thu thì thu hồi bằng dòng sổ ngược.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d1b3.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d1b3.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm1b', 'CS1'), ('sales1', 'CS1'), ('sales5', 'CS5'), ('ke', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm1b', 'BRANCH_MANAGER'), ('sales1', 'SALES'),
  ('sales5', 'SALES'), ('ke', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select m, id, true from app.branch, (values ('BAN_HANG'), ('VAN_HANH_LOP')) v (m) where code = 'CS1'
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
-- ---------- Lớp, hàm hỗ trợ ----------
create temp table cl (key text primary key, id uuid);
grant all on cl to public;
create function pg_temp.c(p_key text) returns uuid language sql stable as $$ select id from cl where key = p_key $$;
create function pg_temp.mon() returns date language sql stable as $$ select (date_trunc('week', current_date) + interval '14 days')::date $$;
create function pg_temp.mkclass(p_key text, p_max integer) returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS1'), 'year_code', '2627', 'subject_code', 'TOAN',
    'grade_code', 'K09', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', p_max, 'start_date', pg_temp.mon(), 'total_sessions', 4,
    'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
                                                  'first_date', pg_temp.mon(), 'teacher_id', pg_temp.uid('bm1')))));
  insert into cl values (p_key, (v ->> 'id')::uuid);
  perform app.transition_class((v ->> 'id')::uuid, 'DA_TRINH');
  perform app.transition_class((v ->> 'id')::uuid, 'DA_XAC_NHAN');
  perform app.transition_class((v ->> 'id')::uuid, 'DA_DUYET');
end $$;
-- Gọi hàm nội bộ bằng quyền chủ, trả JSON.
create function pg_temp.enr(p_order text) returns jsonb language plpgsql security definer as $$
begin return app.create_enrollments_for_order(pg_temp.o(p_order)); end $$;
create function pg_temp.hours(p_order text, p_kind text) returns numeric language sql stable security definer as $$
  select coalesce(sum(l.hours), 0) from app.hour_ledger l join app.enrollment e on e.id = l.enrollment_id where e.order_id = pg_temp.o(p_order) and l.entry_type = p_kind $$;
create function pg_temp.nenr(p_order text) returns integer language sql stable security definer as $$ select count(*)::int from app.enrollment where order_id = pg_temp.o(p_order) $$;
-- Một phiếu thu đi hết chuỗi duyệt: lập → gửi → quản lý → kế toán.
create function pg_temp.pay(p_order text, p_amount bigint) returns void language plpgsql as $$
declare v jsonb; v_id uuid;
begin
  perform pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
  v := app.create_receipt(pg_temp.o(p_order), jsonb_build_object('amount', p_amount, 'payment_method_code', 'TIEN_MAT'));
  v_id := (v ->> 'id')::uuid;
  perform app.submit_receipt(v_id);
  perform pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
  perform app.approve_receipt_manager(v_id);
  perform pg_temp.claims(pg_temp.uid('ke'), 'aal2');
  perform app.approve_receipt_accounting(v_id);
  perform pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
end $$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Dựng ----------
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
create function pg_temp.cs(p_code text, p_extra jsonb) returns text language sql as $$
  select pg_temp.err(format('select app.save_discount_policy(null, %L::jsonb)',
    jsonb_build_object('code', p_code, 'name', 'Chính sách thử', 'kind', 'PERCENT', 'max_value', 100, 'fixed_value', true,
                       'valid_from', '2026-01-01', 'is_gift', true) || p_extra)) $$;
grant execute on function pg_temp.cs(text, jsonb) to public;
select is(pg_temp.cs('CK_TANG', '{}'), null, 'Chính sách Tặng: phần trăm, áp đúng mức 100 thì tạo được');
select is(pg_temp.cs('CK_TANG50', '{"max_value": 50}'), 'HMT_CHINH_SACH_SAI', 'Chính sách Tặng mức khác 100 bị chặn');
select is(pg_temp.cs('CK_TANGMO', '{"fixed_value": false}'), 'HMT_CHINH_SACH_SAI', 'Chính sách Tặng không áp đúng mức bị chặn');
select is(pg_temp.cs('CK_TANGGIO', '{"kind": "GIFT_HOURS", "fixed_value": false}'), 'HMT_CHINH_SACH_SAI', 'Chính sách Tặng kiểu giờ tặng bị chặn');
select is(pg_temp.cs('CK_THUONG100', '{"is_gift": false}'), null, 'Chính sách thường mức 100 vẫn tạo được');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.cs('CK_SALE', '{}'), 'HMT_KHONG_CO_QUYEN', 'Sale không tạo được chính sách');
select app.create_lead(pg_temp.lead_data('0900076001', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900076001'));
select pg_temp.sudo($$create function pg_temp.pol(p_code text) returns uuid language sql stable security definer as 'select id from app.discount_policy where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.pol(text) to public$$);
-- Dòng có danh sách chính sách.
create function pg_temp.l(p_qty numeric, p_pols text[] default '{}') returns jsonb language sql as $$
  select pg_temp.line(pg_temp.ps('0900076001', 1), 'LC-TOAN-K09', 'OFF', p_qty) || jsonb_build_object('discounts',
    coalesce((select jsonb_agg(jsonb_build_object('policy_id', pg_temp.pol(c), 'value', case when c = 'GIAM_THUONG_LUONG' then 5 end)) from unnest(p_pols) c), '[]'::jsonb)) $$;
grant execute on function pg_temp.l(numeric, text[]) to public;
create function pg_temp.pv(p_lines jsonb) returns jsonb language sql as $$
  select app.preview_quotation_lines(pg_temp.oid('0900076001'), p_lines) $$;
grant execute on function pg_temp.pv(jsonb) to public;

-- ================= Trần, cảnh báo =================
select is(pg_temp.pv(jsonb_build_array(pg_temp.l(10, '{CK_TANG}'))) -> 'lines' -> 0 ->> 'over_cap', 'false', 'Chính sách Tặng không tính vào trần chiết khấu');
select is(pg_temp.pv(jsonb_build_array(pg_temp.l(10, '{CK_TANG}'))) -> 'warnings', '[]'::jsonb, 'Dòng tặng không gây cảnh báo vượt trần');
select is(pg_temp.pv(jsonb_build_array(pg_temp.l(10, '{CK_TANG}'))) -> 'lines' -> 0 ->> 'line_total', '0', 'Dòng tặng thành tiền 0');
select is(pg_temp.pv(jsonb_build_array(pg_temp.l(10, '{CK_TANG}'))) -> 'lines' -> 0 ->> 'list_unit_price', '220000', 'Dòng tặng chụp giá niêm yết');
select is(pg_temp.pv(jsonb_build_array(pg_temp.l(10, '{CK_THUONG100}'))) -> 'lines' -> 0 ->> 'over_cap', 'true', 'Giảm 100% bằng chính sách thường vẫn tính vào trần');
select is(pg_temp.pv(jsonb_build_array(pg_temp.l(10, '{CK_THUONG100}'))) -> 'lines' -> 0 ->> 'is_gift_line', 'false', 'Giảm 100% thường không phải dòng tặng');
select is(pg_temp.pv(jsonb_build_array(pg_temp.l(10, '{CK_TANG,TANG_GIO}')
            || jsonb_build_object('discounts', jsonb_build_array(jsonb_build_object('policy_id', pg_temp.pol('CK_TANG')), jsonb_build_object('policy_id', pg_temp.pol('TANG_GIO'), 'value', 4))))) -> 'lines' -> 0 ->> 'over_cap',
          'true', 'Giờ tặng trên dòng tặng vẫn tính vào trần');
select is(pg_temp.err($$select pg_temp.pv(jsonb_build_array(pg_temp.l(10, '{CK_TANG,GIAM_THUONG_LUONG}')))$$), 'HMT_CHIET_KHAU_SAI', 'Tặng cộng thêm chiết khấu khác quá 100% bị chặn');

-- ================= Tổng niêm yết, giá trị quà =================
create temp table q as select (app.save_quotation(null, pg_temp.oid('0900076001'), jsonb_build_array(pg_temp.l(10), pg_temp.l(4, '{CK_TANG}'))) ->> 'id')::uuid as id;
grant select on q to public;
select is(app.get_quotation((select id from q)) ->> 'gross_total', '2200000', 'Tổng niêm yết không cộng dòng tặng');
select is(app.get_quotation((select id from q)) ->> 'discount_total', '0', 'Tổng chiết khấu không cộng dòng tặng');
select is(app.get_quotation((select id from q)) ->> 'total_amount', '2200000', 'Số phải trả đúng');
select is(app.get_quotation((select id from q)) -> 'lines' -> 1 ->> 'list_unit_price', '220000', 'Bản ghi báo giá trả giá niêm yết của dòng tặng');
select app.send_quotation((select id from q));
select is(app.get_quotation((select id from q)) -> 'lines' -> 1 ->> 'is_gift_line', 'true', 'Gửi báo giá giữ cờ dòng tặng');
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id = pg_temp.oid('0900076001')$$);
insert into os select 'g', (app.create_order_from_quotation((select id from q)) ->> 'id')::uuid;
select is(app.get_order(pg_temp.o('g')) -> 'lines' -> 1 ->> 'is_gift_line', 'true', 'Đơn từ báo giá sao cờ dòng tặng (R-TIEN-14)');
select is(app.get_order(pg_temp.o('g')) -> 'lines' -> 1 ->> 'list_unit_price', '220000', 'Đơn sao giá niêm yết đã chụp');
select is(app.get_order(pg_temp.o('g')) ->> 'gross_total', '2200000', 'Đơn: tổng niêm yết không cộng dòng tặng');

-- ================= Sửa đơn Nháp: thêm dòng tặng, đổi dòng thường ↔ dòng tặng =================
create function pg_temp.sua(p_edits jsonb) returns jsonb language sql as $$ select app.edit_order(pg_temp.o('g'), p_edits) $$;
create function pg_temp.dl(p_no integer) returns jsonb language sql as $$ select app.get_order(pg_temp.o('g')) -> 'lines' -> (p_no - 1) $$;
grant execute on function pg_temp.sua(jsonb), pg_temp.dl(integer) to public;
select lives_ok($$select pg_temp.sua(jsonb_build_array(jsonb_build_object('add', pg_temp.l(2, '{CK_TANG}'))))$$, 'Sửa đơn: thêm được dòng tặng');
select is(pg_temp.dl(3) ->> 'is_gift_line', 'true', 'Dòng thêm vào đơn mang cờ dòng tặng');
select is(pg_temp.dl(3) ->> 'list_unit_price', '220000', 'Dòng thêm vào đơn chụp giá niêm yết');
select is(pg_temp.dl(3) ->> 'over_cap', 'false', 'Dòng tặng thêm vào đơn không vượt trần');
select is(app.get_order(pg_temp.o('g')) ->> 'gross_total', '2200000', 'Thêm dòng tặng không đổi tổng niêm yết');
select is(app.get_order(pg_temp.o('g')) ->> 'total_amount', '2200000', 'Thêm dòng tặng không đổi số phải trả');
select pg_temp.sua('[{"line_no": 3, "remove": true}]');
select pg_temp.sua(jsonb_build_array(jsonb_build_object('line_no', 1, 'discounts', jsonb_build_array(jsonb_build_object('policy_id', pg_temp.pol('CK_TANG'))))));
select is(pg_temp.dl(1) ->> 'is_gift_line', 'true', 'Đổi ưu đãi dòng thường sang Tặng thì thành dòng tặng');
select is(app.get_order(pg_temp.o('g')) ->> 'gross_total', '0', 'Đơn toàn dòng tặng: tổng niêm yết bằng 0');
select pg_temp.sua('[{"line_no": 1, "discounts": []}]');
select is(pg_temp.dl(1) ->> 'is_gift_line', 'false', 'Bỏ ưu đãi Tặng thì dòng trở lại dòng thường');
select is(app.get_order(pg_temp.o('g')) ->> 'gross_total', '2200000', 'Dòng trở lại thường được cộng vào tổng niêm yết');

-- ================= Cấp giờ =================
select app.save_order(pg_temp.o('g'), null, pg_temp.term('COC_VA_CHIA_DOT'));
select app.submit_order(pg_temp.o('g'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_order(pg_temp.o('g'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.pay('g', 1100000);
select is(pg_temp.nenr('g'), 2, 'Dòng tặng cũng có ghi danh riêng');
select is(pg_temp.hours('g', 'CAP_MUA'), 5.00::numeric, 'Thu một nửa: chỉ dòng có thu tiền được giờ theo tỉ lệ');
select is(pg_temp.hours('g', 'CAP_TANG'), 0::numeric, 'Chưa thu đủ: dòng tặng chưa được giờ');
select pg_temp.pay('g', 1100000);
select is(pg_temp.hours('g', 'CAP_MUA'), 10.00::numeric, 'Thu đủ: đủ giờ mua');
select is(pg_temp.hours('g', 'CAP_TANG'), 4.00::numeric, 'Thu đủ phần có thu tiền: dòng tặng được đủ giờ');
select is((select array[purchased_hours, gifted_hours] from app.enrollment e join app.sales_order_line l on l.id = e.order_line_id
            where l.order_id = pg_temp.o('g') and l.line_no = 2), array[0, 4]::numeric[], 'Ghi danh dòng tặng: giờ mua 0, giờ tặng 4');

-- ================= Hoàn tác phiếu thu: thu hồi giờ tặng bằng dòng ngược (R-GD-04) =================
select pg_temp.sudo($$insert into app.setting_branch (setting_key, branch_id, value) select 'money_reversal_enabled', id, 'true' from app.branch where code = 'CS1'
  on conflict (setting_key, branch_id) do update set value = 'true'$$);
select pg_temp.sudo($$create function pg_temp.dao() returns void language plpgsql as $f$
begin perform app.reverse_money_in((select id from app.money_in where order_id = pg_temp.o('g') and amount > 0 order by created_at desc, code desc limit 1), 'NHAP_SAI_SO_TIEN'); end $f$ $$);
select pg_temp.sudo($$grant execute on function pg_temp.dao() to public$$);
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select lives_ok($$select pg_temp.dao()$$, 'Kế toán hoàn tác một khoản thu');
select is(pg_temp.hours('g', 'CAP_TANG'), 0::numeric, 'Hoàn tác làm đơn không còn thu đủ: thu hồi giờ của dòng tặng');
select is(pg_temp.hours('g', 'CAP_MUA'), 5.00::numeric, 'Giờ mua về đúng tỉ lệ tiền còn lại');
select pg_temp.sudo($$create function pg_temp.tang_dong() returns numeric[] language sql security definer as $f$
  select array_agg(l.hours order by l.seq) from app.hour_ledger l join app.enrollment e on e.id = l.enrollment_id
   where e.order_id = pg_temp.o('g') and l.entry_type = 'CAP_TANG' $f$ $$);
select pg_temp.sudo($$grant execute on function pg_temp.tang_dong() to public$$);
select is(pg_temp.tang_dong(), array[4, -4]::numeric[], 'Thu hồi bằng dòng sổ ngược, không sửa dòng cũ');

-- ================= Dòng quà (dịch vụ, tài liệu): giá trị quà =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
create temp table gq as select app.preview_quotation_lines(pg_temp.oid('0900076001'), jsonb_build_array(pg_temp.l(10),
  jsonb_build_object('kind', 'GIFT', 'prospect_student_id', pg_temp.ps('0900076001', 1), 'quantity', 1,
                     'gift_policy_id', (select id from app.gift_policy where code = 'QUA_TAI_LIEU')))) as r;
select is((select r -> 'lines' -> 1 ->> 'list_unit_price' from gq), '150000', 'Dòng quà chụp giá niêm yết để hiện Giá trị quà');
select is((select r -> 'lines' -> 1 ->> 'unit_price' from gq), '0', 'Dòng quà đơn giá vẫn 0');
select is((select r ->> 'total_amount' from gq), '2200000', 'Giá trị quà không tính vào tổng');

-- ================= Đơn đã có giữ cờ đã chụp khi chính sách đổi (R-TIEN-14) =================
reset role;
select pg_temp.sudo($$update app.discount_policy set is_gift = false where code = 'CK_TANG'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(app.get_order(pg_temp.o('g')) -> 'lines' -> 1 ->> 'is_gift_line', 'true', 'Chính sách bỏ cờ Tặng sau đó: đơn cũ giữ dòng tặng');
select is(app.get_order(pg_temp.o('g')) ->> 'gross_total', '2200000', 'Đơn cũ giữ tổng niêm yết');
select is(pg_temp.pv(jsonb_build_array(pg_temp.l(10, '{CK_TANG}'))) -> 'lines' -> 0 ->> 'is_gift_line', 'false', 'Báo giá tính mới theo cờ hiện tại của chính sách');
reset role;
select pg_temp.sudo($$update app.discount_policy set is_gift = true where code = 'CK_TANG'$$);
select is((select p.unit_price from app.enrollment_recognized_prices() p
             join app.enrollment e on e.id = p.enrollment_id join app.sales_order_line l on l.id = e.order_line_id
            where l.order_id = pg_temp.o('g') and l.line_no = 2), null::numeric, 'Giờ của dòng tặng không có giá ghi nhận doanh thu (không tiền chia về dòng)');

-- ================= Đơn chỉ gồm dòng tặng (tổng 0 đồng): chưa cấp giờ, chờ anh Trường quyết =================
select app.create_lead(pg_temp.lead_data('0900076002', '{"student_name": "Em Hai", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where parent_phone = '0900076002'$$);
select app.create_opportunity(pg_temp.lid('0900076002'));
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id = pg_temp.oid('0900076002')$$);
create temp table q0 as select (app.save_quotation(null, pg_temp.oid('0900076002'), jsonb_build_array(
  pg_temp.line(pg_temp.ps('0900076002', 1), 'LC-TOAN-K09', 'OFF', 4)
    || jsonb_build_object('discounts', jsonb_build_array(jsonb_build_object('policy_id', pg_temp.pol('CK_TANG')))))) ->> 'id')::uuid as id;
grant select on q0 to public;
select app.send_quotation((select id from q0));
insert into os select 'z', (app.create_order_from_quotation((select id from q0)) ->> 'id')::uuid;
select app.save_order(pg_temp.o('z'), null, pg_temp.term('COC_VA_CHIA_DOT'));
select app.submit_order(pg_temp.o('z'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_order(pg_temp.o('z'));
select is(app.get_order(pg_temp.o('z')) ->> 'total_amount', '0', 'Đơn toàn dòng tặng: số phải trả 0');
select pg_temp.enr('z');
select is(pg_temp.hours('z', 'CAP_TANG') + pg_temp.hours('z', 'CAP_MUA'), 0::numeric, 'Đơn toàn dòng tặng: chưa cấp giờ');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= Đơn tái tục (R-GD-13) có dòng tặng =================
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH676', 'Phụ huynh giả 676', '0900676009', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HS676A', id, 'Em Tái Tục', 2012, branch_id from app.parent where code = 'PH676'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions, status_code, max_students)
  select 'LOP676', id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10, 'DA_DUYET', 0 from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code, delivery_mode_code)
  select 'GD676A', s.id, s.parent_id, s.branch_id, 'DANG_HOC', 'OFF' from app.student s where s.code = 'HS676A'$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date - 30 from app.enrollment e, app.class c where e.code = 'GD676A' and c.code = 'LOP676'$$);
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time)
  select c.id, c.branch_id, current_date + n, '18:00', '19:30' from app.class c, generate_series(1, 3) n where c.code = 'LOP676'$$);
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, origin_code)
  select 'TT976001', s.branch_id, s.id, s.parent_id, c.id, 'L8', 'TAY' from app.student s, app.class c where s.code = 'HS676A' and c.code = 'LOP676'$$);
select pg_temp.sudo($$create function pg_temp.tid() returns uuid language sql stable security definer as 'select id from app.upsale_ticket where code = ''TT976001'''$$);
select pg_temp.sudo($$grant execute on function pg_temp.tid() to public$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
insert into os select 'tt', (app.create_order_from_upsale_ticket(pg_temp.tid(), jsonb_build_array(
  jsonb_build_object('kind', 'ENROL', 'package_id', pg_temp.pkg('LC-TOAN-K09'), 'quantity', 10, 'discounts', '[]'::jsonb),
  jsonb_build_object('kind', 'ENROL', 'package_id', pg_temp.pkg('LC-TOAN-K09'), 'quantity', 3,
                     'discounts', jsonb_build_array(jsonb_build_object('policy_id', pg_temp.pol('CK_TANG')))))) ->> 'id')::uuid;
select is(app.get_order(pg_temp.o('tt')) -> 'lines' -> 1 ->> 'is_gift_line', 'true', 'Đơn tái tục: dòng gắn Tặng là dòng tặng');
select is(app.get_order(pg_temp.o('tt')) -> 'lines' -> 1 ->> 'list_unit_price', '220000', 'Đơn tái tục: chụp giá niêm yết dòng tặng');
select is(app.get_order(pg_temp.o('tt')) ->> 'gross_total', '2200000', 'Đơn tái tục: tổng niêm yết không cộng dòng tặng');
select is(app.get_order(pg_temp.o('tt')) -> 'lines' -> 1 ->> 'over_cap', 'false', 'Đơn tái tục: dòng tặng không vượt trần');

select * from finish();
rollback;
