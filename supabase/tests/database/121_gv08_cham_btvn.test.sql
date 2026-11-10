-- GV-08 (migration 121): chấm BTVN buổi trước, bài Nộp sau, bước chấm BTVN chặn Done khi Bật (Q-272).
-- Luật: R-GV-10, R-GV-11, R-GV-12, R-GV-08, R-GV-13, R-GIO-06. Dữ liệu giả; ngày tính từ hôm nay.
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


-- Buổi 1: em 2 vắng không phép, em 3 có mặt. Buổi 2: em 1, em 2 có mặt, em 3 vắng có phép.
select pg_temp.sudo($$update app.session_attendance set teacher_status_code = 'VANG_KHONG_PHEP' where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(2)$$);
select pg_temp.sudo($$update app.session_attendance set teacher_status_code = 'CO_MAT' where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(3)$$);
select pg_temp.sudo($$update app.session_attendance set teacher_status_code = 'CO_MAT' where session_id = pg_temp.s('p', 2) and student_id = pg_temp.st(2)$$);

-- ================= Bỏ qua khi không có gì để chấm (R-V2-35, R-GIO-06) =================
select is(app.homework_grading_sheet(pg_temp.s('p', 1)) ->> 'state', 'DAU_LOP', 'Buổi đầu của lớp: DAU_LOP, không có BTVN để chấm');
select is(app.homework_grading_sheet(pg_temp.s('p', 2)) ->> 'state', 'KHONG_GIAO', 'Buổi trước không giao BTVN: KHONG_GIAO, bỏ qua');
select is(pg_temp.err($$select app.save_homework_grading(pg_temp.s('p', 2), '[]'::jsonb)$$), 'HMT_KHONG_CO_BTVN_DE_CHAM', 'Chặn: buổi trước không giao BTVN thì không chấm được');
select is(app.session_overview(pg_temp.s('p', 2)) ->> 'prev_homework_state', 'KHONG_GIAO', 'Tiến độ buổi: KHONG_GIAO');

-- ================= Chấm BTVN buổi trước (R-GV-10, R-GV-11) =================
select app.save_session_content(pg_temp.s('p', 1), array['Phương trình bậc nhất'], 'Bài 1 đến bài 5 trang 42');
select is(app.homework_grading_sheet(pg_temp.s('p', 2)) ->> 'state', 'CAN_CHAM', 'Buổi trước có giao BTVN: CAN_CHAM');
select is(app.homework_grading_sheet(pg_temp.s('p', 2)) -> 'prev' ->> 'homework_text', 'Bài 1 đến bài 5 trang 42', 'Màn chấm có nội dung BTVN đã giao');
select is(jsonb_array_length(app.homework_grading_sheet(pg_temp.s('p', 2)) -> 'students'), 2, 'Danh sách chấm: 2 em có mặt (em 3 vắng buổi này không phải chấm)');
select is((select e ->> 'absent_at_assignment' from jsonb_array_elements(app.homework_grading_sheet(pg_temp.s('p', 2)) -> 'students') e where e ->> 'student_id' = pg_temp.st(2)::text), 'true', 'Em 2 vắng buổi giao bài: đặt sẵn Không áp dụng (R-GV-11)');
select is(jsonb_array_length(app.homework_grading_sheet(pg_temp.s('p', 2)) -> 'absent_now'), 1, 'Em 3 có mặt buổi giao bài, vắng buổi chấm: nằm ở mục Em vắng buổi này');
select is((app.homework_grading_sheet(pg_temp.s('p', 2)) ->> 'present')::int, 2, 'Số em cần có trạng thái: 2');
select is((app.homework_grading_sheet(pg_temp.s('p', 2)) ->> 'done')::int, 1, 'Em 2 vắng buổi giao bài đã tính có trạng thái; em 1 chưa: 1/2');
select is(app.session_overview(pg_temp.s('p', 2)) -> 'homework_missing', to_jsonb(array['Em giả D2 1']), 'Tiến độ buổi liệt kê tên em còn thiếu');
select is(app.session_overview(pg_temp.s('p', 2)) ->> 'pending_reason', 'Giáo viên chưa chấm BTVN buổi trước cho 1 em.', 'Q-272: tham số Bật thì thiếu chấm BTVN buổi trước chặn Done và nêu lý do');

