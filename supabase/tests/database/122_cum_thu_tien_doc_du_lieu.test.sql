-- Cụm Thu tiền (migration 122): list_money_in (TC-08), list_receivables (TC-13). Luật: R-TIEN-01, R-TIEN-07, R-TIEN-26. Chỉ đọc. Dữ liệu giả; ngày tính từ hôm nay THEO GIỜ VIỆT NAM
-- (cùng múi giờ với hàm; không dùng current_date của máy chủ để bài không lệch quanh nửa đêm giờ Việt Nam).
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
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('bm5'), ('sales1'), ('cskh1'), ('ke'), ('gv1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@tc.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@tc.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm5', 'CS5'), ('sales1', 'CS1'), ('cskh1', 'CS1'), ('ke', 'CS1'), ('gv1', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('sales1', 'SALES'),
  ('cskh1', 'CSKH'), ('ke', 'ACCOUNTANT'), ('gv1', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Dữ liệu giả (chèn thẳng, bỏ qua trigger) ----------
-- o1 (CS1): đợt 1 = 1.500.000 hạn 14 ngày trước; đợt 2 = 1.200.000 hạn 30 ngày sau. Tiền đã vào ròng 1.200.000 (1.000.000 + 500.000 − 300.000 đảo).
-- o2 (CS1): hai đợt 500.000, hạn sau 3 và 10 ngày, chưa đóng. o3 (CS5): đợt 800.000 quá hạn 2 ngày. o4 (CS1): đơn Đã trình, không tính. o5 (CS5): đã đóng đủ 400.000.
create function pg_temp.seed() returns void language plpgsql security definer as $$
declare
  v_cs1 uuid := (select id from app.branch where code = 'CS1');
  v_cs5 uuid := (select id from app.branch where code = 'CS5');
  v_p1 uuid; v_p5 uuid; v_o record; v_r uuid;
begin
  set local session_replication_role = 'replica';
  insert into app.parent (code, full_name, phone, branch_id) values ('PHTC1', 'Phụ huynh giả TC1', '0900202001', v_cs1) returning id into v_p1;
  insert into app.parent (code, full_name, phone, branch_id) values ('PHTC5', 'Phụ huynh giả TC5', '0900202005', v_cs5) returning id into v_p5;
  for v_o in select * from (values
      ('DH-TC-O1', v_cs1, v_p1, 'DA_DUYET', 2700000), ('DH-TC-O2', v_cs1, v_p1, 'DA_DUYET', 1000000), ('DH-TC-O3', v_cs5, v_p5, 'DA_DUYET', 800000),
      ('DH-TC-O4', v_cs1, v_p1, 'DA_TRINH', 900000), ('DH-TC-O5', v_cs5, v_p5, 'DA_DUYET', 400000)) as t (code, branch_id, parent_id, status_code, total) loop
    insert into app.sales_order (code, branch_id, renewal_ticket_id, parent_id, status_code, priced_on, total_amount, created_by)
    values (v_o.code, v_o.branch_id, gen_random_uuid(), v_o.parent_id, v_o.status_code, (now() at time zone 'Asia/Ho_Chi_Minh')::date, v_o.total,
            (select id from u where key = 'sales1'));
  end loop;
  insert into app.sales_order_installment (order_id, branch_id, seq, due_days, amount, due_date)
  select o.id, o.branch_id, t.seq, t.due_days, t.amount, (now() at time zone 'Asia/Ho_Chi_Minh')::date + t.shift
    from app.sales_order o join (values
      ('DH-TC-O1', 1, 0, 1500000, -14), ('DH-TC-O1', 2, 30, 1200000, 30), ('DH-TC-O2', 1, 3, 500000, 3), ('DH-TC-O2', 2, 10, 500000, 10),
      ('DH-TC-O3', 1, 0, 800000, -2), ('DH-TC-O4', 1, 5, 900000, 5), ('DH-TC-O5', 1, 0, 400000, -30)) as t (code, seq, due_days, amount, shift) on t.code = o.code;
  -- Khoản tiền vào: mỗi khoản một phiếu thu Đã duyệt.
  for v_o in select * from (values
      ('DH-TC-O1', 'KTV-TC-1', 1000000, 5), ('DH-TC-O1', 'KTV-TC-2', 500000, 4), ('DH-TC-O1', 'KTV-TC-3', -300000, 2), ('DH-TC-O5', 'KTV-TC-4', 400000, 1)) as t (ord, code, amount, ago) loop
    insert into app.receipt (code, order_id, parent_id, branch_id, collect_branch_id, status_code, amount, payment_method_code, search_text)
    select 'PT-' || v_o.code, o.id, o.parent_id, o.branch_id, o.branch_id, 'DA_DUYET', abs(v_o.amount), 'TIEN_MAT',
           app.fold_text('PT-' || v_o.code || ' ' || o.code || ' ' || par.full_name || ' ' || par.phone)
      from app.sales_order o join app.parent par on par.id = o.parent_id where o.code = v_o.ord returning id into v_r;
    -- Khoản âm là khoản đảo (migration 180): không có phiếu thu, trỏ về khoản gốc KTV-TC-1, có lý do.
    insert into app.money_in (code, receipt_id, order_id, parent_id, branch_id, amount, created_at, reversal_of, reason_code)
    select v_o.code, case when v_o.amount > 0 then v_r end, o.id, o.parent_id, o.branch_id, v_o.amount, now() - make_interval(days => v_o.ago),
           case when v_o.amount < 0 then (select id from app.money_in where code = 'KTV-TC-1') end,
           case when v_o.amount < 0 then 'NHAP_SAI_SO_TIEN' end
      from app.sales_order o where o.code = v_o.ord;
  end loop;
  set local session_replication_role = 'origin';
end $$;
select pg_temp.seed();
set local role authenticated;

-- ================= TC-08 Khoản tiền vào =================
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is((app.list_money_in() ->> 'total')::int, 4, 'Kế toán thấy mọi khoản tiền vào (4)');
select is((app.list_money_in() ->> 'sum')::bigint, 1600000::bigint, 'Tổng khoản tiền vào: 1.000.000 + 500.000 − 300.000 + 400.000');
select is(app.list_money_in() -> 'rows' -> 0 ->> 'code', 'KTV-TC-4', 'Mặc định sắp mới nhất trước');
select is(app.list_money_in('{}', 'amount_desc') -> 'rows' -> 0 ->> 'code', 'KTV-TC-1', 'Sắp theo số tiền giảm dần');
select is((app.list_money_in('{"kind":"DAO"}') ->> 'total')::int, 1, 'Lọc khoản đảo (âm) thấy 1 khoản (R-TIEN-26)');
select is((app.list_money_in('{"kind":"THU"}') ->> 'total')::int, 3, 'Lọc khoản thu thấy 3 khoản');
select is((app.list_money_in('{"q":"dh-tc-o1"}') ->> 'total')::int, 3, 'Tìm theo mã đơn');
select is((app.list_money_in('{"q":"phu huynh gia tc5"}') ->> 'total')::int, 1, 'Tìm theo tên phụ huynh không dấu');
select is((app.list_money_in('{"q":"0900202005"}') ->> 'total')::int, 1, 'Tìm theo SĐT phụ huynh');
select is((app.list_money_in('{"q":"ktv-tc-2"}') ->> 'total')::int, 1, 'Tìm theo mã khoản tiền vào');
select is((app.list_money_in(format('{"created_from":"%s"}', (now() - interval '3 days'))::jsonb) ->> 'total')::int, 2, 'Lọc từ mốc ghi sổ');
select is((app.list_money_in('{}', 'date_desc', 2, 0) -> 'rows' -> 2), null, 'Phân trang: limit 2 chỉ hai dòng');
select is((app.list_money_in('{}', 'date_desc', 2, 2) -> 'rows' -> 0 ->> 'code'), 'KTV-TC-2', 'Phân trang: trang hai bắt đầu đúng dòng');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.list_money_in() ->> 'total')::int, 3, 'Trưởng cơ sở CS1 chỉ thấy khoản của cơ sở mình (3)');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((app.list_money_in() ->> 'total')::int, 1, 'Trưởng cơ sở CS5 thấy 1 khoản');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.list_money_in() ->> 'total')::int, 4, 'Admin thấy mọi cơ sở');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.list_money_in()$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Sale không xem sổ khoản tiền vào');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.list_money_in()$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không xem sổ khoản tiền vào');

