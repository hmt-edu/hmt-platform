-- Migration 218 (Code D): hoàn phí và phiếu chi. Luật: R-TIEN-28, R-TIEN-31, R-TIEN-34, R-CS-07, R-V2-24. Dữ liệu giả.
-- Dựng đơn thật (cơ hội → đơn → phiếu thu → kế toán duyệt) như 064; hai hàm cấp giờ là nội bộ nên gọi bằng quyền chủ.
-- Đảo khoản (R-TIEN-26) chưa có ở main nên chưa kiểm phần giờ giảm theo tiền đảo.
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
  select jsonb_build_object('parent_name', 'Chị Hoàn Phí', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('bm1b'), ('sales1'), ('sales5'), ('ke');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d216.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d216.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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

-- ---------- Dựng đơn ----------
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('a', 0);
select pg_temp.mkclass('q', 1);
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900007001', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900007002', '{"student_name": "Em Hai", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900007003', '{"student_name": "Em Bốn", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900007001'));
select app.create_opportunity(pg_temp.lid('0900007002'));
select app.create_opportunity(pg_temp.lid('0900007003'));
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Ba', 2014 from app.opportunity o where o.id = pg_temp.oid('0900007002')$$);
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in (pg_temp.oid('0900007001'), pg_temp.oid('0900007002'), pg_temp.oid('0900007003'))$$);
create function pg_temp.mkorder(p_key text, p_phone text, p_lines jsonb) returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_order_from_opportunity(pg_temp.oid(p_phone), p_lines);
  insert into os values (p_key, (v ->> 'id')::uuid);
  -- Giờ tặng 2 giờ cho dòng 1 của d2 (đơn còn Nháp nên sửa được).
  if p_key = 'd2' then
    perform pg_temp.sudo(format('update app.sales_order_line set gifted_quantity = 2 where order_id = %L and line_no = 1', (v ->> 'id')));
  end if;
  perform app.save_order((v ->> 'id')::uuid, null, pg_temp.term('COC_VA_CHIA_DOT'));
  perform app.submit_order((v ->> 'id')::uuid);
  perform pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
  perform app.approve_order((v ->> 'id')::uuid);
  perform pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
end $$;
grant execute on function pg_temp.mkorder(text, text, jsonb) to public;
-- d1: một dòng 10 giờ vào lớp a (K09, đã duyệt). d2: hai dòng 10 giờ và 5 giờ, chưa chọn lớp. d3: một dòng vào lớp q (chỉ 1 chỗ).
select pg_temp.mkorder('d1', '0900007001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900007001', 1), 'LC-TOAN-K09', 'OFF', 10)
   || jsonb_build_object('class_id', pg_temp.c('a'), 'enrol_start_date', pg_temp.mon())));
select pg_temp.mkorder('d2', '0900007002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900007002', 1), 'LC-TOAN-K09', 'OFF', 10),
                                                              pg_temp.line(pg_temp.ps('0900007002', 2), 'LC-TOAN-K09', 'OFF', 5)));
select pg_temp.mkorder('d3', '0900007003', jsonb_build_array(pg_temp.line(pg_temp.ps('0900007003', 1), 'LC-TOAN-K09', 'OFF', 10)
   || jsonb_build_object('class_id', pg_temp.c('q'), 'enrol_start_date', pg_temp.mon())));

-- ---------- Số liệu: d1 thu đủ thành tiền dòng; d3 chỉ đặt cọc ----------
select pg_temp.sudo($$create function pg_temp.lt() returns bigint language sql stable security definer as 'select line_total from app.sales_order_line where order_id = pg_temp.o(''d1'')'$$);
select pg_temp.sudo($$create function pg_temp.up() returns bigint language sql stable security definer as 'select unit_price from app.sales_order_line where order_id = pg_temp.o(''d1'')'$$);
select pg_temp.sudo($$create function pg_temp.d1e() returns uuid language sql stable security definer as 'select id from app.enrollment where order_id = pg_temp.o(''d1'')'$$);
select pg_temp.sudo($$create function pg_temp.d3e() returns uuid language sql stable security definer as 'select id from app.enrollment where order_id = pg_temp.o(''d3'')'$$);
select pg_temp.sudo($$create function pg_temp.cr(p_enr uuid, p_kind text, p_hours numeric default null) returns jsonb language sql security definer as 'select app.compute_refund(p_enr, p_kind, p_hours)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.lt(), pg_temp.up(), pg_temp.d1e(), pg_temp.d3e(), pg_temp.cr(uuid, text, numeric) to public$$);
select pg_temp.pay('d1', pg_temp.lt());
select pg_temp.pay('d3', 1000000);
-- Học 2 giờ ở d1 (giả lập buổi Done); d3 học 9 giờ để hết tiền.
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, session_id)
  select pg_temp.d1e(), s.branch_id, 'TRU_BUOI', -2, s.id from app.class_session s where s.class_id = pg_temp.c('a') and s.type_code = 'CHINH' order by s.session_date limit 1$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, session_id)
  select pg_temp.d3e(), s.branch_id, 'TRU_BUOI', -9, s.id from app.class_session s where s.class_id = pg_temp.c('q') and s.type_code = 'CHINH' order by s.session_date limit 1$$);
