-- Bảo mật DB mức THẤP (migration 667, A-23-36). Luật: soát E1 (đặt lại mật khẩu thu hồi phiên), soát Q5 (quỹ giờ ghi danh chỉ người có quyền xem). Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh'), ('khach'), ('muctieu');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email, encrypted_password) select id, 'authenticated', 'authenticated', key || '@s667.hoamatoan.invalid', 'x' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@s667.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'cskh' then 'CSKH' end from u where u.key in ('admin', 'cskh');
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

-- E1: đặt lại mật khẩu thu hồi phiên (session_version tăng).
create temp table sv (before_v integer);
grant all on sv to public;
insert into sv select session_version from app.user_account where id = (select id from u where key = 'muctieu');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select lives_ok($$select app.admin_mark_password_reset(pg_temp.uid('muctieu'))$$, 'E1: Admin đặt lại mật khẩu được');
reset role;
select is((select session_version from app.user_account where id = (select id from u where key = 'muctieu')), (select before_v + 1 from sv),
  'E1: đặt lại mật khẩu thu hồi phiên cũ (session_version tăng 1)');
select is((select count(*)::int from auth.sessions where user_id = (select id from u where key = 'muctieu')), 0, 'E1: không còn phiên đăng nhập nào của người bị đặt lại');
select is((select must_change_password from app.user_account where id = (select id from u where key = 'muctieu')), true, 'E1: vẫn bật «phải đổi mật khẩu»');
-- Bị chặn: người không phải Admin không đặt lại mật khẩu được.
select pg_temp.claims(pg_temp.uid('cskh'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.admin_mark_password_reset(pg_temp.uid('muctieu'))$$), 'HMT_KHONG_CO_QUYEN', 'E1: CSKH không đặt lại mật khẩu được');
reset role;

-- Q5: quỹ giờ của ghi danh.
-- Đúng: nhân viên xem được (ghi danh không có sổ giờ thì 0).
select pg_temp.claims(pg_temp.uid('cskh'), 'aal1');
set local role authenticated;
select is(app.enrollment_hours_balance(gen_random_uuid()), 0::numeric, 'Q5: nhân viên đọc được quỹ giờ');
reset role;
-- Chặn: người đăng nhập không phải nhân viên và không phải học sinh/phụ huynh của ghi danh.
select pg_temp.claims(pg_temp.uid('khach'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.enrollment_hours_balance(gen_random_uuid())$$), 'HMT_KHONG_CO_QUYEN', 'Q5: người không phải nhân viên, không phải chủ ghi danh bị chặn');
reset role;
-- Đúng: chạy nền, không có người đăng nhập, giữ nguyên hành vi cũ.
select set_config('request.jwt.claims', '', true);
select is(app.enrollment_hours_balance(gen_random_uuid()), 0::numeric, 'Q5: chạy nền không người dùng vẫn đọc được');

select * from finish();
rollback;
