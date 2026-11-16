-- QT-14 Ngày nghỉ lễ (migration 181). Luật: R-LOP-12 (ngày nghỉ chung hoặc theo cơ sở; xem trước buổi bị ảnh hưởng), R-LOP-09 (is_holiday), quyền module HOLIDAY
-- (Admin toàn hệ thống; Trưởng cơ sở trong cơ sở; Sale chỉ xem). Mỗi luật có ca đúng và ca bị chặn. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p181.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p181.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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

create function pg_temp.hol(p_date date, p_branch text default null) returns uuid language sql stable security definer as $$
  select id from app.holiday where holiday_date = p_date and branch_id is not distinct from (select id from app.branch where code = p_branch) $$;
grant execute on function pg_temp.hol(date, text) to public;

set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('q', 5);
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- Buổi đầu tiên của lớp q (Nháp hoặc Đã chốt) là ngày dùng để thử "buổi bị ảnh hưởng".
create temp table d (v date);
grant all on d to public;
insert into d select min(session_date) from app.class_session where class_id = pg_temp.c('q');
select ok((select v from d) is not null, 'Lớp thử đã sinh buổi');

-- ---- Thêm ngày nghỉ chung (Admin) ----
create temp table r1 (v jsonb);
grant all on r1 to public;
insert into r1 select app.save_holiday(null, (select v from d), 'Nghỉ lễ thử chung', null);
select is((select (v ->> 'is_new')::boolean from r1), true, 'Admin thêm ngày nghỉ chung được');
select is((select (v ->> 'affected_sessions')::int from r1), 1, 'R-LOP-12: báo số buổi bị ảnh hưởng (buổi của lớp thử trùng ngày)');
select is(app.is_holiday((select v from d), (select id from app.branch where code = 'CS1')), true, 'R-LOP-09: ngày nghỉ chung tính cho mọi cơ sở (is_holiday)');
select is((app.list_holiday_sessions((select (v ->> 'id')::uuid from r1)) ->> 'total')::int, 1, 'Xem buổi bị ảnh hưởng: 1 buổi');
select is(app.list_holiday_sessions((select (v ->> 'id')::uuid from r1)) -> 'rows' -> 0 ->> 'class_code', (select code from app.class where id = pg_temp.c('q')), 'Dòng buổi ghi đúng mã lớp');

-- ---- Chặn trùng, thiếu ngày, thiếu tên ----
select is(pg_temp.err($$select app.save_holiday(null, (select v from d), 'Trùng', null)$$), 'HMT_NGAY_NGHI_TRUNG', 'Chặn thêm trùng ngày nghỉ chung');
select is(pg_temp.err($$select app.save_holiday(null, null, 'Thiếu ngày', null)$$), 'HMT_THIEU_NGAY', 'Thiếu ngày thì chặn');
select is(pg_temp.err($$select app.save_holiday(null, current_date + 400, '   ', null)$$), 'HMT_THIEU_TEN', 'Thiếu tên thì chặn');

-- ---- Sửa tên, chặn đổi cơ sở ----
select is(((app.save_holiday((select (v ->> 'id')::uuid from r1), (select v from d), 'Đổi tên', null)) ->> 'is_new')::boolean, false, 'Sửa tên ngày nghỉ');
select is((select name from app.holiday where id = (select (v ->> 'id')::uuid from r1)), 'Đổi tên', 'Tên đã đổi');
select is(pg_temp.err($$select app.save_holiday((select (v ->> 'id')::uuid from r1), (select v from d), 'x', (select id from app.branch where code = 'CS1'))$$), 'HMT_KHONG_DOI_CO_SO', 'Không đổi cơ sở của ngày nghỉ đã có');

-- ---- Trưởng cơ sở: chỉ ngày nghỉ của cơ sở mình, không động tới ngày chung ----
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.save_holiday(null, current_date + 500, 'Chung của BM', null)$$), 'HMT_KHONG_CO_QUYEN', 'Trưởng cơ sở không thêm ngày nghỉ chung');
select is(pg_temp.err($$select app.save_holiday(null, current_date + 500, 'Khác CS', (select id from app.branch where code = 'CS5'))$$), 'HMT_KHONG_CO_QUYEN', 'Trưởng cơ sở CS1 không thêm ngày nghỉ của CS5');
select is(((app.save_holiday(null, current_date + 500, 'Riêng CS1', (select id from app.branch where code = 'CS1'))) ->> 'is_new')::boolean, true, 'Trưởng cơ sở thêm được ngày nghỉ riêng cơ sở mình');
select is(pg_temp.err($$select app.set_holiday_active((select (v ->> 'id')::uuid from r1), false)$$), 'HMT_KHONG_CO_QUYEN', 'Trưởng cơ sở không ngừng ngày nghỉ chung');
select is(((app.set_holiday_active(pg_temp.hol(current_date + 500, 'CS1'), false)) ->> 'is_active')::boolean, false, 'Trưởng cơ sở ngừng được ngày nghỉ của cơ sở mình');
select is(app.is_holiday(current_date + 500, (select id from app.branch where code = 'CS1')), false, 'Ngày nghỉ đã Ngừng không còn tính');
select is(((app.save_holiday(null, current_date + 500, 'Dùng lại', (select id from app.branch where code = 'CS1'))) ->> 'is_new')::boolean, true, 'Thêm lại đúng ngày đã Ngừng thì dùng lại dòng cũ, không trùng');
select is((select count(*)::int from app.holiday where holiday_date = current_date + 500), 1, 'Chỉ còn một dòng cho ngày đó (không nhân đôi)');

-- ---- Sale chỉ xem ----
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.save_holiday(null, current_date + 600, 'Sale thêm', (select id from app.branch where code = 'CS1'))$$), 'HMT_KHONG_CO_QUYEN', 'Sale không thêm được ngày nghỉ');
select is((app.list_holiday_sessions(pg_temp.hol((select v from d)))) is not null, true, 'Sale xem được buổi bị ảnh hưởng của cơ sở mình');

-- ---- Admin ngừng ngày chung ----
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(((app.set_holiday_active((select (v ->> 'id')::uuid from r1), false)) ->> 'is_active')::boolean, false, 'Admin ngừng được ngày nghỉ chung');
select is(app.is_holiday((select v from d), (select id from app.branch where code = 'CS1')), false, 'Ngày nghỉ chung đã Ngừng không còn tính');
select is(pg_temp.err($$delete from app.holiday where id = (select (v ->> 'id')::uuid from r1)$$) is not null, true, 'Không xoá cứng ngày nghỉ');

select * from finish();
rollback;
