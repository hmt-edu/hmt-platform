-- D1c (migration 102): vòng đời buổi, danh sách buổi, điểm danh hai phía, Done và trừ giờ, huỷ buổi, sửa sau Done.
-- Luật: R-BUOI-02, 06, 07, 09; R-GIO-01..08; R-DD-01..03; R-GD-05, 12, 18; R-GV-08. Dữ liệu giả; ngày tính từ hôm nay.
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

-- Từ đây chạy với vai trò đăng nhập thật (RLS và quyền gọi hàm có hiệu lực).
set local role authenticated;
-- ---------- Hồ sơ giả ----------
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHD1C01', 'Phụ huynh giả D1c', '0900101002', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSD1C0' || n, (select id from app.parent where code = 'PHD1C01'), 'Em giả D1c ' || n, 2012, pg_temp.cs('CS1') from generate_series(1, 6) n$$);

-- ---------- Lớp quá khứ P (4 buổi thứ Hai), lớp tương lai F, lớp riêng L ----------
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('p', 'CB', pg_temp.past(), 4);
select pg_temp.mkclass('f', 'CB', pg_temp.fut(), 4);
select pg_temp.mkclass('l', 'LR', pg_temp.fut(), 3);
-- Ghi danh: ea (em 1, 4 giờ), ea2 (em 1, ghi danh thứ hai vào sau), eb (em 2, 0 giờ), ec (em 3, bảo lưu), ed (em 4, vào lớp muộn), ee (em 5, tạo hôm nay).
select pg_temp.sudo($$select pg_temp.mke('a', 1, true, 4)$$);
select pg_temp.sudo($$select pg_temp.mke('a2', 1, true, 4)$$);
select pg_temp.sudo($$select pg_temp.mke('b', 2, true, 0)$$);
select pg_temp.sudo($$select pg_temp.mke('c', 3, true, 4)$$);
select pg_temp.sudo($$select pg_temp.mke('d', 4, true, 4)$$);
select pg_temp.sudo($$select pg_temp.mke('e', 5, false, 4)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e('a'), pg_temp.c('p'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('a2'), pg_temp.c('p'), pg_temp.past() + 7);
select app.assign_enrollment_class(pg_temp.e('b'), pg_temp.c('p'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('c'), pg_temp.c('p'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('d'), pg_temp.c('p'), pg_temp.past() + 14);
select app.assign_enrollment_class(pg_temp.e('e'), pg_temp.c('p'), pg_temp.past() + 7);
select pg_temp.sudo($$update app.enrollment set status_code = 'BAO_LUU' where id = pg_temp.e('c')$$);

-- ================= Chốt danh sách (R-BUOI-02, R-GIO-02, 03, 04, 08, R-GV-08) =================
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('p') and status_code = 'NHAP'), 4, 'Lớp P có 4 buổi Nháp sau khi duyệt');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.close_session(pg_temp.s('p', 1))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không đổi tình trạng buổi (R-GV-08)');
select is(pg_temp.err($$select app.set_attendance_teacher(pg_temp.s('p', 1), '[]')$$), 'HMT_BUOI_CHUA_CHOT', 'Chặn: chưa chốt danh sách thì chưa điểm danh (R-GIO-08)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.close_session(pg_temp.s('p', 1)), 1, 'Đúng: chốt danh sách buổi 1: chỉ 1 em vào danh sách (R-GIO-03)');
select is((select status_code from app.class_session where id = pg_temp.s('p', 1)), 'DA_CHOT', 'Buổi sang Đã chốt');
select is(pg_temp.err($$select app.close_session(pg_temp.s('p', 1))$$), 'HMT_BUOI_KHONG_CHOT_DUOC', 'Chặn: chốt lại buổi đã chốt');
-- R-GIO-04: em có hai ghi danh cùng lớp chỉ một dòng, ghi danh vào lớp sớm nhất.
select is((select count(*)::int from app.session_attendance where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(1)), 1, 'Một em một dòng điểm danh dù có hai ghi danh cùng lớp (R-GIO-04)');
select is((select enrollment_id from app.session_attendance where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(1)), pg_temp.e('a'), 'Trừ vào ghi danh vào lớp sớm nhất (R-GIO-04)');
select is((select excluded_reason from app.session_attendance where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(2)), 'HET_GIO', 'Em số dư 0 không vào danh sách, lý do hết giờ (R-GIO-03)');
select is((select excluded_reason from app.session_attendance where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(3)), 'BAO_LUU', 'Em đang bảo lưu không vào danh sách (R-GIO-03)');
select is((select excluded_reason from app.session_attendance where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(4)), 'CHUA_TOI_NGAY_VAO', 'Em chưa tới ngày vào lớp không vào danh sách (R-GIO-03)');
select is((select count(*)::int from app.session_attendance where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(5)), 0, 'Ghi danh sinh sau ngày buổi không lọt vào danh sách, không có dòng (R-GIO-02)');

-- ================= Điểm danh hai phía (R-DD-01..03, R-GV-08) =================
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.set_attendance_teacher(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT')))$$),
          'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không điểm danh buổi này (R-GV-08)');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.set_attendance_ops(pg_temp.s('p', 1), '[]')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không ghi phía vận hành (R-DD-02)');
select is(pg_temp.err($$select app.set_attendance_teacher(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'X')))$$),
          'HMT_DANH_MUC_KHONG_CO', 'Chặn: trạng thái điểm danh không có trong danh mục (R-DD-01)');
