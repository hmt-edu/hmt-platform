-- Q-181 (BH-11, R-TIEN-39, migration 088): tạo đơn thẳng từ cơ hội khi cơ hội đã có đơn Nháp thì chặn kèm mã đơn Nháp cũ (HMT_CO_DON_NHAP);
-- có cờ xác nhận thì tạo thêm; đơn tạo từ báo giá không bị áp; đơn Huỷ không tính; get_opportunity_draft_order đọc theo quyền.

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
insert into u (key) values ('admin'), ('bm1'), ('bm1b'), ('bm5'), ('sales1'), ('sales1b'), ('sales5'), ('ke');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@b2.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@b2.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm1b', 'CS1'), ('bm5', 'CS5'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'), ('ke', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm1b', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('sales1', 'SALES'),
  ('sales1b', 'SALES'), ('sales5', 'SALES'), ('ke', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
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

-- Dựng một đơn Nháp từ cơ hội và lưu điều khoản thanh toán.
create function pg_temp.mkorder(p_key text, p_phone text, p_lines jsonb, p_term text) returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_order_from_opportunity(pg_temp.oid(p_phone), p_lines, null, true);
  insert into os values (p_key, (v ->> 'id')::uuid);
  perform app.save_order((v ->> 'id')::uuid, null, pg_temp.term(p_term));
end $$;
grant execute on function pg_temp.mkorder(text, text, jsonb, text) to public;


-- Dòng đơn có ưu đãi linh hoạt (chính sách hệ thống nhập % tay).
select pg_temp.sudo($$create function pg_temp.fpid() returns uuid language sql stable security definer as 'select id from app.discount_policy where code = ''UU_DAI_LINH_HOAT'''$$);
select pg_temp.sudo($$grant execute on function pg_temp.fpid() to public$$);
create function pg_temp.fline(p_ps uuid, p_hours numeric, p_pct text) returns jsonb language sql as $$
  select jsonb_build_object('kind', 'ENROL', 'prospect_student_id', p_ps, 'package_id', pg_temp.pkg('LC-TOAN-K09'), 'delivery_mode_code', 'OFF',
                            'quantity', p_hours,
                            'discounts', case when p_pct is null then '[]'::jsonb
                                         else jsonb_build_array(jsonb_build_object('policy_id', pg_temp.fpid(), 'value', p_pct)) end) $$;
grant execute on function pg_temp.fline(uuid, numeric, text) to public;
select pg_temp.sudo($$create function pg_temp.enote(p_order text, p_event text) returns text language sql stable security definer as
  'select note from app.sales_order_event where order_id = pg_temp.o(p_order) and event_code = p_event order by seq desc limit 1'$$);
select pg_temp.sudo($$grant execute on function pg_temp.enote(text, text) to public$$);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
create temp table qs (key text primary key, id uuid, code text);
grant all on qs to public;
create function pg_temp.q(p_key text) returns uuid language sql stable as $$ select id from qs where key = p_key $$;
grant execute on function pg_temp.q(text) to public;

-- ================= Dựng cơ hội L8 =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009301', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900009302', '{"student_name": "Em Hai", "student_birth_year": 2012}'));
reset role;
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where parent_phone in ('0900009301', '0900009302')$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity((select id from app.lead where parent_phone = '0900009301'));
select app.create_opportunity((select id from app.lead where parent_phone = '0900009302'));
reset role;
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in (pg_temp.oid('0900009301'), pg_temp.oid('0900009302'))$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

create function pg_temp.dcode(p_phone text) returns text language sql stable security definer as
  'select o.code from app.sales_order o where o.opportunity_id = pg_temp.oid(p_phone) and o.status_code = ''NHAP'' order by o.created_at desc, o.code desc limit 1';
grant execute on function pg_temp.dcode(text) to public;
create function pg_temp.ocount(p_phone text) returns bigint language sql stable security definer as
  'select count(*) from app.sales_order o where o.opportunity_id = pg_temp.oid(p_phone)';
grant execute on function pg_temp.ocount(text) to public;

