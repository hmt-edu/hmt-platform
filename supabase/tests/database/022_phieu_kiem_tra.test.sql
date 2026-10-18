-- P3b2b: phiếu kiểm tra (docs/spec/04 R-CRM-05, 06, 10, 11, 12, 13, 14, 15, 21, 27; tám câu anh chốt 18/10).
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò đọc, ghi trong và ngoài cơ sở (gồm giáo viên được phân công).
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
                      ('cskh1', 'CS1'), ('teacher1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher1', 'TEACHER'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);


-- ================= Dựng dữ liệu: lead, cơ hội, phòng (đóng vai Tuyển sinh CS1, CS5) =================
select pg_temp.sudo($$insert into app.room (branch_id, code, name) select id, 'TK101', 'Phòng 101' from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$insert into app.room (branch_id, code, name) select id, 'TK501', 'Phòng 501' from app.branch where code = 'CS5'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900000301', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900000302', '{"student_name": "Em Hai", "student_birth_year": 2013}'));
select app.create_lead(pg_temp.lead_data('0900000303', '{"student_name": "Em Ba", "student_birth_year": 2011}'));
select app.create_lead(pg_temp.lead_data('0900000304', '{"student_name": "Em Bốn", "student_birth_year": 2010}'));
select app.create_lead(pg_temp.lead_data('0900000305', '{"student_name": "Em Năm", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900000306', '{"student_name": "Em Sáu", "student_birth_year": 2011}'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900000399', '{"student_name": "Em Chín", "student_birth_year": 2012}'));
select pg_temp.sudo($$create temp table lead_ids as select id, parent_phone from app.lead$$);
select pg_temp.sudo($$grant select on lead_ids to authenticated$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable as 'select id from lead_ids where parent_phone = p_phone'$$);
select pg_temp.sudo($$grant execute on function pg_temp.lid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.oid(p_code text) returns uuid language sql stable security definer as 'select id from app.opportunity where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.tid(p_code text) returns uuid language sql stable security definer as 'select id from app.student_test where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.tid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.room(p_code text) returns uuid language sql stable security definer as 'select id from app.room where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.room(text) to public$$);
select pg_temp.sudo($$create function pg_temp.test_data(p_extra jsonb default '{}'::jsonb) returns jsonb language sql stable as
  'select jsonb_build_object(''subject_code'', ''TOAN'', ''grade_code'', (select code from app.catalog_item where catalog_code = ''GRADE'' order by sort_order limit 1),
     ''mode_code'', ''OFFLINE'', ''level_code'', ''CO_BAN'', ''exam_name'', ''Toán cơ bản - đề 1'',
     ''scheduled_at'', now() + interval ''3 days'') || p_extra'$$);
select pg_temp.sudo($$grant execute on function pg_temp.test_data(jsonb) to public$$);
select pg_temp.sudo($$create function pg_temp.rem(p_at timestamptz) returns timestamptz language sql stable security definer as 'select app.test_reminder_time(p_at)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.rem(timestamptz) to public$$);
select pg_temp.sudo($$create function pg_temp.l5(p_id uuid) returns text language sql stable security definer as 'select app.opportunity_l5_substage(p_id)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.l5(uuid) to public$$);
select pg_temp.sudo($$create function pg_temp.audit_has(p_id uuid, p_like text) returns boolean language sql stable security definer as
  'select exists (select from app.audit_log a join app.audited_table t on t.id = a.table_id where t.table_name = ''app.student_test'' and a.record_id = p_id and a.action = ''U'' and a.changes::text like p_like)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.audit_has(uuid, text) to public$$);

select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900000301'));
select app.create_opportunity(pg_temp.lid('0900000302'));
select app.create_opportunity(pg_temp.lid('0900000303'));
select app.create_opportunity(pg_temp.lid('0900000304'));
select app.create_opportunity(pg_temp.lid('0900000305'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900000399'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900000306'));
select app.change_opportunity_stage(pg_temp.oid('CO000007'), 'L5');
-- CO000001 ở L1, CO000002 ở L4 (chưa đủ L5); CO000003, 4, 5 ở L5.
select app.change_opportunity_stage(pg_temp.oid('CO000002'), 'L4');
select app.change_opportunity_stage(pg_temp.oid('CO000003'), 'L5');
select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L5');
select app.change_opportunity_stage(pg_temp.oid('CO000005'), 'L5');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.change_opportunity_stage(pg_temp.oid('CO000006'), 'L5');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= R-CRM-05: tạo phiếu =================
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000001'), pg_temp.test_data())$$), 'HMT_CO_HOI_CHUA_DEN_L5',
          'R-CRM-05: cơ hội ở L1 không tạo được phiếu');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000002'), pg_temp.test_data())$$), 'HMT_CO_HOI_CHUA_DEN_L5',
          'R-CRM-05: cơ hội ở L4 không tạo được phiếu');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000003'), pg_temp.test_data('{"scheduled_at": null}'))$$), 'HMT_THIEU_THONG_TIN',
          'R-CRM-05: thiếu ngày giờ test thì chặn (bắt buộc)');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000003'), pg_temp.test_data(jsonb_build_object('scheduled_at', now() - interval '1 hour')))$$),
          'HMT_GIO_TEST_QUA_KHU', 'Chặn giờ test ở quá khứ khi tạo (anh chốt 18/10)');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000003'), pg_temp.test_data('{"subject_code": null}'))$$), 'HMT_THIEU_THONG_TIN', 'Chặn: thiếu môn');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000003'), pg_temp.test_data('{"mode_code": "KHONG_CO"}'))$$), 'HMT_DANH_MUC_KHONG_CO', 'Chặn: hình thức ngoài danh mục');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000003'), pg_temp.test_data(jsonb_build_object('owner_id', pg_temp.uid('sales5'))))$$),
          'HMT_NGUOI_PHU_TRACH_SAI', 'Chặn: người phụ trách khác cơ sở');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000003'), pg_temp.test_data(jsonb_build_object('grader_id', pg_temp.uid('sales1b'))))$$),
          'HMT_GIAO_VIEN_CHAM_SAI', 'Chặn: người chấm không phải giáo viên');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000003'), pg_temp.test_data(jsonb_build_object('room_id', pg_temp.room('TK501'), 'test_branch_id', (select id from app.branch where code = 'CS1'))))$$),
          'HMT_PHONG_SAI', 'Chặn: phòng không thuộc cơ sở test');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000003'), pg_temp.test_data(), now() + interval '10 days')$$), 'HMT_GIO_NHAC_SAI',
          'TS-15: giờ nhắc phải trước giờ test');
