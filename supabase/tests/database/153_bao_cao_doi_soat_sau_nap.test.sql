-- Code B (migration 151): báo cáo đối soát sau nạp, chỉ Admin, chỉ số tổng. Dữ liệu giả.
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

-- Lớp nền cho các bài Ghi danh (gọi bằng quyền Admin).
select is((select app.import_training_records('LOP', '[{"row":2,"ma_lop_cu":"NAP-4M1","loai_lop":"Lớp chung","mon":"Toán","khoi":"4","lich_hoc":"Thứ 7 (14h30-17h00)","ma_gv":"2001","ngay_khai_giang":"2026-07-18","si_so_toi_da":"12","tinh_trang":"Đang chạy","co_so":"CS1","phan_loai":"CB","trinh_do":"A","so_buoi":"20","nam_hoc":"2627"}]'::jsonb, true, 'lop.csv') ->> 'imported'),
          '1', 'Lớp nền nạp được');

select is((select app.import_training_records('GHI_DANH', jsonb_build_array(
  jsonb_build_object('row', 2, 'hoc_sinh_ma_cu', 'M-NAP-0001', 'ma_lop_cu', 'NAP-4M1', 'tinh_trang_moi', 'Đang học', 'ngay_vao_lop', '2026-08-01', 'thoi_luong_buoi', '2.5', 'gio_du_kien', '10', 'gio_da_hoc', '4', 'gio_con_lai', '6'),
  jsonb_build_object('row', 3, 'hoc_sinh_ma_cu', 'M-NAP-0002', 'ma_lop_cu', 'NAP-4M1', 'tinh_trang_moi', 'Đang học', 'ngay_vao_lop', '2026-08-01', 'thoi_luong_buoi', '2.5', 'gio_du_kien', '10', 'gio_da_hoc', '4', 'gio_con_lai', '6'),
  jsonb_build_object('row', 4, 'hoc_sinh_ma_cu', 'M-NAP-0003', 'ma_lop_cu', 'NAP-4M1', 'tinh_trang_moi', 'Chờ xếp lớp', 'thoi_luong_buoi', '2.5', 'gio_du_kien', '10', 'gio_da_hoc', '4', 'gio_con_lai', '6')), true, 'gd.csv') ->> 'imported'), '3', 'Ghi danh nền nạp được');
select is((select app.import_records('CO_HOI', jsonb_build_array(pg_temp.opp(2), pg_temp.opp(3), pg_temp.opp(4), pg_temp.opp(5)), true, 'ch.csv') ->> 'imported'), '4', 'Cơ hội nền (4 dòng, L5) nạp được');

-- ================= Báo cáo đối soát sau nạp (R-V2-29) =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.import_reconciliation_report()$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: chỉ Admin xem báo cáo đối soát');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.import_reconciliation_report('CS9')$$), 'HMT_NAP_CO_SO_SAI', 'Chặn: mã cơ sở sai');
create temp table rc (j jsonb);
grant all on rc to public;
insert into rc select app.import_reconciliation_report('CS1');
select is((select j ->> 'classes' from rc), '1', 'Đối soát CS1: 1 lớp nạp');
select is((select j ->> 'students' from rc), '4', 'Đối soát CS1: 4 học sinh có mã cũ');
select is((select j ->> 'enrollments_active' from rc), '2', 'Đối soát CS1: 2 ghi danh Đang học (ghi danh thứ ba Chờ xếp lớp)');
select is((select (j ->> 'hours_left')::numeric from rc), 18.00::numeric, 'Đối soát CS1: tổng giờ còn lại 18 (3 ghi danh × 6 giờ)');
select is((select app.import_reconciliation_report('CS5') -> 'opportunities_by_stage' ->> 'L5'), '4', 'Đối soát CS5: 4 cơ hội ở L5');
select is((select app.import_reconciliation_report('CS5') ->> 'opportunities_total'), '4', 'Đối soát CS5: tổng 4 cơ hội');
select is((select app.import_reconciliation_report() ::text like '%Zeta%' or app.import_reconciliation_report()::text like '%0900%'), false, 'Báo cáo không chứa tên hay số điện thoại');

select * from finish();
rollback;
