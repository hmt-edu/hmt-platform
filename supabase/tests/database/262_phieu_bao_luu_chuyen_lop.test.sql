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

-- ================= Tạo phiếu Bảo lưu: kiểm dữ liệu =================
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('bl'), 'BAO_LUU', 'Gia đình bận', '{}'::jsonb)$$), 'HMT_PHIEU_DU_LIEU_SAI', 'Chặn: thiếu ghi danh');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('bl'), 'BAO_LUU', 'Gia đình bận', jsonb_build_object('enrollment_id', pg_temp.e('2'), 'months', 3, 'reason_code', 'BAN_THI'))$$), 'HMT_PHIEU_DU_LIEU_SAI', 'Chặn: ghi danh của học sinh khác (không phải học sinh của ticket)');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('bl'), 'BAO_LUU', 'Gia đình bận', jsonb_build_object('enrollment_id', pg_temp.e('1'), 'months', 0, 'reason_code', 'BAN_THI'))$$), 'HMT_PHIEU_DU_LIEU_SAI', 'Chặn: số tháng bảo lưu phải từ 1');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('bl'), 'BAO_LUU', 'Gia đình bận', jsonb_build_object('enrollment_id', pg_temp.e('1'), 'months', 3))$$), 'HMT_PHIEU_DU_LIEU_SAI', 'Chặn: thiếu lý do bảo lưu');
insert into tp select 'bl', (app.create_ticket_task(pg_temp.k('bl'), 'BAO_LUU', 'Gia đình bận', jsonb_build_object('enrollment_id', pg_temp.e('1'), 'months', 3, 'reason_code', 'BAN_THI')) ->> 'id')::uuid;
select is((select status_code from app.ticket_task where id = pg_temp.pk('bl')), 'NHAP', 'Đúng: phiếu Bảo lưu tạo ở Nháp');

