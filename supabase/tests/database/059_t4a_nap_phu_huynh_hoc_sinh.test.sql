-- T4a (migration 068; spec 04 R-V2-29, 30, 31): nạp dữ liệu cũ theo loại, Phụ huynh và Học sinh.
-- Mỗi luật có ca đúng và ca bị chặn. Dữ liệu giả (tên, SĐT bịa, không dùng dữ liệu thật).
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@t4a.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select id, 'Giả ' || key, key || '@t4a.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES')) v(k, role) on v.k = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

-- ================= Quyền: chỉ Admin (đã xác thực hai bước) =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select pg_temp.imp('PHU_HUYNH', '[{"ma_cu":"X","ho_ten":"A","sdt":"0900000001","co_so":"CS5"}]')$$),
          'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không được nạp dữ liệu cũ');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select pg_temp.imp('PHU_HUYNH', '[{"ma_cu":"X","ho_ten":"A","sdt":"0900000001","co_so":"CS5"}]')$$),
          'HMT_KHONG_CO_QUYEN', 'Chặn: Admin chưa xác thực hai bước không được nạp');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select pg_temp.imp('LOP', '[{"ma_cu":"X"}]')$$), 'HMT_LOAI_NAP_SAI', 'Chặn: loại nạp chưa hỗ trợ');
select is(pg_temp.err($$select pg_temp.imp('PHU_HUYNH', '[]')$$), 'HMT_THIEU_THONG_TIN', 'Chặn: không có dòng nào');
select is(pg_temp.err($$select pg_temp.imp('PHU_HUYNH', (select jsonb_agg(jsonb_build_object('ma_cu', 'Q' || g)) from generate_series(1, 1001) g))$$),
          'HMT_QUA_NHIEU_DONG', 'Chặn cả lô khi quá import_max_rows (1000)');

-- ================= Phụ huynh =================
-- Dòng 2..9: hợp lệ có SĐT thứ hai và người thân; hợp lệ tối thiểu; SĐT sai; thiếu tên; thiếu mã cũ; cơ sở không có; thiếu SĐT; SĐT +84.
create temp table ph_rows (rows jsonb);
insert into ph_rows values ('[
 {"row":2,"ma_cu":"PH-CU-1","ho_ten":"Khúc Văn Đặng","sdt":"0911111101","sdt_2":"0911111102","ho_ten_2":"Khúc Thị Bà","dia_chi":"Số 9 phố Mẫu","co_so":"CS5"},
 {"row":3,"ma_cu":"PH-CU-2","ho_ten":"Lương Quý Hiền","sdt":"0911111103","co_so":"cs5"},
 {"row":4,"ma_cu":"PH-CU-3","ho_ten":"Mạc Đình Sơn","sdt":"091111","co_so":"CS5"},
 {"row":5,"ma_cu":"PH-CU-4","sdt":"0911111104","co_so":"CS5"},
 {"row":6,"ho_ten":"Ninh Thị Lan","sdt":"0911111105","co_so":"CS5"},
 {"row":7,"ma_cu":"PH-CU-6","ho_ten":"Ông Văn Tư","sdt":"0911111106","co_so":"CS9"},
 {"row":8,"ma_cu":"PH-CU-7","ho_ten":"Phan Quang Vinh","co_so":"CS5"},
 {"row":9,"ma_cu":"PH-CU-8","ho_ten":"Quách Hữu Thọ","sdt":"+84911111107","co_so":"CS5"}]');

select is((select (pg_temp.imp('PHU_HUYNH', rows) ->> 'imported')::int from ph_rows), 3, 'Xem trước phụ huynh: 3 dòng hợp lệ');
select is((select count(*)::int from app.parent where legacy_ref like 'PH-CU-%'), 0, 'Xem trước không ghi gì');
select is((select count(*)::int from app.import_log), 0, 'Xem trước không ghi nhật ký nạp');

