-- TC-02 Thu nợ đầu kỳ (migration 251). Luật R-V2-15 (phiếu không đơn, CSKH tạo, Kế toán duyệt, không qua quản lý, không vượt nợ còn lại), R-V2-32 (nợ đầu kỳ ở sổ số dư), R-HT-01 (Admin không duyệt tiền),
-- R-TIEN-26 (hoàn tác cộng lại nợ). Cờ opening_debt_receipt_enabled mặc định TẮT. Dữ liệu giả.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$ begin execute p_sql; end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh'), ('ke');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p251.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p251.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('cskh', 'CS1'), ('ke', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('cskh', 'CSKH'), ('ke', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- Phụ huynh giả ở CS1 có nợ đầu kỳ 3.000.000 (số âm trong sổ số dư, khoá theo phụ huynh); phụ huynh 2 không có nợ. Học sinh chỉ là ghi chú tham chiếu.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH251A', 'Phụ huynh giả 251', '0900251001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HS251A', id, 'Em nợ đầu kỳ', 2012, branch_id from app.parent where code = 'PH251A'$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HS251B', id, 'Em không nợ', 2013, branch_id from app.parent where code = 'PH251A'$$);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH251B', 'Phụ huynh không nợ 251', '0900251002', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref)
  select s.parent_id, s.id, s.branch_id, 'DAU_KY_CONG_NO', -3000000, current_date, 'TEST-251' from app.student s where s.code = 'HS251A'$$);
create function pg_temp.pid(p_code text) returns uuid language sql stable security definer as $$ select id from app.parent where code = p_code $$;
create function pg_temp.sid(p_code text) returns uuid language sql stable security definer as $$ select id from app.student where code = p_code $$;
create function pg_temp.dat(p_amount bigint) returns jsonb language sql as $$ select jsonb_build_object('amount', p_amount, 'payment_method_code', 'TIEN_MAT') $$;
create function pg_temp.bal(p_parent uuid) returns bigint language sql stable security definer as $$
  select coalesce(sum(amount), 0)::bigint from app.customer_balance_entry where parent_id = p_parent $$;
create function pg_temp.nrev(p_parent uuid) returns integer language sql stable security definer as $$
  select count(*)::int from app.customer_balance_entry where parent_id = p_parent and entry_type = 'DAO_THU_NO_DAU_KY' $$;
create temp table rc (v jsonb);
grant all on rc to public;
grant execute on all functions in schema pg_temp to public;

set local role authenticated;
select pg_temp.claims((select id from u where key = 'cskh'), 'aal1');

-- ---- Cờ tắt mặc định ----
select is((select value from app.setting_def where key = 'opening_debt_receipt_enabled'), 'false', 'Cờ opening_debt_receipt_enabled mặc định TẮT');
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH251A'), pg_temp.dat(1000000))$$), 'HMT_TINH_NANG_TAT', 'Cờ tắt: CSKH không tạo được phiếu nợ đầu kỳ');
reset role;
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'opening_debt_receipt_enabled'$$);
set local role authenticated;
select pg_temp.claims((select id from u where key = 'cskh'), 'aal1');

-- ---- Nợ còn lại ----
select is(app.opening_debt_remaining(pg_temp.pid('PH251A')), 3000000::bigint, 'Nợ đầu kỳ còn lại của phụ huynh A là 3.000.000');
select is(app.opening_debt_remaining(pg_temp.pid('PH251B')), 0::bigint, 'Phụ huynh B không có nợ: còn lại 0');

-- ---- Tạo phiếu: luật R-V2-15 ----
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH251B'), pg_temp.dat(1000))$$), 'HMT_SO_TIEN_VUOT', 'Phụ huynh không có nợ: không tạo được phiếu (vượt nợ còn lại)');
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH251A'), pg_temp.dat(3000001))$$), 'HMT_SO_TIEN_VUOT', 'Số tiền vượt nợ còn lại bị chặn');
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH251A'), pg_temp.dat(0))$$), 'HMT_SO_TIEN_SAI', 'Số tiền bằng 0 bị chặn');
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH251A'), jsonb_build_object('amount', 1000))$$), 'HMT_THIEU_HINH_THUC', 'Thiếu hình thức thanh toán bị chặn');
insert into rc select app.create_opening_debt_receipt(pg_temp.pid('PH251A'), pg_temp.dat(1000000));
select is((select status_code from app.receipt where id = (select (v ->> 'id')::uuid from rc)), 'NHAP', 'CSKH tạo được phiếu nợ đầu kỳ, trạng thái Nháp');
select is((select order_id from app.receipt where id = (select (v ->> 'id')::uuid from rc)), null, 'Phiếu không gắn đơn hàng');
select is(app.opening_debt_remaining(pg_temp.pid('PH251A')), 2000000::bigint, 'Phiếu đang chờ được trừ khỏi nợ còn lại (không thu vượt)');
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH251A'), pg_temp.dat(2000001))$$), 'HMT_SO_TIEN_VUOT', 'Phiếu thứ hai vượt phần còn lại sau phiếu đang chờ: bị chặn');