-- ================= Tuỳ chọn biểu mẫu (migration 350) =================
select is(jsonb_array_length(app.get_task_form_options(pg_temp.k('bl')) -> 'enrollments'), 1, 'Đúng: tuỳ chọn trả đúng một ghi danh của học sinh gắn ticket');
select is(app.get_task_form_options(pg_temp.k('bl')) -> 'enrollments' -> 0 ->> 'id', pg_temp.e('1')::text, 'Đúng: ghi danh trả về là của học sinh 1');
select ok(jsonb_array_length(app.get_task_form_options(pg_temp.k('bl')) -> 'hold_reasons') > 0, 'Đúng: có lý do bảo lưu');
select ok(jsonb_array_length(app.get_task_form_options(pg_temp.k('bl')) -> 'transfer_reasons') > 0, 'Đúng: có lý do chuyển lớp');
select is(pg_temp.err($$select app.get_task_form_options(gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Chặn: ticket không có');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.get_task_form_options(pg_temp.k('bl'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không có quyền sửa ticket nên không lấy tuỳ chọn');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');

-- ================= Duyệt rồi thực hiện phiếu Bảo lưu =================
select app.submit_ticket_task(pg_temp.pk('bl'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_ticket_task(pg_temp.pk('bl'));
select is((select status_code from app.ticket_task where id = pg_temp.pk('bl')), 'DA_DUYET', 'Quản lý cơ sở duyệt (một cấp): Đã duyệt');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'BAO_LUU'$$);
select is(pg_temp.err($$select app.execute_ticket_task(pg_temp.pk('bl'))$$), 'HMT_TINH_NANG_TAT', 'Chặn: công tắc BAO_LUU tắt thì không thực hiện phiếu Bảo lưu');
select is((select status_code from app.ticket_task where id = pg_temp.pk('bl')), 'DA_DUYET', 'Nguyên tử: lỗi thì phiếu vẫn Đã duyệt, chưa đổi gì');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'BAO_LUU'$$);
select app.execute_ticket_task(pg_temp.pk('bl'));
select is((select status_code from app.ticket_task where id = pg_temp.pk('bl')), 'DA_THUC_HIEN', 'Thực hiện: phiếu Đã thực hiện');
select is((select status_code from app.enrollment where id = pg_temp.e('1')), 'BAO_LUU', 'Ghi danh sang Bảo lưu ngay, không duyệt lần hai (R-V2-24)');
select is((select ticket_ref from app.enrollment_hold where id = (select (result ->> 'hold_id')::uuid from app.ticket_task where id = pg_temp.pk('bl'))),
          (select code from app.ticket where id = pg_temp.k('bl')), 'Bản ghi bảo lưu giữ mã ticket (R-CS-02)');
select is((select status_code from app.ticket where id = pg_temp.k('bl')), 'DA_XU_LY', 'Ticket tự sang Đã xử lý (AS-03)');

-- ================= C30 (migration 423): tuỳ chọn Gia hạn bảo lưu, phiếu Gia hạn =================
select is((select e ->> 'status_code' from jsonb_array_elements(app.get_task_form_options(pg_temp.k('bl')) -> 'enrollments') e where e ->> 'id' = pg_temp.e('1')::text), 'BAO_LUU',
          'C30 Đúng: tuỳ chọn có cả ghi danh đang Bảo lưu (để gia hạn)');
select is(jsonb_array_length(app.get_task_form_options(pg_temp.k('bl')) -> 'holds'), 1, 'C30 Đúng: tuỳ chọn trả bảo lưu đang chạy của học sinh');
select is(app.get_task_form_options(pg_temp.k('bl')) -> 'holds' -> 0 ->> 'enrollment_id', pg_temp.e('1')::text, 'C30 Đúng: bảo lưu đang chạy thuộc ghi danh 1');
insert into tt values ('gh', pg_temp.tk('DN_01_01', 1));
insert into tp select 'gh', (app.create_ticket_task(pg_temp.k('gh'), 'BAO_LUU', 'Chưa thi xong', jsonb_build_object('enrollment_id', pg_temp.e('1'), 'months', 1, 'reason_code', 'BAN_THI',
  'extends_hold_id', (app.get_task_form_options(pg_temp.k('gh')) -> 'holds' -> 0 ->> 'id')::uuid)) ->> 'id')::uuid;
select app.submit_ticket_task(pg_temp.pk('gh'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_ticket_task(pg_temp.pk('gh'));
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.execute_ticket_task(pg_temp.pk('gh'));
select is((select count(*)::int from app.enrollment_hold where enrollment_id = pg_temp.e('1') and kind_code = 'GIA_HAN' and status_code = 'DANG_BAO_LUU'), 1, 'C30 Đúng: phiếu Gia hạn tạo bản gia hạn đang bảo lưu');

-- ================= Phiếu Chuyển lớp =================
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('cl'), 'CHUYEN_LOP', 'Đổi giờ', jsonb_build_object('enrollment_id', pg_temp.e('2'), 'reason_code', 'KHAC'))$$), 'HMT_PHIEU_DU_LIEU_SAI', 'Chặn: phiếu Chuyển lớp thiếu lớp mới, ngày, loại');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('cl'), 'CHUYEN_LOP', 'Chuyển cơ sở', jsonb_build_object('enrollment_id', pg_temp.e('2'), 'to_class_id', pg_temp.c('x5'), 'start_date', pg_temp.mon(), 'kind_code', 'CHUYEN_CO_SO', 'reason_code', 'KHAC'))$$), 'HMT_PHIEU_CHUA_LAM', 'Chặn: Chuyển cơ sở cần hai quản lý duyệt, chưa làm ở phiếu');
insert into tp select 'cl', (app.create_ticket_task(pg_temp.k('cl'), 'CHUYEN_LOP', 'Đổi giờ học', jsonb_build_object('enrollment_id', pg_temp.e('2'), 'to_class_id', pg_temp.c('c'), 'start_date', pg_temp.mon() + 1, 'kind_code', 'DOI_GIO', 'reason_code', 'KHAC')) ->> 'id')::uuid;
select app.submit_ticket_task(pg_temp.pk('cl'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_ticket_task(pg_temp.pk('cl'));
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.execute_ticket_task(pg_temp.pk('cl'));
select is((select status_code from app.ticket_task where id = pg_temp.pk('cl')), 'DA_THUC_HIEN', 'Thực hiện: phiếu Chuyển lớp Đã thực hiện');
select is((select count(*)::int from app.enrollment_class where enrollment_id = pg_temp.e('2') and end_date is null and class_id = pg_temp.c('c')), 1, 'Ghi danh đã sang lớp C');
select is((select ticket_ref from app.class_transfer where id = (select (result ->> 'transfer_id')::uuid from app.ticket_task where id = pg_temp.pk('cl'))),
          (select code from app.ticket where id = pg_temp.k('cl')), 'Bản ghi chuyển lớp giữ mã ticket (R-CS-02)');

-- ================= Loại còn lại vẫn báo chưa làm =================
insert into tp select 'dl', (app.create_ticket_task(pg_temp.k('dl'), 'DOI_LICH', 'Đổi lịch', '{}'::jsonb) ->> 'id')::uuid;
select app.submit_ticket_task(pg_temp.pk('dl'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_ticket_task(pg_temp.pk('dl'));
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.execute_ticket_task(pg_temp.pk('dl'))$$), 'HMT_PHIEU_CHUA_LAM', 'Phiếu Đổi lịch chưa thực hiện được (chưa có hàm áp dụng)');

select * from finish();
rollback;
