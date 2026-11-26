-- Migration 678 (E-26-05): Admin hệ thống làm được bước của CƠ SỞ ĐÍCH khi chuyển cơ sở (phiếu không dính tiền), ở cơ sở khác cơ sở mình.
-- Vai khác không đổi; vẫn giữ «một người không duyệt hai cấp». Dựng nền như bài 568. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@e678a.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@e678a.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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

select pg_temp.sudo($$select pg_temp.mke('1', 1)$$);
select pg_temp.sudo($$select pg_temp.mke('2', 2)$$);
select pg_temp.sudo($$select pg_temp.mke('3', 3)$$);
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
-- ================= Nền: ticket Bảo lưu, Chuyển lớp, Đổi lịch của học sinh 1, 2 (CS1) =================
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select m, id, true from app.branch, (values ('AFTERSALE'), ('BAO_LUU'), ('CHUYEN_LOP')) v (m) where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.tk(p_cat text, p_n integer) returns uuid language sql as $$
  select (app.create_ticket(jsonb_build_object('ticket_type', 'DN', 'branch_id', pg_temp.cs('CS1'), 'title', 'Ticket giả', 'description', 'Mô tả giả', 'channel_code', 'GOI_DIEN',
    'category_code', p_cat, 'parent_id', (select id from app.parent where code = 'PHD210'), 'student_id', pg_temp.st(p_n))) ->> 'id')::uuid $$;
grant execute on function pg_temp.tk(text, integer) to public;
create temp table tt (key text primary key, id uuid);
grant all on tt to public;
create function pg_temp.k(p_key text) returns uuid language sql stable as $$ select id from tt where key = p_key $$;
grant execute on function pg_temp.k(text) to public;
create temp table tp (key text primary key, id uuid);
grant all on tp to public;
create function pg_temp.pk(p_key text) returns uuid language sql stable as $$ select id from tp where key = p_key $$;
grant execute on function pg_temp.pk(text) to public;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
insert into tt values ('bl', pg_temp.tk('DN_01_01', 1)), ('cl', pg_temp.tk('DN_01_03', 2)), ('dl', pg_temp.tk('DN_01_05', 3));

-- ================= CS-07 Chuyển cơ sở: hai quản lý duyệt tuần tự (migration 568) =================
create temp table dst (key text primary key, id uuid);
grant all on dst to public;
create function pg_temp.d(p_key text) returns uuid language sql stable as $$ select id from dst where key = p_key $$;
grant execute on function pg_temp.d(text) to public;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
insert into tt values ('cs', pg_temp.tk('DN_01_04', 2));

select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('cs'), 'CHUYEN_LOP', 'Chuyển cơ sở', jsonb_build_object('enrollment_id', pg_temp.e('2'), 'kind_code', 'CHUYEN_CO_SO', 'dest_branch_id', pg_temp.cs('CS1'), 'reason_code', 'KHAC'))$$),
          'HMT_PHIEU_DU_LIEU_SAI', 'Chặn: cơ sở đích trùng cơ sở của ticket');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('cs'), 'CHUYEN_LOP', 'Chuyển cơ sở', jsonb_build_object('enrollment_id', pg_temp.e('2'), 'kind_code', 'CHUYEN_CO_SO', 'reason_code', 'KHAC'))$$),
          'HMT_PHIEU_DU_LIEU_SAI', 'Chặn: Chuyển cơ sở thiếu cơ sở đích');
-- Dữ liệu giả không có văn phòng: thêm một văn phòng thử (chỉ trong giao dịch của bài).
select pg_temp.sudo($$insert into app.branch (code, name, sort_order, is_office) values ('CS9', 'Văn phòng thử', 99, true)$$);
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('cs'), 'CHUYEN_LOP', 'Chuyển cơ sở', jsonb_build_object('enrollment_id', pg_temp.e('2'), 'kind_code', 'CHUYEN_CO_SO', 'dest_branch_id', pg_temp.cs('CS9'), 'reason_code', 'KHAC'))$$),
          'HMT_PHIEU_DU_LIEU_SAI', 'Chặn: cơ sở đích là văn phòng, không có lớp học');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('cs'), 'CHUYEN_LOP', 'Chuyển cơ sở', jsonb_build_object('enrollment_id', pg_temp.e('2'), 'kind_code', 'CHUYEN_CO_SO', 'dest_branch_id', 'không-phải-uuid', 'reason_code', 'KHAC'))$$),
          'HMT_PHIEU_DU_LIEU_SAI', 'Chặn: cơ sở đích không phải mã hợp lệ');
