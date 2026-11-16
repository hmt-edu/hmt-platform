-- BUOI-06 Thêm học thử vào buổi (migration 145): add_trial_student. Luật: R-GD-11, R-GD-17, R-CRM-03, R-CRM-27. Dữ liệu giả.
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
select pg_temp.sudo($$select pg_temp.mke('a', 1, true, 3)$$);   -- còn 3 giờ: sắp hết (ngưỡng 10 giờ)
select pg_temp.sudo($$select pg_temp.mke('b', 2, true, 40)$$);  -- còn 40 giờ, 1,5 giờ một tuần: chưa tới ngưỡng
select pg_temp.sudo($$select pg_temp.mke('c', 3, true, 0)$$);   -- hết giờ
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e('a'), pg_temp.c('f'), pg_temp.fut());
select app.assign_enrollment_class(pg_temp.e('b'), pg_temp.c('f'), pg_temp.fut());
select app.assign_enrollment_class(pg_temp.e('c'), pg_temp.c('f'), pg_temp.fut());

-- Cơ hội L5 với một em (đủ họ tên, năm sinh) tạo bằng hàm nghiệp vụ với quyền Sale CS1.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
create temp table op (key text primary key, id uuid, ps uuid);
grant all on op to public;
select app.create_lead(jsonb_build_object('parent_name', 'Phụ huynh giả HT', 'parent_phone', '0900202001', 'student_name', 'Em Giả Học Thử', 'student_birth_year', 2012,
  'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS', 'channel_code', 'FACEBOOK_ADS_LEAD_FORM')) ->> 'id' as id \gset lead_
select app.change_lead_stage(:'lead_id'::uuid, 'C4', 'C4C');
select (app.create_opportunity(:'lead_id'::uuid)) ->> 'id' as id \gset opp_
insert into op values ('o', :'opp_id'::uuid, (select id from app.prospect_student where opportunity_id = :'opp_id'::uuid and position = 1));
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');

-- ================= Cờ HOC_THU mặc định tắt =================
select is(pg_temp.err($$select app.add_trial_student(pg_temp.s('f', 1), (select ps from op where key = 'o'))$$), 'HMT_TINH_NANG_TAT', 'Cờ tắt: không thêm được học thử (mặc định tắt)');
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'HOC_THU', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- Buổi Nháp chưa thêm được; chốt rồi mới thêm.
select is(pg_temp.err($$select app.add_trial_student(pg_temp.s('f', 1), (select ps from op where key = 'o'))$$), 'HMT_BUOI_KHONG_THEM_HOC_THU', 'Chặn: buổi Nháp chưa có danh sách');
select is(app.close_session(pg_temp.s('f', 1)), 3, 'Chốt danh sách ba em');
select is(pg_temp.err($$select app.add_trial_student(pg_temp.s('f', 1), (select ps from op where key = 'o'))$$), 'HMT_CO_HOI_CHUA_DEN_L5', 'Chặn: cơ hội chưa tới L5 (R-CRM-03)');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.change_opportunity_stage((select id from op where key = 'o'), 'L5');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');

-- ================= Thêm học thử =================
select ok((app.add_trial_student(pg_temp.s('f', 1), (select ps from op where key = 'o')) ->> 'student_id') is not null, 'Thêm học thử: tạo hoặc tìm hồ sơ học sinh rồi thêm vào danh sách');
select is((select count(*)::int from app.session_attendance where session_id = pg_temp.s('f', 1) and is_trial and is_active), 1, 'Danh sách buổi có một dòng học thử');
select is((select enrollment_id from app.session_attendance where session_id = pg_temp.s('f', 1) and is_trial), null, 'Học thử không có ghi danh (không trừ giờ, R-GD-11)');
select is((select trial_opportunity_id from app.session_attendance where session_id = pg_temp.s('f', 1) and is_trial), (select id from op where key = 'o'), 'Dòng học thử nhớ cơ hội');
select isnt((select student_id from app.prospect_student where id = (select ps from op where key = 'o')), null, 'Dòng em của cơ hội đã gắn hồ sơ học sinh (R-CRM-27)');
select is(pg_temp.err($$select app.add_trial_student(pg_temp.s('f', 1), (select ps from op where key = 'o'))$$), 'HMT_EM_DA_CO_TRONG_BUOI', 'Chặn: em đã có trong buổi');

-- Hạn mức R-GD-17: mặc định hai buổi mỗi cơ hội.
select is(app.close_session(pg_temp.s('f', 2)), 3, 'Chốt buổi 2');
select ok((app.add_trial_student(pg_temp.s('f', 2), (select ps from op where key = 'o')) ->> 'student_id') is not null, 'Buổi 2: học thử thứ hai được');
select is(app.close_session(pg_temp.s('f', 3)), 3, 'Chốt buổi 3');
select is(pg_temp.err($$select app.add_trial_student(pg_temp.s('f', 3), (select ps from op where key = 'o'))$$), 'HMT_HOC_THU_VUOT_HAN_MUC', 'Chặn: vượt trial_sessions_max_per_opportunity (R-GD-17)');

-- ================= Done không trừ giờ học thử; quyền =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.add_trial_student(pg_temp.s('f', 3), (select ps from op where key = 'o'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không có quyền Sửa buổi');
select is(has_function_privilege('anon', 'app.add_trial_student(uuid, uuid)', 'execute'), false, 'Người chưa đăng nhập không gọi được');

select * from finish();
rollback;
