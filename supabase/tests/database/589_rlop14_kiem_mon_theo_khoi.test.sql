-- Migration 589 (R-LOP-14, Chat quyết 20/11, phương án A): kiểm môn theo khối khi tạo lớp sau tham số class_subject_grade_check_enabled.
-- Luật: R-LOP-14 (khối từ algebra_geometry_split_grade trở lên không tạo lớp chung TOAN, khối dưới không tạo DAI/HINH, lớp riêng LR được miễn). Mỗi luật có ca đúng và ca bị chặn. Dữ liệu giả.
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
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('bm5'), ('sales1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@l571.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@l571.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm5', 'CS5'), ('sales1', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('sales1', 'SALES')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
create function pg_temp.slot(p_wd int, p_first date) returns jsonb language sql stable as $$
  select jsonb_build_object('weekday', p_wd, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1, 'first_date', p_first) $$;
-- Dữ liệu một lớp: CS1, TOAN K08 CB A, bắt đầu thứ Hai 2027-03-01, 4 buổi, một khung thứ Hai.
create function pg_temp.data(p_extra jsonb default '{}'::jsonb) returns jsonb language sql stable as $$
  select jsonb_build_object('branch_id', pg_temp.cs('CS1'), 'year_code', '2627', 'subject_code', 'TOAN', 'grade_code', 'K08',
    'class_type_code', 'CB', 'level_code', 'A', 'max_students', 15, 'start_date', '2027-03-01', 'total_sessions', 4,
    'slots', jsonb_build_array(pg_temp.slot(1, date '2027-03-01'))) || p_extra $$;
create temp table cl (key text primary key, id uuid);
grant all on cl to public;
create function pg_temp.mk(p_key text, p_data jsonb) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  v := app.create_class(p_data);
  insert into cl values (p_key, (v ->> 'id')::uuid);
  return v;
end $$;
create function pg_temp.c(p_key text) returns uuid language sql stable as $$ select id from cl where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
-- Tham số mặc định TẮT: lớp Toán khối 8 và lớp Đại số khối 5 vẫn tạo được (không vỡ dữ liệu cũ).
select is(app.get_setting_bool('class_subject_grade_check_enabled'), false, 'R-LOP-14: tham số kiểm môn theo khối mặc định TẮT');
select ok((pg_temp.mk('tat_toan8', pg_temp.data()) ->> 'id') is not null, 'Tắt: lớp chung Toán khối 8 vẫn tạo được');
select ok((pg_temp.mk('tat_dai5', pg_temp.data('{"subject_code": "DAI", "grade_code": "K05"}'::jsonb)) ->> 'id') is not null, 'Tắt: lớp Đại số khối 5 vẫn tạo được');
-- Bật tham số (Admin bật khi go-live).
reset role;
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'class_subject_grade_check_enabled'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
-- Bị chặn: khối 8 (>= 7) không tạo lớp chung TOAN; khối 5 (< 7) không tạo DAI, HINH.
select is(pg_temp.err($$select app.create_class(pg_temp.data('{"subject_code": "TOAN", "grade_code": "K08"}'::jsonb))$$), 'HMT_LOP_MON_SAI_KHOI', 'Bật: khối 8 không tạo lớp chung Toán');
select is(pg_temp.err($$select app.create_class(pg_temp.data('{"subject_code": "DAI", "grade_code": "K05"}'::jsonb))$$), 'HMT_LOP_MON_SAI_KHOI', 'Bật: khối 5 không tạo lớp Đại số');
select is(pg_temp.err($$select app.create_class(pg_temp.data('{"subject_code": "HINH", "grade_code": "K06"}'::jsonb))$$), 'HMT_LOP_MON_SAI_KHOI', 'Bật: khối 6 không tạo lớp Hình học');
-- Đúng: khối 8 tạo Đại số, khối 5 tạo Toán, đúng ngưỡng khối 7 (>= 7) tạo Hình học.
select ok((pg_temp.mk('bat_dai8', pg_temp.data('{"subject_code": "DAI"}'::jsonb)) ->> 'id') is not null, 'Bật: khối 8 tạo lớp Đại số được');
select ok((pg_temp.mk('bat_toan5', pg_temp.data('{"subject_code": "TOAN", "grade_code": "K05"}'::jsonb)) ->> 'id') is not null, 'Bật: khối 5 tạo lớp chung Toán được');
select ok((pg_temp.mk('bat_hinh7', pg_temp.data('{"subject_code": "HINH", "grade_code": "K07"}'::jsonb)) ->> 'id') is not null, 'Bật: đúng khối bắt đầu tách (7) tạo lớp Hình học được');
select is(pg_temp.err($$select app.create_class(pg_temp.data('{"subject_code": "TOAN", "grade_code": "K07"}'::jsonb))$$), 'HMT_LOP_MON_SAI_KHOI', 'Bật: đúng khối 7 vẫn không tạo lớp chung Toán');
-- Lớp riêng được miễn kiểm.
select ok((pg_temp.mk('bat_lr', pg_temp.data('{"class_type_code": "LR", "level_code": null}'::jsonb)) ->> 'id') is not null, 'Bật: lớp riêng khối 8 môn Toán được miễn');
-- Quyền vẫn như cũ: Sale không tạo lớp.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.create_class(pg_temp.data('{"subject_code": "DAI"}'::jsonb))$$), 'HMT_KHONG_CO_QUYEN', 'Quyền tạo lớp không đổi: Sale vẫn bị chặn');
reset role;
select * from finish();
rollback;