-- Luật R-TIEN-39: cơ hội chưa có đơn Nháp thì tạo bình thường, không cần cờ.
select is(app.get_opportunity_draft_order(pg_temp.oid('0900009301')), null, 'R-TIEN-39: cơ hội chưa có đơn thì hộp BH-11 không có gì để hiện (null)');
insert into os select 'd1', (r ->> 'id')::uuid from (select app.create_order_from_opportunity(pg_temp.oid('0900009301'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009301', 1), 'LC-TOAN-K09', 'OFF', 5))) as r) x;
select is(pg_temp.ocount('0900009301'), 1::bigint, 'R-TIEN-39: chưa có đơn Nháp thì tạo được, không cần cờ xác nhận');

-- Luật R-TIEN-39: đã có đơn Nháp, không cờ: bị chặn, báo mã đơn Nháp cũ, không sinh đơn mới.
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900009301'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009301', 1), 'LC-TOAN-K09', 'OFF', 5)))$$), 'HMT_CO_DON_NHAP',
  'R-TIEN-39: đã có đơn Nháp mà không cờ xác nhận thì chặn HMT_CO_DON_NHAP');
select ok(pg_temp.msg($$select app.create_order_from_opportunity(pg_temp.oid('0900009301'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009301', 1), 'LC-TOAN-K09', 'OFF', 5)))$$) like '%' || pg_temp.dcode('0900009301') || '%',
  'R-TIEN-39: câu báo lỗi nêu mã đơn Nháp cũ');
select is(pg_temp.ocount('0900009301'), 1::bigint, 'R-TIEN-39: bị chặn thì không sinh đơn mới, mã không nhảy số');
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900009301'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009301', 1), 'LC-TOAN-K09', 'OFF', 5)), null, false)$$), 'HMT_CO_DON_NHAP',
  'R-TIEN-39: cờ false rõ ràng cũng bị chặn');

-- Hộp BH-11 đọc đúng đơn Nháp cũ.
select is(app.get_opportunity_draft_order(pg_temp.oid('0900009301')) ->> 'code', pg_temp.dcode('0900009301'), 'BH-11: hộp hiện đúng mã đơn Nháp cũ');
select is(app.get_opportunity_draft_order(pg_temp.oid('0900009301')) ->> 'id', pg_temp.o('d1')::text, 'BH-11: "Mở đơn cũ" có id đơn để mở');
select is((app.get_opportunity_draft_order(pg_temp.oid('0900009301')) ->> 'total_amount')::bigint > 0, true, 'BH-11: hộp có tổng tiền của đơn Nháp');

-- Có cờ xác nhận: tạo thêm được (Vẫn tạo).
insert into os select 'd2', (r ->> 'id')::uuid from (select app.create_order_from_opportunity(pg_temp.oid('0900009301'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009301', 1), 'LC-TOAN-K09', 'OFF', 5)), null, true) as r) x;
select is(pg_temp.ocount('0900009301'), 2::bigint, 'R-TIEN-39: có cờ xác nhận thì tạo thêm, cơ hội có hai đơn Nháp');
select is(app.get_opportunity_draft_order(pg_temp.oid('0900009301')) ->> 'id', pg_temp.o('d2')::text, 'BH-11: hộp lấy đơn Nháp mới nhất');

-- Đơn Huỷ không tính là đơn Nháp (R-CRM-19).
select app.cancel_order(pg_temp.o('d1'), 'KHAC', 'Nhập nhầm');
select app.cancel_order(pg_temp.o('d2'), 'KHAC', 'Nhập nhầm');
select is(app.get_opportunity_draft_order(pg_temp.oid('0900009301')), null, 'R-TIEN-39: đơn đã Huỷ thì không còn cảnh báo (null)');
insert into os select 'd3', (r ->> 'id')::uuid from (select app.create_order_from_opportunity(pg_temp.oid('0900009301'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009301', 1), 'LC-TOAN-K09', 'OFF', 5))) as r) x;
select is(pg_temp.ocount('0900009301'), 3::bigint, 'R-TIEN-39: các đơn trước đã Huỷ thì tạo mới không cần cờ');

-- Không áp cho đơn tạo từ báo giá: cơ hội đang có đơn Nháp (d3), vẫn chuyển được báo giá thành đơn.
insert into qs select 'q1', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009301'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009301', 1), 'LC-TOAN-K09', 'OFF', 5))) as r) x;
select app.send_quotation(pg_temp.q('q1'));
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'))$$), null, 'R-TIEN-39: đơn tạo từ báo giá không bị cảnh báo đơn Nháp');

-- Quyền: người ngoài cơ sở không đọc được hộp BH-11.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select isnt(pg_temp.err($$select app.get_opportunity_draft_order(pg_temp.oid('0900009301'))$$), null, 'Sale cơ sở khác không đọc được hộp BH-11');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

select * from finish();
rollback;
