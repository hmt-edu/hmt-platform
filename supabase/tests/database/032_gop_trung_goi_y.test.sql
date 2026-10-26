-- P3f-1: gợi ý bản trùng (merge_candidates) và xem trước gộp có so sánh, danh sách mục chuyển (merge_preview),
-- tham số merge_preview_max_items (docs/spec/04 R-CRM-22, 37). Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò thử trong và ngoài cơ sở.
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
select pg_temp.sudo($$create function pg_temp.test_data(p_extra jsonb default '{}'::jsonb) returns jsonb language sql stable as
  'select jsonb_build_object(''subject_code'', ''TOAN'', ''grade_code'', (select code from app.catalog_item where catalog_code = ''GRADE'' order by sort_order limit 1),
     ''mode_code'', ''OFFLINE'', ''level_code'', ''CO_BAN'', ''scheduled_at'', now() + interval ''3 days'') || p_extra'$$);
select pg_temp.sudo($$grant execute on function pg_temp.test_data(jsonb) to public$$);
select pg_temp.sudo($$create function pg_temp.oid(p_code text) returns uuid language sql stable security definer as 'select id from app.opportunity where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.lid(p_code text) returns uuid language sql stable security definer as 'select id from app.lead where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.lid(text) to public$$);

select pg_temp.sudo($$create function pg_temp.notes(p_type text, p_id uuid) returns integer language sql stable security definer as 'select count(*)::integer from app.note where entity_type = p_type and entity_id = p_id'$$);
select pg_temp.sudo($$grant execute on function pg_temp.notes(text, uuid) to public$$);
select pg_temp.sudo($$create function pg_temp.cands(p_entity text, p_id uuid) returns jsonb language plpgsql as 'begin return coalesce((select jsonb_agg(to_jsonb(c) order by c.code) from app.merge_candidates(p_entity, p_id) c), ''[]''::jsonb); end'$$);
select pg_temp.sudo($$grant execute on function pg_temp.cands(text, uuid) to public$$);

-- ================= Dựng dữ liệu =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900000601', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900000601', '{"student_name": "Em Một", "student_birth_year": 2012}'), true);
select app.create_lead(pg_temp.lead_data('0900000601', '{"student_name": "Em Khác", "student_birth_year": 2013}'), true);
select app.create_lead(pg_temp.lead_data('0900000602', '{"student_name": "Em Hai", "student_birth_year": 2011}'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900000601', '{"student_name": "Em Một", "student_birth_year": 2012}'), true);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
-- Lead: LD000001, 2 (Em Một, 0601, CS1), LD000003 (Em Khác, 0601, CS1), LD000004 (0602), LD000005 (Em Một, 0601, CS5).
select app.create_appointment(pg_temp.lid('LD000002'), 'GOI_DIEN', now() + interval '1 day', 'Hẹn lead 2');
select pg_temp.sudo($$insert into app.note (entity_type, entity_id, body, created_at) values
  ('LEAD', (select id from app.lead where code = 'LD000002'), 'Ghi chú một của lead 2', now() - interval '2 hours'),
  ('LEAD', (select id from app.lead where code = 'LD000002'), 'Ghi chú hai của lead 2', now() - interval '1 hour')$$);
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000001'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000002'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000003'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000005'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
-- Cơ hội: CO000001 (Em Một), CO000002 (Em Một), CO000003 (Em Khác), CO000004 (Em Một, CS5).

-- ================= Tham số =================
select is((select array[value_type, unit, min_value::text, max_value::text, value] from app.setting_def where key = 'merge_preview_max_items'),
          array['INT', 'mục', '5', '100', '20'], 'Tham số merge_preview_max_items: kiểu, đơn vị, min 5, max 100, mặc định 20');

-- ================= Gợi ý lead (R-CRM-22) =================
select is(pg_temp.cands('LEAD', pg_temp.lid('LD000001')) -> 0 ->> 'code', 'LD000002', 'Gợi ý lead: bản cùng SĐT cùng cơ sở hiện ra');
select is(jsonb_array_length(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))), 2, 'Gợi ý lead: chỉ hai bản cùng SĐT trong cơ sở mình (LD000002, LD000003), không có bản khác SĐT');
select is((pg_temp.cands('LEAD', pg_temp.lid('LD000001')) -> 0 ->> 'can_merge')::boolean, true, 'Gợi ý lead: cùng cơ sở thì gộp được (can_merge)');
select is(pg_temp.cands('LEAD', pg_temp.lid('LD000001')) -> 0 ->> 'label', 'Chị Thử Một · Em Một', 'Gợi ý lead: nhãn có tên phụ huynh và học sinh');
select is((select count(*)::int from jsonb_array_elements(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))) e where e ->> 'code' = 'LD000005'), 0,
          'Phạm vi xem: Tuyển sinh CS1 không thấy lead cùng SĐT ở CS5 (không lộ tên, SĐT)');
