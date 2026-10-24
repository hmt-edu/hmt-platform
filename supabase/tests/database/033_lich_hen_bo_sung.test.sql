-- Lịch hẹn bổ sung (QĐ-Đ6, Đ33 đến Đ36): Xuất (export_appointments), Group By (appointment_group_counts), giao việc hàng loạt
-- (assign_appointments), bộ lọc `kind` của list_appointments (docs/spec/04 R-CRM-04, 07, 38). Mỗi luật có ca đúng và ca bị chặn;
-- mỗi vai trò thử trong và ngoài cơ sở.
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
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1'), ('teacher1'), ('teacher5'), ('hs'), ('sales5b');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999999' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5'), ('sales5b', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('sales5b', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);


-- ================= Dựng dữ liệu =================
select pg_temp.sudo($$create function pg_temp.test_data(p_extra jsonb default '{}'::jsonb) returns jsonb language sql stable as
  'select jsonb_build_object(''subject_code'', ''TOAN'', ''grade_code'', (select code from app.catalog_item where catalog_code = ''GRADE'' order by sort_order limit 1),
     ''mode_code'', ''OFFLINE'', ''level_code'', ''CO_BAN'', ''scheduled_at'', now() + interval ''3 days'') || p_extra'$$);
select pg_temp.sudo($$grant execute on function pg_temp.test_data(jsonb) to public$$);
select pg_temp.sudo($$create function pg_temp.oid(p_code text) returns uuid language sql stable security definer as 'select id from app.opportunity where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.lid(p_code text) returns uuid language sql stable security definer as 'select id from app.lead where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.lid(text) to public$$);

select pg_temp.sudo($$create function pg_temp.notes(p_type text, p_id uuid) returns integer language sql stable security definer as 'select count(*)::integer from app.note where entity_type = p_type and entity_id = p_id and body like ''Giao lịch hẹn%'''$$);
select pg_temp.sudo($$grant execute on function pg_temp.notes(text, uuid) to public$$);
select pg_temp.sudo($$create function pg_temp.audit_has(p_table text, p_id uuid, p_like text) returns boolean language sql stable security definer as
  'select exists (select from app.audit_log a join app.audited_table t on t.id = a.table_id where t.table_name = p_table and a.record_id = p_id and a.action = ''U'' and a.changes::text like p_like)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.audit_has(text, uuid, text) to public$$);
select pg_temp.sudo($$create function pg_temp.aid(p_title text) returns uuid language sql stable security definer as 'select id from app.appointment where title = p_title'$$);
select pg_temp.sudo($$grant execute on function pg_temp.aid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.owner_of(p_title text) returns text language sql stable security definer as 'select u.login_name from app.appointment a join app.user_account u on u.id = a.owner_id where a.title = p_title'$$);
select pg_temp.sudo($$grant execute on function pg_temp.owner_of(text) to public$$);
select pg_temp.sudo($$create function pg_temp.export_rows(p_module text) returns integer language sql stable security definer as 'select coalesce(sum(row_count), 0)::integer from app.export_log where module_code = p_module'$$);
select pg_temp.sudo($$grant execute on function pg_temp.export_rows(text) to public$$);

-- ================= Dựng dữ liệu =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900000701', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900000702', '{"student_name": "Em Hai", "student_birth_year": 2011}'));
select app.create_appointment(pg_temp.lid('LD000001'), 'GOI_DIEN', now() + interval '2 days', 'A1 lead một');
select app.create_appointment(pg_temp.lid('LD000001'), 'GOI_DIEN', now() + interval '3 days', 'A2 lead một');
select app.create_appointment(pg_temp.lid('LD000002'), 'GOI_DIEN', now() + interval '4 days', 'A3 lead hai');
select app.create_opportunity(pg_temp.lid('LD000002'));
select app.create_appointment(null, 'GOI_DIEN', now() + interval '5 days', 'A4 cơ hội', null, null, pg_temp.oid('CO000001'));
select app.create_appointment(pg_temp.lid('LD000001'), 'GOI_DIEN', now() + interval '6 days', 'A5 sẽ hoàn thành');
select app.create_appointment(pg_temp.lid('LD000001'), 'GOI_DIEN', now() + interval '7 days', 'A6 sẽ huỷ');
select app.complete_appointment(pg_temp.aid('A5 sẽ hoàn thành'));
select app.cancel_appointment(pg_temp.aid('A6 sẽ huỷ'),
  (select code from app.catalog_item where catalog_code = 'APPOINTMENT_CANCEL_REASON' and is_active and not requires_note order by sort_order limit 1));
