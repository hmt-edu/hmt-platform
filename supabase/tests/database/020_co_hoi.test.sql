-- P3b2a: cơ hội (docs/spec/04 R-CRM-01, 02, 03, 09, 12, 13, 14, 15, 16, 17, 23, 26, 27, 28; 34, 35; bốn câu P3b2 anh chốt 18/10).
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò đọc, ghi trong và ngoài cơ sở.
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
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1'), ('teacher5'), ('hs');
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

-- ================= Dựng lead (đóng vai Tuyển sinh CS1, CS5) =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900000101', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900000102', '{"student_name": null, "student_birth_year": null}'));
select app.create_lead(pg_temp.lead_data('0900000104', '{"parent_name": "Bố Tên Khác", "student_name": "Em Bốn", "student_birth_year": 2013}'));
select app.create_lead(pg_temp.lead_data('0900000105', '{"student_name": "Em Năm", "student_birth_year": 2011}'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900000103', '{"student_name": "Em Ba", "student_birth_year": 2012}'));
select pg_temp.sudo($$create temp table lead_ids as select id, parent_phone from app.lead$$);
select pg_temp.sudo($$grant select on lead_ids to authenticated$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable as 'select id from lead_ids where parent_phone = p_phone'$$);
select pg_temp.sudo($$grant execute on function pg_temp.lid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.oid(p_code text) returns uuid language sql stable security definer as 'select id from app.opportunity where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oid(text) to public$$);

-- Nhật ký chỉ ADMIN đọc: bài kiểm hỏi qua hàm chạy bằng quyền chủ DB.
select pg_temp.sudo($$create function pg_temp.audit_has(p_id uuid, p_like text) returns boolean language sql stable security definer as
  'select exists (select from app.audit_log a join app.audited_table t on t.id = a.table_id where t.table_name = ''app.opportunity'' and a.record_id = p_id and a.action = ''U'' and a.changes::text like p_like)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.audit_has(uuid, text) to public$$);

-- ================= Danh mục, tham số, khoá =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((select value from app.setting_def where key = 'kanban_cards_per_column'), '20', 'Tham số số thẻ mỗi cột Kanban mặc định 20');
select is((select array_agg(code order by code) from app.catalog_item
            where catalog_code = 'OPP_SUBSTAGE' and is_locked and code like 'L5%'),
          array['L5A', 'L5B', 'L5C', 'L5D', 'L5E', 'L5F', 'L5G', 'L5H', 'L5I', 'L5K', 'L5M', 'L5N', 'L5O', 'L5P', 'L5Q'],
          'Khoá toàn bộ nhóm con L5 (hệ thống gắn, R-CRM-15)');
select is((select array_agg(code order by code) from app.catalog_item
            where catalog_code = 'OPP_SUBSTAGE' and is_locked and (code like 'L6%' or code like 'L8%')),
          array['L6A', 'L8A', 'L8B', 'L8C'], 'Khoá L6A (R-CRM-13) và L8A, L8B, L8C (R-CRM-16, 17)');
select is((select is_locked from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L7B'), false, 'L7B chưa khoá');

-- ================= Tạo cơ hội: R-CRM-01, 09, 26, 27, 28 =================
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900000101'))$$), null,
          'R-CRM-01: tạo cơ hội từ lead đang ở C4C: được');
select is((select code from app.opportunity where lead_id = pg_temp.lid('0900000101')), 'CO000001', 'Mã cơ hội cấp lúc Lưu: CO000001');
select is((select array[stage_code, record_status] from app.opportunity where code = 'CO000001'), array['L1', 'DANG_DUNG'],
          'Cơ hội mới ở L1 (anh chốt 18/10), đang dùng');
select is((select array[stage_code, substage_code] from app.lead where id = pg_temp.lid('0900000101')), array['C4', 'C4D'],
          'R-CRM-09: tạo cơ hội xong lead tự về C4D "Tạo cơ hội thành công"');
select is((select owner_id from app.opportunity where code = 'CO000001'), pg_temp.uid('sales1'), 'Người phụ trách chép từ lead');
select is((select array[ps.full_name, ps.birth_year::text] from app.prospect_student ps join app.opportunity o on o.id = ps.opportunity_id where o.code = 'CO000001' and ps.position = 1),
          array['Em Một', '2012'], 'Tên, năm sinh học sinh chép từ lead');
select is((select count(*)::int from app.parent where phone = '0900000101'), 1, 'R-CRM-27: lead chưa có phụ huynh thì sinh hồ sơ phụ huynh khi tạo cơ hội');
select is((select p.branch_id from app.opportunity o join app.parent p on p.id = o.parent_id where o.code = 'CO000001'),
          (select id from app.branch where code = 'CS1'), 'R-CRM-28: cơ sở tiếp nhận của phụ huynh mới = cơ sở của cơ hội');
select is((select parent_id from app.lead where id = pg_temp.lid('0900000101')), (select parent_id from app.opportunity where code = 'CO000001'),
          'Lead nhận phụ huynh vừa sinh');
select ok((select search_text like '%0900000101%' and search_text like '%co000001%' from app.opportunity where code = 'CO000001'),
          'Ô tìm kiếm có mã cơ hội và SĐT phụ huynh');

select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900000101'))$$), 'HMT_LEAD_DA_CO_CO_HOI',
          'R-CRM-01: lead đã có cơ hội thì cảnh báo, cần xác nhận lần hai');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select ok((select pg_temp.msg($$select app.create_opportunity(pg_temp.lid('0900000101'))$$)) like '%CO000001%',
          'R-CRM-01: câu cảnh báo nêu mã cơ hội cũ');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900000101'), '{}'::jsonb, true)$$), null, 'Xác nhận lần hai: tạo thêm được');
select is((select count(*)::int from app.opportunity where lead_id = pg_temp.lid('0900000101')), 2, 'Lead có hai cơ hội');
select is((select count(*)::int from app.parent where phone = '0900000101'), 1, 'Cơ hội thứ hai dùng lại phụ huynh, không sinh thêm');

-- Phụ huynh khớp SĐT nhưng khác tên: dùng hồ sơ cũ, không ghi đè tên.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id)
  select 'PH900004', 'Mẹ Có Sẵn', '0900000104', id from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900000104'))$$), null, 'Phụ huynh khớp SĐT khác tên: tạo cơ hội được');
select is((select p.code || '/' || p.full_name from app.opportunity o join app.parent p on p.id = o.parent_id
            where o.lead_id = pg_temp.lid('0900000104')), 'PH900004/Mẹ Có Sẵn', 'Dùng hồ sơ phụ huynh cũ, KHÔNG ghi đè tên');
select is((select count(*)::int from app.parent where phone = '0900000104'), 1, 'Không sinh thêm phụ huynh cùng SĐT');

-- Chặn: quyền, cơ sở, lead đã gộp, ghi thẳng.
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select is(pg_temp.err($$select app.create_opportunity('00000000-0000-0000-0000-000000000000')$$), 'HMT_KHONG_TIM_THAY', 'Chặn: lead không có');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900000103'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh CS1 tạo cơ hội cho lead CS5');
select is(pg_temp.err($$insert into app.opportunity (code) values ('X')$$), '42501', 'Không ghi thẳng bảng cơ hội');
select is(pg_temp.err($$select app.find_or_create_parent('0900000999', 'X', null, null, null, (select id from app.branch where code = 'CS1'))$$),
          '42501', 'Giao diện không gọi hàm nội bộ tìm hoặc tạo phụ huynh');
select is(pg_temp.err($$select app.find_or_create_student(gen_random_uuid(), 'X', 2012, null, null, null, null, null)$$),
          '42501', 'Giao diện không gọi hàm nội bộ tìm hoặc tạo học sinh');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900000103'))$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không tạo cơ hội');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$update app.lead set record_status = 'DA_GOP', merged_into_id = (select id from app.lead where parent_phone = '0900000101')
                       where parent_phone = '0900000105'$$);
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900000105'))$$), 'HMT_BAN_GHI_DA_GOP', 'Chặn: lead đã gộp không tạo cơ hội');
select pg_temp.sudo($$update app.lead set record_status = 'DANG_DUNG', merged_into_id = null where parent_phone = '0900000105'$$);

