-- T3: nhóm con L4E–L4H, L7M–L7S; danh mục 33 thành BQ1–BQ5 (R-CRM-14).
begin;
select plan(9);

select is((select array_agg(code order by sort_order) from app.catalog_item
            where catalog_code = 'OPP_SUBSTAGE' and code like 'L4%'),
          array['L4A', 'L4B', 'L4C', 'L4D', 'L4E', 'L4F', 'L4G', 'L4H'],
          'L4 có thêm L4E–L4H, xếp liền sau L4D');
select is((select array_agg(code order by sort_order) from app.catalog_item
            where catalog_code = 'OPP_SUBSTAGE' and code like 'L7%'),
          array['L7A', 'L7B', 'L7C', 'L7D', 'L7E', 'L7F', 'L7G', 'L7H', 'L7I', 'L7K', 'L7L', 'L7M', 'L7N', 'L7O', 'L7P', 'L7Q', 'L7R', 'L7S'],
          'L7 có thêm L7M–L7S, xếp liền sau L7L');
select ok(not exists (select from app.catalog_item c join app.catalog_item p on p.id = c.parent_id
                       where c.catalog_code = 'OPP_SUBSTAGE' and c.code <> 'L5Q' and left(c.code, 2) <> p.code),
          'Mọi nhóm con thuộc đúng giai đoạn cha (L4E–H dưới L4, L7M–S dưới L7)');
select is((select count(distinct sort_order)::int from app.catalog_item where catalog_code = 'OPP_SUBSTAGE'),
          (select count(*)::int from app.catalog_item where catalog_code = 'OPP_SUBSTAGE'),
          'Thứ tự nhóm con không trùng sau khi thêm 11 nhóm con');
select is((select count(*)::int from app.catalog_item where catalog_code = 'OPP_SUBSTAGE'), 61,
          'Giai đoạn con cơ hội: 61 (50 + 4 + 7)');

select is((select array_agg(code order by sort_order) from app.catalog_item where catalog_code = 'TEST_SKIP_REASON' and is_active),
          array['BQ1', 'BQ2', 'BQ3', 'BQ4', 'BQ5'], 'R-CRM-14: danh mục 33 còn hiệu lực là BQ1–BQ5');
select is((select array_agg(code order by code) from app.catalog_item where catalog_code = 'TEST_SKIP_REASON' and not is_active),
          array['CO_KET_QUA_NOI_KHAC', 'HOC_SINH_CU', 'KHAC', 'PH_KHONG_MUON'], 'Bốn lý do cũ chuyển sang Ngừng, không xoá');
select is((select array_agg(code order by code) from app.catalog_item where catalog_code = 'TEST_SKIP_REASON' and requires_note and is_active),
          array['BQ5'], 'Chỉ BQ5 "Lý do khác" bắt buộc ghi chú');
select is((select name from app.catalog_item where catalog_code = 'TEST_SKIP_REASON' and code = 'BQ4'),
          'Ghi danh nhanh theo chương trình khuyến mãi', 'BQ4 đúng tên anh Trường chốt');

select * from finish();
rollback;
