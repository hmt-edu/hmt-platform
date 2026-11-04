-- T2 (migration 065; Đ286; spec 04 mục 14: R-V2-04, R-V2-31): số điện thoại thứ hai, cột mới phụ huynh và học sinh, khớp phụ huynh theo cả hai số.
-- Mỗi luật có ca đúng và ca bị chặn. Dữ liệu giả.
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
create function pg_temp.claims(p_user uuid) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal1')));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('sales1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@t2.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select id, 'Giả ' || key, key || '@t2.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code) select id, 'SALES' from u;

-- ================= Cột mới =================
select is((select count(*)::int from information_schema.columns where table_schema = 'app' and table_name = 'parent' and column_name in ('phone_2', 'relative_name')),
          2, 'Phụ huynh có SĐT thứ hai và họ tên người thân');
select is((select count(*)::int from information_schema.columns where table_schema = 'app' and table_name = 'student' and column_name in ('gender', 'school_type', 'grade')),
          3, 'Học sinh có giới tính, loại trường, khối');
select is((select count(*)::int from information_schema.columns where table_schema = 'app' and table_name = 'lead' and column_name = 'parent_phone_2'),
          1, 'Lead có SĐT thứ hai của phụ huynh');

-- Luật R-V2-04: số thứ hai đúng 10 số bắt đầu bằng 0.
select is(pg_temp.err($$insert into app.parent (code, full_name, phone, phone_2, branch_id)
  select 'PH910001', 'Phụ huynh số hai sai', '0900000601', '12345', id from app.branch where code = 'CS1'$$), '23514', 'SĐT thứ hai sai độ dài bị chặn');
select is(pg_temp.err($$insert into app.parent (code, full_name, phone, phone_2, branch_id)
  select 'PH910002', 'Phụ huynh số hai đúng', '0900000602', '0900000612', id from app.branch where code = 'CS1'$$), null, 'SĐT thứ hai đúng 10 số được lưu');
-- Luật R-V2-31: giới tính NAM hoặc NU, khối 1 đến 12.
select is(pg_temp.err($$insert into app.student (code, parent_id, full_name, birth_year, gender, branch_id)
  select 'HS910001', (select id from app.parent where code = 'PH910002'), 'Em giới tính sai', 2014, 'KHAC', id from app.branch where code = 'CS1'$$), '23514', 'Giới tính ngoài NAM, NU bị chặn');
select is(pg_temp.err($$insert into app.student (code, parent_id, full_name, birth_year, grade, branch_id)
  select 'HS910002', (select id from app.parent where code = 'PH910002'), 'Em khối sai', 2014, 13, id from app.branch where code = 'CS1'$$), '23514', 'Khối 13 bị chặn');
select is(pg_temp.err($$insert into app.student (code, parent_id, full_name, birth_year, gender, grade, school_type, branch_id)
  select 'HS910003', (select id from app.parent where code = 'PH910002'), 'Em đủ cột', 2014, 'NU', 8, 'Công lập', id from app.branch where code = 'CS1'$$), null, 'Học sinh đủ giới tính, khối, loại trường được lưu');

-- ================= Khớp phụ huynh theo cả hai số (R-V2-04, R-CRM-27) =================
select is(app.find_or_create_parent('0900000602', 'Tên khác', null, null, null, (select id from app.branch where code = 'CS5')),
          (select id from app.parent where code = 'PH910002'), 'Khớp theo số chính');
select is(app.find_or_create_parent('0900000612', 'Tên khác', null, null, null, (select id from app.branch where code = 'CS5')),
          (select id from app.parent where code = 'PH910002'), 'Khớp theo số thứ hai của hồ sơ có sẵn');
select is(app.find_or_create_parent('0900000699', 'Tên khác', null, null, null, (select id from app.branch where code = 'CS5'), '0900000612'),
          (select id from app.parent where code = 'PH910002'), 'Số mới nhưng số thứ hai của người gọi trùng số thứ hai của hồ sơ: khớp hồ sơ đó');
select is((select full_name from app.parent where code = 'PH910002'), 'Phụ huynh số hai đúng', 'Khớp thì không ghi đè tên');
-- Điền chỗ trống: hồ sơ chưa có số thứ hai thì nhận số thứ hai mới.
select pg_temp.err($$insert into app.parent (code, full_name, phone, branch_id)
  select 'PH910003', 'Phụ huynh chưa có số hai', '0900000603', id from app.branch where code = 'CS1'$$);
select app.find_or_create_parent('0900000603', 'Tên khác', null, null, null, (select id from app.branch where code = 'CS5'), '0900000613');
select is((select phone_2 from app.parent where code = 'PH910003'), '0900000613', 'Hồ sơ chưa có số thứ hai được điền số thứ hai mới');
select is(app.find_or_create_parent('0900000613', 'Tên khác', null, null, null, (select id from app.branch where code = 'CS5')),
          (select id from app.parent where code = 'PH910003'), 'Số thứ hai vừa điền dùng để khớp lần sau');
-- Không khớp thì tạo mới, ghi cả hai số, cơ sở là cơ sở của cơ hội.
select is((select count(*)::int from app.parent where phone = '0900000620'), 0, 'Chưa có hồ sơ số 0900000620');
select app.find_or_create_parent('0900000620', 'Phụ huynh mới', null, null, null, (select id from app.branch where code = 'CS5'), '0900000621');
select is((select phone_2 || '/' || (select code from app.branch b where b.id = p.branch_id) from app.parent p where phone = '0900000620'), '0900000621/CS5', 'Tạo mới ghi cả số thứ hai và cơ sở tiếp nhận');
select is(pg_temp.err($$select app.find_or_create_parent('0900000630', 'Số hai sai', null, null, null, (select id from app.branch where code = 'CS5'), '123')$$),
          'HMT_SDT_SAI', 'SĐT thứ hai nhập sai bị chặn');
select is(pg_temp.err($$select app.find_or_create_parent('12345', 'Số chính sai', null, null, null, (select id from app.branch where code = 'CS5'))$$),
          'HMT_SDT_SAI', 'SĐT chính sai vẫn bị chặn như trước');

-- ================= Kiểm trùng khi tạo lead (chỉ cảnh báo) =================
select pg_temp.claims((select id from u where key = 'sales1'));
set local role authenticated;
select is((select count(*)::int from app.find_duplicate_contacts('0900000612') where kind = 'PARENT'), 1, 'Kiểm trùng báo phụ huynh có số này là số thứ hai');
select is((select count(*)::int from app.find_duplicate_contacts('0900000602') where kind = 'PARENT'), 1, 'Kiểm trùng báo phụ huynh có số này là số chính');
select is((select count(*)::int from app.find_duplicate_contacts('0900000777') where kind = 'PARENT'), 0, 'Số chưa có ở đâu: không báo trùng');
reset role;

-- ================= Tìm kiếm theo số thứ hai =================
select is((select count(*)::int from app.parent where search_text like '%0900000612%'), 1, 'Ô tìm kiếm phụ huynh tìm được theo số thứ hai');

select * from finish();
rollback;
