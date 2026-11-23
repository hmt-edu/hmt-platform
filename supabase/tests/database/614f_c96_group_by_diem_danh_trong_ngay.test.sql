-- C96 (migration 614): Group By BUOI-11 Điểm danh vận hành trong ngày (absent_today_group_counts): Vắng, Chưa tới; khớp danh sách; phạm vi; chặn trường lạ, giáo viên. Dựng theo test 120.
-- Luật: R-BUOI-02, R-GIO-02, R-GIO-06, R-GIO-08, R-DD-01, R-DD-02, R-DD-03, R-GV-05, R-GV-08, R-GV-13, R-HT-07. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('gv1'), ('cskh1'), ('cskh2'), ('sales1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ba.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ba.hoamatoan.invalid',
       (select id from app.branch where code = case u.key when 'cskh2' then 'CS2' else 'CS1' end), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'gv1' then 'TEACHER' when 'sales1' then 'SALES' else 'CSKH' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS2')
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

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
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHBA1', 'Phụ huynh giả BA', '0900106001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSBA' || n, (select id from app.parent where code = 'PHBA1'), 'Em giả BA ' || n, 2012, (select id from app.branch where code = 'CS1') from generate_series(1, 5) n$$);

-- Buổi: hôm nay (giờ Việt Nam) đã bắt đầu từ 00:00 (chắc chắn đã qua), Đã chốt; hôm qua Done; mai Nháp; hôm nay Nháp.
create function pg_temp.mk(p_no integer, p_date date, p_status text, p_start time, p_end time) returns uuid language plpgsql security definer as $$
declare v_id uuid;
begin
  insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, status_code)
  values ((select id from cl), (select id from app.branch where code = 'CS1'), p_no, p_date, p_start, p_end, pg_temp.uid('gv1'), p_status)
  returning id into v_id;
  return v_id;
