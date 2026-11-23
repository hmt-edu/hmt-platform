-- Phiếu nghiệp vụ Bảo lưu, Chuyển lớp (migration 262): tạo kiểm dữ liệu, thực hiện bằng hàm áp dụng của cụm Ghi danh (migration 234), công tắc, nguyên tử. Dữ liệu giả (dựng nền như bài 234).
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

-- ================= C-23-13 (migration 625): chuyển lớp khác môn bị chặn ngay lúc tạo phiếu =================
-- Ghi danh 2 đang học lớp A (Toán). Lớp C là Toán, lớp D là Đại (khác môn).
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('cl'), 'CHUYEN_LOP', 'Đổi môn', jsonb_build_object('enrollment_id', pg_temp.e('2'), 'to_class_id', pg_temp.c('d'), 'start_date', pg_temp.mon() + 14, 'kind_code', 'DOI_GIO', 'reason_code', 'KHAC'))$$),
  'HMT_CHUYEN_LOP_KHAC_MON', 'Chặn sớm: phiếu Chuyển lớp sang lớp khác môn báo «Khác môn: dùng Chuyển phí» ngay khi tạo');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('cl'), 'CHUYEN_LOP', 'Đổi giờ', jsonb_build_object('enrollment_id', pg_temp.e('2'), 'to_class_id', pg_temp.c('c'), 'start_date', pg_temp.mon() + 15, 'kind_code', 'DOI_GIO', 'reason_code', 'KHAC'))$$),
  null, 'Đúng: chuyển sang lớp cùng môn tạo được phiếu');
select * from finish();
rollback;
