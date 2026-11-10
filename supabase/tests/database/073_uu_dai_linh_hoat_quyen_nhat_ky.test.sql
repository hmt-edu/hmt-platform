-- Q-154 (migration 086): (a) Báo giá có chính sách chiết khấu ghi audit_log đúng người nhập, giá trị % nằm ở dòng chụp lại; (b) app.order_flexible_note không còn cho người dùng gọi trực tiếp, ba hàm tạo, sửa đơn vẫn chạy.
-- Mỗi luật có ca đúng và ca bị chặn.
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
  v := app.create_order_from_opportunity(pg_temp.oid(p_phone), p_lines);
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
select app.create_lead(pg_temp.lead_data('0900009201', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900009202', '{"student_name": "Em Hai", "student_birth_year": 2012}'));
reset role;
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where parent_phone in ('0900009201', '0900009202')$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity((select id from app.lead where parent_phone = '0900009201'));
select app.create_opportunity((select id from app.lead where parent_phone = '0900009202'));
reset role;
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in (pg_temp.oid('0900009201'), pg_temp.oid('0900009202'))$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= (a) Báo giá: audit_log của quotation_line_discount =================
insert into qs select 'a1', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009202'),
  jsonb_build_array(pg_temp.fline(pg_temp.ps('0900009202', 1), 10, '3'))) as r) x;
select pg_temp.sudo($$create function pg_temp.dnum(p_q text) returns bigint language sql stable security definer as
  'select count(*) from app.quotation_line_discount d join app.quotation_line l on l.id = d.line_id where l.quotation_id = pg_temp.q(p_q)'$$);
select pg_temp.sudo($$create function pg_temp.dval(p_q text) returns numeric language sql stable security definer as
  'select d.applied_value from app.quotation_line_discount d join app.quotation_line l on l.id = d.line_id where l.quotation_id = pg_temp.q(p_q)'$$);
select pg_temp.sudo($$create function pg_temp.dby(p_q text) returns uuid language sql stable security definer as
  'select d.created_by from app.quotation_line_discount d join app.quotation_line l on l.id = d.line_id where l.quotation_id = pg_temp.q(p_q)'$$);
select pg_temp.sudo($$create function pg_temp.dactor(p_q text) returns uuid language sql stable security definer as
  'select a.actor from app.audit_log a join app.audited_table t on t.id = a.table_id join app.quotation_line_discount d on d.id = a.record_id
     join app.quotation_line l on l.id = d.line_id
    where t.table_name = ''app.quotation_line_discount'' and a.action = ''I'' and l.quotation_id = pg_temp.q(p_q)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.dnum(text), pg_temp.dval(text), pg_temp.dby(text), pg_temp.dactor(text) to public$$);
select is(pg_temp.dnum('a1'), 1::bigint, 'Báo giá lưu một dòng chính sách chiết khấu (Ưu đãi linh hoạt)');
select is(pg_temp.dval('a1'), 3::numeric, 'Dòng chiết khấu chụp lại mức đã nhập: 3% (applied_value)');
select is(pg_temp.dby('a1'), pg_temp.uid('sales1'), 'Dòng chiết khấu ghi người nhập: sales1 (created_by)');
select is(pg_temp.dactor('a1'), pg_temp.uid('sales1'), 'audit_log của quotation_line_discount ghi hành động I do sales1');

-- ================= (b) order_flexible_note không còn gọi trực tiếp được =================
-- Ba hàm tạo, sửa đơn vẫn ghi dòng ưu đãi vào dòng thời gian (chạy bằng quyền chủ hàm).
insert into os select 'e1', (r ->> 'id')::uuid from (select app.create_order_from_opportunity(pg_temp.oid('0900009202'),
  jsonb_build_array(pg_temp.fline(pg_temp.ps('0900009202', 1), 5, '2'))) as r) x;
select is(pg_temp.enote('e1', 'TAO'), 'Ưu đãi linh hoạt 2% ở dòng 1', 'Q-154b: create_order_from_opportunity vẫn ghi dòng ưu đãi sau khi thu quyền');
select app.save_order(pg_temp.o('e1'), null, pg_temp.term('CHIA_3_DOT'));
select app.edit_order(pg_temp.o('e1'), jsonb_build_array(jsonb_build_object('line_no', 1, 'discounts', pg_temp.fline(pg_temp.ps('0900009202', 1), 5, '4') -> 'discounts')));
select ok(pg_temp.enote('e1', 'SUA') like '%Ưu đãi linh hoạt 4% ở dòng 1%', 'Q-154b: edit_order vẫn ghi dòng ưu đãi sau khi thu quyền');

select is(pg_temp.err($$select app.order_flexible_note(pg_temp.o('e1'), false)$$), '42501',
          'Q-154b: người dùng đăng nhập gọi trực tiếp order_flexible_note: bị từ chối (42501)');
select ok(not has_function_privilege('authenticated', 'app.order_flexible_note(uuid, boolean)', 'execute'),
          'Q-154b: authenticated không có quyền thực thi order_flexible_note');
select ok(not has_function_privilege('anon', 'app.order_flexible_note(uuid, boolean)', 'execute'),
          'Q-154b: anon không có quyền thực thi order_flexible_note');
select * from finish();
rollback;
