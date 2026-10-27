-- P5a-DB1b-1 (đơn hàng): bài kiểm ĐỘC LẬP, viết chỉ dựa trên chữ luật (R-CRM-16, 27; R-TIEN-01, 02, 03, 06, 07, 14, 35, 37, 38;
-- R-GD-06, 08; R-HT-01, 06). Cố phá từng luật. Bài trượt vì code lệch luật được giữ nguyên.
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
create function pg_temp.msg(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
-- Chạy câu lệnh rồi LUÔN hoàn tác; trả HMT_PROBE_OK nếu câu lệnh được chạy mà không lỗi (không để lại dấu vết trong các bài sau).
create function pg_temp.probe(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  raise exception 'probe' using hint = 'HMT_PROBE_OK';
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
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
create temp table os (key text primary key, id uuid, code text);
create temp table qs (key text primary key, id uuid, code text);
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable security definer as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.o(p_key text) returns uuid language sql stable security definer as $$ select id from pg_temp.os where key = p_key $$;
create function pg_temp.q(p_key text) returns uuid language sql stable security definer as $$ select id from pg_temp.qs where key = p_key $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Độc Lập', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
create function pg_temp.pkg(p_code text) returns uuid language sql stable security definer as 'select id from app.sales_package where code = p_code';
create function pg_temp.pol(p_code text) returns uuid language sql stable security definer as 'select id from app.discount_policy where code = p_code';
create function pg_temp.term(p_code text) returns uuid language sql stable security definer as 'select id from app.payment_term where code = p_code and version = 1';
create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as
  'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone order by o.code limit 1';
create function pg_temp.lid(p_phone text) returns uuid language sql stable security definer as 'select id from app.lead where parent_phone = p_phone order by code limit 1';
create function pg_temp.ps(p_phone text, p_pos integer) returns uuid language sql stable security definer as
  'select ps.id from app.prospect_student ps where ps.opportunity_id = pg_temp.oid(p_phone) and ps.position = p_pos';
create function pg_temp.line(p_ps uuid, p_pkg text, p_mode text, p_qty numeric, p_disc jsonb default '[]'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('kind', 'ENROL', 'prospect_student_id', p_ps, 'package_id', pg_temp.pkg(p_pkg), 'delivery_mode_code', p_mode,
                            'quantity', p_qty, 'discounts', p_disc) $$;
create function pg_temp.disc(p_policy text, p_value numeric default null) returns jsonb language sql as $$
  select jsonb_build_object('policy_id', pg_temp.pol(p_policy), 'value', p_value) $$;
create function pg_temp.mk(p_key text, p_phone text, p_lines jsonb) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := app.create_order_from_opportunity(pg_temp.oid(p_phone), p_lines);
  insert into pg_temp.os values (p_key, (r ->> 'id')::uuid, r ->> 'code');
  return r;
end $$;
create function pg_temp.st(p_key text) returns text language sql stable security definer as 'select status_code from app.sales_order where id = pg_temp.o(p_key)';
create function pg_temp.ev(p_key text) returns text language sql stable security definer as
  'select string_agg(event_code, '','' order by seq) from app.sales_order_event where order_id = pg_temp.o(p_key)';
create function pg_temp.qlive(p uuid) returns boolean language sql stable security definer as 'select app.quotation_has_live_order(p)';
create function pg_temp.qconv(p uuid) returns boolean language sql stable security definer as 'select app.quotation_converted(p)';
create function pg_temp.nst(p_phone text) returns integer language sql stable security definer as
  'select count(*)::int from app.student s where s.parent_id = (select parent_id from app.opportunity where id = pg_temp.oid(p_phone))';
-- Đưa đơn thẳng từ cơ hội tới trạng thái: 0 Nháp, 1 Nháp có điều khoản, 2 Đã trình, 3 Đã duyệt (người lập sales1, người duyệt bm1).
create function pg_temp.go(p_key text, p_phone text, p_qty numeric, p_stage integer, p_disc jsonb default '[]'::jsonb) returns void language plpgsql as $$
begin
  perform pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
  perform pg_temp.mk(p_key, p_phone, jsonb_build_array(pg_temp.line(pg_temp.ps(p_phone, 1), 'LC-TOAN-K09', 'OFF', p_qty, p_disc)));
  if p_stage >= 1 then perform app.save_order(pg_temp.o(p_key), null, pg_temp.term('CHIA_3_DOT')); end if;
  if p_stage >= 2 then perform app.submit_order(pg_temp.o(p_key)); end if;
  if p_stage >= 3 then
    perform pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
    perform app.approve_order(pg_temp.o(p_key), true);
    perform pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
  end if;
end $$;

insert into u (key) values ('admin'), ('bm1'), ('bm1b'), ('sales1'), ('sales1b'), ('sales5'), ('bm5'), ('ke'), ('hs');
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@tsb.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@tsb.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999997' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm1b', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('bm5', 'CS5'), ('ke', 'CS1'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm1b', 'BRANCH_MANAGER'), ('sales1', 'SALES'),
  ('sales1b', 'SALES'), ('sales5', 'SALES'), ('bm5', 'BRANCH_MANAGER'), ('ke', 'ACCOUNTANT'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true;
grant all on u, os, qs to public;
grant execute on all functions in schema pg_temp to public;

-- ================= Dựng dữ liệu =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
select app.set_manager(pg_temp.uid('sales5'), pg_temp.uid('bm5'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900019001', '{"parent_name": "Chị Độc Một", "student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900019002', '{"parent_name": "Chị Độc Hai", "student_name": "Em Bốn", "student_birth_year": 2010}'));
select app.create_lead(pg_temp.lead_data('0900019009', '{"parent_name": "Chị Độc Chưa L8", "student_name": "Em Chín", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900019010', '{"parent_name": "Chị Độc Báo Giá", "student_name": "Em Một", "student_birth_year": 2012}'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900019005', '{"parent_name": "Chị Độc Tự Duyệt", "student_name": "Em Bảy", "student_birth_year": 2011}'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900019099', '{"parent_name": "Chị Độc CS5", "student_name": "Em Tám", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900019001'));
select app.create_opportunity(pg_temp.lid('0900019002'));
select app.create_opportunity(pg_temp.lid('0900019009'));
select app.create_opportunity(pg_temp.lid('0900019010'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900019005'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900019099'));
-- Em thứ hai đủ thông tin, em thứ ba thiếu năm sinh ở cơ hội 1.
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Hai', 2014 from app.opportunity o where o.id = pg_temp.oid('0900019001')$$);
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name)
  select o.id, o.branch_id, 3, 'Em Ba' from app.opportunity o where o.id = pg_temp.oid('0900019001')$$);
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Hai Báo Giá', 2014 from app.opportunity o where o.id = pg_temp.oid('0900019010')$$);
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in
  (pg_temp.oid('0900019001'), pg_temp.oid('0900019002'), pg_temp.oid('0900019005'), pg_temp.oid('0900019099'))$$);

-- ================= Số âm, số 0, giá trị vô lý khi tạo đơn (R-TIEN-37, R-TIEN-35) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select isnt(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900019001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 1), 'LC-TOAN-K09', 'OFF', -5)))$$),
            null, 'Số giờ âm thì chặn khi tạo đơn');
