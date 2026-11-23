-- Cụm Ghi danh (migration 114): app.enrollment_matching_classes, enrollment_assign_options, assign_enrollments_to_classes, set_order_line_class (BH-08, GD-03).
-- Luật: R-GD-06, R-GD-08 (lớp đã duyệt, còn chỗ), R-GD-14 (ngày vào lớp), R-GD-15 (lớp luân phiên không báo trùng), R-GD-05, phạm vi cơ sở. Dữ liệu giả.
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

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh1'), ('cskh5'), ('sales1'), ('gv1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@gd114.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@gd114.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh5' then 'CS5' else 'CS1' end), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'cskh1' then 'CSKH' when 'cskh5' then 'CSKH' when 'sales1' then 'SALES' else 'TEACHER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
create function pg_temp.w(p_weeks integer) returns date language sql stable as $$ select (date_trunc('week', current_date) + make_interval(weeks => p_weeks))::date $$;
create temp table cl (key text primary key, id uuid);
grant all on cl to public;
create function pg_temp.c(p_key text) returns uuid language sql stable as $$ select id from cl where key = p_key $$;
-- Tạo lớp bằng hàm nghiệp vụ (vai trò Admin); p_repeat = lặp mỗi N tuần; p_first = ngày thứ Hai của buổi đầu; p_max = sĩ số; p_approve = duyệt luôn.
create function pg_temp.mkclass(p_key text, p_branch text, p_subject text, p_grade text, p_first date, p_repeat integer, p_max integer, p_approve boolean, p_weekday integer default 1)
returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_class(jsonb_build_object('branch_id', pg_temp.cs(p_branch), 'year_code', '2627', 'subject_code', p_subject, 'grade_code', p_grade,
    'class_type_code', 'CB', 'level_code', 'A', 'max_students', p_max, 'start_date', p_first, 'total_sessions', 6,
    'slots', jsonb_build_array(jsonb_build_object('weekday', p_weekday, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', p_repeat,
                                                  'first_date', p_first + (p_weekday - 1)))));
  insert into cl values (p_key, (v ->> 'id')::uuid);
  if p_approve then
    perform app.transition_class((v ->> 'id')::uuid, 'DA_TRINH');
    perform app.transition_class((v ->> 'id')::uuid, 'DA_XAC_NHAN');
    perform app.transition_class((v ->> 'id')::uuid, 'DA_DUYET');
  end if;
end $$;
grant execute on all functions in schema pg_temp to public;

-- Gói: Đại (subject DAI), Hình (HINH), Toán chung (TOAN, khớp cả DAI, HINH, TOAN).
select pg_temp.sudo($$insert into app.sales_package (code, name, package_type_code, subject_code, grade_from_code, grade_to_code) values
  ('LC-DAI-K08', 'Đại số 8 giả', 'LC', 'DAI', 'K08', null), ('LC-HINH-K08', 'Hình học 8 giả', 'LC', 'HINH', 'K08', null),
  ('LC-TOAN-K08', 'Toán 8 giả', 'LC', 'TOAN', 'K08', null)$$);
create function pg_temp.pk(p_code text) returns uuid language sql stable security definer as $$ select id from app.sales_package where code = p_code $$;
grant execute on all functions in schema pg_temp to public;

-- Lớp CS1: A Đại (thứ Hai, lặp 2 tuần từ tuần +2), B Hình (thứ Hai, lặp 2 tuần từ tuần +3: luân phiên với A), C Toán (thứ Hai MỖI tuần từ tuần +2),
--          D Đại thứ Ba (không giờ trùng), N Nháp (chưa duyệt), F đầy (sĩ số 1, đã có một em), K khác khối (K05); CS5: X Đại.
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select pg_temp.mkclass('a', 'CS1', 'DAI', 'K08', pg_temp.w(2), 2, 10, true);
select pg_temp.mkclass('b', 'CS1', 'HINH', 'K08', pg_temp.w(3), 2, 10, true);
select pg_temp.mkclass('c', 'CS1', 'TOAN', 'K08', pg_temp.w(2), 1, 10, true);
select pg_temp.mkclass('d', 'CS1', 'DAI', 'K08', pg_temp.w(2), 1, 10, true, 2);
select pg_temp.mkclass('n', 'CS1', 'DAI', 'K08', pg_temp.w(2), 1, 10, false);
select pg_temp.mkclass('f', 'CS1', 'DAI', 'K08', pg_temp.w(4), 1, 1, true);
select pg_temp.mkclass('k', 'CS1', 'DAI', 'K05', pg_temp.w(2), 1, 10, true);
select pg_temp.mkclass('x', 'CS5', 'DAI', 'K08', pg_temp.w(2), 1, 10, true);
reset role;
-- Nhóm lớp: A (Đại) và B (Hình) cùng nhóm.
select pg_temp.sudo($$update app.class set group_id = (select (app.create_class_group(pg_temp.cs('CS1'), 'K08', 'Nhóm 8M1')))
  where id in (pg_temp.c('a'), pg_temp.c('b'))$$);

