-- QT-07 (migration 594): Lý do huỷ test bắt buộc nối nhóm con L5C–L5O đang dùng hoặc «Không nối nhóm con»; không sửa nối sau khi tạo. Mỗi luật có ca đúng và ca bị chặn. Dữ liệu giả.
begin;
-- D41 (migration 472): bài này kiểm luật «Admin, Kế toán phải qua hai bước»; luật chỉ áp khi tham số mfa_required_enabled bật (mặc định tắt), nên bật tham số ở đây.
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
-- 647 (A-23-27): bắt hai bước chỉ còn Admin; bài này vẫn kiểm luật aal2 cho Kế toán nên dựng lại cờ trong giao dịch của bài (hoàn tác khi kết thúc).
do $$ begin perform set_config('hmt.migration', 'on', true); update app.role set require_mfa = true where code = 'ACCOUNTANT'; perform set_config('hmt.migration', '', true); end $$;
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

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@q07n.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@q07n.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' else 'CSKH' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.list_test_cancel_link_options()$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: người không phải Admin không xem được ô chọn nhóm con');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- Ô chọn: đúng L5C–L5O đang dùng, không L5A, L5B, L5P, L5Q.
select ok((select bool_and(o ->> 'code' ~ '^L5[C-O]$') from jsonb_array_elements(app.list_test_cancel_link_options()) o), 'Ô chọn chỉ có nhóm con L5C đến L5O');
select ok(jsonb_array_length(app.list_test_cancel_link_options()) > 0, 'Ô chọn không rỗng');
select ok(not exists (select from jsonb_array_elements(app.list_test_cancel_link_options()) o where o ->> 'code' in ('L5A', 'L5B', 'L5P', 'L5Q')), 'Ô chọn không có L5A, L5B, L5P, L5Q');

reset role;
create function pg_temp.sub(p_code text) returns uuid language sql as $$ select id from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = p_code $$;
grant execute on function pg_temp.sub(text) to public;
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- Luật: bắt buộc chọn nối hoặc «Không nối nhóm con».
select is(pg_temp.err($$select app.catalog_add_item('TEST_CANCEL_REASON', 'LDH_TEST1', 'Lý do giả 1')$$), 'HMT_THIEU_NOI_NHOM_CON', 'Chặn: thêm lý do huỷ test mà chưa chọn nối');
select is(pg_temp.err($$select app.catalog_add_item('TEST_CANCEL_REASON', 'LDH_TEST1', 'Lý do giả 1', null, null, pg_temp.sub('L5C'), true)$$), 'HMT_NOI_NHOM_CON_MAU_THUAN', 'Chặn: chọn cả nhóm con lẫn «Không nối»');
select is(pg_temp.err($$select app.catalog_add_item('TEST_CANCEL_REASON', 'LDH_TEST1', 'Lý do giả 1', null, null, pg_temp.sub('L5A'))$$), 'HMT_NOI_NHOM_CON_SAI', 'Chặn: nối L5A (ngoài L5C–L5O)');
select is(pg_temp.err($$select app.catalog_add_item('TEST_CANCEL_REASON', 'LDH_TEST1', 'Lý do giả 1', null, null, pg_temp.sub('L5B'))$$), 'HMT_NOI_NHOM_CON_SAI', 'Chặn: nối L5B');
select is(pg_temp.err($$select app.catalog_add_item('TEST_CANCEL_REASON', 'LDH_TEST1', 'Lý do giả 1', null, null, pg_temp.sub('L5P'))$$), 'HMT_NOI_NHOM_CON_SAI', 'Chặn: nối L5P (đã Ngừng)');
select is(pg_temp.err($$select app.catalog_add_item('TEST_CANCEL_REASON', 'LDH_TEST1', 'Lý do giả 1', null, null, pg_temp.sub('L6A'))$$), 'HMT_NOI_NHOM_CON_SAI', 'Chặn: nối nhóm con của giai đoạn khác (L6A)');
select is(pg_temp.err($$select app.catalog_add_item('TEST_CANCEL_REASON', 'LDH_TEST1', 'Lý do giả 1', null, null, (select id from app.catalog_item where catalog_code = 'LEAD_SUBSTAGE' limit 1))$$), 'HMT_MUC_NOI_SAI', 'Chặn: nối mục của danh mục khác (luật cũ giữ nguyên)');

