-- P3b3a: gộp trùng lead, cơ hội, học sinh, phụ huynh (docs/spec/04 R-CRM-22, 25, 37; anh chốt 18/10).
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò gộp trong và ngoài cơ sở.
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
select pg_temp.sudo($$create function pg_temp.audit_has(p_table text, p_id uuid, p_like text) returns boolean language sql stable security definer as
  'select exists (select from app.audit_log a join app.audited_table t on t.id = a.table_id where t.table_name = p_table and a.record_id = p_id and a.action = ''U'' and a.changes::text like p_like)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.audit_has(text, uuid, text) to public$$);
select pg_temp.sudo($$create function pg_temp.notes(p_type text, p_id uuid) returns integer language sql stable security definer as 'select count(*)::integer from app.note where entity_type = p_type and entity_id = p_id'$$);
select pg_temp.sudo($$grant execute on function pg_temp.notes(text, uuid) to public$$);
select pg_temp.sudo($$create function pg_temp.sysnotes(p_type text, p_id uuid) returns integer language sql stable security definer as 'select count(*)::integer from app.note where entity_type = p_type and entity_id = p_id and body like ''Hệ thống: đã gộp%'''$$);
select pg_temp.sudo($$grant execute on function pg_temp.sysnotes(text, uuid) to public$$);
select pg_temp.sudo($s$create function pg_temp.docs_stub(p_codes text) returns void language plpgsql security definer as $b$
begin
  execute format('create or replace function app.opportunity_sales_documents(p_opportunity_id uuid) returns text[] language sql stable set search_path = '''' as $f$select array[%s]::text[]$f$', p_codes);
end
$b$$s$);
select pg_temp.sudo($$grant execute on function pg_temp.docs_stub(text) to public$$);
select pg_temp.sudo($$create function pg_temp.fp(p_phone text) returns uuid language sql security definer as 'select app.find_or_create_parent(p_phone, ''X'', null, null, null, (select id from app.branch where code = ''CS1''))'$$);
select pg_temp.sudo($$grant execute on function pg_temp.fp(text) to public$$);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900000401', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900000401', '{"student_name": "Em Một", "student_birth_year": 2012}'), true);
select app.create_lead(pg_temp.lead_data('0900000401', '{"student_name": "Em Khác", "student_birth_year": 2013}'), true);
select app.create_lead(pg_temp.lead_data('0900000402', '{"student_name": "Em Hai", "student_birth_year": 2011}'));
select app.create_lead(pg_temp.lead_data('0900000403', '{"student_name": null, "student_birth_year": null}'));
select app.create_lead(pg_temp.lead_data('0900000403', '{"student_name": "Em Ba", "student_birth_year": 2010}'), true);
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900000499', '{"student_name": "Em Chín", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900000498', '{"student_name": "Em Tám", "student_birth_year": 2012}'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
-- Lead: LD000001, 2, 3 (cùng SĐT 0401), LD000004 (0402), LD000005, 6 (0403), LD000007, 8 (CS5).
select app.create_appointment(pg_temp.lid('LD000001'), 'GOI_DIEN', now() + interval '3 days', 'Hẹn lead 1');
select app.create_appointment(pg_temp.lid('LD000002'), 'GOI_DIEN', now() + interval '1 day', 'Hẹn lead 2');
select pg_temp.sudo($$insert into app.note (entity_type, entity_id, body) values ('LEAD', (select id from app.lead where code = 'LD000002'), 'Ghi chú của lead 2'), ('LEAD', (select id from app.lead where code = 'LD000002'), 'Ghi chú thứ hai')$$);
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000001'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000002'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000003'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000004'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000005'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000006'));
-- CO000001, 2 (Em Một, 0401), CO000003 (Em Khác, 0401), CO000004 (Em Hai, 0402), CO000005 (không học sinh, 0403), CO000006 (Em Ba, 0403).
select app.create_appointment(null, 'GOI_DIEN', now() + interval '2 days', 'Hẹn cơ hội 2', null, null, pg_temp.oid('CO000002'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000007'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= Dùng chung: xem trước, quyền, xác nhận =================
select is(pg_temp.err($$select app.merge_preview('XX', pg_temp.lid('LD000001'), pg_temp.lid('LD000002'))$$), 'HMT_LOAI_BAN_GHI_SAI', 'Loại bản ghi lạ bị chặn');
select is(pg_temp.err($$select app.merge_preview('LEAD', null, pg_temp.lid('LD000002'))$$), 'HMT_THIEU_THONG_TIN', 'Phải chọn đủ hai hồ sơ');
select is(pg_temp.err($$select app.merge_leads(pg_temp.lid('LD000001'), pg_temp.lid('LD000001'), true)$$), 'HMT_GOP_CUNG_BAN_GHI', 'Chặn: gộp hồ sơ vào chính nó');
select is(pg_temp.err($$select app.merge_leads(pg_temp.lid('LD000001'), gen_random_uuid(), true)$$), 'HMT_KHONG_TIM_THAY', 'Chặn: hồ sơ không có');
select is(pg_temp.err($$select app.merge_leads(pg_temp.lid('LD000001'), pg_temp.lid('LD000007'), true)$$), 'HMT_GOP_KHAC_CO_SO', 'R-CRM-22: hai lead khác cơ sở, Tuyển sinh không gộp được');
select is(pg_temp.err($$select app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000007'))$$), 'HMT_GOP_KHAC_CO_SO', 'Xem trước cũng kiểm quyền như gộp thật');
select is(pg_temp.err($$select app.merge_leads(pg_temp.lid('LD000001'), pg_temp.lid('LD000002'))$$), 'HMT_CAN_XAC_NHAN', 'Gộp không hoàn tác: thiếu xác nhận thì chặn');
select is((select record_status from app.lead where code = 'LD000002'), 'DANG_DUNG', 'Chưa xác nhận thì chưa gộp gì');
select is((app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002')) -> 'move'),
          '{"notes": 2, "appointments": 1, "opportunities": 1}'::jsonb, 'Xem trước lead: số lịch hẹn, ghi chú, cơ hội sẽ chuyển');
select is((app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002')) ->> 'keep_code') || '/' || (app.merge_preview('LEAD', pg_temp.lid('LD000001'), pg_temp.lid('LD000002')) ->> 'merge_code'),
          'LD000001/LD000002', 'Xem trước nêu mã hai bên');

-- ================= Gộp lead (R-CRM-22) =================
select is(pg_temp.err($$select app.merge_leads(pg_temp.lid('LD000001'), pg_temp.lid('LD000002'), true)$$), null, 'Gộp lead: Tuyển sinh gộp hai lead cùng cơ sở được');
select is((select array[record_status, (select code from app.lead k where k.id = l.merged_into_id)] from app.lead l where l.code = 'LD000002'),
          array['DA_GOP', 'LD000001'], 'Bản bị gộp thành "Đã gộp", ghi gộp vào LD000001');
select is((select count(*)::int from app.appointment where lead_id = pg_temp.lid('LD000001')), 2, 'Lịch hẹn của bản bị gộp chuyển sang bản giữ lại');
select is((select count(*)::int from app.appointment where lead_id = pg_temp.lid('LD000002')), 0, 'Bản bị gộp không còn lịch hẹn');
select is((select next_appointment_at from app.lead where code = 'LD000001'), (select min(scheduled_at) from app.appointment where lead_id = pg_temp.lid('LD000001') and status = 'CHUA_LAM'),
          '"Lịch hẹn kế tiếp" của bản giữ lại tính lại sau khi chuyển');
select is((select next_appointment_at from app.lead where code = 'LD000002'), null, '"Lịch hẹn kế tiếp" của bản bị gộp trống');
select is(pg_temp.notes('LEAD', pg_temp.lid('LD000001')) - pg_temp.sysnotes('LEAD', pg_temp.lid('LD000001')), 2, 'Ghi chú của bản bị gộp chuyển sang bản giữ lại');
select is(pg_temp.notes('LEAD', pg_temp.lid('LD000002')) - pg_temp.sysnotes('LEAD', pg_temp.lid('LD000002')), 0, 'Bản bị gộp không còn ghi chú thường');
select is(pg_temp.sysnotes('LEAD', pg_temp.lid('LD000001')) + pg_temp.sysnotes('LEAD', pg_temp.lid('LD000002')), 2, 'Ghi chú hệ thống "Đã gộp…" có trên cả hai bản');
select is((select count(*)::int from app.note where entity_type = 'LEAD' and entity_id = pg_temp.lid('LD000002') and body like 'Hệ thống: đã gộp vào LD000001%'), 1, 'Ghi chú trên bản bị gộp nêu mã bản giữ lại');
select is((select lead_id from app.opportunity where code = 'CO000002'), pg_temp.lid('LD000001'), 'Cơ hội của lead bị gộp chuyển sang lead giữ lại');
select ok(pg_temp.audit_has('app.lead', pg_temp.lid('LD000002'), '%DA_GOP%'), 'Lịch sử (nhật ký) ghi việc gộp ở bản bị gộp');
select is(pg_temp.err($$select app.update_lead(pg_temp.lid('LD000002'), '{"need": "x"}')$$), 'HMT_BAN_GHI_DA_GOP', 'Bản đã gộp chỉ đọc: sửa bị chặn');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('LD000002'), 'C2')$$), 'HMT_BAN_GHI_DA_GOP', 'Bản đã gộp chỉ đọc: đổi giai đoạn bị chặn');
select is(pg_temp.err($$select app.create_appointment(pg_temp.lid('LD000002'), 'GOI_DIEN', now() + interval '9 days', 'x')$$), 'HMT_BAN_GHI_DA_GOP', 'Bản đã gộp: không thêm lịch hẹn');
select is(pg_temp.err($$select app.merge_leads(pg_temp.lid('LD000003'), pg_temp.lid('LD000002'), true)$$), 'HMT_BAN_GHI_DA_GOP', 'Không gộp lại bản đã gộp');
select is((app.list_leads('{}') ->> 'total')::int, (select count(*)::int from app.lead where record_status = 'DANG_DUNG' and branch_id = (select id from app.branch where code = 'CS1')), 'Danh sách mặc định ẩn bản đã gộp');
select is((app.list_leads('{"q": "LD000002"}') ->> 'total')::int, 1, 'Bản đã gộp vẫn tìm được bằng mã');
select is((app.list_leads('{"q": "ld000002"}') ->> 'total')::int, 1, 'Tìm bằng mã không phân biệt hoa thường');
select is((app.list_leads('{"include_merged": true}') ->> 'total')::int, (select count(*)::int from app.lead where branch_id = (select id from app.branch where code = 'CS1')), 'Bật hiện bản đã gộp thì thấy đủ');
select is(pg_temp.err($$select app.merge_leads(pg_temp.lid('LD000003'), pg_temp.lid('LD000001'), true)$$), null, 'Gộp tiếp: LD000001 vào LD000003');
select is((select array_agg((select code from app.lead k where k.id = l.merged_into_id) order by l.code) from app.lead l where l.code in ('LD000001', 'LD000002')),
          array['LD000003', 'LD000003'], 'Chuỗi gộp được làm phẳng: LD000002 cũng trỏ thẳng về LD000003');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.merge_leads(pg_temp.lid('LD000007'), pg_temp.lid('LD000008'), true)$$), null, 'Tuyển sinh CS5 gộp hai lead cơ sở mình được');
select is(pg_temp.err($$select app.merge_leads(pg_temp.lid('LD000003'), pg_temp.lid('LD000004'), true)$$), 'HMT_KHONG_CO_QUYEN', 'Tuyển sinh CS5 không gộp hai lead của cơ sở khác');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.merge_leads(pg_temp.lid('LD000003'), pg_temp.lid('LD000004'), true)$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không gộp');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.merge_preview('LEAD', pg_temp.lid('LD000003'), pg_temp.lid('LD000004'))$$), null, 'CSKH có quyền Duyệt: xem trước được');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= Gộp cơ hội (R-CRM-22, 37a) =================
select is((app.merge_preview('OPPORTUNITY', pg_temp.oid('CO000001'), pg_temp.oid('CO000002')) -> 'blockers')::text, '[]', 'Hai cơ hội cùng phụ huynh, cùng học sinh: không có điều kiện chặn');
select is(pg_temp.err($$select app.merge_opportunities(pg_temp.oid('CO000001'), pg_temp.oid('CO000003'), true)$$), 'HMT_GOP_KHAC_HOC_SINH', 'R-CRM-37(a): cùng phụ huynh nhưng khác học sinh thì gộp học sinh trước');
select is(pg_temp.err($$select app.merge_opportunities(pg_temp.oid('CO000001'), pg_temp.oid('CO000004'), true)$$), 'HMT_GOP_KHAC_PHU_HUYNH', 'R-CRM-37(a): khác phụ huynh thì gộp phụ huynh trước');
select is(jsonb_array_length(app.merge_preview('OPPORTUNITY', pg_temp.oid('CO000001'), pg_temp.oid('CO000004')) -> 'blockers'), 2, 'Xem trước nêu đủ điều kiện chặn (khác phụ huynh và khác học sinh)');
select is(pg_temp.err($$select app.merge_opportunities(pg_temp.oid('CO000001'), pg_temp.oid('CO000002'))$$), 'HMT_CAN_XAC_NHAN', 'Gộp cơ hội cũng cần xác nhận');
select pg_temp.docs_stub($$'BG000001', 'DH000002'$$);
select is(pg_temp.err($$select app.merge_opportunities(pg_temp.oid('CO000001'), pg_temp.oid('CO000002'), true)$$), 'HMT_GOP_CO_BAO_GIA_DON', 'R-CRM-22: bản bị gộp đã có báo giá hoặc đơn thì chặn');
select ok(pg_temp.msg($$select app.merge_opportunities(pg_temp.oid('CO000001'), pg_temp.oid('CO000002'), true)$$) like '%BG000001%DH000002%', 'Câu lỗi nêu rõ mã báo giá, đơn');
select is((app.merge_preview('OPPORTUNITY', pg_temp.oid('CO000001'), pg_temp.oid('CO000002')) -> 'blockers' -> 0 ->> 'code'), 'HMT_GOP_CO_BAO_GIA_DON', 'Xem trước nêu điều kiện chặn báo giá, đơn');
select pg_temp.docs_stub('');
select is(pg_temp.err($$select app.merge_opportunities(pg_temp.oid('CO000006'), pg_temp.oid('CO000005'), true)$$), null,
          'R-CRM-37(a): bên bị gộp chưa có học sinh: gộp được, bản giữ lại giữ học sinh của mình');
select is((select record_status from app.opportunity where code = 'CO000005'), 'DA_GOP', 'CO000005 thành Đã gộp');
select app.create_lead(pg_temp.lead_data('0900000404', '{"student_name": null, "student_birth_year": null}'));
select app.create_lead(pg_temp.lead_data('0900000404', '{"student_name": "Em Lấy", "student_birth_year": 2012, "school": "THCS Lấy"}'), true);
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000009'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('LD000010'));
select app.change_opportunity_stage(pg_temp.oid('CO000009'), 'L4');
select is((app.merge_preview('OPPORTUNITY', pg_temp.oid('CO000008'), pg_temp.oid('CO000009')) -> 'warnings' -> 0 ->> 'code'), 'HMT_GOP_GIAI_DOAN_CAO_HON',
          'Cảnh báo: bản bị gộp (L4) ở giai đoạn cao hơn bản giữ lại (L1)');
select ok((app.merge_preview('OPPORTUNITY', pg_temp.oid('CO000008'), pg_temp.oid('CO000009')) -> 'warnings' -> 0 ->> 'message') ~ 'CO000009.*L4.*CO000008.*L1', 'Cảnh báo nêu mã và giai đoạn hai bên');
select is((app.merge_preview('OPPORTUNITY', pg_temp.oid('CO000009'), pg_temp.oid('CO000008')) -> 'warnings')::text, '[]', 'Giữ bản ở giai đoạn cao hơn thì không cảnh báo');
select is(pg_temp.err($$select app.merge_opportunities(pg_temp.oid('CO000008'), pg_temp.oid('CO000009'), true)$$), null, 'Gộp cơ hội: được (CO000008 giữ lại, chưa có học sinh)');
select is((select array[o.stage_code, ps.full_name, ps.birth_year::text, ps.school] from app.prospect_student ps join app.opportunity o on o.id = ps.opportunity_id where o.code = 'CO000008' and ps.position = 1),
          array['L1', 'Em Lấy', '2012', 'THCS Lấy'], 'R-CRM-37(a): bản giữ lại chưa có học sinh thì lấy của bên kia; giai đoạn giữ nguyên L1 (R-CRM-02)');
select pg_temp.sudo($$insert into app.note (entity_type, entity_id, body) values ('OPPORTUNITY', (select id from app.opportunity where code = 'CO000002'), 'Ghi chú cơ hội 2')$$);
select app.change_opportunity_stage(pg_temp.oid('CO000001'), 'L5');
select app.change_opportunity_stage(pg_temp.oid('CO000002'), 'L5');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000002'), pg_temp.test_data())$$), null, 'Tạo phiếu cho cơ hội bị gộp (chuẩn bị)');
select is((app.merge_preview('OPPORTUNITY', pg_temp.oid('CO000001'), pg_temp.oid('CO000002')) -> 'move'), '{"tests": 1, "notes": 1, "appointments": 1}'::jsonb, 'Xem trước cơ hội: lịch hẹn, ghi chú, phiếu sẽ chuyển');
select is((select substage_code from app.opportunity where code = 'CO000001'), 'L5A', 'Trước khi gộp: bản giữ lại chưa có phiếu, L5A');
select is(pg_temp.err($$select app.merge_opportunities(pg_temp.oid('CO000001'), pg_temp.oid('CO000002'), true)$$), null, 'Gộp cơ hội: được');
select is((select array[record_status, (select code from app.opportunity k where k.id = o.merged_into_id)] from app.opportunity o where o.code = 'CO000002'), array['DA_GOP', 'CO000001'], 'Cơ hội bị gộp thành Đã gộp, gộp vào CO000001');
select is((select count(*)::int from app.student_test where opportunity_id = pg_temp.oid('CO000001')), 1, 'Phiếu chuyển sang cơ hội giữ lại');
select is((select count(*)::int from app.appointment where opportunity_id = pg_temp.oid('CO000001')), 1, 'Lịch hẹn của cơ hội bị gộp chuyển sang (lịch nhắc của phiếu đi theo phiếu)');
select ok((select next_appointment_at is not null from app.opportunity where code = 'CO000001'), '"Lịch hẹn kế tiếp" của cơ hội giữ lại tính lại');
select is((select next_appointment_at from app.opportunity where code = 'CO000002'), null, '"Lịch hẹn kế tiếp" của cơ hội bị gộp trống');
select is(pg_temp.notes('OPPORTUNITY', pg_temp.oid('CO000001')) - pg_temp.sysnotes('OPPORTUNITY', pg_temp.oid('CO000001')), 1, 'Ghi chú chuyển sang cơ hội giữ lại');
select is(pg_temp.sysnotes('OPPORTUNITY', pg_temp.oid('CO000001')) + pg_temp.sysnotes('OPPORTUNITY', pg_temp.oid('CO000002')), 2, 'Ghi chú hệ thống "Đã gộp…" trên cả hai cơ hội');
select is((select substage_code from app.opportunity where code = 'CO000001'), 'L5B', 'R-CRM-15: phiếu Nháp vừa chuyển sang thì bản giữ lại tính lại nhóm con (L5B)');
select is((select stage_code from app.opportunity where code = 'CO000001'), 'L5', 'Giai đoạn bản giữ lại giữ nguyên');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('CO000002'), pg_temp.test_data())$$), 'HMT_BAN_GHI_DA_GOP', 'Cơ hội đã gộp chỉ đọc: không tạo phiếu');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000002'), 'L7')$$), 'HMT_BAN_GHI_DA_GOP', 'Cơ hội đã gộp chỉ đọc: không đổi giai đoạn');
select is((app.list_opportunities('{}') ->> 'total')::int, (select count(*)::int from app.opportunity where record_status = 'DANG_DUNG' and branch_id = (select id from app.branch where code = 'CS1')), 'Danh sách cơ hội ẩn bản đã gộp');
select is((app.list_opportunities('{"q": "CO000002"}') ->> 'total')::int, 1, 'Cơ hội đã gộp vẫn tìm được bằng mã');
select ok(pg_temp.audit_has('app.opportunity', pg_temp.oid('CO000002'), '%DA_GOP%'), 'Lịch sử (nhật ký) ghi việc gộp cơ hội');

-- ================= Gộp học sinh (R-CRM-25, 37b) =================
select pg_temp.sudo($$create temp table st as
  select app.find_or_create_student((select id from app.parent where phone = '0900000401'), 'Em Một Hai', 2012, null, 'THCS A', null, null, (select id from app.branch where code = 'CS1')) as keep,
         app.find_or_create_student((select id from app.parent where phone = '0900000401'), 'Em Một Ba', 2012, '2012-05-05', 'THCS B', 'Khá', 'Mục tiêu B', (select id from app.branch where code = 'CS1')) as mrg,
         app.find_or_create_student((select id from app.parent where phone = '0900000402'), 'Em Khác Cha', 2011, null, null, null, null, (select id from app.branch where code = 'CS1')) as other$$);
select pg_temp.sudo($$grant select on st to authenticated$$);
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position) select o.id, o.branch_id, 1 from app.opportunity o where o.code = 'CO000006' and not exists (select 1 from app.prospect_student p where p.opportunity_id = o.id); update app.prospect_student set student_id = (select mrg from st), full_name = null, birth_date = null, birth_year = null, school = null, self_rating = null, goal = null where opportunity_id = (select id from app.opportunity where code = 'CO000006')$$);
select pg_temp.sudo($$update app.student_test set student_id = (select mrg from st) where opportunity_id = (select id from app.opportunity where code = 'CO000001')$$);
select is(pg_temp.err($$select app.merge_students((select keep from st), (select other from st), true)$$), 'HMT_GOP_KHAC_PHU_HUYNH', 'R-CRM-37(b): khác phụ huynh thì gộp phụ huynh trước');
select is((app.merge_preview('STUDENT', (select keep from st), (select other from st)) -> 'blockers' -> 0 ->> 'code'), 'HMT_GOP_KHAC_PHU_HUYNH', 'Xem trước nêu điều kiện chặn');
select is((app.merge_preview('STUDENT', (select keep from st), (select mrg from st)) -> 'move'), '{"tests": 1, "notes": 0, "opportunities": 1, "attendance": 0, "enrollments": 0, "balance_entries": 0}'::jsonb, 'Xem trước học sinh: cơ hội, phiếu, ghi chú (và ghi danh, điểm danh, số dư, migration 596) sẽ chuyển');
select is(pg_temp.err($$select app.merge_students((select keep from st), (select mrg from st))$$), 'HMT_CAN_XAC_NHAN', 'Gộp học sinh cần xác nhận');
select is(pg_temp.err($$select app.merge_students((select keep from st), (select mrg from st), true)$$), null, 'Gộp học sinh cùng phụ huynh: được');
select is((select record_status from app.student where id = (select mrg from st)), 'DA_GOP', 'Học sinh bị gộp thành Đã gộp');
select is((select ps.student_id from app.prospect_student ps join app.opportunity o on o.id = ps.opportunity_id where o.code = 'CO000006' and ps.position = 1), (select keep from st), 'Cơ hội chuyển sang học sinh giữ lại');
select is((select count(*)::int from app.student_test where student_id = (select keep from st)), 1, 'Phiếu chuyển sang học sinh giữ lại');
select is((select array[birth_date::text, school, self_rating, goal] from app.student where id = (select keep from st)), array['2012-05-05', 'THCS A', 'Khá', 'Mục tiêu B'],
          'Ô còn trống của học sinh giữ lại lấy của bản kia; ô đã có giữ nguyên');
select is(pg_temp.sysnotes('STUDENT', (select keep from st)) + pg_temp.sysnotes('STUDENT', (select mrg from st)), 2, 'Ghi chú hệ thống "Đã gộp…" trên cả hai học sinh');
select ok((select bool_and(search_text like '%em mot hai%') from app.student_test where student_id = (select keep from st)), 'Ô tìm kiếm của phiếu đổi theo học sinh giữ lại');
select is((select count(*)::int from app.student where id = (select mrg from st) and merged_into_id = (select keep from st)), 1, 'Ghi gộp vào học sinh giữ lại');
select is(pg_temp.err($$select app.merge_students((select keep from st), (select mrg from st), true)$$), 'HMT_BAN_GHI_DA_GOP', 'Không gộp lại học sinh đã gộp');

-- ================= Gộp phụ huynh (R-CRM-25, 37c) =================
select pg_temp.sudo($$create temp table pr as select (select id from app.parent where phone = '0900000401') as keep, (select id from app.parent where phone = '0900000403') as mrg, (select id from app.parent where phone = '0900000402') as third$$);
select pg_temp.sudo($$grant select on pr to authenticated$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HS990001', (select mrg from pr), 'Em Một Hai', 2012, (select id from app.branch where code = 'CS1')$$);
select pg_temp.sudo($$insert into app.note (entity_type, entity_id, body) values ('PARENT', (select mrg from pr), 'Ghi chú phụ huynh bị gộp')$$);
select is((app.merge_preview('PARENT', (select keep from pr), (select mrg from pr)) -> 'move'),
          '{"leads": 2, "notes": 1, "students": 1, "opportunities": 2, "orders": 0, "receipts": 0, "quotations": 0, "enrollments": 0, "balance_entries": 0}'::jsonb, 'Xem trước phụ huynh: lead, cơ hội, học sinh, ghi chú (và đơn, phiếu thu, ghi danh, số dư, migration 596) sẽ chuyển');
select pg_temp.docs_stub($$'BG000009'$$);
select is(pg_temp.err($$select app.merge_parents((select keep from pr), (select mrg from pr), true)$$), null,
          'R-CRM-25: gộp phụ huynh không chặn theo báo giá, đơn (còn [CHỜ]): được dù cơ hội có báo giá');
select pg_temp.docs_stub('');
select is((select record_status from app.parent where id = (select mrg from pr)), 'DA_GOP', 'Phụ huynh bị gộp thành Đã gộp');
select is((select count(*)::int from app.lead where parent_id = (select mrg from pr)) + (select count(*)::int from app.opportunity where parent_id = (select mrg from pr))
          + (select count(*)::int from app.student where parent_id = (select mrg from pr)), 0, 'Lead, cơ hội, học sinh của phụ huynh bị gộp chuyển hết sang bản giữ lại');
select is((select count(*)::int from app.student where parent_id = (select keep from pr) and code = 'HS990001'), 1, 'Phụ huynh giữ lại nhận thêm học sinh của bản bị gộp (không tự gộp học sinh)');
select is(pg_temp.notes('PARENT', (select keep from pr)) - pg_temp.sysnotes('PARENT', (select keep from pr)), 1, 'Ghi chú của phụ huynh bị gộp chuyển sang');
select is(pg_temp.sysnotes('PARENT', (select keep from pr)) + pg_temp.sysnotes('PARENT', (select mrg from pr)), 2, 'Ghi chú hệ thống "Đã gộp…" trên cả hai phụ huynh');
select ok((select count(*) from app.opportunity o join app.parent p on p.id = o.parent_id where p.id = (select keep from pr) and o.search_text like '%' || app.fold_text(p.full_name) || '%') >= 1,
          'Ô tìm kiếm của cơ hội chuyển sang có tên phụ huynh giữ lại');
select is((select count(*)::int from app.duplicate_students_of_parent((select keep from pr))), 1, 'R-CRM-37(c): báo học sinh trùng tên, năm sinh dưới phụ huynh giữ lại');
select is((select student_name || '/' || birth_year from app.duplicate_students_of_parent((select keep from pr))), 'Em Một Hai/2012', 'Cặp học sinh trùng được nêu tên và năm sinh');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.merge_parents((select keep from pr), (select third from pr), true)$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không gộp phụ huynh');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.duplicate_students_of_parent((select keep from pr))$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không xem danh sách học sinh trùng');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.merge_parents((select keep from pr), (select mrg from pr), true)$$), 'HMT_BAN_GHI_DA_GOP', 'Không gộp lại phụ huynh đã gộp');
select is(pg_temp.err($$select app.create_lead(pg_temp.lead_data('0900000403'))$$), 'HMT_SDT_TRUNG', 'SĐT của phụ huynh đã gộp vẫn báo trùng khi tạo lead');
select is((select id::text from app.find_duplicate_contacts('0900000403') where kind = 'PARENT'), (select keep::text from pr), 'Kiểm trùng SĐT trỏ về phụ huynh giữ lại');
select is((select count(*)::int from app.find_duplicate_contacts('0900000403') where kind = 'PARENT'), 1, 'Chỉ một phụ huynh trùng (bản giữ lại)');
select is(pg_temp.fp('0900000403'), (select keep from pr), 'Tìm hoặc tạo phụ huynh: gặp hồ sơ đã gộp thì trả bản giữ lại');
select is(pg_temp.err($$select app.merge_parents((select keep from pr), (select id from app.parent where phone = '0900000499'), true)$$), 'HMT_GOP_KHAC_CO_SO', 'Phụ huynh khác cơ sở: Tuyển sinh không gộp được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.merge_parents((select keep from pr), (select id from app.parent where phone = '0900000499'), true)$$), null, 'Phụ huynh khác cơ sở: Admin gộp được');
select is(pg_temp.err($$select app.merge_leads(pg_temp.lid('LD000007'), pg_temp.lid('LD000004'), true)$$), null, 'Lead khác cơ sở: Admin gộp được');

-- ================= Ghi chú: ngoại lệ chuyển ghi chú chỉ trong hàm gộp =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$update app.note set entity_id = entity_id$$), '42501', 'Người dùng không sửa thẳng bảng ghi chú');
select is(pg_temp.err($$select app.move_notes('LEAD', gen_random_uuid(), gen_random_uuid())$$), '42501', 'Người dùng không gọi hàm chuyển ghi chú trực tiếp');
select is(pg_temp.err($$select pg_temp.sudo('update app.note set entity_id = (select id from app.lead where code = ''LD000004'') where entity_type = ''LEAD'' and entity_id = (select id from app.lead where code = ''LD000003'')')$$),
          'HMT_MA_KHONG_DOI_DUOC', 'Ngoài hàm gộp, chuyển ghi chú sang bản ghi khác vẫn bị chặn (cả quyền chủ DB)');
select is(coalesce(current_setting('hmt.merge', true), ''), '', 'Cờ chuyển ghi chú được tắt sau khi gộp');

select * from finish();
rollback;