select pg_temp.sudo($$create function pg_temp.hrs(p_enr uuid) returns numeric language sql stable security definer as 'select app.enrollment_hours_balance(p_enr)'$$);
select pg_temp.sudo($$create function pg_temp.est(p_enr uuid) returns text language sql stable security definer as 'select status_code from app.enrollment where id = p_enr'$$);
select pg_temp.sudo($$grant execute on function pg_temp.hrs(uuid), pg_temp.est(uuid) to public$$);
create temp table rf (key text primary key, id uuid);
grant all on rf to public;
create function pg_temp.f(p_key text) returns uuid language sql stable as $$ select id from rf where key = p_key $$;
grant execute on function pg_temp.f(text) to public;

-- ================= Công tắc, quyền, đầu vào =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.create_refund_request(pg_temp.d1e(), 'MOT_PHAN', 3, 'KHONG_HOP')$$), 'HMT_TINH_NANG_TAT', 'Chặn: công tắc HOAN_PHI tắt');
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'HOAN_PHI', id, true from app.branch where code = 'CS1' on conflict (module_code, branch_id) do update set enabled = true$$);
select is(pg_temp.err($$select app.create_refund_request(pg_temp.d1e(), 'MOT_PHAN', 99, 'KHONG_HOP')$$), 'HMT_HOAN_PHI_GIO_SAI', 'Chặn: hoàn một phần quá giờ còn lại (qua compute_refund)');
select is(pg_temp.err($$select app.create_refund_request(pg_temp.d1e(), 'MOT_PHAN', 3, 'KHONG_CO_MA')$$), 'HMT_DANH_MUC_KHONG_CO', 'Chặn: mã lý do không có trong danh mục');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.create_refund_request(pg_temp.d1e(), 'MOT_PHAN', 3, 'KHONG_HOP')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không có quyền Sửa ghi danh');