-- ================= Tìm hoặc tạo học sinh (R-CRM-27): hai câu trả lời 2 và 4 =================
select pg_temp.sudo($$create temp table st as
  select app.find_or_create_student((select id from app.parent where code = 'PH900004'), 'Nguyễn Văn An', 2012, null, 'THCS A', null, null,
                                    (select id from app.branch where code = 'CS1')) as a$$);
select pg_temp.sudo($$alter table st add column b uuid, add column c uuid$$);
select pg_temp.sudo($$update st set b = app.find_or_create_student((select id from app.parent where code = 'PH900004'), '  NGUYEN   van an ', 2012, null, null, null, null,
                                    (select id from app.branch where code = 'CS1')),
                                    c = app.find_or_create_student((select id from app.parent where code = 'PH900004'), 'Nguyễn Văn An', 2013, null, null, null, null,
                                    (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$grant select on st to authenticated$$);
select is((select a = b from st), true, 'R-CRM-27: cùng phụ huynh, tên chuẩn hoá (bỏ dấu, hoa thường, dấu cách), năm sinh: dùng hồ sơ có sẵn');
select is((select a <> c from st), true, 'Học sinh trùng tên khác năm sinh: hai hồ sơ riêng');
select is((select count(*)::int from app.student where parent_id = (select id from app.parent where code = 'PH900004')), 2, 'Phụ huynh có đúng hai hồ sơ học sinh');
select is((select s.branch_id from app.student s join st on st.a = s.id), (select id from app.branch where code = 'CS1'), 'Cơ sở tiếp nhận của học sinh mới = cơ sở của cơ hội');
select is((select code like 'HS%' from app.student s join st on st.a = s.id), true, 'Mã học sinh cấp theo spec 02 (HS…)');
select is(pg_temp.err($$select app.normalize_person_name('  Nguyễn   VĂN  An ')$$), null, 'Chuẩn hoá tên chạy được');
select is(app.normalize_person_name('  Nguyễn   VĂN  An '), 'nguyen van an', 'Chuẩn hoá tên: bỏ dấu, chữ thường, một dấu cách');

-- ================= Sửa cơ hội: câu trả lời 2 (sửa học sinh ở cơ hội = sửa hồ sơ học sinh) =================
select is(pg_temp.err($$select app.update_opportunity(pg_temp.oid('CO000001'), '{"student_name": "Em Một Sửa", "school": "THCS Mới"}')$$), null,
          'Sửa thông tin học sinh ở cơ hội (chưa có hồ sơ học sinh): được');
select is((select ps.full_name from app.prospect_student ps join app.opportunity o on o.id = ps.opportunity_id where o.code = 'CO000001' and ps.position = 1), 'Em Một Sửa', 'Cơ hội lưu tên học sinh mới');
select pg_temp.sudo($$update app.prospect_student set student_id = (select a from st), full_name = null, birth_date = null, birth_year = null, school = null, self_rating = null, goal = null where opportunity_id = (select id from app.opportunity where code = 'CO000001')$$);
select is(pg_temp.err($$select app.update_opportunity(pg_temp.oid('CO000001'), '{"student_name": "Tên Chung Một Nguồn", "student_birth_year": 2010}')$$), null,
          'Cơ hội đã có hồ sơ học sinh: sửa được');
select is((select array[full_name, birth_year::text] from app.student where id = (select a from st)), array['Tên Chung Một Nguồn', '2010'],
          'Câu 2: sửa học sinh ở cơ hội là sửa luôn hồ sơ học sinh (một nguồn)');
select is(pg_temp.err($$select app.update_opportunity(pg_temp.oid('CO000001'), '{"student_name": null}')$$), 'HMT_THIEU_HOC_SINH',
          'Hồ sơ học sinh không được xoá tên');
select is(pg_temp.err($$select app.update_opportunity('00000000-0000-0000-0000-000000000000', '{}')$$), 'HMT_KHONG_TIM_THAY', 'Sửa: cơ hội không có');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.update_opportunity(pg_temp.oid('CO000001'), '{"need": "x"}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh CS5 sửa cơ hội CS1');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= Đổi giai đoạn: R-CRM-02, 03, 13, 14, 15, 16, 17 =================
-- Cơ hội CO000003 (lead 0900000104) có học sinh; CO000002 (lead 0900000101) cũng có. Cơ hội của lead 0900000102 không có học sinh.
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900000102'), '{"stage_code": "L5", "substage_code": "L5B", "skip_reason_code": "KHAC"}')$$), null,
          'Lead không có học sinh: vẫn tạo cơ hội (R-CRM-03 chỉ bắt từ L5); truyền giai đoạn lúc tạo cũng không được dùng');
select is((select array[stage_code, coalesce(substage_code, 'trống'), coalesce(skip_reason_code, 'trống')] from app.opportunity where code = 'CO000004'),
          array['L1', 'trống', 'trống'], 'R-CRM-36: cơ hội mới luôn bắt đầu ở L1, người dùng không chọn giai đoạn lúc tạo');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L4')$$), null, 'Chuyển L1 → L4: được');
select is((select stage_code from app.opportunity where code = 'CO000004'), 'L4', 'Cơ hội ở L4');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L2')$$), 'HMT_CO_HOI_KHONG_LUI', 'R-CRM-02: không lùi L4 → L2');
select is(pg_temp.err($$select pg_temp.sudo('update app.opportunity set stage_code = ''L1'' where code = ''CO000004''')$$), 'HMT_CO_HOI_KHONG_LUI',
          'R-CRM-02: chặn cả khi ghi thẳng vào bảng (ở cơ sở dữ liệu, không chỉ ẩn nút)');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L5')$$), 'HMT_THIEU_HOC_SINH', 'R-CRM-03: sang L5 thiếu học sinh');
select ok((select pg_temp.msg($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L5')$$)) like '%tên học sinh và năm sinh học sinh%',
          'R-CRM-03: câu lỗi nêu rõ thiếu ô nào');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L7')$$), 'HMT_THIEU_HOC_SINH', 'R-CRM-03: bấm thẳng L7 vẫn bắt học sinh (trước R-CRM-14)');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L8', 'L8A', null, null, true)$$), 'HMT_THIEU_HOC_SINH', 'R-CRM-03: bấm thẳng L8 vẫn bắt học sinh');