select is((select count(*)::int from app.student_test), 0, 'Các ca bị chặn không tạo phiếu nào');
select is((select count(*)::int from app.student where parent_id = (select parent_id from app.opportunity where code = 'CO000003')), 0,
          'Ca bị chặn không sinh hồ sơ học sinh');

select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000003'), pg_temp.test_data(jsonb_build_object('grader_id', pg_temp.uid('teacher5'), 'room_id', pg_temp.room('TK101'), 'scheduled_at', now() + interval '3 days')))$$), null,
          'R-CRM-05: cơ hội ở L5, đủ thông tin: tạo phiếu được');
select is((select code from app.student_test where opportunity_id = pg_temp.oid('CO000003')), 'PKT000001', 'Mã phiếu cấp lúc Lưu: PKT000001');
select is((select status_code from app.student_test where code = 'PKT000001'), 'DRAFT', 'Phiếu mới ở Nháp');
select ok((select student_id is not null from app.opportunity where code = 'CO000003'), 'R-CRM-27: tạo phiếu sinh hồ sơ học sinh và gắn vào cơ hội');
select is((select s.full_name || '/' || s.birth_year from app.student s join app.opportunity o on o.student_id = s.id where o.code = 'CO000003'), 'Em Ba/2011',
          'Hồ sơ học sinh lấy tên, năm sinh từ cơ hội');
select is((select s.branch_id from app.student s join app.opportunity o on o.student_id = s.id where o.code = 'CO000003'), (select id from app.branch where code = 'CS1'),
          'Cơ sở tiếp nhận của học sinh = cơ sở của cơ hội');
select is((select array[t.branch_id::text, t.test_branch_id::text, t.created_branch_id::text, t.owner_id::text] from app.student_test t where t.code = 'PKT000001'),
          array[(select id::text from app.branch where code = 'CS1'), (select id::text from app.branch where code = 'CS1'),
                (select id::text from app.branch where code = 'CS1'), pg_temp.uid('sales1')::text],
          'Cơ sở test mặc định cơ sở người tạo; cơ sở tạo tự ghi; người phụ trách mặc định người tạo');
select is((select substage_code from app.opportunity where code = 'CO000003'), 'L5B', 'R-CRM-15: cơ hội ở L5 có phiếu Nháp → nhóm con L5B');
select ok((select search_text like '%pkt000001%' and search_text like '%em ba%' from app.student_test where code = 'PKT000001'), 'Ô tìm kiếm có mã phiếu và tên học sinh');

-- Lịch hẹn nhắc tự sinh (R-CRM-05, TS-15).
select is((select count(*)::int from app.appointment where student_test_id = pg_temp.tid('PKT000001')), 1, 'Tạo phiếu tự sinh một lịch hẹn nhắc');
select is((select array[activity_code, owner_id::text, status, is_auto_reminder::text] from app.appointment where student_test_id = pg_temp.tid('PKT000001')),
          array['GOI_DIEN', pg_temp.uid('sales1')::text, 'CHUA_LAM', 'true'], 'Lịch nhắc: Gọi điện, người phụ trách phiếu, Chưa làm');
select is((select (a.scheduled_at at time zone 'Asia/Ho_Chi_Minh')::time from app.appointment a where a.student_test_id = pg_temp.tid('PKT000001')),
          time '17:00', 'Test ở xa (trên 24 giờ): nhắc 17:00 (theo tham số) giờ Việt Nam');
select is((select (a.scheduled_at at time zone 'Asia/Ho_Chi_Minh')::date = ((t.scheduled_at at time zone 'Asia/Ho_Chi_Minh')::date - 1)
             from app.appointment a join app.student_test t on t.id = a.student_test_id where t.code = 'PKT000001'), true, 'Nhắc vào ngày hôm trước ngày test');
select is(pg_temp.rem(now() + interval '5 hours') , now() + interval '3 hours', 'Test trong 24 giờ tới: nhắc trước giờ test 2 giờ (tham số)');
select is(pg_temp.rem(now() + interval '30 minutes'), now(), 'Test sắp tới trong chưa đầy 2 giờ: nhắc ngay, vẫn trước giờ test');
select ok(pg_temp.rem(now() + interval '30 minutes') < now() + interval '30 minutes', 'Giờ nhắc luôn trước giờ test');
select is((app.list_appointments(jsonb_build_object('student_test_id', pg_temp.tid('PKT000001'))) ->> 'total')::int, 1, 'Danh sách lịch hẹn lọc theo phiếu');
select is((app.list_appointments(jsonb_build_object('student_test_id', pg_temp.tid('PKT000001'))) -> 'rows' -> 0 ->> 'record_code'), 'PKT000001', 'Dòng lịch nhắc có mã hồ sơ gắn là phiếu');
select is(pg_temp.err($$select app.create_appointment(pg_temp.lid('0900000301'), 'GOI_DIEN', now(), 'x', null, null, null)$$), null, 'Lịch hẹn gắn lead vẫn tạo được sau khi thêm cột phiếu');

-- Nhiều phiếu một cơ hội; học sinh dùng lại.
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000003'), pg_temp.test_data('{"exam_name": "Toán cơ bản - đề 2"}'), now() + interval '2 days', 'ZALO')$$), null,
          'R-CRM-05: một cơ hội có nhiều phiếu');
