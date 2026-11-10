-- GV-05 (migration 111): app.teacher_attendance_sheet và app.save_attendance_teacher.
-- Luật: R-DD-01, R-DD-02, R-GV-08, R-GV-09 (hai người cùng sửa một ô), R-GV-13, R-GIO-07, R-GIO-08, R-V2-36 (cờ has_review). Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('gv1'), ('ta1'), ('gv2');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@gv05.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, case u.key when 'ta1' then 'Lê Thu Hà (giả)' else 'Giả ' || u.key end, u.key || '@gv05.hoamatoan.invalid',
       (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'ta1' then 'TA' else 'TEACHER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

-- Lớp (tạo bằng hàm nghiệp vụ, bắt đầu 2 tuần sau để không sinh buổi trong quá khứ), rồi chèn buổi và dòng điểm danh thẳng bằng quyền cao.
create temp table cl (id uuid);
grant all on cl to public;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
insert into cl select (app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS1'), 'year_code', '2627',
  'subject_code', 'TOAN', 'grade_code', 'K08', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
  'start_date', (date_trunc('week', current_date) + interval '14 days')::date, 'total_sessions', 5,
  'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
     'first_date', (date_trunc('week', current_date) + interval '14 days')::date, 'teacher_id', pg_temp.uid('gv1'))))) ->> 'id')::uuid;
reset role;
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHG05A', 'Phụ huynh giả GV05', '0900105001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSG05' || n, (select id from app.parent where code = 'PHG05A'), 'Em giả GV05 ' || n, 2012, (select id from app.branch where code = 'CS1') from generate_series(1, 3) n$$);
create function pg_temp.mk(p_no integer, p_status text, p_type text) returns uuid language plpgsql security definer as $$
declare v_id uuid;
begin
  insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, assistant_id, status_code, type_code)
  values ((select id from cl), (select id from app.branch where code = 'CS1'), p_no, current_date - 1, '18:00', '19:30', pg_temp.uid('gv1'), pg_temp.uid('ta1'), p_status, p_type)
  returning id into v_id;
  return v_id;
end $$;
create temp table se (key text primary key, id uuid);
grant all on se to public;
select pg_temp.sudo($$insert into se values ('chot', pg_temp.mk(101, 'DA_CHOT', 'CHINH')), ('nhap', pg_temp.mk(102, 'NHAP', 'CHINH')), ('done', pg_temp.mk(103, 'DONE', 'CHINH'))$$);
create function pg_temp.sid(p_key text) returns uuid language sql stable as $$ select id from se where key = p_key $$;
create function pg_temp.stid(p_n integer) returns uuid language sql stable security definer as $$ select id from app.student where code = 'HSG05' || p_n $$;
-- Dòng điểm danh: buổi chốt và buổi done có em 1, 2, 3 (em 3 là học thử); buổi nháp chưa có dòng.
select pg_temp.sudo($$insert into app.session_attendance (session_id, class_id, branch_id, student_id, is_trial)
  select pg_temp.sid(k), (select id from cl), (select id from app.branch where code = 'CS1'), pg_temp.stid(n), n = 3
    from unnest(array['chot', 'done']) k, generate_series(1, 3) n$$);
create function pg_temp.marked(p_n integer) returns text language sql stable security definer as $$
  select teacher_marked_at::text from app.session_attendance where session_id = pg_temp.sid('chot') and student_id = pg_temp.stid(p_n) $$;
create function pg_temp.status(p_n integer) returns text language sql stable security definer as $$
  select teacher_status_code from app.session_attendance where session_id = pg_temp.sid('chot') and student_id = pg_temp.stid(p_n) $$;

grant execute on all functions in schema pg_temp to public;

-- ================= Đọc bảng điểm danh =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is((app.teacher_attendance_sheet(pg_temp.sid('chot')) ->> 'listed')::boolean, true, 'R-GIO-08: buổi Đã chốt có danh sách');
select is(jsonb_array_length(app.teacher_attendance_sheet(pg_temp.sid('chot')) -> 'students'), 3, 'Danh sách đủ 3 em');
select is(app.teacher_attendance_sheet(pg_temp.sid('chot')) -> 'session' ->> 'subject_name', (select name from app.catalog_item where catalog_code = 'SUBJECT' and code = 'TOAN'),
  'Tiêu đề buổi có tên môn');
select is(app.teacher_attendance_sheet(pg_temp.sid('chot')) -> 'session' ->> 'start_time', '18:00', 'Tiêu đề buổi có giờ bắt đầu');
select is((select string_agg(x ->> 'code', ',' order by ord) from jsonb_array_elements(app.teacher_attendance_sheet(pg_temp.sid('chot')) -> 'statuses') with ordinality t(x, ord)),
  'CO_MAT,DI_MUON,VANG_CO_PHEP,VANG_KHONG_PHEP', 'R-DD-01: 4 trạng thái lấy từ danh mục, đúng thứ tự');
