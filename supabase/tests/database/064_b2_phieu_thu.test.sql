-- B2 (migration 073): phiếu thu tối thiểu. Luật: R-TIEN-01, 02, 04, 06, 22, 23, R-V2-14, R-HT-01, R-HT-06, Đ258.
-- Mỗi luật có ca đúng và ca bị chặn; vai đọc, ghi trong và ngoài phạm vi. Dữ liệu giả.
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
  select jsonb_build_object('parent_name', 'Chị Phiếu Thu', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('bm1b'), ('sales1'), ('sales5'), ('ke');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@b2.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@b2.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm1b', 'CS1'), ('sales1', 'CS1'), ('sales5', 'CS5'), ('ke', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm1b', 'BRANCH_MANAGER'), ('sales1', 'SALES'),
  ('sales5', 'SALES'), ('ke', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$create function pg_temp.pkg(p_code text) returns uuid language sql stable security definer as 'select id from app.sales_package where code = p_code'$$);
select pg_temp.sudo($$create function pg_temp.term(p_code text) returns uuid language sql stable security definer as 'select id from app.payment_term where code = p_code and version = 1'$$);
select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as 'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone'$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable security definer as 'select id from app.lead where parent_phone = p_phone order by code limit 1'$$);
select pg_temp.sudo($$create function pg_temp.ps(p_phone text, p_pos integer) returns uuid language sql stable security definer as
  'select ps.id from app.prospect_student ps where ps.opportunity_id = pg_temp.oid(p_phone) and ps.position = p_pos'$$);
select pg_temp.sudo($$grant execute on function pg_temp.pkg(text), pg_temp.term(text), pg_temp.oid(text), pg_temp.lid(text), pg_temp.ps(text, integer) to public$$);
create function pg_temp.line(p_ps uuid, p_pkg text, p_mode text, p_qty numeric) returns jsonb language sql as $$
  select jsonb_build_object('kind', 'ENROL', 'prospect_student_id', p_ps, 'package_id', pg_temp.pkg(p_pkg), 'delivery_mode_code', p_mode,
                            'quantity', p_qty, 'discounts', '[]'::jsonb) $$;
grant execute on function pg_temp.line(uuid, text, text, numeric) to public;
create temp table os (key text primary key, id uuid);
grant all on os to public;
create temp table rs (key text primary key, id uuid);
grant all on rs to public;
create function pg_temp.o(p_key text) returns uuid language sql stable as $$ select id from os where key = p_key $$;
create function pg_temp.r(p_key text) returns uuid language sql stable as $$ select id from rs where key = p_key $$;
grant execute on function pg_temp.o(text), pg_temp.r(text) to public;
-- Tạo phiếu thu, nhớ theo khoá.
create function pg_temp.mkr(p_key text, p_order text, p_data jsonb) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  v := app.create_receipt(pg_temp.o(p_order), p_data);
  insert into rs values (p_key, (v ->> 'id')::uuid);
  return v;
end $$;
grant execute on function pg_temp.mkr(text, text, jsonb) to public;
select pg_temp.sudo($$create function pg_temp.rst(p_key text) returns text language sql stable security definer as 'select status_code from app.receipt where id = pg_temp.r(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.rev(p_key text) returns text language sql stable security definer as
  'select string_agg(event_code, '','' order by seq) from app.receipt_event where receipt_id = pg_temp.r(p_key)'$$);
select pg_temp.sudo($$create function pg_temp.paid(p_key text) returns bigint language sql stable security definer as 'select app.order_paid_amount(pg_temp.o(p_key))'$$);
select pg_temp.sudo($$grant execute on function pg_temp.rst(text), pg_temp.rev(text), pg_temp.paid(text) to public$$);

