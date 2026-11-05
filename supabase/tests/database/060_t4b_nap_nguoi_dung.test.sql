-- T4b (migration 069; spec 04 R-V2-29, 30, 34): nạp Người dùng, phần DB (kiểm dòng, tạo tài khoản, gắn quản lý, khoá, nhật ký).
-- Mỗi luật có ca đúng và ca bị chặn. Dữ liệu giả. Edge Function `import-users` gọi các hàm này bằng token của Admin.
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
create function pg_temp.st(p_res jsonb, p_row integer) returns text language sql as
  $$ select r ->> 'status' from jsonb_array_elements(p_res -> 'rows') r where (r ->> 'row')::integer = p_row $$;
create function pg_temp.hs(p_res jsonb, p_row integer, p_key text) returns text language sql as
  $$ select r ->> p_key from jsonb_array_elements(p_res -> 'rows') r where (r ->> 'row')::integer = p_row $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1'), ('moi1'), ('moi2'), ('moi3'), ('daco');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email, encrypted_password) select id, 'authenticated', 'authenticated', key || '@t4b.hoamatoan.invalid', 'băm-giả' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select id, 'Giả ' || key, key || '@t4b.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u where key in ('admin', 'sales1', 'daco');
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('daco', 'SALES')) v(k, role) on v.k = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
-- Tài khoản đã có sẵn từ lần nạp trước (tên đăng nhập daco.cu).
update app.user_account set legacy_ref = 'daco.cu' where id = (select id from u where key = 'daco');
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

-- ================= Quyền: chỉ Admin (đã xác thực hai bước) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.import_users_resolve('[{"username":"a1"}]')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không kiểm/nạp người dùng');
select is(pg_temp.err($$select app.import_user_lock(gen_random_uuid())$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không khoá tài khoản qua hàm nạp');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.import_users_resolve('[{"username":"a1"}]')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Admin chưa xác thực hai bước');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.import_users_resolve('[]')$$), 'HMT_THIEU_THONG_TIN', 'Chặn: không có dòng nào');

-- ================= Kiểm từng dòng (xem trước, không tạo gì) =================
create temp table rows_in (rows jsonb);
insert into rows_in values ('[
 {"row":2,"username":"zed.mot","ho_ten":"Quách Thị Mẫu","ma_nv":"9001","vai_tro":"SALES","co_so_truy_cap":"CS5","trang_thai":"Đang làm","email":"zed.mot@thu.example","quan_ly":"zed.hai"},
 {"row":3,"username":"zed.hai","ho_ten":"Lương Văn Hai","vai_tro":"BRANCH_MANAGER","co_so_truy_cap":"CS5, CS1","trang_thai":"Đang làm"},
 {"row":4,"username":"zed.ba","ho_ten":"Nghiêm Thị Ba","vai_tro":"TEACHER","co_so_truy_cap":"all","trang_thai":"Nghỉ phép","quan_ly":"zed.hai"},
 {"row":5,"username":"Zed Bon","ho_ten":"Dòng tên đăng nhập sai","vai_tro":"SALES","co_so_truy_cap":"CS5"},
 {"row":6,"username":"zed.nam","vai_tro":"SALES","co_so_truy_cap":"CS5"},
 {"row":7,"username":"zed.sau","ho_ten":"Vai Trò Sai","vai_tro":"STUDENT","co_so_truy_cap":"CS5"},
 {"row":8,"username":"zed.bay","ho_ten":"Cơ Sở Sai","vai_tro":"SALES","co_so_truy_cap":"CS9"},
 {"row":9,"username":"zed.tam","ho_ten":"Trạng Thái Sai","vai_tro":"SALES","co_so_truy_cap":"CS5","trang_thai":"Tạm nghỉ"},
 {"row":10,"username":"zed.chin","ho_ten":"Email Sai","vai_tro":"SALES","co_so_truy_cap":"CS5","email":"khong-phai-email"},
 {"row":11,"username":"zed.mot","ho_ten":"Trùng tên đăng nhập trong file","vai_tro":"SALES","co_so_truy_cap":"CS5"},
 {"row":12,"username":"zed.muoi","ho_ten":"Quản lý lạ","vai_tro":"SALES","co_so_truy_cap":"CS5","quan_ly":"khong.co.ai"},
 {"row":13,"username":"zed.muoimot","ho_ten":"Tự quản lý mình","vai_tro":"SALES","co_so_truy_cap":"CS5","quan_ly":"zed.muoimot"},
 {"row":14,"username":"daco.cu","ho_ten":"Đã có tài khoản","vai_tro":"SALES","co_so_truy_cap":"CS1"},
 {"row":15,"username":"zed.muoiba","ho_ten":"Email của người khác","vai_tro":"SALES","co_so_truy_cap":"CS5","email":"daco@t4b.hoamatoan.invalid"},
 {"row":16,"username":"zed.muoibon","ho_ten":"Email Trùng Trong File","vai_tro":"SALES","co_so_truy_cap":"CS5","email":"zed.mot@thu.example"}]');
