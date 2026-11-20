-- Migration 586: danh sách em của lead, cơ hội: app.add_prospect_student, app.update_prospect_student, app.remove_prospect_student.
-- Luật: R-CRM-23 (tối đa prospect_max_students em, em mới chỉ bắt buộc họ tên, năm sinh 4 chữ số, chọn con có sẵn chỉ ở cơ hội),
-- R-CRM-03 (từ L5 bắt buộc tên và năm sinh, cơ hội còn ít nhất một em), R-CRM-26/27 (quyền Sửa, dòng chỉ là ghi nhận). Dữ liệu giả.
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
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Em Thử', 'parent_phone', p_phone, 'student_name', 'Em Đầu', 'student_birth_year', 2012,
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1'), ('sales5'), ('teacher5');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@em.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@em.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('sales1', 'CS1'), ('sales5', 'CS5'), ('teacher5', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('sales5', 'SALES'), ('teacher5', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- ================= Dựng dữ liệu: ba lead ở CS1 (sales1); lead 3 thành cơ hội L5, lead 2 thành cơ hội chưa tới L5 =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900586001'));
select app.create_lead(pg_temp.lead_data('0900586002'));
select app.create_lead(pg_temp.lead_data('0900586003'));
select app.create_lead(pg_temp.lead_data('0900586004'));
select pg_temp.sudo($$create temp table ids as select id, parent_phone from app.lead where parent_phone like '09005860%'$$);
select pg_temp.sudo($$grant select on ids to authenticated$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable as 'select id from ids where parent_phone = p_phone'$$);
select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as 'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone'$$);
select pg_temp.sudo($$create function pg_temp.em(p_entity text, p_phone text, p_name text) returns uuid language sql stable security definer as
  'select ps.id from app.prospect_student ps where ps.full_name = p_name and (case when p_entity = ''LEAD'' then ps.lead_id = (select id from ids where parent_phone = p_phone)
     else ps.opportunity_id = (select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone) end)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.lid(text), pg_temp.oid(text), pg_temp.em(text, text, text) to public$$);
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900586002'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900586003'));
select app.change_opportunity_stage(pg_temp.oid('0900586003'), 'L5');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900586004'));
select app.change_opportunity_stage(pg_temp.oid('0900586004'), 'L5');
select pg_temp.sudo($$create function pg_temp.emfirst(p_phone text) returns uuid language sql stable security definer as
  'select ps.id from app.prospect_student ps where ps.opportunity_id = (select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone) order by ps.position limit 1'$$);
select pg_temp.sudo($$create function pg_temp.test_data() returns jsonb language sql stable as
  'select jsonb_build_object(''subject_code'', ''TOAN'', ''grade_code'', (select code from app.catalog_item where catalog_code = ''GRADE'' order by sort_order limit 1),
     ''mode_code'', ''OFFLINE'', ''level_code'', ''CO_BAN'', ''exam_name'', ''Toán cơ bản'', ''scheduled_at'', now() + interval ''3 days'')'$$);
select pg_temp.sudo($$grant execute on function pg_temp.emfirst(text), pg_temp.test_data() to public$$);

