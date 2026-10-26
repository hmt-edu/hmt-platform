-- P5a-DB1a (báo giá): lưu, tính tiền, gửi, từ chối, huỷ; danh sách, bản ghi, xuất; giấy tờ của cơ hội (QĐ-Đ83, Đ93, Đ101, Đ102, Đ105, Đ106,
-- Đ169 đến Đ174; R-CRM-19, 20, 22; R-TIEN-02, 05, 10, 13, 14, 15, 29, 30, 35, 36). Mỗi luật có ca đúng và ca bị chặn; mỗi vai đọc, ghi trong và ngoài phạm vi.
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
select app.create_lead(pg_temp.lead_data('0900004001', '{"parent_name": "Chị Báo Giá A", "student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900004002', '{"parent_name": "Chị Báo Giá B", "student_name": "Em Bốn", "student_birth_year": 2010}'));
select app.create_lead(pg_temp.lead_data('0900004010', '{"parent_name": "Chị Gộp Báo Giá", "student_name": "Em Gộp", "student_birth_year": 2011}'));
select app.create_lead(pg_temp.lead_data('0900004010', '{"parent_name": "Chị Gộp Báo Giá", "student_name": "Em Gộp Hai", "student_birth_year": 2011}'), true);
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900004099', '{"parent_name": "Chị Báo Giá CS5", "student_name": "Em Chín", "student_birth_year": 2012}'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900004001'));
select app.create_opportunity(pg_temp.lid('0900004002'));
select app.create_opportunity((select id from app.lead where parent_phone = '0900004010' order by code limit 1));
select app.create_opportunity((select id from app.lead where parent_phone = '0900004010' order by code desc limit 1), '{}'::jsonb, true);
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900004099'));
-- Cơ hội A có thêm hai em (danh sách em, DB-2 sẽ có hàm thêm): Em Hai đủ thông tin, Em Ba thiếu năm sinh.
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Hai', 2014 from app.opportunity o where o.id = pg_temp.oid('0900004001')$$);
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name)
  select o.id, o.branch_id, 3, 'Em Ba' from app.opportunity o where o.id = pg_temp.oid('0900004001')$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= Lưu báo giá: tính tiền (R-TIEN-13, 14, 36) =================
select is(pg_temp.err($$select pg_temp.mk('a1', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 48, jsonb_build_array(pg_temp.disc('GIAM_6_THANG')))))$$), null, 'Lưu báo giá mới: được');
select ok((select code from qs where key = 'a1') ~ '^BG-CS1-\d{4}-\d{4}$', 'R-CRM-19: mã BG-CS1-AAMM-STT cấp lúc Lưu');
select is((select status_code from app.quotation where id = pg_temp.q('a1')), 'NHAP', 'Báo giá mới là Nháp');
select is((select array[q.branch_id = o.branch_id, q.parent_id = o.parent_id] from app.quotation q join app.opportunity o on o.id = q.opportunity_id where q.id = pg_temp.q('a1')), array[true, true], 'Báo giá lấy cơ sở và phụ huynh của cơ hội');
select is((select array[l.unit_code, l.quantity::text, l.unit_price::text, l.gross_amount::text, l.discount_percent::text, l.discount_amount::text, l.line_total::text]
            from app.quotation_line l where l.quotation_id = pg_temp.q('a1')),
          array['GIO', '48.00', '220000', '10560000', '5.00', '528000', '10032000'], 'R-TIEN-36: thành tiền = giờ mua × đơn giá; trừ 5% (áp đúng mức): 10.032.000 đ');
select is((select total_amount from app.quotation where id = pg_temp.q('a1')), 10032000::bigint, 'Tổng báo giá tính ở máy chủ');
select is((select count(*)::int from app.quotation_line_discount d join app.quotation_line l on l.id = d.line_id where l.quotation_id = pg_temp.q('a1') and d.policy_code = 'GIAM_6_THANG'), 1, 'Chính sách áp trên dòng được chụp lại');
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.oid('0900004001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 48, jsonb_build_array(pg_temp.disc('GIAM_6_THANG', 1)))))$$), null, 'Chính sách "áp đúng mức": giá trị gửi lên bị bỏ qua');
select is((select discount_percent from app.quotation_line where quotation_id = (select id from app.quotation order by created_at desc limit 1)), 5.00::numeric, '"Áp đúng mức" lấy đúng mức tối đa (5%), không theo số gửi lên');

-- Đ172: tiền chiết khấu làm tròn xuống đồng.
select pg_temp.mk('r1', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 0.33, jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 3.33)))));
select is((select array[gross_amount::text, discount_amount::text, line_total::text] from app.quotation_line where quotation_id = pg_temp.q('r1')),
          array['72600', '2417', '70183'], 'Đ172: 72.600 × 3,33% = 2.417,58 làm tròn xuống 2.417 đ');

