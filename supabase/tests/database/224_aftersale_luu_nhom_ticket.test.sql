-- Aftersale lát 6 (migration 224): save_ticket_category: thêm, sửa, ngừng nhóm và nhóm con; quyền Admin; luật bất biến. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('cskh5'), ('cskh1'), ('gv5'), ('gv5b'), ('qlcs5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@as.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@as.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' when key like 'cskh%' then 'CSKH' when key like 'gv%' then 'TEACHER' else 'BRANCH_MANAGER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHAS501', 'Phụ huynh giả ticket', '0900002001', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  values ('HSAS501', (select id from app.parent where code = 'PHAS501'), 'Học sinh giả ticket', 2013, (select id from app.branch where code = 'CS5'))$$);
grant execute on all functions in schema pg_temp to public;

create function pg_temp.mk(p_type text, p_cat text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('ticket_type', p_type, 'branch_id', (select id from app.branch where code = 'CS5'), 'title', 'Tiêu đề giả', 'description', 'Mô tả giả',
    'channel_code', 'GOI_DIEN', 'category_code', p_cat, 'parent_id', (select id from app.parent where code = 'PHAS501')) || p_extra $$;
grant execute on function pg_temp.mk(text, text, jsonb) to public;

select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code in ('CS5', 'CS1')
  on conflict (module_code, branch_id) do update set enabled = true$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
create temp table t1 (j jsonb);
grant all on t1 to public;
insert into t1 select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'));

select is(pg_temp.err($$select app.save_ticket_category('{"code":"X1","name":"X","kind":"GROUP","ticket_type":"DN"}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH không có quyền Quản trị · Sửa nên không đổi được nhóm ticket');
reset role;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;

-- ================= Tạo =================
select is((app.save_ticket_category('{"code":"DN_TEST","name":"Nhóm thử","kind":"GROUP","ticket_type":"DN","sort_order":90}'::jsonb) ->> 'created')::boolean, true, 'Tạo nhóm Đề nghị mới');
select is((select ticket_type || '/' || kind from app.ticket_category where code = 'DN_TEST'), 'DN/GROUP', 'Nhóm mới đúng loại và cấp');
select app.save_ticket_category('{"code":"DN_TEST_01","name":"Nhóm con thử","kind":"SUBGROUP","parent_code":"DN_TEST","default_priority":"CAO","default_team":"CSKH"}'::jsonb);
select is((select ticket_type || '/' || default_priority || '/' || default_team from app.ticket_category where code = 'DN_TEST_01'), 'DN/CAO/CSKH', 'Nhóm con lấy loại của nhóm cha, lưu mức độ và đội mặc định');
select is(pg_temp.err($$select app.save_ticket_category('{"code":"DN_TEST_02","name":"Mồ côi","kind":"SUBGROUP","parent_code":"KHONG_CO"}'::jsonb)$$), 'HMT_NHOM_SAI', 'Chặn: nhóm con phải thuộc nhóm đang dùng');
select is(pg_temp.err($$select app.save_ticket_category('{"code":"DN_TEST_03","name":"Sai đội","kind":"SUBGROUP","parent_code":"DN_TEST","default_team":"KHONG_CO"}'::jsonb)$$) is not null, true, 'Chặn: đội mặc định không có trong danh mục');
select is(pg_temp.err($$select app.save_ticket_category('{"code":"DN_TEST_04","name":"Tính chất sai","kind":"SUBGROUP","parent_code":"DN_TEST","nature_code":"HO_TRO"}'::jsonb)$$), 'HMT_NHOM_SAI', 'Chặn: tính chất chỉ ở ticket giáo viên (AS-05)');
select is(pg_temp.err($$select app.save_ticket_category('{"code":"DN_TEST_05","name":"","kind":"SUBGROUP","parent_code":"DN_TEST"}'::jsonb)$$), 'HMT_THIEU_THONG_TIN', 'Chặn: thiếu tên');
select is(pg_temp.err($$select app.save_ticket_category('{"code":"GV_TEST","name":"Nhóm chưa có loại","kind":"GROUP"}'::jsonb)$$), 'HMT_TICKET_LOAI_SAI', 'Chặn: nhóm cha phải có loại ticket');

-- ================= Sửa =================
select is((app.save_ticket_category('{"code":"DN_TEST_01","name":"Đổi tên","default_priority":"THAP","business_type":"DOI_LICH","requires_student":true}'::jsonb) ->> 'created')::boolean, false, 'Sửa nhóm đã có không tạo mới');
select is((select name || '/' || default_priority || '/' || business_type || '/' || requires_student from app.ticket_category where code = 'DN_TEST_01'), 'Đổi tên/THAP/DOI_LICH/true', 'Sửa: tên, mức độ, phiếu nghiệp vụ, bắt buộc học sinh');
select is((select default_team from app.ticket_category where code = 'DN_TEST_01'), 'CSKH', 'Sửa: ô không gửi thì giữ nguyên (đội mặc định)');
select is(pg_temp.err($$select app.save_ticket_category('{"code":"DN_TEST_01","ticket_type":"KN"}'::jsonb)$$), 'HMT_NHOM_KHONG_DOI', 'Chặn: không đổi loại ticket của nhóm đã tạo');
select is(pg_temp.err($$select app.save_ticket_category('{"code":"DN_TEST_01","parent_code":"DN_01"}'::jsonb)$$), 'HMT_NHOM_KHONG_DOI', 'Chặn: không chuyển nhóm cha');
select is(pg_temp.err($$select app.save_ticket_category('{"code":"DN_TEST","default_priority":"CAO"}'::jsonb)$$), 'HMT_NHOM_SAI', 'Chặn: mức độ chỉ đặt ở nhóm con');

-- ================= Ngừng =================
select app.save_ticket_category('{"code":"DN_TEST","is_active":false}'::jsonb);
select is((select is_active from app.ticket_category where code = 'DN_TEST_01'), false, 'Ngừng nhóm cha thì ngừng luôn nhóm con');
select app.save_ticket_category('{"code":"DN_TEST","is_active":true}'::jsonb);
select is((select is_active from app.ticket_category where code = 'DN_TEST_01'), false, 'Bật lại nhóm cha không tự bật lại nhóm con');
select is((select count(*)::int from app.ticket_category where code = 'DN_TEST'), 1, 'Không xoá: nhóm vẫn còn bản ghi');
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.create_ticket(pg_temp.mk('DN', 'DN_TEST_01'))$$), 'HMT_TICKET_NHOM_SAI', 'Nhóm con đã ngừng thì không tạo ticket mới vào');

select * from finish();
rollback;
