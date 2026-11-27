begin;
-- Migration 691 (E-26-04): «Để sau» (app.work_snooze, app.snooze_work). Luật: tối đa 3 ngày, 2 lần (tham số), không hoãn chờ duyệt và
-- buổi chưa điểm danh; hoãn theo người dùng, cả đội vẫn thấy. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@e691.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@e691.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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
insert into app.parent (id, code, full_name, phone, branch_id) values (pg_temp.i('p1'), 'PHE691', 'Phụ huynh giả 679', '0900691001', pg_temp.cs('CS1'));
insert into app.student (id, code, parent_id, full_name, birth_year, branch_id) values (pg_temp.i('s1'), 'HSE691', pg_temp.i('p1'), 'Em giả 679', 2013, pg_temp.cs('CS1'));
insert into app.lead (id, code, parent_name, parent_phone, parent_id, branch_id, owner_id, source_type_code, source_code)
select pg_temp.i(v.k), 'LDE691' || v.k, 'Phụ huynh lead ' || v.k, v.phone, case when v.k = 'l1' then pg_temp.i('p1') end, pg_temp.cs(v.cs), pg_temp.uid(v.own), 'MARKETING', 'WEBSITE'
  from (values ('l1', '0900691001', 'CS1', 'sales1'), ('l2', '0900691002', 'CS1', 'sales1'), ('l5', '0900691005', 'CS5', 'sales5')) v (k, phone, cs, own);
insert into app.student_test (id, code, opportunity_id, prospect_student_id, student_id, branch_id, test_branch_id, created_branch_id, subject_code, grade_code, mode_code, level_code, scheduled_at, owner_id)
select pg_temp.i('t1'), 'PKE691', gen_random_uuid(), gen_random_uuid(), pg_temp.i('s1'), pg_temp.cs('CS1'), pg_temp.cs('CS1'), pg_temp.cs('CS1'), 'TOAN', 'K08', 'OFFLINE', 'CB',
       now() + interval '1 hour', pg_temp.uid('sales1');
insert into app.appointment (id, lead_id, activity_code, scheduled_at, title, owner_id, branch_id)
select pg_temp.i(v.k), pg_temp.i(v.lead), 'GOI_DIEN', now() + v.plus::interval, 'Hẹn giả ' || v.k, pg_temp.uid(v.own), pg_temp.cs(v.cs)
  from (values ('a1', 'l1', '-3 hours', 'sales1', 'CS1'), ('a2', 'l2', '2 days', 'sales1', 'CS1'), ('a3', 'l2', '40 days', 'sales1', 'CS1'),
               ('a4', 'l5', '-3 hours', 'sales5', 'CS5')) v (k, lead, plus, own, cs);
insert into app.appointment (id, student_test_id, is_auto_reminder, activity_code, scheduled_at, title, owner_id, branch_id)
values (pg_temp.i('a6'), pg_temp.i('t1'), true, 'GOI_DIEN', now() - interval '1 hour', 'Nhắc phiếu giả', pg_temp.uid('sales1'), pg_temp.cs('CS1'));
insert into app.class (id, code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions, status_code, cskh_id)
values (pg_temp.i('k1'), 'LOPE691', pg_temp.cs('CS1'), '2627', 'TOAN', 'K08', 'CB', 'A', pg_temp.today() - 7, 4, 'DA_DUYET', pg_temp.uid('cskh1'));
insert into app.class_session (id, class_id, branch_id, session_no, session_date, start_time, end_time, status_code, teacher_id)
values (pg_temp.i('sp'), pg_temp.i('k1'), pg_temp.cs('CS1'), 1, pg_temp.today() - 1, '08:00', '09:00', 'DA_CHOT', pg_temp.uid('gv1')),
       (pg_temp.i('sn'), pg_temp.i('k1'), pg_temp.cs('CS1'), 2, pg_temp.today(), '00:00', '23:59:59', 'DA_CHOT', pg_temp.uid('gv1'));
insert into app.session_attendance (id, session_id, class_id, branch_id, student_id, ops_status_code)
values (pg_temp.i('at'), pg_temp.i('sn'), pg_temp.i('k1'), pg_temp.cs('CS1'), pg_temp.i('s1'), 'VANG_CO_PHEP');
insert into app.upsale_ticket (id, code, branch_id, student_id, parent_id, class_id, origin_code, owner_id, hours_left, expected_end_date)
values (pg_temp.i('u1'), 'UPE691A', pg_temp.cs('CS1'), pg_temp.i('s1'), pg_temp.i('p1'), pg_temp.i('k1'), 'TAY', pg_temp.uid('cskh1'), 2, pg_temp.today() + 5),
       (pg_temp.i('u2'), 'UPE691B', pg_temp.cs('CS1'), gen_random_uuid(), pg_temp.i('p1'), pg_temp.i('k1'), 'TAY', pg_temp.uid('cskh1'), 90, pg_temp.today() + 170);
insert into app.enrollment (id, code, student_id, parent_id, branch_id, subject_code)
values (pg_temp.i('en'), 'GDE691', pg_temp.i('s1'), pg_temp.i('p1'), pg_temp.cs('CS1'), 'TOAN');
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

create function pg_temp.hoan(p_signal text, p_key text, p_plus interval default '1 day') returns text language sql volatile as $$
  select pg_temp.err(format('select app.snooze_work(%L, %L, now() + %L::interval)', p_signal, pg_temp.i(p_key), p_plus)) $$;
create function pg_temp.nhan(p_key text, p_filters jsonb) returns boolean language sql stable as $$
  select (x ->> 'snoozed_until') is not null
    from jsonb_array_elements(app.list_my_work(p_filters, 100) -> 'cards') c
   cross join lateral jsonb_array_elements(c -> 'items') x
   where x ->> 'entity_id' = pg_temp.i(p_key)::text $$;