-- ================= Lead: thêm, sửa, bỏ, tối đa =================
select is(jsonb_array_length(app.add_prospect_student('LEAD', pg_temp.lid('0900586001'), '{"full_name": "Em Hai", "birth_year": 2014, "school": "THCS Thử"}')), 2, 'Lead: thêm em mới, danh sách có 2 em');
select is((select (e ->> 'school') from jsonb_array_elements(app.add_prospect_student('LEAD', pg_temp.lid('0900586001'), '{"full_name": "Em Ba"}')) e where e ->> 'full_name' = 'Em Ba'), null, 'Lead: em mới chỉ bắt buộc họ tên, năm sinh không bắt buộc');
select is(pg_temp.err($$select app.add_prospect_student('LEAD', pg_temp.lid('0900586001'), '{"full_name": "  "}')$$), 'HMT_THIEU_TEN_EM', 'Chặn: thêm em không có họ tên');
select is(pg_temp.err($$select app.add_prospect_student('LEAD', pg_temp.lid('0900586001'), '{"full_name": "Em Sai", "birth_year": 99}')$$), 'HMT_NAM_SINH_SAI', 'Chặn: năm sinh không đủ 4 chữ số');
select is(pg_temp.err($$select app.add_prospect_student('LEAD', pg_temp.lid('0900586001'), '{"student_id": "00000000-0000-0000-0000-000000000001"}')$$), 'HMT_EM_CHI_O_CO_HOI', 'Chặn: lead không có «Chọn con có sẵn»');
select is(jsonb_array_length(app.update_prospect_student(pg_temp.em('LEAD', '0900586001', 'Em Hai'), '{"full_name": "Em Hai Sửa", "goal": "Vào lớp 10"}')), 3, 'Lead: sửa em, danh sách vẫn 3 em');
select is((select (e ->> 'goal') from jsonb_array_elements(app.update_prospect_student(pg_temp.em('LEAD', '0900586001', 'Em Hai Sửa'), '{"school": "THCS Mới"}')) e where e ->> 'full_name' = 'Em Hai Sửa'), 'Vào lớp 10', 'Lead: sửa một ô thì các ô khác giữ nguyên');
select is(pg_temp.err($$select app.update_prospect_student(pg_temp.em('LEAD', '0900586001', 'Em Hai Sửa'), '{"full_name": ""}')$$), 'HMT_THIEU_TEN_EM', 'Chặn: xoá trống họ tên khi sửa em');
select is(jsonb_array_length(app.remove_prospect_student(pg_temp.em('LEAD', '0900586001', 'Em Ba'))), 2, 'Lead: bỏ em, danh sách còn 2 em');
-- Tối đa prospect_max_students (mặc định 5): lead có 2 em, thêm đủ 5 rồi chặn em thứ 6.
select app.add_prospect_student('LEAD', pg_temp.lid('0900586001'), '{"full_name": "Em Bốn"}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900586001'), '{"full_name": "Em Năm"}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900586001'), '{"full_name": "Em Sáu"}');
select is(pg_temp.err($$select app.add_prospect_student('LEAD', pg_temp.lid('0900586001'), '{"full_name": "Em Bảy"}')$$), 'HMT_EM_TOI_DA', 'Chặn: quá số em tối đa của danh sách');
select is((select count(*)::int from app.prospect_student where lead_id = pg_temp.lid('0900586001')), app.get_setting_int('prospect_max_students')::int, 'Danh sách đúng bằng số em tối đa theo tham số');

-- ================= Cơ hội chưa tới L5: chọn con có sẵn =================
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSEM586A', o.parent_id, 'Con có sẵn A', 2011, o.branch_id from app.opportunity o where o.id = pg_temp.oid('0900586002')$$);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) select 'PHEM586X', 'Phụ huynh khác', '0900586099', id from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSEM586X', (select id from app.parent where code = 'PHEM586X'), 'Con người khác', 2011, (select id from app.branch where code = 'CS1')$$);
select is(jsonb_array_length(app.add_prospect_student('OPPORTUNITY', pg_temp.oid('0900586002'),
  jsonb_build_object('student_id', (select id from app.student where code = 'HSEM586A')))), 2, 'Cơ hội: chọn con có sẵn của phụ huynh, danh sách có 2 em');
select is((select (e ->> 'student_code') from jsonb_array_elements(app.update_prospect_student(pg_temp.emfirst('0900586002'), '{}')) e where e ->> 'student_code' is not null), 'HSEM586A', 'Dòng chọn con có sẵn đọc thẳng từ hồ sơ học sinh (có mã học sinh)');
select is(pg_temp.err($$select app.add_prospect_student('OPPORTUNITY', pg_temp.oid('0900586002'), jsonb_build_object('student_id', (select id from app.student where code = 'HSEM586A')))$$), 'HMT_EM_TRUNG', 'Chặn: con có sẵn đã có trong danh sách');
select is(pg_temp.err($$select app.add_prospect_student('OPPORTUNITY', pg_temp.oid('0900586002'), jsonb_build_object('student_id', (select id from app.student where code = 'HSEM586X')))$$), 'HMT_EM_KHAC_PHU_HUYNH', 'Chặn: con của phụ huynh khác');
select is(jsonb_array_length(app.add_prospect_student('OPPORTUNITY', pg_temp.oid('0900586002'), '{"full_name": "Em mới chưa năm sinh"}')), 3, 'Cơ hội chưa tới L5: thêm em mới không cần năm sinh');
select is((select count(*)::int from app.student where full_name = 'Em mới chưa năm sinh'), 0, 'Thêm em mới không tạo hồ sơ học sinh (R-CRM-27)');