create temp table res1 (r jsonb);
insert into res1 select pg_temp.imp('PHU_HUYNH', rows, true, 'ph-cs5-mau.xlsx') from ph_rows;
select is((select array[r ->> 'imported', r ->> 'duplicates', r ->> 'errors'] from res1), array['3', '0', '5'], 'Nạp phụ huynh: 3 hợp lệ, 0 trùng, 5 lỗi');
select is((select array[pg_temp.st(r, 2), pg_temp.st(r, 3), pg_temp.st(r, 4), pg_temp.st(r, 5), pg_temp.st(r, 6), pg_temp.st(r, 7), pg_temp.st(r, 8), pg_temp.st(r, 9)] from res1),
          array['HOP_LE', 'HOP_LE', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'HOP_LE'], 'Mỗi dòng đúng trạng thái; dòng lỗi không chặn dòng hợp lệ');
select is((select array[phone, phone_2, relative_name, address, legacy_ref, (select code from app.branch where id = branch_id)]
             from app.parent where legacy_ref = 'PH-CU-1'),
          array['0911111101', '0911111102', 'Khúc Thị Bà', 'Số 9 phố Mẫu', 'PH-CU-1', 'CS5'], 'Phụ huynh nạp đủ SĐT, SĐT thứ hai, người thân, địa chỉ, mã cũ, cơ sở');
