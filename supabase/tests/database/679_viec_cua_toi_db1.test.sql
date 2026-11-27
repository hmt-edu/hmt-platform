begin;
-- Migration 679 (E-26-04): app.list_my_work, «Việc của tôi» PR DB1. Luật: quyền theo phân hệ và cơ sở (không quyền mới), «của tôi / cả đội»,
-- gom thẻ theo phụ huynh, phân trang theo thẻ, khử trùng lịch nhắc phiếu kiểm tra. Dữ liệu giả.
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
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1'), ('sales5'), ('cskh1'), ('bm1'), ('gv1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@e679.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@e679.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('sales1', 'CS1'), ('sales5', 'CS5'), ('cskh1', 'CS1'), ('bm1', 'CS1'), ('gv1', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('sales5', 'SALES'), ('cskh1', 'CSKH'),
                                        ('bm1', 'BRANCH_MANAGER'), ('gv1', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
insert into app.feature_flag (module_code, branch_id, enabled) select 'DIEM_DANH_TRONG_NGAY', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
grant execute on function pg_temp.uid(text), pg_temp.cs(text) to public;

-- Dữ liệu dựng thẳng (tắt trigger và khoá ngoại trong giao dịch của bài): chỉ để thử hàm đọc.
create temp table id (key text primary key, id uuid not null default gen_random_uuid());
insert into id (key) values ('p1'), ('l1'), ('l2'), ('l5'), ('s1'), ('t1'), ('a1'), ('a2'), ('a3'), ('a4'), ('a6'), ('k1'), ('sp'), ('sn'), ('at'), ('u1'), ('u2'), ('en'), ('hd');
grant select on id to authenticated;
create function pg_temp.i(p_key text) returns uuid language sql stable as $$ select id from id where key = p_key $$;
grant execute on function pg_temp.i(text) to public;
create function pg_temp.today() returns date language sql stable as $$ select (now() at time zone 'Asia/Ho_Chi_Minh')::date $$;
grant execute on function pg_temp.today() to public;

set local session_replication_role = replica;
insert into app.parent (id, code, full_name, phone, branch_id) values (pg_temp.i('p1'), 'PHE679', 'Phụ huynh giả 679', '0900679001', pg_temp.cs('CS1'));
insert into app.student (id, code, parent_id, full_name, birth_year, branch_id) values (pg_temp.i('s1'), 'HSE679', pg_temp.i('p1'), 'Em giả 679', 2013, pg_temp.cs('CS1'));
insert into app.lead (id, code, parent_name, parent_phone, parent_id, branch_id, owner_id, source_type_code, source_code)
select pg_temp.i(v.k), 'LDE679' || v.k, 'Phụ huynh lead ' || v.k, v.phone, case when v.k = 'l1' then pg_temp.i('p1') end, pg_temp.cs(v.cs), pg_temp.uid(v.own), 'MARKETING', 'WEBSITE'
  from (values ('l1', '0900679001', 'CS1', 'sales1'), ('l2', '0900679002', 'CS1', 'sales1'), ('l5', '0900679005', 'CS5', 'sales5')) v (k, phone, cs, own);
insert into app.student_test (id, code, opportunity_id, prospect_student_id, student_id, branch_id, test_branch_id, created_branch_id, subject_code, grade_code, mode_code, level_code, scheduled_at, owner_id)
select pg_temp.i('t1'), 'PKE679', gen_random_uuid(), gen_random_uuid(), pg_temp.i('s1'), pg_temp.cs('CS1'), pg_temp.cs('CS1'), pg_temp.cs('CS1'), 'TOAN', 'K08', 'OFFLINE', 'CB',
       now() + interval '1 hour', pg_temp.uid('sales1');
insert into app.appointment (id, lead_id, activity_code, scheduled_at, title, owner_id, branch_id)
select pg_temp.i(v.k), pg_temp.i(v.lead), 'GOI_DIEN', now() + v.plus::interval, 'Hẹn giả ' || v.k, pg_temp.uid(v.own), pg_temp.cs(v.cs)
  from (values ('a1', 'l1', '-3 hours', 'sales1', 'CS1'), ('a2', 'l2', '2 days', 'sales1', 'CS1'), ('a3', 'l2', '40 days', 'sales1', 'CS1'),
               ('a4', 'l5', '-3 hours', 'sales5', 'CS5')) v (k, lead, plus, own, cs);
insert into app.appointment (id, student_test_id, is_auto_reminder, activity_code, scheduled_at, title, owner_id, branch_id)
values (pg_temp.i('a6'), pg_temp.i('t1'), true, 'GOI_DIEN', now() - interval '1 hour', 'Nhắc phiếu giả', pg_temp.uid('sales1'), pg_temp.cs('CS1'));
insert into app.class (id, code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions, status_code, cskh_id)
values (pg_temp.i('k1'), 'LOPE679', pg_temp.cs('CS1'), '2627', 'TOAN', 'K08', 'CB', 'A', pg_temp.today() - 7, 4, 'DA_DUYET', pg_temp.uid('cskh1'));
insert into app.class_session (id, class_id, branch_id, session_no, session_date, start_time, end_time, status_code, teacher_id)
values (pg_temp.i('sp'), pg_temp.i('k1'), pg_temp.cs('CS1'), 1, pg_temp.today() - 1, '08:00', '09:00', 'DA_CHOT', pg_temp.uid('gv1')),
       (pg_temp.i('sn'), pg_temp.i('k1'), pg_temp.cs('CS1'), 2, pg_temp.today(), '00:00', '23:59:59', 'DA_CHOT', pg_temp.uid('gv1'));
insert into app.session_attendance (id, session_id, class_id, branch_id, student_id, ops_status_code)
values (pg_temp.i('at'), pg_temp.i('sn'), pg_temp.i('k1'), pg_temp.cs('CS1'), pg_temp.i('s1'), 'VANG_CO_PHEP');
insert into app.upsale_ticket (id, code, branch_id, student_id, parent_id, class_id, origin_code, owner_id, hours_left, expected_end_date)
values (pg_temp.i('u1'), 'UPE679A', pg_temp.cs('CS1'), pg_temp.i('s1'), pg_temp.i('p1'), pg_temp.i('k1'), 'TAY', pg_temp.uid('cskh1'), 2, pg_temp.today() + 5),
       (pg_temp.i('u2'), 'UPE679B', pg_temp.cs('CS1'), gen_random_uuid(), pg_temp.i('p1'), pg_temp.i('k1'), 'TAY', pg_temp.uid('cskh1'), 90, pg_temp.today() + 170);
insert into app.enrollment (id, code, student_id, parent_id, branch_id, subject_code)
values (pg_temp.i('en'), 'GDE679', pg_temp.i('s1'), pg_temp.i('p1'), pg_temp.cs('CS1'), 'TOAN');
insert into app.enrollment_hold (id, enrollment_id, student_id, branch_id, kind_code, months, reason_code, status_code, created_by)
values (pg_temp.i('hd'), pg_temp.i('en'), pg_temp.i('s1'), pg_temp.cs('CS1'), 'MOI', 1, 'KHAC', 'CHO_DUYET', pg_temp.uid('cskh1'));
set local session_replication_role = origin;

-- Các mục trả về dạng «TÍN_HIỆU:mã bản ghi giả», chỉ lấy bản ghi của bài (DB có thể có dữ liệu seed).
create function pg_temp.viec(p_filters jsonb default '{}') returns text language sql stable as $$
  select coalesce(string_agg((x ->> 'signal') || ':' || id.key, ' ' order by x ->> 'signal', id.key), '')
    from jsonb_array_elements(app.list_my_work(p_filters, 100) -> 'cards') c
   cross join lateral jsonb_array_elements(c -> 'items') x
    join id on id.id = (x ->> 'entity_id')::uuid $$;
create function pg_temp.the(p_key text, p_filters jsonb default '{}') returns jsonb language sql stable as $$
  select c from jsonb_array_elements(app.list_my_work(p_filters, 100) -> 'cards') c where c ->> 'group_key' = p_key $$;
grant execute on function pg_temp.viec(jsonb), pg_temp.the(text, jsonb) to public;

set local role authenticated;

-- ================= Của tôi =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.viec(), 'APPOINTMENT:a1 APPOINTMENT:a2 TEST:t1', 'Tuyển sinh: lịch hẹn và phiếu của mình; bỏ lịch quá xa và lịch nhắc của phiếu Nháp');
select is(app.list_my_work() -> 'counts', '{"now": 2, "today": 0, "soon": 1}'::jsonb, 'Đếm theo ba nhóm gấp');
select is((app.list_my_work() ->> 'total_cards')::int, 2, 'Hai thẻ: một phụ huynh, một lead chưa có phụ huynh');
select is(jsonb_array_length(pg_temp.the('P:' || pg_temp.i('p1')) -> 'items'), 2, 'Gom lịch hẹn và phiếu kiểm tra cùng phụ huynh vào một thẻ');
select is(pg_temp.the('P:' || pg_temp.i('p1')) ->> 'parent_name', 'Phụ huynh giả 679', 'Thẻ có tên phụ huynh');
select is(pg_temp.the('P:' || pg_temp.i('p1')) ->> 'urgency', 'NOW', 'Thẻ lấy nhóm gấp nhất');
select is(pg_temp.the('T:0900679002') ->> 'phone', '0900679002', 'Lead chưa có phụ huynh gom theo số điện thoại');
select is(app.list_my_work('{}', 1, 0) -> 'cards' -> 0 ->> 'urgency', 'NOW', 'Trang đầu là thẻ gấp nhất');
select is(jsonb_array_length(app.list_my_work('{}', 1, 1) -> 'cards'), 1, 'Phân trang theo thẻ ở máy chủ');
select is((app.list_my_work('{}', 1, 1) ->> 'total_cards')::int, 2, 'Tổng số thẻ không đổi theo trang');

select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.viec(), 'ABSENT_TODAY:at RENEWAL:u1 SESSION_NO_ATTENDANCE:sn SESSION_PENDING:sp',
  'CSKH của lớp: vắng hôm nay, tái tục sắp hết giờ (bỏ phiếu còn nhiều giờ), buổi chưa điểm danh, buổi chưa hoàn tất');

