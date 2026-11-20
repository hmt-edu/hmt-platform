-- C89 (migration 580): list_receipts trả `bank_matched` và lọc «Sao kê» (KHOP, CHUA) cho cột TC-04; người không có quyền xem phiếu thu bị chặn. Dựng theo mẫu test 434.
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
insert into u (key) values ('admin'), ('gv5'), ('bm1');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@c89.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@c89.hoamatoan.invalid', (select id from app.branch where code = case when u.key = 'bm1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code) select id, case when key = 'admin' then 'ADMIN' when key = 'bm1' then 'BRANCH_MANAGER' else 'TEACHER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

-- Phiếu thu giả (bỏ kiểm khoá ngoại bằng replica để khỏi dựng đơn): hai Nháp tiền mặt, một Đã gửi chuyển khoản, cơ sở CS5; một Nháp tiền mặt cơ sở CS1.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHC89', 'Phụ huynh giả C69C', '0900089003', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$set local session_replication_role = 'replica'$$);
select pg_temp.sudo($$insert into app.receipt (code, order_id, parent_id, branch_id, collect_branch_id, status_code, amount, payment_method_code, search_text)
  select v.c, gen_random_uuid(), (select id from app.parent where code = 'PHC89'), (select id from app.branch where code = v.b), (select id from app.branch where code = v.b), v.s, 500000, v.m, app.fold_text(v.c)
    from (values ('PTC89-1', 'CS5', 'NHAP', 'TIEN_MAT'), ('PTC89-2', 'CS5', 'NHAP', 'TIEN_MAT'), ('PTC89-3', 'CS5', 'DA_GUI', 'CHUYEN_KHOAN'), ('PTC89-4', 'CS1', 'NHAP', 'TIEN_MAT')) v (c, b, s, m)$$);
-- PTC89-1 đã được Kế toán đánh dấu khớp sao kê (TC-15); ba phiếu còn lại chưa. (cập nhật khi còn replica: dòng vừa thêm cùng giao dịch bị kiểm lại khoá ngoại)
select pg_temp.sudo($$update app.receipt set bank_matched_at = now(), bank_matched_by = gen_random_uuid() where code = 'PTC89-1'$$);
select pg_temp.sudo($$set local session_replication_role = 'origin'$$);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
-- Admin (toàn hệ thống): mảng branch_ids thu hẹp đúng cơ sở chọn.
select is((app.list_receipts(jsonb_build_object('q', 'PTC89', 'branch_ids', jsonb_build_array((select id from app.branch where code = 'CS5')))) ->> 'total')::int, 3, 'Chip một cơ sở CS5: 3 phiếu');
select is((app.list_receipts(jsonb_build_object('q', 'PTC89', 'branch_ids', jsonb_build_array((select id from app.branch where code = 'CS1')))) ->> 'total')::int, 1, 'Chip một cơ sở CS1: 1 phiếu');
select is((app.list_receipts(jsonb_build_object('q', 'PTC89', 'branch_ids', jsonb_build_array((select id from app.branch where code = 'CS1'), (select id from app.branch where code = 'CS5')))) ->> 'total')::int, 4, 'Chip hai cơ sở CS1, CS5: đủ 4 phiếu (HOẶC giữa các cơ sở)');
select is((app.list_receipts('{"q": "PTC89", "branch_ids": []}'::jsonb) ->> 'total')::int, 4, 'Mảng rỗng thì không lọc');
select is((app.receipt_group_counts(jsonb_build_object('q', 'PTC89', 'branch_ids', jsonb_build_array((select id from app.branch where code = 'CS5'))), array['status']) ->> 'total')::int,
          (app.list_receipts(jsonb_build_object('q', 'PTC89', 'branch_ids', jsonb_build_array((select id from app.branch where code = 'CS5')))) ->> 'total')::int, 'Số đếm nhóm bằng tổng danh sách với cùng chip Cơ sở');
select is((app.list_receipts(jsonb_build_object('q', 'PTC89', 'branch_id', (select id from app.branch where code = 'CS5'))) ->> 'total')::int, 3, 'Tương thích: bộ lọc branch_id cũ vẫn chạy');
-- Trưởng cơ sở CS1 (phạm vi cơ sở): mảng KHÔNG nới phạm vi.
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is((app.list_receipts(jsonb_build_object('q', 'PTC89', 'branch_ids', jsonb_build_array((select id from app.branch where code = 'CS5')))) ->> 'total')::int, 0, 'Phạm vi: Trưởng cơ sở CS1 đưa mảng CS5 vẫn không thấy phiếu CS5');
select is((app.list_receipts(jsonb_build_object('q', 'PTC89', 'branch_ids', jsonb_build_array((select id from app.branch where code = 'CS1'), (select id from app.branch where code = 'CS5')))) ->> 'total')::int, 1, 'Phạm vi: mảng CS1, CS5 chỉ trả phần của CS1');
select is((app.receipt_group_counts(jsonb_build_object('q', 'PTC89', 'branch_ids', jsonb_build_array((select id from app.branch where code = 'CS5'))), array['status']) ->> 'total')::int, 0, 'Phạm vi: số đếm nhóm cũng không nới');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$select app.list_receipts('{"branch_ids": []}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không có quyền xem phiếu thu');

select * from finish();
rollback;
