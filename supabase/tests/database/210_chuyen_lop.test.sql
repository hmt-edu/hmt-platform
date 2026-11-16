-- Migration 210 (Code D): bản ghi Chuyển lớp, chuyển cơ sở.
-- Luật: R-GD-10, R-CS-02, R-CS-03, R-CS-07, R-V2-24. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d210.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d210.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm5', 'CS5'), ('cskh1', 'CS1'), ('sales1', 'CS1'), ('gv1', 'CS1'), ('gv2', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('cskh1', 'CSKH'),
  ('sales1', 'SALES'), ('gv1', 'TEACHER'), ('gv2', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select m, id, true from app.branch, (values ('VAN_HANH_LOP'), ('CHUYEN_LOP')) v (m) where code in ('CS1', 'CS5')
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
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHD210', 'Phụ huynh giả D210', '0900210001', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSD210' || n, (select id from app.parent where code = 'PHD210'), 'Em giả D210 ' || n, 2012, pg_temp.cs('CS1') from generate_series(1, 5) n$$);
create function pg_temp.st(p_n integer) returns uuid language sql stable security definer as $$ select id from app.student where code = 'HSD210' || p_n $$;
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
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e('1'), pg_temp.c('a'), pg_temp.mon());
select app.assign_enrollment_class(pg_temp.e('2'), pg_temp.c('a'), pg_temp.mon());
select app.assign_enrollment_class(pg_temp.e('3'), pg_temp.c('c'), pg_temp.mon() + 1);
create temp table tr (key text primary key, id uuid);
grant all on tr to public;
create function pg_temp.t(p_key text) returns uuid language sql stable as $$ select id from tr where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

-- ================= Công tắc tính năng =================
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'CHUYEN_LOP'$$);
select is(pg_temp.err($$select app.create_class_transfer(pg_temp.e('1'), pg_temp.c('c'), pg_temp.mon() + 1, 'DOI_GIO', 'DOI_LICH_BAN')$$),
          'HMT_TINH_NANG_TAT', 'Chặn: công tắc CHUYEN_LOP tắt thì không tạo yêu cầu chuyển lớp');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'CHUYEN_LOP'$$);

-- ================= Tạo yêu cầu (R-GD-10, R-CS-03) =================
select is(pg_temp.err($$select app.create_class_transfer(pg_temp.e('1'), pg_temp.c('a'), pg_temp.mon(), 'DOI_GIO', 'DOI_LICH_BAN')$$),
          'HMT_CHUYEN_LOP_TRUNG_LOP', 'Chặn: lớp mới trùng lớp đang học');
select is(pg_temp.err($$select app.create_class_transfer(pg_temp.e('1'), pg_temp.c('d'), pg_temp.mon() + 2, 'DOI_GIO', 'DOI_LICH_BAN')$$),
          'HMT_CHUYEN_LOP_KHAC_MON', 'Chặn: chuyển lớp khác môn là chuyển phí (R-CS-03)');
select is(pg_temp.err($$select app.create_class_transfer(pg_temp.e('1'), pg_temp.c('c'), pg_temp.mon() + 1, 'CHUYEN_CO_SO', 'DOI_LICH_BAN')$$),
          'HMT_CHUYEN_LOP_LOAI_SAI', 'Chặn: loại «Chuyển cơ sở» nhưng lớp mới cùng cơ sở');
select is(pg_temp.err($$select app.create_class_transfer(pg_temp.e('1'), pg_temp.c('c'), pg_temp.mon() + 1, 'DOI_GIO', 'KHONG_CO_MA')$$),
          'HMT_DANH_MUC_KHONG_CO', 'Chặn: mã lý do không có trong danh mục');
select is(pg_temp.err($$select app.create_class_transfer(pg_temp.e('1'), pg_temp.c('c'), pg_temp.mon() + 2, 'DOI_GIO', 'DOI_LICH_BAN')$$),
          'HMT_NGAY_VAO_LOP_SAI', 'Chặn: ngày vào lớp mới không phải buổi của lớp (R-GD-06)');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.create_class_transfer(pg_temp.e('1'), pg_temp.c('c'), pg_temp.mon() + 1, 'DOI_GIO', 'DOI_LICH_BAN')$$),
          'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không có quyền Sửa ghi danh nên không tạo yêu cầu');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select lives_ok($$insert into tr select 'k1', app.create_class_transfer(pg_temp.e('1'), pg_temp.c('c'), pg_temp.mon() + 1, 'DOI_GIO', 'DOI_LICH_BAN', 'Bận giờ cũ', 'DN-TEST')$$,
                'Đúng: CSKH tạo yêu cầu chuyển lớp cùng môn');
