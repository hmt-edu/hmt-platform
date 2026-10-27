-- P5a-DB1c-2: hàm chỉ đọc và ghi chú cho BH-02 (QĐ-Đ173, Đ181, Đ226, Đ228; R-TIEN-10, 13, 29, 36, 37): xem thử giá, gói bán, chính sách chiết khấu, ghi chú báo giá.
-- Mỗi hàm có ca đúng và ca bị chặn; xem thử phải bằng kết quả lưu; không ghi gì.
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

-- ================= preview_quotation_lines =================
create temp table pv (k text primary key, r jsonb);
grant all on pv to public;
insert into pv select 'a', app.preview_quotation_lines(pg_temp.oid('0900011001'), jsonb_build_array(
  pg_temp.line(pg_temp.ps('0900011001', 1), 'LC-TOAN-K09', 'OFF', 48, jsonb_build_array(pg_temp.disc('GIAM_6_THANG'), pg_temp.disc('GIAM_THUONG_LUONG', 6))),
  pg_temp.line(pg_temp.ps('0900011001', 2), 'LC-TOAN-K09', 'ONL', 10)));
select is((select (r ->> 'total_amount')::bigint from pv where k = 'a'), 10598400::bigint, 'Xem thử: tổng đúng (48 giờ × 220.000 giảm 11% = 9.398.400, cộng 10 giờ × 120.000)');
select is(jsonb_array_length((select r -> 'lines' from pv where k = 'a')), 2, 'Xem thử: trả từng dòng');
select is((select r -> 'lines' -> 0 ->> 'line_no' from pv where k = 'a'), '1', 'Xem thử: số dòng bắt đầu từ 1');
select is((select r -> 'lines' -> 0 ->> 'unit_price' from pv where k = 'a'), '220000', 'Xem thử: đơn giá theo bảng giá hiệu lực');
select is((select r -> 'lines' -> 0 ->> 'discount_percent' from pv where k = 'a'), '11.00', 'Xem thử: chiết khấu cộng dồn 5% + 6%');
select is((select r -> 'warnings' from pv where k = 'a'), '[]'::jsonb, 'Xem thử: chưa vượt trần thì không cảnh báo');
-- Xem thử không ghi gì.
select is((select count(*)::int from app.quotation), 0, 'Xem thử không tạo báo giá');
select is((select count(*)::int from app.quotation_line), 0, 'Xem thử không tạo dòng');
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011001'), '[]'::jsonb)$$), null, 'Xem thử không dòng: được');
select is(app.preview_quotation_lines(pg_temp.oid('0900011001'), '[]'::jsonb) ->> 'total_amount', '0', 'Xem thử không dòng: tổng 0');
select is(app.preview_quotation_lines(pg_temp.oid('0900011001'), null) -> 'lines', '[]'::jsonb, 'Xem thử dòng rỗng (null): mảng rỗng');
select is((select count(*)::int from app.audit_log l join app.audited_table t on t.id = l.table_id where t.table_name = 'app.quotation'), 0, 'Xem thử không ghi nhật ký');
-- Xem thử bằng kết quả sau Lưu (cùng hàm tính giá).
select pg_temp.mk('s1', '0900011001', jsonb_build_array(
  pg_temp.line(pg_temp.ps('0900011001', 1), 'LC-TOAN-K09', 'OFF', 48, jsonb_build_array(pg_temp.disc('GIAM_6_THANG'), pg_temp.disc('GIAM_THUONG_LUONG', 6))),
  pg_temp.line(pg_temp.ps('0900011001', 2), 'LC-TOAN-K09', 'ONL', 10)));
