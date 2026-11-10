-- GV-06 (migration 109): session_overview trả thêm thông tin buổi và các dòng nội dung.
-- Luật: R-GV-08, R-GV-13, R-V2-35. Dữ liệu giả; ngày tính từ hôm nay.
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

-- Lớp thứ hai có buổi ở tương lai (buổi Nháp), cùng giáo viên gv1.
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('f', 'CB', pg_temp.fut(), 2);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');

-- ================= Chi tiết buổi cho GV-04, GV-06 (R-GV-08, R-V2-35) =================
select is(app.session_overview(pg_temp.s('p', 1)) ->> 'class_code', (select code from app.class where id = pg_temp.c('p')), 'Chi tiết buổi có mã lớp');
select is(app.session_overview(pg_temp.s('p', 1)) ->> 'subject_name', 'Toán', 'Chi tiết buổi có tên môn');
select is(app.session_overview(pg_temp.s('p', 1)) ->> 'type_name', (select name from app.catalog_item where catalog_code = 'SESSION_TYPE' and code = 'CHINH'), 'Chi tiết buổi có tên loại buổi từ danh mục');
select is((app.session_overview(pg_temp.s('p', 1)) ->> 'session_no')::int, 1, 'Chi tiết buổi có số buổi');
select is((app.session_overview(pg_temp.s('p', 1)) ->> 'review_scored')::int, 0, 'Chưa chấm nhận xét thì review_scored = 0');
select is(app.session_overview(pg_temp.s('p', 1)) -> 'lines', '[]'::jsonb, 'Chưa nhập thì danh sách dòng nội dung rỗng');
select is((app.session_overview(pg_temp.s('p', 1)) ->> 'attendance_marked')::int, 3, 'Tiến độ điểm danh: 3/3 em đã có trạng thái');
select is(app.save_session_content(pg_temp.s('p', 1), array['Dòng A', 'Dòng B'], 'Bài 1'), 2, 'Giáo viên lưu 2 dòng nội dung');
select is(app.session_overview(pg_temp.s('p', 1)) -> 'lines', '["Dòng A", "Dòng B"]'::jsonb, 'Chi tiết buổi trả đúng các dòng theo thứ tự');
select is(app.save_session_content(pg_temp.s('p', 1), array['Dòng C'], null), 1, 'Lưu lại bớt dòng');
select is(app.session_overview(pg_temp.s('p', 1)) -> 'lines', '["Dòng C"]'::jsonb, 'Dòng bị bỏ không còn trong chi tiết buổi');
select is(app.session_overview(pg_temp.s('p', 1)) ->> 'homework_text', null, 'BTVN trống = không giao (R-V2-35)');
select is((select count(*)::int from jsonb_object_keys(app.session_overview(pg_temp.s('p', 1))) k where k in ('phone', 'parent', 'fee')), 0, 'Không có thông tin phụ huynh, học phí (R-GV-13)');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.session_overview(pg_temp.s('p', 1))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không xem chi tiết buổi (R-GV-08)');

-- ================= Buổi Kiểm tra không đòi dòng nội dung (Q-252, R-V2-35) =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.save_session_content(pg_temp.s('p', 1), array[]::text[], null)$$), 'HMT_THIEU_NOI_DUNG', 'Buổi thường không có dòng nội dung vẫn bị chặn');
select is(app.save_session_content(pg_temp.s('p', 3), array[]::text[], null), 0, 'Buổi Kiểm tra lưu được khi không có dòng nội dung');
select is(app.save_session_content(pg_temp.s('p', 3), array['  '], 'Làm lại bài 3'), 0, 'Buổi Kiểm tra: dòng trống bị bỏ, chỉ có BTVN vẫn lưu được');
select is(app.session_overview(pg_temp.s('p', 3)) ->> 'homework_text', 'Làm lại bài 3', 'BTVN của buổi Kiểm tra được lưu');
select is((app.session_overview(pg_temp.s('p', 3)) ->> 'has_content')::boolean, false, 'Buổi Kiểm tra chưa có dòng nội dung thì has_content = false');
select is(app.session_overview(pg_temp.s('p', 3)) -> 'exam', 'null'::jsonb, 'Buổi Kiểm tra chưa cấu hình thì exam = null (không bịa)');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.set_exam_config(pg_temp.s('p', 3), 'Phương trình bậc nhất', 10, 'TONG', 0, 0, 0);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(app.session_overview(pg_temp.s('p', 3)) -> 'exam' ->> 'scope_text', 'Phương trình bậc nhất', 'Buổi Kiểm tra đã cấu hình thì chi tiết buổi có phạm vi kiến thức');
select is((app.session_overview(pg_temp.s('p', 3)) -> 'exam' ->> 'max_score')::numeric, 10::numeric, 'Chi tiết buổi có điểm tối đa');

