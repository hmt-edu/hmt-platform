-- GV-18 (migration 598): LMS chấm bài nộp online. Luật: R-LMS-01 (cả lớp hoặc từng em, hạn mặc định giờ vào buổi sau, hai công tắc), R-LMS-04 (tệp 10 MB, 20 trang),
-- Luật: R-GV-11 (thang 1–5, năm trạng thái), R-LMS-02 (nhãn Nộp muộn; em chưa nộp), R-LMS-03 (chấm xong khoá, mở lại), Q5, Q6, Q12, Q14. Dữ liệu giả.
-- Trường hợp đúng và bị chặn: giáo viên khác, Sale chỉ Xem, em chưa nộp, em vắng, xung đột phiên bản, bài đã gỡ.
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
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHD1C01', 'Phụ huynh giả GV11', '0900101002', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSD1C0' || n, (select id from app.parent where code = 'PHD1C01'), 'Em giả GV11 ' || n, 2012, pg_temp.cs('CS1') from generate_series(1, 6) n$$);
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
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
-- Em 1 Có mặt, em 2 Đi muộn, em 3 Vắng có phép ở cả 3 buổi.
select app.set_attendance_teacher(pg_temp.s('p', n), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT'),
  jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'DI_MUON'), jsonb_build_object('student_id', pg_temp.st(3), 'status_code', 'VANG_CO_PHEP')))
  from generate_series(1, 3) n;
-- Điểm tiêu chí buổi 1: em 1 được 3 và 5 (trung bình 4); em 3 (vắng) có điểm 1 nhưng không được tính (R-GV-04); em 2 chưa có điểm (R-GV-02).
select pg_temp.sudo($$insert into app.session_review_criterion (session_id, branch_id, criterion_id, group_code, name, sort_order)
  select s.id, s.branch_id, rc.id, rc.group_code, rc.name, rc.sort_order
    from app.class_session s join app.class c on c.id = s.class_id join lateral app.review_criteria_for_subject(c.subject_code) rc on true
   where s.id = pg_temp.s('p', 1) order by rc.sort_order limit 2 on conflict do nothing$$);
select pg_temp.sudo($$insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score)
  select sa.session_id, sa.branch_id, rc.id, sa.id, 'DA_DANH_GIA', case when rc.sort_order = (select min(sort_order) from app.session_review_criterion where session_id = sa.session_id) then 3 else 5 end
    from app.session_attendance sa join app.session_review_criterion rc on rc.session_id = sa.session_id
   where sa.session_id = pg_temp.s('p', 1) and sa.student_id = pg_temp.st(1)$$);
select pg_temp.sudo($$insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score)
  select sa.session_id, sa.branch_id, rc.id, sa.id, 'DA_DANH_GIA', 1
    from app.session_attendance sa join app.session_review_criterion rc on rc.session_id = sa.session_id
   where sa.session_id = pg_temp.s('p', 1) and sa.student_id = pg_temp.st(3) limit 1$$);
-- BTVN giao ở buổi 2; buổi 1 không giao (R-V2-35).
select pg_temp.sudo($$insert into app.session_content (session_id, branch_id, homework_text) values (pg_temp.s('p', 2), pg_temp.cs('CS1'), 'Làm bài 1 đến 5 trang 10')$$);
-- Lớp thứ hai ở tương lai; ép buổi 1 sang Done (chỉ để thử: buổi Done không có nhãn dù lần cập nhật cuối nằm trước hạn).
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('f', 'CB', pg_temp.fut(), 2);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');


-- Em thứ tư xếp vào lớp tương lai 'f' để thử hạn mặc định (giờ vào buổi sau).
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.sudo($$select pg_temp.mke('d', 4, true, 10)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e('d'), pg_temp.c('f'), pg_temp.fut());
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
create function pg_temp.mk(p_json jsonb) returns uuid language sql volatile as $$ select (app.lms_create_assignment(p_json) ->> 'id')::uuid $$;
grant execute on function pg_temp.mk(jsonb) to public;
create function pg_temp.starts(p_id uuid) returns timestamptz language sql stable as $$ select ((x.session_date + x.start_time)::timestamp at time zone 'Asia/Ho_Chi_Minh') from app.class_session x where x.id = p_id $$;
grant execute on function pg_temp.starts(uuid) to public;
create temp table asg (key text primary key, id uuid);
grant all on asg to public;
create function pg_temp.a(p_key text) returns uuid language sql stable as $$ select id from asg where key = p_key $$;
grant execute on function pg_temp.a(text) to public;
create function pg_temp.ver(p_key text) returns integer language sql stable security definer as $$ select version from app.lms_assignment where id = pg_temp.a(p_key) $$;
grant execute on function pg_temp.ver(text) to public;