select is((select count(*)::int from app.student_test where opportunity_id = pg_temp.oid('CO000003')), 2, 'Cơ hội có hai phiếu');
select is((select count(distinct student_id)::int from app.student_test where opportunity_id = pg_temp.oid('CO000003')), 1, 'Hai phiếu dùng chung một hồ sơ học sinh');
select is((select array[activity_code, (scheduled_at = now() + interval '2 days')::text] from app.appointment where student_test_id = pg_temp.tid('PKT000002')),
          array['ZALO', 'true'], 'Người dùng chọn giờ nhắc và loại hoạt động riêng khi tạo');

-- Quyền tạo.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000004'), pg_temp.test_data())$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh CS5 tạo phiếu cho cơ hội CS1');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000004'), pg_temp.test_data())$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không tạo phiếu');
select is(pg_temp.err($$insert into app.student_test (code) values ('X')$$), '42501', 'Không ghi thẳng bảng phiếu');
select is(pg_temp.err($$select app.ensure_test_reminder(gen_random_uuid())$$), '42501', 'Giao diện không gọi hàm nội bộ sinh lịch nhắc');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= Đổi lịch, lịch nhắc, sửa phiếu =================
select is(pg_temp.err($$select app.reschedule_student_test(pg_temp.tid('PKT000001'), now() - interval '1 day')$$), 'HMT_GIO_TEST_QUA_KHU', 'Chặn đổi lịch về quá khứ (anh chốt 18/10)');
select is(pg_temp.err($$select app.reschedule_student_test(pg_temp.tid('PKT000001'), now() + interval '5 days')$$), null, 'Đổi lịch phiếu Nháp: được');
select is((select (a.scheduled_at at time zone 'Asia/Ho_Chi_Minh')::date = ((t.scheduled_at at time zone 'Asia/Ho_Chi_Minh')::date - 1)
             from app.appointment a join app.student_test t on t.id = a.student_test_id where t.code = 'PKT000001'), true,
          'Đổi lịch phiếu: lịch nhắc chưa sửa tay đổi theo');
-- Sửa tay lịch nhắc thì đổi lịch phiếu không ghi đè.
select pg_temp.sudo($$update app.appointment set scheduled_at = scheduled_at - interval '1 hour' where student_test_id = (select id from app.student_test where code = 'PKT000001')$$);
select is((select scheduled_at from app.appointment where student_test_id = pg_temp.tid('PKT000001')) is not distinct from
          (select auto_scheduled_at - interval '1 hour' from app.appointment where student_test_id = pg_temp.tid('PKT000001')), true, 'Lịch nhắc đã sửa tay (chuẩn bị)');
select pg_temp.sudo($$create temp table hand as select scheduled_at as t from app.appointment where student_test_id = (select id from app.student_test where code = 'PKT000001')$$);
select pg_temp.sudo($$grant select on hand to authenticated$$);
select is(pg_temp.err($$select app.reschedule_student_test(pg_temp.tid('PKT000001'), now() + interval '6 days')$$), null, 'Đổi lịch lần hai');
select is((select scheduled_at from app.appointment where student_test_id = pg_temp.tid('PKT000001')), (select t from hand), 'Lịch nhắc sửa tay không bị ghi đè khi đổi lịch phiếu');
select is(pg_temp.err($$select app.reschedule_student_test(pg_temp.tid('PKT000001'), now() + interval '6 days', now() + interval '1 day')$$), null, 'Chỉ định giờ nhắc mới khi đổi lịch: được');
select is((select scheduled_at from app.appointment where student_test_id = pg_temp.tid('PKT000001')), now() + interval '1 day', 'Giờ nhắc người dùng chọn được áp dụng');

select is(pg_temp.err($$select app.update_student_test(pg_temp.tid('PKT000001'), jsonb_build_object('owner_id', pg_temp.uid('sales1b')))$$), null, 'Đổi người phụ trách (có quyền Giao việc): được');
select is((select owner_id from app.appointment where student_test_id = pg_temp.tid('PKT000001')), pg_temp.uid('sales1b'), 'Lịch nhắc chưa làm theo người phụ trách mới');
select is(pg_temp.err($$select app.update_student_test(pg_temp.tid('PKT000001'), jsonb_build_object('room_id', pg_temp.room('TK501')))$$), 'HMT_PHONG_SAI', 'Chặn: phòng của cơ sở khác');
select is(pg_temp.err($$select app.update_student_test(pg_temp.tid('PKT000001'), jsonb_build_object('room_id', pg_temp.room('TK101'), 'grader_id', pg_temp.uid('teacher1'), 'exam_name', ' Đề mới '))$$), null,
          'Chọn phòng, giáo viên chấm (ở cơ sở nào cũng được), tên đề: được');
select is((select exam_name from app.student_test where code = 'PKT000001'), 'Đề mới', 'Tên đề được cắt khoảng trắng');
select is(pg_temp.err($$select app.update_student_test(pg_temp.tid('PKT000001'), jsonb_build_object('test_branch_id', (select id from app.branch where code = 'CS5')))$$), null,
          'Đổi cơ sở test: được');