select isnt(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900019001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 1), 'LC-TOAN-K09', 'OFF', 0)))$$),
            null, 'Số giờ bằng 0 thì chặn khi tạo đơn');
select isnt(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900019001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 1), 'LC-TOAN-K09', 'OFF', 0.001)))$$),
            null, 'Số giờ nhỏ hơn 0,01 (làm tròn về 0) thì chặn khi tạo đơn');
select isnt(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900019001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 1), 'LC-TOAN-K09', 'OFF', null)))$$),
            null, 'Thiếu số giờ thì chặn khi tạo đơn');
select isnt(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900019001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', -5)))))$$),
            null, 'R-TIEN-37: chiết khấu âm thì chặn');
select isnt(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900019001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 150)))))$$),
            null, 'R-TIEN-37: chiết khấu trên 100% thì chặn');
select isnt(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900019001'), jsonb_build_array(pg_temp.line(null, 'LC-TOAN-K09', 'OFF', 10)))$$),
            null, 'R-TIEN-35: mỗi dòng ghi một học sinh, dòng không có em thì chặn');
select isnt(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900019001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 1), null, 'OFF', 10)))$$),
            null, 'Dòng không có gói thì chặn');
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900019001'), null)$$), 'HMT_DON_KHONG_DONG', 'Danh sách dòng null thì chặn');
select is((select count(*)::int from app.sales_order where opportunity_id = pg_temp.oid('0900019001')), 0, 'Các ca bị chặn không để lại đơn nào');

-- ================= R-CRM-16: chỉ tạo đơn từ cơ hội L8 =================
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900019009'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019009', 1), 'LC-TOAN-K09', 'OFF', 10)))$$),
          'HMT_CHUA_O_L8', 'R-CRM-16: cơ hội L1 không tạo được đơn thẳng');
select pg_temp.sudo($$update app.opportunity set stage_code = 'L7', substage_code = null where id = pg_temp.oid('0900019009')$$);
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900019009'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019009', 1), 'LC-TOAN-K09', 'OFF', 10)))$$),
          'HMT_CHUA_O_L8', 'R-CRM-16: cơ hội L7 (sát L8) cũng không tạo được đơn');
select is((select count(*)::int from app.sales_order where opportunity_id = pg_temp.oid('0900019009')), 0, 'R-CRM-16: bị chặn thì không có đơn nào');

-- ================= Sai vai trò, sai cơ sở, ngoài phạm vi =================
select pg_temp.go('d1', '0900019001', 10, 0);
select pg_temp.go('d2', '0900019001', 10, 1);
select pg_temp.go('t1', '0900019002', 10, 2);
select pg_temp.go('v1', '0900019002', 10, 3);
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.save_order(pg_temp.o('d1'), null, pg_temp.term('CHIA_3_DOT'))$$), 'HMT_KHONG_CO_QUYEN', 'Ngoài phạm vi: Sale CS5 không lưu đơn nháp CS1');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('d2'))$$), 'HMT_KHONG_CO_QUYEN', 'Ngoài phạm vi: Sale CS5 không trình đơn CS1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('d1'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_CO_QUYEN', 'Ngoài phạm vi: Sale CS5 không huỷ đơn CS1');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('t1'), 'KHONG_DUNG_CHINH_SACH', 'x')$$), 'HMT_KHONG_CO_QUYEN', 'Ngoài phạm vi: Trưởng cơ sở CS5 không từ chối đơn CS1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('t1'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_CO_QUYEN', 'Ngoài phạm vi: Trưởng cơ sở CS5 không huỷ đơn CS1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('v1'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_CO_QUYEN', 'Ngoài phạm vi: Trưởng cơ sở CS5 không huỷ đơn đã duyệt CS1');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.save_order(pg_temp.o('d1'), null, pg_temp.term('CHIA_3_DOT'))$$), 'HMT_KHONG_CO_QUYEN', 'Sai vai trò: Kế toán không lưu đơn');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('d2'))$$), 'HMT_KHONG_CO_QUYEN', 'Sai vai trò: Kế toán không trình đơn');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('t1'), 'KHONG_DUNG_CHINH_SACH', 'x')$$), 'HMT_KHONG_CO_QUYEN', 'Sai vai trò: Kế toán không từ chối đơn');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('t1'))$$), 'HMT_KHONG_CO_QUYEN', 'Sai vai trò: Kế toán không duyệt đơn');
select is(pg_temp.err($$select app.create_order_from_quotation(gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Báo giá không có thì báo không tìm thấy');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.create_order_from_opportunity(pg_temp.oid('0900019001'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 1), 'LC-TOAN-K09', 'OFF', 10)))$$),
          'HMT_KHONG_CO_QUYEN', 'Sai vai trò: học sinh không tạo đơn');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('t1'))$$), 'HMT_KHONG_CO_QUYEN', 'Sai vai trò: học sinh không duyệt đơn');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('d1'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_CO_QUYEN', 'Sai vai trò: học sinh không huỷ đơn');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('t1'), 'KHONG_DUNG_CHINH_SACH', 'x')$$), 'HMT_KHONG_CO_QUYEN', 'R-HT-01: Admin chưa xác thực hai bước không từ chối thay');
select is(pg_temp.st('t1'), 'DA_TRINH', 'Các ca bị chặn không đổi trạng thái đơn');

-- ================= R-TIEN-06 / R-HT-06: người lập sửa, trình đơn Nháp của mình =================
select pg_temp.go('nc', '0900019001', 10, 1);
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');

-- ================= Gọi hai lần, sai trạng thái =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('t1'))$$), 'HMT_SAI_TRANG_THAI', 'Trình đơn Đã trình lần hai thì chặn');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('v1'))$$), 'HMT_SAI_TRANG_THAI', 'Trình đơn Đã duyệt thì chặn');
select is(pg_temp.err($$select app.save_order(pg_temp.o('v1'), null, pg_temp.term('CHIA_3_DOT'))$$), 'HMT_DON_DA_KHOA', 'R-TIEN-03: lưu đơn Đã duyệt thì chặn');
select is(pg_temp.err($$select app.save_order(pg_temp.o('t1'), '[]'::jsonb)$$), 'HMT_DON_DA_KHOA', 'Lưu đơn Đã trình (kể cả danh sách rỗng) thì chặn');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('d2'))$$), 'HMT_SAI_TRANG_THAI', 'Duyệt đơn Nháp thì chặn');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('d2'), 'KHONG_DUNG_CHINH_SACH', 'x')$$), 'HMT_SAI_TRANG_THAI', 'Từ chối đơn Nháp thì chặn');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('v1'), true)$$), 'HMT_SAI_TRANG_THAI', 'Duyệt đơn Đã duyệt lần hai thì chặn');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('v1'), 'KHONG_DUNG_CHINH_SACH', 'x')$$), 'HMT_SAI_TRANG_THAI', 'Từ chối đơn Đã duyệt thì chặn');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('t1'), 'KHONG_DUNG_CHINH_SACH', 'Giá sai')$$), null, 'Từ chối đơn Đã trình: được');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('t1'), 'KHONG_DUNG_CHINH_SACH', 'Giá sai')$$), 'HMT_SAI_TRANG_THAI', 'Từ chối lần hai (đơn đã về Nháp) thì chặn');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('t1'))$$), 'HMT_SAI_TRANG_THAI', 'Duyệt đơn vừa bị từ chối (về Nháp) thì chặn');
select is(pg_temp.ev('t1'), 'TAO,TRINH,TU_CHOI', 'R-TIEN-06: lịch sử đủ Tạo, Trình, Từ chối, không có Duyệt');

