-- CH-04 Quà tặng: cột «Áp dụng cho» (Báo giá, Đơn, Phiếu thu) theo canvas 9933 (CH04_chinh, form «Thêm chính sách quà tặng»); Chat duyệt #460 (21/11/2026): luật như chiết khấu theo R-TIEN-30. CAO (cấu hình giá, báo giá, đơn).
-- app.gift_policy.applies_to: mặc định mọi chính sách quà tặng có sẵn áp dụng CẢ BA, nên danh sách quà tặng mời chọn ở báo giá và đơn KHÔNG đổi với dữ liệu cũ.
-- Đơn và báo giá đã tạo vẫn chụp giá trị lúc tạo (CLAUDE.md, cấu hình mục 3).
-- Hiệu lực: app.list_applicable_gift_policies chỉ trả chính sách có Báo giá hoặc Đơn. Hàm tính tiền app.price_line không có ngữ cảnh «báo giá hay đơn», nên máy chủ CHƯA từ chối riêng từng ngữ cảnh khi gọi thẳng rpc (cùng chỗ vênh với chiết khấu, migration 476); Phiếu thu không có dòng quà nên giá trị này chỉ lưu và hiện.
-- Chỉ mục: không thêm (bảng vài chục dòng).
alter table app.gift_policy add column applies_to text[] not null default array['BAO_GIA', 'DON', 'PHIEU_THU'];
alter table app.gift_policy add constraint gift_policy_applies_to_check
  check (cardinality(applies_to) > 0 and applies_to <@ array['BAO_GIA', 'DON', 'PHIEU_THU']);
comment on column app.gift_policy.applies_to is 'Chính sách quà tặng áp dụng cho: BAO_GIA, DON, PHIEU_THU (CH-04). Mặc định cả ba.';

-- app.save_gift_policy (thay bản migration 044): thêm applies_to trong p_data (tuỳ chọn; thiếu thì giữ nguyên khi sửa, mặc định cả ba khi tạo).
create or replace function app.save_gift_policy(p_id uuid, p_data jsonb)
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
  -- Luật CH-04 (canvas 9933): «Áp dụng cho» chỉ gồm Báo giá, Đơn, Phiếu thu và không để trống (như chiết khấu, R-TIEN-30).
  if p_data ? 'applies_to' and (cardinality(v_applies) = 0 or not v_applies <@ array['BAO_GIA', 'DON', 'PHIEU_THU']) then
    perform app.raise_error('HMT_AP_DUNG_CHO_SAI', 'Chọn ít nhất một nơi áp dụng: Báo giá, Đơn hoặc Phiếu thu.');
  end if;
  if p_id is null then
    perform app.assert_config_sales('TAO');
    if btrim(coalesce(p_data ->> 'code', '')) = '' or btrim(coalesce(p_data ->> 'name', '')) = ''
       or nullif(p_data ->> 'valid_from', '') is null or nullif(p_data ->> 'max_quantity', '') is null
       or nullif(p_data ->> 'gift_package_id', '') is null then
      perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập mã, tên, gói quà, số lượng tối đa và ngày bắt đầu hiệu lực.');
    end if;
    begin
      insert into app.gift_policy (code, name, gift_package_id, max_quantity, requires_approval, valid_from, valid_to,
                                   package_type_codes, branch_ids, applies_to)
      values (btrim(p_data ->> 'code'), btrim(p_data ->> 'name'), (p_data ->> 'gift_package_id')::uuid,
              (p_data ->> 'max_quantity')::numeric, coalesce((p_data ->> 'requires_approval')::boolean, false),
              (p_data ->> 'valid_from')::date, nullif(p_data ->> 'valid_to', '')::date, v_types, v_branches, v_applies)
      returning id into v_id;
    exception
      when unique_violation then
        perform app.raise_error('HMT_MA_TRUNG', 'Mã chính sách này đã có.');
      when check_violation then
        perform app.raise_error('HMT_CHINH_SACH_SAI', 'Số lượng tối đa phải lớn hơn 0.');
    end;
  else
    perform app.assert_config_sales('SUA');
    if not exists (select from app.gift_policy where id = p_id) then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy chính sách.');
    end if;
    begin
      update app.gift_policy set
        name = coalesce(nullif(btrim(p_data ->> 'name'), ''), name),
        gift_package_id = coalesce((p_data ->> 'gift_package_id')::uuid, gift_package_id),
        max_quantity = coalesce((p_data ->> 'max_quantity')::numeric, max_quantity),
        requires_approval = coalesce((p_data ->> 'requires_approval')::boolean, requires_approval),
        valid_from = coalesce((p_data ->> 'valid_from')::date, valid_from),
        valid_to = case when p_data ? 'valid_to' then nullif(p_data ->> 'valid_to', '')::date else valid_to end,
        package_type_codes = case when p_data ? 'package_type_codes' then v_types else package_type_codes end,
        branch_ids = case when p_data ? 'branch_ids' then v_branches else branch_ids end,
        applies_to = case when p_data ? 'applies_to' then v_applies else applies_to end
       where id = p_id;
    exception when check_violation then
      perform app.raise_error('HMT_CHINH_SACH_SAI', 'Số lượng tối đa phải lớn hơn 0.');
    end;
  end if;
  return v_id;
end;
$$;

-- app.list_applicable_gift_policies (thay bản migration 058): thêm khoá applies_to, chỉ trả chính sách áp dụng cho Báo giá hoặc Đơn.
create or replace function app.list_applicable_gift_policies(p_opportunity_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_opp app.opportunity;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  v_opp := app.assert_quotation_helper_access(p_opportunity_id);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', g.id, 'code', g.code, 'name', g.name, 'max_quantity', g.max_quantity, 'requires_approval', g.requires_approval,
             'package_type_codes', to_jsonb(g.package_type_codes), 'applies_to', to_jsonb(g.applies_to),
             'gift_package', jsonb_build_object('id', p.id, 'code', p.code, 'name', p.name, 'package_type_code', p.package_type_code,
                                                'unit_code', app.package_unit(p.package_type_code))) order by g.code)
      from app.gift_policy g
      join app.sales_package p on p.id = g.gift_package_id
     where g.is_active and p.is_active and g.applies_to && array['BAO_GIA', 'DON'] and g.valid_from <= v_on and (g.valid_to is null or g.valid_to >= v_on)
       and (cardinality(g.branch_ids) = 0 or v_opp.branch_id = any (g.branch_ids))), '[]'::jsonb);
end;
$$;
