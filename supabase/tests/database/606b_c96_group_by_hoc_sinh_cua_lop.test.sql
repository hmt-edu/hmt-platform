-- C96 (migration 606): Group By LOP-09 Học sinh của lớp (class_student_group_counts) và bộ lọc branch_id của list_class_students; phạm vi lớp; chặn trường lạ. Dựng theo test 477.
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
create function pg_temp.sid(p_code text) returns uuid language sql stable security definer as $$ select id from app.student where code = p_code $$;
create function pg_temp.cid(p_code text) returns uuid language sql stable security definer as $$ select id from app.class where code = p_code $$;
create function pg_temp.tid(p_code text) returns uuid language sql stable security definer as $$ select id from app.upsale_ticket where code = p_code $$;
create function pg_temp.stage(p_code text) returns text language sql stable security definer as $$ select stage_code from app.upsale_ticket where code = p_code $$;
create function pg_temp.evs(p_code text) returns text language sql stable security definer as $$
  select string_agg(event_type, ',' order by seq) from app.upsale_ticket_event where ticket_id = pg_temp.tid(p_code) $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh1'), ('cskh5'), ('bm1'), ('ke1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p410.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p410.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('cskh1', 'CS1'), ('cskh5', 'CS5'), ('bm1', 'CS1'), ('ke1', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('cskh1', 'CSKH'), ('cskh5', 'CSKH'), ('bm1', 'BRANCH_MANAGER'), ('ke1', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- Dữ liệu: hai học sinh học lớp L1 ở CS1; một học sinh không có dòng xếp lớp.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH410', 'Phụ huynh giả 410', '0900410001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select s.code, p.id, s.name, 2012, p.branch_id from app.parent p, (values ('HS410A', 'Em A'), ('HS410B', 'Em B'), ('HS410C', 'Em C')) s (code, name) where p.code = 'PH410'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select 'LOP410', id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10 from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id)
  select 'GD410' || right(s.code, 1), s.id, s.parent_id, s.branch_id from app.student s where s.code in ('HS410A', 'HS410B')$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date from app.enrollment e, app.class c where e.code in ('GD410A', 'GD410B') and c.code = 'LOP410'$$);

-- Một học sinh đã rời lớp (GD410B): đóng dòng xếp lớp.
select pg_temp.sudo($$update app.enrollment_class set end_date = current_date, end_reason = 'CHUYEN_LOP' where enrollment_id = (select id from app.enrollment where code = 'GD410B')$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date from app.enrollment e, app.class c where e.code = 'GD410B' and c.code = 'LOP410'$$);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.list_class_students(pg_temp.cid('LOP410')) ->> 'total')::int, 3, 'LOP-09: liệt kê cả dòng đã rời (3 dòng: 2 em, một em có hai dòng)');
select is((app.list_class_students(pg_temp.cid('LOP410'), '{"state": ["DA_ROI"]}') ->> 'total')::int, 1, 'LOP-09: lọc Đã rời ra một dòng');
select is((app.list_class_students(pg_temp.cid('LOP410'), '{"state": ["DANG_HOC"]}') ->> 'total')::int, 2, 'LOP-09: lọc Còn trong lớp ra hai dòng');
select is((app.list_class_students(pg_temp.cid('LOP410'), '{"search": "HS410A"}') ->> 'total')::int, 1, 'LOP-09: tìm theo mã học sinh');
select is((app.list_class_students(pg_temp.cid('LOP410'), '{}', 'name_asc', 2, 0) -> 'rows') is not null and jsonb_array_length(app.list_class_students(pg_temp.cid('LOP410'), '{}', 'name_asc', 2, 0) -> 'rows') = 2, true, 'LOP-09: phân trang máy chủ (2 dòng một trang)');
select is((app.list_class_students(pg_temp.cid('LOP410'), '{}', 'name_asc', 2, 2) -> 'rows' -> 0 ->> 'student_code') is not null, true, 'LOP-09: trang hai còn dòng');
select ok(not (app.list_class_students(pg_temp.cid('LOP410')) -> 'rows' -> 0) ? 'phone', 'LOP-09: dòng không có số điện thoại, phụ huynh');
-- Quyền: Trưởng cơ sở CS5 không xem lớp CS1.
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.list_class_students(pg_temp.cid('LOP410'))$$), 'HMT_KHONG_CO_QUYEN', 'LOP-09 chặn: CSKH cơ sở khác không xem học sinh của lớp CS1');
reset role;