create temp table res1 (r jsonb);
insert into res1 select app.import_users_resolve(rows) from rows_in;
select is((select array[r ->> 'imported', r ->> 'duplicates', r ->> 'errors'] from res1), array['3', '1', '11'], 'Kiểm: 3 dòng hợp lệ, 1 trùng (đã có tài khoản), 11 lỗi');
select is((select array[pg_temp.st(r, 2), pg_temp.st(r, 3), pg_temp.st(r, 4), pg_temp.st(r, 5), pg_temp.st(r, 6), pg_temp.st(r, 7), pg_temp.st(r, 8),
                        pg_temp.st(r, 9), pg_temp.st(r, 10), pg_temp.st(r, 11), pg_temp.st(r, 12), pg_temp.st(r, 13), pg_temp.st(r, 14),
                        pg_temp.st(r, 15), pg_temp.st(r, 16)] from res1),
          array['HOP_LE', 'HOP_LE', 'HOP_LE', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'TRUNG', 'LOI', 'LOI'],
          'Từng luật: tên đăng nhập, họ tên, vai trò, cơ sở, trạng thái, email, trùng trong file, quản lý, đã có tài khoản');
select is((select count(*)::int from app.user_account where legacy_ref like 'zed.%'), 0, 'Kiểm không tạo tài khoản nào');
select is((select r -> 'rows' -> 0 -> 'resolved' ->> 'branch_code' from res1), 'CS5', 'Cơ sở chính một cơ sở: CS5');
select is((select r -> 'rows' -> 1 -> 'resolved' ->> 'branch_code' from res1), 'CS5', 'Nhiều cơ sở: lấy cơ sở đầu làm cơ sở chính');
select is((select jsonb_array_length(r -> 'rows' -> 1 -> 'warnings') from res1), 1, 'Nhiều cơ sở: có đúng một cảnh báo (không LOI)');
select is((select r -> 'rows' -> 1 -> 'resolved' ->> 'raw_branches' from res1), 'CS5, CS1', 'Nhiều cơ sở: giữ nguyên văn để áp lại sau');
select is((select r -> 'rows' -> 2 -> 'resolved' ->> 'branch_code' from res1), (select code from app.branch where is_active and not is_office order by code limit 1), 'ALL: cơ sở chính là cơ sở đầu không phải văn phòng');
select is((select jsonb_array_length(r -> 'rows' -> 2 -> 'warnings') from res1), 1, 'ALL: có cảnh báo');
select is((select (r -> 'rows' -> 2 -> 'resolved' ->> 'locked')::boolean from res1), true, 'Nghỉ phép: sẽ khoá tài khoản');
select is((select (r -> 'rows' -> 0 -> 'resolved' ->> 'locked')::boolean from res1), false, 'Đang làm: không khoá');
select is((select r -> 'rows' -> 1 -> 'resolved' ->> 'email' from res1), 'zed.hai@tam.invalid', 'Email trống: tên đăng nhập@miền quy ước (miền giả của Cài đặt)');
select is((select r -> 'rows' -> 0 -> 'resolved' ->> 'email' from res1), 'zed.mot@thu.example', 'Email có trong file: dùng email đó');
select is((select r -> 'rows' -> 0 -> 'resolved' ->> 'manager_username' from res1), 'zed.hai', 'Quản lý có trong file được nhận');

-- Tên miền quy ước đổi trong Cài đặt thì email theo miền mới.
update app.setting_def set value = 'thu-nghiem.example' where key = 'import_user_email_domain';
select is((select (app.import_users_resolve('[{"username":"zed.dom","ho_ten":"Miền","vai_tro":"SALES","co_so_truy_cap":"CS5"}]') -> 'rows' -> 0 -> 'resolved' ->> 'email')),
          'zed.dom@thu-nghiem.example', 'Tên miền email quy ước là tham số Cài đặt, không viết cứng');
update app.setting_def set value = 'tam.invalid' where key = 'import_user_email_domain';

-- ================= Quyền riêng tư: kết quả (trừ cột resolved dành cho Edge Function) không chứa họ tên, email, tên đăng nhập =================
select is((select count(*)::int from res1, jsonb_array_elements(r -> 'rows') e
            where (e - 'resolved')::text ~ '(Quách|Lương|Nghiêm|Dòng tên|Vai Trò|Cơ Sở|Trạng Thái|zed\.|daco|@|thu\.example)'), 0,
          'Kết quả kiểm (không kể cột resolved) không chứa họ tên, email, tên đăng nhập');
select is(pg_temp.hs((select r from res1), 5, 'label'), 'Dòng 5 (D.)', 'Dòng báo bằng số dòng và chữ cái đầu của tên');
select is(pg_temp.hs((select r from res1), 6, 'label'), 'Dòng 6 (?.)', 'Dòng không có tên báo dấu hỏi');

