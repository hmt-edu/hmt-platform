-- Danh sách em của lead và cơ hội, PR DB-1 (QĐ-Đ75, Đ81, Đ86, Đ88): bảng prospect_student, chuyển hàm, giữ hành vi cũ.
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò đọc trong và ngoài cơ sở.
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
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900003001', '{"parent_name": "Chị Em A", "student_name": "Em Một", "student_birth_year": 2012, "school": "THCS Một"}'));
select app.create_lead(pg_temp.lead_data('0900003002', '{"parent_name": "Chị Em B", "student_name": null}'));
select app.create_lead(pg_temp.lead_data('0900003003', '{"parent_name": "Chị Em C", "student_name": "Em Ba", "student_birth_year": 2011}'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900003099', '{"parent_name": "Chị Em CS5", "student_name": "Em Chín", "student_birth_year": 2012}'));
select pg_temp.sudo($$create temp table lead_ids as select id, parent_phone from app.lead where parent_phone like '09000030%'$$);
select pg_temp.sudo($$grant select on lead_ids to authenticated$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable as 'select id from lead_ids where parent_phone = p_phone'$$);
select pg_temp.sudo($$grant execute on function pg_temp.lid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as 'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.test_data() returns jsonb language sql stable as
  'select jsonb_build_object(''subject_code'', ''TOAN'', ''grade_code'', (select code from app.catalog_item where catalog_code = ''GRADE'' order by sort_order limit 1),
     ''mode_code'', ''OFFLINE'', ''level_code'', ''CO_BAN'', ''exam_name'', ''Toán cơ bản'', ''scheduled_at'', now() + interval ''3 days'')'$$);
select pg_temp.sudo($$grant execute on function pg_temp.test_data() to public$$);

-- ================= Bảng, tham số, ràng buộc =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((select value from app.setting_def where key = 'prospect_max_students'), '5', 'Đ88: tham số prospect_max_students mặc định 5');
select is((select array[min_value, max_value] from app.setting_def where key = 'prospect_max_students'), array[1::numeric, 20], 'Đ88: khoảng 1 đến 20');
select is((select relrowsecurity from pg_class where oid = 'app.prospect_student'::regclass), true, 'Danh sách em: RLS bật');
select throws_ok($$insert into app.prospect_student (lead_id, branch_id, position) select id, branch_id, 9 from app.lead limit 1$$, '42501', null,
                 'Danh sách em: người dùng không ghi trực tiếp vào bảng');

-- ================= Lead: nhập một em ghi vào dòng 1 (Đ81) =================
select is((select count(*)::int from app.prospect_student where lead_id = pg_temp.lid('0900003001')), 1, 'Đ81: lead nhập một em thì có một dòng em');
select is((select array[ps.full_name, ps.birth_year::text, ps.school] from app.prospect_student ps where ps.lead_id = pg_temp.lid('0900003001')),
          array['Em Một', '2012', 'THCS Một'], 'Em đầu của lead: tên, năm sinh, trường');
select is((select count(*)::int from app.prospect_student where lead_id = pg_temp.lid('0900003002')), 0, 'Lead không nhập học sinh thì không có dòng em');
select is(pg_temp.err($$select app.update_lead(pg_temp.lid('0900003002'), '{"student_name": "Em Hai", "student_birth_year": 2013}')$$), null,
          'Sửa lead thêm thông tin học sinh: được');
select is((select ps.full_name from app.prospect_student ps where ps.lead_id = pg_temp.lid('0900003002') and ps.position = 1), 'Em Hai',
          'Sửa lead: ghi vào dòng 1 (tạo dòng nếu chưa có)');
select is(pg_temp.err($$select app.update_lead(pg_temp.lid('0900003002'), '{"school": "THCS Hai"}')$$), null, 'Sửa lead chỉ một ô của em');
select is((select array[ps.full_name, ps.school] from app.prospect_student ps where ps.lead_id = pg_temp.lid('0900003002')),
          array['Em Hai', 'THCS Hai'], 'Ô không nêu trong dữ liệu sửa thì giữ nguyên');
select is((select count(*)::int from app.prospect_student where lead_id = pg_temp.lid('0900003002')), 1, 'Sửa lead không nhân dòng em');

-- ================= Tìm kiếm theo tên em (D17) =================
select is((app.list_leads('{"q": "em hai"}') ->> 'total')::int, 1, 'Lead tìm được theo tên em (không dấu)');
select is((app.list_leads('{"q": "em hai"}') -> 'rows' -> 0 ->> 'student_name'), 'Em Hai', 'Danh sách lead vẫn trả student_name (em đầu)');
select is((app.list_leads('{"q": "em hai"}') -> 'rows' -> 0 ->> 'student_birth_year'), '2013', 'Danh sách lead vẫn trả student_birth_year');
select is((app.get_lead(pg_temp.lid('0900003001')) ->> 'student_name'), 'Em Một', 'get_lead giữ khoá student_name (tương thích)');
select is(jsonb_array_length(app.get_lead(pg_temp.lid('0900003001')) -> 'students'), 1, 'get_lead trả mảng students');
select ok(not (app.get_lead(pg_temp.lid('0900003001')) ? 'search_text'), 'get_lead không lộ search_text');

-- ================= Cơ hội: em đầu của lead chép sang (Đ81) =================
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900003001'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900003002'), '{"student_name": "Em Hai Sửa"}');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900003003'), '{"student_birth_date": "2011-03-04"}');
select is((select array[ps.full_name, ps.birth_year::text, ps.school] from app.prospect_student ps where ps.opportunity_id = pg_temp.oid('0900003001')),
          array['Em Một', '2012', 'THCS Một'], 'Tạo cơ hội: em đầu của lead chép sang dòng 1 của cơ hội');