-- Phiếu kiểm tra có lịch nhắc tự sinh (đi theo người phụ trách phiếu).
select app.change_opportunity_stage(pg_temp.oid('CO000001'), 'L5');
select app.create_student_test(pg_temp.oid('CO000001'), pg_temp.test_data());
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900000799', '{"student_name": "Em Chín", "student_birth_year": 2012}'));
select app.create_appointment(pg_temp.lid('LD000003'), 'GOI_DIEN', now() + interval '2 days', 'A7 cơ sở 5');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');

-- Tập lịch hẹn CS1: A1, A2, A3, A4, A5 (Hoàn thành), A6 (Huỷ), lịch nhắc tự sinh của phiếu = 7 dòng; CS5: A7.
select is((select count(*)::int from app.appointment where branch_id = (select id from app.branch where code = 'CS1')), 7, 'Dữ liệu thử: 7 lịch hẹn ở CS1');

-- ================= Group By (Đ35) =================
select is((app.appointment_group_counts('{}', array['status']) ->> 'total')::int, 7, 'Group By: tổng số lịch hẹn trong cơ sở mình (không tính cơ sở khác)');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.appointment_group_counts('{}', array['status']) -> 'groups') g where g ->> 'k1' = 'CHUA_LAM'), 5, 'Group By trạng thái: 5 lịch Chưa làm');
select is((select g ->> 'l1' from jsonb_array_elements(app.appointment_group_counts('{}', array['status']) -> 'groups') g where g ->> 'k1' = 'HOAN_THANH'), 'Hoàn thành', 'Nhãn nhóm là tiếng Việt, không phải mã');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.appointment_group_counts('{}', array['kind']) -> 'groups') g where g ->> 'k1' = 'STUDENT_TEST'), 1, 'Group By loại hồ sơ: 1 lịch gắn phiếu (lịch nhắc tự sinh)');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.appointment_group_counts('{}', array['kind']) -> 'groups') g where g ->> 'k1' = 'LEAD'), 5, 'Group By loại hồ sơ: 5 lịch gắn lead');
select is((select g ->> 'l1' from jsonb_array_elements(app.appointment_group_counts('{}', array['kind']) -> 'groups') g where g ->> 'k1' = 'OPPORTUNITY'), 'Cơ hội', 'Nhãn loại hồ sơ: Cơ hội');
select is((select sum((g ->> 'count')::int)::int from jsonb_array_elements(app.appointment_group_counts('{}', array['status', 'kind']) -> 'groups') g), 7, 'Group By hai cấp: tổng các nhóm bằng tổng số lịch');
select is((select count(*)::int from jsonb_array_elements(app.appointment_group_counts('{}', array['owner']) -> 'groups') g), 1, 'Group By người phụ trách: lịch của CS1 đều do sales1 phụ trách (một nhóm)');
select is((select g ->> 'l1' from jsonb_array_elements(app.appointment_group_counts('{}', array['branch']) -> 'groups') g limit 1), 'CS1 ' || (select name from app.branch where code = 'CS1'), 'Nhãn cơ sở: mã và tên');
select is((select count(*)::int from jsonb_array_elements(app.appointment_group_counts('{}', array['activity']) -> 'groups') g), 1, 'Group By loại hoạt động: một nhóm (Gọi điện)');
select is((app.appointment_group_counts('{"status": ["HUY"]}', array['kind']) ->> 'total')::int, 1, 'Group By dùng cùng bộ lọc như danh sách (chỉ lịch Huỷ)');
select is((app.appointment_group_counts('{"kind": ["LEAD"]}', array['status']) ->> 'total')::int, (app.list_appointments('{"kind": ["LEAD"]}') ->> 'total')::int, 'Bộ lọc loại hồ sơ: đếm nhóm khớp danh sách');
select is((app.list_appointments('{"kind": ["STUDENT_TEST"]}') ->> 'total')::int, 1, 'Danh sách có bộ lọc loại hồ sơ: chỉ lịch gắn phiếu');
select is((app.list_appointments('{"kind": ["LEAD", "OPPORTUNITY"]}') ->> 'total')::int, 6, 'Bộ lọc loại hồ sơ nhiều giá trị là HOẶC');
select is(pg_temp.err($$select app.appointment_group_counts('{}', array['khong_co'])$$), 'HMT_NHOM_SAI', 'Chặn: trường nhóm lạ');
select is(pg_temp.err($$select app.appointment_group_counts('{}', array['status', 'kind', 'owner'])$$), 'HMT_NHOM_SAI', 'Chặn: Group By quá hai cấp');
select is(pg_temp.err($$select app.appointment_group_counts('{}', array['status', 'status'])$$), 'HMT_NHOM_SAI', 'Chặn: hai cấp trùng nhau');
select is(pg_temp.err($$select app.appointment_group_counts('{}', array[]::text[])$$), 'HMT_NHOM_SAI', 'Chặn: không chọn trường nhóm');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((app.appointment_group_counts('{}', array['status']) ->> 'total')::int, 1, 'Phạm vi: Tuyển sinh CS5 chỉ đếm lịch hẹn của cơ sở mình');
-- Hiện trạng ghi để đối chiếu Đ34: phạm vi XEM lịch hẹn của Tuyển sinh là CƠ SỞ (không chỉ lịch của mình).
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is((app.list_appointments('{}') ->> 'total')::int, 7, 'Hiện trạng: Tuyển sinh thấy mọi lịch hẹn của cơ sở mình, không chỉ lịch do mình phụ trách (đối chiếu QĐ-Đ34)');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.appointment_group_counts('{}', array['status'])$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không có quyền xem lịch hẹn: Group By bị chặn');

