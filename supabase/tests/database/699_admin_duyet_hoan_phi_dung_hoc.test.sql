-- Migration E-26-05c: Admin tự duyệt rồi duyệt tiếp bước kế toán ở hoàn phí và dừng học, ghi đủ cờ. Dựng nền như bài 458. Dữ liệu giả.
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

create temp table rf (key text primary key, id uuid);
grant all on rf to public;
create function pg_temp.f(p_key text) returns uuid language sql stable as $$ select id from rf where key = p_key $$;
grant execute on function pg_temp.f(text) to public;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select m, id, true from app.branch, (values ('HOAN_PHI'), ('DUNG_HOC')) v (m) where code = 'CS1' on conflict (module_code, branch_id) do update set enabled = true$$);

-- ================= Hoàn phí: Admin tạo thì không tự duyệt bước quản lý =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select pg_temp.sudo($$insert into app.ticket (code, ticket_type, branch_id, title, description, channel_code, category_code, priority_code, parent_id, student_id, response_due_at, resolve_due_at)
  select 'DN-T8', 'DN', e.branch_id, 'Đề nghị', 'Ticket giả cho bài kiểm', 'DIEN_THOAI', 'DN_02_01', 'THUONG', e.parent_id, e.student_id, now() + interval '1 day', now() + interval '3 days'
    from app.enrollment e where e.id = pg_temp.d1e()$$);
select pg_temp.sudo($$insert into app.ticket (code, ticket_type, branch_id, title, description, channel_code, category_code, priority_code, parent_id, student_id, response_due_at, resolve_due_at)
  select 'DN-T8S', 'DN', e.branch_id, 'Đề nghị', 'Ticket giả cho bài kiểm', 'DIEN_THOAI', 'DN_01_06', 'THUONG', e.parent_id, e.student_id, now() + interval '1 day', now() + interval '3 days'
    from app.enrollment e where e.id = pg_temp.d3e()$$);
select lives_ok($$insert into rf select 'ra', app.create_refund_request(pg_temp.d1e(), 'MOT_PHAN', 3, 'KHONG_HOP', 'Admin tạo', 'DN-T8')$$, 'Chuẩn bị: Admin tạo yêu cầu hoàn phí');
select lives_ok($$select app.submit_refund_request(pg_temp.f('ra'))$$, 'Chuẩn bị: Admin trình');
select lives_ok($$select app.approve_refund_manager(pg_temp.f('ra'))$$, 'R-HT-01 (26/11): Admin được tự duyệt bước quản lý hoàn phí');
select is((select status_code from app.refund_request where id = pg_temp.f('ra')), 'CHO_KE_TOAN', 'Sang chờ kế toán');
select is((select count(*)::int from app.admin_approval_log where entity_id = pg_temp.f('ra') and flag = 'TU_DUYET' and step = 'QUAN_LY'), 1, 'Ghi cờ Admin tự duyệt');

-- ================= Dừng học: tương tự =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select lives_ok($$insert into st select 'sa', app.create_enrollment_stop(pg_temp.d3e(), 'KHONG_HOP', 'Admin tạo', 'DN-T8S')$$, 'Chuẩn bị: Admin tạo yêu cầu dừng học');
select lives_ok($$select app.submit_enrollment_stop(pg_temp.s('sa'))$$, 'Chuẩn bị: Admin trình');
select lives_ok($$select app.approve_stop_manager(pg_temp.s('sa'))$$, 'R-HT-01 (26/11): Admin được tự duyệt bước quản lý dừng học');
select is((select status_code from app.enrollment_stop where id = pg_temp.s('sa')), 'CHO_KE_TOAN', 'Sang chờ kế toán');
select is((select count(*)::int from app.admin_approval_log where entity_id = pg_temp.s('sa') and flag = 'TU_DUYET' and step = 'QUAN_LY'), 1, 'Ghi cờ Admin tự duyệt');

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select lives_ok($$select app.approve_refund_accountant(pg_temp.f('ra'))$$, 'R-HT-01: Admin tự duyệt cả bước kế toán hoàn phí của yêu cầu mình tạo');
select is((select string_agg(step || ':' || flag, ',' order by step, flag) from app.admin_approval_log where entity_type = 'REFUND_REQUEST' and entity_id = pg_temp.f('ra')),
          'KE_TOAN:HAI_BUOC,KE_TOAN:TU_DUYET,QUAN_LY:TU_DUYET', 'Nhật ký hoàn phí: tự duyệt hai bước, đủ ba cờ');
select lives_ok($$select app.approve_stop_accountant(pg_temp.s('sa'))$$, 'R-HT-01: Admin tự duyệt cả bước kế toán dừng học');
select is((select string_agg(step || ':' || flag, ',' order by step, flag) from app.admin_approval_log where entity_type = 'ENROLLMENT_STOP' and entity_id = pg_temp.s('sa')),
          'KE_TOAN:HAI_BUOC,KE_TOAN:TU_DUYET,QUAN_LY:TU_DUYET', 'Nhật ký dừng học: đủ ba cờ');

select * from finish();
rollback;