select is((select count(*)::int from jsonb_array_elements(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))) e where e ->> 'code' = 'LD000001'), 0, 'Gợi ý không gồm chính hồ sơ đang mở');
select is(pg_temp.err($$select * from app.merge_candidates('LEAD', pg_temp.lid('LD000005'))$$), 'HMT_KHONG_TIM_THAY', 'Mở gợi ý cho hồ sơ ở cơ sở khác: coi như không có, không lộ sự tồn tại');
select is(pg_temp.err($$select * from app.merge_candidates('LEAD', gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Chặn: hồ sơ không có');
select is(pg_temp.err($$select * from app.merge_candidates('XX', pg_temp.lid('LD000001'))$$), 'HMT_LOAI_BAN_GHI_SAI', 'Chặn: loại bản ghi lạ (chỉ lead, cơ hội)');
select is(pg_temp.err($$select * from app.merge_candidates('PARENT', gen_random_uuid())$$), 'HMT_LOAI_BAN_GHI_SAI', 'Chặn: phụ huynh chưa gợi ý trong P3f (QĐ-P3f-1)');

select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(jsonb_array_length(pg_temp.cands('LEAD', pg_temp.lid('LD000005'))), 0,
          'Phạm vi xem: Tuyển sinh CS5 gọi với SĐT có ở lead CS1 thì không thấy dòng nào');
select is(pg_temp.err($$select * from app.merge_candidates('LEAD', pg_temp.lid('LD000001'))$$), 'HMT_KHONG_TIM_THAY', 'Tuyển sinh CS5 mở gợi ý cho lead CS1: không có');

select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select * from app.merge_candidates('LEAD', pg_temp.lid('LD000005'))$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không có quyền gộp: gợi ý bị chặn');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select * from app.merge_candidates('LEAD', pg_temp.lid('LD000005'))$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không có quyền gộp: gợi ý bị chặn');

select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(jsonb_array_length(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))), 2, 'CSKH (có quyền Duyệt) cũng thấy gợi ý trong cơ sở mình');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(jsonb_array_length(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))), 2, 'Trưởng cơ sở thấy gợi ý trong cơ sở mình');

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(jsonb_array_length(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))), 3, 'Admin thấy cả bản ở cơ sở khác (LD000005)');
select is((select (e ->> 'can_merge')::boolean from jsonb_array_elements(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))) e where e ->> 'code' = 'LD000005'), true,
          'Admin gộp được hai lead khác cơ sở (R-CRM-22): can_merge đúng');
select is((select e ->> 'branch_code' from jsonb_array_elements(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))) e where e ->> 'code' = 'LD000005'), 'CS5', 'Dòng gợi ý nêu mã cơ sở');

-- ================= Gợi ý cơ hội (R-CRM-22, 37a) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((select array_agg(e ->> 'code' order by e ->> 'code') from jsonb_array_elements(pg_temp.cands('OPPORTUNITY', pg_temp.oid('CO000001'))) e),
          array['CO000002', 'CO000003'], 'Gợi ý cơ hội: cùng phụ huynh trong cơ sở mình, không thấy cơ hội CS5');
select is((select (e ->> 'can_merge')::boolean from jsonb_array_elements(pg_temp.cands('OPPORTUNITY', pg_temp.oid('CO000001'))) e where e ->> 'code' = 'CO000002'), true,
          'Cơ hội cùng phụ huynh, cùng học sinh: gộp được');
