-- C16 cụm 1 (migration 420): người duyệt dự kiến và lý do chặn trình của phiếu thu Nháp (R-HT-06, R-V2-12, R-V2-41, Q-62, Q-63). Dữ liệu giả.
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
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.rid(p_code text) returns uuid language sql stable security definer as $$ select id from app.receipt where code = p_code $$;
create function pg_temp.exp(p_code text, p_key text) returns text language sql stable as $$ select app.receipt_expected_approver(pg_temp.rid(p_code)) ->> p_key $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('sale_ql'), ('sale_tcs'), ('sale_khong'), ('ql'), ('ql_thieu'), ('tcs'), ('ke5');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p420.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p420.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('sale_ql', 'SALES'), ('sale_tcs', 'SALES'), ('sale_khong', 'SALES'), ('ql', 'BRANCH_MANAGER'),
  ('ql_thieu', 'MARKETER'), ('tcs', 'BRANCH_MANAGER'), ('ke5', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
-- Quản lý trực tiếp chỉ đổi qua hàm có cờ hmt.manager (luật toàn vẹn của migration 036); bài dựng dữ liệu bật cờ trong giao dịch.
select pg_temp.sudo($$select set_config('hmt.manager', 'on', true)$$);
select pg_temp.sudo($$update app.user_account set manager_id = (select id from pg_temp.u where key = 'ql') where id = (select id from pg_temp.u where key = 'sale_ql')$$);
-- Phiếu Nháp của ba người lập, mỗi người một đơn Nháp giả (gốc là phiếu tái tục giả, như bài 114).
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH420', 'Phụ huynh giả 420', '0900420001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.sales_order (code, branch_id, renewal_ticket_id, parent_id, priced_on, status_code)
  select 'DH-P420-' || n, (select id from app.branch where code = 'CS1'), gen_random_uuid(), (select id from app.parent where code = 'PH420'), current_date, 'DA_DUYET'
    from generate_series(1, 3) n$$);
-- Mỗi phiếu dựng khi đăng nhập giả là người lập (trigger chuẩn ghi created_by = người đang đăng nhập); dựng bằng quyền máy chủ, bài chỉ kiểm hàm đọc.
create function pg_temp.mkrec(p_n integer, p_key text) returns void language plpgsql security definer as $$
begin
  perform pg_temp.claims(pg_temp.uid(p_key), 'aal1');
  insert into app.receipt (code, order_id, parent_id, branch_id, collect_branch_id, amount, payment_method_code)
  select 'PT-P420-' || p_n, o.id, o.parent_id, o.branch_id, o.branch_id, 1000000, 'TIEN_MAT' from app.sales_order o where o.code = 'DH-P420-' || p_n;
end $$;
grant execute on function pg_temp.mkrec(integer, text) to public;
select pg_temp.mkrec(1, 'sale_ql');
select pg_temp.mkrec(2, 'sale_tcs');
select pg_temp.mkrec(3, 'sale_khong');

set local role authenticated;
select pg_temp.claims(pg_temp.uid('sale_ql'), 'aal1');
-- Có quản lý trực tiếp có quyền: không chặn.
select is(pg_temp.exp('PT-P420-1', 'expected_route'), 'QUAN_LY', 'Có quản lý trực tiếp: đường duyệt QUAN_LY');
select is(pg_temp.exp('PT-P420-1', 'expected_approver_name'), 'Giả ql', 'Tên người duyệt dự kiến là quản lý trực tiếp');
select is(pg_temp.exp('PT-P420-1', 'expected_block'), null, 'Quản lý còn hoạt động, đủ quyền: không chặn');
-- Quản lý bị khoá.
select pg_temp.sudo($$update app.user_account set is_locked = true where id = (select id from pg_temp.u where key = 'ql')$$);
select is(pg_temp.exp('PT-P420-1', 'expected_block'), 'NGUOI_DUYET_BI_KHOA', 'Quản lý bị khoá: chặn NGUOI_DUYET_BI_KHOA (Q-63)');
select pg_temp.sudo($$update app.user_account set is_locked = false where id = (select id from pg_temp.u where key = 'ql')$$);
-- Quản lý thiếu quyền Duyệt phiếu thu (đổi quản lý sang người chỉ có quyền Marketer).
select pg_temp.sudo($$update app.user_account set manager_id = (select id from pg_temp.u where key = 'ql_thieu') where id = (select id from pg_temp.u where key = 'sale_ql')$$);
select is(pg_temp.exp('PT-P420-1', 'expected_block'), 'NGUOI_DUYET_THIEU_QUYEN', 'Quản lý thiếu quyền Duyệt phiếu thu: chặn NGUOI_DUYET_THIEU_QUYEN');
-- Chưa có quản lý, cơ sở có Trưởng cơ sở: không chặn, đường TRUONG_CS (R-V2-41).
select pg_temp.claims(pg_temp.uid('sale_tcs'), 'aal1');
select is(pg_temp.exp('PT-P420-2', 'expected_route'), 'TRUONG_CS', 'Chưa có quản lý, có Trưởng cơ sở: đường duyệt TRUONG_CS');
select is(pg_temp.exp('PT-P420-2', 'expected_block'), null, 'Đường Trưởng cơ sở không chặn trình');
-- Chưa có quản lý và cơ sở không còn Trưởng cơ sở nào hoạt động: chặn KHONG_CO_QUAN_LY.
select pg_temp.sudo($$update app.user_role set is_active = false where role_code = 'BRANCH_MANAGER' and user_id in (select id from pg_temp.u)$$);
select is(pg_temp.exp('PT-P420-2', 'expected_block'), 'KHONG_CO_QUAN_LY', 'Không còn Trưởng cơ sở: chặn KHONG_CO_QUAN_LY');
-- Phiếu không Nháp hoặc nợ đầu kỳ: không trả gì.
select pg_temp.sudo($$update app.receipt set status_code = 'DA_GUI' where code = 'PT-P420-3'$$);
select is(app.receipt_expected_approver(pg_temp.rid('PT-P420-3')), '{}'::jsonb, 'Phiếu đã gửi: không trả người duyệt dự kiến');
-- Quyền: người cơ sở khác không xem; hàm không nói gì về phiếu không có quyền.
select pg_temp.claims(pg_temp.uid('sale_khong'), 'aal1');
select pg_temp.sudo($$update app.user_account set branch_id = (select id from app.branch where code = 'CS5') where id = (select id from pg_temp.u where key = 'sale_khong')$$);
select pg_temp.claims(pg_temp.uid('sale_khong'), 'aal1');
select is(pg_temp.err($$select app.receipt_expected_approver(pg_temp.rid('PT-P420-2'))$$), 'HMT_KHONG_CO_QUYEN', 'Người cơ sở khác không xem người duyệt dự kiến của phiếu');

select * from finish();
rollback;
