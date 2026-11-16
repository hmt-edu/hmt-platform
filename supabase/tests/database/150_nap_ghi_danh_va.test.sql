-- Code B (migration 150): vá Ghi danh (tình trạng trống, "Đã xếp lớp", giờ âm, 0 giờ vẫn có dòng Số dư đầu kỳ, chặn cả loại).
-- Luật: R-V2-30, R-V2-32, R-V2-33, Q-177, Q-253. Dữ liệu giả.
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
create function pg_temp.st(p_res jsonb, p_row integer) returns text language sql as
  $$ select r ->> 'status' from jsonb_array_elements(p_res -> 'rows') r where (r ->> 'row')::integer = p_row $$;
create function pg_temp.msg(p_res jsonb, p_row integer) returns text language sql as
  $$ select r ->> 'message' from jsonb_array_elements(p_res -> 'rows') r where (r ->> 'row')::integer = p_row $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh1');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@nap5.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password, legacy_ref)
select u.id, 'Giả ' || u.key, u.key || '@nap5.hoamatoan.invalid', (select id from app.branch where code = case when u.key = 'sale5' then 'CS5' else 'CS1' end), false,
       case u.key when 'sale5' then 'sale.cs5.b' end from u;
insert into app.user_role (user_id, role_code) select id, case key when 'admin' then 'ADMIN' when 'cskh1' then 'CSKH' else 'SALES' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHNAP501', 'Phụ huynh giả nạp', '0900001001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id, legacy_ref)
  values ('HSNAP501', (select id from app.parent where code = 'PHNAP501'), 'Học sinh giả nạp 1', 2012, (select id from app.branch where code = 'CS1'), 'M-NAP-0001'),
         ('HSNAP502', (select id from app.parent where code = 'PHNAP501'), 'Học sinh giả nạp 2', 2012, (select id from app.branch where code = 'CS1'), 'M-NAP-0002'),
         ('HSNAP503', (select id from app.parent where code = 'PHNAP501'), 'Học sinh giả nạp 3', 2012, (select id from app.branch where code = 'CS1'), 'M-NAP-0003'),
         ('HSNAP504', (select id from app.parent where code = 'PHNAP501'), 'Học sinh giả nạp 4', 2012, (select id from app.branch where code = 'CS1'), 'M-NAP-0004')$$);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- Lớp nền cho các bài Ghi danh (gọi bằng quyền Admin).
select is((select app.import_training_records('LOP', '[{"row":2,"ma_lop_cu":"NAP-4M1","loai_lop":"Lớp chung","mon":"Toán","khoi":"4","lich_hoc":"Thứ 7 (14h30-17h00)","ma_gv":"2001","ngay_khai_giang":"2026-07-18","si_so_toi_da":"12","tinh_trang":"Đang chạy","co_so":"CS1","phan_loai":"CB","trinh_do":"A","so_buoi":"20","nam_hoc":"2627"}]'::jsonb, true, 'lop.csv') ->> 'imported'),
          '1', 'Lớp nền nạp được');

