-- P7 (migration 128): tự Done buổi không nuốt lỗi im lặng. Luật: R-GIO-06 (tự Done), R-GD-18 (quỹ giờ không âm). Dữ liệu giả.
-- Đúng: buổi hợp lệ vẫn Done và trừ giờ; lỗi: buổi gây lỗi để lại 1 dòng có mã lỗi, buổi khác cùng lượt vẫn Done; chạy lại không ghi trùng vô hạn.
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
-- D2 (migration 103): Done cần nhận xét 9 tiêu chí. Hàm giả này chụp tiêu chí, chấm mức 3 cho mọi em có mặt và thêm một dòng nội dung buổi (Q-231), để các bài D1c thử Done và trừ giờ.
create function pg_temp.fillreview(p_session uuid) returns void language plpgsql security definer as $$
begin
  insert into app.session_review_criterion (session_id, branch_id, criterion_id, group_code, name, sort_order)
  select s.id, s.branch_id, rc.id, rc.group_code, rc.name, rc.sort_order
    from app.class_session s join app.class c on c.id = s.class_id
    join lateral app.review_criteria_for_subject(c.subject_code) rc on true
   where s.id = p_session
  on conflict do nothing;
  insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score)
  select sa.session_id, sa.branch_id, rc.id, sa.id, 'DA_DANH_GIA', 3
    from app.session_attendance sa join app.session_review_criterion rc on rc.session_id = sa.session_id
   where sa.session_id = p_session and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
  on conflict do nothing;
  -- GV (migration 107, Q-231): buổi thường cần ít nhất một dòng nội dung buổi mới Done được.
  insert into app.session_content_line (session_id, branch_id, sort_order, line_text)
  select s.id, s.branch_id, 1, 'Nội dung buổi giả' from app.class_session s where s.id = p_session
  on conflict do nothing;
end $$;
grant execute on all functions in schema pg_temp to public;

-- Hàm trợ giúp tạo bằng quyền chủ (gọi hàm tự Done vốn chỉ dành cho lịch hệ thống, và đếm bảng nhật ký).
create function pg_temp.run() returns integer language sql security definer as $$ select app.auto_complete_sessions() $$;
grant execute on function pg_temp.run() to public;
create function pg_temp.errs(p_where text) returns bigint language plpgsql security definer as $$
declare n bigint;
begin execute 'select count(*) from app.session_auto_done_error where ' || p_where into n; return n; end $$;
grant execute on function pg_temp.errs(text) to public;
-- Từ đây chạy với vai trò đăng nhập thật (RLS và quyền gọi hàm có hiệu lực).
set local role authenticated;