-- ================= Tạo tài khoản, gắn quản lý, khoá =================
select is(pg_temp.err(format($$select app.import_user_create(%L, %L)$$, pg_temp.uid('moi1'),
          (select (r -> 'rows' -> 1 -> 'resolved')::text from res1))), null, 'Tạo tài khoản Trưởng cơ sở (dòng 3)');
select is(pg_temp.err(format($$select app.import_user_create(%L, %L)$$, pg_temp.uid('moi2'),
          (select (r -> 'rows' -> 0 -> 'resolved')::text from res1))), null, 'Tạo tài khoản Tuyển sinh (dòng 2)');
select is(pg_temp.err(format($$select app.import_user_create(%L, %L)$$, pg_temp.uid('moi3'),
          (select (r -> 'rows' -> 2 -> 'resolved')::text from res1))), null, 'Tạo tài khoản giáo viên nghỉ phép (dòng 4)');
select is((select array[login_name, legacy_ref, must_change_password::text, (select code from app.branch where id = branch_id)]
             from app.user_account where id = pg_temp.uid('moi2')),
          array['zed.mot@thu.example', 'zed.mot', 'true', 'CS5'], 'Tài khoản nạp: email đăng nhập, tên đăng nhập ở legacy_ref, bắt đổi mật khẩu lần đầu, cơ sở chính');
select ok((select staff_code ~ '^NV[0-9]+$' from app.user_account where id = pg_temp.uid('moi2')), 'Mã nhân viên cấp mới theo chuẩn NV cho Tuyển sinh');
select ok((select staff_code ~ '^GV[0-9]+$' from app.user_account where id = pg_temp.uid('moi3')), 'Mã giáo viên cấp mới theo chuẩn GV cho giáo viên');
select is((select array_agg(role_code) from app.user_role where user_id = pg_temp.uid('moi1') and is_active), array['BRANCH_MANAGER'], 'Vai trò đúng như file');
-- Nạp lại: tên đăng nhập đã có thì kiểm ra TRUNG.
select is((select pg_temp.st(app.import_users_resolve(rows), 3) from rows_in), 'TRUNG', 'Nạp lại: dòng đã nạp thành TRUNG, bỏ qua');
-- Gắn quản lý.
select is(pg_temp.err(format($$select app.import_user_set_manager(%L, 'zed.hai')$$, pg_temp.uid('moi2'))), null, 'Gắn quản lý trực tiếp theo tên đăng nhập');
select is((select manager_id from app.user_account where id = pg_temp.uid('moi2')), pg_temp.uid('moi1'), 'manager_id trỏ đúng quản lý');
select is(pg_temp.err(format($$select app.import_user_set_manager(%L, 'khong.co.ai')$$, pg_temp.uid('moi2'))), 'HMT_QUAN_LY_SAI', 'Quản lý không có trong hệ thống bị chặn');
select is(pg_temp.err(format($$select app.import_user_set_manager(%L, 'zed.mot')$$, pg_temp.uid('moi2'))), 'HMT_QUAN_LY_TU_THAN', 'Tự làm quản lý của mình bị chặn');
-- Khoá người nghỉ, sau khi gắn quản lý.
select is(pg_temp.err(format($$select app.import_user_set_manager(%L, 'zed.hai')$$, pg_temp.uid('moi3'))), null, 'Gắn quản lý cho người nghỉ trước khi khoá');
select is(pg_temp.err(format($$select app.import_user_lock(%L)$$, pg_temp.uid('moi3'))), null, 'Khoá tài khoản người nghỉ');
select is((select array[is_locked::text, lock_reason] from app.user_account where id = pg_temp.uid('moi3')),
          array['true', 'Nạp dữ liệu cũ: người nghỉ phép hoặc đã nghỉ'], 'Tài khoản khoá kèm lý do nạp dữ liệu cũ');

-- ================= Nhật ký nạp =================
select is(pg_temp.err(format($$select app.import_users_finish('nguoi-dung-cs5.xlsx', 15, 3, 1, 11, %L::jsonb)$$,
          (select jsonb_build_array(jsonb_build_object('user_id', pg_temp.uid('moi1'), 'raw_branches', 'CS5, CS1'),
                                    jsonb_build_object('user_id', pg_temp.uid('moi3'), 'raw_branches', 'all'))::text))), null, 'Ghi nhật ký nạp');
select is((select array[kind, rows_total::text, imported_count::text, duplicate_count::text, error_count::text, file_name]
             from app.import_log where kind = 'NGUOI_DUNG'), array['NGUOI_DUNG', '15', '3', '1', '11', 'nguoi-dung-cs5.xlsx'], 'Nhật ký nạp có số liệu');
select is((select array_agg(raw_branches order by raw_branches) from app.import_user_branch_pending), array['all', 'CS5, CS1'], 'Danh sách cơ sở nguyên văn được giữ để áp lại sau');
select is((select count(*)::int from app.import_log l where l::text ~* '(Quách|Lương|zed\.|@|daco)'), 0, 'Nhật ký nạp không chứa họ tên, email, tên đăng nhập');

select * from finish();
rollback;
