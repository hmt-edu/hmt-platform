-- Cụm Khách hàng (migration 117): list_parents, get_parent_record, list_students, get_student_record, student_status. Luật S02-TT-HS, R-CRM-27. Dữ liệu giả.
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

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('bm5'), ('cskh1'), ('sales1'), ('gv1'), ('gv2');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d1c.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d1c.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm5', 'CS5'), ('cskh1', 'CS1'), ('sales1', 'CS1'), ('gv1', 'CS1'), ('gv2', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('cskh1', 'CSKH'),
  ('sales1', 'SALES'), ('gv1', 'TEACHER'), ('gv2', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
-- Q-198: đặt rõ nhánh Bật (không dựa vào mặc định): Done cần nhận xét, điểm.
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'session_done_requires_review'$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
-- Thứ Hai 4 tuần trước (buổi quá khứ để Done được) và thứ Hai 2 tuần sau (buổi tương lai).
create function pg_temp.past() returns date language sql stable as $$ select (date_trunc('week', current_date) - interval '28 days')::date $$;
create function pg_temp.fut() returns date language sql stable as $$ select (date_trunc('week', current_date) + interval '14 days')::date $$;
create temp table cl (key text primary key, id uuid);
grant all on cl to public;
create function pg_temp.c(p_key text) returns uuid language sql stable as $$ select id from cl where key = p_key $$;
create function pg_temp.mkclass(p_key text, p_type text, p_first date, p_total integer, p_teacher text default 'gv1') returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_class(jsonb_build_object('branch_id', pg_temp.cs('CS1'), 'year_code', '2627', 'subject_code', 'TOAN', 'grade_code', 'K08',
    'class_type_code', p_type, 'level_code', case when p_type = 'LR' then null else 'A' end, 'max_students', 0, 'start_date', p_first,
    'total_sessions', p_total,
    'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
                                                  'first_date', p_first, 'teacher_id', pg_temp.uid(p_teacher)))));
  insert into cl values (p_key, (v ->> 'id')::uuid);
  perform app.transition_class((v ->> 'id')::uuid, 'DA_TRINH');
  perform app.transition_class((v ->> 'id')::uuid, 'DA_XAC_NHAN');
  perform app.transition_class((v ->> 'id')::uuid, 'DA_DUYET');
end $$;
-- Buổi thứ n (theo ngày) của lớp.
create function pg_temp.s(p_key text, p_n integer) returns uuid language sql stable security definer as $$
  select id from app.class_session where class_id = pg_temp.c(p_key) and session_no = p_n and status_code not in ('HUY_KHONG_PHI', 'DA_THAY') $$;
create temp table en (key text primary key, id uuid);
grant all on en to public;
create function pg_temp.e(p_key text) returns uuid language sql stable as $$ select id from en where key = p_key $$;
create function pg_temp.st(p_n integer) returns uuid language sql stable security definer as $$ select id from app.student where code = 'HSD1C0' || p_n $$;
-- Ghi danh giả; p_old = true thì lùi ngày tạo 60 ngày (tắt tạm trigger điền cột chuẩn) để vào được danh sách buổi quá khứ (R-GIO-02).
create function pg_temp.mke(p_key text, p_n integer, p_old boolean, p_hours numeric) returns void language plpgsql security definer as $$
declare v_id uuid;
begin
  insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code)
  values ('GDC' || p_key, pg_temp.st(p_n), (select parent_id from app.student where id = pg_temp.st(p_n)), pg_temp.cs('CS1'), 'TOAN')
  returning id into v_id;
  if p_old then
    alter table app.enrollment disable trigger enrollment_fill_standard;
    update app.enrollment set created_at = now() - interval '60 days' where id = v_id;
    alter table app.enrollment enable trigger enrollment_fill_standard;
  end if;
  insert into en values (p_key, v_id);
  if p_hours <> 0 then
    perform app.add_opening_hours(v_id, p_hours, 'DOT-D1C');
  end if;
end $$;
grant execute on all functions in schema pg_temp to public;

-- Từ đây chạy với vai trò đăng nhập thật (RLS và quyền gọi hàm có hiệu lực).
set local role authenticated;