-- ================= Xuất (quyền Xuất theo ma trận) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.export_appointments('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không có quyền Xuất lịch hẹn');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.export_appointments('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH không có quyền Xuất lịch hẹn');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.export_appointments('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không có quyền Xuất lịch hẹn');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.export_appointments('{}') ->> 'exported')::int, 7, 'Trưởng cơ sở xuất đúng lịch hẹn của cơ sở mình (không có cơ sở khác)');
select is((app.export_appointments('{}') ->> 'truncated')::boolean, false, 'Chưa vượt export_max_rows thì không cắt');
select is((select count(*)::int from jsonb_array_elements(app.export_appointments('{}') -> 'rows') r where r ->> 'branch' <> 'CS1'), 0, 'Dòng xuất chỉ có cơ sở của người xuất');
select is((select r ->> 'status' from jsonb_array_elements(app.export_appointments('{"status": ["HUY"]}') -> 'rows') r), 'Huỷ', 'Xuất theo bộ lọc; trạng thái là chữ tiếng Việt');
select is((select r ->> 'activity' from jsonb_array_elements(app.export_appointments('{"status": ["HUY"]}') -> 'rows') r), (select name from app.catalog_item where catalog_code = 'ACTIVITY_TYPE' and code = 'GOI_DIEN'), 'Xuất có tên loại hoạt động, không phải mã');
select is((select r ->> 'kind' from jsonb_array_elements(app.export_appointments('{"kind": ["STUDENT_TEST"]}') -> 'rows') r), 'Phiếu kiểm tra', 'Xuất có loại hồ sơ gắn');
select is((select r ->> 'record_code' from jsonb_array_elements(app.export_appointments('{"kind": ["OPPORTUNITY"]}') -> 'rows') r), 'CO000001', 'Xuất có mã hồ sơ gắn');
select is((select (r ->> 'auto_reminder')::boolean from jsonb_array_elements(app.export_appointments('{"kind": ["STUDENT_TEST"]}') -> 'rows') r), true, 'Xuất đánh dấu lịch nhắc tự sinh');
select ok(pg_temp.export_rows('APPOINTMENT') >= 7 + 7 + 1 + 1 + 1 + 1 + 1, 'Nhật ký xuất ghi mỗi lần xuất (ai, module, bộ lọc, số dòng)');
select pg_temp.sudo($$update app.setting_def set value = '3' where key = 'export_max_rows'$$);
select is((app.export_appointments('{}') ->> 'exported')::int, 3, 'Cắt ở export_max_rows');
select is((app.export_appointments('{}') ->> 'truncated')::boolean, true, 'Vượt export_max_rows thì báo truncated');
select is((app.export_appointments('{}') ->> 'total')::int, 7, 'Báo tổng số thật dù đã cắt');
select pg_temp.sudo($$update app.setting_def set value = '5000' where key = 'export_max_rows'$$);
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.export_appointments('{}') ->> 'exported')::int, 8, 'Admin xuất mọi cơ sở (7 ở CS1 và 1 ở CS5)');