-- R-TIEN-29: chiết khấu cộng dồn; giờ tặng tính vào trần; vượt trần chỉ cảnh báo.
select pg_temp.mk('c1', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 48, jsonb_build_array(pg_temp.disc('GIAM_6_THANG'), pg_temp.disc('GIAM_THUONG_LUONG', 10)))));
select is((select discount_percent from app.quotation_line where quotation_id = pg_temp.q('c1')), 15.00::numeric, 'R-TIEN-29: 5% + 10% cộng dồn thành 15%');
select is((select over_cap from app.quotation_line where quotation_id = pg_temp.q('c1')), false, 'R-TIEN-29: 15% chưa vượt trần 20%');
select is((select needs_acknowledgement from app.quotation_line where quotation_id = pg_temp.q('c1')), true, 'Đ102: chính sách cần duyệt thì cần người duyệt tích đồng ý');
select is((select count(*)::int from app.quotation_line_discount d join app.quotation_line l on l.id = d.line_id where l.quotation_id = pg_temp.q('c1')), 2, 'Hai chính sách % cùng áp trên một dòng');
select is(app.save_quotation(pg_temp.q('c1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 48,
          jsonb_build_array(pg_temp.disc('GIAM_6_THANG'), pg_temp.disc('GIAM_THUONG_LUONG', 10), pg_temp.disc('TANG_GIO', 4))))) -> 'warnings' -> 0 ->> 'code', 'HMT_VUOT_TRAN',
          'R-TIEN-29: 15% + giờ tặng 4/48 (8,33%) vượt trần 20%: vẫn lưu, trả cảnh báo HMT_VUOT_TRAN (D3)');
select is((select array[gift_percent::text, over_cap::text, needs_acknowledgement::text, gifted_quantity::text] from app.quotation_line where quotation_id = pg_temp.q('c1')),
          array['8.33', 'true', 'true', '4.00'], 'Giờ tặng quy ra % = giờ tặng ÷ giờ mua và tính vào trần');
select is((select discount_amount from app.quotation_line where quotation_id = pg_temp.q('c1')), 1584000::bigint, 'Giờ tặng không trừ tiền: chỉ chiết khấu % trừ tiền (15% của 10.560.000)');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('c1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 48,
          jsonb_build_array(pg_temp.disc('GIAM_6_THANG'), pg_temp.disc('GIAM_THUONG_LUONG', 6), pg_temp.disc('TANG_GIO', 4)))))$$), null, 'Không vượt trần (5% + 6% + 8,33% = 19,33%): lưu được');
select is((select over_cap from app.quotation_line where quotation_id = pg_temp.q('c1')), false, 'Chưa vượt trần thì over_cap false');
select pg_temp.sudo($$insert into app.discount_policy (code, name, kind, max_value, valid_from) values ('TANG_GIO_HAI', 'Tặng giờ khác', 'GIFT_HOURS', 2, date '2026-09-01')$$);
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('c1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 48,
          jsonb_build_array(pg_temp.disc('TANG_GIO', 2), pg_temp.disc('TANG_GIO_HAI', 1)))))$$), 'HMT_CHI_MOT_CHINH_SACH_TANG_GIO', 'Đ174: một dòng chỉ dùng một chính sách tặng giờ');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('c1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 48,
          jsonb_build_array(pg_temp.disc('GIAM_6_THANG'), pg_temp.disc('GIAM_6_THANG')))))$$), 'HMT_CHINH_SACH_TRUNG', 'Một chính sách không chọn hai lần trên một dòng');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('c1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 48,
          jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 11)))))$$), 'HMT_CHIET_KHAU_VUOT_MUC', 'Vượt mức tối đa của chính sách thì chặn (R-TIEN-36)');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('c1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 48,
          jsonb_build_array(pg_temp.disc('TANG_GIO', 5)))))$$), 'HMT_CHIET_KHAU_VUOT_MUC', 'Tặng giờ vượt mức tối đa thì chặn');
select pg_temp.sudo($$insert into app.discount_policy (code, name, kind, max_value, valid_from, valid_to) values ('HET_HAN', 'Hết hạn', 'PERCENT', 3, date '2025-01-01', date '2025-12-31')$$);
select pg_temp.sudo($$insert into app.discount_policy (code, name, kind, max_value, valid_from, package_type_codes) values ('CHI_VIP', 'Chỉ VIP', 'PERCENT', 3, date '2026-01-01', array['VIP'])$$);
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('c1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 48, jsonb_build_array(pg_temp.disc('HET_HAN', 3)))))$$), 'HMT_CHINH_SACH_KHONG_AP_DUNG', 'Chính sách hết hiệu lực thì chặn');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('c1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 48, jsonb_build_array(pg_temp.disc('CHI_VIP', 3)))))$$), 'HMT_CHINH_SACH_KHONG_AP_DUNG', 'Chính sách không áp cho loại gói này thì chặn');

-- Đ101, R-TIEN-15, R-TIEN-30: đơn vị theo loại gói; quà tặng.
select pg_temp.mk('u1', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'DV-CSGK', 'OFF', 3), pg_temp.line(pg_temp.ps('0900004001', 1), 'TL-MATOAN', 'OFF', 1)));
select is((select array_agg(unit_code order by line_no) from app.quotation_line where quotation_id = pg_temp.q('u1')), array['THANG', 'BO'], 'Đ101: dịch vụ theo tháng, tài liệu theo bộ; dòng chụp lại đơn vị');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('u1'), null, jsonb_build_array(jsonb_build_object('kind', 'GIFT', 'prospect_student_id', pg_temp.ps('0900004001', 1), 'gift_policy_id', pg_temp.gpol('QUA_TAI_LIEU'), 'quantity', 1),
          pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 10)))$$), null, 'Dòng quà tặng: lưu được');