-- ================= Cơ hội từ L5 =================
select is(pg_temp.err($$select app.add_prospect_student('OPPORTUNITY', pg_temp.oid('0900586003'), '{"full_name": "Em L5 thiếu năm"}')$$), 'HMT_THIEU_HOC_SINH', 'Chặn (R-CRM-03): từ L5 em mới bắt buộc năm sinh');
select is(jsonb_array_length(app.add_prospect_student('OPPORTUNITY', pg_temp.oid('0900586003'), '{"full_name": "Em L5 đủ", "birth_year": 2015}')), 2, 'Từ L5: em mới có tên và năm sinh thì thêm được');
select is(pg_temp.err($$select app.update_prospect_student(pg_temp.em('OPPORTUNITY', '0900586003', 'Em L5 đủ'), '{"birth_year": null}')$$), 'HMT_THIEU_HOC_SINH', 'Chặn (R-CRM-03): từ L5 không xoá năm sinh của em');
select is((select (e ->> 'birth_year')::int from jsonb_array_elements(app.update_prospect_student(pg_temp.em('OPPORTUNITY', '0900586003', 'Em L5 đủ'), '{"birth_year": 2016}')) e where e ->> 'full_name' = 'Em L5 đủ'), 2016, 'Từ L5: đổi năm sinh sang giá trị khác được');
-- Phiếu kiểm tra gắn em đầu thì không bỏ được; em đã dùng ở phiếu bị chặn.
select app.create_student_test(pg_temp.oid('0900586003'), pg_temp.test_data());
select is(pg_temp.err($$select app.remove_prospect_student(pg_temp.emfirst('0900586003'))$$), 'HMT_EM_DANG_DUNG', 'Chặn: em đã có phiếu kiểm tra thì không bỏ');
select is(jsonb_array_length(app.remove_prospect_student(pg_temp.em('OPPORTUNITY', '0900586003', 'Em L5 đủ'))), 1, 'Từ L5: bỏ em chưa dùng, còn 1 em');
select is(pg_temp.err($$select app.remove_prospect_student(pg_temp.emfirst('0900586004'))$$), 'HMT_EM_CUOI', 'Chặn (R-CRM-03): từ L5 cơ hội phải còn ít nhất một em');

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.add_prospect_student('LEAD', pg_temp.lid('0900586001'), '{"full_name": "Em ngoài cơ sở"}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: sale cơ sở khác không thêm em vào lead CS1');
select is(pg_temp.err($$select app.update_prospect_student(pg_temp.em('LEAD', '0900586001', 'Em Đầu'), '{"full_name": "X"}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: sale cơ sở khác không sửa em của lead CS1');
select is(pg_temp.err($$select app.remove_prospect_student(pg_temp.em('LEAD', '0900586001', 'Em Đầu'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: sale cơ sở khác không bỏ em của lead CS1');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.add_prospect_student('OPPORTUNITY', pg_temp.oid('0900586002'), '{"full_name": "Em giáo viên"}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không có quyền Sửa cơ hội');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(jsonb_array_length(app.add_prospect_student('OPPORTUNITY', pg_temp.oid('0900586002'), '{"full_name": "Em do Admin"}')), 4, 'Quyền: Admin thêm em được ở mọi cơ sở');
select is(pg_temp.err($$select app.add_prospect_student('LOAI_LA', pg_temp.lid('0900586001'), '{"full_name": "X"}')$$), 'HMT_LOAI_SAI', 'Chặn: loại hồ sơ lạ');
select is(pg_temp.err($$select app.remove_prospect_student('00000000-0000-0000-0000-000000000009')$$), 'HMT_KHONG_TIM_THAY', 'Chặn: bỏ em không tồn tại');
reset role;
set local role anon;
select is(pg_temp.err($$select app.add_prospect_student('LEAD', pg_temp.lid('0900586001'), '{"full_name": "X"}')$$), '42501', 'Chặn: khách chưa đăng nhập không gọi được add_prospect_student');
select is(pg_temp.err($$select app.prospect_guard('LEAD', pg_temp.lid('0900586001'))$$), '42501', 'Chặn: hàm trong prospect_guard không mở cho API');
reset role;

select * from finish();
rollback;