-- ================= R-TIEN-03: đơn đã khoá, sửa trực tiếp bị chặn =================
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order_line set quantity = 99 where order_id = pg_temp.o(''v1'')')$$), 'HMT_DON_DA_KHOA', 'R-TIEN-03: sửa dòng đơn Đã duyệt bị chặn');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order_line set unit_price = 1, line_total = 1 where order_id = pg_temp.o(''v1'')')$$), 'HMT_DON_DA_KHOA', 'R-TIEN-14: đổi đơn giá đã chụp của đơn Đã duyệt bị chặn');
select is(pg_temp.err($$select pg_temp.sudo('delete from app.sales_order_line where order_id = pg_temp.o(''v1'')')$$), 'HMT_DON_DA_KHOA', 'R-TIEN-03: xoá dòng đơn Đã duyệt bị chặn');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order_installment set amount = 1 where order_id = pg_temp.o(''v1'')')$$), 'HMT_DON_DA_KHOA', 'R-TIEN-03: sửa lịch đóng tiền đơn Đã duyệt bị chặn');
select is(pg_temp.err($$select pg_temp.sudo('delete from app.sales_order_installment where order_id = pg_temp.o(''v1'')')$$), 'HMT_DON_DA_KHOA', 'R-TIEN-03: xoá đợt đóng tiền đơn Đã duyệt bị chặn');
select is(pg_temp.probe($$select pg_temp.sudo('update app.sales_order set total_amount = 1 where id = pg_temp.o(''v1'')')$$), 'HMT_DON_DA_KHOA', 'R-TIEN-03: sửa tổng tiền của đơn Đã duyệt bị chặn');
select is(pg_temp.probe($$select pg_temp.sudo('update app.sales_order set payment_term_id = null where id = pg_temp.o(''v1'')')$$), 'HMT_DON_DA_KHOA', 'R-TIEN-03: đổi điều khoản thanh toán của đơn Đã duyệt bị chặn');
select is(pg_temp.probe($$select pg_temp.sudo('insert into app.sales_order_line (order_id, line_no, prospect_student_id, package_id, package_code, package_name, package_type_code,
    delivery_mode_code, unit_code, quantity, unit_price, gross_amount, line_total)
  select order_id, 9, prospect_student_id, package_id, package_code, package_name, package_type_code, delivery_mode_code, unit_code, 1, 1, 1, 1
    from app.sales_order_line where order_id = pg_temp.o(''v1'') limit 1')$$), 'HMT_DON_DA_KHOA', 'R-TIEN-03: thêm dòng vào đơn Đã duyệt bị chặn');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order_line set quantity = 99 where order_id = pg_temp.o(''t1'') and false')$$), null, 'Đối chứng: lệnh không đụng dòng nào thì không lỗi');
select pg_temp.go('dd', '0900019001', 10, 3, jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 5)));
select ok((select count(*) from app.sales_order_line_discount where line_id in (select id from app.sales_order_line where order_id = pg_temp.o('dd'))) >= 1, 'Đơn có chiết khấu chụp lại dòng chiết khấu');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order_line_discount set applied_value = 1 where line_id in (select id from app.sales_order_line where order_id = pg_temp.o(''dd''))')$$), 'HMT_DON_DA_KHOA', 'R-TIEN-14: sửa chiết khấu đã chụp của đơn Đã duyệt bị chặn');
select is(pg_temp.err($$select pg_temp.sudo('delete from app.sales_order_line_discount where line_id in (select id from app.sales_order_line where order_id = pg_temp.o(''dd''))')$$), 'HMT_DON_DA_KHOA', 'R-TIEN-14: xoá chiết khấu đã chụp của đơn Đã duyệt bị chặn');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order_line set quantity = quantity where order_id = pg_temp.o(''t1'')')$$), null, 'Đối chứng: đơn Nháp (t1 đã bị từ chối về Nháp) còn sửa được dòng');

