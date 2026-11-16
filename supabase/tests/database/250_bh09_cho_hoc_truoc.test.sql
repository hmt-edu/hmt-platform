-- BH-09 Cho học trước, đóng tiền sau (migration 250). Luật R-GD-12 (quản lý cơ sở bật trên đơn đã duyệt chưa thu tiền; ghi danh tạo sớm; quỹ được âm trong hạn mức), R-TIEN-20 (đơn thường vẫn cần đủ cọc).
-- Mỗi luật có ca đúng và ca bị chặn. Dựng đơn thật như 107. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p250.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p250.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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
select pg_temp.mkclass('q', 1);
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900010001', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900010002', '{"student_name": "Em Bốn", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900010001'));
select app.create_opportunity(pg_temp.lid('0900010002'));
-- Cơ hội 1 có ba em (ít nhất 2 em, 3 dòng đơn).
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, p.pos, p.name, 2013 from app.opportunity o, (values (2, 'Em Hai'), (3, 'Em Ba')) p (pos, name) where o.id = pg_temp.oid('0900010001')$$);
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in (pg_temp.oid('0900010001'), pg_temp.oid('0900010002'))$$);
create function pg_temp.mkorder(p_key text, p_phone text, p_lines jsonb) returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_order_from_opportunity(pg_temp.oid(p_phone), p_lines, null, true);
  insert into os values (p_key, (v ->> 'id')::uuid);
  perform app.save_order((v ->> 'id')::uuid, null, pg_temp.term('COC_VA_CHIA_DOT'));
  perform app.submit_order((v ->> 'id')::uuid);
  perform pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
  perform app.approve_order((v ->> 'id')::uuid);
  perform pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
end $$;
grant execute on function pg_temp.mkorder(text, text, jsonb) to public;
-- m: ba dòng cho ba em (10 + 5 + 5 giờ), chưa chọn lớp. n: một dòng vào lớp q (chỉ 1 chỗ, sẽ bị lấp đầy).
select pg_temp.mkorder('m', '0900010001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900010001', 1), 'LC-TOAN-K09', 'OFF', 10),
                                                             pg_temp.line(pg_temp.ps('0900010001', 2), 'LC-TOAN-K09', 'OFF', 5),
                                                             pg_temp.line(pg_temp.ps('0900010001', 3), 'LC-TOAN-K09', 'OFF', 5)));
select pg_temp.mkorder('n', '0900010002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900010002', 1), 'LC-TOAN-K09', 'OFF', 10)
   || jsonb_build_object('class_id', pg_temp.c('q'), 'enrol_start_date', pg_temp.mon())));

create function pg_temp.pl(p_order text) returns jsonb language sql as $$ select app.set_order_pay_later(pg_temp.o(p_order), true, 'thử') $$;
create function pg_temp.enr_flag(p_order text, p_flag boolean) returns integer language sql stable security definer as $$
  select count(*)::int from app.enrollment where order_id = pg_temp.o(p_order) and pay_later_enabled = p_flag $$;
grant execute on function pg_temp.pl(text), pg_temp.enr_flag(text, boolean) to public;

-- ---- Cờ tắt mặc định ----
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((select value from app.setting_def where key = 'pay_later_toggle_enabled'), 'false', 'Cờ pay_later_toggle_enabled mặc định TẮT');
select is(pg_temp.err($$select pg_temp.pl('m')$$), 'HMT_TINH_NANG_TAT', 'Cờ tắt: Trưởng cơ sở không bật được');
select is(pg_temp.nenr('m'), 0, 'Chưa bật thì chưa có ghi danh (đơn chưa thu tiền)');
reset role;
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'pay_later_toggle_enabled'$$);
set local role authenticated;

-- ---- Quyền ----
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select pg_temp.pl('m')$$), 'HMT_KHONG_CO_QUYEN', 'Sale không bật được cho học trước (chỉ quản lý cơ sở)');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select pg_temp.pl('m')$$), 'HMT_KHONG_CO_QUYEN', 'Kế toán không bật được');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');