select is(pg_temp.err($$select app.save_homework_grading(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'DA_CHAM')))$$), 'HMT_DIEM_KHONG_HOP_LE', 'Chặn: Đã chấm cần điểm');
select is(pg_temp.err($$select app.save_homework_grading(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'LAM_CHUA_XONG', 'score', 6)))$$), 'HMT_DIEM_KHONG_HOP_LE', 'Chặn: điểm ngoài 1 đến 5');
select is(pg_temp.err($$select app.save_homework_grading(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'KHONG_CO_TRONG_DANH_MUC')))$$) is not null, true, 'Chặn: trạng thái ngoài danh mục');
select is(pg_temp.err($$select app.save_homework_grading(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(3), 'status_code', 'KHONG_LAM')))$$), 'HMT_EM_KHONG_CO_MAT', 'Chặn: em vắng buổi này không chấm trong buổi này');
select is(app.save_homework_grading(pg_temp.s('p', 2), jsonb_build_array(
  jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'DA_CHAM', 'score', 4, 'note', 'Làm tốt', 'expected_version', 0))), 1, 'Giáo viên chấm em 1: Đã chấm 4 điểm');
select is((app.homework_grading_sheet(pg_temp.s('p', 2)) ->> 'done')::int, 2, 'Sau khi chấm: 2/2 em có trạng thái');
select is(app.session_overview(pg_temp.s('p', 2)) ->> 'homework_missing', '[]', 'Không còn em thiếu');
select isnt(app.session_overview(pg_temp.s('p', 2)) ->> 'pending_reason', 'Giáo viên chưa chấm BTVN buổi trước cho 1 em.', 'Đủ trạng thái thì hết lý do BTVN');
select is((select e -> 'result' ->> 'score' from jsonb_array_elements(app.homework_grading_sheet(pg_temp.s('p', 2)) -> 'students') e where e ->> 'student_id' = pg_temp.st(1)::text), '4', 'Điểm đã lưu');

-- Không làm không phải điểm 0 (R-GV-12): không có điểm.
select app.save_homework_grading(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'KHONG_LAM', 'expected_version', 1)));
select is((select score from app.homework_result where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(1)), null, 'Không làm: không có điểm, không phải điểm 0 (R-GV-12)');
select is((select version from app.homework_result where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(1)), 2, 'Mỗi lần lưu tăng phiên bản dòng');

-- ================= Hai người cùng sửa (Q-243) =================
select is(pg_temp.err($$select app.save_homework_grading(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'DA_CHAM', 'score', 5, 'expected_version', 1)))$$), 'HMT_XUNG_DOT', 'Chặn: phiên bản cũ thì báo xung đột, không ghi đè');
select is((select status_code from app.homework_result where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(1)), 'KHONG_LAM', 'Xung đột: dữ liệu giữ nguyên');

