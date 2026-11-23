-- QT-11 app.list_audit_log (migration 550): chỉ Admin đọc; lọc theo bảng, loại, khoảng ngày; phân trang. Dữ liệu giả.
begin;
-- D41 (migration 472): bài này kiểm luật «Admin, Kế toán phải qua hai bước»; luật chỉ áp khi tham số mfa_required_enabled bật (mặc định tắt), nên bật tham số ở đây.
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
-- 647 (A-23-27): bắt hai bước chỉ còn Admin; bài này vẫn kiểm luật aal2 cho Kế toán nên dựng lại cờ trong giao dịch của bài (hoàn tác khi kết thúc).
do $$ begin perform set_config('hmt.migration', 'on', true); update app.role set require_mfa = true where code = 'ACCOUNTANT'; perform set_config('hmt.migration', '', true); end $$;
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
insert into u (key) values ('admin'), ('cskh5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@lg.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@lg.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' else 'CSKH' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

-- Dữ liệu giả: ba sự kiện đăng nhập, hai lần xuất file; admin đang bị khoá tạm để thử mở.
insert into app.login_event (login_name, user_id, branch_id, result, at)
select 'ma@lg.hoamatoan.invalid', pg_temp.uid('cskh5'), (select id from app.branch where code = 'CS5'), 'THANH_CONG', now() - interval '3 day'
union all select 'ma@lg.hoamatoan.invalid', pg_temp.uid('cskh5'), (select id from app.branch where code = 'CS5'), 'SAI_MAT_KHAU', now() - interval '1 day'
union all select 'khac@lg.hoamatoan.invalid', null, null, 'KHONG_CO_TAI_KHOAN', now();
insert into app.export_log (user_id, branch_id, module_code, row_count, at)
select pg_temp.uid('admin'), (select id from app.branch where code = 'CS5'), 'ADMIN', 5, now() - interval '2 day'
union all select pg_temp.uid('cskh5'), (select id from app.branch where code = 'CS5'), 'LEAD', 9, now();
update app.user_account set failed_login_count = 5, temp_locked_until = now() + interval '10 minute' where id = pg_temp.uid('cskh5');

set local role authenticated;

-- Luật S03-18, S03-21: CSKH bị chặn ở cả ba hàm.
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.list_login_events()$$), 'HMT_KHONG_CO_QUYEN', 'Nhật ký đăng nhập: CSKH bị chặn (S03-18)');
select is(pg_temp.err($$select app.list_export_log()$$), 'HMT_KHONG_CO_QUYEN', 'Nhật ký xuất file: CSKH bị chặn (S03-21)');
select is(pg_temp.err($$select app.unlock_temp_login(gen_random_uuid())$$), 'HMT_KHONG_CO_QUYEN', 'Mở khoá tạm: CSKH bị chặn');

-- Admin chưa hai bước bị chặn.
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.list_login_events()$$), 'HMT_KHONG_CO_QUYEN', 'Nhật ký đăng nhập: Admin chưa hai bước bị chặn');

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(app.list_login_events('{"q":"ma@lg"}') ->> 'total', '2', 'Đăng nhập: tìm theo tên đăng nhập');
select is(app.list_login_events('{"q":"@lg","result":"SAI_MAT_KHAU"}') ->> 'total', '1', 'Đăng nhập: lọc kết quả sai mật khẩu');
select is(app.list_login_events(jsonb_build_object('q', '@lg', 'from', (now() - interval '2 day')::text)) ->> 'total', '2', 'Đăng nhập: lọc từ ngày');
select is(app.list_login_events('{"q":"@lg"}', 1, 0) -> 'rows' -> 0 ->> 'login_name', 'khac@lg.hoamatoan.invalid', 'Đăng nhập: mới nhất trước');
select is(app.list_login_events('{"q":"ma@lg","result":"SAI_MAT_KHAU"}') -> 'rows' -> 0 ->> 'temp_locked', 'true', 'Đăng nhập: báo đang khoá tạm');
select is(app.list_export_log(jsonb_build_object('user', pg_temp.uid('cskh5'))) ->> 'total', '1', 'Xuất file: lọc theo người');
select is(app.list_export_log('{"module":"ADMIN"}') -> 'rows' -> 0 ->> 'row_count', '5', 'Xuất file: lọc theo phân hệ');
select is(app.list_export_log(jsonb_build_object('user', pg_temp.uid('admin'))) -> 'rows' -> 0 ->> 'user_name', 'Giả admin', 'Xuất file: có tên người xuất');

-- Mở khoá tạm: xoá bộ đếm và mốc khoá; tài khoản lạ bị từ chối.
select is(pg_temp.err($$select app.unlock_temp_login(gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Mở khoá tạm: tài khoản không có bị từ chối');
select app.unlock_temp_login(pg_temp.uid('cskh5'));
select is((select temp_locked_until is null and failed_login_count = 0 from app.user_account where id = pg_temp.uid('cskh5')), true, 'Mở khoá tạm: xoá bộ đếm và mốc khoá');

select * from finish();
rollback;
