-- QT-07 app.list_catalog_history (migration 481): chỉ Admin đọc; lịch sử thêm, đổi tên, Ngừng mục của một danh mục (kể cả cấp con); phân trang. Dữ liệu giả.
begin;
-- D41 (migration 472): bài này kiểm luật «Admin, Kế toán phải qua hai bước»; luật chỉ áp khi tham số mfa_required_enabled bật (mặc định tắt), nên bật tham số ở đây.
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

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@al.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@al.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' else 'CSKH' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

set local role authenticated;

-- Luật S03-12: CSKH và Admin chưa hai bước bị chặn.
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.list_catalog_history('ACTIVITY_TYPE')$$), 'HMT_KHONG_CO_QUYEN', 'Lịch sử danh mục: CSKH bị chặn (S03-12)');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.list_catalog_history('ACTIVITY_TYPE')$$), 'HMT_KHONG_CO_QUYEN', 'Lịch sử danh mục: Admin chưa xác thực hai bước bị chặn');

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.list_catalog_history('KHONG_CO_DANH_MUC')$$), 'HMT_KHONG_TIM_THAY', 'Danh mục không có thật: báo không tìm thấy');
-- Dữ liệu khai báo ban đầu đã có dòng tạo mục: so sánh theo số dòng trước và sau, không viết cứng.
create temp table base as select (app.list_catalog_history('ACTIVITY_TYPE') ->> 'total')::int as act, (app.list_catalog_history('SESSION_TYPE') ->> 'total')::int as ses;
grant select on base to authenticated;

-- Admin thêm một mục, đổi tên, rồi Ngừng.
create temp table m as select app.catalog_add_item('ACTIVITY_TYPE', 'LS_THU', 'Mục lịch sử') as id;
grant select on m to authenticated;
select app.catalog_rename_item((select id from m), 'Mục lịch sử đổi tên');
select app.catalog_set_item_active((select id from m), false);

select is((app.list_catalog_history('ACTIVITY_TYPE') ->> 'total')::int, (select act from base) + 3, 'Lịch sử: thêm tạo + đổi tên + Ngừng = 3 dòng');
select is(app.list_catalog_history('ACTIVITY_TYPE', 1, 0) -> 'rows' -> 0 -> 'changes' -> 'is_active' ->> 1, 'false', 'Mới nhất trước: dòng đầu là Ngừng');
select is(app.list_catalog_history('ACTIVITY_TYPE', 1, 1) -> 'rows' -> 0 -> 'changes' -> 'name' ->> 0, 'Mục lịch sử', 'Đổi tên: tên cũ ghi đúng');
select is(app.list_catalog_history('ACTIVITY_TYPE', 1, 2) -> 'rows' -> 0 ->> 'action', 'I', 'Dòng thứ ba từ mới nhất là tạo mục');
select is(app.list_catalog_history('ACTIVITY_TYPE', 1, 0) -> 'rows' -> 0 ->> 'actor_name', 'Giả admin', 'Có tên người sửa');
select is(app.list_catalog_history('ACTIVITY_TYPE', 1, 0) -> 'rows' -> 0 ->> 'item_code', 'LS_THU', 'Có mã mục');
select is(jsonb_array_length(app.list_catalog_history('ACTIVITY_TYPE', 2, 2) -> 'rows'), 2, 'Phân trang: trang hai (2 dòng mỗi trang) có 2 dòng');
select is((app.list_catalog_history('SESSION_TYPE') ->> 'total')::int, (select ses from base), 'Danh mục khác không lẫn dòng của danh mục này');

select * from finish();
rollback;
