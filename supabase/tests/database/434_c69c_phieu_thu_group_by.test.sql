-- C69 (migration 434): Group By ở máy chủ cho danh sách Phiếu thu (receipt_group_counts) và bộ lọc payment_method của list_receipts: đếm theo tình trạng, cơ sở, hai cấp, bộ lọc; chặn trường lạ, trùng cấp, không quyền. Dữ liệu giả.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('gv5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@c69.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@c69.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code) select id, case when key = 'admin' then 'ADMIN' else 'TEACHER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

-- Phiếu thu giả (bỏ kiểm khoá ngoại bằng replica để khỏi dựng đơn): hai Nháp tiền mặt, một Đã gửi chuyển khoản, cơ sở CS5; một Nháp tiền mặt cơ sở CS1.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHC69C', 'Phụ huynh giả C69C', '0900069003', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$set local session_replication_role = 'replica'$$);
select pg_temp.sudo($$insert into app.receipt (code, order_id, parent_id, branch_id, collect_branch_id, status_code, amount, payment_method_code, search_text)
  select v.c, gen_random_uuid(), (select id from app.parent where code = 'PHC69C'), (select id from app.branch where code = v.b), (select id from app.branch where code = v.b), v.s, 500000, v.m, app.fold_text(v.c)
    from (values ('PTC69-1', 'CS5', 'NHAP', 'TIEN_MAT'), ('PTC69-2', 'CS5', 'NHAP', 'TIEN_MAT'), ('PTC69-3', 'CS5', 'DA_GUI', 'CHUYEN_KHOAN'), ('PTC69-4', 'CS1', 'NHAP', 'TIEN_MAT')) v (c, b, s, m)$$);
select pg_temp.sudo($$set local session_replication_role = 'origin'$$);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.receipt_group_counts('{"q": "PTC69"}'::jsonb, array['status']) ->> 'total')::int, 4, 'Group By tình trạng: tổng 4 phiếu thu giả');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.receipt_group_counts('{"q": "PTC69"}'::jsonb, array['method']) -> 'groups') g where g ->> 'k1' = 'TIEN_MAT'), 3, 'Nhóm Tiền mặt có 3 phiếu');
select is((select g ->> 'l1' from jsonb_array_elements(app.receipt_group_counts('{"q": "PTC69"}'::jsonb, array['status']) -> 'groups') g where g ->> 'k1' = 'DA_GUI'), (select name from app.catalog_item where catalog_code = 'RECEIPT_STATUS' and code = 'DA_GUI'), 'Nhãn nhóm lấy từ danh mục tình trạng phiếu thu');
select is(jsonb_array_length(app.receipt_group_counts('{"q": "PTC69"}'::jsonb, array['status', 'branch']) -> 'groups'), 3, 'Hai cấp tình trạng, cơ sở: ba nhóm lá');
select is((app.receipt_group_counts('{"q": "PTC69", "payment_method": ["CHUYEN_KHOAN"]}'::jsonb, array['status']) ->> 'total')::int, 1, 'Bộ lọc hình thức áp dụng cho số đếm');
select is((app.list_receipts('{"q": "PTC69", "payment_method": ["TIEN_MAT"]}'::jsonb) ->> 'total')::int, 3, 'list_receipts lọc được theo hình thức (mở nhóm Hình thức)');
select is(pg_temp.err($$select app.receipt_group_counts('{}'::jsonb, array['creator'])$$), 'HMT_NHOM_SAI', 'Chặn: trường nhóm không cho phép');
select is(pg_temp.err($$select app.receipt_group_counts('{}'::jsonb, array['status', 'status'])$$), 'HMT_NHOM_SAI', 'Chặn: hai cấp giống nhau');
select is(pg_temp.err($$select app.receipt_group_counts('{}'::jsonb, array['status', 'branch', 'method'])$$), 'HMT_NHOM_SAI', 'Chặn: quá hai cấp');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$select app.receipt_group_counts('{}'::jsonb, array['status'])$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không có quyền xem phiếu thu');

select * from finish();
rollback;
