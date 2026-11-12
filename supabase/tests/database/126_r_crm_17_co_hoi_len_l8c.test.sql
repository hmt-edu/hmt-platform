-- R-CRM-17 (migration 126): duyệt phiếu thu làm MỌI đơn đã duyệt của cơ hội thu đủ thì cơ hội L8A/L8B tự lên L8C (xét từng đơn, chỉ tính phiếu đã duyệt).
-- Dựng đơn thật như 103 (cơ hội, đơn, phiếu thu, kế toán duyệt); KHÔNG gọi tay hàm tạo ghi danh: mọi ghi danh ở đây do việc duyệt phiếu thu sinh ra.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p126.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p126.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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
create function pg_temp.sub(p_phone text) returns text language sql stable security definer as $$
  select substage_code from app.opportunity where id = pg_temp.oid(p_phone) $$;
-- Trả phần còn lại của đơn (hoặc p_less nhỏ hơn) qua chuỗi duyệt đầy đủ.
create function pg_temp.pay(p_order text, p_amount bigint, p_final boolean default true) returns void language plpgsql as $$
declare v jsonb; v_id uuid;
begin
  perform pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
  v := app.create_receipt(pg_temp.o(p_order), jsonb_build_object('amount', p_amount, 'payment_method_code', 'TIEN_MAT'));
  v_id := (v ->> 'id')::uuid;
  perform app.submit_receipt(v_id);
  perform pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
  perform app.approve_receipt_manager(v_id);
  if p_final then
    perform pg_temp.claims(pg_temp.uid('ke'), 'aal2');
    perform app.approve_receipt_accounting(v_id);
  end if;
  perform pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
end $$;
create function pg_temp.total(p_order text) returns bigint language sql stable security definer as $$ select total_amount from app.sales_order where id = pg_temp.o(p_order) $$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Dựng cơ hội và đơn ----------
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900126001', '{"student_name": "Em A", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900126002', '{"student_name": "Em B", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900126003', '{"student_name": "Em C", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900126004', '{"student_name": "Em D", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900126001'));
select app.create_opportunity(pg_temp.lid('0900126002'));
select app.create_opportunity(pg_temp.lid('0900126003'));
select app.create_opportunity(pg_temp.lid('0900126004'));
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Hai', 2013 from app.opportunity o where o.id = pg_temp.oid('0900126003')$$);
-- 001 ở L8B (đơn thu đủ), 002 ở L8A (thu thiếu), 003 ở L8A (hai đơn), 004 ở L8A (phiếu chưa duyệt).
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8B' where id = pg_temp.oid('0900126001')$$);
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in (pg_temp.oid('0900126002'), pg_temp.oid('0900126003'), pg_temp.oid('0900126004'))$$);
create function pg_temp.mkorder(p_key text, p_phone text, p_pos integer) returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_order_from_opportunity(pg_temp.oid(p_phone), jsonb_build_array(pg_temp.line(pg_temp.ps(p_phone, p_pos), 'LC-TOAN-K09', 'OFF', 10)), null, true);
  insert into os values (p_key, (v ->> 'id')::uuid);
  perform app.save_order((v ->> 'id')::uuid, null, pg_temp.term('COC_VA_CHIA_DOT'));
  perform app.submit_order((v ->> 'id')::uuid);
  perform pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
  perform app.approve_order((v ->> 'id')::uuid);
  perform pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
end $$;
grant execute on function pg_temp.mkorder(text, text, integer) to public;
select pg_temp.mkorder('a', '0900126001', 1);
select pg_temp.mkorder('b', '0900126002', 1);
select pg_temp.mkorder('c1', '0900126003', 1);
select pg_temp.mkorder('c2', '0900126003', 2);
select pg_temp.mkorder('d', '0900126004', 1);

-- ================= (b) thu thiếu: giữ nguyên =================
select pg_temp.pay('b', pg_temp.total('b') - 100000);
select is(pg_temp.sub('0900126002'), 'L8A', 'R-CRM-17 (b): đơn còn thiếu tiền thì cơ hội giữ nguyên L8A');

-- ================= (d) phiếu thu chưa duyệt không tính =================
select pg_temp.pay('d', pg_temp.total('d'), false);
select is(pg_temp.sub('0900126004'), 'L8A', 'R-CRM-17 (d): phiếu thu mới qua quản lý, kế toán chưa duyệt thì không tính, giữ L8A');

-- ================= (c) hai đơn, một đủ một thiếu: giữ nguyên =================
select pg_temp.pay('c1', pg_temp.total('c1'));
select is(pg_temp.sub('0900126003'), 'L8A', 'R-CRM-17 (c): hai đơn, một đủ một chưa thu: giữ L8A (xét từng đơn, không cộng gộp)');
select pg_temp.pay('c2', pg_temp.total('c2'));
select is(pg_temp.sub('0900126003'), 'L8C', 'R-CRM-17: đơn còn lại thu đủ thì cả hai đơn đủ, cơ hội lên L8C');

-- ================= (a) một đơn thu đủ: lên L8C (từ L8B) =================
select pg_temp.pay('a', pg_temp.total('a'));
select is(pg_temp.sub('0900126001'), 'L8C', 'R-CRM-17 (a): đơn duy nhất thu đủ thì cơ hội L8B lên L8C');
select is((select stage_code from app.opportunity where id = pg_temp.oid('0900126001')), 'L8', 'Vẫn ở giai đoạn L8');

-- ================= Chỉ đi tới: đã L8C không lùi khi có đơn mới chưa thu =================
select pg_temp.sudo($$update app.opportunity set substage_code = 'L8C' where id = pg_temp.oid('0900126002')$$);
select pg_temp.pay('b', 100000);
select is(pg_temp.sub('0900126002'), 'L8C', 'R-CRM-17: đã L8C thì giữ nguyên L8C');

select * from finish();
rollback;