select is(pg_temp.err($$select pg_temp.sudo('update app.opportunity set stage_code = ''L5'' where code = ''CO000004''')$$), 'HMT_THIEU_HOC_SINH',
          'R-CRM-03: chặn cả khi ghi thẳng vào bảng');
select is(pg_temp.err($$select app.update_opportunity(pg_temp.oid('CO000004'), '{"student_name": "Em Hai", "student_birth_year": 2014}')$$), null, 'Bổ sung học sinh');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L6')$$), 'HMT_L6_HE_THONG', 'R-CRM-13: người dùng không bấm L6');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L5', 'L5B')$$), 'HMT_NHOM_CON_L5_HE_THONG', 'R-CRM-15: vào L5 không chọn tay nhóm con');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L5')$$), null, 'Sang L5 khi đủ học sinh: được');
select is((select array[stage_code, substage_code] from app.opportunity where code = 'CO000004'), array['L5', 'L5A'],
          'R-CRM-15: vào L5 hệ thống gắn nhóm con (không có phiếu nào tính được → L5A)');

-- R-CRM-35: ba ngoại lệ của đổi nhóm con cùng giai đoạn; R-CRM-34: nhóm con L6.
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L5', 'L5B')$$), 'HMT_NHOM_CON_L5_HE_THONG',
          'R-CRM-35 ngoại lệ (2) (R-CRM-15): không tay đổi nhóm con L5');
