-- PR 6e: bốn phân hệ quyền mới (Cấu hình bán hàng, Cấu hình đào tạo, Ngày nghỉ lễ, Lịch hẹn) theo bảng quyền anh Trường
-- duyệt 16/10, và luật "ADMIN luôn giữ đủ quyền phân hệ Quản trị".
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
-- Quyền của một vai trò trên bốn phân hệ mới, dạng "PHÂN_HỆ:HÀNH_ĐỘNG:PHẠM_VI", theo thứ tự.
create function pg_temp.perms(p_role text) returns text[] language sql as $$
  select array_agg(module_code || ':' || action_code || ':' || scope_code order by module_code, action_code)
    from app.permission
   where role_code = p_role and is_active
     and module_code in ('CONFIG_SALES', 'CONFIG_TRAINING', 'HOLIDAY', 'APPOINTMENT');
$$;
grant execute on all functions in schema pg_temp to public;

-- Bốn phân hệ có trong danh mục.
select is((select array_agg(code order by sort_order) from app.catalog_item
           where catalog_code = 'PERM_MODULE' and code in ('CONFIG_SALES', 'CONFIG_TRAINING', 'HOLIDAY', 'APPOINTMENT')),
          array['CONFIG_SALES', 'CONFIG_TRAINING', 'HOLIDAY', 'APPOINTMENT'], 'Có bốn phân hệ quyền mới');

-- Bảng SAU theo từng vai trò.
select is(cardinality(pg_temp.perms('ADMIN')), 28, 'ADMIN: đủ 7 hành động trên cả bốn phân hệ mới');
select is((select count(distinct scope_code)::int from app.permission
           where role_code = 'ADMIN' and is_active and module_code in ('CONFIG_SALES', 'CONFIG_TRAINING', 'HOLIDAY', 'APPOINTMENT')),
          1, 'ADMIN: mọi quyền phân hệ mới ở phạm vi toàn hệ thống');
select is(pg_temp.perms('BRANCH_MANAGER'),
          array['APPOINTMENT:DUYET:CO_SO', 'APPOINTMENT:GIAO_VIEC:CO_SO', 'APPOINTMENT:HUY:CO_SO', 'APPOINTMENT:SUA:CO_SO',
                'APPOINTMENT:TAO:CO_SO', 'APPOINTMENT:XEM:CO_SO', 'APPOINTMENT:XUAT:CO_SO',
                'CONFIG_SALES:XEM:TOAN_HE_THONG', 'CONFIG_TRAINING:XEM:TOAN_HE_THONG',
                'HOLIDAY:HUY:CO_SO', 'HOLIDAY:SUA:CO_SO', 'HOLIDAY:TAO:CO_SO', 'HOLIDAY:XEM:CO_SO'],
          'Trưởng cơ sở: xem cấu hình toàn hệ thống; ngày nghỉ lễ xem, tạo, sửa, huỷ cơ sở mình; Lịch hẹn đủ như Cơ hội');
select is(pg_temp.perms('ACCOUNTANT'), array['CONFIG_SALES:XEM:TOAN_HE_THONG'], 'Kế toán: chỉ xem Cấu hình bán hàng');
select is(pg_temp.perms('SALES'),
          array['APPOINTMENT:HUY:CO_SO', 'APPOINTMENT:SUA:CO_SO', 'APPOINTMENT:TAO:CO_SO', 'APPOINTMENT:XEM:CO_SO',
                'CONFIG_SALES:XEM:TOAN_HE_THONG', 'HOLIDAY:XEM:CO_SO'],
          'Tuyển sinh: Lịch hẹn xem, tạo, sửa, huỷ cơ sở mình; xem Cấu hình bán hàng; xem ngày nghỉ lễ cơ sở mình');
select is(pg_temp.perms('CSKH'),
          array['APPOINTMENT:HUY:CO_SO', 'APPOINTMENT:SUA:CO_SO', 'APPOINTMENT:TAO:CO_SO', 'APPOINTMENT:XEM:CO_SO',
                'CONFIG_SALES:XEM:TOAN_HE_THONG', 'CONFIG_TRAINING:XEM:TOAN_HE_THONG', 'HOLIDAY:XEM:CO_SO'],
          'CSKH: Lịch hẹn xem, tạo, sửa, huỷ cơ sở mình; xem cả hai cấu hình; xem ngày nghỉ lễ cơ sở mình');
