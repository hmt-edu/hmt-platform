-- TC-02 nợ theo TỪNG EM (migration 253): trần theo em khi phiếu có em tham chiếu, hàm đọc nợ từng em. Giữ khoá phụ huynh (Chat 15:28 b). Dựng như bài 251, 252.
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
insert into u (key) values ('admin'), ('cskh'), ('ke'), ('cskh5');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p253.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p253.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('cskh', 'CS1'), ('ke', 'CS1'), ('cskh5', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('cskh', 'CSKH'), ('ke', 'ACCOUNTANT'), ('cskh5', 'CSKH')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- Phụ huynh giả ở CS1 có nợ đầu kỳ 3.000.000 (số âm trong sổ số dư, khoá theo phụ huynh); phụ huynh 2 không có nợ. Học sinh chỉ là ghi chú tham chiếu.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH253A', 'Phụ huynh giả 251', '0900253001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HS253A', id, 'Em nợ đầu kỳ', 2012, branch_id from app.parent where code = 'PH253A'$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HS253B', id, 'Em không nợ', 2013, branch_id from app.parent where code = 'PH253A'$$);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH253B', 'Phụ huynh không nợ 251', '0900253002', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref)
  select s.parent_id, s.id, s.branch_id, 'DAU_KY_CONG_NO', -3000000, current_date, 'TEST-253' from app.student s where s.code = 'HS253A'$$);
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


-- Hai em của một phụ huynh: A nợ 3.000.000 (dựng sẵn); B nợ 5.000.000 và có tiền thu thừa 500.000 (không bù trừ vào nợ).
select pg_temp.sudo($$insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref)
  select s.parent_id, s.id, s.branch_id, 'DAU_KY_CONG_NO', -5000000, current_date, 'TEST-253B' from app.student s where s.code = 'HS253B'$$);
select pg_temp.sudo($$insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref)
  select s.parent_id, s.id, s.branch_id, 'DAU_KY_THU_THUA', 500000, current_date, 'TEST-253C' from app.student s where s.code = 'HS253B'$$);
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'opening_debt_receipt_enabled'$$);
create function pg_temp.dst(p_amount bigint, p_student text) returns jsonb language sql as $$
  select jsonb_build_object('amount', p_amount, 'payment_method_code', 'TIEN_MAT') || case when p_student is null then '{}'::jsonb else jsonb_build_object('student_id', pg_temp.sid(p_student)) end $$;
grant execute on function pg_temp.dst(bigint, text) to public;
create function pg_temp.stu(p_json jsonb, p_code text, p_key text) returns text language sql immutable as $$
  select e ->> p_key from jsonb_array_elements(p_json -> 'students') e where e ->> 'code' = p_code $$;
grant execute on function pg_temp.stu(jsonb, text, text) to public;
set local role authenticated;
select pg_temp.claims((select id from u where key = 'cskh'), 'aal1');

-- ---- Hàm đọc nợ từng em ----
select is(pg_temp.stu(app.opening_debt_by_student(pg_temp.pid('PH253A')), 'HS253A', 'remaining'), '3000000', 'Em A: nợ còn lại 3.000.000');
select is(pg_temp.stu(app.opening_debt_by_student(pg_temp.pid('PH253A')), 'HS253B', 'remaining'), '5000000', 'Em B: nợ còn lại 5.000.000 (không bị tiền thu thừa bù trừ)');
select is(pg_temp.stu(app.opening_debt_by_student(pg_temp.pid('PH253A')), 'HS253B', 'credit'), '500000', 'Em B: tiền thu thừa 500.000 hiện riêng');
select is((app.opening_debt_by_student(pg_temp.pid('PH253A')) ->> 'parent_remaining')::bigint, 8000000::bigint, 'Tổng nợ phụ huynh = cộng nợ các em (không trừ tiền thu thừa)');
select is((app.opening_debt_by_student(pg_temp.pid('PH253A')) ->> 'parent_credit')::bigint, 500000::bigint, 'Tổng tiền thu thừa của phụ huynh');
select is(app.opening_debt_remaining(pg_temp.pid('PH253A')), 8000000::bigint, 'Trần theo phụ huynh (migration 251) vẫn là 8.000.000');

-- ---- Trần theo em ----
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH253A'), pg_temp.dst(3000001, 'HS253A'))$$), 'HMT_SO_TIEN_VUOT', 'Vượt nợ của em A (3.000.001) bị chặn dù tổng nợ phụ huynh là 8.000.000');
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH253A'), pg_temp.dst(5000001, 'HS253B'))$$), 'HMT_SO_TIEN_VUOT', 'Vượt nợ của em B bị chặn');
create temp table ra (v jsonb);
grant all on ra to public;
insert into ra select app.create_opening_debt_receipt(pg_temp.pid('PH253A'), pg_temp.dst(3000000, 'HS253A'));
select is((select status_code from app.receipt where id = (select (v ->> 'id')::uuid from ra)), 'NHAP', 'Đúng bằng nợ của em A: tạo được');
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH253A'), pg_temp.dst(1, 'HS253A'))$$), 'HMT_SO_TIEN_VUOT', 'Phiếu thứ hai cho em A: bị chặn (phiếu chờ đã trừ khỏi nợ của em)');
select is(pg_temp.stu(app.opening_debt_by_student(pg_temp.pid('PH253A')), 'HS253A', 'remaining'), '0', 'Nợ của em A (đã trừ phiếu chờ) về 0');
select is(pg_temp.stu(app.opening_debt_by_student(pg_temp.pid('PH253A')), 'HS253B', 'remaining'), '5000000', 'Phiếu của em A không làm đổi nợ em B');