select pg_temp.sudo($$select set_config('hmt.migration', 'on', true)$$);
select pg_temp.sudo($$update app.opportunity set stage_code = 'L6', substage_code = 'L6A' where code = 'CO000002'$$);
select pg_temp.sudo($$select set_config('hmt.migration', '', true)$$);
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000002'), 'L6', 'L6B')$$), null,
          'R-CRM-34: ở L6 người dùng tự chọn L6B…L6F sau L6A (L6A → L6B)');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000002'), 'L6', 'L6A')$$), 'HMT_L6A_HE_THONG',
          'R-CRM-35 ngoại lệ (3) (R-CRM-34): người dùng không chọn lại L6A');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000002'), 'L6', 'L6C')$$), null, 'R-CRM-35: đổi nhóm con cùng giai đoạn được, L6B → L6C');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000002'), 'L6', 'L6C')$$), 'HMT_KHONG_THAY_DOI', 'Cùng nhóm con: không đổi');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000002'), 'L6')$$), 'HMT_THIEU_THONG_TIN', 'Cùng giai đoạn mà không chọn nhóm con mới: bị chặn');

-- R-CRM-14 (chưa có phiếu: coi là không có phiếu) và R-CRM-12 (mô phỏng điểm nối với phiếu).
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L7')$$), 'HMT_THIEU_LY_DO', 'R-CRM-14: không có phiếu hoàn thành thì sang L7 bắt lý do bỏ qua test');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L7', null, 'BQ5')$$), 'HMT_THIEU_GHI_CHU', 'R-CRM-14: "Khác" bắt ghi chú');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L7', null, 'KHONG_CO_MA')$$), 'HMT_DANH_MUC_KHONG_CO', 'R-CRM-14: lý do ngoài danh mục 33 bị chặn');
select pg_temp.sudo($$create or replace function app.opportunity_test_state(p_opportunity_id uuid)
  returns table (in_progress integer, completed integer, cancelled integer, in_progress_codes text[]) language sql stable
  set search_path = '' as 'select 1, 0, 0, array[''PKT000007'']::text[]'$$);
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L7', null, 'BQ1')$$), 'HMT_PHIEU_DANG_DO',
          'R-CRM-12: còn phiếu dang dở thì không sang L7 (kể cả đã chọn lý do bỏ qua)');