-- ================= R-TIEN-02: gốc đơn =================
select is(pg_temp.err($$select pg_temp.sudo('insert into app.sales_order (code, branch_id, opportunity_id, renewal_ticket_id, parent_id, priced_on)
  select ''DHT-HAI-GOC'', branch_id, opportunity_id, gen_random_uuid(), parent_id, current_date from app.sales_order limit 1')$$), '23514', 'R-TIEN-02: đơn có hai gốc (cơ hội và phiếu tái tục) bị CHECK chặn');

-- ================= Lịch sử chỉ thêm, trạng thái đi đúng bảng =================
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order_event set note = ''sửa'' where order_id = pg_temp.o(''v1'')')$$), 'HMT_LICH_SU_CHI_THEM', 'R-TIEN-06: sửa ghi chú lịch sử bị chặn');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order_event set event_code = ''TAO'' where order_id = pg_temp.o(''v1'')')$$), 'HMT_LICH_SU_CHI_THEM', 'R-TIEN-06: đổi loại sự kiện lịch sử bị chặn');
select is(pg_temp.err($$select pg_temp.sudo('delete from app.sales_order_event where order_id = pg_temp.o(''t1'') and event_code = ''TU_CHOI''')$$), 'HMT_LICH_SU_CHI_THEM', 'R-TIEN-06: xoá lần từ chối khỏi lịch sử bị chặn');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order set status_code = ''DA_DUYET'' where id = pg_temp.o(''d1'')')$$), 'HMT_SAI_TRANG_THAI', 'R-TIEN-06: Nháp không nhảy thẳng sang Đã duyệt');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order set status_code = ''DA_TRINH'' where id = pg_temp.o(''v1'')')$$), 'HMT_SAI_TRANG_THAI', 'R-TIEN-03: Đã duyệt không lùi về Đã trình');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order set status_code = ''NHAP'' where id = pg_temp.o(''v1'')')$$), 'HMT_SAI_TRANG_THAI', 'R-TIEN-03: Đã duyệt không lùi về Nháp (khoá không mở được)');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order set code = ''DH-DOI-MA'' where id = pg_temp.o(''d1'')')$$), 'HMT_MA_KHONG_DOI_DUOC', 'Mã đơn không cho sửa');

-- ================= R-TIEN-35: dòng thiếu thông tin em =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('s1', '0900019001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 3), 'LC-TOAN-K09', 'OFF', 5)));
select app.save_order(pg_temp.o('s1'), null, pg_temp.term('CHIA_3_DOT'));
select is(pg_temp.err($$select app.submit_order(pg_temp.o('s1'))$$), 'HMT_EM_THIEU_THONG_TIN', 'R-TIEN-35: đơn một dòng, em thiếu năm sinh thì không trình');
select ok((select count(*) from app.sales_order_event where order_id = pg_temp.o('s1') and event_code = 'TRINH') = 0, 'R-TIEN-35: bị chặn thì không ghi sự kiện Trình');
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, birth_year)
  select o.id, o.branch_id, 4, 2013 from app.opportunity o where o.id = pg_temp.oid('0900019001')$$);
select pg_temp.mk('s2', '0900019001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 4), 'LC-TOAN-K09', 'OFF', 5)));
select app.save_order(pg_temp.o('s2'), null, pg_temp.term('CHIA_3_DOT'));
select is(pg_temp.err($$select app.submit_order(pg_temp.o('s2'))$$), 'HMT_EM_THIEU_THONG_TIN', 'R-TIEN-35: em thiếu họ tên thì không trình');
select pg_temp.mk('s3', '0900019001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 1), 'LC-TOAN-K09', 'OFF', 5), pg_temp.line(pg_temp.ps('0900019001', 3), 'LC-TOAN-K09', 'OFF', 5),
                                                         pg_temp.line(pg_temp.ps('0900019001', 4), 'LC-TOAN-K09', 'OFF', 5)));
select app.save_order(pg_temp.o('s3'), null, pg_temp.term('CHIA_3_DOT'));
select is(pg_temp.err($$select app.submit_order(pg_temp.o('s3'))$$), 'HMT_EM_THIEU_THONG_TIN', 'R-TIEN-35: nhiều dòng thiếu thì vẫn bị chặn');
select matches((select pg_temp.msg($$select app.submit_order(pg_temp.o('s3'))$$)), 'Dòng 2: thiếu năm sinh.*Dòng 3: thiếu họ tên', 'R-TIEN-35: báo đúng từng dòng, từng ô thiếu (dòng 2 năm sinh, dòng 3 họ tên)');

-- ================= R-CRM-27: hồ sơ học sinh chỉ sinh khi duyệt =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mk('b1', '0900019005', jsonb_build_array(pg_temp.line(pg_temp.ps('0900019005', 1), 'LC-TOAN-K09', 'OFF', 10)));
select is(pg_temp.nst('0900019005'), 0, 'R-CRM-27: tạo đơn không sinh hồ sơ học sinh');
select app.save_order(pg_temp.o('b1'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('b1'));
select is(pg_temp.nst('0900019005'), 0, 'R-CRM-27: trình đơn không sinh hồ sơ học sinh');
select is((select approval_route from app.sales_order where id = pg_temp.o('b1')), 'TU_DUYET', 'R-HT-06: Trưởng cơ sở lập thì tự duyệt');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('b1'))$$), 'HMT_KHONG_PHAI_NGUOI_DUYET', 'R-HT-06: Trưởng cơ sở khác không duyệt đơn tự duyệt của người khác');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('b1'))$$), null, 'R-HT-06: Trưởng cơ sở tự duyệt đơn của mình');
select is(pg_temp.nst('0900019005'), 1, 'R-CRM-27: duyệt đơn sinh đúng một hồ sơ học sinh');
select is((select array[s.full_name, s.birth_year::text] from app.sales_order_line l join app.student s on s.id = l.student_id where l.order_id = pg_temp.o('b1')),
          array['Em Bảy', '2011'], 'R-CRM-27: hồ sơ học sinh lấy đúng tên và năm sinh của em');
