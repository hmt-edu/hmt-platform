-- P5a-DB0 (cấu hình bán hàng): gói, bảng giá có ngày hiệu lực, chiết khấu, quà tặng, điều khoản thanh toán, đơn vị, danh mục,
-- tham số, phiên bản ma trận quyền (QĐ-Đ100 đến Đ107; R-TIEN-07, 10, 14, 15, 29, 30, 36).
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò đọc, ghi trong và ngoài phạm vi.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.term_amounts(p uuid, t bigint) returns table (seq integer, due_days integer, amount bigint) language sql security definer as $$ select * from app.payment_term_amounts(p, t) $$;
create function pg_temp.price_at(p uuid, m text, d date) returns bigint language sql security definer as $$ select app.package_price_at(p, m, d) $$;

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
create function pg_temp.pkg(p_code text) returns uuid language sql stable security definer as $$ select id from app.sales_package where code = p_code $$;
grant execute on function pg_temp.pkg(text) to public;
create function pg_temp.pol(p_code text) returns uuid language sql stable security definer as $$ select id from app.discount_policy where code = p_code $$;
grant execute on function pg_temp.pol(text) to public;

-- ================= Danh mục, tham số =================
select is((select count(*)::int from app.catalog_item where catalog_code = 'PACKAGE_UNIT'), 3, 'Đ101: danh mục đơn vị có giờ, tháng, bộ');
select is(app.package_unit('DV'), 'THANG', 'Đ101: gói dịch vụ tính theo tháng');
select is(app.package_unit('TL'), 'BO', 'Đ101: gói tài liệu tính theo bộ');
select is(app.package_unit('LC') || app.package_unit('VIP') || app.package_unit('VNN') || app.package_unit('KR'), 'GIOGIOGIOGIO', 'Đ101: các gói còn lại tính theo giờ');
select is((select count(*)::int from app.catalog_item where catalog_code = 'ORDER_CANCEL_REASON'), 6, 'Đ104: Lý do huỷ đơn có sáu lý do');
select ok((select requires_note from app.catalog_item where catalog_code = 'ORDER_CANCEL_REASON' and code = 'KHAC'), 'Đ104: "Khác" bắt buộc ghi chú (R-HT-04)');
select is((select name from app.catalog_item where catalog_code = 'ORDER_CANCEL_REASON' and code = 'KHACH_DOI_Y'), 'Khách đổi ý, không đăng ký nữa', 'Đ104: chữ lý do đúng');
select is((select applies_to from app.catalog_item where catalog_code = 'REJECT_REASON' and code = 'SAI_SO_TIEN'), array['PHIEU_THU'], 'Đ103: "Sai số tiền" chỉ phiếu thu');
select is((select applies_to from app.catalog_item where catalog_code = 'REJECT_REASON' and code = 'SAI_CHUNG_TU'), array['PHIEU_THU'], 'Đ103: "Sai chứng từ" chỉ phiếu thu');
select is((select applies_to from app.catalog_item where catalog_code = 'REJECT_REASON' and code = 'KHONG_DUNG_CHINH_SACH'), array['BAO_GIA', 'DON'], 'Đ103: "Không đúng chính sách" chỉ báo giá, đơn');
select is((select count(*)::int from app.catalog_item where catalog_code = 'REJECT_REASON' and code in ('THIEU_THONG_TIN', 'KHAC') and applies_to = '{}'), 2, 'Đ103: "Thiếu thông tin" và "Khác" dùng chung, applies_to trống');
select is((select value from app.setting_def where key = 'debt_due_soon_days'), '3', 'Đ107: debt_due_soon_days mặc định 3');
select is((select array[min_value, max_value] from app.setting_def where key = 'debt_due_soon_days'), array[1::numeric, 30], 'Đ107: khoảng 1 đến 30');
select is((select allow_branch_override from app.setting_def where key = 'debt_due_soon_days'), false, 'Đ107: không ghi đè theo cơ sở');
select throws_ok($$insert into app.setting_branch (setting_key, branch_id, value) select 'debt_due_soon_days', id, '5' from app.branch where code = 'CS1'$$,
                 null, null, 'Đ107: đặt ghi đè theo cơ sở bị từ chối');

