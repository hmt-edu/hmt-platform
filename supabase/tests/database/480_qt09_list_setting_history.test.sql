-- QT-09 app.list_setting_history (migration 480): chỉ Admin đọc; lịch sử đổi giá trị chung và ghi đè theo cơ sở; lọc theo tham số; phân trang. Dữ liệu giả.
begin;
-- D41 (migration 472): bài này kiểm luật «Admin, Kế toán phải qua hai bước»; luật chỉ áp khi tham số mfa_required_enabled bật (mặc định tắt), nên bật tham số ở đây.
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
-- 647 (A-23-27): bắt hai bước chỉ còn Admin; bài này vẫn kiểm luật aal2 cho Kế toán nên dựng lại cờ trong giao dịch của bài (hoàn tác khi kết thúc).
do $$ begin perform set_config('hmt.migration', 'on', true); update app.role set require_mfa = true where code = 'ACCOUNTANT'; perform set_config('hmt.migration', '', true); end $$;
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

-- Tham số thử: kiểu INT, cho ghi đè theo cơ sở, còn chỗ tăng 1 trong khoảng cho phép (không viết cứng khoá).
create temp table k as
select key, (value::int) as v from app.setting_def
 where value_type = 'INT' and allow_branch_override and max_value is not null and value::int + 2 <= max_value
 order by key limit 1;
grant select on k to authenticated;

set local role authenticated;

-- Luật S03-12: CSKH và Admin chưa hai bước bị chặn.
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.list_setting_history()$$), 'HMT_KHONG_CO_QUYEN', 'Lịch sử tham số: CSKH bị chặn (S03-12)');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.list_setting_history()$$), 'HMT_KHONG_CO_QUYEN', 'Lịch sử tham số: Admin chưa xác thực hai bước bị chặn');

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.list_setting_history((select key from k)) ->> 'total')::int, 0, 'Chưa sửa gì: lịch sử tham số trống');

-- Admin sửa giá trị chung hai lần, ghi đè cơ sở CS5 một lần rồi bỏ ghi đè.
select app.set_setting((select key from k), ((select v from k) + 1)::text, null);
select app.set_setting((select key from k), ((select v from k) + 2)::text, null);
select app.set_setting((select key from k), ((select v from k) + 1)::text, (select id from app.branch where code = 'CS5'));
select app.clear_setting_override((select key from k), (select id from app.branch where code = 'CS5'));

select is((app.list_setting_history((select key from k)) ->> 'total')::int, 4, 'Lịch sử: 2 lần đổi chung + tạo ghi đè + bỏ ghi đè = 4 dòng');
select is(app.list_setting_history((select key from k), 1, 0) -> 'rows' -> 0 ->> 'branch_code', 'CS5', 'Mới nhất trước: dòng đầu là bỏ ghi đè CS5');
select is(app.list_setting_history((select key from k), 1, 0) -> 'rows' -> 0 ->> 'old_value', ((select v from k) + 1)::text, 'Bỏ ghi đè: giá trị cũ là giá trị ghi đè');
select is((select r ->> 'old_value' from jsonb_array_elements(app.list_setting_history((select key from k)) -> 'rows') r
            where r ->> 'branch_code' is null order by r ->> 'at' desc limit 1), ((select v from k) + 1)::text, 'Đổi giá trị chung: giá trị cũ ghi đúng');
select is(app.list_setting_history((select key from k), 1, 0) -> 'rows' -> 0 ->> 'actor_name', 'Giả admin', 'Có tên người sửa');
select is(jsonb_array_length(app.list_setting_history((select key from k), 3, 3) -> 'rows'), 1, 'Phân trang: trang cuối có 1 dòng');
select is((app.list_setting_history('khong_co_tham_so_nay') ->> 'total')::int, 0, 'Tham số lạ: không có dòng');
select ok((app.list_setting_history() ->> 'total')::int >= 4, 'Không chọn tham số: hiện mọi tham số');

select * from finish();
rollback;
