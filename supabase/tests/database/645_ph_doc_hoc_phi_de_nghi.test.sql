-- PH-03, PH-04 (migration 645): hàm đọc, ghi cho cổng Phụ huynh. Dữ liệu giả.
-- Luật: phụ huynh chỉ thấy con, đơn, ticket của mình (kể cả hồ sơ cùng SĐT); nhân viên, học sinh không dùng hàm phụ huynh; công tắc Học tập, Aftersale.
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
create function pg_temp.claims(p_user uuid) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal1')));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$ begin execute p_sql; end $$;
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('ph1'), ('ph1b'), ('ph2'), ('nv');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.sid(p_code text) returns uuid language plpgsql security definer as $$ begin return (select id from app.student where code = p_code); end $$;
create temp table k (key text primary key, id uuid);
grant all on k to public;
create function pg_temp.k(p_key text) returns uuid language sql stable as $$ select id from k where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@f645.hoamatoan.invalid' from u;
-- PH645001 và PH645002 CÙNG SĐT (một tài khoản ph1 thấy con của cả hai); PH645003 SĐT khác (ph2); ph1b là tài khoản của PH645002.
insert into app.parent (code, full_name, phone, branch_id)
select c.code, 'Phụ huynh giả ' || c.code, c.phone, (select id from app.branch where code = 'CS1')
  from (values ('PH645001', '0900645001'), ('PH645002', '0900645001'), ('PH645003', '0900645003')) c (code, phone);
insert into app.user_account (id, display_name, login_name, branch_id, parent_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@f645.hoamatoan.invalid', (select id from app.branch where code = 'CS1'),
       case u.key when 'ph1' then 'PH645001' when 'ph1b' then 'PH645002' when 'ph2' then 'PH645003' end, false
  from u;
insert into app.user_role (user_id, role_code) select u.id, case when u.key = 'nv' then 'SALES' else 'PARENT' end from u;
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = c.ph), c.name, 2012, (select id from app.branch where code = 'CS1')
  from (values ('HS645001', 'PH645001', 'Em 645 Một'), ('HS645002', 'PH645002', 'Em 645 Hai'), ('HS645003', 'PH645003', 'Em 645 Ba')) c (code, ph, name);
insert into app.feature_flag (module_code, branch_id, enabled)
select m, b.id, true from app.branch b, (values ('HOC_TAP'), ('AFTERSALE')) v (m) where b.code = 'CS1'
on conflict (module_code, branch_id) do update set enabled = true;

-- Đơn đã duyệt của PH645001 cho em Một: tổng 7.200.000, đã thu 4.800.000 (một phiếu đã duyệt); đơn của PH645003 cho em Ba.
select pg_temp.sudo($$
  insert into app.sales_order (code, branch_id, renewal_ticket_id, parent_id, status_code, priced_on, total_amount)
  select 'DH645001', b.id, gen_random_uuid(), (select id from app.parent where code = 'PH645001'), 'NHAP', current_date, 7200000 from app.branch b where b.code = 'CS1';
  insert into app.sales_order (code, branch_id, renewal_ticket_id, parent_id, status_code, priced_on, total_amount)
  select 'DH645003', b.id, gen_random_uuid(), (select id from app.parent where code = 'PH645003'), 'NHAP', current_date, 1000000 from app.branch b where b.code = 'CS1';
  insert into app.sales_order_line (order_id, branch_id, line_no, student_id, package_id, package_code, package_name, package_type_code, delivery_mode_code, unit_code,
                                    quantity, gifted_quantity, unit_price, gross_amount, line_total)
  select o.id, o.branch_id, 1, (select id from app.student where code = case o.code when 'DH645001' then 'HS645001' else 'HS645003' end),
         (select id from app.sales_package limit 1), 'GOI-645', 'Hình 9 giả', 'LC', 'TRUC_TIEP', 'GIO', 36, 0, 200000, o.total_amount, o.total_amount
    from app.sales_order o where o.code in ('DH645001', 'DH645003');
  update app.sales_order set status_code = 'DA_TRINH' where code in ('DH645001', 'DH645003');
  update app.sales_order set status_code = 'DA_DUYET' where code in ('DH645001', 'DH645003');
  insert into app.receipt (code, order_id, parent_id, branch_id, collect_branch_id, status_code, amount, payment_method_code, paid_on)
  select 'PT645001', o.id, o.parent_id, o.branch_id, o.branch_id, 'DA_DUYET', 4800000, 'TIEN_MAT', current_date from app.sales_order o where o.code = 'DH645001';
  insert into app.money_in (code, receipt_id, order_id, parent_id, branch_id, amount)
  select 'MI645001', r.id, r.order_id, r.parent_id, r.branch_id, r.amount from app.receipt r where r.code = 'PT645001';
$$);
-- Ticket: gốc Đã xử lý của PH645001 (em Một), một ticket của PH645003.
select pg_temp.sudo($$
  insert into app.ticket (code, ticket_type, branch_id, title, description, channel_code, category_code, priority_code, status_code, parent_id, student_id, resolution,
                          resolved_at, response_due_at, resolve_due_at)
  select c.code, 'KN', b.id, 'Giả ' || c.code, 'Nội dung', 'ZALO', 'KN_01_01', 'CAO', 'DA_XU_LY',
         (select id from app.parent where code = c.ph), (select id from app.student where code = c.hs), 'Phương án giả', now(), now() + interval '1 day', now() + interval '2 days'
    from app.branch b, (values ('KN-F645-1', 'PH645001', 'HS645001'), ('KN-F645-3', 'PH645003', 'HS645003')) c (code, ph, hs) where b.code = 'CS1';
$$);
insert into k select 'tk1', id from app.ticket where code = 'KN-F645-1';
insert into k select 'tk3', id from app.ticket where code = 'KN-F645-3';
insert into k select 'dh1', id from app.sales_order where code = 'DH645001';
insert into k select 'dh3', id from app.sales_order where code = 'DH645003';