-- ================= Nộp sau, cập nhật không mở lại buổi cũ (R-GV-11) =================
select app.save_homework_grading(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'NOP_SAU', 'expected_version', 2)));
select is((select count(*)::int from jsonb_array_elements(app.homework_grading_sheet(pg_temp.s('p', 2)) -> 'late') l where l ->> 'student_id' = pg_temp.st(1)::text), 1, 'Bài Nộp sau lên danh sách chờ cập nhật');
select is((select (l ->> 'inferred')::boolean from jsonb_array_elements(app.homework_grading_sheet(pg_temp.s('p', 2)) -> 'late') l where l ->> 'student_id' = pg_temp.st(3)::text), true, 'Em vắng buổi chấm (có mặt buổi giao bài) vào Nộp sau, suy ra từ điểm danh');
select is(pg_temp.err($$select app.update_late_homework(pg_temp.s('p', 1), pg_temp.st(1), 'DA_CHAM', 7)$$), 'HMT_DIEM_KHONG_HOP_LE', 'Chặn: cập nhật Nộp sau với điểm sai');
select app.update_late_homework(pg_temp.s('p', 1), pg_temp.st(1), 'DA_CHAM', 3, 'Nộp muộn', 3);
select is((select score from app.homework_result where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(1)), 3::smallint, 'Cập nhật bài Nộp sau thành Đã chấm 3 điểm');
select is(pg_temp.err($$select app.update_late_homework(pg_temp.s('p', 1), pg_temp.st(1), 'KHONG_LAM')$$), 'HMT_BTVN_DA_CHAM', 'Chặn: chỉ cập nhật được bài đang Nộp sau');
select app.update_late_homework(pg_temp.s('p', 1), pg_temp.st(3), 'LAM_CHUA_XONG', 2);
select is((select status_code from app.homework_result where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(3)), 'LAM_CHUA_XONG', 'Em vắng buổi chấm nộp bài: giáo viên chấm khi em nộp');
select is(pg_temp.err($$select app.update_late_homework(pg_temp.s('p', 1), pg_temp.st(2), 'DA_CHAM', 3)$$), 'HMT_EM_KHONG_CO_MAT', 'Chặn: em vắng buổi giao bài không có bài Nộp sau');
select is((select count(*)::int from jsonb_array_elements(app.homework_grading_sheet(pg_temp.s('p', 2)) -> 'late')), 0, 'Hết bài Nộp sau chờ');

-- ================= Tham số Tắt không chặn (Q-272) =================
-- Xoá cứng chỉ để dựng lại tình huống thử (tắt tạm trigger chặn xoá).
select pg_temp.sudo($$alter table app.homework_result disable trigger user$$);
select pg_temp.sudo($$delete from app.homework_result where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(1)$$);
select pg_temp.sudo($$alter table app.homework_result enable trigger user$$);
select is(app.session_overview(pg_temp.s('p', 2)) ->> 'pending_reason', 'Giáo viên chưa chấm BTVN buổi trước cho 1 em.', 'Bật: thiếu một em thì chặn');
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'session_done_requires_review'$$);
select isnt(app.session_overview(pg_temp.s('p', 2)) ->> 'pending_reason', 'Giáo viên chưa chấm BTVN buổi trước cho 1 em.', 'Tắt: bước chấm BTVN không chặn Done (Q-272)');
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'session_done_requires_review'$$);

-- ================= Quyền (R-GV-08, R-GV-13) =================
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.homework_grading_sheet(pg_temp.s('p', 2))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không xem màn chấm');
select is(pg_temp.err($$select app.save_homework_grading(pg_temp.s('p', 2), '[]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không chấm');
select is(pg_temp.err($$select app.update_late_homework(pg_temp.s('p', 1), pg_temp.st(1), 'DA_CHAM', 3)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không cập nhật Nộp sau');
select is((select count(*)::int from app.homework_result), 0, 'RLS: giáo viên không được phân công không đọc được kết quả BTVN');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is((select count(*)::int from jsonb_object_keys(app.homework_grading_sheet(pg_temp.s('p', 2))) k where k in ('phone', 'parent', 'fee')), 0, 'Không có thông tin phụ huynh, học phí (R-GV-13)');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.homework_grading_sheet(pg_temp.s('p', 2))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: trưởng cơ sở khác không xem');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');

-- ================= Buổi đã Done =================
select pg_temp.sudo($$update app.class_session set status_code = 'DONE' where id = pg_temp.s('p', 2)$$);
select is(pg_temp.err($$select app.save_homework_grading(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'KHONG_LAM')))$$), 'HMT_BUOI_DA_DONE', 'Chặn: buổi đã Done thì giáo viên không chấm nữa');

-- ================= GV-07: màn Chấm nhận xét từng em (đọc một lần, lưu một lần) =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(jsonb_array_length(app.review_grading_sheet(pg_temp.s('p', 1)) -> 'criteria'), 0, 'Chưa mở nhận xét: chưa có tiêu chí của buổi');
select is(jsonb_array_length(app.review_grading_sheet(pg_temp.s('p', 1)) -> 'students'), 3, 'Màn nhận xét liệt kê mọi em trong danh sách buổi (kể cả em vắng)');
select is(app.save_review_grading(pg_temp.s('p', 1), '[]', jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1),
  'criterion_id', (select id from app.review_criterion where name = 'Tập trung' limit 1), 'state', 'DA_DANH_GIA', 'score', 4)),
  jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'comment', 'Tập trung tốt', 'improvement', 'Làm thêm bài')))
  >= 2, true, 'Lưu một lần: mở nhận xét, ghi điểm và nhận xét chung');