-- ================= Ma trận quyền: phiên bản mới (Đ105) =================
select ok((select count(*) from app.permission_version) >= 1, 'Có lịch sử phiên bản ma trận');
select ok(exists (select from app.permission_version where note like 'Đ105:%'), 'Đ105: phiên bản mới có ghi chú');
select is((select count(*)::int from app.permission where is_active and module_code = 'QUOTATION' and action_code = 'XUAT' and role_code in ('SALES', 'CSKH')), 0, 'Đ105: Sale và CSKH không còn Xuất báo giá');
select is((select count(*)::int from app.permission where is_active and module_code = 'QUOTATION' and action_code = 'XEM' and role_code in ('SALES', 'CSKH')), 2, 'Đ105: Sale và CSKH vẫn Xem (in) báo giá của mình');
select is((select scope_code from app.permission where is_active and module_code = 'QUOTATION' and action_code = 'XUAT' and role_code = 'BRANCH_MANAGER'), 'CO_SO', 'Đ105: Trưởng cơ sở Xuất báo giá ở cơ sở mình');
select is((select scope_code from app.permission where is_active and module_code = 'QUOTATION' and action_code = 'XUAT' and role_code = 'ACCOUNTANT'), 'TOAN_HE_THONG', 'Đ105: Kế toán Xuất báo giá');
select is((select scope_code from app.permission where is_active and module_code = 'QUOTATION' and action_code = 'XEM' and role_code = 'ACCOUNTANT'), 'TOAN_HE_THONG', 'Đ105 (f): Kế toán Xem báo giá toàn hệ thống');
select is((select count(*)::int from app.permission where is_active and module_code = 'QUOTATION' and action_code = 'XUAT' and role_code = 'ADMIN'), 1, 'Đ105: Admin Xuất báo giá');
select is((select string_agg(role_code, ',' order by role_code) from app.permission where is_active and module_code = 'SALES_ORDER' and action_code = 'XUAT'), 'ACCOUNTANT,ADMIN,BRANCH_MANAGER', 'Đ105: Xuất đơn chỉ Kế toán, Admin, Trưởng cơ sở');
select is((select string_agg(role_code, ',' order by role_code) from app.permission where is_active and module_code = 'RECEIPT' and action_code = 'XUAT'), 'ACCOUNTANT,ADMIN,BRANCH_MANAGER', 'Đ105: Xuất phiếu thu chỉ Kế toán, Admin, Trưởng cơ sở');

