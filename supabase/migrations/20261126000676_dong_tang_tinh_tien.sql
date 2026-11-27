-- B-26-03 PR-DB2 (1/2), RỦI RO CAO (tiền): DÒNG TẶNG (anh Trường chốt H, 26/11).
-- Dòng tặng = dòng sản phẩm thường gắn chính sách ưu đãi «Tặng» (% mức 100). Luật:
--  1) mức của chính sách Tặng KHÔNG tính vào trần chiết khấu, không gây cảnh báo vượt trần (giờ tặng trên dòng vẫn tính);
--  2) «Tổng niêm yết» và tổng chiết khấu không cộng dòng tặng (số phải trả không đổi);
--  3) dòng chụp giá niêm yết list_unit_price để hiện «Giá trị quà» (chỉ hiển thị, không tham gia tính tiền).
-- Cấp giờ cho dòng tặng ở migration kế tiếp (677).

select set_config('hmt.migration', 'on', false);

alter table app.discount_policy add column is_gift boolean not null default false;
comment on column app.discount_policy.is_gift is 'Chính sách «Tặng»: dòng gắn chính sách này là dòng tặng (không tính trần, không vào tổng niêm yết, cấp giờ khi đơn thu đủ).';
-- Luật: chính sách Tặng là phần trăm, áp đúng mức 100, không phải Ưu đãi linh hoạt.
alter table app.discount_policy add constraint discount_policy_gift_check
  check (not is_gift or (kind = 'PERCENT' and max_value = 100 and fixed_value and not is_flexible)); -- allow-number: tặng là giảm 100 phần trăm

alter table app.quotation_line add column is_gift_line boolean not null default false,
  add column list_unit_price bigint check (list_unit_price >= 0);
alter table app.sales_order_line add column is_gift_line boolean not null default false,
  add column list_unit_price bigint check (list_unit_price >= 0);
comment on column app.sales_order_line.is_gift_line is 'Dòng tặng, chụp lúc tính giá (R-TIEN-14): đổi chính sách sau không đổi đơn cũ.';
comment on column app.sales_order_line.list_unit_price is 'Giá niêm yết chụp lúc tính giá, chỉ để hiển thị «Giá trị quà». Không dùng tính tiền.';
-- Dòng đã có: đơn giá chính là giá niêm yết; dòng quà cũ không biết giá lúc đó nên để trống.
update app.quotation_line set list_unit_price = unit_price where line_kind = 'ENROL';
update app.sales_order_line set list_unit_price = unit_price where line_kind = 'ENROL';

-- Lấy từ 20261126000675_san_pham_dong_va_danh_sach.sql; chỉ đổi phần luật dòng tặng (B-26-03).
create or replace function app.tg_sales_line_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  p app.sales_package;
begin
  if TG_TABLE_NAME = 'sales_order_line' then
    if (to_jsonb(new) ->> 'quotation_line_id') is not null then
      select q.subject_code, q.grade_code, q.is_gift_line, q.list_unit_price
        into new.subject_code, new.grade_code, new.is_gift_line, new.list_unit_price
        from app.quotation_line q where q.id = (to_jsonb(new) ->> 'quotation_line_id')::uuid;
      return new;
    end if;
  end if;
  select * into p from app.sales_package where id = new.package_id;
  new.subject_code := p.subject_code;
  new.grade_code := nullif(new.grade_code, '');
  if new.grade_code is null then
    if cardinality(p.grade_codes) = 1 then
      new.grade_code := p.grade_codes[1];
    end if;
  elsif not new.grade_code = any (p.grade_codes) then
    perform app.raise_error('HMT_KHOI_KHONG_THUOC_SAN_PHAM',
      format('Dòng %s: khối đã chọn không thuộc sản phẩm %s.', new.line_no, p.code));
  end if;
  return new;
end;
$$;

