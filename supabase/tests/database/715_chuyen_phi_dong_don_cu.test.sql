-- Migration 715 (C-27-27): Chuyển phí xong thì xử lý đơn cũ. Luật R-TIEN-32, R-TIEN-38. Mỗi luật có ca đúng và ca bị chặn. Dựng đơn như bài 451. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p715.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p715.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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

reset role;
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'pay_later_toggle_enabled'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');

-- ---------- Đơn m (ba em, cho học trước) thu một phần; đơn n không chuyển phí, để đối chứng ----------
select pg_temp.pl('m');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.pay('m', 600000);
-- Một phiếu thu đang chờ duyệt lúc chuyển phí, một phiếu nháp.
select pg_temp.mkr('cho', 'm', jsonb_build_object('amount', 100000, 'payment_method_code', 'TIEN_MAT'));
select app.submit_receipt(pg_temp.r('cho'));
select pg_temp.mkr('nhap', 'm', jsonb_build_object('amount', 100000, 'payment_method_code', 'TIEN_MAT'));
reset role;
select set_config('hmt.migration', 'on', true);
update app.sales_order_installment set due_date = current_date - 10 where order_id = (select id from os where key = 'm');
select set_config('hmt.migration', '', true);
-- Chuyển phí một ghi danh (hàm nội bộ mà phiếu Chuyển phí đã duyệt gọi).
create function pg_temp.chuyen(p_pos integer) returns uuid language sql security definer as $$
  select app.apply_fee_transfer(e.id, null, (select code from app.catalog_item where catalog_code = 'TRANSFER_REASON' and is_active order by sort_order limit 1), 'thử', 'TK715')
    from app.enrollment e join app.sales_order_line l on l.id = e.order_line_id where e.order_id = pg_temp.o('m') and l.line_no = p_pos $$;
create function pg_temp.ord(p_key text) returns app.sales_order language sql stable security definer as $$ select o from app.sales_order o where o.id = pg_temp.o(p_key) $$;
create function pg_temp.congno(p_key text) returns integer language sql as $$
  select (app.list_receivables(jsonb_build_object('q', (pg_temp.ord(p_key)).code)) ->> 'total')::int $$;
create function pg_temp.viec(p_key text) returns integer language sql security definer as $$
  select count(*)::int from app.work_debts_overdue(false, null) w where w.title = 'Công nợ ' || (pg_temp.ord(p_key)).code $$;
create function pg_temp.sodu() returns bigint language sql stable security definer as $$
  select coalesce(sum(amount), 0)::bigint from app.customer_balance_entry where source_ref = 'FEE-TK715' $$;
create function pg_temp.dot(p_key text) returns text language sql stable security definer as $$
  select string_agg(seq || ':' || amount, ',' order by seq) from app.sales_order_installment where order_id = pg_temp.o(p_key) $$;
grant execute on all functions in schema pg_temp to public;
create temp table truoc as select pg_temp.dot('m') as dot,
  (select (app.compute_stop_balance(e.id) ->> 'balance_amount')::bigint from app.enrollment e join app.sales_order_line l on l.id = e.order_line_id
    where e.order_id = pg_temp.o('m') and l.line_no = 1) as tien1;
grant select on truoc to public;
set local role authenticated;
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select ok(pg_temp.congno('m') > 0, 'Chuẩn bị: đơn còn đợt quá hạn nằm ở Công nợ');
select is(pg_temp.viec('m'), 1, 'Chuẩn bị: đơn nằm ở Việc của tôi');

-- ---- Chuyển phí một phần: đơn còn ghi danh khác thì công nợ giữ nguyên ----
select pg_temp.chuyen(1);
select is((pg_temp.ord('m')).fee_transferred_at, null, 'Còn ghi danh hiệu lực: đơn chưa bị đánh dấu');
select ok(pg_temp.congno('m') > 0, 'Còn ghi danh hiệu lực: công nợ giữ nguyên');
select is((select count(*)::int from app.sales_order_event where order_id = pg_temp.o('m') and event_code = 'CHUYEN_PHI' and note like 'Chuyển phí một phần%'), 1, 'Ghi lịch sử chuyển phí một phần');
select is(pg_temp.sodu(), (select tien1 from truoc), 'R-TIEN-32: giá trị chuyển bằng số tính trước khi chuyển');