-- ================= Gói (R-TIEN-10, 15; spec 02) =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select lives_ok($$select app.save_sales_package(null, '{"code": "LC-TOAN-K08", "name": "Lớp chung Toán 8", "package_type_code": "LC", "subject_code": "TOAN", "grade_from_code": "K08"}')$$, 'Admin tạo gói lớp chung');
select is(pg_temp.err($$select app.save_sales_package(null, '{"code": "LC-TOAN-K09", "name": "x", "package_type_code": "LC", "subject_code": "TOAN", "grade_from_code": "K09"}')$$), 'HMT_MA_GOI_TRUNG', 'Mã gói đã có (gói mẫu) thì chặn');
select lives_ok($$select app.save_sales_package(null, '{"code": "VIP-TOAN-K05K09", "name": "VIP Toán 5 đến 9", "package_type_code": "VIP", "subject_code": "TOAN", "grade_from_code": "K05", "grade_to_code": "K09"}')$$, 'Gói nhiều khối: mã Loại-Môn-KhốiđầuKhốicuối');
select lives_ok($$select app.save_sales_package(null, '{"code": "LC-TOAN-K09-OFF", "name": "x", "package_type_code": "LC", "subject_code": "TOAN", "grade_from_code": "K09"}')$$, 'B-26-03: không ép mã Loại-Môn-Khối (mã LC-TOAN-K09-OFF tạo được)');
select lives_ok($$select app.save_sales_package(null, '{"code": "LC-VAN-K10", "name": "x", "package_type_code": "LC", "subject_code": "TOAN", "grade_from_code": "K10"}')$$, 'B-26-03: không ép mã Loại-Môn-Khối (mã LC-VAN-K10 tạo được)');
select is(pg_temp.err($$select app.save_sales_package(null, '{"code": "LC-TOAN-K09K05", "name": "x", "package_type_code": "LC", "subject_code": "TOAN", "grade_from_code": "K09", "grade_to_code": "K05"}')$$), 'HMT_KHOI_SAI', 'Khối đầu lớn hơn khối cuối thì chặn');
select isnt(pg_temp.err($$select app.save_sales_package(null, '{"code": "XX-TOAN-K10", "name": "x", "package_type_code": "XX", "subject_code": "TOAN", "grade_from_code": "K10"}')$$), null, 'Loại gói phải thuộc danh mục');
select is(pg_temp.err($$select app.save_sales_package(null, '{"code": "LC-TOAN-K10", "name": " ", "package_type_code": "LC", "subject_code": "TOAN", "grade_from_code": "K10"}')$$), 'HMT_THIEU_THONG_TIN', 'Thiếu tên gói thì chặn');
select lives_ok($$select app.save_sales_package(null, '{"code": "DV-HOTRO", "name": "Hỗ trợ học tập", "package_type_code": "DV"}')$$, 'Gói dịch vụ không gắn môn, khối');
select is(pg_temp.err($$select app.save_sales_package(null, '{"code": "DV-LOI", "name": "x", "package_type_code": "DV", "subject_code": "TOAN"}')$$), 'HMT_GOI_KHONG_DOI', 'Gói dịch vụ có môn thì chặn');
select is(pg_temp.err($$select app.save_sales_package(pg_temp.pkg('LC-TOAN-K08'), '{"name": "Toán 8 đổi tên", "legacy_ref": "GOI-8"}')$$), null, 'Sửa tên, mã cũ của gói: được');
select is((select name from app.sales_package where code = 'LC-TOAN-K08'), 'Toán 8 đổi tên', 'Tên gói đã đổi');
select is(pg_temp.err($$select app.save_sales_package(pg_temp.pkg('LC-TOAN-K08'), '{"grade_from_code": "K07"}')$$), 'HMT_GOI_KHONG_DOI', 'Loại, môn, khối của gói không đổi được');
select throws_ok($$update app.sales_package set name = 'x' where code = 'LC-TOAN-K08'$$, '42501', null, 'Người dùng không ghi trực tiếp bảng gói');

