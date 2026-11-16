-- Migration 232 (Code D): dừng học giữ số dư khách hàng. Luật: R-GD-16, R-TIEN-33, R-CS-07, R-V2-24. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('bm1'), ('bm1b'), ('sales1'), ('sales5'), ('ke'), ('bm5');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d217.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d217.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm1b', 'CS1'), ('sales1', 'CS1'), ('sales5', 'CS5'), ('ke', 'CS1'), ('bm5', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm1b', 'BRANCH_MANAGER'), ('sales1', 'SALES'),
  ('sales5', 'SALES'), ('ke', 'ACCOUNTANT'), ('bm5', 'BRANCH_MANAGER')) as v (key, role) on v.key = u.key;
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
select pg_temp.sudo($$create function pg_temp.est(p_enr uuid) returns text language sql stable security definer as 'select status_code from app.enrollment where id = p_enr'$$);
select pg_temp.sudo($$create function pg_temp.hrs(p_enr uuid) returns numeric language sql stable security definer as 'select app.enrollment_hours_balance(p_enr)'$$);
select pg_temp.sudo($$create function pg_temp.par(p_enr uuid) returns uuid language sql stable security definer as 'select parent_id from app.enrollment where id = p_enr'$$);
select pg_temp.sudo($$grant execute on function pg_temp.est(uuid), pg_temp.hrs(uuid), pg_temp.par(uuid) to public$$);
create temp table st (key text primary key, id uuid);
grant all on st to public;
create function pg_temp.s(p_key text) returns uuid language sql stable as $$ select id from st where key = p_key $$;
grant execute on function pg_temp.s(text) to public;

-- ================= Công tắc, quyền, đầu vào =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.create_enrollment_stop(pg_temp.d1e(), 'KHONG_HOP')$$), 'HMT_TINH_NANG_TAT', 'Chặn: công tắc DUNG_HOC tắt');
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'DUNG_HOC', id, true from app.branch where code = 'CS1' on conflict (module_code, branch_id) do update set enabled = true$$);
select is(pg_temp.err($$select app.create_enrollment_stop(pg_temp.d1e(), 'KHONG_CO_MA')$$), 'HMT_DANH_MUC_KHONG_CO', 'Chặn: mã lý do không có trong danh mục');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.create_enrollment_stop(pg_temp.d1e(), 'KHONG_HOP')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không có quyền Sửa ghi danh');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');

-- ================= Tính số dư (R-GD-16) =================
select lives_ok($$insert into st select 'a', app.create_enrollment_stop(pg_temp.d1e(), 'KHONG_HOP', 'Phụ huynh xin dừng', 'DN-TEST')$$, 'Đúng: tạo yêu cầu dừng học giữ số dư');
select is((select hours_left from app.enrollment_stop where id = pg_temp.s('a')), 8::numeric, 'Giờ còn lại 8 (10 mua − 2 đã học)');
select is((select hours_paid_left from app.enrollment_stop where id = pg_temp.s('a')), 8::numeric, 'Giờ mua còn lại 8, không có giờ tặng bị huỷ');
select is((select balance_amount from app.enrollment_stop where id = pg_temp.s('a')), round(8 * pg_temp.lt()::numeric / 10)::bigint, 'R-GD-16: tiền giữ = giờ mua còn lại × giá sau chiết khấu, KHÔNG trừ phí xử lý');
select is(pg_temp.err($$select app.create_enrollment_stop(pg_temp.d1e(), 'KHAC')$$), 'HMT_DUNG_HOC_DANG_MO', 'Chặn: ghi danh đã có yêu cầu chưa xong');
select is(pg_temp.err($$select app.compute_stop_balance(pg_temp.d1e())$$), '42501', 'Chặn: hàm tính là nội bộ');

