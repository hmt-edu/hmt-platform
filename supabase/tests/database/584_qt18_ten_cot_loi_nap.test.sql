-- QT-18 (migration 584; R-V2-29, 30, 31): dòng lỗi khi nạp dữ liệu cũ có tên cột lỗi (khoá `column`). Mỗi luật có ca đúng và ca không đoán cột. Dữ liệu giả.
begin;
-- D41 (migration 472): bài này kiểm luật «Admin, Kế toán phải qua hai bước»; luật chỉ áp khi tham số mfa_required_enabled bật (mặc định tắt), nên bật tham số ở đây.
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
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
-- Gọi nạp, trả kết quả JSON.
create function pg_temp.imp(p_kind text, p_rows jsonb, p_commit boolean default false, p_file text default null)
returns jsonb language sql as $$ select app.import_records(p_kind, p_rows, p_commit, p_file) $$;
-- Trạng thái của dòng thứ n trong kết quả.
create function pg_temp.st(p_res jsonb, p_row integer) returns text language sql as
  $$ select r ->> 'status' from jsonb_array_elements(p_res -> 'rows') r where (r ->> 'row')::integer = p_row $$;
create function pg_temp.hs(p_res jsonb, p_row integer, p_key text) returns text language sql as
  $$ select r ->> p_key from jsonb_array_elements(p_res -> 'rows') r where (r ->> 'row')::integer = p_row $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@q18.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select id, 'Giả ' || key, key || '@q18.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES')) v(k, role) on v.k = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

-- Hàm suy cột: câu lỗi nêu cột thì lấy đúng cột đó (nhóm đào tạo).
select is(app.import_error_column('GHI_DANH', 'HMT_NAP_LOP_CHUA_CO', 'Không tìm thấy lớp theo ma_lop_cu. Nạp tab Lớp trước.'), null,
          'Câu lỗi không viết «cột X»: không đoán (ma_lop_cu chỉ nằm trong câu, không có từ «cột»)');
select is(app.import_error_column('SO_DU', 'HMT_NAP_THIEU_COT', 'Thiếu giá trị cột hoc_sinh_ma_cu.'), 'hoc_sinh_ma_cu', 'Đào tạo: câu «Thiếu giá trị cột X» cho đúng cột X');
select is(app.import_error_column('PHIEU_TEST', 'HMT_NAP_SO_SAI', 'Cột diem phải từ 0 đến 10.'), 'diem', 'Đào tạo: «Cột diem phải…» cho cột diem');
-- Nhóm CRM: mã chỉ về một cột, có xét loại nạp.
select is(app.import_error_column('PHU_HUYNH', 'HMT_SDT_SAI', 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.'), 'sdt', 'Phụ huynh: SĐT sai là cột sdt');
select is(app.import_error_column('HOC_SINH', 'HMT_SDT_SAI', 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.'), 'sdt_ph', 'Học sinh: SĐT sai là cột sdt_ph (SĐT phụ huynh)');
select is(app.import_error_column('CO_HOI', 'HMT_THIEU_HO_TEN', 'Thiếu họ tên phụ huynh.'), 'ho_ten_ph', 'Cơ hội: thiếu họ tên là cột ho_ten_ph');
select is(app.import_error_column('HOC_SINH', 'HMT_NGAY_SINH_SAI', 'Ngày sinh không có thật.'), 'ngay_sinh', 'Học sinh: ngày sinh sai là cột ngay_sinh');
-- Mã chung chung hoặc không biết: không đoán.
select is(app.import_error_column('CO_HOI', 'HMT_NGUON_SAI', 'Kênh không thuộc nguồn đã chọn.'), null, 'Mã chung chung (HMT_NGUON_SAI): không đoán cột');
select is(app.import_error_column('PHU_HUYNH', 'HMT_DONG_SAI', 'Dòng không đúng định dạng.'), null, 'Dòng không đúng định dạng: không có cột');
select is(app.import_error_column('PHU_HUYNH', null, null), null, 'Không có mã lỗi: không có cột');

-- ================= Đầu cuối qua hàm nạp (Admin hai bước) =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.hs(pg_temp.imp('PHU_HUYNH', '[{"row":2,"ma_cu":"Q1","ho_ten":"Giả A","sdt":"090","co_so":"CS5"}]'), 2, 'column'), 'sdt',
          'Xem trước Phụ huynh: dòng SĐT sai báo column = sdt');
select is(pg_temp.hs(pg_temp.imp('PHU_HUYNH', '[{"row":3,"ma_cu":"Q2","ho_ten":"Giả B","sdt":"0900000002","co_so":"CS5"}]'), 3, 'column'), null,
          'Dòng hợp lệ không có column');
select is(pg_temp.hs(pg_temp.imp('HOC_SINH', '[{"row":2,"ma_cu":"Q3","ho_ten":"Giả C","ngay_sinh":"2012-02-31","sdt_ph":"0900000001","co_so":"CS5"}]'), 2, 'column'), 'ngay_sinh',
          'Xem trước Học sinh: ngày sinh không có thật báo column = ngay_sinh');
select is(pg_temp.hs(pg_temp.imp('PHU_HUYNH', '[{"row":2,"ma_cu":"Q1","ho_ten":"Giả A","sdt":"090","co_so":"CS5"}]'), 2, 'error_code'), 'HMT_SDT_SAI',
          'Dòng lỗi CRM có thêm error_code');
select is(app.import_training_records('PHIEU_TEST', '[{"row":2,"ma_cu":"Q9","sdt_ph":"0900000001","ngay_test":"2026-13-45"}]', false) -> 'rows' -> 0 ->> 'column',
          (select app.import_error_column('PHIEU_TEST', r ->> 'error_code', r ->> 'message')
             from jsonb_array_elements(app.import_training_records('PHIEU_TEST', '[{"row":2,"ma_cu":"Q9","sdt_ph":"0900000001","ngay_test":"2026-13-45"}]', false) -> 'rows') r limit 1),
          'Nhóm đào tạo: column của dòng lỗi khớp hàm suy cột từ chính câu lỗi');

select * from finish();
rollback;
