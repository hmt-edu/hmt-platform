-- CH-08 (migration 560): app.list_campaigns, create_campaign, set_campaign_active. Luật R-CRM-11 (anh Trường chốt 19/11): mọi vai trò vào được cổng CRM tạo được chiến dịch;
-- giáo viên không vào cổng CRM nên bị chặn; Ngừng/Dùng lại chỉ Admin hoặc người tạo; tên bắt buộc và không trùng; ngày kết thúc không trước ngày bắt đầu. Dữ liệu giả.
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

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sale1'), ('cskh1'), ('acc'), ('gv1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p560.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p560.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'sale1' then 'SALES' when 'cskh1' then 'CSKH' when 'acc' then 'ACCOUNTANT' else 'TEACHER' end from u;
grant execute on all functions in schema pg_temp to public;

-- ---- Người tuyển sinh tạo chiến dịch ----
select pg_temp.claims(pg_temp.uid('sale1'), 'aal1');
set local role authenticated;
create temp table c1 as select (app.create_campaign('Khai giảng tháng 12', date '2026-12-01', date '2026-12-31') ->> 'id')::uuid as id;
grant select on c1 to public;
select ok((select id from c1) is not null, 'CH-08: nhân viên tuyển sinh tạo được chiến dịch (mọi vai trò cổng CRM)');
select is(pg_temp.err($$select app.create_campaign('  ')$$), 'HMT_CHIEN_DICH_TEN', 'CH-08: tên trống bị chặn');
select is(pg_temp.err($$select app.create_campaign('KHAI GIẢNG THÁNG 12')$$), 'HMT_CHIEN_DICH_TRUNG', 'CH-08: tên trùng (không phân biệt hoa thường) bị chặn');
select is(pg_temp.err($$select app.create_campaign('Sai ngày', date '2026-12-31', date '2026-12-01')$$), 'HMT_CHIEN_DICH_NGAY_SAI', 'CH-08: ngày kết thúc trước ngày bắt đầu bị chặn');
select is((app.create_campaign('Không có ngày') ->> 'id') is not null, true, 'CH-08: ngày bắt đầu, kết thúc đều tuỳ chọn');
reset role;

-- ---- Vai trò khác cũng tạo được; giáo viên bị chặn ----
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((app.create_campaign('Chiến dịch CSKH') ->> 'id') is not null, true, 'CH-08: CSKH tạo được chiến dịch');
reset role;
select pg_temp.claims(pg_temp.uid('acc'), 'aal2');
set local role authenticated;
select is((app.create_campaign('Chiến dịch Kế toán') ->> 'id') is not null, true, 'CH-08: Kế toán tạo được chiến dịch');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.create_campaign('Giáo viên tạo')$$), 'HMT_KHONG_CO_QUYEN', 'CH-08: giáo viên (không vào cổng CRM) không tạo được');
select is(pg_temp.err($$select app.list_campaigns()$$), 'HMT_KHONG_CO_QUYEN', 'CH-08: giáo viên không xem được danh sách chiến dịch');
reset role;

-- ---- Danh sách ----
select pg_temp.sudo($$insert into app.lead (code, parent_name, parent_phone, branch_id, owner_id, source_type_code, source_code, campaign_id)
  select 'LD560001', 'Phụ huynh giả 560', '0900560001', b.id, pg_temp.uid('sale1'), 'MARKETING', 'WEBSITE', (select id from c1) from app.branch b where b.code = 'CS1'$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((app.list_campaigns() ->> 'total')::int, 4, 'CH-08: danh sách thấy cả chiến dịch người khác tạo (dùng chung)');
select is((select (x ->> 'lead_count')::int from jsonb_array_elements(app.list_campaigns('{"q": "khai giảng"}') -> 'rows') x limit 1), 1, 'CH-08: số lead gắn vào chiến dịch');
select is((app.list_campaigns('{"q": "khai giảng"}') ->> 'total')::int, 1, 'CH-08: lọc theo tên');
select is(jsonb_array_length(app.list_campaigns('{}', 2, 0) -> 'rows'), 2, 'CH-08: phân trang theo số dòng');
select is(pg_temp.err($$select app.list_campaigns('{"status": "X"}')$$), 'HMT_LOC_KHONG_HOP_LE', 'CH-08: tình trạng lọc lạ bị từ chối');
-- CSKH không phải người tạo chiến dịch của sale1, cũng không phải Admin.
select is(pg_temp.err(format($$select app.set_campaign_active(%L, false)$$, (select id from c1))), 'HMT_KHONG_CO_QUYEN', 'CH-08: người không phải người tạo, không phải Admin không ngừng được');
select is((select (x ->> 'can_toggle')::boolean from jsonb_array_elements(app.list_campaigns('{"q": "khai giảng"}') -> 'rows') x limit 1), false, 'CH-08: dòng báo can_toggle = false cho người không có quyền ngừng');
reset role;

-- ---- Ngừng, Dùng lại ----
select pg_temp.claims(pg_temp.uid('sale1'), 'aal1');
set local role authenticated;
select lives_ok(format($$select app.set_campaign_active(%L, false)$$, (select id from c1)), 'CH-08: người tạo ngừng được chiến dịch');
select is((app.list_campaigns('{"status": "NGUNG"}') ->> 'total')::int, 1, 'CH-08: lọc Ngừng thấy chiến dịch vừa ngừng');
select is((app.list_campaigns('{"status": "DANG_DUNG"}') ->> 'total')::int, 3, 'CH-08: lọc Đang dùng không còn chiến dịch đã ngừng');
reset role;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select lives_ok(format($$select app.set_campaign_active(%L, true)$$, (select id from c1)), 'CH-08: Admin dùng lại được chiến dịch của người khác');
select is((app.list_campaigns('{"status": "NGUNG"}') ->> 'total')::int, 0, 'CH-08: sau khi dùng lại không còn chiến dịch Ngừng');
select is(pg_temp.err($$select app.set_campaign_active(gen_random_uuid(), false)$$), 'HMT_KHONG_TIM_THAY', 'CH-08: chiến dịch không có thì báo không tìm thấy');
reset role;
select * from finish();
rollback;