-- ================= TC-13 Công nợ =================
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is((app.list_receivables() ->> 'total')::int, 5, 'Kế toán thấy 5 đợt còn nợ (đơn Đã trình và đợt đã đóng đủ không hiện)');
select is((app.list_receivables() ->> 'owed_sum')::bigint, 3300000::bigint, 'Tổng còn nợ: 300.000 + 1.200.000 + 500.000 + 500.000 + 800.000');
select is(app.list_receivables() -> 'rows' -> 0 ->> 'order_code', 'DH-TC-O1', 'Mặc định sắp hạn đóng sớm nhất trước (đợt 1 của O1, hạn 14 ngày trước)');
select is((app.list_receivables() -> 'rows' -> 0 ->> 'owed')::bigint, 300000::bigint, 'Tiền đã vào ròng 1.200.000 lấp đợt 1 (1.500.000): còn nợ 300.000');
select is((app.list_receivables() -> 'rows' -> 0 ->> 'paid_amount')::bigint, 1200000::bigint, 'Đã đóng của đợt 1 = 1.200.000');
select is(app.list_receivables() -> 'rows' -> 0 ->> 'status', 'QUA_HAN', 'Đợt quá hạn');
select is((app.list_receivables() -> 'rows' -> 0 ->> 'overdue_days')::int, 14, 'Quá hạn 14 ngày');
select is((select e ->> 'status' from jsonb_array_elements(app.list_receivables() -> 'rows') e where e ->> 'order_code' = 'DH-TC-O2' and e ->> 'seq' = '1'), 'SAP_DEN_HAN', 'Hạn trong 3 ngày tới: Sắp đến hạn (tham số debt_due_soon_days)');
select is((select e ->> 'status' from jsonb_array_elements(app.list_receivables() -> 'rows') e where e ->> 'order_code' = 'DH-TC-O2' and e ->> 'seq' = '2'), 'CHUA_DEN_HAN', 'Hạn sau 10 ngày: Chưa đến hạn');
select is((select (e ->> 'paid_amount')::bigint from jsonb_array_elements(app.list_receivables() -> 'rows') e where e ->> 'order_code' = 'DH-TC-O1' and e ->> 'seq' = '2'), 0::bigint, 'Đợt 2 chưa đóng khi đợt 1 chưa đủ (lấp lần lượt)');
select is((select count(*)::int from jsonb_array_elements(app.list_receivables() -> 'rows') e where e ->> 'order_code' in ('DH-TC-O4', 'DH-TC-O5')), 0, 'Đơn chưa duyệt và đơn đã đóng đủ không có trong công nợ');
select is((app.list_receivables('{"status":["QUA_HAN"]}') ->> 'total')::int, 2, 'Lọc Quá hạn thấy 2 đợt');
select is((app.list_receivables('{"status":["SAP_DEN_HAN"]}') ->> 'total')::int, 1, 'Lọc Sắp đến hạn thấy 1 đợt');
select is((app.list_receivables('{"q":"dh-tc-o2"}') ->> 'total')::int, 2, 'Tìm theo mã đơn');
select is((app.list_receivables('{"q":"0900202005"}') ->> 'total')::int, 1, 'Tìm theo SĐT phụ huynh');
select is(app.list_receivables('{}', 'owed_desc') -> 'rows' -> 0 ->> 'order_code', 'DH-TC-O1', 'Sắp theo còn nợ giảm dần: đợt 2 của O1 (1.200.000) đầu');
select is((app.list_receivables(format('{"due_to":"%s"}', (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1)::jsonb) ->> 'total')::int, 2, 'Lọc hạn đóng đến hôm qua');
select is((app.list_receivables('{}', 'due_asc', 2, 0) -> 'rows' -> 2), null, 'Phân trang: limit 2');
select is((app.list_receivables(format('{"branch_id":"%s"}', pg_temp.cs('CS5'))::jsonb) ->> 'total')::int, 1, 'Lọc theo cơ sở');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.list_receivables() ->> 'total')::int, 4, 'Trưởng cơ sở CS1 chỉ thấy công nợ cơ sở mình (4 đợt)');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((app.list_receivables() ->> 'total')::int, 4, 'Sale thấy công nợ cơ sở mình');
select is((app.list_receivables(format('{"sale_id":"%s"}', pg_temp.uid('sales1'))::jsonb) ->> 'total')::int, 4, 'Lọc theo sale lập đơn');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((app.list_receivables() ->> 'total')::int, 1, 'Trưởng cơ sở CS5 chỉ thấy 1 đợt');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.list_receivables()$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không xem công nợ');

select * from finish();
rollback;
