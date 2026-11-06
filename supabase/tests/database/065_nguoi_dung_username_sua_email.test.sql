-- Người dùng đợt 1 (migration 074; R-V2-08 tên đăng nhập, luật Sửa email Q-M4): cột username, tạo tài khoản, đặt một lần, Sửa email.
-- Mỗi luật có ca đúng và ca bị chặn. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('sales1'), ('nv1'), ('hs1'), ('moi1'), ('moi2');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;
insert into auth.users (id, aud, role, email, encrypted_password) select id, 'authenticated', 'authenticated', key || '@u74.hoamatoan.invalid', 'băm-giả' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password, username, student_code)
select id, 'Giả ' || key, key || '@u74.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false,
       case key when 'nv1' then 'nv.mot' else null end, case key when 'hs1' then 'HS9974' else null end
  from u where key in ('admin', 'sales1', 'nv1', 'hs1');
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('nv1', 'SALES'), ('hs1', 'STUDENT')) v(k, role) on v.k = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- ============ Quyền: chỉ Admin ============
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.check_account_fields('abc', 'x@y.vn')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không kiểm tên đăng nhập, email');
select is(pg_temp.err($$select app.admin_change_email_apply(pg_temp.uid('nv1'), 'moi@u74.example')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không Sửa email');
select is(pg_temp.err($$select app.admin_set_username(pg_temp.uid('sales1'), 'ban.sale')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không đặt tên đăng nhập');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- ============ Tạo tài khoản với tên đăng nhập ============
select is(pg_temp.err($$select app.admin_create_account(pg_temp.uid('moi1'), 'Giả Mới Một', 'moi1@u74.hoamatoan.invalid', 'CS1', array['SALES'], null, 'NV', null, 'Moi.Mot')$$), null, 'Đúng: tạo có tên đăng nhập');
select is((select username from app.user_account where id = pg_temp.uid('moi1')), 'moi.mot', 'Tên đăng nhập lưu viết thường');
select is(pg_temp.err($$select app.admin_create_account(pg_temp.uid('moi2'), 'Giả Mới Hai', 'moi2@u74.hoamatoan.invalid', 'CS1', array['SALES'], null, 'NV', null, 'MOI.MOT')$$), 'HMT_TEN_DANG_NHAP_TRUNG', 'Chặn: tên đăng nhập trùng (không phân biệt hoa thường)');
select is(pg_temp.err($$select app.admin_create_account(pg_temp.uid('moi2'), 'Giả Mới Hai', 'moi2@u74.hoamatoan.invalid', 'CS1', array['SALES'], null, 'NV', null, '1sai dau')$$), 'HMT_TEN_DANG_NHAP_SAI', 'Chặn: tên đăng nhập sai dạng');
select is(pg_temp.err($$select app.admin_create_account(pg_temp.uid('moi2'), 'Giả Mới Hai', 'nv1@u74.hoamatoan.invalid', 'CS1', array['SALES'], null, 'NV', null, 'moi.hai')$$), 'HMT_EMAIL_TRUNG', 'Chặn: email trùng tài khoản khác');
select is(pg_temp.err($$select app.admin_create_account(pg_temp.uid('moi2'), 'Giả Mới Hai', 'khong-phai-email', 'CS1', array['SALES'], null, 'NV', null, 'moi.hai')$$), 'HMT_EMAIL_SAI', 'Chặn: email sai dạng');

-- ============ Kiểm ngay ở ô ============
select is(app.check_account_fields('moi.mot', 'nv1@u74.hoamatoan.invalid'), jsonb_build_object('username', 'HMT_TEN_DANG_NHAP_TRUNG', 'email', 'HMT_EMAIL_TRUNG'), 'Báo trùng cả hai ô');
select is(app.check_account_fields('con.trong', 'trong@u74.example'), jsonb_build_object('username', null, 'email', null), 'Còn trống thì không báo lỗi');

-- ============ Tên đăng nhập không đổi; đặt một lần ============
select is(pg_temp.err($$update app.user_account set username = 'doi.ten' where id = pg_temp.uid('nv1')$$), 'HMT_TEN_DANG_NHAP_KHONG_DOI', 'Chặn: đổi tên đăng nhập đã có');
select is(pg_temp.err($$select app.admin_set_username(pg_temp.uid('nv1'), 'doi.ten')$$), 'HMT_TEN_DANG_NHAP_KHONG_DOI', 'Chặn: đặt lại tên đăng nhập cho tài khoản đã có');
select is(pg_temp.err($$update app.user_account set login_name = 'tay@u74.example' where id = pg_temp.uid('nv1')$$), 'HMT_MA_KHONG_DOI_DUOC', 'Chặn: sửa tay email đăng nhập ngoài hàm Sửa email');
select is(pg_temp.err($$select app.admin_set_username(pg_temp.uid('admin'), 'quan.tri.74')$$), null, 'Đúng: đặt tên đăng nhập một lần cho tài khoản chưa có');
select is((select username from app.user_account where id = pg_temp.uid('admin')), 'quan.tri.74', 'Đã lưu tên đăng nhập của Admin');
select is(pg_temp.err($$select app.admin_set_username(pg_temp.uid('hs1'), 'hoc.sinh.74')$$), 'HMT_KHONG_TIM_THAY', 'Chặn: tài khoản học sinh không có tên đăng nhập');

-- ============ Sửa email ============
select is(pg_temp.err($$select app.admin_change_email_apply(pg_temp.uid('admin'), 'tu.doi@u74.example')$$), 'HMT_KHONG_TU_DOI_EMAIL', 'Chặn: Admin tự đổi email của mình');
select is(pg_temp.err($$select app.admin_change_email_apply(pg_temp.uid('hs1'), 'hs@u74.example')$$), 'HMT_KHONG_TIM_THAY', 'Chặn: đổi email tài khoản học sinh');
select is(pg_temp.err($$select app.admin_change_email_apply(pg_temp.uid('nv1'), 'moi1@u74.hoamatoan.invalid')$$), 'HMT_EMAIL_TRUNG', 'Chặn: email mới trùng tài khoản khác');
select is(pg_temp.err($$select app.admin_change_email_apply(pg_temp.uid('nv1'), 'nv1@u74.hoamatoan.invalid')$$), 'HMT_KHONG_THAY_DOI', 'Chặn: email mới trùng email hiện tại');
select is(pg_temp.err($$select app.admin_change_email_apply(pg_temp.uid('nv1'), 'sai dang')$$), 'HMT_EMAIL_SAI', 'Chặn: email mới sai dạng');
insert into auth.sessions (id, user_id) values (gen_random_uuid(), pg_temp.uid('nv1'));
create temp table before_v as select session_version v from app.user_account where id = pg_temp.uid('nv1');
select is(pg_temp.err($$select app.admin_change_email_apply(pg_temp.uid('nv1'), 'Nv1.Moi@u74.example')$$), null, 'Đúng: Admin đổi email người khác');
select is((select login_name from app.user_account where id = pg_temp.uid('nv1')), 'nv1.moi@u74.example', 'Email mới lưu viết thường');
select is((select username from app.user_account where id = pg_temp.uid('nv1')), 'nv.mot', 'Tên đăng nhập giữ nguyên sau khi đổi email');
select is((select count(*)::int from auth.sessions where user_id = pg_temp.uid('nv1')), 0, 'Thu hồi mọi phiên cũ');
select is((select session_version - (select v from before_v) from app.user_account where id = pg_temp.uid('nv1')), 1, 'Token cũ mất tác dụng (số phiên bản tăng)');
select ok(exists (select from app.audit_log where action = 'U' and record_id = pg_temp.uid('nv1')
                    and changes::text like '%login_name%'), 'Nhật ký ghi thay đổi email');

select is(app.get_account_form_defaults() ->> 'email_domain', lower(app.get_setting('import_user_email_domain')), 'Form Tạo lấy tên miền email từ tham số');
select is(app.get_user(pg_temp.uid('nv1')) ->> 'username', 'nv.mot', 'Bản ghi người dùng có tên đăng nhập');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.get_account_form_defaults()$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không đọc mặc định form tạo');

select * from finish();
rollback;
