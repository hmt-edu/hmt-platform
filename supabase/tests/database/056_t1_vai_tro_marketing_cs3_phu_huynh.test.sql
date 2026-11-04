-- T1 (migration 064; Đ286; spec 04 mục 14): vai trò Marketing, hồ sơ phụ huynh mọi cơ sở xem được, CS3 dạy học thường, gợi ý tên đăng nhập.
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
create function pg_temp.claims(p_user uuid) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal1')));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('mk1'), ('sales1'), ('sales5');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@t1.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@t1.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('mk1', 'CS1'), ('sales1', 'CS1'), ('sales5', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('mk1', 'MARKETER'), ('sales1', 'SALES'), ('sales5', 'SALES')) as v (key, role) on v.key = u.key;

-- ================= R-V2-09: vai trò Marketing =================
select is((select string_agg(code, ',' order by code) from app.role where code like 'MARKETING%' or code = 'MARKETER'),
          'MARKETER,MARKETING,MARKETING_MANAGER', 'Có ba vai trò MARKETER, MARKETING, MARKETING_MANAGER');
select is((select string_agg(distinct default_scope, ',') from app.role where code like 'MARKETING%' or code = 'MARKETER'),
          'TOAN_HE_THONG', 'Ba vai trò Marketing có phạm vi tất cả cơ sở');
select is((select count(*)::int from app.permission where role_code = 'MARKETER' and is_active),
          (select count(*)::int from app.permission where role_code = 'SALES' and is_active),
          'MARKETER có số ô quyền bằng SALES');
select is((select count(*)::int from app.permission where role_code in ('MARKETING', 'MARKETING_MANAGER') and is_active),
          2 * (select count(*)::int from app.permission where role_code = 'SALES' and is_active),
          'MARKETING và MARKETING_MANAGER cũng có số ô quyền bằng SALES');
select is((select count(*)::int
             from app.permission s join app.permission m on m.module_code = s.module_code and m.action_code = s.action_code and m.role_code = 'MARKETER'
            where s.role_code = 'SALES' and s.is_active and m.is_active
              and m.scope_code is distinct from case when s.scope_code = 'CO_SO' then 'TOAN_HE_THONG' else s.scope_code end), 0,
          'Quyền MARKETER giống SALES, chỉ phạm vi cơ sở đổi thành tất cả cơ sở');
select is((select count(*)::int from app.permission where role_code = 'MARKETER' and is_active and action_code = 'DUYET' and module_code in ('SALES_ORDER', 'RECEIPT')), 0,
          'MARKETER không duyệt đơn, phiếu thu (như SALES)');
select pg_temp.claims(pg_temp.uid('mk1'));
select is(app.permission_scope('LEAD', 'XEM'), 'TOAN_HE_THONG', 'Marketer xem lead ở tất cả cơ sở');
select pg_temp.claims(pg_temp.uid('sales1'));
select is(app.permission_scope('LEAD', 'XEM'), 'CO_SO', 'Sale vẫn chỉ xem lead ở cơ sở mình');

-- ================= R-V2-05: hồ sơ phụ huynh mọi cơ sở xem được =================
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id)
  values ('PH900001', 'Phụ huynh CS5 giả', '0900000501', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, full_name, birth_year, parent_id, branch_id)
  values ('HS900001', 'Học sinh CS5 giả', 2012, (select id from app.parent where code = 'PH900001'), (select id from app.branch where code = 'CS5'))$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'));
select is((select count(*)::int from app.parent where code = 'PH900001'), 1, 'Sale CS1 xem được hồ sơ phụ huynh của CS5');
select is((select count(*)::int from app.student where code = 'HS900001'), 1, 'Học sinh: ma trận cho Sale xem toàn hệ thống nên Sale CS1 cũng thấy (không đổi ở T1)');
select pg_temp.claims(pg_temp.uid('sales5'));
select is((select count(*)::int from app.parent where code = 'PH900001'), 1, 'Sale CS5 xem phụ huynh của cơ sở mình');
select is((select count(*)::int from app.student where code = 'HS900001'), 1, 'Sale CS5 xem học sinh của cơ sở mình');
reset role;
-- Người không có quyền xem phụ huynh vẫn không thấy.
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text, true);
select is((select count(*)::int from app.parent), 0, 'Người không có vai trò nào không thấy hồ sơ phụ huynh');
reset role;

-- ================= R-V2-10: CS3 là cơ sở dạy học thường =================
select is((select is_office from app.branch where code = 'CS3'), false, 'CS3 không còn là văn phòng');
select is(pg_temp.err($$insert into app.room (branch_id, code, name) select id, 'T1P1', 'Phòng thử' from app.branch where code = 'CS3'$$),
          null, 'CS3 tạo được phòng học');
select is(pg_temp.err($$update app.branch set is_office = true where code = 'CS3'$$), 'HMT_CO_SO_VAN_PHONG',
          'CS3 đã có phòng học thì không đổi lại thành văn phòng');

-- ================= R-V2-08: gợi ý tên đăng nhập =================
select is(app.suggest_username('Nguyễn Văn An'), 'annv', 'Nguyễn Văn An thành annv');
select is(app.suggest_username('Trần Thị Mai Anh'), 'anhttm', 'Họ và hai tên đệm: anhttm');
select is(app.suggest_username('  Đặng   Quốc  Huy '), 'huydq', 'Bỏ khoảng trắng thừa, đ thành d: huydq');
select is(app.suggest_username('An'), 'an', 'Chỉ có tên: lấy tên');
select is(pg_temp.err($$select app.suggest_username('   123 ')$$), 'HMT_THIEU_TEN', 'Họ tên không có chữ nào bị chặn');
select pg_temp.sudo($$insert into auth.users (id, aud, role, email) values ('eeeeeeee-0000-0000-0000-0000000000b1', 'authenticated', 'authenticated', 'b1@t1.hoamatoan.invalid')$$);
select pg_temp.sudo($$insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
  values ('eeeeeeee-0000-0000-0000-0000000000b1', 'Nguyễn Văn An', 'annv', (select id from app.branch where code = 'CS1'), false)$$);
select is(app.suggest_username('Nguyễn Văn An'), 'annv1', 'Trùng tên: thêm số 1');
select pg_temp.sudo($$insert into auth.users (id, aud, role, email) values ('eeeeeeee-0000-0000-0000-0000000000b2', 'authenticated', 'authenticated', 'b2@t1.hoamatoan.invalid')$$);
select pg_temp.sudo($$insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
  values ('eeeeeeee-0000-0000-0000-0000000000b2', 'Ngô Văn An', 'annv1', (select id from app.branch where code = 'CS1'), false)$$);
select is(app.suggest_username('Nguyễn Văn An'), 'annv2', 'Trùng tiếp: thêm số 2');
select is(has_function_privilege('authenticated', 'app.suggest_username(text)', 'EXECUTE'), false, 'Người đăng nhập không gọi được hàm gợi ý tên (hàm nội bộ)');
select is(has_function_privilege('anon', 'app.suggest_username(text)', 'EXECUTE'), false, 'Ẩn danh không gọi được hàm gợi ý tên');

select * from finish();
rollback;
