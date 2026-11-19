-- Cụm Lớp (migration 116): list_classes, get_class_record, week_sessions. Luật R-LOP-01, R-LOP-05, R-LOP-08, R-LOP-14, R-LOP-15. Dữ liệu giả.
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
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('f', 'CB', pg_temp.fut(), 2);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');

-- ================= Danh sách lớp (LOP-01) =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.list_classes() ->> 'total')::int, 2, 'Trưởng cơ sở CS1 thấy 2 lớp của cơ sở mình');
-- Group By ở máy chủ (migration 309): class_group_counts đếm theo một hoặc hai trường, bộ lọc và phạm vi quyền giống list_classes.
select is((app.class_group_counts('{}', array['status']) ->> 'total')::int, 2, 'Group By: tổng bằng số lớp trong phạm vi của Trưởng cơ sở CS1');
select is(jsonb_array_length(app.class_group_counts('{}', array['status']) -> 'groups'), 1, 'Group By tình trạng duyệt: cả hai lớp cùng Đã duyệt nên một nhóm');
select is((app.class_group_counts('{}', array['status']) -> 'groups' -> 0 ->> 'l1'), 'Đã duyệt', 'Nhóm có nhãn tiếng Việt từ danh mục');
select is((app.class_group_counts('{}', array['subject', 'type']) -> 'groups' -> 0 ->> 'k2') is not null, true, 'Group By hai cấp: có khoá cấp hai');
select is((app.class_group_counts('{"status":["NHAP"]}', array['status']) ->> 'total')::int, 0, 'Group By theo đúng bộ lọc: không lớp Nháp thì tổng 0');
select is(pg_temp.err($$select app.class_group_counts('{}', array['status', 'status'])$$), 'HMT_NHOM_SAI', 'Chặn: hai cấp nhóm phải khác nhau');
select is(pg_temp.err($$select app.class_group_counts('{}', array['khong_co'])$$), 'HMT_NHOM_SAI', 'Chặn: trường nhóm không cho phép');
select is(pg_temp.err($$select app.class_group_counts('{}', array['subject', 'grade', 'type'])$$), 'HMT_NHOM_SAI', 'Chặn: nhóm quá hai cấp');
select is(has_function_privilege('anon', 'app.class_group_counts(jsonb, text[])', 'execute'), false, 'Người chưa đăng nhập không gọi được class_group_counts');
select is((app.list_classes('{"search":"zzz-khong-co"}') ->> 'total')::int, 0, 'Tìm không thấy thì 0 lớp');
select is((app.list_classes(jsonb_build_object('search', (select code from app.class where id = pg_temp.c('p')))) ->> 'total')::int, 1, 'Tìm theo mã lớp');
select is((app.list_classes('{"status":["DA_DUYET"]}') ->> 'total')::int, 2, 'Lọc tình trạng duyệt: cả 2 lớp Đã duyệt');
-- T2 mục 10 (migration 307): mỗi khung của «schedule» có thêm khoá giáo viên, phòng (để danh sách ghi rõ thứ nào do ai dạy, phòng nào).
select ok(exists (select from jsonb_array_elements(app.list_classes() -> 'rows') r, jsonb_array_elements(r -> 'schedule') sl where sl ? 'teacher_name' and sl ? 'room_name'),
  'list_classes: mỗi khung giờ trong schedule có khoá teacher_name và room_name');
select is((app.list_classes('{"status":["NHAP"]}') ->> 'total')::int, 0, 'Lọc tình trạng duyệt: không lớp Nháp');
select is((app.list_classes('{"operating":["CHUA_KHAI_GIANG"]}') ->> 'total')::int, 2, 'Lọc tình trạng vận hành: 2 lớp Chưa khai giảng');
select is((app.list_classes('{"subject_code":"TOAN","grade_code":"K08"}') ->> 'total')::int, 2, 'Lọc môn và khối');
select is((app.list_classes('{}', 'code_asc', 1, 0) -> 'rows' -> 1), null, 'Phân trang: limit 1 chỉ một dòng');
select is((app.list_classes('{}', 'code_asc', 1, 0) ->> 'total')::int, 2, 'Phân trang: tổng vẫn 2');
select is((app.list_classes() -> 'rows' -> 0 ->> 'enrolled')::int, 3, 'Sĩ số: lớp p có 3 em xếp lớp');
select is((app.list_classes('{}', 'code_asc') -> 'rows' -> 0 ->> 'seats_left'), null, 'Sĩ số tối đa 0 = không giới hạn: chỗ còn lại để trống');
select is(jsonb_array_length(app.list_classes() -> 'rows' -> 0 -> 'schedule'), 1, 'Dòng lớp có lịch học theo khung giờ');
select is(app.list_classes() -> 'rows' -> 0 ->> 'teacher_names', 'Giả gv1', 'Dòng lớp có tên giáo viên của khung giờ');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((app.list_classes() ->> 'total')::int, 0, 'Trưởng cơ sở CS5 không thấy lớp của CS1');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.list_classes() ->> 'total')::int, 2, 'Admin thấy toàn hệ thống');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is((app.list_classes() ->> 'total')::int, 0, 'Giáo viên không được phân công không thấy lớp');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is((app.list_classes() ->> 'total')::int, 2, 'Giáo viên thấy lớp được phân công');