select is((select status_code from app.class_transfer where id = pg_temp.t('k1')), 'NHAP', 'Yêu cầu mới ở Nháp');
select is((select hours_snapshot from app.class_transfer where id = pg_temp.t('k1')), app.enrollment_hours_balance(pg_temp.e('1')), 'Chụp lại giờ còn lại lúc tạo');
select is(pg_temp.err($$select app.create_class_transfer(pg_temp.e('1'), pg_temp.c('c'), pg_temp.mon() + 1, 'DOI_GIO', 'DOI_LICH_BAN')$$),
          'HMT_CHUYEN_LOP_DANG_MO', 'Chặn: ghi danh đã có yêu cầu chuyển lớp chưa xong');
select is(pg_temp.err($$select app.execute_class_transfer(pg_temp.t('k1'))$$), 'HMT_CHUYEN_LOP_KHONG_DUOC_SUA', 'Chặn: thực hiện khi chưa duyệt');
select is(pg_temp.err($$insert into app.class_transfer (enrollment_id) values (pg_temp.e('1'))$$), '42501', 'Chặn: không ghi thẳng vào bảng yêu cầu chuyển lớp');

-- ================= Trình, duyệt (R-CS-07) =================
select is(pg_temp.err($$select app.approve_class_transfer(pg_temp.t('k1'))$$), 'HMT_CHUYEN_LOP_KHONG_DUOC_SUA', 'Chặn: duyệt khi chưa trình');
select lives_ok($$select app.submit_class_transfer(pg_temp.t('k1'))$$, 'Đúng: trình duyệt');
select is(pg_temp.err($$select app.approve_class_transfer(pg_temp.t('k1'))$$), 'HMT_CHUYEN_LOP_THIEU_QUYEN_DUYET', 'Chặn: CSKH không có quyền duyệt');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.approve_class_transfer(pg_temp.t('k1'))$$), 'HMT_CHUYEN_LOP_THIEU_QUYEN_DUYET', 'Chặn: Trưởng cơ sở khác (CS5) không có quyền duyệt chuyển lớp của CS1');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.reject_class_transfer(pg_temp.t('k1'), '  ')$$), 'HMT_CHUYEN_LOP_THIEU_LY_DO', 'Chặn: từ chối không ghi lý do');
select lives_ok($$select app.approve_class_transfer(pg_temp.t('k1'))$$, 'Đúng: Trưởng cơ sở duyệt chuyển lớp cùng môn');
select is((select status_code from app.class_transfer where id = pg_temp.t('k1')), 'DA_DUYET', 'Cùng môn: một người duyệt là đủ, sang Đã duyệt');
select is(pg_temp.err($$select app.approve_class_transfer(pg_temp.t('k1'))$$), 'HMT_CHUYEN_LOP_KHONG_DUOC_SUA', 'Chặn: duyệt hai lần');

-- ================= Thực hiện (R-GD-10) =================
select lives_ok($$select app.execute_class_transfer(pg_temp.t('k1'))$$, 'Đúng: thực hiện chuyển lớp đã duyệt');
select is((select status_code from app.class_transfer where id = pg_temp.t('k1')), 'DA_CHUYEN', 'Yêu cầu sang Đã chuyển');
select is((select count(*)::int from app.enrollment_class where enrollment_id = pg_temp.e('1') and end_date is null and class_id = pg_temp.c('c')), 1, 'Dòng xếp lớp mới ở lớp C đang mở');
select is((select end_reason from app.enrollment_class where enrollment_id = pg_temp.e('1') and class_id = pg_temp.c('a')), 'CHUYEN_LOP', 'Dòng cũ đóng với lý do chuyển lớp');
select is(pg_temp.err($$select app.execute_class_transfer(pg_temp.t('k1'))$$), 'HMT_CHUYEN_LOP_KHONG_DUOC_SUA', 'Chặn: thực hiện hai lần');
select is(pg_temp.err($$select app.cancel_class_transfer(pg_temp.t('k1'))$$), 'HMT_CHUYEN_LOP_KHONG_DUOC_SUA', 'Chặn: huỷ yêu cầu đã chuyển xong');

