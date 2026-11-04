-- Luật 16/10: nhóm con L5P, L6 đánh lại A–F (R-CRM-13, R-CRM-15), danh mục 33 "Lý do bỏ qua test" (R-CRM-14).
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
create function pg_temp.name_of(p_code text) returns text language sql as $$
  select name from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = p_code;
$$;

-- Hàm mới mặc định không cấp quyền chạy cho ai (migration 014): cấp cho hàm trợ giúp của bài kiểm thử.
grant execute on all functions in schema pg_temp to public;

-- R-CRM-15: L5P thuộc L5, đứng ngay sau L5B, không nối lý do huỷ test.
select is(pg_temp.name_of('L5P'), 'Đã làm bài, chờ giáo viên chấm', 'R-CRM-15: có nhóm con L5P');
select is((select p.code from app.catalog_item i join app.catalog_item p on p.id = i.parent_id
           where i.catalog_code = 'OPP_SUBSTAGE' and i.code = 'L5P'), 'L5', 'R-CRM-15: L5P thuộc giai đoạn L5');
select is((select array_agg(code order by sort_order) from app.catalog_item
           where catalog_code = 'OPP_SUBSTAGE' and code in ('L5A', 'L5B', 'L5P', 'L5C')),
          array['L5A', 'L5B', 'L5P', 'L5C'], 'R-CRM-15: L5P xếp ngay sau L5B');
select is(pg_temp.name_of('L5B'), 'Đã xếp lịch test', 'Spec 06 mục 1.3: L5B là "Đã xếp lịch test"');
select ok(not exists (select from app.catalog_item where catalog_code = 'TEST_CANCEL_REASON' and code = 'L5P'),
          'R-CRM-15: L5P không nối danh mục lý do huỷ test');

-- R-CRM-13: L6 chỉ còn A–F.
select is((select array_agg(code order by code) from app.catalog_item
           where catalog_code = 'OPP_SUBSTAGE' and code like 'L6%'),
          array['L6A', 'L6B', 'L6C', 'L6D', 'L6E', 'L6F'], 'R-CRM-13: L6 có A–F, không còn L6G');
select is(pg_temp.name_of('L6A'), 'Có kết quả, cần phân loại', 'L6A có kết quả, cần phân loại');
select is(pg_temp.name_of('L6B'), 'Học xuất sắc', 'L6B học xuất sắc');
select is(pg_temp.name_of('L6C'), 'Học tốt', 'L6C học tốt');
select is(pg_temp.name_of('L6D'), 'Học khá', 'L6D học khá');
select is(pg_temp.name_of('L6E'), 'Học trung bình', 'L6E học trung bình');
select is(pg_temp.name_of('L6F'), 'Học yếu', 'L6F học yếu');
select ok(not exists (select from app.catalog_item i join app.catalog_item o on o.id = i.parent_id or o.id = i.linked_item_id
                      where o.catalog_code = 'OPP_SUBSTAGE' and o.code = 'L6G'),
          'Không còn bản ghi trỏ tới L6G');

-- Thứ tự nhóm con liền mạch, không trùng.
select is((select count(distinct sort_order)::int from app.catalog_item where catalog_code = 'OPP_SUBSTAGE'),
          (select count(*)::int from app.catalog_item where catalog_code = 'OPP_SUBSTAGE'), 'Thứ tự nhóm con không trùng');

-- Danh mục 33.
select is((select kind from app.catalog where code = 'TEST_SKIP_REASON'), 'MO', 'Danh mục 33 là danh mục mở');
select is((select array_agg(name order by sort_order) from app.catalog_item where catalog_code = 'TEST_SKIP_REASON' and not is_active),
          array['Học sinh cũ đã biết trình độ', 'Phụ huynh không muốn test', 'Đã có kết quả test nơi khác', 'Khác'],
          'R-CRM-14: bốn giá trị cũ của danh mục 33 còn lại ở trạng thái Ngừng (T3 thay bằng BQ1–BQ5)');

-- Vẫn không xoá cứng được mục danh mục (ngoại lệ chỉ nằm trong migration này).
select is(pg_temp.err($$delete from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code = 'L6F'$$),
          'HMT_KHONG_XOA', 'Sau migration, xoá mục danh mục vẫn bị chặn');

select * from finish();
rollback;
