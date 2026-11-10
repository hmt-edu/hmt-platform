-- P5a-DB-O2c (migration 063, Đ283): tự duyệt khi Trưởng cơ sở trình (Q-P6, Đ102, R-TIEN-35, KD6, R-HT-06) và bốn cờ quyền của get_order.
-- Mỗi luật có ca đúng và ca bị chặn; ma trận cờ so với việc hàm ghi chạy được hay bị chặn (từng vai, từng trạng thái); mỗi vai đọc trong và ngoài cơ sở.
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
  select jsonb_build_object('parent_name', 'Chị Đơn Hàng', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('bm1b'), ('sales1'), ('sales1b'), ('sales1c'), ('cskh1'), ('sales5'), ('bm5'), ('ke'), ('hs');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999998' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm1b', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales1c', 'CS1'),
                      ('cskh1', 'CS1'), ('sales5', 'CS5'), ('bm5', 'CS5'), ('ke', 'CS1'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm1b', 'BRANCH_MANAGER'), ('sales1', 'SALES'),
  ('sales1b', 'SALES'), ('sales1c', 'SALES'), ('cskh1', 'CSKH'), ('sales5', 'SALES'), ('bm5', 'BRANCH_MANAGER'),
  ('ke', 'ACCOUNTANT'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- Bán hàng bật ở CS1 cho bài (Đ173); seed thường chỉ bật CS5.
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$create function pg_temp.pkg(p_code text) returns uuid language sql stable security definer as 'select id from app.sales_package where code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.pol(p_code text) returns uuid language sql stable security definer as 'select id from app.discount_policy where code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.term(p_code text) returns uuid language sql stable security definer as 'select id from app.payment_term where code = p_code and version = 1'$$);
select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as 'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone order by o.code limit 1'$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable security definer as 'select id from app.lead where parent_phone = p_phone order by code limit 1'$$);
select pg_temp.sudo($$create function pg_temp.ps(p_phone text, p_pos integer) returns uuid language sql stable security definer as
  'select ps.id from app.prospect_student ps where ps.opportunity_id = pg_temp.oid(p_phone) and ps.position = p_pos'$$);
select pg_temp.sudo($$grant execute on function pg_temp.pkg(text), pg_temp.pol(text), pg_temp.term(text), pg_temp.oid(text), pg_temp.lid(text),
  pg_temp.ps(text, integer) to public$$);
-- Một dòng nhập cho đơn thẳng từ cơ hội.
create function pg_temp.line(p_ps uuid, p_pkg text, p_mode text, p_qty numeric, p_disc jsonb default '[]'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('kind', 'ENROL', 'prospect_student_id', p_ps, 'package_id', pg_temp.pkg(p_pkg), 'delivery_mode_code', p_mode,
                            'quantity', p_qty, 'discounts', p_disc) $$;
grant execute on function pg_temp.line(uuid, text, text, numeric, jsonb) to public;
create function pg_temp.disc(p_policy text, p_value numeric default null) returns jsonb language sql as $$
  select jsonb_build_object('policy_id', pg_temp.pol(p_policy), 'value', p_value) $$;
grant execute on function pg_temp.disc(text, numeric) to public;
create temp table os (key text primary key, id uuid, code text);
grant all on os to public;
create temp table qs (key text primary key, id uuid, code text);
grant all on qs to public;
create function pg_temp.o(p_key text) returns uuid language sql stable as $$ select id from os where key = p_key $$;
create function pg_temp.q(p_key text) returns uuid language sql stable as $$ select id from qs where key = p_key $$;
grant execute on function pg_temp.o(text), pg_temp.q(text) to public;
-- Tạo đơn thẳng và nhớ theo khoá.
create function pg_temp.mk(p_key text, p_phone text, p_lines jsonb) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := app.create_order_from_opportunity(pg_temp.oid(p_phone), p_lines, null, true);
  insert into os values (p_key, (r ->> 'id')::uuid, r ->> 'code');
  return r;
end $$;
grant execute on function pg_temp.mk(text, text, jsonb) to public;
-- Trạng thái, người duyệt, các giá trị khác của đơn (đọc bằng quyền chủ).
select pg_temp.sudo($$create function pg_temp.st(p_key text) returns text language sql stable security definer as 'select status_code from app.sales_order where id = pg_temp.o(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.ev(p_key text) returns text language sql stable security definer as
  'select string_agg(event_code, '','' order by seq) from app.sales_order_event where order_id = pg_temp.o(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.qlive(p uuid) returns boolean language sql stable security definer as 'select app.quotation_has_live_order(p)'$$);
select pg_temp.sudo($$create function pg_temp.qconv(p uuid) returns boolean language sql stable security definer as 'select app.quotation_converted(p)'$$);
select pg_temp.sudo($$create function pg_temp.docs(p uuid) returns text[] language sql stable security definer as 'select app.opportunity_sales_documents(p)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.st(text), pg_temp.ev(text), pg_temp.qlive(uuid), pg_temp.qconv(uuid), pg_temp.docs(uuid) to public$$);

-- ================= Dựng dữ liệu =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
select app.set_manager(pg_temp.uid('sales1c'), pg_temp.uid('cskh1'));
select app.set_manager(pg_temp.uid('cskh1'), pg_temp.uid('bm1'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009001', '{"parent_name": "Chị Đơn Một", "student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900009002', '{"parent_name": "Chị Đơn Hai", "student_name": "Em Bốn", "student_birth_year": 2010}'));
select app.create_lead(pg_temp.lead_data('0900009003', '{"parent_name": "Chị Sinh Đôi", "student_name": "Em Sinh Đôi", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900009009', '{"parent_name": "Chị Chưa L8", "student_name": "Em Chín", "student_birth_year": 2012}'));
select pg_temp.claims(pg_temp.uid('sales1c'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009004', '{"parent_name": "Chị Quản Lý Thiếu Quyền", "student_name": "Em Năm", "student_birth_year": 2011}'));
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009006', '{"parent_name": "Chị Không Quản Lý", "student_name": "Em Sáu", "student_birth_year": 2011}'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009005', '{"parent_name": "Chị Tự Duyệt", "student_name": "Em Bảy", "student_birth_year": 2011}'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900009099', '{"parent_name": "Chị Đơn CS5", "student_name": "Em Tám", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900009001'));
select app.create_opportunity(pg_temp.lid('0900009002'));
select app.create_opportunity(pg_temp.lid('0900009003'));
select app.create_opportunity(pg_temp.lid('0900009009'));
select pg_temp.claims(pg_temp.uid('sales1c'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900009004'));
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900009006'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900009005'));
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select app.create_opportunity(pg_temp.lid('0900009099'));
-- Em thứ hai (đủ), em thứ ba (thiếu năm sinh) của cơ hội 1; hai em trùng tên và năm sinh ở cơ hội 3 (KD6).
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Hai', 2014 from app.opportunity o where o.id = pg_temp.oid('0900009001')$$);
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name)
  select o.id, o.branch_id, 3, 'Em Ba' from app.opportunity o where o.id = pg_temp.oid('0900009001')$$);
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Sinh Đôi', 2012 from app.opportunity o where o.id = pg_temp.oid('0900009003')$$);
-- Các cơ hội đã thanh toán thật (L8), trừ 0900009009 giữ ở L1 (R-CRM-16).
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in
  (pg_temp.oid('0900009001'), pg_temp.oid('0900009002'), pg_temp.oid('0900009003'), pg_temp.oid('0900009004'),
   pg_temp.oid('0900009005'), pg_temp.oid('0900009006'), pg_temp.oid('0900009099'))$$);


-- ================= Dữ liệu: ba đơn CS1 ở ba trạng thái + một đơn huỷ + một đơn CS5 + một đơn từ báo giá =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('n1', '0900009001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_6_THANG'))),
                                                          pg_temp.line(pg_temp.ps('0900009001', 2), 'LC-TOAN-K09', 'OFF', 5)));
select pg_temp.mk('n2', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 20)));
select app.save_order(pg_temp.o('n2'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('n2'));
select pg_temp.mk('n3', '0900009003', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009003', 1), 'LC-TOAN-K09', 'OFF', 30)));
select app.save_order(pg_temp.o('n3'), null, pg_temp.term('CHIA_3_DOT'));
select app.submit_order(pg_temp.o('n3'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_order(pg_temp.o('n3'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('n4', '0900009004', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009004', 1), 'LC-TOAN-K09', 'OFF', 12)));
select app.cancel_order(pg_temp.o('n4'), 'KHAC', 'Nhập nhầm');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select pg_temp.mk('n5', '0900009099', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009099', 1), 'LC-TOAN-K09', 'OFF', 8)));
-- Đơn từ báo giá.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
insert into qs select 'q1', (r ->> 'id')::uuid, r ->> 'code' from (select app.save_quotation(null, pg_temp.oid('0900009005'),
  jsonb_build_array(pg_temp.line(pg_temp.ps('0900009005', 1), 'LC-TOAN-K09', 'OFF', 6))) as r) x;
select app.send_quotation(pg_temp.q('q1'));
insert into os select 'n6', (r ->> 'id')::uuid, r ->> 'code' from (select app.create_order_from_quotation(pg_temp.q('q1')) as r) x;


-- ================= Hàm trợ giúp O2c =================
create function pg_temp.evs(p_key text) returns text language sql stable security definer set search_path = '' as
  $f$ select string_agg(event_code, ',' order by seq) from app.sales_order_event where order_id = (select id from pg_temp.os where key = p_key) $f$;
create function pg_temp.stat(p_key text) returns text language sql stable security definer set search_path = '' as
  $f$ select status_code from app.sales_order where id = (select id from pg_temp.os where key = p_key) $f$;
create function pg_temp.col(p_key text, p_col text) returns text language plpgsql stable security definer set search_path = '' as
  $f$ declare r text; begin execute format('select %I::text from app.sales_order where id = (select id from pg_temp.os where key = %L)', p_col, p_key) into r; return r; end $f$;
create function pg_temp.gof(p_key text) returns jsonb language sql as $f$ select app.get_order(pg_temp.o(p_key)) $f$;
grant execute on function pg_temp.evs(text), pg_temp.stat(text), pg_temp.col(text, text), pg_temp.gof(text) to public;
-- Chạy một lệnh ghi thử rồi LUÔN hoàn tác: trả 'duoc' nếu hàm chạy được (hoặc chỉ vướng lỗi dữ liệu), 'chan' nếu bị chặn vì quyền hoặc trạng thái.
create function pg_temp.probe(p_sql text) returns text language plpgsql as $f$
declare v_hint text; v_state text;
begin
  begin
    execute p_sql;
    raise exception 'thu xong' using hint = 'PROBE_OK';
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
    if v_hint = 'PROBE_OK' then return 'duoc'; end if;
    if v_hint in ('HMT_KHONG_CO_QUYEN', 'HMT_SAI_TRANG_THAI', 'HMT_KHONG_PHAI_NGUOI_DUYET', 'HMT_KHONG_DUOC_HUY_DON',
                  'HMT_DON_DA_CO_PHIEU_THU', 'HMT_TINH_NANG_TAT', 'HMT_KHONG_TIM_THAY') then return 'chan'; end if;
    if v_hint like 'HMT\_%' then return 'duoc'; end if; -- lỗi dữ liệu (thiếu điều khoản, em thiếu thông tin, chưa có quản lý...): không phải lỗi quyền
    return 'khac:' || v_state;
  end;
end $f$;
-- Ma trận: mỗi cờ của get_order phải khớp việc hàm ghi tương ứng chạy được hay bị chặn. Trả chuỗi các ô lệch (rỗng là khớp hết).
create function pg_temp.mismatches(p_admin_aal text default 'aal2') returns text language plpgsql as $f$
declare u text; k text; r record; v jsonb; out_text text := ''; flag boolean; res text;
begin
  foreach u in array array['admin', 'bm1', 'bm1b', 'sales1', 'sales1b', 'sales1c', 'cskh1', 'sales5', 'bm5', 'ke', 'hs'] loop
    perform pg_temp.claims(pg_temp.uid(u), case when u = 'admin' then p_admin_aal when u = 'ke' then 'aal2' else 'aal1' end);
    foreach k in array array['n1', 'b6', 'n2', 'n3', 'n4', 'n5'] loop
      begin v := app.get_order(pg_temp.o(k)); exception when others then v := null; end;
      for r in select * from (values
          ('can_submit', format('select app.submit_order(%L)', pg_temp.o(k))),
          ('can_cancel', format('select app.cancel_order(%L, ''KHACH_DOI_Y'')', pg_temp.o(k))),
          ('can_approve', format('select app.approve_order(%L, true)', pg_temp.o(k))),
          ('can_reject', format('select app.reject_order(%L, ''THIEU_THONG_TIN'')', pg_temp.o(k)))) as t (flag_name, sql) loop
        flag := coalesce((v ->> r.flag_name)::boolean, false);
        res := pg_temp.probe(r.sql);
        if (flag and res <> 'duoc') or (not flag and res <> 'chan') then
          out_text := out_text || format('%s/%s/%s: cờ=%s hàm=%s; ', u, k, r.flag_name, flag, res);
        end if;
      end loop;
    end loop;
  end loop;
  return out_text;
end $f$;
grant execute on function pg_temp.probe(text), pg_temp.mismatches(text) to public;

-- ================= Dữ liệu O2c =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
-- Trưởng cơ sở bm1 lập: b1 (không cần tích), b2 (chính sách cần duyệt), b3 (cờ cần tích đặt sai), b4 (em thiếu năm sinh), b5 (hai em trùng, KD6),
-- b6 (người khác trình), b7 (bm1b trình), b8 (chữ ký một tham số), b9 (thử tắt Bán hàng).
select pg_temp.mk('b1', '0900009005', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009005', 1), 'LC-TOAN-K09', 'OFF', 6)));
select pg_temp.mk('b2', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 5)))));
select pg_temp.mk('b3', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 5)))));
select pg_temp.mk('b4', '0900009004', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009004', 1), 'LC-TOAN-K09', 'OFF', 6)));
select pg_temp.mk('b5', '0900009003', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009003', 1), 'LC-TOAN-K09', 'OFF', 4), pg_temp.line(pg_temp.ps('0900009003', 2), 'LC-TOAN-K09', 'OFF', 4)));
select pg_temp.mk('b6', '0900009001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 6)));
select pg_temp.mk('b7', '0900009005', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009005', 1), 'LC-TOAN-K09', 'OFF', 5)));
select pg_temp.mk('b8', '0900009005', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009005', 1), 'LC-TOAN-K09', 'OFF', 3)));
select pg_temp.mk('b9', '0900009005', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009005', 1), 'LC-TOAN-K09', 'OFF', 2)));
select app.save_order(pg_temp.o(k), null, pg_temp.term('CHIA_3_DOT')) from (values ('b1'), ('b2'), ('b3'), ('b4'), ('b5'), ('b6'), ('b7'), ('b8'), ('b9')) as v (k);
-- b4: cơ hội L8 buộc có năm sinh nên xoá sau khi lập đơn (bỏ qua ràng buộc để dựng dữ liệu thử).
select pg_temp.sudo($$set local session_replication_role = 'replica'$$);
select pg_temp.sudo($$update app.prospect_student set birth_year = null where id = pg_temp.ps('0900009004', 1)$$);
select pg_temp.sudo($$set local session_replication_role = 'origin'$$);
-- b3: dòng có chính sách cần duyệt nhưng cờ cần tích của đơn bị đặt sai (cũ): lúc trình phải tính lại rồi mới kiểm.
select pg_temp.sudo($$update app.sales_order set needs_acknowledgement = false where id = pg_temp.o('b3')$$);
-- Sale (quản lý bm1) e1 có chính sách cần duyệt, e2 không; CSKH (quản lý bm1) c1; Sale chưa có quản lý d1; Sale có quản lý chưa có quyền Duyệt d2.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mk('e1', '0900009002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009002', 1), 'LC-TOAN-K09', 'OFF', 10, jsonb_build_array(pg_temp.disc('GIAM_THUONG_LUONG', 5)))));
select pg_temp.mk('e2', '0900009001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009001', 1), 'LC-TOAN-K09', 'OFF', 4)));
select app.save_order(pg_temp.o('e1'), null, pg_temp.term('CHIA_3_DOT'));
select app.save_order(pg_temp.o('e2'), null, pg_temp.term('CHIA_3_DOT'));
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select pg_temp.mk('c1', '0900009006', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009006', 1), 'LC-TOAN-K09', 'OFF', 4)));
select app.save_order(pg_temp.o('c1'), null, pg_temp.term('CHIA_3_DOT'));
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select pg_temp.mk('d1', '0900009006', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009006', 1), 'LC-TOAN-K09', 'OFF', 4)));
select app.save_order(pg_temp.o('d1'), null, pg_temp.term('CHIA_3_DOT'));
select pg_temp.claims(pg_temp.uid('sales1c'), 'aal1');
select pg_temp.mk('d2', '0900009006', jsonb_build_array(pg_temp.line(pg_temp.ps('0900009006', 1), 'LC-TOAN-K09', 'OFF', 4)));
select app.save_order(pg_temp.o('d2'), null, pg_temp.term('CHIA_3_DOT'));

-- ================= (b) Bốn cờ: ma trận vai x trạng thái, khớp hàm ghi =================
select is(pg_temp.mismatches('aal2'), '', 'Cờ get_order khớp việc hàm ghi chạy được hay bị chặn: mọi vai (Admin đã xác thực hai bước) x đơn Nháp, Đã trình, Đã duyệt, Huỷ, đơn cơ sở khác');
select is(pg_temp.mismatches('aal1'), '', 'Cờ khớp hàm ghi khi Admin CHƯA xác thực hai bước (can_approve_as_manager đòi): cờ sai, hàm chặn');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((pg_temp.gof('n2') ->> 'can_approve')::boolean, true, 'Admin đã xác thực hai bước: duyệt thay được đơn Đã trình (can_approve đúng)');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select pg_temp.gof('n2')$$), 'HMT_KHONG_CO_QUYEN', 'Admin chưa xác thực hai bước: không đọc được bản ghi (mọi cờ coi như sai)');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('n2'), true)$$), 'HMT_KHONG_CO_QUYEN', 'Admin chưa xác thực hai bước: approve_order cũng chặn');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((pg_temp.gof('b6') ->> 'can_submit')::boolean, true, 'Trưởng cơ sở lập: đơn Nháp của mình có can_submit');
select is((pg_temp.gof('b6') ->> 'can_cancel')::boolean, true, 'Đơn Nháp chỉ người lập huỷ (R-TIEN-38): người lập có can_cancel');
select is((pg_temp.gof('b6') ->> 'can_approve')::boolean, false, 'Đơn Nháp chưa trình: không có can_approve');
select is((pg_temp.gof('n2') ->> 'can_approve')::boolean, true, 'Người duyệt đã chốt: đơn Đã trình có can_approve');
select is((pg_temp.gof('n2') ->> 'can_reject')::boolean, true, 'Người duyệt đã chốt: đơn Đã trình có can_reject (cùng điều kiện với duyệt)');
select is((pg_temp.gof('n2') ->> 'can_cancel')::boolean, true, 'Người duyệt đã chốt huỷ được đơn Đã trình (R-TIEN-38)');
select is((pg_temp.gof('n4') ->> 'can_cancel')::boolean, false, 'Đơn đã Huỷ: không còn can_cancel');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((pg_temp.gof('b6') ->> 'can_cancel')::boolean, false, 'Đơn Nháp của người khác: Sale không có can_cancel');
select is((pg_temp.gof('b6') ->> 'can_submit')::boolean, true, 'Sale cùng cơ sở có quyền Sửa: can_submit đúng cho đơn Nháp của Trưởng cơ sở');
-- Cờ đúng, lỗi cấu hình khi Trình (điều chỉnh 4): cờ chỉ xét quyền và trạng thái.
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is((pg_temp.gof('d1') ->> 'can_submit')::boolean, true, 'Cờ đúng, lỗi cấu hình khi Trình: Sale chưa có quản lý trực tiếp vẫn có can_submit');
select pg_temp.sudo($$update app.user_role set is_active = false where role_code = 'BRANCH_MANAGER'$$); -- R-V2-12: cơ sở chưa có Trưởng cơ sở nào thì mới chặn
select is(pg_temp.err($$select app.submit_order(pg_temp.o('d1'))$$), 'HMT_KHONG_CO_QUAN_LY', 'Cờ đúng, lỗi cấu hình khi Trình: bấm Trình báo HMT_KHONG_CO_QUAN_LY');
select pg_temp.sudo($$update app.user_role set is_active = true where role_code = 'BRANCH_MANAGER'$$);
select pg_temp.claims(pg_temp.uid('sales1c'), 'aal1');
select is((pg_temp.gof('d2') ->> 'can_submit')::boolean, true, 'Cờ đúng, lỗi cấu hình khi Trình: quản lý chưa có quyền Duyệt vẫn có can_submit');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('d2'))$$), 'HMT_NGUOI_DUYET_THIEU_QUYEN', 'Cờ đúng, lỗi cấu hình khi Trình: bấm Trình báo HMT_NGUOI_DUYET_THIEU_QUYEN');
-- Tắt Bán hàng (Đ173): bốn cờ sai, hàm ghi chặn; đọc get_order vẫn được (Đ181).
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select pg_temp.gof('b9')$$), null, 'Đ181: tắt Bán hàng vẫn đọc được get_order');
select is((pg_temp.gof('b9') ->> 'can_submit')::boolean, false, 'Đ173: tắt Bán hàng thì can_submit sai');
select is((pg_temp.gof('b9') ->> 'can_cancel')::boolean, false, 'Đ173: tắt Bán hàng thì can_cancel sai');
select is((pg_temp.gof('n2') ->> 'can_approve')::boolean, false, 'Đ173: tắt Bán hàng thì can_approve sai');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('b9'))$$), 'HMT_TINH_NANG_TAT', 'Đ173: tắt Bán hàng thì Trình bị chặn, kể cả tự duyệt');
select is(pg_temp.stat('b9'), 'NHAP', 'Đ173: tắt Bán hàng: đơn vẫn Nháp');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'BAN_HANG' and branch_id = (select id from app.branch where code = 'CS1')$$);