-- Hồ sơ giả.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHG114A', 'Phụ huynh giả 114', '0900114001', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSG114' || n, (select id from app.parent where code = 'PHG114A'), 'Em giả 114 ' || chr(64 + n), 2012, pg_temp.cs('CS1') from generate_series(1, 4) n$$);
create function pg_temp.st(p_n integer) returns uuid language sql stable security definer as $$ select id from app.student where code = 'HSG114' || p_n $$;
grant execute on all functions in schema pg_temp to public;
-- Ghi danh: E1, E2 của em 1 (Đại, Hình) Chờ xếp lớp; E3 của em 2 Đang học ở lớp C (để thử trùng giờ); E4 em 3 Đang học ở lớp F (làm lớp F đầy).
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, package_id, subject_code, delivery_mode_code, status_code, purchased_hours)
  select v.code, pg_temp.st(v.n), (select parent_id from app.student where id = pg_temp.st(v.n)), pg_temp.cs('CS1'), pg_temp.pk(v.pk), v.subj, 'OFF', v.status, 24
    from (values ('GD114E1', 1, 'LC-DAI-K08', 'DAI', 'CHO_XEP_LOP'), ('GD114E2', 1, 'LC-HINH-K08', 'HINH', 'CHO_XEP_LOP'),
                 ('GD114E3', 2, 'LC-TOAN-K08', 'TOAN', 'DANG_HOC'), ('GD114E4', 3, 'LC-DAI-K08', 'DAI', 'DANG_HOC')) v (code, n, pk, subj, status)$$);
create function pg_temp.en(p_code text) returns uuid language sql stable security definer as $$ select id from app.enrollment where code = p_code $$;
grant execute on all functions in schema pg_temp to public;
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values
  (pg_temp.en('GD114E3'), pg_temp.c('c'), pg_temp.cs('CS1'), current_date), (pg_temp.en('GD114E4'), pg_temp.c('f'), pg_temp.cs('CS1'), current_date)$$);

-- ================= Lớp phù hợp (BH-08, GD-03) =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
create temp table m_dai as select jsonb_array_elements(app.enrollment_matching_classes(pg_temp.pk('LC-DAI-K08'), null, null)) as c;
grant select on m_dai to public;
select is((select string_agg(c ->> 'code', ',' order by c ->> 'code') from m_dai),
  (select string_agg(code, ',' order by code) from app.class where id in (pg_temp.c('a'), pg_temp.c('d'))),
  'Gói Đại: chỉ lớp Đại K08 đã duyệt, còn chỗ, cơ sở mình (không lớp Nháp, lớp đầy, lớp K05, lớp CS5, lớp Hình, lớp Toán)');
select is((select count(*) from m_dai where (c ->> 'group_id') is not null), 1::bigint, 'Lớp trong nhóm lớp có group_id');
select is((select c ->> 'schedule_text' from m_dai where c ->> 'code' = (select code from app.class where id = pg_temp.c('a'))), 'Thứ 2 18:00–19:30', 'Lịch học dạng "Thứ 2 18:00–19:30"');
select is((select c ->> 'schedule_text' from m_dai where c ->> 'code' = (select code from app.class where id = pg_temp.c('d'))), 'Thứ 3 18:00–19:30', 'Lịch học thứ Ba');
select is((select (c ->> 'has_sessions')::boolean from m_dai limit 1), true, 'Lớp đã duyệt có buổi');
select ok((select min((u ->> 'date')::date) >= current_date from m_dai, jsonb_array_elements(c -> 'upcoming') u), 'Buổi sắp tới đều từ hôm nay trở đi');
select ok((select max(jsonb_array_length(c -> 'upcoming')) from m_dai) between 1 and 8, 'Tối đa 8 buổi sắp tới');
select is((select (c ->> 'seats_left')::int from m_dai where c ->> 'code' = (select code from app.class where id = pg_temp.c('a'))), 10, 'Còn đủ 10 chỗ');
select is((select string_agg(c ->> 'code', ',') from jsonb_array_elements(app.enrollment_matching_classes(pg_temp.pk('LC-TOAN-K08'), null, null)) c
            where (c ->> 'code') in (select code from app.class where id = pg_temp.c('c'))), (select code from app.class where id = pg_temp.c('c')),
  'Gói Toán chung khớp cả lớp Toán');
