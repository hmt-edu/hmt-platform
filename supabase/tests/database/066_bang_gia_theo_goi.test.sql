-- Đợt 2 (migration 075; R-TIEN-10, 14, 15): bảng giá theo gói, danh sách giá hiệu lực, thêm nhiều giá một lần. Mỗi luật có ca đúng và ca bị chặn.
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
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1'), ('teacher1');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.pkg(p_code text) returns uuid language sql stable security definer as $$ select id from app.sales_package where code = p_code $$;
grant execute on all functions in schema pg_temp to public;
insert into auth.users (id, aud, role, email, encrypted_password) select id, 'authenticated', 'authenticated', key || '@bg.hoamatoan.invalid', 'băm-giả' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select id, 'Giả ' || key, key || '@bg.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('teacher1', 'TEACHER')) v(k, role) on v.k = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.save_sales_package(null, '{"code": "LC-ANH-K05", "name": "Lớp chung Anh 5", "package_type_code": "LC", "subject_code": "ANH", "grade_from_code": "K05"}');
select app.save_sales_package(null, '{"code": "LC-ANH-K06", "name": "Lớp chung Anh 6", "package_type_code": "LC", "subject_code": "ANH", "grade_from_code": "K06"}');
select app.save_sales_package(null, '{"code": "DV-GIA74", "name": "Dịch vụ thử giá", "package_type_code": "DV"}');

-- ============ Chưa có giá, Không bán ============
select is(app.list_package_prices(current_date, '{"q": "LC-ANH-K05"}') -> 'rows' -> 0 -> 'offline' ->> 'state', 'CHUA_CO_GIA', 'R-TIEN-10: chưa có dòng giá là Chưa có giá');
select is(app.list_package_prices(current_date, '{"q": "DV-GIA74"}') -> 'rows' -> 0 -> 'online' ->> 'state', 'KHONG_BAN', 'R-TIEN-15: dịch vụ không có online là Không bán');
select is(app.list_package_prices(current_date, '{"q": "DV-GIA74"}') -> 'rows' -> 0 -> 'offline' ->> 'state', 'CHUA_CO_GIA', 'Dịch vụ chưa có giá offline thì vẫn Chưa có giá');

-- ============ Thêm nhiều giá một lần ============
select is(app.add_package_prices(current_date - 10, jsonb_build_array(
  jsonb_build_object('package_id', pg_temp.pkg('LC-ANH-K05'), 'mode', 'OFF', 'unit_price', 180000),
  jsonb_build_object('package_id', pg_temp.pkg('LC-ANH-K06'), 'mode', 'OFF', 'unit_price', 180000),
  jsonb_build_object('package_id', pg_temp.pkg('LC-ANH-K06'), 'mode', 'ONL', 'unit_price', null))), 3, 'Thêm ba dòng giá một lần');
select is(app.list_package_prices(current_date, '{"q": "LC-ANH-K05"}') -> 'rows' -> 0 -> 'offline' ->> 'price', '180000', 'Giá offline hiệu lực hôm nay');
select is(app.list_package_prices(current_date, '{"q": "LC-ANH-K06"}') -> 'rows' -> 0 -> 'online' ->> 'state', 'KHONG_BAN', 'Dòng giá để trống là Không bán');
select is(app.list_package_prices(current_date, '{"q": "LC-ANH-K05"}') -> 'rows' -> 0 -> 'online' ->> 'state', 'CHUA_CO_GIA', 'Online chưa có dòng giá vẫn Chưa có giá');
select is(app.list_package_prices(current_date - 20, '{"q": "LC-ANH-K05"}') -> 'rows' -> 0 -> 'offline' ->> 'state', 'CHUA_CO_GIA', 'R-TIEN-14: trước ngày hiệu lực thì chưa có giá');
select is(pg_temp.err($$select app.add_package_prices(current_date, jsonb_build_array(
  jsonb_build_object('package_id', pg_temp.pkg('LC-ANH-K05'), 'mode', 'ONL', 'unit_price', 120000),
  jsonb_build_object('package_id', pg_temp.pkg('DV-GIA74'), 'mode', 'ONL', 'unit_price', 100000)))$$), 'HMT_GOI_KHONG_CO_ONLINE', 'R-TIEN-15: dịch vụ không có giá online thì chặn');
select is(app.list_package_prices(current_date, '{"q": "LC-ANH-K05"}') -> 'rows' -> 0 -> 'online' ->> 'state', 'CHUA_CO_GIA', 'Sai một dòng thì hoàn tác cả lần');
select is(pg_temp.err($$select app.add_package_prices(current_date - 10, jsonb_build_array(
  jsonb_build_object('package_id', pg_temp.pkg('LC-ANH-K05'), 'mode', 'OFF', 'unit_price', 190000)))$$), 'HMT_GIA_DA_CO', 'Đã có giá ngày đó thì chặn');
select is(pg_temp.err($$select app.add_package_prices(current_date, '[]')$$), 'HMT_THIEU_THONG_TIN', 'Không có dòng nào thì chặn');

-- ============ Chọn tất cả theo bộ lọc, nhóm theo loại, môn, khối ============
select is(app.package_ids_for_filter('{"type": "LC", "subject": "ANH"}') ->> 'total', '2', 'Chọn tất cả theo bộ lọc: hai gói Anh lớp chung');
select is(app.package_ids_for_filter('{"type": "LC", "subject": "ANH"}') -> 'items' -> 0 ->> 'package_type_code', 'LC', 'Kết quả chọn tất cả kèm loại gói');
select is(jsonb_array_length(app.list_package_prices(current_date, '{"subject": "ANH"}') -> 'rows'), 2, 'Lọc theo môn');
select is(app.list_package_prices(current_date, '{"subject": "ANH"}') -> 'rows' -> 0 ->> 'code', 'LC-ANH-K05', 'Xếp theo khối tăng dần');

-- ============ Quyền ============
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select isnt(pg_temp.err($$select app.list_package_prices(current_date, '{}')$$), 'HMT_KHONG_CO_QUYEN', 'Sale xem được bảng giá');
select is(pg_temp.err($$select app.add_package_prices(current_date, jsonb_build_array(jsonb_build_object('package_id', pg_temp.pkg('LC-ANH-K05'), 'mode', 'OFF', 'unit_price', 1000)))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Sale không thêm giá');
select is(pg_temp.err($$select app.package_ids_for_filter('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Sale không chọn tất cả để thêm giá');
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is(pg_temp.err($$select app.list_package_prices(current_date, '{}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Giáo viên không xem bảng giá');

select * from finish();
rollback;
