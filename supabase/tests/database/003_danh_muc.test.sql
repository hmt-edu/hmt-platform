-- Luật danh mục (docs/spec/02, docs/nghiep-vu/nen-du-lieu.md mục Danh mục).
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

-- ---------- Mã không đổi được ----------
select is(pg_temp.err($$update app.catalog_item set code = 'TOAN2' where catalog_code = 'SUBJECT' and code = 'TOAN'$$),
          'HMT_MA_KHONG_DOI_DUOC', 'Không đổi được mã mục danh mục');
select is(pg_temp.err($$update app.branch set code = 'CS9' where code = 'CS1'$$),
          'HMT_MA_KHONG_DOI_DUOC', 'Không đổi được mã cơ sở');
select is(pg_temp.err($$update app.academic_year set code = '2728' where code = '2627'$$),
          'HMT_MA_KHONG_DOI_DUOC', 'Không đổi được mã năm học');
select is(pg_temp.err($$update app.catalog set code = 'MON' where code = 'SUBJECT'$$),
          'HMT_MA_KHONG_DOI_DUOC', 'Không đổi được mã danh mục');

-- ---------- Không xoá được ----------
select is(pg_temp.err($$delete from app.branch where code = 'CS1'$$), 'HMT_KHONG_XOA', 'Không xoá được cơ sở');
select is(pg_temp.err($$delete from app.catalog_item where catalog_code = 'SUBJECT' and code = 'TOAN'$$),
          'HMT_KHONG_XOA', 'Không xoá được mục danh mục mở');
select is(pg_temp.err($$delete from app.catalog_item where catalog_code = 'STUDENT_STATUS' and code = 'DANG_HOC'$$),
          'HMT_KHONG_XOA', 'Không xoá được mục danh mục hệ thống');
select is(pg_temp.err($$delete from app.academic_year where code = '2627'$$), 'HMT_KHONG_XOA', 'Không xoá được năm học');

-- ---------- Danh mục hệ thống: chỉ đổi tên, thứ tự ----------
select is(pg_temp.err($$update app.catalog_item set name = 'Đang theo học', sort_order = 9
                        where catalog_code = 'STUDENT_STATUS' and code = 'DANG_HOC'$$),
          null, 'Danh mục hệ thống: đổi được tên hiển thị và thứ tự');
select is(pg_temp.err($$insert into app.catalog_item (catalog_code, code, name) values ('STUDENT_STATUS', 'MOI', 'Mới')$$),
          'HMT_DANH_MUC_HE_THONG', 'Danh mục hệ thống: không thêm mục được');
select is(pg_temp.err($$select app.catalog_add_item('SESSION_TYPE', 'THU', 'Buổi thử')$$),
          'HMT_DANH_MUC_HE_THONG', 'Danh mục hệ thống: hàm thêm mục cũng bị chặn');
select is(pg_temp.err($$update app.catalog_item set is_active = false where catalog_code = 'STUDENT_STATUS' and code = 'BAO_LUU'$$),
          'HMT_DANH_MUC_HE_THONG', 'Danh mục hệ thống: không Ngừng được');
select is(pg_temp.err($$insert into app.catalog (code, name, kind) values ('MOI', 'Danh mục mới', 'MO')$$),
          'HMT_DANH_MUC_HE_THONG', 'Thêm danh mục mới phải qua migration');
select is(pg_temp.err($$update app.catalog set kind = 'MO' where code = 'STUDENT_STATUS'$$),
          'HMT_DANH_MUC_HE_THONG', 'Không đổi danh mục hệ thống thành danh mục mở được');

-- ---------- Danh mục mở: thêm, đổi tên, thứ tự, Ngừng ----------
select ok(app.catalog_add_item('ACTIVITY_TYPE', 'HOP_ONLINE', 'Họp online') is not null,
          'Danh mục mở: thêm được mục');
select is(pg_temp.err($$select app.catalog_set_item_active(app.catalog_item_id('ACTIVITY_TYPE', 'SMS'), false)$$),
          null, 'Danh mục mở: Ngừng được mục');
select is((select is_active from app.catalog_item where catalog_code = 'ACTIVITY_TYPE' and code = 'SMS'),
          false, 'Mục đã Ngừng vẫn còn trong bảng (không xoá)');
select is(pg_temp.err($$select app.catalog_add_item('ACTIVITY_TYPE', 'GOI_DIEN', 'Trùng mã')$$),
          '23505', 'Danh mục mở: không thêm được mã trùng');
select is(pg_temp.err($$select app.catalog_add_item('ACTIVITY_TYPE', 'gọi điện', 'Sai mã')$$),
          '23514', 'Danh mục mở: mã phải viết hoa, không dấu');
select is(pg_temp.err($$select app.assert_catalog_code_active('ACTIVITY_TYPE', 'SMS')$$),
          'HMT_DANH_MUC_KHONG_CO', 'Mục đã Ngừng không dùng được cho dữ liệu mới');