-- ================= Bước chấm và bước BTVN buổi trước cho GV-04 =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is((app.session_overview(pg_temp.s('p', 1)) ->> 'grading_present')::int, 2, 'GV-04: 2 em có mặt (Có mặt, Đi muộn) cần chấm; em vắng không tính');
select is((app.session_overview(pg_temp.s('p', 1)) ->> 'grading_done')::int, 0, 'GV-04: chưa mở nhận xét thì chưa em nào chấm đủ');
select is(jsonb_array_length(app.session_overview(pg_temp.s('p', 1)) -> 'grading_missing'), 2, 'GV-04: liệt kê tên 2 em còn thiếu');
select pg_temp.sudo($$insert into app.session_review_criterion (session_id, branch_id, criterion_id, group_code, name, sort_order)
  select s.id, s.branch_id, rc.id, rc.group_code, rc.name, rc.sort_order
    from app.class_session s join app.class c on c.id = s.class_id join lateral app.review_criteria_for_subject(c.subject_code) rc on true
   where s.id = pg_temp.s('p', 1) on conflict do nothing$$);
select pg_temp.sudo($$insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score)
  select sa.session_id, sa.branch_id, rc.id, sa.id, 'DA_DANH_GIA', 3
    from app.session_attendance sa join app.session_review_criterion rc on rc.session_id = sa.session_id
   where sa.session_id = pg_temp.s('p', 1) and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON') on conflict do nothing$$);
select is((app.session_overview(pg_temp.s('p', 1)) ->> 'grading_done')::int, 2, 'GV-04: chấm đủ 9 tiêu chí thì 2/2 em xong');
select is(jsonb_array_length(app.session_overview(pg_temp.s('p', 1)) -> 'grading_missing'), 0, 'GV-04: không còn em thiếu');
select is(app.session_overview(pg_temp.s('p', 1)) ->> 'prev_homework_state', 'DAU_LOP', 'GV-04: buổi đầu của lớp thì bước BTVN buổi trước bỏ qua');
select is(app.session_overview(pg_temp.s('p', 2)) ->> 'prev_homework_state', 'KHONG_GIAO', 'GV-04: buổi trước không giao BTVN thì bỏ qua');
select app.save_session_content(pg_temp.s('p', 1), array['x'], 'Bài về nhà');
select is(app.session_overview(pg_temp.s('p', 2)) ->> 'prev_homework_state', 'CAN_CHAM', 'GV-04: buổi trước có giao BTVN thì cần chấm');

-- ================= Cột bổ sung cho GV-02 trong teacher_my_sessions =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(app.teacher_my_sessions('NGAY', pg_temp.fut(), pg_temp.fut()) -> 'rows' -> 0 ->> 'room_name', null, 'Buổi chưa có phòng thì room_name để trống, không bịa');
select pg_temp.sudo($$insert into app.room (branch_id, code, name, capacity) values (pg_temp.cs('CS1'), 'PGV109', 'Phòng giả 109', 10)$$);
select pg_temp.sudo($$update app.class_session set room_id = (select id from app.room where code = 'PGV109') where id = pg_temp.s('f', 1)$$);
select is(app.teacher_my_sessions('NGAY', pg_temp.fut(), pg_temp.fut()) -> 'rows' -> 0 ->> 'room_name', 'Phòng giả 109', 'Buổi có phòng thì room_name là tên phòng');
select is(app.teacher_my_sessions('NGAY', pg_temp.fut(), pg_temp.fut()) -> 'rows' -> 0 ->> 'level_code', 'A', 'Dòng buổi có mã trình độ của lớp');
select is(app.teacher_my_sessions('NGAY', pg_temp.fut(), pg_temp.fut()) -> 'rows' -> 0 ->> 'level_name',
          (select name from app.catalog_item where catalog_code = 'LEVEL' and code = 'A'), 'Tên trình độ lấy từ danh mục');