-- ---------- Hồ sơ giả ----------
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHD1C01', 'Phụ huynh giả D2', '0900101002', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSD1C0' || n, (select id from app.parent where code = 'PHD1C01'), 'Em giả D2 ' || n, 2012, pg_temp.cs('CS1') from generate_series(1, 6) n$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('p', 'CB', pg_temp.past(), 3);
select pg_temp.sudo($$select pg_temp.mke('a', 1, true, 10)$$);
select pg_temp.sudo($$select pg_temp.mke('b', 2, true, 10)$$);
select pg_temp.sudo($$select pg_temp.mke('c', 3, true, 10)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e('a'), pg_temp.c('p'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('b'), pg_temp.c('p'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('c'), pg_temp.c('p'), pg_temp.past());
select app.close_session(pg_temp.s('p', 1));
select app.close_session(pg_temp.s('p', 2));
select app.close_session(pg_temp.s('p', 3));
-- Buổi 2 và 3 là buổi Kiểm tra (R-V2-18, Q-176).
select pg_temp.sudo($$update app.class_session set type_code = 'KIEM_TRA' where id in (pg_temp.s('p', 2), pg_temp.s('p', 3))$$);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select app.set_attendance_teacher(pg_temp.s('p', n), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT'),
  jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'DI_MUON'), jsonb_build_object('student_id', pg_temp.st(3), 'status_code', 'VANG_CO_PHEP')))
  from generate_series(1, 3) n;

-- Lớp thứ hai có buổi ở tương lai (buổi Nháp), cùng giáo viên gv1.

-- ================= Tình trạng học sinh (tính từ ghi danh) =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((select count(*)::int from jsonb_array_elements(app.list_students('{"status":["DANG_HOC"]}') -> 'rows')), 3, 'Học sinh có ghi danh đã xếp lớp là Đang học (3 em)');
select is((app.list_students('{"status":["TIEM_NANG"]}') ->> 'total')::int, 3, 'Học sinh chưa có ghi danh là Tiềm năng (3 em)');
select is((app.list_students('{"status":["BAO_LUU"]}') ->> 'total')::int, 0, 'Chưa em nào Bảo lưu');
select is((app.list_students() ->> 'total')::int, 6, 'Danh sách học sinh CS1: 6 em');

-- ================= KH-04 danh sách học sinh =================
select is((app.list_students('{"search":"em gia d2 3"}') ->> 'total')::int, 1, 'Tìm học sinh theo tên không dấu');
select is((app.list_students('{}', 'name_asc', 2, 0) -> 'rows' -> 2), null, 'Phân trang: limit 2 chỉ hai dòng');
select is((app.list_students('{}', 'name_asc', 2, 0) ->> 'total')::int, 6, 'Phân trang: tổng vẫn 6');
select is(jsonb_array_length(app.list_students('{"status":["DANG_HOC"]}') -> 'rows' -> 0 -> 'classes'), 1, 'Học sinh đang học có 1 lớp');
select ok((app.list_students('{"status":["DANG_HOC"]}') -> 'rows' -> 0 ->> 'parent_phone') is not null, 'Danh sách học sinh hiện SĐT phụ huynh (cho vai trò CRM)');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((app.list_students() ->> 'total')::int, 6, 'Vai trò CRM có quyền Học sinh · Xem toàn hệ thống: Trưởng cơ sở CS5 thấy cả học sinh CS1');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is((app.list_students() ->> 'total')::int, 3, 'Giáo viên được phân công chỉ thấy 3 học sinh trong lớp của mình');
select is(app.list_students() -> 'rows' -> 0 ->> 'parent_phone', null, 'Giáo viên không thấy SĐT phụ huynh (R-GV-13)');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is((app.list_students() ->> 'total')::int, 0, 'Giáo viên không được phân công không thấy học sinh nào');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.list_parents()$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không xem danh sách phụ huynh');

-- ================= KH-01 danh sách phụ huynh =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.list_parents() ->> 'total')::int, 1, 'Danh sách phụ huynh: 1 phụ huynh giả');
select is((app.list_parents('{"status":["DANG_HOC"]}') ->> 'total')::int, 1, 'Phụ huynh có con đang học');
select is((app.list_parents('{"status":["CHUA_DANG_HOC"]}') ->> 'total')::int, 0, 'Không phụ huynh nào chưa có con đang học');
select is((app.list_parents('{"search":"0900101002"}') ->> 'total')::int, 1, 'Tìm phụ huynh theo SĐT');
select is((app.list_parents('{"search":"khong co ai"}') ->> 'total')::int, 0, 'Tìm không thấy thì 0');
select is((app.list_parents() -> 'rows' -> 0 ->> 'children_count')::int, 6, 'Phụ huynh có 6 con');
select is(app.list_parents() -> 'rows' -> 0 -> 'studying_at', '["CS1"]'::jsonb, 'Đang học tại CS1 (tự tính từ ghi danh)');

