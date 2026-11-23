-- A-23-12/13 (migration 624): Done ngay khi giáo viên lưu bước cuối; quỹ giờ âm không chặn lưu; hai ghi danh cùng lớp trừ cũ trước, LOP-09 một dòng mỗi em. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@a2312.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@a2312.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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
create function pg_temp.st(p_n integer) returns uuid language sql stable security definer as $$ select id from app.student where code = 'HSA230' || p_n $$;
-- Ghi danh giả; p_old = true thì lùi ngày tạo 60 ngày (tắt tạm trigger điền cột chuẩn) để vào được danh sách buổi quá khứ (R-GIO-02).
create function pg_temp.mke(p_key text, p_n integer, p_old boolean, p_hours numeric) returns void language plpgsql security definer as $$
declare v_id uuid;
begin
  insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code)
  values ('GDA' || p_key, pg_temp.st(p_n), (select parent_id from app.student where id = pg_temp.st(p_n)), pg_temp.cs('CS1'), 'TOAN')
  returning id into v_id;
  if p_old then
    alter table app.enrollment disable trigger enrollment_fill_standard;
    update app.enrollment set created_at = now() - interval '60 days' where id = v_id;
    alter table app.enrollment enable trigger enrollment_fill_standard;
  end if;
  insert into en values (p_key, v_id);
  if p_hours <> 0 then
    perform app.add_opening_hours(v_id, p_hours, 'DOT-A230');
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
-- Bốn em giả: 1 (1,5 giờ), 2 (10 giờ), 3 (1,5 giờ ghi danh cũ + 10 giờ ghi danh mới), 4 (1,5 giờ).
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHA2301', 'Phụ huynh giả A2312', '0900101004', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSA230' || n, (select id from app.parent where code = 'PHA2301'), 'Em giả A2312 ' || n, 2012, pg_temp.cs('CS1') from generate_series(1, 6) n$$);
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'session_done_requires_review'$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('g', 'CB', pg_temp.past(), 4);
select pg_temp.mkclass('h', 'CB', pg_temp.past(), 4);
select pg_temp.mkclass('k', 'CB', pg_temp.past(), 4);
select pg_temp.sudo($$select pg_temp.mke('a', 1, true, 10)$$);
select pg_temp.sudo($$select pg_temp.mke('b', 2, true, 10)$$);
select pg_temp.sudo($$select pg_temp.mke('c', 3, true, 1.5)$$);
select pg_temp.sudo($$select pg_temp.mke('d', 3, true, 10)$$);
select pg_temp.sudo($$select pg_temp.mke('e', 4, true, 10)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e('a'), pg_temp.c('g'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('b'), pg_temp.c('g'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('c'), pg_temp.c('h'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('d'), pg_temp.c('h'), pg_temp.past() + 7);
select app.assign_enrollment_class(pg_temp.e('e'), pg_temp.c('k'), pg_temp.past());

-- ================= A-23-12: Done ngay khi giáo viên lưu bước cuối =================
select is(app.close_session(pg_temp.s('g', 1)), 2, 'Chốt buổi 1 lớp G: hai em vào danh sách');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select app.set_attendance_teacher(pg_temp.s('g', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT'), jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'CO_MAT')));
select is((select status_code from app.class_session where id = pg_temp.s('g', 1)), 'DA_CHOT', 'Mới điểm danh (thiếu nội dung buổi): buổi chưa Done');
select app.save_session_content(pg_temp.s('g', 1), array['Nội dung buổi giả']);
select is((select status_code from app.class_session where id = pg_temp.s('g', 1)), 'DONE', 'Giáo viên lưu bước cuối: buổi Done NGAY, không chờ cron');
select is((select count(*)::integer from app.hour_ledger where session_id = pg_temp.s('g', 1) and entry_type = 'TRU_BUOI'), 2, 'Done ngay trừ giờ: mỗi em đúng một dòng sổ');
select isnt((select completion_stamped_at from app.class_session where id = pg_temp.s('g', 1)), null, 'Dấu Đúng hạn/Trễ hạn được đóng ngay lúc Done');
select is(pg_temp.err($$select app.save_session_content(pg_temp.s('g', 1), array['Dòng hai'])$$), 'HMT_BUOI_DA_DONE', 'Lưu lại sau Done: giáo viên bị chặn (không có đường trừ giờ lần hai)');
select is((select count(*)::integer from app.hour_ledger where session_id = pg_temp.s('g', 1) and entry_type = 'TRU_BUOI'), 2, 'Sau lần lưu bị chặn: vẫn đúng một dòng trừ mỗi em');
select is(app.enrollment_hours_balance(pg_temp.e('a')), 8.50::numeric, 'Em 1: 10 − 1,5 = 8,5 giờ');
select pg_temp.sudo($$select app.auto_complete_sessions()$$);
select is(app.enrollment_hours_balance(pg_temp.e('a')), 8.50::numeric, 'Buổi đã Done ngay rồi cron chạy: không trừ lại');

-- ================= Quỹ giờ âm sau khi chốt: lưu vẫn thành công, buổi giữ Đã chốt, ghi lỗi =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.close_session(pg_temp.s('k', 1)), 1, 'Chốt buổi 1 lớp K: em 4 vào');
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, reason_code) values (pg_temp.e('e'), pg_temp.cs('CS1'), 'DIEU_CHINH', -10, (select code from app.catalog_item where catalog_code = 'HOURS_ADJUST_REASON' limit 1))$$);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select app.set_attendance_teacher(pg_temp.s('k', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(4), 'status_code', 'CO_MAT')));
select lives_ok($$select app.save_session_content(pg_temp.s('k', 1), array['Nội dung'])$$, 'Quỹ giờ âm lúc Done: lưu của giáo viên VẪN thành công');
select is((select status_code from app.class_session where id = pg_temp.s('k', 1)), 'DA_CHOT', 'Buổi giữ Đã chốt');
select is((select error_code from app.session_auto_done_error where session_id = pg_temp.s('k', 1)), 'HMT_QUY_GIO_AM', 'Lỗi ghi vào nhật ký tự Done để vận hành xử lý');
select is((select count(*)::integer from app.session_content_line where session_id = pg_temp.s('k', 1) and is_active), 1, 'Nội dung giáo viên đã lưu còn nguyên');

-- ================= A-23-13: hai ghi danh cùng lớp =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.close_session(pg_temp.s('h', 1)), 1, 'Lớp H buổi 1: em 3 chỉ MỘT dòng danh sách dù có hai ghi danh');
select is((select enrollment_id from app.session_attendance where session_id = pg_temp.s('h', 1) and student_id = pg_temp.st(3) and is_active), pg_temp.e('c'), 'Buổi 1: trừ ghi danh CŨ (còn đủ 1,5 giờ) trước');
select is(app.close_session(pg_temp.s('h', 2)), 1, 'Buổi 2: vẫn một dòng cho em 3');
select is((select enrollment_id from app.session_attendance where session_id = pg_temp.s('h', 2) and student_id = pg_temp.st(3) and is_active), pg_temp.e('d'), 'Buổi 2: ghi danh cũ đã giữ chỗ hết giờ nên sang ghi danh mới');
select is((select count(*)::integer from jsonb_array_elements(app.list_class_students(pg_temp.c('h')) -> 'rows') r where (r ->> 'student_id')::uuid = pg_temp.st(3) and r ->> 'end_date' is null), 1, 'LOP-09: một dòng đang học mỗi em');
select is((select (r ->> 'hours_left')::numeric from jsonb_array_elements(app.list_class_students(pg_temp.c('h')) -> 'rows') r where (r ->> 'student_id')::uuid = pg_temp.st(3)), 11.50::numeric, 'LOP-09: giờ còn là tổng hai ghi danh (1,5 + 10)');
select is((app.list_class_students(pg_temp.c('h')) ->> 'total')::integer, 1, 'LOP-09: tổng số dòng đếm theo em');

select * from finish();
rollback;
