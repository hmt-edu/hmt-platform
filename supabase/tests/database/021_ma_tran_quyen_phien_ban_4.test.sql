-- Ma trận quyền phiên bản 4 (17 ô trên Phụ huynh, Học sinh; R-CRM-26, 27, 29; anh Trường duyệt TRƯỚC / SAU 18/10).
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
-- Chạy một câu lệnh với quyền chủ DB (dựng dữ liệu thử khi đang đóng vai người dùng).
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Thử Một', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1'), ('teacher5'), ('hs');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999999' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

create function pg_temp.perms(p_role text, p_modules text[]) returns text[] language sql as $$
  select array_agg(module_code || ':' || action_code || ':' || scope_code order by module_code, action_code)
    from app.permission where role_code = p_role and is_active and module_code = any (p_modules);
$$;
grant execute on function pg_temp.perms(text, text[]) to public;

-- ================= Phiên bản 4 =================
select is((select changed_count from app.permission_version where version_no = 4), 17, 'Phiên bản 4 đổi đúng 17 ô');
select is((select count(*)::int from app.permission_change c join app.permission_version v on v.id = c.version_id where v.version_no = 4),
          17, 'Phiên bản 4 liệt kê đủ 17 ô');
select is((select note from app.permission_version where version_no = 4),
          'R-CRM-26, 27, 29: hồ sơ phụ huynh, học sinh dùng chung toàn hệ thống, không Tạo tay, chỉ Admin Xuất', 'Phiên bản 4 có ghi chú');
select is((select count(*)::int from app.permission_change c join app.permission_version v on v.id = c.version_id
            where v.version_no = 4 and c.action_code = 'TAO' and c.to_scope is null), 8, 'R-CRM-27: bỏ Tạo 8 ô (4 vai trò × Phụ huynh, Học sinh)');
select is((select count(*)::int from app.permission_change c join app.permission_version v on v.id = c.version_id
            where v.version_no = 4 and c.action_code = 'XUAT' and c.to_scope is null), 2, 'R-CRM-29: bỏ Xuất của Trưởng cơ sở 2 ô');
select is((select count(*)::int from app.permission_change c join app.permission_version v on v.id = c.version_id
            where v.version_no = 4 and c.action_code = 'XEM' and c.to_scope = 'TOAN_HE_THONG'), 7, 'R-CRM-26: Xem toàn hệ thống 7 ô (6 + Kế toán Phụ huynh)');

-- ================= Ma trận sau phiên bản 4 =================
select is(pg_temp.perms('SALES', array['PARENT', 'STUDENT']),
          array['PARENT:DUYET:CO_SO', 'PARENT:SUA:CO_SO', 'PARENT:XEM:TOAN_HE_THONG',
                'STUDENT:DUYET:CO_SO', 'STUDENT:SUA:CO_SO', 'STUDENT:XEM:TOAN_HE_THONG'],
          'Tuyển sinh: không Tạo, Xem toàn hệ thống, Sửa và Duyệt vẫn cơ sở mình');
select is(pg_temp.perms('CSKH', array['PARENT', 'STUDENT']),
          array['PARENT:DUYET:CO_SO', 'PARENT:SUA:CO_SO', 'PARENT:XEM:TOAN_HE_THONG',
                'STUDENT:DUYET:CO_SO', 'STUDENT:SUA:CO_SO', 'STUDENT:XEM:TOAN_HE_THONG'],
          'CSKH: không Tạo, Xem toàn hệ thống, Sửa và Duyệt vẫn cơ sở mình');
select is(pg_temp.perms('BRANCH_MANAGER', array['PARENT', 'STUDENT']),
          array['PARENT:DUYET:CO_SO', 'PARENT:GIAO_VIEC:CO_SO', 'PARENT:HUY:CO_SO', 'PARENT:SUA:CO_SO', 'PARENT:XEM:TOAN_HE_THONG',
                'STUDENT:DUYET:CO_SO', 'STUDENT:GIAO_VIEC:CO_SO', 'STUDENT:HUY:CO_SO', 'STUDENT:SUA:CO_SO', 'STUDENT:XEM:TOAN_HE_THONG'],
          'Trưởng cơ sở: không Tạo, không Xuất, Xem toàn hệ thống');
select is(pg_temp.perms('ADMIN', array['PARENT', 'STUDENT']),
          array['PARENT:DUYET:TOAN_HE_THONG', 'PARENT:GIAO_VIEC:TOAN_HE_THONG', 'PARENT:HUY:TOAN_HE_THONG', 'PARENT:SUA:TOAN_HE_THONG',
                'PARENT:XEM:TOAN_HE_THONG', 'PARENT:XUAT:TOAN_HE_THONG',
                'STUDENT:DUYET:TOAN_HE_THONG', 'STUDENT:GIAO_VIEC:TOAN_HE_THONG', 'STUDENT:HUY:TOAN_HE_THONG', 'STUDENT:SUA:TOAN_HE_THONG',
                'STUDENT:XEM:TOAN_HE_THONG', 'STUDENT:XUAT:TOAN_HE_THONG'],
          'Admin: không Tạo, vẫn Xuất (chỉ Admin còn Xuất)');
