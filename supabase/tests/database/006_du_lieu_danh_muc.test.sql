-- Dữ liệu danh mục nạp bằng migration khớp docs/spec/02 và các chốt ngày 10/10/2026.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.codes(p_catalog text) returns text[] language sql as $$
  select array_agg(code order by sort_order) from app.catalog_item where catalog_code = p_catalog;
$$;

-- Cơ sở, năm học.
select is((select array_agg(code order by sort_order) from app.branch), array['CS1', 'CS2', 'CS4', 'CS5', 'CS3'],
          'Cơ sở: CS1, CS2, CS4, CS5 dạy học; CS3 là Hội sở (chốt 11/10/2026)');
select is((select count(*)::int from app.branch where is_office), 0, 'Không cơ sở nào là văn phòng (CS3 thành cơ sở dạy học từ 04/11/2026, Đ286)');
select is((select name from app.branch where code = 'CS5'), 'Mỹ Đình', 'CS5 là Mỹ Đình');
select is((select array[start_date, end_date] from app.academic_year where code = '2627'),
          array[date '2026-06-01', date '2027-05-31'], 'Năm học 2627: 01/06/2026 – 31/05/2027');

-- Danh mục hệ thống.
select is(pg_temp.codes('STUDENT_STATUS'), array['TIEM_NANG', 'DANG_HOC', 'BAO_LUU', 'DUNG_HOC'], 'Tình trạng học sinh đúng spec 02');
select is(pg_temp.codes('ENROLLMENT_STATUS'),
          array['CHO_XEP_LOP', 'DANG_HOC', 'DA_XEP_LOP', 'BAO_LUU', 'HOAN_THANH', 'CHUYEN_LOP', 'DUNG', 'HOAN_PHI'], 'Tình trạng ghi danh đúng spec 02');
select is(pg_temp.codes('ATTENDANCE_STATUS'), array['CO_MAT', 'DI_MUON', 'VANG_CO_PHEP', 'VANG_KHONG_PHEP'], 'Điểm danh đúng spec 02');
select is(pg_temp.codes('SESSION_TYPE'), array['CHINH', 'CUNG_CO', 'HOC_BU', 'BO_TRO', 'KIEM_TRA'], 'Loại buổi: chính, củng cố, học bù, bổ trợ, kiểm tra (R-V2-18, Q-176)');
select is(pg_temp.codes('CLASS_TYPE'), array['CB', 'NC', 'LR'], 'Phân loại lớp CB, NC, LR');
select is(pg_temp.codes('STUDY_MODE'), array['OFF', 'ONL'], 'Hình thức OFF, ONL');
select is(pg_temp.codes('DOC_TYPE'), array['BG', 'DH', 'PT', 'PC', 'DN', 'KN', 'KTV', 'YB'], 'Loại chứng từ BG, DH, PT, PC, KTV (khoản tiền vào, B2), ticket DN, KN (R-CS-01) và yêu cầu buổi YB (migration 139)');
select is(pg_temp.codes('HOMEWORK_STATUS'), array['DA_CHAM', 'LAM_CHUA_XONG', 'KHONG_LAM', 'NOP_SAU', 'KHONG_AP_DUNG'],
          'Trạng thái BTVN đúng R-GV-11');
select is(pg_temp.codes('MODULE'), array['BAN_HANG', 'VAN_HANH_LOP', 'CONG_GIAO_VIEN', 'HOC_TAP', 'BAO_CAO', 'YEU_CAU_BUOI', 'DIEM_DANH_TRONG_NGAY'], 'Phân hệ cho công tắc (thêm YEU_CAU_BUOI, migration 139; DIEM_DANH_TRONG_NGAY, migration 143)');
select is((select count(*)::int from app.catalog where kind = 'HE_THONG'), 31, '31 danh mục hệ thống (migration 100, D1a: thêm Tình trạng duyệt của lớp, Tình trạng buổi học; migration 084, Q-122: thêm Giai đoạn con lead, Giai đoạn con cơ hội, chỉ đổi tên; B2: thêm Trạng thái phiếu thu; P5a-DB1b-1: thêm Trạng thái đơn hàng; P5a-DB1a: thêm Trạng thái báo giá; P5a-DB0: thêm Đơn vị tính của gói; PR 6c: thêm Giai đoạn phiếu tái tục, Nhóm đề nghị; PR 6b: thêm Loại gói, Mức độ khiếu nại; PR 6a: thêm Môn, Khối, Trình độ, Giai đoạn lead, Giai đoạn cơ hội; trước đó bước 3: PERM_MODULE, PERM_ACTION, PERM_SCOPE; bước 4b: NOTIFICATION_KIND)');
select is((select kind from app.catalog where code = 'HOMEWORK_STATUS'), 'HE_THONG', 'Trạng thái BTVN là danh mục hệ thống (không thêm bớt)');