select ok((select pg_temp.msg($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L8', 'L8A', null, null, true)$$)) like '%PKT000007%',
          'R-CRM-12: câu lỗi nêu mã phiếu dang dở');
select pg_temp.sudo($$create or replace function app.opportunity_test_state(p_opportunity_id uuid)
  returns table (in_progress integer, completed integer, cancelled integer, in_progress_codes text[]) language sql stable
  set search_path = '' as 'select 0, 1, 0, array[]::text[]'$$);
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000002'), 'L7')$$), null,
          'R-CRM-14: có phiếu hoàn thành thì sang L7 không cần lý do bỏ qua');
select is((select skip_reason_code from app.opportunity where code = 'CO000002'), null, 'Không ghi lý do bỏ qua khi có phiếu hoàn thành');
select pg_temp.sudo($$create or replace function app.opportunity_test_state(p_opportunity_id uuid)
  returns table (in_progress integer, completed integer, cancelled integer, in_progress_codes text[]) language sql stable
  set search_path = '' as 'select 0, 0, 0, array[]::text[]'$$);
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L7', null, 'BQ1')$$), null, 'Bỏ qua test có lý do: sang L7 được');
select is((select array[stage_code, skip_reason_code] from app.opportunity where code = 'CO000004'), array['L7', 'BQ1'], 'Ghi lý do bỏ qua test');
select is((select substage_code from app.opportunity where code = 'CO000004'), null, 'Nhóm con L7 không bắt buộc');

-- Đổi nhóm con L7 qua lại có lịch sử.
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L7', 'L7B')$$), null, 'L7: chọn nhóm con L7B');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L7', 'L7C')$$), null, 'L7B → L7C');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L7', 'L7B')$$), null, 'R-CRM-35: được lùi nhóm con L7C → L7B');
select ok(pg_temp.audit_has(pg_temp.oid('CO000004'), '%L7C%'), 'Đổi nhóm con có lịch sử (nhật ký)');