select is(pg_temp.err($$select app.set_attendance_teacher(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'CO_MAT')))$$),
          'HMT_EM_KHONG_TRONG_DANH_SACH', 'Chặn: giáo viên không tạo dòng điểm danh cho em không có trong danh sách (R-GV-08)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.set_attendance_ops(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT', 'contact_reason_code', 'KHAC')))$$),
          'HMT_CAN_GHI_CHU', 'Chặn: lý do liên hệ "Khác" bắt buộc ghi chú (R-DD-03)');
select is(app.set_attendance_ops(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT', 'contact_reason_code', 'DA_NHAC_VAO_LOP'))),
          1, 'Đúng: vận hành ghi trạng thái và lý do liên hệ (R-DD-03)');
-- Chưa Done được: giáo viên chưa điểm danh.
select is(app.session_pending_reason(pg_temp.s('p', 1)), 'Giáo viên chưa điểm danh 1 em.', 'Lý do chưa Done: giáo viên chưa điểm danh (R-GIO-06)');
select is(pg_temp.err($$select pg_temp.sudo('select app.mark_session_done(''' || pg_temp.s('p', 1) || '''::uuid)')$$), 'HMT_BUOI_CHUA_DONE_DUOC', 'Chặn: Done khi giáo viên chưa điểm danh xong (R-GIO-06)');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(app.set_attendance_teacher(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'VANG_KHONG_PHEP'))), 1,
          'Đúng: giáo viên điểm danh (Vắng không phép)');
select is((select ops_status_code from app.session_attendance where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(1)), 'CO_MAT', 'Ô vận hành giữ riêng (Có mặt)');
select is((select teacher_status_code from app.session_attendance where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(1)), 'VANG_KHONG_PHEP', 'Ô giáo viên quyết định trạng thái chính thức (R-DD-02)');

-- ================= Done và trừ giờ (R-GIO-01, 04, R-GD-05, R-GD-18, R-GD-12) =================
select pg_temp.sudo($$select pg_temp.fillreview(pg_temp.s('p', 1))$$);
select pg_temp.sudo($$select app.mark_session_done(pg_temp.s('p', 1))$$);
select is((select status_code from app.class_session where id = pg_temp.s('p', 1)), 'DONE', 'Buổi Done khi đủ điều kiện (R-GIO-06)');
-- Dấu Đúng hạn/Trễ hạn (R-GV-05): buổi 1 diễn ra 4 tuần trước nên Done bây giờ là Trễ hạn, ghi số giờ trễ, đóng dấu một lần.
select is((select completion_late from app.class_session where id = pg_temp.s('p', 1)), true, 'Dấu: buổi cũ Done muộn là Trễ hạn');
select ok((select completion_late_hours from app.class_session where id = pg_temp.s('p', 1)) > 0, 'Dấu: ghi số giờ trễ lớn hơn 0');
select ok((select completion_stamped_at from app.class_session where id = pg_temp.s('p', 1)) is not null, 'Dấu: có thời điểm đóng dấu');
select is(app.enrollment_hours_balance(pg_temp.e('a')), 2.50::numeric, 'Đúng: có tên trong danh sách thì trừ 1,5 giờ dù vắng không phép (R-GIO-01)');
select is(app.enrollment_hours_balance(pg_temp.e('a2')), 4.00::numeric, 'Ghi danh thứ hai không bị trừ: trừ đúng một lần, vào ghi danh sớm nhất (R-GIO-04)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((select count(*)::int from app.hour_ledger where session_id = pg_temp.s('p', 1) and entry_type = 'TRU_BUOI'), 1, 'Sổ giờ có đúng một dòng trừ cho buổi này (R-GIO-04)');
select is((select status_code from app.enrollment where id = pg_temp.e('a')), 'DANG_HOC', 'Ghi danh sang Đang học khi có buổi Done đầu tiên (R-GD-05)');
select is((select status_code from app.enrollment where id = pg_temp.e('a2')), 'DA_XEP_LOP', 'Ghi danh chưa bị trừ giờ vẫn Đã xếp lớp (R-GD-05)');
select is(pg_temp.err($$select pg_temp.sudo('select app.mark_session_done(''' || pg_temp.s('p', 1) || '''::uuid)')$$), 'HMT_BUOI_CHUA_DONE_DUOC', 'Chặn: Done lần hai (không trừ giờ hai lần)');
-- Quỹ không được âm (R-GD-18): buổi 2 và 3 đều chốt khi còn 2,5 giờ; Done buổi 2 còn 1,0; Done buổi 3 bị chặn.
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.close_session(pg_temp.s('p', 2)), 1, 'Chốt buổi 2: em 1 còn đủ giờ');
select is(app.close_session(pg_temp.s('p', 3)), 2, 'Chốt buổi 3: em 1 còn đủ giờ lúc chốt, em 4 đã tới ngày vào lớp nên vào danh sách');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select app.set_attendance_teacher(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT')));
select app.set_attendance_teacher(pg_temp.s('p', 3), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'DI_MUON'),
  jsonb_build_object('student_id', pg_temp.st(4), 'status_code', 'CO_MAT')));
select pg_temp.sudo($$select pg_temp.fillreview(pg_temp.s('p', 2))$$);
-- Buổi 2 đặt kết thúc hôm qua 23:00 và hạn hoàn tất 72 giờ: Done bây giờ là Đúng hạn (giờ trễ 0).
select pg_temp.sudo($$update app.class_session set session_date = ((now() at time zone 'Asia/Ho_Chi_Minh')::date - 1), start_time = '22:00', end_time = '23:00' where id = pg_temp.s('p', 2)$$);
select pg_temp.sudo($$update app.setting_def set value = '72' where key = 'teacher_session_complete_hours'$$);
select pg_temp.sudo($$select app.mark_session_done(pg_temp.s('p', 2))$$);
select is(app.enrollment_hours_balance(pg_temp.e('a')), 1.00::numeric, 'Done buổi 2: còn 1,0 giờ');
select is((select completion_late from app.class_session where id = pg_temp.s('p', 2)), false, 'Dấu: Done trong hạn là Đúng hạn');
select is((select completion_late_hours from app.class_session where id = pg_temp.s('p', 2)), 0.00::numeric, 'Dấu: Đúng hạn thì giờ trễ 0');
select is(app.session_overview(pg_temp.s('p', 2)) -> 'completion' ->> 'late', 'false', 'GV-04: session_overview trả dấu Đúng hạn của buổi Done');
select is(app.session_overview(pg_temp.s('p', 1)) -> 'completion' ->> 'late', 'true', 'GV-04: session_overview trả dấu Trễ hạn của buổi Done muộn');
select pg_temp.sudo($$select pg_temp.fillreview(pg_temp.s('p', 3))$$);
select is(pg_temp.err($$select pg_temp.sudo('select app.mark_session_done(''' || pg_temp.s('p', 3) || '''::uuid)')$$), 'HMT_QUY_GIO_AM', 'Chặn: Done làm quỹ giờ âm (R-GD-18)');
select is((select status_code from app.class_session where id = pg_temp.s('p', 3)), 'DA_CHOT', 'Buổi vẫn Đã chốt khi Done bị chặn');
-- Cho học trước (R-GD-12): quản lý bật, quỹ được âm trong hạn mức max_sessions_ahead.
select pg_temp.sudo($$update app.enrollment set pay_later_enabled = true where id = pg_temp.e('a')$$);
select pg_temp.sudo($$select app.mark_session_done(pg_temp.s('p', 3))$$);
select is(app.enrollment_hours_balance(pg_temp.e('a')), -0.50::numeric, 'Cho học trước: quỹ âm −0,5 giờ nằm trong hạn mức (R-GD-12)');

-- ================= Tự chốt, tự Done (R-GIO-05, R-GIO-06) =================
select is(pg_temp.err($$select app.auto_close_sessions()$$), '42501', 'Chặn: giao diện không gọi tự chốt (chỉ lịch hệ thống)');
select pg_temp.sudo($$select app.auto_close_sessions()$$);
select is((select status_code from app.class_session where id = pg_temp.s('p', 4)), 'DA_CHOT', 'Tự chốt: buổi quá khứ còn Nháp được chốt (R-GIO-05)');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('f') and status_code = 'NHAP'), 4, 'Tự chốt: buổi cách 2 tuần chưa vào cửa sổ quét, giữ Nháp (R-GIO-05)');
select pg_temp.sudo($$select app.auto_complete_sessions()$$);
select is((select status_code from app.class_session where id = pg_temp.s('p', 4)), 'DA_CHOT', 'Tự Done: giáo viên chưa điểm danh thì giữ Đã chốt (R-GIO-06)');
select ok(app.session_pending_reason(pg_temp.s('p', 4)) like 'Giáo viên chưa điểm danh%', 'Lý do buổi chưa Done được nêu rõ (R-GIO-06)');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select app.set_attendance_teacher(pg_temp.s('p', 4), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT'),
  jsonb_build_object('student_id', pg_temp.st(4), 'status_code', 'VANG_CO_PHEP')));
select pg_temp.sudo($$select pg_temp.fillreview(pg_temp.s('p', 4))$$);
select pg_temp.sudo($$select app.auto_complete_sessions()$$);
select is((select status_code from app.class_session where id = pg_temp.s('p', 4)), 'DONE', 'Tự Done: đủ điều kiện thì Done (R-GIO-06)');
select is(app.session_pending_reason(pg_temp.s('f', 1)), 'Buổi chưa chốt danh sách.', 'Lý do chưa Done: buổi Nháp chưa chốt');

-- ================= Sửa sau Done (R-GIO-07) =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.correct_attendance_after_done(pg_temp.s('p', 1), pg_temp.st(1), 'CO_MAT', 'SUA_SAI_DANH_SACH_DIEM_DANH')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH không sửa điểm danh sau Done (R-GIO-07)');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.correct_attendance_after_done(pg_temp.s('p', 1), pg_temp.st(1), 'CO_MAT', 'KHAC')$$), 'HMT_CAN_GHI_CHU', 'Chặn: sửa sau Done lý do "Khác" cần ghi chú');
select is(pg_temp.err($$select app.correct_attendance_after_done(pg_temp.s('p', 1), pg_temp.st(1), 'CO_MAT', 'KHONG_CO_LY_DO')$$), 'HMT_DANH_MUC_KHONG_CO', 'Chặn: sửa sau Done bắt buộc lý do trong danh mục (R-GIO-07)');
select is(pg_temp.err($$select app.correct_attendance_after_done(pg_temp.s('f', 1), pg_temp.st(1), 'CO_MAT', 'SUA_SAI_DANH_SACH_DIEM_DANH')$$), 'HMT_BUOI_CHUA_DONE', 'Chặn: chức năng sửa sau Done chỉ cho buổi đã Done');
select lives_ok($$select app.correct_attendance_after_done(pg_temp.s('p', 1), pg_temp.st(1), 'CO_MAT', 'SUA_SAI_DANH_SACH_DIEM_DANH')$$, 'Đúng: Trưởng cơ sở sửa Vắng thành Có mặt kèm lý do');
select is((select teacher_status_code from app.session_attendance where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(1)), 'CO_MAT', 'Trạng thái đã đổi');
select is(app.enrollment_hours_balance(pg_temp.e('a')), -2.00::numeric, 'Đổi giữa các trạng thái đi học không đổi giờ (R-GIO-07)');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.set_attendance_teacher(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'VANG_CO_PHEP')))$$),
          'HMT_BUOI_DA_DONE', 'Chặn: giáo viên không sửa điểm danh buổi đã Done (R-GIO-07)');

-- ================= Huỷ buổi (R-BUOI-06, 07, 09) =================
select is(pg_temp.err($$select app.cancel_session(pg_temp.s('f', 1), 'HUY_KHONG_PHI', 'TT_THOI_TIET')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không huỷ buổi (R-BUOI-09)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.cancel_session(pg_temp.s('p', 1), 'HUY_KHONG_PHI', 'TT_THOI_TIET')$$), 'HMT_BUOI_KHONG_HUY_DUOC', 'Chặn: buổi Done không huỷ được (R-BUOI-09)');
select is(pg_temp.err($$select app.cancel_session(pg_temp.s('f', 1), 'HUY_KHONG_PHI', 'HS_OM')$$), 'HMT_HUY_BUOI_HS_CHI_LOP_RIENG', 'Chặn: lý do của học sinh chỉ cho lớp riêng (R-BUOI-07)');
select is(app.cancel_session(pg_temp.s('f', 1), 'HUY_CO_PHI', 'TT_THOI_TIET') ->> 'status', 'HUY_KHONG_PHI', 'Trung tâm huỷ luôn là Huỷ không tính phí dù chọn kiểu nào (R-BUOI-06)');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('f') and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI')), 4,
          'Trung tâm huỷ: tự thêm một buổi cuối lịch, tổng buổi vẫn đủ 4 (R-BUOI-06)');
select is((select array_agg(session_no order by session_date)::text from app.class_session where class_id = pg_temp.c('f') and status_code = 'NHAP'), '{1,2,3,4}',
          'Trung tâm huỷ: số "Buổi N" đánh lại liên tục (R-BUOI-06)');
select is((select expected_end_date from app.class where id = pg_temp.c('f')), pg_temp.fut() + 28, 'Ngày kết thúc dự kiến lùi một tuần (R-BUOI-06, R-LOP-09)');
select is(pg_temp.err($$select app.cancel_session(pg_temp.s('f', 1), 'HUY_KHONG_PHI', 'TT_THOI_TIET')$$), null, 'Buổi thứ hai của lớp F huỷ tiếp được (số buổi đã đánh lại)');
-- Lớp riêng: học sinh huỷ, người huỷ chọn có hoặc không tính phí (R-BUOI-07).
select pg_temp.sudo($$select pg_temp.mke('l1', 6, false, 3)$$);
select app.assign_enrollment_class(pg_temp.e('l1'), pg_temp.c('l'), pg_temp.fut());
select is(pg_temp.err($$select app.cancel_session(pg_temp.s('l', 1), 'HUY_CO_PHI', 'HS_KHAC')$$), 'HMT_CAN_GHI_CHU', 'Chặn: lý do "Khác" của học sinh bắt buộc ghi chú (R-BUOI-07)');
select is(pg_temp.err($$select app.cancel_session(pg_temp.s('l', 1), null, 'HS_OM')$$), 'HMT_HUY_BUOI_CAN_CHON_KIEU', 'Chặn: học sinh huỷ phải chọn có hoặc không tính phí (R-BUOI-07)');
select is(app.cancel_session(pg_temp.s('l', 1), 'HUY_CO_PHI', 'HS_OM') ->> 'status', 'HUY_CO_PHI', 'Đúng: lớp riêng huỷ có tính phí (R-BUOI-07)');
select is(app.enrollment_hours_balance(pg_temp.e('l1')), 1.50::numeric, 'Huỷ có tính phí trừ giờ như buổi Done: 3 − 1,5 = 1,5 giờ (R-BUOI-02)');
select is(app.cancel_session(pg_temp.s('l', 2), 'HUY_KHONG_PHI', 'HS_VIEC_GIA_DINH') ->> 'status', 'HUY_KHONG_PHI', 'Đúng: lớp riêng huỷ không tính phí (R-BUOI-07)');
select is(app.enrollment_hours_balance(pg_temp.e('l1')), 1.50::numeric, 'Huỷ không tính phí không trừ giờ (R-BUOI-07)');
select is((select count(*)::int from app.session_attendance sa join app.class_session s on s.id = sa.session_id
            where s.class_id = pg_temp.c('l') and s.status_code in ('HUY_CO_PHI', 'HUY_KHONG_PHI') and sa.is_active), 0, 'Huỷ buổi: các dòng điểm danh bị vô hiệu (R-BUOI-09)');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('l') and status_code = 'NHAP'), 1, 'Lớp riêng (học sinh huỷ): không tự thêm buổi cuối (R-BUOI-07)');

-- ================= Dời buổi, dạy thay =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.move_session(pg_temp.s('f', 1), pg_temp.fut() + 1, '17:00', '18:30')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không dời buổi (R-GV-08)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.move_session(pg_temp.s('f', 1), pg_temp.fut() + 1, '18:30', '17:00')$$), 'HMT_BUOI_GIO_SAI', 'Chặn: giờ kết thúc không sau giờ bắt đầu');
select lives_ok($$select app.move_session(pg_temp.s('f', 1), pg_temp.fut() + 1, '17:00', '18:30')$$, 'Đúng: dời một buổi chưa Done');
select is((select is_manual from app.class_session where id = pg_temp.s('f', 1)), true, 'Buổi dời tay đánh dấu chỉnh lẻ (sinh lại lịch giữ nguyên, R-LOP-10)');
select lives_ok($$select app.change_session_staff(pg_temp.s('f', 2), pg_temp.uid('gv2'))$$, 'Đúng: đổi giáo viên một buổi (dạy thay, R-LOP-11)');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is((select count(*)::int from app.class_session where id = pg_temp.s('f', 2)), 1, 'Người dạy thay thấy buổi được giao');

-- ================= RLS điểm danh =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select ok((select count(*) from app.session_attendance where session_id = pg_temp.s('p', 1)) > 0, 'Giáo viên được phân công thấy điểm danh buổi của mình');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is((select count(*)::int from app.session_attendance where session_id = pg_temp.s('p', 1)), 0, 'Giáo viên không được phân công không thấy điểm danh (R-GV-08)');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((select count(*)::int from app.session_attendance), 0, 'Trưởng cơ sở CS5 không thấy điểm danh CS1');
select is(pg_temp.err($$insert into app.session_attendance (session_id, class_id, branch_id, student_id) values (pg_temp.s('p', 1), pg_temp.c('p'), pg_temp.cs('CS1'), pg_temp.st(5))$$), '42501',
          'Chặn: không ghi thẳng vào điểm danh (giáo viên không tạo dòng, R-GV-08)');

select * from finish();
rollback;
