-- Luật 16/10/2026: danh mục giai đoạn cơ hội và danh mục 33 "Lý do bỏ qua test".
-- Nguồn: docs/spec/06 mục 1.3 và danh mục 33; docs/spec/04 R-CRM-13, R-CRM-15.
--
-- NGOẠI LỆ MỘT LẦN so với nguyên tắc "mã không đổi nghĩa": L6A–L6F đổi nghĩa (đánh lại A–F, bỏ nhóm con
-- "chưa có kết quả") và L6G bị xoá cứng. Chỉ làm được vì hệ thống chưa chạy thật, chưa có cơ hội nào mang các mã
-- này. Từ lúc chạy thật, mã giai đoạn con không đổi nghĩa nữa: đổi bằng thêm mã mới và Ngừng mã cũ.

select set_config('hmt.migration', 'on', false);

-- Kiểm trước: chưa có bản ghi nào trỏ tới các mã L6 sắp đổi hoặc xoá (mục cha, mục nối).
do $$
declare
  v_refs integer;
begin
  select count(*) into v_refs
  from app.catalog_item i
  join app.catalog_item l6 on l6.catalog_code = 'OPP_SUBSTAGE' and l6.code like 'L6%'
  where i.parent_id = l6.id or i.linked_item_id = l6.id;
  if v_refs > 0 then
    raise exception 'HMT_L6_CON_THAM_CHIEU: còn % mục trỏ tới nhóm con L6, không đổi được.', v_refs;
  end if;
end;
$$;

-- L5B theo spec 06 mục 1.3 (chốt 12/10): "Đã xếp lịch test".
update app.catalog_item set name = 'Đã xếp lịch test'
where catalog_code = 'OPP_SUBSTAGE' and code = 'L5B';

-- R-CRM-15: nhóm con L5P, hệ thống tự gắn; không nối danh mục lý do huỷ test (13). Xếp ngay sau L5B.
update app.catalog_item set sort_order = sort_order + 1
where catalog_code = 'OPP_SUBSTAGE'
  and sort_order > (select sort_order from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L5B');

insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id)
select 'OPP_SUBSTAGE', 'L5P', 'Đã làm bài, chờ giáo viên chấm',
       (select sort_order + 1 from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L5B'),
       (select id from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5');

-- R-CRM-13: L6 đánh lại A–F. Mã cũ L6B…L6G dời nghĩa lên một bậc, L6G bỏ.
update app.catalog_item i set name = v.name
from (values
  ('L6A', 'Có kết quả, cần phân loại'),
  ('L6B', 'Học xuất sắc'),
  ('L6C', 'Học tốt'),
  ('L6D', 'Học khá'),
  ('L6E', 'Học trung bình'),
  ('L6F', 'Học yếu')
) as v(code, name)
where i.catalog_code = 'OPP_SUBSTAGE' and i.code = v.code;

-- Xoá L6G (xoá cứng một lần; trigger chặn xoá được tắt đúng trong câu này).
alter table app.catalog_item disable trigger catalog_item_no_delete;
delete from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L6G';
alter table app.catalog_item enable trigger catalog_item_no_delete;

-- Xếp lại thứ tự liền mạch cho các nhóm con (L5P chen vào, L6G đã bỏ).
update app.catalog_item i set sort_order = r.n
from (select id, row_number() over (order by sort_order, code) as n
      from app.catalog_item where catalog_code = 'OPP_SUBSTAGE') r
where i.id = r.id and i.sort_order <> r.n;

-- Danh mục 33 "Lý do bỏ qua test" (R-CRM-14): danh mục mở; "Khác" bắt buộc ghi chú do hàm đổi giai đoạn kiểm.
insert into app.catalog (code, name, kind, parent_catalog, linked_catalog, description, sort_order) values
  ('TEST_SKIP_REASON', 'Lý do bỏ qua test', 'MO', null, null,
   'Bắt buộc chọn khi bấm tay L7, L8 mà cơ hội không có phiếu test hoặc mọi phiếu đều Huỷ/Từ chối (R-CRM-14).', 25);

insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('TEST_SKIP_REASON', 'HOC_SINH_CU', 'Học sinh cũ đã biết trình độ', 1),
  ('TEST_SKIP_REASON', 'PH_KHONG_MUON', 'Phụ huynh không muốn test', 2),
  ('TEST_SKIP_REASON', 'CO_KET_QUA_NOI_KHAC', 'Đã có kết quả test nơi khác', 3),
  ('TEST_SKIP_REASON', 'KHAC', 'Khác', 4);

select set_config('hmt.migration', '', false);