select ok((select event_note ilike '%tự duyệt%' from (select note as event_note from app.sales_order_event where order_id = pg_temp.o('b1') and event_code = 'DUYET') z),
          'R-HT-06: lịch sử ghi "tự duyệt" khi Trưởng cơ sở duyệt đơn của chính mình');
select is((select approved_on_behalf from app.sales_order where id = pg_temp.o('b1')), false, 'Tự duyệt không phải duyệt thay');

-- ================= R-HT-06: người duyệt chốt lúc trình, đổi quản lý sau đó không đổi =================
select pg_temp.go('sn', '0900019002', 10, 2);
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1b'));
select is((select assigned_approver_id from app.sales_order where id = pg_temp.o('sn')), pg_temp.uid('bm1'), 'R-HT-06: đổi quản lý sau khi trình không đổi người duyệt đã chốt');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('sn'))$$), 'HMT_KHONG_PHAI_NGUOI_DUYET', 'R-HT-06: quản lý mới không duyệt đơn đã trình trước khi đổi');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('sn'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_DUOC_HUY_DON', 'R-TIEN-38: quản lý mới không huỷ đơn đã trình trước khi đổi');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('sn'))$$), null, 'R-HT-06: người đã chốt vẫn duyệt được dù không còn là quản lý');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));

-- ================= R-HT-01 / R-HT-06: Admin duyệt thay mọi cơ sở; Admin lập không có quản lý =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select pg_temp.mk('c5', '0900019099', jsonb_build_array(pg_temp.line(pg_temp.ps('0900019099', 1), 'LC-TOAN-K09', 'OFF', 10)));
select app.save_order(pg_temp.o('c5'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('c5'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('c5'))$$), 'HMT_KHONG_CO_QUYEN', 'Trưởng cơ sở CS1 không duyệt đơn CS5');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('c5'))$$), null, 'R-HT-01: Admin (aal2) duyệt thay đơn ở cơ sở khác');
select is((select approved_on_behalf from app.sales_order where id = pg_temp.o('c5')), true, 'R-HT-01: ghi duyệt thay');
select is((select note from app.sales_order_event where order_id = pg_temp.o('c5') and event_code = 'DUYET'), 'Admin duyệt thay', 'R-HT-01: lịch sử ghi "Admin duyệt thay"');
select is(pg_temp.err($$select pg_temp.mk('ad1', '0900019002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900019002', 1), 'LC-TOAN-K09', 'OFF', 10)))$$), null, 'Admin tạo được đơn (đối chứng cho bài kế)');
select app.save_order(pg_temp.o('ad1'), null, pg_temp.term('CHIA_3_DOT'));
select is(pg_temp.err($$select app.submit_order(pg_temp.o('ad1'))$$), 'HMT_KHONG_CO_QUAN_LY', 'R-HT-06: Admin lập (không phải Trưởng cơ sở, không có quản lý) thì không trình được');

-- ================= R-TIEN-37 / R-TIEN-14: tiền các dòng nhất quán =================
select is((select count(*)::int from app.sales_order_line l where l.line_kind = 'ENROL' and l.line_total <> l.gross_amount - l.discount_amount), 0, 'R-TIEN-37: thành tiền sau chiết khấu = thành tiền − tiền chiết khấu, mọi dòng');
select is((select string_agg(o.code, ',') from app.sales_order o where o.total_amount <> (select coalesce(sum(l.line_total), 0) from app.sales_order_line l where l.order_id = o.id)), null, 'Tổng đơn bằng tổng thành tiền các dòng');
select pg_temp.mk('r4', '0900019002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900019002', 1), 'LC-TOAN-K09', 'OFF', 0.01)));
select is((select gross_amount from app.sales_order_line where order_id = pg_temp.o('r4')), 2200::bigint, 'R-TIEN-37: 0,01 giờ × 220.000 = 2.200 đ');
select pg_temp.mk('r5', '0900019002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900019002', 1), 'LC-TOAN-K09', 'OFF', 0.07, jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 0.5)))));
select is((select array[gross_amount::text, discount_amount::text, line_total::text] from app.sales_order_line where order_id = pg_temp.o('r5')),
          array['15400', '77', '15323'], 'R-TIEN-37: 0,5% của 15.400 = 77 đ (không làm tròn lên), thành tiền 15.323');

-- ================= R-TIEN-07: lịch đóng tiền =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('i1', '0900019002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900019002', 1), 'LC-TOAN-K09', 'OFF', 0.33)));
select app.save_order(pg_temp.o('i1'), null, pg_temp.term('CHIA_3_DOT'));
select is((select sum(amount) from app.sales_order_installment where order_id = pg_temp.o('i1')), 72600::numeric, 'R-TIEN-07: tổng các đợt bằng tổng đơn kể cả khi phần lẻ (72.600 chia 3 đợt)');
select is((select array_agg(seq order by seq) from app.sales_order_installment where order_id = pg_temp.o('i1')), (select array_agg(g) from generate_series(1, (select count(*)::int from app.sales_order_installment where order_id = pg_temp.o('i1'))) g), 'R-TIEN-07: các đợt đánh số liên tục từ 1');
select is((select amount >= (select min(amount) from app.sales_order_installment where order_id = pg_temp.o('i1') and seq = 2) from app.sales_order_installment where order_id = pg_temp.o('i1') order by seq desc limit 1), true, 'R-TIEN-07: đợt cuối không nhỏ hơn đợt giữa (phần lẻ dồn vào đợt cuối)');
select is(pg_temp.err($$select app.save_order(pg_temp.o('i1'), null, pg_temp.term('COC_VA_CHIA_DOT'))$$), 'HMT_COC_VUOT_DON', 'R-TIEN-07: cọc cố định không nhỏ hơn tổng đơn thì chặn');
select is((select payment_term_id from app.sales_order where id = pg_temp.o('i1')), pg_temp.term('CHIA_3_DOT'), 'R-TIEN-07: lưu bị chặn thì giữ nguyên điều khoản cũ');
select is((select sum(amount) from app.sales_order_installment where order_id = pg_temp.o('i1')), 72600::numeric, 'R-TIEN-07: lưu bị chặn thì lịch đóng tiền cũ còn nguyên');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('i1'))$$), null, 'Đơn nhỏ với điều khoản chia đợt trình được');
select is((select count(*)::int from app.sales_order_installment where order_id = pg_temp.o('i1') and due_date is not null), 0, 'R-TIEN-07: trình chưa chốt hạn đóng, chỉ chốt khi duyệt');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_order(pg_temp.o('i1'));
select is((select count(*)::int from app.sales_order_installment where order_id = pg_temp.o('i1') and due_date is distinct from (now() at time zone 'Asia/Ho_Chi_Minh')::date + due_days), 0, 'R-TIEN-07: hạn đóng mọi đợt = ngày duyệt + số ngày của đợt');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.save_order(pg_temp.o('d2'), null, pg_temp.term('COC_VA_CHIA_DOT'))$$), null, 'Đối chứng: đổi điều khoản đơn đủ lớn được');
select is((select array_agg(amount order by seq) from app.sales_order_installment where order_id = pg_temp.o('d2')), array[1000000, 1200000]::bigint[], 'R-TIEN-07: đổi điều khoản thì lịch tính lại (không còn đợt cũ)');

