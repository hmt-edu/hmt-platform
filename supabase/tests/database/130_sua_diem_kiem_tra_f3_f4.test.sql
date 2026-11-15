-- F3 (điểm nhóm âm) và F4 (chặn đổi cấu hình khi đã có điểm), migration 130. Luật: R-V2-20. Dữ liệu giả; ngày tính từ hôm nay.
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


-- Hàm bọc để gọi hàm nội bộ từ vai trò đăng nhập.
create function pg_temp.resolve(p_mode text, p_entry jsonb) returns numeric[] language sql security definer as $$
  select app.exam_resolve_scores(jsonb_populate_record(null::app.session_exam,
    jsonb_build_object('max_score', 10, 'entry_mode', p_mode, 'max_memory', case when p_mode = 'NHOM' then 3 else 0 end,
                       'max_understand', case when p_mode = 'NHOM' then 4 else 0 end, 'max_apply', case when p_mode = 'NHOM' then 3 else 0 end)), p_entry) $$;
grant execute on function pg_temp.resolve(text, jsonb) to public;

-- ================= F3: điểm nhóm âm =================
select is(pg_temp.resolve('NHOM', '{"memory": 2, "understand": 3, "apply": 3}'::jsonb), array[8, 2, 3, 3]::numeric[],
  'F3 đúng: ba nhóm hợp lệ thì trả tổng và từng nhóm');
select is(pg_temp.err($$select pg_temp.resolve('NHOM', '{"memory": -1, "understand": 4, "apply": 3}'::jsonb)$$), 'HMT_DIEM_AM',
  'F3 chặn: điểm một nhóm âm (tổng vẫn dương) báo HMT_DIEM_AM, không lọt lỗi ràng buộc của bảng');
select is(pg_temp.err($$select pg_temp.resolve('NHOM', '{"memory": 1, "understand": -0.5, "apply": 3}'::jsonb)$$), 'HMT_DIEM_AM',
  'F3 chặn: nhóm Hiểu âm cũng báo HMT_DIEM_AM');
select is(pg_temp.err($$select pg_temp.resolve('NHOM', '{"memory": 4, "understand": 4, "apply": 3}'::jsonb)$$), 'HMT_DIEM_VUOT_TOI_DA',
  'F3 giữ luật cũ: một nhóm vượt tối đa vẫn báo HMT_DIEM_VUOT_TOI_DA');
select is(pg_temp.err($$select pg_temp.resolve('TONG', '{"total": -1}'::jsonb)$$), 'HMT_DIEM_VUOT_TOI_DA',
  'F3 giữ luật cũ: điểm tổng âm vẫn bị chặn');
-- Qua hàm giáo viên nhập điểm (buổi 2 là kiểm tra theo 3 nhóm, em 1 có mặt).
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.set_exam_config(pg_temp.s('p', 2), 'Bất đẳng thức', 10, 'NHOM', 3, 4, 3);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.set_exam_scores(pg_temp.s('p', 2), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'memory', -1, 'understand', 4, 'apply', 3)))$$),
  'HMT_DIEM_AM', 'F3 chặn: giáo viên nhập nhóm âm qua set_exam_scores bị báo HMT_DIEM_AM');
select is((select count(*)::int from app.exam_score where session_id = pg_temp.s('p', 2)), 0, 'F3: nhập lỗi thì không ghi dòng điểm nào');

-- ================= F4: đổi cấu hình khi đã có điểm =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.set_exam_config(pg_temp.s('p', 3), 'Phương trình bậc nhất', 10, 'TONG', 0, 0, 0);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok($$select app.set_exam_config(pg_temp.s('p', 3), 'Phương trình bậc hai', 20, 'TONG', 0, 0, 0)$$,
  'F4 đúng: chưa có điểm chấm thì đổi được cấu hình');
select is((select max_score from app.session_exam where session_id = pg_temp.s('p', 3)), 20::numeric, 'F4: cấu hình đã đổi');
select app.set_exam_config(pg_temp.s('p', 3), 'Phương trình bậc nhất', 10, 'TONG', 0, 0, 0);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select app.set_exam_scores(pg_temp.s('p', 3), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'total', 9)));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.set_exam_config(pg_temp.s('p', 3), 'Phương trình bậc nhất', 20, 'TONG', 0, 0, 0)$$), 'HMT_KIEM_TRA_DA_CO_DIEM',
  'F4 chặn: đã có điểm chấm thì đổi điểm tối đa báo HMT_KIEM_TRA_DA_CO_DIEM');
select is(pg_temp.err($$select app.set_exam_config(pg_temp.s('p', 3), 'Phương trình bậc nhất', 10, 'NHOM', 3, 4, 3)$$), 'HMT_KIEM_TRA_DA_CO_DIEM',
  'F4 chặn: đã có điểm chấm thì đổi cách nhập báo HMT_KIEM_TRA_DA_CO_DIEM');
select is(pg_temp.err($$select app.set_exam_config(pg_temp.s('p', 3), 'Phạm vi khác', 10, 'TONG', 0, 0, 0)$$), 'HMT_KIEM_TRA_DA_CO_DIEM',
  'F4 chặn: đã có điểm chấm thì đổi phạm vi kiến thức cũng bị chặn');
select is((select max_score from app.session_exam where session_id = pg_temp.s('p', 3)), 10::numeric, 'F4: cấu hình giữ nguyên sau khi bị chặn');
select lives_ok($$select app.set_exam_config(pg_temp.s('p', 3), 'Phương trình bậc nhất', 10, 'TONG', 0, 0, 0)$$,
  'F4: gọi lại đúng cấu hình đang có thì vẫn cho qua (không đổi gì)');

select * from finish();
rollback;
