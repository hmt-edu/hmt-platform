-- Quản trị người dùng (QT-01, QT-02; QĐ-Đ44 đến Đ50): list_users, get_user, export_users, admin_revoke_sessions, admin_reset_mfa.
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò thử đọc, ghi; Admin chưa xác thực hai bước (aal1) bị chặn.
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
-- Lấy câu lỗi tiếng Việt (MESSAGE) của một lệnh.
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
-- Chạy một câu lệnh với quyền chủ DB (dựng dữ liệu thử khi đang đóng vai người dùng).
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Thử Một', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1'), ('teacher1'), ('teacher5'), ('hs'), ('sales5b');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999999' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5'), ('sales5b', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('sales5b', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);


-- ================= Dựng dữ liệu =================
select pg_temp.sudo($$create function pg_temp.test_data(p_extra jsonb default '{}'::jsonb) returns jsonb language sql stable as
  'select jsonb_build_object(''subject_code'', ''TOAN'', ''grade_code'', (select code from app.catalog_item where catalog_code = ''GRADE'' order by sort_order limit 1),
     ''mode_code'', ''OFFLINE'', ''level_code'', ''CO_BAN'', ''scheduled_at'', now() + interval ''3 days'') || p_extra'$$);
select pg_temp.sudo($$grant execute on function pg_temp.test_data(jsonb) to public$$);
select pg_temp.sudo($$create function pg_temp.oid(p_code text) returns uuid language sql stable security definer as 'select id from app.opportunity where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.lid(p_code text) returns uuid language sql stable security definer as 'select id from app.lead where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.lid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.audit_has(p_table text, p_id uuid, p_like text) returns boolean language sql stable security definer as
  'select exists (select from app.audit_log a join app.audited_table t on t.id = a.table_id where t.table_name = p_table and a.record_id = p_id and a.action = ''U'' and a.changes::text like p_like)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.audit_has(text, uuid, text) to public$$);
select pg_temp.sudo($$create function pg_temp.factors(p_user uuid) returns integer language sql stable security definer as 'select count(*)::integer from auth.mfa_factors where user_id = p_user'$$);
select pg_temp.sudo($$grant execute on function pg_temp.factors(uuid) to public$$);
select pg_temp.sudo($$create function pg_temp.sessions(p_user uuid) returns integer language sql stable security definer as 'select count(*)::integer from auth.sessions where user_id = p_user'$$);
select pg_temp.sudo($$grant execute on function pg_temp.sessions(uuid) to public$$);
select pg_temp.sudo($$create function pg_temp.sver(p_user uuid) returns integer language sql stable security definer as 'select session_version from app.user_account where id = p_user'$$);
select pg_temp.sudo($$grant execute on function pg_temp.sver(uuid) to public$$);
select pg_temp.sudo($$create function pg_temp.exports() returns integer language sql stable security definer as 'select coalesce(sum(row_count), 0)::integer from app.export_log where module_code = ''ADMIN'''$$);
select pg_temp.sudo($$grant execute on function pg_temp.exports() to public$$);

-- ================= Dựng dữ liệu (quyền chủ DB) =================
select pg_temp.sudo($$update app.user_account set staff_code = 'NV900001' where id = (select id from u where key = 'sales1')$$);
select pg_temp.sudo($$update app.user_account set staff_code = 'GV900001' where id = (select id from u where key = 'teacher5')$$);
select pg_temp.sudo($$update app.user_account set is_locked = true, lock_reason = 'Nghỉ việc' where id = (select id from u where key = 'sales5b')$$);
select pg_temp.sudo($$insert into app.login_event (login_name, user_id, result)
  select 'sales1@ts.hoamatoan.invalid', (select id from u where key = 'sales1'), case when g % 3 = 0 then 'SAI_MAT_KHAU' else 'THANH_CONG' end from generate_series(1, 12) g$$);
-- Thiết bị hai bước và phiên giả: sales1 (2 thiết bị, 1 phiên), bm1 (1 thiết bị, 1 phiên).
select pg_temp.sudo($$insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret)
  select gen_random_uuid(), (select id from u where key = k), 'Thiết bị ' || n, 'totp', 'verified', now(), now(), 'x'
    from (values ('sales1', 1), ('sales1', 2), ('bm1', 1)) v (k, n)$$);
select pg_temp.sudo($$insert into auth.sessions (id, user_id, created_at, updated_at)
  select gen_random_uuid(), (select id from u where key = k), now(), now() from (values ('sales1'), ('bm1')) v (k)$$);

-- ================= Danh sách (QT-01) =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
select is((app.list_users('{}') ->> 'total')::int, (select count(*)::int from app.user_account where student_code is null), 'Danh sách: Admin thấy mọi tài khoản nhân viên, giáo viên, trợ giảng');
select is((select count(*)::int from jsonb_array_elements(app.list_users('{"q": "Giả hs"}') -> 'rows')), 0, 'Danh sách không có tài khoản học sinh');
select is((app.list_users('{"q": "giả sales1b"}') ->> 'total')::int, 1, 'Tìm theo tên không cần dấu, không phân biệt hoa thường');
select is((app.list_users('{"q": "SALES1@TS.HOAMATOAN"}') ->> 'total')::int, 1, 'Tìm theo email đăng nhập');
select is((app.list_users('{"q": "nv900001"}') ->> 'total')::int, 1, 'Tìm theo mã NV');
select is((select r ->> 'login_name' from jsonb_array_elements(app.list_users('{"role": ["TEACHER"]}') -> 'rows') r where r ->> 'staff_code' = 'GV900001'), 'teacher5@ts.hoamatoan.invalid', 'Lọc theo vai trò (giáo viên)');
select is((select bool_and(r -> 'roles' @> '[{"code": "SALES"}]'::jsonb) from jsonb_array_elements(app.list_users('{"role": ["SALES"]}') -> 'rows') r), true, 'Lọc theo vai trò: mọi dòng đều có vai trò đó');
select is((select count(*)::int from jsonb_array_elements(app.list_users(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5'))) -> 'rows') r where r ->> 'branch_code' <> 'CS5'), 0, 'Lọc theo cơ sở');
select is((select count(*)::int from jsonb_array_elements(app.list_users('{"status": "LOCKED"}') -> 'rows') r where (r ->> 'is_locked')::boolean = false), 0, 'Lọc theo trạng thái: chỉ tài khoản đã khoá');
select ok((select count(*) from jsonb_array_elements(app.list_users('{"status": "LOCKED"}') -> 'rows') r where r ->> 'staff_code' is null and r ->> 'display_name' = 'Giả sales5b') = 1, 'Tài khoản đã khoá hiện trong lọc "Đã khoá"');
select is((select count(*)::int from jsonb_array_elements(app.list_users('{"status": "ACTIVE", "q": "sales5b"}') -> 'rows')), 0, 'Lọc "Đang hoạt động" không có tài khoản đã khoá');
select is((select count(*)::int from jsonb_array_elements(app.list_users('{"kind": "GV"}') -> 'rows') r where r ->> 'staff_code' not like 'GV%'), 0, 'Lọc theo loại (GV): chỉ mã GV');
select is(jsonb_array_length(app.list_users('{}', 'name_asc', 2, 0) -> 'rows'), 2, 'Phân trang ở máy chủ: lấy đúng số dòng');
select ok((app.list_users('{}', 'name_asc', 2, 0) ->> 'total')::int > 2, 'Phân trang: tổng số vẫn là số thật');
select ok(jsonb_array_length(app.list_users('{}', 'name_asc', 500, 0) -> 'rows') <= 100, 'Giới hạn dòng mỗi trang bị cắt về list_page_size_max');
select is((select r ->> 'manager_name' from jsonb_array_elements(app.list_users('{"q": "nv900001"}') -> 'rows') r), 'Giả bm1', 'Danh sách nêu quản lý trực tiếp');
select ok((select (r -> 'roles' -> 0 ->> 'name') <> '' from jsonb_array_elements(app.list_users('{"q": "nv900001"}') -> 'rows') r), 'Vai trò hiện tên tiếng Việt');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.list_users('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Admin chưa xác thực hai bước (aal1) không xem được danh sách');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.list_users('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không xem danh sách người dùng');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.list_users('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không xem danh sách người dùng');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.list_users('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không xem danh sách người dùng');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.list_users('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: học sinh không xem danh sách người dùng');

-- ================= Bản ghi (QT-02) =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(app.get_user(pg_temp.uid('sales1')) ->> 'login_name', 'sales1@ts.hoamatoan.invalid', 'Bản ghi: email đăng nhập');
select is(app.get_user(pg_temp.uid('sales1')) -> 'branch' ->> 'code', 'CS1', 'Bản ghi: cơ sở');
select is(app.get_user(pg_temp.uid('sales1')) -> 'roles' -> 0 ->> 'code', 'SALES', 'Bản ghi: vai trò');
select is(app.get_user(pg_temp.uid('sales1')) -> 'manager' ->> 'name', 'Giả bm1', 'Bản ghi: quản lý trực tiếp');
select is((app.get_user(pg_temp.uid('sales1')) ->> 'mfa_devices')::int, 2, 'Bản ghi: số thiết bị hai bước (chỉ số lượng, không lộ bí mật)');
select is((app.get_user(pg_temp.uid('sales1')) ->> 'mfa_required')::boolean, false, 'Bản ghi: vai trò Tuyển sinh không bắt buộc hai bước');
select is((app.get_user(pg_temp.uid('admin')) ->> 'mfa_required')::boolean, true, 'Bản ghi: vai trò Admin bắt buộc hai bước');
select is((app.get_user(pg_temp.uid('sales5b')) ->> 'is_locked')::boolean, true, 'Bản ghi: tài khoản đã khoá nêu lý do');
select is(app.get_user(pg_temp.uid('sales5b')) ->> 'lock_reason', 'Nghỉ việc', 'Bản ghi: lý do khoá');
select is(jsonb_array_length(app.get_user(pg_temp.uid('sales1')) -> 'recent_logins'), 10, 'Lịch sử đăng nhập: đúng số dòng của tham số user_login_history_rows (10)');
select ok((app.get_user(pg_temp.uid('sales1')) -> 'recent_logins' -> 0 ->> 'at')::timestamptz >= (app.get_user(pg_temp.uid('sales1')) -> 'recent_logins' -> 9 ->> 'at')::timestamptz, 'Lịch sử đăng nhập: mới nhất trước');
select pg_temp.sudo($$update app.setting_def set value = '5' where key = 'user_login_history_rows'$$);
select is(jsonb_array_length(app.get_user(pg_temp.uid('sales1')) -> 'recent_logins'), 5, 'Đổi tham số thì số dòng lịch sử đổi theo');
select is(pg_temp.err($$select app.get_user(pg_temp.uid('hs'))$$), 'HMT_KHONG_TIM_THAY', 'Tài khoản học sinh không có ở màn người dùng');
select is(pg_temp.err($$select app.get_user(gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Chặn: người dùng không có');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.get_user(pg_temp.uid('sales1'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không xem bản ghi người dùng');

-- ================= Xuất (Đ45) =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.export_users('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Đ45: Trưởng cơ sở không xuất được danh sách người dùng');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.export_users('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Đ45: CSKH không xuất được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.export_users('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Đ45: Admin chưa xác thực hai bước không xuất được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.export_users('{}') ->> 'exported')::int, (select count(*)::int from app.user_account where student_code is null), 'Đ45: Admin xuất đủ tài khoản (không gồm học sinh)');
select is((select array_agg(k order by k) from (select distinct jsonb_object_keys(r) k from jsonb_array_elements(app.export_users('{}') -> 'rows') r) x),
          array['branch', 'display_name', 'login_name', 'roles', 'staff_code', 'status'], 'Đ45: đúng sáu cột (mã, tên, email, vai trò, cơ sở, trạng thái); không mật khẩu, không dữ liệu hai bước');
select is((select r ->> 'status' from jsonb_array_elements(app.export_users('{"q": "sales5b"}') -> 'rows') r), 'Đã khoá', 'Xuất: trạng thái là chữ tiếng Việt');
select is((select r ->> 'roles' from jsonb_array_elements(app.export_users('{"q": "nv900001"}') -> 'rows') r), (select name from app.role where code = 'SALES'), 'Xuất: vai trò là tên, không phải mã');
select is((app.export_users('{"kind": "GV"}') ->> 'exported')::int, (app.list_users('{"kind": "GV"}') ->> 'total')::int, 'Xuất theo bộ lọc, khớp danh sách');
select ok(pg_temp.exports() >= (select count(*)::int from app.user_account where student_code is null) + 1, 'Đ45: ghi nhật ký xuất (ai, module, bộ lọc, số dòng)');
select pg_temp.sudo($$update app.setting_def set value = '3' where key = 'export_max_rows'$$);
select is((app.export_users('{}') ->> 'exported')::int, 3, 'Cắt ở export_max_rows');
select is((app.export_users('{}') ->> 'truncated')::boolean, true, 'Vượt export_max_rows thì báo truncated');
select pg_temp.sudo($$update app.setting_def set value = '5000' where key = 'export_max_rows'$$);

-- ================= Thu hồi phiên (Đ49, Đ50) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.admin_revoke_sessions(pg_temp.uid('bm1'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không thu hồi được phiên người khác');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.admin_revoke_sessions(pg_temp.uid('sales1'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không thu hồi được phiên');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.admin_revoke_sessions(pg_temp.uid('sales1'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Admin chưa xác thực hai bước không thu hồi được phiên');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.admin_revoke_sessions(pg_temp.uid('admin'))$$), 'HMT_THAO_TAC_CHINH_MINH', 'Đ50: Admin không thu hồi phiên của chính mình');
select is(pg_temp.err($$select app.admin_revoke_sessions(pg_temp.uid('hs'))$$), 'HMT_KHONG_TIM_THAY', 'Chặn: tài khoản học sinh không có ở thao tác này');
select is(pg_temp.err($$select app.admin_revoke_sessions(gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Chặn: tài khoản không có');
select is(pg_temp.sessions(pg_temp.uid('sales1')), 1, 'Trước khi thu hồi: sales1 có 1 phiên');
select is(pg_temp.err($$select app.admin_revoke_sessions(pg_temp.uid('sales1'))$$), null, 'Admin thu hồi phiên của người khác được');
select is(pg_temp.sessions(pg_temp.uid('sales1')), 0, 'Thu hồi phiên: phiên ở Supabase Auth đã xoá');
select is(pg_temp.sver(pg_temp.uid('sales1')), 1, 'Thu hồi phiên: số phiên bản tăng (token cũ chết)');
select ok(pg_temp.audit_has('app.user_account', pg_temp.uid('sales1'), '%session_version%'), 'Nhật ký thao tác ghi việc thu hồi phiên');
select is(pg_temp.sessions(pg_temp.uid('bm1')), 1, 'Thu hồi phiên của một người không đụng phiên của người khác');
select is(pg_temp.factors(pg_temp.uid('sales1')), 2, 'Thu hồi phiên không xoá thiết bị hai bước');

-- ================= Đặt lại hai bước (Đ49, Đ50) =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.admin_reset_mfa(pg_temp.uid('sales1'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không đặt lại hai bước của người khác');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.admin_reset_mfa(pg_temp.uid('sales1'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không đặt lại hai bước');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.admin_reset_mfa(pg_temp.uid('sales1'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Admin chưa xác thực hai bước không đặt lại được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.admin_reset_mfa(pg_temp.uid('admin'))$$), 'HMT_THAO_TAC_CHINH_MINH', 'Đ50: Admin không đặt lại hai bước của chính mình');
select is(pg_temp.err($$select app.admin_reset_mfa(pg_temp.uid('hs'))$$), 'HMT_KHONG_TIM_THAY', 'Chặn: tài khoản học sinh không có ở thao tác này');
select is(pg_temp.err($$select app.admin_reset_mfa(gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Chặn: tài khoản không có');
select is(pg_temp.factors(pg_temp.uid('sales1')), 2, 'Trước khi đặt lại: sales1 có 2 thiết bị');
select is((app.admin_reset_mfa(pg_temp.uid('sales1')) ->> 'removed')::int, 2, 'Admin đặt lại hai bước: nêu số thiết bị đã xoá');
select is(pg_temp.factors(pg_temp.uid('sales1')), 0, 'Đặt lại hai bước: mọi thiết bị của người đó đã xoá ở Supabase Auth');
select is(pg_temp.factors(pg_temp.uid('bm1')), 1, 'Đặt lại hai bước không đụng thiết bị của người khác');
select is(pg_temp.sver(pg_temp.uid('sales1')), 2, 'Đặt lại hai bước thu hồi phiên (số phiên bản tăng thêm)');
select is((select mfa_reset_at is not null and mfa_reset_by = pg_temp.uid('admin') from app.user_account where id = pg_temp.uid('sales1')), true, 'Ghi ai đặt lại và lúc nào');
select ok(pg_temp.audit_has('app.user_account', pg_temp.uid('sales1'), '%mfa_reset_at%'), 'Nhật ký thao tác ghi việc đặt lại hai bước');
select is((app.get_user(pg_temp.uid('sales1')) ->> 'mfa_devices')::int, 0, 'Bản ghi: số thiết bị về 0 sau khi đặt lại');
select is(app.get_user(pg_temp.uid('sales1')) ->> 'mfa_reset_by', 'Giả admin', 'Bản ghi nêu người đã đặt lại hai bước');
select is((app.admin_reset_mfa(pg_temp.uid('sales1')) ->> 'removed')::int, 0, 'Đặt lại lần nữa khi không còn thiết bị: không lỗi, xoá 0');
-- Người thuộc vai trò bắt buộc hai bước, chưa thiết lập lại thì chưa có mức xác thực hai bước: mọi quyền theo vai trò đó đóng.
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(app.mfa_satisfied(), false, 'Vai trò bắt buộc hai bước ở mức aal1 (chưa thiết lập lại thiết bị) không được qua cổng hai bước');

select * from finish();
rollback;
