-- QT-13 Tài khoản học sinh: app.list_student_accounts, app.admin_check_student_account (migration 565).
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
insert into u (key) values ('admin'), ('sales1'), ('hs1'), ('hs2');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, is_locked, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = 'CS1'),
       case u.key when 'hs1' then 'HS990001' when 'hs2' then 'HS990002' end,
       u.key = 'hs2', false
  from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('hs1', 'STUDENT'), ('hs2', 'STUDENT')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- ---------- Học sinh giả: ba em, hai có tài khoản (một đang dùng, một bị khoá), một chưa cấp ----------
insert into app.parent (code, full_name, phone, branch_id)
values ('PHQT13', 'Phụ huynh Mẫu Qtmười ba', '0991300001', (select id from app.branch where code = 'CS1'));
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = 'PHQT13'), c.name, 2012, (select id from app.branch where code = 'CS1')
  from (values ('HS990001', 'Em Qtmười Một'), ('HS990002', 'Em Qtmười Hai'), ('HS990003', 'Em Qtmười Ba')) as c (code, name);

-- ===== Luật: chỉ Admin xem được =====
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.list_student_accounts('{}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Luật chỉ Admin: nhân viên Sale xem danh sách tài khoản học sinh bị chặn');
select is(pg_temp.err($$select app.admin_check_student_account('HS990003')$$) is not null, true, 'Luật chỉ Admin: nhân viên Sale kiểm cấp tài khoản bị chặn');
reset role;
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.list_student_accounts('{}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Admin chưa qua hai bước (aal1) bị chặn');
reset role;

-- ===== Admin đã qua hai bước =====
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is((app.list_student_accounts('{"q":"HS99000"}'::jsonb) ->> 'total')::int, 3, 'Admin: tìm theo mã HS thấy ba em');
select is((select jsonb_agg(r ->> 'state' order by r ->> 'student_code')::text
             from jsonb_array_elements(app.list_student_accounts('{"q":"HS99000"}'::jsonb) -> 'rows') r),
          '["HOAT_DONG", "BI_KHOA", "CHUA_CAP"]', 'Tình trạng: em một đang dùng, em hai bị khoá, em ba chưa cấp');
select is((app.list_student_accounts('{"q":"HS99000","state":"CHUA_CAP"}'::jsonb) ->> 'total')::int, 1, 'Lọc tình trạng CHUA_CAP: một em');
select is((app.list_student_accounts('{"q":"HS99000","state":"BI_KHOA"}'::jsonb) -> 'rows' -> 0 ->> 'student_code'), 'HS990002', 'Lọc tình trạng BI_KHOA: em hai');
select is((app.list_student_accounts('{"q":"qtmuoi ba"}'::jsonb) ->> 'total')::int, 3, 'Tìm theo tên phụ huynh (không dấu) thấy cả ba em');
select is((app.list_student_accounts('{"q":"HS99000"}'::jsonb, 2, 0) -> 'rows')::jsonb @> '[{"student_code":"HS990001"}]'::jsonb
          and jsonb_array_length(app.list_student_accounts('{"q":"HS99000"}'::jsonb, 2, 0) -> 'rows') = 2, true, 'Phân trang máy chủ: trang đầu hai dòng');
select is(jsonb_array_length(app.list_student_accounts('{"q":"HS99000"}'::jsonb, 2, 2) -> 'rows'), 1, 'Phân trang máy chủ: trang hai còn một dòng');
select is((app.list_student_accounts('{"q":"HS990003"}'::jsonb) -> 'rows' -> 0 ->> 'branch_code'), 'CS1', 'Dòng có mã cơ sở');

-- ===== Cấp tài khoản: học sinh có thật và chưa có tài khoản =====
select is(app.admin_check_student_account('HS990003') ->> 'display_name', 'Em Qtmười Ba', 'Cấp: em chưa có tài khoản, trả đúng tên');
select is(app.admin_check_student_account('HS990003') ->> 'branch_code', 'CS1', 'Cấp: trả đúng mã cơ sở');
select is(pg_temp.err($$select app.admin_check_student_account('HS990001')$$), 'HMT_TAI_KHOAN_DA_CO', 'Luật một học sinh một tài khoản: em đã có tài khoản bị chặn');
select is(pg_temp.err($$select app.admin_check_student_account('HS000000')$$), 'HMT_KHONG_TIM_THAY', 'Mã học sinh không có thật bị chặn');
reset role;

select * from finish();
rollback;
