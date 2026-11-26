-- GV (migration 107): dữ liệu đọc cho giáo viên, nội dung buổi, điều kiện nội dung khi Done.
-- Luật: R-GV-08, R-GV-13, R-GIO-06, R-GIO-08, R-V2-35, R-V2-37, Q-198, Q-208. Dữ liệu giả; ngày tính từ hôm nay.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Migration 577: hàm trợ giúp không cấp cho authenticated; bài kiểm gọi qua hàm bọc chạy bằng quyền chủ (pg_temp).
create function pg_temp.session_pending_reason(p uuid) returns text language sql security definer as $$ select app.session_pending_reason(p) $$;
grant execute on function pg_temp.session_pending_reason(uuid) to public;

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

-- ================= Buổi của tôi (R-GV-08, R-V2-37) =================
select is((app.teacher_my_sessions('CAN_LAM') ->> 'total')::int, 3, 'GV-12: giáo viên thấy 3 buổi đã kết thúc mà chưa Done của mình (R-V2-37)');
select is((app.teacher_my_sessions('NGAY', pg_temp.fut(), pg_temp.fut()) ->> 'total')::int, 1, 'GV-02: chế độ ngày chỉ hiện buổi của đúng ngày, không kèm buổi quá hạn (R-V2-37)');
select is((app.teacher_my_sessions('NGAY', pg_temp.past(), pg_temp.past()) -> 'rows' -> 0 ->> 'my_role'), 'GIAO_VIEN', 'Dòng buổi ghi vai trò giáo viên');
select is((app.teacher_my_sessions('CAN_LAM', null, null, 1, 0) -> 'rows' -> 1), null, 'Phân trang: limit 1 chỉ trả một dòng');
select is((app.teacher_my_sessions('CAN_LAM', null, null, 1, 0) ->> 'total')::int, 3, 'Phân trang: tổng vẫn là 3');
select is(jsonb_array_length(app.teacher_my_sessions('CAN_LAM', null, null, 1000, 0) -> 'rows'), 3, 'Trần phân trang không làm lỗi khi xin quá lớn');
select is(pg_temp.err($$select app.teacher_my_sessions('SAI')$$), 'HMT_THAM_SO_SAI', 'Chặn: chế độ xem không hợp lệ');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is((app.teacher_my_sessions('CAN_LAM') ->> 'total')::int, 0, 'Giáo viên khác không thấy buổi của gv1 (R-GV-08)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((app.teacher_my_sessions('CAN_LAM') ->> 'total')::int, 0, 'Vận hành không phải giáo viên của buổi thì "buổi của tôi" trống');

-- ================= Danh sách em (R-GIO-08, R-GV-13) =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(jsonb_array_length(app.teacher_session_students(pg_temp.s('p', 1)) -> 'students'), 3, 'Buổi Đã chốt: giáo viên thấy 3 em');
select is(app.teacher_session_students(pg_temp.s('f', 1)) ->> 'listed', 'false', 'Buổi chưa chốt: không hiện danh sách em (R-GIO-08)');
select is(jsonb_array_length(app.teacher_session_students(pg_temp.s('f', 1)) -> 'students'), 0, 'Buổi chưa chốt: danh sách rỗng (R-GIO-08)');
select is((app.teacher_session_students(pg_temp.s('p', 1)) -> 'students' -> 0) ? 'phone', false, 'Không có số điện thoại trong danh sách em (R-GV-13)');
select is((select count(*)::int from jsonb_object_keys(app.teacher_session_students(pg_temp.s('p', 1)) -> 'students' -> 0)), 6, 'Mỗi em chỉ 6 trường: không có học phí, phụ huynh (R-GV-13)');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.teacher_session_students(pg_temp.s('p', 1))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không xem danh sách em (R-GV-08)');
select is(pg_temp.err($$select app.session_overview(pg_temp.s('p', 1))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không xem tiến độ buổi');

-- ================= Nội dung buổi (R-V2-35, R-GIO-08) =================
select is(pg_temp.err($$select app.save_session_content(pg_temp.s('p', 1), array['Bài 1'])$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công không lưu nội dung (R-GV-08)');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.save_session_content(pg_temp.s('p', 1), array[]::text[], 'BTVN')$$), 'HMT_THIEU_NOI_DUNG', 'Chặn: không có dòng nội dung nào (R-V2-35)');
select is(pg_temp.err($$select app.save_session_content(pg_temp.s('p', 1), array['  ', ''], null)$$), 'HMT_THIEU_NOI_DUNG', 'Chặn: dòng trống không tính là nội dung (R-V2-35)');
select is(app.save_session_content(pg_temp.s('f', 1), array['Phương trình bậc nhất', '  ', 'Bài tập 1 đến 5'], null), 2, 'Lưu được nội dung khi buổi chưa chốt; dòng trống bị bỏ (R-GIO-08)');
select is((app.session_overview(pg_temp.s('f', 1)) ->> 'has_content')::boolean, true, 'Tiến độ: bước nội dung đã xong sau khi lưu');
select is(app.session_overview(pg_temp.s('f', 1)) ->> 'homework_text', null, 'BTVN để trống = buổi này không giao, vẫn lưu được (R-V2-35)');
select is(app.save_session_content(pg_temp.s('f', 1), array['Phương trình bậc nhất'], '  Bài 6 đến 10  '), 1, 'Lưu lại thay cả bộ dòng, ghi BTVN');
select is((select string_agg(line_text, '|' order by sort_order) from app.session_content_line where session_id = pg_temp.s('f', 1) and is_active), 'Phương trình bậc nhất', 'Lưu lại thay hết dòng cũ');
select is(app.session_overview(pg_temp.s('f', 1)) ->> 'homework_text', 'Bài 6 đến 10', 'BTVN được cắt khoảng trắng đầu cuối');
select is((select count(*)::int from app.session_content where session_id = pg_temp.s('f', 1)), 1, 'Mỗi buổi đúng một dòng nội dung chung');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is((select count(*)::int from app.session_content), 0, 'RLS: giáo viên khác không đọc được nội dung buổi của gv1');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is((select count(*)::int from app.session_content_line where is_active), 1, 'RLS: giáo viên đọc được dòng nội dung buổi của mình');

-- ================= Điều kiện Done khi tham số Tắt (Q-198, Q-208, R-V2-35) =================
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'session_done_requires_review'$$);
select is(pg_temp.session_pending_reason(pg_temp.s('p', 1)), 'Giáo viên chưa nhập nội dung buổi.', 'Tắt: đã điểm danh xong nhưng chưa có nội dung thì chặn Done (Q-208)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select pg_temp.sudo('select app.mark_session_done(''' || pg_temp.s('p', 1) || '''::uuid)')$$), 'HMT_BUOI_CHUA_DONE_DUOC', 'Tắt: chốt Done bị chặn khi thiếu nội dung buổi (Q-208)');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(app.save_session_content(pg_temp.s('p', 1), array['Ôn tập chương 1'], null), 1, 'Giáo viên nhập nội dung, không BTVN');
select is((select status_code from app.class_session where id = pg_temp.s('p', 1)), 'DONE', 'Tắt: có nội dung (BTVN trống) là đủ, giáo viên lưu xong thì Done ngay (R-V2-35, Q-208, A-23-12)');
select is(pg_temp.session_pending_reason(pg_temp.s('p', 2)), null, 'Tắt: buổi Kiểm tra không đòi dòng nội dung (khung GV-06 kiểm tra, Q-231)');
select is((select status_code from app.class_session where id = pg_temp.s('p', 1)), 'DONE', 'Tắt: có nội dung thì buổi Done được');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.save_session_content(pg_temp.s('p', 1), array['Sửa'], null)$$), 'HMT_BUOI_DA_DONE', 'Chặn: buổi Done thì giáo viên không sửa nội dung (R-GV-08)');
select is((app.teacher_my_sessions('CAN_LAM') ->> 'total')::int, 2, 'Buổi đã Done rời khỏi danh sách Cần làm');
-- Nhánh Bật: điều kiện nhận xét vẫn đứng như D2.
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'session_done_requires_review'$$);
select is(pg_temp.session_pending_reason(pg_temp.s('p', 2)), 'Buổi kiểm tra chưa đặt điểm tối đa và cách nhập điểm.', 'Bật: điều kiện của buổi kiểm tra giữ như D2, không đòi dòng nội dung (Q-231)');
-- Nhánh Bật, hai chiều (Q-231): buổi thường thiếu nội dung thì chặn trước cả nhận xét; có nội dung thì sang điều kiện nhận xét.
select is(pg_temp.session_pending_reason(pg_temp.s('p', 3)), 'Buổi kiểm tra chưa đặt điểm tối đa và cách nhập điểm.', 'Bật: buổi Kiểm tra thứ hai cũng chỉ bị chặn vì chưa cấu hình điểm');
select pg_temp.sudo($$update app.class_session set type_code = 'CHINH' where id = pg_temp.s('p', 3)$$);
select ok(pg_temp.session_pending_reason(pg_temp.s('p', 3)) like 'Giáo viên chưa nhập nội dung buổi.%', 'Bật: buổi thường thiếu nội dung thì chặn Done (Q-231)');
select pg_temp.sudo($$insert into app.session_content_line (session_id, branch_id, sort_order, line_text) select id, branch_id, 1, 'Nội dung giả' from app.class_session where id = pg_temp.s('p', 3)$$);
select is(pg_temp.session_pending_reason(pg_temp.s('p', 3)), 'Giáo viên chưa mở phần nhận xét của buổi.', 'Bật: đã có nội dung thì chuyển sang điều kiện nhận xét như D2 (Q-231)');

select * from finish();
rollback;