-- ================= Giao việc hàng loạt (Đ33, Đ36, R-CRM-38) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.assign_appointments(array[pg_temp.aid('A1 lead một')], pg_temp.uid('sales1b'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không có quyền Giao việc cho lịch hẹn');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.assign_appointments(array[pg_temp.aid('A7 cơ sở 5')], pg_temp.uid('sales5'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không có quyền Giao việc');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.assign_appointments(array[]::uuid[], pg_temp.uid('sales1b'))$$), 'HMT_THIEU_THONG_TIN', 'Chặn: chưa chọn lịch hẹn nào');
select is(pg_temp.err($$select app.assign_appointments(array[pg_temp.aid('A1 lead một')], null)$$), 'HMT_THIEU_THONG_TIN', 'Chặn: chưa chọn người phụ trách mới');
select is(pg_temp.err($$select app.assign_appointments(array(select gen_random_uuid() from generate_series(1, 101)), pg_temp.uid('sales1b'))$$), 'HMT_QUA_NHIEU_BAN_GHI', 'Chặn: quá list_page_size_max lịch hẹn một lần');
-- Giao đúng: hai lịch Chưa làm của lead 1; người phụ trách của lead KHÔNG đổi.
select is((app.assign_appointments(array[pg_temp.aid('A1 lead một'), pg_temp.aid('A2 lead một'), pg_temp.aid('A1 lead một')], pg_temp.uid('sales1b')) ->> 'assigned')::int, 2, 'Giao hai lịch Chưa làm cho nhân sự cùng cơ sở (id trùng chỉ tính một lần)');
select is(pg_temp.owner_of('A1 lead một'), 'sales1b@ts.hoamatoan.invalid', 'Người phụ trách của lịch hẹn đã đổi');
select is((select u.login_name from app.lead l join app.user_account u on u.id = l.owner_id where l.code = 'LD000001'), 'sales1@ts.hoamatoan.invalid', 'KHÔNG đổi người phụ trách của lead mà lịch gắn vào');
select is(pg_temp.notes('LEAD', pg_temp.lid('LD000001')), 2, 'Mỗi lịch đã giao ghi một ghi chú hệ thống trên hồ sơ gắn');
select ok(pg_temp.audit_has('app.appointment', pg_temp.aid('A1 lead một'), '%owner_id%'), 'Nhật ký thao tác ghi việc đổi người phụ trách');
-- Lô chọn lẫn: giao phần hợp lệ, nêu lý do từng nhóm bị bỏ.
select pg_temp.sudo($$create temp table mixed (r jsonb)$$);
select pg_temp.sudo($$grant all on mixed to public$$);
select pg_temp.sudo($$insert into mixed select app.assign_appointments(array[
    (select id from app.appointment where title = 'A3 lead hai'),
    (select id from app.appointment where title = 'A5 sẽ hoàn thành'),
    (select id from app.appointment where title = 'A6 sẽ huỷ'),
    (select id from app.appointment where is_auto_reminder limit 1),
    (select id from app.appointment where title = 'A1 lead một'),
    (select id from app.appointment where title = 'A7 cơ sở 5')],
    (select id from app.user_account where login_name = 'sales1b@ts.hoamatoan.invalid'))$$);