-- ================= (a) Trưởng cơ sở trình = tự duyệt (Q-P6) =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(app.submit_order(pg_temp.o('b1')) ->> 'status', 'DA_DUYET', 'Q-P6: Trưởng cơ sở trình đơn của mình thì thành Đã duyệt ngay');
select is(app.get_order(pg_temp.o('b1')) ->> 'status_code', 'DA_DUYET', 'Q-P6: trạng thái lưu là Đã duyệt');
select is(pg_temp.evs('b1'), 'TAO,TRINH,DUYET', 'Q-P6: lịch sử đủ hai dòng, đúng thứ tự theo seq: Trình rồi Duyệt');
select is((select note from app.sales_order_event where order_id = pg_temp.o('b1') and event_code = 'DUYET'), 'Tự duyệt', 'Q-P6: sự kiện Duyệt kèm ghi chú "Tự duyệt"');
select is(pg_temp.col('b1', 'approved_by'), pg_temp.uid('bm1')::text, 'Q-P6: người duyệt là chính Trưởng cơ sở');
select is(pg_temp.col('b1', 'approved_on_behalf'), 'false', 'Q-P6: không phải duyệt thay');
select is(pg_temp.col('b1', 'approval_route'), 'TU_DUYET', 'R-HT-06: đường duyệt TU_DUYET');
select is((select count(*)::int from app.sales_order_line l where l.order_id = pg_temp.o('b1') and l.student_id is not null), 1, 'R-CRM-27: hồ sơ học sinh được tạo hoặc khớp khi tự duyệt (như approve_order)');
select is((select count(*)::int from app.sales_order_installment i where i.order_id = pg_temp.o('b1') and i.due_date is not null), 3, 'R-TIEN-07: hạn đóng của ba đợt được chốt khi tự duyệt');
select is(pg_temp.err($$select app.cancel_order(pg_temp.o('b1'), 'KHACH_DOI_Y')$$), null, 'Đơn tự duyệt vẫn huỷ được như đơn đã duyệt (R-TIEN-38)');
-- R-V2-11 (anh chốt 06/11, A4): không còn ô tích đồng ý; chính sách cần duyệt, vượt trần chỉ cảnh báo, tự duyệt được ngay.
select is(app.submit_order(pg_temp.o('b2')) ->> 'status', 'DA_DUYET', 'R-V2-11: chính sách cần duyệt không chặn, Trưởng cơ sở tự duyệt');
select is(pg_temp.col('b2', 'acknowledged'), 'true', 'R-V2-11: ghi đơn có cờ cảnh báo lúc duyệt');
select is(pg_temp.evs('b2'), 'TAO,TRINH,DUYET', 'R-V2-11: lịch sử đủ Trình, Duyệt');
-- Vượt trần sau khi tính lại tổng: duyệt được, nhật ký ghi người duyệt và tổng % của dòng vượt.
select pg_temp.sudo($$set local session_replication_role = 'replica'$$);
select pg_temp.sudo($$update app.sales_order_line set over_cap = true, discount_percent = 15, gift_percent = 8.3 where order_id = pg_temp.o('b3')$$);
select pg_temp.sudo($$set local session_replication_role = 'origin'$$);
select is(app.submit_order(pg_temp.o('b3')) ->> 'status', 'DA_DUYET', 'R-V2-11: vượt trần chỉ cảnh báo, tự duyệt được');
select ok((select e.note from app.sales_order_event e where e.order_id = pg_temp.o('b3') and e.event_code = 'DUYET') like '%Duyệt đơn vượt trần%',
          'R-V2-11: nhật ký duyệt ghi đơn vượt trần và tổng % dòng vượt');