select is((select count(*) from jsonb_array_elements(app.teacher_attendance_sheet(pg_temp.sid('chot')) -> 'students') x
            where x ? 'phone' or x ? 'parent_id' or x ? 'contact_reason_code' or x ? 'ops_note'), 0::bigint,
  'R-GV-13: không có số điện thoại, phụ huynh, lý do liên hệ, ghi chú vận hành');
select is((select count(*) from jsonb_array_elements(app.teacher_attendance_sheet(pg_temp.sid('chot')) -> 'students') x where (x ->> 'is_trial')::boolean), 1::bigint,
  'Em học thử có cờ is_trial');
select is((app.teacher_attendance_sheet(pg_temp.sid('nhap')) ->> 'listed')::boolean, false, 'R-GIO-08: buổi Nháp chưa có danh sách (listed = false)');
select is(jsonb_array_length(app.teacher_attendance_sheet(pg_temp.sid('nhap')) -> 'students'), 0, 'Buổi Nháp: danh sách rỗng');
select is((app.teacher_attendance_sheet(pg_temp.sid('done')) ->> 'listed')::boolean, true, 'Buổi Done vẫn đọc được (chỉ xem)');
reset role;

-- Giáo viên khác, hoặc chưa đăng nhập: không xem được (R-GV-08).
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.teacher_attendance_sheet(pg_temp.sid('chot'))$$), 'HMT_KHONG_CO_QUYEN', 'R-GV-08: giáo viên không được phân công không xem được');
select is(pg_temp.err($$select app.save_attendance_teacher(pg_temp.sid('chot'), '[]')$$), 'HMT_KHONG_CO_QUYEN', 'R-GV-08: giáo viên không được phân công không lưu được');
reset role;
select set_config('request.jwt.claims', '', true);
set local role authenticated;
select is(pg_temp.err($$select app.teacher_attendance_sheet(pg_temp.sid('chot'))$$), 'HMT_KHONG_CO_QUYEN', 'Chưa đăng nhập: không xem được');
reset role;

-- ================= Lưu điểm danh =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(app.save_attendance_teacher(pg_temp.sid('chot'), jsonb_build_array(
  jsonb_build_object('student_id', pg_temp.stid(1), 'status_code', 'CO_MAT', 'base_marked_at', null),
  jsonb_build_object('student_id', pg_temp.stid(2), 'status_code', 'VANG_CO_PHEP', 'base_marked_at', null))) ->> 'saved', '2',
  'R-DD-02: giáo viên lưu 2 ô, không xung đột');
reset role;
select is(pg_temp.status(1), 'CO_MAT', 'Ô em 1 ghi Có mặt');
select is(pg_temp.status(2), 'VANG_CO_PHEP', 'Ô em 2 ghi Vắng có phép');
select isnt(pg_temp.marked(1), null, 'Có giờ ghi của ô (để so xung đột)');

-- Cả bài chạy trong một giao dịch nên now() không đổi: lùi giờ ghi các ô vừa lưu 5 phút để các lần lưu sau có giờ khác nhau như ngoài thực tế.
select pg_temp.sudo($$update app.session_attendance set teacher_marked_at = teacher_marked_at - interval '5 minutes' where session_id = pg_temp.sid('chot') and teacher_marked_at is not null$$);
-- Hai người cùng sửa một ô (R-GV-09): trợ giảng sửa em 1 sang Đi muộn; giáo viên (cầm giờ ghi cũ) lưu em 1 Vắng không phép và em 3 Có mặt.
select pg_temp.sudo($$create temp table old1 as select pg_temp.marked(1) as m$$);
select pg_temp.sudo($$grant select on old1 to public$$);
select pg_temp.claims(pg_temp.uid('ta1'), 'aal1');
set local role authenticated;
select is(app.save_attendance_teacher(pg_temp.sid('chot'), jsonb_build_array(
  jsonb_build_object('student_id', pg_temp.stid(1), 'status_code', 'DI_MUON', 'base_marked_at', (select m from old1)))) ->> 'saved', '1',
  'R-GV-09: trợ giảng lưu được (cùng quyền với giáo viên)');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
create temp table cf as select app.save_attendance_teacher(pg_temp.sid('chot'), jsonb_build_array(
  jsonb_build_object('student_id', pg_temp.stid(1), 'status_code', 'VANG_KHONG_PHEP', 'base_marked_at', (select m from old1)),
  jsonb_build_object('student_id', pg_temp.stid(3), 'status_code', 'CO_MAT', 'base_marked_at', null))) as r;
select is((select r ->> 'saved' from cf), '0', 'R-GV-09: có ô vênh thì không ghi gì (kể cả ô không vênh)');
select is(jsonb_array_length((select r -> 'conflicts' from cf)), 1, 'Trả đúng 1 ô vênh');
select is((select r -> 'conflicts' -> 0 ->> 'marked_by_name' from cf), 'Lê Thu Hà (giả)', 'Ô vênh nêu tên người vừa sửa');
select is((select r -> 'conflicts' -> 0 ->> 'current_status_code' from cf), 'DI_MUON', 'Ô vênh nêu trạng thái hiện tại');
reset role;
select is(pg_temp.status(1), 'DI_MUON', 'Ô em 1 vẫn là của trợ giảng (chưa ghi đè)');
select is(pg_temp.status(3), null, 'Ô em 3 chưa ghi (cả lần lưu bị hoãn)');

