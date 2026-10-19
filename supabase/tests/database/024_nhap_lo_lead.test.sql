-- P3b3b: nhập lô lead từ file (docs/spec/04 R-CRM-11; TS-04; anh chốt 18/10).
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò nhập trong và ngoài cơ sở.
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
-- Lấy câu lỗi tiếng Việt (MESSAGE) của một lệnh.
create function pg_temp.msg(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
-- Chạy một câu lệnh với quyền chủ DB (dựng dữ liệu thử khi đang đóng vai người dùng).
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Thử Một', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1'), ('teacher1'), ('teacher5'), ('hs');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999999' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);


-- ================= Dựng dữ liệu =================
select pg_temp.sudo($$create function pg_temp.res(p_result jsonb, p_row integer) returns jsonb language sql immutable as
  'select r from jsonb_array_elements($1 -> ''rows'') r where (r ->> ''row'')::integer = $2'$$);
select pg_temp.sudo($$grant execute on function pg_temp.res(jsonb, integer) to public$$);
select pg_temp.sudo($$create function pg_temp.camp() returns uuid language sql stable security definer as 'select id from app.campaign where name = ''Chiến dịch thử nhập lô'''$$);
select pg_temp.sudo($$grant execute on function pg_temp.camp() to public$$);
select pg_temp.sudo($$insert into app.campaign (name) values ('Chiến dịch thử nhập lô')$$);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id)
  select 'PH900031', 'Phụ Huynh Có Sẵn', '0900000531', id from app.branch where code = 'CS1'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
-- Lead có sẵn trùng SĐT.
select app.create_lead(pg_temp.lead_data('0900000530', '{"parent_name": "Lead Có Sẵn"}'));
create temp table dft as select jsonb_build_object('source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS', 'channel_code', 'FACEBOOK_ADS_LEAD_FORM',
  'campaign_id', pg_temp.camp()) as d;
grant select on dft to public;

-- Mười dòng đủ mọi ca.
create temp table rows10 as select jsonb_build_array(
  jsonb_build_object('row', 2, 'parent_name', 'Chị Một', 'parent_phone', '0900000501', 'student_name', 'Em Một', 'student_birth_year', '2012', 'need', 'Học Toán 9'),
  jsonb_build_object('row', 3, 'parent_name', '  ', 'parent_phone', '0900000502'),
  jsonb_build_object('row', 4, 'parent_name', 'Chị Ba', 'parent_phone', '12345'),
  jsonb_build_object('row', 5, 'parent_name', 'Chị Bốn', 'parent_phone', '+84 900 000 504', 'source_code', 'WEBSITE', 'channel_code', null),
  jsonb_build_object('row', 6, 'parent_name', 'Chị Năm', 'parent_phone', '0900000505', 'source_type_code', 'EVENT'),
  jsonb_build_object('row', 7, 'parent_name', 'Chị Sáu', 'parent_phone', '0900000506', 'student_birth_year', 'hai nghìn'),
  jsonb_build_object('row', 8, 'parent_name', 'Chị Bảy', 'parent_phone', '0900000530'),
  jsonb_build_object('row', 9, 'parent_name', 'Chị Tám', 'parent_phone', '0900000531'),
  jsonb_build_object('row', 10, 'parent_name', 'Chị Chín', 'parent_phone', '0900000501'),
  jsonb_build_object('row', 11, 'parent_name', 'Chị Mười', 'parent_phone', '0900000510', 'owner_email', 'khong.co@thu.hoamatoan.invalid')
) as r;
grant select on rows10 to public;

-- ================= Quyền và giới hạn =================
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.import_leads((select r from rows10), false, (select d from dft))$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không nhập lô lead');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.import_leads((select r from rows10), false, (select d from dft))$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không nhập lô lead');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.import_leads((select r from rows10), false, (select d from dft) || jsonb_build_object('branch_id', (select id from app.branch where code = 'CS1')))$$),
          'HMT_KHONG_CO_QUYEN', 'Tuyển sinh CS5 không nhập lô vào cơ sở CS1');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.import_leads('{"a": 1}'::jsonb, false)$$), 'HMT_THIEU_THONG_TIN', 'Không phải mảng: bị chặn');
