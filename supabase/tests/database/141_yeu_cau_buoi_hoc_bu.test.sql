-- Yêu cầu học bù (migration 141): BUOI-07. Luật: R-BUOI-03 (lý do bắt buộc, sinh buổi mới, không trừ giờ, không gắn buổi gốc), R-BUOI-01, R-BUOI-10, R-GIO-02, R-GIO-03, R-GIO-04. Dữ liệu giả; ngày tính từ hôm nay.
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
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHD1C01', 'Phụ huynh giả BT', '0900101003', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSD1C0' || n, (select id from app.parent where code = 'PHD1C01'), 'Em giả BT ' || n, 2012, pg_temp.cs('CS1') from generate_series(1, 4) n$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('f', 'CB', pg_temp.fut(), 3);
select pg_temp.sudo($$select pg_temp.mke('a', 1, true, 10)$$);
select pg_temp.sudo($$select pg_temp.mke('b', 2, true, 10)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e('a'), pg_temp.c('f'), pg_temp.fut());
select app.assign_enrollment_class(pg_temp.e('b'), pg_temp.c('f'), pg_temp.fut());
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'YEU_CAU_BUOI', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- ================= Tạo yêu cầu học bù (BUOI-07) =================
select ok((app.save_makeup_request(null, pg_temp.c('f'), array[pg_temp.st(1), pg_temp.st(2)], pg_temp.fut() + 3, '18:00', '19:30', null, null, 'Ốm nghỉ buổi 2') ->> 'code') ~ '^YB-CS1-\d{4}-\d{4}$', 'Tạo yêu cầu học bù: mã YB');
select is((select kind from app.session_request where reason = 'Ốm nghỉ buổi 2'), 'HOC_BU', 'Loại Học bù');
select is(pg_temp.err($$select app.save_makeup_request(null, pg_temp.c('f'), array[pg_temp.st(1)], pg_temp.fut() + 3, '18:00', '19:30', null, null, '  ')$$), 'HMT_THIEU_LY_DO', 'Chặn: thiếu lý do (R-BUOI-03)');
select is(pg_temp.err($$select app.save_makeup_request(null, pg_temp.c('f'), '{}'::uuid[], pg_temp.fut() + 3, '18:00', '19:30', null, null, 'x')$$), 'HMT_THIEU_HOC_SINH', 'Chặn: không chọn em nào');
select is(pg_temp.err($$select app.save_makeup_request(null, pg_temp.c('f'), array[pg_temp.st(4)], pg_temp.fut() + 3, '18:00', '19:30', null, null, 'x')$$), 'HMT_EM_KHONG_TRONG_LOP', 'Chặn: em không học trong lớp');
select is(pg_temp.err($$select app.save_makeup_request(null, pg_temp.c('f'), array[pg_temp.st(1)], pg_temp.fut() + 3, '19:30', '18:00', null, null, 'x')$$), 'HMT_BUOI_GIO_SAI', 'Chặn: giờ sai');
select is(pg_temp.err($$select app.save_makeup_request(null, pg_temp.c('f'), array[pg_temp.st(1)], pg_temp.fut() + 3, '18:00', '19:30', pg_temp.uid('sales1'), null, 'x')$$), 'HMT_GIAO_VIEN_KHONG_HOP_LE', 'Chặn: người vai Sale không làm giáo viên');
select lives_ok($$select app.save_makeup_request(pg_temp.req('Ốm nghỉ buổi 2'), pg_temp.c('f'), array[pg_temp.st(1)], pg_temp.fut() + 3, '18:00', '19:30', null, null, 'Ốm nghỉ buổi 2')$$, 'Sửa: bỏ bớt một em');
select is((select count(*)::int from app.session_request_student where request_id = pg_temp.req('Ốm nghỉ buổi 2') and is_active), 1, 'Còn một em đang chọn');
select lives_ok($$select app.submit_session_request(pg_temp.req('Ốm nghỉ buổi 2'))$$, 'Gửi duyệt');

-- ================= Duyệt: SINH BUỔI MỚI loại Học bù, danh sách chỉ em được chọn =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.approve_session_request(pg_temp.req('Ốm nghỉ buổi 2'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH không duyệt');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('f') and type_code = 'HOC_BU'), 0, 'Trước duyệt chưa có buổi học bù');
select ok((app.approve_session_request(pg_temp.req('Ốm nghỉ buổi 2')) ->> 'session_id') is not null, 'Duyệt: sinh buổi mới');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('f') and type_code = 'HOC_BU'), 1, 'Có đúng một buổi Học bù mới (không chọn buổi có sẵn)');
select is((select teacher_id from app.class_session where id = (select created_session_id from app.session_request where reason = 'Ốm nghỉ buổi 2')), pg_temp.uid('gv1'), 'Không chọn giáo viên: lấy giáo viên khung giờ của lớp');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.close_session((select created_session_id from app.session_request where reason = 'Ốm nghỉ buổi 2')), 1, 'Chốt danh sách: chỉ em được chọn');
select is((select s.student_id from app.session_attendance s where s.session_id = (select created_session_id from app.session_request where reason = 'Ốm nghỉ buổi 2')), pg_temp.st(1), 'Đúng em được chọn');

-- ================= Danh sách =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(app.list_session_requests('{}'::jsonb) -> 'rows' -> 0 ->> 'kind', 'HOC_BU', 'Danh sách: loại Học bù');
select is(app.list_session_requests('{}'::jsonb) -> 'rows' -> 0 ->> 'reason', 'Ốm nghỉ buổi 2', 'Danh sách: có lý do');
select is(app.list_session_requests('{}'::jsonb) -> 'rows' -> 0 -> 'student_names', jsonb_build_array('Em giả BT 1'), 'Danh sách: tên em được chọn');

select * from finish();
rollback;
