-- Dữ liệu mẫu staging đợt 1 (migration 648; E-23-28): khoá môi trường, hạn mức, quyền xoá, đọc theo chủ bộ. Dữ liệu giả.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh5a'), ('cskh5b'), ('cskh1');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@dm.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@dm.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' else 'CSKH' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

create function pg_temp.sets_of(p_user text) returns bigint language plpgsql as $$
begin
  perform pg_temp.claims(pg_temp.uid(p_user), case when p_user = 'admin' then 'aal2' else 'aal1' end);
  return (select count(*) from app.list_demo_data_sets());
end $$;
grant execute on function pg_temp.sets_of(text) to public;

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5a'), 'aal1');

-- Luật (1): chạy thật (chưa có khoá môi trường) luôn từ chối, kể cả đã bật công tắc.
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'demo_data_enabled'$$);
select is(pg_temp.err($$select app.create_demo_data_set()$$), 'HMT_DEMO_TAT',
  'Luật khoá môi trường: không có khoá STAGING (chạy thật) thì tạo bộ bị chặn dù đã bật công tắc');

select is(app.demo_data_available(), false, 'Luật khoá môi trường: nút Dữ liệu mẫu ẩn khi chưa có khoá STAGING');

-- Luật (1): môi trường staging nhưng công tắc tắt thì chặn.
select pg_temp.sudo($$insert into app.deployment_env (env_code) values ('STAGING')$$);
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'demo_data_enabled'$$);
select is(pg_temp.err($$select app.create_demo_data_set()$$), 'HMT_DEMO_TAT',
  'Luật công tắc: staging nhưng demo_data_enabled tắt thì tạo bộ bị chặn');

select is(app.demo_data_available(), true, 'Đúng: staging và công tắc bật thì nút Dữ liệu mẫu hiện');
-- Đúng: staging và công tắc bật thì tạo được; bộ gắn cơ sở và người bấm.
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'demo_data_enabled'$$);
create temp table s1 (id uuid);
grant all on s1 to public;
insert into s1 select app.create_demo_data_set();
select is((select branch_id from app.demo_data_set where id = (select id from s1)), (select id from app.branch where code = 'CS5'),
  'Đúng: bộ mới gắn cơ sở của người bấm');
select is((select created_by from app.demo_data_set where id = (select id from s1)), pg_temp.uid('cskh5a'),
  'Luật (4): bộ mới ghi created_by là người bấm');

-- Luật (5): hạn mức theo người (đặt 1: bộ thứ hai bị chặn).
select pg_temp.sudo($$update app.setting_def set value = '1' where key = 'demo_data_max_per_user'$$);
select is(pg_temp.err($$select app.create_demo_data_set()$$), 'HMT_DEMO_QUA_HAN_MUC_NGUOI',
  'Luật hạn mức người: đủ số bộ cho phép thì bộ kế bị chặn');
select pg_temp.sudo($$update app.setting_def set value = '3' where key = 'demo_data_max_per_user'$$);

-- Luật (5): hạn mức theo cơ sở (đặt 2: người thứ hai tạo bộ thứ hai được, người thứ ba bị chặn).
select pg_temp.sudo($$update app.setting_def set value = '2' where key = 'demo_data_max_per_branch'$$);
select pg_temp.claims(pg_temp.uid('cskh5b'), 'aal1');
create temp table s2 (id uuid);
grant all on s2 to public;
insert into s2 select app.create_demo_data_set();
select pg_temp.claims(pg_temp.uid('cskh5a'), 'aal1');
select is(pg_temp.err($$select app.create_demo_data_set()$$), 'HMT_DEMO_QUA_HAN_MUC_CO_SO',
  'Luật hạn mức cơ sở: cơ sở đủ số bộ cho phép thì bộ kế bị chặn');
select pg_temp.sudo($$update app.setting_def set value = '10' where key = 'demo_data_max_per_branch'$$);

-- Đọc theo chủ bộ: mỗi người thường thấy bộ của mình, Admin thấy cả hai; người cơ sở khác không thấy.
select is(pg_temp.sets_of('cskh5a'), 1::bigint, 'Đọc: người thường chỉ thấy bộ của mình (liệt kê)');
select is(pg_temp.sets_of('cskh1'), 0::bigint, 'Đọc: người khác không thấy bộ của người kia');
select is(pg_temp.sets_of('admin'), 2::bigint, 'Đọc: Admin thấy mọi bộ');
select pg_temp.claims(pg_temp.uid('cskh5b'), 'aal1');
select is((select count(*) from app.demo_data_set), 1::bigint, 'RLS: người thường chỉ đọc được bộ của mình');

-- Không ghi trực tiếp qua bảng.
select is(pg_temp.err($$insert into app.demo_data_set (branch_id) select id from app.branch limit 1$$), '42501',
  'RLS: không ghi thẳng vào bảng bộ dữ liệu mẫu, chỉ qua hàm');

-- Luật (3): quyền xoá.
select is(pg_temp.err(format($$select app.delete_demo_data_set(%L)$$, (select id from s1))), 'HMT_DEMO_KHONG_THAY_BO',
  'Luật xoá: người khác không thấy bộ của người kia (không xoá được)');
select pg_temp.claims(pg_temp.uid('cskh5a'), 'aal1');
select is(pg_temp.err(format($$select app.delete_demo_data_set(%L)$$, (select id from s2))), 'HMT_DEMO_KHONG_THAY_BO',
  'Luật xoá: không xoá được bộ của người khác');
select is(pg_temp.err(format($$select app.delete_demo_data_set(%L)$$, (select id from s1))), null, 'Đúng: chủ bộ xoá được bộ của mình');
select is((select status_code from app.demo_data_set where id = (select id from s1)), 'DA_XOA', 'Xoá = đổi trạng thái, không xoá cứng');
select is(pg_temp.err(format($$select app.delete_demo_data_set(%L)$$, (select id from s1))), 'HMT_DEMO_DA_XOA', 'Luật xoá: xoá lại bộ đã xoá bị chặn');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err(format($$select app.delete_demo_data_set(%L)$$, (select id from s2))), null, 'Đúng: Admin xoá được bộ của người khác');

-- Luật hạn mức: bộ đã xoá không tính vào hạn mức (người a tạo lại được dù hạn mức người đặt 1).
select pg_temp.sudo($$update app.setting_def set value = '1' where key = 'demo_data_max_per_user'$$);
select pg_temp.claims(pg_temp.uid('cskh5a'), 'aal1');
select is(pg_temp.err($$select app.create_demo_data_set()$$), null, 'Hạn mức: bộ đã xoá không tính vào hạn mức');

-- Luật (4): nhật ký tạo và xoá.
create function pg_temp.audit_n() returns bigint language sql security definer as $$
  select count(*) from app.audit_log a join app.audited_table t on t.id = a.table_id where t.table_name = 'app.demo_data_set' or t.table_name = 'demo_data_set' $$;
grant execute on function pg_temp.audit_n() to public;
select cmp_ok(pg_temp.audit_n(), '>=', 4::bigint, 'Luật nhật ký: tạo và xoá bộ đều có dòng nhật ký');

select * from finish();
rollback;
