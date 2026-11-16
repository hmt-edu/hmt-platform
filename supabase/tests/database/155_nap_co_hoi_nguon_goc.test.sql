-- Migration 155: cột nguon_goc của tab 05_COHOI là chữ tự do (script); hàm suy loại nguồn kèm cảnh báo (Chat 15/11). Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.row(p_n integer, p_over jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('row', p_n, 'ma_cu', '09000000' || lpad(p_n::text, 2, '0'), 'ngay_tao', '2026-09-15', 'ho_ten_ph', 'Zeta Quang ' || p_n,
    'sdt_ph', '09000000' || lpad(p_n::text, 2, '0'), 'danh_sach_em', 'Em Một', 'nam_sinh', '2013', 'khoi', '7', 'nhu_cau', 'Học Toán',
    'nguon_goc', 'Marketing', 'nguon', 'Facebook Ads', 'medium', 'Facebook Ads: Inbox', 'co_so', 'CS5', 'nguoi_phu_trach', 'sale.cs5.ng',
    'tinh_trang_cu', 'Đã hẹn test', 'giai_doan', 'L2') || p_over $$;
create function pg_temp.warns(p_res jsonb, p_row integer) returns text language sql as
  $$ select (r -> 'warnings')::text from jsonb_array_elements(p_res -> 'rows') r where (r ->> 'row')::integer = p_row $$;
create function pg_temp.st(p_res jsonb, p_row integer) returns text language sql as
  $$ select r ->> 'status' from jsonb_array_elements(p_res -> 'rows') r where (r ->> 'row')::integer = p_row $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sale5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ng.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password, legacy_ref)
select u.id, 'Giả ' || u.key, u.key || '@ng.hoamatoan.invalid', (select id from app.branch where code = case when u.key = 'sale5' then 'CS5' else 'CS1' end), false,
       case u.key when 'sale5' then 'sale.cs5.ng' end from u;
insert into app.user_role (user_id, role_code) select id, case key when 'admin' then 'ADMIN' else 'SALES' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

create temp table r1 (j jsonb);
grant all on r1 to public;
insert into r1 select app.import_records('CO_HOI', jsonb_build_array(
  pg_temp.row(2),
  pg_temp.row(3, '{"nguon_goc":"Page T9"}'),
  pg_temp.row(4, '{"nguon_goc":"BGĐ","nguon":"Ban Giám Đốc","medium":""}'),
  pg_temp.row(5, '{"nguon_goc":""}'),
  pg_temp.row(6, '{"nguon_goc":"Page T9","nguon":"Nguồn không có"}')), false, 'ch.csv');
select is((select (j ->> 'imported') || '/' || (j ->> 'errors') from r1), '4/1', 'Xem trước: 4 dòng hợp lệ, 1 dòng lỗi (nguồn không có trong danh mục)');
select is(pg_temp.warns((select j from r1), 2), '[]', 'nguon_goc khớp tên loại nguồn: không cảnh báo');
select is(pg_temp.warns((select j from r1), 3), '["Loại nguồn suy mặc định."]', 'nguon_goc chữ tự do: cảnh báo "Loại nguồn suy mặc định", không phải lỗi');
select is(pg_temp.st((select j from r1), 3), 'HOP_LE', 'nguon_goc chữ tự do vẫn là dòng hợp lệ');
select is(pg_temp.warns((select j from r1), 4), '["Loại nguồn suy mặc định."]', 'BGĐ được suy ra loại Ban Giám Đốc, vẫn có cảnh báo suy mặc định');
select is(pg_temp.warns((select j from r1), 5), '["Loại nguồn suy mặc định."]', 'nguon_goc trống: suy Marketing kèm cảnh báo');
select is(pg_temp.st((select j from r1), 6), 'LOI', 'Chặn: nguồn (cột nguon) không có trong danh mục vẫn là lỗi (HMT_NGUON_SAI giữ nguyên)');
select is((select (j -> 'summary' ->> 'source_type_defaulted') from r1), '3', 'Báo cáo: 3 dòng suy loại nguồn');
select is((select count(*)::int from app.opportunity where legacy_ref like '09000000%'), 0, 'Xem trước hoàn tác, chưa ghi cơ hội nào');
select is((select app.import_records('CO_HOI', jsonb_build_array(
  pg_temp.row(2), pg_temp.row(3, '{"nguon_goc":"Page T9"}'), pg_temp.row(4, '{"nguon_goc":"BGĐ","nguon":"Ban Giám Đốc","medium":""}'),
  pg_temp.row(5, '{"nguon_goc":""}')), true, 'ch.csv') ->> 'imported'), '4', 'Nạp thật: 4 cơ hội');
select is((select source_type_code from app.opportunity where legacy_ref = '0900000002'), 'MARKETING', 'Khớp tên loại: Marketing');
select is((select source_type_code from app.opportunity where legacy_ref = '0900000003'), 'MARKETING', 'Chữ tự do: loại Marketing');
select is((select source_type_code from app.opportunity where legacy_ref = '0900000004'), 'BAN_GIAM_DOC', 'BGĐ: loại Ban Giám Đốc');
select is((select count(*)::int from app.note n join app.opportunity o on o.id = n.entity_id where n.entity_type = 'OPPORTUNITY' and o.legacy_ref = '0900000003' and n.body like '%Nguồn gốc (chữ gốc): Page T9%'), 1, 'Chữ gốc "Page T9" nằm trong ghi chú cơ hội');
select is((select count(*)::int from app.note n join app.opportunity o on o.id = n.entity_id where n.entity_type = 'OPPORTUNITY' and o.legacy_ref = '0900000002' and n.body like '%Nguồn gốc%'), 0, 'Loại nguồn khớp: không ghi chú nguồn gốc');
select is((select app.import_records('CO_HOI', jsonb_build_array(pg_temp.row(3, '{"nguon_goc":"Page T9"}')), true, 'ch.csv') ->> 'duplicates'), '1', 'Nạp lại: trùng mã cũ bị bỏ qua (R-V2-30)');

select * from finish();
rollback;