-- ================= Bảng giá có ngày hiệu lực (R-TIEN-10, 14) =================
select lives_ok($$select app.add_package_price(pg_temp.pkg('LC-TOAN-K08'), 'OFF', 200000, date '2026-01-01')$$, 'Thêm giá offline');
select lives_ok($$select app.add_package_price(pg_temp.pkg('LC-TOAN-K08'), 'OFF', 230000, date '2026-10-01')$$, 'Thêm giá offline mới từ ngày sau');
select lives_ok($$select app.add_package_price(pg_temp.pkg('LC-TOAN-K08'), 'ONL', 110000, date '2025-01-01')$$, 'Giá có thể ở quá khứ (g)');
select is(pg_temp.price_at(pg_temp.pkg('LC-TOAN-K08'), 'OFF', date '2026-09-30'), 200000::bigint, 'Giá theo ngày: trước ngày hiệu lực mới vẫn giá cũ (R-TIEN-14)');
select is(pg_temp.price_at(pg_temp.pkg('LC-TOAN-K08'), 'OFF', date '2026-10-01'), 230000::bigint, 'Giá theo ngày: từ ngày hiệu lực dùng giá mới');
select is(pg_temp.price_at(pg_temp.pkg('LC-TOAN-K08'), 'OFF', date '2025-12-31'), null, 'Chưa có giá tại ngày đó thì null (không bán)');
select is(pg_temp.price_at(pg_temp.pkg('LC-TOAN-K08'), 'ONL', date '2026-06-01'), 110000::bigint, 'Một gói hai giá: giá online riêng giá offline');
select is(pg_temp.err($$select app.add_package_price(pg_temp.pkg('LC-TOAN-K08'), 'OFF', 999000, date '2026-10-01')$$), 'HMT_GIA_DA_CO', 'Trùng (gói, hình thức, ngày) thì chặn');
select is(pg_temp.err($$select app.add_package_price(pg_temp.pkg('LC-TOAN-K08'), 'OFF', 0, date '2027-01-01')$$), 'HMT_GIA_SAI', 'Giá không dương thì chặn');
select is(pg_temp.err($$select app.add_package_price(pg_temp.pkg('LC-TOAN-K08'), 'OFF', 100000, null)$$), 'HMT_THIEU_THONG_TIN', 'Thiếu ngày hiệu lực thì chặn');
select lives_ok($$select app.add_package_price(pg_temp.pkg('LC-TOAN-K08'), 'ONL', null, date '2026-07-01')$$, 'Giá trống: ngừng bán hình thức online từ ngày đó');
select is(pg_temp.price_at(pg_temp.pkg('LC-TOAN-K08'), 'ONL', date '2026-07-01'), null, 'Giá trống = không bán hình thức đó');
select is(pg_temp.price_at(pg_temp.pkg('LC-TOAN-K08'), 'ONL', date '2026-06-30'), 110000::bigint, 'Trước ngày ngừng bán vẫn có giá');
select is(pg_temp.err($$select app.add_package_price(pg_temp.pkg('DV-HOTRO'), 'ONL', 100000, date '2026-01-01')$$), 'HMT_GOI_KHONG_CO_ONLINE', 'R-TIEN-15: gói dịch vụ không có giá online');
select isnt(pg_temp.err($$select app.add_package_price(pg_temp.pkg('LC-TOAN-K08'), 'XX', 100000, date '2026-01-01')$$), null, 'Hình thức phải thuộc danh mục');
select pg_temp.sudo($$set local hmt.migration = ''$$);
select throws_ok($$select pg_temp.sudo('update app.package_price set unit_price = 1 where unit_price = 200000')$$, null, null, 'R-TIEN-14: giá đã tạo không sửa được');
select throws_ok($$select pg_temp.sudo('delete from app.package_price where unit_price = 200000')$$, null, null, 'Giá đã tạo không xoá được');

