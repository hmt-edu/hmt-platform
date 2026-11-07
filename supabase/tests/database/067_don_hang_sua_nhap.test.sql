-- Đơn hàng bước 2 (migration 079, anh chốt 06/11: B1, Q-29, Q-31): sửa đơn Nháp tại chỗ (đơn thẳng từ cơ hội và đơn chuyển từ báo giá), nhật ký "Sửa đơn" /
-- "Đơn đã sửa so với báo giá", trình lại chưa sửa từ lần bị từ chối. Mỗi luật có ca đúng và ca bị chặn. Dữ liệu giả.
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
  select jsonb_build_object('parent_name', 'Chị Sửa Đơn', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('hs');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@so.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@so.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999997' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('hs', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$create function pg_temp.pkg(p_code text) returns uuid language sql stable security definer as 'select id from app.sales_package where code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.pol(p_code text) returns uuid language sql stable security definer as 'select id from app.discount_policy where code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.term(p_code text) returns uuid language sql stable security definer as 'select id from app.payment_term where code = p_code and version = 1'$$);
select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as 'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone'$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable security definer as 'select id from app.lead where parent_phone = p_phone order by code limit 1'$$);
select pg_temp.sudo($$create function pg_temp.ps(p_phone text, p_pos integer) returns uuid language sql stable security definer as
  'select ps.id from app.prospect_student ps where ps.opportunity_id = pg_temp.oid(p_phone) and ps.position = p_pos'$$);
select pg_temp.sudo($$grant execute on function pg_temp.pkg(text), pg_temp.pol(text), pg_temp.term(text), pg_temp.oid(text), pg_temp.lid(text),
  pg_temp.ps(text, integer) to public$$);
create function pg_temp.line(p_ps uuid, p_pkg text, p_mode text, p_qty numeric, p_disc jsonb default '[]'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('kind', 'ENROL', 'prospect_student_id', p_ps, 'package_id', pg_temp.pkg(p_pkg), 'delivery_mode_code', p_mode,
                            'quantity', p_qty, 'discounts', p_disc) $$;
create function pg_temp.disc(p_policy text, p_value numeric default null) returns jsonb language sql as $$
  select jsonb_build_object('policy_id', pg_temp.pol(p_policy), 'value', p_value) $$;
grant execute on function pg_temp.line(uuid, text, text, numeric, jsonb), pg_temp.disc(text, numeric) to public;
create temp table os (key text primary key, id uuid, code text);
grant all on os to public;
create temp table qs (key text primary key, id uuid, code text);
grant all on qs to public;
create function pg_temp.o(p_key text) returns uuid language sql stable as $$ select id from os where key = p_key $$;
create function pg_temp.q(p_key text) returns uuid language sql stable as $$ select id from qs where key = p_key $$;
grant execute on function pg_temp.o(text), pg_temp.q(text) to public;
create function pg_temp.mk(p_key text, p_phone text, p_lines jsonb) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := app.create_order_from_opportunity(pg_temp.oid(p_phone), p_lines);
  insert into os values (p_key, (r ->> 'id')::uuid, r ->> 'code');
  return r;
end $$;
grant execute on function pg_temp.mk(text, text, jsonb) to public;
-- Đọc bằng quyền chủ: sự kiện, dòng, tổng.
create function pg_temp.evs(p_key text) returns text language sql stable security definer set search_path = '' as
  $f$ select string_agg(event_code, ',' order by seq) from app.sales_order_event where order_id = (select id from pg_temp.os where key = p_key) $f$;
create function pg_temp.note(p_key text, p_code text) returns text language sql stable security definer set search_path = '' as
  $f$ select note from app.sales_order_event where order_id = (select id from pg_temp.os where key = p_key) and event_code = p_code order by seq desc limit 1 $f$;
create function pg_temp.lq(p_key text, p_no integer, p_col text) returns text language plpgsql stable security definer set search_path = '' as
  $f$ declare r text; begin execute format('select %I::text from app.sales_order_line where order_id = (select id from pg_temp.os where key = %L) and line_no = %s', p_col, p_key, p_no) into r; return r; end $f$;
create function pg_temp.nlines(p_key text) returns integer language sql stable security definer set search_path = '' as
  $f$ select count(*)::int from app.sales_order_line where order_id = (select id from pg_temp.os where key = p_key) $f$;
create function pg_temp.tot(p_key text) returns text language sql stable security definer set search_path = '' as
  $f$ select total_amount::text from app.sales_order where id = (select id from pg_temp.os where key = p_key) $f$;
create function pg_temp.resub(p_key text) returns boolean language sql stable security definer set search_path = '' as
  $f$ select app.order_resubmitted_unedited((select id from pg_temp.os where key = p_key)) $f$;
grant execute on function pg_temp.resub(text), pg_temp.evs(text), pg_temp.note(text, text), pg_temp.lq(text, integer, text), pg_temp.nlines(text), pg_temp.tot(text) to public;

-- ================= Dữ liệu =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900008001', '{"parent_name": "Chị Sửa Một", "student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900008002', '{"parent_name": "Chị Sửa Hai", "student_name": "Em Hai", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900008001'));
select app.create_opportunity(pg_temp.lid('0900008002'));
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Ba', 2014 from app.opportunity o where o.id = pg_temp.oid('0900008001')$$);
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in (pg_temp.oid('0900008001'), pg_temp.oid('0900008002'))$$);
-- e1: đơn thẳng hai dòng (dòng 1 có chính sách cố định); e2: đơn chuyển từ báo giá.
select pg_temp.mk('e1', '0900008001', jsonb_build_array(
  pg_temp.line(pg_temp.ps('0900008001', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_6_THANG'))),
  pg_temp.line(pg_temp.ps('0900008001', 2), 'LC-TOAN-K09', 'OFF', 5)));
select app.save_order(pg_temp.o('e1'), null, pg_temp.term('CHIA_3_DOT'));
insert into qs select 'q1', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900008002'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900008002', 1), 'LC-TOAN-K09', 'OFF', 6, jsonb_build_array(pg_temp.disc('GIAM_6_THANG'))))) as r) x;
select app.send_quotation(pg_temp.q('q1'));
insert into os select 'e2', (r ->> 'id')::uuid, r ->> 'code' from (select app.create_order_from_quotation(pg_temp.q('q1')) as r) x;
select app.save_order(pg_temp.o('e2'), null, pg_temp.term('CHIA_3_DOT'));