-- ---------- Mục bị khoá ----------
update app.catalog_item set is_locked = true where catalog_code = 'OPP_STAGE' and code = 'L5';
select is(pg_temp.err($$update app.catalog_item set is_active = false where catalog_code = 'OPP_STAGE' and code = 'L5'$$),
          'HMT_MUC_BI_KHOA', 'Mục bị khoá (luật code bám vào) không Ngừng được');

-- ---------- Nhiều tầng: mục cha đúng danh mục cha ----------
select is(pg_temp.err($$select app.catalog_add_item('OPP_SUBSTAGE', 'L9A', 'Thiếu mục cha')$$),
          'HMT_MUC_CHA_SAI', 'Danh mục 2 tầng: mục con phải có mục cha');
select is(pg_temp.err($$select app.catalog_add_item('OPP_SUBSTAGE', 'L9A', 'Cha sai danh mục', null,
                                                    app.catalog_item_id('LEAD_STAGE', 'C1'))$$),
          'HMT_MUC_CHA_SAI', 'Danh mục 2 tầng: mục cha phải thuộc đúng danh mục cha');
select is(pg_temp.err($$select app.catalog_add_item('OPP_SUBSTAGE', 'L1A', 'Con của L1', null,
                                                    app.catalog_item_id('OPP_STAGE', 'L1'))$$),
          null, 'Danh mục 2 tầng: thêm mục con đúng cha được');
select is(pg_temp.err($$select app.catalog_add_item('SUBJECT', 'XYZ', 'Môn có cha', null,
                                                    app.catalog_item_id('GRADE', 'K02'))$$),
          'HMT_MUC_CHA_SAI', 'Danh mục 1 tầng không có mục cha');

-- ---------- Mục nối: lý do huỷ test → giai đoạn con L5x ----------
select is(pg_temp.err($$select app.catalog_add_item('TEST_CANCEL_REASON', 'X1', 'Nối sai', null, null,
                                                    app.catalog_item_id('LEAD_SUBSTAGE', 'C2A'))$$),
          'HMT_MUC_NOI_SAI', 'Lý do huỷ test chỉ nối được với giai đoạn con của cơ hội');

-- ---------- Ghi qua API bị chặn ở bước 2 ----------
set local role authenticated;
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select is(pg_temp.err($$select app.catalog_add_item('ACTIVITY_TYPE', 'API_THU', 'Thử qua API')$$),
          'HMT_KHONG_CO_QUYEN', 'Qua API: chưa có quyền sửa danh mục (bước 3 mở theo ma trận quyền)');
select is(pg_temp.err($$update app.catalog_item set name = 'x' where code = 'TOAN'$$),
          '42501', 'Qua API: không ghi thẳng vào bảng danh mục được');
select ok((select count(*) from app.catalog_item where catalog_code = 'SUBJECT') > 0,
          'Qua API: người đã đăng nhập đọc được danh mục');
reset role;
select set_config('request.jwt.claims', '', true);

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is(pg_temp.err($$select count(*) from app.catalog_item$$), '42501', 'Khách chưa đăng nhập không đọc được danh mục');
reset role;
select set_config('request.jwt.claims', '', true);

-- ---------- Phòng học ----------
select is(pg_temp.err($$insert into app.room (branch_id, code, name) select id, 'P101', 'Trùng' from app.branch where code = 'CS1'
                        union all select id, 'P101', 'Trùng' from app.branch where code = 'CS1'$$),
          '23505', 'Phòng: mã không trùng trong một cơ sở');
select is(pg_temp.err($$insert into app.room (branch_id, code, name) select id, 'P999', 'Phòng thử' from app.branch where code = 'CS2'$$),
          null, 'Phòng: thêm phòng cho cơ sở được');
select is(pg_temp.err($$update app.room set branch_id = (select id from app.branch where code = 'CS1')
                        where code = 'P999'$$),
          'HMT_MA_KHONG_DOI_DUOC', 'Phòng: không chuyển sang cơ sở khác được');

-- ---------- Ngày nghỉ ----------
insert into app.holiday (holiday_date, name) values (date '2030-01-01', 'Nghỉ chung thử');
insert into app.holiday (holiday_date, name, branch_id) select date '2030-01-02', 'Nghỉ CS5 thử', id from app.branch where code = 'CS5';
select ok(app.is_holiday(date '2030-01-01', (select id from app.branch where code = 'CS1')), 'Ngày nghỉ chung áp cho mọi cơ sở');
select ok(app.is_holiday(date '2030-01-02', (select id from app.branch where code = 'CS5')), 'Ngày nghỉ riêng áp cho đúng cơ sở');
select ok(not app.is_holiday(date '2030-01-02', (select id from app.branch where code = 'CS1')), 'Ngày nghỉ riêng không áp cho cơ sở khác');

select * from finish();
rollback;
