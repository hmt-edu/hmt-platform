-- S10 (migration 649): app.assert_session_access kiểm phạm vi theo danh sách cho phép. Luật: R-HT, R-BUOI-09. Dữ liệu giả.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('gv1'), ('gv2'), ('cskh1'), ('cskh2');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@s10.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@s10.hoamatoan.invalid',
       (select id from app.branch where code = case u.key when 'cskh2' then 'CS2' else 'CS1' end), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'gv1' then 'TEACHER' when 'gv2' then 'TEACHER' else 'CSKH' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS2')
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

create temp table cl (id uuid);
grant all on cl to public;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
insert into cl select (app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS1'), 'year_code', '2627',
  'subject_code', 'TOAN', 'grade_code', 'K08', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
  'start_date', (date_trunc('week', current_date) + interval '14 days')::date, 'total_sessions', 5,
  'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
     'first_date', (date_trunc('week', current_date) + interval '14 days')::date, 'teacher_id', pg_temp.uid('gv1'))))) ->> 'id')::uuid;
reset role;
create temp table se (id uuid);
grant all on se to public;
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, status_code)
  values ((select id from cl), (select id from app.branch where code = 'CS1'), 301, current_date + 3, '18:00', '19:30', (select id from u where key = 'gv1'), 'NHAP')$$);
select pg_temp.sudo($$insert into se select id from app.class_session where class_id = (select id from cl) and session_no = 301$$);
create function pg_temp.chk(p_user text, p_module text, p_action text, p_staff boolean default false) returns text language plpgsql security definer as $$
begin
  -- Hàm kiểm quyền là nội bộ (không cấp cho authenticated): gọi qua hàm bọc chạy bằng chủ sở hữu; danh tính lấy từ claims.
  perform pg_temp.claims(pg_temp.uid(p_user), 'aal2');
  return pg_temp.err(format('select app.assert_session_access(%L, %L, %L, %L)', (select id from se), p_module, p_action, p_staff));
end $$;
grant execute on all functions in schema pg_temp to public;

-- Trường hợp ĐÚNG (còn chạy): Admin toàn hệ thống; CSKH đúng cơ sở; giáo viên đúng buổi (phạm vi được phân công).
select is(pg_temp.chk('admin', 'ATTENDANCE', 'XEM'), null, 'S10: Admin (toàn hệ thống) vào được buổi mọi cơ sở');
select is(pg_temp.chk('cskh1', 'ATTENDANCE', 'XEM'), null, 'S10: CSKH đúng cơ sở của buổi vào được (CO_SO)');
-- Trường hợp BỊ CHẶN.
select is(pg_temp.chk('cskh2', 'ATTENDANCE', 'XEM'), 'HMT_KHONG_CO_QUYEN', 'S10: CSKH cơ sở khác bị chặn (CO_SO khác cơ sở)');
-- Lỗ hổng cũ: gán phạm vi CUA_TOI cho CSKH ở ATTENDANCE·XEM thì trước đây lọt qua mọi cơ sở.
select set_config('hmt.migration', 'on', true);
select pg_temp.sudo($$update app.permission set scope_code = 'CUA_TOI' where role_code = 'CSKH' and module_code = 'ATTENDANCE' and action_code = 'XEM'$$);
select is(pg_temp.chk('cskh2', 'ATTENDANCE', 'XEM'), 'HMT_KHONG_CO_QUYEN', 'S10: phạm vi CUA_TOI không còn lọt qua buổi của cơ sở khác (danh sách cho phép)');
select is(pg_temp.chk('cskh1', 'ATTENDANCE', 'XEM'), 'HMT_KHONG_CO_QUYEN', 'S10: phạm vi CUA_TOI bị chặn cả ở cơ sở mình (phạm vi không nằm trong danh sách cho phép)');
select pg_temp.sudo($$update app.permission set scope_code = 'CHINH_MINH' where role_code = 'CSKH' and module_code = 'ATTENDANCE' and action_code = 'XEM'$$);
select is(pg_temp.chk('cskh2', 'ATTENDANCE', 'XEM'), 'HMT_KHONG_CO_QUYEN', 'S10: phạm vi CHINH_MINH bị chặn');
-- Được phân công: giáo viên đúng buổi vào được, giáo viên khác bị chặn, thao tác riêng vận hành thì chặn cả giáo viên đúng buổi.
select is(pg_temp.chk('gv1', 'ATTENDANCE', 'XEM'), null, 'S10: giáo viên của buổi vào được (DUOC_PHAN_CONG)');
select is(pg_temp.chk('gv2', 'ATTENDANCE', 'XEM'), 'HMT_KHONG_CO_QUYEN', 'S10: giáo viên không phụ trách buổi bị chặn');
select is(pg_temp.chk('gv1', 'ATTENDANCE', 'XEM', true), 'HMT_KHONG_CO_QUYEN', 'S10: thao tác riêng vận hành (staff_only) chặn cả giáo viên đúng buổi');

select * from finish();
rollback;