select is((select total_amount from app.quotation where id = pg_temp.q('s1')), (select (r ->> 'total_amount')::bigint from pv where k = 'a'), 'Xem thử = Lưu: tổng');
select is((select array_agg(array[l.unit_price, l.gross_amount, l.discount_percent, l.discount_amount, l.line_total, l.gift_percent, l.gifted_quantity] order by l.line_no)
             from app.quotation_line l where l.quotation_id = pg_temp.q('s1')),
          (select array_agg(array[(x ->> 'unit_price')::numeric, (x ->> 'gross_amount')::numeric, (x ->> 'discount_percent')::numeric, (x ->> 'discount_amount')::numeric,
                                  (x ->> 'line_total')::numeric, (x ->> 'gift_percent')::numeric, (x ->> 'gifted_quantity')::numeric] order by (x ->> 'line_no')::int)
             from jsonb_array_elements((select r -> 'lines' from pv where k = 'a')) x),
          'Xem thử = Lưu: từng dòng (đơn giá, thành tiền, chiết khấu, giờ tặng)');
select is((select array_agg(array[l.over_cap::text, l.needs_acknowledgement::text] order by l.line_no) from app.quotation_line l where l.quotation_id = pg_temp.q('s1')),
          (select array_agg(array[x ->> 'over_cap', x ->> 'needs_acknowledgement'] order by (x ->> 'line_no')::int)
             from jsonb_array_elements((select r -> 'lines' from pv where k = 'a')) x), 'Xem thử = Lưu: cờ vượt trần, cờ cần tích đồng ý');
-- Vượt trần: cảnh báo, không chặn (D3); giờ tặng tính vào trần.
select is(app.preview_quotation_lines(pg_temp.oid('0900011001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900011001', 1), 'LC-TOAN-K09', 'OFF', 48,
          jsonb_build_array(pg_temp.disc('GIAM_6_THANG'), pg_temp.disc('GIAM_THUONG_LUONG', 10), pg_temp.disc('TANG_GIO', 4)))) ) -> 'warnings' -> 0 ->> 'code',
          'HMT_VUOT_TRAN', 'Xem thử: vượt trần (5% + 10% + giờ tặng 8,33% > 20%) thì cảnh báo HMT_VUOT_TRAN, không chặn');
select is(app.preview_quotation_lines(pg_temp.oid('0900011001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900011001', 1), 'LC-TOAN-K09', 'OFF', 48,
          jsonb_build_array(pg_temp.disc('GIAM_6_THANG'), pg_temp.disc('GIAM_THUONG_LUONG', 10), pg_temp.disc('TANG_GIO', 4)))) ) -> 'lines' -> 0 ->> 'needs_acknowledgement', 'true',
          'Xem thử: vượt trần đặt cờ cần tích đồng ý');
-- Làm tròn (R-TIEN-37).
select is(app.preview_quotation_lines(pg_temp.oid('0900011001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900011001', 1), 'LC-TOAN-K09', 'OFF', 0.33,
          jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 3.33))))) -> 'lines' -> 0 ->> 'discount_amount', '2417', 'R-TIEN-37: xem thử làm tròn chiết khấu xuống (2.417)');
