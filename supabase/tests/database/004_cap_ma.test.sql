-- Luật cấp mã (docs/spec/02 mục "Mã các đối tượng"; bảng đếm khoá dòng, không nhảy số).
begin;
create extension if not exists pgtap with schema extensions;
create extension if not exists dblink with schema extensions;
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
-- Hàm mới mặc định không cấp quyền chạy cho ai (migration 014): cấp cho hàm trợ giúp của bài kiểm thử.
grant execute on all functions in schema pg_temp to public;

-- ---------- Mẫu mã đúng spec 02 ----------
select matches(app.issue_person_code('HS'), '^HS[0-9]{6}$', 'Mã học sinh: HS + 6 số');
select matches(app.issue_person_code('PH'), '^PH[0-9]{6}$', 'Mã phụ huynh: PH + 6 số');
select matches(app.issue_person_code('NV'), '^NV[0-9]{4}$', 'Mã nhân viên: NV + 4 số');
select matches(app.issue_person_code('GV'), '^GV2[0-9]{3}$', 'Mã giáo viên: GV + số 2xxx');
select matches(app.issue_person_code('TG'), '^TG8[0-9]{3}$', 'Mã trợ giảng: TG + số 8xxx');
select is(pg_temp.err($$select app.issue_person_code('XX')$$), 'HMT_LOAI_MA_SAI', 'Không cấp mã cho loại người lạ');

select is(app.issue_class_code('CS5', '2627', 'TOAN', 'K08', 'CB', 'A'), 'CS5-2627-TOAN-K08-CB-A-001',
          'Mã lớp chung: CS-Năm-Môn-Khối-Phânloại-Trìnhđộ-STT');
select is(app.issue_class_code('CS5', '2627', 'TOAN', 'K08', 'CB', 'A'), 'CS5-2627-TOAN-K08-CB-A-002',
          'Mã lớp: STT tăng trong cùng tổ hợp');
select is(app.issue_class_code('CS5', '2627', 'TOAN', 'K08', 'CB', 'B'), 'CS5-2627-TOAN-K08-CB-B-001',
          'Mã lớp: STT đếm riêng từng tổ hợp');
select is(app.issue_class_code('CS2', '2627', 'TOAN', 'K09', 'LR'), 'CS2-2627-TOAN-K09-LR-001',
          'Mã lớp riêng: không có trình độ');
select is(pg_temp.err($$select app.issue_class_code('CS2', '2627', 'TOAN', 'K09', 'LR', 'A')$$),
          'HMT_MA_LOP_SAI', 'Lớp riêng không được có trình độ');
select is(pg_temp.err($$select app.issue_class_code('CS2', '2627', 'TOAN', 'K09', 'CB')$$),
          'HMT_MA_LOP_SAI', 'Lớp cơ bản phải có trình độ');
select is(pg_temp.err($$select app.issue_class_code('CS9', '2627', 'TOAN', 'K09', 'CB', 'A')$$),
          'HMT_DANH_MUC_KHONG_CO', 'Không cấp mã lớp cho cơ sở không có (CS9)');
select is(pg_temp.err($$select app.issue_class_code('CS3', '2627', 'TOAN', 'K09', 'CB', 'A')$$),
          'HMT_CO_SO_VAN_PHONG', 'Không cấp mã lớp cho Hội sở (văn phòng)');
select is(pg_temp.err($$select app.issue_class_code('CS1', '2627', 'TOAN', 'K13', 'CB', 'A')$$),
          'HMT_DANH_MUC_KHONG_CO', 'Không cấp mã lớp cho khối không có');

select is(app.build_framework_code('TOAN', 'K03', 'CB', '2627'), 'TOAN-K03-CB-2627', 'Mã khung: Môn-Khối-Cấpđộ-Năm');
select is(app.build_framework_code('TOAN', 'K03', 'CB', '2627', 2), 'TOAN-K03-CB-2627-V2', 'Mã khung bản sửa: thêm -V2');
select is(app.build_lesson_code('TOAN-K03-CB-2627', 5), 'TOAN-K03-CB-2627-B05', 'Mã bài: mã khung + B + 2 số');
select is(app.build_package_code('LC', 'TOAN', 'K09', 'OFF'), 'LC-TOAN-K09-OFF', 'Mã gói: Loại-Môn-Khối-Hìnhthức');
select is(pg_temp.err($$select app.build_package_code('LC', 'DAI', 'K09', 'OFF')$$),
          'HMT_GOI_KHONG_TACH_DAI_HINH', 'Gói không có môn Đại số/Hình học riêng');

select is(app.issue_document_number('PT', 'CS1', timestamptz '2026-10-31 23:30+07'), 'PT-CS1-2610-0001',
          'Mã chứng từ: Loại-CS-NămTháng-STT');
select is(app.issue_document_number('PT', 'CS1', timestamptz '2026-10-31 23:45+07'), 'PT-CS1-2610-0002',
          'Chứng từ: STT liên tục trong tháng');
select is(app.issue_document_number('PT', 'CS2', timestamptz '2026-10-15 10:00+07'), 'PT-CS2-2610-0001',
          'Chứng từ: STT riêng từng cơ sở');
