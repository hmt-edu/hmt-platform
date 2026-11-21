-- CH-04 app.list_policy_history (migration 601): người có Cấu hình bán hàng · Xem đọc; lịch sử tạo, sửa, Ngừng chính sách chiết khấu và quà tặng; lọc theo loại; phân trang. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('cskh5'), ('gv5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@lp.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@lp.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' when key = 'gv5' then 'TEACHER' else 'CSKH' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

create function pg_temp.pkg(p_code text) returns uuid language sql stable security definer as $$ select id from app.sales_package where code = p_code $$;
create function pg_temp.pol(p_code text) returns uuid language sql stable security definer as $$ select id from app.discount_policy where code = p_code $$;
create function pg_temp.gpol(p_code text) returns uuid language sql stable security definer as $$ select id from app.gift_policy where code = p_code $$;
grant execute on all functions in schema pg_temp to public;

set local role authenticated;

-- Chặn: giáo viên không có quyền Cấu hình bán hàng · Xem; Admin chưa hai bước (luật S03-12) cũng bị chặn.
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$select app.list_policy_history()$$), 'HMT_KHONG_CO_QUYEN', 'Lịch sử chính sách: giáo viên (không có Cấu hình bán hàng · Xem) bị chặn');
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.list_policy_history()$$), null, 'Lịch sử chính sách: CSKH có Cấu hình bán hàng · Xem (như đọc chính sách) đọc được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.list_policy_history()$$), 'HMT_KHONG_CO_QUYEN', 'Lịch sử chính sách: Admin chưa xác thực hai bước bị chặn');

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.list_policy_history('KHAC')$$), 'HMT_LOAI_SAI', 'Chặn: loại chính sách lạ');
create temp table base as select (app.list_policy_history() ->> 'total')::int as n;
grant select on base to authenticated;

-- Admin tạo một chiết khấu, sửa hai lần (giá trị rồi Ngừng); tạo một quà tặng, sửa tên một lần.
select app.save_discount_policy(null, '{"code": "LSU_GIAM", "name": "Giảm lịch sử", "kind": "PERCENT", "max_value": 8, "valid_from": "2026-09-01"}');
select app.save_discount_policy(pg_temp.pol('LSU_GIAM'), '{"max_value": 9}');
select app.set_config_active('DISCOUNT_POLICY', pg_temp.pol('LSU_GIAM'), false);
select app.save_gift_policy(null, jsonb_build_object('code', 'LSU_QUA', 'name', 'Quà lịch sử', 'gift_package_id', pg_temp.pkg('TL-MATOAN'), 'max_quantity', 2, 'valid_from', '2026-09-01'));
select app.save_gift_policy(pg_temp.gpol('LSU_QUA'), '{"name": "Quà lịch sử đổi tên"}');

select is((app.list_policy_history() ->> 'total')::int, (select n from base) + 5, 'Lịch sử: tạo + sửa + Ngừng chiết khấu (3) và tạo + đổi tên quà (2) = 5 dòng mới');
select ok((app.list_policy_history('DISCOUNT') ->> 'total')::int >= 3, 'Lọc chiết khấu: có ít nhất 3 dòng vừa tạo');
select is((select count(*)::int from jsonb_array_elements(app.list_policy_history('DISCOUNT') -> 'rows') r where r ->> 'code' = 'LSU_GIAM'), 3, 'Chiết khấu lịch sử có 3 dòng (tạo, sửa giá trị, Ngừng)');
select is((select count(*)::int from jsonb_array_elements(app.list_policy_history('GIFT') -> 'rows') r where r ->> 'code' = 'LSU_QUA'), 2, 'Quà tặng lịch sử có 2 dòng (tạo, đổi tên)');
select is((select count(*)::int from jsonb_array_elements(app.list_policy_history('GIFT') -> 'rows') r where r ->> 'code' = 'LSU_GIAM'), 0, 'Lọc quà tặng không lẫn chiết khấu');
select is((select r -> 'changes' -> 'max_value' ->> 1 from jsonb_array_elements(app.list_policy_history('DISCOUNT') -> 'rows') r where r ->> 'code' = 'LSU_GIAM' and r -> 'changes' ? 'max_value' and r ->> 'action' = 'U'), '9.00', 'Dòng sửa giá trị ghi giá trị mới');
select is((select r -> 'changes' -> 'is_active' ->> 1 from jsonb_array_elements(app.list_policy_history('DISCOUNT') -> 'rows') r where r ->> 'code' = 'LSU_GIAM' and r -> 'changes' ? 'is_active'), 'false', 'Dòng Ngừng ghi is_active thành false');
select is(app.list_policy_history(null, 1, 0) -> 'rows' -> 0 ->> 'code', 'LSU_QUA', 'Mới nhất trước: dòng đầu là đổi tên quà tặng');
select is(app.list_policy_history(null, 1, 0) -> 'rows' -> 0 ->> 'actor_name', 'Giả admin', 'Có tên người sửa');
select is(jsonb_array_length(app.list_policy_history(null, 2, 0) -> 'rows'), 2, 'Phân trang: limit 2 chỉ hai dòng');
select is((app.list_policy_history(null, 2, 0) ->> 'total')::int, (select n from base) + 5, 'Phân trang vẫn báo tổng đúng');
select is(jsonb_typeof((select r -> 'changes' from jsonb_array_elements(app.list_policy_history('GIFT') -> 'rows') r where r ->> 'code' = 'LSU_QUA' and r ->> 'action' = 'U')), 'object', 'Dòng sửa quà tặng có chi tiết thay đổi');

-- Chặn: khách chưa đăng nhập không gọi được.
reset role;
set local role anon;
select is(pg_temp.err($$select app.list_policy_history()$$), '42501', 'Chặn: khách chưa đăng nhập không gọi được list_policy_history');
reset role;

select * from finish();
rollback;