select ok((select count(*) from jsonb_array_elements(app.enrollment_matching_classes(pg_temp.pk('LC-TOAN-K08'), null, null)) c
            where (c ->> 'code') in (select code from app.class where id in (pg_temp.c('a'), pg_temp.c('b'), pg_temp.c('c'), pg_temp.c('d')))) = 4,
  'Gói Toán chung khớp lớp Đại, Hình, Toán (R-GD-06)');
-- Trùng giờ (R-GD-15): em 2 đang học lớp C (thứ Hai mỗi tuần). Lớp A (thứ Hai cách tuần): có buổi trùng; lớp D (thứ Ba): không.
select ok((select (c ->> 'clash_sessions')::int > 0 from jsonb_array_elements(app.enrollment_matching_classes(pg_temp.pk('LC-DAI-K08'), null, pg_temp.st(2))) c
            where c ->> 'code' = (select code from app.class where id = pg_temp.c('a'))), 'Lớp A trùng buổi với lớp C em đang học (clash_sessions > 0)');
select is((select (c ->> 'clash_sessions')::int from jsonb_array_elements(app.enrollment_matching_classes(pg_temp.pk('LC-DAI-K08'), null, pg_temp.st(2))) c
            where c ->> 'code' = (select code from app.class where id = pg_temp.c('d'))), 0, 'Lớp D (thứ Ba) không trùng');
select is((select (c ->> 'clash_sessions')::int from jsonb_array_elements(app.enrollment_matching_classes(pg_temp.pk('LC-HINH-K08'), null, pg_temp.st(1))) c
            where c ->> 'code' = (select code from app.class where id = pg_temp.c('b'))), 0, 'Em chưa học lớp nào: không báo trùng');
-- R-GD-15: em 4 đang học lớp A (ghi danh E5) rồi xét lớp B luân phiên: cùng thứ, giờ nhưng khác tuần: không trùng.
reset role;
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, package_id, subject_code, delivery_mode_code, status_code, purchased_hours)
  values ('GD114E5', pg_temp.st(4), (select parent_id from app.student where id = pg_temp.st(4)), pg_temp.cs('CS1'), pg_temp.pk('LC-DAI-K08'), 'DAI', 'OFF', 'DANG_HOC', 24)$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values (pg_temp.en('GD114E5'), pg_temp.c('a'), pg_temp.cs('CS1'), current_date)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((select (c ->> 'clash_sessions')::int from jsonb_array_elements(app.enrollment_matching_classes(pg_temp.pk('LC-HINH-K08'), null, pg_temp.st(4))) c
            where c ->> 'code' = (select code from app.class where id = pg_temp.c('b'))), 0, 'R-GD-15: lớp B luân phiên với lớp A (cùng thứ, giờ, khác tuần): không báo trùng');
reset role;

select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
set local role authenticated;
select is((select string_agg(c ->> 'code', ',') from jsonb_array_elements(app.enrollment_matching_classes(pg_temp.pk('LC-DAI-K08'), pg_temp.cs('CS1'), null)) c),
  (select code from app.class where id = pg_temp.c('x')), 'Phạm vi cơ sở: CSKH CS5 chỉ thấy lớp CS5 dù truyền cơ sở CS1');
reset role;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select ok(jsonb_array_length(app.enrollment_matching_classes(pg_temp.pk('LC-DAI-K08'), null, null)) >= 2, 'Sale (Đơn hàng · Sửa) cũng chọn lớp được (BH-08)');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.enrollment_matching_classes(pg_temp.pk('LC-DAI-K08'), null, null)$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không chọn lớp được');
reset role;

