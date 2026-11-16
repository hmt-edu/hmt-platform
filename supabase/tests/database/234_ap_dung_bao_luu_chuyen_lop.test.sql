-- Migration 234 (Code D): hàm áp dụng bảo lưu và chuyển lớp cho phiếu nghiệp vụ Aftersale. Luật: R-GD-09, R-GD-10, R-CS-03, R-V2-24. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d234.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d234.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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
create temp table tr (key text primary key, id uuid);
grant all on tr to public;
create function pg_temp.t(p_key text) returns uuid language sql stable as $$ select id from tr where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

select pg_temp.sudo($$create function pg_temp.ah(p_enr uuid, p_months integer, p_reason text, p_ext uuid default null) returns uuid language sql security definer as 'select app.apply_enrollment_hold(p_enr, p_months, p_reason, null, ''PNV-TEST'', p_ext)'$$);
select pg_temp.sudo($$create function pg_temp.ac(p_enr uuid, p_to uuid, p_date date, p_kind text, p_reason text) returns uuid language sql security definer as 'select app.apply_class_transfer(p_enr, p_to, p_date, p_kind, p_reason, null, ''PNV-TEST'')'$$);
select pg_temp.sudo($$create function pg_temp.est(p_enr uuid) returns text language sql stable security definer as 'select status_code from app.enrollment where id = p_enr'$$);
select pg_temp.sudo($$create function pg_temp.hs(p_id uuid) returns text language sql stable security definer as 'select status_code || ''/'' || coalesce(end_kind, '''') from app.enrollment_hold where id = p_id'$$);
select pg_temp.sudo($$grant execute on function pg_temp.ah(uuid, integer, text, uuid), pg_temp.ac(uuid, uuid, date, text, text), pg_temp.est(uuid), pg_temp.hs(uuid) to public$$);
create temp table ap (key text primary key, id uuid);
grant all on ap to public;
create function pg_temp.p(p_key text) returns uuid language sql stable as $$ select id from ap where key = p_key $$;
grant execute on function pg_temp.p(text) to public;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');

select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
do $$
declare r record;
begin
  for r in select * from (values ('1', 'a', 0), ('2', 'a', 0), ('3', 'c', 1)) v (k, cls, plus) loop
    if (select status_code from app.enrollment where id = pg_temp.e(r.k)) = 'CHO_XEP_LOP' then
      perform app.assign_enrollment_class(pg_temp.e(r.k), pg_temp.c(r.cls), pg_temp.mon() + r.plus);
    end if;
  end loop;
end $$;

select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours)
  select pg_temp.e(k), (select id from app.branch where code = 'CS1'), 'DAU_KY', 5 from (values ('1'), ('2')) v (k)$$);

-- ================= Quyền gọi và công tắc =================
select is(pg_temp.err($$select app.apply_enrollment_hold(pg_temp.e('1'), 3, 'BAN_THI')$$), '42501', 'Chặn: giao diện không gọi thẳng hàm áp dụng bảo lưu (nội bộ)');
select is(pg_temp.err($$select app.apply_class_transfer(pg_temp.e('1'), pg_temp.c('c'), pg_temp.mon() + 1, 'DOI_GIO', 'KHAC')$$), '42501', 'Chặn: giao diện không gọi thẳng hàm áp dụng chuyển lớp (nội bộ)');
select is(pg_temp.err($$select pg_temp.ah(pg_temp.e('1'), 3, 'BAN_THI')$$), 'HMT_TINH_NANG_TAT', 'Chặn: công tắc BAO_LUU tắt thì không áp dụng bảo lưu');
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'CHUYEN_LOP'$$);
select is(pg_temp.err($$select pg_temp.ac(pg_temp.e('1'), pg_temp.c('c'), pg_temp.mon() + 1, 'DOI_GIO', 'KHAC')$$), 'HMT_TINH_NANG_TAT', 'Chặn: công tắc CHUYEN_LOP tắt thì không áp dụng chuyển lớp');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'CHUYEN_LOP'$$);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAO_LUU', id, true from app.branch where code in ('CS1', 'CS5') on conflict (module_code, branch_id) do update set enabled = true$$);

-- ================= Áp dụng bảo lưu =================
select is(pg_temp.err($$select pg_temp.ah(pg_temp.e('1'), 7, 'BAN_THI')$$), 'HMT_BAO_LUU_QUA_THOI_GIAN', 'R-GD-09: chặn bảo lưu quá reservation_max_months');
select is(pg_temp.err($$select pg_temp.ah(pg_temp.e('1'), 3, 'KHONG_CO_MA')$$), 'HMT_DANH_MUC_KHONG_CO', 'Chặn: mã lý do không có trong danh mục');
select is(pg_temp.err($$select pg_temp.ah(pg_temp.e('1'), 3, 'BAN_THI', gen_random_uuid())$$), 'HMT_BAO_LUU_GIA_HAN_SAI', 'Chặn: gia hạn bản không tồn tại');
select lives_ok($$insert into ap select 'h1', pg_temp.ah(pg_temp.e('1'), 3, 'BAN_THI')$$, 'Đúng: áp dụng bảo lưu 3 tháng');
select is(pg_temp.est(pg_temp.e('1')), 'BAO_LUU', 'Ghi danh sang Bảo lưu ngay');
select is(pg_temp.hs(pg_temp.p('h1')), 'DANG_BAO_LUU/', 'Bản ghi ở Đang bảo lưu, không qua bước duyệt thứ hai');
select is((select start_date from app.enrollment_hold where id = pg_temp.p('h1')), (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'Bảo lưu bắt đầu ở ngày áp dụng');
select is((select end_date from app.enrollment_hold where id = pg_temp.p('h1')), ((now() at time zone 'Asia/Ho_Chi_Minh')::date + interval '3 months')::date, 'Hết hạn sau 3 tháng');
select is((select return_status_code from app.enrollment_hold where id = pg_temp.p('h1')), 'DA_XEP_LOP', 'Nhớ tình trạng trước bảo lưu để trả lại');
select is(app.enrollment_hours_balance(pg_temp.e('1')), 5.00::numeric, 'R-GD-09: giờ còn lại giữ nguyên');
select is(pg_temp.err($$select pg_temp.ah(pg_temp.e('1'), 2, 'BAN_THI')$$), 'HMT_BAO_LUU_GHI_DANH_SAI', 'Chặn: ghi danh đang bảo lưu không bảo lưu mới');
select lives_ok($$insert into ap select 'h2', pg_temp.ah(pg_temp.e('1'), 2, 'GIA_DINH', pg_temp.p('h1'))$$, 'Đúng: áp dụng gia hạn nối tiếp');
select is(pg_temp.hs(pg_temp.p('h1')), 'KET_THUC/GIA_HAN', 'Bản cũ kết thúc kiểu gia hạn');
select is((select start_date from app.enrollment_hold where id = pg_temp.p('h2')), (select end_date from app.enrollment_hold where id = pg_temp.p('h1')), 'Bản gia hạn nối từ ngày hết hạn bản cũ');
select is(pg_temp.err($$select pg_temp.ah(pg_temp.e('1'), 2, 'GIA_DINH', pg_temp.p('h1'))$$), 'HMT_BAO_LUU_GIA_HAN_SAI', 'Chặn: gia hạn bản đã kết thúc');

-- ================= Áp dụng chuyển lớp =================
select is(pg_temp.err($$select pg_temp.ac(pg_temp.e('2'), pg_temp.c('a'), pg_temp.mon(), 'DOI_GIO', 'KHAC')$$), 'HMT_CHUYEN_LOP_TRUNG_LOP', 'Chặn: lớp mới trùng lớp đang học');
select is(pg_temp.err($$select pg_temp.ac(pg_temp.e('2'), pg_temp.c('d'), pg_temp.mon() + 2, 'DOI_GIO', 'KHAC')$$), 'HMT_CHUYEN_LOP_KHAC_MON', 'Chặn: chuyển lớp khác môn là chuyển phí (R-CS-03)');
select is(pg_temp.err($$select pg_temp.ac(pg_temp.e('2'), pg_temp.c('c'), pg_temp.mon() + 1, 'CHUYEN_CO_SO', 'KHAC')$$), 'HMT_CHUYEN_LOP_LOAI_SAI', 'Chặn: loại chuyển cơ sở nhưng lớp mới cùng cơ sở');
select is(pg_temp.err($$select pg_temp.ac(pg_temp.e('2'), pg_temp.c('c'), pg_temp.mon() + 2, 'DOI_GIO', 'KHAC')$$), 'HMT_NGAY_VAO_LOP_SAI', 'Chặn: ngày vào lớp mới không phải buổi của lớp (R-GD-06)');
select lives_ok($$insert into ap select 'c1', pg_temp.ac(pg_temp.e('2'), pg_temp.c('c'), pg_temp.mon() + 1, 'DOI_GIO', 'KHAC')$$, 'Đúng: áp dụng chuyển lớp cùng môn');
select is((select status_code from app.class_transfer where id = pg_temp.p('c1')), 'DA_CHUYEN', 'Bản ghi ở Đã chuyển, không qua duyệt thứ hai');
select is((select count(*)::int from app.enrollment_class where enrollment_id = pg_temp.e('2') and end_date is null and class_id = pg_temp.c('c')), 1, 'Dòng xếp lớp mới ở lớp C đang mở');
select is((select end_reason from app.enrollment_class where enrollment_id = pg_temp.e('2') and class_id = pg_temp.c('a')), 'CHUYEN_LOP', 'Dòng cũ đóng với lý do chuyển lớp');
select is(app.enrollment_hours_balance(pg_temp.e('2')), 5.00::numeric, 'R-GD-10: giờ còn lại đi theo ghi danh');
select is((select ticket_ref from app.class_transfer where id = pg_temp.p('c1')), 'PNV-TEST', 'Giữ mã phiếu nghiệp vụ làm tham chiếu');
select is(pg_temp.err($$select pg_temp.ac(gen_random_uuid(), pg_temp.c('c'), pg_temp.mon() + 1, 'DOI_GIO', 'KHAC')$$), 'HMT_KHONG_TIM_THAY', 'Chặn: ghi danh không tồn tại');
select lives_ok($$insert into ap select 'c2', pg_temp.ac(pg_temp.e('2'), pg_temp.c('a'), pg_temp.mon() + 7, 'DOI_GIO', 'KHAC')$$, 'Đúng: chuyển lại về lớp A (mỗi ghi danh chỉ một yêu cầu mở, bản trước đã Đã chuyển)');
select is(app.enrollment_hours_balance(pg_temp.e('2')), 5.00::numeric, 'Giờ vẫn nguyên sau hai lần chuyển');

select * from finish();
rollback;
