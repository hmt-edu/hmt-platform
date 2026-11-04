-- Ma trận quyền phiên bản 6 (QĐ-Đ204): Sale và CSKH có Huỷ đơn hàng ở cơ sở mình; đúng hai ô đổi; các quyền khác của đơn giữ như phiên bản 5.
-- Hành vi huỷ đơn (Sale chỉ huỷ đơn Nháp do mình lập; không huỷ đơn người khác hay đơn đã trình) kiểm ở bài của hàm huỷ đơn (P5a-DB1b-1).
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
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('sales1'), ('cskh1'), ('ke');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('sales1', 'SALES'), ('cskh1', 'CSKH'), ('ke', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;

-- ================= Phiên bản và ô đổi =================
select is((select max(version_no) from app.permission_version), 7, 'Ma trận hiện hành là phiên bản 7 (phiên bản 6 của Đ204 vẫn có; T1 thêm vai trò Marketing)');
select is((select changed_count from app.permission_version where version_no = 6), 2, 'Phiên bản 6 đổi đúng 2 ô');
select ok((select note from app.permission_version where version_no = 6) like 'Đ204:%', 'Phiên bản 6 có ghi chú Đ204');
select is((select count(*)::int from app.permission_change c join app.permission_version v on v.id = c.version_id where v.version_no = 6
            and c.module_code = 'SALES_ORDER' and c.action_code = 'HUY'), 2, 'Cả hai ô đổi đều là Huỷ đơn hàng');

-- ================= Quyền hiện hành =================
select is((select string_agg(role_code, ',' order by role_code) from app.permission where is_active and module_code = 'SALES_ORDER' and action_code = 'HUY'),
          'ADMIN,BRANCH_MANAGER,CSKH,MARKETER,MARKETING,MARKETING_MANAGER,SALES', 'Huỷ đơn hàng: Admin, Trưởng cơ sở, CSKH, Sale và ba vai trò Marketing (quyền như Sale); Kế toán không');
select is((select scope_code from app.permission where is_active and module_code = 'SALES_ORDER' and action_code = 'HUY' and role_code = 'SALES'), 'CO_SO', 'Sale huỷ đơn: phạm vi cơ sở');
select is((select scope_code from app.permission where is_active and module_code = 'SALES_ORDER' and action_code = 'HUY' and role_code = 'CSKH'), 'CO_SO', 'CSKH huỷ đơn: phạm vi cơ sở');
-- Duyệt, Xuất và các quyền khác của đơn giữ như phiên bản 5.
select is((select string_agg(role_code, ',' order by role_code) from app.permission where is_active and module_code = 'SALES_ORDER' and action_code = 'DUYET'),
          'ADMIN,BRANCH_MANAGER', 'Duyệt đơn hàng không đổi: Admin, Trưởng cơ sở');
select is((select string_agg(role_code, ',' order by role_code) from app.permission where is_active and module_code = 'SALES_ORDER' and action_code = 'XUAT'),
          'ACCOUNTANT,ADMIN,BRANCH_MANAGER', 'Xuất đơn hàng không đổi (Đ105): Kế toán, Admin, Trưởng cơ sở');
select is((select string_agg(role_code, ',' order by role_code) from app.permission where is_active and module_code = 'SALES_ORDER' and action_code = 'TAO'),
          'ADMIN,BRANCH_MANAGER,CSKH,MARKETER,MARKETING,MARKETING_MANAGER,SALES', 'Tạo đơn hàng: như phiên bản 5, thêm ba vai trò Marketing (quyền như Sale)');
-- Mỗi vai trò thử qua hàm quyền (phạm vi cơ sở).
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(app.has_permission('SALES_ORDER', 'HUY'), true, 'Sale có quyền Huỷ đơn hàng');
select is(app.has_permission('SALES_ORDER', 'DUYET'), false, 'Sale vẫn không có quyền Duyệt đơn hàng');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.has_permission('SALES_ORDER', 'HUY'), true, 'CSKH có quyền Huỷ đơn hàng');
select is(app.has_permission('SALES_ORDER', 'DUYET'), false, 'CSKH vẫn không có quyền Duyệt đơn hàng');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(app.has_permission('SALES_ORDER', 'HUY'), false, 'Kế toán không có quyền Huỷ đơn hàng');

select * from finish();
rollback;