select is(pg_temp.perms('TEACHER'), array['CONFIG_TRAINING:XEM:TOAN_HE_THONG'], 'Giáo viên: chỉ xem Cấu hình đào tạo');
select is(pg_temp.perms('TA'), array['CONFIG_TRAINING:XEM:TOAN_HE_THONG'], 'Trợ giảng: chỉ xem Cấu hình đào tạo (như giáo viên)');
select is(pg_temp.perms('STUDENT'), null, 'Học sinh: không có quyền nào ở bốn phân hệ mới');
select is(pg_temp.perms('PARENT'), null, 'Phụ huynh: không có quyền nào ở bốn phân hệ mới');
select is((select count(*)::int from app.permission where module_code = 'ADMIN' and role_code <> 'ADMIN' and is_active), 0,
          'Phân hệ Quản trị vẫn chỉ ADMIN');

-- Việc nạp tạo một phiên bản có danh sách ô đổi.
select is((select changed_count from app.permission_version where version_no = 2), 57, 'Phiên bản 2: 57 ô quyền mới');
select is((select count(*)::int from app.permission_change c join app.permission_version v on v.id = c.version_id where v.version_no = 2),
          57, 'Phiên bản 2 liệt kê đủ 57 ô');

-- Luật mới: ADMIN luôn giữ đủ quyền phân hệ Quản trị.
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email)
select id, 'authenticated', 'authenticated', key || '@tach.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@tach.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code) select id, 'ADMIN' from u;

create temp table base as select app.permission_current_version() as v;
grant select on base to authenticated;

set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');

select is(pg_temp.err($$select app.save_permission_matrix((select v from base), jsonb_build_array(
            jsonb_build_object('role', 'ADMIN', 'module', 'ADMIN', 'action', 'SUA', 'scope', null)))$$),
          'HMT_ADMIN_GIU_QUYEN_QUAN_TRI', 'Lưu bỏ quyền Quản trị của ADMIN: bị chặn, báo lỗi có mã');
select is(pg_temp.err($$select app.save_permission_matrix((select v from base), jsonb_build_array(
            jsonb_build_object('role', 'ADMIN', 'module', 'ADMIN', 'action', 'XEM', 'scope', 'CO_SO')))$$),
          'HMT_ADMIN_GIU_QUYEN_QUAN_TRI', 'Lưu thu hẹp phạm vi Quản trị của ADMIN: bị chặn');
select is(pg_temp.err($$select app.save_permission_matrix((select v from base), jsonb_build_array(
            jsonb_build_object('role', 'SALES', 'module', 'HOLIDAY', 'action', 'TAO', 'scope', 'CO_SO'),
            jsonb_build_object('role', 'ADMIN', 'module', 'ADMIN', 'action', 'XUAT', 'scope', null)))$$),
          'HMT_ADMIN_GIU_QUYEN_QUAN_TRI', 'Một ô vi phạm thì cả lần lưu hoàn tác');
select is(app.permission_current_version(), (select v from base), 'Lưu bị chặn thì không tạo phiên bản');
select ok(not exists (select from app.permission where role_code = 'SALES' and module_code = 'HOLIDAY' and action_code = 'TAO'),
          'Ô hợp lệ cùng lần lưu không được áp');
select is((select count(*)::int from app.permission
           where role_code = 'ADMIN' and module_code = 'ADMIN' and is_active and scope_code = 'TOAN_HE_THONG'), 7,
          'ADMIN vẫn đủ 7 hành động Quản trị, toàn hệ thống');
-- Đúng: sửa quyền khác của ADMIN, hoặc giữ nguyên Quản trị, vẫn lưu được.
select is(pg_temp.err($$select app.save_permission_matrix((select v from base), jsonb_build_array(
            jsonb_build_object('role', 'ADMIN', 'module', 'ADMIN', 'action', 'XEM', 'scope', 'TOAN_HE_THONG'),
            jsonb_build_object('role', 'SALES', 'module', 'HOLIDAY', 'action', 'TAO', 'scope', 'CO_SO')))$$),
          null, 'Giữ nguyên Quản trị của ADMIN cùng với sửa ô khác: lưu được');

-- Ngay cả chủ DB (migration, sửa trực tiếp) cũng không bỏ được: luật nằm ở bảng quyền.
reset role;
select set_config('request.jwt.claims', '', true);
select is(pg_temp.err($$update app.permission set is_active = false where role_code = 'ADMIN' and module_code = 'ADMIN' and action_code = 'HUY'$$),
          'HMT_ADMIN_GIU_QUYEN_QUAN_TRI', 'Sửa trực tiếp bảng quyền cũng không bỏ được quyền Quản trị của ADMIN');

select * from finish();
rollback;