-- ================= Dựng đơn =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900007001', '{"student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900007002', '{"student_name": "Em Hai", "student_birth_year": 2012}'));
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900007001'));
select app.create_opportunity(pg_temp.lid('0900007002'));
select pg_temp.sudo($$insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
  select o.id, o.branch_id, 2, 'Em Ba', 2014 from app.opportunity o where o.id = pg_temp.oid('0900007002')$$);
select pg_temp.sudo($$update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where id in (pg_temp.oid('0900007001'), pg_temp.oid('0900007002'))$$);
-- Đơn d1: một dòng 10 giờ × 220.000 = 2.200.000, điều khoản cọc 1.000.000 + 1.200.000. Đơn d2: hai dòng 10 giờ (2.200.000) và 5 giờ (1.100.000) = 3.300.000.
create function pg_temp.mkorder(p_key text, p_phone text, p_lines jsonb, p_term text) returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_order_from_opportunity(pg_temp.oid(p_phone), p_lines, null, true);
  insert into os values (p_key, (v ->> 'id')::uuid);
  perform app.save_order((v ->> 'id')::uuid, null, pg_temp.term(p_term));
end $$;
grant execute on function pg_temp.mkorder(text, text, jsonb, text) to public;
select pg_temp.mkorder('d1', '0900007001', jsonb_build_array(pg_temp.line(pg_temp.ps('0900007001', 1), 'LC-TOAN-K09', 'OFF', 10)), 'COC_VA_CHIA_DOT');
select pg_temp.mkorder('d2', '0900007002', jsonb_build_array(pg_temp.line(pg_temp.ps('0900007002', 1), 'LC-TOAN-K09', 'OFF', 10),
                                                              pg_temp.line(pg_temp.ps('0900007002', 2), 'LC-TOAN-K09', 'OFF', 5)), 'CHIA_3_DOT');

-- ================= R-TIEN-02: phiếu thu chỉ tạo từ đơn Đã duyệt =================
select is(pg_temp.err($$select app.create_receipt(pg_temp.o('d1'), '{"amount": 1000000, "payment_method_code": "TIEN_MAT"}')$$),
          'HMT_DON_CHUA_DUYET', 'R-TIEN-02: đơn Nháp chưa tạo được phiếu thu');
select app.submit_order(pg_temp.o('d1'));
select app.submit_order(pg_temp.o('d2'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_order(pg_temp.o('d1'));
select app.approve_order(pg_temp.o('d2'));
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= Tạo phiếu thu (Nháp), Đ258, số tiền =================
select is(pg_temp.err($$select pg_temp.mkr('p1', 'd1', '{"amount": 1000000, "payment_method_code": "CHUYEN_KHOAN", "txn_ref": "GD001"}')$$), null, 'Đúng: tạo phiếu thu Nháp từ đơn Đã duyệt');
select is(pg_temp.rst('p1'), 'NHAP', 'Phiếu mới là Nháp');
select ok((select code ~ '^PT-CS1-\d{4}-\d{4}$' from app.receipt where id = pg_temp.r('p1')), 'Mã PT-CS1-AAMM-STT cấp lúc tạo');
select is(pg_temp.rev('p1'), 'TAO', 'Lịch sử ghi việc tạo');
select is((select (collect_branch_id = branch_id)::text || ':' || (receiver_id = created_by)::text from app.receipt where id = pg_temp.r('p1')), 'true:true',
          'Đ258: Cơ sở thu tiền mặc định cơ sở người lập, Người nhận tiền mặc định người lập');
select is(pg_temp.err($$select app.create_receipt(pg_temp.o('d1'), '{"amount": 99999999, "payment_method_code": "TIEN_MAT"}')$$), 'HMT_SO_TIEN_VUOT', 'Chặn: số tiền vượt phần còn thu được của đơn');
select is(pg_temp.err($$select app.create_receipt(pg_temp.o('d1'), '{"amount": 0, "payment_method_code": "TIEN_MAT"}')$$), 'HMT_SO_TIEN_SAI', 'Chặn: số tiền không lớn hơn 0');
select is(pg_temp.err($$select app.create_receipt(pg_temp.o('d1'), '{"amount": 100000}')$$), 'HMT_THIEU_HINH_THUC', 'Chặn: thiếu hình thức thanh toán');
select is(pg_temp.err($$select app.create_receipt(pg_temp.o('d1'), '{"amount": 100000, "payment_method_code": "BITCOIN"}')$$), 'HMT_DANH_MUC_KHONG_CO', 'Chặn: hình thức thanh toán ngoài danh mục');
select is(pg_temp.err($$select app.create_receipt(pg_temp.o('d1'), '{"amount": 100000, "payment_method_code": "TIEN_MAT", "paid_on": "2999-01-01"}')$$), 'HMT_NGAY_THU_SAI', 'Chặn: ngày thu ở tương lai');
select is(pg_temp.err($$select app.create_receipt(pg_temp.o('d1'), jsonb_build_object('amount', 100000, 'payment_method_code', 'TIEN_MAT',
          'target_line_id', (select id from app.sales_order_line where order_id = pg_temp.o('d2') limit 1)))$$), 'HMT_DONG_SAI', 'Chặn: dòng cấn không thuộc đơn');
select ok((select (r -> 'warnings') <> '[]'::jsonb from (select app.create_receipt(pg_temp.o('d1'), jsonb_build_object('amount', 100000, 'payment_method_code', 'TIEN_MAT',
          'collect_branch_id', (select id from app.branch where code = 'CS5'))) r) x), 'Đ258: Cơ sở thu tiền khác cơ sở đơn chỉ nhắc nhẹ, không chặn');
select pg_temp.sudo($$update app.receipt set status_code = 'HUY' where amount = 100000 and status_code = 'NHAP'$$);

-- ================= Sửa Nháp, quyền tạo =================
select is(pg_temp.err($$select app.save_receipt(pg_temp.r('p1'), '{"amount": 1000000, "payment_method_code": "TIEN_MAT"}')$$), null, 'Đúng: người lập sửa phiếu Nháp');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.create_receipt(pg_temp.o('d1'), '{"amount": 100000, "payment_method_code": "TIEN_MAT"}')$$), 'HMT_KHONG_CO_QUYEN', 'Sale CS5 không tạo phiếu cho đơn CS1');
select is(pg_temp.err($$select app.save_receipt(pg_temp.r('p1'), '{"amount": 500000, "payment_method_code": "TIEN_MAT"}')$$), 'HMT_KHONG_CO_QUYEN', 'Sale CS5 không sửa phiếu CS1');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.save_receipt(pg_temp.r('p1'), '{"amount": 500000, "payment_method_code": "TIEN_MAT"}')$$), 'HMT_KHONG_PHAI_NGUOI_LAP', 'Chỉ người lập mới sửa phiếu của mình');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ================= Gửi, quản lý duyệt (R-TIEN-01, R-HT-06) =================
-- Anh chốt 06/11 (Q-B1): mã giao dịch KHÔNG bắt buộc với mọi hình thức; kế toán thấy khi duyệt và có thể từ chối nếu thiếu.
select app.save_receipt(pg_temp.r('p1'), '{"amount": 1000000, "payment_method_code": "CHUYEN_KHOAN"}');
select is((select txn_ref from app.receipt where id = pg_temp.r('p1')), null, 'Q-B1: chuyển khoản không có mã giao dịch vẫn lưu được');
select app.save_receipt(pg_temp.r('p1'), '{"amount": 1000000, "payment_method_code": "CHUYEN_KHOAN", "txn_ref": "GD001"}');
select is(pg_temp.err($$select app.submit_receipt(pg_temp.r('p1'))$$), null, 'Đúng: người lập gửi phiếu thu');
select is(pg_temp.rst('p1'), 'DA_GUI', 'Phiếu về Đã gửi');
select is((select approval_route || ':' || (select key from u where id = assigned_approver_id) from app.receipt where id = pg_temp.r('p1')), 'QUAN_LY:bm1',
          'R-HT-06: chốt quản lý trực tiếp của người lập làm người duyệt bước quản lý');