-- Lỗi báo đúng dòng.
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900011001', 1), 'LC-TOAN-K09', 'OFF', 0)))$$), 'HMT_DONG_THIEU', 'Xem thử: số lượng 0 thì chặn');
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900011001', 1), 'VIP-TOAN-K03K07', 'OFF', 5)))$$), 'HMT_HINH_THUC_KHONG_CO_GIA', 'Xem thử: hình thức không có giá thì chặn');
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900011002', 1), 'LC-TOAN-K09', 'OFF', 5)))$$), 'HMT_EM_NGOAI_DANH_SACH', 'Xem thử: em ngoài danh sách em của cơ hội thì chặn');
select ok(pg_temp.msg($$select app.preview_quotation_lines(pg_temp.oid('0900011001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900011001', 1), 'LC-TOAN-K09', 'OFF', 5), pg_temp.line(pg_temp.ps('0900011001', 1), 'LC-TOAN-K09', 'OFF', 0)))$$) like 'Dòng 2:%', 'Xem thử: báo đúng dòng bị lỗi');
select pg_temp.sudo($$update app.sales_package set is_active = false where code = 'TL-MATOAN'$$);
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900011001', 1), 'TL-MATOAN', 'OFF', 1)))$$), 'HMT_GOI_DA_NGUNG', 'Xem thử: gói đã ngừng thì chặn');
select pg_temp.sudo($$update app.sales_package set is_active = true where code = 'TL-MATOAN'$$);
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011001'), jsonb_build_array(pg_temp.line(null, 'LC-TOAN-K09', 'OFF', 5)))$$), 'HMT_DONG_THIEU', 'Xem thử: dòng chưa chọn em thì chặn như khi lưu (không tính giá)');
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011001'), '{"a": 1}'::jsonb)$$), 'HMT_DONG_THIEU', 'Xem thử: đầu vào không phải mảng thì chặn');
select is(pg_temp.err($$select app.preview_quotation_lines('00000000-0000-0000-0000-000000000000', '[]'::jsonb)$$), 'HMT_KHONG_TIM_THAY', 'Xem thử: cơ hội không có');
-- Quyền, công tắc, cơ hội đã gộp.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011001'), '[]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Xem thử: Sale CS5 không dùng cho cơ hội CS1');
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011099'), '[]'::jsonb)$$), null, 'Xem thử: Sale CS5 dùng cho cơ hội cơ sở mình (CS5 đã bật Bán hàng)');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011001'), '[]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Xem thử: Kế toán không có quyền lập báo giá');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011099'), '[]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Xem thử: giáo viên không có quyền');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011001'), '[]'::jsonb)$$), 'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì không xem thử');
select is(pg_temp.err($$select app.list_sellable_packages(pg_temp.oid('0900011001'))$$), 'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì không liệt kê gói');
select is(pg_temp.err($$select app.list_applicable_discount_policies(pg_temp.oid('0900011001'))$$), 'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì không liệt kê chính sách');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select pg_temp.sudo($$update app.opportunity set record_status = 'DA_GOP', merged_into_id = pg_temp.oid('0900011001') where id = pg_temp.oid('0900011002')$$);
select is(pg_temp.err($$select app.preview_quotation_lines(pg_temp.oid('0900011002'), '[]'::jsonb)$$), 'HMT_BAN_GHI_DA_GOP', 'Xem thử: cơ hội đã gộp thì chặn');
select pg_temp.sudo($$update app.opportunity set record_status = 'DANG_DUNG', merged_into_id = null where id = pg_temp.oid('0900011002')$$);