select is((select count(*)::int from app.permission where is_active and action_code = 'XUAT' and module_code in ('PARENT', 'STUDENT')
           and role_code <> 'ADMIN'), 0, 'R-CRM-29: ngoài Admin không ai có Xuất trên Phụ huynh, Học sinh');
select is((select count(*)::int from app.permission where is_active and action_code = 'TAO' and module_code in ('PARENT', 'STUDENT')), 0,
          'R-CRM-27: không vai trò nào có Tạo trên Phụ huynh, Học sinh');
select is(pg_temp.perms('ACCOUNTANT', array['PARENT', 'STUDENT']), array['PARENT:XEM:TOAN_HE_THONG', 'STUDENT:XEM:TOAN_HE_THONG'],
          'Kế toán: Xem Phụ huynh và Học sinh, toàn hệ thống');
select is(pg_temp.perms('TEACHER', array['PARENT', 'STUDENT']), array['STUDENT:XEM:DUOC_PHAN_CONG'], 'Giáo viên không đổi');
select is(pg_temp.perms('TA', array['PARENT', 'STUDENT']), array['STUDENT:XEM:DUOC_PHAN_CONG'], 'Trợ giảng không đổi');
select is((select count(*)::int from app.permission where role_code = 'ADMIN' and module_code = 'ADMIN' and is_active), 7,
          'Admin vẫn giữ đủ 7 hành động của phân hệ Quản trị (R-CRM-24)');
select is((select count(*)::int from app.permission where is_active and action_code = 'DUYET' and module_code in ('PARENT', 'STUDENT')
           and role_code in ('SALES', 'CSKH', 'BRANCH_MANAGER', 'ADMIN')), 8, 'Duyệt (gộp trùng) trên Phụ huynh, Học sinh giữ nguyên cho bốn vai trò');

-- ================= Hệ quả: đọc hồ sơ dùng chung toàn hệ thống (RLS) =================
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id)
  select 'PH900001', 'Phụ Huynh CS1', '0900000201', id from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id)
  select 'PH900005', 'Phụ Huynh CS5', '0900000205', id from app.branch where code = 'CS5'$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HS900005', p.id, 'Học Sinh CS5', 2012, p.branch_id from app.parent p where p.code = 'PH900005'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((select count(*)::int from app.parent where code in ('PH900001', 'PH900005')), 2, 'Tuyển sinh CS1 đọc phụ huynh cả hai cơ sở');
select is((select count(*)::int from app.student where code = 'HS900005'), 1, 'Tuyển sinh CS1 đọc học sinh của cơ sở khác');
select is((select visible from app.find_duplicate_contacts('0900000205') where kind = 'PARENT'), true,
          'Kiểm trùng SĐT: phụ huynh cơ sở khác nay thấy đủ thông tin');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((select count(*)::int from app.parent where code in ('PH900001', 'PH900005')), 2, 'CSKH đọc phụ huynh cả hai cơ sở');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((select count(*)::int from app.student where code = 'HS900005'), 1, 'Trưởng cơ sở đọc học sinh cơ sở khác');
-- Ghi: Sửa vẫn theo cơ sở, không ghi thẳng, không Tạo.
select is(pg_temp.err($$insert into app.parent (code, full_name, phone, branch_id) select 'PHX', 'X', '0900000299', id from app.branch limit 1$$), '42501',
          'Không ghi thẳng bảng phụ huynh (không Tạo tay)');
select is(app.has_permission('PARENT', 'TAO'), false, 'Trưởng cơ sở không có Tạo phụ huynh');
select is(app.can_see_branch('STUDENT', 'SUA', (select id from app.branch where code = 'CS5')), false, 'Sửa học sinh vẫn theo cơ sở: Trưởng cơ sở CS1 không sửa học sinh CS5');
select is(app.can_see_branch('STUDENT', 'SUA', (select id from app.branch where code = 'CS1')), true, 'Sửa học sinh cơ sở mình: được');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is((select count(*)::int from app.parent), 0, 'Giáo viên không đọc phụ huynh');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((select count(*)::int from app.parent where code in ('PH900001', 'PH900005')), 2, 'Admin đọc mọi phụ huynh');
select is(app.has_permission('PARENT', 'XUAT'), true, 'Admin còn Xuất phụ huynh');

select * from finish();
rollback;