-- ================= Chính sách chiết khấu (R-TIEN-29, 36; Đ102) =================
select lives_ok($$select app.save_discount_policy(null, '{"code": "GIAM_THU", "name": "Giảm thử", "kind": "PERCENT", "max_value": 8, "fixed_value": true, "requires_approval": false, "valid_from": "2026-09-01", "package_type_codes": ["LC", "VIP"]}')$$, 'Tạo chính sách phần trăm áp đúng mức');
select lives_ok($$select app.save_discount_policy(null, '{"code": "TANG_THU", "name": "Tặng giờ thử", "kind": "GIFT_HOURS", "max_value": 4, "valid_from": "2026-09-01", "requires_approval": true}')$$, 'Tạo chính sách tặng giờ (nhân viên điền)');
select is(pg_temp.err($$select app.save_discount_policy(null, '{"code": "TANG_CODINH", "name": "x", "kind": "GIFT_HOURS", "max_value": 4, "fixed_value": true, "valid_from": "2026-09-01"}')$$), 'HMT_CHINH_SACH_SAI', 'R-TIEN-36: tặng giờ luôn loại điền, không "áp đúng mức"');
select is(pg_temp.err($$select app.save_discount_policy(null, '{"code": "VUOT_100", "name": "x", "kind": "PERCENT", "max_value": 120, "valid_from": "2026-09-01"}')$$), 'HMT_CHINH_SACH_SAI', 'Phần trăm tối đa không quá 100');
select is(pg_temp.err($$select app.save_discount_policy(null, '{"code": "GIAM_THU", "name": "x", "kind": "PERCENT", "max_value": 5, "valid_from": "2026-09-01"}')$$), 'HMT_MA_TRUNG', 'Mã chính sách trùng thì chặn');
select is(pg_temp.err($$select app.save_discount_policy(null, '{"code": "NGAY_SAI", "name": "x", "kind": "PERCENT", "max_value": 5, "valid_from": "2026-09-01", "valid_to": "2026-08-01"}')$$), 'HMT_NGAY_HIEU_LUC_SAI', 'Ngày hết hiệu lực trước ngày bắt đầu thì chặn');
select isnt(pg_temp.err($$select app.save_discount_policy(null, '{"code": "LOAI_SAI", "name": "x", "kind": "PERCENT", "max_value": 5, "valid_from": "2026-09-01", "package_type_codes": ["XX"]}')$$), null, 'Loại gói áp dụng phải thuộc danh mục');
select is(pg_temp.err($$select app.save_discount_policy(null, '{"code": "KIND_SAI", "name": "x", "kind": "TIEN", "max_value": 5, "valid_from": "2026-09-01"}')$$), 'HMT_CHINH_SACH_SAI', 'Loại chính sách chỉ phần trăm hoặc tặng giờ');
select is(pg_temp.err($$select app.save_discount_policy(pg_temp.pol('GIAM_THU'), '{"max_value": 9, "requires_approval": true}')$$), null, 'Sửa chính sách: được');
select is((select array[max_value::text, requires_approval::text] from app.discount_policy where code = 'GIAM_THU'), array['9.00', 'true'], 'Chính sách đã sửa');
select is(pg_temp.err($$select app.save_discount_policy(pg_temp.pol('GIAM_THU'), '{"kind": "GIFT_HOURS"}')$$), 'HMT_CHINH_SACH_KHONG_DOI', 'Loại chính sách không đổi được');
select lives_ok($$select app.save_discount_policy(null, '{"code": "CO_SO_THU", "name": "Theo cơ sở", "kind": "PERCENT", "max_value": 3, "valid_from": "2026-09-01", "branch_ids": []}')$$, 'Để trống cơ sở = mọi cơ sở');
select is(pg_temp.err($$select app.save_discount_policy(null, '{"code": "CS_SAI", "name": "x", "kind": "PERCENT", "max_value": 3, "valid_from": "2026-09-01", "branch_ids": ["00000000-0000-0000-0000-000000000000"]}')$$), 'HMT_CO_SO_SAI', 'Cơ sở áp dụng phải có thật');

-- ================= Chính sách quà tặng (R-TIEN-30) =================
select lives_ok($$select app.save_gift_policy(null, jsonb_build_object('code', 'QUA_THU', 'name', 'Quà thử', 'gift_package_id', pg_temp.pkg('TL-MATOAN'), 'max_quantity', 2, 'valid_from', '2026-09-01'))$$, 'Tạo quà tặng là gói tài liệu');
select lives_ok($$select app.save_gift_policy(null, jsonb_build_object('code', 'QUA_DV_THU', 'name', 'Quà dịch vụ', 'gift_package_id', pg_temp.pkg('DV-CSGK'), 'max_quantity', 1, 'valid_from', '2026-09-01'))$$, 'Tạo quà tặng là gói dịch vụ');
select is(pg_temp.err($$select app.save_gift_policy(null, jsonb_build_object('code', 'QUA_SAI', 'name', 'x', 'gift_package_id', pg_temp.pkg('LC-TOAN-K09'), 'max_quantity', 1, 'valid_from', '2026-09-01'))$$), 'HMT_QUA_TANG_SAI', 'R-TIEN-30: quà tặng không phải gói giờ học');
select is(pg_temp.err($$select app.save_gift_policy(null, jsonb_build_object('code', 'QUA_0', 'name', 'x', 'gift_package_id', pg_temp.pkg('TL-MATOAN'), 'max_quantity', 0, 'valid_from', '2026-09-01'))$$), 'HMT_CHINH_SACH_SAI', 'Số lượng tối đa phải lớn hơn 0');
select is(pg_temp.err($$select app.save_gift_policy(null, jsonb_build_object('code', 'QUA_THU', 'name', 'x', 'gift_package_id', pg_temp.pkg('TL-MATOAN'), 'max_quantity', 1, 'valid_from', '2026-09-01'))$$), 'HMT_MA_TRUNG', 'Mã quà tặng trùng thì chặn');

