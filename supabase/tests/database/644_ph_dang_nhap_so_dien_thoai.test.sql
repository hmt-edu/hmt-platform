-- Đăng nhập phụ huynh bằng SĐT (migration 644): app.login_parent_code_by_phone. Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('a'), ('b'), ('c');
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@f644.hoamatoan.invalid' from u;
-- Ba hồ sơ phụ huynh: hai hồ sơ cùng SĐT 0900644001 (a tạo trước, b sau), một hồ sơ SĐT riêng.
insert into app.parent (code, full_name, phone, branch_id)
select v.code, 'Phụ huynh giả ' || v.code, v.phone, (select id from app.branch where code = 'CS1')
  from (values ('PH644001', '0900644001'), ('PH644002', '0900644001'), ('PH644003', '0900644003')) v (code, phone);
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password, parent_code, created_at)
select u.id, 'Giả ' || u.key, u.key || '@f644.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false, v.code, now() - v.ago
  from u join (values ('a', 'PH644001', interval '2 days'), ('b', 'PH644002', interval '1 day'), ('c', 'PH644003', interval '1 day')) v (key, code, ago) on v.key = u.key;
insert into app.user_role (user_id, role_code) select id, 'PARENT' from u;

select is(app.login_parent_code_by_phone('0900644003'), 'PH644003', 'Đúng: SĐT riêng ra đúng mã phụ huynh');
select is(app.login_parent_code_by_phone(' 0900644003 '), 'PH644003', 'Đúng: bỏ khoảng trắng hai đầu');
select is(app.login_parent_code_by_phone('0900644001'), 'PH644001', 'Đúng: SĐT trùng nhiều hồ sơ dùng MỘT tài khoản, tài khoản cấp sớm nhất');
select is(app.login_parent_code_by_phone('0911111111'), null, 'Chặn: SĐT chưa có tài khoản thì không trả mã');
update app.user_account set is_locked = true where parent_code = 'PH644001';
select is(app.login_parent_code_by_phone('0900644001'), 'PH644002', 'Đúng: tài khoản bị khoá thì chuyển sang tài khoản còn dùng được cùng SĐT');
update app.user_account set is_locked = true where parent_code = 'PH644003';
select is(app.login_parent_code_by_phone('0900644003'), null, 'Chặn: tài khoản duy nhất bị khoá thì không đăng nhập được');

set local role authenticated;
select throws_ok($$select app.login_parent_code_by_phone('0900644001')$$, '42501', null, 'Chặn: người dùng đã đăng nhập không gọi được hàm tra SĐT (chỉ Edge Function)');
select * from finish();
rollback;
