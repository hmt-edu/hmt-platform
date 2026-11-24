-- D-23-38: kênh «Phụ huynh không đồng ý» là kênh hệ thống, không cho chọn tay ở Tạo ticket (migration 652).
begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

select is((select applies_to from app.catalog_item where catalog_code = 'TICKET_CHANNEL' and code = 'PH_KHONG_DONG_Y'), '{HE_THONG}'::text[],
  'D-23-38 Đúng: kênh Phụ huynh không đồng ý chỉ áp dụng cho hệ thống (không có TICKET_TAY)');
select is((select count(*) from app.catalog_item where catalog_code = 'TICKET_CHANNEL' and code in ('GOI_DIEN', 'ZALO', 'TRUC_TIEP', 'EMAIL', 'GIAO_VIEN_BAO', 'KHAC') and cardinality(applies_to) = 0), 6::bigint,
  'D-23-38 Đúng: sáu kênh nhập tay vẫn để trống applies_to (áp dụng mọi nơi)');
select ok(exists (select 1 from app.catalog_item where catalog_code = 'TICKET_CHANNEL' and code = 'PH_KHONG_DONG_Y' and is_active),
  'D-23-38 Đúng: mục vẫn Đang dùng để hệ thống ghi và ticket cũ hiện tên kênh');

select * from finish();
rollback;