-- ================= C96 (migration 606): Group By LOP-09 Học sinh của lớp (class_student_group_counts) =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.class_student_group_counts(pg_temp.cid('LOP410'), '{}'::jsonb, array['state']) ->> 'total')::int, 3, 'LOP-09 Group By tình trạng: tổng 3 dòng xếp lớp');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.class_student_group_counts(pg_temp.cid('LOP410'), '{}'::jsonb, array['state']) -> 'groups') g where g ->> 'k1' = 'DANG_HOC'), 2, 'Nhóm Đang học có 2 dòng');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.class_student_group_counts(pg_temp.cid('LOP410'), '{}'::jsonb, array['state']) -> 'groups') g where g ->> 'k1' = 'DA_ROI'), 1, 'Nhóm Đã rời có 1 dòng');
select is((select g ->> 'l1' from jsonb_array_elements(app.class_student_group_counts(pg_temp.cid('LOP410'), '{}'::jsonb, array['state']) -> 'groups') g where g ->> 'k1' = 'DA_ROI'), 'Đã rời', 'Nhãn nhóm Đã rời');
select is((select g ->> 'l1' from jsonb_array_elements(app.class_student_group_counts(pg_temp.cid('LOP410'), '{}'::jsonb, array['branch']) -> 'groups') g limit 1) like 'CS1 %', true, 'Nhóm Cơ sở phụ trách có nhãn «mã tên»');
select is((select g ->> 'l1' from jsonb_array_elements(app.class_student_group_counts(pg_temp.cid('LOP410'), '{}'::jsonb, array['delivery']) -> 'groups') g limit 1), 'Chưa có', 'Ghi danh chưa ghi hình thức học vào nhóm «Chưa có»');
select is((app.class_student_group_counts(pg_temp.cid('LOP410'), '{"state": ["DA_ROI"]}'::jsonb, array['branch']) ->> 'total')::int, (app.list_class_students(pg_temp.cid('LOP410'), '{"state": ["DA_ROI"]}'::jsonb) ->> 'total')::int, 'Số đếm khớp danh sách khi cùng bộ lọc tình trạng');
select is((app.list_class_students(pg_temp.cid('LOP410'), jsonb_build_object('branch_id', (select id from app.branch where code = 'CS1'))) ->> 'total')::int, 3, 'Mở nhóm Cơ sở: list_class_students lọc được theo branch_id');
select is((app.list_class_students(pg_temp.cid('LOP410'), jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5'))) ->> 'total')::int, 0, 'Lọc cơ sở khác ra 0 dòng');
select is(jsonb_array_length(app.class_student_group_counts(pg_temp.cid('LOP410'), '{}'::jsonb, array['state', 'delivery']) -> 'groups'), 2, 'Hai cấp tình trạng, hình thức học: hai nhóm lá');
select is(pg_temp.err($$select app.class_student_group_counts(pg_temp.cid('LOP410'), '{}'::jsonb, array['creator'])$$), 'HMT_NHOM_SAI', 'Chặn: trường nhóm không cho phép');
select is(pg_temp.err($$select app.class_student_group_counts(pg_temp.cid('LOP410'), '{}'::jsonb, array['state', 'state'])$$), 'HMT_NHOM_SAI', 'Chặn: hai cấp giống nhau');
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.class_student_group_counts(pg_temp.cid('LOP410'), '{}'::jsonb, array['state'])$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH cơ sở khác không đếm được học sinh của lớp CS1');
reset role;

select * from finish();
rollback;
