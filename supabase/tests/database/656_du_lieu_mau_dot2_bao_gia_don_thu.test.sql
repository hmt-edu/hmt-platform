-- Dữ liệu mẫu đợt 2, mảnh báo giá, đơn hàng, phiếu thu (migration 656; B-23-41, B-23-42). Dữ liệu giả.
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

create temp table u (key text primary key, role_code text not null, id uuid not null default gen_random_uuid());
insert into u (key, role_code) values ('admin', 'ADMIN'), ('cskh5', 'CSKH'), ('ketoan', 'ACCOUNTANT'), ('gv5', 'TEACHER'), ('tg5', 'TA');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@dm.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@dm.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code) select id, role_code from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

create temp table s1 (id uuid);
grant all on s1 to public;
create temp table s2 (id uuid);
grant all on s2 to public;
-- Cơ hội mẫu đầu tiên của bộ s1, để thử gọi thẳng hàm báo giá (người gọi khác nhau).
create function pg_temp.first_opp() returns uuid language sql security definer as $$
  select entity_id from app.demo_data_item where set_id = (select id from s1) and entity_type = 'OPPORTUNITY' order by created_at, entity_id limit 1 $$;
create function pg_temp.lines_for(p_opp uuid) returns jsonb language sql security definer as $$
  select jsonb_build_array(jsonb_build_object('kind', 'ENROL',
           'prospect_student_id', (select id from app.prospect_student where opportunity_id = p_opp order by position limit 1),
           'package_id', (select p.id from app.sales_package p where p.grade_from_code is not null and p.is_active order by p.code limit 1),
           'delivery_mode_code', (select pp.delivery_mode_code from app.sales_package p join app.package_price pp on pp.package_id = p.id
                                   where p.grade_from_code is not null and p.is_active and pp.unit_price is not null order by p.code, pp.delivery_mode_code limit 1),
           'quantity', 10, 'discounts', '[]'::jsonb)) $$;
create function pg_temp.first_order() returns uuid language sql security definer as $$
  select id from app.sales_order where is_demo order by created_at, id limit 1 $$;
create function pg_temp.n_quotes() returns bigint language sql security definer as $$
  select count(*) from app.quotation where is_demo $$;
grant execute on function pg_temp.first_opp(), pg_temp.lines_for(uuid), pg_temp.first_order(), pg_temp.n_quotes() to public;

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'demo_data_enabled'$$);
select pg_temp.sudo($$insert into app.deployment_env (env_code) values ('STAGING')$$);

-- Bộ đầu do CSKH tạo: lead, cơ hội (mảnh F) rồi báo giá, đơn, phiếu thu (mảnh B).
insert into s1 select app.create_demo_data_set();

-- Số lượng và trạng thái.
select is((select count(*) from app.quotation where is_demo), 6::bigint, 'Đúng: bộ có 6 báo giá mẫu');
select is((select count(*) from app.quotation where is_demo and status_code = 'DA_GUI'), 5::bigint, 'Đúng: 5 báo giá Đã gửi');
select is((select count(*) from app.quotation where is_demo and status_code = 'NHAP'), 1::bigint, 'Đúng: 1 báo giá còn Nháp');
select is((select count(*) from app.sales_order where is_demo), 4::bigint, 'Đúng: bộ có 4 đơn hàng mẫu');
select is((select count(*) from app.sales_order where is_demo and status_code = 'DA_DUYET'), 2::bigint, 'Đúng: 2 đơn đã duyệt để có phiếu thu, 2 đơn còn Nháp');
select is((select count(*) from app.receipt where is_demo and status_code = 'NHAP'), 2::bigint, 'Đúng: 2 phiếu thu mẫu ở Nháp (không duyệt, không sinh khoản tiền vào)');
select is((select count(*) from app.receipt r join app.sales_order o on o.id = r.order_id where r.is_demo and r.amount >= o.total_amount), 1::bigint, 'Đúng: một phiếu thu đủ, một phiếu thiếu một phần');
select is((select count(*) from app.demo_data_item where set_id = (select id from s1) and entity_type in ('QUOTATION', 'ORDER', 'RECEIPT')), 12::bigint, 'Đúng: mỗi báo giá, đơn, phiếu thu có dòng demo_data_item (6 + 4 + 2)');
select is((select count(*) from app.student where is_demo), 2::bigint, 'Đúng: hồ sơ học sinh do duyệt hai đơn tạo ra thuộc bộ (is_demo)');
select is((select count(*) from app.opportunity where is_demo and stage_code = 'L8'), 4::bigint, 'Ràng buộc 4: 4 cơ hội mẫu có đơn được nâng lên L8');

-- Luật mã: cấp bằng hàm thật như bản thật.
select is((select count(*) from app.quotation where is_demo and code !~ '^BG-CS5-[0-9]{4}-[0-9]{4}$'), 0::bigint, 'Luật mã: báo giá cấp mã như bản thật');
select is((select count(*) from app.receipt where is_demo and code !~ '^PT-CS5-[0-9]{4}-[0-9]{4}$'), 0::bigint, 'Luật mã: phiếu thu cấp mã như bản thật');
select is((select count(*) from app.receipt where is_demo and note !~ '^\[MẪU\]'), 0::bigint, 'Luật nhãn: phiếu thu mẫu ghi rõ [MẪU]');

