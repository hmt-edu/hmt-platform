-- BC-09 (migration 555): app.report_teaching_hours. Luật R-GV-14 (buổi Done, mọi loại buổi, theo thời lượng, người dạy thật gồm trợ giảng, huỷ không tính, tháng theo ngày buổi), quyền Báo cáo · Xem theo cơ sở. Dữ liệu giả.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$ begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('gv1'), ('ta1'), ('gv2'), ('gv3');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p555.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p555.hoamatoan.invalid',
       (select id from app.branch where code = case u.key when 'gv3' then 'CS2' else 'CS1' end), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'bm1' then 'BRANCH_MANAGER' when 'ta1' then 'TA' else 'TEACHER' end from u;
grant execute on all functions in schema pg_temp to public;

select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select c.code, b.id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10 from app.branch b join (values ('LOP555', 'CS1'), ('LOP555B', 'CS2')) c (code, br) on c.br = b.code$$);
-- Buổi 1,5 giờ (18:00 đến 19:30): s1 CHINH (gv1 + ta1), s2 CUNG_CO (gv1), s3 HOC_BU (gv2), s4 BO_TRO (gv1), s5 CHINH huỷ (gv1: không tính), s6 CHINH NHAP (gv2: không tính),
-- s7 CHINH tháng trước (gv1: không tính), s8 CHINH CS2 (gv3).
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, assistant_id, status_code, type_code)
  select c.id, c.branch_id, v.no, v.d, '18:00', '19:30', pg_temp.uid(v.t), case when v.a then pg_temp.uid('ta1') end, v.st, v.ty
    from (values ('LOP555', 1, date_trunc('month', current_date)::date, 'gv1', true, 'DONE', 'CHINH'),
                 ('LOP555', 2, date_trunc('month', current_date)::date, 'gv1', false, 'DONE', 'CUNG_CO'),
                 ('LOP555', 3, date_trunc('month', current_date)::date, 'gv2', false, 'DONE', 'HOC_BU'),
                 ('LOP555', 4, date_trunc('month', current_date)::date, 'gv1', false, 'DONE', 'BO_TRO'),
                 ('LOP555', 5, date_trunc('month', current_date)::date, 'gv1', false, 'HUY_CO_PHI', 'CHINH'),
                 ('LOP555', 6, date_trunc('month', current_date)::date, 'gv2', false, 'NHAP', 'CHINH'),
                 ('LOP555', 7, (date_trunc('month', current_date) - interval '1 day')::date, 'gv1', false, 'DONE', 'CHINH'),
                 ('LOP555B', 8, date_trunc('month', current_date)::date, 'gv3', false, 'DONE', 'CHINH')) v (cc, no, d, t, a, st, ty)
    join app.class c on c.code = v.cc$$);

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
create temp table r as select app.report_teaching_hours() as j;
grant select on r to public;
create function pg_temp.row(p_name text) returns jsonb language sql stable as $$ select x from r, jsonb_array_elements(j -> 'rows') x where x ->> 'name' = p_name $$;
grant execute on function pg_temp.row(text) to public;
select is((select (j ->> 'total')::int from r), 4, 'BC-09: bốn người có giờ dạy trong tháng (gv1, ta1, gv2, gv3)');
select is((pg_temp.row('Giả gv1') ->> 'hours')::numeric, 4.5, 'BC-09: gv1 dạy 3 buổi Done 1,5 giờ = 4,5 (buổi huỷ và buổi tháng trước không tính)');
select is((pg_temp.row('Giả gv1') -> 'by_type' ->> 'CHINH')::numeric, 1.5, 'BC-09: gv1 tách theo loại: Chính 1,5');
select is((pg_temp.row('Giả gv1') -> 'by_type' ->> 'CUNG_CO')::numeric, 1.5, 'BC-09: gv1 tách theo loại: Củng cố 1,5');
select is((pg_temp.row('Giả gv1') -> 'by_type' ->> 'BO_TRO')::numeric, 1.5, 'BC-09: học bổ trợ vẫn tính giờ dạy (R-BUOI-05)');
select is((pg_temp.row('Giả gv2') ->> 'hours')::numeric, 1.5, 'BC-09: gv2 chỉ buổi Học bù Done; buổi Nháp không tính');
select is((pg_temp.row('Giả gv2') -> 'by_type' ->> 'HOC_BU')::numeric, 1.5, 'BC-09: gv2 tách theo loại: Học bù 1,5');
select is((pg_temp.row('Giả ta1') ->> 'hours')::numeric, 1.5, 'BC-09: trợ giảng được tính giờ dạy cùng buổi với giáo viên');
select is(pg_temp.row('Giả ta1') ->> 'role', 'TRO_GIANG', 'BC-09: trợ giảng ghi vai TRO_GIANG');
select is(pg_temp.row('Giả gv1') ->> 'role', 'GIAO_VIEN', 'BC-09: giáo viên ghi vai GIAO_VIEN');
select is((select (j -> 'totals' ->> 'hours')::numeric from r), 9.0, 'BC-09: tổng giờ dạy: 1,5 (s1 gv1) + 1,5 (s1 ta1) + 1,5 + 1,5 + 1,5 + 1,5 (s8 gv3) = 9,0');
select is((select (j -> 'totals' ->> 'assistants')::int from r), 1, 'BC-09: một trợ giảng có giờ dạy');
select is((select (j -> 'totals' ->> 'teachers')::int from r), 3, 'BC-09: ba giáo viên có giờ dạy');
select is((app.report_teaching_hours(null, (select id from app.branch where code = 'CS2')) ->> 'total')::int, 1, 'BC-09: lọc cơ sở CS2 chỉ còn gv3');
select is(jsonb_array_length(app.report_teaching_hours(null, null, 2, 0) -> 'rows'), 2, 'BC-09: phân trang theo số dòng');
select is((app.report_teaching_hours((date_trunc('month', current_date) - interval '1 day')::date) ->> 'total')::int, 1, 'BC-09: tháng trước chỉ gv1 (theo ngày buổi diễn ra)');
reset role;

select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
set local role authenticated;
select is((app.report_teaching_hours() ->> 'total')::int, 3, 'BC-09: Trưởng cơ sở CS1 chỉ thấy người của CS1, không thấy gv3 của CS2');
select is(pg_temp.err($$select app.report_teaching_hours(null, (select id from app.branch where code = 'CS2'))$$), 'HMT_KHONG_CO_QUYEN', 'BC-09: Trưởng cơ sở chọn cơ sở khác bị chặn');
reset role;

select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.report_teaching_hours()$$), 'HMT_KHONG_CO_QUYEN', 'BC-09: giáo viên không xem được báo cáo giờ dạy toàn trường');
reset role;
select * from finish();
rollback;
