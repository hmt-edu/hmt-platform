-- C60 (migration 428): tên người duyệt dự kiến của cấp đang chờ ở phiếu nghiệp vụ: Trưởng cơ sở đúng cơ sở, Kế toán; không có ai thì null; chỉ để hiển thị. Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('bm5'), ('bm1'), ('ke');
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@c60.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@c60.hoamatoan.invalid', (select id from app.branch where code = case when u.key = 'bm1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key like 'bm%' then 'BRANCH_MANAGER' else 'ACCOUNTANT' end from u;
-- Dọn vai Trưởng cơ sở và Kế toán khác để phép thử chỉ thấy người giả.
update app.user_role set is_active = false where role_code in ('BRANCH_MANAGER', 'ACCOUNTANT') and user_id not in (select id from u);

select is(app.ticket_task_next_approver((select id from app.branch where code = 'CS5'), 'QUAN_LY_CO_SO'), 'Giả bm5', 'Cấp quản lý cơ sở: đúng Trưởng cơ sở của cơ sở phiếu');
select is(app.ticket_task_next_approver((select id from app.branch where code = 'CS1'), 'QUAN_LY_CO_SO'), 'Giả bm1', 'Cấp quản lý cơ sở: cơ sở khác ra người khác');
select is(app.ticket_task_next_approver((select id from app.branch where code = 'CS5'), 'KE_TOAN'), 'Giả ke', 'Cấp kế toán: người giữ vai Kế toán');
select is(app.ticket_task_next_approver((select id from app.branch where code = 'CS3'), 'QUAN_LY_CO_SO'), null, 'Cơ sở chưa có Trưởng cơ sở: null (giao diện hiện tên vai)');
update app.user_role set is_active = false where user_id = (select id from u where key = 'bm5');
select is(app.ticket_task_next_approver((select id from app.branch where code = 'CS5'), 'QUAN_LY_CO_SO'), null, 'Trưởng cơ sở ngừng hoạt động không được gợi ý');
select is(app.ticket_task_next_approver((select id from app.branch where code = 'CS5'), 'VAI_LA'), null, 'Vai lạ: null');

select * from finish();
rollback;