-- ================= Hoàn một phần: tạo, duyệt hai bước, phiếu chi =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok($$insert into rf select 'a', app.create_refund_request(pg_temp.d1e(), 'MOT_PHAN', 3, 'KHONG_HOP', 'Phụ huynh xin hoàn', 'DN-TEST')$$, 'Đúng: tạo yêu cầu hoàn một phần 3 giờ');
select is((select refund_amount from app.refund_request where id = pg_temp.f('a')), (pg_temp.cr(pg_temp.d1e(), 'MOT_PHAN', 3) ->> 'refund_amount')::bigint, 'Số tiền chụp lúc tạo khớp compute_refund');
select is(pg_temp.err($$select app.create_refund_request(pg_temp.d1e(), 'MOT_PHAN', 1, 'KHONG_HOP')$$), 'HMT_HOAN_PHI_DANG_MO', 'Chặn: ghi danh đã có yêu cầu chưa xong');
select is(pg_temp.err($$select app.approve_refund_manager(pg_temp.f('a'))$$), 'HMT_HOAN_PHI_KHONG_DUOC_SUA', 'Chặn: quản lý duyệt khi chưa trình');
select lives_ok($$select app.submit_refund_request(pg_temp.f('a'))$$, 'Đúng: trình duyệt');
select is(pg_temp.err($$select app.approve_refund_manager(pg_temp.f('a'))$$), 'HMT_HOAN_PHI_TU_DUYET', 'Chặn: người tạo không tự duyệt');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.approve_refund_manager(pg_temp.f('a'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Kế toán không duyệt ở bước quản lý cơ sở');
select is(pg_temp.err($$select app.approve_refund_accountant(pg_temp.f('a'))$$), 'HMT_HOAN_PHI_KHONG_DUOC_SUA', 'Chặn: Kế toán duyệt trước khi quản lý duyệt');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select lives_ok($$select app.approve_refund_manager(pg_temp.f('a'))$$, 'Đúng: quản lý khác duyệt');
select is(pg_temp.err($$select app.approve_refund_accountant(pg_temp.f('a'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không có quyền Kế toán duyệt (R-TIEN-01)');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is((select hours from (select pg_temp.hrs(pg_temp.d1e()) hours) x), 8::numeric, 'Trước khi duyệt: còn 8 giờ (10 mua − 2 đã học)');
select lives_ok($$insert into rf select 'pv', app.approve_refund_accountant(pg_temp.f('a'))$$, 'Đúng: Kế toán duyệt, sinh phiếu chi');
select is(pg_temp.hrs(pg_temp.d1e()), 5::numeric, 'Sổ giờ ngược dấu đúng 3 giờ hoàn (8 → 5) (R-GD-04)');
select is(pg_temp.est(pg_temp.d1e()), 'DA_XEP_LOP', 'Hoàn một phần: ghi danh giữ nguyên tình trạng');
select is((select amount from app.payment_voucher where id = pg_temp.f('pv')), (select refund_amount from app.refund_request where id = pg_temp.f('a')), 'Phiếu chi đúng số tiền hoàn');
select ok((select code from app.payment_voucher where id = pg_temp.f('pv')) ~ '^PC-CS1-\d{4}-\d{4}$', 'Mã phiếu chi dạng PC-CS-YYMM-STT (spec 02)');
select is((select status_code from app.refund_request where id = pg_temp.f('a')), 'DA_DUYET', 'Yêu cầu sang Đã duyệt');
select is(pg_temp.err($$select app.approve_refund_accountant(pg_temp.f('a'))$$), 'HMT_HOAN_PHI_KHONG_DUOC_SUA', 'Chặn: duyệt hai lần (không ghi sổ giờ hai lần)');
select lives_ok($$select app.pay_payment_voucher(pg_temp.f('pv'), 'Chuyển khoản')$$, 'Đúng: ghi nhận đã chi');
select is((select status_code from app.refund_request where id = pg_temp.f('a')), 'DA_CHI', 'Yêu cầu sang Đã chi');
select is(pg_temp.err($$select app.pay_payment_voucher(pg_temp.f('pv'))$$), 'HMT_PHIEU_CHI_DA_CHI', 'Chặn: chi hai lần');

-- ================= Hoàn toàn bộ =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok($$insert into rf select 'b', app.create_refund_request(pg_temp.d1e(), 'TOAN_BO', null, 'CHUYEN_NOI_O')$$, 'Đúng: tạo yêu cầu hoàn toàn bộ');
select app.submit_refund_request(pg_temp.f('b'));
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select app.approve_refund_manager(pg_temp.f('b'));
-- Có buổi Done mới giữa chừng: số liệu đổi, kế toán duyệt bị chặn.
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, session_id)
  select pg_temp.d1e(), s.branch_id, 'TRU_BUOI', -1, s.id from app.class_session s
   where s.class_id = pg_temp.c('a') and s.type_code = 'CHINH' and s.id not in (select session_id from app.hour_ledger where session_id is not null and enrollment_id = pg_temp.d1e())
   order by s.session_date limit 1$$);
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.approve_refund_accountant(pg_temp.f('b'))$$), 'HMT_HOAN_PHI_SO_LIEU_DOI', 'Chặn: giờ đã học đổi sau khi tạo thì không duyệt, phải tạo lại');
select lives_ok($$select app.reject_refund_request(pg_temp.f('b'), 'Số liệu đổi, tạo lại')$$, 'Đúng: kế toán từ chối kèm lý do');
select is(pg_temp.err($$select app.reject_refund_request(pg_temp.f('b'), 'x')$$), 'HMT_HOAN_PHI_KHONG_DUOC_SUA', 'Chặn: từ chối yêu cầu đã từ chối');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok($$insert into rf select 'c', app.create_refund_request(pg_temp.d1e(), 'TOAN_BO', null, 'TAI_CHINH')$$, 'Tạo lại yêu cầu hoàn toàn bộ');
select app.submit_refund_request(pg_temp.f('c'));
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select app.approve_refund_manager(pg_temp.f('c'));
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select lives_ok($$insert into rf select 'pv2', app.approve_refund_accountant(pg_temp.f('c'))$$, 'Đúng: kế toán duyệt hoàn toàn bộ');
select is(pg_temp.hrs(pg_temp.d1e()), 0::numeric, 'Hoàn toàn bộ: giờ còn lại về 0 (giờ tặng bị huỷ)');
select is(pg_temp.est(pg_temp.d1e()), 'HOAN_PHI', 'Hoàn toàn bộ: ghi danh sang Hoàn phí');
select is((select count(*)::int from app.enrollment_class where enrollment_id = pg_temp.d1e() and end_date is null), 0, 'Hoàn toàn bộ: đóng dòng xếp lớp đang mở');
select is(pg_temp.err($$select app.create_refund_request(pg_temp.d1e(), 'TOAN_BO', null, 'KHAC')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Kế toán không có quyền Sửa ghi danh để tạo yêu cầu');

-- ================= Huỷ, RLS, quyền gọi =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.create_refund_request(pg_temp.d1e(), 'TOAN_BO', null, 'KHAC')$$), 'HMT_HOAN_PHI_GHI_DANH_SAI', 'Chặn: ghi danh đã Hoàn phí không hoàn nữa');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((select count(*)::int from app.refund_request) + (select count(*)::int from app.payment_voucher), 0, 'RLS: người cơ sở khác không thấy yêu cầu hoàn phí và phiếu chi CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select ok((select count(*) from app.payment_voucher) >= 2, 'Kế toán thấy phiếu chi');
select is(pg_temp.err($$insert into app.payment_voucher (code) values ('X')$$), '42501', 'Chặn: không ghi thẳng vào phiếu chi');
select is(pg_temp.err($$select app.refund_request_for_update(gen_random_uuid(), array['NHAP'])$$), '42501', 'Chặn: hàm nội bộ không cấp cho giao diện');

select * from finish();
rollback;
