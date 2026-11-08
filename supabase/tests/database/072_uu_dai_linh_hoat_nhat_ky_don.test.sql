-- Ưu đãi linh hoạt (Q-145, R-V2-45; migration 085): nhật ký đơn. Sự kiện TAO và SUA thêm dòng "Ưu đãi linh hoạt X% ở dòng N" (không ghi tên người);
-- đơn tạo từ báo giá thêm cuối dòng "(nhập ở báo giá BG-...)". Đơn tạo trực tiếp, đơn từ báo giá, sửa đơn (đổi mức, thêm dòng). Mỗi luật có ca đúng và ca chặn.

-- Mỗi luật có ca đúng và ca bị chặn; vai đọc, ghi trong và ngoài phạm vi. Dữ liệu giả.
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

-- ================= (1) Đơn tạo trực tiếp từ cơ hội: ưu đãi nhập ngay ở đơn =================
insert into os select 'd1', (r ->> 'id')::uuid from (select app.create_order_from_opportunity(pg_temp.oid('0900009201'),
  jsonb_build_array(pg_temp.fline(pg_temp.ps('0900009201', 1), 10, null), pg_temp.fline(pg_temp.ps('0900009201', 1), 5, '3'))) as r) x;
select is(pg_temp.enote('d1', 'TAO'), 'Ưu đãi linh hoạt 3% ở dòng 2', 'Q-145: đơn tạo trực tiếp: TAO ghi "Ưu đãi linh hoạt 3% ở dòng 2" (X% và số dòng thật)');
select ok(pg_temp.enote('d1', 'TAO') not like '%báo giá%', 'Q-145: đơn tạo trực tiếp không có chữ "nhập ở báo giá"');
select ok(pg_temp.enote('d1', 'TAO') not like '%Giả sales1%', 'Q-145: dòng không ghi tên người (sự kiện đã hiện người thực hiện)');
insert into os select 'd0', (r ->> 'id')::uuid from (select app.create_order_from_opportunity(pg_temp.oid('0900009202'),
  jsonb_build_array(pg_temp.fline(pg_temp.ps('0900009202', 1), 8, null))) as r) x;
select is(pg_temp.enote('d0', 'TAO'), null, 'Q-145: đơn không có ưu đãi linh hoạt: TAO không thêm dòng nào (note trống)');

-- ================= (2) Đơn tạo từ báo giá: % nhập ở báo giá, kèm mã báo giá =================
insert into qs select 'b1', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009202'),
  jsonb_build_array(pg_temp.fline(pg_temp.ps('0900009202', 1), 10, '2'), pg_temp.fline(pg_temp.ps('0900009202', 1), 4, null))) as r) x;
select app.send_quotation(pg_temp.q('b1'));
insert into os select 'b1d', (r ->> 'id')::uuid from (select app.create_order_from_quotation(pg_temp.q('b1')) as r) x;
select is(pg_temp.enote('b1d', 'TAO'), 'Ưu đãi linh hoạt 2% ở dòng 1 (nhập ở báo giá ' || (select code from qs where key = 'b1') || ')',
          'Q-145: đơn từ báo giá: TAO ghi dòng ưu đãi kèm "(nhập ở báo giá <mã thật>)"');

-- ================= (3) Sửa đơn: đổi mức, thêm dòng, sửa không đụng ưu đãi =================
select app.save_order(pg_temp.o('d1'), null, pg_temp.term('CHIA_3_DOT'));
select app.edit_order(pg_temp.o('d1'), jsonb_build_array(jsonb_build_object('line_no', 2, 'discounts', pg_temp.fline(pg_temp.ps('0900009201', 1), 5, '4') -> 'discounts')));
select ok(pg_temp.enote('d1', 'SUA') like '%Ưu đãi linh hoạt 4% ở dòng 2%', 'Q-145: sửa đổi mức 3% thành 4%: SUA ghi "Ưu đãi linh hoạt 4% ở dòng 2"');
select app.edit_order(pg_temp.o('d1'), jsonb_build_array(jsonb_build_object('line_no', 2, 'quantity', 6)));
select ok(pg_temp.enote('d1', 'SUA') not like '%Ưu đãi linh hoạt%', 'Q-145: sửa số giờ mà không đổi mức ưu đãi: SUA không thêm dòng ưu đãi');
select app.edit_order(pg_temp.o('d1'), jsonb_build_array(jsonb_build_object('add', pg_temp.fline(pg_temp.ps('0900009201', 1), 3, '1.5'))));
select ok(pg_temp.enote('d1', 'SUA') like '%Ưu đãi linh hoạt 1.5% ở dòng 3%', 'Q-145: thêm dòng mới có ưu đãi 1,5%: SUA ghi "Ưu đãi linh hoạt 1.5% ở dòng 3"');
select is(pg_temp.enote('b1d', 'SUA'), null, 'Đơn chưa sửa: không có sự kiện SUA');
-- Luật chặn vẫn nguyên: nhập quá hạn mức khi sửa đơn.
select is(pg_temp.err($$select app.edit_order(pg_temp.o('d1'), jsonb_build_array(jsonb_build_object('line_no', 1, 'discounts', pg_temp.fline(pg_temp.ps('0900009201', 1), 10, '6') -> 'discounts')))$$),
          'HMT_UU_DAI_VUOT_MUC', 'R-V2-45: sửa đơn nhập 6% vượt hạn mức 5%: bị từ chối');

select * from finish();
rollback;
