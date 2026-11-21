-- CH-04 quà tặng «Áp dụng cho» (migration 602): app.gift_policy.applies_to, app.save_gift_policy, app.list_applicable_gift_policies. Luật CH-04 (như chiết khấu), R-TIEN-30. Dữ liệu giả.
begin;
-- D41 (migration 472): bài này kiểm luật «Admin, Kế toán phải qua hai bước»; luật chỉ áp khi tham số mfa_required_enabled bật (mặc định tắt), nên bật tham số ở đây.
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
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
insert into u (key) values ('admin'), ('sales5'), ('gv5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@qt.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@qt.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' when key = 'gv5' then 'TEACHER' else 'SALES' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

create function pg_temp.pkg(p_code text) returns uuid language sql stable security definer as $$ select id from app.sales_package where code = p_code $$;
create function pg_temp.gpol(p_code text) returns uuid language sql stable security definer as $$ select id from app.gift_policy where code = p_code $$;
create function pg_temp.applies(p_code text) returns text language sql stable security definer as $$ select array_to_string(applies_to, ',') from app.gift_policy where code = p_code $$;
create function pg_temp.lead_data(p_phone text) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Quà Thử', 'parent_phone', p_phone, 'student_name', 'Em Quà', 'student_birth_year', 2012,
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS', 'channel_code', 'FACEBOOK_ADS_LEAD_FORM') $$;
create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as
  $$ select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
grant execute on all functions in schema pg_temp to public;

set local role authenticated;

-- ================= Tạo, sửa chính sách quà tặng =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.save_gift_policy(null, jsonb_build_object('code', 'AD_MAC_DINH', 'name', 'Quà mặc định', 'gift_package_id', pg_temp.pkg('TL-MATOAN'), 'max_quantity', 1, 'valid_from', '2026-09-01'));
select is(pg_temp.applies('AD_MAC_DINH'), 'BAO_GIA,DON,PHIEU_THU', 'Tạo không nói «Áp dụng cho»: mặc định cả ba (dữ liệu cũ không đổi)');
select app.save_gift_policy(null, jsonb_build_object('code', 'AD_CHI_DON', 'name', 'Quà chỉ đơn', 'gift_package_id', pg_temp.pkg('TL-MATOAN'), 'max_quantity', 1, 'valid_from', '2026-09-01', 'applies_to', jsonb_build_array('DON')));
select is(pg_temp.applies('AD_CHI_DON'), 'DON', 'Tạo với «Áp dụng cho» chỉ Đơn: lưu đúng');
select app.save_gift_policy(null, jsonb_build_object('code', 'AD_CHI_THU', 'name', 'Quà chỉ phiếu thu', 'gift_package_id', pg_temp.pkg('TL-MATOAN'), 'max_quantity', 1, 'valid_from', '2026-09-01', 'applies_to', jsonb_build_array('PHIEU_THU')));
select is(pg_temp.err($$select app.save_gift_policy(null, jsonb_build_object('code', 'AD_RONG', 'name', 'x', 'gift_package_id', pg_temp.pkg('TL-MATOAN'), 'max_quantity', 1, 'valid_from', '2026-09-01', 'applies_to', '[]'::jsonb))$$), 'HMT_AP_DUNG_CHO_SAI', 'Chặn: «Áp dụng cho» để trống');
select is(pg_temp.err($$select app.save_gift_policy(null, jsonb_build_object('code', 'AD_LA', 'name', 'x', 'gift_package_id', pg_temp.pkg('TL-MATOAN'), 'max_quantity', 1, 'valid_from', '2026-09-01', 'applies_to', jsonb_build_array('KHAC')))$$), 'HMT_AP_DUNG_CHO_SAI', 'Chặn: «Áp dụng cho» có giá trị lạ');
select app.save_gift_policy(pg_temp.gpol('AD_CHI_DON'), '{"applies_to": ["BAO_GIA", "DON"]}');
select is(pg_temp.applies('AD_CHI_DON'), 'BAO_GIA,DON', 'Sửa «Áp dụng cho»: ghi đè đúng');
select app.save_gift_policy(pg_temp.gpol('AD_CHI_DON'), '{"name": "Quà chỉ đơn đổi tên"}');
select is(pg_temp.applies('AD_CHI_DON'), 'BAO_GIA,DON', 'Sửa không nói «Áp dụng cho»: giữ nguyên');
select is(pg_temp.err($$select app.save_gift_policy(pg_temp.gpol('AD_CHI_DON'), '{"applies_to": []}')$$), 'HMT_AP_DUNG_CHO_SAI', 'Chặn: sửa «Áp dụng cho» thành rỗng');

-- ================= Quà mời chọn ở báo giá, đơn =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900602001'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity((select id from app.lead where parent_phone = '0900602001'));
select is((select count(*)::int from jsonb_array_elements(app.list_applicable_gift_policies(pg_temp.oid('0900602001'))) r where r ->> 'code' = 'AD_MAC_DINH'), 1, 'Quà mặc định (cả ba) có trong danh sách mời chọn');
select is((select count(*)::int from jsonb_array_elements(app.list_applicable_gift_policies(pg_temp.oid('0900602001'))) r where r ->> 'code' = 'AD_CHI_DON'), 1, 'Quà áp dụng cho Báo giá, Đơn có trong danh sách mời chọn');
select is((select count(*)::int from jsonb_array_elements(app.list_applicable_gift_policies(pg_temp.oid('0900602001'))) r where r ->> 'code' = 'AD_CHI_THU'), 0, 'Quà chỉ áp dụng cho Phiếu thu KHÔNG có trong danh sách mời chọn ở báo giá, đơn');
select is((select r -> 'applies_to' ->> 0 from jsonb_array_elements(app.list_applicable_gift_policies(pg_temp.oid('0900602001'))) r where r ->> 'code' = 'AD_CHI_DON'), 'BAO_GIA', 'Danh sách mời chọn trả khoá applies_to');

-- ================= Quyền =================
select is(pg_temp.err($$select app.save_gift_policy(null, jsonb_build_object('code', 'AD_SALE', 'name', 'x', 'gift_package_id', pg_temp.pkg('TL-MATOAN'), 'max_quantity', 1, 'valid_from', '2026-09-01', 'applies_to', jsonb_build_array('DON')))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: sale không có quyền Cấu hình bán hàng · Tạo');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$select app.save_gift_policy(pg_temp.gpol('AD_CHI_DON'), '{"applies_to": ["PHIEU_THU"]}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không sửa được «Áp dụng cho»');
reset role;
set local role anon;
select is(pg_temp.err($$select app.save_gift_policy(null, '{}')$$), '42501', 'Chặn: khách chưa đăng nhập không gọi được save_gift_policy');
reset role;

select * from finish();
rollback;