-- ================= Người tạo không tự duyệt =================
select lives_ok($$insert into tr select 'k2', app.create_class_transfer(pg_temp.e('2'), pg_temp.c('c'), pg_temp.mon() + 1, 'DOI_GIO', 'KHAC')$$, 'Trưởng cơ sở tạo yêu cầu cho em 2');
select app.submit_class_transfer(pg_temp.t('k2'));
select is(pg_temp.err($$select app.approve_class_transfer(pg_temp.t('k2'))$$), 'HMT_CHUYEN_LOP_TU_DUYET', 'Chặn: người tạo không tự duyệt yêu cầu của mình');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select lives_ok($$select app.reject_class_transfer(pg_temp.t('k2'), 'Phụ huynh đổi ý')$$, 'Đúng: Admin từ chối kèm lý do');
select is((select status_code from app.class_transfer where id = pg_temp.t('k2')), 'TU_CHOI', 'Yêu cầu sang Từ chối');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select lives_ok($$insert into tr select 'k3', app.create_class_transfer(pg_temp.e('2'), pg_temp.c('c'), pg_temp.mon() + 1, 'DOI_GIO', 'KHAC')$$, 'Từ chối xong thì tạo lại được');
select lives_ok($$select app.cancel_class_transfer(pg_temp.t('k3'))$$, 'Đúng: huỷ yêu cầu Nháp');
select is((select status_code from app.class_transfer where id = pg_temp.t('k3')), 'HUY', 'Yêu cầu sang Huỷ');

-- ================= Chuyển cơ sở: cần quản lý cả hai cơ sở (R-CS-07) =================
select lives_ok($$insert into tr select 'k4', app.create_class_transfer(pg_temp.e('3'), pg_temp.c('x5'), pg_temp.mon(), 'CHUYEN_CO_SO', 'DOI_NOI_O')$$, 'Đúng: tạo yêu cầu chuyển cơ sở CS1 sang CS5');
select app.submit_class_transfer(pg_temp.t('k4'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok($$select app.approve_class_transfer(pg_temp.t('k4'))$$, 'Quản lý CS1 duyệt phần cơ sở cũ');
select is((select status_code from app.class_transfer where id = pg_temp.t('k4')), 'CHO_DUYET', 'Chuyển cơ sở: mới một cơ sở duyệt thì vẫn Chờ duyệt');
select is(pg_temp.err($$select app.execute_class_transfer(pg_temp.t('k4'))$$), 'HMT_CHUYEN_LOP_KHONG_DUOC_SUA', 'Chặn: thực hiện chuyển cơ sở khi mới một cơ sở duyệt');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((select count(*)::int from app.class_transfer), 1, 'RLS: quản lý CS5 thấy yêu cầu có lớp mới ở cơ sở mình, không thấy yêu cầu khác của CS1');
select lives_ok($$select app.approve_class_transfer(pg_temp.t('k4'))$$, 'Quản lý CS5 duyệt phần cơ sở mới');
select is((select status_code from app.class_transfer where id = pg_temp.t('k4')), 'DA_DUYET', 'Chuyển cơ sở: đủ hai cơ sở duyệt thì sang Đã duyệt');
select is(pg_temp.err($$select app.execute_class_transfer(pg_temp.t('k4'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: quản lý CS5 không có quyền Sửa ghi danh ở cơ sở cũ CS1 nên không thực hiện');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok($$select app.execute_class_transfer(pg_temp.t('k4'))$$, 'Đúng: thực hiện chuyển cơ sở');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((select branch_id from app.enrollment where id = pg_temp.e('3')), pg_temp.cs('CS5'), 'Ghi danh sang cơ sở mới');
select is(app.enrollment_hours_balance(pg_temp.e('3')), 0.00::numeric, 'Giờ còn lại đi theo ghi danh khi chuyển cơ sở (R-GD-10)');

-- ================= RLS đọc =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is((select count(*)::int from app.class_transfer), 0, 'Giáo viên không thấy yêu cầu chuyển lớp');

select * from finish();
