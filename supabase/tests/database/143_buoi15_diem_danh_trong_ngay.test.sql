-- BUOI-15 Điểm danh trong ngày (migration 143): danh sách theo dõi chỉ đọc, sau cờ DIEM_DANH_TRONG_NGAY. Luật: R-DD-01..03, R-GIO-02..04, R-GIO-08. Dữ liệu giả; ngày tính từ hôm nay.
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
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHD1C01', 'Phụ huynh giả GD7', '0900101007', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSD1C0' || n, (select id from app.parent where code = 'PHD1C01'), 'Em giả GD7 ' || n, 2012, pg_temp.cs('CS1') from generate_series(1, 4) n$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('f', 'CB', pg_temp.fut(), 3);
select pg_temp.sudo($$select pg_temp.mke('a', 1, true, 10)$$);
select pg_temp.sudo($$select pg_temp.mke('b', 2, true, 10)$$);
select pg_temp.sudo($$select pg_temp.mke('c', 3, true, 10)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e('a'), pg_temp.c('f'), pg_temp.fut());
select app.assign_enrollment_class(pg_temp.e('b'), pg_temp.c('f'), pg_temp.fut());
select app.assign_enrollment_class(pg_temp.e('c'), pg_temp.c('f'), pg_temp.fut());

-- ================= Cờ phân hệ DIEM_DANH_TRONG_NGAY mặc định tắt =================
select is(pg_temp.err($$select app.session_day_attendance('{}'::jsonb)$$), 'HMT_TINH_NANG_TAT', 'Cờ tắt: không xem được danh sách (mặc định tắt)');
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'DIEM_DANH_TRONG_NGAY', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- Buổi 1 của lớp f (thứ Hai tuần sau tuần sau): chốt danh sách ba em (Nháp thì chưa có danh sách).
select is(app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)))) -> 'rows' -> 0 ->> 'state', 'CHUA_CO_DANH_SACH', 'Buổi Nháp: chưa có danh sách (R-GIO-08)');
select is(app.close_session(pg_temp.s('f', 1)), 3, 'Chốt danh sách ba em');
select is(app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)))) -> 'rows' -> 0 ->> 'state', 'CHUA_GHI', 'Chưa em nào có ô giáo viên: Chưa ghi');
select is(app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)))) -> 'rows' -> 0 ->> 'total', '3', 'Ba em trong danh sách');

-- Vận hành ghi báo nghỉ cho em 1 (lý do liên hệ XIN_NGHI_HOC) và Có mặt cho em 2.
select is(app.set_attendance_ops(pg_temp.s('f', 1), jsonb_build_array(
  jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'VANG_CO_PHEP', 'contact_reason_code', 'XIN_NGHI_HOC'),
  jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'CO_MAT', 'contact_reason_code', 'DA_VAO_LOP'))), 2, 'Vận hành ghi báo nghỉ và có mặt');
select is(app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)))) -> 'rows' -> 0 ->> 'notice', '1', 'Báo nghỉ: một em có lý do XIN_NGHI_HOC');
select is(app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)))) -> 'rows' -> 0 -> 'ops' ->> 'VANG_CO_PHEP', '1', 'Bộ đếm vận hành: một em Vắng có phép');
select is(app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)))) -> 'rows' -> 0 -> 'ops' ->> 'CHUA', '1', 'Bộ đếm vận hành: một em chưa ghi');
select is(app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)))) -> 'rows' -> 0 ->> 'state', 'CHUA_GHI', 'Ô giáo viên quyết định: vận hành ghi chưa đổi tình trạng ghi');

-- Giáo viên ghi hai em: ghi dở, rồi ghi đủ.
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(app.set_attendance_teacher(pg_temp.s('f', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'VANG_CO_PHEP'),
                                                                          jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'CO_MAT'))), 2, 'Giáo viên ghi hai em');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)))) -> 'rows' -> 0 ->> 'state', 'GHI_DO', 'Hai trong ba em có ô giáo viên: Ghi dở');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(app.set_attendance_teacher(pg_temp.s('f', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(3), 'status_code', 'CO_MAT'))), 1, 'Giáo viên ghi em còn lại');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)))) -> 'rows' -> 0 ->> 'state', 'GHI_DU', 'Mọi em có ô giáo viên: Ghi đủ');

-- ================= Lọc, phân trang =================
select is((app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)), 'state', jsonb_build_array('GHI_DU'))) ->> 'total')::int, 1, 'Lọc theo tình trạng ghi: Ghi đủ');
select is((app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)), 'state', jsonb_build_array('CHUA_GHI'))) ->> 'total')::int, 0, 'Lọc theo tình trạng ghi: Chưa ghi không còn buổi nào');
select is((app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)), 'has_notice', true)) ->> 'total')::int, 1, 'Lọc có báo nghỉ');
select is((app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1)), 'has_notice', false)) ->> 'total')::int, 0, 'Lọc không có báo nghỉ');
select is(jsonb_array_length(app.session_day_attendance(jsonb_build_object('date', (select session_date from app.class_session where id = pg_temp.s('f', 1))), 1, 0) -> 'rows'), 1, 'Phân trang ở máy chủ');
select is((app.session_day_attendance(jsonb_build_object('date', date '2000-01-03')) ->> 'total')::int, 0, 'Ngày không có buổi: danh sách trống');

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.session_day_attendance('{}'::jsonb)$$), 'HMT_TINH_NANG_TAT', 'Cơ sở khác chưa bật cờ: bị chặn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.session_day_attendance('{}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: người không có quyền xem buổi học');
select is(has_function_privilege('anon', 'app.session_day_attendance(jsonb, integer, integer)', 'execute'), false, 'Người chưa đăng nhập không gọi được hàm');

select * from finish();
rollback;
