-- N1 (migration 421, Soát S14): Kế toán không tự lập + tự gửi + tự duyệt phiếu thu nợ đầu kỳ. Luật R-V2-15 (CSKH tạo, Kế toán duyệt, không qua quản lý), R-HT-01.
-- Kịch bản tái hiện của Soát: một Kế toán gọi create_opening_debt_receipt → submit → approve: trước sửa phiếu Đã duyệt, nợ về 0. Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
create temp table rc (key text primary key, id uuid);
grant all on rc to public;
grant select on u to authenticated;
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
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.pid(p_code text) returns uuid language sql stable security definer as $$ select id from app.parent where code = p_code $$;
create function pg_temp.st(p_key text) returns text language sql stable security definer as $$ select status_code from app.receipt where id = (select id from pg_temp.rc where key = p_key) $$;
grant execute on all functions in schema pg_temp to public;
insert into u (key) values ('admin'), ('cskh'), ('ke'), ('ke2');
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p421.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p421.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('cskh', 'CSKH'), ('ke', 'ACCOUNTANT'), ('ke2', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'opening_debt_receipt_enabled'$$);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH421', 'Phụ huynh giả 421', '0900421001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.customer_balance_entry (parent_id, branch_id, entry_type, amount, entry_date, source_ref)
  select id, branch_id, 'DAU_KY_CONG_NO', -3000000, current_date, 'TEST-421' from app.parent where code = 'PH421'$$);
create function pg_temp.bal() returns bigint language sql stable security definer as $$
  select coalesce(sum(amount), 0)::bigint from app.customer_balance_entry where parent_id = pg_temp.pid('PH421') $$;
grant execute on function pg_temp.bal() to public;
create function pg_temp.mk(p_key text, p_user text) returns void language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.claims(pg_temp.uid(p_user), case when p_user like 'ke%' then 'aal2' else 'aal1' end);
  v := app.create_opening_debt_receipt(pg_temp.pid('PH421'), jsonb_build_object('amount', 1000000, 'payment_method_code', 'TIEN_MAT'));
  insert into rc values (p_key, (v ->> 'id')::uuid);
end $$;
grant execute on function pg_temp.mk(text, text) to public;
set local role authenticated;

-- ---- Ca bị chặn 1: Kế toán tự lập, tự gửi, tự duyệt (kịch bản tái hiện của Soát) ----
select pg_temp.mk('A', 'ke');
select lives_ok($$select app.submit_opening_debt_receipt((select id from rc where key = 'A'))$$, 'Kế toán tự lập rồi tự gửi được (gửi thì không bị chặn)');
select is(pg_temp.err($$select app.approve_opening_debt_receipt((select id from rc where key = 'A'))$$), 'HMT_CUNG_NGUOI_DUYET_HAI_BUOC', 'N1: người lập không tự duyệt phiếu nợ đầu kỳ của mình');
select is(pg_temp.err($$select app.approve_receipt_accounting((select id from rc where key = 'A'))$$), 'HMT_CUNG_NGUOI_DUYET_HAI_BUOC', 'N1: đường hàm cũ approve_receipt_accounting cũng chặn người lập tự duyệt');
select is(pg_temp.st('A'), 'CHO_KE_TOAN', 'Phiếu bị chặn vẫn chờ Kế toán khác duyệt');
select is(pg_temp.bal(), -3000000::bigint, 'Nợ đầu kỳ chưa đổi khi chặn tự duyệt');

-- ---- Ca bị chặn 2: CSKH lập, Kế toán gửi rồi chính Kế toán đó duyệt ----
select pg_temp.mk('B', 'cskh');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select lives_ok($$select app.submit_opening_debt_receipt((select id from rc where key = 'B'))$$, 'Kế toán gửi phiếu do CSKH lập được');
select is(pg_temp.err($$select app.approve_opening_debt_receipt((select id from rc where key = 'B'))$$), 'HMT_CUNG_NGUOI_DUYET_HAI_BUOC', 'N1: người gửi không tự duyệt phiếu mình đã gửi');

-- ---- Ca đúng: người duyệt là Kế toán khác người lập và người gửi ----
select pg_temp.claims(pg_temp.uid('ke2'), 'aal2');
select is((app.approve_opening_debt_receipt((select id from rc where key = 'A')) ->> 'remaining')::bigint, 1000000::bigint, 'Kế toán khác duyệt phiếu A: nợ còn 1.000.000 (đã trừ phiếu B đang chờ)');
select is((app.approve_opening_debt_receipt((select id from rc where key = 'B')) ->> 'remaining')::bigint, 1000000::bigint, 'Kế toán khác duyệt phiếu B: nợ còn 1.000.000 (đã thu 2.000.000)');
select is(pg_temp.st('A') || pg_temp.st('B'), 'DA_DUYETDA_DUYET', 'Hai phiếu đã duyệt');
select pg_temp.mk('D', 'cskh');
select pg_temp.claims(pg_temp.uid('cskh'), 'aal1');
select lives_ok($$select app.submit_opening_debt_receipt((select id from rc where key = 'D'))$$, 'CSKH gửi phiếu của mình');
-- R-HT-01 vẫn đúng: Admin không duyệt tiền.
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select pg_temp.claims(pg_temp.uid('cskh'), 'aal1');
select is(pg_temp.err($$select app.approve_opening_debt_receipt((select id from rc where key = 'D'))$$), 'HMT_KHONG_CO_QUYEN', 'R-HT-01: Vai không có quyền duyệt tiền không duyệt phiếu thu nợ đầu kỳ');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select pg_temp.claims(pg_temp.uid('ke'), 'aal2');
select is((app.approve_opening_debt_receipt((select id from rc where key = 'D')) ->> 'remaining')::bigint, 0::bigint, 'Ca đúng cũ vẫn chạy: CSKH lập và gửi, Kế toán duyệt, nợ về 0');

select * from finish();
rollback;
