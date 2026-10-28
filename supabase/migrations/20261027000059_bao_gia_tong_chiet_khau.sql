-- ===========================================================================
-- P5a-DB1e (migration 059): app.price_line trả thêm `total_discount_percent` (= % chiết khấu + giờ tặng quy ra %, đúng số so với trần
-- R-TIEN-29) để BH-02 hiện "Tổng chiết khấu x% / trần 20%" mà giao diện không tự cộng (K06c; giao diện không tính chiết khấu).
-- Chỉ thêm một khoá vào kết quả; mọi luật giá giữ nguyên. Kết quả này cũng đi vào app.preview_quotation_lines.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Chỉ đổi MỘT chỗ so với migration 045: câu lỗi quà vượt mức in số lượng tối đa bỏ số 0 thừa ("không quá 2." thay vì "không quá 2.00."),
-- đúng chữ của khung K06c ("Dòng N: số lượng quà không quá M."). Mọi luật tính giá giữ nguyên, các bài kiểm giá cũ phải vẫn đạt.
-- ---------------------------------------------------------------------------
-- Tính tiền một dòng báo giá hoặc đơn.
-- Đầu vào: số dòng, loại (ENROL hoặc GIFT), gói, hình thức, số lượng mua, chính sách chiết khấu (jsonb), chính sách quà (GIFT), cơ sở, ngày.
-- Kết quả: jsonb đủ cột chụp lại của dòng (đơn giá, số lượng, đơn vị, thành tiền, % chiết khấu, tiền chiết khấu, cờ vượt trần, cờ cần tích).
-- Luật: R-TIEN-10, 12 (giá theo hình thức; hình thức không có giá thì lỗi); R-TIEN-13, 14 (máy chủ tính, giá hiệu lực tại ngày tính);
-- R-TIEN-29 (chiết khấu % cộng dồn; giờ tặng quy ra % = giờ tặng ÷ giờ mua và tính vào trần; vượt trần là cảnh báo, cờ over_cap);
-- R-TIEN-30 (quà tặng giá 0, ngoài trần); R-TIEN-36 (thành tiền = số lượng × đơn giá); Đ101 (đơn vị theo loại gói);
-- Đ102 (một cờ cần tích chung cho vượt trần và chính sách cần duyệt); Đ172 (tiền chiết khấu làm tròn xuống đồng).
create or replace function app.price_line(
  p_line_no integer, p_kind text, p_package_id uuid, p_mode text, p_quantity numeric, p_discounts jsonb,
  p_gift_policy_id uuid, p_branch_id uuid, p_on date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  pkg app.sales_package;
  gp app.gift_policy;
  v_price bigint;
  v_mode text := p_mode;
  v_disc jsonb;
  v_percent numeric := 0;
  v_gift_hours numeric := 0;
  v_gift_percent numeric := 0;
  v_cap numeric := app.get_setting('discount_total_cap_percent')::numeric;
  v_gross bigint;
  v_discount_amount bigint;
  v_over boolean := false;
  v_ack boolean := false;
  v_applied jsonb := '[]'::jsonb;
begin
  if p_quantity is null or p_quantity <= 0 then
    perform app.raise_error('HMT_DONG_THIEU', format('Dòng %s: nhập số lượng lớn hơn 0.', p_line_no));
  end if;
  if p_kind = 'GIFT' then
    -- Luật R-TIEN-30: quà tặng là gói dịch vụ, tài liệu của chính sách quà, giá 0, số lượng không quá mức tối đa, ngoài trần chiết khấu.
    select * into gp from app.gift_policy where id = p_gift_policy_id;
    if gp.id is null then
      perform app.raise_error('HMT_DONG_THIEU', format('Dòng %s: chọn chính sách quà tặng.', p_line_no));
    end if;
    if not gp.is_active or gp.valid_from > p_on or (gp.valid_to is not null and gp.valid_to < p_on)
       or (cardinality(gp.branch_ids) > 0 and not p_branch_id = any (gp.branch_ids)) then
      perform app.raise_error('HMT_CHINH_SACH_KHONG_AP_DUNG', format('Dòng %s: chính sách quà "%s" không áp dụng cho cơ sở hoặc ngày này.', p_line_no, gp.name));
    end if;
    if p_quantity > gp.max_quantity then
      perform app.raise_error('HMT_CHIET_KHAU_VUOT_MUC', format('Dòng %s: số lượng quà không quá %s.', p_line_no, trim_scale(gp.max_quantity)));
    end if;
    select * into pkg from app.sales_package where id = gp.gift_package_id;
    v_price := 0;
    v_mode := 'OFF';
    v_ack := gp.requires_approval;
  else
    select * into pkg from app.sales_package where id = p_package_id;
    if pkg.id is null then
      perform app.raise_error('HMT_DONG_THIEU', format('Dòng %s: chọn gói.', p_line_no));
    end if;
    if not pkg.is_active then
      perform app.raise_error('HMT_GOI_DA_NGUNG', format('Dòng %s: gói %s đã ngừng bán.', p_line_no, pkg.code));
    end if;
    -- Luật R-TIEN-10, 12: giá theo hình thức; giá trống nghĩa là gói không bán hình thức đó.
    v_price := app.package_price_at(pkg.id, v_mode, p_on);
    if v_mode is null or v_price is null then
      perform app.raise_error('HMT_HINH_THUC_KHONG_CO_GIA', format('Dòng %s: gói %s không bán hình thức này.', p_line_no, pkg.code));
    end if;
    v_disc := app.price_apply_discounts(p_line_no, pkg.package_type_code, p_branch_id, p_on, p_discounts);
    v_percent := (v_disc ->> 'percent')::numeric;
    v_gift_hours := (v_disc ->> 'gift_hours')::numeric;
    v_applied := v_disc -> 'applied';
    v_ack := (v_disc ->> 'needs_acknowledgement')::boolean;
    -- Luật R-TIEN-29, 36: giờ tặng quy ra % = giờ tặng ÷ giờ mua, tính vào trần; vượt trần là cảnh báo, không chặn lưu.
    v_gift_percent := round(v_gift_hours / p_quantity * 100, 2); -- allow-number: quy ra phần trăm
    v_over := (v_percent + v_gift_percent) > v_cap;
    v_ack := v_ack or v_over;
  end if;
  v_gross := round(p_quantity * v_price)::bigint;
  -- Luật Đ172: tiền chiết khấu làm tròn xuống đồng.
  v_discount_amount := floor(v_gross * v_percent / 100)::bigint; -- allow-number: phần trăm
  return jsonb_build_object(
    'package_id', pkg.id, 'package_code', pkg.code, 'package_name', pkg.name, 'package_type_code', pkg.package_type_code,
    'delivery_mode_code', v_mode, 'unit_code', app.package_unit(pkg.package_type_code),
    'quantity', p_quantity, 'gifted_quantity', v_gift_hours, 'unit_price', v_price, 'gross_amount', v_gross,
    'discount_percent', v_percent, 'gift_percent', v_gift_percent, 'discount_amount', v_discount_amount,
    'total_discount_percent', v_percent + v_gift_percent,
    'line_total', v_gross - v_discount_amount, 'over_cap', v_over, 'needs_acknowledgement', v_ack,
    'gift_policy_id', case when p_kind = 'GIFT' then gp.id end, 'discounts', v_applied);
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.price_line(integer, text, uuid, text, numeric, jsonb, uuid, uuid, date) from public, anon, authenticated;
