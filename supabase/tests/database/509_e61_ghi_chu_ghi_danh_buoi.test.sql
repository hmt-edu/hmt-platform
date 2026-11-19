-- E61: ghi chú và hoạt động cho Ghi danh (GD-02) và Buổi học (BUOI-02): loại ghi chú mới ENROLLMENT, CLASS_SESSION.
-- Luật: quyền xem theo cơ sở (CSKH cùng cơ sở ghi và đọc được; khác cơ sở bị chặn; giáo viên «được phân công» không đọc ghi chú buổi).
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

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh1'), ('cskh5'), ('sales1'), ('gv1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@e61.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@e61.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh5' then 'CS5' else 'CS1' end), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'cskh1' then 'CSKH' when 'cskh5' then 'CSKH' when 'sales1' then 'SALES' else 'TEACHER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
grant execute on all functions in schema pg_temp to public;

-- Hồ sơ giả: phụ huynh, 4 học sinh CS1 và 1 học sinh CS5.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values
  ('PHG509A', 'Phụ huynh giả 509 A', '0900509001', pg_temp.cs('CS1')), ('PHG509B', 'Phụ huynh giả 509 B', '0900509002', pg_temp.cs('CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSG509' || n, (select id from app.parent where code = 'PHG509A'), 'Em giả 509 ' || chr(64 + n), 2012, pg_temp.cs('CS1') from generate_series(1, 4) n$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  values ('HSG5095', (select id from app.parent where code = 'PHG509B'), 'Em giả 509 E', 2012, pg_temp.cs('CS5'))$$);

-- Lớp CS1 (tạo bằng hàm nghiệp vụ) và một buổi để có dòng Trừ buổi.
create temp table cl (id uuid);
grant all on cl to public;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
insert into cl select (app.create_class(jsonb_build_object('branch_id', pg_temp.cs('CS1'), 'year_code', '2627', 'subject_code', 'TOAN', 'grade_code', 'K08',
  'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0, 'start_date', (date_trunc('week', current_date) + interval '14 days')::date, 'total_sessions', 5,
  'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
    'first_date', (date_trunc('week', current_date) + interval '14 days')::date)))) ->> 'id')::uuid;
reset role;
create temp table se (id uuid);
grant all on se to public;
select pg_temp.sudo($$with i as (insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, status_code, type_code)
  values ((select id from cl), pg_temp.cs('CS1'), 7, current_date - 1, '18:00', '19:30', 'DONE', 'CHINH') returning id) insert into se select id from i$$);


select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, delivery_mode_code, status_code, purchased_hours, gifted_hours)
  select 'GD509A', st.id, st.parent_id, st.branch_id, 'TOAN', 'OFF', 'CHO_XEP_LOP', 24, 0 from app.student st where st.code = 'HSG5091'$$);

select is((select count(*)::int from app.note_target where entity_type in ('ENROLLMENT', 'CLASS_SESSION')), 2, 'E61: hai loại ghi chú mới đã đăng ký');

-- ---------- Ghi danh ----------
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.can_see_note_target('ENROLLMENT', (select id from app.enrollment where code = 'GD509A')), true, 'E61: CSKH cùng cơ sở thấy ghi chú ghi danh');
select is(pg_temp.err($$select app.add_note('ENROLLMENT', (select id from app.enrollment where code = 'GD509A'), 'Đã gọi phụ huynh')$$), null, 'E61: CSKH cùng cơ sở ghi chú vào ghi danh được');
select is((select count(*)::int from app.record_notes('ENROLLMENT', (select id from app.enrollment where code = 'GD509A'))), 1, 'E61: đọc lại được ghi chú vừa viết');
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(app.can_see_note_target('ENROLLMENT', (select id from app.enrollment where code = 'GD509A')), false, 'E61: CSKH khác cơ sở không thấy ghi chú ghi danh');
select is(pg_temp.err($$select app.add_note('ENROLLMENT', (select id from app.enrollment where code = 'GD509A'), 'Lén ghi')$$), 'HMT_KHONG_CO_QUYEN', 'E61: CSKH khác cơ sở không ghi chú vào ghi danh được');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(app.can_see_note_target('ENROLLMENT', (select id from app.enrollment where code = 'GD509A')), false, 'E61: giáo viên không thấy ghi chú ghi danh');

-- ---------- Buổi học ----------
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.can_see_note_target('CLASS_SESSION', (select id from se)), true, 'E61: CSKH cùng cơ sở thấy ghi chú buổi');
select is(pg_temp.err($$select app.add_note('CLASS_SESSION', (select id from se), 'Buổi này đổi phòng')$$), null, 'E61: CSKH cùng cơ sở ghi chú vào buổi được');
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(app.can_see_note_target('CLASS_SESSION', (select id from se)), false, 'E61: CSKH khác cơ sở không thấy ghi chú buổi');
select is(pg_temp.err($$select app.add_note('CLASS_SESSION', (select id from se), 'Lén ghi')$$), 'HMT_KHONG_CO_QUYEN', 'E61: CSKH khác cơ sở không ghi chú vào buổi được');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(app.can_see_note_target('CLASS_SESSION', (select id from se)), false, 'E61: giáo viên (được phân công) không đọc ghi chú buổi');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(app.can_see_note_target('CLASS_SESSION', (select id from se)), true, 'E61: Admin thấy ghi chú buổi');

select * from finish();
rollback;
