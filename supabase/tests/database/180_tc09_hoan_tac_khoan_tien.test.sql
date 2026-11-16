-- TC-09 Hoàn tác khoản tiền vào (migration 180). Luật: R-TIEN-26 (khoản âm trỏ về khoản gốc, chặn đảo hai lần, lý do bắt buộc, giờ tính lại), R-HT-01 (Admin không đảo), R-HT-04 (lý do Khác cần ghi chú), R-GD-12 (giờ âm cho phép).
-- Cờ money_reversal_enabled mặc định TẮT. Dựng đơn thật như 107, duyệt phiếu thu bằng hàm thật. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p180.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p180.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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

create function pg_temp.mid(p_order text, p_pos integer) returns uuid language sql stable security definer as $$
  select id from app.money_in where order_id = pg_temp.o(p_order) and amount > 0 order by code offset p_pos - 1 limit 1 $$;
create function pg_temp.enr_hours(p_order text) returns numeric language sql stable security definer as $$
  select coalesce(sum(l.hours), 0) from app.hour_ledger l join app.enrollment e on e.id = l.enrollment_id where e.order_id = pg_temp.o(p_order) $$;
grant execute on function pg_temp.mid(text, integer), pg_temp.enr_hours(text) to public;

-- Khoản tiền vào: 1.200.000 (đủ cọc, sinh ghi danh và giờ), rồi 1.000.000.
select pg_temp.pay('m', 1200000);
select pg_temp.pay('m', 1000000);
select is(pg_temp.paid('m'), 2200000::bigint, 'Tiền đã vào đơn trước khi hoàn tác: 2.200.000');
create temp table hv (v numeric);
grant all on hv to public;
insert into hv select pg_temp.enr_hours('m');
select ok((select v from hv) > 0, 'Giờ đã cấp theo tiền trước khi hoàn tác');

-- ---- Cờ tắt (mặc định) ----
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.reverse_money_in(pg_temp.mid('m', 2), 'NHAP_SAI_SO_TIEN')$$), 'HMT_TINH_NANG_TAT', 'Cờ money_reversal_enabled tắt (mặc định): Kế toán không hoàn tác được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((select value from app.setting_def where key = 'money_reversal_enabled'), 'false', 'Tham số money_reversal_enabled mặc định TẮT');
select pg_temp.sudo($$insert into app.setting_branch (setting_key, branch_id, value) select 'money_reversal_enabled', id, 'true' from app.branch where code = 'CS1'$$);

-- ---- R-HT-01: Admin, Quản lý, Sale không hoàn tác ----
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.reverse_money_in(pg_temp.mid('m', 2), 'NHAP_SAI_SO_TIEN')$$), 'HMT_KHONG_CO_QUYEN', 'R-HT-01: Admin không hoàn tác khoản tiền');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.reverse_money_in(pg_temp.mid('m', 2), 'NHAP_SAI_SO_TIEN')$$), 'HMT_KHONG_CO_QUYEN', 'Quản lý cơ sở không hoàn tác khoản tiền');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.reverse_money_in(pg_temp.mid('m', 2), 'NHAP_SAI_SO_TIEN')$$), 'HMT_KHONG_CO_QUYEN', 'Sale không hoàn tác khoản tiền');

-- ---- Kế toán: luật lý do ----
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.reverse_money_in(pg_temp.mid('m', 2), null)$$), 'HMT_THIEU_LY_DO', 'R-TIEN-26: thiếu lý do thì chặn');
select is(pg_temp.err($$select app.reverse_money_in(pg_temp.mid('m', 2), 'KHONG_CO_MA_NAY')$$) is not null, true, 'Mã lý do ngoài danh mục thì chặn');
select is(pg_temp.err($$select app.reverse_money_in(pg_temp.mid('m', 2), 'KHAC')$$), 'HMT_THIEU_GHI_CHU', 'R-HT-04: lý do Khác không ghi chú thì chặn');
select is(pg_temp.paid('m'), 2200000::bigint, 'Các ca bị chặn không đổi số tiền');