select is((select ps.full_name from app.prospect_student ps where ps.opportunity_id = pg_temp.oid('0900003002')), 'Em Hai Sửa',
          'Tạo cơ hội: ô nêu trong dữ liệu tạo thắng ô của lead');
select is((select ps.birth_year from app.prospect_student ps where ps.opportunity_id = pg_temp.oid('0900003003')), 2011,
          'Tạo cơ hội: có ngày sinh mà không có năm sinh thì năm lấy từ ngày sinh');
select is((select count(*)::int from app.prospect_student where lead_id = pg_temp.lid('0900003001')), 1, 'Lead giữ nguyên danh sách em của nó');
select is((app.list_opportunities('{"q": "em hai sua"}') ->> 'total')::int, 1, 'Cơ hội tìm được theo tên em');
select is((app.get_opportunity(pg_temp.oid('0900003001')) ->> 'student_name'), 'Em Một', 'get_opportunity giữ khoá student_name');
select is((app.get_opportunity(pg_temp.oid('0900003001')) -> 'students' -> 0 ->> 'full_name'), 'Em Một', 'get_opportunity trả mảng students');
select is((app.list_opportunities('{}') -> 'rows' -> 0 ? 'student_name'), true, 'Danh sách cơ hội vẫn có khoá student_name');
select lives_ok($$select app.list_opportunities('{}', 'name_asc')$$, 'Danh sách cơ hội sắp xếp theo tên em chạy được');
select lives_ok($$select app.opportunity_board('{}')$$, 'Bảng Kanban cơ hội chạy được');
select lives_ok($$select app.lead_board('{}')$$, 'Bảng Kanban lead chạy được');

-- ================= R-CRM-03: từ L5 cần tên, năm sinh của em đầu =================
select is(pg_temp.err($$select app.update_opportunity(pg_temp.oid('0900003001'), '{"student_name": "Em Một Mới"}')$$), null, 'Sửa tên em ở cơ hội L1: được');
select is((select ps.full_name from app.prospect_student ps where ps.opportunity_id = pg_temp.oid('0900003001')), 'Em Một Mới', 'Sửa cơ hội ghi vào em đầu');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('0900003001'), 'L5')$$), null, 'R-CRM-03: có tên, năm sinh thì lên L5');
select is(pg_temp.err($$select app.update_opportunity(pg_temp.oid('0900003001'), '{"student_name": null}')$$), 'HMT_THIEU_HOC_SINH',
          'R-CRM-03: từ L5 không được xoá tên em');
