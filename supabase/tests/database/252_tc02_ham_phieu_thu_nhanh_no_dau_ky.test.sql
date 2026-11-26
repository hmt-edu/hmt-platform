-- TC-02 các hàm phiếu thu CŨ biết phiếu không đơn (migration 252): save_receipt, submit_receipt, approve_receipt_accounting, list_receipts, get_receipt. Dựng như bài 251.
-- (Bài 251 gốc:) Luật R-V2-15 (phiếu không đơn, CSKH tạo, Kế toán duyệt, không qua quản lý, không vượt nợ còn lại), R-V2-32 (nợ đầu kỳ ở sổ số dư), R-HT-01 (Admin không duyệt tiền),
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p252.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p252.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('cskh', 'CS1'), ('ke', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('cskh', 'CSKH'), ('ke', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- Phụ huynh giả ở CS1 có nợ đầu kỳ 3.000.000 (số âm trong sổ số dư, khoá theo phụ huynh); phụ huynh 2 không có nợ. Học sinh chỉ là ghi chú tham chiếu.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH252A', 'Phụ huynh giả 251', '0900252001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HS252A', id, 'Em nợ đầu kỳ', 2012, branch_id from app.parent where code = 'PH252A'$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HS252B', id, 'Em không nợ', 2013, branch_id from app.parent where code = 'PH252A'$$);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH252B', 'Phụ huynh không nợ 251', '0900252002', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref)
  select s.parent_id, s.id, s.branch_id, 'DAU_KY_CONG_NO', -3000000, current_date, 'TEST-252' from app.student s where s.code = 'HS252A'$$);
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


select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'opening_debt_receipt_enabled'$$);
set local role authenticated;
select pg_temp.claims((select id from u where key = 'cskh'), 'aal1');
insert into rc select app.create_opening_debt_receipt(pg_temp.pid('PH252A'), jsonb_build_object('amount', 1000000, 'payment_method_code', 'TIEN_MAT', 'student_id', pg_temp.sid('HS252A')));
create temp table rid (v uuid);
grant all on rid to public;
insert into rid select (v ->> 'id')::uuid from rc;

-- ---- save_receipt (hàm cũ) sửa được phiếu nợ đầu kỳ Nháp ----
select is((app.save_receipt((select v from rid), jsonb_build_object('amount', 1500000, 'payment_method_code', 'CHUYEN_KHOAN')) ->> 'id')::uuid, (select v from rid), 'save_receipt (hàm cũ) sửa được phiếu nợ đầu kỳ Nháp');
select is((select amount from app.receipt where id = (select v from rid)), 1500000::bigint, 'Số tiền đã đổi');
select is(pg_temp.err($$select app.save_receipt((select v from rid), jsonb_build_object('amount', 3000001, 'payment_method_code', 'TIEN_MAT'))$$), 'HMT_SO_TIEN_VUOT', 'Sửa vượt nợ còn lại: bị chặn');
select is((select amount from app.receipt where id = (select v from rid)), 1500000::bigint, 'Sửa bị chặn thì số tiền giữ nguyên');
select is((app.save_receipt((select v from rid), jsonb_build_object('amount', 3000000, 'payment_method_code', 'TIEN_MAT')) ->> 'id')::uuid, (select v from rid), 'Sửa đúng bằng nợ còn lại (trừ chính phiếu): được');

-- ---- list_receipts / get_receipt thấy phiếu không đơn ----
select is((select count(*)::int from jsonb_array_elements(app.list_receipts('{}'::jsonb) -> 'rows') e where (e ->> 'is_opening_debt')::boolean), 1, 'list_receipts: phiếu nợ đầu kỳ KHÔNG biến mất (nối trái đơn)');
select is((select e ->> 'order_code' from jsonb_array_elements(app.list_receipts('{}'::jsonb) -> 'rows') e where (e ->> 'is_opening_debt')::boolean), null, 'list_receipts: order_code rỗng cho phiếu nợ đầu kỳ');
select is(app.get_receipt((select v from rid)) ->> 'is_opening_debt', 'true', 'get_receipt: đánh dấu phiếu nợ đầu kỳ');
select is(app.get_receipt((select v from rid)) -> 'order', 'null'::jsonb, 'get_receipt: đơn là null, không vỡ');
select is((app.get_receipt((select v from rid)) -> 'payment' ->> 'opening_debt_remaining')::bigint, 3000000::bigint, 'get_receipt: tóm tắt thanh toán là nợ đầu kỳ còn lại (phiếu đang chờ không tự trừ chính nó)');
select is(app.get_receipt((select v from rid)) -> 'opening_student' ->> 'code', 'HS252A', 'get_receipt: học sinh tham chiếu');
select is(app.get_receipt((select v from rid)) -> 'actions', '["sua", "gui", "huy"]'::jsonb, 'get_receipt: hành động của người lập ở Nháp');

-- ---- submit_receipt (hàm cũ) gửi thẳng Kế toán ----
select is(app.submit_receipt((select v from rid)) ->> 'status', 'CHO_KE_TOAN', 'submit_receipt (hàm cũ) gửi phiếu nợ đầu kỳ thẳng Chờ kế toán, không qua quản lý');
select is((select assigned_approver_id from app.receipt where id = (select v from rid)), null, 'Không chốt người duyệt quản lý');

-- ---- approve_receipt_accounting (hàm cũ): chỉ Kế toán, chuyển sang nhánh nợ đầu kỳ ----
select is(pg_temp.err($$select app.approve_receipt_accounting((select v from rid))$$), 'HMT_KHONG_CO_QUYEN', 'CSKH không duyệt được qua hàm cũ');
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select pg_temp.claims((select id from u where key = 'cskh'), 'aal1');
select is(pg_temp.err($$select app.approve_receipt_accounting((select v from rid))$$), 'HMT_KHONG_CO_QUYEN', 'R-HT-01: Vai không có quyền duyệt tiền không duyệt tiền qua hàm cũ');
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select pg_temp.claims((select id from u where key = 'ke'), 'aal2');
select is(app.approve_receipt_accounting((select v from rid)) ->> 'remaining', '0', 'Kế toán duyệt qua hàm cũ: nợ còn lại về 0 (3.000.000 đã thu đủ)');
select is((select status_code from app.receipt where id = (select v from rid)), 'DA_DUYET', 'Phiếu Đã duyệt');
select is((select order_id from app.money_in where receipt_id = (select v from rid)), null, 'Khoản tiền vào không gắn đơn');
select is(pg_temp.bal(pg_temp.pid('PH252A')), 0::bigint, 'Sổ số dư của phụ huynh: nợ -3.000.000 cộng thu 3.000.000 = 0');
select is((select count(*)::int from app.hour_ledger l join app.enrollment e on e.id = l.enrollment_id where e.parent_id = pg_temp.pid('PH252A')), 0, 'Không cấp giờ cho khoản nợ đầu kỳ');

select * from finish();
rollback;