-- ================= Hồ sơ lớp (LOP-02) =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(app.get_class_record(pg_temp.c('p')) ->> 'status_code', 'DA_DUYET', 'Hồ sơ lớp có tình trạng duyệt');
select is(jsonb_array_length(app.get_class_record(pg_temp.c('p')) -> 'students'), 3, 'Hồ sơ lớp liệt kê 3 học sinh đang xếp');
-- LOP-02 (migration 310): «Lớp còn lại của nhóm»: lớp chưa vào nhóm thì rỗng; hai lớp cùng nhóm thì mỗi lớp thấy lớp kia (R-LOP-14).
select is(jsonb_array_length(app.get_class_record(pg_temp.c('p')) -> 'group_classes'), 0, 'Lớp chưa thuộc nhóm: không có lớp còn lại của nhóm');
select pg_temp.sudo($$update app.class set subject_code = 'HINH' where id = pg_temp.c('f')$$);
select pg_temp.sudo($$with g as (insert into app.class_group (branch_id, grade_code) select branch_id, grade_code from app.class where id = pg_temp.c('p') returning id)
  update app.class set group_id = (select id from g) where id in (pg_temp.c('p'), pg_temp.c('f'))$$);
select is((app.get_class_record(pg_temp.c('p')) -> 'group_classes' -> 0 ->> 'id')::uuid, pg_temp.c('f'), 'Lớp p thấy lớp f cùng nhóm là lớp còn lại của nhóm');
select is(jsonb_array_length(app.get_class_record(pg_temp.c('f')) -> 'group_classes'), 1, 'Lớp f cũng thấy đúng một lớp còn lại (không tự liệt kê chính nó)');
select is(jsonb_array_length(app.get_class_record(pg_temp.c('p')) -> 'slots'), 1, 'Hồ sơ lớp có 1 khung giờ');
select is((app.get_class_record(pg_temp.c('p')) -> 'session_counts' ->> 'DA_CHOT')::int, 3, 'Đếm buổi theo tình trạng: 3 buổi Đã chốt');
select is((app.get_class_record(pg_temp.c('p')) -> 'students' -> 0) ? 'phone', false, 'Hồ sơ lớp không có số điện thoại học sinh');
select ok(jsonb_array_length(app.get_class_record(pg_temp.c('p')) -> 'events') >= 1, 'Hồ sơ lớp có lịch sử lớp');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.get_class_record(pg_temp.c('p'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở CS5 không xem lớp CS1');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.get_class_record(pg_temp.c('p'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không xem hồ sơ lớp');

-- ================= Lịch tuần cơ sở (LOP-08) =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select ok(jsonb_array_length(app.week_sessions(pg_temp.cs('CS1'), pg_temp.past(), pg_temp.past() + 6)) >= 1, 'Lịch tuần có buổi của lớp p');
select is(jsonb_array_length(app.week_sessions(pg_temp.cs('CS1'), pg_temp.past() + 100, pg_temp.past() + 106)), 0, 'Tuần không có buổi thì rỗng');
select is(pg_temp.err($$select app.week_sessions(pg_temp.cs('CS1'), current_date, current_date + 30)$$), 'HMT_THAM_SO_SAI', 'Chặn: khoảng xem quá 14 ngày');
select is(pg_temp.err($$select app.week_sessions(pg_temp.cs('CS5'), current_date, current_date + 6)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở CS1 không xem lịch tuần cơ sở CS5');
select pg_temp.sudo($$update app.class_session set room_id = (select id from app.room where branch_id = pg_temp.cs('CS1') limit 1)
  where id in (pg_temp.s('p', 1), pg_temp.s('f', 1)) and exists (select from app.room where branch_id = pg_temp.cs('CS1'))$$);
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.week_sessions(pg_temp.cs('CS1'), current_date, current_date + 6)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên (phạm vi được phân công) không xem lịch tuần cơ sở');

-- ================= Lựa chọn cho biểu mẫu LOP-03 =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(jsonb_array_length(app.list_class_form_options(pg_temp.cs('CS1')) -> 'teachers'), 2, 'Biểu mẫu: 2 giáo viên đang hoạt động của CS1');
select ok(app.list_class_form_options(pg_temp.cs('CS1')) -> 'rooms' is not null, 'Biểu mẫu: có danh sách phòng');
select is(jsonb_array_length(app.list_class_form_options(pg_temp.cs('CS1')) -> 'cskh'), 1, 'Biểu mẫu: 1 CSKH của CS1');
select is(pg_temp.err($$select app.list_class_form_options(pg_temp.cs('CS5'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở CS1 không lấy lựa chọn của CS5');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.list_class_form_options(pg_temp.cs('CS1'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không lấy lựa chọn tạo lớp');

select * from finish();
rollback;
