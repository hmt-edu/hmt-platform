-- BC-08 (migration 554): app.report_teacher_late. Luật R-GV-05, R-GV-06 (báo cáo số buổi trễ, tổng giờ trễ), R-GV-14 (tháng theo ngày buổi), quyền Báo cáo · Xem theo cơ sở. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p554.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p554.hoamatoan.invalid',
       (select id from app.branch where code = case u.key when 'gv3' then 'CS2' else 'CS1' end), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'bm1' then 'BRANCH_MANAGER' when 'ta1' then 'TA' else 'TEACHER' end from u;
grant execute on all functions in schema pg_temp to public;

select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select c.code, b.id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10 from app.branch b join (values ('LOP554', 'CS1'), ('LOP554B', 'CS2')) c (code, br) on c.br = b.code$$);
-- Buổi: s1 (gv1 + ta1, trễ 2,5 giờ), s2 (gv1, trễ 1 giờ), s3 (gv2, đúng hạn), s4 (gv1, tháng trước, trễ 5 giờ: không tính), s5 (CS2, gv3, trễ 3 giờ), s6 (gv2, NHÁP: không tính).
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, assistant_id, status_code, type_code, completion_stamped_at, completion_late, completion_late_hours)
  select c.id, c.branch_id, v.no, v.d, '18:00', '19:30', pg_temp.uid(v.t), case when v.a then pg_temp.uid('ta1') end, v.st, 'CHINH', now(), v.late, v.h
    from (values ('LOP554', 1, date_trunc('month', current_date)::date, 'gv1', true, 'DONE', true, 2.5),
                 ('LOP554', 2, date_trunc('month', current_date)::date, 'gv1', false, 'DONE', true, 1.0),
                 ('LOP554', 3, date_trunc('month', current_date)::date, 'gv2', false, 'DONE', false, 0),
                 ('LOP554', 4, (date_trunc('month', current_date) - interval '1 day')::date, 'gv1', false, 'DONE', true, 5),
                 ('LOP554B', 5, date_trunc('month', current_date)::date, 'gv3', false, 'DONE', true, 3.0),
                 ('LOP554', 6, date_trunc('month', current_date)::date, 'gv2', false, 'NHAP', true, 9)) v (cc, no, d, t, a, st, late, h)
    join app.class c on c.code = v.cc$$);

-- ---- Admin xem toàn hệ thống ----
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
create temp table r as select app.report_teacher_late() as j;
grant select on r to public;
select is((select (j ->> 'total')::int from r), 3, 'BC-08: ba người có buổi trễ trong tháng (gv1, ta1, gv3); gv2 đúng hạn không có mặt');
select is((select j -> 'rows' -> 0 ->> 'name' from r), 'Giả gv1', 'BC-08: xếp số giờ trễ giảm dần, gv1 đứng đầu');
select is((select (j -> 'rows' -> 0 ->> 'late_sessions')::int from r), 2, 'BC-08: gv1 có hai buổi trễ trong tháng (buổi tháng trước không tính, R-GV-14)');
select is((select (j -> 'rows' -> 0 ->> 'late_hours')::numeric from r), 3.5, 'BC-08: gv1 tổng giờ trễ 3,5 (2,5 + 1)');
select is((select (j -> 'rows' -> 0 ->> 'done_sessions')::int from r), 2, 'BC-08: gv1 có hai buổi Done trong tháng');
select is((select count(*)::int from r, jsonb_array_elements(j -> 'rows') x where x ->> 'name' = 'Giả gv2'), 0, 'BC-08: CHỈ người có buổi trễ (gv2 chỉ có buổi đúng hạn và buổi nháp)');
select is((select (x ->> 'late_hours')::numeric from r, jsonb_array_elements(j -> 'rows') x where x ->> 'name' = 'Giả ta1'), 2.5, 'BC-08: trợ giảng cũng được tính buổi trễ chung với giáo viên');
-- Lọc cơ sở và phân trang.
select is((app.report_teacher_late(null, (select id from app.branch where code = 'CS2')) ->> 'total')::int, 1, 'BC-08: lọc cơ sở CS2 chỉ còn gv3');
select is(jsonb_array_length(app.report_teacher_late(null, null, 1, 0) -> 'rows'), 1, 'BC-08: phân trang theo số dòng');
select is((app.report_teacher_late(null, null, 1, 1) -> 'rows' -> 0 ->> 'name'), 'Giả gv3', 'BC-08: trang hai là người kế tiếp theo giờ trễ');
select is((app.report_teacher_late((date_trunc('month', current_date) - interval '1 day')::date) ->> 'total')::int, 1, 'BC-08: đổi sang tháng trước thấy buổi 5 giờ của gv1');
reset role;

-- ---- Trưởng cơ sở chỉ cơ sở mình ----
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
set local role authenticated;
select is((app.report_teacher_late() ->> 'total')::int, 2, 'BC-08: Trưởng cơ sở CS1 chỉ thấy người của CS1 (gv1, ta1), không thấy gv3 của CS2');
select is(pg_temp.err($$select app.report_teacher_late(null, (select id from app.branch where code = 'CS2'))$$), 'HMT_KHONG_CO_QUYEN', 'BC-08: Trưởng cơ sở chọn cơ sở khác bị chặn');
reset role;

-- ---- Giáo viên không có quyền Báo cáo ----
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.report_teacher_late()$$), 'HMT_KHONG_CO_QUYEN', 'BC-08: giáo viên không xem được báo cáo giáo viên trễ hạn');
reset role;
select * from finish();
rollback;
