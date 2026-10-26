-- P3d-1 (DB): get_opportunity, list_opportunities, opportunity_board, opportunity_group_counts, export_opportunities
-- (docs/spec/04 R-CRM-07, 22, 29; TS-07, TS-08).
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
select pg_temp.sudo($$insert into app.room (branch_id, code, name) select id, 'TK101', 'Phòng 101' from app.branch where code = 'CS1'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900001001', '{"parent_name": "Chị Cơ Hội A", "student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900001002', '{"parent_name": "Chị Cơ Hội B", "student_name": "Em Hai", "student_birth_year": 2013}'));
select app.create_lead(pg_temp.lead_data('0900001003', '{"parent_name": "Chị Cơ Hội C", "student_name": "Em Ba", "student_birth_year": 2011}'));
select app.create_lead(pg_temp.lead_data('0900001004', '{"parent_name": "Chị Cơ Hội D", "student_name": "Em Bốn", "student_birth_year": 2010}'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900001099', '{"parent_name": "Chị Cơ Hội CS5", "student_name": "Em Chín", "student_birth_year": 2012}'));
select pg_temp.sudo($$create temp table lead_ids as select id, parent_phone from app.lead where parent_phone like '09000010%'$$);
select pg_temp.sudo($$grant select on lead_ids to authenticated$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable as 'select id from lead_ids where parent_phone = p_phone'$$);
select pg_temp.sudo($$grant execute on function pg_temp.lid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as 'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.test_data() returns jsonb language sql stable as
  'select jsonb_build_object(''subject_code'', ''TOAN'', ''grade_code'', (select code from app.catalog_item where catalog_code = ''GRADE'' order by sort_order limit 1),
     ''mode_code'', ''OFFLINE'', ''level_code'', ''CO_BAN'', ''exam_name'', ''Toán cơ bản'', ''scheduled_at'', now() + interval ''3 days'')'$$);
select pg_temp.sudo($$grant execute on function pg_temp.test_data() to public$$);
-- Bốn cơ hội của CS1 (sales1) và một của CS5 (sales5).
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900001001'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900001002'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900001003'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900001004'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900001099'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
-- A: lịch hẹn quá hạn; B (lên L5, có phiếu test): lịch hẹn hôm nay; C: lịch hẹn sắp tới; D: chưa có lịch hẹn.
select app.create_appointment(null, 'GOI_DIEN', now() - interval '3 days', 'Gọi A', null, null, pg_temp.oid('0900001001'));
select app.create_appointment(null, 'GOI_DIEN', now(), 'Gọi B', null, null, pg_temp.oid('0900001002'));
select app.create_appointment(null, 'GOI_DIEN', now() + interval '3 days', 'Gọi C', null, null, pg_temp.oid('0900001003'));
select app.change_opportunity_stage(pg_temp.oid('0900001002'), 'L5');
select app.create_student_test(pg_temp.oid('0900001002'), pg_temp.test_data());
create function pg_temp.n(p_filters jsonb) returns integer language sql stable as $$
  select (app.list_opportunities(p_filters) ->> 'total')::int $$;
create function pg_temp.col(p_filters jsonb, p_stage text, p_key text) returns integer language sql stable as $$
  select (c ->> p_key)::int from jsonb_array_elements(app.opportunity_board(p_filters)) c where c ->> 'stage_code' = p_stage $$;
create function pg_temp.colbar(p_filters jsonb, p_stage text, p_key text) returns integer language sql stable as $$
  select (c -> 'bar' ->> p_key)::int from jsonb_array_elements(app.opportunity_board(p_filters)) c where c ->> 'stage_code' = p_stage $$;
grant execute on function pg_temp.n(jsonb), pg_temp.col(jsonb, text, text), pg_temp.colbar(jsonb, text, text) to public;
create function pg_temp.get(p_phone text) returns jsonb language sql stable as $$ select app.get_opportunity(pg_temp.oid(p_phone)) $$;
grant execute on function pg_temp.get(text) to public;

-- ================= get_opportunity (TS-08) =================
select is(pg_temp.get('0900001001') ->> 'parent_name', 'Chị Cơ Hội A', 'get_opportunity: có tên phụ huynh');
select is(pg_temp.get('0900001001') ->> 'owner_name', 'Giả sales1', 'Có tên người phụ trách (người xem có thể không đọc được bảng tài khoản)');
select is(pg_temp.get('0900001001') ->> 'branch_code', 'CS1', 'Có mã cơ sở');
select is(pg_temp.get('0900001001') ->> 'stage_code', 'L1', 'Có giai đoạn L1 (R-CRM-36)');
select isnt(pg_temp.get('0900001001') ->> 'lead_code', null, 'Có mã lead gốc');
select is(pg_temp.get('0900001001') ->> 'parent_phone', '0900001001', 'Có số điện thoại phụ huynh');
select is(pg_temp.get('0900001001') -> 'search_text', null, 'Không trả cột tìm kiếm');
select is((pg_temp.get('0900001001') ->> 'appointments_total')::int, 1, 'Đếm lịch hẹn của cơ hội');
select is((pg_temp.get('0900001001') ->> 'appointments_open')::int, 1, 'Đếm lịch hẹn chưa làm');
select is((pg_temp.get('0900001004') ->> 'appointments_total')::int, 0, 'Cơ hội chưa có lịch hẹn: 0');
select is(jsonb_array_length(pg_temp.get('0900001001') -> 'tests'), 0, 'Cơ hội chưa có phiếu: danh sách phiếu rỗng');
select is((pg_temp.get('0900001002') ->> 'tests_total')::int, 1, 'Đếm phiếu kiểm tra');
select is(pg_temp.get('0900001002') -> 'tests' -> 0 ->> 'code', 'PKT000001', 'Danh sách phiếu có mã phiếu');
select is(pg_temp.get('0900001002') -> 'tests' -> 0 ->> 'status', 'Nháp', 'Danh sách phiếu có tên trạng thái (không phải mã)');
select is((pg_temp.get('0900001002') -> 'test_state' ->> 'in_progress')::int, 1, 'Có trạng thái phiếu test (một phiếu dang dở, R-CRM-12)');
select is(pg_temp.get('0900001002') -> 'test_state' -> 'in_progress_codes' ->> 0, 'PKT000001', 'Có mã phiếu dang dở để hộp chặn nêu rõ');
select is(pg_temp.get('0900001001') ->> 'merged_into_code', null, 'Cơ hội đang dùng không có mã bản giữ lại');
select isnt(pg_temp.get('0900001001') ->> 'created_by_name', null, 'Có tên người tạo');
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is(pg_temp.get('0900001001') ->> 'parent_name', 'Chị Cơ Hội A', 'Đồng nghiệp cùng cơ sở đọc được (phạm vi cơ sở)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.get('0900001001') ->> 'parent_name', 'Chị Cơ Hội A', 'CSKH cùng cơ sở đọc được');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(pg_temp.get('0900001001') ->> 'parent_name', 'Chị Cơ Hội A', 'Trưởng cơ sở đọc được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.get('0900001001') ->> 'parent_name', 'Chị Cơ Hội A', 'Admin đọc được mọi cơ sở');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select pg_temp.get('0900001001')$$), 'HMT_KHONG_CO_QUYEN', 'Tuyển sinh CS5 không đọc được cơ hội của CS1');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select pg_temp.get('0900001099')$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên (không có quyền Cơ hội) không đọc được');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select pg_temp.get('0900001099')$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không đọc được');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.get_opportunity(gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Không có cơ hội: báo không tìm thấy');

-- ================= list_opportunities: bộ lọc mới =================
select is(pg_temp.n('{}'), 4, 'Sales CS1 thấy 4 cơ hội của cơ sở mình');
select is(pg_temp.n('{"source": ["FACEBOOK_ADS"]}'), 4, 'Lọc nguồn: khớp');
select is(pg_temp.n('{"source": ["KHONG_CO"]}'), 0, 'Lọc nguồn: không khớp thì rỗng');
select is(pg_temp.n('{"source_type": ["MARKETING"]}'), 4, 'Lọc loại nguồn');
select is(pg_temp.n('{"channel": ["FACEBOOK_ADS_LEAD_FORM"]}'), 4, 'Lọc kênh');
select is(pg_temp.n('{"stage": ["L5"]}'), 1, 'Lọc giai đoạn L5');
select is(pg_temp.n('{"appointment": ["OVERDUE"]}'), 1, 'R-CRM-07: lọc lịch hẹn Quá hạn');
select is(pg_temp.n('{"appointment": ["TODAY"]}'), 1, 'Lọc lịch hẹn Hôm nay');
select is(pg_temp.n('{"appointment": ["UPCOMING"]}'), 1, 'Lọc lịch hẹn Sắp tới');
select is(pg_temp.n('{"appointment": ["NONE"]}'), 1, 'Lọc chưa có lịch hẹn');
select is(pg_temp.n('{"appointment": ["OVERDUE", "TODAY"]}'), 2, 'R-CRM-07: cùng nhóm là HOẶC (Quá hạn hoặc Hôm nay)');
select is(pg_temp.n('{"appointment": ["OVERDUE"], "stage": ["L5"]}'), 0, 'R-CRM-07: khác nhóm là VÀ (quá hạn và L5)');
select is(pg_temp.n('{"mine_roles": ["OWNER"]}'), 4, 'Tôi phụ trách: người tạo là người phụ trách');
select is(pg_temp.n('{"mine_roles": ["SUPPORT"]}'), 0, 'Tôi hỗ trợ: chưa ai hỗ trợ');
select is(pg_temp.n('{"only_merged": true}'), 0, 'Chỉ bản đã gộp: chưa có');
select ok((app.list_opportunities('{}') -> 'rows' -> 0 ->> 'source_code') is not null, 'Dòng danh sách có nguồn');
select ok((app.list_opportunities('{}') -> 'rows' -> 0) ? 'campaign_name' and (app.list_opportunities('{}') -> 'rows' -> 0) ? 'supporter_name', 'Dòng danh sách có chiến dịch, người hỗ trợ');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.n('{"mine_roles": ["OWNER"]}'), 0, 'CSKH không phụ trách cơ hội nào: Tôi phụ trách rỗng');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.n('{}'), 1, 'Sales CS5 chỉ thấy cơ hội của CS5');
select is(pg_temp.n('{"appointment": ["OVERDUE"]}'), 0, 'Lọc lịch hẹn vẫn trong phạm vi cơ sở');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.list_opportunities('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không xem được danh sách');