select is(app.issue_document_number('PT', 'CS1', timestamptz '2026-10-31 17:30+00'), 'PT-CS1-2611-0001',
          'Chứng từ: tháng tính theo giờ Việt Nam (00:30 ngày 1/11 giờ VN là tháng 11)');
select is(app.issue_document_number('DH', 'CS1', timestamptz '2026-10-15 10:00+07'), 'DH-CS1-2610-0001',
          'Chứng từ: STT riêng từng loại');
select is(app.issue_document_number('DN', 'CS5', timestamptz '2026-10-15 10:00+07'), 'DN-CS5-2610-0001',
          'Mã ticket đề nghị: DN-CS-NămTháng-STT (R-CS-01)');
select is(app.issue_document_number('KN', 'CS5', timestamptz '2026-10-15 10:00+07'), 'KN-CS5-2610-0001',
          'Mã ticket khiếu nại: KN-CS-NămTháng-STT, đếm riêng với DN');
select is(pg_temp.err($$select app.issue_document_number('XX', 'CS1')$$),
          'HMT_DANH_MUC_KHONG_CO', 'Không cấp số cho loại chứng từ lạ');

-- ---------- Không dùng lại số, bộ đếm không lùi, không xoá ----------
select is(pg_temp.err($$update app.code_counter set last_value = 0 where counter_key = 'HS'$$),
          'HMT_MA_KHONG_LUI', 'Bộ đếm không lùi số được');
select is(pg_temp.err($$delete from app.code_counter where counter_key = 'HS'$$),
          'HMT_KHONG_XOA', 'Không xoá được bộ đếm');
select is(pg_temp.err($$update app.code_format set pad_width = 3 where code = 'HS'$$),
          'HMT_LUAT_LOI', 'Định dạng mã chỉ đổi qua migration');

-- ---------- Không mở cho API ----------
set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select is(pg_temp.err($$select app.issue_person_code('HS')$$), '42501',
          'Qua API không tự xin mã được (chỉ hàm nghiệp vụ cấp trong cùng giao dịch)');
reset role;
select set_config('request.jwt.claims', '', true);

-- ---------- Hai giao dịch xin mã cùng lúc: không trùng, liên tiếp ----------
-- Dùng dblink mở 2 kết nối thật. Tháng 2099-01 để không đụng số khác; các kết nối này
-- commit thật vào DB local (db reset sẽ dọn).
-- Kết nối qua địa chỉ mạng của máy chủ (không qua 127.0.0.1, nơi Supabase cho vào không cần
-- mật khẩu và dblink từ chối với người dùng thường).
create temp table conn as
  select format('dbname=postgres user=postgres password=postgres host=%s port=%s',
                host(inet_server_addr()), inet_server_port()) as s;
select dblink_connect('c1', (select s from conn));
select dblink_connect('c2', (select s from conn));

select dblink_exec('c1', 'begin');
create temp table r1 as
  select * from dblink('c1', $q$select app.issue_document_number('PT', 'CS5', timestamptz '2099-01-15 10:00+07')$q$) as t(code text);
-- c2 xin mã trong lúc c1 chưa xong: phải chờ khoá dòng.
select dblink_send_query('c2', $q$select app.issue_document_number('PT', 'CS5', timestamptz '2099-01-15 10:00+07')$q$);
select dblink_exec('c1', 'commit');
create temp table r2 as select * from dblink_get_result('c2') as t(code text);
select dblink_get_result('c2');

select isnt((select code from r1), (select code from r2), 'Xin mã cùng lúc: hai giao dịch không bị trùng mã');
select is(right((select code from r2), 4)::int, right((select code from r1), 4)::int + 1,
          'Xin mã cùng lúc: hai số liền nhau');

-- ---------- Giao dịch huỷ thì số được trả lại (không nhảy số) ----------
select dblink_exec('c1', 'begin');
create temp table r3 as
  select * from dblink('c1', $q$select app.issue_document_number('PT', 'CS5', timestamptz '2099-01-15 10:00+07')$q$) as t(code text);
select dblink_exec('c1', 'rollback');
create temp table r4 as
  select * from dblink('c2', $q$select app.issue_document_number('PT', 'CS5', timestamptz '2099-01-15 10:00+07')$q$) as t(code text);
select is((select code from r4), (select code from r3), 'Giao dịch huỷ: số chưa dùng được cấp lại, không nhảy số');

select dblink_disconnect('c1');
select dblink_disconnect('c2');

-- ---------- Luật lõi loại buổi ----------
select ok(app.session_type_deducts_hours('CHINH'), 'Buổi chính trừ giờ');
select ok(app.session_type_deducts_hours('CUNG_CO'), 'Buổi củng cố trừ giờ');
select ok(not app.session_type_deducts_hours('HOC_BU'), 'Học bù không trừ giờ');
select ok(not app.session_type_deducts_hours('BO_TRO'), 'Học bổ trợ không trừ giờ');
select is(pg_temp.err($$select app.session_type_deducts_hours('NGHI')$$), 'HMT_LOAI_BUOI_SAI',
          'Không có loại buổi "nghỉ" (huỷ là tình trạng buổi)');

select * from finish();
rollback;