select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'HOC_TAP', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
-- Bài giao ở buổi 3 của lớp p cho cả lớp (3 em: em 1 Có mặt, em 2 Đi muộn, em 3 Vắng có phép ở buổi 3).
insert into asg values ('b', pg_temp.mk(jsonb_build_object('session_id', pg_temp.s('p', 3), 'title', 'Bài chấm', 'description', 'Làm bài 1 đến 5', 'due_at', now() + interval '1 day')));
-- Em 1 đã nộp đúng hạn; em 2 nộp muộn (nộp lại 2 lần); em 3 chưa nộp (vắng buổi giao).
select pg_temp.sudo($$insert into app.lms_submission (assignment_id, student_id, attempt_count, submitted_at, is_late) values
  (pg_temp.a('b'), pg_temp.st(1), 1, now(), false), (pg_temp.a('b'), pg_temp.st(2), 2, now(), true)$$);
select pg_temp.sudo($$insert into app.lms_submission_file (submission_id, page_no, storage_key, byte_size, mime_type)
  select id, 1, 'k/1', 1000, 'image/png' from app.lms_submission where assignment_id = pg_temp.a('b') and student_id = pg_temp.st(1)$$);

-- ================= Danh sách em =================
select is(app.lms_grading_list(pg_temp.a('b')) -> 'assignment' ->> 'targets', '3', 'Danh sách: 3 em nhận bài');
select is(app.lms_grading_list(pg_temp.a('b')) -> 'assignment' ->> 'submitted', '2', 'Danh sách: 2 em đã nộp');
select is(app.lms_grading_list(pg_temp.a('b')) -> 'assignment' ->> 'graded', '0', 'Danh sách: chưa chấm em nào (tiến độ 0/3)');
select is((select x ->> 'is_late' from jsonb_array_elements(app.lms_grading_list(pg_temp.a('b')) -> 'rows') x where x ->> 'student_code' = 'HSD1C02'), 'true', 'R-LMS-02: em nộp muộn có nhãn Nộp muộn');
select is((select x ->> 'submit_state' from jsonb_array_elements(app.lms_grading_list(pg_temp.a('b')) -> 'rows') x where x ->> 'student_code' = 'HSD1C03'), 'CHUA_NOP', 'Em chưa nộp: trạng thái nộp CHUA_NOP');
select is(jsonb_array_length(app.lms_grading_list(pg_temp.a('b'), 'CHUA_CHAM') -> 'rows'), 3, 'Lọc Chưa chấm: 3 em');
select is(jsonb_array_length(app.lms_grading_list(pg_temp.a('b'), 'DA_CHAM') -> 'rows'), 0, 'Lọc Đã chấm: 0 em');
select is(pg_temp.err($$select app.lms_grading_list(pg_temp.a('b'), 'SAI')$$), 'HMT_THAM_SO_SAI', 'Chặn: bộ lọc không hợp lệ');

-- ================= Phiếu chấm: trạng thái được chọn (R-LMS-02, Q6) =================
select is(app.lms_grading_sheet(pg_temp.a('b'), pg_temp.st(1)) -> 'allowed_statuses', '["DA_CHAM","LAM_CHUA_XONG","KHONG_LAM","NOP_SAU","KHONG_AP_DUNG"]'::jsonb, 'Em đã nộp: đủ năm trạng thái');
select is(jsonb_array_length(app.lms_grading_sheet(pg_temp.a('b'), pg_temp.st(1)) -> 'submission' -> 'pages'), 1, 'Phiếu chấm có các trang bài nộp');
select is(app.lms_grading_sheet(pg_temp.a('b'), pg_temp.st(3)) ->> 'default_status', 'KHONG_AP_DUNG', 'Q6: em vắng buổi giao mà chưa nộp mặc định Không áp dụng');
select is(app.lms_grading_sheet(pg_temp.a('b'), pg_temp.st(3)) -> 'allowed_statuses', '["KHONG_AP_DUNG","NOP_SAU","KHONG_LAM"]'::jsonb, 'Q6: em vắng chưa nộp đổi được sang Nộp sau hoặc Không làm');
select is(pg_temp.err($$select app.lms_grading_sheet(pg_temp.a('b'), pg_temp.st(5))$$), 'HMT_LMS_EM_KHONG_NHAN_BAI', 'Chặn: em không nhận bài này');