-- R-TIEN-35 và KD6 áp như approve_order; lỗi thì lùi cả giao dịch.
select is(pg_temp.err($$select app.submit_order(pg_temp.o('b4'))$$), 'HMT_EM_THIEU_THONG_TIN', 'R-TIEN-35: em thiếu năm sinh thì tự duyệt bị chặn');
select is(pg_temp.stat('b4'), 'NHAP', 'R-TIEN-35: đơn vẫn Nháp');
select is(pg_temp.err($$select app.submit_order(pg_temp.o('b5'))$$), 'HMT_EM_TRUNG_TEN_NAM_SINH', 'KD6: hai em trùng tên và năm sinh trong đơn thì tự duyệt bị chặn');
select is(pg_temp.stat('b5'), 'NHAP', 'KD6: bị chặn thì đơn vẫn Nháp (cả bước Trình cũng lùi)');
select is(pg_temp.evs('b5'), 'TAO', 'KD6: không để lại sự kiện Trình');
select is((select count(*)::int from app.sales_order_line l where l.order_id = pg_temp.o('b5') and l.student_id is not null), 0, 'KD6: không gắn hồ sơ học sinh nào khi bị chặn');
-- Đường QUAN_LY giữ nguyên: Sale, CSKH trình chỉ thành Đã trình; p_acknowledged bị bỏ qua.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(app.submit_order(pg_temp.o('e2')) ->> 'status', 'DA_TRINH', 'Sale trình vẫn chỉ thành Đã trình');
select is(app.submit_order(pg_temp.o('e1'), true) ->> 'auto_approved', 'false', 'Đường QUAN_LY: không tự duyệt, kể cả khi truyền p_acknowledged = true');
select is(pg_temp.col('e1', 'acknowledged'), 'false', 'Đường QUAN_LY: p_acknowledged bị bỏ qua (người duyệt tích ở bước duyệt)');
select is(pg_temp.col('e1', 'approval_route'), 'QUAN_LY', 'Đường QUAN_LY giữ nguyên');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.submit_order(pg_temp.o('c1')) ->> 'status', 'DA_TRINH', 'CSKH trình vẫn chỉ thành Đã trình');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(app.approve_order(pg_temp.o('e1')) ->> 'on_behalf', 'false', 'R-V2-11: approve_order không cần tích đồng ý, duyệt được');
select is(pg_temp.evs('e1'), 'TAO,TRINH,DUYET', 'approve_order giữ nguyên lịch sử Trình, Duyệt');
-- Người khác trình đơn Nháp của Trưởng cơ sở thì chỉ thành Đã trình; Trưởng cơ sở duyệt sau.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(app.submit_order(pg_temp.o('b6')) ->> 'status', 'DA_TRINH', 'Sale trình đơn Nháp của Trưởng cơ sở thì chỉ thành Đã trình');
select is(app.get_order(pg_temp.o('b6')) ->> 'approval_route', 'TU_DUYET', 'Đường duyệt vẫn chốt theo người lập (TU_DUYET)');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(app.submit_order(pg_temp.o('b7')) ->> 'status', 'DA_TRINH', 'Trưởng cơ sở khác trình đơn Nháp của bm1 thì chỉ thành Đã trình');
select is(pg_temp.err($$select app.approve_order(pg_temp.o('b7'))$$), 'HMT_KHONG_PHAI_NGUOI_DUYET', 'R-HT-06: Trưởng cơ sở khác không duyệt đơn Đã trình của người khác (người duyệt đã chốt là bm1)');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(app.approve_order(pg_temp.o('b6')) ->> 'on_behalf', 'false', 'Trưởng cơ sở lập rồi duyệt đơn Đã trình do người khác trình: duyệt được');
-- Chữ ký một tham số vẫn chạy (tham số mới có mặc định).
select is(app.submit_order(pg_temp.o('b8')) ->> 'status', 'DA_DUYET', 'Lời gọi một tham số vẫn chạy và tự duyệt');
select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'app' and p.proname = 'submit_order'), 1, 'Chỉ còn một hàm submit_order (đã bỏ chữ ký cũ)');
-- Quyền thực thi: lõi duyệt là hàm nội bộ, không gọi được qua rpc.
select is(pg_temp.err($$select app.order_approve_core(pg_temp.o('b9'), true, false, 'x')$$), '42501', 'order_approve_core không mở cho rpc (từ chối quyền thực thi)');
reset role;
select is(has_function_privilege('anon', 'app.submit_order(uuid, boolean)', 'execute'), false, 'submit_order không mở cho người chưa đăng nhập');
select is(has_function_privilege('authenticated', 'app.submit_order(uuid, boolean)', 'execute'), true, 'submit_order mở cho người đã đăng nhập (hàm tự kiểm quyền)');
select is(has_function_privilege('authenticated', 'app.order_approve_core(uuid, boolean, boolean, text)', 'execute'), false, 'order_approve_core: authenticated không có quyền thực thi');
set local role authenticated;

select * from finish();
rollback;