select is((select array[line_kind, unit_price::text, line_total::text, package_code, over_cap::text] from app.quotation_line where quotation_id = pg_temp.q('u1') and line_no = 1),
          array['GIFT', '0', '0', 'TL-MATOAN', 'false'], 'R-TIEN-30: quà tặng giá 0 đ, ngoài trần');
select is((select total_amount from app.quotation where id = pg_temp.q('u1')), 2200000::bigint, 'Tổng không tính quà tặng');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('u1'), null, jsonb_build_array(jsonb_build_object('kind', 'GIFT', 'prospect_student_id', pg_temp.ps('0900004001', 1), 'gift_policy_id', pg_temp.gpol('QUA_TAI_LIEU'), 'quantity', 2)))$$), 'HMT_CHIET_KHAU_VUOT_MUC', 'Quà tặng vượt số lượng tối đa thì chặn');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('u1'), null, jsonb_build_array(jsonb_build_object('kind', 'GIFT', 'prospect_student_id', pg_temp.ps('0900004001', 1), 'quantity', 1)))$$), 'HMT_DONG_THIEU', 'Quà tặng thiếu chính sách thì chặn');

-- R-TIEN-10, 12: giá theo hình thức; gói ngừng.
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('u1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'VIP-TOAN-K03K07', 'OFF', 10)))$$), 'HMT_HINH_THUC_KHONG_CO_GIA', 'R-TIEN-10: gói không bán hình thức đó thì chặn');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('u1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'VIP-TOAN-K03K07', 'ONL', 10)))$$), null, 'Hình thức có giá thì lưu được');
select pg_temp.sudo($$update app.sales_package set is_active = false where code = 'TL-MATOAN'$$);
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('u1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'TL-MATOAN', 'OFF', 1)))$$), 'HMT_GOI_DA_NGUNG', 'Gói đã ngừng thì chặn');
select pg_temp.sudo($$update app.sales_package set is_active = true where code = 'TL-MATOAN'$$);
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('u1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 0)))$$), 'HMT_DONG_THIEU', 'Số lượng 0 thì chặn');

-- Đ83: em chọn trong danh sách em của cơ hội; Đ93: báo giá Nháp cho phép em chưa đủ thông tin.
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('u1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004002', 1), 'LC-TOAN-K09', 'OFF', 10)))$$), 'HMT_EM_NGOAI_DANH_SACH', 'Đ83: em của cơ hội khác thì chặn, gợi ý thêm em ở cơ hội');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('u1'), null, jsonb_build_array(pg_temp.line(null, 'LC-TOAN-K09', 'OFF', 10)))$$), 'HMT_DONG_THIEU', 'Dòng thiếu học sinh thì chặn');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('u1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 3), 'LC-TOAN-K09', 'OFF', 10)))$$), null, 'Đ93: báo giá Nháp lưu được với em thiếu năm sinh');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('u1'), null, '[]'::jsonb)$$), null, 'Lưu báo giá Nháp chưa có dòng: được');
select is((select total_amount from app.quotation where id = pg_temp.q('u1')), 0::bigint, 'Báo giá không dòng có tổng 0');
select is(pg_temp.err($$select app.save_quotation(null, '00000000-0000-0000-0000-000000000000', '[]'::jsonb)$$), 'HMT_KHONG_TIM_THAY', 'Cơ hội không có thì báo không tìm thấy');

-- Đ169: Nháp tính giá theo bảng giá hiệu lực lúc Lưu; Gửi rồi thì đóng băng (R-TIEN-14).
select pg_temp.mk('p1', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'ONL', 10)));
select is((select unit_price from app.quotation_line where quotation_id = pg_temp.q('p1')), 120000::bigint, 'Giá online hiệu lực lúc lưu: 120.000');
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'ONL', 130000, (now() at time zone 'Asia/Ho_Chi_Minh')::date from app.sales_package where code = 'LC-TOAN-K09'$$);
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('p1'), null, jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'ONL', 10)))$$), null, 'Lưu lại báo giá Nháp');
select is((select unit_price from app.quotation_line where quotation_id = pg_temp.q('p1')), 130000::bigint, 'Đ169: Nháp lưu lại thì tính theo bảng giá hiệu lực lúc lưu (130.000)');
select is((select priced_on from app.quotation where id = pg_temp.q('p1')), (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'Ngày tính giá là ngày lưu');
select is(pg_temp.err($$select app.send_quotation(pg_temp.q('p1'))$$), null, 'Gửi báo giá: được');
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'ONL', 999000, ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 1) from app.sales_package where code = 'LC-TOAN-K09'$$);
select is((select unit_price from app.quotation_line where quotation_id = pg_temp.q('p1')), 130000::bigint, 'Đ169, R-TIEN-14: sau Gửi, đổi bảng giá không ảnh hưởng báo giá');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('p1'), null, '[]'::jsonb)$$), 'HMT_BAO_GIA_DA_KHOA', 'Báo giá đã gửi không lưu lại được');
select throws_ok($$select pg_temp.sudo('update app.quotation_line set quantity = 99 where quotation_id = pg_temp.q(''p1'')')$$, null, null, 'Dòng của báo giá đã gửi bị khoá (trigger)');
select throws_ok($$select pg_temp.sudo('delete from app.quotation_line where quotation_id = pg_temp.q(''p1'')')$$, null, null, 'Không xoá được dòng của báo giá đã gửi');