select is(pg_temp.err($$select app.import_leads('[]'::jsonb, false)$$), 'HMT_THIEU_THONG_TIN', 'Không có dòng nào: bị chặn');
select is(pg_temp.err($$select app.import_leads((select jsonb_agg(jsonb_build_object('parent_name', 'X', 'parent_phone', '09' || lpad(g::text, 8, '0'))) from generate_series(1, 501) g), false, (select d from dft))$$),
          'HMT_QUA_NHIEU_DONG', 'Quá 500 dòng: chặn cả lô');
select ok(pg_temp.msg($$select app.import_leads((select jsonb_agg(jsonb_build_object('parent_name', 'X', 'parent_phone', '09' || lpad(g::text, 8, '0'))) from generate_series(1, 501) g), false, (select d from dft))$$) like '%501%500%',
          'Câu báo quá dòng nêu số dòng và mức tối đa');
select is((select count(*)::int from app.lead where parent_phone in ('0900000501', '0900000504', '0900000540', '0900000550')), 0, 'Chưa có lead nào của lô thử');

-- ================= Xem trước =================
create temp table prev as select app.import_leads((select r from rows10), false, (select d from dft), 'thu.csv') as p;
grant select on prev to public;
select is((select (p ->> 'mode') || '/' || (p ->> 'total') || '/' || (p ->> 'imported') || '/' || (p ->> 'duplicates') || '/' || (p ->> 'errors') from prev), 'XEM_TRUOC/10/2/3/5',
          'Xem trước: 10 dòng, 2 hợp lệ, 3 trùng, 5 lỗi');
select is((select pg_temp.res(p, 2) ->> 'status' from prev), 'HOP_LE', 'Dòng đủ thông tin: hợp lệ');
select ok((select pg_temp.res(p, 2) ->> 'code' like 'LD%' from prev), 'Dòng hợp lệ có mã lead sẽ cấp');
select is((select pg_temp.res(p, 3) ->> 'status' from prev), 'LOI', 'Thiếu họ tên phụ huynh: lỗi');
select ok((select pg_temp.res(p, 3) ->> 'message' like '%họ tên phụ huynh%' from prev), 'Lỗi thiếu họ tên: câu tiếng Việt nêu rõ ô thiếu');
select is((select pg_temp.res(p, 4) ->> 'status' from prev), 'LOI', 'SĐT sai: lỗi');
select ok((select pg_temp.res(p, 4) ->> 'message' like '%10 số%' from prev), 'Lỗi SĐT: câu tiếng Việt');
select is((select pg_temp.res(p, 5) ->> 'status' from prev), 'HOP_LE', 'Nguồn ở dòng ghi đè mặc định, nguồn không có kênh con thì không cần kênh; SĐT +84 chuẩn hoá');
select is((select pg_temp.res(p, 6) ->> 'status' from prev), 'LOI', 'Loại nguồn không khớp nguồn: lỗi');
select is((select pg_temp.res(p, 7) ->> 'status' from prev), 'LOI', 'Năm sinh không phải số: lỗi');
select ok((select pg_temp.res(p, 7) ->> 'message' like '%Năm sinh%' from prev), 'Lỗi năm sinh: câu tiếng Việt');
select is((select pg_temp.res(p, 8) ->> 'status' || '/' || (pg_temp.res(p, 8) ->> 'code') from prev), 'TRUNG/' || (select code from app.lead where parent_phone = '0900000530'), 'Trùng SĐT với lead có sẵn: bỏ qua, nêu mã lead');
select ok((select pg_temp.res(p, 8) ->> 'message' like 'Trùng với LD%' from prev), 'Câu báo trùng: "Trùng với <mã>"');
select is((select pg_temp.res(p, 9) ->> 'status' || '/' || (pg_temp.res(p, 9) ->> 'code') from prev), 'TRUNG/PH900031', 'Trùng SĐT với phụ huynh có sẵn: bỏ qua, nêu mã phụ huynh');
select is((select pg_temp.res(p, 10) ->> 'status' || '/' || (pg_temp.res(p, 10) ->> 'code') from prev), 'TRUNG/' || (select pg_temp.res(p, 2) ->> 'code' from prev), 'Trùng SĐT với dòng trước trong file: bỏ qua, nêu mã dòng trước');
select is((select pg_temp.res(p, 11) ->> 'status' from prev), 'LOI', 'Email nhân viên không có: lỗi');
select ok((select pg_temp.res(p, 11) ->> 'message' like '%khong.co@%' from prev), 'Lỗi email nhân viên: nêu email');
select is((select count(*)::int from app.lead where parent_phone in ('0900000501', '0900000504')), 0, 'Xem trước không ghi gì (hoàn tác toàn bộ)');
select is((select count(*)::int from app.lead_import_log), 0, 'Xem trước không ghi nhật ký nhập');