-- ================= opportunity_board =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(jsonb_array_length(app.opportunity_board('{}')), 8, 'Kanban: đủ tám cột L1–L8');
select is(pg_temp.col('{}', 'L1', 'total'), 3, 'Cột L1 có 3 cơ hội');
select is(pg_temp.col('{}', 'L5', 'total'), 1, 'Cột L5 có 1 cơ hội');
select is(pg_temp.colbar('{}', 'L1', 'overdue'), 1, 'Thanh màu L1: 1 quá hạn');
select is(pg_temp.colbar('{}', 'L1', 'ok'), 1, 'Thanh màu L1: 1 sắp tới');
select is(pg_temp.colbar('{}', 'L1', 'none'), 1, 'Thanh màu L1: 1 chưa có lịch');
select is(pg_temp.colbar('{}', 'L5', 'today'), 1, 'Thanh màu L5: 1 hôm nay');
select is(pg_temp.col('{"appointment": ["OVERDUE"]}', 'L1', 'total'), 1, 'Lọc quá hạn: tổng cột còn 1');
select is(pg_temp.colbar('{"appointment": ["OVERDUE"]}', 'L1', 'ok'), 1, 'Lọc lịch hẹn không đổi số đếm thanh màu (tính cả cột)');
select is(jsonb_array_length((select c -> 'rows' from jsonb_array_elements(app.opportunity_board('{"appointment": ["OVERDUE"]}')) c where c ->> 'stage_code' = 'L1')), 1, 'Lọc quá hạn: thẻ của cột chỉ còn 1');
select is(pg_temp.col('{"source": ["KHONG_CO"]}', 'L1', 'total'), 0, 'Lọc nguồn không khớp: cột rỗng');
select ok((select c -> 'rows' -> 0 ? 'parent_phone' and c -> 'rows' -> 0 ? 'source_code' from jsonb_array_elements(app.opportunity_board('{}')) c where c ->> 'stage_code' = 'L1'), 'Thẻ có SĐT và nguồn');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.col('{}', 'L1', 'total'), 1, 'Kanban chỉ trong cơ sở của người xem');