-- ---- Ca đúng: Kế toán hoàn tác khoản 1.000.000 ----
create temp table rv (v jsonb);
grant all on rv to public;
insert into rv select app.reverse_money_in(pg_temp.mid('m', 2), 'NHAP_SAI_SO_TIEN');
select is(pg_temp.paid('m'), 1200000::bigint, 'R-TIEN-26: tiền đã vào của đơn giảm đúng 1.000.000 sau khi hoàn tác');
select is((select amount from app.money_in where code = (select v ->> 'code' from rv)), -1000000::bigint, 'Thêm một khoản âm bằng khoản gốc');
select is((select reversal_of from app.money_in where code = (select v ->> 'code' from rv)), pg_temp.mid('m', 2), 'Khoản âm trỏ về khoản gốc');
select is((select amount from app.money_in where id = pg_temp.mid('m', 2)), 1000000::bigint, 'Khoản gốc giữ nguyên, không sửa');
select ok((select v ->> 'code' from rv) like 'KTV-%', 'Khoản đảo cùng dãy mã KTV');
select is((select sum(a.amount)::bigint from app.money_in_allocation a join app.money_in m on m.id = a.money_in_id where m.reversal_of = pg_temp.mid('m', 2)), -1000000::bigint, 'Phần chia về dòng đơn của khoản đảo âm đúng bằng khoản gốc');
select ok(pg_temp.enr_hours('m') < (select v from hv), 'R-TIEN-26: giờ đã cấp được tính lại theo tiền còn lại (giảm)');
select is((select (v ->> 'enrollments_negative')::int from rv), 0, 'Hàm trả số ghi danh giờ âm (không có)');

-- ---- Chặn đảo hai lần, đảo khoản âm ----
select is(pg_temp.err($$select app.reverse_money_in(pg_temp.mid('m', 2), 'TRUNG_PHIEU')$$), 'HMT_DA_DAO_KHOAN', 'R-TIEN-26: chặn đảo hai lần');
select is(pg_temp.err($$select app.reverse_money_in((select id from app.money_in where reversal_of is not null limit 1), 'TRUNG_PHIEU')$$), 'HMT_KHONG_DAO_KHOAN_AM', 'Không đảo một khoản đã là khoản đảo');

-- ---- Chỉ thêm: không sửa, không xoá khoản ----
select is(pg_temp.err($$select pg_temp.sudo('update app.money_in set amount = 1 where reversal_of is not null')$$) is not null, true, 'Khoản tiền vào chỉ thêm: không sửa được khoản đảo');

-- ---- Ràng buộc dấu ----
select is(pg_temp.err($$select pg_temp.sudo('insert into app.money_in (code, receipt_id, order_id, parent_id, branch_id, amount) select ''KTV-LOI'', null, order_id, parent_id, branch_id, -5 from app.money_in limit 1')$$) is not null, true, 'Khoản âm không có khoản gốc thì bị chặn (ràng buộc dấu)');

-- ---- Phạm vi cơ sở: Kế toán thấy khoản tiền ở sổ TC-08 kể cả khoản đảo ----
select is((select (app.list_money_in('{"kind":"DAO"}'::jsonb) ->> 'total')::int), 1, 'TC-08 liệt kê khoản đảo (nối trái, không có phiếu thu)');
select is((select count(*)::int from jsonb_array_elements(app.list_money_in('{}'::jsonb) -> 'rows') r where r ->> 'reversal_of_code' is not null), 1, 'Dòng khoản đảo ghi mã khoản gốc');
select is((select count(*)::int from jsonb_array_elements(app.list_money_in('{}'::jsonb) -> 'rows') r where (r ->> 'is_reversed')::boolean), 1, 'Khoản gốc được đánh dấu đã bị hoàn tác');

-- ---- Khoản đã hoàn tác tới mức giờ âm (R-GD-12): hoàn tác khoản đầu thì giờ về 0 hoặc âm, hàm vẫn chạy ----
select is(pg_temp.err($$select app.reverse_money_in(pg_temp.mid('m', 1), 'SAI_DON_HOAC_SAI_KHACH')$$), null, 'Hoàn tác tiếp khoản còn lại thành công');
select is(pg_temp.paid('m'), 0::bigint, 'Đã hoàn tác hết: tiền đã vào đơn về 0');

select * from finish();
rollback;