-- ================= Nhập thật: khớp xem trước =================
create temp table runr as select app.import_leads((select r from rows10), true, (select d from dft), 'thu.csv') as p;
grant select on runr to public;
select is((select (p ->> 'mode') || '/' || (p ->> 'total') || '/' || (p ->> 'imported') || '/' || (p ->> 'duplicates') || '/' || (p ->> 'errors') from runr), 'NHAP/10/2/3/5',
          'Nhập thật: tổng kết khớp xem trước');
select is((select jsonb_agg(r - 'message' order by (r ->> 'row')::integer) from jsonb_array_elements((select p -> 'rows' from runr)) r),
          (select jsonb_agg(r - 'message' order by (r ->> 'row')::integer) from jsonb_array_elements((select p -> 'rows' from prev)) r),
          'Từng dòng (trạng thái, mã) của nhập thật y hệt xem trước: cùng một đường mã, mã không nhảy số');
select is((select count(*)::int from app.lead where parent_phone in ('0900000501', '0900000504')), 2, 'Chỉ hai dòng hợp lệ được nhập');
select is((select count(*)::int from app.lead where parent_phone in ('0900000502', '12345', '0900000505', '0900000506', '0900000510')), 0, 'Dòng lỗi không được nhập');
select is((select count(*)::int from app.lead where parent_phone = '0900000501'), 1, 'Dòng trùng trong file không nhập thêm');
select is((select array[stage_code, source_type_code, source_code, coalesce(channel_code, 'trống'), (campaign_id = pg_temp.camp())::text, owner_id::text, need]
             from app.lead where parent_phone = '0900000501'),
          array['C1', 'MARKETING', 'FACEBOOK_ADS', 'FACEBOOK_ADS_LEAD_FORM', 'true', pg_temp.uid('sales1')::text, 'Học Toán 9'],
          'Lead nhập: giai đoạn C1, nguồn, kênh, chiến dịch mặc định, người phụ trách là người nhập, nhu cầu từ cột ghi chú');
select is((select array[student_name, student_birth_year::text] from app.lead where parent_phone = '0900000501'), array['Em Một', '2012'], 'Tên, năm sinh học sinh được ghi');
select is((select array[source_code, coalesce(channel_code, 'trống')] from app.lead where parent_phone = '0900000504'), array['WEBSITE', 'trống'], 'Nguồn ở dòng ghi đè nguồn mặc định');
select is((select code from app.lead where parent_phone = '0900000501'), (select p -> 'rows' -> 0 ->> 'code' from runr), 'Mã lead đã nhập đúng mã báo ở kết quả');
select is((select count(*)::int from app.lead_import_log), 1, 'Nhập thật ghi một dòng nhật ký nhập');
select is((select array[file_name, rows_total::text, imported_count::text, duplicate_count::text, error_count::text, importer_id::text] from app.lead_import_log),
          array['thu.csv', '10', '2', '3', '5', pg_temp.uid('sales1')::text], 'Nhật ký nhập: tên file, số liệu, người nhập');