select is(pg_temp.err($$select app.submit_receipt(pg_temp.r('p1'))$$), 'HMT_SAI_TRANG_THAI', 'Gửi lần hai thì chặn');
select is(pg_temp.err($$select app.save_receipt(pg_temp.r('p1'), '{"amount": 500000, "payment_method_code": "TIEN_MAT"}')$$), 'HMT_SAI_TRANG_THAI', 'R-TIEN-23: phiếu rời Nháp không sửa được');
select is(pg_temp.err($$select pg_temp.sudo('update app.receipt set amount = 1 where id = pg_temp.r(''p1'')')$$), 'HMT_PHIEU_THU_DA_KHOA', 'Phiếu đã gửi: số tiền khoá ngay ở bảng');
select is(pg_temp.err($$select app.approve_receipt_manager(pg_temp.r('p1'))$$), 'HMT_KHONG_CO_QUYEN', 'Người lập (Sale) không có quyền Duyệt phiếu thu');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.approve_receipt_manager(pg_temp.r('p1'))$$), 'HMT_KHONG_CO_QUYEN', 'R-TIEN-01: Admin không duyệt thay bước quản lý của phiếu thu');
select pg_temp.claims(pg_temp.uid('bm1b'), 'aal1');
select is(pg_temp.err($$select app.approve_receipt_manager(pg_temp.r('p1'))$$), 'HMT_KHONG_PHAI_NGUOI_DUYET', 'Có quyền Duyệt nhưng không phải người đã chốt thì chặn');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.approve_receipt_accounting(pg_temp.r('p1'))$$), 'HMT_SAI_TRANG_THAI', 'Kế toán chưa duyệt được phiếu còn ở bước quản lý (chưa Chờ kế toán)');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_receipt_manager(pg_temp.r('p1'))$$), null, 'Đúng: quản lý đã chốt duyệt bước quản lý');
select is(pg_temp.rst('p1'), 'CHO_KE_TOAN', 'Sau bước quản lý phiếu Chờ kế toán');
select is(pg_temp.rev('p1'), 'TAO,SUA,SUA,SUA,GUI,DUYET_QL', 'Lịch sử: tạo, sửa (ba lần), gửi, quản lý duyệt');
select is(pg_temp.err($$select app.approve_receipt_accounting(pg_temp.r('p1'))$$), 'HMT_KHONG_CO_QUYEN', 'Quản lý không có quyền duyệt bước kế toán');