select is((select (r ->> 'requested')::int from mixed), 6, 'Lô chọn lẫn: nêu số lịch hẹn đã chọn');
select is((select (r ->> 'assigned')::int from mixed), 1, 'Lô chọn lẫn: chỉ giao phần hợp lệ (1 lịch)');
select is((select (r ->> 'skipped')::int from mixed), 5, 'Lô chọn lẫn: nêu số bị bỏ (5 lịch)');
select is((select count(*)::int from mixed, jsonb_array_elements(r -> 'reasons')), 4, 'Lô chọn lẫn: bốn nhóm lý do (không im lặng bỏ dòng)');
select is((select (x ->> 'count')::int from mixed, jsonb_array_elements(r -> 'reasons') x where x ->> 'code' = 'HMT_LICH_HEN_TRANG_THAI_SAI'), 2, 'Lý do: lịch Hoàn thành và Huỷ không giao được (Đ33)');
select is((select (x ->> 'count')::int from mixed, jsonb_array_elements(r -> 'reasons') x where x ->> 'code' = 'HMT_LICH_NHAC_THEO_PHIEU'), 1, 'Lý do riêng: lịch nhắc tự sinh của phiếu không giao tay (Đ36)');
select is((select (x ->> 'count')::int from mixed, jsonb_array_elements(r -> 'reasons') x where x ->> 'code' = 'HMT_GIAO_CUNG_NGUOI'), 1, 'Lý do: lịch đã do người này phụ trách');
select is((select (x ->> 'count')::int from mixed, jsonb_array_elements(r -> 'reasons') x where x ->> 'code' = 'HMT_KHONG_TIM_THAY'), 1, 'Lý do: lịch ở cơ sở khác coi như không thấy');
select ok((select bool_and(coalesce(x ->> 'message', '') <> '' and jsonb_array_length(x -> 'ids') = (x ->> 'count')::int) from mixed, jsonb_array_elements(r -> 'reasons') x), 'Mỗi nhóm bị bỏ có câu tiếng Việt và danh sách id đúng số lượng');
select is(pg_temp.owner_of('A3 lead hai'), 'sales1b@ts.hoamatoan.invalid', 'Lịch hợp lệ trong lô chọn lẫn đã được giao');
select is(pg_temp.owner_of('A5 sẽ hoàn thành'), 'sales1@ts.hoamatoan.invalid', 'Lịch Hoàn thành giữ nguyên người phụ trách');
select is((select u.login_name from app.appointment a join app.user_account u on u.id = a.owner_id where a.is_auto_reminder), 'sales1@ts.hoamatoan.invalid', 'Lịch nhắc tự sinh vẫn theo người phụ trách phiếu (không bị giao tay)');
select is(pg_temp.owner_of('A7 cơ sở 5'), 'sales5@ts.hoamatoan.invalid', 'Lịch ở cơ sở khác không bị đổi');
-- Người nhận sai cơ sở: không giao, nêu lý do; không đổi người phụ trách của cơ hội.
select is((app.assign_appointments(array[pg_temp.aid('A4 cơ hội')], pg_temp.uid('sales5')) ->> 'assigned')::int, 0, 'Người nhận thuộc cơ sở khác: không giao được lịch nào');
select is((app.assign_appointments(array[pg_temp.aid('A4 cơ hội')], pg_temp.uid('sales5')) -> 'reasons' -> 0 ->> 'code'), 'HMT_NGUOI_PHU_TRACH_SAI', 'Lý do: người phụ trách phải thuộc đúng cơ sở của lịch hẹn');
select is((select u.login_name from app.opportunity o join app.user_account u on u.id = o.owner_id where o.code = 'CO000001'), 'sales1@ts.hoamatoan.invalid', 'Giao lịch của cơ hội không đổi người phụ trách cơ hội');
-- Trưởng cơ sở không giao lịch ở cơ sở khác dù biết id.
select is((app.assign_appointments(array[pg_temp.aid('A7 cơ sở 5')], pg_temp.uid('sales5b')) -> 'reasons' -> 0 ->> 'code'), 'HMT_KHONG_TIM_THAY', 'Trưởng cơ sở CS1 không giao được lịch hẹn của CS5');
-- Admin giao được ở mọi cơ sở.
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.assign_appointments(array[pg_temp.aid('A7 cơ sở 5')], pg_temp.uid('sales5b')) ->> 'assigned')::int, 1, 'Admin giao được lịch hẹn ở cơ sở khác');
select is(pg_temp.owner_of('A7 cơ sở 5'), 'sales5b@ts.hoamatoan.invalid', 'Người phụ trách lịch hẹn CS5 đã đổi bởi Admin');