select is(pg_temp.err($$insert into app.lead_import_log (importer_id, branch_id, rows_total, imported_count, duplicate_count, error_count) values (gen_random_uuid(), gen_random_uuid(), 0, 0, 0, 0)$$), '42501', 'Không ghi thẳng bảng nhật ký nhập');
select is(pg_temp.err($$select app.import_one_lead('{}'::jsonb, '{}'::jsonb)$$), '42501', 'Giao diện không gọi hàm nội bộ nhập một dòng');
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is((select count(*)::int from app.lead_import_log), 0, 'Người khác không đọc nhật ký nhập của người nhập');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((select count(*)::int from app.lead_import_log), 1, 'Admin đọc mọi nhật ký nhập');

-- ================= Cột email sale, nhập 500 dòng, Admin chọn cơ sở =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((app.import_leads(jsonb_build_array(jsonb_build_object('parent_name', 'Chị Giao', 'parent_phone', '0900000540', 'owner_email', 'sales1b@ts.hoamatoan.invalid')),
          false, (select d from dft)) -> 'rows' -> 0 ->> 'status'), 'HOP_LE', 'Email sale cùng cơ sở (người nhập có quyền Giao việc): hợp lệ');
select is(pg_temp.err($$select app.import_leads(jsonb_build_array(jsonb_build_object('parent_name', 'Chị Giao', 'parent_phone', '0900000540', 'owner_email', 'sales1b@ts.hoamatoan.invalid')), true, (select d from dft))$$), null, 'Nhập dòng có email sale');
select is((select owner_id from app.lead where parent_phone = '0900000540'), pg_temp.uid('sales1b'), 'Người phụ trách theo email trong file');
select is((app.import_leads(jsonb_build_array(jsonb_build_object('parent_name', 'Chị Khác Cơ Sở', 'parent_phone', '0900000541', 'owner_email', 'sales5@ts.hoamatoan.invalid')),
          false, (select d from dft)) -> 'rows' -> 0 ->> 'status'), 'LOI', 'Email sale của cơ sở khác: lỗi');
select is((select (app.import_leads((select jsonb_agg(jsonb_build_object('parent_name', 'Chị ' || g, 'parent_phone', '0910' || lpad(g::text, 6, '0'))) from generate_series(1, 500) g),
          true, (select d from dft), 'lon.csv') ->> 'imported')::int), 500, 'Nhập đúng 500 dòng (mức tối đa): được, trong một giao dịch');
select is((select count(*)::int from app.lead where parent_phone like '0910%'), 500, '500 lead đã vào');
select is((select imported_count from app.lead_import_log where file_name = 'lon.csv'), 500, 'Nhật ký ghi 500 dòng nhập');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.import_leads(jsonb_build_array(jsonb_build_object('parent_name', 'Chị CS5', 'parent_phone', '0900000550')), false,
          (select d from dft) || jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5'))) -> 'rows' -> 0 ->> 'status'), 'LOI',
          'Admin nhập vào CS5 mà không chọn người phụ trách của CS5: lỗi (người nhập ở CS1)');
select is((app.import_leads(jsonb_build_array(jsonb_build_object('parent_name', 'Chị CS5', 'parent_phone', '0900000550')), false,
          (select d from dft) || jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5'), 'owner_id', pg_temp.uid('sales5'))) -> 'rows' -> 0 ->> 'status'), 'HOP_LE',
          'Admin chọn cơ sở CS5 và người phụ trách của CS5: hợp lệ');
select is((app.import_leads(jsonb_build_array(jsonb_build_object('parent_name', 'Chị CS5', 'parent_phone', '0900000550')), true,
          (select d from dft) || jsonb_build_object('branch_id', (select id from app.branch where code = 'CS5'), 'owner_id', pg_temp.uid('sales5'))) ->> 'imported')::int, 1, 'Admin nhập vào CS5');
select is((select branch_id from app.lead where parent_phone = '0900000550'), (select id from app.branch where code = 'CS5'), 'Lead nhập vào đúng cơ sở Admin chọn');

select * from finish();
rollback;