-- ================= Ghi danh: vá theo bảng đối chiếu (H1, H6, R-V2-30) =================
create function pg_temp.gd(p_n integer, p_stu text, p_over jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('row', p_n, 'hoc_sinh_ma_cu', p_stu, 'ma_lop_cu', 'NAP-4M1', 'tinh_trang_moi', 'Đang học', 'ngay_vao_lop', '2026-08-01',
    'thoi_luong_buoi', '2.5', 'gio_du_kien', '10', 'gio_da_hoc', '4', 'gio_con_lai', '6') || p_over $$;
grant execute on function pg_temp.gd(integer, text, jsonb) to public;
create temp table gd1 (j jsonb);
grant all on gd1 to public;
insert into gd1 select app.import_training_records('GHI_DANH', jsonb_build_array(
  pg_temp.gd(2, 'M-NAP-0001', '{"tinh_trang_moi":"Đã xếp lớp"}'),
  pg_temp.gd(3, 'M-NAP-0002', '{"tinh_trang_moi":"","ngay_vao_lop":""}'),
  pg_temp.gd(4, 'M-NAP-0003', '{"tinh_trang_moi":"Đã xếp lớp","ngay_vao_lop":""}')), false, 'gd.csv');
select is((select j ->> 'imported' from gd1), '3', 'Xem trước: "Đã xếp lớp" và tình trạng trống không còn làm hỏng dòng (H1)');
select is((select j ->> 'errors' from gd1), '0', 'Xem trước: không dòng nào lỗi');
select is((select jsonb_array_length(r -> 'warnings') from jsonb_array_elements((select j -> 'rows' from gd1)) r where (r ->> 'row')::int = 3), 1, 'Tình trạng trống có một cảnh báo');
select is(pg_temp.err($$select app.import_training_records('GHI_DANH', jsonb_build_array(pg_temp.gd(2, 'M-NAP-0001', '{"gio_du_kien":"4","gio_da_hoc":"10","gio_con_lai":"-6"}')), false, 'gd.csv')$$), null, 'Hàm không ném lỗi; lỗi nằm trong kết quả từng dòng');
select is((select j -> 'summary' -> 'errors_by_type' -> 'HMT_NAP_GIO_AM' from (select app.import_training_records('GHI_DANH', jsonb_build_array(pg_temp.gd(2, 'M-NAP-0001', '{"gio_du_kien":"4","gio_da_hoc":"10","gio_con_lai":"-6"}')), false, 'gd.csv') j) x)::text, '[2]', 'Chặn: giờ còn lại âm báo HMT_NAP_GIO_AM (Q-253, H6)');
create temp table gd2 (j jsonb);
grant all on gd2 to public;
insert into gd2 select app.import_training_records('GHI_DANH', jsonb_build_array(
  pg_temp.gd(2, 'M-NAP-0001'), pg_temp.gd(3, 'M-KHONG-CO')), true, 'gd.csv');
select is((select j ->> 'mode' from gd2), 'CHAN_CA_LOAI', 'Nạp thật có một dòng lỗi: chặn cả loại (R-V2-30, H3)');
select is((select j ->> 'imported' from gd2), '0', 'Chặn cả loại: số nạp 0');
select is((select count(*)::int from app.enrollment where legacy_ref like 'M-NAP-%'), 0, 'Chặn cả loại: dòng đúng cũng không được ghi');
select is((select imported_count from app.import_log where kind = 'GHI_DANH' order by created_at desc limit 1), 0, 'Nhật ký ghi lần bị chặn với 0 dòng nạp');
select is((select app.import_training_records('GHI_DANH', jsonb_build_array(
  pg_temp.gd(2, 'M-NAP-0001', '{"tinh_trang_moi":"Đã xếp lớp"}'), pg_temp.gd(3, 'M-NAP-0002', '{"tinh_trang_moi":"","ngay_vao_lop":""}'),
  pg_temp.gd(4, 'M-NAP-0003', '{"tinh_trang_moi":"Đã xếp lớp","ngay_vao_lop":""}')), true, 'gd.csv') ->> 'imported'), '3', 'Nạp thật khi mọi dòng đúng: 3 ghi danh');
select is((select status_code from app.enrollment where legacy_ref = 'M-NAP-0001|NAP-4M1'), 'DANG_HOC', '"Đã xếp lớp" có ngày vào lớp thành Đang học');
select is((select status_code from app.enrollment where legacy_ref = 'M-NAP-0002|NAP-4M1'), 'CHO_XEP_LOP', 'Tình trạng trống thành Chờ xếp lớp');
select is((select status_code from app.enrollment where legacy_ref = 'M-NAP-0003|NAP-4M1'), 'CHO_XEP_LOP', '"Đã xếp lớp" không có ngày vào lớp thành Chờ xếp lớp');
select is(app.enrollment_hours_balance((select id from app.enrollment where legacy_ref = 'M-NAP-0001|NAP-4M1')), 6.00::numeric, 'Số dư đầu kỳ vẫn đúng gio_con_lai = 6');
-- Giờ còn lại bằng 0 vẫn sinh dòng Số dư đầu kỳ (Q-177, Chat 11:25).
select is((select app.import_training_records('GHI_DANH', jsonb_build_array(pg_temp.gd(5, 'M-NAP-0004', '{"gio_du_kien":"4","gio_da_hoc":"4","gio_con_lai":"0"}')), true, 'gd.csv') ->> 'imported'), '1', 'Ghi danh hết giờ (còn lại 0) nạp được');
select is((select count(*)::int from app.hour_ledger l join app.enrollment e on e.id = l.enrollment_id where e.legacy_ref = 'M-NAP-0004|NAP-4M1' and l.entry_type = 'DAU_KY' and l.hours = 0), 1, 'Giờ còn lại 0 vẫn có đúng một dòng Số dư đầu kỳ (Q-177)');
select is(pg_temp.err($$select pg_temp.sudo('insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) select id, branch_id, ''DIEU_CHINH'', 0 from app.enrollment where legacy_ref = ''M-NAP-0004|NAP-4M1''')$$), '23514', 'Chặn: dòng sổ giờ loại khác Số dư đầu kỳ vẫn cấm 0 giờ (R-GD-04)');
select is(app.enrollment_hours_balance((select id from app.enrollment where legacy_ref = 'M-NAP-0004|NAP-4M1')), 0.00::numeric, 'Số dư giờ của ghi danh hết giờ là 0');

select * from finish();
rollback;