-- ================= list_sellable_packages =================
select is((select count(*)::int from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x where x ->> 'code' = 'LC-TOAN-K09'), 1, 'Gói bán: có gói lớp chung Toán 9');
select is(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages' -> 0 ->> 'code', 'DV-CSGK', 'Gói bán: sắp theo mã');
select is((select x -> 'prices' from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x where x ->> 'code' = 'LC-TOAN-K09'),
          '{"OFF": 220000, "ONL": 120000}'::jsonb, 'Gói bán: giá offline và online theo bảng giá hôm nay');
select is((select x -> 'prices' from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x where x ->> 'code' = 'VIP-TOAN-K03K07'),
          '{"ONL": 500000}'::jsonb, 'R-TIEN-10: giá trống nghĩa là không bán hình thức đó (VIP chỉ có online)');
select is((select x ->> 'unit_code' from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x where x ->> 'code' = 'DV-CSGK'), 'THANG', 'Gói bán: đơn vị tính theo loại gói (dịch vụ theo tháng)');
select is(jsonb_array_length(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'types') >= 6, true, 'Gói bán: có danh sách loại gói để lọc');
select is((select count(*)::int from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001'), 'LC') -> 'packages') x where x ->> 'package_type_code' <> 'LC'), 0, 'Gói bán: lọc theo loại gói');
select is((app.list_sellable_packages(pg_temp.oid('0900011001'), 'LC') ->> 'total')::int, 1, 'Gói bán: lọc loại LC còn 1 gói');
select is((app.list_sellable_packages(pg_temp.oid('0900011001'), null, 'Toán 9') ->> 'total')::int, 2, 'Gói bán: tìm không dấu, không phân biệt hoa thường (khớp hai gói Toán 9)');
select is((app.list_sellable_packages(pg_temp.oid('0900011001'), null, 'khong co goi nay') ->> 'total')::int, 0, 'Gói bán: không khớp thì rỗng');
-- Giá hiệu lực ngày mai không dùng hôm nay; gói ngừng, gói chưa có giá không hiện.
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'OFF', 999000, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1 from app.sales_package where code = 'LC-TOAN-K09'$$);
select is((select x -> 'prices' ->> 'OFF' from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x where x ->> 'code' = 'LC-TOAN-K09'), '220000', 'Gói bán: giá có hiệu lực ngày mai chưa dùng hôm nay');
select pg_temp.sudo($$update app.sales_package set is_active = false where code = 'TL-MATOAN'$$);
select is((select count(*)::int from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x where x ->> 'code' = 'TL-MATOAN'), 0, 'Gói bán: gói đã ngừng không hiện');
select pg_temp.sudo($$insert into app.sales_package (code, name, package_type_code) values ('TL-KHONGGIA', 'Gói chưa có giá', 'TL')$$);
select is((select count(*)::int from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x where x ->> 'code' = 'TL-KHONGGIA'), 0, 'Gói bán: gói chưa có giá nào hôm nay không hiện');
-- Gợi ý theo cơ hội: phiếu kiểm tra Toán khối 9.
select is(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'suggested', '["LC-TOAN-K09", "VNN-TOAN-K09"]'::jsonb, 'Gợi ý theo cơ hội: gói đúng môn Toán, khối 9 (VIP Toán 3 đến 7 không gợi ý)');
select is(app.list_sellable_packages(pg_temp.oid('0900011002')) -> 'suggested', '[]'::jsonb, 'Gợi ý theo cơ hội: cơ hội chưa có phiếu kiểm tra thì không gợi ý');
-- Hay dùng (Đ228): gói người dùng chọn nhiều nhất trên báo giá của mình.
select is(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'popular', '["LC-TOAN-K09"]'::jsonb, 'Đ228: Hay dùng là gói đã chọn trên báo giá của mình');
select pg_temp.mk('s2', '0900011001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900011001', 1), 'DV-CSGK', 'OFF', 3), pg_temp.line(pg_temp.ps('0900011001', 2), 'DV-CSGK', 'OFF', 2),
                                                        pg_temp.line(pg_temp.ps('0900011001', 1), 'LC-TOAN-K09', 'OFF', 5)));
