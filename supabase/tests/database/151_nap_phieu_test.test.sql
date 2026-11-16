-- Code B (migration 152): nạp Phiếu test cũ (R-V2-29, 30, 31). Dữ liệu giả; kết quả không chứa họ tên, số điện thoại.
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
-- Dòng cơ hội mẫu (CS5, người phụ trách sale.cs5.b); p_n quyết định số điện thoại 0900 000 0nn.
create function pg_temp.opp(p_n integer) returns jsonb language sql as $$
  select jsonb_build_object('row', p_n, 'ma_cu', '09000000' || lpad(p_n::text, 2, '0'), 'ngay_tao', '2026-09-15', 'ho_ten_ph', 'Zeta Quang ' || p_n,
    'sdt_ph', '09000000' || lpad(p_n::text, 2, '0'), 'danh_sach_em', 'Em Một', 'nam_sinh', '2013', 'khoi', '7', 'truong', 'THCS Thử', 'nhu_cau', 'Học Toán',
    'nguon_goc', 'Marketing', 'nguon', 'Facebook Ads', 'medium', 'Facebook Ads: Inbox', 'co_so', 'CS5', 'nguoi_phu_trach', 'sale.cs5.b',
    'nguoi_phu_trach_goc', 'Tên Gốc', 'tinh_trang_cu', 'Đã hẹn test', 'giai_doan', 'L5', 'ghi_chu', 'Khách quan tâm') $$;