-- ================= opportunity_group_counts =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((app.opportunity_group_counts('{}', array['stage']) ->> 'total')::int, 4, 'Group By: tổng đủ 4');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.opportunity_group_counts('{}', array['stage']) -> 'groups') g where g ->> 'k1' = 'L1'), 3, 'Group By giai đoạn: L1 có 3');
select is((select g ->> 'l1' from jsonb_array_elements(app.opportunity_group_counts('{}', array['stage']) -> 'groups') g where g ->> 'k1' = 'L5'), (select name from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5'), 'Nhãn nhóm là tên giai đoạn');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.opportunity_group_counts('{}', array['stage', 'source']) -> 'groups') g where g ->> 'k1' = 'L1' and g ->> 'k2' = 'FACEBOOK_ADS'), 3, 'Group By hai cấp: giai đoạn rồi nguồn');
select is((select g ->> 'l1' from jsonb_array_elements(app.opportunity_group_counts('{}', array['owner']) -> 'groups') g limit 1), 'Giả sales1', 'Nhãn nhóm người phụ trách là tên người');
select is((app.opportunity_group_counts('{"appointment": ["OVERDUE"]}', array['stage']) ->> 'total')::int, 1, 'Group By theo bộ lọc của danh sách');
select is(pg_temp.err($$select app.opportunity_group_counts('{}', array['khong_co'])$$), 'HMT_NHOM_SAI', 'Trường nhóm lạ bị chặn');
select is(pg_temp.err($$select app.opportunity_group_counts('{}', array['stage', 'stage'])$$), 'HMT_NHOM_SAI', 'Hai cấp giống nhau bị chặn');
select is(pg_temp.err($$select app.opportunity_group_counts('{}', array['stage', 'source', 'owner'])$$), 'HMT_NHOM_SAI', 'Quá hai cấp bị chặn');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((app.opportunity_group_counts('{}', array['stage']) ->> 'total')::int, 1, 'Group By trong phạm vi cơ sở');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.opportunity_group_counts('{}', array['stage'])$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không đếm nhóm được');

-- ================= export_opportunities =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.export_opportunities('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Nhân viên kinh doanh không có quyền xuất');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is((app.export_opportunities('{}') ->> 'exported')::int, 4, 'Trưởng cơ sở xuất đúng số cơ hội trong cơ sở mình');
select is((select count(*) from app.export_log where module_code = 'OPPORTUNITY' and row_count = 4), 1::bigint, 'Xuất file ghi nhật ký xuất');
select isnt(app.export_opportunities('{}') -> 'rows' -> 0 ->> 'stage', null, 'Dòng xuất có tên giai đoạn (không phải mã)');
select is((app.export_opportunities('{"appointment": ["OVERDUE", "TODAY"]}') ->> 'exported')::int, 2, 'Xuất theo bộ lọc nhiều lựa chọn cùng nhóm');
select is((app.export_opportunities('{"q": "Cơ Hội CS5"}') ->> 'exported')::int, 0, 'Xuất không lấy cơ hội cơ sở khác');
reset role;
update app.setting_def set value = '2' where key = 'export_max_rows';
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(app.export_opportunities('{}') - 'rows', '{"total": 4, "exported": 2, "truncated": true}'::jsonb, 'Quá export_max_rows: cắt và báo đã cắt');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.export_opportunities('{}') ->> 'total')::int, 5, 'Admin xuất toàn hệ thống');

select * from finish();
rollback;
