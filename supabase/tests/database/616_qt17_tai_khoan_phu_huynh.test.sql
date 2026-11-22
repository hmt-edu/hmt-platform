-- QT-17 Tài khoản phụ huynh: app.list_parent_accounts, app.admin_check_parent_account, mã PH ở tài khoản (migration 616).
-- Luật: chỉ Admin (đã xác thực hai bước); tình trạng CHUA_CAP, HOAT_DONG, BI_KHOA; lọc theo tên, mã HS, tên phụ huynh, cơ sở, tình trạng;
-- phân trang ở máy chủ; chỉ cấp tài khoản cho học sinh có thật và chưa có tài khoản.
begin;
-- Bài này kiểm luật «Admin phải qua hai bước»; luật chỉ áp khi mfa_required_enabled bật (mặc định tắt), nên bật ở đây.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1'), ('ph1'), ('ph2');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, parent_code, is_locked, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = 'CS1'),
       case u.key when 'ph1' then 'PH990001' when 'ph2' then 'PH990002' end,
       u.key = 'ph2', false
  from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('ph1', 'PARENT'), ('ph2', 'PARENT')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- ---------- Phụ huynh giả: ba người, hai có tài khoản (đang dùng, bị khoá), một chưa cấp; PH990001 có hai con ----------
insert into app.parent (code, full_name, phone, branch_id)
select c.code, c.name, c.phone, (select id from app.branch where code = 'CS1')
  from (values ('PH990001', 'Phụ huynh Mẫu Qtmười Bảy Một', '0991700001'), ('PH990002', 'Phụ huynh Mẫu Qtmười Bảy Hai', '0991700002'),
               ('PH990003', 'Phụ huynh Mẫu Qtmười Bảy Ba', '0991700003')) as c (code, name, phone);
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = 'PH990001'), c.name, 2012, (select id from app.branch where code = 'CS1')
  from (values ('HS991701', 'Em Qtmười Bảy Một'), ('HS991702', 'Em Qtmười Bảy Hai')) as c (code, name);

-- ===== Luật: chỉ Admin xem được =====
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.list_parent_accounts('{}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Luật chỉ Admin: nhân viên Sale xem danh sách tài khoản phụ huynh bị chặn');
select is(pg_temp.err($$select app.admin_check_parent_account('PH990003')$$) is not null, true, 'Luật chỉ Admin: nhân viên Sale kiểm cấp tài khoản phụ huynh bị chặn');
reset role;
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.list_parent_accounts('{}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Admin chưa qua hai bước (aal1) bị chặn');
reset role;

-- ===== Admin đã qua hai bước =====
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is((app.list_parent_accounts('{"q":"Qtmười Bảy"}'::jsonb) ->> 'total')::int, 3, 'Admin: lọc theo tên thấy ba phụ huynh giả');
select is((select r ->> 'state' from jsonb_array_elements(app.list_parent_accounts('{"q":"PH990001"}'::jsonb) -> 'rows') r), 'HOAT_DONG', 'Tình trạng: có tài khoản, không khoá = Đang dùng');
select is((select r ->> 'state' from jsonb_array_elements(app.list_parent_accounts('{"q":"PH990002"}'::jsonb) -> 'rows') r), 'BI_KHOA', 'Tình trạng: tài khoản bị khoá = Đã khoá');
select is((select r ->> 'state' from jsonb_array_elements(app.list_parent_accounts('{"q":"PH990003"}'::jsonb) -> 'rows') r), 'CHUA_CAP', 'Tình trạng: chưa có tài khoản = Chưa cấp');
select is((select (r ->> 'children_count')::int from jsonb_array_elements(app.list_parent_accounts('{"q":"PH990001"}'::jsonb) -> 'rows') r), 2, 'Số con: đếm đúng hai em của PH990001');
select is((app.list_parent_accounts('{"q":"Qtmười Bảy","state":"CHUA_CAP"}'::jsonb) ->> 'total')::int, 1, 'Lọc theo tình trạng Chưa cấp: một phụ huynh');
select is((select count(*)::int from jsonb_array_elements(app.list_parent_accounts('{"q":"Qtmười Bảy"}'::jsonb, 2, 0) -> 'rows')), 2, 'Phân trang ở máy chủ: trang 2 dòng');
select is(app.admin_check_parent_account('PH990003') ->> 'branch_code', 'CS1', 'Kiểm cấp: phụ huynh chưa có tài khoản được phép, trả mã cơ sở');
select is(pg_temp.err($$select app.admin_check_parent_account('PH990001')$$), 'HMT_TAI_KHOAN_DA_CO', 'Luật: phụ huynh đã có tài khoản không cấp lần hai');
select is(pg_temp.err($$select app.admin_check_parent_account('PH000000')$$), 'HMT_KHONG_TIM_THAY', 'Luật: mã PH không có thật bị chặn');
reset role;

