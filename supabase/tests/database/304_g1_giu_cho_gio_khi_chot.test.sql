-- G1 (migration 304): chốt danh sách tính giờ GIỮ CHỖ của buổi Đã chốt chưa Done (R-GIO-03). Kịch bản Soát S14: em 1,5 giờ vào cả hai buổi rồi buổi 2 kẹt HMT_QUY_GIO_AM. Dữ liệu giả.
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

create function pg_temp.req(p_key text) returns uuid language sql stable security definer as $$ select id from app.session_request where coalesce(reason, note) = p_key $$;
grant execute on function pg_temp.req(text) to public;
-- Từ đây chạy với vai trò đăng nhập thật (RLS và quyền gọi hàm có hiệu lực).


-- Ba em giả (cần hồ sơ học sinh), hai em xếp vào lớp tương lai đã duyệt 'f' (giáo viên gv1).

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
-- Sáu em giả: 1 (1,5 giờ), 2 (10 giờ), 3 (1,5 giờ), 4 (10 giờ), 5 (1,5 giờ), 6 (10 giờ).
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHD1C01', 'Phụ huynh giả G1', '0900101004', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSD1C0' || n, (select id from app.parent where code = 'PHD1C01'), 'Em giả G1 ' || n, 2012, pg_temp.cs('CS1') from generate_series(1, 6) n$$);
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'session_done_requires_review'$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('g', 'CB', pg_temp.past(), 4);
select pg_temp.mkclass('h', 'CB', pg_temp.past(), 4);
select pg_temp.mkclass('k', 'CB', pg_temp.past(), 4);
select pg_temp.sudo($$select pg_temp.mke('a', 1, true, 1.5)$$);
select pg_temp.sudo($$select pg_temp.mke('b', 2, true, 10)$$);
select pg_temp.sudo($$select pg_temp.mke('c', 3, true, 1.5)$$);
select pg_temp.sudo($$select pg_temp.mke('d', 4, true, 10)$$);
select pg_temp.sudo($$select pg_temp.mke('e', 5, true, 1.5)$$);
select pg_temp.sudo($$select pg_temp.mke('f', 6, true, 10)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e('a'), pg_temp.c('g'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('b'), pg_temp.c('g'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('c'), pg_temp.c('h'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('d'), pg_temp.c('h'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('e'), pg_temp.c('k'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('f'), pg_temp.c('k'), pg_temp.past());

-- ================= Kịch bản Soát: hai buổi cùng chốt trước khi buổi 1 Done =================
select is(app.close_session(pg_temp.s('g', 1)), 2, 'Chốt buổi 1: em 1 (1,5 giờ) và em 2 (10 giờ) cùng vào danh sách');
select is(app.close_session(pg_temp.s('g', 2)), 1, 'G1: chốt buổi 2: chỉ em 2 vào; em 1 hết giờ khả dụng vì buổi 1 đã giữ chỗ (R-GIO-03)');
select is((select excluded_reason from app.session_attendance where session_id = pg_temp.s('g', 2) and student_id = pg_temp.st(1)), 'HET_GIO', 'G1: em 1 bị loại khỏi buổi 2 với lý do hết giờ');
select is(app.enrollment_hours_reserved(pg_temp.e('a'), pg_temp.s('g', 2)), 1.50::numeric, 'enrollment_hours_reserved: buổi 1 giữ chỗ 1,5 giờ cho ghi danh của em 1');
select is(app.enrollment_hours_reserved(pg_temp.e('a'), pg_temp.s('g', 1)), 0.00::numeric, 'Buổi chưa đến lượt không giữ chỗ cho buổi trước nó');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select app.set_attendance_teacher(pg_temp.s('g', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT'), jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'CO_MAT')));
select app.set_attendance_teacher(pg_temp.s('g', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'CO_MAT')));
select pg_temp.sudo($$select pg_temp.fillreview(pg_temp.s('g', 1))$$);
select pg_temp.sudo($$select pg_temp.fillreview(pg_temp.s('g', 2))$$);
select lives_ok($$select pg_temp.sudo('select app.mark_session_done(''' || pg_temp.s('g', 1) || '''::uuid)')$$, 'Done buổi 1: trừ 1,5 giờ của em 1 và em 2');
select lives_ok($$select pg_temp.sudo('select app.mark_session_done(''' || pg_temp.s('g', 2) || '''::uuid)')$$, 'G1: Done buổi 2 KHÔNG còn kẹt HMT_QUY_GIO_AM (trước G1 kẹt cả buổi)');
select is((select status_code from app.class_session where id = pg_temp.s('g', 2)), 'DONE', 'Buổi 2 đã Done');
select is(app.enrollment_hours_balance(pg_temp.e('a')), 0.00::numeric, 'Em 1: hết giờ, đúng một lần trừ');
select is(app.enrollment_hours_balance(pg_temp.e('b')), 7.00::numeric, 'Em 2: 10 − 1,5 − 1,5 = 7 giờ (đủ hai lần trừ)');
-- Buổi 1 đã Done (có dòng trừ trong sổ): chốt buổi 3 không trừ đôi giữ chỗ.
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.close_session(pg_temp.s('g', 3)), 1, 'Chốt buổi 3 sau Done: em 1 hết giờ (sổ giờ) bị loại, em 2 còn 7 giờ vào; giữ chỗ không tính buổi đã Done');

-- ================= Huỷ không tính phí: hết giữ chỗ =================
select is(app.close_session(pg_temp.s('h', 1)), 2, 'Lớp H: chốt buổi 1, em 3 (1,5 giờ) và em 4 vào');
select app.cancel_session(pg_temp.s('h', 1), 'HUY_KHONG_PHI', 'TT_THOI_TIET');
select is(app.close_session(pg_temp.s('h', 2)), 2, 'Buổi 1 huỷ không tính phí thì hết giữ chỗ: chốt buổi 2, em 3 vẫn vào');

-- ================= Chốt buổi sớm sau buổi muộn: không đẩy em khỏi buổi sớm =================
select is(app.close_session(pg_temp.s('k', 2)), 2, 'Lớp K: chốt buổi 2 (muộn) trước');
select is(app.close_session(pg_temp.s('k', 1)), 2, 'Chốt buổi 1 (sớm) sau: em 5 vẫn vào buổi sớm (chỉ tính giữ chỗ của buổi diễn ra TRƯỚC)');

select * from finish();
rollback;
