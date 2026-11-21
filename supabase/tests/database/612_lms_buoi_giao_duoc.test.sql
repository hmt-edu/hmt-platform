-- GV-17 (migration 612): danh sách buổi giao được (app.lms_giveable_sessions). Luật: R-LMS-01 (cả lớp hoặc từng em, hạn mặc định giờ vào buổi sau, hai công tắc), R-LMS-04 (tệp 10 MB, 20 trang),
-- Luật: R-GV-08 (chỉ buổi được phân công), Q14 (quyền sẵn có), R-LMS-01 (buổi thật của lớp). Dữ liệu giả.
-- Trường hợp đúng và bị chặn: lớp có buổi của hai giáo viên, buổi huỷ, giáo viên khác, Sale chỉ Xem, cơ sở khác, công tắc tắt, anon.
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


-- Lớp p có 3 buổi (đều của gv1). Đổi buổi 2 sang gv2 để lớp có buổi của hai giáo viên; buổi 3 huỷ.
select pg_temp.sudo($$update app.class_session set teacher_id = pg_temp.uid('gv2') where class_id = pg_temp.c('p') and session_no = 2$$);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
-- Công tắc tính năng tắt: chặn.
select is(pg_temp.err($$select app.lms_giveable_sessions(pg_temp.c('p'))$$), 'HMT_TINH_NANG_TAT', 'Chặn: phân hệ Học tập chưa bật thì không liệt kê buổi giao');
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'HOC_TAP', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- ================= Đúng =================
select is(jsonb_array_length(app.lms_giveable_sessions(pg_temp.c('p'))), 2, 'R-GV-08: gv1 thấy 2 buổi mình dạy (buổi 1 và 3), không thấy buổi 2 của gv2');
select is((select jsonb_agg(x ->> 'session_no' order by x ->> 'session_no') from jsonb_array_elements(app.lms_giveable_sessions(pg_temp.c('p'))) x), '["1", "3"]'::jsonb, 'Đúng số buổi 1 và 3');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is((select jsonb_agg(x ->> 'session_no') from jsonb_array_elements(app.lms_giveable_sessions(pg_temp.c('p'))) x), '["2"]'::jsonb, 'R-GV-08: gv2 (có một buổi của lớp) chỉ thấy buổi 2');
-- Mọi buổi liệt kê đều giao được (lms_create_assignment không báo thiếu quyền).
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select ok((select bool_and(app.lms_create_assignment(jsonb_build_object('session_id', (x ->> 'id')::uuid, 'title', 'x', 'description', 'y', 'due_at', now() + interval '1 day')) is not null)
             from jsonb_array_elements(app.lms_giveable_sessions(pg_temp.c('p'))) x), 'Mọi buổi được liệt kê đều giao bài được');
select pg_temp.sudo($$update app.class_session set status_code = 'HUY_KHONG_PHI' where class_id = pg_temp.c('p') and session_no = 3$$);
select is(jsonb_array_length(app.lms_giveable_sessions(pg_temp.c('p'))), 1, 'R-LMS-01: buổi đã huỷ không được liệt kê');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(jsonb_array_length(app.lms_giveable_sessions(pg_temp.c('p'))), 2, 'Trưởng cơ sở thấy mọi buổi thật trong cơ sở (buổi 1 và 2)');

-- ================= Bị chặn =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.lms_giveable_sessions(pg_temp.c('p'))$$), 'HMT_KHONG_CO_QUYEN', 'Q14 chặn: Sale (chỉ Xem Điểm danh) không liệt kê buổi giao');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.lms_giveable_sessions(pg_temp.c('p'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở khác không liệt kê buổi của lớp cơ sở này');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.lms_giveable_sessions(gen_random_uuid())$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: lớp không tồn tại báo cùng lỗi (không lộ sự tồn tại)');
select is(has_function_privilege('anon', 'app.lms_giveable_sessions(uuid)', 'execute'), false, 'Người chưa đăng nhập không gọi được hàm');

select * from finish();
rollback;