-- ================= Kế toán từ chối, gửi lại đi lại từ bước quản lý (R-TIEN-06, TD14) =================
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.reject_receipt(pg_temp.r('p1'), '')$$), 'HMT_THIEU_LY_DO', 'Từ chối bắt buộc lý do');
select is(pg_temp.err($$select app.reject_receipt(pg_temp.r('p1'), 'Sai mã giao dịch')$$), null, 'Đúng: kế toán từ chối kèm lý do');
select is(pg_temp.rst('p1'), 'NHAP', 'R-TIEN-06: bị từ chối thì về Nháp');
select is((select count(*)::int from app.receipt_event where receipt_id = pg_temp.r('p1') and event_code = 'TU_CHOI' and note = 'Sai mã giao dịch'), 1, 'Lịch sử giữ lần từ chối và lý do');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.submit_receipt(pg_temp.r('p1'));
select is(pg_temp.rst('p1'), 'DA_GUI', 'TD14: gửi lại đi lại từ bước quản lý (không nhảy thẳng tới kế toán)');
select is((select note from app.receipt_event where receipt_id = pg_temp.r('p1') and event_code = 'GUI' order by seq desc limit 1), 'Gửi lại, chưa sửa từ lần bị từ chối',
          'Q-58: gửi lại chưa sửa từ lần bị từ chối thì sự kiện Gửi ghi rõ, không chặn');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.reject_receipt(pg_temp.r('p1'), 'Cần sửa ghi chú');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.save_receipt(pg_temp.r('p1'), '{"amount": 1000000, "payment_method_code": "CHUYEN_KHOAN", "txn_ref": "GD001"}');
select app.submit_receipt(pg_temp.r('p1'));
select is((select note from app.receipt_event where receipt_id = pg_temp.r('p1') and event_code = 'GUI' order by seq desc limit 1), null,
          'Q-58: đã sửa sau lần từ chối thì sự kiện Gửi không có ghi chú "chưa sửa"');
select is(pg_temp.rst('p1'), 'DA_GUI', 'Q-58: gửi lại sau khi sửa vẫn đi từ bước quản lý');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_receipt_manager(pg_temp.r('p1'));

-- ================= Kế toán duyệt: sinh khoản tiền vào, chia tiền về dòng (R-TIEN-01, 22) =================
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.approve_receipt_accounting(pg_temp.r('p1'))$$), null, 'Đúng: kế toán duyệt');
select is(pg_temp.rst('p1'), 'DA_DUYET', 'Phiếu Đã duyệt');
select is(pg_temp.paid('d1'), 1000000::bigint, 'Khoản tiền vào sinh khi kế toán duyệt: đơn đã thu 1.000.000');
select ok((select code ~ '^KTV-CS1-\d{4}-\d{4}$' from app.money_in where receipt_id = pg_temp.r('p1')), 'Mã KTV-CS1-AAMM-STT cấp cho khoản tiền vào');
select is((select sum(a.amount)::bigint from app.money_in_allocation a join app.money_in m on m.id = a.money_in_id where m.receipt_id = pg_temp.r('p1')), 1000000::bigint,
          'Tiền chia về dòng đúng tổng khoản tiền vào');