-- Gửi báo giá (R-TIEN-05; Đ170).
select is((select status_code from app.quotation where id = pg_temp.q('p1')), 'DA_GUI', 'Sau Gửi: trạng thái Đã gửi');
select is((select valid_until from app.quotation where id = pg_temp.q('p1')), (now() at time zone 'Asia/Ho_Chi_Minh')::date + 14, 'R-TIEN-05: hạn = ngày Gửi + quotation_validity_days (14)');
select ok((select sent_at is not null and sent_by is not null from app.quotation where id = pg_temp.q('p1')), 'Ghi người gửi, giờ gửi');
select is(pg_temp.err($$select app.send_quotation(pg_temp.q('p1'))$$), 'HMT_SAI_TRANG_THAI', 'Gửi lần hai thì chặn');
select pg_temp.mk('e1', '0900004001', '[]'::jsonb);
select is(pg_temp.err($$select app.send_quotation(pg_temp.q('e1'))$$), 'HMT_BAO_GIA_KHONG_DONG', 'Gửi báo giá không có dòng thì chặn');
select pg_temp.mk('i1', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 10), pg_temp.line(pg_temp.ps('0900004001', 3), 'LC-TOAN-K09', 'OFF', 10)));
select is(pg_temp.err($$select app.send_quotation(pg_temp.q('i1'))$$), 'HMT_EM_THIEU_THONG_TIN', 'Đ170: gửi khi còn em thiếu năm sinh thì chặn');
select ok(pg_temp.msg($$select app.send_quotation(pg_temp.q('i1'))$$) like '%Dòng 2: thiếu năm sinh của em%', 'Đ170: báo đúng dòng, đúng ô thiếu');
select pg_temp.sudo($$update app.prospect_student set birth_year = 2013 where opportunity_id = pg_temp.oid('0900004001') and position = 3$$);
select is(pg_temp.err($$select app.send_quotation(pg_temp.q('i1'))$$), null, 'Bổ sung năm sinh ở danh sách em thì gửi được');
select pg_temp.sudo($$update app.prospect_student set birth_year = null where opportunity_id = pg_temp.oid('0900004001') and position = 3$$);

-- R-TIEN-05: không có Hết hạn, quá hạn chỉ là nhãn.
select pg_temp.sudo($$update app.quotation set valid_until = (now() at time zone 'Asia/Ho_Chi_Minh')::date - 5 where id = pg_temp.q('i1')$$);
select is(app.get_quotation(pg_temp.q('i1')) ->> 'status_code', 'DA_GUI', 'R-TIEN-05: quá hạn không đổi trạng thái (không có Hết hạn)');
select is((app.get_quotation(pg_temp.q('i1')) ->> 'overdue_days')::int, 5, 'Nhãn "Đã quá hạn N ngày": N = 5');
select is((select count(*)::int from app.catalog_item where catalog_code = 'QUOTATION_STATUS' and code = 'HET_HAN'), 0, 'Danh mục trạng thái báo giá không có Hết hạn');

-- Từ chối (R-HT-04).
select pg_temp.mk('j1', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 10)));
select is(pg_temp.err($$select app.reject_quotation(pg_temp.q('j1'), 'THIEU_THONG_TIN', null)$$), 'HMT_SAI_TRANG_THAI', 'Từ chối báo giá Nháp thì chặn (chỉ Đã gửi)');
select app.send_quotation(pg_temp.q('j1'));
select is(pg_temp.err($$select app.reject_quotation(pg_temp.q('j1'), 'SAI_SO_TIEN', null)$$), 'HMT_LY_DO_THIEU', 'Lý do dành cho phiếu thu không dùng cho báo giá (Đ103)');
select is(pg_temp.err($$select app.reject_quotation(pg_temp.q('j1'), 'KHAC', null)$$), 'HMT_LY_DO_THIEU', '"Khác" bắt buộc ghi chú (R-HT-04)');
select is(pg_temp.err($$select app.reject_quotation(pg_temp.q('j1'), null, null)$$), 'HMT_LY_DO_THIEU', 'Thiếu lý do thì chặn');
select is(pg_temp.err($$select app.reject_quotation(pg_temp.q('j1'), 'KHONG_DUNG_CHINH_SACH', null)$$), null, 'Lý do "Không đúng chính sách" dùng được cho báo giá: từ chối được');
select is((select array[status_code, reject_reason_code] from app.quotation where id = pg_temp.q('j1')), array['TU_CHOI', 'KHONG_DUNG_CHINH_SACH'], 'Báo giá Từ chối kèm lý do');
select is(pg_temp.err($$select app.send_quotation(pg_temp.q('j1'))$$), 'HMT_SAI_TRANG_THAI', 'Báo giá Từ chối không gửi lại (không có "Tạo lại")');
select pg_temp.mk('j2', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 10)));
select app.send_quotation(pg_temp.q('j2'));
select is(pg_temp.err($$select app.reject_quotation(pg_temp.q('j2'), 'KHAC', 'Phụ huynh chọn nơi khác')$$), null, '"Khác" có ghi chú thì từ chối được');