select is((select array[e ->> 'can_merge', e ->> 'blocker_code'] from jsonb_array_elements(pg_temp.cands('OPPORTUNITY', pg_temp.oid('CO000001'))) e where e ->> 'code' = 'CO000003'),
          array['false', 'HMT_GOP_KHAC_HOC_SINH'], 'R-CRM-37a: khác học sinh thì không gộp được, mã HMT_GOP_KHAC_HOC_SINH');
select is((select e ->> 'blocker_message' from jsonb_array_elements(pg_temp.cands('OPPORTUNITY', pg_temp.oid('CO000001'))) e where e ->> 'code' = 'CO000003'),
          'Hai cơ hội khác học sinh: gộp học sinh trước.', 'Câu tiếng Việt của mã chặn khác học sinh');
select is(pg_temp.err($$select * from app.merge_candidates('OPPORTUNITY', pg_temp.oid('CO000004'))$$), 'HMT_KHONG_TIM_THAY', 'Cơ hội ở cơ sở khác: Tuyển sinh CS1 không mở được gợi ý');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(jsonb_array_length(pg_temp.cands('OPPORTUNITY', pg_temp.oid('CO000004'))), 0, 'Tuyển sinh CS5: cơ hội cùng phụ huynh ở CS1 không hiện');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((select (e ->> 'can_merge')::boolean from jsonb_array_elements(pg_temp.cands('OPPORTUNITY', pg_temp.oid('CO000001'))) e where e ->> 'code' = 'CO000004'), true,
          'Admin thấy cơ hội CS5 cùng phụ huynh, cùng học sinh: gộp được');

-- ================= Xem trước: so sánh và danh sách mục chuyển =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002')) -> 'sides' -> 'keep' ->> 'code') || '/' || (app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002')) -> 'sides' -> 'merge' ->> 'code'),
          'LD000001/LD000002', 'Xem trước lead: so sánh nêu mã hai bên');