-- ================= Điều khoản thanh toán (R-TIEN-07; Đ117 c) =================
select lives_ok($$select app.create_payment_term('CHIA_HAI', 'Hai đợt 50, 50', date '2026-09-01', '[{"seq": 1, "share_percent": 50, "due_days": 0}, {"seq": 2, "share_percent": 50, "due_days": 30}]')$$, 'Tạo điều khoản toàn phần trăm');
select lives_ok($$select app.create_payment_term('COC_THU', 'Cọc rồi chia', date '2026-09-01', '[{"seq": 1, "fixed_amount": 1000000, "due_days": 0}, {"seq": 2, "share_percent": 60, "due_days": 15}, {"seq": 3, "share_percent": 40, "due_days": 45}]')$$, 'Tạo điều khoản: đợt 1 cọc cố định, các đợt sau chia %');
select is(pg_temp.err($$select app.create_payment_term('CHIA_HAI', 'x', date '2026-09-01', '[{"seq": 1, "share_percent": 100, "due_days": 0}]')$$), null, 'Cùng mã: tạo được bản mới');
select is((select max(version) from app.payment_term where code = 'CHIA_HAI'), 2, 'Bản mới của cùng mã có version 2');
select is(pg_temp.err($$select app.create_payment_term('TONG_SAI', 'x', date '2026-09-01', '[{"seq": 1, "share_percent": 50, "due_days": 0}, {"seq": 2, "share_percent": 40, "due_days": 30}]')$$), 'HMT_DIEU_KHOAN_SAI', 'Tổng phần trăm không đủ 100 thì chặn');
select is(pg_temp.err($$select app.create_payment_term('SEQ_SAI', 'x', date '2026-09-01', '[{"seq": 1, "share_percent": 50, "due_days": 0}, {"seq": 3, "share_percent": 50, "due_days": 30}]')$$), 'HMT_DIEU_KHOAN_SAI', 'Đợt không liên tục thì chặn');
select is(pg_temp.err($$select app.create_payment_term('HAI_KIEU', 'x', date '2026-09-01', '[{"seq": 1, "share_percent": 50, "fixed_amount": 5, "due_days": 0}, {"seq": 2, "share_percent": 50, "due_days": 30}]')$$), 'HMT_DIEU_KHOAN_SAI', 'Một đợt vừa % vừa số tiền thì chặn');
select is(pg_temp.err($$select app.create_payment_term('TIEN_DOT_2', 'x', date '2026-09-01', '[{"seq": 1, "share_percent": 50, "due_days": 0}, {"seq": 2, "fixed_amount": 500000, "due_days": 30}]')$$), 'HMT_DIEU_KHOAN_SAI', 'Số tiền cố định chỉ ở đợt 1');
select is(pg_temp.err($$select app.create_payment_term('COC_MOT_DOT', 'x', date '2026-09-01', '[{"seq": 1, "fixed_amount": 500000, "due_days": 0}]')$$), 'HMT_DIEU_KHOAN_SAI', 'Đợt 1 cố định mà không có đợt sau thì chặn');
select is(pg_temp.err($$select app.create_payment_term('NGAY_AM', 'x', date '2026-09-01', '[{"seq": 1, "share_percent": 100, "due_days": -1}]')$$), 'HMT_DIEU_KHOAN_SAI', 'Số ngày đến hạn âm thì chặn');
select is(pg_temp.err($$select app.create_payment_term('RONG', 'x', date '2026-09-01', '[]')$$), 'HMT_DIEU_KHOAN_SAI', 'Không có đợt nào thì chặn');
select is((select string_agg(amount::text, ',' order by seq) from pg_temp.term_amounts((select id from app.payment_term where code = 'CHIA_HAI' and version = 1), 10000000)), '5000000,5000000', 'Cách tính: hai đợt 50, 50');
select is((select string_agg(amount::text || '/' || due_days, ',' order by seq) from pg_temp.term_amounts((select id from app.payment_term where code = 'COC_THU'), 10000000)), '1000000/0,5400000/15,3600000/45', 'Cách tính: cọc 1.000.000, phần còn lại 9.000.000 chia 60%, 40%');
select is((select sum(amount) from pg_temp.term_amounts((select id from app.payment_term where code = 'COC_THU'), 1234567)), 1234567::numeric, 'Cách tính: đợt cuối nhận phần dư, tổng đúng bằng tổng đơn');
select is(pg_temp.err($$select * from pg_temp.term_amounts((select id from app.payment_term where code = 'COC_THU'), 1000000)$$), 'HMT_COC_VUOT_DON', 'Cách tính: tiền cọc không nhỏ hơn tổng đơn thì chặn');
select is(pg_temp.err($$select * from pg_temp.term_amounts((select id from app.payment_term where code = 'COC_THU'), 0)$$), 'HMT_TONG_DON_SAI', 'Cách tính: tổng đơn phải lớn hơn 0');
select throws_ok($$select pg_temp.sudo('update app.payment_term_installment set due_days = 99')$$, null, null, 'Đợt đã tạo không sửa được (chỉ thêm bản mới)');
select throws_ok($$select pg_temp.sudo('update app.payment_term set name = ''đổi tên'' where code = ''COC_THU''')$$, null, null, 'Điều khoản đã tạo không đổi tên');