select is(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'popular', '["LC-TOAN-K09", "DV-CSGK"]'::jsonb, 'Đ228: sắp theo số lần chọn giảm dần (LC-TOAN-K09 ba dòng, DV-CSGK hai dòng)');
select pg_temp.sudo($$update app.setting_def set value = '1' where key = 'quotation_popular_packages_count'$$);
select is(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'popular', '["LC-TOAN-K09"]'::jsonb, 'Đ228: số gói Hay dùng theo tham số quotation_popular_packages_count');
select pg_temp.sudo($$update app.setting_def set value = '5' where key = 'quotation_popular_packages_count'$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'popular', '[]'::jsonb, 'Đ228: Hay dùng chỉ tính báo giá của chính mình (CSKH chưa lập báo giá nào)');
select is(jsonb_array_length(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') > 0, true, 'Gói bán: CSKH cũng dùng được (có quyền lập báo giá)');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
-- Ngoài cửa sổ M ngày thì không tính.
select pg_temp.sudo($$alter table app.quotation disable trigger quotation_fill_standard$$);
select pg_temp.sudo($$update app.quotation set created_at = now() - interval '200 days'$$);
select pg_temp.sudo($$alter table app.quotation enable trigger quotation_fill_standard$$);
select is(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'popular', '[]'::jsonb, 'Đ228: báo giá cũ hơn quotation_popular_window_days (90 ngày) không tính');
select pg_temp.sudo($$update app.setting_def set value = '365' where key = 'quotation_popular_window_days'$$);
select is(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'popular', '["LC-TOAN-K09", "DV-CSGK"]'::jsonb, 'Đ228: nới cửa sổ lên 365 ngày thì tính lại');
-- Giới hạn kết quả: không tải cả bảng.
select pg_temp.sudo($$insert into app.sales_package (code, name, package_type_code) select 'TL-LIM' || lpad(g::text, 3, '0'), 'Gói thử ' || g, 'TL' from generate_series(1, 25) g$$);
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'OFF', 100000, date '2026-01-01' from app.sales_package where code like 'TL-LIM%'$$);
select pg_temp.sudo($$update app.setting_def set value = '20' where key = 'list_page_size_max'$$);
select is(jsonb_array_length(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages'), 21, 'Gói bán: 20 gói đầu theo list_page_size_max, cộng 1 gói gợi ý nằm ngoài trang');
select ok((app.list_sellable_packages(pg_temp.oid('0900011001')) ->> 'total')::int > 20, 'Gói bán: vẫn báo tổng số gói thật');
select is((select count(*)::int from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x where x ->> 'code' = 'VNN-TOAN-K09'), 1, 'Gói bán: gói gợi ý nằm ngoài trang đầu vẫn có chi tiết');
select is((select count(*)::int from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x where x ->> 'code' in (select jsonb_array_elements_text(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'suggested'))), 2, 'Gói bán: mọi gói gợi ý đều có chi tiết trong packages');
select is((select count(*)::int from jsonb_array_elements(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'packages') x where x ->> 'code' in (select jsonb_array_elements_text(app.list_sellable_packages(pg_temp.oid('0900011001')) -> 'popular'))), 2, 'Gói bán: mọi gói Hay dùng đều có chi tiết trong packages');
select pg_temp.sudo($$update app.setting_def set value = '50' where key = 'list_page_size_max'$$);
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.list_sellable_packages(pg_temp.oid('0900011001'))$$), 'HMT_KHONG_CO_QUYEN', 'Gói bán: Sale CS5 không dùng cho cơ hội CS1');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.list_sellable_packages(pg_temp.oid('0900011099'))$$), 'HMT_KHONG_CO_QUYEN', 'Gói bán: học sinh không có quyền');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.list_sellable_packages('00000000-0000-0000-0000-000000000000')$$), 'HMT_KHONG_TIM_THAY', 'Gói bán: cơ hội không có');

-- ================= list_applicable_discount_policies =================
select is((select array_agg(x ->> 'code' order by x ->> 'code') from jsonb_array_elements(app.list_applicable_discount_policies(pg_temp.oid('0900011001'))) x),
          array['GIAM_6_THANG', 'GIAM_THUONG_LUONG', 'TANG_GIO'], 'Chính sách: ba chính sách hiệu lực hôm nay');
