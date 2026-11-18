-- A25 (migration 303): yêu cầu buổi chọn loại Kiểm tra kèm cấu hình điểm; kiểm tra bù KHÔNG trừ giờ, kiểm tra từ củng cố trừ giờ. Luật: R-V2-20, R-V2-18, R-BUOI-03, R-BUOI-05. Dữ liệu giả.
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

-- ================= Đặt loại Kiểm tra cho yêu cầu NHÁP =================
select app.save_makeup_request(null, pg_temp.c('f'), array[pg_temp.st(1)], pg_temp.fut() + 3, '18:00', '19:30', null, null, 'Thi bù buổi 2');
select is(pg_temp.err($$select app.set_request_exam(pg_temp.req('Thi bù buổi 2'), true, 'Phương trình', 10, 'NHOM', 3, 3, 3)$$), 'HMT_DIEM_NHOM_KHONG_KHOP', 'Chặn: tổng ba nhóm 9 khác điểm tối đa 10 (R-V2-20)');
select is(pg_temp.err($$select app.set_request_exam(pg_temp.req('Thi bù buổi 2'), true, 'x', 10, 'KHAC')$$), 'HMT_CACH_NHAP_DIEM_SAI', 'Chặn: cách nhập điểm sai');
select is(pg_temp.err($$select app.set_request_exam(pg_temp.req('Thi bù buổi 2'), true, 'x', 0, 'TONG')$$), 'HMT_DIEM_TOI_DA_SAI', 'Chặn: điểm tối đa phải lớn hơn 0');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.set_request_exam(pg_temp.req('Thi bù buổi 2'), true, 'x', 10, 'TONG')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không tạo yêu cầu buổi');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.set_request_exam(pg_temp.req('Thi bù buổi 2'), true, 'x', 10, 'TONG')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở khác cơ sở');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select lives_ok($$select app.set_request_exam(pg_temp.req('Thi bù buổi 2'), true, 'Phương trình bậc nhất', 10, 'NHOM', 3, 3, 4)$$, 'Đúng: ba nhóm 3+3+4 = 10');
select is((select session_type_code from app.session_request where reason = 'Thi bù buổi 2'), 'KIEM_TRA', 'Yêu cầu mang loại Kiểm tra');
select is(app.list_session_requests('{}'::jsonb) -> 'rows' -> 0 -> 'exam' ->> 'mode', 'NHOM', 'Danh sách trả cấu hình điểm');
select lives_ok($$select app.submit_session_request(pg_temp.req('Thi bù buổi 2'))$$, 'Gửi duyệt');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.set_request_exam(pg_temp.req('Thi bù buổi 2'), false)$$), 'HMT_SAI_TRANG_THAI', 'Chặn: yêu cầu đã gửi duyệt không đổi loại');

-- ================= Duyệt: kiểm tra bù KHÔNG trừ giờ =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select ok((app.approve_session_request(pg_temp.req('Thi bù buổi 2')) ->> 'session_id') is not null, 'Duyệt yêu cầu học bù loại Kiểm tra');
select is((select type_code from app.class_session where id = (select created_session_id from app.session_request where reason = 'Thi bù buổi 2')), 'KIEM_TRA', 'Buổi sinh ra là loại Kiểm tra');
select is((select no_charge from app.class_session where id = (select created_session_id from app.session_request where reason = 'Thi bù buổi 2')), true, 'Kiểm tra bù: không trừ giờ (R-BUOI-03)');
select is((select entry_mode || ':' || max_score || ':' || max_memory || ':' || max_apply from app.session_exam where session_id = (select created_session_id from app.session_request where reason = 'Thi bù buổi 2')), 'NHOM:10.00:3.00:4.00', 'Cấu hình điểm đã đặt cho buổi (R-V2-20)');
select is(app.session_deducts_hours((select s from app.class_session s where id = (select created_session_id from app.session_request where reason = 'Thi bù buổi 2'))), false, 'session_deducts_hours: kiểm tra bù không trừ');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.close_session((select created_session_id from app.session_request where reason = 'Thi bù buổi 2')), 1, 'Chốt danh sách: chỉ em được chọn (như học bù)');

-- ================= Củng cố loại Kiểm tra: TRỪ giờ như buổi Chính =================
select app.save_session_request(null, pg_temp.c('f'), pg_temp.fut() + 4, '18:00', '19:30');
select pg_temp.sudo($$update app.session_request set note = 'Kiểm tra củng cố' where kind = 'CUNG_CO' and note is null$$);
select app.set_request_exam((select id from app.session_request where note = 'Kiểm tra củng cố'), true, null, null, 'TONG');
select is((select exam_max_score from app.session_request where note = 'Kiểm tra củng cố'), 10.00, 'Điểm tối đa trống: lấy tham số mặc định exam_default_max_score');
select app.submit_session_request((select id from app.session_request where note = 'Kiểm tra củng cố'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_session_request((select id from app.session_request where note = 'Kiểm tra củng cố'));
select is((select type_code || ':' || no_charge from app.class_session where id = (select created_session_id from app.session_request where note = 'Kiểm tra củng cố')), 'KIEM_TRA:false', 'Kiểm tra từ củng cố: loại Kiểm tra, có trừ giờ');
select is(app.session_deducts_hours((select s from app.class_session s where id = (select created_session_id from app.session_request where note = 'Kiểm tra củng cố'))), true, 'session_deducts_hours: kiểm tra thường trừ giờ (R-V2-18)');

select * from finish();
rollback;