-- ================= Ngừng, dùng lại (không xoá) =================
select is(pg_temp.err($$select app.set_config_active('PACKAGE', pg_temp.pkg('DV-HOTRO'), false)$$), null, 'Ngừng gói');
select is((select is_active from app.sales_package where code = 'DV-HOTRO'), false, 'Gói đã ngừng');
select is(pg_temp.err($$select app.add_package_price(pg_temp.pkg('DV-HOTRO'), 'OFF', 100000, date '2026-01-01')$$), 'HMT_GOI_DA_NGUNG', 'Gói đã ngừng thì không thêm giá mới');
select is(pg_temp.err($$select app.set_config_active('PACKAGE', pg_temp.pkg('DV-HOTRO'), true)$$), null, 'Dùng lại gói');
select is(pg_temp.err($$select app.set_config_active('DISCOUNT_POLICY', pg_temp.pol('GIAM_THU'), false)$$), null, 'Ngừng chính sách chiết khấu');
select is(pg_temp.err($$select app.set_config_active('PAYMENT_TERM', (select id from app.payment_term where code = 'CHIA_HAI' and version = 1), false)$$), null, 'Ngừng điều khoản');
select is(pg_temp.err($$select app.set_config_active('KHAC', pg_temp.pkg('DV-HOTRO'), false)$$), 'HMT_LOAI_CAU_HINH_SAI', 'Loại cấu hình lạ thì chặn');
select is(pg_temp.err($$select app.set_config_active('PACKAGE', '00000000-0000-0000-0000-000000000000', false)$$), 'HMT_KHONG_TIM_THAY', 'Ngừng mục không có thì báo không tìm thấy');

-- ================= Nhật ký =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select ok(pg_temp.audit_has('app.sales_package', pg_temp.pkg('LC-TOAN-K08'), '%Toán 8 đổi tên%'), 'Mọi sửa cấu hình ghi nhật ký (gói)');
select ok(pg_temp.audit_has('app.discount_policy', pg_temp.pol('GIAM_THU'), '%requires_approval%'), 'Mọi sửa cấu hình ghi nhật ký (chiết khấu)');

