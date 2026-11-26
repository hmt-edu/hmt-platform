-- B-26-03 PR-DB1: sản phẩm (mã tự do, danh sách khối, thông tin gợi ý), dòng báo giá/đơn chụp môn và khối đã chọn,
-- danh sách sản phẩm bán trả đủ. Mỗi luật có ca đúng và ca bị chặn.
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
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1'), ('teacher1'), ('teacher5'), ('hs'), ('ke');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999999' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5'), ('ke', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT'), ('ke', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);



select pg_temp.sudo($$create function pg_temp.audit_has(p_table text, p_id uuid, p_like text) returns boolean language sql stable security definer as
  'select exists (select from app.audit_log a join app.audited_table t on t.id = a.table_id where t.table_name = p_table and a.record_id = p_id and a.action = ''U'' and a.changes::text like p_like)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.audit_has(text, uuid, text) to public$$);
select pg_temp.sudo($$create function pg_temp.pkg(p_code text) returns uuid language sql stable security definer as 'select id from app.sales_package where code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.pol(p_code text) returns uuid language sql stable security definer as 'select id from app.discount_policy where code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.gpol(p_code text) returns uuid language sql stable security definer as 'select id from app.gift_policy where code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as 'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone order by o.code limit 1'$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable security definer as 'select id from app.lead where parent_phone = p_phone order by code limit 1'$$);
-- Dòng em thứ n của cơ hội theo SĐT phụ huynh.
select pg_temp.sudo($$create function pg_temp.ps(p_phone text, p_pos integer) returns uuid language sql stable security definer as
  'select ps.id from app.prospect_student ps where ps.opportunity_id = pg_temp.oid(p_phone) and ps.position = p_pos'$$);
select pg_temp.sudo($$create function pg_temp.qid(p_code text) returns uuid language sql stable security definer as 'select id from app.quotation where code = p_code'$$);
select pg_temp.sudo($$grant execute on function pg_temp.pkg(text), pg_temp.pol(text), pg_temp.gpol(text), pg_temp.oid(text), pg_temp.lid(text),
  pg_temp.ps(text, integer), pg_temp.qid(text) to public$$);
select pg_temp.sudo($$create function pg_temp.docs(p_opp uuid) returns text[] language sql stable security definer as 'select app.opportunity_sales_documents(p_opp)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.docs(uuid) to public$$);
-- Dựng một dòng báo giá gửi vào save_quotation.
create function pg_temp.line(p_ps uuid, p_pkg text, p_mode text, p_qty numeric, p_disc jsonb default '[]'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('kind', 'ENROL', 'prospect_student_id', p_ps, 'package_id', pg_temp.pkg(p_pkg), 'delivery_mode_code', p_mode,
                            'quantity', p_qty, 'discounts', p_disc) $$;
grant execute on function pg_temp.line(uuid, text, text, numeric, jsonb) to public;
create function pg_temp.disc(p_policy text, p_value numeric default null) returns jsonb language sql as $$
  select jsonb_build_object('policy_id', pg_temp.pol(p_policy), 'value', p_value) $$;
grant execute on function pg_temp.disc(text, numeric) to public;
create temp table qs (key text primary key, id uuid, code text);
grant all on qs to public;
-- Lưu báo giá mới cho một cơ hội và nhớ lại theo khoá.
create function pg_temp.mk(p_key text, p_phone text, p_lines jsonb) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := app.save_quotation(null, pg_temp.oid(p_phone), p_lines);
  insert into qs values (p_key, (r ->> 'id')::uuid, r ->> 'code');
  return r;
end $$;
grant execute on function pg_temp.mk(text, text, jsonb) to public;
create function pg_temp.q(p_key text) returns uuid language sql stable as $$ select id from qs where key = p_key $$;
grant execute on function pg_temp.q(text) to public;

-- Đ173: Bán hàng bật ở CS1 cho bài (seed thường chỉ bật CS5).
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- ================= Dựng dữ liệu =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900011001', '{"parent_name": "Chị Xem Thử", "student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900011002', '{"parent_name": "Chị Xem Thử Hai", "student_name": "Em Hai", "student_birth_year": 2013}'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900011099', '{"parent_name": "Chị Xem Thử CS5", "student_name": "Em Chín", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900011001'));
select app.create_opportunity(pg_temp.lid('0900011002'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900011099'));
-- Cơ hội 1 có thêm em thứ hai; cơ hội 1 ở L5 và có một phiếu kiểm tra Toán khối 9 (gợi ý theo cơ hội).
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Hai', 2014 from app.opportunity o where o.id = pg_temp.oid('0900011001')$$);
select pg_temp.sudo($$update app.opportunity set stage_code = 'L5', substage_code = 'L5A' where id = pg_temp.oid('0900011001')$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_student_test(pg_temp.oid('0900011001'), jsonb_build_object('subject_code', 'TOAN', 'grade_code', 'K09', 'mode_code', 'OFFLINE',
  'level_code', 'CO_BAN', 'exam_name', 'Toán 9', 'scheduled_at', now() + interval '3 days'));


-- ================= Sản phẩm: mã, khối (anh chốt SP1) =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
create function pg_temp.sp(p_code text, p_extra jsonb) returns text language sql as $$
  select pg_temp.err(format('select app.save_sales_package(null, %L::jsonb)',
    jsonb_build_object('code', p_code, 'name', 'SP thử ' || p_code, 'package_type_code', 'LC', 'subject_code', 'TOAN') || p_extra)) $$;
grant execute on function pg_temp.sp(text, jsonb) to public;
create function pg_temp.col(p_code text) returns jsonb language sql stable security definer as $$
  select to_jsonb(p) from app.sales_package p where p.code = p_code $$;
grant execute on function pg_temp.col(text) to public;

select is(pg_temp.sp('TOAN-LC-9', '{"grade_codes": ["K09"]}'), null, 'Mã sản phẩm theo file (không ép Loại-Môn-Khối): được');
select is(pg_temp.sp('toan lc 9', '{"grade_codes": ["K09"]}'), '23514', 'Mã vẫn phải đúng dạng chữ in và gạch nối: mã sai bị chặn');
select is(pg_temp.sp('TOAN-LC-9', '{"grade_codes": ["K09"]}'), 'HMT_MA_GOI_TRUNG', 'Mã trùng thì chặn');
select throws_ok($$select pg_temp.sudo('update app.sales_package set code = ''TOAN-LC-9X'' where code = ''TOAN-LC-9''')$$, null, null, 'Mã sản phẩm không đổi được');
select is(pg_temp.col('TOAN-LC-9') ->> 'grade_label', '9', 'Nhãn khối tự lấy từ danh mục khi không nhập');
select is(pg_temp.col('TOAN-LC-9') ->> 'grade_from_code', 'K09', 'Khối ghép lớp suy ra từ danh sách khối');

select is(pg_temp.sp('TOAN-V12-TH1', '{"grade_codes": ["K07","K03","K05NC","K04","K05","K06"], "grade_label": "3, 4, 5, 5NC, 6, 7"}'), null, 'Sản phẩm dải khối có 5NC: được');
select is(pg_temp.col('TOAN-V12-TH1') -> 'grade_codes', '["K03","K04","K05","K05NC","K06","K07"]'::jsonb, 'Danh sách khối sắp theo thứ tự danh mục');
select is((pg_temp.col('TOAN-V12-TH1') ->> 'grade_from_code') || '-' || (pg_temp.col('TOAN-V12-TH1') ->> 'grade_to_code'), 'K03-K07', '5NC thuộc khối 5 khi ghép lớp');
select is(pg_temp.sp('TOAN-ROI', '{"grade_codes": ["K03","K07"]}'), 'HMT_KHOI_KHONG_LIEN', 'Khối rời nhau thì chặn');
select isnt(pg_temp.sp('TOAN-SAI', '{"grade_codes": ["K99"]}'), null, 'Khối ngoài danh mục Khối của sản phẩm thì chặn');
select is(pg_temp.sp('TOAN-V12-SAT', '{"grade_codes": ["SAT"]}'), null, 'SAT: được');
select is(pg_temp.col('TOAN-V12-SAT') ->> 'grade_from_code', null, 'Chuyên sâu, Toán tiếng Anh, SAT không ràng khối khi ghép lớp');
select is(pg_temp.sp('TOAN-LC-12HSA', '{"grade_codes": ["K12_HSA"]}'), null, '12 HSA: được');
select is(pg_temp.col('TOAN-LC-12HSA') ->> 'grade_from_code', 'K12', '12 HSA thuộc khối 12');
select is(pg_temp.sp('TOAN-KHONGKHOI', '{}'), null, 'Sản phẩm giờ học không bắt buộc khối');
select is(pg_temp.sp('TOAN-THIEUMON', '{"subject_code": "", "grade_codes": ["K09"]}'), 'HMT_THIEU_THONG_TIN', 'Sản phẩm giờ học thiếu môn thì chặn');
select is(pg_temp.sp('TOAN-CU', '{"grade_from_code": "K05", "grade_to_code": "K07"}'), null, 'Cách nhập khối đầu, khối cuối vẫn dùng được');
select is(pg_temp.col('TOAN-CU') -> 'grade_codes', '["K05","K06","K07"]'::jsonb, 'Khối đầu, cuối suy ra danh sách khối');
select is(pg_temp.sp('TOAN-NGUOC', '{"grade_from_code": "K09", "grade_to_code": "K05"}'), 'HMT_KHOI_SAI', 'Khối đầu lớn hơn khối cuối thì chặn');
select is(pg_temp.sp('DV-THU', '{"package_type_code": "DV", "subject_code": "", "grade_codes": ["K09"]}'), 'HMT_GOI_KHONG_DOI', 'Dịch vụ gắn khối thì chặn');
select is(pg_temp.sp('TL-THU', '{"package_type_code": "TL", "subject_code": ""}'), null, 'Tài liệu không môn, không khối: được');
select is(pg_temp.err($$select app.save_sales_package(pg_temp.pkg('TOAN-LC-9'), '{"grade_codes": ["K08"]}')$$), 'HMT_GOI_KHONG_DOI', 'Khối của sản phẩm không đổi được');
-- Thông tin gợi ý.
select is(pg_temp.err($$select app.save_sales_package(pg_temp.pkg('TOAN-LC-9'), '{"hours_per_month": 16, "standard_class_size": 15, "hours_per_session": 2, "sessions_per_week": 1, "note": "ghi chú"}')$$), null, 'Sửa thông tin gợi ý: được');
select is(pg_temp.col('TOAN-LC-9') ->> 'standard_class_size', '15', 'Sĩ số chuẩn đã lưu');
select is(pg_temp.err($$select app.save_sales_package(pg_temp.pkg('TOAN-LC-9'), '{"hours_per_month": 0}')$$), '23514', 'Giờ mỗi tháng phải lớn hơn 0');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.sp('TOAN-SALE', '{}'), 'HMT_KHONG_CO_QUYEN', 'Sale không tạo được sản phẩm');
-- Giá.
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.add_package_price(pg_temp.pkg(c), 'OFF', 220000, date '2026-01-01') from unnest(array['TOAN-LC-9','TOAN-V12-TH1','TOAN-V12-SAT']) c;

-- ================= Dòng báo giá, đơn chụp môn và khối đã chọn =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
create function pg_temp.gl(p_pkg text, p_grade text) returns jsonb language sql as $$
  select jsonb_build_array(pg_temp.line(pg_temp.ps('0900011001', 1), p_pkg, 'OFF', 10)
         || case when p_grade is null then '{}'::jsonb else jsonb_build_object('grade_code', p_grade) end) $$;
grant execute on function pg_temp.gl(text, text) to public;
create function pg_temp.ql(p_key text, p_col text) returns text language sql stable security definer as $$
  select to_jsonb(l) ->> p_col from app.quotation_line l where l.quotation_id = pg_temp.q(p_key) and l.line_no = 1 $$;
grant execute on function pg_temp.ql(text, text) to public;

select pg_temp.mk('r', '0900011001', pg_temp.gl('TOAN-V12-TH1', 'K05'));
select is(pg_temp.ql('r', 'grade_code'), 'K05', 'Dòng sản phẩm dải chụp khối đã chọn');
select is(pg_temp.ql('r', 'subject_code'), 'TOAN', 'Dòng chụp môn của sản phẩm');
select is(pg_temp.ql('r', 'package_type_code'), 'LC', 'Dòng chụp loại lớp');
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.oid('0900011001'), pg_temp.gl('TOAN-V12-TH1', 'K09'))$$), 'HMT_KHOI_KHONG_THUOC_SAN_PHAM', 'Máy chủ chặn khối không thuộc sản phẩm');
select pg_temp.mk('one', '0900011001', pg_temp.gl('TOAN-LC-9', null));
select is(pg_temp.ql('one', 'grade_code'), 'K09', 'Sản phẩm một khối: tự điền khối');
select pg_temp.mk('open', '0900011001', pg_temp.gl('TOAN-V12-TH1', null));
select is(pg_temp.ql('open', 'grade_code'), null, 'Sản phẩm dải chưa chọn khối: để trống, không đoán');
select pg_temp.mk('sat', '0900011001', pg_temp.gl('TOAN-V12-SAT', null));
select is(pg_temp.ql('sat', 'grade_code'), 'SAT', 'Khối SAT chụp đúng mã');

-- Chuyển báo giá thành đơn: sao nguyên môn, khối (R-TIEN-14).
select app.send_quotation(pg_temp.q('r'));
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id = pg_temp.oid('0900011001')$$);
create temp table od as select (app.create_order_from_quotation(pg_temp.q('r')) ->> 'id')::uuid as id;
grant select on od to public;
create function pg_temp.ol(p_no integer, p_col text) returns text language sql stable security definer as $$
  select to_jsonb(l) ->> p_col from app.sales_order_line l where l.order_id = (select id from od) and l.line_no = p_no $$;
grant execute on function pg_temp.ol(integer, text) to public;
select is(pg_temp.ol(1, 'grade_code') || '/' || pg_temp.ol(1, 'subject_code'), 'K05/TOAN', 'Đơn từ báo giá sao nguyên khối, môn');
-- Viết lại toàn bộ dòng đơn (hàm save_order gọi).
select pg_temp.sudo($def$create function pg_temp.viet(p_grade text) returns text language sql security definer as $$
  select pg_temp.err(format('select app.order_write_priced_lines(%L, pg_temp.oid(''0900011001''), %L, %L::jsonb, current_date)',
    (select id from od), (select branch_id from app.sales_order where id = (select id from od)), pg_temp.gl('TOAN-V12-TH1', p_grade))) $$$def$);
select pg_temp.sudo($$grant execute on function pg_temp.viet(text) to public$$);
select is(pg_temp.viet('K07'), null, 'Ghi dòng đơn chọn khối trong dải: được');
select is(pg_temp.ol(1, 'grade_code'), 'K07', 'Dòng đơn chụp khối đã chọn');
select is(pg_temp.viet('K12'), 'HMT_KHOI_KHONG_THUOC_SAN_PHAM', 'Đơn: khối ngoài sản phẩm bị chặn');
select lives_ok($$select pg_temp.sudo('select app.order_add_priced_line((select id from od), pg_temp.oid(''0900011001''), (select branch_id from app.sales_order where id = (select id from od)), pg_temp.gl(''TOAN-V12-TH1'', ''K03'') -> 0, current_date)')$$, 'Thêm dòng vào đơn: được');
select is(pg_temp.ol(2, 'grade_code'), 'K03', 'Dòng thêm vào đơn chụp khối đã chọn');

-- ================= Danh sách sản phẩm bán: trả đủ, thứ tự ổn định =================
select is((select x ->> 'grade_label' from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x where x ->> 'code' = 'TOAN-V12-TH1'),
          '3, 4, 5, 5NC, 6, 7', 'Danh sách trả nhãn khối');
select is((select x -> 'grade_codes' ->> 0 from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x where x ->> 'code' = 'TOAN-V12-TH1'),
          'K03', 'Danh sách trả danh sách khối');
select pg_temp.sudo($$update app.setting_def set value = '20' where key = 'list_page_size_max'$$);
select pg_temp.sudo($$insert into app.sales_package (code, name, package_type_code, subject_code)
  select 'ZZ-THU-' || n, 'Sản phẩm thử ' || n, 'LC', 'TOAN' from generate_series(1, 25) n$$);
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'OFF', 100000, date '2026-01-01' from app.sales_package where code like 'ZZ-THU-%'$$);
select ok((app.list_sellable_packages(pg_temp.oid('0900011001')) ->> 'total')::int > 20, 'Có hơn 20 sản phẩm bán để thử cỡ trang');
select is(jsonb_array_length(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages'),
          (app.list_sellable_packages(pg_temp.oid('0900011001')) ->> 'total')::int, 'Không cắt mất sản phẩm khi số sản phẩm vượt cỡ trang');
select is((select array_agg(x ->> 'code' order by ord) from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') with ordinality t(x, ord)),
          (select array_agg(x ->> 'code' order by x ->> 'code') from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x), 'Danh sách sắp theo mã');
select is((select string_agg(x ->> 'code', ',') from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001'), null, 'th1') -> 'packages') x), 'TOAN-V12-TH1', 'Tìm theo mã');

select * from finish();
rollback;
