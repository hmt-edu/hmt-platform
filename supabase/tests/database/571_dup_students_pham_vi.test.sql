-- Rà security definer: app.duplicate_students_of_parent chỉ nêu học sinh trong phạm vi Xem (migration 571, cùng loại E67).
begin;
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('sales1'), ('admin');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- Một phụ huynh CS2 có hai em trùng tên, năm sinh (nhập nhầm hai lần) ở CS2.
insert into app.parent (code, full_name, phone, branch_id)
values ('PHDUP71', 'Phụ huynh Trùng', '0991710001', (select id from app.branch where code = 'CS2'));
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = 'PHDUP71'), 'Em Trùng Bảy Một', 2012, (select id from app.branch where code = 'CS2')
  from (values ('HSDUP711'), ('HSDUP712')) as c (code);
create temp table ids as select (select id from app.parent where code = 'PHDUP71') as p;
grant select on ids to authenticated;

select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is((select count(*)::int from app.duplicate_students_of_parent((select p from ids))), 1,
          'Phạm vi Xem toàn hệ thống (R-CRM-26): Sale thấy cặp em trùng của cơ sở khác');
reset role;

-- Thu hẹp quyền Xem học sinh của SALES về CO_SO (cơ sở CS1): em ở CS2 nằm ngoài phạm vi.
update app.permission set scope_code = 'CO_SO' where role_code = 'SALES' and module_code = 'STUDENT' and action_code = 'XEM' and is_active;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is((select count(*)::int from app.duplicate_students_of_parent((select p from ids))), 0,
          'Ngoài phạm vi Xem (CO_SO): không nêu tên, mã học sinh trùng của cơ sở khác');
reset role;

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is((select student_codes::text from app.duplicate_students_of_parent((select p from ids))), '{HSDUP711,HSDUP712}',
          'Admin (toàn hệ thống) vẫn thấy đủ hai mã học sinh trùng');
reset role;

select * from finish();
rollback;
