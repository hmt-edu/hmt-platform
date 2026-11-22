-- BC-08 Xuất CSV (migration 620): app.export_teacher_late. Luật quyền Báo cáo · Xuất, nhật ký xuất file, phạm vi cơ sở, giới hạn export_max_rows. Dữ liệu giả.
-- Dữ liệu dựng như bài 554. Luật R-GV-05, R-GV-06 (báo cáo số buổi trễ, tổng giờ trễ), R-GV-14 (tháng theo ngày buổi), quyền Báo cáo · Xem theo cơ sở. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p620.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p620.hoamatoan.invalid',
       (select id from app.branch where code = case u.key when 'gv3' then 'CS2' else 'CS1' end), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'bm1' then 'BRANCH_MANAGER' when 'ta1' then 'TA' else 'TEACHER' end from u;
grant execute on all functions in schema pg_temp to public;

select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select c.code, b.id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10 from app.branch b join (values ('LOP620', 'CS1'), ('LOP620B', 'CS2')) c (code, br) on c.br = b.code$$);
-- Buổi: s1 (gv1 + ta1, trễ 2,5 giờ), s2 (gv1, trễ 1 giờ), s3 (gv2, đúng hạn), s4 (gv1, tháng trước, trễ 5 giờ: không tính), s5 (CS2, gv3, trễ 3 giờ), s6 (gv2, NHÁP: không tính).
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, assistant_id, status_code, type_code, completion_stamped_at, completion_late, completion_late_hours)
  select c.id, c.branch_id, v.no, v.d, '18:00', '19:30', pg_temp.uid(v.t), case when v.a then pg_temp.uid('ta1') end, v.st, 'CHINH', now(), v.late, v.h
    from (values ('LOP620', 1, date_trunc('month', current_date)::date, 'gv1', true, 'DONE', true, 2.5),
                 ('LOP620', 2, date_trunc('month', current_date)::date, 'gv1', false, 'DONE', true, 1.0),
                 ('LOP620', 3, date_trunc('month', current_date)::date, 'gv2', false, 'DONE', false, 0),
                 ('LOP620', 4, (date_trunc('month', current_date) - interval '1 day')::date, 'gv1', false, 'DONE', true, 5),
                 ('LOP620B', 5, date_trunc('month', current_date)::date, 'gv3', false, 'DONE', true, 3.0),
                 ('LOP620', 6, date_trunc('month', current_date)::date, 'gv2', false, 'NHAP', true, 9)) v (cc, no, d, t, a, st, late, h)
    join app.class c on c.code = v.cc$$);

-- ---- Admin xuất toàn hệ thống ----
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
create temp table r as select app.export_teacher_late() as j;
grant select on r to public;
select is((select (j ->> 'exported')::int from r), 3, 'Xuất: ba người có buổi trễ trong tháng, giống báo cáo xem');
select is((select (j ->> 'truncated')::boolean from r), false, 'Xuất: chưa quá giới hạn dòng');
select is((select j -> 'rows' -> 0 ->> 'name' from r), 'Giả gv1', 'Xuất: cùng thứ tự với báo cáo xem (giờ trễ giảm dần)');
select is((select (j -> 'rows' -> 0 ->> 'late_hours')::numeric from r), 3.5, 'Xuất: giờ trễ gv1 3,5 (BC-08 chỉ ghi số liệu)');
select is((app.export_teacher_late(null, (select id from app.branch where code = 'CS2')) ->> 'exported')::int, 1, 'Xuất: lọc cơ sở CS2 chỉ còn gv3');
reset role;
select is((select count(*)::int from app.export_log where module_code = 'REPORT' and filters ->> 'report' = 'BC08' and row_count = 3), 1, 'Nhật ký xuất file: ghi một dòng, đúng số dòng, đúng báo cáo');

-- ---- Giới hạn số dòng mỗi lần xuất ----
update app.setting_def set value = '2' where key = 'export_max_rows';
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is((app.export_teacher_late() ->> 'exported')::int, 2, 'Giới hạn: chỉ xuất tối đa export_max_rows dòng');
select is((app.export_teacher_late() ->> 'truncated')::boolean, true, 'Giới hạn: báo truncated khi quá');
reset role;

-- ---- Trưởng cơ sở: có Báo cáo · Xuất theo cơ sở (ma trận quyền), chỉ xuất người của cơ sở mình ----
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
set local role authenticated;
select is((app.export_teacher_late() ->> 'exported')::int, 2, 'Phạm vi: Trưởng cơ sở CS1 chỉ xuất người của CS1 (gv1, ta1), không có gv3 của CS2');
select is(pg_temp.err($$select app.export_teacher_late(null, (select id from app.branch where code = 'CS2'))$$), 'HMT_KHONG_CO_QUYEN', 'Phạm vi: Trưởng cơ sở chọn cơ sở khác bị chặn');
reset role;

-- ---- Giáo viên ----
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.export_teacher_late()$$), 'HMT_KHONG_CO_QUYEN', 'Luật: giáo viên không có quyền Báo cáo · Xuất bị chặn');
reset role;
select is((select count(*)::int from app.export_log where module_code = 'REPORT' and filters ->> 'report' = 'BC08' and user_id = pg_temp.uid('gv1')), 0, 'Bị chặn thì không ghi nhật ký xuất');
select * from finish();
rollback;