-- Danh mục mở theo spec 02.
select is(pg_temp.codes('SUBJECT'), array['TOAN', 'DAI', 'HINH', 'LY', 'HOA', 'VAN', 'ANH', 'KHTN', 'TRUNG', 'SAT'], 'Môn đúng spec 02');
select is(pg_temp.codes('GRADE'), array['K02', 'K03', 'K04', 'K05', 'K06', 'K07', 'K08', 'K09', 'K10', 'K11', 'K12'], 'Khối K02–K12');
select is(pg_temp.codes('LEVEL'), array['S', 'A', 'B', 'C'], 'Trình độ S, A, B, C');
select is(pg_temp.codes('FRAMEWORK_LEVEL'), array['CB', 'NC'], 'Cấp độ khung CB, NC');

-- Nguồn 3 tầng.
select is((select count(*)::int from app.catalog_item where catalog_code = 'SOURCE_TYPE'), 6, 'Nguồn: 6 loại');
select is((select count(*)::int from app.catalog_item where catalog_code = 'SOURCE'), 11, 'Nguồn: 11 nguồn');
select is((select count(*)::int from app.catalog_item where catalog_code = 'SOURCE_CHANNEL'), 14, 'Nguồn: 14 kênh');
select is((select p.code from app.catalog_item c join app.catalog_item p on p.id = c.parent_id
            where c.catalog_code = 'SOURCE' and c.code = 'HOTLINE'), 'MARKETING', 'Hotline thuộc Marketing (chốt 10/10)');
select ok(exists (select from app.catalog_item where catalog_code = 'SOURCE' and code = 'BAN_GIAM_DOC'), 'Có nguồn Ban Giám Đốc');

-- Giai đoạn lead, cơ hội (chốt 10/10: L2A đổi tên, bỏ L3H cũ, L3I cũ thành L3H).
select is((select count(*)::int from app.catalog_item where catalog_code = 'LEAD_SUBSTAGE'), 15, 'Giai đoạn con lead: 15');
select is((select name from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L2A'), 'Không nghe máy', 'L2A = Không nghe máy');
select is((select name from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L3H'), 'Không nghe máy nhiều lần',
          'L3H mới = Không nghe máy nhiều lần');
select is((select legacy_ref from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L3H'), 'L3I', 'L3H mới có mã cũ L3I');
select ok(not exists (select from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L3I'), 'Không còn L3I');
select is((select count(*)::int from app.catalog_item where catalog_code = 'OPP_SUBSTAGE'), 62, 'Giai đoạn con cơ hội: 62 (49 + L5Q + L4E–H + L7M–S + L6G, Config 04/11; L5P, L5Q Ngừng)');

-- Lý do huỷ test nối với L5x.
select is((select count(*)::int from app.catalog_item r join app.catalog_item l on l.id = r.linked_item_id
            where r.catalog_code = 'TEST_CANCEL_REASON' and l.catalog_code = 'OPP_SUBSTAGE' and l.code like 'L5%'),
          12, 'Cả 12 lý do huỷ test có nối nối với giai đoạn con L5x (11 + L5Q; "Tạo phiếu sai" không nối)');

-- Loại hoạt động.
select is(pg_temp.codes('ACTIVITY_TYPE'), array['GOI_DIEN', 'ZALO', 'EMAIL', 'GAP_TRUC_TIEP', 'SMS', 'NHAC_THU_TIEN'], 'Loại hoạt động');

-- Tỉnh, phường.
select is((select count(*)::int from app.catalog_item where catalog_code = 'PROVINCE'), 34, '34 tỉnh, thành');
select is((select count(*)::int from app.catalog_item w join app.catalog_item p on p.id = w.parent_id
            where w.catalog_code = 'WARD' and p.code = 'HA_NOI'), 126, 'Hà Nội: 126 phường, xã');
select is((select count(*)::int from app.catalog_item where catalog_code = 'WARD' and name like 'Phường %'), 51, 'Hà Nội: 51 phường');
select is((select count(*)::int from app.catalog_item where catalog_code = 'WARD' and name like 'Xã %'), 75, 'Hà Nội: 75 xã');

-- Nạp dữ liệu không để lại "cửa sau" cho danh mục hệ thống.
select is(coalesce(current_setting('hmt.migration', true), ''), '', 'Sau migration, cờ hmt.migration đã tắt');

select * from finish();
rollback;