-- R-CRM-16 (L8) và R-CRM-17 (không rời L8C).
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L8')$$), 'HMT_L8_CAN_NHOM_CON', 'R-CRM-16: sang L8 bắt chọn nhóm con');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L8', 'L7B', null, null, true)$$), 'HMT_L8_CAN_NHOM_CON', 'R-CRM-16: nhóm con ngoài L8A/B/C bị chặn');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L8', 'L8C')$$), 'HMT_L8_CAN_XAC_NHAN', 'R-CRM-16: sang L8 bắt xác nhận không hoàn tác');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L8', 'L8C', null, null, true)$$), null, 'Sang L8C có xác nhận: được');
select is((select array[stage_code, substage_code] from app.opportunity where code = 'CO000004'), array['L8', 'L8C'], 'Cơ hội ở L8C');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L8', 'L8A')$$), 'HMT_L8C_GIU_NGUYEN',
          'R-CRM-35 ngoại lệ (1) (R-CRM-17): đã L8C thì không rời L8C');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000004'), 'L7')$$), 'HMT_CO_HOI_KHONG_LUI', 'R-CRM-02: không lùi từ L8');
-- Cơ hội khác: L8A ⇄ L8B đổi được cả hai chiều.
select pg_temp.sudo($$select set_config('hmt.migration', 'on', true)$$);
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A', skip_reason_code = 'BQ2' where code = 'CO000003'$$);
select pg_temp.sudo($$select set_config('hmt.migration', '', true)$$);
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000003'), 'L8', 'L8B')$$), null, 'R-CRM-35: L8A → L8B được');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000003'), 'L8', 'L8A')$$), null, 'R-CRM-35: L8B → L8A (lùi) được');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000003'), 'L8', 'L8C')$$), null, 'L8A → L8C: được');
-- Quyền và bản đã gộp.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000002'), 'L7', 'L7B')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: đổi giai đoạn cơ hội cơ sở khác');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$update app.opportunity set record_status = 'DA_GOP', merged_into_id = (select id from app.opportunity where code = 'CO000001')
                       where code = 'CO000002'$$);
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000002'), 'L7', 'L7B')$$), 'HMT_BAN_GHI_DA_GOP', 'Bản đã gộp: chỉ đọc (đổi giai đoạn)');
select is(pg_temp.err($$select app.update_opportunity(pg_temp.oid('CO000002'), '{"need": "x"}')$$), 'HMT_BAN_GHI_DA_GOP', 'Bản đã gộp: chỉ đọc (sửa)');
select pg_temp.sudo($$update app.opportunity set record_status = 'DANG_DUNG', merged_into_id = null where code = 'CO000002'$$);

-- ================= Lịch hẹn gắn cơ hội (R-CRM-04) =================
select is(pg_temp.err($$select app.create_appointment(null, 'GOI_DIEN', now() + interval '1 day', 'Hẹn cơ hội', null, null, pg_temp.oid('CO000001'))$$), null,
          'Tạo lịch hẹn gắn cơ hội: được');
select ok((select next_appointment_at is not null from app.opportunity where code = 'CO000001'), '"Lịch hẹn kế tiếp" của cơ hội tự tính');
select is(pg_temp.err($$select app.create_appointment(null, 'GOI_DIEN', now(), 'x')$$), 'HMT_LICH_HEN_MO_COI', 'R-CRM-04: không có lịch hẹn mồ côi');
select is(pg_temp.err($$select app.create_appointment(pg_temp.lid('0900000101'), 'GOI_DIEN', now(), 'x', null, null, pg_temp.oid('CO000001'))$$), 'HMT_LICH_HEN_MO_COI',
          'R-CRM-04: không gắn hai hồ sơ cùng lúc');
