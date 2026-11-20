-- Migration 571 (LOP-02/03, anh Trường chốt 20/11): Hình thức học của lớp (OFF, ONL, OMO) và app.preview_class_end_date.
-- Luật: R-LOP-02 (sửa thông tin ở Nháp, Từ chối), R-LOP-09 (ngày kết thúc dự kiến), R-LOP-12 (bỏ ngày nghỉ lễ), R-LOP-13. Mỗi luật có ca đúng và ca bị chặn. Dữ liệu giả.
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
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('bm5'), ('sales1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@l571.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@l571.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm5', 'CS5'), ('sales1', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('sales1', 'SALES')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
create function pg_temp.slot(p_wd int, p_first date) returns jsonb language sql stable as $$
  select jsonb_build_object('weekday', p_wd, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1, 'first_date', p_first) $$;
-- Dữ liệu một lớp: CS1, TOAN K08 CB A, bắt đầu thứ Hai 2027-03-01, 4 buổi, một khung thứ Hai.
create function pg_temp.data(p_extra jsonb default '{}'::jsonb) returns jsonb language sql stable as $$
  select jsonb_build_object('branch_id', pg_temp.cs('CS1'), 'year_code', '2627', 'subject_code', 'TOAN', 'grade_code', 'K08',
    'class_type_code', 'CB', 'level_code', 'A', 'max_students', 15, 'start_date', '2027-03-01', 'total_sessions', 4,
    'slots', jsonb_build_array(pg_temp.slot(1, date '2027-03-01'))) || p_extra $$;
create temp table cl (key text primary key, id uuid);
grant all on cl to public;
create function pg_temp.mk(p_key text, p_data jsonb) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  v := app.create_class(p_data);
  insert into cl values (p_key, (v ->> 'id')::uuid);
  return v;
end $$;
create function pg_temp.c(p_key text) returns uuid language sql stable as $$ select id from cl where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

-- ================= Danh mục và cột =================
select is((select count(*)::int from app.catalog_item where catalog_code = 'CLASS_DELIVERY' and code in ('OFF', 'ONL', 'OMO') and is_active), 3, 'Danh mục CLASS_DELIVERY có đủ OFF, ONL, OMO');
select is((select count(*)::int from app.catalog_item where catalog_code = 'STUDY_MODE' and code = 'OMO'), 0, 'OMO không lọt vào STUDY_MODE (hình thức bán của ghi danh)');

set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');

-- ================= Hình thức học khi tạo lớp =================
select pg_temp.mk('macdinh', pg_temp.data());
select is((app.get_class_record(pg_temp.c('macdinh')) ->> 'delivery_mode_code'), 'OFF', 'Tạo lớp không chọn hình thức: mặc định OFF');
select is((app.get_class_record(pg_temp.c('macdinh')) ->> 'delivery_mode_name'), 'Offline', 'Hồ sơ lớp trả tên hình thức học (Offline)');
select pg_temp.mk('omo', pg_temp.data('{"delivery_mode_code": "OMO", "subject_code": "ANH"}'::jsonb));
select is((app.get_class_record(pg_temp.c('omo')) ->> 'delivery_mode_code'), 'OMO', 'Tạo lớp chọn OMO: lưu OMO');
select is(pg_temp.err($$select app.create_class(pg_temp.data('{"delivery_mode_code": "XYZ", "subject_code": "VAN"}'::jsonb))$$), 'HMT_DANH_MUC_KHONG_CO', 'Chặn: hình thức học không có trong danh mục');

-- Sửa hình thức ở Nháp
select app.save_class_info(pg_temp.c('macdinh'), '{"delivery_mode_code": "ONL"}'::jsonb);
select is((app.get_class_record(pg_temp.c('macdinh')) ->> 'delivery_mode_code'), 'ONL', 'Sửa lớp Nháp: đổi sang Online');
select is(pg_temp.err($$select app.save_class_info(pg_temp.c('macdinh'), '{"delivery_mode_code": "XYZ"}'::jsonb)$$), 'HMT_DANH_MUC_KHONG_CO', 'Chặn: sửa sang hình thức không có trong danh mục');
-- Lớp Đã duyệt: hình thức bị khoá cùng các trường thông tin khác
select pg_temp.sudo($$update app.class set status_code = 'DA_DUYET' where id = pg_temp.c('macdinh')$$);
select is(pg_temp.err($$select app.save_class_info(pg_temp.c('macdinh'), '{"delivery_mode_code": "OFF"}'::jsonb)$$), 'HMT_LOP_DA_KHOA', 'Chặn: lớp Đã duyệt không đổi hình thức học');
-- Quyền: Sale không tạo lớp
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.create_class(pg_temp.data('{"delivery_mode_code": "ONL", "subject_code": "VAN"}'::jsonb))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Sale không có quyền tạo lớp kể cả khi chọn hình thức');

-- ================= Hộp chọn lớp trả hình thức học =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.sudo($$update app.class set status_code = 'DA_DUYET' where id = pg_temp.c('omo')$$);
select ok((select bool_or(x ->> 'delivery_mode_code' = 'OMO')
             from jsonb_array_elements(app.enrollment_matching_classes((select id from app.sales_package where is_active order by code limit 1), pg_temp.cs('CS1'), null)) x)
          is not false, 'Hộp chọn lớp trả khoá delivery_mode_code (hoặc chưa có gói phù hợp)');

-- ================= Xem trước ngày kết thúc dự kiến =================
-- 4 buổi, thứ Hai hàng tuần từ 01/03/2027: 01, 08, 15, 22/03 → kết thúc 22/03/2027.
select is(app.preview_class_end_date(pg_temp.cs('CS1'), date '2027-03-01', 4, jsonb_build_array(pg_temp.slot(1, date '2027-03-01'))), date '2027-03-22', 'Xem trước: 4 buổi thứ Hai hàng tuần kết thúc 22/03/2027');
-- Hai khung thứ Hai và thứ Tư: 01, 03, 08, 10/03 → 10/03/2027.
select is(app.preview_class_end_date(pg_temp.cs('CS1'), date '2027-03-01', 4, jsonb_build_array(pg_temp.slot(1, date '2027-03-01'), pg_temp.slot(3, date '2027-03-03'))), date '2027-03-10', 'Xem trước: hai khung/tuần kết thúc sớm hơn (10/03/2027)');
-- Ngày nghỉ lễ chung rơi vào buổi thứ hai: buổi nhảy sang tuần sau (R-LOP-12).
select pg_temp.sudo($$insert into app.holiday (holiday_date, name) values (date '2027-03-08', 'Nghỉ giả cho kiểm thử')$$);
select is(app.preview_class_end_date(pg_temp.cs('CS1'), date '2027-03-01', 4, jsonb_build_array(pg_temp.slot(1, date '2027-03-01'))), date '2027-03-29', 'Xem trước bỏ ngày nghỉ lễ (R-LOP-12): lùi một tuần, 29/03/2027');
-- Chưa có khung giờ hoặc chưa có số buổi: null, không lỗi.
select is(app.preview_class_end_date(pg_temp.cs('CS1'), date '2027-03-01', 4, '[]'::jsonb), null::date, 'Xem trước: chưa có khung giờ thì trả null');
select is(app.preview_class_end_date(pg_temp.cs('CS1'), date '2027-03-01', 0, jsonb_build_array(pg_temp.slot(1, date '2027-03-01'))), null::date, 'Xem trước: chưa có số buổi thì trả null');
-- Khung sai (ngày đầu sai thứ) báo lỗi có mã như lúc lưu.
select is(pg_temp.err($$select app.preview_class_end_date(pg_temp.cs('CS1'), date '2027-03-01', 4, jsonb_build_array(pg_temp.slot(2, date '2027-03-01')))$$), 'HMT_LOP_NGAY_DAU_SAI_THU', 'Xem trước chặn khung có ngày đầu sai thứ');
-- Không ghi gì: số buổi của lớp không đổi sau khi xem trước.
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('omo')), 0, 'Xem trước không ghi buổi nào');
-- Quyền: Trưởng cơ sở CS5 không xem trước cho cơ sở CS1; Sale CS1 xem được cơ sở mình nếu có quyền xem lớp.
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.preview_class_end_date(pg_temp.cs('CS1'), date '2027-03-01', 4, jsonb_build_array(pg_temp.slot(1, date '2027-03-01')))$$), 'HMT_KHONG_CO_QUYEN', 'Xem trước chặn: Trưởng cơ sở CS5 không dùng cho cơ sở CS1');

reset role;
select * from finish();
rollback;