-- Huỷ (R-CRM-19, Đ171).
select pg_temp.mk('h1', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 10)));
select is(pg_temp.err($$select app.cancel_quotation(pg_temp.q('h1'), 'Tạo nhầm')$$), null, 'Huỷ báo giá Nháp: được');
select is((select array[status_code, cancel_note] from app.quotation where id = pg_temp.q('h1')), array['HUY', 'Tạo nhầm'], 'Báo giá Huỷ kèm ghi chú');
select is((select count(*)::int from app.quotation where id = pg_temp.q('h1')), 1, 'Huỷ không xoá cứng');
select is(pg_temp.err($$select app.cancel_quotation(pg_temp.q('h1'))$$), 'HMT_SAI_TRANG_THAI', 'Huỷ lần hai thì chặn');
select is(pg_temp.err($$select app.cancel_quotation(pg_temp.q('p1'))$$), null, 'Huỷ báo giá Đã gửi: được');
select is(pg_temp.err($$select app.cancel_quotation(pg_temp.q('j1'))$$), null, 'Huỷ báo giá Từ chối: được');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('h1'), null, '[]'::jsonb)$$), 'HMT_BAO_GIA_DA_KHOA', 'Báo giá Huỷ không sửa được');
select throws_ok($$select pg_temp.sudo('delete from app.quotation where id = pg_temp.q(''h1'')')$$, null, null, 'Không xoá cứng báo giá');
select throws_ok($$select pg_temp.sudo('update app.quotation set status_code = ''TU_CHOI'' where id = pg_temp.q(''e1'')')$$, null, null, 'Bảng chuyển trạng thái: Nháp không sang Từ chối (trigger)');
select throws_ok($$select pg_temp.sudo('update app.quotation set status_code = ''NHAP'' where id = pg_temp.q(''h1'')')$$, null, null, 'Bảng chuyển trạng thái: Huỷ không quay lại (trigger)');
select throws_ok($$select pg_temp.sudo('update app.quotation set code = ''BG-SAI'' where id = pg_temp.q(''e1'')')$$, null, null, 'Mã báo giá không đổi (spec 02)');

-- Ràng buộc bảng.
select throws_ok($$select pg_temp.sudo('insert into app.quotation_line (quotation_id, line_no, line_kind, package_id, package_code, package_name, package_type_code, delivery_mode_code, unit_code, quantity, unit_price, gross_amount, line_total, gift_policy_id, prospect_student_id) select q.id, 99, ''GIFT'', p.id, ''x'', ''x'', ''TL'', ''OFF'', ''BO'', 1, 5, 5, 5, null, null from app.quotation q, app.sales_package p limit 1')$$, '23514', null, 'Dòng GIFT phải có chính sách quà và giá 0');
select throws_ok($$select pg_temp.sudo('insert into app.quotation_line (quotation_id, line_no, package_id, package_code, package_name, package_type_code, delivery_mode_code, unit_code, quantity, unit_price, gross_amount, line_total) select q.id, 98, p.id, ''x'', ''x'', ''LC'', ''OFF'', ''GIO'', 1, 5, 5, 5 from app.quotation q, app.sales_package p limit 1')$$, '23514', null, 'Dòng phải có em trong danh sách hoặc hồ sơ học sinh');