select is((select x ->> 'kind' from jsonb_array_elements(app.list_applicable_discount_policies(pg_temp.oid('0900011001'))) x where x ->> 'code' = 'TANG_GIO'), 'GIFT_HOURS', 'Chính sách: loại giờ tặng');
select is((select (x ->> 'max_value')::numeric from jsonb_array_elements(app.list_applicable_discount_policies(pg_temp.oid('0900011001'))) x where x ->> 'code' = 'GIAM_THUONG_LUONG'), 10::numeric, 'Chính sách: mức tối đa');
select is((select (x ->> 'requires_approval')::boolean from jsonb_array_elements(app.list_applicable_discount_policies(pg_temp.oid('0900011001'))) x where x ->> 'code' = 'GIAM_THUONG_LUONG'), true, 'Chính sách: cần duyệt');
select is((select (x ->> 'fixed_value')::boolean from jsonb_array_elements(app.list_applicable_discount_policies(pg_temp.oid('0900011001'))) x where x ->> 'code' = 'GIAM_6_THANG'), true, 'Chính sách: áp đúng mức');
select pg_temp.sudo($$insert into app.discount_policy (code, name, kind, max_value, valid_from, valid_to) values ('HET_HAN_2', 'Hết hạn', 'PERCENT', 3, date '2025-01-01', date '2025-12-31')$$);
select pg_temp.sudo($$insert into app.discount_policy (code, name, kind, max_value, valid_from, branch_ids) values ('CHI_CS5', 'Chỉ CS5', 'PERCENT', 3, date '2026-01-01', array[(select id from app.branch where code = 'CS5')])$$);
select pg_temp.sudo($$insert into app.discount_policy (code, name, kind, max_value, valid_from, is_active) values ('DA_NGUNG', 'Đã ngừng', 'PERCENT', 3, date '2026-01-01', false)$$);
select pg_temp.sudo($$insert into app.discount_policy (code, name, kind, max_value, valid_from) values ('CHUA_TOI_NGAY', 'Chưa tới ngày', 'PERCENT', 3, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 5)$$);
select is((select count(*)::int from jsonb_array_elements(app.list_applicable_discount_policies(pg_temp.oid('0900011001'))) x where x ->> 'code' in ('HET_HAN_2', 'CHI_CS5', 'DA_NGUNG', 'CHUA_TOI_NGAY')), 0, 'Chính sách: hết hạn, chưa tới ngày, đã ngừng, sai cơ sở đều không hiện');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((select count(*)::int from jsonb_array_elements(app.list_applicable_discount_policies(pg_temp.oid('0900011099'))) x where x ->> 'code' = 'CHI_CS5'), 1, 'Chính sách: chính sách riêng CS5 hiện cho cơ hội CS5');
select is(pg_temp.err($$select app.list_applicable_discount_policies(pg_temp.oid('0900011001'))$$), 'HMT_KHONG_CO_QUYEN', 'Chính sách: Sale CS5 không dùng cho cơ hội CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.list_applicable_discount_policies(pg_temp.oid('0900011001'))$$), 'HMT_KHONG_CO_QUYEN', 'Chính sách: Kế toán không có quyền lập báo giá');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.list_applicable_discount_policies('00000000-0000-0000-0000-000000000000')$$), 'HMT_KHONG_TIM_THAY', 'Chính sách: cơ hội không có');

-- ================= Ghi chú và lịch sử của báo giá (BH-02) =================
select is(pg_temp.err($$select app.add_note('QUOTATION', pg_temp.q('s1'), 'Phụ huynh hẹn trả lời cuối tuần')$$), null, 'Ghi chú báo giá: người lập thêm được');
select is((select count(*)::int from app.record_notes('QUOTATION', pg_temp.q('s1'))), 1, 'Ghi chú báo giá: đọc lại được');
select is((select body from app.record_notes('QUOTATION', pg_temp.q('s1')) limit 1), 'Phụ huynh hẹn trả lời cuối tuần', 'Ghi chú báo giá: đúng nội dung');
select is(pg_temp.err($$select * from app.record_history('QUOTATION', pg_temp.q('s1'))$$), null, 'Lịch sử báo giá: đọc được');
select ok((select count(*) from app.record_history('QUOTATION', pg_temp.q('s1'))) >= 0, 'Lịch sử báo giá: trả về một bảng');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.add_note('QUOTATION', pg_temp.q('s1'), 'ghi trái phép')$$), 'HMT_KHONG_CO_QUYEN', 'Ghi chú báo giá: Sale CS5 không ghi vào báo giá CS1');
select is(pg_temp.err($$select * from app.record_notes('QUOTATION', pg_temp.q('s1'))$$), 'HMT_KHONG_CO_QUYEN', 'Ghi chú báo giá: Sale CS5 không đọc ghi chú báo giá CS1');
select is(pg_temp.err($$select * from app.record_history('QUOTATION', pg_temp.q('s1'))$$), 'HMT_KHONG_CO_QUYEN', 'Lịch sử báo giá: Sale CS5 không đọc lịch sử báo giá CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is((select count(*)::int from app.record_notes('QUOTATION', pg_temp.q('s1'))), 1, 'Ghi chú báo giá: Kế toán (xem toàn hệ thống) đọc được');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select * from app.record_notes('QUOTATION', pg_temp.q('s1'))$$), 'HMT_KHONG_CO_QUYEN', 'Ghi chú báo giá: giáo viên không đọc được');

select * from finish();
rollback;