-- ---------- Hồ sơ giả ----------
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHD1C01', 'Phụ huynh giả P7', '0900101002', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSD1C0' || n, (select id from app.parent where code = 'PHD1C01'), 'Em giả P7 ' || n, 2012, pg_temp.cs('CS1') from generate_series(1, 6) n$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('p', 'CB', pg_temp.past(), 3);
select pg_temp.mkclass('q', 'CB', pg_temp.past(), 1);
-- Em 1 (lớp P) có 4 giờ: buổi 1 và 2 trừ được (còn 1,0), buổi 3 làm quỹ âm nên bị chặn (R-GD-18). Em 2 (lớp Q) có 4 giờ: buổi duy nhất của Q Done bình thường.
select pg_temp.sudo($$select pg_temp.mke('a', 1, true, 4)$$);
select pg_temp.sudo($$select pg_temp.mke('b', 2, true, 4)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e('a'), pg_temp.c('p'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('b'), pg_temp.c('q'), pg_temp.past());
select app.close_session(pg_temp.s('p', 1));
select app.close_session(pg_temp.s('p', 2));
select app.close_session(pg_temp.s('p', 3));
-- G1 (migration 304): chốt buổi 3 với 4 giờ đã giữ chỗ 3 giờ ở buổi 1, 2 nên em không còn vào danh sách buổi 3 nữa. Bài này kiểm đường LỖI của tự Done (quỹ âm, R-GD-18)
-- nên dựng tay dòng điểm danh buổi 3 như dữ liệu chốt từ trước G1.
select pg_temp.sudo($$insert into app.session_attendance (session_id, class_id, branch_id, student_id, enrollment_id, is_active)
  select pg_temp.s('p', 3), s.class_id, s.branch_id, pg_temp.st(1), pg_temp.e('a'), true from app.class_session s where s.id = pg_temp.s('p', 3)
  on conflict (session_id, student_id) do update set enrollment_id = excluded.enrollment_id, is_active = true, excluded_reason = null$$);
select app.close_session(pg_temp.s('q', 1));
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select app.set_attendance_teacher(pg_temp.s('p', n), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT'))) from generate_series(1, 3) n;
select app.set_attendance_teacher(pg_temp.s('q', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'CO_MAT')));
select pg_temp.sudo($$select pg_temp.fillreview(pg_temp.s('p', n)) from generate_series(1, 3) n$$);
select pg_temp.sudo($$select pg_temp.fillreview(pg_temp.s('q', 1))$$);
select is((select count(*)::int from app.class_session where status_code = 'DA_CHOT' and class_id in (pg_temp.c('p'), pg_temp.c('q'))), 4, 'Chuẩn bị: 4 buổi Đã chốt, đủ điều kiện Done');

-- ================= Lượt chạy 1: ba buổi Done, một buổi lỗi quỹ giờ âm =================
-- Từ đây đọc nhật ký lỗi bằng tài khoản Quản trị (chỉ Quản trị đọc được, kiểm riêng ở cuối).
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.run(), 3, 'Lượt 1: 3 buổi Done, buổi lỗi không chặn buổi khác (R-GIO-06)');
select is((select status_code from app.class_session where id = pg_temp.s('p', 1)), 'DONE', '(a) buổi hợp lệ vẫn Done');
select is((select status_code from app.class_session where id = pg_temp.s('q', 1)), 'DONE', '(b) buổi của lớp khác cùng lượt vẫn Done dù có buổi lỗi');
select is(app.enrollment_hours_balance(pg_temp.e('a')), 1.00::numeric, '(a) trừ giờ như cũ: 4,0 − 1,5 − 1,5 = 1,0');
select is(app.enrollment_hours_balance(pg_temp.e('b')), 2.50::numeric, 'Trừ giờ lớp Q: 4,0 − 1,5 = 2,5');
select is((select status_code from app.class_session where id = pg_temp.s('p', 3)), 'DA_CHOT', 'Buổi lỗi vẫn Đã chốt (quỹ giờ không âm, R-GD-18)');
select is(pg_temp.errs('true'), 1::bigint, '(b) đúng MỘT dòng nhật ký lỗi cho cả lượt');
select is((select error_code from app.session_auto_done_error where session_id = pg_temp.s('p', 3)), 'HMT_QUY_GIO_AM', '(b) dòng nhật ký có mã lỗi HMT_QUY_GIO_AM');
select ok((select length(error_message) > 0 and attempts = 1 and resolved_at is null from app.session_auto_done_error where session_id = pg_temp.s('p', 3)), '(b) có câu lỗi, 1 lần thử, chưa hết lỗi');
select is(pg_temp.errs(format('session_id in (%L, %L, %L)', pg_temp.s('p', 1), pg_temp.s('p', 2), pg_temp.s('q', 1))), 0::bigint, 'Buổi Done được không có dòng lỗi');

-- ================= Lượt chạy 2, 3: thử lại buổi lỗi, không ghi trùng vô hạn =================
select is(pg_temp.run(), 0, 'Lượt 2: buổi lỗi được thử lại, vẫn lỗi, không Done thêm');
select is(pg_temp.errs('true'), 1::bigint, '(c) chạy lại không thêm dòng: vẫn đúng một dòng');
select is((select attempts from app.session_auto_done_error where session_id = pg_temp.s('p', 3)), 2, '(c) số lần thử tăng lên 2 (thử lại thật)');
select pg_temp.run();
select is((select attempts from app.session_auto_done_error where session_id = pg_temp.s('p', 3)), 3, '(c) lượt 3: số lần thử 3, vẫn một dòng');
select is(pg_temp.errs('true'), 1::bigint, '(c) vẫn đúng một dòng sau 3 lượt');

-- ================= Hết lỗi: nạp thêm giờ thì Done được và đánh dấu đã hết lỗi =================
select pg_temp.sudo($$select app.add_opening_hours(pg_temp.e('a'), 4, 'DOT-P7')$$);
select is(pg_temp.run(), 1, 'Nạp thêm giờ: lượt sau Done buổi từng lỗi');
select is((select status_code from app.class_session where id = pg_temp.s('p', 3)), 'DONE', 'Buổi từng lỗi nay Done');
select ok((select resolved_at is not null from app.session_auto_done_error where session_id = pg_temp.s('p', 3)), 'Dòng lỗi được đánh dấu đã hết lỗi');
select is(pg_temp.run(), 0, 'Lượt sau: không còn gì để Done');
select is((select attempts from app.session_auto_done_error where session_id = pg_temp.s('p', 3)), 3, 'Hết lỗi rồi thì số lần thử không tăng nữa');

-- ================= Quyền đọc nhật ký lỗi (RLS) =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((select count(*)::int from app.session_auto_done_error), 0, 'Chặn: CSKH không đọc được nhật ký lỗi tự Done');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((select count(*)::int from app.session_auto_done_error), 1, 'Quản trị đọc được nhật ký lỗi tự Done');
select is(pg_temp.err($$select app.auto_complete_sessions()$$), '42501', 'Chặn: giao diện không gọi tự Done (chỉ lịch hệ thống), như trước');

select * from finish();
rollback;