-- ================= KH-02 bản ghi phụ huynh =================
select is(jsonb_array_length(app.get_parent_record((select id from app.parent where code = 'PHD1C01')) -> 'children'), 6, 'Bản ghi phụ huynh liệt kê 6 con');
select is((app.get_parent_record((select id from app.parent where code = 'PHD1C01')) -> 'counts' ->> 'enrollments')::int, 3, 'Số đếm ghi danh của phụ huynh: 3');
select is(app.get_parent_record((select id from app.parent where code = 'PHD1C01')) ->> 'is_studying', 'true', 'Phụ huynh có con đang học');
select is(pg_temp.err($$select app.get_parent_record(gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Phụ huynh không tồn tại báo không tìm thấy');

-- ================= KH-05 hồ sơ học sinh =================
select is(app.get_student_record(pg_temp.st(1)) ->> 'status', 'DANG_HOC', 'Hồ sơ em 1: Đang học');
select is(app.get_student_record(pg_temp.st(4)) ->> 'status', 'TIEM_NANG', 'Hồ sơ em 4: Tiềm năng');
select is(jsonb_array_length(app.get_student_record(pg_temp.st(1)) -> 'enrollments'), 1, 'Em 1 có 1 ghi danh');
select ok(app.get_student_record(pg_temp.st(1)) -> 'enrollments' -> 0 ->> 'class_code' is not null, 'Ghi danh của em 1 có lớp');
select is(jsonb_array_length(app.get_student_record(pg_temp.st(1)) -> 'attendance'), 3, 'Em 1 có 3 buổi điểm danh');
select ok(app.get_student_record(pg_temp.st(1)) ? 'attendance_summary', 'Hồ sơ có tổng kết điểm danh');
select is(app.get_student_record(pg_temp.st(1)) -> 'parent' ->> 'full_name', 'Phụ huynh giả D2', 'Hồ sơ có tên phụ huynh');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.get_student_record(pg_temp.st(1))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không xem hồ sơ học sinh (R-GV-13)');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(app.get_student_record(pg_temp.st(1)) -> 'parent' ->> 'phone', null, 'Giáo viên được phân công xem hồ sơ nhưng không thấy SĐT phụ huynh');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(app.get_student_record(pg_temp.st(1)) ->> 'code', 'HSD1C01', 'Admin xem được hồ sơ học sinh mọi cơ sở');

-- ================= Tình trạng học sinh theo trạng thái ghi danh (quy tắc hiển thị tạm) =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select pg_temp.sudo($$update app.enrollment set status_code = 'CHO_XEP_LOP' where id = pg_temp.e('a')$$);
select is(app.get_student_record(pg_temp.st(1)) ->> 'status', 'DANG_HOC', 'Ghi danh Chờ xếp lớp tính là Đang học');
select pg_temp.sudo($$update app.enrollment set status_code = 'BAO_LUU' where id = pg_temp.e('a')$$);
select is(app.get_student_record(pg_temp.st(1)) ->> 'status', 'BAO_LUU', 'Chỉ có ghi danh Bảo lưu là Bảo lưu');
select pg_temp.sudo($$update app.enrollment set status_code = 'HOAN_THANH' where id = pg_temp.e('a')$$);
select is(app.get_student_record(pg_temp.st(1)) ->> 'status', 'DUNG', 'Ghi danh Hoàn thành là Dừng học');
select pg_temp.sudo($$update app.enrollment set status_code = 'CHUYEN_LOP' where id = pg_temp.e('a')$$);
select is(app.get_student_record(pg_temp.st(1)) ->> 'status', 'DUNG', 'Ghi danh Chuyển lớp là Dừng học');
select pg_temp.sudo($$update app.enrollment set status_code = 'HOAN_PHI' where id = pg_temp.e('a')$$);
select is(app.get_student_record(pg_temp.st(1)) ->> 'status', 'DUNG', 'Ghi danh Hoàn phí là Dừng học');
select is((app.list_students('{"status":["DUNG"]}') ->> 'total')::int, 1, 'Lọc Dừng học thấy em 1');
select pg_temp.sudo($$update app.enrollment set status_code = 'BAO_LUU' where id = pg_temp.e('a')$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code)
  select 'GDTMP-1', e.student_id, e.parent_id, e.branch_id, e.subject_code, 'DANG_HOC' from app.enrollment e where e.id = pg_temp.e('a')$$);
select is(app.get_student_record(pg_temp.st(1)) ->> 'status', 'DANG_HOC', 'Vừa Bảo lưu vừa Đang học: Đang học thắng');

select * from finish();
rollback;