select is(jsonb_array_length(app.review_grading_sheet(pg_temp.s('p', 1)) -> 'criteria'), 9, 'Sau khi lưu, buổi có 9 tiêu chí (R-V2-19)');
select is((select e -> 'scores' -> (select id::text from app.review_criterion where name = 'Tập trung' limit 1) ->> 'score'
             from jsonb_array_elements(app.review_grading_sheet(pg_temp.s('p', 1)) -> 'students') e where e ->> 'student_id' = pg_temp.st(1)::text), '4', 'Điểm đã lưu hiện đúng trên màn');
select is((select e ->> 'comment' from jsonb_array_elements(app.review_grading_sheet(pg_temp.s('p', 1)) -> 'students') e where e ->> 'student_id' = pg_temp.st(1)::text), 'Tập trung tốt', 'Nhận xét chung đã lưu');
select is((select (e ->> 'average')::numeric from jsonb_array_elements(app.review_grading_sheet(pg_temp.s('p', 1)) -> 'students') e where e ->> 'student_id' = pg_temp.st(1)::text), 4::numeric, 'Điểm trung bình do DB tính trên ô Đã đánh giá (R-GV-03)');
select is(pg_temp.err($$select app.save_review_grading(pg_temp.s('p', 1), '[]', jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(2),
  'criterion_id', (select id from app.review_criterion where name = 'Tập trung' limit 1), 'state', 'DA_DANH_GIA', 'score', 3)), '[]')$$), 'HMT_EM_KHONG_CO_MAT', 'Chặn: không chấm em vắng (R-GV-04)');
select is(pg_temp.err($$select app.save_review_grading(pg_temp.s('p', 1), '[]', jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1),
  'criterion_id', (select id from app.review_criterion where name = 'Tập trung' limit 1), 'state', 'DA_DANH_GIA', 'score', 9)), '[]')$$), 'HMT_DIEM_KHONG_HOP_LE', 'Chặn: điểm ngoài 1 đến 5');
select is(app.save_review_grading(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('criterion_id', (select id from app.review_criterion where name = 'Tập trung' limit 1), 'enabled', false)), '[]', '[]') >= 1, true, 'Tắt một tiêu chí cho cả buổi');
select is((select (c ->> 'enabled')::boolean from jsonb_array_elements(app.review_grading_sheet(pg_temp.s('p', 1)) -> 'criteria') c
            where c ->> 'criterion_id' = (select id::text from app.review_criterion where name = 'Tập trung' limit 1)), false, 'Tiêu chí đã tắt hiện Không áp dụng cả buổi');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.review_grading_sheet(pg_temp.s('p', 1))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không xem màn nhận xét');
select is(pg_temp.err($$select app.save_review_grading(pg_temp.s('p', 1), '[]', '[]', '[]')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không lưu nhận xét');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select pg_temp.sudo($$update app.class_session set status_code = 'DONE' where id = pg_temp.s('p', 1)$$);
select is(pg_temp.err($$select app.save_review_grading(pg_temp.s('p', 1), '[]', '[]', '[]')$$), 'HMT_BUOI_DA_DONE', 'Chặn: buổi đã Done thì giáo viên không sửa nhận xét');

select * from finish();
rollback;