grant execute on function pg_temp.hoan(text, text, interval), pg_temp.nhan(text, jsonb) to public;

set local role authenticated;

-- ================= R2: tối đa 3 ngày =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.hoan('APPOINTMENT', 'a1', '4 days'), 'HMT_HAN_DE_SAU_SAI', 'Chặn: để sau quá 3 ngày');
select is(pg_temp.hoan('APPOINTMENT', 'a1', '-1 hour'), 'HMT_HAN_DE_SAU_SAI', 'Chặn: hạn để sau ở quá khứ');
select is(pg_temp.err(format('select app.snooze_work(%L, %L, null)', 'APPOINTMENT', pg_temp.i('a1'))), 'HMT_HAN_DE_SAU_SAI', 'Chặn: không có hạn');
select is(app.snooze_work('APPOINTMENT', pg_temp.i('a1'), now() + interval '3 days', '  Chờ phụ huynh  ') - 'snooze_until',
  '{"snooze_count": 1, "remaining": 1}'::jsonb, 'Để sau đúng 3 ngày được, còn 1 lượt');
select is((select note from app.work_snooze), 'Chờ phụ huynh', 'Lưu ghi chú đã cắt khoảng trắng');
select is(pg_temp.viec(), 'APPOINTMENT:a2 TEST:t1', 'Việc đã để sau ẩn khỏi danh sách của tôi');
select is(app.list_my_work() -> 'counts', '{"now": 1, "today": 0, "soon": 1}'::jsonb, 'Số đếm không tính việc đã để sau');
select ok(pg_temp.nhan('a1', '{"mine": false}'), 'Chế độ cả đội vẫn thấy, có nhãn đã để sau');
select ok(not pg_temp.nhan('a2', '{"mine": false}'), 'Việc không hoãn thì không có nhãn');

-- ================= R3: tối đa 2 lần =================
select is(pg_temp.hoan('APPOINTMENT', 'a1'), null, 'Lần thứ hai được');
select is(pg_temp.hoan('APPOINTMENT', 'a1'), 'HMT_HET_LUOT_DE_SAU', 'Chặn: lần thứ ba');
select is((select snooze_count from app.work_snooze), 2, 'Số lần giữ ở 2');

select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select ok(pg_temp.nhan('a1', '{"mine": false}'), 'Người khác thấy việc đã được để sau');
select is((select count(*)::int from app.work_snooze), 0, 'Quyền đọc: không đọc được dòng để sau của người khác');

reset role;
update app.work_snooze set snooze_until = now() - interval '1 minute';
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.viec(), 'APPOINTMENT:a1 APPOINTMENT:a2 TEST:t1', 'Hết hạn để sau thì việc hiện lại');

-- ================= R1: loại không hoãn =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.hoan('APPROVAL', 'hd'), 'HMT_VIEC_KHONG_HOAN', 'Chặn: việc chờ duyệt');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.hoan('SESSION_NO_ATTENDANCE', 'sn'), 'HMT_VIEC_KHONG_HOAN', 'Chặn: buổi đang diễn ra chưa điểm danh');
select is(pg_temp.hoan('SESSION_PENDING', 'sp'), 'HMT_VIEC_KHONG_HOAN', 'Chặn: buổi đã hết giờ chưa điểm danh');
select is(pg_temp.hoan('RENEWAL', 'u1'), null, 'Tái tục được để sau');
select is(pg_temp.hoan('ABSENT_TODAY', 'at'), null, 'Vắng hôm nay được để sau');
reset role;
set local session_replication_role = replica;
insert into app.session_attendance (session_id, class_id, branch_id, student_id, teacher_status_code)
values (pg_temp.i('sp'), pg_temp.i('k1'), pg_temp.cs('CS1'), pg_temp.i('s1'), 'CO_MAT');
set local session_replication_role = origin;
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.hoan('SESSION_PENDING', 'sp'), null, 'Buổi đã điểm danh, chưa hoàn tất thì được để sau');

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.hoan('APPOINTMENT', 'a2'), 'HMT_VIEC_KHONG_CON', 'Chặn: Trưởng cơ sở không hoãn hộ việc của người khác');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.hoan('APPOINTMENT', 'a2'), 'HMT_VIEC_KHONG_CON', 'Chặn: người cơ sở khác');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.hoan('APPOINTMENT', 'a3'), 'HMT_VIEC_KHONG_CON', 'Chặn: việc chưa nằm trong danh sách (quá xa)');
select is(pg_temp.hoan('LA', 'a2'), 'HMT_VIEC_KHONG_CON', 'Chặn: loại tín hiệu lạ');
select is(pg_temp.err($$insert into app.work_snooze (user_id, signal, entity_id, snooze_until) values (auth.uid(), 'TEST', gen_random_uuid(), now())$$),
  '42501', 'Không ghi thẳng vào bảng');
select is(pg_temp.err($$update app.work_snooze set snooze_count = 1$$), '42501', 'Không sửa thẳng số lần');
select is(has_function_privilege('anon', 'app.snooze_work(text, uuid, timestamptz, text)', 'execute'), false, 'Người chưa đăng nhập không gọi được');
select set_config('request.jwt.claims', '{}', true);
select is(pg_temp.hoan('APPOINTMENT', 'a2'), 'HMT_KHONG_CO_QUYEN', 'Không có người đăng nhập thì bị chặn');

-- ================= Tham số theo cơ sở =================
reset role;
select set_config('hmt.migration', 'on', true);
update app.setting_def set value = '0' where key = 'work_snooze_max_times';
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.hoan('APPOINTMENT', 'a2'), 'HMT_HET_LUOT_DE_SAU', 'Tham số số lần = 0: không cho để sau');

select * from finish();
rollback;