-- ================= Duyệt hai bước =================
select is(pg_temp.err($$select app.approve_stop_manager(pg_temp.s('a'))$$), 'HMT_DUNG_HOC_KHONG_DUOC_SUA', 'Chặn: duyệt khi chưa trình');
select lives_ok($$select app.submit_enrollment_stop(pg_temp.s('a'))$$, 'Đúng: trình duyệt');
select is(pg_temp.err($$select app.approve_stop_manager(pg_temp.s('a'))$$), 'HMT_DUNG_HOC_TU_DUYET', 'Chặn: người tạo không tự duyệt');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(pg_temp.err($$select app.approve_stop_accountant(pg_temp.s('a'))$$), 'HMT_DUNG_HOC_KHONG_DUOC_SUA', 'Chặn: kế toán duyệt trước khi quản lý duyệt');
select lives_ok($$select app.approve_stop_manager(pg_temp.s('a'))$$, 'Đúng: quản lý khác duyệt');
select is(pg_temp.err($$select app.approve_stop_accountant(pg_temp.s('a'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không có quyền Kế toán duyệt (R-TIEN-01)');
-- Số liệu đổi: có buổi Done mới thì kế toán duyệt bị chặn.
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, session_id)
  select pg_temp.d1e(), s.branch_id, 'TRU_BUOI', -1, s.id from app.class_session s
   where s.class_id = pg_temp.c('a') and s.type_code = 'CHINH' and s.id not in (select session_id from app.hour_ledger where session_id is not null and enrollment_id = pg_temp.d1e())
   order by s.session_date limit 1$$);
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.approve_stop_accountant(pg_temp.s('a'))$$), 'HMT_DUNG_HOC_SO_LIEU_DOI', 'Chặn: giờ đã học đổi sau khi tạo thì không duyệt');
select lives_ok($$select app.reject_enrollment_stop(pg_temp.s('a'), 'Số liệu đổi, tạo lại')$$, 'Đúng: kế toán từ chối kèm lý do');
select is(pg_temp.err($$select app.reject_enrollment_stop(pg_temp.s('a'), ' ')$$), 'HMT_DUNG_HOC_KHONG_DUOC_SUA', 'Chặn: từ chối yêu cầu đã từ chối');
-- ================= Từ chối (bắt buộc lý do, hai bước) và huỷ =================
-- Ghi danh d1 còn học (yêu cầu a đã từ chối), mỗi lần chỉ một yêu cầu mở nên làm lần lượt.
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok($$insert into st select 'r1', app.create_enrollment_stop(pg_temp.d1e(), 'KHAC')$$, 'Tạo yêu cầu để từ chối ở bước quản lý');
select app.submit_enrollment_stop(pg_temp.s('r1'));
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(pg_temp.err($$select app.reject_enrollment_stop(pg_temp.s('r1'), '   ')$$), 'HMT_DUNG_HOC_THIEU_LY_DO', 'Chặn: từ chối không ghi lý do (bước quản lý)');
select lives_ok($$select app.reject_enrollment_stop(pg_temp.s('r1'), 'Chưa đủ căn cứ')$$, 'Đúng: quản lý từ chối kèm lý do');
select is((select status_code || '/' || reject_reason from app.enrollment_stop where id = pg_temp.s('r1')), 'TU_CHOI/Chưa đủ căn cứ', 'Yêu cầu sang Từ chối, lưu lý do');
select is(pg_temp.est(pg_temp.d1e()), 'DA_XEP_LOP', 'Từ chối thì ghi danh không đổi');
select is(pg_temp.err($$select app.reject_enrollment_stop(pg_temp.s('r1'), 'x')$$), 'HMT_DUNG_HOC_KHONG_DUOC_SUA', 'Chặn: từ chối yêu cầu đã từ chối');
-- Từ chối ở bước kế toán.
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok($$insert into st select 'r2', app.create_enrollment_stop(pg_temp.d1e(), 'KHAC')$$, 'Tạo yêu cầu để từ chối ở bước kế toán');
select app.submit_enrollment_stop(pg_temp.s('r2'));
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select app.approve_stop_manager(pg_temp.s('r2'));
select is(pg_temp.err($$select app.reject_enrollment_stop(pg_temp.s('r2'), 'Trưởng cơ sở không có quyền kế toán')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: ở bước kế toán, Trưởng cơ sở không từ chối được (cần quyền Đối soát kế toán)');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.reject_enrollment_stop(pg_temp.s('r2'), '')$$), 'HMT_DUNG_HOC_THIEU_LY_DO', 'Chặn: từ chối không ghi lý do (bước kế toán)');
select lives_ok($$select app.reject_enrollment_stop(pg_temp.s('r2'), 'Số tiền chưa khớp')$$, 'Đúng: kế toán từ chối kèm lý do');
select is((select status_code from app.enrollment_stop where id = pg_temp.s('r2')), 'TU_CHOI', 'Bước kế toán: yêu cầu sang Từ chối');
-- Huỷ từ Nháp, Chờ quản lý, Chờ kế toán.
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok($$insert into st select 'h1', app.create_enrollment_stop(pg_temp.d1e(), 'KHAC')$$, 'Tạo yêu cầu để huỷ ở Nháp');
select lives_ok($$select app.cancel_enrollment_stop(pg_temp.s('h1'))$$, 'Đúng: huỷ yêu cầu Nháp');
select lives_ok($$insert into st select 'h2', app.create_enrollment_stop(pg_temp.d1e(), 'KHAC')$$, 'Tạo yêu cầu để huỷ ở Chờ quản lý');
select app.submit_enrollment_stop(pg_temp.s('h2'));
select lives_ok($$select app.cancel_enrollment_stop(pg_temp.s('h2'))$$, 'Đúng: huỷ yêu cầu Chờ quản lý');
select lives_ok($$insert into st select 'h3', app.create_enrollment_stop(pg_temp.d1e(), 'KHAC')$$, 'Tạo yêu cầu để huỷ ở Chờ kế toán');
select app.submit_enrollment_stop(pg_temp.s('h3'));
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select app.approve_stop_manager(pg_temp.s('h3'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok($$select app.cancel_enrollment_stop(pg_temp.s('h3'))$$, 'Đúng: huỷ yêu cầu Chờ kế toán');
select is((select count(*)::int from app.enrollment_stop where id in (pg_temp.s('h1'), pg_temp.s('h2'), pg_temp.s('h3')) and status_code = 'HUY'), 3, 'Cả ba yêu cầu đã huỷ');
select is(pg_temp.err($$select app.cancel_enrollment_stop(pg_temp.s('h3'))$$), 'HMT_DUNG_HOC_KHONG_DUOC_SUA', 'Chặn: huỷ yêu cầu đã huỷ');
select is(pg_temp.err($$select app.cancel_enrollment_stop(pg_temp.s('r1'))$$), 'HMT_DUNG_HOC_KHONG_DUOC_SUA', 'Chặn: huỷ yêu cầu đã từ chối');
select lives_ok($$insert into st select 'h4', app.create_enrollment_stop(pg_temp.d1e(), 'KHAC')$$, 'Tạo yêu cầu cho ca thiếu quyền huỷ');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.cancel_enrollment_stop(pg_temp.s('h4'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không có quyền Sửa ghi danh nên không huỷ được');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.cancel_enrollment_stop(pg_temp.s('h4'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: người cơ sở khác không huỷ được yêu cầu của CS1');
select is((select count(*)::int from app.enrollment_stop), 0, 'RLS: người cơ sở khác không thấy yêu cầu dừng học CS1');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((select count(*)::int from app.enrollment_stop), 0, 'RLS: Trưởng cơ sở CS5 không thấy yêu cầu dừng học CS1');
select is(pg_temp.err($$select app.submit_enrollment_stop(pg_temp.s('h4'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở CS5 không trình được yêu cầu của CS1');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.cancel_enrollment_stop(pg_temp.s('h4'));

select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok($$insert into st select 'b', app.create_enrollment_stop(pg_temp.d1e(), 'TAI_CHINH')$$, 'Tạo lại yêu cầu với số liệu mới');
select is((select hours_left from app.enrollment_stop where id = pg_temp.s('b')), 7::numeric, 'Giờ còn lại mới 7');
select app.submit_enrollment_stop(pg_temp.s('b'));
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select app.approve_stop_manager(pg_temp.s('b'));
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(app.customer_balance(pg_temp.par(pg_temp.d1e())), 0::bigint, 'Trước khi duyệt: số dư khách hàng 0');
select lives_ok($$select app.approve_stop_accountant(pg_temp.s('b'))$$, 'Đúng: kế toán duyệt');
select is(pg_temp.hrs(pg_temp.d1e()), 0::numeric, 'Sổ giờ ngược dấu: giờ còn lại về 0');
select is(pg_temp.est(pg_temp.d1e()), 'DUNG', 'Ghi danh sang Dừng');
select is((select count(*)::int from app.enrollment_class where enrollment_id = pg_temp.d1e() and end_date is null), 0, 'Đóng dòng xếp lớp đang mở');
select is(app.customer_balance(pg_temp.par(pg_temp.d1e())), round(7 * pg_temp.lt()::numeric / 10)::bigint, 'R-TIEN-33: số dư khách hàng = tiền giữ (7 giờ × giá sau chiết khấu)');
select pg_temp.sudo($$create function pg_temp.ety(p_enr uuid) returns text language sql stable security definer as 'select entry_type from app.customer_balance_entry where enrollment_id = p_enr'$$);
select pg_temp.sudo($$grant execute on function pg_temp.ety(uuid) to public$$);
select is(pg_temp.ety(pg_temp.d1e()), 'TU_DUNG_HOC', 'Dòng sổ số dư loại «từ dừng học»');
select is(pg_temp.err($$select app.approve_stop_accountant(pg_temp.s('b'))$$), 'HMT_DUNG_HOC_KHONG_DUOC_SUA', 'Chặn: duyệt hai lần (không cộng số dư hai lần)');
select is(pg_temp.err($$update app.customer_balance_entry set amount = 1$$), '42501', 'Chặn: không sửa sổ số dư từ giao diện');
select is(pg_temp.err($q$select pg_temp.sudo($$update app.customer_balance_entry set amount = 1$$)$q$), 'HMT_SO_DU_CHI_THEM', 'Chặn: sổ số dư chỉ thêm dòng, chủ bảng cũng không sửa được (R-TIEN-33)');

-- ================= Huỷ, ghi danh không hợp lệ, RLS =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.create_enrollment_stop(pg_temp.d1e(), 'KHAC')$$), 'HMT_DUNG_HOC_GHI_DANH_SAI', 'Chặn: ghi danh đã Dừng không dừng nữa');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((select count(*)::int from app.enrollment_stop), 0, 'RLS: người cơ sở khác không thấy yêu cầu dừng học CS1');
select is(pg_temp.err($$select app.customer_balance(pg_temp.par(pg_temp.d1e()))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: cơ sở khác không xem số dư khách hàng CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select ok(app.customer_balance(pg_temp.par(pg_temp.d1e())) > 0, 'Kế toán xem được số dư qua hàm customer_balance');
select is(pg_temp.err($$insert into app.customer_balance_entry (parent_id, branch_id, entry_type, amount) values (gen_random_uuid(), gen_random_uuid(), 'DIEU_CHINH', 1)$$), '42501', 'Chặn: không ghi thẳng vào sổ số dư');

select * from finish();
rollback;
