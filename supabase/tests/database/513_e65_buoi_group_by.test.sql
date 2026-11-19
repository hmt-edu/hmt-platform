-- E65 (migration 513): Group By ở máy chủ cho Buổi học: session_group_counts, bộ lọc type_code và no_teacher của session_list.
-- Luật: R-GD-05 (hàng chờ chỉ Chờ xếp lớp), R-GD-04 (sổ giờ chỉ thêm, hiện mọi dòng), R-GD-18 (chuyển phí kèm mã ticket), R-GV-13 (giáo viên không đọc),
-- phạm vi cơ sở. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@e63.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@e63.hoamatoan.invalid',
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
  ('PHG513A', 'Phụ huynh giả 513 A', '0900513001', pg_temp.cs('CS1')), ('PHG513B', 'Phụ huynh giả 513 B', '0900513002', pg_temp.cs('CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSG513' || n, (select id from app.parent where code = 'PHG513A'), 'Em giả 513 ' || chr(64 + n), 2012, pg_temp.cs('CS1') from generate_series(1, 4) n$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  values ('HSG5135', (select id from app.parent where code = 'PHG513B'), 'Em giả 513 E', 2012, pg_temp.cs('CS5'))$$);

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

-- Ghi danh: A (Chờ xếp lớp, Em A), B (Đang học, có lớp, Em B, có sổ giờ đủ loại), C (Đã xếp lớp, Em C), D (Hoàn phí, Em D), E (CS5, Chờ xếp lớp, Em E).
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, delivery_mode_code, status_code, purchased_hours, gifted_hours)
  select v.code, st.id, st.parent_id, st.branch_id, 'TOAN', 'OFF', v.status, v.purch, 0
    from (values ('GD513A', 'HSG5131', 'CHO_XEP_LOP', 24), ('GD513B', 'HSG5132', 'DANG_HOC', 48), ('GD513C', 'HSG5133', 'DA_XEP_LOP', 24),
                 ('GD513D', 'HSG5134', 'HOAN_PHI', 24), ('GD513E', 'HSG5135', 'CHO_XEP_LOP', 24)) v (code, student, status, purch)
    join app.student st on st.code = v.student$$);
create function pg_temp.en(p_code text) returns uuid language sql stable security definer as $$ select id from app.enrollment where code = p_code $$;
grant execute on all functions in schema pg_temp to public;
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select pg_temp.en(c), (select id from cl), pg_temp.cs('CS1'), current_date - 30 from unnest(array['GD513B', 'GD513C']) c$$);
-- Sổ giờ của B: cấp 48, điều chỉnh +2, trừ buổi -2, chuyển phí -4 (kèm mã ticket).
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) values (pg_temp.en('GD513B'), pg_temp.cs('CS1'), 'CAP_MUA', 48)$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, reason_code, note, created_by)
  values (pg_temp.en('GD513B'), pg_temp.cs('CS1'), 'DIEU_CHINH', 2, (select code from app.catalog_item where catalog_code = 'HOURS_ADJUST_REASON' order by sort_order limit 1),
          'Buổi điểm danh nhầm', pg_temp.uid('cskh1'))$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, session_id) values (pg_temp.en('GD513B'), pg_temp.cs('CS1'), 'TRU_BUOI', -2, (select id from se))$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, source_ref) values (pg_temp.en('GD513B'), pg_temp.cs('CS1'), 'CHUYEN_PHI', -4, 'TK-TEST-0001')$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) values (pg_temp.en('GD513A'), pg_temp.cs('CS1'), 'CAP_MUA', 24), (pg_temp.en('GD513C'), pg_temp.cs('CS1'), 'CAP_MUA', 24)$$);




-- Thêm hai buổi cùng lớp: một buổi Nháp có giáo viên gv1 (loại CHINH), một buổi Nháp chưa có giáo viên; buổi 'se' (Done, chưa có giáo viên) đã có sẵn.
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, status_code, type_code, teacher_id)
  values ((select id from cl), pg_temp.cs('CS1'), 8, current_date + 1, '18:00', '19:30', 'NHAP', 'CHINH', pg_temp.uid('gv1')),
         ((select id from cl), pg_temp.cs('CS1'), 9, current_date + 2, '18:00', '19:30', 'NHAP', 'CHINH', null)$$);

select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((app.session_group_counts('{}', array['status']) ->> 'total')::int >= 3, true, 'E65: tổng nhóm bao gồm ba buổi vừa dựng');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.session_group_counts(jsonb_build_object('class_id', (select id from cl)), array['status']) -> 'groups') g where g ->> 'k1' = 'NHAP'), 2, 'E65: nhóm theo tình trạng: 2 buổi Nháp của lớp');
select is((app.session_group_counts(jsonb_build_object('class_id', (select id from cl)), array['status']) -> 'groups' -> 0 ->> 'l1') is not null, true, 'E65: nhóm có nhãn tiếng Việt từ danh mục');
select is((select sum((g ->> 'count')::int)::int from jsonb_array_elements(app.session_group_counts(jsonb_build_object('class_id', (select id from cl)), array['date']) -> 'groups') g), 3, 'E65: nhóm theo ngày: cộng số đếm bằng tổng của lớp');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.session_group_counts(jsonb_build_object('class_id', (select id from cl)), array['teacher']) -> 'groups') g where g ->> 'k1' = ''), 2, 'E65: nhóm «Chưa có giáo viên» có 2 buổi');
select is((app.session_list(jsonb_build_object('class_id', (select id from cl), 'no_teacher', true)) ->> 'total')::int, 2, 'E65: bộ lọc no_teacher mở đúng nhóm chưa có giáo viên');
select is((app.session_list(jsonb_build_object('class_id', (select id from cl), 'type_code', jsonb_build_array('CHINH'))) ->> 'total')::int, 3, 'E65: bộ lọc loại buổi hoạt động');
select is((app.session_list(jsonb_build_object('class_id', (select id from cl), 'type_code', jsonb_build_array('KHAC_LA'))) ->> 'total')::int, 0, 'E65: loại buổi không có thì 0 dòng');
select is((app.session_group_counts(jsonb_build_object('class_id', (select id from cl)), array['status', 'type']) -> 'groups' -> 0 ->> 'k2'), 'CHINH', 'E65: hai cấp: cấp hai là loại buổi');
select is(pg_temp.err($$select app.session_group_counts('{}', array['status', 'status'])$$), 'HMT_NHOM_SAI', 'E65: hai cấp trùng nhau thì chặn');
select is(pg_temp.err($$select app.session_group_counts('{}', array['lạ'])$$), 'HMT_NHOM_SAI', 'E65: trường nhóm lạ thì chặn');
select is(pg_temp.err($$select app.session_group_counts('{}', array['status', 'type', 'date'])$$), 'HMT_NHOM_SAI', 'E65: quá hai cấp thì chặn');
reset role;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
set local role authenticated;
select is((select count(*)::int from jsonb_array_elements(app.session_group_counts(jsonb_build_object('class_id', (select id from cl)), array['status']) -> 'groups')), 0, 'E65: CSKH khác cơ sở không thấy buổi của lớp CS1 trong nhóm');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.session_group_counts('{}', array['status'])$$), 'HMT_KHONG_CO_QUYEN', 'E65: giáo viên không đọc được nhóm');
reset role;

select * from finish();
rollback;
