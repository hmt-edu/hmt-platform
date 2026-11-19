-- QT-16 Hồ sơ giáo viên, trợ giảng (migration 313): list_teaching_profiles, list_teaching_candidates, save_teaching_profile, set_teaching_profile_active. Luật R-LOP-08, R-LOP-10. Dữ liệu giả.
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
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('cskh1'), ('gv1'), ('gv2'), ('ta1'), ('sales1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@qt16.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@qt16.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('cskh1', 'CSKH'), ('gv1', 'TEACHER'), ('gv2', 'TEACHER'), ('ta1', 'TA'), ('sales1', 'SALES')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs1() returns uuid language sql stable security definer as $$ select id from app.branch where code = 'CS1' $$;

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select ok((select count(*) from jsonb_array_elements(app.list_teaching_candidates()) x where x ->> 'name' like 'Giả gv1') = 1, 'Ứng viên: giáo viên chưa có hồ sơ có trong danh sách');
select ok(not exists (select from jsonb_array_elements(app.list_teaching_candidates()) x where x ->> 'name' = 'Giả sales1'), 'Ứng viên: người không có vai Giáo viên, Trợ giảng không có trong danh sách');
select is((select x ->> 'kind' from jsonb_array_elements(app.list_teaching_candidates()) x where x ->> 'name' = 'Giả ta1'), 'TG', 'Ứng viên có vai Trợ giảng là loại TG');

-- ================= Thêm hồ sơ (Admin) =================
select is(pg_temp.err($$select app.save_teaching_profile('{}'::jsonb)$$), 'HMT_THIEU_THONG_TIN', 'Chặn: thêm hồ sơ mà không chọn người dùng');
select is(pg_temp.err(format($$select app.save_teaching_profile(jsonb_build_object('user_id', %L))$$, pg_temp.uid('sales1'))), 'HMT_KHONG_PHAI_GIAO_VIEN', 'Chặn (R-LOP-08): người không có vai Giáo viên, Trợ giảng không có hồ sơ dạy');
select is(pg_temp.err(format($$select app.save_teaching_profile(jsonb_build_object('user_id', %L, 'subject_codes', jsonb_build_array('KHONG_CO_MON')))$$, pg_temp.uid('gv1'))), 'HMT_MON_SAI', 'Chặn: môn học không có trong danh mục');
select is(pg_temp.err(format($$select app.save_teaching_profile(jsonb_build_object('user_id', %L, 'grade_codes', jsonb_build_array('K99')))$$, pg_temp.uid('gv1'))), 'HMT_KHOI_SAI', 'Chặn: khối không có trong danh mục');
select is(pg_temp.err(format($$select app.save_teaching_profile(jsonb_build_object('user_id', %L, 'branch_ids', jsonb_build_array(gen_random_uuid())))$$, pg_temp.uid('gv1'))), 'HMT_KHONG_TIM_THAY', 'Chặn: cơ sở không tồn tại');
select lives_ok(format($$select app.save_teaching_profile(jsonb_build_object('user_id', %L, 'subject_codes', jsonb_build_array('TOAN', 'ANH'), 'grade_codes', jsonb_build_array('K06', 'K07'), 'branch_ids', jsonb_build_array(%L), 'note', 'Dạy tối'))$$, pg_temp.uid('gv1'), pg_temp.cs1()), 'Đúng: Admin lập hồ sơ cho giáo viên');
select is(pg_temp.err(format($$select app.save_teaching_profile(jsonb_build_object('user_id', %L))$$, pg_temp.uid('gv1'))), 'HMT_HO_SO_DA_CO', 'Chặn: mỗi người một hồ sơ');
select lives_ok(format($$select app.save_teaching_profile(jsonb_build_object('user_id', %L))$$, pg_temp.uid('ta1')), 'Đúng: lập hồ sơ cho trợ giảng (không môn, khối)');
select is((select kind from app.teaching_profile where user_id = pg_temp.uid('ta1')), 'TG', 'Hồ sơ của người chỉ có vai Trợ giảng là loại TG');
select is((select kind from app.teaching_profile where user_id = pg_temp.uid('gv1')), 'GV', 'Hồ sơ của giáo viên là loại GV');
select ok(not exists (select from jsonb_array_elements(app.list_teaching_candidates()) x where x ->> 'name' = 'Giả gv1'), 'Ứng viên: người đã có hồ sơ không còn trong danh sách');

-- ================= Ô chọn giáo viên khi tạo lớp (migration 314): kèm gợi ý từ hồ sơ dạy, không chặn =================
select is((select (x ->> 'has_profile')::boolean from jsonb_array_elements(app.list_class_form_options(pg_temp.cs1()) -> 'teachers') x where x ->> 'name' = 'Giả gv1'), true, 'Tạo lớp: giáo viên có hồ sơ dạy được đánh dấu has_profile');
select is((select x -> 'subject_names' from jsonb_array_elements(app.list_class_form_options(pg_temp.cs1()) -> 'teachers') x where x ->> 'name' = 'Giả gv1'), '["Toán", "Tiếng Anh"]'::jsonb, 'Tạo lớp: ô chọn có môn dạy từ hồ sơ');
select is((select (x ->> 'has_profile')::boolean from jsonb_array_elements(app.list_class_form_options(pg_temp.cs1()) -> 'teachers') x where x ->> 'name' = 'Giả gv2'), false, 'Tạo lớp: giáo viên chưa có hồ sơ vẫn có trong ô chọn (hồ sơ chỉ gợi ý, không chặn)');

-- ================= Danh sách, lọc =================
select is((app.list_teaching_profiles('{"search": "gv1"}') ->> 'total')::int, 1, 'Danh sách: tìm theo tên');
select is((app.list_teaching_profiles('{"kind": "TG"}') ->> 'total')::int, 1, 'Danh sách: lọc theo loại TG');
select is((app.list_teaching_profiles('{"subject": "TOAN"}') ->> 'total')::int, 1, 'Danh sách: lọc theo môn dạy');
select is((app.list_teaching_profiles('{"grade": "K09"}') ->> 'total')::int, 0, 'Danh sách: lọc khối không có ai dạy thì 0');
select is(app.list_teaching_profiles('{"search": "gv1"}') -> 'rows' -> 0 -> 'subject_names', '["Toán", "Tiếng Anh"]'::jsonb, 'Danh sách: tên môn lấy từ danh mục');
select is(app.list_teaching_profiles('{"search": "gv1"}') -> 'rows' -> 0 -> 'branch_codes', '["CS1"]'::jsonb, 'Danh sách: mã cơ sở thường dạy');

-- ================= Sửa, Ngừng =================
select lives_ok(format($$select app.save_teaching_profile(jsonb_build_object('id', %L, 'subject_codes', jsonb_build_array('TOAN'), 'grade_codes', jsonb_build_array('K06')))$$, (select id from app.teaching_profile where user_id = pg_temp.uid('gv1'))), 'Đúng: Admin sửa môn, khối của hồ sơ');
select is((select subject_codes from app.teaching_profile where user_id = pg_temp.uid('gv1')), array['TOAN'], 'Sửa xong: chỉ còn môn Toán');
select lives_ok(format($$select app.set_teaching_profile_active(%L, false)$$, (select id from app.teaching_profile where user_id = pg_temp.uid('gv1'))), 'Đúng: Ngừng hồ sơ (không xoá)');
select is((app.list_teaching_profiles('{"active": true}') ->> 'total')::int, 1, 'Lọc đang dùng: chỉ còn hồ sơ của trợ giảng');
select is(pg_temp.err($$select app.set_teaching_profile_active(gen_random_uuid(), false)$$), 'HMT_KHONG_TIM_THAY', 'Chặn: Ngừng hồ sơ không có');

-- ================= Người không phải Admin =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.list_teaching_profiles() ->> 'total')::int, 2, 'Trưởng cơ sở xem được danh sách hồ sơ dạy (Cấu hình đào tạo · Xem)');
select is(pg_temp.err(format($$select app.save_teaching_profile(jsonb_build_object('user_id', %L))$$, pg_temp.uid('gv2'))), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không lập hồ sơ dạy');
select is(pg_temp.err($$select app.list_teaching_candidates()$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không xem danh sách ứng viên');
select is(pg_temp.err(format($$select app.set_teaching_profile_active(%L, true)$$, (select id from app.teaching_profile limit 1))), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không Ngừng, Dùng lại hồ sơ');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((app.list_teaching_profiles() ->> 'total')::int, 2, 'CSKH xem được danh sách hồ sơ dạy');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.list_teaching_profiles()$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Sale không có Cấu hình đào tạo · Xem');
select is(has_function_privilege('anon', 'app.list_teaching_profiles(jsonb, text, integer, integer)', 'execute'), false, 'Người chưa đăng nhập không gọi được list_teaching_profiles');

select * from finish();
rollback;