-- ===== Luật: mã PH và vai trò Phụ huynh đi cùng nhau =====
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is(pg_temp.err(format($$select app.admin_create_account(%L, 'X', 'ph990003@phuhuynh.hoamatoan.edu.vn', 'CS1', array['PARENT'])$$, gen_random_uuid())), 'HMT_THIEU_MA_PH', 'Luật: vai trò Phụ huynh thiếu mã PH bị chặn');
select is(pg_temp.err(format($$select app.admin_create_account(%L, 'X', 'x@example.com', 'CS1', array['SALES'], null, null, null, null, 'PH990003')$$, gen_random_uuid())), 'HMT_THIEU_MA_PH', 'Luật: mã PH gắn vai trò không phải Phụ huynh bị chặn');
select is(pg_temp.err(format($$select app.admin_create_account(%L, 'X', 'ph990003@phuhuynh.hoamatoan.edu.vn', 'CS1', array['PARENT','SALES'], null, null, null, null, 'PH990003')$$, gen_random_uuid())), 'HMT_THIEU_MA_PH', 'Luật: Phụ huynh không gộp với vai trò khác');
reset role;
-- Tạo đúng: cần dòng auth.users thật (khoá ngoại).
insert into auth.users (id, aud, role, email, encrypted_password) values ('00000000-0000-0000-0000-000000001703', 'authenticated', 'authenticated', 'ph990003@phuhuynh.hoamatoan.edu.vn', 'ma-bam-gia');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select lives_ok($$select app.admin_create_account('00000000-0000-0000-0000-000000001703', 'Phụ huynh Mẫu Qtmười Bảy Ba', 'ph990003@phuhuynh.hoamatoan.edu.vn', 'CS1', array['PARENT'], null, null, null, null, 'PH990003')$$, 'Admin cấp tài khoản phụ huynh đúng: thành công');
select is((select r ->> 'state' from jsonb_array_elements(app.list_parent_accounts('{"q":"PH990003"}'::jsonb) -> 'rows') r), 'HOAT_DONG', 'Sau khi cấp: Đang dùng');
reset role;
select is(pg_temp.err($$update app.user_account set parent_code = 'PH990009' where parent_code = 'PH990003'$$), 'HMT_MA_KHONG_DOI_DUOC', 'Luật: không đổi mã phụ huynh đã cấp');

-- ===== Cổng và nhân viên =====
select pg_temp.claims(pg_temp.uid('ph1'), 'aal1');
select is(current_setting('request.jwt.claims')::jsonb -> 'hmt_portals', '["ph"]'::jsonb, 'Token phụ huynh có cổng ph, không có cổng nào khác');
select is((select app.current_user_is_staff()), false, 'Phụ huynh không được coi là nhân viên (hàm nhận nhân viên đã loại mã PH)');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'app' and p.prosrc ~ '\mstudent_code is null' and p.prosrc !~ '\mstudent_code is null and (\w+\.)?parent_code is null'), 0,
          'Mọi hàm app.* nhận nhân viên bằng «student_code is null» đã kèm «parent_code is null» (không sót)');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is((select count(*)::int from jsonb_array_elements(app.list_users('{}'::jsonb, 'name_asc', 100, 0) -> 'rows') r where r ->> 'display_name' like 'Giả ph%'), 0,
          'Danh sách Người dùng (nhân viên) không lẫn tài khoản phụ huynh');
reset role;

select * from finish();
rollback;