-- "Giữ của tôi": gọi lại với giờ ghi hiện tại làm gốc thì ghi.
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(app.save_attendance_teacher(pg_temp.sid('chot'), jsonb_build_array(
  jsonb_build_object('student_id', pg_temp.stid(1), 'status_code', 'VANG_KHONG_PHEP', 'base_marked_at', pg_temp.marked(1)),
  jsonb_build_object('student_id', pg_temp.stid(3), 'status_code', 'CO_MAT', 'base_marked_at', null))) ->> 'saved', '2',
  'Giữ của tôi: gọi lại với giờ ghi hiện tại thì ghi cả hai ô');
reset role;
select is(pg_temp.status(1), 'VANG_KHONG_PHEP', 'Ô em 1 giờ là của giáo viên');

-- Không phải vênh thật: người kia đã lưu đúng trạng thái mình định lưu.
select pg_temp.sudo($$create temp table old1b as select pg_temp.marked(1) as m$$);
select pg_temp.sudo($$grant select on old1b to public$$);
select pg_temp.claims(pg_temp.uid('ta1'), 'aal1');
set local role authenticated;
select app.save_attendance_teacher(pg_temp.sid('chot'), jsonb_build_array(jsonb_build_object('student_id', pg_temp.stid(1), 'status_code', 'CO_MAT', 'base_marked_at', (select m from old1b))));
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(app.save_attendance_teacher(pg_temp.sid('chot'), jsonb_build_array(
  jsonb_build_object('student_id', pg_temp.stid(1), 'status_code', 'CO_MAT', 'base_marked_at', (select m from old1b)))) -> 'conflicts', '[]'::jsonb,
  'Không báo vênh khi trạng thái hiện tại đã đúng bằng trạng thái định lưu');

-- Xoá ô về trống (status_code trống): hợp lệ.
select is(app.save_attendance_teacher(pg_temp.sid('chot'), jsonb_build_array(
  jsonb_build_object('student_id', pg_temp.stid(3), 'status_code', '', 'base_marked_at', pg_temp.marked(3)))) ->> 'saved', '1', 'Xoá ô về chưa điểm danh');
reset role;
select is(pg_temp.status(3), null, 'Ô em 3 về trống');

-- Lỗi từ app.set_attendance_teacher giữ nguyên mã.
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.save_attendance_teacher(pg_temp.sid('done'), '[]')$$), 'HMT_BUOI_DA_DONE', 'R-GIO-07: buổi Done thì giáo viên không lưu được');
select is(pg_temp.err($$select app.save_attendance_teacher(pg_temp.sid('nhap'), '[]')$$), 'HMT_BUOI_CHUA_CHOT', 'R-GIO-08: buổi chưa chốt thì không lưu được');
select is(pg_temp.err(format($$select app.save_attendance_teacher(pg_temp.sid('chot'), '[{"student_id": "%s", "status_code": "CO_MAT"}]')$$, gen_random_uuid())),
  'HMT_EM_KHONG_TRONG_DANH_SACH', 'R-GV-08: không tạo dòng, em không trong danh sách bị chặn');
select ok(pg_temp.err(format($$select app.save_attendance_teacher(pg_temp.sid('chot'), '[{"student_id": "%s", "status_code": "KHONG_CO", "base_marked_at": "%s"}]')$$, pg_temp.stid(1), pg_temp.marked(1))) is not null,
  'Trạng thái ngoài danh mục bị chặn');
reset role;

-- Cờ has_review (R-V2-36): em có điểm nhận xét thì hộp xác nhận hiện ở giao diện.
select pg_temp.sudo($$insert into app.session_review_criterion (session_id, branch_id, criterion_id, group_code, name, sort_order)
  select s.id, s.branch_id, rc.id, rc.group_code, rc.name, rc.sort_order
    from app.class_session s join app.class c on c.id = s.class_id join lateral app.review_criteria_for_subject(c.subject_code) rc on true
   where s.id = pg_temp.sid('chot') on conflict do nothing$$);
select pg_temp.sudo($$insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score)
  select sa.session_id, sa.branch_id, rc.id, sa.id, 'DA_DANH_GIA', 3
    from app.session_attendance sa join app.session_review_criterion rc on rc.session_id = sa.session_id
   where sa.session_id = pg_temp.sid('chot') and sa.student_id = pg_temp.stid(2) limit 1$$);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is((select x ->> 'has_review' from jsonb_array_elements(app.teacher_attendance_sheet(pg_temp.sid('chot')) -> 'students') x
            where x ->> 'student_id' = pg_temp.stid(2)::text), 'true', 'R-V2-36: em đã có điểm nhận xét có cờ has_review');
select is((select x ->> 'has_review' from jsonb_array_elements(app.teacher_attendance_sheet(pg_temp.sid('chot')) -> 'students') x
            where x ->> 'student_id' = pg_temp.stid(1)::text), 'false', 'Em chưa có điểm: has_review = false');
reset role;

select * from finish();
rollback;