-- ================= Dời lịch hẹn: lịch nhắc tự sinh không đổi người phụ trách (Đ37, R-CRM-38) =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.sudo($$create function pg_temp.auto_id() returns uuid language sql stable security definer as 'select id from app.appointment where is_auto_reminder'$$);
select pg_temp.sudo($$grant execute on function pg_temp.auto_id() to public$$);
select is(pg_temp.err($$select app.reschedule_appointment(pg_temp.auto_id(), now() + interval '9 days', pg_temp.uid('sales1b'))$$), 'HMT_LICH_NHAC_THEO_PHIEU', 'Đ37: Trưởng cơ sở có quyền Giao việc vẫn không đổi được người phụ trách của lịch nhắc tự sinh khi Dời');
select is(pg_temp.msg($$select app.reschedule_appointment(pg_temp.auto_id(), now() + interval '9 days', pg_temp.uid('sales1b'))$$), 'Lịch nhắc tự sinh của phiếu kiểm tra đi theo người phụ trách phiếu: đổi người phụ trách ở phiếu, không đổi ở lịch nhắc.', 'Đ37: câu tiếng Việt cho giao diện hiện thẳng');
select is((select u.login_name from app.appointment a join app.user_account u on u.id = a.owner_id where a.is_auto_reminder), 'sales1@ts.hoamatoan.invalid', 'Bị chặn thì lịch nhắc không đổi người phụ trách');
select is((select scheduled_at > now() + interval '8 days' and scheduled_at < now() + interval '10 days' from app.appointment where is_auto_reminder), false, 'Bị chặn thì cũng không dời giờ (cả lần gọi bị huỷ)');
select is(pg_temp.err($$select app.reschedule_appointment(pg_temp.auto_id(), now() + interval '9 days')$$), null, 'Đ37: dời giờ lịch nhắc tự sinh vẫn được (không đổi người phụ trách)');
select is((select scheduled_at > now() + interval '8 days' and scheduled_at < now() + interval '10 days' from app.appointment where is_auto_reminder), true, 'Giờ của lịch nhắc đã dời');
select is(pg_temp.err($$select app.reschedule_appointment(pg_temp.auto_id(), now() + interval '9 days', pg_temp.uid('sales1'), 'Ghi chú dời')$$), null, 'Đ37: truyền chính người phụ trách hiện tại thì không phải đổi người, dời giờ và ghi chú được');
select is(pg_temp.err($$select app.reschedule_appointment(pg_temp.aid('A4 cơ hội'), now() + interval '10 days', pg_temp.uid('sales1b'))$$), null, 'Lịch hẹn thường vẫn đổi được người phụ trách khi Dời (R-CRM-38 b)');
select is(pg_temp.owner_of('A4 cơ hội'), 'sales1b@ts.hoamatoan.invalid', 'Lịch hẹn thường đã đổi người phụ trách qua Dời');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.reschedule_appointment(pg_temp.auto_id(), now() + interval '9 days', pg_temp.uid('sales1b'))$$), 'HMT_LICH_NHAC_THEO_PHIEU', 'Đ37: Admin cũng không đổi tay người phụ trách lịch nhắc tự sinh');

select * from finish();
rollback;