select is(app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002')) -> 'sides' -> 'merge' ->> 'phone', '0900000601', 'Xem trước lead: bên so sánh có SĐT');
select is(jsonb_array_length(app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002')) -> 'items' -> 'appointments'), 1, 'Xem trước lead: liệt kê đúng một lịch hẹn sẽ chuyển');
select is(app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002')) -> 'items' -> 'appointments' -> 0 ->> 'title', 'Hẹn lead 2', 'Xem trước lead: lịch hẹn nêu tiêu đề');
select is(jsonb_array_length(app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002')) -> 'items' -> 'notes'), 2, 'Xem trước lead: liệt kê đúng hai ghi chú sẽ chuyển');
select is((select array_agg(e ->> 'body' order by e ->> 'body') from jsonb_array_elements(app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002')) -> 'items' -> 'notes') e), array['Ghi chú hai của lead 2', 'Ghi chú một của lead 2'], 'Xem trước lead: ghi chú nêu nội dung');
select is(app.merge_preview('OPPORTUNITY', pg_temp.oid('CO000001'), pg_temp.oid('CO000002')) -> 'sides' -> 'merge' ->> 'stage_code', 'L1', 'Xem trước cơ hội: bên so sánh có giai đoạn');
select ok(app.merge_preview('OPPORTUNITY', pg_temp.oid('CO000001'), pg_temp.oid('CO000002')) ? 'items', 'Xem trước cơ hội có danh sách mục chuyển');

-- Tham số giới hạn số mục: số thật vẫn nằm ở move.
select pg_temp.sudo($$insert into app.note (entity_type, entity_id, body, created_at)
  select 'LEAD', (select id from app.lead where code = 'LD000002'), 'Ghi chú thêm ' || g, now() - interval '30 minutes' + g * interval '1 minute' from generate_series(1, 6) g$$);
select pg_temp.sudo($$update app.setting_def set value = '5' where key = 'merge_preview_max_items'$$);
select is(jsonb_array_length(app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002')) -> 'items' -> 'notes'), 5, 'Tham số merge_preview_max_items cắt danh sách ghi chú ở 5 mục');
select is((app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002')) -> 'move' ->> 'notes')::int, 8, 'Số ghi chú sẽ chuyển (move) vẫn là số thật, không bị cắt');
select is(jsonb_array_length(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))), 2, 'Số dòng gợi ý còn trong giới hạn');
select pg_temp.sudo($$update app.setting_def set value = '20' where key = 'merge_preview_max_items'$$);

-- Xem trước không ghi gì.
select is((select record_status from app.lead where code = 'LD000002'), 'DANG_DUNG', 'Xem trước không gộp gì (bản bị gộp vẫn đang dùng)');
select is(pg_temp.notes('LEAD', pg_temp.lid('LD000002')), 8, 'Xem trước không chuyển ghi chú');
-- Quyền xem trước giữ như gộp thật.
select is(pg_temp.err($$select app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000005'))$$), 'HMT_GOP_KHAC_CO_SO', 'Xem trước vẫn chặn hai lead khác cơ sở với Tuyển sinh');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002'))$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không xem trước gộp được');

-- ================= Người xem nhiều cơ sở mà không phải Admin (R-CRM-22: HMT_GOP_KHAC_CO_SO) =================
-- Cấp TẠM quyền Xem toàn hệ thống cho vai trò Tuyển sinh (Duyệt vẫn trong cơ sở mình), trong giao dịch này; cuối bài rollback.
-- Không thêm vai trò vào ma trận quyền.
select pg_temp.sudo($$update app.permission set scope_code = 'TOAN_HE_THONG' where role_code = 'SALES' and module_code = 'LEAD' and action_code = 'XEM'$$);
select pg_temp.sudo($$update app.permission set scope_code = 'TOAN_HE_THONG' where role_code = 'SALES' and module_code = 'OPPORTUNITY' and action_code = 'XEM'$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((select (e ->> 'can_merge')::boolean from jsonb_array_elements(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))) e where e ->> 'code' = 'LD000005'), false,
          'Xem được nhiều cơ sở nhưng không phải Admin: lead cơ sở khác hiện ra, không gộp được');
select is((select e ->> 'blocker_code' from jsonb_array_elements(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))) e where e ->> 'code' = 'LD000005'), 'HMT_GOP_KHAC_CO_SO',
          'R-CRM-22: lead khác cơ sở, người không phải Admin: mã HMT_GOP_KHAC_CO_SO');
select is((select e ->> 'blocker_message' from jsonb_array_elements(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))) e where e ->> 'code' = 'LD000005'),
          'Hai hồ sơ thuộc hai cơ sở khác nhau: chỉ Admin gộp được.', 'Câu tiếng Việt của HMT_GOP_KHAC_CO_SO');
select is((select e ->> 'blocker_code' from jsonb_array_elements(pg_temp.cands('OPPORTUNITY', pg_temp.oid('CO000001'))) e where e ->> 'code' = 'CO000004'), 'HMT_GOP_KHAC_CO_SO',
          'R-CRM-22: cơ hội khác cơ sở, người không phải Admin: mã HMT_GOP_KHAC_CO_SO (xét trước điều kiện học sinh)');
select is((select (e ->> 'can_merge')::boolean from jsonb_array_elements(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))) e where e ->> 'code' = 'LD000002'), true,
          'Cùng cơ sở mình vẫn gộp được khi xem được nhiều cơ sở');
select is(pg_temp.err($$select app.merge_leads(pg_temp.lid('LD000001'), pg_temp.lid('LD000005'), true)$$), 'HMT_GOP_KHAC_CO_SO',
          'Gợi ý khớp hàm gộp thật: gộp hai lead khác cơ sở vẫn bị chặn');

-- ================= Sau khi gộp =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.merge_leads(pg_temp.lid('LD000001'), pg_temp.lid('LD000002'), true);
select is(pg_temp.err($$select * from app.merge_candidates('LEAD', pg_temp.lid('LD000002'))$$), 'HMT_BAN_GHI_DA_GOP', 'Hồ sơ đã gộp: không gợi ý tiếp');
select is((select count(*)::int from jsonb_array_elements(pg_temp.cands('LEAD', pg_temp.lid('LD000001'))) e where e ->> 'code' = 'LD000002'), 0, 'Bản đã gộp không còn trong gợi ý của bản khác');

select * from finish();
rollback;