-- Lấy từ 20261119000476_ch04_chiet_khau_ap_dung_cho.sql; chỉ đổi phần luật dòng tặng (B-26-03).
create or replace function app.save_discount_policy(p_id uuid, p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_id;
  v_types text[] := array(select jsonb_array_elements_text(coalesce(p_data -> 'package_type_codes', '[]'::jsonb)));
  v_branches uuid[] := array(select jsonb_array_elements_text(coalesce(p_data -> 'branch_ids', '[]'::jsonb))::uuid);
  v_applies text[] := array(select jsonb_array_elements_text(coalesce(p_data -> 'applies_to', '["BAO_GIA", "DON", "PHIEU_THU"]'::jsonb)));
begin
  -- Luật CH-04 (19/11): «Áp dụng cho» chỉ gồm Báo giá, Đơn, Phiếu thu và không để trống.
  if p_data ? 'applies_to' and (cardinality(v_applies) = 0 or not v_applies <@ array['BAO_GIA', 'DON', 'PHIEU_THU']) then
    perform app.raise_error('HMT_AP_DUNG_CHO_SAI', 'Chọn ít nhất một nơi áp dụng: Báo giá, Đơn hoặc Phiếu thu.');
  end if;
  if p_id is null then
    perform app.assert_config_sales('TAO');
    if btrim(coalesce(p_data ->> 'code', '')) = '' or btrim(coalesce(p_data ->> 'name', '')) = ''
       or nullif(p_data ->> 'valid_from', '') is null or nullif(p_data ->> 'max_value', '') is null then
      perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập mã, tên, mức tối đa và ngày bắt đầu hiệu lực.');
    end if;
    begin
      insert into app.discount_policy (code, name, kind, max_value, fixed_value, requires_approval, valid_from, valid_to,
                                       package_type_codes, branch_ids, applies_to, is_gift)
      values (btrim(p_data ->> 'code'), btrim(p_data ->> 'name'), p_data ->> 'kind', (p_data ->> 'max_value')::numeric,
              coalesce((p_data ->> 'fixed_value')::boolean, false), coalesce((p_data ->> 'requires_approval')::boolean, false),
              (p_data ->> 'valid_from')::date, nullif(p_data ->> 'valid_to', '')::date, v_types, v_branches, v_applies,
              coalesce((p_data ->> 'is_gift')::boolean, false))
      returning id into v_id;
    exception
      when unique_violation then
        perform app.raise_error('HMT_MA_TRUNG', 'Mã chính sách này đã có.');
      when check_violation then
        perform app.raise_error('HMT_CHINH_SACH_SAI',
          'Chính sách không hợp lệ: phần trăm từ 0 đến 100; tặng giờ không đặt "áp đúng mức"; chính sách Tặng là phần trăm, áp đúng mức 100.');
    end;
  else
    perform app.assert_config_sales('SUA');
    if not exists (select from app.discount_policy where id = p_id) then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy chính sách.');
    end if;
    begin
      update app.discount_policy set
        name = coalesce(nullif(btrim(p_data ->> 'name'), ''), name),
        kind = coalesce(p_data ->> 'kind', kind),
        max_value = coalesce((p_data ->> 'max_value')::numeric, max_value),
        fixed_value = coalesce((p_data ->> 'fixed_value')::boolean, fixed_value),
        requires_approval = coalesce((p_data ->> 'requires_approval')::boolean, requires_approval),
        valid_from = coalesce((p_data ->> 'valid_from')::date, valid_from),
        valid_to = case when p_data ? 'valid_to' then nullif(p_data ->> 'valid_to', '')::date else valid_to end,
        package_type_codes = case when p_data ? 'package_type_codes' then v_types else package_type_codes end,
        branch_ids = case when p_data ? 'branch_ids' then v_branches else branch_ids end,
        applies_to = case when p_data ? 'applies_to' then v_applies else applies_to end,
        is_gift = coalesce((p_data ->> 'is_gift')::boolean, is_gift)
       where id = p_id;
    exception when check_violation then
      perform app.raise_error('HMT_CHINH_SACH_SAI',
        'Chính sách không hợp lệ: phần trăm từ 0 đến 100; tặng giờ không đặt "áp đúng mức"; chính sách Tặng là phần trăm, áp đúng mức 100.');
    end;
  end if;
  return v_id;
end;
$$;

-- Lấy từ 20261108000085_uu_dai_linh_hoat.sql; chỉ đổi phần luật dòng tặng (B-26-03).
create or replace function app.price_apply_discounts(
  p_line_no integer, p_package_type text, p_branch_id uuid, p_on date, p_discounts jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e jsonb;
  d app.discount_policy;
  v_value numeric;
  v_percent numeric := 0;
  v_gift numeric := 0;
  v_gift_count integer := 0;
  v_ack boolean := false;
  v_applied jsonb := '[]'::jsonb;
  v_seen uuid[] := array[]::uuid[];
  v_flex_max numeric;
  v_gift_policy_percent numeric := 0;
begin
  for e in select * from jsonb_array_elements(coalesce(p_discounts, '[]'::jsonb)) loop
    select * into d from app.discount_policy where id = nullif(e ->> 'policy_id', '')::uuid;
    if d.id is null then
      perform app.raise_error('HMT_CHINH_SACH_KHONG_CO', format('Dòng %s: chính sách chiết khấu không có.', p_line_no));
    end if;
    -- Luật: một chính sách chỉ áp một lần trên dòng.
    if d.id = any (v_seen) then
      perform app.raise_error('HMT_CHINH_SACH_TRUNG', format('Dòng %s: chính sách "%s" chọn hai lần.', p_line_no, d.name));
    end if;
    v_seen := v_seen || d.id;
    -- Luật R-TIEN-29: chính sách còn dùng, còn hiệu lực, đúng loại gói, đúng cơ sở.
    if not d.is_active or d.valid_from > p_on or (d.valid_to is not null and d.valid_to < p_on)
       or (cardinality(d.package_type_codes) > 0 and not p_package_type = any (d.package_type_codes))
       or (cardinality(d.branch_ids) > 0 and not p_branch_id = any (d.branch_ids)) then
      perform app.raise_error('HMT_CHINH_SACH_KHONG_AP_DUNG',
        format('Dòng %s: chính sách "%s" không áp dụng cho gói, cơ sở hoặc ngày này.', p_line_no, d.name));
    end if;
    -- Luật R-TIEN-36: mức do nhân viên điền, không quá mức tối đa; chính sách "áp đúng mức" lấy đúng mức tối đa.
    -- Luật R-V2-45 (Ưu đãi linh hoạt, Q-141): % do nhân viên nhập tay (bắt buộc nhập, không có mức mặc định), hạn mức mỗi dòng đọc từ
    -- tham số flexible_discount_max_percent (mặc định 5%, Admin sửa 0 đến 20%); nhập quá thì từ chối. Tính vào trần tổng như mọi chiết khấu %.
    if d.is_flexible then
      v_flex_max := app.get_setting('flexible_discount_max_percent')::numeric;
      v_value := nullif(e ->> 'value', '')::numeric;
      if v_value is null or v_value <= 0 then
        perform app.raise_error('HMT_UU_DAI_THIEU_MUC', format('Dòng %s: nhập %% ưu đãi linh hoạt lớn hơn 0.', p_line_no));
      end if;
      if v_value > v_flex_max then
        perform app.raise_error('HMT_UU_DAI_VUOT_MUC', format('Ưu đãi linh hoạt tối đa %s%%', trim_scale(v_flex_max)));
      end if;
    else
      v_value := case when d.fixed_value then d.max_value else nullif(e ->> 'value', '')::numeric end;
      v_value := coalesce(v_value, case when d.kind = 'PERCENT' then d.max_value end);
      if v_value is null or v_value <= 0 or v_value > d.max_value then
        perform app.raise_error('HMT_CHIET_KHAU_VUOT_MUC',
          format('Dòng %s: mức của chính sách "%s" phải lớn hơn 0 và không quá %s.', p_line_no, d.name, d.max_value));
      end if;
    end if;
    if d.kind = 'PERCENT' then
      v_percent := v_percent + v_value;
      -- Luật (anh chốt H): phần của chính sách Tặng để riêng, không tính vào trần.
      if d.is_gift then
        v_gift_policy_percent := v_gift_policy_percent + v_value;
      end if;
    else
      -- Luật Đ174: một dòng dùng tối đa MỘT chính sách tặng giờ.
      v_gift_count := v_gift_count + 1;
      if v_gift_count > 1 then
        perform app.raise_error('HMT_CHI_MOT_CHINH_SACH_TANG_GIO', format('Dòng %s: chỉ dùng được một chính sách tặng giờ.', p_line_no));
      end if;
      v_gift := v_value;
    end if;
    v_ack := v_ack or d.requires_approval;
    v_applied := v_applied || jsonb_build_object('policy_id', d.id, 'policy_code', d.code, 'policy_name', d.name,
                                                 'kind', d.kind, 'applied_value', v_value, 'requires_approval', d.requires_approval);
  end loop;
  if v_percent > 100 then -- allow-number: phần trăm tối đa 100
    perform app.raise_error('HMT_CHIET_KHAU_SAI', format('Dòng %s: tổng chiết khấu phần trăm không quá 100.', p_line_no));
  end if;
  return jsonb_build_object('percent', v_percent, 'gift_policy_percent', v_gift_policy_percent, 'gift_hours', v_gift, 'needs_acknowledgement', v_ack, 'applied', v_applied);
end;
$$;

-- Lấy từ 20261027000059_bao_gia_tong_chiet_khau.sql; chỉ đổi phần luật dòng tặng (B-26-03).
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
  v_list_price bigint;
  v_gift_policy_percent numeric := 0;
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
    v_list_price := app.package_price_at(pkg.id, 'OFF', p_on);
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
    v_list_price := v_price;
    v_disc := app.price_apply_discounts(p_line_no, pkg.package_type_code, p_branch_id, p_on, p_discounts);
    v_percent := (v_disc ->> 'percent')::numeric;
    v_gift_policy_percent := (v_disc ->> 'gift_policy_percent')::numeric;
    v_gift_hours := (v_disc ->> 'gift_hours')::numeric;
    v_applied := v_disc -> 'applied';
    v_ack := (v_disc ->> 'needs_acknowledgement')::boolean;
    -- Luật R-TIEN-29, 36: giờ tặng quy ra % = giờ tặng ÷ giờ mua, tính vào trần; vượt trần là cảnh báo, không chặn lưu.
    v_gift_percent := round(v_gift_hours / p_quantity * 100, 2); -- allow-number: quy ra phần trăm
    -- Luật (anh chốt H): mức của chính sách Tặng không tính vào trần và không gây cảnh báo vượt trần.
    v_over := (v_percent - v_gift_policy_percent + v_gift_percent) > v_cap;
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
    'gift_policy_id', case when p_kind = 'GIFT' then gp.id end,
    'is_gift_line', v_gift_policy_percent > 0, 'list_unit_price', v_list_price, 'discounts', v_applied);
end;
$$;

-- Lấy từ 20261126000675_san_pham_dong_va_danh_sach.sql; chỉ đổi phần luật dòng tặng (B-26-03).
create or replace function app.save_quotation(p_id uuid, p_opportunity_id uuid, p_lines jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q app.quotation;
  v_opp app.opportunity;
  v_branch_code text;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_id uuid;
  v_code text;
  v_total bigint := 0;
  v_warnings jsonb := '[]'::jsonb;
  v_line_id uuid;
  e jsonb;
  d jsonb;
  v_n integer := 0;
  r jsonb;
begin
  if p_lines is not null and jsonb_typeof(p_lines) <> 'array' then
    perform app.raise_error('HMT_DONG_THIEU', 'Danh sách dòng báo giá không hợp lệ.');
  end if;
  if p_id is null then
    select * into v_opp from app.opportunity where id = p_opportunity_id;
    if v_opp.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
    end if;
    -- Luật: quyền tạo báo giá ở cơ sở của cơ hội; cơ hội đã gộp thì không tạo (R-CRM-22).
    perform app.assert_can('QUOTATION', 'TAO', v_opp.branch_id);
    -- Luật Đ173: phân hệ Bán hàng phải bật ở cơ sở.
    perform app.require_feature('BAN_HANG', v_opp.branch_id);
    if v_opp.record_status = 'DA_GOP' then
      perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không tạo báo giá được.');
    end if;
    select code into v_branch_code from app.branch where id = v_opp.branch_id;
    v_code := app.issue_document_number('BG', v_branch_code);
    insert into app.quotation (code, branch_id, opportunity_id, parent_id, priced_on)
    values (v_code, v_opp.branch_id, v_opp.id, v_opp.parent_id, v_on)
    returning id into v_id;
    select * into v_q from app.quotation where id = v_id;
  else
    select * into v_q from app.quotation where id = p_id for update;
    if v_q.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy báo giá.');
    end if;
    perform app.assert_can('QUOTATION', 'SUA', v_q.branch_id);
    perform app.require_feature('BAN_HANG', v_q.branch_id); -- Luật Đ173
    -- Luật Đ169: chỉ báo giá Nháp lưu được; Gửi rồi thì đóng băng.
    if v_q.status_code <> 'NHAP' then
      perform app.raise_error('HMT_BAO_GIA_DA_KHOA', 'Báo giá đã gửi: không sửa được. Tạo báo giá mới nếu cần đổi.');
    end if;
    v_id := v_q.id;
    v_opp := (select o from app.opportunity o where o.id = v_q.opportunity_id);
    delete from app.quotation_line_discount where line_id in (select id from app.quotation_line where quotation_id = v_id);
    delete from app.quotation_line where quotation_id = v_id;
  end if;

  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_n := v_n + 1;
    -- Luật Đ83: học sinh chọn trong danh sách em của cơ hội.
    perform app.validate_line_student(v_n, v_opp.id, nullif(e ->> 'prospect_student_id', '')::uuid);
    r := app.price_line(v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), nullif(e ->> 'package_id', '')::uuid,
                        e ->> 'delivery_mode_code', nullif(e ->> 'quantity', '')::numeric, e -> 'discounts',
                        nullif(e ->> 'gift_policy_id', '')::uuid, v_opp.branch_id, v_on);
    insert into app.quotation_line (
      quotation_id, line_no, line_kind, prospect_student_id, package_id, package_code, package_name, package_type_code,
      delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent, gift_percent,
      discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, grade_code, is_gift_line, list_unit_price)
    values (
      v_id, v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), (e ->> 'prospect_student_id')::uuid,
      (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
      r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
      (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
      (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
      (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
      e ->> 'grade_code',
      (r ->> 'is_gift_line')::boolean, (r ->> 'list_unit_price')::bigint)
    returning id into v_line_id;
    for d in select * from jsonb_array_elements(r -> 'discounts') loop
      insert into app.quotation_line_discount (line_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
      values (v_line_id, (d ->> 'policy_id')::uuid, d ->> 'policy_code', d ->> 'policy_name', d ->> 'kind',
              (d ->> 'applied_value')::numeric, (d ->> 'requires_approval')::boolean);
    end loop;
    v_total := v_total + (r ->> 'line_total')::bigint;
    -- Luật R-TIEN-29 (D3): vượt trần vẫn lưu, trả cảnh báo.
    if (r ->> 'over_cap')::boolean then
      v_warnings := v_warnings || jsonb_build_object('code', 'HMT_VUOT_TRAN', 'line_no', v_n,
        'message', format('Dòng %s: chiết khấu (gồm giờ tặng) vượt trần %s%%. Đơn cần người duyệt tích đồng ý.', v_n,
                          app.get_setting('discount_total_cap_percent')));
    end if;
  end loop;

  update app.quotation set priced_on = v_on, total_amount = v_total where id = v_id;
  select code into v_code from app.quotation where id = v_id;
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', v_total, 'warnings', v_warnings);
end;
$$;

-- Lấy từ 20261126000675_san_pham_dong_va_danh_sach.sql; chỉ đổi phần luật dòng tặng (B-26-03).
create or replace function app.order_write_priced_lines(p_order_id uuid, p_opportunity_id uuid, p_branch_id uuid, p_lines jsonb, p_on date)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  e jsonb;
  d jsonb;
  r jsonb;
  v_n integer := 0;
  v_total bigint := 0;
  v_line_id uuid;
  v_class uuid;
  v_start date;
begin
  delete from app.sales_order_line_discount where line_id in (select id from app.sales_order_line where order_id = p_order_id);
  delete from app.sales_order_line where order_id = p_order_id;
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_n := v_n + 1;
    -- Luật Đ83: học sinh chọn trong danh sách em của cơ hội.
    perform app.validate_line_student(v_n, p_opportunity_id, nullif(e ->> 'prospect_student_id', '')::uuid);
    v_class := nullif(e ->> 'class_id', '')::uuid;
    v_start := nullif(e ->> 'enrol_start_date', '')::date;
    if v_class is not null and v_start is null then
      perform app.raise_error('HMT_THIEU_NGAY_VAO_LOP', format('Dòng %s: chọn lớp thì cần ngày vào lớp.', v_n));
    end if;
    r := app.price_line(v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), nullif(e ->> 'package_id', '')::uuid,
                        e ->> 'delivery_mode_code', nullif(e ->> 'quantity', '')::numeric, e -> 'discounts',
                        nullif(e ->> 'gift_policy_id', '')::uuid, p_branch_id, p_on);
    perform app.check_order_line_class(v_n, v_class, (r ->> 'package_id')::uuid, p_branch_id);
    insert into app.sales_order_line (
      order_id, line_no, line_kind, prospect_student_id, package_id, package_code, package_name, package_type_code,
      delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent, gift_percent,
      discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date, grade_code, is_gift_line, list_unit_price)
    values (
      p_order_id, v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), (e ->> 'prospect_student_id')::uuid,
      (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
      r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
      (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
      (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
      (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
      v_class, v_start, e ->> 'grade_code',
      (r ->> 'is_gift_line')::boolean, (r ->> 'list_unit_price')::bigint)
    returning id into v_line_id;
    for d in select * from jsonb_array_elements(r -> 'discounts') loop
      insert into app.sales_order_line_discount (line_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
      values (v_line_id, (d ->> 'policy_id')::uuid, d ->> 'policy_code', d ->> 'policy_name', d ->> 'kind',
              (d ->> 'applied_value')::numeric, (d ->> 'requires_approval')::boolean);
    end loop;
    v_total := v_total + (r ->> 'line_total')::bigint;
  end loop;
  return v_total;
end;
$$;

-- Lấy từ 20261126000675_san_pham_dong_va_danh_sach.sql; chỉ đổi phần luật dòng tặng (B-26-03).
create or replace function app.order_add_priced_line(p_order_id uuid, p_opportunity_id uuid, p_branch_id uuid, p_spec jsonb, p_on date)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d jsonb;
  r jsonb;
  v_n integer;
  v_line_id uuid;
  v_class uuid;
  v_start date;
begin
  select coalesce(max(line_no), 0) + 1 into v_n from app.sales_order_line where order_id = p_order_id;
  -- Luật Đ83: học sinh chọn trong danh sách em của cơ hội.
  perform app.validate_line_student(v_n, p_opportunity_id, nullif(p_spec ->> 'prospect_student_id', '')::uuid);
  v_class := nullif(p_spec ->> 'class_id', '')::uuid;
  v_start := nullif(p_spec ->> 'enrol_start_date', '')::date;
  if v_class is not null and v_start is null then
    perform app.raise_error('HMT_THIEU_NGAY_VAO_LOP', format('Dòng %s: chọn lớp thì cần ngày vào lớp.', v_n));
  end if;
  r := app.price_line(v_n, coalesce(nullif(p_spec ->> 'kind', ''), 'ENROL'), nullif(p_spec ->> 'package_id', '')::uuid,
                      p_spec ->> 'delivery_mode_code', nullif(p_spec ->> 'quantity', '')::numeric, p_spec -> 'discounts',
                      nullif(p_spec ->> 'gift_policy_id', '')::uuid, p_branch_id, p_on);
  perform app.check_order_line_class(v_n, v_class, (r ->> 'package_id')::uuid, p_branch_id);
  insert into app.sales_order_line (
    order_id, line_no, line_kind, prospect_student_id, package_id, package_code, package_name, package_type_code,
    delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent, gift_percent,
    discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date, grade_code, is_gift_line, list_unit_price)
  values (
    p_order_id, v_n, coalesce(nullif(p_spec ->> 'kind', ''), 'ENROL'), (p_spec ->> 'prospect_student_id')::uuid,
    (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
    r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
    (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
    (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
    (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
    v_class, v_start, p_spec ->> 'grade_code',
      (r ->> 'is_gift_line')::boolean, (r ->> 'list_unit_price')::bigint)
  returning id into v_line_id;
  for d in select * from jsonb_array_elements(r -> 'discounts') loop
    insert into app.sales_order_line_discount (line_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
    values (v_line_id, (d ->> 'policy_id')::uuid, d ->> 'policy_code', d ->> 'policy_name', d ->> 'kind',
            (d ->> 'applied_value')::numeric, (d ->> 'requires_approval')::boolean);
  end loop;
  return jsonb_build_object('line_no', v_n, 'package_code', r ->> 'package_code', 'line_total', (r ->> 'line_total')::bigint,
                            'quantity', (r ->> 'quantity')::numeric, 'discount_percent', (r ->> 'discount_percent')::numeric,
                            'gifted_quantity', (r ->> 'gifted_quantity')::numeric, 'over_cap', (r ->> 'over_cap')::boolean);
end;
$$;

-- Lấy từ 20261126000675_san_pham_dong_va_danh_sach.sql; chỉ đổi phần luật dòng tặng (B-26-03).
create or replace function app.create_order_from_upsale_ticket(p_ticket_id uuid, p_lines jsonb, p_payment_term_id uuid default null, p_enrol_start_date date default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_start date;
  v_mode text;
  e jsonb;
  d jsonb;
  r jsonb;
  v_n integer := 0;
  v_kind text;
  v_class uuid;
  v_line_id uuid;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn cần ít nhất một dòng.');
  end if;
  select * into t from app.upsale_ticket where id = p_ticket_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  -- Hai quyền, kiểm riêng từng bước (Chat 13:20).
  perform app.assert_can('SALES_ORDER', 'TAO', t.branch_id);
  perform app.assert_can('UPSALE', 'SUA', t.branch_id);
  perform app.require_feature('BAN_HANG', t.branch_id);
  -- Luật R-GD-13: chỉ phiếu đã Đồng ý tái tục (L6) tạo được đơn.
  if t.stage_code <> 'L6' then
    perform app.raise_error('HMT_PHIEU_CHUA_DONG_Y', 'Chỉ tạo được đơn khi phiếu tái tục ở giai đoạn Đồng ý tái tục (L6).');
  end if;
  -- Luật Đ187: mỗi phiếu tối đa một đơn đang sống (Nháp, Đã trình, Đã duyệt).
  if exists (select from app.sales_order where renewal_ticket_id = t.id and status_code in ('NHAP', 'DA_TRINH', 'DA_DUYET')) then
    perform app.raise_error('HMT_PHIEU_DA_CO_DON', 'Phiếu tái tục này đã có đơn đang xử lý.');
  end if;
  -- Luật R-GD-13: học sinh còn học ở lớp của phiếu; hình thức học giữ như ghi danh cũ.
  select e2.delivery_mode_code into v_mode
    from app.enrollment e2 join app.enrollment_class ec on ec.enrollment_id = e2.id and ec.class_id = t.class_id and ec.end_date is null
   where e2.student_id = t.student_id and e2.status_code in ('DA_XEP_LOP', 'DANG_HOC') order by e2.created_at desc limit 1;
  if not found then
    perform app.raise_error('HMT_HOC_SINH_KHONG_O_LOP', 'Học sinh này hiện không học ở lớp của phiếu nên chưa tạo được đơn tái tục.');
  end if;
  -- Ngày vào lớp: không truyền thì lấy buổi sắp tới gần nhất của lớp (ghi danh phải vào đúng một buổi sắp tới, R-GD-06); kiểm sớm để báo lỗi ngay thay vì rơi vào hàng chờ xếp lớp.
  v_start := coalesce(p_enrol_start_date,
                      (select min(s.session_date) from app.class_session s
                        where s.class_id = t.class_id and s.status_code in ('NHAP', 'DA_CHOT') and s.session_date >= v_on),
                      v_on);
  perform app.assert_enrol_start_date(t.class_id, v_start, 'Đơn tái tục');
  select code into v_branch_code from app.branch where id = t.branch_id;
  v_code := app.issue_document_number('DH', v_branch_code);
  insert into app.sales_order (code, branch_id, renewal_ticket_id, parent_id, priced_on)
  values (v_code, t.branch_id, t.id, t.parent_id, v_on)
  returning id into v_id;
  -- Dòng đơn: học sinh, lớp lấy từ phiếu; giá tính như đơn thường (R-TIEN-13, 14).
  for e in select * from jsonb_array_elements(p_lines) loop
    v_n := v_n + 1;
    v_kind := coalesce(nullif(e ->> 'kind', ''), 'ENROL');
    v_class := case when v_kind = 'ENROL' then t.class_id end;
    r := app.price_line(v_n, v_kind, nullif(e ->> 'package_id', '')::uuid, coalesce(nullif(e ->> 'delivery_mode_code', ''), v_mode),
                        nullif(e ->> 'quantity', '')::numeric, e -> 'discounts', nullif(e ->> 'gift_policy_id', '')::uuid, t.branch_id, v_on);
    perform app.check_order_line_class(v_n, v_class, (r ->> 'package_id')::uuid, t.branch_id);
    insert into app.sales_order_line (
      order_id, branch_id, line_no, line_kind, student_id, package_id, package_code, package_name, package_type_code,
      delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent, gift_percent,
      discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date, grade_code, is_gift_line, list_unit_price)
    values (
      v_id, t.branch_id, v_n, v_kind, t.student_id,
      (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
      r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
      (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
      (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
      (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
      v_class, case when v_class is not null then v_start end, e ->> 'grade_code',
      (r ->> 'is_gift_line')::boolean, (r ->> 'list_unit_price')::bigint)
    returning id into v_line_id;
    for d in select * from jsonb_array_elements(r -> 'discounts') loop
      insert into app.sales_order_line_discount (line_id, branch_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
      values (v_line_id, t.branch_id, (d ->> 'policy_id')::uuid, d ->> 'policy_code', d ->> 'policy_name', d ->> 'kind',
              (d ->> 'applied_value')::numeric, (d ->> 'requires_approval')::boolean);
    end loop;
  end loop;
  -- Điều khoản thanh toán áp ngay trong cùng giao dịch (Đ260, R-CRM-19); sai thì cả giao dịch lùi.
  if p_payment_term_id is not null then
    perform app.order_apply_term(v_id, p_payment_term_id);
  end if;
  perform app.order_refresh_totals(v_id);
  perform app.order_add_event(v_id, 'TAO', null, 'NHAP', null, null, 'Tạo từ phiếu tái tục ' || t.code);
  -- Phiếu sang L7B «Đã có đơn, chờ đóng tiền» trong cùng giao dịch (R-GD-13, 26/10).
  update app.upsale_ticket set stage_code = 'L7', substage_code = 'L7B' where id = t.id;
  perform app.upsale_add_event(t.id, 'DOI_GIAI_DOAN', 'L6', 'L7', 'Tạo đơn ' || v_code);
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', (select total_amount from app.sales_order where id = v_id));
end;
$$;

-- Lấy từ 20261026000045_p5a_bao_gia.sql; chỉ đổi phần luật dòng tặng (B-26-03).
create or replace function app.send_quotation(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q app.quotation;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_old_total bigint;
  v_new_total bigint := 0;
  v_warnings jsonb := '[]'::jsonb;
  l app.quotation_line;
  r jsonb;
  d jsonb;
  v_disc jsonb;
begin
  select * into v_q from app.quotation where id = p_id for update;
  if v_q.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy báo giá.');
  end if;
  perform app.assert_can('QUOTATION', 'SUA', v_q.branch_id);
  perform app.require_feature('BAN_HANG', v_q.branch_id); -- Luật Đ173
  if v_q.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ gửi được báo giá Nháp.');
  end if;
  if not exists (select from app.quotation_line where quotation_id = p_id) then
    perform app.raise_error('HMT_BAO_GIA_KHONG_DONG', 'Báo giá chưa có dòng nào, chưa gửi được.');
  end if;
  perform app.assert_line_students_complete(p_id);
  v_old_total := v_q.total_amount;
  -- Luật Đ175: tính lại từng dòng theo giá và chính sách hiệu lực ngày Gửi; lỗi của price_line chặn Gửi và nêu đúng dòng.
  for l in select * from app.quotation_line where quotation_id = p_id order by line_no loop
    select coalesce(jsonb_agg(jsonb_build_object('policy_id', x.policy_id, 'value', x.applied_value)), '[]'::jsonb)
      into v_disc from app.quotation_line_discount x where x.line_id = l.id;
    r := app.price_line(l.line_no, l.line_kind, l.package_id, l.delivery_mode_code, l.quantity, v_disc,
                        l.gift_policy_id, v_q.branch_id, v_on);
    update app.quotation_line set
      unit_price = (r ->> 'unit_price')::bigint, gross_amount = (r ->> 'gross_amount')::bigint,
      discount_percent = (r ->> 'discount_percent')::numeric, gift_percent = (r ->> 'gift_percent')::numeric,
      gifted_quantity = (r ->> 'gifted_quantity')::numeric, discount_amount = (r ->> 'discount_amount')::bigint,
      line_total = (r ->> 'line_total')::bigint, over_cap = (r ->> 'over_cap')::boolean,
      needs_acknowledgement = (r ->> 'needs_acknowledgement')::boolean,
      is_gift_line = (r ->> 'is_gift_line')::boolean, list_unit_price = (r ->> 'list_unit_price')::bigint
     where id = l.id;
    -- Chụp lại mức đã áp của từng chính sách (chính sách "áp đúng mức" có thể đổi mức tối đa).
    for d in select * from jsonb_array_elements(r -> 'discounts') loop
      update app.quotation_line_discount set applied_value = (d ->> 'applied_value')::numeric,
             requires_approval = (d ->> 'requires_approval')::boolean
       where line_id = l.id and policy_id = (d ->> 'policy_id')::uuid;
    end loop;
    v_new_total := v_new_total + (r ->> 'line_total')::bigint;
  end loop;
  if v_new_total <> v_old_total then
    v_warnings := jsonb_build_array(jsonb_build_object('code', 'HMT_TONG_TIEN_DOI',
      'message', format('Giá hoặc chính sách đã đổi từ lúc lưu: tổng báo giá từ %s đ thành %s đ.', v_old_total, v_new_total)));
  end if;
  update app.quotation set status_code = 'DA_GUI', sent_at = now(), sent_by = auth.uid(), priced_on = v_on, total_amount = v_new_total,
         valid_until = v_on + app.get_setting_int('quotation_validity_days', v_q.branch_id)::integer
   where id = p_id;
  return jsonb_build_object('id', p_id, 'total_amount', v_new_total, 'previous_total', v_old_total, 'warnings', v_warnings);
end;
$$;

-- Lấy từ 20261108000085_uu_dai_linh_hoat.sql; chỉ đổi phần luật dòng tặng (B-26-03).
create or replace function app.edit_order(p_id uuid, p_edits jsonb default null, p_payment_term_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  e jsonb;
  l app.sales_order_line;
  n app.sales_order_line;
  r jsonb;
  v_discounts jsonb;
  v_changes text[] := array[]::text[];
  v_diff text;
  v_old_term text;
  v_new_term text;
  v_qcode text;
  v_i integer;
  v_flex numeric;
  v_old_flex numeric;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'SUA', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code <> 'NHAP' then
    perform app.raise_error('HMT_DON_DA_KHOA', 'Đơn đã trình: không sửa được. Nhờ người duyệt từ chối để đưa về Nháp.');
  end if;
  -- Điều khoản thanh toán.
  if p_payment_term_id is not null and p_payment_term_id is distinct from v_o.payment_term_id then
    select coalesce((select name from app.payment_term where id = v_o.payment_term_id), 'chưa chọn') into v_old_term;
    perform app.order_apply_term(p_id, p_payment_term_id);
    select name into v_new_term from app.payment_term where id = p_payment_term_id;
    v_changes := array_append(v_changes, format('điều khoản thanh toán %s → %s', v_old_term, v_new_term));
  end if;
  -- Sửa từng dòng tại chỗ (giữ học sinh, gói, liên kết dòng báo giá); tính lại theo ngày tính giá của đơn (R-TIEN-14).
  if p_edits is not null then
    if jsonb_typeof(p_edits) <> 'array' then
      perform app.raise_error('HMT_DONG_THIEU', 'Danh sách sửa dòng không hợp lệ.');
    end if;
    for e in select * from jsonb_array_elements(p_edits) loop
      -- Thêm dòng mới (Q-67, canvas BH05_nhap_sua): phần tử {add: {kind, prospect_student_id, package_id, delivery_mode_code, quantity, discounts,
      -- gift_policy_id}}; tính giá theo ngày tính giá của đơn (R-TIEN-14), kiểm em thuộc cơ hội (Đ83), nối số dòng. Nhật ký ghi mã gói.
      if e ? 'add' then
        if v_o.opportunity_id is null then
          perform app.raise_error('HMT_DON_KHONG_CO_CO_HOI', 'Đơn này không sinh từ cơ hội nên chưa thêm dòng được.');
        end if;
        r := app.order_add_priced_line(p_id, v_o.opportunity_id, v_o.branch_id, e -> 'add', v_o.priced_on);
        -- Nhật ký (Q-69): mã gói, số giờ, chiết khấu % và giờ tặng do máy chủ tính. Vượt trần chiết khấu chỉ cảnh báo (R-V2-11), KHÔNG chặn ở đây: cảnh báo hiện ở hộp Duyệt.
        v_changes := array_append(v_changes, format('thêm dòng %s (%s): số giờ %s%s%s', r ->> 'line_no', r ->> 'package_code',
          trim_scale((r ->> 'quantity')::numeric),
          case when (r ->> 'discount_percent')::numeric > 0 then format(', chiết khấu %s%%', trim_scale((r ->> 'discount_percent')::numeric)) else '' end,
          case when (r ->> 'gifted_quantity')::numeric > 0 then format(', tặng %s giờ', trim_scale((r ->> 'gifted_quantity')::numeric)) else '' end));
        -- Nhật ký (Q-145): dòng mới có ưu đãi linh hoạt thì thêm một dòng "Ưu đãi linh hoạt X% ở dòng N".
        select d.applied_value into v_flex from app.sales_order_line s
          join app.sales_order_line_discount d on d.line_id = s.id and d.policy_code = 'UU_DAI_LINH_HOAT'
         where s.order_id = p_id and s.line_no = (r ->> 'line_no')::integer;
        if v_flex is not null then
          v_changes := array_append(v_changes, format('Ưu đãi linh hoạt %s%% ở dòng %s', trim_scale(v_flex), r ->> 'line_no'));
        end if;
        continue;
      end if;
      select * into l from app.sales_order_line where order_id = p_id and line_no = (e ->> 'line_no')::integer;
      if l.id is null then
        perform app.raise_error('HMT_DONG_KHONG_CO', format('Không có dòng %s trong đơn.', e ->> 'line_no'));
      end if;
      if coalesce((e ->> 'remove')::boolean, false) then
        delete from app.sales_order_line_discount where line_id = l.id;
        delete from app.sales_order_line where id = l.id;
        v_changes := array_append(v_changes, format('bỏ dòng %s (%s)', l.line_no, l.package_code));
        continue;
      end if;
      if l.line_kind = 'GIFT' then
        continue; -- dòng quà tặng chỉ bỏ được, không tính lại
      end if;
      select d.applied_value into v_old_flex from app.sales_order_line_discount d where d.line_id = l.id and d.policy_code = 'UU_DAI_LINH_HOAT';
      -- Chính sách giữ nguyên nếu không gửi: chính sách cố định không truyền giá trị, còn lại truyền giá trị đã áp.
      v_discounts := case when e ? 'discounts' then e -> 'discounts' else coalesce((
        select jsonb_agg(jsonb_build_object('policy_id', d.policy_id, 'value', case when p.fixed_value then null else d.applied_value end))
          from app.sales_order_line_discount d join app.discount_policy p on p.id = d.policy_id where d.line_id = l.id), '[]'::jsonb) end;
      r := app.price_line(l.line_no, l.line_kind, l.package_id, coalesce(nullif(e ->> 'delivery_mode_code', ''), l.delivery_mode_code),
                          coalesce(nullif(e ->> 'quantity', '')::numeric, l.quantity), v_discounts, null, v_o.branch_id, v_o.priced_on);
      update app.sales_order_line set delivery_mode_code = r ->> 'delivery_mode_code', quantity = (r ->> 'quantity')::numeric,
             gifted_quantity = (r ->> 'gifted_quantity')::numeric, unit_price = (r ->> 'unit_price')::bigint,
             gross_amount = (r ->> 'gross_amount')::bigint, discount_percent = (r ->> 'discount_percent')::numeric,
             gift_percent = (r ->> 'gift_percent')::numeric, discount_amount = (r ->> 'discount_amount')::bigint,
             line_total = (r ->> 'line_total')::bigint, over_cap = (r ->> 'over_cap')::boolean,
             needs_acknowledgement = (r ->> 'needs_acknowledgement')::boolean,
      is_gift_line = (r ->> 'is_gift_line')::boolean, list_unit_price = (r ->> 'list_unit_price')::bigint
       where id = l.id returning * into n;
      delete from app.sales_order_line_discount where line_id = l.id;
      insert into app.sales_order_line_discount (line_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
      select l.id, (d ->> 'policy_id')::uuid, d ->> 'policy_code', d ->> 'policy_name', d ->> 'kind', (d ->> 'applied_value')::numeric,
             (d ->> 'requires_approval')::boolean from jsonb_array_elements(r -> 'discounts') d;
      v_diff := app.order_line_diff_text(l, n);
      if v_diff is not null then
        v_changes := array_append(v_changes, format('dòng %s (%s): %s', l.line_no, l.package_code, v_diff));
      end if;
      -- Nhật ký (Q-145): ưu đãi linh hoạt mới hoặc đổi mức thì thêm một dòng "Ưu đãi linh hoạt X% ở dòng N" (không đổi mức thì không ghi).
      select d.applied_value into v_flex from app.sales_order_line_discount d where d.line_id = l.id and d.policy_code = 'UU_DAI_LINH_HOAT';
      if v_flex is not null and v_flex is distinct from v_old_flex then
        v_changes := array_append(v_changes, format('Ưu đãi linh hoạt %s%% ở dòng %s', trim_scale(v_flex), l.line_no));
      end if;
    end loop;
    if not exists (select from app.sales_order_line where order_id = p_id) then
      perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn cần ít nhất một dòng.');
    end if;
    -- Đánh lại số dòng liên tục sau khi bỏ dòng (hai bước để không đụng ràng buộc duy nhất của số dòng).
    update app.sales_order_line s set line_no = x.rn + 100000 -- allow-number: số đệm tránh trùng khi đánh lại số dòng
      from (select id, row_number() over (order by line_no)::integer as rn from app.sales_order_line where order_id = p_id) x where s.id = x.id;
    update app.sales_order_line set line_no = line_no - 100000 where order_id = p_id; -- allow-number: số đệm tránh trùng khi đánh lại số dòng
  end if;
  perform app.order_refresh_totals(p_id);
  -- Nhật ký (Q-31): đơn từ báo giá ghi "Đơn đã sửa so với báo giá <mã>" kèm cũ, mới; không chặn.
  if cardinality(v_changes) > 0 then
    select code into v_qcode from app.quotation where id = v_o.quotation_id;
    perform app.order_add_event(p_id, 'SUA', 'NHAP', 'NHAP', null, null,
      -- Q-51 (anh chốt 07/11): dòng đầu là tiêu đề, mỗi thay đổi một dòng (giao diện tách theo dòng); tổng tiền cũ, mới lấy từ ảnh chụp tổng tiền
      -- của hai sự kiện liền nhau (cột total_amount), không viết lại ở đây.
      case when v_qcode is not null then format('Đơn đã sửa so với báo giá %s', v_qcode) else 'Sửa đơn' end
        || E'\n' || array_to_string(v_changes, E'\n'));
  end if;
  return jsonb_build_object('id', p_id, 'code', v_o.code, 'total_amount', (select total_amount from app.sales_order where id = p_id),
                            'changed', cardinality(v_changes) > 0);
end;
$$;

-- Lấy từ 20261028000062_don_hang_tong_nguoi_duyet_ghi_chu.sql; Tổng niêm yết, tổng chiết khấu không cộng dòng tặng.
create or replace function app.get_quotation(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  q app.quotation;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_display text;
begin
  select * into q from app.quotation where id = p_id;
  if q.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy báo giá.');
  end if;
  perform app.assert_can('QUOTATION', 'XEM', q.branch_id);
  v_display := case when q.status_code = 'DA_GUI' and app.quotation_converted(q.id) then 'DA_CHUYEN_DON' else q.status_code end;
  return (to_jsonb(q) - 'search_text') || jsonb_build_object(
    'display_status_code', v_display,
    'display_status', (select c.name from app.catalog_item c where c.catalog_code = 'QUOTATION_STATUS' and c.code = v_display),
    'overdue_days', case when q.status_code = 'DA_GUI' and q.valid_until < v_today then v_today - q.valid_until end,
    'branch_code', (select b.code from app.branch b where b.id = q.branch_id),
    'opportunity_code', (select o.code from app.opportunity o where o.id = q.opportunity_id),
    'parent_code', (select p.code from app.parent p where p.id = q.parent_id),
    'parent_name', (select p.full_name from app.parent p where p.id = q.parent_id),
    'parent_phone', (select p.phone from app.parent p where p.id = q.parent_id),
    'created_by_name', app.staff_display_name(q.created_by),
    'sent_by_name', app.staff_display_name(q.sent_by),
    'reject_reason', (select c.name from app.catalog_item c where c.catalog_code = 'REJECT_REASON' and c.code = q.reject_reason_code),
    'has_incomplete_students', exists (
      select from app.quotation_line l join app.prospect_student_v v on v.id = l.prospect_student_id
       where l.quotation_id = q.id and (v.full_name is null or v.birth_year is null)),
    'lines', coalesce((
      select jsonb_agg(to_jsonb(l) - 'quotation_id' || jsonb_build_object(
               'student_name', v.full_name, 'student_birth_year', v.birth_year, 'student_code', v.student_code,
               'student_complete', (v.full_name is not null and v.birth_year is not null),
               'gift_policy_name', (select g.name from app.gift_policy g where g.id = l.gift_policy_id),
               -- Đơn đang sống của dòng (Đ106: tối đa một); chưa lên đơn hoặc đơn đã huỷ thì rỗng.
               'order_id', ol.order_id, 'order_code', ol.order_code, 'order_status_code', ol.order_status_code,
               'discounts', coalesce((select jsonb_agg(to_jsonb(d) - 'line_id' - 'branch_id' order by d.created_at, d.id)
                                        from app.quotation_line_discount d where d.line_id = l.id), '[]'::jsonb))
             order by l.line_no)
        from app.quotation_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
        left join lateral (select o.id as order_id, o.code as order_code, o.status_code as order_status_code
                             from app.sales_order_line sl join app.sales_order o on o.id = sl.order_id
                            where sl.quotation_line_id = l.id and sl.is_live) ol on true
       where l.quotation_id = q.id), '[]'::jsonb),
    -- Tổng niêm yết và tổng chiết khấu do DB cộng từ các dòng đã đóng băng, không tính lại; dòng quà tặng không tính (R-TIEN-30).
    'gross_total', (select coalesce(sum(l3.gross_amount), 0)::bigint from app.quotation_line l3
                     where l3.quotation_id = q.id and l3.line_kind = 'ENROL' and not l3.is_gift_line),
    'discount_total', (select coalesce(sum(l3.discount_amount), 0)::bigint from app.quotation_line l3
                        where l3.quotation_id = q.id and l3.line_kind = 'ENROL' and not l3.is_gift_line),
    -- Số đơn đang sống sinh từ báo giá này (cho nút "Đơn hàng" của BH-02).
    'live_order_count', (select count(distinct sl.order_id)::integer
                           from app.quotation_line l2 join app.sales_order_line sl on sl.quotation_line_id = l2.id and sl.is_live
                          where l2.quotation_id = q.id));
end;
$$;

-- Lấy từ 20261121000565_get_order_cancel_block.sql; Tổng niêm yết, tổng chiết khấu không cộng dòng tặng.
create or replace function app.get_order(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
  v_route text;
  v_approver uuid;
  v_hint text;
  v_feature boolean;
  v_can_approve boolean;
  v_can_cancel boolean;
begin
  select * into o from app.sales_order where id = p_id;
  if o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can_wide('SALES_ORDER', 'XEM', o.branch_id);
  -- Người duyệt dự kiến của đơn Nháp: ĐÚNG đầu vào và hàm mà submit_order dùng để chốt assigned_approver_id (R-HT-06): người LẬP đơn
  -- (created_by) qua app.approval_route. Chưa có quản lý trực tiếp thì KHÔNG báo lỗi: đường duyệt THIEU, người duyệt rỗng, để giao diện
  -- hiện khung "chưa có quản lý trực tiếp". Đơn đã trình trở đi thì không trả (đã có assigned_approver_id).
  if o.status_code = 'NHAP' then
    begin
      select r.route, r.approver_id into v_route, v_approver from app.approval_route(o.created_by, o.branch_id, 'DON') r;
    -- Chủ ý bắt mọi lỗi: tra người duyệt dự kiến chỉ để hiển thị, KHÔNG được chặn việc mở màn đơn. Chưa có quản lý thì THIEU; lỗi khác thì để
    -- trống (route null); luật chặn thật vẫn nằm ở submit_order lúc Trình.
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      if v_hint = 'HMT_KHONG_CO_QUAN_LY' then
        v_route := 'THIEU';
        v_approver := null;
      else
        v_route := null;
        v_approver := null;
      end if;
    end;
  end if;
  -- Bốn cờ cho giao diện (Đ283): tính bằng ĐÚNG các hàm không báo lỗi mà hàm ghi dùng (can_see_branch của assert_can, feature_enabled của
  -- require_feature, can_approve_as_manager, order_has_receipt), nên giao diện không tự đoán quyền. Cờ chỉ xét QUYỀN và TRẠNG THÁI, không xét
  -- dữ liệu: thiếu điều khoản, em thiếu năm sinh, chưa có quản lý trực tiếp... vẫn do hàm ghi báo lúc bấm (cờ đúng, lỗi cấu hình khi Trình).
  v_feature := app.feature_enabled('BAN_HANG', o.branch_id);
  -- Duyệt và Từ chối (approve_order, reject_order kiểm y hệt): đơn Đã trình, quyền Duyệt, đúng người duyệt đã chốt (Admin thay khi vắng).
  v_can_approve := coalesce(o.status_code = 'DA_TRINH' and v_feature
                            and app.can_see_branch_wide('SALES_ORDER', 'DUYET', o.branch_id)
                            and app.can_approve_as_manager(o.created_by, 'DON', o.assigned_approver_id, o.approval_route, o.branch_id), false);
  -- Huỷ (cancel_order, R-TIEN-38): đơn Nháp chỉ người lập; đơn Đã trình, Đã duyệt do người duyệt đã chốt; chỉ khi chưa có phiếu thu.
  v_can_cancel := coalesce(o.status_code <> 'HUY' and v_feature
                  and app.can_see_branch_wide('SALES_ORDER', 'HUY', o.branch_id)
                  and case when o.status_code = 'NHAP' then o.created_by is not distinct from auth.uid()
                           else app.can_approve_as_manager(o.created_by, 'DON', o.assigned_approver_id, o.approval_route, o.branch_id) end
                  and not app.order_has_receipt(o.id), false);
  return (to_jsonb(o) - 'search_text') || jsonb_build_object(
    -- Trình (submit_order): đơn Nháp, quyền Sửa ở cơ sở, Bán hàng bật.
    'can_submit', coalesce(o.status_code = 'NHAP' and v_feature and app.can_see_branch_wide('SALES_ORDER', 'SUA', o.branch_id), false),
    'can_cancel', v_can_cancel,
    -- Lý do chặn huỷ đơn (canvas BH05_huy_chan; cùng điều kiện với app.cancel_order): PHIEU_THU (đã có phiếu thu), GHI_DANH (còn ghi danh hiệu lực, «cho học trước»); trống thì không bị chặn.
    'cancel_block', case when o.status_code = 'HUY' then null
                         when app.order_has_receipt(o.id) then 'PHIEU_THU'
                         when exists (select from app.enrollment e where e.order_id = o.id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU')) then 'GHI_DANH'
                         else null end,
    'can_approve', v_can_approve,
    'can_reject', v_can_approve,
    'status', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_STATUS' and c.code = o.status_code),
    'branch_code', (select b.code from app.branch b where b.id = o.branch_id),
    'opportunity_code', (select x.code from app.opportunity x where x.id = o.opportunity_id),
    'quotation_code', (select q.code from app.quotation q where q.id = o.quotation_id),
    'parent_code', (select p.code from app.parent p where p.id = o.parent_id),
    'parent_name', (select p.full_name from app.parent p where p.id = o.parent_id),
    'parent_phone', (select p.phone from app.parent p where p.id = o.parent_id),
    'payment_term_name', (select t.name from app.payment_term t where t.id = o.payment_term_id),
    -- Tổng niêm yết và tổng chiết khấu: DB cộng từ các dòng đã đóng băng, không tính lại; dòng quà tặng không tính (R-TIEN-30).
    'gross_total', (select coalesce(sum(l3.gross_amount), 0)::bigint from app.sales_order_line l3
                     where l3.order_id = o.id and l3.line_kind = 'ENROL' and not l3.is_gift_line),
    'discount_total', (select coalesce(sum(l3.discount_amount), 0)::bigint from app.sales_order_line l3
                        where l3.order_id = o.id and l3.line_kind = 'ENROL' and not l3.is_gift_line),
    -- Chỉ khi đơn Nháp: QUAN_LY, TU_DUYET hoặc THIEU; người duyệt dự kiến; và người đó có quyền Duyệt đơn ở cơ sở này không (Đ205).
    'expected_route', v_route,
    'expected_approver_id', v_approver,
    'expected_approver_name', app.staff_display_name(v_approver),
    'expected_approver_can_approve', case when v_approver is null then null
                                          else app.user_can_at_branch(v_approver, 'SALES_ORDER', 'DUYET', o.branch_id) end,
    -- Q-63, Q-62: MỘT lý do chặn phía người duyệt cho giao diện (dải thông báo cạnh nút trình dùng lại, không đổi DB nữa); chỉ khi đơn Nháp.
    -- KHONG_CO_QUAN_LY, NGUOI_DUYET_BI_KHOA (người duyệt dự kiến đang bị khoá), NGUOI_DUYET_THIEU_QUYEN (không bị khoá nhưng thiếu quyền Duyệt
    -- ở cơ sở), null (không chặn). Trùng mã lỗi của submit_order.
    'expected_block', case when o.status_code <> 'NHAP' then null
                           when v_route = 'THIEU' then 'KHONG_CO_QUAN_LY'
                           when v_approver is null then null
                           when exists (select from app.user_account a where a.id = v_approver and a.is_locked) then 'NGUOI_DUYET_BI_KHOA'
                           when not app.user_can_at_branch(v_approver, 'SALES_ORDER', 'DUYET', o.branch_id) then 'NGUOI_DUYET_THIEU_QUYEN'
                           else null end,
    'created_by_name', app.staff_display_name(o.created_by),
    'submitted_by_name', app.staff_display_name(o.submitted_by),
    'approver_name', app.staff_display_name(o.assigned_approver_id),
    'approved_by_name', app.staff_display_name(o.approved_by),
    'cancel_reason', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_CANCEL_REASON' and c.code = o.cancel_reason_code),
    'has_incomplete_students', exists (
      select from app.sales_order_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
        left join app.student s on s.id = l.student_id
       where l.order_id = o.id
         and (coalesce(s.full_name, v.full_name) is null or coalesce(s.birth_year, v.birth_year) is null)),
    'lines', coalesce((
      select jsonb_agg(to_jsonb(l) - 'order_id' || jsonb_build_object(
               'student_name', coalesce(s.full_name, v.full_name), 'student_birth_year', coalesce(s.birth_year, v.birth_year),
               'student_code', coalesce(s.code, v.student_code),
               'student_complete', (coalesce(s.full_name, v.full_name) is not null and coalesce(s.birth_year, v.birth_year) is not null),
               'gift_policy_name', (select g.name from app.gift_policy g where g.id = l.gift_policy_id),
               'discounts', coalesce((select jsonb_agg(to_jsonb(d) - 'line_id' - 'branch_id' order by d.created_at, d.id)
                                        from app.sales_order_line_discount d where d.line_id = l.id), '[]'::jsonb))
             order by l.line_no)
        from app.sales_order_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
        left join app.student s on s.id = l.student_id
       where l.order_id = o.id), '[]'::jsonb),
    'installments', coalesce((
      select jsonb_agg(jsonb_build_object('seq', i.seq, 'due_days', i.due_days, 'amount', i.amount, 'due_date', i.due_date) order by i.seq)
        from app.sales_order_installment i where i.order_id = o.id), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
               'seq', e.seq, 'event_code', e.event_code, 'from_status', e.from_status, 'to_status', e.to_status,
               'reason_code', e.reason_code, 'note', e.note, 'on_behalf', e.on_behalf, 'created_at', e.created_at, 'total_amount', e.total_amount,
               'actor_name', app.staff_display_name(e.created_by)) order by e.seq)
        from app.sales_order_event e where e.order_id = o.id), '[]'::jsonb));
end;
$$;

-- Lấy từ 20261106000077_don_hang_vuot_tran_canh_bao.sql; chỉ đổi phần luật dòng tặng (B-26-03).
create or replace function app.order_approve_core(p_id uuid, p_acknowledged boolean, p_on_behalf boolean, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  l app.sales_order_line;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_cap numeric := app.get_setting_numeric('discount_total_cap_percent', null);
  v_over text;
  v_note text := p_note;
begin
  -- Đọc LẠI đơn: order_refresh_totals ở submit_order có thể đã đổi needs_acknowledgement sau khi hàm gọi đọc đơn.
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  -- Luật R-V2-11 (anh chốt 06/11, A4): vượt trần chiết khấu chỉ CẢNH BÁO, không chặn và không cần tích đồng ý. Bước duyệt chính là lúc xem xét;
  -- nhật ký ghi người duyệt đơn vượt trần và tổng % cộng dồn từng dòng vượt lúc duyệt. Trần đọc từ tham số discount_total_cap_percent (không viết cứng).
  select string_agg(format('dòng %s %s%%', l2.line_no, to_char(case when l2.is_gift_line then l2.gift_percent else l2.discount_percent + l2.gift_percent end, 'FM999990.0')), '; ' order by l2.line_no)
    into v_over from app.sales_order_line l2 where l2.order_id = p_id and l2.over_cap;
  if v_over is not null then
    v_note := concat_ws(' · ', nullif(p_note, ''), format('Duyệt đơn vượt trần %s%%: %s', to_char(v_cap, 'FM999990.##'), v_over));
  end if;
  -- Luật R-TIEN-35: kiểm lại em đủ họ tên, năm sinh; R-GD-08: kiểm lại lớp.
  perform app.assert_order_students_complete(p_id);
  for l in select * from app.sales_order_line where order_id = p_id order by line_no loop
    perform app.check_order_line_class(l.line_no, l.class_id, l.package_id, v_o.branch_id);
  end loop;
  -- Trigger khoá dòng cho phép riêng việc gắn hồ sơ học sinh và chốt hạn đóng trong lúc duyệt (hmt.order_approve).
  perform set_config('hmt.order_approve', 'on', true);
  -- Luật R-CRM-27: tìm hoặc tạo hồ sơ học sinh; trùng tên và năm sinh trong đơn thì chặn (KD6).
  perform app.order_link_students(p_id, v_o.parent_id, v_o.branch_id);
  -- Lịch đóng tiền đã tính lúc lưu và lúc trình (đơn khoá từ khi trình): chốt hạn đóng (ngày duyệt + số ngày của đợt).
  update app.sales_order_installment set due_date = v_today + due_days where order_id = p_id;
  perform set_config('hmt.order_approve', '', true);
  update app.sales_order set status_code = 'DA_DUYET', approved_at = now(), approved_by = auth.uid(),
         approved_on_behalf = coalesce(p_on_behalf, false), acknowledged = v_o.needs_acknowledgement where id = p_id;
  perform app.order_add_event(p_id, 'DUYET', 'DA_TRINH', 'DA_DUYET', null, null, v_note, coalesce(p_on_behalf, false));
end;
$$;

select set_config('hmt.migration', '', false);
