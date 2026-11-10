-- Q-137 (anh OK 08/11): bộ nguồn lead khớp spec 06 mục 1.1 [26/10]: 4 loại · 11 nguồn · 12 kênh. QĐ-Đ184: "chỉ còn 4 Source type"; Referral và
-- Upsale là NGUỒN dưới Marketing; bỏ Medium Renew Lost, New Opp. Dữ liệu nạp từ 12/10 (migration 003) còn 6 loại, 14 kênh.
-- Làm gì:
--  (1) Chuyển 2 nguồn REFERRAL, UPSALE về dưới loại MARKETING (đổi cha, giữ mã, giữ tên, giữ thứ tự).
--  (2) Lead và cơ hội cũ: đổi source_type_code sang MARKETING theo nguồn (nguồn và kênh giữ nguyên). Luật HMT_NGUON_SAI (nguồn phải thuộc loại) giữ
--      nguyên, không nới.
--  (3) Ngừng (không xoá): 2 kênh UPSALE_RENEW_LOST, UPSALE_NEW_OPP và 2 loại cũ REFERRAL, UPSALE. Lead cũ dùng kênh Ngừng vẫn giữ giá trị.
-- Số đếm: câu RAISE NOTICE bên dưới in số lead và cơ hội đổi loại ra nhật ký chạy migration.
-- Chỉ mục: không thêm; câu UPDATE lọc theo cột source_type_code của lead, opportunity (bảng có chỉ mục lọc theo loại nguồn).
-- An toàn: sau khi đổi, còn lead hoặc cơ hội mang loại REFERRAL, UPSALE (nguồn không phải 2 nguồn trên) thì dừng migration, không để dữ liệu lệch.

select set_config('hmt.migration', 'on', false);

do $$
declare
  v_marketing uuid;
  v_lead integer;
  v_opp integer;
begin
  select id into v_marketing from app.catalog_item where catalog_code = 'SOURCE_TYPE' and code = 'MARKETING';
  if v_marketing is null then
    raise exception 'Q-137: không có loại nguồn MARKETING';
  end if;

  -- Số đếm trước khi đổi (lead, cơ hội mang loại cũ).
  select count(*) into v_lead from app.lead where source_type_code in ('REFERRAL', 'UPSALE');
  select count(*) into v_opp from app.opportunity where source_type_code in ('REFERRAL', 'UPSALE');
  raise notice 'Q-137: lead đổi loại sang MARKETING: %, cơ hội đổi loại: %', v_lead, v_opp;

  -- (1) Referral, Upsale thành nguồn dưới Marketing.
  update app.catalog_item set parent_id = v_marketing
   where catalog_code = 'SOURCE' and code in ('REFERRAL', 'UPSALE');

  -- (2) Lead và cơ hội cũ: loại đổi theo nguồn; nguồn và kênh giữ nguyên.
  update app.lead set source_type_code = 'MARKETING'
   where source_type_code in ('REFERRAL', 'UPSALE') and source_code in ('REFERRAL', 'UPSALE');
  update app.opportunity set source_type_code = 'MARKETING'
   where source_type_code in ('REFERRAL', 'UPSALE') and source_code in ('REFERRAL', 'UPSALE');

  if exists (select from app.lead where source_type_code in ('REFERRAL', 'UPSALE'))
     or exists (select from app.opportunity where source_type_code in ('REFERRAL', 'UPSALE')) then
    raise exception 'Q-137: còn lead hoặc cơ hội mang loại REFERRAL, UPSALE mà nguồn không phải REFERRAL, UPSALE: dừng migration, cần xem tay.';
  end if;

  -- (3) Ngừng 2 kênh cũ và 2 loại cũ (không xoá).
  update app.catalog_item set is_active = false
   where (catalog_code = 'SOURCE_CHANNEL' and code in ('UPSALE_RENEW_LOST', 'UPSALE_NEW_OPP'))
      or (catalog_code = 'SOURCE_TYPE' and code in ('REFERRAL', 'UPSALE'));
end;
$$;

select set_config('hmt.migration', '', false);