select ok(app.catalog_add_item('TEST_CANCEL_REASON', 'LDH_TEST2', 'Lý do giả 2', null, null, pg_temp.sub('L5C')) is not null, 'Đúng: nối L5C');
select ok(app.catalog_add_item('TEST_CANCEL_REASON', 'LDH_TEST3', 'Lý do giả 3', null, null, null, true) is not null, 'Đúng: «Không nối nhóm con» tường minh');
select is((select linked_item_id from app.catalog_item where code = 'LDH_TEST3' and catalog_code = 'TEST_CANCEL_REASON'), null, 'Mục «Không nối» không có linked_item_id');
select is((select linked_item_id from app.catalog_item where code = 'LDH_TEST2' and catalog_code = 'TEST_CANCEL_REASON'), pg_temp.sub('L5C'), 'Mục nối lưu đúng nhóm con');

-- Nhóm con đã Ngừng thì không nối được.
reset role;
select set_config('hmt.migration', 'on', true);
update app.catalog_item set is_active = false where catalog_code = 'OPP_SUBSTAGE' and code = 'L5D';
select set_config('hmt.migration', '', true);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.catalog_add_item('TEST_CANCEL_REASON', 'LDH_TEST4', 'Lý do giả 4', null, null, pg_temp.sub('L5D'))$$), 'HMT_NOI_NHOM_CON_SAI', 'Chặn: nối nhóm con đã Ngừng');
select ok(not exists (select from jsonb_array_elements(app.list_test_cancel_link_options()) o where o ->> 'code' = 'L5D'), 'Nhóm con đã Ngừng không hiện ở ô chọn');

-- Cột «Nối nhóm con» trong cây danh mục.
select is((select i ->> 'linked_code' from jsonb_array_elements(app.get_catalog_tree('TEST_CANCEL_REASON') -> 'items') i where i ->> 'code' = 'LDH_TEST2'), 'L5C', 'Cây danh mục trả nhóm con đã nối');
select is((select i ->> 'linked_code' from jsonb_array_elements(app.get_catalog_tree('TEST_CANCEL_REASON') -> 'items') i where i ->> 'code' = 'LDH_TEST3'), null, 'Mục «Không nối» không có nhóm con trong cây');

-- Luật: không sửa mục nối sau khi tạo (kể cả khi gọi thẳng bảng); đổi tên vẫn được.
reset role;
select is(pg_temp.err($$update app.catalog_item set linked_item_id = pg_temp.sub('L5E') where catalog_code = 'TEST_CANCEL_REASON' and code = 'LDH_TEST2'$$), 'HMT_NOI_NHOM_CON_KHONG_SUA', 'Chặn: đổi nhóm con đã nối');
select is(pg_temp.err($$update app.catalog_item set linked_item_id = null where catalog_code = 'TEST_CANCEL_REASON' and code = 'LDH_TEST2'$$), 'HMT_NOI_NHOM_CON_KHONG_SUA', 'Chặn: bỏ nối');
select is(pg_temp.err($$update app.catalog_item set name = 'Đổi tên giả' where catalog_code = 'TEST_CANCEL_REASON' and code = 'LDH_TEST2'$$), null, 'Đúng: đổi tên không bị chặn');

-- Danh mục khác không bị ảnh hưởng.
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select ok(app.catalog_add_item('ACTIVITY_TYPE', 'HOAT_DONG_Q07', 'Hoạt động giả') is not null, 'Danh mục khác: thêm mục không cần nối');

select * from finish();
rollback;