-- Ràng buộc 1 và 3(d): hết giao dịch gọi thì cờ không còn.
select is(coalesce(current_setting('hmt.demo_sales', true), ''), '', 'Ràng buộc 1: sau khi tạo bộ, cờ hmt.demo_sales không còn');

-- Ràng buộc 3(b): người không có quyền gọi thẳng hàm thật vẫn bị chặn (kể cả khi bộ mẫu đã có).
select pg_temp.claims(pg_temp.uid('tg5'), 'aal1');
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.first_opp(), pg_temp.lines_for(pg_temp.first_opp()))$$), 'HMT_KHONG_CO_QUYEN', 'Ràng buộc 3b: Trợ giảng gọi thẳng save_quotation vẫn bị chặn');
select is(pg_temp.err($$select app.create_receipt(pg_temp.first_order(), '{"amount": 1000}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Ràng buộc 3b: Trợ giảng gọi thẳng create_receipt vẫn bị chặn');

-- Ràng buộc 2 và 3(a): cờ bật nhưng thiếu khoá thì vẫn bị chặn; có cờ mà công tắc tắt cũng vậy.
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'demo_data_enabled'$$);
select pg_temp.sudo($$select set_config('hmt.demo_sales', 'on', true)$$);
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.first_opp(), pg_temp.lines_for(pg_temp.first_opp()))$$), 'HMT_KHONG_CO_QUYEN', 'Ràng buộc 3a: cờ bật nhưng công tắc dữ liệu mẫu tắt thì vẫn bị chặn');
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'demo_data_enabled'$$);
select pg_temp.sudo($$delete from app.deployment_env$$);
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.first_opp(), pg_temp.lines_for(pg_temp.first_opp()))$$), 'HMT_KHONG_CO_QUYEN', 'Ràng buộc 3a: cờ bật nhưng thiếu dòng STAGING (coi như chạy thật) thì vẫn bị chặn');
select pg_temp.sudo($$insert into app.deployment_env (env_code) values ('PROD')$$);
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.first_opp(), pg_temp.lines_for(pg_temp.first_opp()))$$), 'HMT_KHONG_CO_QUYEN', 'Ràng buộc 3a: cờ bật nhưng môi trường PROD thì vẫn bị chặn');
select pg_temp.sudo($$delete from app.deployment_env$$);
select pg_temp.sudo($$insert into app.deployment_env (env_code) values ('STAGING')$$);
select pg_temp.sudo($$select set_config('hmt.demo_sales', '', true)$$);
-- Cờ tắt, khoá đủ: người không quyền vẫn bị chặn (khoá một mình không đủ để mở quyền).
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.first_opp(), pg_temp.lines_for(pg_temp.first_opp()))$$), 'HMT_KHONG_CO_QUYEN', 'Ràng buộc 2: khoá đủ nhưng không có cờ thì quyền giữ nguyên, vẫn bị chặn');

-- Ràng buộc 3(c): Kế toán, Giáo viên, Trợ giảng (không có quyền tạo báo giá, đơn, phiếu thu) vẫn tạo được bộ.
select pg_temp.sudo($$update app.setting_def set value = '5' where key = 'demo_data_max_per_user'$$);
select pg_temp.sudo($$update app.setting_def set value = '20' where key = 'demo_data_max_per_branch'$$);
select pg_temp.claims(pg_temp.uid('ketoan'), 'aal2');
select is(pg_temp.err($$insert into s2 select app.create_demo_data_set()$$), null, 'Ràng buộc 3c: Kế toán tạo được bộ có báo giá, đơn, phiếu thu');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$insert into s2 select app.create_demo_data_set()$$), null, 'Ràng buộc 3c: Giáo viên tạo được bộ');
select pg_temp.claims(pg_temp.uid('tg5'), 'aal1');
select is(pg_temp.err($$insert into s2 select app.create_demo_data_set()$$), null, 'Ràng buộc 3c: Trợ giảng tạo được bộ');
select is(pg_temp.n_quotes(), 24::bigint, 'Đúng: bốn bộ, mỗi bộ 6 báo giá');
select is(coalesce(current_setting('hmt.demo_sales', true), ''), '', 'Ràng buộc 3d: sau mọi lần tạo bộ, cờ không còn');
-- Sau khi tạo bộ xong, người đó vẫn không có quyền gọi thẳng (cờ không rò sang thao tác kế).
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.first_opp(), pg_temp.lines_for(pg_temp.first_opp()))$$), 'HMT_KHONG_CO_QUYEN', 'Ràng buộc 3d: ngay sau khi tạo bộ, Trợ giảng gọi thẳng báo giá vẫn bị chặn');

-- Luật khoá: công tắc tắt thì không tạo bộ, không phát sinh báo giá.
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'demo_data_enabled'$$);
select is(pg_temp.err($$select app.create_demo_data_set()$$), 'HMT_DEMO_TAT', 'Luật khoá: công tắc tắt thì không tạo bộ');
select is(pg_temp.n_quotes(), 24::bigint, 'Luật khoá: không phát sinh báo giá mẫu khi công tắc tắt');

-- Hàm con không cấp cho giao diện.
select is(pg_temp.err(format($$select app.demo_make_sales(%L, (select id from app.branch where code = 'CS5'))$$, (select id from s1))), '42501', 'Luật: hàm con demo_make_sales không cấp cho người dùng');
select is(pg_temp.err($$select app.demo_data_is_allowed()$$), '42501', 'Luật: demo_data_is_allowed không cấp cho người dùng');

select * from finish();
rollback;