-- ================= Tuỳ chọn xếp lớp cho ghi danh (GD-03) =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is(jsonb_array_length(app.enrollment_assign_options(pg_temp.en('GD114E1')) -> 'siblings'), 2, 'Hai ghi danh chờ xếp lớp của cùng học sinh');
select is((select count(*) from jsonb_array_elements(app.enrollment_assign_options(pg_temp.en('GD114E1')) -> 'classes') c where c ->> 'code' in (select code from app.class where id in (pg_temp.c('a'), pg_temp.c('d')))), 2::bigint,
  'Lớp lẻ cho ghi danh Đại: lớp Đại phù hợp');
select is(jsonb_array_length(app.enrollment_assign_options(pg_temp.en('GD114E1')) -> 'groups'), 1, 'Một nhóm lớp phù hợp (Nhóm 8M1)');
select is(app.enrollment_assign_options(pg_temp.en('GD114E1')) -> 'groups' -> 0 ->> 'group_name', 'Nhóm 8M1', 'Tên nhóm lớp');
select is(jsonb_array_length(app.enrollment_assign_options(pg_temp.en('GD114E1')) -> 'groups' -> 0 -> 'pairs'), 2, 'Nhóm có cặp cho cả hai ghi danh (Đại → A, Hình → B)');
select is((app.enrollment_assign_options(pg_temp.en('GD114E1')) -> 'groups' -> 0 -> 'pairs' -> 0 ->> 'enrollment_code') || '→' ||
          (select code from app.class where id = pg_temp.c('a')), 'GD114E1→' || (select code from app.class where id = pg_temp.c('a')), 'Ghi danh Đại vào lớp Đại');
select is(app.enrollment_assign_options(pg_temp.en('GD114E1')) -> 'groups' -> 0 -> 'pairs' -> 1 -> 'class' ->> 'code', (select code from app.class where id = pg_temp.c('b')), 'Ghi danh Hình vào lớp Hình');
select is(pg_temp.err(format($$select app.enrollment_assign_options('%s')$$, pg_temp.en('GD114E3'))), null, 'Ghi danh Đang học vẫn xem được tuỳ chọn (xếp lớp bị chặn ở hàm xếp)');
reset role;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
set local role authenticated;
select is(pg_temp.err(format($$select app.enrollment_assign_options('%s')$$, pg_temp.en('GD114E1'))), 'HMT_KHONG_TIM_THAY', 'Ghi danh cơ sở khác: không tìm thấy');
reset role;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err(format($$select app.enrollment_assign_options('%s')$$, pg_temp.en('GD114E1'))), 'HMT_KHONG_CO_QUYEN', 'Sale không xếp lớp (cần Ghi danh · Sửa)');
reset role;

-- ================= Xếp nhiều ghi danh một giao dịch =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is(pg_temp.err(format($$select app.assign_enrollments_to_classes('[{"enrollment_id": "%s", "class_id": "%s", "start_date": "%s"}, {"enrollment_id": "%s", "class_id": "%s", "start_date": "%s"}]')$$,
  pg_temp.en('GD114E1'), pg_temp.c('a'), (select min(session_date) from app.class_session where class_id = pg_temp.c('a')),
  pg_temp.en('GD114E2'), pg_temp.c('b'), current_date - 100)), 'HMT_NGAY_VAO_LOP_SAI', 'Ngày vào lớp sai ở dòng sau: báo lỗi có mã');
reset role;
select is((select status_code from app.enrollment where id = pg_temp.en('GD114E1')), 'CHO_XEP_LOP', 'Atomic: ghi danh đầu chưa được xếp khi dòng sau lỗi');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is(app.assign_enrollments_to_classes(format('[{"enrollment_id": "%s", "class_id": "%s", "start_date": "%s"}, {"enrollment_id": "%s", "class_id": "%s", "start_date": "%s"}]',
  pg_temp.en('GD114E1'), pg_temp.c('a'), (select min(session_date) from app.class_session where class_id = pg_temp.c('a')),
  pg_temp.en('GD114E2'), pg_temp.c('b'), (select min(session_date) from app.class_session where class_id = pg_temp.c('b')))::jsonb), 2, 'Xếp cả hai ghi danh một lần');