select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.viec(), 'APPROVAL:hd', 'Trưởng cơ sở: việc của mình là phiếu chờ duyệt');

-- ================= Cả đội và phạm vi cơ sở =================
select ok(pg_temp.viec('{"mine": false}') like '%APPOINTMENT:a1%' and pg_temp.viec('{"mine": false}') like '%RENEWAL:u1%'
          and pg_temp.viec('{"mine": false}') like '%SESSION_PENDING:sp%', 'Trưởng cơ sở xem cả đội trong cơ sở mình');
select ok(pg_temp.viec('{"mine": false}') not like '%APPOINTMENT:a4%', 'Phạm vi cơ sở không thấy việc cơ sở khác');
select is(pg_temp.viec(jsonb_build_object('mine', false, 'owner_id', pg_temp.uid('cskh1'))),
  'ABSENT_TODAY:at RENEWAL:u1', 'Cả đội lọc theo người: chỉ việc người đó phụ trách, không kèm việc chờ duyệt');
select is(pg_temp.viec(jsonb_build_object('mine', false, 'branch_id', pg_temp.cs('CS5'))), '', 'Chọn cơ sở khác ngoài phạm vi: không có gì');

select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.viec('{"mine": false}'), 'APPOINTMENT:a4', 'Người cơ sở CS5 chỉ thấy việc CS5');

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.viec(jsonb_build_object('mine', false, 'branch_id', pg_temp.cs('CS5'))), 'APPOINTMENT:a4', 'Admin lọc được theo cơ sở bất kỳ');

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.viec('{"mine": false}'), '', 'Giáo viên (phạm vi hẹp) không thấy việc nào ở trang CRM, kể cả khi bật cả đội');
select is(pg_temp.err($$select app.work_appointments(false, null, now(), 1)$$), '42501', 'Hàm con không cấp cho người dùng');
select is(has_function_privilege('anon', 'app.list_my_work(jsonb, integer, integer)', 'execute'), false, 'Người chưa đăng nhập không gọi được');
select set_config('request.jwt.claims', '{}', true);
select is(pg_temp.err($$select app.list_my_work()$$), 'HMT_KHONG_CO_QUYEN', 'Không có người đăng nhập thì bị chặn');

select * from finish();
rollback;
