-- P3e-1 (DB): get_student_test, list_student_tests và student_test_board (bộ lọc mới), student_test_group_counts, export_student_tests,
-- list_test_graders, list_test_rooms (docs/spec/04 R-CRM-05, 07, 29; TS-15, TS-16, TS-17).
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò nhập trong và ngoài cơ sở.
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
-- Lấy câu lỗi tiếng Việt (MESSAGE) của một lệnh.
create function pg_temp.msg(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
-- Chạy một câu lệnh với quyền chủ DB (dựng dữ liệu thử khi đang đóng vai người dùng).
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Thử Một', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1'), ('teacher1'), ('teacher5'), ('hs');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999999' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);


-- ================= Dựng dữ liệu =================
select pg_temp.sudo($$insert into app.room (branch_id, code, name, capacity) select id, 'TK101', 'Phòng 101', 12 from app.branch where code = 'CS1'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900002001', '{"parent_name": "Chị Phiếu A", "student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900002002', '{"parent_name": "Chị Phiếu B", "student_name": "Em Hai", "student_birth_year": 2013}'));
select app.create_lead(pg_temp.lead_data('0900002003', '{"parent_name": "Chị Phiếu C", "student_name": "Em Ba", "student_birth_year": 2011}'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900002099', '{"parent_name": "Chị Phiếu CS5", "student_name": "Em Chín", "student_birth_year": 2012}'));
select pg_temp.sudo($$create temp table lead_ids as select id, parent_phone from app.lead where parent_phone like '09000020%'$$);
select pg_temp.sudo($$grant select on lead_ids to authenticated$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable as 'select id from lead_ids where parent_phone = p_phone'$$);
select pg_temp.sudo($$grant execute on function pg_temp.lid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as 'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.tid(p_code text) returns uuid language sql stable security definer as 'select id from app.student_test where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.tid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.test_data(p_extra jsonb default '{}'::jsonb) returns jsonb language sql stable as
  'select jsonb_build_object(''subject_code'', ''TOAN'', ''grade_code'', (select code from app.catalog_item where catalog_code = ''GRADE'' order by sort_order limit 1),
     ''mode_code'', ''OFFLINE'', ''level_code'', ''CO_BAN'', ''exam_name'', ''Toán cơ bản'', ''scheduled_at'', now() + interval ''3 days'') || p_extra'$$);
select pg_temp.sudo($$grant execute on function pg_temp.test_data(jsonb) to public$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900002001'));
select app.create_opportunity(pg_temp.lid('0900002002'));
select app.create_opportunity(pg_temp.lid('0900002003'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900002099'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.change_opportunity_stage(pg_temp.oid('0900002001'), 'L5');
select app.change_opportunity_stage(pg_temp.oid('0900002002'), 'L5');
select app.change_opportunity_stage(pg_temp.oid('0900002003'), 'L5');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.change_opportunity_stage(pg_temp.oid('0900002099'), 'L5');
-- PKT1 (A): Nháp, có giáo viên chấm teacher5 và phòng TK101; PKT2 (B): Đang test; PKT3 (C): Huỷ; PKT4 (CS5).
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_student_test(pg_temp.oid('0900002001'), pg_temp.test_data(jsonb_build_object('grader_id', pg_temp.uid('teacher5'),
  'room_id', (select id from app.room where code = 'TK101'))));
select app.create_student_test(pg_temp.oid('0900002002'), pg_temp.test_data());
select app.create_student_test(pg_temp.oid('0900002003'), pg_temp.test_data());
select app.start_student_test(pg_temp.tid('PKT000002'));
select app.cancel_student_test(pg_temp.tid('PKT000003'), (select code from app.catalog_item where catalog_code = 'TEST_CANCEL_REASON' and not requires_note order by sort_order limit 1));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_student_test(pg_temp.oid('0900002099'), pg_temp.test_data());
-- PKT1 quá giờ test (Nháp, giờ test hai ngày trước) để thử lọc "Quá hạn".
select pg_temp.sudo($$update app.student_test set scheduled_at = now() - interval '2 days' where code = 'PKT000001'$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
create function pg_temp.n(p_filters jsonb) returns integer language sql stable as $$
  select (app.list_student_tests(p_filters) ->> 'total')::int $$;
create function pg_temp.col(p_filters jsonb, p_status text) returns integer language sql stable as $$
  select (c ->> 'total')::int from jsonb_array_elements(app.student_test_board(p_filters)) c where c ->> 'status_code' = p_status $$;
create function pg_temp.get(p_code text) returns jsonb language sql stable as $$ select app.get_student_test(pg_temp.tid(p_code)) $$;
grant execute on function pg_temp.n(jsonb), pg_temp.col(jsonb, text), pg_temp.get(text) to public;

-- ================= get_student_test (TS-17) =================
select is(pg_temp.get('PKT000001') ->> 'student_name', 'Em Một', 'get_student_test: có tên học sinh');
select is(pg_temp.get('PKT000001') ->> 'status', 'Nháp', 'Có tên trạng thái (không phải mã)');
select is(pg_temp.get('PKT000001') ->> 'opportunity_code', (select code from app.opportunity where id = pg_temp.oid('0900002001')), 'Có mã cơ hội');
select isnt(pg_temp.get('PKT000001') ->> 'lead_code', null, 'Có mã lead gốc');
select is(pg_temp.get('PKT000001') ->> 'parent_name', 'Chị Phiếu A', 'Có tên phụ huynh');
select is(pg_temp.get('PKT000001') ->> 'grader_name', 'Giả teacher5', 'Có tên giáo viên chấm');
select is(pg_temp.get('PKT000001') ->> 'room_name', 'Phòng 101', 'Có tên phòng');
select is((pg_temp.get('PKT000001') ->> 'room_capacity')::int, 12, 'Có sức chứa của phòng');
select is(pg_temp.get('PKT000001') ->> 'owner_name', 'Giả sales1', 'Có tên người phụ trách');
select is(pg_temp.get('PKT000001') ->> 'created_by_name', 'Giả sales1', 'Có tên người tạo');
select is(pg_temp.get('PKT000001') ->> 'test_branch_code', 'CS1', 'Có mã cơ sở test');
select is(pg_temp.get('PKT000001') ->> 'subject', 'Toán', 'Có tên môn');
select is(pg_temp.get('PKT000001') -> 'search_text', null, 'Không trả cột tìm kiếm');
select is((pg_temp.get('PKT000001') ->> 'appointments_total')::int, 1, 'Đếm lịch hẹn nhắc tự sinh (R-CRM-05)');
select isnt(pg_temp.get('PKT000003') ->> 'cancel_reason', null, 'Phiếu huỷ có tên lý do huỷ');
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is(pg_temp.get('PKT000001') ->> 'code', 'PKT000001', 'Đồng nghiệp cùng cơ sở đọc được (phạm vi cơ sở)');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.get('PKT000001') ->> 'code', 'PKT000001', 'Giáo viên chấm đọc được phiếu của mình (phạm vi được phân công)');
select is(pg_temp.err($$select pg_temp.get('PKT000002')$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không đọc được phiếu không phải của mình');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select pg_temp.get('PKT000001')$$), 'HMT_KHONG_CO_QUYEN', 'Tuyển sinh CS5 không đọc được phiếu của CS1');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select pg_temp.get('PKT000001')$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không đọc được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.get('PKT000004') ->> 'code', 'PKT000004', 'Admin đọc được mọi cơ sở');
select is(pg_temp.err($$select app.get_student_test(gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Không có phiếu: báo không tìm thấy');

-- ================= list_student_tests: bộ lọc mới =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.n('{}'), 3, 'Sales CS1 thấy 3 phiếu của cơ sở mình');
select is(pg_temp.n('{"status": ["DRAFT"]}'), 1, 'Lọc trạng thái Nháp');
select is(pg_temp.n('{"subject": ["TOAN"]}'), 3, 'Lọc môn');
select is(pg_temp.n('{"subject": ["KHONG_CO"]}'), 0, 'Lọc môn không khớp thì rỗng');
select is(pg_temp.n('{"mode": ["OFFLINE"]}'), 3, 'Lọc hình thức');
select is(pg_temp.n('{"level": ["CO_BAN"]}'), 3, 'Lọc cấp độ');
select is(pg_temp.n('{"mine_roles": ["OWNER"]}'), 3, 'Tôi phụ trách');
select is(pg_temp.n('{"mine_roles": ["CREATOR"]}'), 3, 'Tôi tạo');
select is(pg_temp.n('{"mine_roles": ["GRADER"]}'), 0, 'Tôi chấm bài: sales1 không chấm phiếu nào');
select is(pg_temp.n('{"mine_roles": ["GRADER", "OWNER"]}'), 3, 'R-CRM-07: cùng nhóm "của tôi" là HOẶC');
select is(pg_temp.n('{"mine_roles": ["OWNER"], "status": ["CANCELLED"]}'), 1, 'R-CRM-07: khác nhóm là VÀ');
select is(pg_temp.n('{"when": ["OVERDUE"]}'), 1, 'Quá hạn: phiếu Nháp đã quá giờ test');
select is(pg_temp.n('{"when": ["TODAY"]}'), 0, 'Hôm nay: chưa có');
select is(pg_temp.n('{"when": ["UPCOMING"]}'), 2, 'Sắp tới: từ ngày mai');
select is(pg_temp.n('{"when": ["OVERDUE", "UPCOMING"]}'), 3, 'R-CRM-07: Quá hạn hoặc Sắp tới (HOẶC)');
select is(pg_temp.n('{"when": ["UPCOMING"], "status": ["CANCELLED"]}'), 1, 'Thời gian và trạng thái: VÀ');
select is(app.list_student_tests('{}') -> 'rows' -> 0 ->> 'created_by_name', 'Giả sales1', 'Dòng có tên người tạo');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.n('{}'), 1, 'Giáo viên chỉ thấy phiếu mình chấm (phạm vi được phân công)');
select is(pg_temp.n('{"mine_roles": ["GRADER"]}'), 1, 'Tôi chấm bài: giáo viên thấy phiếu mình chấm');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.n('{}'), 1, 'Sales CS5 chỉ thấy phiếu của CS5');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.list_student_tests('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không xem được danh sách');

-- ================= student_test_board =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(jsonb_array_length(app.student_test_board('{}')), 5, 'Kanban: đủ năm cột trạng thái');
select is(pg_temp.col('{}', 'DRAFT'), 1, 'Cột Nháp có 1 phiếu');
select is(pg_temp.col('{}', 'TESTING'), 1, 'Cột Đang test có 1 phiếu');
select is(pg_temp.col('{}', 'CANCELLED'), 1, 'Cột Đã huỷ có 1 phiếu');
select is(pg_temp.col('{"when": ["UPCOMING"]}', 'DRAFT'), 0, 'Lọc Sắp tới: phiếu Nháp quá giờ không còn');
select is(pg_temp.col('{"when": ["OVERDUE"]}', 'DRAFT'), 1, 'Lọc Quá hạn: còn phiếu Nháp quá giờ');
select is(pg_temp.col('{"mine_roles": ["GRADER"]}', 'DRAFT'), 0, 'Lọc "Tôi chấm bài" áp cho Kanban');
select is((select c -> 'bar' ->> 'overdue' from jsonb_array_elements(app.student_test_board('{}')) c where c ->> 'status_code' = 'DRAFT')::int, 1, 'Thanh đầu cột Nháp: 1 phiếu quá giờ');
select is((select (c -> 'bar' ->> 'upcoming')::int from jsonb_array_elements(app.student_test_board('{}')) c where c ->> 'status_code' = 'TESTING'), 1, 'Thanh đầu cột Đang test: 1 phiếu sắp tới');
select is((select (c -> 'bar' ->> 'today')::int from jsonb_array_elements(app.student_test_board('{}')) c where c ->> 'status_code' = 'TESTING'), 0, 'Thanh đầu cột Đang test: chưa có phiếu hôm nay');
select ok((select c -> 'rows' -> 0 ? 'level_code' and c -> 'rows' -> 0 ? 'owner_id' and c -> 'rows' -> 0 ? 'grader_id' and c -> 'rows' -> 0 ? 'created_by' from jsonb_array_elements(app.student_test_board('{}')) c where c ->> 'status_code' = 'DRAFT'), 'Thẻ có cấp độ và mã người tạo, phụ trách, chấm (nhãn "Tôi")');
select ok((select c -> 'rows' -> 0 ? 'created_by_name' from jsonb_array_elements(app.student_test_board('{}')) c where c ->> 'status_code' = 'DRAFT'), 'Thẻ có người tạo');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.col('{}', 'DRAFT'), 1, 'Kanban chỉ trong phạm vi cơ sở (CS5: 1 phiếu Nháp)');
select is(pg_temp.col('{}', 'TESTING'), 0, 'Kanban CS5 không thấy phiếu của CS1');

-- ================= student_test_group_counts =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((app.student_test_group_counts('{}', array['status']) ->> 'total')::int, 3, 'Group By: tổng đủ 3');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.student_test_group_counts('{}', array['status']) -> 'groups') g where g ->> 'k1' = 'DRAFT'), 1, 'Group By trạng thái: Nháp có 1');
select is((select g ->> 'l1' from jsonb_array_elements(app.student_test_group_counts('{}', array['status']) -> 'groups') g where g ->> 'k1' = 'TESTING'), (select name from app.catalog_item where catalog_code = 'TEST_STATUS' and code = 'TESTING'), 'Nhãn nhóm là tên trạng thái');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.student_test_group_counts('{}', array['subject', 'status']) -> 'groups') g where g ->> 'k1' = 'TOAN' and g ->> 'k2' = 'CANCELLED'), 1, 'Group By hai cấp: môn rồi trạng thái');
select is((select g ->> 'l1' from jsonb_array_elements(app.student_test_group_counts('{}', array['owner']) -> 'groups') g limit 1), 'Giả sales1', 'Nhãn nhóm người phụ trách là tên người');
select is((app.student_test_group_counts('{"when": ["OVERDUE"]}', array['status']) ->> 'total')::int, 1, 'Group By theo bộ lọc của danh sách');
select is(pg_temp.err($$select app.student_test_group_counts('{}', array['khong_co'])$$), 'HMT_NHOM_SAI', 'Trường nhóm lạ bị chặn');
select is(pg_temp.err($$select app.student_test_group_counts('{}', array['status', 'status'])$$), 'HMT_NHOM_SAI', 'Hai cấp giống nhau bị chặn');
select is(pg_temp.err($$select app.student_test_group_counts('{}', array['status', 'subject', 'mode'])$$), 'HMT_NHOM_SAI', 'Quá hai cấp bị chặn');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((app.student_test_group_counts('{}', array['status']) ->> 'total')::int, 1, 'Group By trong phạm vi cơ sở');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.student_test_group_counts('{}', array['status'])$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không đếm nhóm được');

-- ================= export_student_tests =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.export_student_tests('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Nhân viên kinh doanh không có quyền xuất');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is((app.export_student_tests('{}') ->> 'exported')::int, 3, 'Trưởng cơ sở xuất đúng số phiếu trong cơ sở mình');
select is((select count(*) from app.export_log where module_code = 'STUDENT_TEST' and row_count = 3), 1::bigint, 'Xuất file ghi nhật ký xuất');
select isnt(app.export_student_tests('{}') -> 'rows' -> 0 ->> 'status', null, 'Dòng xuất có tên trạng thái (không phải mã)');
select is((app.export_student_tests('{"when": ["OVERDUE"]}') ->> 'exported')::int, 1, 'Xuất theo bộ lọc mới');
select is((app.export_student_tests('{"q": "Phiếu CS5"}') ->> 'exported')::int, 0, 'Xuất không lấy phiếu cơ sở khác');
reset role;
update app.setting_def set value = '2' where key = 'export_max_rows';
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(app.export_student_tests('{}') - 'rows', '{"total": 3, "exported": 2, "truncated": true}'::jsonb, 'Quá export_max_rows: cắt và báo đã cắt');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.export_student_tests('{}') ->> 'total')::int, 4, 'Admin xuất toàn hệ thống');

-- ================= list_test_graders, list_test_rooms =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((select count(*)::int from app.list_test_graders((select id from app.branch where code = 'CS5')) where display_name = 'Giả teacher5'), 1, 'Danh sách giáo viên chấm của cơ sở CS5 có giáo viên');
select is((select count(*)::int from app.list_test_graders() where display_name = 'Giả teacher5'), 0, 'Mặc định theo cơ sở người gọi (CS1): chưa có giáo viên CS5');
select is((select count(*)::int from app.list_test_graders((select id from app.branch where code = 'CS5')) where display_name = 'Giả hs'), 0, 'Học sinh không nằm trong danh sách giáo viên');
select is((select name from app.list_test_rooms() limit 1), 'Phòng 101', 'Danh sách phòng của cơ sở có phòng');
select is((select capacity from app.list_test_rooms() limit 1), 12, 'Danh sách phòng có sức chứa');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select * from app.list_test_graders()$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không xem được danh sách giáo viên');
select is(pg_temp.err($$select * from app.list_test_rooms()$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không xem được danh sách phòng');

select * from finish();
rollback;
