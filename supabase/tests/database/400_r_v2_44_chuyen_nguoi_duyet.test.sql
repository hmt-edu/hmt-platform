-- R-V2-44 Chuyển người duyệt (migration 400). Mỗi điều kiện có ca đúng và ca bị chặn. Dựng đơn thật như test 250. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('bm1'), ('bm1b'), ('bm5'), ('sales1'), ('sales5'), ('ke');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p400.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p400.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm1b', 'CS1'), ('bm5', 'CS5'), ('sales1', 'CS1'), ('sales5', 'CS5'), ('ke', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm1b', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('sales1', 'SALES'),
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
select app.create_lead(pg_temp.lead_data('0900010003', '{"student_name": "Em Năm", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900010001'));
select app.create_opportunity(pg_temp.lid('0900010002'));
select app.create_opportunity(pg_temp.lid('0900010003'));
-- Cơ hội 1 có ba em (ít nhất 2 em, 3 dòng đơn).
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, p.pos, p.name, 2013 from app.opportunity o, (values (2, 'Em Hai'), (3, 'Em Ba')) p (pos, name) where o.id = pg_temp.oid('0900010001')$$);
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in (pg_temp.oid('0900010001'), pg_temp.oid('0900010002'), pg_temp.oid('0900010003'))$$);
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
-- Đơn m, n: đã trình rồi duyệt xong (dùng cho ca «sai trạng thái»); đơn p: đã trình, CHỜ quản lý duyệt.
create function pg_temp.mkp(p_key text, p_phone text) returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_order_from_opportunity(pg_temp.oid(p_phone), jsonb_build_array(pg_temp.line(pg_temp.ps(p_phone, 1), 'LC-TOAN-K09', 'OFF', 10)), null, true);
  insert into os values (p_key, (v ->> 'id')::uuid);
  perform app.save_order((v ->> 'id')::uuid, null, pg_temp.term('COC_VA_CHIA_DOT'));
end $$;
grant execute on function pg_temp.mkp(text, text) to public;
select pg_temp.mkp('m', '0900010001');
select pg_temp.mkp('n', '0900010002');
select pg_temp.mkp('p', '0900010003');
select app.submit_order(pg_temp.o('m'));
select app.submit_order(pg_temp.o('p'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_order(pg_temp.o('m'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.submit_order(pg_temp.o('n'));
-- Phiếu thu: gửi từ đơn m (đã duyệt) → DA_GUI chờ bm1.
select pg_temp.mkr('r1', 'm', '{"amount": 1000000, "payment_method_code": "TIEN_MAT"}'::jsonb);
select app.submit_receipt(pg_temp.r('r1'));
select pg_temp.mkr('r2', 'm', '{"amount": 500000, "payment_method_code": "TIEN_MAT"}'::jsonb);
select app.submit_receipt(pg_temp.r('r2'));

create function pg_temp.aid(p_kind text, p_key text) returns uuid language sql stable security definer as $$
  select case when p_kind = 'PHIEU_THU' then (select assigned_approver_id from app.receipt where id = pg_temp.r(p_key))
              else (select assigned_approver_id from app.sales_order where id = pg_temp.o(p_key)) end $$;
create function pg_temp.reas(p_kind text, p_key text, p_to text, p_reason text, p_note text default null) returns jsonb language sql as $$
  select app.reassign_approver(p_kind, case when p_kind = 'PHIEU_THU' then pg_temp.r(p_key) else pg_temp.o(p_key) end, pg_temp.uid(p_to), p_reason, p_note) $$;
grant execute on function pg_temp.aid(text, text), pg_temp.reas(text, text, text, text, text) to public;

-- ---- Cờ tắt mặc định ----
select is((select value from app.setting_def where key = 'approver_reassign_enabled'), 'false', 'R-V2-44: cờ approver_reassign_enabled mặc định TẮT');
select is((select value from app.setting_def where key = 'approver_reassign_after_hours'), '48', 'R-V2-44 (b): quá hạn mặc định 48 giờ');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select pg_temp.sudo($$update app.user_account set is_locked = true where id = pg_temp.uid('bm1')$$);
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'bm1b', 'BI_KHOA')$$), 'HMT_TINH_NANG_TAT', 'R-V2-44: cờ tắt thì Admin không chuyển được');
reset role;
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'approver_reassign_enabled'$$);
set local role authenticated;

-- ---- Quyền: chỉ Admin (đã hai bước) ----
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'bm1b', 'BI_KHOA')$$), 'HMT_KHONG_CO_QUYEN', 'R-V2-44: Trưởng cơ sở không tự chuyển người duyệt');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'bm1b', 'BI_KHOA')$$), 'HMT_KHONG_CO_QUYEN', 'R-V2-44: Kế toán không chuyển người duyệt');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'bm1b', 'BI_KHOA')$$), 'HMT_KHONG_CO_QUYEN', 'R-V2-44: Admin chưa xác thực hai bước bị chặn');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- ---- Lý do ----
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'bm1b', 'KHONG_CO_MA_NAY')$$), 'HMT_LY_DO_THIEU', 'R-V2-44: thiếu hoặc sai mã lý do bị chặn');
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'bm1b', 'KHAC')$$), 'HMT_LY_DO_THIEU', 'R-V2-44: lý do «Khác» không ghi chú bị chặn');

