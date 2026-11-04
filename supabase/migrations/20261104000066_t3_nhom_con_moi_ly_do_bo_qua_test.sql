-- T3: nhóm con mới L4E–L4H và L7M–L7S (Config mới 04/11/2026), đổi danh mục 33 "Lý do bỏ qua test" thành BQ1–BQ5.
-- Nguồn: docs/spec/04 mục 14 (R-V2, anh Trường chốt 04/11, Đ285); danh mục 33: tên BQ1–BQ5 anh Trường đưa 04/11.
-- Không đổi mã, không đổi nghĩa mã nào đã có. L5B, L5P, L5Q, L6A–L6F KHÔNG đổi ở đây: lệch Config mới, chờ anh quyết.

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Nhóm con L4E–L4H (giai đoạn L4 "Khách hàng tiềm năng"): xếp ngay sau L4D.
-- ---------------------------------------------------------------------------
update app.catalog_item set sort_order = sort_order + 4
where catalog_code = 'OPP_SUBSTAGE'
  and sort_order > (select sort_order from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L4D');

insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id)
select 'OPP_SUBSTAGE', v.code, v.name,
       (select sort_order from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L4D') + v.n,
       (select id from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L4')
from (values
  ('L4E', 'Tiềm năng, cần tư vấn thêm về chương trình', 1),
  ('L4F', 'Tiềm năng, cần trao đổi thêm về chi phí', 2),
  ('L4G', 'Tiềm năng, cần xử lý về địa điểm học', 3),
  ('L4H', 'Tiềm năng, cần trao đổi thêm về lịch học', 4)
) v(code, name, n);

-- ---------------------------------------------------------------------------
-- Nhóm con L7M–L7S (giai đoạn L7 "Tư vấn"): xếp ngay sau L7L.
-- ---------------------------------------------------------------------------
update app.catalog_item set sort_order = sort_order + 7
where catalog_code = 'OPP_SUBSTAGE'
  and sort_order > (select sort_order from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L7L');

insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id)
select 'OPP_SUBSTAGE', v.code, v.name,
       (select sort_order from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L7L') + v.n,
       (select id from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L7')
from (values
  ('L7M', 'Đã tư vấn, PH từ chối về học phí', 1),
  ('L7N', 'Đã tư vấn, PH từ chối về chương trình học', 2),
  ('L7O', 'Đã tư vấn, PH từ chối về thời gian học', 3),
  ('L7P', 'Đã tư vấn, PH từ chối về hình thức học', 4),
  ('L7Q', 'Đã tư vấn, PH từ chối về địa điểm học', 5),
  ('L7R', 'Đã tư vấn, PH không có nhu cầu nữa', 6),
  ('L7S', 'Đã tư vấn, con không muốn học', 7)
) v(code, name, n);

-- ---------------------------------------------------------------------------
-- Danh mục 33 "Lý do bỏ qua test": năm giá trị mới BQ1–BQ5; BQ5 "Lý do khác" bắt buộc ghi chú (R-CRM-14).
-- Bốn giá trị cũ chuyển sang Ngừng (không xoá, vì phiếu bỏ qua test đã ghi có thể đang dùng); xếp sau năm giá trị mới.
-- ---------------------------------------------------------------------------
update app.catalog_item set sort_order = sort_order + 5
where catalog_code = 'TEST_SKIP_REASON';

update app.catalog_item set is_active = false
where catalog_code = 'TEST_SKIP_REASON' and code in ('HOC_SINH_CU', 'PH_KHONG_MUON', 'CO_KET_QUA_NOI_KHAC', 'KHAC');

insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note)
values
  ('TEST_SKIP_REASON', 'BQ1', 'PH từ chối làm bài test', 1, false),
  ('TEST_SKIP_REASON', 'BQ2', 'Học sinh đã có kết quả đánh giá trước đó', 2, false),
  ('TEST_SKIP_REASON', 'BQ3', 'Đã đủ thông tin trình độ qua trao đổi', 3, false),
  ('TEST_SKIP_REASON', 'BQ4', 'Ghi danh nhanh theo chương trình khuyến mãi', 4, false),
  ('TEST_SKIP_REASON', 'BQ5', 'Lý do khác', 5, true);

select set_config('hmt.migration', '', false);
