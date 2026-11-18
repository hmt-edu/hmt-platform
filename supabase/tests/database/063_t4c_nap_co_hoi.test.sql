-- T4c (migration 072; spec 04 R-V2-29, 30, 31, 33): nạp Cơ hội (kèm phụ huynh, lead gốc, danh sách em, ghi chú). Dữ liệu giả.
-- Mỗi luật có ca đúng và ca bị chặn; kết quả không chứa họ tên, số điện thoại.
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
create function pg_temp.imp(p_rows jsonb, p_commit boolean default false)
returns jsonb language sql as $$ select app.import_records('CO_HOI', p_rows, p_commit, 'test.csv') $$;
create function pg_temp.st(p_res jsonb, p_row integer) returns text language sql as
  $$ select r ->> 'status' from jsonb_array_elements(p_res -> 'rows') r where (r ->> 'row')::integer = p_row $$;
create function pg_temp.msg(p_res jsonb, p_row integer) returns text language sql as
  $$ select r ->> 'message' from jsonb_array_elements(p_res -> 'rows') r where (r ->> 'row')::integer = p_row $$;
-- Một dòng hợp lệ mẫu; p_over là các khoá ghi đè (jsonb).
create function pg_temp.row(p_n integer, p_over jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object(
    'row', p_n, 'ma_cu', '0900' || lpad(p_n::text, 6, '0'), 'ngay_tao', '2026-09-15', 'ho_ten_ph', 'Zeta Quang ' || p_n,
    'sdt_ph', '0900' || lpad(p_n::text, 6, '0'), 'danh_sach_em', 'Em Một;Em Hai', 'nam_sinh', '2013;2015', 'khoi', '7', 'truong', 'THCS Thử',
    'nhu_cau', 'Học Toán', 'nguon_goc', 'Marketing', 'nguon', 'Facebook Ads', 'medium', 'Facebook Ads: Inbox', 'co_so', 'CS5',
    'nguoi_phu_trach', 'sale.cs5.t4c', 'nguoi_phu_trach_goc', 'Tên Gốc', 'tinh_trang_cu', 'Đã hẹn test', 'giai_doan', 'L2', 'ghi_chu', 'Khách quan tâm')
  || p_over $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1'), ('sale5'), ('sale1'), ('nghi5');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@t4c.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password, legacy_ref)
select u.id, 'Giả ' || u.key, u.key || '@t4c.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key in ('admin', 'sales1', 'sale1') then 'CS1' else 'CS5' end), false,
       case u.key when 'sale5' then 'sale.cs5.t4c' when 'sale1' then 'sale.cs1.t4c' when 'nghi5' then 'nghi.cs5.t4c' end
  from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES')) v(k, role) on v.k = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
update app.user_account set is_locked = true where id = (select id from u where key = 'nghi5');
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select pg_temp.imp(jsonb_build_array(pg_temp.row(2)))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không được nạp Cơ hội');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- ================= Danh mục =================
select is((select is_active from app.catalog_item where catalog_code = 'TEST_SKIP_REASON' and code = 'NAP_CU'), false,
          'Lý do bỏ qua test "Nạp dữ liệu cũ" ở trạng thái Ngừng (người dùng không chọn được)');

-- ================= Xem trước không ghi gì =================
create temp table pre as select (select count(*) from app.opportunity) o, (select count(*) from app.lead) l, (select count(*) from app.parent) p,
                                (select count(*) from app.import_log) g;
create temp table prev as select pg_temp.imp(jsonb_build_array(pg_temp.row(2))) r;
select is((select r ->> 'mode' from prev), 'XEM_TRUOC', 'Xem trước: chế độ XEM_TRUOC');
select is(pg_temp.st((select r from prev), 2), 'HOP_LE', 'Xem trước: dòng đúng là HOP_LE');
select is((select count(*) from app.opportunity), (select o from pre), 'Xem trước không tạo cơ hội');
select is((select count(*) from app.lead), (select l from pre), 'Xem trước không tạo lead');
select is((select count(*) from app.parent), (select p from pre), 'Xem trước không tạo phụ huynh');

-- ================= Luật từng dòng: đúng và bị chặn =================
create temp table rows_in (rows jsonb);
insert into rows_in select jsonb_build_array(
  pg_temp.row(2),                                                                                   -- hợp lệ, L2
  pg_temp.row(3, '{"ho_ten_ph":"Zeta Quang 3","nguoi_phu_trach":"khong.co.tai.khoan"}'),             -- người phụ trách chưa có tài khoản
  pg_temp.row(4, '{"nguoi_phu_trach":"sale.cs1.t4c"}'),                                             -- người phụ trách khác cơ sở
  pg_temp.row(5, '{"nguon_goc":"Loại lạ"}'),                                                        -- loại nguồn không có
  pg_temp.row(6, '{"nguon_goc":"Telemarketing","nguon":"Facebook Ads","medium":""}'),                  -- nguồn không thuộc loại Telemarketing
  pg_temp.row(7, '{"nguon_goc":"Telemarketing","nguon":"Cold Call","medium":""}'),                  -- nguồn có kênh mà thiếu kênh
  pg_temp.row(8, '{"medium":"Cold Call: Buy"}'),                                                    -- kênh không thuộc nguồn
  pg_temp.row(9, '{"giai_doan":"L9"}'),                                                             -- giai đoạn lạ
  pg_temp.row(10, '{"nhom_con":"L5B"}'),                                                            -- nhóm con không thuộc giai đoạn L2
  pg_temp.row(11, '{"giai_doan":"L5","nam_sinh":""}'),                                              -- L5 thiếu năm sinh
  pg_temp.row(12, '{"giai_doan":"L5","danh_sach_em":"","nam_sinh":""}'),                            -- L5 thiếu tên em
  pg_temp.row(13, '{"giai_doan":"L5"}'),                                                            -- L5 đủ tên và năm sinh: hợp lệ
  pg_temp.row(14, '{"danh_sach_em":"A;B;C;D;E;F","nam_sinh":""}'),                                  -- 6 em
  pg_temp.row(15, '{"nam_sinh":"20x3"}'),                                                           -- năm sinh sai
  pg_temp.row(16, '{"ngay_tao":"15/09/2026"}'),                                                     -- ngày sai dạng
  pg_temp.row(17, '{"ngay_tao":"2999-01-01"}'),                                                     -- ngày ở tương lai
  pg_temp.row(18, '{"giai_doan":"L7"}'),                                                            -- L7 hợp lệ (cần tên, năm sinh): lý do NAP_CU
  pg_temp.row(19, '{"sdt_ph":"091"}'),                                                              -- SĐT sai
  pg_temp.row(20, '{"co_so":"CS9"}'),                                                               -- cơ sở không có
  pg_temp.row(21, '{"ma_cu":""}'),                                                                  -- thiếu mã cũ
  pg_temp.row(22, '{"nguoi_phu_trach":"nghi.cs5.t4c"}'),                                            -- người nghỉ: hợp lệ kèm cảnh báo
  pg_temp.row(23, '{"danh_sach_em":"","nam_sinh":""}')                                              -- chưa có em, L2: hợp lệ
);
create temp table res as select pg_temp.imp((select rows from rows_in)) r;
select is(pg_temp.st((select r from res), 2), 'HOP_LE', 'Đúng: dòng hợp lệ L2');
select is(pg_temp.st((select r from res), 3), 'LOI', 'Chặn: người phụ trách chưa có tài khoản');
select is(pg_temp.msg((select r from res), 3), 'Người phụ trách chưa có tài khoản (nạp Người dùng trước).', 'Câu lỗi người phụ trách');
select is(pg_temp.st((select r from res), 4), 'LOI', 'Chặn: người phụ trách khác cơ sở');
select is(pg_temp.st((select r from res), 5), 'LOI', 'Chặn: loại nguồn không có');
select is(pg_temp.st((select r from res), 6), 'LOI', 'Chặn: nguồn không thuộc loại');
select is(pg_temp.st((select r from res), 7), 'LOI', 'Chặn: nguồn có kênh mà thiếu kênh');
select is(pg_temp.st((select r from res), 8), 'LOI', 'Chặn: kênh không thuộc nguồn');
select is(pg_temp.st((select r from res), 9), 'LOI', 'Chặn: giai đoạn lạ');
select is(pg_temp.st((select r from res), 10), 'LOI', 'Chặn: nhóm con không thuộc giai đoạn');
select is(pg_temp.st((select r from res), 11), 'HOP_LE', 'Ngoại lệ chỉ cho lượt nạp: L5 thiếu năm sinh em vẫn nạp');
select is(pg_temp.st((select r from res), 12), 'HOP_LE', 'Ngoại lệ chỉ cho lượt nạp: L5 thiếu tên em vẫn nạp');
select ok((select (r -> 'warnings') ->> 0 like 'Thiếu thông tin em (dữ liệu cũ)%' from jsonb_array_elements((select r from res) -> 'rows') r where (r ->> 'row')::integer = 11),
          'Cảnh báo: thiếu thông tin em (dữ liệu cũ)');
select is(pg_temp.st((select r from res), 13), 'HOP_LE', 'Đúng R-CRM-03: L5 đủ tên và năm sinh em');
select is(pg_temp.st((select r from res), 14), 'LOI', 'Chặn: quá 5 em');
select is(pg_temp.st((select r from res), 15), 'LOI', 'Chặn: năm sinh em sai');
select is(pg_temp.st((select r from res), 16), 'LOI', 'Chặn: ngày tạo sai dạng');
select is(pg_temp.st((select r from res), 17), 'LOI', 'Chặn: ngày tạo ở tương lai');
select is(pg_temp.st((select r from res), 18), 'HOP_LE', 'Đúng: L7 đủ tên và năm sinh em');
select is(pg_temp.st((select r from res), 19), 'LOI', 'Chặn: SĐT phụ huynh sai');
select is(pg_temp.st((select r from res), 20), 'LOI', 'Chặn: cơ sở không có thật');
select is(pg_temp.st((select r from res), 21), 'LOI', 'Chặn: thiếu mã cũ');
select is(pg_temp.st((select r from res), 22), 'HOP_LE', 'Đúng: người phụ trách đã nghỉ vẫn nạp');
select ok((select (r -> 'warnings') <> '[]'::jsonb from jsonb_array_elements((select r from res) -> 'rows') r where (r ->> 'row')::integer = 22),
          'Cảnh báo: người phụ trách đã nghỉ hoặc bị khoá');
select is(pg_temp.st((select r from res), 23), 'HOP_LE', 'Đúng: cơ hội L2 chưa có em vẫn nạp');
select is(((select r from res) ->> 'imported')::integer, 7, 'Đếm: 7 dòng hợp lệ (2, 11, 12, 13, 18, 22, 23)');
select is(((select r from res) ->> 'errors')::integer, 15, 'Đếm: 15 dòng lỗi');

-- ================= Không in dữ liệu cá nhân =================
select ok(position('Zeta' in (select r::text from res)) = 0, 'Kết quả không có họ tên phụ huynh (chỉ chữ cái đầu)');
select ok(position('0900' in (select r::text from res)) = 0, 'Kết quả không có số điện thoại');

-- ================= Nạp thật: ba thứ trong một giao dịch =================
create temp table pre2 as select (select count(*) from app.opportunity) o, (select count(*) from app.parent) p, (select count(*) from app.lead) l;
create temp table real as select pg_temp.imp((select rows from rows_in), true) r;
select is((select r ->> 'mode' from real), 'NHAP', 'Nạp thật: chế độ NHAP');
select is((select count(*) from app.opportunity) - (select o from pre2), (select (r ->> 'imported')::bigint from real), 'Nạp thật: số cơ hội mới bằng số dòng hợp lệ');
select is((select count(*) from app.lead) - (select l from pre2), (select (r ->> 'imported')::bigint from real), 'Nạp thật: mỗi cơ hội có một lead gốc mới');
select is((select count(*) from app.parent) - (select p from pre2), (select (r ->> 'imported')::bigint from real), 'Nạp thật: mỗi SĐT mới một phụ huynh mới');
select is((select stage_code || '/' || substage_code from app.lead where legacy_ref = '0900000002'), 'C4/C4D', 'Lead gốc về C4D Tạo cơ hội thành công');
select is((select stage_code from app.opportunity where legacy_ref = '0900000002'), 'L2', 'Cơ hội nạp thẳng đúng giai đoạn trong file');
select is((select stage_code from app.opportunity where legacy_ref = '0900000013'), 'L5', 'Cơ hội L5 nạp thẳng (bỏ qua luật chuyển giai đoạn)');
select is((select legacy_created_at from app.opportunity where legacy_ref = '0900000002'), date '2026-09-15', 'Ngày tạo cũ ở cột riêng legacy_created_at');
select is((select created_at::date from app.opportunity where legacy_ref = '0900000002'), current_date, 'created_at vẫn là lúc ghi thật, không bị ghi đè');
select is((select legacy_created_at from app.lead where legacy_ref = '0900000002'), date '2026-09-15', 'Lead gốc cũng giữ ngày tạo cũ ở cột riêng');
select is((select skip_reason_code from app.opportunity where legacy_ref = '0900000018'), 'NAP_CU', 'Cơ hội L7 ghi lý do bỏ qua test "Nạp dữ liệu cũ"');
select is((select skip_reason_code from app.opportunity where legacy_ref = '0900000002'), null, 'Cơ hội L2 không có lý do bỏ qua test');
select is((select count(*)::integer from app.prospect_student ps join app.opportunity o on o.id = ps.opportunity_id where o.legacy_ref = '0900000002'), 2,
          'Danh sách em: hai em của cơ hội');
select is((select full_name || '/' || birth_year from app.prospect_student ps join app.opportunity o on o.id = ps.opportunity_id
            where o.legacy_ref = '0900000002' and ps.position = 2), 'Em Hai/2015', 'Em thứ hai có năm sinh theo cột nam_sinh');
select is((select full_name from app.prospect_student ps join app.opportunity o on o.id = ps.opportunity_id where o.legacy_ref = '0900000002' and ps.position = 1), 'Em Một', 'Em đầu ghi vào danh sách em của cơ hội');
select is((select count(*)::integer from app.prospect_student ps join app.lead l on l.id = ps.lead_id where l.legacy_ref = '0900000002'), 2, 'Lead gốc cũng có danh sách em');
select is((select count(*)::integer from app.prospect_student ps join app.opportunity o on o.id = ps.opportunity_id where o.legacy_ref = '0900000023'), 0,
          'Cơ hội chưa có em: danh sách em trống');
select ok((select p.opportunity_import from app.parent p join app.opportunity o on o.parent_id = p.id where o.legacy_ref = '0900000002'),
          'Phụ huynh tạo từ nạp Cơ hội được đánh dấu để lần nạp Phụ huynh sau nối vào');
select is((select owner_id from app.opportunity where legacy_ref = '0900000002'), pg_temp.uid('sale5'), 'Người phụ trách tra theo tên đăng nhập (legacy_ref tài khoản)');
select ok((select body like '%Khách quan tâm%' and body like '%Tình trạng cũ: Đã hẹn test%' and body like '%Khối: 7%' from app.note n
            join app.opportunity o on o.id = n.entity_id where n.entity_type = 'OPPORTUNITY' and o.legacy_ref = '0900000002'),
          'Ghi chú gắn cơ hội: ghi chú gốc, tình trạng cũ, khối');
select is((select source_type_code || '/' || source_code || '/' || channel_code from app.opportunity where legacy_ref = '0900000002'),
          'MARKETING/FACEBOOK_ADS/FACEBOOK_ADS_INBOX', 'Nguồn ba tầng khớp theo tên với danh mục');
select is((select rows_total || '/' || imported_count from app.import_log where kind = 'CO_HOI' order by created_at desc limit 1),
          (select (r ->> 'total') || '/' || (r ->> 'imported') from real), 'Nhật ký nạp ghi số liệu, không ghi dữ liệu cá nhân');

-- ================= Dấu thiếu thông tin em, báo cáo sau nạp =================
select ok((select student_info_missing from app.opportunity where legacy_ref = '0900000011'), 'Cơ hội L5 thiếu năm sinh em có dấu thiếu thông tin em');
select ok((select student_info_missing from app.opportunity where legacy_ref = '0900000012'), 'Cơ hội L5 thiếu tên em có dấu thiếu thông tin em');
select is((select stage_code from app.opportunity where legacy_ref = '0900000012'), 'L5', 'Cơ hội thiếu thông tin em vẫn nằm đúng giai đoạn trong file');
select ok(not (select student_info_missing from app.opportunity where legacy_ref = '0900000013'), 'Cơ hội L5 đủ tên và năm sinh không bị đánh dấu');
select ok(not (select student_info_missing from app.opportunity where legacy_ref = '0900000023'), 'Cơ hội L2 chưa có em không bị đánh dấu (R-CRM-03 chỉ từ L5)');
select is((select birth_year from app.prospect_student ps join app.opportunity o on o.id = ps.opportunity_id where o.legacy_ref = '0900000011' and ps.position = 1), null,
          'Không suy năm sinh từ khối: năm sinh để trống');
select is((select r -> 'summary' ->> 'missing_student_info' from real), '2', 'Báo cáo: 2 dòng thiếu thông tin em');
select is((select r -> 'summary' ->> 'attached_parent' from real), '0', 'Báo cáo: số dòng gắn vào phụ huynh có sẵn');
select is((select r -> 'summary' -> 'by_stage' ->> 'L5' from real), '3', 'Báo cáo: 3 cơ hội L5 (11, 12, 13)');
select is((select r -> 'summary' -> 'by_stage' ->> 'L2' from real), '3', 'Báo cáo: 3 cơ hội L2 (2, 22, 23)');
select ok(position('Zeta' in (select (r -> 'summary')::text from real)) = 0, 'Báo cáo chỉ có số lượng, không có họ tên');
-- Cơ hội còn thiếu thông tin em không sang bước tiếp theo được; luật R-CRM-03 vẫn chặn cơ hội thường lên L5 khi chưa có em.
select is(pg_temp.err($$select app.change_opportunity_stage((select id from app.opportunity where legacy_ref = '0900000011'), 'L6', 'L6C')$$),
          'HMT_THIEU_THONG_TIN_EM', 'Chặn: cơ hội thiếu thông tin em không sang bước tiếp theo');
select is(pg_temp.err($$select app.change_opportunity_stage((select id from app.opportunity where legacy_ref = '0900000011'), 'L7', 'L7B', 'BQ1')$$),
          'HMT_THIEU_THONG_TIN_EM', 'Chặn: cơ hội thiếu thông tin em không tư vấn tiếp (tiến tới ghi danh)');
select is(pg_temp.err($$select app.change_opportunity_stage((select id from app.opportunity where legacy_ref = '0900000011'), 'L7', 'L7M', 'BQ1')$$),
          null, 'Đóng cơ hội (PH từ chối L7M) luôn được, kể cả còn dấu thiếu thông tin em');
select ok((select student_info_missing from app.opportunity where legacy_ref = '0900000011'), 'Đóng cơ hội không gỡ dấu thiếu thông tin em');
select is(pg_temp.err($$select app.change_opportunity_stage((select id from app.opportunity where legacy_ref = '0900000023'), 'L5')$$),
          'HMT_THIEU_HOC_SINH', 'R-CRM-03 giữ nguyên cho cơ hội thường: lên L5 khi chưa có em bị chặn');
-- Bổ sung đủ tên và năm sinh em đầu thì dấu tự gỡ.
insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_year)
select o.id, o.branch_id, 1, 'Em Bổ Sung', 2012 from app.opportunity o where o.legacy_ref = '0900000012';
select ok(not (select student_info_missing from app.opportunity where legacy_ref = '0900000012'), 'Bổ sung đủ tên và năm sinh em: dấu thiếu thông tin em tự gỡ');