reset role;
select is((select string_agg(status_code, ',' order by code) from app.enrollment where code in ('GD114E1', 'GD114E2')), 'DA_XEP_LOP,DA_XEP_LOP', 'Cả hai ghi danh sang Đã xếp lớp');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.assign_enrollments_to_classes('[]')$$), 'HMT_THIEU_THONG_TIN', 'Danh sách rỗng bị chặn');
reset role;

-- ================= Gắn lớp cho dòng đơn Nháp (BH-08) =================
select pg_temp.sudo($$insert into app.sales_order (code, branch_id, renewal_ticket_id, parent_id, priced_on, status_code)
  values ('DH-G114-0001', pg_temp.cs('CS1'), gen_random_uuid(), (select id from app.parent where code = 'PHG114A'), current_date, 'NHAP'),
         ('DH-G114-0002', pg_temp.cs('CS1'), gen_random_uuid(), (select id from app.parent where code = 'PHG114A'), current_date, 'NHAP')$$);
select pg_temp.sudo($$insert into app.sales_order_line (order_id, branch_id, line_no, student_id, package_id, package_code, package_name, package_type_code, delivery_mode_code, unit_code, quantity, unit_price, gross_amount, line_total)
  select o.id, o.branch_id, 1, pg_temp.st(4), pg_temp.pk('LC-DAI-K08'), 'LC-DAI-K08', 'Đại số 8 giả', 'LC', 'OFF', 'GIO', 24, 220000, 5280000, 5280000
    from app.sales_order o where o.code in ('DH-G114-0001', 'DH-G114-0002')$$);
select pg_temp.sudo($$update app.sales_order set status_code = 'DA_TRINH' where code = 'DH-G114-0002'$$);
create function pg_temp.od(p_code text) returns uuid language sql stable security definer as $$ select id from app.sales_order where code = p_code $$;
grant execute on all functions in schema pg_temp to public;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err(format($$select app.set_order_line_class('%s', 1, '%s', '%s')$$, pg_temp.od('DH-G114-0001'), pg_temp.c('d'), (select min(session_date) from app.class_session where class_id = pg_temp.c('d')))),
  null, 'Sale gắn lớp Đại cho dòng đơn Nháp, ngày là buổi sắp tới của lớp');
reset role;
select is((select class_id from app.sales_order_line where order_id = pg_temp.od('DH-G114-0001') and line_no = 1), pg_temp.c('d'), 'Dòng đơn lưu lớp');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(app.order_line_classes(pg_temp.od('DH-G114-0001')) -> 0 ->> 'class_code', (select code from app.class where id = pg_temp.c('d')), 'order_line_classes trả mã lớp của dòng');
select is(jsonb_array_length(app.order_line_classes(pg_temp.od('DH-G114-0002'))), 0, 'Đơn chưa chọn lớp: danh sách rỗng');
reset role;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
set local role authenticated;
select is(pg_temp.err(format($$select app.order_line_classes('%s')$$, pg_temp.od('DH-G114-0001'))), 'HMT_KHONG_CO_QUYEN', 'Đơn cơ sở khác: không xem được lớp của dòng');
reset role;
select isnt((select enrol_start_date from app.sales_order_line where order_id = pg_temp.od('DH-G114-0001') and line_no = 1), null, 'Dòng đơn lưu ngày vào lớp');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err(format($$select app.set_order_line_class('%s', 1, '%s', '%s')$$, pg_temp.od('DH-G114-0001'), pg_temp.c('d'), current_date - 100)), 'HMT_NGAY_VAO_LOP_SAI', 'R-GD-14: ngày vào lớp không phải buổi sắp tới thì chặn');
select is(pg_temp.err(format($$select app.set_order_line_class('%s', 1, '%s', '%s')$$, pg_temp.od('DH-G114-0001'), pg_temp.c('n'), pg_temp.w(2))), 'HMT_LOP_CHUA_DUYET', 'R-GD-08: lớp chưa duyệt bị chặn');
select is(pg_temp.err(format($$select app.set_order_line_class('%s', 1, '%s', '%s')$$, pg_temp.od('DH-G114-0001'), pg_temp.c('f'), pg_temp.w(4))), 'HMT_LOP_HET_CHO', 'R-GD-08: lớp đầy bị chặn');
select is(pg_temp.err(format($$select app.set_order_line_class('%s', 1, '%s', '%s')$$, pg_temp.od('DH-G114-0001'), pg_temp.c('x'), pg_temp.w(2))), 'HMT_LOP_SAI_CO_SO', 'R-GD-06: lớp cơ sở khác bị chặn');
select is(pg_temp.err(format($$select app.set_order_line_class('%s', 1, '%s', '%s')$$, pg_temp.od('DH-G114-0001'), pg_temp.c('b'), pg_temp.w(3))), 'HMT_LOP_SAI_MON', 'R-GD-06: lớp Hình không đúng môn của gói Đại');
select is(pg_temp.err(format($$select app.set_order_line_class('%s', 1, null, null)$$, pg_temp.od('DH-G114-0001'))), null, 'Bỏ lớp (chưa chọn lớp, chờ xếp sau) được phép');
select is(pg_temp.err(format($$select app.set_order_line_class('%s', 1, '%s', '%s')$$, pg_temp.od('DH-G114-0002'), pg_temp.c('d'), pg_temp.w(2) + 1)), 'HMT_DON_DA_KHOA', 'Đơn đã trình không đổi lớp');
select is(pg_temp.err(format($$select app.set_order_line_class('%s', 9, '%s', '%s')$$, pg_temp.od('DH-G114-0001'), pg_temp.c('d'), pg_temp.w(2) + 1)), 'HMT_DONG_KHONG_CO', 'Dòng không có trong đơn');
reset role;
select is((select class_id from app.sales_order_line where order_id = pg_temp.od('DH-G114-0001') and line_no = 1), null, 'Bỏ lớp: dòng đơn không còn lớp');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err(format($$select app.set_order_line_class('%s', 1, null, null)$$, pg_temp.od('DH-G114-0001'))), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không gắn lớp cho đơn');
reset role;