select is(pg_temp.err($$select app.update_opportunity(pg_temp.oid('0900003001'), '{"student_birth_year": null}')$$), 'HMT_THIEU_HOC_SINH',
          'R-CRM-03: từ L5 không được xoá năm sinh em');

-- ================= Phiếu kiểm tra: em đầu, gắn hồ sơ học sinh (R-CRM-27, Đ86) =================
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('0900003001'), pg_temp.test_data())$$), null, 'Tạo phiếu từ cơ hội L5: được');
select is((select count(*)::int from app.student_test t join app.prospect_student ps on ps.id = t.prospect_student_id
            where t.opportunity_id = pg_temp.oid('0900003001')), 1, 'Phiếu trỏ tới dòng em của cơ hội');
select ok((select ps.student_id is not null from app.prospect_student ps where ps.opportunity_id = pg_temp.oid('0900003001')),
          'R-CRM-27: tạo phiếu thì dòng em gắn hồ sơ học sinh');
select is((select array[ps.full_name, ps.birth_year::text, ps.school] from app.prospect_student ps where ps.opportunity_id = pg_temp.oid('0900003001')),
          array[null, null, null], 'Đ86: dòng đã gắn hồ sơ không giữ bản sao tên, năm sinh, trường');
select is((app.get_opportunity(pg_temp.oid('0900003001')) ->> 'student_name'), 'Em Một Mới', 'Đ86: tên đọc thẳng từ hồ sơ học sinh');
select is((select s.full_name from app.student s join app.prospect_student ps on ps.student_id = s.id where ps.opportunity_id = pg_temp.oid('0900003001')),
          'Em Một Mới', 'Hồ sơ học sinh lấy tên từ dòng em');
select throws_ok($$update app.prospect_student set full_name = 'Em Lệch' where opportunity_id = (select id from app.opportunity limit 1)$$, '42501', null,
                 'Đ86: người dùng không ghi trực tiếp bảng danh sách em');
select is(pg_temp.err($$select app.update_opportunity(pg_temp.oid('0900003001'), '{"student_name": "Em Một Đổi", "student_birth_year": 2012}')$$), null,
          'Sửa em đã gắn hồ sơ ở cơ hội: được');
select is((select s.full_name from app.student s join app.prospect_student ps on ps.student_id = s.id where ps.opportunity_id = pg_temp.oid('0900003001')),
          'Em Một Đổi', 'R-CRM-26: sửa em đã gắn hồ sơ là sửa luôn hồ sơ học sinh');
select is((app.list_opportunities('{"q": "em mot doi"}') ->> 'total')::int, 1, 'Đổi tên học sinh thì tìm kiếm của cơ hội đổi theo');
select is(pg_temp.err($$select app.update_opportunity(pg_temp.oid('0900003001'), '{"student_name": null}')$$), 'HMT_THIEU_HOC_SINH',
          'Em đã gắn hồ sơ không được xoá tên');

-- ================= RLS: đọc trong và ngoài cơ sở =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select ok((select count(*) from app.prospect_student) >= 4, 'Sale CS1 đọc được các dòng em của cơ sở mình');
select is((select count(*)::int from app.prospect_student where full_name = 'Em Chín'), 0, 'Sale CS1 không đọc được dòng em của CS5');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((select count(*)::int from app.prospect_student where full_name = 'Em Chín'), 1, 'Sale CS5 đọc được dòng em của cơ sở mình');
select is((select count(*)::int from app.prospect_student where full_name = 'Em Một Mới'), 0, 'Sale CS5 không đọc được dòng em của CS1');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is((select count(*)::int from app.prospect_student), 0, 'Giáo viên (không có quyền Lead, Cơ hội · Xem) đọc ra 0 dòng em');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is((select count(*)::int from app.prospect_student), 0, 'Học sinh đọc ra 0 dòng em');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select ok((select count(*) from app.prospect_student) >= 4, 'CSKH CS1 đọc được các dòng em của cơ sở mình');