-- ---- Điều kiện người nhận ----
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'sales1', 'BI_KHOA')$$), 'HMT_NGUOI_NHAN_KHONG_HOP_LE', 'R-V2-44: không chuyển cho chính người lập');
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'admin', 'BI_KHOA')$$), 'HMT_NGUOI_NHAN_KHONG_HOP_LE', 'R-V2-44: không chuyển cho Admin');
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'ke', 'BI_KHOA')$$), 'HMT_NGUOI_NHAN_KHONG_HOP_LE', 'R-V2-44: không chuyển cho Kế toán');
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'bm5', 'BI_KHOA')$$), 'HMT_NGUOI_NHAN_KHONG_HOP_LE', 'R-V2-44: không chuyển cho Trưởng cơ sở của cơ sở khác');
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'bm1', 'BI_KHOA')$$), 'HMT_NGUOI_NHAN_KHONG_HOP_LE', 'R-V2-44: không chuyển cho người đang được giao (đang bị khoá)');
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'sales5', 'BI_KHOA')$$), 'HMT_NGUOI_NHAN_KHONG_HOP_LE', 'R-V2-44: người nhận không phải quản lý hay Trưởng cơ sở bị chặn');

-- ---- Chuyển đúng: người đã chốt (bm1) bị khoá ----
select is((pg_temp.reas('PHIEU_THU', 'r1', 'bm1b', 'BI_KHOA') ->> 'to_approver_id')::uuid, pg_temp.uid('bm1b'), 'R-V2-44: người chốt bị khoá thì Admin chuyển được phiếu thu');
select is(pg_temp.aid('PHIEU_THU', 'r1'), pg_temp.uid('bm1b'), 'Người được giao của phiếu thu đã đổi');
select is(pg_temp.rst('r1'), 'DA_GUI', 'Chuyển KHÔNG đổi trạng thái: phiếu vẫn chờ quản lý');
select is(pg_temp.rev('r1'), 'TAO,GUI,CHUYEN_NGUOI_DUYET', 'Lịch sử phiếu thu ghi sự kiện chuyển người duyệt');
select is(pg_temp.err($$select app.approve_receipt_manager(pg_temp.r('r1'))$$), 'HMT_KHONG_CO_QUYEN', 'R-HT-01: Admin không tự duyệt thay bước quản lý phiếu thu (chỉ chuyển)');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select lives_ok($$select app.approve_receipt_manager(pg_temp.r('r1'))$$, 'Người nhận mới duyệt được bước quản lý');
select is(pg_temp.rst('r1'), 'CHO_KE_TOAN', 'Duyệt xong sang chờ kế toán');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r1', 'bm1b', 'BI_KHOA')$$), 'HMT_SAI_TRANG_THAI', 'R-V2-44: phiếu đã qua bước quản lý thì không chuyển nữa');

-- ---- Người chốt còn hiệu lực thì chặn; quá hạn thì cho ----
reset role;
select pg_temp.sudo($$update app.user_account set is_locked = false where id = pg_temp.uid('bm1')$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r2', 'bm1b', 'QUA_HAN_XU_LY')$$), 'HMT_NGUOI_DUYET_CON_HIEU_LUC', 'R-V2-44: người chốt còn hoạt động, chưa quá hạn thì chặn');
reset role;
select pg_temp.sudo($$update app.receipt set submitted_at = now() - interval '49 hours' where id = pg_temp.r('r2')$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((pg_temp.reas('PHIEU_THU', 'r2', 'bm1b', 'QUA_HAN_XU_LY') ->> 'to_approver_id')::uuid, pg_temp.uid('bm1b'), 'R-V2-44 (a): quá hạn 48 giờ thì chuyển được dù người chốt còn hoạt động');
select is(pg_temp.err($$select pg_temp.reas('PHIEU_THU', 'r2', 'bm1', 'QUA_HAN_XU_LY')$$), 'HMT_NGUOI_DUYET_CON_HIEU_LUC', 'R-V2-44: vừa chuyển xong thì mốc quá hạn tính lại, không chuyển liên tiếp');
select is(jsonb_array_length(app.list_approver_candidates('PHIEU_THU', pg_temp.r('r2'))), 1, 'Danh sách người nhận hợp lệ: chỉ còn bm1 (quản lý trực tiếp), bm1b đang được giao');

-- ---- Mất quyền Duyệt ----
reset role;
select pg_temp.sudo($$update app.user_role set is_active = false where user_id = pg_temp.uid('bm1') and role_code = 'BRANCH_MANAGER'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- ---- Đơn hàng (DA_TRINH) ----
select is(pg_temp.err($$select pg_temp.reas('DON', 'm', 'bm1b', 'BI_KHOA')$$), 'HMT_SAI_TRANG_THAI', 'R-V2-44: đơn đã duyệt không chuyển người duyệt');
select is((pg_temp.reas('DON', 'p', 'bm1b', 'NGHI_VIEC', 'thử') ->> 'to_approver_id')::uuid, pg_temp.uid('bm1b'), 'R-V2-44: người chốt không còn quyền Duyệt thì Admin chuyển được đơn đã trình');
select is(pg_temp.aid('DON', 'p'), pg_temp.uid('bm1b'), 'Người được giao của đơn đã đổi');
select is((select status_code from app.sales_order where id = pg_temp.o('p')), 'DA_TRINH', 'Chuyển không đổi trạng thái đơn');
select is((select count(*)::int from app.sales_order_event where order_id = pg_temp.o('p') and event_code = 'CHUYEN_NGUOI_DUYET' and reason_code = 'NGHI_VIEC'), 1, 'Lịch sử đơn ghi sự kiện chuyển kèm lý do');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select lives_ok($$select app.approve_order(pg_temp.o('p'))$$, 'Người nhận mới duyệt được đơn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.reassign_approver('DON', pg_temp.o('n'), pg_temp.uid('bm1b'), 'BI_KHOA', null)$$), 'HMT_KHONG_CO_QUYEN', 'R-V2-44: Sale không chuyển người duyệt');

select * from finish();
rollback;