-- ================= Lưu điểm =================
select is((app.lms_save_grade(pg_temp.a('b'), pg_temp.st(1), 'DA_CHAM', 5, ' Tốt ', 0) ->> 'version')::int, 1, 'R-GV-11: chấm Đã chấm điểm 5, phiên bản dòng BTVN = 1');
select is((select score::int from app.homework_result where session_id = pg_temp.s('p', 3) and student_id = pg_temp.st(1)), 5, 'Q1: điểm ghi vào BTVN của buổi giao (không bảng điểm thứ hai)');
select is((select note from app.homework_result where session_id = pg_temp.s('p', 3) and student_id = pg_temp.st(1)), 'Tốt', 'Ghi chú được cắt khoảng trắng');
select isnt((select graded_at from app.lms_submission where assignment_id = pg_temp.a('b') and student_id = pg_temp.st(1)), null, 'R-LMS-03: chấm xong đóng dấu đã chấm (khoá bài nộp)');
select is(app.lms_grading_list(pg_temp.a('b')) -> 'assignment' ->> 'graded', '1', 'Tiến độ đã chấm 1/3');
select is(jsonb_array_length(app.lms_grading_list(pg_temp.a('b'), 'CHUA_CHAM') -> 'rows'), 2, 'Lọc Chưa chấm còn 2 em');
select is(pg_temp.err($$select app.lms_save_grade(pg_temp.a('b'), pg_temp.st(1), 'DA_CHAM', 4, null, 0)$$), 'HMT_XUNG_DOT', 'Q-243 chặn: chấm lại với phiên bản cũ thì từ chối');
select is((app.lms_save_grade(pg_temp.a('b'), pg_temp.st(1), 'LAM_CHUA_XONG', 3, null, 1) ->> 'version')::int, 2, 'Chấm lại đúng phiên bản: Làm chưa xong vẫn có điểm 3');
-- Q5: chọn Không làm thì bỏ điểm đã chọn.
select ok(app.lms_save_grade(pg_temp.a('b'), pg_temp.st(2), 'KHONG_LAM', 4, null, null) is not null, 'Q5: Không làm kèm điểm 4 vẫn lưu được');
select is((select score::int from app.homework_result where session_id = pg_temp.s('p', 3) and student_id = pg_temp.st(2)), null, 'Q5: Không làm thì điểm đã chọn bị bỏ');
select is(pg_temp.err($$select app.lms_save_grade(pg_temp.a('b'), pg_temp.st(1), 'DA_CHAM', 6, null, null)$$), 'HMT_DIEM_KHONG_HOP_LE', 'R-GV-11 chặn: điểm ngoài 1–5');
select is(pg_temp.err($$select app.lms_save_grade(pg_temp.a('b'), pg_temp.st(1), 'DA_CHAM', null, null, null)$$), 'HMT_DIEM_KHONG_HOP_LE', 'R-GV-11 chặn: Đã chấm mà không có điểm');
-- Em chưa nộp (vắng): Không áp dụng được; chấm điểm bị chặn; Nộp sau chưa đóng dấu.
select is(pg_temp.err($$select app.lms_save_grade(pg_temp.a('b'), pg_temp.st(3), 'DA_CHAM', 5, null, null)$$), 'HMT_LMS_CHUA_NOP_BAI', 'R-LMS-02 chặn: em chưa nộp không chấm điểm được');
select ok(app.lms_save_grade(pg_temp.a('b'), pg_temp.st(3), 'KHONG_AP_DUNG', null, null, null) is not null, 'Q6: em vắng chưa nộp: Không áp dụng lưu được');
select ok(app.lms_save_grade(pg_temp.a('b'), pg_temp.st(3), 'NOP_SAU', null, null, null) is not null, 'Em chưa nộp: Nộp sau lưu được');
select is((select graded_at from app.lms_submission where assignment_id = pg_temp.a('b') and student_id = pg_temp.st(3)), null, 'Nộp sau chưa phải chấm xong: chưa đóng dấu đã chấm');