-- ---- Chuyển nốt: đơn được đánh dấu, nợ biến mất, đợt thu không đổi ----
select pg_temp.chuyen(2);
select pg_temp.chuyen(3);
select is((pg_temp.ord('m')).fee_transferred_at is not null and (pg_temp.ord('m')).fee_transfer_ref = 'TK715', true, 'Mọi dòng đã đóng: đơn được đánh dấu đã chuyển phí');
select is((pg_temp.ord('m')).status_code, 'DA_DUYET', 'Tình trạng đơn giữ Đã duyệt');
select is(pg_temp.dot('m'), (select dot from truoc), 'Đợt thu không bị sửa, xoá');
select is(pg_temp.congno('m'), 0, 'Không còn ở Công nợ');
select is((app.receivable_group_counts(jsonb_build_object('q', (pg_temp.ord('m')).code), array['branch']) ->> 'total')::int, 0, 'Không còn trong số đếm Group By công nợ');
select is(pg_temp.viec('m'), 0, 'Không còn ở Việc của tôi');
select is(app.get_order(pg_temp.o('m')) ->> 'fee_transfer_ref', 'TK715', 'Bản ghi đơn trả dấu đã chuyển phí');

-- ---- Chặn thu thêm vào đơn cũ ----
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.create_receipt(pg_temp.o('m'), jsonb_build_object('amount', 100000, 'payment_method_code', 'TIEN_MAT'))$$), 'HMT_DON_DA_CHUYEN_PHI', 'Chặn: lập phiếu thu mới');
select is(pg_temp.err($$select app.submit_receipt(pg_temp.r('nhap'))$$), 'HMT_DON_DA_CHUYEN_PHI', 'Chặn: gửi duyệt phiếu nháp cũ');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_receipt_manager(pg_temp.r('cho'))$$), 'HMT_DON_DA_CHUYEN_PHI', 'Chặn: duyệt phiếu đang chờ');
select lives_ok($$select app.reject_receipt(pg_temp.r('cho'), 'Đơn đã chuyển phí')$$, 'Vẫn từ chối được phiếu đang chờ');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select lives_ok($$select app.cancel_receipt(pg_temp.r('cho'), (select code from app.catalog_item where catalog_code = 'RECEIPT_CANCEL_REASON' and is_active and not requires_note limit 1))$$, 'Vẫn huỷ được phiếu chưa duyệt');

-- ---- Hồ sơ phụ huynh không còn tính nợ của đơn đã chuyển phí ----
reset role;
create function pg_temp.no_ph(p_key text) returns bigint language sql security definer as $$
  select (app.parent_money_summary(p) ->> 'debt')::bigint from app.parent p where p.id = (pg_temp.ord(p_key)).parent_id $$;
grant execute on function pg_temp.no_ph(text) to public;
set local role authenticated;
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.no_ph('m'), 0::bigint, 'Hồ sơ phụ huynh: đơn đã chuyển phí không còn là nợ');
select ok(pg_temp.no_ph('n') > 0, 'Hồ sơ phụ huynh khác vẫn tính nợ đơn thường');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ---- Đơn không chuyển phí không bị đụng ----
select is((pg_temp.ord('n')).fee_transferred_at, null, 'Đơn khác không bị đánh dấu');
select ok(pg_temp.err($$select app.create_receipt(pg_temp.o('n'), jsonb_build_object('amount', 100000, 'payment_method_code', 'TIEN_MAT'))$$) is null, 'Đơn khác vẫn lập phiếu thu được');
select is(has_function_privilege('authenticated', 'app.close_transferred_order(uuid, text)', 'execute'), false, 'Hàm nội bộ không gọi trực tiếp được');

select * from finish();
rollback;