-- ================= Quyền và RLS =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select pg_temp.mk('cs1', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 10)))$$), null, 'CSKH tạo báo giá trong cơ sở mình: được');
select ok((select count(*) from app.quotation) >= 5, 'CSKH đọc được báo giá cơ sở mình');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((select count(*)::int from app.quotation where branch_id = (select id from app.branch where code = 'CS1')), 0, 'Sale CS5 không đọc được báo giá CS1 (RLS)');
select is((select count(*)::int from app.quotation_line l where l.branch_id = (select id from app.branch where code = 'CS1')), 0, 'Sale CS5 không đọc được dòng báo giá CS1');
select is(pg_temp.err($$select app.get_quotation(pg_temp.q('a1'))$$), 'HMT_KHONG_CO_QUYEN', 'Sale CS5 mở báo giá CS1 thì bị từ chối');
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.oid('0900004001'), '[]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Sale CS5 không tạo báo giá cho cơ hội CS1');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('e1'), null, '[]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Sale CS5 không sửa báo giá CS1');
select is(pg_temp.err($$select app.send_quotation(pg_temp.q('e1'))$$), 'HMT_KHONG_CO_QUYEN', 'Sale CS5 không gửi báo giá CS1');
select is(pg_temp.err($$select pg_temp.mk('s5', '0900004099', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004099', 1), 'LC-TOAN-K09', 'OFF', 10)))$$), null, 'Sale CS5 tạo báo giá trong cơ sở mình: được');
select is(pg_temp.err($$select app.send_quotation(pg_temp.q('s5'))$$), null, 'Sale CS5 gửi báo giá cơ sở mình');
select is((select valid_until from app.quotation where id = pg_temp.q('s5')), (now() at time zone 'Asia/Ho_Chi_Minh')::date + 7, 'Hạn theo tham số ghi đè riêng của cơ sở CS5 (7 ngày)');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.list_quotations('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không xem được danh sách báo giá');
select is((select count(*)::int from app.quotation), 0, 'Giáo viên đọc ra 0 báo giá');
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.oid('0900004001'), '[]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không tạo báo giá');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is((select count(*)::int from app.quotation) + (select count(*)::int from app.quotation_line_discount), 0, 'Học sinh đọc ra 0 dòng');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select ok((app.list_quotations('{}') ->> 'total')::int >= 6, 'Kế toán xem được báo giá mọi cơ sở (Đ105 f)');
select ok(jsonb_array_length(app.get_quotation(pg_temp.q('a1')) -> 'lines') >= 1, 'Kế toán mở được bản ghi báo giá');
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.oid('0900004001'), '[]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Kế toán không tạo báo giá (chỉ đọc, xuất)');
select is(pg_temp.err($$select app.cancel_quotation(pg_temp.q('e1'))$$), 'HMT_KHONG_CO_QUYEN', 'Kế toán không huỷ báo giá');

-- ================= Danh sách, tìm kiếm, phân trang (D17) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(app.list_quotations('{"q": "em hai"}') ->> 'total', '0', 'Tìm tên em chưa có trong báo giá nào: 0');
select pg_temp.mk('s2', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 2), 'LC-TOAN-K09', 'OFF', 12)));
select is(app.list_quotations('{"q": "em hai"}') ->> 'total', '1', 'D17: tìm được báo giá theo tên em (không dấu)');
select ok((app.list_quotations('{"q": "0900004001"}') ->> 'total')::int > 0, 'Tìm theo SĐT phụ huynh');
select is(app.list_quotations(jsonb_build_object('q', (select code from qs where key = 's2'))) ->> 'total', '1', 'Tìm theo mã báo giá');
select is(app.list_quotations('{"q": "bao gia a"}') ->> 'total' <> '0', true, 'Tìm theo tên phụ huynh');
select pg_temp.sudo($$update app.prospect_student set full_name = 'Em Hai Đổi Tên' where opportunity_id = pg_temp.oid('0900004001') and position = 2$$);
select is(app.list_quotations('{"q": "doi ten"}') ->> 'total', '1', 'Em đổi tên thì tìm kiếm của báo giá đổi theo');
select pg_temp.sudo($$update app.parent set full_name = 'Chị Đổi Họ Tên Mới' where phone = '0900004001'$$);
select is(app.list_quotations('{"q": "doi ho ten moi"}') ->> 'total' <> '0', true, 'Phụ huynh đổi tên thì tìm kiếm của báo giá đổi theo');
select is((app.list_quotations('{"status": ["DA_GUI"]}') ->> 'total')::int, (select count(*)::int from app.quotation where status_code = 'DA_GUI' and branch_id = (select branch_id from app.user_account where id = pg_temp.uid('sales1'))), 'Lọc theo trạng thái Đã gửi');
select is(app.list_quotations(jsonb_build_object('opportunity_id', pg_temp.oid('0900004001'))) ->> 'total', (select count(*)::text from app.quotation where opportunity_id = pg_temp.oid('0900004001')), 'Lọc theo cơ hội (tab TS-08)');
select is(app.list_quotations(jsonb_build_object('parent_id', (select parent_id from app.opportunity where id = pg_temp.oid('0900004001')))) ->> 'total', (select count(*)::text from app.quotation where opportunity_id = pg_temp.oid('0900004001')), 'Lọc theo phụ huynh (tab KH-02)');
select ok((app.list_quotations('{"mine": true}') ->> 'total')::int > 0, 'Lọc "của tôi"');
select is((app.list_quotations('{"expired": true}') ->> 'total')::int, 1, 'Lọc "đã quá hạn": chỉ báo giá Đã gửi quá hạn');
select is(jsonb_array_length(app.list_quotations('{}', 'created_desc', 1, 0) -> 'rows'), 1, 'Phân trang: limit 1 trả một dòng');
select ok((app.list_quotations('{}', 'created_desc', 1, 0) ->> 'total')::int > 1, 'Phân trang: total là tổng, không phải số dòng của trang');
select ok(jsonb_array_length(app.list_quotations('{}', 'created_desc', 100000, 0) -> 'rows') <= 100, 'Phân trang: tối đa 100 dòng mỗi trang');
select is((app.list_quotations('{}', 'total_desc', 1, 0) -> 'rows' -> 0 ->> 'total_amount')::bigint, (select max(total_amount) from app.quotation where branch_id = (select branch_id from app.user_account where id = pg_temp.uid('sales1'))), 'Sắp xếp theo tổng tiền giảm dần');
select is((select bool_and(r ? 'overdue_days') from jsonb_array_elements(app.list_quotations('{}') -> 'rows') r), true, 'Danh sách có cột overdue_days ở mọi dòng (null khi chưa quá hạn)');

-- ================= Xuất (Đ105) =================
select is(pg_temp.err($$select app.export_quotations('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Đ105: Sale không xuất được báo giá');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.export_quotations('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Đ105: CSKH không xuất được báo giá');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.export_quotations('{}')$$), null, 'Đ105: Trưởng cơ sở xuất được');
select is((app.export_quotations('{}') ->> 'exported')::int, (select count(*)::int from app.quotation where branch_id = (select branch_id from app.user_account where id = pg_temp.uid('bm1'))), 'Trưởng cơ sở chỉ xuất báo giá cơ sở mình');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select ok((app.export_quotations('{}') ->> 'exported')::int > (select count(*)::int from app.quotation where branch_id = (select branch_id from app.user_account where id = pg_temp.uid('bm1'))), 'Kế toán xuất báo giá mọi cơ sở');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.export_quotations('{"status": ["HUY"]}')$$), null, 'Admin xuất được');
select ok((select count(*) from app.export_log where module_code = 'QUOTATION') >= 4, 'Mỗi lần xuất ghi nhật ký xuất');
select ok((app.export_quotations('{}') -> 'rows' -> 0) ? 'students', 'Bản xuất có cột học sinh');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.export_quotations('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không xuất được');