-- ================= Bổ sung (b): branch_id theo cơ sở của hồ sơ cha =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select pg_temp.sudo($$update app.lead set branch_id = (select id from app.branch where code = 'CS2') where id = pg_temp.lid('0900003003')$$);
select is((select b.code from app.prospect_student ps join app.branch b on b.id = ps.branch_id where ps.lead_id = pg_temp.lid('0900003003')), 'CS2',
          'branch_id của dòng em đổi theo khi lead đổi cơ sở');
select pg_temp.sudo($$update app.opportunity set branch_id = (select id from app.branch where code = 'CS2') where id = pg_temp.oid('0900003003')$$);
select is((select b.code from app.prospect_student ps join app.branch b on b.id = ps.branch_id where ps.opportunity_id = pg_temp.oid('0900003003')), 'CS2',
          'branch_id của dòng em đổi theo khi cơ hội đổi cơ sở');

-- ================= Ràng buộc =================
select throws_ok($$select pg_temp.sudo('insert into app.prospect_student (branch_id) select id from app.branch limit 1')$$, '23514', null,
                 'Dòng em phải thuộc đúng một trong lead hoặc cơ hội');
select throws_ok($$select pg_temp.sudo('insert into app.prospect_student (lead_id, opportunity_id, branch_id) select l.id, o.id, l.branch_id from app.lead l, app.opportunity o limit 1')$$, '23514', null,
                 'Dòng em không thuộc cả lead lẫn cơ hội');
select throws_ok($$select pg_temp.sudo('update app.prospect_student set full_name = ''Bản sao'' where student_id is not null')$$, '23514', null,
                 'Đ86: dòng đã gắn hồ sơ học sinh không được giữ bản sao tên');

-- ================= Gộp cơ hội (hành vi cũ, R-CRM-37a) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900003010', '{"parent_name": "Chị Gộp", "student_name": null}'));
select pg_temp.sudo($$update app.lead set parent_id = null where parent_phone = '0900003010'$$);
select pg_temp.sudo($$insert into lead_ids select id, parent_phone from app.lead where parent_phone = '0900003010'$$);
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900003010'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900003010'), '{"student_name": "Em Gộp", "student_birth_year": 2010}', true);
select pg_temp.sudo($$create temp table mg as select
  (select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = '0900003010' order by o.code limit 1) as k,
  (select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = '0900003010' order by o.code desc limit 1) as m$$);
select pg_temp.sudo($$grant select on mg to authenticated$$);
select is((select count(*)::int from app.prospect_student where opportunity_id = (select k from mg)), 0, 'Cơ hội giữ lại chưa có em');
select is(pg_temp.err($$select app.merge_opportunities((select k from mg), (select m from mg), true)$$), null, 'Gộp cơ hội: được');
select is((select ps.full_name from app.prospect_student ps where ps.opportunity_id = (select k from mg)), 'Em Gộp',
          'R-CRM-37(a): bản giữ lại chưa có em thì nhận dòng em của bản kia');
select is((app.list_opportunities('{"q": "em gop"}') ->> 'total')::int, 1, 'Sau gộp, tìm theo tên em chỉ ra bản giữ lại');

-- ================= Các hàm đọc đã chuyển sang bảng mới chạy được =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select lives_ok($$select app.export_leads('{}')$$, 'Xuất lead chạy được');
select lives_ok($$select app.export_opportunities('{}')$$, 'Xuất cơ hội chạy được');
select ok((app.export_leads('{}')::text) like '%Em Hai%', 'Xuất lead có tên em đầu');
select lives_ok($$select app.merge_candidates('LEAD', pg_temp.lid('0900003001'))$$, 'Gợi ý bản trùng của lead chạy được');
select lives_ok($$select app.merge_candidates('OPPORTUNITY', pg_temp.oid('0900003001'))$$, 'Gợi ý bản trùng của cơ hội chạy được');
select lives_ok($$select app.list_appointments('{}')$$, 'Danh sách lịch hẹn chạy được');
select lives_ok($$select app.export_appointments('{}')$$, 'Xuất lịch hẹn chạy được');
select lives_ok($$select app.find_duplicate_contacts('0900003001')$$, 'Tìm liên hệ trùng chạy được');

select * from finish();
rollback;
