-- GV-12 bổ sung: app.teacher_my_pending_tests (R-CRM-11, R-GV-08, R-GV-13). Mỗi luật có ca đúng và ca bị chặn.
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

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('sales1'), ('teacher1'), ('teacher2'), ('hs');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = 'CS1'),
       case when u.key = 'hs' then 'HS999998' end, false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('sales1', 'SALES'), ('teacher1', 'TEACHER'), ('teacher2', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;

-- Dựng hai phiếu: PKT đầu giao teacher1, PKT hai giao teacher2; cả hai nộp bài (Chờ giáo viên chấm).
select pg_temp.sudo($$insert into app.room (branch_id, code, name) select id, 'TK101', 'Phòng 101' from app.branch where code = 'CS1'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900000501', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900000502', '{"student_name": "Em Hai", "student_birth_year": 2013}'));
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
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900000501'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900000502'));
select app.change_opportunity_stage(pg_temp.oid('CO000001'), 'L5');
select app.change_opportunity_stage(pg_temp.oid('CO000002'), 'L5');
select app.create_student_test(pg_temp.oid('CO000001'), pg_temp.test_data(jsonb_build_object('grader_id', pg_temp.uid('teacher1'), 'room_id', pg_temp.room('TK101'))));
select app.create_student_test(pg_temp.oid('CO000002'), pg_temp.test_data(jsonb_build_object('grader_id', pg_temp.uid('teacher2'), 'room_id', pg_temp.room('TK101'))));

-- Luật R-CRM-11: phiếu còn Nháp thì chưa hiện ở mục chờ chấm.
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is((app.teacher_my_pending_tests() ->> 'total')::int, 0, 'Phiếu còn Nháp: chưa hiện trong mục chờ chấm');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.start_student_test(pg_temp.tid('PKT000001'));
select app.submit_student_test(pg_temp.tid('PKT000001'));
select app.start_student_test(pg_temp.tid('PKT000002'));
select app.submit_student_test(pg_temp.tid('PKT000002'));

-- Luật R-CRM-11, R-GV-08: mỗi giáo viên chỉ thấy phiếu giao cho mình.
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is((app.teacher_my_pending_tests() ->> 'total')::int, 1, 'Giáo viên 1 thấy đúng một phiếu của mình');
select is(app.teacher_my_pending_tests() -> 'rows' -> 0 ->> 'code', 'PKT000001', 'Phiếu hiện đúng mã PKT000001 (không lẫn phiếu giáo viên 2)');
-- Luật R-GV-13: chỉ tên em, môn, tên đề, giờ làm; không số điện thoại, phụ huynh.
select is((select array_agg(k order by k) from jsonb_object_keys(app.teacher_my_pending_tests() -> 'rows' -> 0) k),
          array['code', 'exam_name', 'scheduled_at', 'student_name', 'subject_name', 'test_id'], 'R-GV-13: hàng trả về không có thông tin liên hệ, phụ huynh');
select is(app.teacher_my_pending_tests() -> 'rows' -> 0 ->> 'student_name', 'Em Một', 'Hiện tên em');
select pg_temp.claims(pg_temp.uid('teacher2'), 'aal1');
select is(app.teacher_my_pending_tests() -> 'rows' -> 0 ->> 'code', 'PKT000002', 'Giáo viên 2 chỉ thấy phiếu của mình');

-- Luật R-CRM-11: phiếu đã Hoàn thành thì không còn chờ chấm.
select app.enter_test_result(pg_temp.tid('PKT000002'), 8, 'Tốt', 'A', 'CB');
select app.complete_student_test(pg_temp.tid('PKT000002'));
select is((app.teacher_my_pending_tests() ->> 'total')::int, 0, 'Phiếu đã Hoàn thành: hết chờ chấm');


-- GV-15: đọc phiếu (R-CRM-11, R-GV-08, R-GV-13).
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is(app.teacher_test_sheet(pg_temp.tid('PKT000001')) -> 'test' ->> 'student_name', 'Em Một', 'GV-15: giáo viên chấm đọc được phiếu của mình');
select is((select array_agg(k order by k) from jsonb_object_keys(app.teacher_test_sheet(pg_temp.tid('PKT000001')) -> 'test') k) && array['parent_name', 'parent_phone', 'owner_name'], false,
          'R-GV-13: phiếu cho giáo viên không có phụ huynh, điện thoại');
select ok(jsonb_array_length(app.teacher_test_sheet(pg_temp.tid('PKT000001')) -> 'levels') > 0, 'Có danh sách trình độ từ danh mục');
select is(pg_temp.err($$select app.teacher_test_sheet(pg_temp.tid('PKT000002'))$$), 'HMT_KHONG_CO_QUYEN', 'R-GV-08: phiếu của giáo viên khác bị chặn');
select is(pg_temp.err($$select app.teacher_test_sheet(gen_random_uuid())$$), 'HMT_KHONG_CO_QUYEN', 'Phiếu không tồn tại: cùng một lỗi, không lộ');
select is(pg_temp.err($$select app.enter_test_result(pg_temp.tid('PKT000001'), 7.5, 'Khá', 'A', 'CB')$$), null, 'GV-15: Lưu nháp kết quả bằng hàm có sẵn');
select is(app.teacher_test_sheet(pg_temp.tid('PKT000001')) -> 'test' ->> 'score', '7.5', 'Điểm đã lưu hiện lại');
select is(pg_temp.err($$select app.complete_student_test(pg_temp.tid('PKT000001'))$$), null, 'GV-15: Trả về sale (Hoàn thành)');
select is(app.teacher_test_sheet(pg_temp.tid('PKT000001')) -> 'test' ->> 'status_code', 'COMPLETED', 'Phiếu Hoàn thành vẫn mở xem được');

-- Chặn: người không có quyền xem phiếu (học sinh) và người chưa đăng nhập.
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.teacher_my_pending_tests()$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không gọi được');
select is(pg_temp.err($$select app.teacher_test_sheet(pg_temp.tid('PKT000001'))$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không đọc được phiếu');
select * from finish();
rollback;
