-- Code B (migration 153): Sổ số dư khách hàng và nạp Số dư tiền (R-V2-30, R-V2-32, R-TIEN-33), báo cáo đối soát có tiền. Dữ liệu giả.
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

-- ================= Số dư tiền và Sổ số dư (R-V2-32, R-TIEN-33, R-V2-30) =================
create function pg_temp.sd(p_n integer, p_stu text, p_debt text, p_credit text) returns jsonb language sql as $$
  select jsonb_build_object('row', p_n, 'hoc_sinh_ma_cu', p_stu, 'cong_no_phai_thu_dong', p_debt, 'tien_thu_thua_dong', p_credit) $$;
grant execute on function pg_temp.sd(integer, text, text, text) to public;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.import_training_records('SO_DU', '[{"row":2}]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: chỉ Admin nạp Số dư');
select is((select count(*)::int from app.customer_balance_entry), 0, 'Không phải Admin: không đọc được Sổ số dư (RLS)');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
create temp table sd1 (j jsonb);
grant all on sd1 to public;
insert into sd1 select app.import_training_records('SO_DU', jsonb_build_array(
  pg_temp.sd(2, 'M-NAP-0001', '2490000', '0'), pg_temp.sd(3, 'M-NAP-0002', '0', '660000'), pg_temp.sd(4, 'M-NAP-0003', '0', '0')), false, 'sd.csv');
select is((select (j ->> 'imported') || '/' || (j ->> 'errors') from sd1), '3/0', 'Xem trước số dư: 3 dòng hợp lệ');
select is((select count(*)::int from app.customer_balance_entry), 0, 'Xem trước hoàn tác, chưa ghi dòng sổ nào');
-- Một dòng lỗi chặn cả loại.
create temp table sd2 (j jsonb);
grant all on sd2 to public;
insert into sd2 select app.import_training_records('SO_DU', jsonb_build_array(
  pg_temp.sd(2, 'M-NAP-0001', '2490000', '0'), pg_temp.sd(3, 'M-KHONG-CO', '0', '660000'), pg_temp.sd(4, 'M-NAP-0003', '-5', '0'), pg_temp.sd(5, 'M-NAP-0004', '1.5', '0')), true, 'sd.csv');
select is((select j ->> 'mode' from sd2), 'CHAN_CA_LOAI', 'Số dư: một dòng lỗi chặn cả loại (R-V2-30)');
select is((select j -> 'summary' -> 'errors_by_type' -> 'HMT_NAP_HOC_SINH_CHUA_CO' from sd2)::text, '[3]', 'Báo cáo: dòng 3 chưa có học sinh');
select is((select j -> 'summary' -> 'errors_by_type' -> 'HMT_NAP_TIEN_SAI' from sd2)::text, '[4, 5]', 'Báo cáo: tiền âm và tiền có phần lẻ đều bị chặn');
select is((select count(*)::int from app.customer_balance_entry), 0, 'Bị chặn: không ghi dòng sổ nào, kể cả dòng đúng');
-- Nạp thật khi mọi dòng đúng.
select is((select app.import_training_records('SO_DU', jsonb_build_array(
  pg_temp.sd(2, 'M-NAP-0001', '2490000', '0'), pg_temp.sd(3, 'M-NAP-0002', '0', '660000'), pg_temp.sd(4, 'M-NAP-0003', '0', '0')), true, 'sd.csv') ->> 'imported'), '3', 'Nạp thật số dư: 3 dòng');
select is((select amount from app.customer_balance_entry where entry_type = 'DAU_KY_CONG_NO'), -2490000::bigint, 'Công nợ đầu kỳ là số ÂM trong sổ (R-V2-32)');
select is((select amount from app.customer_balance_entry where entry_type = 'DAU_KY_THU_THUA'), 660000::bigint, 'Tiền thu thừa là số DƯƠNG trong sổ (R-V2-32)');
select is((select count(*)::int from app.customer_balance_entry), 2, 'Dòng không có số dư nào không ghi sổ');
select is((select entry_date from app.customer_balance_entry where entry_type = 'DAU_KY_CONG_NO'), app.get_setting('opening_balance_date')::date, 'Dòng sổ mang ngày chốt (tham số opening_balance_date)');
select is((select count(*)::int from app.customer_balance_entry b join app.student s on s.id = b.student_id where b.parent_id = s.parent_id), 2, 'Sổ theo phụ huynh, giữ học sinh ở từng dòng (H4)');
select is((select app.import_training_records('SO_DU', jsonb_build_array(pg_temp.sd(2, 'M-NAP-0001', '2490000', '0')), true, 'sd.csv') ->> 'duplicates'), '1', 'Nạp lại: trùng mã học sinh cũ bị bỏ qua, không ghi đè');
select is((select count(*)::int from app.customer_balance_entry), 2, 'Nạp lại không thêm dòng sổ');
select is(pg_temp.err($$select pg_temp.sudo('update app.customer_balance_entry set amount = -1')$$), 'HMT_SO_DU_CHI_THEM', 'Chặn: sổ số dư chỉ thêm dòng, không sửa (R-TIEN-33)');
select is(pg_temp.err($$select pg_temp.sudo('delete from app.customer_balance_entry')$$), 'HMT_KHONG_XOA', 'Chặn: không xoá dòng sổ (R-TIEN-33)');
select is((select j::text like '%M-NAP-%' from sd1), false, 'Kết quả không chứa mã cũ của học sinh');


-- Báo cáo đối soát có tổng tiền (R-V2-29)
select is((select (app.import_reconciliation_report('CS1') ->> 'debt_total_vnd')::bigint), 2490000::bigint, 'Đối soát: tổng công nợ 2.490.000 đồng (số dương)');
select is((select (app.import_reconciliation_report('CS1') ->> 'credit_total_vnd')::bigint), 660000::bigint, 'Đối soát: tổng tiền thu thừa 660.000 đồng');

select * from finish();
rollback;