-- ================= R-GD-06, R-GD-08: lớp và ngày vào lớp =================
select is(pg_temp.err($$select app.save_order(pg_temp.o('d1'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 1), 'LC-TOAN-K09', 'OFF', 10) || jsonb_build_object('class_id', gen_random_uuid())))$$),
          'HMT_THIEU_NGAY_VAO_LOP', 'R-GD-06: chọn lớp mà không có ngày vào lớp thì chặn khi lưu');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order_line set class_id = gen_random_uuid(), enrol_start_date = null where order_id = pg_temp.o(''d1'')')$$), '23514', 'R-GD-06: dòng có lớp mà không có ngày vào lớp bị CHECK chặn ở bảng');
select isnt(pg_temp.err($$select app.save_order(pg_temp.o('d1'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019001', 1), 'LC-TOAN-K09', 'OFF', 10)
          || jsonb_build_object('class_id', gen_random_uuid(), 'enrol_start_date', current_date + 3)))$$), null, 'R-GD-08: lớp không tồn tại/không hợp lệ không lưu được');
select pg_temp.sudo($$update app.sales_order_line set class_id = gen_random_uuid(), enrol_start_date = current_date + 3 where order_id = pg_temp.o('d2')$$);
select is(pg_temp.err($$select app.submit_order(pg_temp.o('d2'))$$), 'HMT_LOP_CHUA_CO_BANG', 'R-GD-08: lớp trên dòng được kiểm lại khi trình (kiểm thật chờ P5b; hiện chỉ biết hàm kiểm lớp có được gọi)');
select is(pg_temp.st('d2'), 'NHAP', 'R-GD-08: lớp không hợp lệ thì đơn không qua Đã trình');

-- ================= Báo giá -> đơn (R-TIEN-02, R-TIEN-14, R-CRM-16) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 3, 'Em Ba Báo Giá', 2013 from app.opportunity o where o.id = pg_temp.oid('0900019010')$$);
insert into qs select 'q3', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900019010'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900019010', 1), 'LC-TOAN-K09', 'OFF', 3))) as r) x;
select app.cancel_quotation(pg_temp.q('q3'));
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q3'))$$), 'HMT_BAO_GIA_CHUA_GUI', 'R-TIEN-14: báo giá đã Huỷ không chuyển đơn được');
insert into qs select 'q1', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900019010'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900019010', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 5))),
                    pg_temp.line(pg_temp.ps('0900019010', 2), 'LC-TOAN-K09', 'OFF', 5),
                    pg_temp.line(pg_temp.ps('0900019010', 3), 'LC-TOAN-K09', 'OFF', 2))) as r) x;
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'))$$), 'HMT_BAO_GIA_CHUA_GUI', 'R-TIEN-14: báo giá Nháp không chuyển đơn được');
select app.send_quotation(pg_temp.q('q1'));
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'))$$), 'HMT_CHUA_O_L8', 'R-CRM-16: cơ hội chưa L8 thì không chuyển báo giá thành đơn');
select is((select count(*)::int from app.sales_order where quotation_id = pg_temp.q('q1')), 0, 'R-CRM-16: bị chặn thì không có đơn');
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id = pg_temp.oid('0900019010')$$);
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'))$$), 'HMT_KHONG_CO_QUYEN', 'Sai vai trò: Kế toán không chuyển báo giá thành đơn');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'))$$), 'HMT_KHONG_CO_QUYEN', 'Sai vai trò: học sinh không chuyển báo giá thành đơn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'), array[]::integer[])$$), 'HMT_KHONG_CO_DONG_DE_CHUYEN', 'Danh sách dòng rỗng thì không có dòng nào để chuyển');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'), array[0])$$), 'HMT_DONG_KHONG_CO', 'Số dòng 0 không thuộc báo giá thì chặn');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'), array[-1])$$), 'HMT_DONG_KHONG_CO', 'Số dòng âm không thuộc báo giá thì chặn');
select is((select count(*)::int from app.sales_order where quotation_id = pg_temp.q('q1')), 0, 'Các ca bị chặn không để lại đơn nào');
insert into os select 'qa', (r ->> 'id')::uuid, r ->> 'code' from (select app.create_order_from_quotation(pg_temp.q('q1'), array[1]) as r) x;
select is((select array[gross_amount, discount_amount, line_total, unit_price] from app.sales_order_line where order_id = pg_temp.o('qa') and line_no = 1),
          (select array[gross_amount, discount_amount, line_total, unit_price] from app.quotation_line where quotation_id = pg_temp.q('q1') and line_no = 1),
          'R-TIEN-14: đơn sao nguyên tiền đã đóng băng của dòng báo giá');