-- ================= Đơn thẳng: sửa tại chỗ =================
select is(pg_temp.nlines('e1'), 2, 'Đơn e1 có hai dòng');
select is(pg_temp.lq('e1', 1, 'discount_percent'), '5.00', 'Dòng 1 có chiết khấu 5% của chính sách cố định');
select is(app.edit_order(pg_temp.o('e1'), '[{"line_no": 1, "quantity": 20}]') ->> 'changed', 'true', 'Đúng: đổi số giờ dòng 1, có thay đổi');
select is(pg_temp.lq('e1', 1, 'quantity'), '20.00', 'Số giờ dòng 1 đã đổi');
select is(pg_temp.lq('e1', 1, 'discount_percent'), '5.00', 'Chính sách giữ nguyên khi không gửi chiết khấu');
select is(pg_temp.lq('e1', 1, 'gross_amount'), '4400000', 'Thành tiền tính lại ở máy chủ: 20 giờ × 220.000');
select is(pg_temp.evs('e1'), 'TAO,SUA', 'Sửa có đổi thì ghi sự kiện SUA');
select ok(pg_temp.note('e1', 'SUA') like 'Sửa đơn: dòng 1 (LC-TOAN-K09): số giờ 10 → 20%', 'Nhật ký ghi giá trị cũ và mới (đơn thẳng: "Sửa đơn")');
select is(app.edit_order(pg_temp.o('e1'), '[{"line_no": 1, "quantity": 20}]') ->> 'changed', 'false', 'Gửi lại đúng giá trị cũ: không có thay đổi');
select is(pg_temp.evs('e1'), 'TAO,SUA', 'Không đổi gì thì không ghi sự kiện thêm');
select is(app.edit_order(pg_temp.o('e1'), '[{"line_no": 1, "discounts": []}]') ->> 'changed', 'true', 'Bỏ chính sách chiết khấu của dòng');
select is(pg_temp.lq('e1', 1, 'discount_percent'), '0.00', 'Bỏ chính sách thì chiết khấu về 0');
select is(pg_temp.err($$select app.edit_order(pg_temp.o('e1'), '[{"line_no": 9, "quantity": 3}]')$$), 'HMT_DONG_KHONG_CO', 'Chặn: dòng không có trong đơn');
select is(pg_temp.err($$select app.edit_order(pg_temp.o('e1'), '[{"line_no": 1, "quantity": 0}]')$$), 'HMT_DONG_THIEU', 'Chặn: số lượng 0');
select is(app.edit_order(pg_temp.o('e1'), '[{"line_no": 1, "remove": true}]') ->> 'changed', 'true', 'Bỏ dòng 1');
select is(pg_temp.nlines('e1'), 1, 'Còn một dòng');
select is(pg_temp.lq('e1', 1, 'quantity'), '5.00', 'Dòng còn lại được đánh lại số dòng 1');
select is(pg_temp.err($$select app.edit_order(pg_temp.o('e1'), '[{"line_no": 1, "remove": true}]')$$), 'HMT_DON_KHONG_DONG', 'Chặn: bỏ hết dòng thì đơn không còn dòng nào');
select is(pg_temp.nlines('e1'), 1, 'Bị chặn thì dòng cuối còn nguyên (giao dịch hoàn tác)');
select is(pg_temp.err($$select app.edit_order(pg_temp.o('e1'), null, gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Chặn: điều khoản không có');

-- ================= Đơn chuyển từ báo giá: sửa được như đơn Nháp (B1), có nhật ký so với báo giá (Q-31) =================
select is(pg_temp.lq('e2', 1, 'quantity'), '6.00', 'Đơn từ báo giá: dòng sao nguyên số giờ 6');
select is(app.edit_order(pg_temp.o('e2'), '[{"line_no": 1, "quantity": 8, "delivery_mode_code": "OFF"}]') ->> 'changed', 'true', 'Đơn từ báo giá Nháp: sửa số giờ được (trước đây bị khoá)');
select is(pg_temp.lq('e2', 1, 'quantity'), '8.00', 'Số giờ đã đổi theo báo giá chuyển đơn');
select is(pg_temp.lq('e2', 1, 'unit_price'), '220000', 'Đơn giá tính theo ngày tính giá của đơn (ngày báo giá), không đổi');
select isnt(pg_temp.lq('e2', 1, 'quotation_line_id'), null, 'Liên kết dòng báo giá được giữ');
select ok(pg_temp.note('e2', 'SUA') like 'Đơn đã sửa so với báo giá %: dòng 1 (LC-TOAN-K09): số giờ 6 → 8%', 'Q-31: nhật ký ghi "Đơn đã sửa so với báo giá <mã>" kèm cũ, mới');
select ok(pg_temp.note('e2', 'SUA') like '%' || (select code from qs where key = 'q1') || '%', 'Nhật ký nêu đúng mã báo giá');
select is(app.edit_order(pg_temp.o('e2'), '[{"line_no": 1, "discounts": []}]') ->> 'changed', 'true', 'Đơn từ báo giá: bỏ chiết khấu được');

-- Đổi hình thức: tra bảng giá tại ngày tính giá của đơn (cho mọi dòng được sửa, anh chốt 07/11); nhật ký ghi hình thức và đơn giá cũ, mới.
select is(app.edit_order(pg_temp.o('e2'), '[{"line_no": 1, "delivery_mode_code": "ONL"}]') ->> 'changed', 'true', 'Đổi hình thức dòng đơn từ báo giá');
select is(pg_temp.lq('e2', 1, 'unit_price'), '120000', 'Đổi hình thức thì tra bảng giá (online 120.000)');
select ok(pg_temp.note('e2', 'SUA') like 'Đơn đã sửa so với báo giá %đơn giá 220.000 → 120.000%' and pg_temp.note('e2', 'SUA') like '%hình thức OFF → ONL%', 'Nhật ký ghi hình thức OFF → ONL và đơn giá 220.000 → 120.000');

-- ================= Quyền, trạng thái =================
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.edit_order(pg_temp.o('e1'), '[]')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: học sinh không sửa đơn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.submit_order(pg_temp.o('e1'));
select is(pg_temp.err($$select app.edit_order(pg_temp.o('e1'), '[]')$$), 'HMT_DON_DA_KHOA', 'Chặn: đơn đã trình không sửa được');

-- ================= Trình lại chưa sửa từ lần bị từ chối (Q-29) =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.reject_order(pg_temp.o('e1'), 'THIEU_THONG_TIN');
select is(pg_temp.resub('e1'), true, 'Vừa bị từ chối, chưa có sự kiện SUA sau đó: coi là chưa sửa');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.submit_order(pg_temp.o('e1'));
select is(pg_temp.note('e1', 'TRINH'), 'Trình lại, chưa sửa từ lần bị từ chối', 'Q-29: lần trình lại không sửa được ghi rõ trong nhật ký');
select ok(pg_temp.evs('e1') like '%TU_CHOI,TRINH', 'Lịch sử có lần từ chối rồi lần trình lại');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.reject_order(pg_temp.o('e1'), 'THIEU_THONG_TIN');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.edit_order(pg_temp.o('e1'), '[{"line_no": 1, "quantity": 7}]');
select is(pg_temp.resub('e1'), false, 'Đã sửa sau lần từ chối: không còn coi là chưa sửa');
select app.submit_order(pg_temp.o('e1'));
select is(pg_temp.note('e1', 'TRINH'), null, 'Trình lại sau khi đã sửa: không có ghi chú "chưa sửa"');
select is(pg_temp.resub('e2'), false, 'Đơn chưa từng bị từ chối: không phải trình lại chưa sửa');

select * from finish();
rollback;