select is((select room_id from app.student_test where code = 'PKT000001'), null, 'Đổi cơ sở test thì phòng cũ bị bỏ');
select is(pg_temp.err($$select app.update_student_test(pg_temp.tid('PKT000001'), jsonb_build_object('test_branch_id', (select id from app.branch where code = 'CS1')))$$), null, 'Trả về cơ sở test CS1');
select is(pg_temp.err($$select app.update_student_test(pg_temp.tid('PKT000001'), jsonb_build_object('grader_id', pg_temp.uid('sales1b')))$$), 'HMT_GIAO_VIEN_CHAM_SAI', 'Giáo viên chấm phải là giáo viên');
select is(pg_temp.err($$select app.update_student_test(pg_temp.tid('PKT000001'), jsonb_build_object('owner_id', pg_temp.uid('sales5')))$$), 'HMT_NGUOI_PHU_TRACH_SAI', 'Người phụ trách khác cơ sở bị chặn');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.update_student_test(pg_temp.tid('PKT000001'), '{"exam_name": "x"}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh CS5 sửa phiếu CS1');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= Trạng thái: Bắt đầu, Nộp bài, kết quả, Hoàn thành (R-CRM-10, 11, 13, 15) =================
select is(pg_temp.err($$select app.submit_student_test(pg_temp.tid('PKT000001'))$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chặn: nộp bài khi phiếu còn Nháp');
select is(pg_temp.err($$select app.enter_test_result(pg_temp.tid('PKT000001'), 7, 'x')$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chặn: nhập kết quả khi phiếu chưa Chờ giáo viên chấm');
select is(pg_temp.err($$select app.start_student_test(pg_temp.tid('PKT000001'))$$), null, 'Bắt đầu test: Nháp → Đang test');
select is(pg_temp.err($$select app.start_student_test(pg_temp.tid('PKT000001'))$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chặn: bắt đầu test hai lần');
select is(pg_temp.err($$select app.reschedule_student_test(pg_temp.tid('PKT000001'), now() + interval '7 days')$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ phiếu Nháp mới đổi lịch');
select is(pg_temp.err($$select app.submit_student_test(pg_temp.tid('PKT000001'))$$), null, 'Nộp bài: Đang test → Chờ giáo viên chấm');
select is((select substage_code from app.opportunity where code = 'CO000003'), 'L5P', 'R-CRM-15: còn phiếu Chờ giáo viên chấm → L5P (ưu tiên hơn L5B của phiếu Nháp)');
select is(pg_temp.err($$select app.complete_student_test(pg_temp.tid('PKT000001'))$$), 'HMT_THIEU_KET_QUA', 'Hoàn thành thiếu điểm, nhận xét: bị chặn');
select ok((select pg_temp.msg($$select app.complete_student_test(pg_temp.tid('PKT000001'))$$)) like '%điểm%nhận xét%', 'Câu lỗi nêu rõ thiếu ô nào');
select is(pg_temp.err($$select app.enter_test_result(pg_temp.tid('PKT000001'), 7.25, 'x')$$), 'HMT_DIEM_SAI', 'R-CRM-10: điểm tối đa một chữ số thập phân');
select is(pg_temp.err($$select app.enter_test_result(pg_temp.tid('PKT000001'), 11, 'x')$$), 'HMT_DIEM_SAI', 'R-CRM-10: điểm không quá 10');
select is(pg_temp.err($$select app.enter_test_result(pg_temp.tid('PKT000001'), -1, 'x')$$), 'HMT_DIEM_SAI', 'R-CRM-10: điểm không âm');
select is(pg_temp.err($$select app.enter_test_result(pg_temp.tid('PKT000001'), 7.5, 'Làm tốt', 'Z')$$), 'HMT_DANH_MUC_KHONG_CO', 'Trình độ đề xuất phải trong danh mục S, A, B, C');
select is(pg_temp.err($$select app.enter_test_result(pg_temp.tid('PKT000001'), 7.5, 'Làm tốt', 'A', 'CB')$$), null, 'Nhập kết quả (người phụ trách nhập thay giáo viên chấm)');
select is((select array[result_on_behalf::text, result_entered_by::text, score::text] from app.student_test where code = 'PKT000001'),
          array['true', pg_temp.uid('sales1')::text, '7.5'], 'R-CRM-11: ghi "nhập thay" và người nhập');
select is(pg_temp.err($$select app.complete_student_test(pg_temp.tid('PKT000001'))$$), null, 'Hoàn thành phiếu khi đủ giáo viên chấm, điểm, nhận xét');
select is((select array[stage_code, substage_code] from app.opportunity where code = 'CO000003'), array['L6', 'L6A'], 'R-CRM-13: phiếu Hoàn thành thì cơ hội tự lên L6A');
select ok((select completed_at is not null from app.student_test where code = 'PKT000001'), 'Ghi giờ hoàn thành');
select is(pg_temp.err($$select app.complete_student_test(pg_temp.tid('PKT000001'))$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chặn: hoàn thành hai lần');
select is(pg_temp.err($$select app.enter_test_result(pg_temp.tid('PKT000001'), 8, 'Sửa sau Hoàn thành', 'A', 'CB')$$), null, 'Sau Hoàn thành vẫn sửa được kết quả');
select ok(pg_temp.audit_has(pg_temp.tid('PKT000001'), '%score%'), 'R-CRM-21: sửa sau Hoàn thành có lịch sử (nhật ký)');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000003'), 'L6', 'L6B')$$), null, 'R-CRM-34: ở L6 người dùng tự chọn L6B…L6F sau L6A');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000003'), 'L6', 'L6A')$$), 'HMT_L6A_HE_THONG', 'R-CRM-35: người dùng không chọn lại L6A (hệ thống gắn)');

-- R-CRM-12: phiếu PKT000002 còn Nháp thì cơ hội chưa sang L7, L8.
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000003'), 'L7')$$), 'HMT_PHIEU_DANG_DO', 'R-CRM-12: còn phiếu dang dở thì không sang L7');
select ok((select pg_temp.msg($$select app.change_opportunity_stage(pg_temp.oid('CO000003'), 'L8', 'L8A', null, null, true)$$)) like '%PKT000002%', 'R-CRM-12: câu lỗi nêu mã phiếu dang dở');
-- Có phiếu Hoàn thành: sang L7 không cần lý do bỏ qua test (R-CRM-14), sau khi phiếu còn lại được huỷ.
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tid('PKT000002'), 'L5C')$$), null, 'Huỷ phiếu Nháp còn lại');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000003'), 'L7')$$), null, 'R-CRM-14: có phiếu hoàn thành thì sang L7 không cần lý do bỏ qua test');
select is((select skip_reason_code from app.opportunity where code = 'CO000003'), null, 'Không ghi lý do bỏ qua khi có phiếu hoàn thành');
select is((select count(*)::int from app.appointment where student_test_id = pg_temp.tid('PKT000002') and status = 'HUY' and is_auto_reminder), 1, 'Huỷ phiếu thì lịch nhắc tự sinh được huỷ theo');

-- ================= R-CRM-21: lùi bước, và (d) huỷ phiếu Hoàn thành rồi sang L7, L8 phải có lý do bỏ qua test =================
select is(pg_temp.err($$select app.step_back_student_test(pg_temp.tid('PKT000001'))$$), 'HMT_THIEU_LY_DO', 'R-CRM-21: đưa phiếu Hoàn thành về Nháp bắt lý do');
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tid('PKT000001'), 'L5C')$$), 'HMT_PHIEU_HOAN_THANH_PHAI_VE_NHAP', 'Phiếu Hoàn thành phải về Nháp trước rồi mới huỷ');
select is(pg_temp.err($$select app.step_back_student_test(pg_temp.tid('PKT000001'), '  Nhập nhầm điểm  ')$$), null, 'Đưa phiếu Hoàn thành về Nháp có lý do: được');
select is((select array[status_code, status_reason] from app.student_test where code = 'PKT000001'), array['DRAFT', 'Nhập nhầm điểm'], 'Phiếu về Nháp, ghi lý do');
select ok((select completed_at is null from app.student_test where code = 'PKT000001'), 'Về Nháp thì bỏ giờ hoàn thành');
select is((select stage_code from app.opportunity where code = 'CO000003'), 'L7', 'R-CRM-21: phiếu về Nháp không kéo cơ hội lùi giai đoạn');
select is(pg_temp.err($$select app.step_back_student_test(pg_temp.tid('PKT000001'))$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Phiếu Nháp không lùi được nữa');
-- (d) Cơ hội CO000004 (L5): phiếu hoàn thành → L6A; sau đó phiếu về Nháp rồi Huỷ → mọi phiếu đều Huỷ → sang L7, L8 phải chọn lý do bỏ qua test.
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000004'), pg_temp.test_data())$$), null, 'Cơ hội CO000004: tạo phiếu PKT000003');
select is(pg_temp.err($$select app.start_student_test(pg_temp.tid('PKT000003'))$$), null, 'PKT000003: bắt đầu test');
select is(pg_temp.err($$select app.submit_student_test(pg_temp.tid('PKT000003'))$$), null, 'PKT000003: nộp bài');
select is(pg_temp.err($$select app.enter_test_result(pg_temp.tid('PKT000003'), 6, 'Khá', 'B', 'NC', pg_temp.uid('teacher5'))$$), null, 'PKT000003: nhập kết quả, chọn giáo viên chấm');
select is(pg_temp.err($$select app.complete_student_test(pg_temp.tid('PKT000003'))$$), null, 'PKT000003: hoàn thành');
select is((select array[stage_code, substage_code] from app.opportunity where code = 'CO000004'), array['L6', 'L6A'], 'CO000004 lên L6A');
select is(pg_temp.err($$select app.step_back_student_test(pg_temp.tid('PKT000003'), 'Chấm lại')$$), null, 'PKT000003: đưa về Nháp');
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tid('PKT000003'), 'L5D')$$), null, 'PKT000003: huỷ');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L7')$$), 'HMT_THIEU_LY_DO',
          'R-CRM-14 (d): phiếu hoàn thành đã bị huỷ, mọi phiếu đều Huỷ → sang L7 phải chọn lý do bỏ qua test');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L8', 'L8A', null, null, true)$$), 'HMT_THIEU_LY_DO',
          'R-CRM-14 (d): sang L8 cũng phải chọn lý do bỏ qua test');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L7', null, 'PH_KHONG_MUON')$$), null, 'Chọn lý do bỏ qua test thì sang L7 được');
