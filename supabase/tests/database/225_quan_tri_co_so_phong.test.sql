-- QT-08 (migration 225): sửa tên hiển thị, địa chỉ cơ sở; thêm, sửa, ngừng, dùng lại phòng học; quyền Admin; các luật chặn. Dữ liệu giả.
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

create function pg_temp.bid(p_code text) returns uuid language sql as $$ select id from app.branch where code = p_code $$;
grant execute on function pg_temp.bid(text) to public;

-- ================= Quyền =================
select is(pg_temp.err($$select app.update_branch_info(pg_temp.bid('CS5'), 'Tên mới', 'Địa chỉ')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH không sửa được cơ sở');
select is(pg_temp.err($$select app.save_room(jsonb_build_object('branch_id', pg_temp.bid('CS5'), 'code', 'PT01', 'name', 'Phòng thử', 'capacity', 10))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH không thêm được phòng');
reset role;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;

-- ================= Cơ sở =================
create temp table old_branch as select name, address from app.branch where code = 'CS5';
grant select on old_branch to public;
select app.update_branch_info(pg_temp.bid('CS5'), '  CS5 Tên thử  ', '  Địa chỉ mẫu thử  ');
select is((select name || '|' || address from app.branch where code = 'CS5'), 'CS5 Tên thử|Địa chỉ mẫu thử', 'Sửa cơ sở: lưu tên và địa chỉ đã cắt khoảng trắng');
select app.update_branch_info(pg_temp.bid('CS5'), 'CS5 Tên thử', '');
select is((select address from app.branch where code = 'CS5'), null, 'Sửa cơ sở: địa chỉ trống thì xoá địa chỉ');
select is(pg_temp.err($$select app.update_branch_info(pg_temp.bid('CS5'), '   ', 'x')$$), 'HMT_THIEU_THONG_TIN', 'Chặn: tên hiển thị trống');
select is(pg_temp.err($$select app.update_branch_info(pg_temp.bid('CS5'), 'Tên', repeat('a', 201))$$), 'HMT_DIA_CHI_QUA_DAI', 'Chặn: địa chỉ quá 200 ký tự');
select is(pg_temp.err($$select app.update_branch_info(gen_random_uuid(), 'Tên', 'x')$$), 'HMT_KHONG_TIM_THAY', 'Chặn: cơ sở không có');
select is((select code || '|' || is_active from app.branch where code = 'CS5'), 'CS5|true', 'Mã và trạng thái dùng của cơ sở không đổi');

-- ================= Thêm phòng =================
create temp table r1 (j jsonb);
grant all on r1 to public;
insert into r1 select app.save_room(jsonb_build_object('branch_id', pg_temp.bid('CS5'), 'code', 'PT01', 'name', ' Phòng thử 01 ', 'capacity', 24));
select is((select (j ->> 'created')::boolean from r1), true, 'Thêm phòng mới');
select is((select name || '|' || capacity || '|' || is_active from app.room where code = 'PT01' and branch_id = pg_temp.bid('CS5')), 'Phòng thử 01|24|true', 'Phòng mới: tên cắt khoảng trắng, sức chứa, đang dùng');
select is(pg_temp.err($$select app.save_room(jsonb_build_object('branch_id', pg_temp.bid('CS5'), 'code', 'pt01', 'name', 'Khác', 'capacity', 10))$$), 'HMT_PHONG_MA_SAI', 'Chặn: mã phòng viết thường');
select is(pg_temp.err($$select app.save_room(jsonb_build_object('branch_id', pg_temp.bid('CS5'), 'code', 'PT 02', 'name', 'Khác', 'capacity', 10))$$), 'HMT_PHONG_MA_SAI', 'Chặn: mã phòng có khoảng trắng');
select is(pg_temp.err($$select app.save_room(jsonb_build_object('branch_id', pg_temp.bid('CS5'), 'code', 'PT01', 'name', 'Tên khác', 'capacity', 10))$$), 'HMT_PHONG_MA_TRUNG', 'Chặn: mã phòng trùng trong cơ sở');
select is(pg_temp.err($$select app.save_room(jsonb_build_object('branch_id', pg_temp.bid('CS5'), 'code', 'PT02', 'name', 'PHONG THU 01', 'capacity', 10))$$), 'HMT_PHONG_TEN_TRUNG', 'Chặn: tên phòng trùng trong cơ sở (không phân biệt hoa thường, dấu)');
select is(pg_temp.err($$select app.save_room(jsonb_build_object('branch_id', pg_temp.bid('CS5'), 'code', 'PT03', 'name', 'Phòng thử 03', 'capacity', 0))$$), 'HMT_PHONG_SUC_CHUA_SAI', 'Chặn: sức chứa bằng 0');
select is(pg_temp.err($$select app.save_room(jsonb_build_object('branch_id', pg_temp.bid('CS5'), 'code', 'PT03', 'name', 'Phòng thử 03'))$$), 'HMT_PHONG_SUC_CHUA_SAI', 'Chặn: bỏ trống sức chứa');
select is(pg_temp.err($$select app.save_room(jsonb_build_object('branch_id', pg_temp.bid('CS5'), 'code', 'PT03', 'name', '', 'capacity', 5))$$), 'HMT_THIEU_THONG_TIN', 'Chặn: tên phòng trống');
select is(pg_temp.err($$select app.save_room(jsonb_build_object('branch_id', gen_random_uuid(), 'code', 'PT03', 'name', 'Phòng thử 03', 'capacity', 5))$$), 'HMT_KHONG_TIM_THAY', 'Chặn: cơ sở không có');
select ok(exists (select from app.room where code = 'PT01' and branch_id = pg_temp.bid('CS1')) = false, 'Cùng mã ở cơ sở khác là việc khác: không thấy PT01 ở CS1');
select is((select (app.save_room(jsonb_build_object('branch_id', pg_temp.bid('CS1'), 'code', 'PT01', 'name', 'Phòng thử 01', 'capacity', 8)) ->> 'created')::boolean), true, 'Cùng mã và tên ở cơ sở khác được phép');

-- ================= Sửa phòng =================
select is((app.save_room(jsonb_build_object('id', (select (j ->> 'id') from r1), 'name', 'Phòng thử đổi tên', 'capacity', 30)) ->> 'created')::boolean, false, 'Sửa phòng không tạo mới');
select is((select name || '|' || capacity from app.room where id = (select (j ->> 'id')::uuid from r1)), 'Phòng thử đổi tên|30', 'Sửa phòng: tên và sức chứa');
select is((select code from app.room where id = (select (j ->> 'id')::uuid from r1)), 'PT01', 'Sửa phòng: mã không đổi');
select is(pg_temp.err($$select app.save_room(jsonb_build_object('id', (select j ->> 'id' from r1), 'name', 'Phòng thử đổi tên', 'capacity', -3))$$), 'HMT_PHONG_SUC_CHUA_SAI', 'Chặn: sửa sức chứa âm');

-- ================= Ngừng, dùng lại =================
select app.set_room_active((select (j ->> 'id')::uuid from r1), false);
select is((select is_active from app.room where id = (select (j ->> 'id')::uuid from r1)), false, 'Ngừng phòng');
select is((select count(*)::int from app.room where id = (select (j ->> 'id')::uuid from r1)), 1, 'Không xoá: phòng đã ngừng vẫn còn bản ghi');
select app.set_room_active((select (j ->> 'id')::uuid from r1), true);
select is((select is_active from app.room where id = (select (j ->> 'id')::uuid from r1)), true, 'Dùng lại phòng');
select is(pg_temp.err($$select app.set_room_active(gen_random_uuid(), false)$$), 'HMT_KHONG_TIM_THAY', 'Chặn: phòng không có');
select is(pg_temp.err($$select app.set_room_active((select (j ->> 'id')::uuid from r1), null)$$), 'HMT_THIEU_THONG_TIN', 'Chặn: thiếu lựa chọn ngừng hoặc dùng lại');

-- ================= Ghi trực tiếp vẫn bị chặn =================
select is(pg_temp.err($$update app.room set name = 'Ghi thẳng' where code = 'PT01'$$) is not null, true, 'Không ghi thẳng vào bảng phòng (chỉ qua hàm)');
select is(pg_temp.err($$update app.branch set name = 'Ghi thẳng' where code = 'CS5'$$) is not null, true, 'Không ghi thẳng vào bảng cơ sở (chỉ qua hàm)');

select * from finish();
rollback;
