-- E31: cờ «phải đổi mật khẩu lần đầu» theo tham số (học sinh mặc định TẮT, nhân viên mặc định BẬT). R-HT-03, S03-02, CHUNG-07.
-- Hai chỗ quyết định cờ: app.current_user_ready (RLS) và claim hmt_must_change_password của token (hook đăng nhập).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.claims(p_user uuid, p_aal text) returns jsonb language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
  return v_result -> 'claims';
end $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('hs'), ('nv');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@e31.hoamatoan.invalid' from u;
-- Cả hai tài khoản còn cờ «phải đổi mật khẩu» (mật khẩu tạm).
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@e31.hoamatoan.invalid', (select id from app.branch where code = 'CS5'),
       case when u.key = 'hs' then 'HS999777' end, true from u;
insert into app.user_role (user_id, role_code)
select u.id, case when u.key = 'hs' then 'STUDENT' else 'TEACHER' end from u;

-- ---------- Giá trị mặc định (anh Trường chốt 19/11) ----------
select is((select value from app.setting_def where key = 'first_password_change_required_student'), 'false', 'Mặc định: học sinh KHÔNG bắt đổi mật khẩu lần đầu');
select is((select value from app.setting_def where key = 'first_password_change_required_staff'), 'true', 'Mặc định: nhân viên VẪN bắt đổi mật khẩu lần đầu (giữ như cũ)');

-- ---------- Học sinh, tham số Tắt: vào thẳng ----------
select is(pg_temp.claims(pg_temp.uid('hs'), 'aal1') -> 'hmt_must_change_password', 'false'::jsonb, 'Học sinh, tham số Tắt: token không đòi đổi mật khẩu');
set local role authenticated;
select is(app.current_user_ready(), true, 'Học sinh, tham số Tắt: đủ điều kiện dùng hệ thống (RLS không chặn), vào thẳng cổng học');
reset role;
select is((select must_change_password from app.user_account where id = pg_temp.uid('hs')), true, 'Cờ trong bảng vẫn giữ (mật khẩu tạm còn), chỉ không áp');

-- ---------- Nhân viên, tham số Bật (mặc định): như cũ ----------
select is(pg_temp.claims(pg_temp.uid('nv'), 'aal1') -> 'hmt_must_change_password', 'true'::jsonb, 'Nhân viên, tham số Bật: token vẫn đòi đổi mật khẩu');
set local role authenticated;
select is(app.current_user_ready(), false, 'Nhân viên, tham số Bật: chưa dùng được hệ thống cho tới khi đổi mật khẩu');
reset role;

-- ---------- Bật tham số học sinh: như nhân viên ----------
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'first_password_change_required_student'$$);
select is(pg_temp.claims(pg_temp.uid('hs'), 'aal1') -> 'hmt_must_change_password', 'true'::jsonb, 'Học sinh, tham số Bật: token đòi đổi mật khẩu như cũ');
set local role authenticated;
select is(app.current_user_ready(), false, 'Học sinh, tham số Bật: bị chặn tới khi đổi mật khẩu');
reset role;

-- ---------- Tắt tham số nhân viên: vào thẳng; học sinh Bật không ảnh hưởng ----------
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'first_password_change_required_staff'$$);
select is(pg_temp.claims(pg_temp.uid('nv'), 'aal1') -> 'hmt_must_change_password', 'false'::jsonb, 'Nhân viên, tham số Tắt: vào thẳng');
select is(pg_temp.claims(pg_temp.uid('hs'), 'aal1') -> 'hmt_must_change_password', 'true'::jsonb, 'Hai tham số độc lập: học sinh vẫn Bật');

-- ---------- Tài khoản đã đổi mật khẩu (cờ tắt): không bao giờ bị chặn, tài khoản khoá vẫn bị khoá ----------
select pg_temp.sudo($$update app.user_account set must_change_password = false where id = (select id from u where key = 'hs')$$);
select is(pg_temp.claims(pg_temp.uid('hs'), 'aal1') -> 'hmt_must_change_password', 'false'::jsonb, 'Đã đổi mật khẩu (cờ tắt): không đòi đổi dù tham số học sinh Bật');
select pg_temp.sudo($$update app.user_account set is_locked = true where id = (select id from u where key = 'hs')$$);
set local role authenticated;
select is(app.current_user_ready(), false, 'Tài khoản bị khoá: vẫn không dùng được (tham số không mở khoá)');
reset role;

select * from finish();
rollback;