select is(app.teacher_my_sessions('NGAY', pg_temp.fut(), pg_temp.fut()) -> 'rows' -> 0 ->> 'class_type_name',
          (select name from app.catalog_item where catalog_code = 'CLASS_TYPE' and code = 'CB'), 'Tên phân loại lớp lấy từ danh mục');
select is(app.teacher_my_sessions('NGAY', pg_temp.fut(), pg_temp.fut()) -> 'rows' -> 0 ->> 'session_type_name',
          (select name from app.catalog_item where catalog_code = 'SESSION_TYPE' and code = 'CHINH'), 'Tên loại buổi lấy từ danh mục');
select is((app.teacher_my_sessions('NGAY', pg_temp.fut(), pg_temp.fut()) -> 'rows' -> 0) ? 'status_code', true, 'Các cột cũ giữ nguyên');

-- ================= Chặn ghi đè khi hai người cùng sửa (Q-243) =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select pg_temp.sudo($$create temp table ver (k text primary key, v text)$$);
select pg_temp.sudo($$grant all on ver to public$$);
select pg_temp.sudo($$insert into ver values ('a', app.session_overview(pg_temp.s('p', 2)) ->> 'content_version')$$);
select is((select v from ver where k = 'a'), '0', 'Chưa có nội dung thì phiên bản là 0');
-- Người thứ nhất (giáo viên) và người thứ hai (vận hành) cùng mở lúc chưa có nội dung.
select is(app.save_session_content(pg_temp.s('p', 2), array['Người thứ nhất'], null, 0), 1, 'Người thứ nhất lưu lần đầu với phiên bản 0: được');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.save_session_content(pg_temp.s('p', 2), array['Người thứ hai'], null, 0)$$), 'HMT_XUNG_DOT', 'Người thứ hai còn giữ bản cũ 0: bị từ chối (Q-243)');
select is(app.session_overview(pg_temp.s('p', 2)) -> 'lines', '["Người thứ nhất"]'::jsonb, 'Bản của người thứ nhất không bị ghi đè lặng lẽ');
select pg_temp.sudo($$update ver set v = app.session_overview(pg_temp.s('p', 2)) ->> 'content_version' where k = 'a'$$);
select is((select v from ver where k = 'a'), '1', 'Sau lần lưu đầu thì phiên bản là 1');
select is(app.save_session_content(pg_temp.s('p', 2), array['Người thứ hai, sau khi tải lại'], null, (select v from ver where k = 'a')::int), 1, 'Người thứ hai tải lại rồi lưu với phiên bản mới: được');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.save_session_content(pg_temp.s('p', 2), array['Bản cũ của người thứ nhất'], null, (select v from ver where k = 'a')::int)$$), 'HMT_XUNG_DOT', 'Người thứ nhất giữ phiên bản cũ sau khi người thứ hai đã lưu: bị từ chối');
select is(app.session_overview(pg_temp.s('p', 2)) -> 'lines', '["Người thứ hai, sau khi tải lại"]'::jsonb, 'Bản của người thứ hai còn nguyên');
select is((app.session_overview(pg_temp.s('p', 2)) ->> 'content_version')::int, 2, 'Sau lần lưu thứ hai thì phiên bản là 2');
select is(app.save_session_content(pg_temp.s('p', 2), array['Gọi nội bộ không kiểm phiên bản'], null), 1, 'Không gửi phiên bản (null) thì không kiểm');

select * from finish();
rollback;