-- ---- Học sinh chỉ là ghi chú tham chiếu (R-V2-15, Chat 15:28 (b)) ----
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH251B'), jsonb_build_object('amount', 1, 'payment_method_code', 'TIEN_MAT', 'student_id', pg_temp.sid('HS251A')))$$), 'HMT_HOC_SINH_SAI', 'Học sinh của phụ huynh khác: bị chặn (học sinh chỉ là ghi chú của đúng phụ huynh này)');
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH251A'), jsonb_build_object('amount', 1, 'payment_method_code', 'TIEN_MAT', 'student_id', gen_random_uuid()))$$), 'HMT_HOC_SINH_SAI', 'Học sinh không thuộc phụ huynh: bị chặn');
-- ---- Gửi thẳng Kế toán, không qua quản lý ----
select lives_ok($$select app.submit_opening_debt_receipt((select (v ->> 'id')::uuid from rc))$$, 'CSKH gửi phiếu');
select is((select status_code from app.receipt where id = (select (v ->> 'id')::uuid from rc)), 'CHO_KE_TOAN', 'Gửi thẳng sang Chờ kế toán (không có bước quản lý)');
select is((select assigned_approver_id from app.receipt where id = (select (v ->> 'id')::uuid from rc)), null, 'Không chốt người duyệt quản lý');

-- ---- Duyệt: chỉ Kế toán (R-HT-01) ----
select is(pg_temp.err($$select app.approve_opening_debt_receipt((select (v ->> 'id')::uuid from rc))$$), 'HMT_KHONG_CO_QUYEN', 'CSKH không duyệt được phiếu');
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select is(pg_temp.err($$select app.approve_opening_debt_receipt((select (v ->> 'id')::uuid from rc))$$), 'HMT_KHONG_CO_QUYEN', 'R-HT-01: Admin không duyệt được phiếu thu tiền');
select pg_temp.claims((select id from u where key = 'ke'), 'aal2');
create temp table ap (v jsonb);
grant all on ap to public;
insert into ap select app.approve_opening_debt_receipt((select (v ->> 'id')::uuid from rc));
select is((select status_code from app.receipt where id = (select (v ->> 'id')::uuid from rc)), 'DA_DUYET', 'Kế toán duyệt: phiếu Đã duyệt');
select is((select amount from app.money_in where id = (select (v ->> 'money_in_id')::uuid from ap)), 1000000::bigint, 'Sinh khoản tiền vào đúng số tiền');
select is((select order_id from app.money_in where id = (select (v ->> 'money_in_id')::uuid from ap)), null, 'Khoản tiền vào không gắn đơn');
select is(app.opening_debt_remaining(pg_temp.pid('PH251A')), 2000000::bigint, 'Nợ đầu kỳ còn lại giảm đúng 1.000.000 sau khi duyệt');
select is(pg_temp.bal(pg_temp.pid('PH251A')), -2000000::bigint, 'Sổ số dư: -3.000.000 + 1.000.000');
select is(pg_temp.err($$select app.approve_opening_debt_receipt((select (v ->> 'id')::uuid from rc))$$), 'HMT_SAI_TRANG_THAI', 'Duyệt hai lần: bị chặn (phiếu đã duyệt)');

-- ---- Hàm cũ không tạo được khoản tiền rỗng đơn (an toàn bảng cũ) ----
reset role;
select is(pg_temp.err($$insert into app.money_in (code, receipt_id, order_id, parent_id, branch_id, amount)
  select 'KTV-LOI-251', r.id, null, r.parent_id, r.branch_id, 1 from app.receipt r limit 1$$) is not null, true, 'Khoản tiền vào không đơn và không đánh dấu nợ đầu kỳ: ràng buộc chặn');
select is(pg_temp.err($$insert into app.receipt (code, order_id, parent_id, branch_id, collect_branch_id, amount, payment_method_code)
  select 'PT-LOI-251', null, p.id, p.branch_id, p.branch_id, 1, 'TIEN_MAT' from app.parent p where code = 'PH251A'$$) is not null, true, 'Phiếu thu không đơn và không đánh dấu nợ đầu kỳ: ràng buộc chặn');

-- ---- Hoàn tác khoản thu nợ đầu kỳ (TC-09): nợ cộng lại ----
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'money_reversal_enabled'$$);
set local role authenticated;
select pg_temp.claims((select id from u where key = 'ke'), 'aal2');
select lives_ok($$select app.reverse_money_in((select (v ->> 'money_in_id')::uuid from ap), 'NHAP_SAI_SO_TIEN')$$, 'Kế toán hoàn tác khoản thu nợ đầu kỳ được (không có đơn, không tính giờ)');
select is(app.opening_debt_remaining(pg_temp.pid('PH251A')), 3000000::bigint, 'Hoàn tác: nợ đầu kỳ còn lại trở về 3.000.000');
select is(pg_temp.nrev(pg_temp.pid('PH251A')), 1, 'Sổ số dư ghi một dòng hoàn tác');
select is((select (app.list_money_in('{}'::jsonb) ->> 'total')::int), 2, 'Sổ khoản tiền vào (TC-08) thấy khoản thu nợ đầu kỳ và khoản đảo dù không có đơn');
select is(pg_temp.err($$select app.reverse_money_in((select (v ->> 'money_in_id')::uuid from ap), 'TRUNG_PHIEU')$$), 'HMT_DA_DAO_KHOAN', 'Chặn hoàn tác hai lần (R-TIEN-26)');

select * from finish();
rollback;