select is(pg_temp.err($$select app.approve_receipt_accounting(pg_temp.r('p1'))$$), 'HMT_SAI_TRANG_THAI', 'Duyệt lần hai thì chặn (không sinh khoản tiền vào thứ hai)');
select is((select count(*)::int from app.money_in where receipt_id = pg_temp.r('p1')), 1, 'Chỉ một khoản tiền vào cho một phiếu');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((app.order_payment_summary(pg_temp.o('d1')) ->> 'paid')::bigint, 1000000::bigint, 'Tóm tắt thanh toán: đã thu');
select is((app.order_payment_summary(pg_temp.o('d1')) ->> 'remaining')::bigint, 1200000::bigint, 'Tóm tắt thanh toán: còn lại');
select is((app.order_payment_summary(pg_temp.o('d1')) ->> 'deposit_reached')::boolean, true, 'R-TIEN-20: đủ cọc tối thiểu 1.000.000 thì bật cờ đủ cọc');
select is((app.order_payment_summary(pg_temp.o('d1')) ->> 'fully_paid')::boolean, false, 'Chưa thu đủ');

-- Chia tỉ lệ nhiều dòng (R-TIEN-22): đơn d2 (2.200.000 và 1.100.000), phiếu 1.650.000 không cấn → 1.100.000 và 550.000.
select pg_temp.mkr('p2', 'd2', '{"amount": 1650000, "payment_method_code": "TIEN_MAT"}');
select app.submit_receipt(pg_temp.r('p2'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_receipt_manager(pg_temp.r('p2'));
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select app.approve_receipt_accounting(pg_temp.r('p2'));
select is((select array_agg(a.amount order by l.line_no) from app.money_in_allocation a join app.money_in m on m.id = a.money_in_id
            join app.sales_order_line l on l.id = a.order_line_id where m.receipt_id = pg_temp.r('p2')), array[1100000, 550000]::bigint[],
          'R-TIEN-22: tiền chia về các dòng theo tỉ lệ thành tiền (2:1)');
-- Cấn vào dòng (R-TIEN-23): phiếu 1.650.000 cấn vào dòng 2 (thành tiền 1.100.000) → dòng 2 nhận đủ 1.100.000, phần thừa 550.000 vào dòng 1.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mkr('p3', 'd2', jsonb_build_object('amount', 1650000, 'payment_method_code', 'TIEN_MAT',
          'target_line_id', (select id from app.sales_order_line where order_id = pg_temp.o('d2') and line_no = 2)));
select is(pg_temp.err($$select app.submit_receipt(pg_temp.r('p3'))$$), 'HMT_SO_TIEN_VUOT', 'Chặn: tổng tiền các phiếu vượt tổng đơn (3.300.000), kiểm lúc gửi')
  where false;
select pg_temp.sudo($$update app.receipt set amount = 1000000 where id = pg_temp.r('p3')$$);
select app.submit_receipt(pg_temp.r('p3'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.approve_receipt_manager(pg_temp.r('p3'));
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select app.approve_receipt_accounting(pg_temp.r('p3'));
select is((select array_agg(a.amount order by l.line_no) from app.money_in_allocation a join app.money_in m on m.id = a.money_in_id
            join app.sales_order_line l on l.id = a.order_line_id where m.receipt_id = pg_temp.r('p3')), array[450000, 550000]::bigint[],
          'R-TIEN-23: phiếu 1.000.000 cấn vào dòng 2 (còn nhận được 550.000), phần thừa 450.000 vào dòng 1 (theo thứ tự dòng 1, dòng 2)');
select is(pg_temp.paid('d2'), 2650000::bigint, 'Đơn d2 đã thu 2.650.000 sau hai phiếu');

-- ================= Trưởng cơ sở lập phiếu: tự duyệt bước quản lý =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkr('p4', 'd1', '{"amount": 500000, "payment_method_code": "TIEN_MAT"}');
select is((app.submit_receipt(pg_temp.r('p4')) ->> 'status'), 'CHO_KE_TOAN', 'R-HT-06: Trưởng cơ sở lập thì tự duyệt bước quản lý, phiếu Chờ kế toán ngay');
select is(pg_temp.rev('p4'), 'TAO,GUI,TU_DUYET_QL', 'Lịch sử ghi "tự duyệt" bước quản lý');

-- ================= Huỷ phiếu =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mkr('p5', 'd1', '{"amount": 100000, "payment_method_code": "TIEN_MAT"}');
select is(pg_temp.err($$select app.cancel_receipt(pg_temp.r('p5'), 'KHAC')$$), 'HMT_THIEU_GHI_CHU', 'Huỷ với lý do "Lý do khác" bắt buộc ghi chú');
select is(pg_temp.err($$select app.cancel_receipt(pg_temp.r('p5'), 'KHACH_DOI_Y')$$), null, 'Đúng: người lập huỷ phiếu chưa duyệt');
select is(pg_temp.rst('p5'), 'HUY', 'Phiếu Huỷ');
select is(pg_temp.err($$select app.cancel_receipt(pg_temp.r('p1'), 'KHACH_DOI_Y')$$), 'HMT_PHIEU_DA_DUYET', 'Phiếu đã duyệt không huỷ được (đảo khoản làm sau)');
select is(pg_temp.err($$select app.cancel_receipt(pg_temp.r('p5'), 'KHACH_DOI_Y')$$), 'HMT_SAI_TRANG_THAI', 'Huỷ lần hai thì chặn');
select pg_temp.sudo($$create function pg_temp.ohr(p uuid) returns boolean language sql stable security definer as 'select app.order_has_receipt(p)'$$);
select pg_temp.sudo($$grant execute on function pg_temp.ohr(uuid) to public$$);
select ok(pg_temp.ohr(pg_temp.o('d1')), 'Đơn có phiếu thu còn sống: order_has_receipt đúng');

-- ================= Số tiền vượt tổng đơn, gửi cùng lúc nhiều phiếu =================
select pg_temp.mkr('p6', 'd1', '{"amount": 100000, "payment_method_code": "TIEN_MAT"}');
select pg_temp.sudo($$update app.receipt set amount = 800000 where id = pg_temp.r('p6')$$);
select is(pg_temp.err($$select app.submit_receipt(pg_temp.r('p6'))$$), 'HMT_SO_TIEN_VUOT', 'Chặn lúc gửi: đã thu 1.000.000, phiếu p4 chờ 500.000, thêm 800.000 vượt đơn 2.200.000 (còn thu được 700.000)');

-- ================= Lịch sử, khoản tiền vào chỉ thêm; trạng thái đi đúng bảng; ghi thẳng bị chặn; RLS =================
select is(pg_temp.err($$select pg_temp.sudo('update app.receipt_event set note = ''sửa'' where receipt_id = pg_temp.r(''p1'')')$$), 'HMT_CHI_THEM', 'Lịch sử phiếu thu chỉ thêm');
select is(pg_temp.err($$select pg_temp.sudo('update app.money_in set amount = 1 where receipt_id = pg_temp.r(''p1'')')$$), 'HMT_CHI_THEM', 'Khoản tiền vào không sửa được');
select is(pg_temp.err($$select pg_temp.sudo('delete from app.money_in_allocation where money_in_id in (select id from app.money_in where receipt_id = pg_temp.r(''p1''))')$$), 'HMT_CHI_THEM', 'Phần chia tiền không xoá được');
select is(pg_temp.err($$select pg_temp.sudo('update app.receipt set status_code = ''DA_DUYET'' where id = pg_temp.r(''p6'')')$$), 'HMT_SAI_TRANG_THAI', 'Nháp không nhảy thẳng sang Đã duyệt');
select is(pg_temp.err($$insert into app.money_in (code, receipt_id, order_id, parent_id, branch_id, amount) select 'KTV-X', id, order_id, parent_id, branch_id, 1 from app.receipt limit 1$$), '42501',
          'Ghi thẳng: không ai tạo khoản tiền vào bằng tay');
select is(pg_temp.err($$update app.receipt set amount = 1$$), '42501', 'Ghi thẳng: Sale không cập nhật phiếu thu qua bảng');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((select count(*)::int from app.receipt), 0, 'RLS: Sale CS5 không thấy phiếu thu CS1');
select is((select count(*)::int from app.money_in), 0, 'RLS: Sale CS5 không thấy khoản tiền vào CS1');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select ok((select count(*)::int from app.receipt) >= 5, 'RLS: Sale CS1 thấy phiếu thu của cơ sở mình');

-- ================= Hàm đọc: danh sách, bản ghi, việc làm được =================
select is((app.list_receipts('{"status": ["NHAP"]}') ->> 'total')::int, 1, 'Danh sách: lọc trạng thái Nháp (p6)');
select is((app.list_receipts('{"mine": true, "status": ["DA_DUYET"]}') ->> 'total')::int, 3, 'Danh sách: phiếu của tôi, Đã duyệt (p1, p2, p3)');
select is((app.list_receipts('{}', 'created_desc', 2, 0) -> 'rows')::jsonb -> 0 ->> 'code' is not null, true, 'Danh sách có mã phiếu');
select is(jsonb_array_length(app.list_receipts('{}', 'created_desc', 2, 0) -> 'rows'), 2, 'Danh sách: phân trang ở máy chủ, giới hạn số dòng');
select is((app.list_receipts(jsonb_build_object('q', 'phieu thu')) ->> 'total')::int >= 5, true, 'Danh sách: tìm theo tên phụ huynh (bỏ dấu)');
select is((app.list_receipts('{"q": "0900007001"}') ->> 'total')::int >= 2, true, 'Danh sách: tìm theo SĐT phụ huynh');
select is((app.list_receipts(jsonb_build_object('q', lower((select code from app.receipt where id = pg_temp.r('p1'))))) ->> 'total')::int, 1, 'Danh sách: tìm theo mã phiếu');
select is((app.list_receipts(jsonb_build_object('q', lower((select o.code from app.receipt r join app.sales_order o on o.id = r.order_id where r.id = pg_temp.r('p1'))))) ->> 'total')::int >= 1, true, 'Danh sách: tìm theo mã đơn');
select pg_temp.sudo($$update app.parent set full_name = 'Chị Đổi Tên Mới' where id = (select parent_id from app.receipt where id = pg_temp.r('p1'))$$);
select is((app.list_receipts('{"q": "doi ten moi"}') ->> 'total')::int >= 1, true, 'Danh sách: phụ huynh đổi tên thì tìm theo tên mới được (chữ để tìm tính lại)');
select is(app.get_receipt(pg_temp.r('p6')) -> 'actions', '["sua", "gui", "huy"]'::jsonb, 'Bản ghi: người lập thấy Sửa, Gửi, Huỷ ở phiếu Nháp');
select is(app.get_receipt(pg_temp.r('p1')) -> 'money_in' ->> 'amount', '1000000', 'Bản ghi: khoản tiền vào của phiếu đã duyệt');
select is((select sum((x ->> 'amount')::bigint)::int from jsonb_array_elements(app.get_receipt(pg_temp.r('p1')) -> 'money_in' -> 'allocations') x), 1000000, 'Bản ghi: phần chia tiền về dòng');
select is(jsonb_array_length(app.get_receipt(pg_temp.r('p1')) -> 'events'), 7, 'Bản ghi: lịch sử đủ (tạo, sửa, gửi, quản lý duyệt, từ chối, gửi, quản lý duyệt, kế toán duyệt)') where false;
select is(app.get_receipt(pg_temp.r('p1')) -> 'payment' ->> 'paid', '1000000', 'Bản ghi: tóm tắt thanh toán của đơn');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(app.get_receipt(pg_temp.r('p6')) -> 'actions', '["huy"]'::jsonb, 'Bản ghi: quản lý (có quyền Huỷ) chỉ thấy Huỷ ở phiếu Nháp của người khác, không Sửa, Gửi');
select is(app.get_receipt(pg_temp.r('p4')) -> 'actions', '["huy"]'::jsonb, 'Bản ghi: phiếu Chờ kế toán của chính mình lập, quản lý chỉ còn Huỷ');
select is(jsonb_array_length(app.list_receipts('{"waiting_manager": true}') -> 'rows'), 0, 'Hàng chờ quản lý duyệt trống khi không có phiếu Đã gửi chờ mình');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(app.get_receipt(pg_temp.r('p4')) -> 'actions', '["duyet_ke_toan", "tu_choi"]'::jsonb, 'Bản ghi: kế toán thấy Duyệt, Từ chối ở phiếu Chờ kế toán');
select is((app.list_receipts('{"waiting_accounting": true}') ->> 'total')::int, 1, 'TC-04: hàng chờ kế toán có đúng phiếu Chờ kế toán (p4)');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((app.list_receipts('{}') ->> 'total')::int, 0, 'RLS: Sale CS5 không thấy phiếu thu CS1 trong danh sách');
select is(pg_temp.err($$select app.get_receipt(pg_temp.r('p1'))$$), 'HMT_KHONG_CO_QUYEN', 'Sale CS5 không đọc được bản ghi phiếu CS1');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- ============ Ô chọn người nhận tiền ============
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select ok(jsonb_array_length(app.receipt_receiver_options(null, 5)) between 1 and 5, 'Sale chọn được người nhận tiền, tối đa số dòng yêu cầu');
select is(app.receipt_receiver_options('Giả sales1', 5) -> 0 ->> 'same_branch', 'true', 'Người cùng cơ sở xếp đầu');
select is((select count(*)::int from jsonb_array_elements(app.receipt_receiver_options('hs', 20)) e where e ->> 'name' = 'Giả hs'), 0, 'Không có tài khoản học sinh trong ô người nhận');
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is(pg_temp.err($$select app.receipt_receiver_options(null, 5)$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không chọn người nhận tiền');

-- ================= Ghi chú và hoạt động của phiếu thu (Q-52, migration 080) =================
-- Quyền xem giống hệt đơn hàng: Phiếu thu · Xem ở cơ sở của phiếu; Kế toán (toàn hệ thống) và Admin thấy mọi cơ sở.
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.record_history('RECEIPT', pg_temp.r('p1'))$$), null, 'Q-52: Sale cùng cơ sở xem được lịch sử thay đổi của phiếu thu');
select is(pg_temp.err($$select app.add_note('RECEIPT', pg_temp.r('p1'), 'Đã nhận tiền mặt')$$), null, 'Q-52: Sale cùng cơ sở viết được ghi chú trên phiếu thu');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.record_history('RECEIPT', pg_temp.r('p1'))$$), 'HMT_KHONG_CO_QUYEN', 'Q-52 chặn: Sale cơ sở khác không xem được lịch sử phiếu thu');
select is((select count(*)::int from app.note where entity_type = 'RECEIPT' and entity_id = pg_temp.r('p1')), 0, 'Q-52 chặn: Sale cơ sở khác không đọc được ghi chú phiếu thu');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is(pg_temp.err($$select app.record_history('RECEIPT', pg_temp.r('p1'))$$), null, 'Q-52: Kế toán (toàn hệ thống) xem được ghi chú và lịch sử phiếu thu');
select is((select count(*)::int from app.note where entity_type = 'RECEIPT' and entity_id = pg_temp.r('p1')), 1, 'Q-52: Kế toán đọc được ghi chú Sale đã viết');

-- ================= Q-63: người duyệt bị khoá khác với người duyệt thiếu quyền (migration 082) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select pg_temp.mkr('p9', 'd1', '{"amount": 100000, "payment_method_code": "TIEN_MAT"}');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.admin_set_locked(pg_temp.uid('bm1'), true, 'thử Q-63');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.submit_receipt(pg_temp.r('p9'))$$), 'HMT_NGUOI_DUYET_BI_KHOA', 'Q-63 chặn: gửi phiếu thu khi quản lý bị khoá báo mã riêng');
select is(pg_temp.msg($$select app.submit_receipt(pg_temp.r('p9'))$$), 'Quản lý trực tiếp của người lập đang bị khoá nên chưa trình được. Nhờ Admin mở khoá hoặc đặt lại Quản lý trực tiếp.',
          'Q-63: câu báo lỗi khi quản lý bị khoá');
select is(pg_temp.rst('p9'), 'NHAP', 'Q-63: bị chặn thì phiếu vẫn Nháp');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.admin_set_locked(pg_temp.uid('bm1'), false, null);
select pg_temp.sudo($$select set_config('hmt.manager', 'on', true)$$);
select pg_temp.sudo($$update app.user_account set manager_id = (select id from pg_temp.u where key = 'sales5') where id = (select id from pg_temp.u where key = 'sales1')$$);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.submit_receipt(pg_temp.r('p9'))$$), 'HMT_NGUOI_DUYET_THIEU_QUYEN', 'Q-63: quản lý không bị khoá nhưng thiếu quyền Duyệt phiếu thu giữ mã và câu cũ');
select pg_temp.sudo($$select set_config('hmt.manager', 'on', true)$$);
select pg_temp.sudo($$update app.user_account set manager_id = (select id from pg_temp.u where key = 'bm1') where id = (select id from pg_temp.u where key = 'sales1')$$);
select is(pg_temp.err($$select app.submit_receipt(pg_temp.r('p9'))$$), null, 'Q-63: đặt lại quản lý hợp lệ thì gửi được');

select * from finish();
rollback;
