-- Migration 476 (Code D, 19/11/2026): CH-04 Chiết khấu theo canvas: cột «Áp dụng cho» (Báo giá, Đơn, Phiếu thu). Anh Trường chốt 16:46 «cứ theo thiết kế». CAO (cấu hình giá).
-- app.discount_policy.applies_to: mặc định mọi chính sách có sẵn áp dụng CẢ BA, nên cách tính hiện tại KHÔNG đổi. Đơn và báo giá đã tạo vẫn chụp giá trị lúc tạo (CLAUDE.md, cấu hình mục 3).
-- Hiệu lực: danh sách chính sách mà báo giá và đơn mời chọn (app.list_applicable_discount_policies) chỉ trả chính sách có Báo giá hoặc Đơn. Hàm tính tiền dùng chung
-- app.price_line không có ngữ cảnh «báo giá hay đơn», nên máy chủ CHƯA từ chối riêng từng ngữ cảnh khi gọi thẳng rpc (ghi chỗ vênh ở PR); Phiếu thu không có dòng chiết khấu nên giá trị này chỉ lưu và hiện.
-- Chỉ mục: không thêm (bảng vài chục dòng).
alter table app.discount_policy add column applies_to text[] not null default array['BAO_GIA', 'DON', 'PHIEU_THU'];
alter table app.discount_policy add constraint discount_policy_applies_to_check
  check (cardinality(applies_to) > 0 and applies_to <@ array['BAO_GIA', 'DON', 'PHIEU_THU']);
comment on column app.discount_policy.applies_to is 'Chính sách áp dụng cho: BAO_GIA, DON, PHIEU_THU (CH-04). Mặc định cả ba.';

-- app.save_discount_policy (thay bản migration 044): thêm applies_to trong p_data (tuỳ chọn; thiếu thì giữ nguyên khi sửa, mặc định cả ba khi tạo).
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
                                       package_type_codes, branch_ids, applies_to)
      values (btrim(p_data ->> 'code'), btrim(p_data ->> 'name'), p_data ->> 'kind', (p_data ->> 'max_value')::numeric,
              coalesce((p_data ->> 'fixed_value')::boolean, false), coalesce((p_data ->> 'requires_approval')::boolean, false),
              (p_data ->> 'valid_from')::date, nullif(p_data ->> 'valid_to', '')::date, v_types, v_branches, v_applies)
      returning id into v_id;
    exception
      when unique_violation then
        perform app.raise_error('HMT_MA_TRUNG', 'Mã chính sách này đã có.');
      when check_violation then
        perform app.raise_error('HMT_CHINH_SACH_SAI',
          'Chính sách không hợp lệ: phần trăm từ 0 đến 100; tặng giờ không đặt "áp đúng mức".');
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
        applies_to = case when p_data ? 'applies_to' then v_applies else applies_to end
       where id = p_id;
    exception when check_violation then
      perform app.raise_error('HMT_CHINH_SACH_SAI',
        'Chính sách không hợp lệ: phần trăm từ 0 đến 100; tặng giờ không đặt "áp đúng mức".');
    end;
  end if;
  return v_id;
end;
$$;

-- app.list_applicable_discount_policies (thay bản migration 085): thêm khoá applies_to, chỉ trả chính sách áp dụng cho Báo giá hoặc Đơn.
create or replace function app.list_applicable_discount_policies(p_opportunity_id uuid)
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
             'id', d.id, 'code', d.code, 'name', d.name, 'kind', d.kind,
             'max_value', case when d.is_flexible then app.get_setting('flexible_discount_max_percent')::numeric else d.max_value end,
             'is_flexible', d.is_flexible, 'fixed_value', d.fixed_value,
             'requires_approval', d.requires_approval, 'package_type_codes', to_jsonb(d.package_type_codes),
             'applies_to', to_jsonb(d.applies_to)) order by d.code)
      from app.discount_policy d
     where d.is_active and d.applies_to && array['BAO_GIA', 'DON']
       and d.valid_from <= v_on and (d.valid_to is null or d.valid_to >= v_on)
       and (cardinality(d.branch_ids) = 0 or v_opp.branch_id = any (d.branch_ids))), '[]'::jsonb);
end;
$$;