-- ===== Phụ huynh ph1 (PH645001; cùng SĐT với PH645002) =====
select pg_temp.claims(pg_temp.uid('ph1'));
set local role authenticated;
select is((select count(*)::int from app.portal_student_ids()), 2, 'Luật PH-2: hai hồ sơ cùng SĐT dùng chung, tài khoản thấy con của cả hai');
select is(app.ph_hours_orders(pg_temp.sid('HS645001')) #>> '{orders,0,code}', 'DH645001', 'PH-03: đơn đã duyệt của con hiện trên màn học phí');
select is((app.ph_hours_orders(pg_temp.sid('HS645001')) #>> '{orders,0,remaining}')::bigint, 2400000::bigint, 'PH-03: còn thiếu = tổng đơn trừ tiền đã vào');
select is(app.ph_hours_orders(pg_temp.sid('HS645001')) #>> '{receipts,0,code}', 'PT645001', 'PH-03: phiếu thu đã duyệt hiện ở «gần đây»');
select is(app.ph_order(pg_temp.k('dh1')) ->> 'status', 'CON_THIEU', 'PH-03: chi tiết đơn còn thiếu');
select is(pg_temp.err(format($$select app.ph_hours_orders(%L)$$, pg_temp.sid('HS645003'))), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: xem học phí con nhà khác bị chặn');
select is(pg_temp.err(format($$select app.ph_order(%L)$$, pg_temp.k('dh3'))), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: xem đơn nhà khác bị chặn');
select is(pg_temp.err(format($$select app.ph_get_ticket(%L)$$, pg_temp.k('tk3'))), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: xem ticket nhà khác bị chặn');
select is((app.ph_list_tickets() ->> 'total')::int, 1, 'PH-04: danh sách chỉ ticket của mình');
select is(app.ph_get_ticket(pg_temp.k('tk1')) ->> 'step', '3', 'PH-04: ticket Đã xử lý ở bước Phương án');
select is(app.ph_get_ticket(pg_temp.k('tk1')) ->> 'proposal', 'Phương án giả', 'PH-04: bước 3 hiện phương án');
select ok(not (app.ph_get_ticket(pg_temp.k('tk1')) ? 'assignee_id'), 'PH-04: không lộ người xử lý');
select is(pg_temp.err(format($$select app.ph_rate_ticket(%L, 6)$$, pg_temp.k('tk1'))), 'HMT_TICKET_THIEU_HAI_LONG', 'AS-04: mức hài lòng phải từ 1 đến 5');
select is(pg_temp.err(format($$select app.ph_rate_ticket(%L, 5)$$, pg_temp.k('tk3'))), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: chấm ticket nhà khác bị chặn');
select is(pg_temp.err(format($$select app.ph_rate_ticket(%L, 5)$$, pg_temp.k('tk1'))), null, 'PH-04: chấm hài lòng ticket đã xử lý được');
select is(pg_temp.err(format($$select app.ph_rate_ticket(%L, 4)$$, pg_temp.k('tk1'))), 'HMT_TICKET_DA_CHAM', 'PH-04: chỉ chấm một lần');
select is(pg_temp.err(format($$select app.ph_confirm_option(%L)$$, pg_temp.k('tk1'))), null, 'PH-04: đồng ý phương án ghi xác nhận');
select jsonb_array_length(app.ph_request_categories('DN')) > 0 as ok \gset
select ok(:'ok', 'PH-04: có danh sách nhóm cho ô «Nhóm»');
select is(pg_temp.err(format($$select app.ph_create_request(%L, 'DN', 'DN_01_05', '  ')$$, pg_temp.sid('HS645001'))), 'HMT_THIEU_THONG_TIN', 'PH-04: nội dung bắt buộc');
select is(pg_temp.err(format($$select app.ph_create_request(%L, 'DN', 'DN_01_05', 'Xin đổi ca')$$, pg_temp.sid('HS645003'))), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: gửi đề nghị cho con nhà khác bị chặn');
select is(pg_temp.err(format($$select app.ph_create_request(%L, 'DN', 'KN_01_01', 'x')$$, pg_temp.sid('HS645001'))), 'HMT_TICKET_NHOM_SAI', 'PH-04: nhóm không thuộc loại bị chặn');
select is(pg_temp.err(format($$select app.ph_create_request(%L, 'DN', 'DN_01_05', 'Xin đổi ca')$$, pg_temp.sid('HS645001'))), null, 'PH-04: gửi đề nghị cho con mình được');
select is((app.ph_list_tickets() ->> 'total')::int, 2, 'PH-04: đề nghị vừa gửi hiện trong danh sách');
reset role;

-- ===== Công tắc Aftersale tắt =====
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'AFTERSALE' and branch_id = (select id from app.branch where code = 'CS1')$$);
select pg_temp.claims(pg_temp.uid('ph1'));
set local role authenticated;
select is(pg_temp.err(format($$select app.ph_create_request(%L, 'DN', 'DN_01_05', 'Xin đổi ca')$$, pg_temp.sid('HS645001'))), 'HMT_TINH_NANG_TAT', 'Công tắc Aftersale tắt thì không gửi được đề nghị');
reset role;

-- ===== Nhân viên không dùng được hàm của phụ huynh =====
select pg_temp.claims(pg_temp.uid('nv'));
set local role authenticated;
select is((select count(*)::int from app.portal_student_ids()), 0, 'Nhân viên không có học sinh ở cổng');
select is(pg_temp.err(format($$select app.ph_order(%L)$$, pg_temp.k('dh1'))), 'HMT_KHONG_CO_QUYEN', 'Nhân viên xem đơn qua hàm phụ huynh bị chặn');
select is(pg_temp.err($$select app.ph_list_tickets()$$), 'HMT_KHONG_CO_QUYEN', 'Nhân viên liệt kê ticket qua hàm phụ huynh bị chặn');
reset role;

-- ===== Phụ huynh khác (ph2) =====
select pg_temp.claims(pg_temp.uid('ph2'));
set local role authenticated;
select is((select count(*)::int from app.portal_student_ids()), 1, 'ph2 chỉ thấy con mình');
select is(pg_temp.err(format($$select app.ph_hours_orders(%L)$$, pg_temp.sid('HS645001'))), 'HMT_KHONG_CO_QUYEN', 'ph2 xem học phí con nhà khác bị chặn');
-- ===== Phiên bị thu hồi (Admin tăng số phiên bản): token cũ không thấy gì =====
select pg_temp.claims(pg_temp.uid('ph2'));
select pg_temp.sudo($$update app.user_account set session_version = session_version + 1 where parent_code = 'PH645003'$$);
set local role authenticated;
select is((select count(*)::int from app.portal_student_ids()), 0, 'Chặn: phiên đã bị thu hồi thì không thấy con nào');
select is(pg_temp.err(format($$select app.ph_order(%L)$$, pg_temp.k('dh3'))), 'HMT_KHONG_CO_QUYEN', 'Chặn: phiên đã bị thu hồi thì không xem được đơn');
select * from finish();
rollback;
