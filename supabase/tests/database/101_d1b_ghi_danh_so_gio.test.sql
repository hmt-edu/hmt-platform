-- D1b (migration 101): ghi danh, dòng xếp lớp, sổ giờ.
-- Luật: R-GD-01, 02, 04, 05, 06, 08, 10, 15, 18; R-LOP-04; R-GV-13 (giáo viên không thấy sổ giờ). Dữ liệu giả.
-- Cấp giờ theo tiền (R-TIEN-20, 21, 24) kiểm ở 103_d1b_cap_gio_theo_tien.test.sql.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Migration 577: hàm trợ giúp không cấp cho authenticated; bài kiểm gọi qua hàm bọc chạy bằng quyền chủ (pg_temp).
create function pg_temp.class_seats_left(p uuid) returns integer language sql security definer as $$ select app.class_seats_left(p) $$;
grant execute on function pg_temp.class_seats_left(uuid) to public;

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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d1b.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d1b.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm5', 'CS5'), ('cskh1', 'CS1'), ('sales1', 'CS1'), ('gv1', 'CS1'), ('gv2', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('cskh1', 'CSKH'),
  ('sales1', 'SALES'), ('gv1', 'TEACHER'), ('gv2', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
create function pg_temp.mon() returns date language sql stable as $$ select (date_trunc('week', current_date) + interval '14 days')::date $$;
create temp table cl (key text primary key, id uuid);
grant all on cl to public;
create function pg_temp.c(p_key text) returns uuid language sql stable as $$ select id from cl where key = p_key $$;
-- Lớp: p_wd thứ trong tuần (1 = Hai), p_first ngày buổi đầu, p_rep lặp mỗi N tuần, sĩ số tối đa.
create function pg_temp.mkclass(p_key text, p_branch text, p_wd integer, p_first date, p_rep integer, p_max integer, p_subject text default 'TOAN') returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_class(jsonb_build_object('branch_id', pg_temp.cs(p_branch), 'year_code', '2627', 'subject_code', p_subject, 'grade_code', 'K08',
    'class_type_code', 'CB', 'level_code', 'A', 'max_students', p_max, 'start_date', pg_temp.mon(), 'total_sessions', 4,
    'slots', jsonb_build_array(jsonb_build_object('weekday', p_wd, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', p_rep,
                                                  'first_date', p_first, 'teacher_id', pg_temp.uid('gv1')))));
  insert into cl values (p_key, (v ->> 'id')::uuid);
end $$;
create function pg_temp.approve(p_key text) returns void language plpgsql as $$
begin
  perform app.transition_class(pg_temp.c(p_key), 'DA_TRINH');
  perform app.transition_class(pg_temp.c(p_key), 'DA_XAC_NHAN');
  perform app.transition_class(pg_temp.c(p_key), 'DA_DUYET');
end $$;
grant execute on all functions in schema pg_temp to public;

-- Hồ sơ giả: một phụ huynh, năm học sinh.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHD1B01', 'Phụ huynh giả D1b', '0900101001', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSD1B0' || n, (select id from app.parent where code = 'PHD1B01'), 'Em giả D1b ' || n, 2012, pg_temp.cs('CS1') from generate_series(1, 5) n$$);
create function pg_temp.st(p_n integer) returns uuid language sql stable security definer as $$ select id from app.student where code = 'HSD1B0' || p_n $$;
create temp table en (key text primary key, id uuid);
grant all on en to public;
create function pg_temp.e(p_key text) returns uuid language sql stable as $$ select id from en where key = p_key $$;
-- Ghi danh giả (không qua đơn): p_key, học sinh số n.
create function pg_temp.mke(p_key text, p_n integer) returns void language plpgsql security definer as $$
declare v_id uuid;
begin
  insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code)
  values ('GDT' || p_key, pg_temp.st(p_n), (select parent_id from app.student where id = pg_temp.st(p_n)), pg_temp.cs('CS1'), 'TOAN')
  returning id into v_id;
  insert into en values (p_key, v_id);
end $$;
grant execute on all functions in schema pg_temp to public;