end $$;
create temp table se (key text primary key, id uuid);
grant all on se to public;
select pg_temp.sudo($$insert into se values
  ('chot', pg_temp.mk(201, (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'DA_CHOT', '00:00', '00:30')),
  ('done', pg_temp.mk(202, (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1, 'DONE', '18:00', '19:30')),
  ('nhap', pg_temp.mk(203, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1, 'NHAP', '18:00', '19:30')),
  ('chot_chua_bd', pg_temp.mk(204, (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'DA_CHOT', '23:58', '23:59'))$$);
create function pg_temp.sid(p_key text) returns uuid language sql stable as $$ select id from se where key = p_key $$;
create function pg_temp.stid(p_n integer) returns uuid language sql stable security definer as $$ select id from app.student where code = 'HSBA' || p_n $$;
-- Dòng điểm danh buổi chốt: em1 giáo viên Có mặt; em2 giáo viên Vắng không phép (vận hành Có mặt: Lệch) kèm lý do; em3 vận hành Vắng có phép; em4 không ai ghi; thêm một em bị loại.
select pg_temp.sudo($$insert into app.session_attendance (session_id, class_id, branch_id, student_id, teacher_status_code, ops_status_code, contact_reason_code, ops_note)
  select pg_temp.sid('chot'), (select id from cl), (select id from app.branch where code = 'CS1'), pg_temp.stid(n),
         case n when 1 then 'CO_MAT' when 2 then 'VANG_KHONG_PHEP' end, case n when 2 then 'CO_MAT' when 3 then 'VANG_CO_PHEP' end,
         case n when 2 then 'KHONG_NGHE_MAY' end, case n when 2 then 'Gọi hai lần' end
    from generate_series(1, 4) n$$);
select pg_temp.sudo($$insert into app.session_attendance (session_id, class_id, branch_id, student_id)
  select pg_temp.sid('chot_chua_bd'), (select id from cl), (select id from app.branch where code = 'CS1'), pg_temp.stid(1)$$);
select pg_temp.sudo($$insert into app.session_attendance (session_id, class_id, branch_id, student_id, is_active, excluded_reason)
  select pg_temp.sid('chot'), (select id from cl), (select id from app.branch where code = 'CS1'), s.id, false, 'BAO_LUU'
    from app.student s where s.code = 'HSBA5'$$);
grant execute on all functions in schema pg_temp to public;

-- ================= BUOI-01: danh sách buổi =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((app.session_list(jsonb_build_object('class_id', (select id from cl), 'date_to', (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)) ->> 'total')::int, 4,
  'BUOI-01: lọc theo lớp và đến hết ngày mai: 4 buổi giả');
select is((app.session_list(jsonb_build_object('class_id', (select id from cl), 'date_to', (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1, 'status', jsonb_build_array('DONE'))) ->> 'total')::int, 1,
  'BUOI-01: lọc theo tình trạng Done: 1 buổi');
select is((app.session_list(jsonb_build_object('class_id', (select id from cl), 'date_to', (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)) -> 'rows' -> 0 ->> 'session_no')::int, 202,
  'BUOI-01: mặc định xếp theo ngày, giờ tăng dần (hôm qua đứng đầu)');
select is((app.session_list(jsonb_build_object('class_id', (select id from cl), 'date_to', (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1), 'time_desc') -> 'rows' -> 0 ->> 'session_no')::int, 203,
  'BUOI-01: time_desc đưa buổi xa nhất lên đầu');
select is(jsonb_array_length(app.session_list(jsonb_build_object('class_id', (select id from cl), 'date_to', (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1), 'time_asc', 2, 1) -> 'rows'), 2,
  'BUOI-01: phân trang ở máy chủ (số dòng, bỏ qua)');
select ok((app.session_list(jsonb_build_object('class_id', (select id from cl), 'date_to', (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)) -> 'rows' -> 1 ->> 'note') is not null,
  'R-GIO-06: buổi Đã chốt chưa Done kèm lý do chưa Done');
select is((select count(*) from jsonb_array_elements(app.session_list(jsonb_build_object('class_id', (select id from cl), 'date_to', (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)) -> 'rows') r
            where r ->> 'status_code' in ('NHAP', 'DONE') and r ->> 'note' is not null), 0::bigint, 'Chỉ buổi Đã chốt có ghi chú lý do');
reset role;

-- Cơ sở khác không thấy buổi của CS1; giáo viên và Sales (không có quyền xem buổi vận hành đủ phạm vi) bị chặn.
select pg_temp.claims(pg_temp.uid('cskh2'), 'aal1');
set local role authenticated;
select is((app.session_list(jsonb_build_object('class_id', (select id from cl), 'date_to', (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1)) ->> 'total')::int, 0,
  'Phạm vi cơ sở: CSKH cơ sở khác không thấy buổi của CS1');
select is(pg_temp.err($$select app.session_record(pg_temp.sid('chot'))$$), 'HMT_KHONG_CO_QUYEN', 'Phạm vi cơ sở: CSKH cơ sở khác không mở được bản ghi buổi');
select is(pg_temp.err($$select app.session_ops_sheet(pg_temp.sid('chot'))$$), 'HMT_KHONG_CO_QUYEN', 'Phạm vi cơ sở: không mở được điểm danh vận hành của buổi cơ sở khác');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.session_list('{}')$$), 'HMT_KHONG_CO_QUYEN', 'R-GV-08: giáo viên không đọc danh sách buổi vận hành');
select is(pg_temp.err($$select app.session_record(pg_temp.sid('chot'))$$), 'HMT_KHONG_CO_QUYEN', 'R-GV-08: giáo viên không mở bản ghi buổi vận hành');
select is(pg_temp.err($$select app.session_ops_sheet(pg_temp.sid('chot'))$$), 'HMT_KHONG_CO_QUYEN', 'R-DD-02: giáo viên không mở bảng điểm danh vận hành');
select is(pg_temp.err($$select app.absent_today_list('{}')$$), 'HMT_KHONG_CO_QUYEN', 'R-DD-02: giáo viên không đọc danh sách gọi nhắc');
reset role;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.absent_today_list('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Sales chỉ xem điểm danh, không ghi: không đọc danh sách gọi nhắc');
reset role;

-- ================= BUOI-02: bản ghi buổi =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is(app.session_record(pg_temp.sid('chot')) -> 'session' ->> 'status_code', 'DA_CHOT', 'BUOI-02: tình trạng buổi');
select is((app.session_record(pg_temp.sid('chot')) -> 'session' ->> 'branch_id') is not null, true, 'BUOI-13: bản ghi buổi trả branch_id để chọn danh sách giáo viên của cơ sở');
select is(app.session_record(pg_temp.sid('chot')) -> 'session' ? 'teacher_id', true, 'BUOI-13: bản ghi buổi có khoá teacher_id (người đang dạy)');
select is(app.session_record(pg_temp.sid('chot')) -> 'session' ? 'assistant_id', true, 'BUOI-13: bản ghi buổi có khoá assistant_id');
select is(app.session_record(pg_temp.sid('chot')) -> 'session' ->> 'teacher_name', 'Giả gv1', 'BUOI-02: tên giáo viên');
select is((app.session_record(pg_temp.sid('chot')) ->> 'listed')::boolean, true, 'BUOI-02: buổi Đã chốt có danh sách');
select is(jsonb_array_length(app.session_record(pg_temp.sid('chot')) -> 'students'), 4, 'R-GIO-02: 4 em trong danh sách');
select is(jsonb_array_length(app.session_record(pg_temp.sid('chot')) -> 'excluded'), 1, 'R-GIO-02: 1 em không vào danh sách');
select is(app.session_record(pg_temp.sid('chot')) -> 'excluded' -> 0 ->> 'reason_code', 'BAO_LUU', 'R-GIO-02: lý do loại là Bảo lưu');
select is((select count(*) from jsonb_array_elements(app.session_record(pg_temp.sid('chot')) -> 'students') x where (x ->> 'mismatch')::boolean), 1::bigint,
  'R-DD-02: một em lệch giữa hai cột (em 2)');
select is((select x ->> 'teacher_status_name' from jsonb_array_elements(app.session_record(pg_temp.sid('chot')) -> 'students') x where x ->> 'student_code' = 'HSBA2'),
  'Vắng không phép', 'R-DD-02: cột giáo viên của em 2');
select ok(app.session_record(pg_temp.sid('chot')) ->> 'complete_deadline' is not null, 'R-GV-05: buổi Đã chốt có hạn giáo viên hoàn tất');
select ok(app.session_record(pg_temp.sid('done')) ->> 'complete_deadline' is null, 'Buổi Done không có hạn');
select is((app.session_record(pg_temp.sid('nhap')) ->> 'listed')::boolean, false, 'R-GIO-08: buổi Nháp chưa có danh sách');
reset role;
select is(pg_temp.err($$select app.session_record('00000000-0000-0000-0000-000000000000')$$), 'HMT_KHONG_TIM_THAY', 'Không có buổi: báo không tìm thấy')
  from (select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1')) x;

-- ================= BUOI-03: điểm danh vận hành =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is(jsonb_array_length(app.session_ops_sheet(pg_temp.sid('chot')) -> 'students'), 4, 'BUOI-03: 4 em');
select is(jsonb_array_length(app.session_ops_sheet(pg_temp.sid('chot')) -> 'reasons') >= 4, true, 'R-DD-03: danh mục lý do liên hệ có đủ');
select is((select x ->> 'ops_note' from jsonb_array_elements(app.session_ops_sheet(pg_temp.sid('chot')) -> 'students') x where x ->> 'student_code' = 'HSBA2'), 'Gọi hai lần', 'BUOI-03: ghi chú vận hành');
select is((app.session_ops_sheet(pg_temp.sid('nhap')) ->> 'listed')::boolean, false, 'R-GIO-08: buổi Nháp chưa có dòng điểm danh');
select is(app.session_ops_sheet(pg_temp.sid('done')) -> 'session' ->> 'status_code', 'DONE', 'BUOI-03: buổi Done vẫn mở để xem');
reset role;

-- ================= BUOI-11: vắng / chưa đến hôm nay =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((app.absent_today_list(jsonb_build_object('q', 'HSBA')) ->> 'total')::int, 3, 'BUOI-11: 3 em (em 2 Vắng theo giáo viên, em 3 Vắng theo vận hành, em 4 chưa đến); em 1 Có mặt và buổi chưa bắt đầu không hiện');
select is((select r ->> 'kind' from jsonb_array_elements(app.absent_today_list(jsonb_build_object('q', 'HSBA')) -> 'rows') r where r ->> 'student_name' = 'Em giả BA 4'), 'CHUA_DEN', 'BUOI-11: em chưa ai ghi là Chưa đến');
select is((select r ->> 'kind' from jsonb_array_elements(app.absent_today_list(jsonb_build_object('q', 'HSBA')) -> 'rows') r where r ->> 'student_name' = 'Em giả BA 2'), 'VANG', 'R-DD-02: ô giáo viên quyết định: em 2 là Vắng dù vận hành ghi Có mặt');
select is((select r ->> 'contact_reason_name' from jsonb_array_elements(app.absent_today_list(jsonb_build_object('q', 'HSBA')) -> 'rows') r where r ->> 'student_name' = 'Em giả BA 2'), 'Không nghe máy', 'R-DD-03: hiện lý do liên hệ đã ghi');
select is((app.absent_today_list(jsonb_build_object('q', 'HSBA', 'kind', 'VANG')) ->> 'total')::int, 2, 'BUOI-11: lọc Vắng: 2 em');
select is((app.absent_today_list(jsonb_build_object('q', 'HSBA', 'kind', 'CHUA_DEN')) ->> 'total')::int, 1, 'BUOI-11: lọc Chưa đến: 1 em');
select is(jsonb_array_length(app.absent_today_list(jsonb_build_object('q', 'HSBA'), 1, 0) -> 'rows'), 1, 'BUOI-11: phân trang ở máy chủ');
-- Ghi lý do liên hệ bằng hàm D1c (giữ nguyên trạng thái vận hành), rồi đọc lại.
select is(app.set_attendance_ops(pg_temp.sid('chot'), jsonb_build_array(jsonb_build_object('student_id', pg_temp.stid(4), 'status_code', null, 'contact_reason_code', 'DA_NHAC_VAO_LOP'))), 1,
  'R-DD-03: ghi lý do liên hệ cho em chưa đến');
select is((select r ->> 'contact_reason_name' from jsonb_array_elements(app.absent_today_list(jsonb_build_object('q', 'HSBA')) -> 'rows') r where r ->> 'student_name' = 'Em giả BA 4'), 'Đã nhắc vào lớp', 'BUOI-11: đọc lại thấy lý do vừa ghi');
reset role;
select pg_temp.claims(pg_temp.uid('cskh2'), 'aal1');
set local role authenticated;
select is((app.absent_today_list(jsonb_build_object('q', 'HSBA')) ->> 'total')::int, 0, 'Phạm vi cơ sở: CSKH cơ sở khác không thấy em của CS1');
reset role;

-- ================= GV-05: lý do liên hệ chỉ xem =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is((select x ->> 'contact_reason_name' from jsonb_array_elements(app.teacher_attendance_sheet(pg_temp.sid('chot')) -> 'students') x where x ->> 'student_code' = 'HSBA2'), 'Không nghe máy',
  'GV-05: giáo viên thấy tên lý do liên hệ (chỉ xem)');
select is((select count(*) from jsonb_array_elements(app.teacher_attendance_sheet(pg_temp.sid('chot')) -> 'students') x where x ? 'ops_note' or x ? 'phone' or x ? 'parent_id'), 0::bigint,
  'R-GV-13: vẫn không có ghi chú vận hành tự do, số điện thoại, phụ huynh');
reset role;


-- ================= C96 (migration 614): Group By BUOI-11 Điểm danh vận hành trong ngày (absent_today_group_counts) =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((app.absent_today_group_counts(jsonb_build_object('q', 'HSBA'), array['status']) ->> 'total')::int, 3, 'BUOI-11 Group By tình trạng: tổng 3 em');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.absent_today_group_counts(jsonb_build_object('q', 'HSBA'), array['status']) -> 'groups') g where g ->> 'k1' = 'VANG'), 2, 'Nhóm Vắng có 2 em');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.absent_today_group_counts(jsonb_build_object('q', 'HSBA'), array['status']) -> 'groups') g where g ->> 'k1' = 'CHUA_DEN'), 1, 'Nhóm Chưa tới có 1 em');
select is((select g ->> 'l1' from jsonb_array_elements(app.absent_today_group_counts(jsonb_build_object('q', 'HSBA'), array['status']) -> 'groups') g where g ->> 'k1' = 'CHUA_DEN'), 'Chưa tới', 'Nhãn nhóm Chưa tới');
select is((app.absent_today_group_counts(jsonb_build_object('q', 'HSBA', 'kind', 'VANG'), array['status']) ->> 'total')::int, (app.absent_today_list(jsonb_build_object('q', 'HSBA', 'kind', 'VANG')) ->> 'total')::int, 'Số đếm khớp danh sách khi cùng bộ lọc kind (mở nhóm)');
select is(pg_temp.err($$select app.absent_today_group_counts('{}'::jsonb, array['creator'])$$), 'HMT_NHOM_SAI', 'Chặn: trường nhóm không cho phép');
select is(pg_temp.err($$select app.absent_today_group_counts('{}'::jsonb, array['status', 'status'])$$), 'HMT_NHOM_SAI', 'Chặn: hai cấp giống nhau');
reset role;
select pg_temp.claims(pg_temp.uid('cskh2'), 'aal1');
set local role authenticated;
select is((app.absent_today_group_counts(jsonb_build_object('q', 'HSBA'), array['status']) ->> 'total')::int, 0, 'Phạm vi cơ sở: CSKH cơ sở khác không đếm được em của CS1');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.absent_today_group_counts('{}'::jsonb, array['status'])$$), 'HMT_KHONG_CO_QUYEN', 'R-DD-02: giáo viên không đếm được danh sách gọi nhắc');
reset role;

select * from finish();
rollback;