select is((select count(*)::int from app.sales_order_line_discount where line_id in (select id from app.sales_order_line where order_id = pg_temp.o('qa'))), 1, 'R-TIEN-14: đơn sao cả chính sách chiết khấu của dòng báo giá');
select is((select o.priced_on = q.priced_on and o.parent_id = q.parent_id and o.opportunity_id = q.opportunity_id from app.sales_order o join app.quotation q on q.id = o.quotation_id where o.id = pg_temp.o('qa')), true, 'Đơn lấy ngày tính giá, phụ huynh, cơ hội của báo giá');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'), array[2, 1])$$), 'HMT_DONG_DA_CO_DON', 'R-TIEN-02: hai đơn sống cùng một dòng báo giá bị chặn (chọn tay có dòng đã dùng)');
select is((select count(*)::int from app.sales_order where quotation_id = pg_temp.q('q1')), 1, 'R-TIEN-02: ca bị chặn không để lại đơn dở dang (đơn thứ hai không có)');
select is(pg_temp.qlive(pg_temp.q('q1')), true, 'Báo giá có đơn đang sống');
select is(pg_temp.qconv(pg_temp.q('q1')), false, 'R-TIEN-02: mới 1/3 dòng nằm trong đơn sống thì chưa "Đã chuyển đơn"');
-- Sửa dòng đơn từ báo giá: giá đóng băng.
select is(pg_temp.err($$select app.save_order(pg_temp.o('qa'), jsonb_build_array(jsonb_build_object('line_no', 1, 'quantity', 99, 'unit_price', 1, 'line_total', 1)))$$), null, 'Lưu đơn từ báo giá: trường ngoài lớp, ngày vào lớp không có tác dụng');
select is((select array[quantity::text, unit_price::text] from app.sales_order_line where order_id = pg_temp.o('qa') and line_no = 1), array['10.00', '220000'], 'R-TIEN-14: đơn từ báo giá không đổi giờ, đơn giá khi lưu');
select is(pg_temp.err($$select app.save_order(pg_temp.o('qa'), jsonb_build_array(jsonb_build_object('line_no', 7)))$$), 'HMT_DONG_KHONG_CO', 'Lưu đơn từ báo giá, số dòng không có trong đơn thì chặn');
insert into os select 'qb', (r ->> 'id')::uuid, r ->> 'code' from (select app.create_order_from_quotation(pg_temp.q('q1')) as r) x;
select is((select count(*)::int from app.sales_order_line where order_id = pg_temp.o('qb')), 2, 'Chọn mọi dòng: chỉ lấy hai dòng còn lại');
select is(pg_temp.qconv(pg_temp.q('q1')), true, 'R-TIEN-02: mọi dòng nằm trong đơn sống thì "Đã chuyển đơn"');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'))$$), 'HMT_KHONG_CO_DONG_DE_CHUYEN', 'Chuyển lần hai khi hết dòng thì báo rõ');
select is(pg_temp.err($$select app.cancel_quotation(pg_temp.q('q1'))$$), 'HMT_BAO_GIA_DA_CO_DON', 'Báo giá đã có đơn sống không huỷ được');
-- Huỷ đơn trả dòng về báo giá, kể cả đơn Đã trình và Đã duyệt.
select app.save_order(pg_temp.o('qb'), null, pg_temp.term('CHIA_3_DOT'));
select app.save_order(pg_temp.o('qa'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('qa'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_order(pg_temp.o('qa'), true);
select is(pg_temp.qconv(pg_temp.q('q1')), true, 'Đơn Đã duyệt vẫn giữ dòng ở trạng thái sống');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('qa'), 'KHACH_DOI_Y')$$), null, 'R-TIEN-38: người duyệt đã chốt huỷ đơn Đã duyệt');
select is(pg_temp.qconv(pg_temp.q('q1')), false, 'R-TIEN-02: đơn Đã duyệt bị huỷ trả dòng về báo giá');
select is(pg_temp.qlive(pg_temp.q('q1')), true, 'Báo giá vẫn còn đơn sống khác (qb)');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'), array[1])$$), null, 'R-TIEN-02: dòng được trả về chuyển lại thành đơn mới được');
select is((select count(*)::int from app.sales_order_line where quotation_line_id in (select id from app.quotation_line where quotation_id = pg_temp.q('q1')) and is_live), 3, 'R-TIEN-02: mỗi dòng báo giá chỉ nằm trong đúng một đơn sống');

-- ================= R-TIEN-38: huỷ đơn =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('d1'), 'KHAC', '   ')$$), 'HMT_LY_DO_THIEU', 'R-TIEN-38: lý do Khác với ghi chú toàn khoảng trắng thì chặn');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('d1'), 'SAI_SO_TIEN')$$), 'HMT_LY_DO_THIEU', 'R-TIEN-38: lý do thuộc danh mục khác (lý do phiếu thu) không dùng được để huỷ đơn');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('d1'), '')$$), 'HMT_LY_DO_THIEU', 'R-TIEN-38: lý do rỗng thì chặn');
select is(pg_temp.st('d1'), 'NHAP', 'R-TIEN-38: huỷ bị chặn thì đơn giữ nguyên');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('v1'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_DUOC_HUY_DON', 'R-TIEN-38: đơn Đã duyệt thì người lập không huỷ được');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('v1'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_DUOC_HUY_DON', 'R-TIEN-38: đơn Đã duyệt thì người không phải người duyệt đã chốt không huỷ được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('d1'), 'KHACH_DOI_Y')$$), 'HMT_KHONG_DUOC_HUY_DON', 'R-TIEN-38: đơn Nháp chỉ người lập huỷ, Admin cũng không huỷ thay đơn Nháp');
-- Đã có phiếu thu thì không huỷ (hàm kiểm phiếu thu trả true tạm trong giao dịch thử).
select pg_temp.sudo($$create or replace function app.order_has_receipt(p_order_id uuid) returns boolean language sql stable set search_path = '' as 'select true'$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('v1'), 'KHACH_DOI_Y')$$), 'HMT_DON_DA_CO_PHIEU_THU', 'R-TIEN-38: đơn Đã duyệt đã có phiếu thu thì người duyệt không huỷ được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('v1'), 'KHACH_DOI_Y')$$), 'HMT_DON_DA_CO_PHIEU_THU', 'R-TIEN-38: đơn đã có phiếu thu thì Admin huỷ thay cũng bị chặn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('d2'), 'KHACH_DOI_Y')$$), 'HMT_DON_DA_CO_PHIEU_THU', 'R-TIEN-38: đơn Nháp đã có phiếu thu cũng không huỷ được');
select is(pg_temp.st('v1') || ':' || (select bool_and(is_live)::text from app.sales_order_line where order_id = pg_temp.o('v1')), 'DA_DUYET:true', 'R-TIEN-38: bị chặn vì phiếu thu thì đơn giữ Đã duyệt, dòng còn sống');
select pg_temp.sudo($$create or replace function app.order_has_receipt(p_order_id uuid) returns boolean language sql stable set search_path = '' as 'select false'$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('v1'), 'KHAC', 'Khách đổi lịch')$$), null, 'R-TIEN-38: chưa có phiếu thu, người duyệt đã chốt huỷ đơn Đã duyệt');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('v1'), 'KHACH_DOI_Y')$$), 'HMT_SAI_TRANG_THAI', 'Huỷ đơn đã huỷ thì chặn');
select is((select array[cancel_reason_code, cancel_note, (cancelled_by = pg_temp.uid('bm1'))::text] from app.sales_order where id = pg_temp.o('v1')), array['KHAC', 'Khách đổi lịch', 'true'], 'R-TIEN-38: ghi lý do, ghi chú, người huỷ');
select is((select reason_code from app.sales_order_event where order_id = pg_temp.o('v1') and event_code = 'HUY'), 'KHAC', 'R-TIEN-38: lịch sử ghi lý do huỷ');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('v1'))$$), 'HMT_SAI_TRANG_THAI', 'Đơn đã huỷ không trình lại được');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('v1'))$$), 'HMT_SAI_TRANG_THAI', 'Đơn đã huỷ không duyệt được');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.save_order(pg_temp.o('v1'), null, pg_temp.term('CHIA_3_DOT'))$$), 'HMT_DON_DA_KHOA', 'Đơn đã huỷ không sửa được');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order_line set quantity = 1 where order_id = pg_temp.o(''v1'')')$$), 'HMT_DON_DA_KHOA', 'Dòng của đơn đã huỷ không sửa trực tiếp được');
select is(pg_temp.err($$select pg_temp.sudo('update app.sales_order_line set is_live = true where order_id = pg_temp.o(''v1'')')$$), 'HMT_DON_DA_KHOA', 'Đơn đã huỷ không "sống lại" dòng bằng cách bật cờ');