insert into dst select 'cs', (app.create_ticket_task(pg_temp.k('cs'), 'CHUYEN_LOP', 'Chuyển cơ sở', jsonb_build_object('enrollment_id', pg_temp.e('2'), 'kind_code', 'CHUYEN_CO_SO', 'dest_branch_id', pg_temp.cs('CS5'), 'reason_code', 'KHAC')) ->> 'id')::uuid;
select is((select levels from app.ticket_task where id = pg_temp.d('cs')), array['QUAN_LY_CO_SO', 'QUAN_LY_CO_SO_DICH'], 'Đúng: phiếu chuyển cơ sở có hai cấp duyệt (cơ sở đi rồi cơ sở đến)');
select app.submit_ticket_task(pg_temp.d('cs'));

select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_ticket_task(pg_temp.d('cs'));

-- Vai khác ở cơ sở đi vẫn bị chặn như cũ.
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(jsonb_array_length(app.list_tasks_for_destination()), 0, 'CSKH không thấy danh sách của cơ sở đích');
select is(pg_temp.err($$select app.get_task_for_destination(pg_temp.d('cs'))$$), 'HMT_KHONG_TIM_THAY', 'CSKH không đọc được phiếu ở bước cơ sở đích');
select is(pg_temp.err($$select app.set_task_destination_class(pg_temp.d('cs'), pg_temp.c('x5'), pg_temp.mon())$$), 'HMT_KHONG_CO_QUYEN', 'CSKH không chọn lớp ở cơ sở đích');

-- Bật luật xác thực hai bước (tham số mặc định tắt) để kiểm: Admin chưa qua hai bước không được tính là Admin.
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'mfa_required_enabled'$$);
-- Admin chưa qua xác thực hai bước: không được tính là Admin.
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(jsonb_array_length(app.list_tasks_for_destination()), 0, 'Admin chưa qua hai bước: không thấy phiếu');
-- Admin (cơ sở CS1) làm bước của cơ sở đích CS5.
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(jsonb_array_length(app.list_tasks_for_destination()), 1, 'R-HT-01: Admin thấy phiếu chờ cơ sở đích');
select is(app.get_task_for_destination(pg_temp.d('cs')) -> 'task' ->> 'dest_branch_code', 'CS5', 'Admin đọc được phiếu ở bước cơ sở đích');
select lives_ok($$select app.set_task_destination_class(pg_temp.d('cs'), pg_temp.c('x5'), pg_temp.mon())$$, 'Admin chọn lớp mới ở cơ sở đích');
select lives_ok($$select app.approve_ticket_task(pg_temp.d('cs'))$$, 'Admin duyệt cấp cơ sở đích');
select is((select status_code from app.ticket_task where id = pg_temp.d('cs')), 'DA_DUYET', 'Phiếu Đã duyệt');
select is((select count(*)::int from app.ticket_task_event where task_id = pg_temp.d('cs') and event_type = 'DUYET' and created_by = pg_temp.uid('admin')), 1, 'Nhật ký ghi đúng Admin là người duyệt');

-- Giữ luật: một người không duyệt hai cấp của cùng phiếu, kể cả Admin.
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
insert into tt values ('cs2', pg_temp.tk('DN_01_04', 1));
insert into dst select 'cs2', (app.create_ticket_task(pg_temp.k('cs2'), 'CHUYEN_LOP', 'Chuyển cơ sở', jsonb_build_object('enrollment_id', pg_temp.e('1'), 'kind_code', 'CHUYEN_CO_SO', 'dest_branch_id', pg_temp.cs('CS5'), 'reason_code', 'KHAC')) ->> 'id')::uuid;
select app.submit_ticket_task(pg_temp.d('cs2'));
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.approve_ticket_task(pg_temp.d('cs2'));
select app.set_task_destination_class(pg_temp.d('cs2'), pg_temp.c('x5'), pg_temp.mon());
select is(pg_temp.err($$select app.approve_ticket_task(pg_temp.d('cs2'))$$), 'HMT_PHIEU_MOT_NGUOI_HAI_CAP', 'Admin cũng không duyệt hai cấp của cùng một phiếu');

select * from finish();
rollback;