-- ================= Vai trò: đọc, ghi trong và ngoài phạm vi =================
select ok((select count(*) from app.sales_package) >= 5, 'Admin đọc được gói');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select ok((select count(*) from app.sales_package) >= 5, 'Sale đọc được gói');
select ok((select count(*) from app.package_price) >= 5, 'Sale đọc được bảng giá');
select ok((select count(*) from app.discount_policy) >= 3, 'Sale đọc được chiết khấu');
select ok((select count(*) from app.payment_term_installment) >= 5, 'Sale đọc được đợt thanh toán');
select is(pg_temp.err($$select app.save_sales_package(null, '{"code": "LC-TOAN-K07", "name": "x", "package_type_code": "LC", "subject_code": "TOAN", "grade_from_code": "K07"}')$$), 'HMT_KHONG_CO_QUYEN', 'Sale không tạo được gói');
select is(pg_temp.err($$select app.add_package_price(pg_temp.pkg('LC-TOAN-K08'), 'OFF', 1, date '2030-01-01')$$), 'HMT_KHONG_CO_QUYEN', 'Sale không thêm được giá');
select is(pg_temp.err($$select app.save_discount_policy(null, '{"code": "SALE_THU", "name": "x", "kind": "PERCENT", "max_value": 1, "valid_from": "2026-09-01"}')$$), 'HMT_KHONG_CO_QUYEN', 'Sale không tạo được chiết khấu');
select is(pg_temp.err($$select app.create_payment_term('SALE_THU', 'x', date '2026-09-01', '[{"seq": 1, "share_percent": 100, "due_days": 0}]')$$), 'HMT_KHONG_CO_QUYEN', 'Sale không tạo được điều khoản');
select is(pg_temp.err($$select app.set_config_active('PACKAGE', pg_temp.pkg('DV-HOTRO'), false)$$), 'HMT_KHONG_CO_QUYEN', 'Sale không ngừng được gói');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select ok((select count(*) from app.sales_package) >= 5, 'CSKH đọc được gói');
select is(pg_temp.err($$select app.save_gift_policy(null, jsonb_build_object('code', 'CSKH_THU', 'name', 'x', 'gift_package_id', pg_temp.pkg('TL-MATOAN'), 'max_quantity', 1, 'valid_from', '2026-09-01'))$$), 'HMT_KHONG_CO_QUYEN', 'CSKH không tạo được quà tặng');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select ok((select count(*) from app.sales_package) >= 5, 'Trưởng cơ sở đọc được gói');
select is(pg_temp.err($$select app.save_sales_package(null, '{"code": "LC-TOAN-K07", "name": "x", "package_type_code": "LC", "subject_code": "TOAN", "grade_from_code": "K07"}')$$), 'HMT_KHONG_CO_QUYEN', 'Trưởng cơ sở không tạo được gói');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select ok((select count(*) from app.package_price) >= 5, 'Kế toán đọc được bảng giá');
select is(pg_temp.err($$select app.add_package_price(pg_temp.pkg('LC-TOAN-K08'), 'OFF', 1, date '2030-01-01')$$), 'HMT_KHONG_CO_QUYEN', 'Kế toán không thêm được giá');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is((select count(*)::int from app.sales_package), 0, 'Giáo viên đọc ra 0 gói');
select is((select count(*)::int from app.package_price) + (select count(*)::int from app.discount_policy) + (select count(*)::int from app.gift_policy)
          + (select count(*)::int from app.payment_term) + (select count(*)::int from app.payment_term_installment), 0, 'Giáo viên đọc ra 0 dòng cấu hình bán hàng');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is((select count(*)::int from app.sales_package), 0, 'Học sinh đọc ra 0 gói');
select is(pg_temp.err($$select app.add_package_price(pg_temp.pkg('LC-TOAN-K08'), 'OFF', 1, date '2030-01-01')$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không thêm được giá');

select * from finish();
rollback;
