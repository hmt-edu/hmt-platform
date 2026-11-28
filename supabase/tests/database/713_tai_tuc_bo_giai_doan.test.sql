-- C-27-20, C-27-20b (migration 713): bộ giai đoạn phiếu tái tục theo Config; kết thúc = L5 hoặc L8C. Luật R-GD-13, R-CRM-16. Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is((select count(*)::int from app.catalog_item s join app.catalog_item p on p.id = s.parent_id
            where s.catalog_code = 'UPSALE_SUBSTAGE' and s.is_active and left(s.code, 2) <> p.code), 0, 'Giai đoạn con thuộc đúng giai đoạn');
select is((select count(distinct p.code)::int from app.catalog_item s join app.catalog_item p on p.id = s.parent_id
            where s.catalog_code = 'UPSALE_SUBSTAGE' and s.is_active), 8, 'Cả tám giai đoạn đều có giai đoạn con');
select is((select count(*)::int from app.catalog_item where catalog_code = 'UPSALE_SUBSTAGE' and is_active), 35, 'Đủ 35 giai đoạn con (L1 3, L2 4, L3 5, L4 5, L5 7, L6 4, L7 4, L8 3)');
select is((select array_agg(name order by code) from app.catalog_item where catalog_code = 'UPSALE_SUBSTAGE' and code like 'L8%'),
          (select array_agg(name order by code) from app.catalog_item where catalog_code = 'OPP_SUBSTAGE' and code like 'L8%'),
          'R-CRM-16: L8 của phiếu tái tục giống hệt L8 của cơ hội');
select is(array[app.upsale_is_closed('L5', 'L5A'), app.upsale_is_closed('L8', 'L8C'), app.upsale_is_closed('L8', 'L8A'),
                app.upsale_is_closed('L8', 'L8B'), app.upsale_is_closed('L7', 'L7D'), app.upsale_is_closed('L8', null)],
          array[true, true, false, false, false, false], 'Kết thúc: chỉ L5 và L8C');
select is((select indexdef like '%closed_at IS NULL%' from pg_indexes where indexname = 'upsale_ticket_open_uq'), true,
          'Mỗi (học sinh, lớp) tối đa một phiếu chưa kết thúc');
select is(has_function_privilege('authenticated', 'app.upsale_is_closed(text, text)', 'execute'), false, 'Hàm phụ không gọi trực tiếp được');

select * from finish();
rollback;
