-- Migration 478 (Code D, TC-15): Đối soát thu tiền: danh sách phiếu Đã duyệt, đánh dấu khớp sao kê, tài khoản nhận (danh mục mới), chỉ Kế toán và Admin. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d216.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d216.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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
select pg_temp.sudo($$create function pg_temp.rid(p_n integer) returns uuid language sql stable security definer as
  'select id from (select id, row_number() over (order by created_at, id) n from app.receipt where status_code = ''DA_DUYET'') x where n = p_n'$$);
select pg_temp.sudo($$create function pg_temp.mt(p_id uuid) returns timestamptz language sql stable security definer as 'select bank_matched_at from app.receipt where id = p_id'$$);
select pg_temp.sudo($$create function pg_temp.mby(p_id uuid) returns uuid language sql stable security definer as 'select bank_matched_by from app.receipt where id = p_id'$$);
select pg_temp.sudo($$create function pg_temp.racc(p_id uuid) returns text language sql stable security definer as 'select receiving_account_code from app.receipt where id = p_id'$$);
select pg_temp.sudo($$create function pg_temp.audits(p_id uuid) returns bigint language sql stable security definer as 'select count(*) from app.audit_log where record_id = p_id and action = ''U'''$$);
select pg_temp.sudo($$grant execute on function pg_temp.rid(integer), pg_temp.mt(uuid), pg_temp.mby(uuid), pg_temp.racc(uuid), pg_temp.audits(uuid) to public$$);
select pg_temp.sudo($$insert into app.catalog_item (catalog_code, code, name, sort_order) values ('RECEIVING_ACCOUNT', 'VCB_3456', 'Vietcombank …3456', 1), ('RECEIVING_ACCOUNT', 'TCB_1122', 'Techcombank …1122', 2)$$);
select pg_temp.pay('d1', 300000);
select pg_temp.pay('d1', 400000);
select pg_temp.pay('d2', 200000);
-- Một phiếu Nháp (chưa duyệt) để thử chặn.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mkr('nhap', 'd3', '{"amount": 100000, "payment_method_code": "TIEN_MAT"}'::jsonb);

-- ================= Quyền xem =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.list_receipt_reconciliation()$$), 'HMT_KHONG_CO_QUYEN', 'TC-15 chặn: Trưởng cơ sở không xem đối soát');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.list_receipt_reconciliation()$$), 'HMT_KHONG_CO_QUYEN', 'TC-15 chặn: Sale không xem đối soát');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is((app.list_receipt_reconciliation() ->> 'total')::int, 3, 'TC-15 đúng: Kế toán thấy 3 phiếu Đã duyệt (không thấy phiếu Nháp)');
select is((app.list_receipt_reconciliation() ->> 'sum_all')::bigint, 900000::bigint, 'TC-15: tổng tiền thu 900.000');
select is((app.list_receipt_reconciliation() ->> 'count_unmatched')::int, 3, 'TC-15: ban đầu cả 3 phiếu chưa khớp');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.list_receipt_reconciliation() ->> 'total')::int, 3, 'TC-15 đúng: Admin cũng xem được');

-- ================= Đánh dấu khớp =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err(format('select app.mark_receipts_bank_matched(array[%L]::uuid[])', pg_temp.rid(1))), 'HMT_KHONG_CO_QUYEN', 'TC-15 chặn: Trưởng cơ sở không đánh dấu khớp');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.mark_receipts_bank_matched(array[]::uuid[])$$), 'HMT_DOI_SOAT_CHUA_CHON', 'TC-15 chặn: không chọn phiếu nào');
select is(pg_temp.err(format('select app.mark_receipts_bank_matched(array[%L]::uuid[], true, %L)', pg_temp.rid(1), 'KHONG_CO')), 'HMT_TAI_KHOAN_NHAN_KHONG_CO', 'TC-15 chặn: tài khoản nhận không có trong danh mục');
select is(pg_temp.err(format('select app.mark_receipts_bank_matched(array[%L]::uuid[])', (select id from app.receipt where status_code = 'NHAP' limit 1))), 'HMT_DOI_SOAT_PHIEU_CHUA_DUYET', 'TC-15 chặn: phiếu chưa duyệt không đối soát');
select is(pg_temp.mt(pg_temp.rid(1)) is null, true, 'TC-15: các ca bị chặn không đánh dấu gì');
select is(app.mark_receipts_bank_matched(array[pg_temp.rid(1), pg_temp.rid(2)], true, 'VCB_3456'), 2, 'TC-15 đúng: Kế toán đánh dấu khớp 2 phiếu kèm tài khoản nhận');
select is(pg_temp.mt(pg_temp.rid(1)) is not null and pg_temp.mby(pg_temp.rid(1)) = pg_temp.uid('ke'), true, 'TC-15: ghi thời điểm và người đánh dấu');
select is(pg_temp.racc(pg_temp.rid(1)), 'VCB_3456', 'TC-15: tài khoản nhận đã ghi');
select is(pg_temp.audits(pg_temp.rid(1)) >= 1, true, 'TC-15: nhật ký audit có dòng sửa phiếu thu');
select is((app.list_receipt_reconciliation() ->> 'count_unmatched')::int, 1, 'TC-15: còn 1 phiếu chưa khớp');
select is((app.list_receipt_reconciliation() ->> 'sum_matched')::bigint + (app.list_receipt_reconciliation() ->> 'sum_unmatched')::bigint, 900000::bigint, 'TC-15: tổng khớp + chưa khớp = tổng thu');
select is((app.list_receipt_reconciliation('{"matched": "CHUA"}') ->> 'total')::int, 1, 'TC-15: lọc Chưa khớp ra 1 phiếu');
select is((app.list_receipt_reconciliation('{"matched": "KHOP"}') ->> 'total')::int, 2, 'TC-15: lọc Đã khớp ra 2 phiếu');
select is((app.list_receipt_reconciliation('{"account": "VCB_3456"}') ->> 'total')::int, 2, 'TC-15: lọc theo tài khoản nhận');
select is((app.list_receipt_reconciliation('{"account": "NONE"}') ->> 'total')::int, 1, 'TC-15: lọc phiếu chưa ghi tài khoản nhận');
select is((app.list_receipt_reconciliation('{"method": "CHUYEN_KHOAN"}') ->> 'total')::int, 0, 'TC-15: lọc hình thức chuyển khoản: không có');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(app.mark_receipts_bank_matched(array[pg_temp.rid(1)], false), 1, 'TC-15 đúng: Admin bỏ đánh dấu khớp');
select is(pg_temp.mt(pg_temp.rid(1)) is null and pg_temp.mby(pg_temp.rid(1)) is null, true, 'TC-15: bỏ khớp xoá thời điểm và người');
select is(pg_temp.racc(pg_temp.rid(1)), 'VCB_3456', 'TC-15: bỏ khớp giữ tài khoản nhận');
-- Tài khoản nhận đã Ngừng thì không gán mới.
select pg_temp.sudo($$update app.catalog_item set is_active = false where catalog_code = 'RECEIVING_ACCOUNT' and code = 'TCB_1122'$$);
select is(pg_temp.err(format('select app.mark_receipts_bank_matched(array[%L]::uuid[], true, %L)', pg_temp.rid(3), 'TCB_1122')), 'HMT_TAI_KHOAN_NHAN_KHONG_CO', 'TC-15 chặn: tài khoản nhận đã Ngừng');

select * from finish();
rollback;