-- ================= Mở lại (R-LMS-03, Q12) =================
select is(pg_temp.err($$select app.lms_reopen_submission(pg_temp.a('b'), pg_temp.st(3))$$), 'HMT_LMS_CHUA_CHAM', 'Chặn: bài chưa chấm thì không cần mở lại');
select ok(app.lms_reopen_submission(pg_temp.a('b'), pg_temp.st(1)) is not null, 'R-LMS-03: mở lại bài đã chấm');
select is((select graded_at from app.lms_submission where assignment_id = pg_temp.a('b') and student_id = pg_temp.st(1)), null, 'Mở lại gỡ dấu đã chấm');
select isnt((select reopened_at from app.lms_submission where assignment_id = pg_temp.a('b') and student_id = pg_temp.st(1)), null, 'Mở lại ghi giờ mở lại');
select is((select score::int from app.homework_result where session_id = pg_temp.s('p', 3) and student_id = pg_temp.st(1)), 3, 'Điểm cũ giữ đến khi chấm lại');

-- ================= Người không có quyền (Q14) =================
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.lms_grading_list(pg_temp.a('b'))$$), 'HMT_KHONG_CO_QUYEN', 'R-GV-08 chặn: giáo viên khác không xem danh sách chấm');
select is(pg_temp.err($$select app.lms_grading_sheet(pg_temp.a('b'), pg_temp.st(1))$$), 'HMT_KHONG_CO_QUYEN', 'R-GV-08 chặn: giáo viên khác không mở phiếu chấm');
select is(pg_temp.err($$select app.lms_save_grade(pg_temp.a('b'), pg_temp.st(1), 'DA_CHAM', 5, null, null)$$), 'HMT_KHONG_CO_QUYEN', 'R-GV-08 chặn: giáo viên khác không chấm');
select is(pg_temp.err($$select app.lms_reopen_submission(pg_temp.a('b'), pg_temp.st(1))$$), 'HMT_KHONG_CO_QUYEN', 'R-GV-08 chặn: giáo viên khác không mở lại');
select is((select count(*)::int from app.homework_result where session_id = pg_temp.s('p', 3)), 0, 'RLS: giáo viên khác không đọc được kết quả BTVN của buổi');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.lms_save_grade(pg_temp.a('b'), pg_temp.st(1), 'DA_CHAM', 5, null, null)$$), 'HMT_KHONG_CO_QUYEN', 'Q14 chặn: Sale (chỉ Xem) không chấm được');
select is(pg_temp.err($$select app.lms_reopen_submission(pg_temp.a('b'), pg_temp.st(1))$$), 'HMT_KHONG_CO_QUYEN', 'Q14 chặn: Sale (chỉ Xem) không mở lại được');

-- ================= Bài đã gỡ, quyền gọi hàm =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
insert into asg values ('g', pg_temp.mk(jsonb_build_object('session_id', pg_temp.s('p', 3), 'title', 'Bài gỡ', 'description', 'x', 'due_at', now() + interval '2 days', 'audience', 'CHON_EM', 'student_ids', jsonb_build_array(pg_temp.st(1)))));
select app.lms_withdraw_assignment(pg_temp.a('g'), 1);
select is(pg_temp.err($$select app.lms_save_grade(pg_temp.a('g'), pg_temp.st(1), 'KHONG_LAM', null, null, null)$$), 'HMT_LMS_DA_GO', 'Chặn: bài đã gỡ không chấm được');
select is(pg_temp.err($$select app.lms_reopen_submission(pg_temp.a('g'), pg_temp.st(1))$$), 'HMT_LMS_DA_GO', 'Chặn: bài đã gỡ không mở lại được');
select is(has_function_privilege('anon', 'app.lms_save_grade(uuid, uuid, text, integer, text, integer)', 'execute'), false, 'Người chưa đăng nhập không gọi được hàm chấm');
select is(has_function_privilege('authenticated', 'app.lms_student_absent(uuid, uuid)', 'execute'), false, 'Hàm trợ giúp không mở cho giao diện');

select * from finish();
rollback;
