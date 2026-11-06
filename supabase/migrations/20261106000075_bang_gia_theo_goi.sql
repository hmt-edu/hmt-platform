-- Đợt 2 (anh chốt 06/11): màn Bảng giá (CH-03) làm THEO GÓI, không theo "bản bảng giá" như khung CH03 (R-TIEN-10, 14, 15; spec 02).
-- (1) list_package_prices: danh sách gói kèm giá hiệu lực tại một ngày (offline, online) và trạng thái "Chưa có giá" (chưa có dòng giá)
--     hay "Không bán" (dòng giá để trống, hoặc dịch vụ, tài liệu không có online); xếp theo loại gói, môn, khối; phân trang ở máy chủ.
-- (2) add_package_prices: thêm nhiều dòng giá MỘT giao dịch (một lần gọi, sai một dòng thì hoàn tác cả lần), dùng add_package_price.
-- Ai gọi: (1) quyền Cấu hình bán hàng · Xem; (2) Admin (Cấu hình bán hàng · Tạo).
select set_config('hmt.migration', 'on', false);

-- Trạng thái một ô giá tại ngày p_on: {state, price, effective_from}.
-- state: CO_GIA | CHUA_CO_GIA (chưa có dòng giá, R-TIEN-10) | KHONG_BAN (dòng giá để trống, hoặc dịch vụ, tài liệu không có online, R-TIEN-15).
create or replace function app.package_price_cell(p_package_id uuid, p_type text, p_mode text, p_on date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r record;
begin
  -- Luật R-TIEN-15: dịch vụ, tài liệu không có giá online.
  if p_type in ('DV', 'TL') and p_mode = 'ONL' then
    return jsonb_build_object('state', 'KHONG_BAN', 'price', null, 'effective_from', null);
  end if;
  select unit_price, effective_from into r
    from app.package_price
   where package_id = p_package_id and delivery_mode_code = p_mode and effective_from <= p_on
   order by effective_from desc limit 1;
  if not found then
    return jsonb_build_object('state', 'CHUA_CO_GIA', 'price', null, 'effective_from', null);
  end if;
  return jsonb_build_object('state', case when r.unit_price is null then 'KHONG_BAN' else 'CO_GIA' end,
                            'price', r.unit_price, 'effective_from', r.effective_from);
end;
$$;

-- Danh sách gói kèm giá hiệu lực. Đầu vào: p_on (mặc định hôm nay theo giờ Việt Nam), p_filters (q, type, subject, grade, status
-- 'active' | 'inactive'), p_limit (tối đa list_page_size_max), p_offset. Kết quả: {total, rows[]} mỗi dòng: id, code, name, package_type_code,
-- subject_code, grade_from_code, grade_to_code, is_active, offline, online. Luật: R-TIEN-10, 14, 15.
create or replace function app.list_package_prices(
  p_on date default null, p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_on date := coalesce(p_on, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_type text := nullif(p_filters ->> 'type', '');
  v_subject text := nullif(p_filters ->> 'subject', '');
  v_grade text := nullif(p_filters ->> 'grade', '');
  v_status text := nullif(p_filters ->> 'status', '');
  v_result jsonb;
begin
  if not app.has_permission('CONFIG_SALES', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem bảng giá.');
  end if;
  with base as (
    select p.*,
           coalesce((select sort_order from app.catalog_item where catalog_code = 'PACKAGE_TYPE' and code = p.package_type_code), 0) as t_ord,
           coalesce((select sort_order from app.catalog_item where catalog_code = 'SUBJECT' and code = p.subject_code), 0) as s_ord,
           coalesce((select sort_order from app.catalog_item where catalog_code = 'GRADE' and code = p.grade_from_code), 0) as g_ord
      from app.sales_package p
     where (v_q is null or app.fold_text(p.code || ' ' || p.name || ' ' || coalesce(p.legacy_ref, '')) like '%' || v_q || '%')
       and (v_type is null or p.package_type_code = v_type)
       and (v_subject is null or p.subject_code = v_subject)
       and (v_grade is null or p.grade_from_code = v_grade)
       and (v_status is null or p.is_active = (v_status = 'active'))
  ), page as (
    select * from base order by t_ord, s_ord, g_ord, code limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'total', (select count(*) from base),
    'rows', coalesce((select jsonb_agg(jsonb_build_object(
        'id', g.id, 'code', g.code, 'name', g.name, 'package_type_code', g.package_type_code, 'subject_code', g.subject_code,
        'grade_from_code', g.grade_from_code, 'grade_to_code', g.grade_to_code, 'is_active', g.is_active,
        'offline', app.package_price_cell(g.id, g.package_type_code, 'OFF', v_on),
        'online', app.package_price_cell(g.id, g.package_type_code, 'ONL', v_on)) order by g.t_ord, g.s_ord, g.g_ord, g.code)
      from page g), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

-- Mã gói khớp bộ lọc (loại, môn, khối, trạng thái, tìm) để "chọn tất cả theo bộ lọc" ở hộp Thêm bảng giá mới. Ai gọi: Admin.
-- Kết quả: {total, items[{id, package_type_code}]} (loại gói để giao diện bỏ giá online của dịch vụ, tài liệu), tối đa list_page_size_max (hộp cảnh báo khi bị cắt qua total).
create or replace function app.package_ids_for_filter(p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_max integer := app.get_setting_int('list_page_size_max');
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_type text := nullif(p_filters ->> 'type', '');
  v_subject text := nullif(p_filters ->> 'subject', '');
  v_grade text := nullif(p_filters ->> 'grade', '');
  v_total integer;
  v_ids jsonb;
begin
  perform app.assert_config_sales('TAO');
  select count(*) into v_total from app.sales_package p
   where p.is_active
     and (v_q is null or app.fold_text(p.code || ' ' || p.name || ' ' || coalesce(p.legacy_ref, '')) like '%' || v_q || '%')
     and (v_type is null or p.package_type_code = v_type) and (v_subject is null or p.subject_code = v_subject)
     and (v_grade is null or p.grade_from_code = v_grade);
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'package_type_code', package_type_code)), '[]'::jsonb) into v_ids from (
    select p.id, p.package_type_code from app.sales_package p
     where p.is_active
       and (v_q is null or app.fold_text(p.code || ' ' || p.name || ' ' || coalesce(p.legacy_ref, '')) like '%' || v_q || '%')
       and (v_type is null or p.package_type_code = v_type) and (v_subject is null or p.subject_code = v_subject)
       and (v_grade is null or p.grade_from_code = v_grade)
     order by p.code limit v_max) s;
  return jsonb_build_object('total', v_total, 'items', v_ids);
end;
$$;

-- Thêm nhiều dòng giá một giao dịch. Ai gọi: Admin (Cấu hình bán hàng · Tạo). p_items: mảng {package_id, mode, unit_price} (unit_price null =
-- không bán hình thức đó từ ngày hiệu lực). Sai một dòng (đã có giá ngày đó, gói ngừng, online của dịch vụ…) thì hoàn tác cả lần. Kết quả: số dòng đã thêm.
-- Luật: R-TIEN-10, 14, 15 (qua add_package_price và trigger package_price_rules).
create or replace function app.add_package_prices(p_effective_from date, p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  i jsonb;
  v_count integer := 0;
begin
  perform app.assert_config_sales('TAO');
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chưa có giá nào để thêm.');
  end if;
  for i in select * from jsonb_array_elements(p_items) loop
    perform app.add_package_price((i ->> 'package_id')::uuid, i ->> 'mode', nullif(i ->> 'unit_price', '')::bigint, p_effective_from);
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke execute on function app.package_price_cell(uuid, text, text, date) from public, anon, authenticated;
revoke execute on function app.list_package_prices(date, jsonb, integer, integer), app.package_ids_for_filter(jsonb),
  app.add_package_prices(date, jsonb) from public, anon;
grant execute on function app.list_package_prices(date, jsonb, integer, integer), app.package_ids_for_filter(jsonb),
  app.add_package_prices(date, jsonb) to authenticated;

select set_config('hmt.migration', '', false);