-- ================= Giấy tờ của cơ hội, chặn gộp (Đ106, R-CRM-22) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('d1', '0900004010', jsonb_build_array(pg_temp.line((select ps.id from app.prospect_student ps where ps.opportunity_id = pg_temp.oid('0900004010') and ps.position = 1), 'LC-TOAN-K09', 'OFF', 5)));
select is(pg_temp.docs(pg_temp.oid('0900004010')), array[(select code from qs where key = 'd1')], 'Đ106: báo giá Nháp còn hiệu lực là giấy tờ của cơ hội');
select is(pg_temp.docs(pg_temp.oid('0900004002')), array[]::text[], 'Cơ hội chưa có giấy tờ: mảng rỗng');
select pg_temp.sudo($$create temp table gop as select
  (select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = '0900004010' order by o.code limit 1) as keep,
  (select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = '0900004010' order by o.code desc limit 1) as merge$$);
select pg_temp.sudo($$grant select on gop to authenticated$$);
select is((select o.id from app.opportunity o where o.id = (select merge from gop)) = pg_temp.oid('0900004010'), false, 'Hai cơ hội của cùng phụ huynh để thử gộp');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((select count(*)::int from jsonb_array_elements(app.merge_preview('OPPORTUNITY', (select keep from gop), (select merge from gop)) -> 'blockers') b where b ->> 'code' = 'HMT_GOP_CO_BAO_GIA_DON'), 0, 'Gộp: bản bị gộp chưa có giấy tờ thì không bị chặn vì giấy tờ');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$update app.quotation set opportunity_id = (select merge from gop) where id = pg_temp.q('d1')$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((select count(*)::int from jsonb_array_elements(app.merge_preview('OPPORTUNITY', (select keep from gop), (select merge from gop)) -> 'blockers') b where b ->> 'code' = 'HMT_GOP_CO_BAO_GIA_DON'), 1, 'R-CRM-22, Đ106: bản bị gộp đã có báo giá còn hiệu lực thì chặn gộp');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.cancel_quotation(pg_temp.q('d1'));
select is(pg_temp.docs((select merge from gop)), array[]::text[], 'Đ106: báo giá Huỷ không còn là giấy tờ');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((select count(*)::int from jsonb_array_elements(app.merge_preview('OPPORTUNITY', (select keep from gop), (select merge from gop)) -> 'blockers') b where b ->> 'code' = 'HMT_GOP_CO_BAO_GIA_DON'), 0, 'Báo giá Huỷ thì hết chặn gộp');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.docs(pg_temp.oid('0900004001')) @> array[(select code from qs where key = 'e1')], true, 'Báo giá Nháp, Đã gửi của cơ hội đều tính');
select is(pg_temp.docs(pg_temp.oid('0900004001')) @> array[(select code from qs where key = 'j1')], false, 'Đ106: báo giá Từ chối, Huỷ không tính');
select is(app.get_opportunity(pg_temp.oid('0900004001')) -> 'sales_documents' @> to_jsonb((select code from qs where key = 'e1')), true, 'Bản ghi cơ hội (TS-08) hiện giấy tờ thật');

-- ================= Đ176: làm tròn =================
select pg_temp.mk('nt1', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 0.33, jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 3.33)))));
select is((select array[gross_amount::text, discount_amount::text, line_total::text] from app.quotation_line where quotation_id = pg_temp.q('nt1')),
          array['72600', '2417', '70183'], 'Đ176: tiền chiết khấu làm tròn xuống, thành tiền sau chiết khấu = thành tiền − tiền chiết khấu');
select pg_temp.mk('nt2', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 0.5)));
select is((select gross_amount from app.quotation_line where quotation_id = pg_temp.q('nt2')), 110000::bigint, 'Đ176: 0,5 giờ × 220.000 = 110.000 đ');
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'ONL', 100001, (now() at time zone 'Asia/Ho_Chi_Minh')::date from app.sales_package where code = 'VIP-TOAN-K03K07'$$);
select pg_temp.mk('nt3', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'VIP-TOAN-K03K07', 'ONL', 0.5)));
select is((select gross_amount from app.quotation_line where quotation_id = pg_temp.q('nt3')), 50001::bigint, 'Đ176: 0,5 × 100.001 = 50.000,5 làm tròn nửa đồng lên: 50.001 đ');
select is((select (gross_amount - discount_amount - line_total) from app.quotation_line where quotation_id = pg_temp.q('nt1')), 0::bigint, 'Đ176: thành tiền − chiết khấu = thành tiền sau chiết khấu');