select ok((select code ~ '^PH[0-9]{6}$' from app.parent where legacy_ref = 'PH-CU-1'), 'Mã phụ huynh cấp tự động theo chuẩn');
select is((select phone from app.parent where legacy_ref = 'PH-CU-7' or phone = '0911111107'), '0911111107', 'SĐT +84 được chuẩn hoá về 10 số');
select is(pg_temp.hs((select r from res1), 4, 'message'), 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.', 'SĐT sai: câu lỗi tiếng Việt, không in số');
select is(pg_temp.hs((select r from res1), 7, 'message'), 'Mã cơ sở không có thật.', 'co_so không có thật: bị chặn');
select is((select count(*)::int from app.import_log where kind = 'PHU_HUYNH' and imported_count = 3 and error_count = 5 and file_name = 'ph-cs5-mau.xlsx'), 1,
          'Nạp thật ghi một dòng nhật ký nạp với số liệu');

-- Nạp lại: dòng đã nạp thành TRUNG, không ghi đè.
update app.parent set full_name = 'Khúc Văn Đặng (đã sửa tay)' where legacy_ref = 'PH-CU-1';
create temp table res2 (r jsonb);
insert into res2 select pg_temp.imp('PHU_HUYNH', rows, true) from ph_rows;
select is((select array[r ->> 'imported', r ->> 'duplicates', r ->> 'errors'] from res2), array['0', '3', '5'], 'Nạp lại: dòng đã nạp thành TRUNG, không nạp lần hai');
select is((select full_name from app.parent where legacy_ref = 'PH-CU-1'), 'Khúc Văn Đặng (đã sửa tay)', 'Nạp lại không ghi đè hồ sơ có sẵn');
select is((select count(*)::int from app.parent where legacy_ref like 'PH-CU-%'), 3, 'Nạp lại không nhân đôi hồ sơ');
select is(pg_temp.hs((select r from res2), 2, 'code'), (select code from app.parent where legacy_ref = 'PH-CU-1'), 'Dòng TRUNG nêu mã hồ sơ có sẵn');

-- Trùng SĐT (kể cả SĐT thứ hai): TRUNG, không tự gộp.
create temp table res3 (r jsonb);
insert into res3 select pg_temp.imp('PHU_HUYNH', '[
 {"row":2,"ma_cu":"PH-CU-20","ho_ten":"Zeta số chính","sdt":"0911111103","co_so":"CS5"},
 {"row":3,"ma_cu":"PH-CU-21","ho_ten":"Zeta số thứ hai của hồ sơ","sdt":"0911111102","co_so":"CS5"},
 {"row":4,"ma_cu":"PH-CU-22","ho_ten":"Zeta số thứ hai trùng số chính","sdt":"0911118888","sdt_2":"0911111101","co_so":"CS5"},
 {"row":5,"ma_cu":"PH-CU-23","ho_ten":"Zeta dòng mới","sdt":"0911112222","sdt_2":"0911113333","co_so":"CS5"},
 {"row":6,"ma_cu":"PH-CU-24","ho_ten":"Zeta dòng trước trong file","sdt":"0911113333","co_so":"CS5"}]', true);
select is((select array[pg_temp.st(r, 2), pg_temp.st(r, 3), pg_temp.st(r, 4), pg_temp.st(r, 5), pg_temp.st(r, 6)] from res3),
          array['TRUNG', 'TRUNG', 'TRUNG', 'HOP_LE', 'TRUNG'], 'R-V2-04: trùng SĐT chính, SĐT thứ hai, hoặc dòng trước trong file thì TRUNG');
select is((select count(*)::int from app.parent where legacy_ref in ('PH-CU-20', 'PH-CU-21', 'PH-CU-22', 'PH-CU-24')), 0, 'Dòng TRUNG không tạo hồ sơ, không tự gộp');
select is((select count(*)::int from app.parent where merged_into_id is not null and legacy_ref like 'PH-CU-%'), 0, 'Không có hồ sơ nào bị gộp');

-- ================= Học sinh =================
create temp table hs_rows (rows jsonb);
insert into hs_rows values ('[
 {"row":2,"ma_cu":"M-HS-1","ho_ten":"Đoàn Bảo An","ngay_sinh":"2016-05-10","gioi_tinh":"Nam","sdt_ph":"0911111101","truong":"Trường Mẫu 1","loai_truong":"Công lập","khoi":"4","ghi_chu":"Mục tiêu mẫu","co_so":"CS5"},
 {"row":3,"ma_cu":"M-HS-2","ho_ten":"Đoàn Bảo Châu","ngay_sinh":"2012-02-02","gioi_tinh":"Nữ","sdt_ph":"0911111102","khoi":"8","co_so":"CS5"},
 {"row":4,"ma_cu":"M-HS-3","ho_ten":"Em Không Phụ Huynh","ngay_sinh":"2014-01-01","sdt_ph":"0988877766","khoi":"6","co_so":"CS5"},
 {"row":5,"ma_cu":"M-HS-4","ho_ten":"Em Khối Không","ngay_sinh":"2014-01-01","sdt_ph":"0911111101","khoi":"0","co_so":"CS5"},
 {"row":6,"ma_cu":"M-HS-5","ho_ten":"Em Khối Mười Ba","ngay_sinh":"2014-01-01","sdt_ph":"0911111101","khoi":"13","co_so":"CS5"},
 {"row":7,"ma_cu":"M-HS-6","ho_ten":"Em Khối Chữ","ngay_sinh":"2014-01-01","sdt_ph":"0911111101","khoi":"lớp ba","co_so":"CS5"},
 {"row":8,"ma_cu":"M-HS-7","ho_ten":"Em Thiếu Ngày Sinh","sdt_ph":"0911111101","khoi":"5","co_so":"CS5"},
 {"row":9,"ma_cu":"M-HS-8","ho_ten":"Em Ngày Sinh Sai Dạng","ngay_sinh":"10/05/2016","sdt_ph":"0911111101","khoi":"5","co_so":"CS5"},
 {"row":10,"ma_cu":"M-HS-9","ho_ten":"Em Ngày Sinh Không Có","ngay_sinh":"2016-02-30","sdt_ph":"0911111101","khoi":"5","co_so":"CS5"},
 {"row":11,"ma_cu":"M-HS-10","ho_ten":"Em Sinh Tương Lai","ngay_sinh":"2999-01-01","sdt_ph":"0911111101","khoi":"5","co_so":"CS5"},
 {"row":12,"ma_cu":"M-HS-11","ho_ten":"Em Giới Tính Lạ","ngay_sinh":"2014-01-01","gioi_tinh":"Khác","sdt_ph":"0911111101","khoi":"5","co_so":"CS5"},
 {"row":13,"ma_cu":"M-HS-12","ho_ten":"Em Cơ Sở Lạ","ngay_sinh":"2014-01-01","sdt_ph":"0911111101","khoi":"5","co_so":"CS7"},
 {"row":14,"ma_cu":"M-HS-13","ho_ten":"Em Thiếu SĐT Phụ Huynh","ngay_sinh":"2014-01-01","khoi":"5","co_so":"CS5"},
 {"row":15,"ma_cu":"M-HS-14","ho_ten":"Em Khối Mười Hai","ngay_sinh":"2008-03-03","sdt_ph":"0911111103","khoi":"12","co_so":"CS5"}]');
create temp table res4 (r jsonb);
insert into res4 select pg_temp.imp('HOC_SINH', rows, true, 'hs-cs5-mau.xlsx') from hs_rows;
select is((select array[r ->> 'imported', r ->> 'duplicates', r ->> 'errors'] from res4), array['3', '0', '11'], 'Nạp học sinh: 3 hợp lệ, 11 lỗi');
select is((select array[pg_temp.st(r, 2), pg_temp.st(r, 3), pg_temp.st(r, 4), pg_temp.st(r, 5), pg_temp.st(r, 6), pg_temp.st(r, 7),
                        pg_temp.st(r, 8), pg_temp.st(r, 9), pg_temp.st(r, 10), pg_temp.st(r, 11), pg_temp.st(r, 12), pg_temp.st(r, 13),
                        pg_temp.st(r, 14), pg_temp.st(r, 15)] from res4),
          array['HOP_LE', 'HOP_LE', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'LOI', 'HOP_LE'], 'Học sinh: khối 1–12, ngày sinh, giới tính, cơ sở, SĐT phụ huynh được kiểm từng dòng');
select is((select array[s.full_name is not null, s.grade::text, s.gender, s.school_type, s.school, s.goal, s.birth_year::text, s.birth_date::text, s.legacy_ref,
                        (select code from app.branch where id = s.branch_id), (p.legacy_ref)]::text[]
             from app.student s join app.parent p on p.id = s.parent_id where s.legacy_ref = 'M-HS-1'),
          array['true', '4', 'NAM', 'Công lập', 'Trường Mẫu 1', 'Mục tiêu mẫu', '2016', '2016-05-10', 'M-HS-1', 'CS5', 'PH-CU-1']::text[],
          'Học sinh nạp đủ khối, giới tính, loại trường, trường, mục mục tiêu, năm sinh, mã cũ, gắn đúng phụ huynh');
select is((select gender from app.student where legacy_ref = 'M-HS-2'), 'NU', 'Giới tính Nữ lưu NU');
select is((select p.legacy_ref from app.student s join app.parent p on p.id = s.parent_id where s.legacy_ref = 'M-HS-2'), 'PH-CU-1', 'Phụ huynh khớp theo SĐT thứ hai');
select is((select grade::int from app.student where legacy_ref = 'M-HS-14'), 12, 'Khối 12 được nhận');
select is(pg_temp.hs((select r from res4), 4, 'message'), 'Không khớp phụ huynh nào theo số điện thoại; nạp phụ huynh trước.', 'sdt_ph không khớp: LOI, câu lỗi không in số');
select is((select count(*)::int from app.parent where phone = '0988877766'), 0, 'Không tự tạo phụ huynh khi sdt_ph không khớp');
select is(pg_temp.hs((select r from res4), 5, 'message'), 'Khối cần là số từ 1 đến 12.', 'Khối 0 bị chặn');
select is(pg_temp.hs((select r from res4), 6, 'message'), 'Khối cần là số từ 1 đến 12.', 'Khối 13 bị chặn');

-- Nạp lại ĐÚNG cùng file học sinh: 3 dòng đã nạp thành TRUNG (bỏ qua), 11 dòng lỗi vẫn lỗi, không ghi đè, không tạo trùng.
update app.student set school = 'Trường đã sửa tay lần một' where legacy_ref = 'M-HS-1';
create temp table res4b (r jsonb);
insert into res4b select pg_temp.imp('HOC_SINH', rows, true) from hs_rows;
select is((select array[r ->> 'imported', r ->> 'duplicates', r ->> 'errors'] from res4b), array['0', '3', '11'],
          'Nạp lại cùng file học sinh: 0 nạp, 3 bỏ qua (TRUNG), 11 lỗi như cũ');
select is((select array[pg_temp.st(r, 2), pg_temp.st(r, 3), pg_temp.st(r, 15)] from res4b), array['TRUNG', 'TRUNG', 'TRUNG'], 'Ba học sinh đã nạp thành TRUNG khi nạp lại');
select is((select count(*)::int from app.student where legacy_ref like 'M-HS-%'), 3, 'Nạp lại cùng file không tạo học sinh trùng');
select is((select school from app.student where legacy_ref = 'M-HS-1'), 'Trường đã sửa tay lần một', 'Nạp lại cùng file không ghi đè học sinh có sẵn');

-- Nạp lại: trùng mã cũ thì bỏ qua, không ghi đè; cùng phụ huynh + tên + năm sinh với mã cũ khác cũng TRUNG.
update app.student set school = 'Trường đã sửa tay' where legacy_ref = 'M-HS-1';
create temp table res5 (r jsonb);
insert into res5 select pg_temp.imp('HOC_SINH', '[
 {"row":2,"ma_cu":"M-HS-1","ho_ten":"Tên khác hẳn","ngay_sinh":"2015-01-01","sdt_ph":"0911111101","truong":"Trường mới","khoi":"5","co_so":"CS5"},
 {"row":3,"ma_cu":"M-HS-99","ho_ten":"Đoàn Bảo Châu","ngay_sinh":"2012-12-12","sdt_ph":"0911111101","khoi":"8","co_so":"CS5"},
 {"row":4,"ma_cu":"M-HS-98","ho_ten":"Đoàn Thêm Mới","ngay_sinh":"2013-03-03","sdt_ph":"0911111101","khoi":"7","co_so":"CS5"}]', true);
select is((select array[pg_temp.st(r, 2), pg_temp.st(r, 3), pg_temp.st(r, 4)] from res5), array['TRUNG', 'TRUNG', 'HOP_LE'],
          'Học sinh: trùng mã cũ và trùng (phụ huynh, tên, năm sinh) là TRUNG; học sinh mới vẫn nạp');
select is((select school from app.student where legacy_ref = 'M-HS-1'), 'Trường đã sửa tay', 'Nạp lại không ghi đè học sinh có sẵn');
select is((select count(*)::int from app.student where legacy_ref in ('M-HS-99')), 0, 'Dòng trùng không tạo hồ sơ');

-- ================= Quyền riêng tư: kết quả, thông báo lỗi và nhật ký nạp không chứa họ tên, SĐT, mã cũ =================
select is((select count(*)::int from (
             select r::text t from res1 union all select r::text from res2 union all select r::text from res3
             union all select r::text from res4 union all select r::text from res4b union all select r::text from res5) x
           where t ~ '(Khúc|Lương|Mạc|Ninh|Ông|Phan|Quách|Đoàn|Zeta|Em |0911|0988|\+84|PH-CU|M-HS|Trường Mẫu|Số 9 phố)'), 0,
          'Kết quả nạp không chứa họ tên, SĐT, mã cũ, trường, địa chỉ');
-- Chỉ quét các cột chữ (loại nạp, tên file). Trước đây quét cả dòng (l::text) nên chuỗi hex ngẫu nhiên của uuid có thể chứa "0911" và làm bài trượt chập chờn.
select is((select count(*)::int from app.import_log l where (l.kind || ' ' || coalesce(l.file_name, '')) ~ '(Khúc|Đoàn|0911|PH-CU|M-HS)'), 0, 'Nhật ký nạp không chứa họ tên, SĐT, mã cũ');
select is(pg_temp.hs((select r from res1), 3, 'label'), 'Dòng 3 (L.)', 'Dòng báo bằng số dòng và chữ cái đầu của tên');
select is(pg_temp.hs((select r from res1), 4, 'label'), 'Dòng 4 (M.)', 'Dòng lỗi cũng chỉ báo số dòng và chữ cái đầu');
select is(pg_temp.hs((select r from res1), 5, 'label'), 'Dòng 5 (?.)', 'Dòng không có tên báo dấu hỏi');
select is(pg_temp.hs((select r from res1), 2, 'initial'), 'K', 'Chữ cái đầu bỏ dấu, viết hoa');

select * from finish();
rollback;