select is((select skip_reason_code from app.opportunity where code = 'CO000004'), 'PH_KHONG_MUON', 'Ghi lý do bỏ qua test');

-- ================= Huỷ (R-CRM-06) và nhóm con L5 (R-CRM-15) =================
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tid('PKT000003'), 'L5D')$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chặn: huỷ phiếu đã huỷ');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000005'), pg_temp.test_data())$$), null, 'CO000005 (L5): tạo phiếu PKT000004');
select is((select substage_code from app.opportunity where code = 'CO000005'), 'L5B', 'CO000005: có phiếu Nháp → L5B');
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tid('PKT000004'), null)$$), 'HMT_THIEU_LY_DO', 'R-CRM-06: huỷ phiếu bắt lý do');
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tid('PKT000004'), 'L5M')$$), 'HMT_THIEU_GHI_CHU', 'R-CRM-06: lý do khác bắt ghi chú');
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tid('PKT000004'), 'KHONG_CO')$$), 'HMT_DANH_MUC_KHONG_CO', 'R-CRM-06: lý do ngoài danh mục 13 bị chặn');
select is(pg_temp.err($$select app.start_student_test(pg_temp.tid('PKT000004'))$$), null, 'PKT000004: bắt đầu test');
select is(pg_temp.err($$select app.submit_student_test(pg_temp.tid('PKT000004'))$$), null, 'PKT000004: nộp bài');
select is((select substage_code from app.opportunity where code = 'CO000005'), 'L5P', 'CO000005: chờ giáo viên chấm → L5P');
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tid('PKT000004'), 'L5E')$$), null, 'R-CRM-06: huỷ được cả khi học sinh đã làm bài (Chờ giáo viên chấm)');
select is((select substage_code from app.opportunity where code = 'CO000005'), 'L5E', 'R-CRM-15 (3): mọi phiếu đều Huỷ → nhóm con nối với lý do huỷ (L5E)');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000005'), pg_temp.test_data())$$), null, 'CO000005: tạo phiếu thứ hai PKT000005');
select is((select substage_code from app.opportunity where code = 'CO000005'), 'L5B', 'Có phiếu Nháp trở lại → L5B');
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tid('PKT000005'), 'L5F')$$), null, 'Huỷ phiếu thứ hai (lý do L5F)');
select pg_temp.sudo($$update app.student_test set cancelled_at = now() - interval '1 day' where code = 'PKT000004'$$);
select is(pg_temp.l5(pg_temp.oid('CO000005')), 'L5F', 'R-CRM-15 (3): lấy lý do của phiếu huỷ gần nhất (L5F, không phải L5E)');
select pg_temp.sudo($$select app.refresh_opportunity_l5_substage((select id from app.opportunity where code = 'CO000005'))$$);
select is((select substage_code from app.opportunity where code = 'CO000005'), 'L5F', 'Nhóm con L5 cập nhật theo phiếu huỷ gần nhất');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000005'), pg_temp.test_data())$$), null, 'CO000005: phiếu thứ ba PKT000006');
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tid('PKT000006'), 'TAO_PHIEU_SAI')$$), null, 'Huỷ vì "Tạo phiếu sai"');
select is((select substage_code from app.opportunity where code = 'CO000005'), 'L5F', 'R-CRM-15 (3): bỏ qua phiếu huỷ vì "Tạo phiếu sai", vẫn theo phiếu huỷ trước đó (L5F)');
-- (4) chỉ còn phiếu "Tạo phiếu sai" → L5A.
select pg_temp.sudo($$update app.student_test set cancel_reason_code = 'TAO_PHIEU_SAI' where code in ('PKT000004', 'PKT000005')$$);
select pg_temp.sudo($$select app.refresh_opportunity_l5_substage((select id from app.opportunity where code = 'CO000005'))$$);
select is((select substage_code from app.opportunity where code = 'CO000005'), 'L5A', 'R-CRM-15 (4): chỉ còn phiếu "Tạo phiếu sai" → L5A');
-- Mở lại phiếu đã huỷ về Nháp bắt lý do (R-CRM-10); lịch nhắc bật lại.
select is(pg_temp.err($$select app.reopen_student_test(pg_temp.tid('PKT000006'), null)$$), 'HMT_THIEU_LY_DO', 'R-CRM-10: mở lại phiếu huỷ bắt lý do');
select is(pg_temp.err($$select app.reopen_student_test(pg_temp.tid('PKT000006'), 'Tạo nhầm huỷ')$$), null, 'Mở lại phiếu đã huỷ: được');
select is((select array[status_code, status_reason, cancel_reason_code] from app.student_test where code = 'PKT000006'), array['DRAFT', 'Tạo nhầm huỷ', null], 'Phiếu về Nháp, xoá lý do huỷ, ghi lý do mở lại');
select is((select status from app.appointment where student_test_id = pg_temp.tid('PKT000006') and is_auto_reminder), 'CHUA_LAM', 'Mở lại phiếu: lịch nhắc bật lại');
select is((select substage_code from app.opportunity where code = 'CO000005'), 'L5B', 'Mở lại phiếu Nháp → L5B');
select is(pg_temp.err($$select app.reopen_student_test(pg_temp.tid('PKT000006'), 'x')$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ mở lại được phiếu đã huỷ');
select is(pg_temp.err($$select app.update_student_test(pg_temp.tid('PKT000004'), '{"exam_name": "x"}')$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Phiếu đã huỷ chỉ đọc (sửa bị chặn)');
-- Lùi một bước ở Đang test, Chờ giáo viên chấm.
select is(pg_temp.err($$select app.start_student_test(pg_temp.tid('PKT000006'))$$), null, 'PKT000006: bắt đầu test');
select is(pg_temp.err($$select app.step_back_student_test(pg_temp.tid('PKT000006'))$$), null, 'Lùi Đang test → Nháp không cần lý do');
select is((select status_code from app.student_test where code = 'PKT000006'), 'DRAFT', 'Phiếu về Nháp');
select is(pg_temp.err($$select app.submit_student_test(pg_temp.tid('PKT000006'))$$), 'HMT_PHIEU_TRANG_THAI_SAI', 'Chưa bắt đầu thì chưa nộp');


-- ================= Lịch nhắc tự đóng khi phiếu sang Đang test (anh chốt 18/10) =================
select pg_temp.sudo($$create function pg_temp.tx(p_name text) returns uuid language sql stable security definer as 'select id from app.student_test where exam_name = p_name'$$);
select pg_temp.sudo($$grant execute on function pg_temp.tx(text) to public$$);
select pg_temp.sudo($$create function pg_temp.rem(p_name text) returns app.appointment language sql stable security definer as
  'select a from app.appointment a where a.student_test_id = (select id from app.student_test where exam_name = p_name) and a.is_auto_reminder order by a.created_at limit 1'$$);
select pg_temp.sudo($$grant execute on function pg_temp.rem(text) to public$$);
select pg_temp.sudo($$create temp table ov (n integer)$$);
select pg_temp.sudo($$grant all on ov to public$$);
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000007'), pg_temp.test_data('{"exam_name": "REM-A"}'))$$), null, 'Chuẩn bị: phiếu A cho cơ hội CO000007');
select is((pg_temp.rem('REM-A')).status, 'CHUA_LAM', 'Phiếu mới: lịch nhắc tự sinh còn Chưa làm');
insert into ov select app.appointment_overdue_count(now() + interval '60 days', true);
select is(pg_temp.err($$select app.start_student_test(pg_temp.tx('REM-A'))$$), null, 'Phiếu A bắt đầu test');
select is((select array[(pg_temp.rem('REM-A')).status, (pg_temp.rem('REM-A')).cancel_reason_code, (pg_temp.rem('REM-A')).cancel_note]),
          array['HUY', 'KHAC', 'Phiếu đã bắt đầu'], 'Phiếu sang Đang test: lịch nhắc tự sinh chưa sửa tay được đóng bằng Huỷ, lý do Khác, ghi chú "Phiếu đã bắt đầu"');
select is(app.appointment_overdue_count(now() + interval '60 days', true), (select n - 1 from ov), 'Lịch nhắc đã đóng không còn tính vào QUÁ HẠN');
select is(pg_temp.err($$select app.step_back_student_test(pg_temp.tx('REM-A'))$$), null, 'Lùi phiếu A về Nháp');
select is((pg_temp.rem('REM-A')).status, 'HUY', 'Lùi về Nháp không tự mở lại lịch nhắc đã đóng');
select is(pg_temp.err($$select app.reschedule_student_test(pg_temp.tx('REM-A'), now() + interval '6 days')$$), null, 'Đổi lịch phiếu A sau khi lùi về Nháp');
select is((select count(*)::int from app.appointment where student_test_id = pg_temp.tx('REM-A')), 1, 'Đổi lịch sau khi lùi về Nháp không sinh lịch nhắc mới');
select is((pg_temp.rem('REM-A')).status, 'HUY', 'Lịch nhắc vẫn đóng sau khi đổi lịch');
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tx('REM-A'), 'L5C')$$), null, 'Huỷ phiếu A');
select is(pg_temp.err($$select app.reopen_student_test(pg_temp.tx('REM-A'), 'Mở lại thử')$$), null, 'Mở lại phiếu A');
select is((pg_temp.rem('REM-A')).cancel_note, 'Phiếu đã bắt đầu', 'Mở lại phiếu không bật lại lịch nhắc đã đóng vì phiếu bắt đầu test (chỉ lịch huỷ theo phiếu mới bật lại)');
-- Lịch nhắc đã sửa tay giữ nguyên.
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000007'), pg_temp.test_data('{"exam_name": "REM-B"}'))$$), null, 'Chuẩn bị: phiếu B');
select pg_temp.sudo($$update app.appointment set scheduled_at = scheduled_at - interval '1 hour' where student_test_id = (select id from app.student_test where exam_name = 'REM-B')$$);
select is(pg_temp.err($$select app.start_student_test(pg_temp.tx('REM-B'))$$), null, 'Phiếu B bắt đầu test');
select is((pg_temp.rem('REM-B')).status, 'CHUA_LAM', 'Lịch nhắc người dùng đã sửa tay giữ nguyên (không tự đóng)');
-- Lịch người dùng tự tạo giữ nguyên.
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000007'), pg_temp.test_data('{"exam_name": "REM-C"}'))$$), null, 'Chuẩn bị: phiếu C');
select pg_temp.sudo($$insert into app.appointment (student_test_id, is_auto_reminder, activity_code, scheduled_at, title, owner_id, branch_id)
  select t.id, false, 'GOI_DIEN', now() + interval '1 day', 'Lịch người dùng tự tạo', t.owner_id, t.branch_id from app.student_test t where t.exam_name = 'REM-C'$$);
select is(pg_temp.err($$select app.start_student_test(pg_temp.tx('REM-C'))$$), null, 'Phiếu C bắt đầu test');
select is((select status from app.appointment where student_test_id = pg_temp.tx('REM-C') and not is_auto_reminder), 'CHUA_LAM', 'Lịch người dùng tự tạo giữ nguyên');
select is((pg_temp.rem('REM-C')).status, 'HUY', 'Cùng phiếu: lịch nhắc tự sinh được đóng');
-- Huỷ phiếu vẫn huỷ lịch nhắc, mở lại thì bật lại.
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000007'), pg_temp.test_data('{"exam_name": "REM-D"}'))$$), null, 'Chuẩn bị: phiếu D');
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tx('REM-D'), 'L5D')$$), null, 'Huỷ phiếu D khi còn Nháp');
select is((pg_temp.rem('REM-D')).cancel_note, 'Phiếu kiểm tra đã huỷ', 'Huỷ phiếu: lịch nhắc huỷ theo (ghi chú khác lịch đóng vì bắt đầu)');
select is(pg_temp.err($$select app.reopen_student_test(pg_temp.tx('REM-D'), 'Mở lại D')$$), null, 'Mở lại phiếu D');
select is((pg_temp.rem('REM-D')).status, 'CHUA_LAM', 'Mở lại phiếu đã huỷ: lịch nhắc huỷ theo phiếu được bật lại');