select is(pg_temp.err($$select app.create_appointment(pg_temp.lid('0900000101'), 'GOI_DIEN', now() + interval '2 days', 'Hẹn lead')$$), null, 'Gọi như cũ (gắn lead) vẫn chạy');
select is((app.list_appointments(jsonb_build_object('opportunity_id', pg_temp.oid('CO000001'))) ->> 'total')::int, 1, 'Lọc lịch hẹn theo cơ hội');
select is((app.list_appointments(jsonb_build_object('opportunity_id', pg_temp.oid('CO000001'))) -> 'rows' -> 0 ->> 'record_code'), 'CO000001', 'Dòng lịch hẹn của cơ hội có mã hồ sơ gắn');
select ok((app.list_appointments(jsonb_build_object('opportunity_id', pg_temp.oid('CO000001'))) -> 'rows' -> 0 ->> 'record_label') like '%Chị Thử Một%',
          'Nhãn hồ sơ gắn của cơ hội: tên phụ huynh');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.create_appointment(null, 'GOI_DIEN', now(), 'x', null, null, pg_temp.oid('CO000001'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: gắn lịch hẹn vào cơ hội cơ sở khác');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$select app.complete_appointment((select id from app.appointment where opportunity_id = (select id from app.opportunity where code = 'CO000001')))$$);

-- ================= Giao người phụ trách =================
select is(app.assign_owner('OPPORTUNITY', array[pg_temp.oid('CO000001')], pg_temp.uid('sales1b')), 1, 'Giao cơ hội cho người cùng cơ sở: được');
select is((select owner_id from app.opportunity where code = 'CO000001'), pg_temp.uid('sales1b'), 'Người phụ trách mới');
select is(pg_temp.err($$select app.assign_owner('OPPORTUNITY', array[pg_temp.oid('CO000001')], pg_temp.uid('sales5'))$$), 'HMT_NGUOI_PHU_TRACH_SAI', 'Chặn: giao cho người khác cơ sở');
select is(pg_temp.err($$select app.assign_owner('OPPORTUNITY', array[]::uuid[], pg_temp.uid('sales1b'))$$), 'HMT_THIEU_THONG_TIN', 'Chặn: không chọn bản ghi');
select is(pg_temp.err($$select app.assign_owner('KHAC', array[pg_temp.oid('CO000001')], pg_temp.uid('sales1b'))$$), 'HMT_LOAI_BAN_GHI_SAI', 'Chặn: loại bản ghi lạ');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.assign_owner('OPPORTUNITY', array[pg_temp.oid('CO000001')], pg_temp.uid('sales5'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giao cơ hội cơ sở khác');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(app.assign_owner('LEAD', array[pg_temp.lid('0900000101')], pg_temp.uid('sales1b')), 1, 'Giao lead vẫn chạy như cũ');

-- ================= Danh sách, Kanban, RLS =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900000103'))$$);
select is((select count(*)::int from app.opportunity), 1, 'RLS: Tuyển sinh CS5 chỉ đọc cơ hội cơ sở mình');
select is((app.list_opportunities() ->> 'total')::int, 1, 'Danh sách: Tuyển sinh CS5 thấy 1 cơ hội');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((select count(*)::int from app.opportunity where branch_id = (select id from app.branch where code = 'CS5')), 0, 'RLS: Tuyển sinh CS1 không đọc cơ hội CS5');
select is((app.list_opportunities() ->> 'total')::int, (select count(*)::int from app.opportunity where record_status = 'DANG_DUNG'),
          'Danh sách ẩn bản đã gộp mặc định, đếm đúng');
select is(jsonb_array_length(app.list_opportunities('{}', 'created_desc', 2, 0) -> 'rows'), 2, 'Phân trang: cỡ trang 2 trả 2 dòng');
select ok((app.list_opportunities('{}', 'created_desc', 2, 0) ->> 'total')::int > 2, 'Phân trang: tổng đếm cả bảng');
select is(jsonb_array_length(app.list_opportunities('{}', 'created_desc', 100000, 0) -> 'rows') <= 100, true, 'Cỡ trang quá lớn bị cắt về tối đa');
select is((app.list_opportunities('{"stage": ["L8"]}') ->> 'total')::int, 2, 'Lọc theo giai đoạn');
select is((app.list_opportunities('{"mine": true}') ->> 'total')::int,
          (select count(*)::int from app.opportunity where owner_id = pg_temp.uid('sales1') and record_status = 'DANG_DUNG'), 'Lọc "của tôi"');
select is((app.list_opportunities('{"q": "me co san"}') ->> 'total')::int, 1, 'Tìm không dấu theo tên phụ huynh');
select pg_temp.sudo($$update app.parent set full_name = 'Phụ Huynh Đổi Tên' where code = 'PH900004'$$);
select is((app.list_opportunities('{"q": "doi ten"}') ->> 'total')::int, 1, 'Phụ huynh đổi tên thì ô tìm kiếm của cơ hội đổi theo');
select is((app.list_opportunities('{"q": "me co san"}') ->> 'total')::int, 0, 'Tên cũ không còn khớp');
select is((app.list_opportunities('{"no_appointment": true}') ->> 'total')::int,
          (select count(*)::int from app.opportunity where next_appointment_at is null and record_status = 'DANG_DUNG'), 'Lọc "chưa có lịch hẹn"');
select is(jsonb_array_length(app.opportunity_board()), 8, 'Kanban: đủ 8 cột L1–L8, một lần gọi');
select is((select sum((c ->> 'total')::int)::int from jsonb_array_elements(app.opportunity_board()) c),
          (select count(*)::int from app.opportunity where record_status = 'DANG_DUNG'), 'Kanban: tổng các cột bằng tổng cơ hội đang dùng');
select is((select max(jsonb_array_length(c -> 'rows')) from jsonb_array_elements(app.opportunity_board('{}', 1)) c), 1, 'Kanban: mỗi cột tối đa số thẻ yêu cầu');
select is((select c ->> 'name' from jsonb_array_elements(app.opportunity_board()) c limit 1), 'Khách hàng mới', 'Kanban: cột đầu là L1');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((select sum((c ->> 'total')::int)::int from jsonb_array_elements(app.opportunity_board()) c), 1, 'Kanban: Tuyển sinh CS5 chỉ thấy cơ hội cơ sở mình');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.list_opportunities()$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không xem danh sách cơ hội');
select is(pg_temp.err($$select app.opportunity_board()$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không xem Kanban cơ hội');
select is((select count(*)::int from app.opportunity), 0, 'RLS: giáo viên không đọc được cơ hội nào');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.list_opportunities('{"include_merged": true}') ->> 'total')::int, (select count(*)::int from app.opportunity), 'ADMIN (toàn hệ thống) thấy mọi cơ hội');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.list_opportunities() ->> 'total')::int, (select count(*)::int from app.opportunity where record_status = 'DANG_DUNG'), 'Trưởng cơ sở CS1 thấy cơ hội cơ sở mình');
select is(pg_temp.err($$select app.change_opportunity_stage(pg_temp.oid('CO000001'), 'L4')$$), null, 'Trưởng cơ sở CS1 đổi giai đoạn cơ hội cơ sở mình: được');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900000105'))$$), null, 'CSKH CS1 tạo cơ hội: được');

-- Ghi chú, lịch sử gắn cơ hội: quyền xem theo cơ sở của cơ hội.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(app.can_see_note_target('OPPORTUNITY', pg_temp.oid('CO000001')), true, 'Ghi chú cơ hội: người cùng cơ sở xem được');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(app.can_see_note_target('OPPORTUNITY', pg_temp.oid('CO000001')), false, 'Ghi chú cơ hội: người khác cơ sở không xem được');

select * from finish();
rollback;