-- ---- after_approval và chính phiếu không tự trừ ----
select is(pg_temp.stu(app.opening_debt_by_student(pg_temp.pid('PH253A'), (select (v ->> 'id')::uuid from ra)), 'HS253A', 'remaining'), '3000000', 'Xem phiếu: nợ em A không trừ chính phiếu đang xem');
select is(pg_temp.stu(app.opening_debt_by_student(pg_temp.pid('PH253A'), (select (v ->> 'id')::uuid from ra)), 'HS253A', 'after_approval'), '0', 'Xem phiếu: nợ em A sau khi duyệt (dự kiến) = 0');
select is(pg_temp.stu(app.opening_debt_by_student(pg_temp.pid('PH253A'), (select (v ->> 'id')::uuid from ra)), 'HS253B', 'after_approval'), '5000000', 'Xem phiếu: em B giữ nguyên sau khi duyệt');

-- ---- Phiếu không em: chỉ kiểm theo phụ huynh như cũ (không đổi hành vi) ----
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH253A'), pg_temp.dst(5000001, null))$$), 'HMT_SO_TIEN_VUOT', 'Phiếu không em: vượt phần nợ phụ huynh còn lại (8.000.000 trừ 3.000.000 chờ) bị chặn');
select is(app.create_opening_debt_receipt(pg_temp.pid('PH253A'), pg_temp.dst(5000000, null)) ->> 'remaining_after', '0', 'Phiếu không em đúng phần còn lại phụ huynh: tạo được');

-- ---- Sửa phiếu qua save_receipt: trần theo em vẫn áp ----
select is(pg_temp.err($$select app.save_receipt((select (v ->> 'id')::uuid from ra), pg_temp.dst(3000001, 'HS253A'))$$), 'HMT_SO_TIEN_VUOT', 'Sửa phiếu em A vượt nợ em: bị chặn (trigger)');
select is((app.save_receipt((select (v ->> 'id')::uuid from ra), pg_temp.dst(2000000, 'HS253A')) ->> 'id')::uuid, (select (v ->> 'id')::uuid from ra), 'Giảm số tiền: sửa được');

-- ---- Gửi và duyệt: nợ em giảm đúng, em khác không đổi ----
select is(app.submit_receipt((select (v ->> 'id')::uuid from ra)) ->> 'status', 'CHO_KE_TOAN', 'Gửi thẳng Kế toán');
select pg_temp.claims((select id from u where key = 'ke'), 'aal2');
select is(app.approve_receipt_accounting((select (v ->> 'id')::uuid from ra)) ->> 'remaining', '1000000', 'Duyệt xong: nợ còn lại của phụ huynh là 1.000.000 (8.000.000 trừ 2.000.000 đã duyệt trừ 5.000.000 phiếu không em đang chờ)');

-- ---- Hàm trợ giúp không cho người đã đăng nhập gọi trực tiếp (không đọc nợ em ở cơ sở khác) ----
select is(pg_temp.err($$select app.opening_student_debt_remaining(pg_temp.sid('HS253A'))$$), '42501', 'Người đã đăng nhập không gọi trực tiếp opening_student_debt_remaining (chặn đọc nợ em bất kỳ)');

-- ---- Vai ngoài cơ sở bị chặn (RLS, quyền): CSKH của CS5 không đọc nợ từng em, không tạo phiếu nợ đầu kỳ cho phụ huynh CS1; tiền thu thừa và nợ không lộ ----
select pg_temp.claims((select id from u where key = 'cskh5'), 'aal1');
select is(pg_temp.err($$select app.opening_debt_by_student(pg_temp.pid('PH253A'))$$), 'HMT_KHONG_CO_QUYEN', 'CSKH cơ sở khác không đọc nợ từng em của phụ huynh cơ sở này');
select is(pg_temp.err($$select app.create_opening_debt_receipt(pg_temp.pid('PH253A'), pg_temp.dst(1000, 'HS253A'))$$), 'HMT_KHONG_CO_QUYEN', 'CSKH cơ sở khác không tạo phiếu thu nợ đầu kỳ cho phụ huynh cơ sở này');
select is((select count(*)::int from app.receipt where is_opening_debt), 0, 'RLS: CSKH cơ sở khác không thấy phiếu nợ đầu kỳ của cơ sở này');
select is(pg_temp.err($$select app.opening_student_debt_remaining(pg_temp.sid('HS253A'))$$), '42501', 'CSKH cơ sở khác không gọi trực tiếp hàm trợ giúp nợ em');

select * from finish();
rollback;