-- ================= Giáo viên được phân công (cổng giáo viên làm sau): chỉ phiếu mình chấm, mình phụ trách =================
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is((select array_agg(code order by code) from app.student_test), array['PKT000003'], 'RLS: giáo viên chỉ đọc phiếu mình là người chấm (PKT000003)');
select is((app.list_student_tests() ->> 'total')::int, 1, 'Danh sách phiếu của giáo viên: chỉ phiếu được phân công');
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tid('PKT000006'), 'L5C')$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không Huỷ phiếu (không có quyền Huỷ)');
select is(pg_temp.err($$select app.start_student_test(pg_temp.tid('PKT000006'))$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không thao tác phiếu không được phân công');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$update app.student_test set status_code = 'TEACHER_REVIEW', completed_at = null, completed_by = null, cancel_reason_code = null,
                       cancelled_at = null, cancelled_by = null where code = 'PKT000003'$$);
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.enter_test_result(pg_temp.tid('PKT000003'), 9, 'Giáo viên tự chấm', 'S', 'NC')$$), null, 'Giáo viên được phân công tự nhập kết quả');
select is((select result_on_behalf from app.student_test where code = 'PKT000003'), false, 'R-CRM-11: giáo viên chấm tự nhập thì không ghi "nhập thay"');
select is(pg_temp.err($$select app.complete_student_test(pg_temp.tid('PKT000003'))$$), null, 'Giáo viên được phân công hoàn thành phiếu mình chấm');
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is((select array_agg(code order by code) from app.student_test), array['PKT000001'], 'RLS: giáo viên khác chỉ đọc phiếu mình được phân công (PKT000001)');
select is(pg_temp.err($$select app.start_student_test(pg_temp.tid('PKT000003'))$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không thao tác phiếu của người khác');

-- ================= RLS và danh sách theo vai trò =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((select count(*)::int from app.student_test), 0, 'RLS: Tuyển sinh CS5 không đọc phiếu của cơ hội CS1');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000006'), pg_temp.test_data(jsonb_build_object('test_branch_id', (select id from app.branch where code = 'CS1'))))$$), null,
          'CS5 tạo phiếu cho cơ hội CS5 với cơ sở test là CS1');
select is((select count(*)::int from app.student_test), 1, 'Tuyển sinh CS5 đọc phiếu của cơ hội cơ sở mình');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((select count(*)::int from app.student_test where test_branch_id = (select id from app.branch where code = 'CS1') and branch_id = (select id from app.branch where code = 'CS5')), 0,
          'Cơ sở test khác cơ sở cơ hội: nhân viên cơ sở test chưa thấy phiếu (ghi TIEN-DO, xem lại ở P3e)');
select is((app.list_student_tests() ->> 'total')::int, (select count(*)::int from app.student_test), 'Danh sách phiếu: Tuyển sinh CS1 thấy phiếu của cơ sở mình');
select is(jsonb_array_length(app.list_student_tests('{}', 'time_asc', 2, 0) -> 'rows'), 2, 'Phân trang: cỡ trang 2');
select is(jsonb_array_length(app.list_student_tests('{}', 'time_asc', 100000, 0) -> 'rows') <= 100, true, 'Cỡ trang quá lớn bị cắt');
select is((app.list_student_tests('{"status": ["DRAFT"]}') ->> 'total')::int, (select count(*)::int from app.student_test where status_code = 'DRAFT' and branch_id = (select id from app.branch where code = 'CS1')), 'Lọc theo trạng thái');
select is((app.list_student_tests('{"mine": true}') ->> 'total')::int, (select count(*)::int from app.student_test where owner_id = pg_temp.uid('sales1')), 'Lọc "tôi phụ trách"');
select is((app.list_student_tests('{"created_by_me": true}') ->> 'total')::int, (select count(*)::int from app.student_test where created_by = pg_temp.uid('sales1')), 'Lọc "tôi tạo"');
select is((app.list_student_tests('{"grader_mine": true}') ->> 'total')::int, 0, 'Lọc "tôi chấm bài": nhân viên không phải giáo viên chấm nên 0');
select is((app.list_student_tests(jsonb_build_object('late_before', now() + interval '30 days', 'status', jsonb_build_array('DRAFT'))) ->> 'total')::int,
          (select count(*)::int from app.student_test where status_code = 'DRAFT'), 'Lọc phiếu Nháp quá giờ (nhãn "Quá giờ")');
select is((app.list_student_tests(jsonb_build_object('q', 'em hai')) ->> 'total')::int, 0, 'Tìm không dấu theo tên học sinh (CO000002 chưa có phiếu)');
select is((app.list_student_tests(jsonb_build_object('q', 'em ba')) ->> 'total')::int, (select count(*)::int from app.student_test t where t.opportunity_id = pg_temp.oid('CO000003')), 'Tìm không dấu theo tên học sinh: có kết quả');
select pg_temp.sudo($$update app.student set full_name = 'Em Ba Đổi Tên' where code = (select s.code from app.student s join app.opportunity o on o.student_id = s.id where o.code = 'CO000003')$$);
select is((app.list_student_tests(jsonb_build_object('q', 'doi ten')) ->> 'total')::int, (select count(*)::int from app.student_test t where t.opportunity_id = pg_temp.oid('CO000003')), 'Học sinh đổi tên thì ô tìm kiếm của phiếu đổi theo');
select is(jsonb_array_length(app.student_test_board()), 5, 'Kanban: đủ bốn cột + cột Đã huỷ, một lần gọi');
select is((select sum((c ->> 'total')::int)::int from jsonb_array_elements(app.student_test_board()) c), (select count(*)::int from app.student_test), 'Kanban: tổng các cột bằng tổng phiếu');
select is((select max(jsonb_array_length(c -> 'rows')) from jsonb_array_elements(app.student_test_board('{}', 1)) c), 1, 'Kanban: mỗi cột tối đa số thẻ yêu cầu');
select is((select c ->> 'name' from jsonb_array_elements(app.student_test_board()) c limit 1), 'Nháp', 'Kanban: cột đầu là Nháp');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((app.list_student_tests() ->> 'total')::int, (select count(*)::int from app.student_test), 'CSKH CS1 thấy phiếu cơ sở mình');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.cancel_student_test(pg_temp.tid('PKT000006'), 'L5C')$$), null, 'Trưởng cơ sở huỷ phiếu cơ sở mình: được');
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is(pg_temp.err($$select app.list_student_tests()$$), null, 'Giáo viên gọi danh sách: được, chỉ thấy phiếu được phân công');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.list_student_tests()$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không xem danh sách phiếu');
select is(pg_temp.err($$select app.student_test_board()$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không xem Kanban phiếu');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.list_student_tests() ->> 'total')::int, (select count(*)::int from app.student_test), 'ADMIN (toàn hệ thống) thấy mọi phiếu');

-- Ghi chú, lịch sử gắn phiếu: quyền xem theo phạm vi của phiếu.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(app.can_see_note_target('STUDENT_TEST', pg_temp.tid('PKT000001')), true, 'Ghi chú phiếu: người cùng cơ sở xem được');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(app.can_see_note_target('STUDENT_TEST', pg_temp.tid('PKT000001')), false, 'Ghi chú phiếu: người khác cơ sở không xem được');
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is(app.can_see_note_target('STUDENT_TEST', pg_temp.tid('PKT000001')), true, 'Ghi chú phiếu: giáo viên được phân công xem được');

select * from finish();
rollback;