create function pg_temp.pt(p_n integer, p_over jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('row', p_n, 'ma_cu', '09000000' || lpad(p_n::text, 2, '0') || '|2026-09-14|em mot', 'sdt_ph', '09000000' || lpad(p_n::text, 2, '0'),
    'ngay_test', '2026-09-14', 'gio_test', '17:30', 'ho_ten_hs', 'Em Một', 'khoi', '7', 'mon', 'Toán', 'diem', '7,5', 'trang_thai_phieu', 'Hoàn thành') || p_over $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh1'), ('sale5');
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

-- ================= Phiếu test (R-V2-29, R-V2-30, R-V2-31) =================
select is((select is_active from app.catalog_item where catalog_code = 'TEST_STATUS' and code = 'COMPLETED_LEGACY'), false, 'Trạng thái "Hoàn thành (dữ liệu cũ)" ở trạng thái Ngừng: không thêm cột Kanban, người dùng không chọn được');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.import_training_records('PHIEU_TEST', '[{"row":2}]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: chỉ Admin nạp Phiếu test');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((select app.import_records('CO_HOI', jsonb_build_array(pg_temp.opp(2), pg_temp.opp(3), pg_temp.opp(4), pg_temp.opp(5)), true, 'ch.csv') ->> 'imported'), '4', 'Cơ hội nền (4 dòng, L5) nạp được');
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSNAP6' || right(p.phone, 2), p.id, 'Em Một', 2013, p.branch_id from app.parent p where p.phone in ('0900000002', '0900000003', '0900000004', '0900000005')$$);
create temp table pt1 (j jsonb);
grant all on pt1 to public;
insert into pt1 select app.import_training_records('PHIEU_TEST', jsonb_build_array(
  pg_temp.pt(2),
  pg_temp.pt(3, '{"diem":"","trang_thai_phieu":"Hoàn thành"}'),
  pg_temp.pt(4, '{"trang_thai_phieu":"Huỷ","ly_do_huy":"L5M","diem":""}'),
  pg_temp.pt(5),
  pg_temp.pt(6, '{"sdt_ph":"0911111111"}'),
  pg_temp.pt(7, '{"ho_ten_hs":"Em Khác","sdt_ph":"0900000005"}')), false, 'pt.csv');
select diag((select r ->> 'message' from jsonb_array_elements((select j -> 'rows' from pt1)) r where (r ->> 'row')::int = 2));
select is((select j ->> 'mode' from pt1), 'XEM_TRUOC', 'Xem trước phiếu test: chế độ XEM_TRUOC');
select is((select (j ->> 'imported') || '/' || (j ->> 'errors') from pt1), '4/2', 'Xem trước: 4 hợp lệ, 2 lỗi (không có cơ hội, không có học sinh)');
select is((select j -> 'summary' -> 'errors_by_type' -> 'HMT_NAP_CO_HOI_CHUA_CO' from pt1)::text, '[6]', 'Báo cáo: dòng 6 không có cơ hội theo số điện thoại');
select is((select count(*)::int from app.student_test where legacy_ref like '09000000%'), 0, 'Xem trước hoàn tác, chưa ghi phiếu nào');
select is((select j::text like '%Em Một%' or j::text like '%0900000%' from pt1), false, 'Kết quả xem trước không chứa họ tên hay số điện thoại');
-- Nạp thật: dòng lỗi không chặn dòng đúng (nhóm CRM, R-V2-30).
select is((select app.import_training_records('PHIEU_TEST', jsonb_build_array(
  pg_temp.pt(2), pg_temp.pt(3, '{"diem":""}'), pg_temp.pt(4, '{"trang_thai_phieu":"Huỷ","ly_do_huy":"L5M","diem":""}'), pg_temp.pt(5),
  pg_temp.pt(6, '{"sdt_ph":"0911111111"}'), pg_temp.pt(7, '{"ho_ten_hs":"Em Khác","sdt_ph":"0900000005"}')), true, 'pt.csv') ->> 'imported'), '4', 'Nạp thật: 4 phiếu, dòng lỗi không chặn dòng đúng');
select is((select status_code from app.student_test where legacy_ref like '0900000002%'), 'COMPLETED_LEGACY', 'Hoàn thành có điểm: "Hoàn thành (dữ liệu cũ)" (R-V2-31)');
select is((select score from app.student_test where legacy_ref like '0900000002%'), 7.5::numeric, 'Giữ điểm cũ 7,5 (dấu phẩy thập phân)');
select is((select suggested_level_code from app.student_test where legacy_ref like '0900000002%'), null, 'Không bắt trình độ đề xuất (R-V2-31)');
select is((select status_code from app.student_test where legacy_ref like '0900000003%'), 'TEACHER_REVIEW', 'Hoàn thành không điểm: Chờ giáo viên chấm');
select is((select status_code || '/' || cancel_reason_code from app.student_test where legacy_ref like '0900000004%'), 'CANCELLED/L5M', 'Phiếu huỷ giữ lý do huỷ');
select is((select scheduled_at from app.student_test where legacy_ref like '0900000002%'), '2026-09-14 10:30:00+00'::timestamptz, 'Ngày giờ test là 17:30 giờ Việt Nam');
select is((select app.import_training_records('PHIEU_TEST', jsonb_build_array(pg_temp.pt(2), pg_temp.pt(3)), true, 'pt.csv') ->> 'duplicates'), '2', 'Nạp lại: trùng mã cũ bị bỏ qua, không ghi đè (R-V2-30)');
select is(pg_temp.st(app.import_training_records('PHIEU_TEST', jsonb_build_array(pg_temp.pt(8, '{"ma_cu":"X8","trang_thai_phieu":"Huỷ","ly_do_huy":"","sdt_ph":"0900000005"}')), false, 'pt.csv'), 8), 'LOI', 'Chặn: phiếu huỷ thiếu lý do huỷ');
select is(pg_temp.st(app.import_training_records('PHIEU_TEST', jsonb_build_array(pg_temp.pt(9, '{"ma_cu":"X9","diem":"11","sdt_ph":"0900000005"}')), false, 'pt.csv'), 9), 'LOI', 'Chặn: điểm ngoài thang 0 đến 10');
select is(pg_temp.st(app.import_training_records('PHIEU_TEST', jsonb_build_array(pg_temp.pt(10, '{"ma_cu":"X10","gio_test":"chiều","sdt_ph":"0900000005"}')), false, 'pt.csv'), 10), 'LOI', 'Chặn: giờ test sai dạng hh:mm');


select * from finish();
rollback;