-- ---- Bật: ghi danh tạo sớm, không cần cọc ----
select is((pg_temp.pl('m') ->> 'enabled')::boolean, true, 'Trưởng cơ sở bật được trên đơn đã duyệt chưa thu tiền');
select is(pg_temp.nenr('m'), 3, 'R-GD-12: ghi danh tạo sớm cho cả 3 dòng, không cần đủ cọc');
select is(pg_temp.enr_flag('m', true), 3, 'Cả ba ghi danh đặt pay_later_enabled');
select is(pg_temp.hours('m', 'CAP_MUA'), 0::numeric, 'Chưa thu tiền nên chưa cấp giờ mua');
select is((select count(*)::int from app.sales_order_event where order_id = pg_temp.o('m') and event_code = 'CHO_HOC_TRUOC'), 1, 'Ghi dòng lịch sử đơn CHO_HOC_TRUOC');
select is((select enabled from app.order_pay_later where order_id = pg_temp.o('m')), true, 'Bảng trạng thái ghi enabled');

-- ---- Màn đơn vẫn đọc được sau khi bật (get_order, order_payment_summary không lỗi) ----
select is(pg_temp.err($$select app.get_order(pg_temp.o('m'))$$), null, 'Sau khi bật, đọc bản ghi đơn (get_order) không lỗi');
select is(pg_temp.err($$select app.order_payment_summary(pg_temp.o('m'))$$), null, 'Sau khi bật, tóm tắt thanh toán không lỗi');

-- ---- Chạy lại không nhân đôi ----
select is((pg_temp.pl('m') ->> 'enabled')::boolean, true, 'Bật lần hai không lỗi');
select is(pg_temp.nenr('m'), 3, 'Bật lần hai không tạo thêm ghi danh');

-- ---- Thu tiền sau: giờ cấp theo tiền, ghi danh giữ nguyên, cờ giữ ----
select pg_temp.pay('m', 1200000);
select is(pg_temp.nenr('m'), 3, 'Thu tiền sau khi cho học trước: không tạo thêm ghi danh');
select ok(pg_temp.hours('m', 'CAP_MUA') > 0, 'Thu tiền: giờ cấp theo tiền đã thu (R-TIEN-21)');
select is(pg_temp.enr_flag('m', true), 3, 'Cờ cho học trước giữ sau khi thu tiền');

-- ---- Bật bị chặn khi đơn đã thu tiền ----
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.pay('n', 1000000);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select pg_temp.pl('n')$$), 'HMT_DON_DA_THU', 'Đơn đã có tiền vào: không bật cho học trước');

-- ---- Tắt: chặn khi quỹ giờ âm, cho phép khi không âm ----
reset role;
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, reason_code)
  select e.id, e.branch_id, 'DIEU_CHINH', -(app.enrollment_hours_balance(e.id) + 2), 'KHAC'
    from app.enrollment e where e.order_id = pg_temp.o('m') order by e.code limit 1$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.set_order_pay_later(pg_temp.o('m'), false)$$), 'HMT_QUY_GIO_AM', 'Có ghi danh quỹ giờ âm: không tắt được');
reset role;
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, reason_code)
  select e.id, e.branch_id, 'DIEU_CHINH', 5, 'KHAC' from app.enrollment e where e.order_id = pg_temp.o('m') and app.enrollment_hours_balance(e.id) < 0$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.set_order_pay_later(pg_temp.o('m'), false) ->> 'enabled')::boolean, false, 'Quỹ giờ không âm: tắt được');
select is(pg_temp.enr_flag('m', true), 0, 'Tắt: mọi ghi danh bỏ cờ cho học trước');
select is((select count(*)::int from app.sales_order_event where order_id = pg_temp.o('m') and event_code = 'CHO_HOC_TRUOC'), 3, 'Lịch sử đơn ghi cả lần bật hai và lần tắt');

select * from finish();
rollback;