-- ================= R-TIEN-14: đơn thẳng tính theo ngày tạo đơn =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('pr', '0900019002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900019002', 1), 'LC-TOAN-K09', 'OFF', 10)));
select pg_temp.sudo($$update app.sales_order set priced_on = current_date - 3 where id = pg_temp.o('pr')$$);
select pg_temp.sudo($$insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
  select id, 'OFF', 333000, (now() at time zone 'Asia/Ho_Chi_Minh')::date from app.sales_package where code = 'LC-TOAN-K09'$$);
select app.save_order(pg_temp.o('pr'), jsonb_build_array(pg_temp.line(pg_temp.ps('0900019002', 1), 'LC-TOAN-K09', 'OFF', 10)));
select is((select unit_price from app.sales_order_line where order_id = pg_temp.o('pr')), 220000::bigint, 'R-TIEN-14: đơn tạo thẳng giữ giá hiệu lực ngày tạo đơn, lưu lại sau khi bảng giá đổi không tính lại theo giá mới');

-- ================= Công tắc tính năng với duyệt, từ chối, chuyển báo giá (Đ173) =================
select pg_temp.go('f1', '0900019001', 10, 2);
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('f1'), true)$$), 'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì không duyệt đơn');
select is(pg_temp.err($$select app.reject_order(pg_temp.o('f1'), 'KHONG_DUNG_CHINH_SACH', 'x')$$), 'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì không từ chối đơn');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.create_order_from_quotation(pg_temp.q('q1'), array[2])$$), 'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì không chuyển báo giá thành đơn');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);

-- ================= RLS và ghi trực tiếp =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$update app.sales_order set total_amount = 1$$), '42501', 'Ghi thẳng: Sale không cập nhật được bảng đơn');
select is(pg_temp.err($$update app.sales_order_line set quantity = 1$$), '42501', 'Ghi thẳng: Sale không cập nhật được dòng đơn');
select is(pg_temp.err($$delete from app.sales_order_event$$), '42501', 'Ghi thẳng: Sale không xoá được lịch sử đơn');
select is(pg_temp.err($$insert into app.sales_order_event (order_id, branch_id, event_code, to_status) select id, branch_id, 'DUYET', 'DA_DUYET' from app.sales_order limit 1$$), '42501', 'Ghi thẳng: Sale không thêm được sự kiện giả vào lịch sử');
select is(pg_temp.err($$update app.sales_order_installment set amount = 1$$), '42501', 'Ghi thẳng: Sale không sửa được lịch đóng tiền');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$update app.sales_order set status_code = 'DA_DUYET'$$), '42501', 'Ghi thẳng: Trưởng cơ sở không tự đổi trạng thái đơn qua bảng');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((select count(*)::int from app.sales_order_line l join app.sales_order o on o.id = l.order_id where o.code like 'DH-CS1-%'), 0, 'RLS: Sale CS5 không thấy dòng đơn CS1');
select is((select count(*)::int from app.sales_order_installment i join app.sales_order o on o.id = i.order_id where o.code like 'DH-CS1-%'), 0, 'RLS: Sale CS5 không thấy lịch đóng tiền đơn CS1');
select is((select count(*)::int from app.sales_order_line_discount d join app.sales_order_line l on l.id = d.line_id join app.sales_order o on o.id = l.order_id where o.code like 'DH-CS1-%'), 0, 'RLS: Sale CS5 không thấy chiết khấu dòng đơn CS1');
select is((select count(*)::int from app.sales_order_event e join app.sales_order o on o.id = e.order_id where o.code like 'DH-CS1-%'), 0, 'RLS: Sale CS5 không thấy lịch sử đơn CS1');
select ok((select count(*) from app.sales_order where code like 'DH-CS5-%') >= 1, 'RLS: Sale CS5 thấy đơn CS5');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is((select count(*)::int from app.sales_order_line) + (select count(*)::int from app.sales_order_installment) + (select count(*)::int from app.sales_order_event), 0, 'RLS: học sinh không thấy dòng, đợt, lịch sử đơn');

select * from finish();
rollback;