-- ================= Đ175: Gửi tính lại theo giá và chính sách ngày Gửi =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
-- Giá không đổi giữa Lưu và Gửi: không cảnh báo.
select pg_temp.mk('ns0', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 10)));
select is(app.send_quotation(pg_temp.q('ns0')) -> 'warnings', '[]'::jsonb, 'Đ175: giá không đổi thì Gửi không cảnh báo');
-- Giá đổi giữa Lưu và Gửi: Gửi dùng giá ngày Gửi, trả cảnh báo, tổng đổi theo.
select pg_temp.mk('ns1', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 10)));
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'OFF', 250000, (now() at time zone 'Asia/Ho_Chi_Minh')::date from app.sales_package where code = 'LC-TOAN-K09'$$);
create temp table sent1 (r jsonb);
grant all on sent1 to public;
insert into sent1 select app.send_quotation(pg_temp.q('ns1'));
select is((select r -> 'warnings' -> 0 ->> 'code' from sent1), 'HMT_TONG_TIEN_DOI', 'Đ175: tổng đổi lúc Gửi thì trả cảnh báo HMT_TONG_TIEN_DOI');
select ok((select r -> 'warnings' -> 0 ->> 'message' from sent1) like '%2200000%2500000%', 'Đ175: câu cảnh báo nêu tổng cũ và tổng mới');
select is((select unit_price from app.quotation_line where quotation_id = pg_temp.q('ns1')), 250000::bigint, 'Đ175: dòng đóng băng theo giá ngày Gửi');
select is((select total_amount from app.quotation where id = pg_temp.q('ns1')), 2500000::bigint, 'Đ175: tổng báo giá cập nhật theo giá ngày Gửi');
select is((select (r ->> 'previous_total')::bigint from sent1), 2200000::bigint, 'Đ175: trả tổng lúc Lưu để giao diện so sánh');
-- Chính sách hết hiệu lực giữa Lưu và Gửi: chặn Gửi, báo đúng dòng.
select pg_temp.sudo($$insert into app.discount_policy (code, name, kind, max_value, valid_from, valid_to) values ('SAP_HET', 'Sắp hết hạn', 'PERCENT', 3, date '2026-01-01', (now() at time zone 'Asia/Ho_Chi_Minh')::date + 5)$$);
select pg_temp.mk('ns2', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 10),
  pg_temp.line(pg_temp.ps('0900004001', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('SAP_HET', 3)))));
select pg_temp.sudo($$update app.discount_policy set valid_to = (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1 where code = 'SAP_HET'$$);
select is(pg_temp.err($$select app.send_quotation(pg_temp.q('ns2'))$$), 'HMT_CHINH_SACH_KHONG_AP_DUNG', 'Đ175: chính sách hết hiệu lực lúc Gửi thì chặn');
select ok(pg_temp.msg($$select app.send_quotation(pg_temp.q('ns2'))$$) like 'Dòng 2:%', 'Đ175: báo đúng dòng bị chặn');
select is((select status_code from app.quotation where id = pg_temp.q('ns2')), 'NHAP', 'Đ175: bị chặn thì báo giá vẫn Nháp');
-- Gói ngừng bán giữa Lưu và Gửi.
select pg_temp.mk('ns3', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'TL-MATOAN', 'OFF', 1)));
select pg_temp.sudo($$update app.sales_package set is_active = false where code = 'TL-MATOAN'$$);
select is(pg_temp.err($$select app.send_quotation(pg_temp.q('ns3'))$$), 'HMT_GOI_DA_NGUNG', 'Đ175: gói ngừng bán lúc Gửi thì chặn');
select pg_temp.sudo($$update app.sales_package set is_active = true where code = 'TL-MATOAN'$$);
-- Hình thức không còn giá giữa Lưu và Gửi.
select pg_temp.mk('ns4', '0900004001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900004001', 1), 'VNN-TOAN-K09', 'OFF', 10)));
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'OFF', null, (now() at time zone 'Asia/Ho_Chi_Minh')::date from app.sales_package where code = 'VNN-TOAN-K09'$$);
select is(pg_temp.err($$select app.send_quotation(pg_temp.q('ns4'))$$), 'HMT_HINH_THUC_KHONG_CO_GIA', 'Đ175: hình thức không còn giá lúc Gửi thì chặn');

-- ================= Đ173: công tắc phân hệ Bán hàng theo cơ sở =================
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.oid('0900004001'), '[]'::jsonb)$$), 'HMT_TINH_NANG_TAT', 'Đ173: Bán hàng tắt thì không tạo báo giá');
select is(pg_temp.err($$select app.save_quotation(pg_temp.q('ns0'), null, '[]'::jsonb)$$), 'HMT_TINH_NANG_TAT', 'Đ173: Bán hàng tắt thì không lưu báo giá');
select is(pg_temp.err($$select app.send_quotation(pg_temp.q('ns2'))$$), 'HMT_TINH_NANG_TAT', 'Đ173: Bán hàng tắt thì không gửi báo giá');
select is(pg_temp.err($$select app.reject_quotation(pg_temp.q('ns0'), 'KHAC', 'x')$$), 'HMT_TINH_NANG_TAT', 'Đ173: Bán hàng tắt thì không từ chối báo giá');
select is(pg_temp.err($$select app.cancel_quotation(pg_temp.q('ns0'))$$), 'HMT_TINH_NANG_TAT', 'Đ173: Bán hàng tắt thì không huỷ báo giá');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select is(pg_temp.err($$select app.save_quotation(null, pg_temp.oid('0900004001'), '[]'::jsonb)$$), null, 'Đ173: bật Bán hàng lại thì tạo được');
select is(pg_temp.err($$select app.cancel_quotation(pg_temp.q('ns2'))$$), null, 'Đ173: bật lại thì huỷ được');

-- ================= Nhật ký =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select ok(pg_temp.audit_has('app.quotation', pg_temp.q('p1'), '%DA_GUI%'), 'Nhật ký ghi việc Gửi báo giá');
select ok(pg_temp.audit_has('app.quotation', pg_temp.q('h1'), '%HUY%'), 'Nhật ký ghi việc Huỷ báo giá');

select * from finish();
rollback;