-- ================= G20 (migration 633): cờ «đã có ghi danh khác cùng lớp» trong tuỳ chọn xếp lớp =================
select pg_temp.sudo($$update app.enrollment set status_code = 'DA_XEP_LOP' where id = pg_temp.en('GD114E2')$$);
select pg_temp.sudo($$update app.enrollment_class set class_id = pg_temp.c('a') where enrollment_id = pg_temp.en('GD114E2') and end_date is null$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((select c -> 'same_class_enrollments' from jsonb_array_elements(app.enrollment_assign_options(pg_temp.en('GD114E1')) -> 'classes') c where c ->> 'id' = pg_temp.c('a')::text),
          jsonb_build_array('GD114E2'), 'G20: em đã có ghi danh khác (GD114E2) trong lớp A thì lớp A có cờ kèm mã ghi danh đó');
select is((select c -> 'same_class_enrollments' from jsonb_array_elements(app.enrollment_assign_options(pg_temp.en('GD114E1')) -> 'classes') c where c ->> 'id' = pg_temp.c('d')::text),
          '[]'::jsonb, 'G20: lớp D em chưa có ghi danh nào khác thì mảng rỗng');
select is((select count(*)::int from jsonb_array_elements(app.enrollment_assign_options(pg_temp.en('GD114E1')) -> 'classes') c where not (c ? 'same_class_enrollments')), 0, 'G20: mọi lớp đều có khoá same_class_enrollments');
reset role;
select pg_temp.sudo($$update app.enrollment_class set end_date = start_date, end_reason = 'NHAP_NHAM' where enrollment_id = pg_temp.en('GD114E2') and class_id = pg_temp.c('a')$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((select c -> 'same_class_enrollments' from jsonb_array_elements(app.enrollment_assign_options(pg_temp.en('GD114E1')) -> 'classes') c where c ->> 'id' = pg_temp.c('a')::text),
          '[]'::jsonb, 'G20: ghi danh đã rời lớp A thì không còn tính là «đã có ghi danh cùng lớp»');
select is(pg_temp.err(format($$select app.enrollment_assign_options('%s')$$, pg_temp.en('GD114E1'))), null, 'G20: quyền không đổi: CSKH cơ sở mình vẫn xem được');
reset role;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
set local role authenticated;
select is(pg_temp.err(format($$select app.enrollment_assign_options('%s')$$, pg_temp.en('GD114E1'))), 'HMT_KHONG_TIM_THAY', 'G20: cơ sở khác vẫn không thấy');
reset role;

select * from finish();
rollback;