-- Từ đây chạy với vai trò đăng nhập thật (RLS và quyền gọi hàm có hiệu lực).
set local role authenticated;
-- Hai gói giả: Toán khối 8 và Lý khối 8 (seed chỉ có gói khối 9).
select pg_temp.sudo($$insert into app.sales_package (code, name, package_type_code, subject_code, grade_from_code, grade_to_code)
  values ('LC-TOAN-K08', 'Toán lớp 8 giả', 'LC', 'TOAN', 'K08', null), ('LC-LY-K08', 'Lý lớp 8 giả', 'LC', 'LY', 'K08', null)$$);
select pg_temp.sudo($$create function pg_temp.withhours(p_class uuid) returns text[] language sql security definer as 'select app.class_students_with_hours(p_class)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.withhours(uuid) to public$$);
-- ---------- Lớp mẫu ----------
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('a', 'CS1', 1, pg_temp.mon(), 1, 2);          -- thứ Hai, hàng tuần, tối đa 2
select pg_temp.mkclass('b', 'CS1', 1, pg_temp.mon(), 1, 0);          -- cùng giờ với A: trùng
select pg_temp.mkclass('c', 'CS1', 2, pg_temp.mon() + 1, 1, 0);      -- thứ Ba
select pg_temp.mkclass('d', 'CS1', 3, pg_temp.mon() + 2, 2, 0, 'DAI');  -- luân phiên: thứ Tư, 2 tuần, bắt đầu tuần 1
select pg_temp.mkclass('e', 'CS1', 3, pg_temp.mon() + 9, 2, 0, 'HINH'); -- luân phiên: thứ Tư, 2 tuần, bắt đầu tuần 2
select pg_temp.mkclass('n', 'CS1', 4, pg_temp.mon() + 3, 1, 0);      -- lớp Nháp (chưa duyệt)
select pg_temp.approve('a');
select pg_temp.approve('b');
select pg_temp.approve('c');
select pg_temp.approve('d');
select pg_temp.approve('e');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select pg_temp.mkclass('x5', 'CS5', 1, pg_temp.mon(), 1, 0);
select pg_temp.approve('x5');

-- ================= Mã ghi danh =================
select pg_temp.sudo($$create function pg_temp.gdcode() returns text language sql security definer as 'select app.issue_enrollment_code()'$$);
select pg_temp.sudo($$grant execute on function pg_temp.gdcode() to public$$);
select ok(pg_temp.gdcode() ~ '^GD\d{6}$', 'Mã ghi danh GD + 6 số (spec 02)');

-- ================= Chỗ còn lại, xếp lớp (R-GD-05, 06, 08) =================
select pg_temp.sudo($$select pg_temp.mke('1', 1)$$);
select pg_temp.sudo($$select pg_temp.mke('2', 2)$$);
select pg_temp.sudo($$select pg_temp.mke('3', 3)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.class_seats_left(pg_temp.c('a')), 2, 'Lớp sĩ số tối đa 2: còn 2 chỗ (R-GD-08)');
select is(pg_temp.class_seats_left(pg_temp.c('b')), null, 'Sĩ số tối đa 0 = không giới hạn (R-GD-08)');
select is(pg_temp.err($$select app.assign_enrollment_class(pg_temp.e('1'), pg_temp.c('a'), null)$$), 'HMT_NGAY_VAO_LOP_THIEU', 'Chặn: xếp lớp thiếu ngày vào lớp (R-GD-06)');
select is(pg_temp.err($$select app.assign_enrollment_class(pg_temp.e('1'), pg_temp.c('a'), pg_temp.mon() + 1)$$), 'HMT_NGAY_VAO_LOP_SAI', 'Chặn: ngày vào lớp không phải một buổi của lớp (R-GD-06)');
select is(pg_temp.err($$select app.assign_enrollment_class(pg_temp.e('1'), pg_temp.c('n'), pg_temp.mon() + 3)$$), 'HMT_LOP_CHUA_DUYET', 'Chặn: lớp chưa duyệt (R-GD-08)');
select is(pg_temp.err($$select app.assign_enrollment_class(pg_temp.e('1'), pg_temp.c('x5'), pg_temp.mon())$$), 'HMT_LOP_SAI_CO_SO', 'Chặn: lớp ở cơ sở khác (R-GD-08)');
select lives_ok($$select app.assign_enrollment_class(pg_temp.e('1'), pg_temp.c('a'), pg_temp.mon())$$, 'Đúng: xếp lớp chọn một buổi của lớp (R-GD-06)');
select is((select status_code from app.enrollment where id = pg_temp.e('1')), 'DA_XEP_LOP', 'Ghi danh sang Đã xếp lớp (R-GD-05)');
select is((select count(*)::int from app.enrollment_class where enrollment_id = pg_temp.e('1') and end_date is null), 1, 'Có đúng một dòng xếp lớp đang mở (R-GD-02)');
select is(pg_temp.err($$select app.assign_enrollment_class(pg_temp.e('1'), pg_temp.c('c'), pg_temp.mon() + 1)$$), 'HMT_GHI_DANH_KHONG_CHO_XEP', 'Chặn: ghi danh đã xếp lớp không xếp lần đầu nữa, đổi lớp qua ticket (R-GD-10)');
select lives_ok($$select app.assign_enrollment_class(pg_temp.e('2'), pg_temp.c('a'), pg_temp.mon())$$, 'Đúng: em thứ hai vào lớp');
select is(pg_temp.class_seats_left(pg_temp.c('a')), 0, 'Lớp đủ 2 em: hết chỗ');
select is(pg_temp.err($$select app.assign_enrollment_class(pg_temp.e('3'), pg_temp.c('a'), pg_temp.mon())$$), 'HMT_LOP_HET_CHO', 'Chặn: lớp đã đủ sĩ số tối đa (R-GD-08)');
select is(pg_temp.err($$select app.check_order_line_class(1, pg_temp.c('a'), null, pg_temp.cs('CS1'))$$), 'HMT_LOP_HET_CHO', 'Kiểm lớp trên dòng đơn cũng chặn lớp đầy (R-GD-08)');
select is(pg_temp.err($$select app.check_order_line_class(1, gen_random_uuid(), null, pg_temp.cs('CS1'))$$), 'HMT_LOP_KHONG_TIM_THAY', 'Kiểm lớp trên dòng đơn: lớp không có thì báo (R-GD-08)');
select is(pg_temp.err($$select app.check_order_line_class(1, pg_temp.c('n'), null, pg_temp.cs('CS1'))$$), 'HMT_LOP_CHUA_DUYET', 'Kiểm lớp trên dòng đơn: lớp chưa duyệt bị chặn (R-GD-08)');
-- Gói sai khối, sai môn.
select is(pg_temp.err($$select app.check_order_line_class(1, pg_temp.c('c'), (select id from app.sales_package where code = 'LC-LY-K08'), pg_temp.cs('CS1'))$$),
          'HMT_LOP_SAI_MON', 'Kiểm lớp: gói khác môn của lớp bị chặn (R-GD-08)');
select is(pg_temp.err($$select app.check_order_line_class(1, pg_temp.c('c'), (select id from app.sales_package where code = 'LC-TOAN-K09'), pg_temp.cs('CS1'))$$),
          'HMT_LOP_SAI_KHOI', 'Kiểm lớp: gói khối 9 không vào lớp khối 8 (R-GD-08)');
select lives_ok($$select app.check_order_line_class(1, pg_temp.c('c'), (select id from app.sales_package where code = 'LC-TOAN-K08'), pg_temp.cs('CS1'))$$, 'Kiểm lớp: gói Toán khối 8 vào lớp Toán khối 8 hợp lệ (R-GD-08)');

-- ================= Trùng giờ (R-GD-15) =================
select pg_temp.sudo($$select pg_temp.mke('4', 1)$$);   -- em số 1, ghi danh thứ hai
select is(pg_temp.err($$select app.assign_enrollment_class(pg_temp.e('4'), pg_temp.c('b'), pg_temp.mon())$$), 'HMT_XEP_LOP_TRUNG_GIO',
          'Chặn: lớp B trùng giờ với lớp A em đang học, kể cả ghi danh khác (R-GD-15)');
select lives_ok($$select app.assign_enrollment_class(pg_temp.e('4'), pg_temp.c('c'), pg_temp.mon() + 1)$$, 'Đúng: lớp khác thứ không trùng giờ (R-GD-15)');
select pg_temp.sudo($$select pg_temp.mke('5', 4)$$);
select lives_ok($$select app.assign_enrollment_class(pg_temp.e('5'), pg_temp.c('d'), pg_temp.mon() + 2)$$, 'Đúng: lớp luân phiên Đại, em vào lớp D');
select pg_temp.sudo($$select pg_temp.mke('6', 4)$$);
select lives_ok($$select app.assign_enrollment_class(pg_temp.e('6'), pg_temp.c('e'), pg_temp.mon() + 9)$$, 'Đúng: lớp luân phiên Hình cùng thứ giờ nhưng lệch tuần không bị chặn (R-GD-15)');

-- ================= Sổ giờ chỉ thêm, điều chỉnh (R-GD-04, R-GD-18) =================
select pg_temp.sudo($$select app.add_opening_hours(pg_temp.e('1'), 6, 'DOT-1')$$);
select is(app.enrollment_hours_balance(pg_temp.e('1')), 6.00::numeric, 'Số dư đầu kỳ ghi vào sổ giờ (R-V2-33)');
select is(pg_temp.err($$select app.adjust_enrollment_hours(pg_temp.e('1'), 1, 'BU_GIO_LOI_TRUNG_TAM')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH không điều chỉnh giờ (GD-05: chỉ Trưởng cơ sở, Admin, Kế toán)');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.adjust_enrollment_hours(pg_temp.e('1'), 1, 'BU_GIO_LOI_TRUNG_TAM')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: quản lý cơ sở khác không điều chỉnh giờ ghi danh CS1');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.adjust_enrollment_hours(pg_temp.e('1'), 0, 'BU_GIO_LOI_TRUNG_TAM')$$), 'HMT_GIO_DIEU_CHINH_SAI', 'Chặn: điều chỉnh 0 giờ');
select is(pg_temp.err($$select app.adjust_enrollment_hours(pg_temp.e('1'), 1, 'KHONG_CO_LY_DO')$$), 'HMT_DANH_MUC_KHONG_CO', 'Chặn: lý do không có trong danh mục (R-GD-04)');
select is(pg_temp.err($$select app.adjust_enrollment_hours(pg_temp.e('1'), 1, 'KHAC')$$), 'HMT_CAN_GHI_CHU', 'Chặn: lý do "Khác" bắt buộc ghi chú');
select is(pg_temp.err($$select app.adjust_enrollment_hours(pg_temp.e('1'), -7, 'SUA_SAI_DANH_SACH_DIEM_DANH')$$), 'HMT_QUY_GIO_AM', 'Chặn: bớt giờ làm quỹ âm (R-GD-18)');
-- F7: số giờ nhập tự do ngoài phạm vi báo mã HMT, không lọt lỗi thô của DB.
select is(pg_temp.err($$select app.adjust_enrollment_hours(pg_temp.e('1'), 10000, 'BU_GIO_LOI_TRUNG_TAM')$$), 'HMT_GIO_DIEU_CHINH_SAI', 'F7 chặn: quá 9999 giờ');
select is(pg_temp.err($$select app.adjust_enrollment_hours(pg_temp.e('1'), 1000000000, 'BU_GIO_LOI_TRUNG_TAM')$$), 'HMT_GIO_DIEU_CHINH_SAI', 'F7 chặn: số cực lớn không còn lỗi tràn số 22003');
select is(pg_temp.err($$select app.adjust_enrollment_hours(pg_temp.e('1'), 0.001, 'BU_GIO_LOI_TRUNG_TAM')$$), 'HMT_GIO_DIEU_CHINH_SAI', 'F7 chặn: làm tròn 2 số lẻ ra 0 không còn lỗi ràng buộc 23514');
select is(pg_temp.err($$select app.adjust_enrollment_hours(pg_temp.e('1'), -0.004, 'SUA_SAI_DANH_SACH_DIEM_DANH')$$), 'HMT_GIO_DIEU_CHINH_SAI', 'F7 chặn: số âm làm tròn ra 0 cũng bị chặn');
-- Migration 690 (anh chốt 27/11): Trưởng cơ sở được cộng giờ ở cơ sở mình (đủ ba vai nằm ở 471).
select is(app.adjust_enrollment_hours(pg_temp.e('1'), 2, 'BU_GIO_LOI_TRUNG_TAM'), 8.00::numeric, 'Đúng: Trưởng cơ sở cộng 2 giờ, số dư 8 (R-GD-04)');
select is(app.adjust_enrollment_hours(pg_temp.e('1'), -3, 'SUA_SAI_DANH_SACH_DIEM_DANH'), 5.00::numeric, 'Đúng: dòng ngược dấu bớt 3 giờ, số dư 5 (R-GD-04)');
select is((select count(*)::int from app.hour_ledger where enrollment_id = pg_temp.e('1')), 3, 'Sổ giờ có 3 dòng (đầu kỳ, +2, −3), không dòng nào bị sửa');
select is(pg_temp.err($$select pg_temp.sudo('update app.hour_ledger set hours = 99 where enrollment_id = ''' || pg_temp.e('1') || '''')$$), 'HMT_SO_GIO_CHI_THEM', 'Chặn: sửa dòng sổ giờ (R-GD-04)');
select is(pg_temp.err($$select pg_temp.sudo('delete from app.hour_ledger where enrollment_id = ''' || pg_temp.e('1') || '''')$$), 'HMT_KHONG_XOA', 'Chặn: xoá dòng sổ giờ (R-GD-04)');

-- ================= Đóng lớp: còn học sinh còn giờ (R-LOP-04) =================
select is(array_length(pg_temp.withhours(pg_temp.c('a')), 1), 1, 'Lớp A còn 1 em còn giờ (em có số dư 5, em kia 0)');
select is(pg_temp.err($$select app.transition_class(pg_temp.c('a'), 'DA_DONG')$$), 'HMT_LOP_CON_HOC_SINH_CON_GIO', 'Chặn: đóng lớp khi còn học sinh còn giờ, nêu tên (R-LOP-04)');
select lives_ok($$select app.transition_class(pg_temp.c('e'), 'DA_DONG')$$, 'Đúng: đóng lớp khi mọi em đều hết giờ (R-LOP-04)');

-- ================= Chuyển lớp (R-GD-10) =================
-- Hàm nội bộ cho ticket A1 (không cấp cho giao diện): thử bằng quyền chủ.
select is(pg_temp.err($$select app.move_enrollment_class(pg_temp.e('1'), pg_temp.c('c'), pg_temp.mon() + 1, 'DN-TEST')$$), '42501', 'Chặn: giao diện không gọi thẳng chuyển lớp, chỉ qua ticket đã duyệt (R-GD-10)');
select pg_temp.sudo($$select app.move_enrollment_class(pg_temp.e('1'), pg_temp.c('c'), pg_temp.mon() + 8, 'DN-TEST')$$);
select is((select count(*)::int from app.enrollment_class where enrollment_id = pg_temp.e('1')), 2, 'Chuyển lớp: có hai dòng xếp lớp (cũ đã đóng, mới đang mở) (R-GD-10)');
select is((select count(*)::int from app.enrollment_class where enrollment_id = pg_temp.e('1') and end_date is null and class_id = pg_temp.c('c')), 1, 'Dòng mới ở lớp C đang mở');
select is((select end_reason from app.enrollment_class where enrollment_id = pg_temp.e('1') and class_id = pg_temp.c('a')), 'CHUYEN_LOP', 'Dòng cũ đóng với lý do chuyển lớp');
select is(app.enrollment_hours_balance(pg_temp.e('1')), 5.00::numeric, 'Giờ còn lại đi theo ghi danh khi chuyển lớp (R-GD-10)');
select is(pg_temp.class_seats_left(pg_temp.c('a')), 1, 'Chuyển đi thì lớp cũ trả lại một chỗ');

-- ================= RLS =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select ok((select count(*) from app.enrollment) > 0, 'Giáo viên được phân công thấy ghi danh trong lớp mình');
select is((select count(*)::int from app.hour_ledger), 0, 'Giáo viên không thấy sổ giờ (R-GV-13)');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is((select count(*)::int from app.enrollment), 0, 'Giáo viên không được phân công không thấy ghi danh');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select ok((select count(*) from app.hour_ledger) > 0, 'Tuyển sinh thấy sổ giờ cơ sở mình');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((select count(*)::int from app.enrollment), 0, 'Trưởng cơ sở CS5 không thấy ghi danh CS1');
select is(pg_temp.err($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) values (pg_temp.e('1'), pg_temp.cs('CS1'), 'DAU_KY', 1)$$), '42501', 'Chặn: không ghi thẳng vào sổ giờ, chỉ qua hàm nghiệp vụ');

select * from finish();
rollback;