-- ================= Nạp lại đúng file: toàn bỏ qua =================
create temp table again as select pg_temp.imp((select rows from rows_in), true) r;
select is(((select r from again) ->> 'imported')::integer, 0, 'Nạp lại cùng file: không còn dòng nào nạp mới');
select is(pg_temp.st((select r from again), 2), 'TRUNG', 'Nạp lại: dòng đã nạp báo TRUNG, bỏ qua, không ghi đè');
select is((select count(*) from app.opportunity where legacy_ref = '0900000002'), 1::bigint, 'Nạp lại không nhân đôi cơ hội');

-- ================= Gắn vào phụ huynh có sẵn (kèm cảnh báo) =================
select pg_temp.imp('[]'::jsonb) where false;
insert into app.parent (code, full_name, phone, branch_id) values (app.issue_person_code('PH'), 'Phụ huynh có sẵn giả', '0911000777', (select id from app.branch where code = 'CS5'));
create temp table attach as select pg_temp.imp(jsonb_build_array(pg_temp.row(30, '{"ma_cu":"0911000777","sdt_ph":"0911000777"}')), true) r;
select is(pg_temp.st((select r from attach), 30), 'HOP_LE', 'SĐT trùng phụ huynh có sẵn: vẫn nạp cơ hội');
select ok((select (r -> 'warnings') ->> 0 like 'Gắn vào phụ huynh có sẵn (mã PH%' from jsonb_array_elements((select r from attach) -> 'rows') r where (r ->> 'row')::integer = 30),
          'Cảnh báo: gắn vào phụ huynh có sẵn, nêu mã hồ sơ');
select is((select count(*)::integer from app.parent where phone = '0911000777'), 1, 'Không tạo phụ huynh trùng');
select is((select p.phone from app.opportunity o join app.parent p on p.id = o.parent_id where o.legacy_ref = '0911000777'), '0911000777', 'Cơ hội gắn đúng phụ huynh có sẵn');
select is((select opportunity_import from app.parent where phone = '0911000777'), false, 'Phụ huynh có sẵn không bị đánh dấu nạp Cơ hội');

select * from finish();
rollback;
