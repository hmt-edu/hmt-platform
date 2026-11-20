-- Kho #19 (TT-04 Đối chiếu tái tục): Group By ở máy chủ (một đến hai cấp: cơ sở, campaign, lý do chưa có phiếu), theo docs/nghiep-vu/doi-chieu-group-by.md.
-- (1) app.list_upsale_reconcile: thêm bộ lọc `reason` (mã lý do chưa có phiếu; DA_CO_PHIEU là dòng đã có phiếu) để mở từng nhóm; thân hàm lấy từ migration 553 (bản duy nhất).
-- (2) app.upsale_reconcile_group_counts(tháng, bộ lọc, trường nhóm): số đếm theo nhóm, cùng phạm vi và bộ lọc với list_upsale_reconcile (chỉ đọc, security definer, phạm vi cơ sở trong upsale_reconcile_base).
-- Ai gọi: người có quyền Phiếu tái tục · Xem. Lỗi HMT_NHOM_SAI khi trường nhóm lạ, trùng hoặc quá hai cấp.
-- Chỉ mục: không thêm (cùng nguồn upsale_reconcile_base như danh sách; số dòng một tháng nhỏ, đo ở TT-E).
select set_config('hmt.migration', 'on', false);

create or replace function app.list_upsale_reconcile(p_month date, p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(coalesce(p_limit, app.get_setting_int('list_page_size_default')), app.get_setting_int('list_page_size_max'));
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_only_missing boolean := coalesce((p_filters ->> 'only_missing')::boolean, false);
  -- Group By (TT-04): lý do chưa có phiếu; mã DA_CO_PHIEU là dòng đã có phiếu (missing_reason rỗng).
  v_reasons text[] := case jsonb_typeof(p_filters -> 'reason') when 'array' then array(select jsonb_array_elements_text(p_filters -> 'reason'))
                           when 'string' then array[p_filters ->> 'reason'] else array[]::text[] end;
  v_total bigint;
  v_rows jsonb;
begin
  with f as (
    select b.*, s.code as student_code, s.full_name as student_name, c.code as class_code, br.code as branch_code
      from app.upsale_reconcile_base(p_month, nullif(p_filters ->> 'branch_id', '')::uuid) b
      join app.student s on s.id = b.student_id
      join app.class c on c.id = b.class_id
      join app.branch br on br.id = b.branch_id
     where (not v_only_missing or b.ticket_id is null)
       and (cardinality(v_reasons) = 0 or coalesce(b.missing_reason, 'DA_CO_PHIEU') = any (v_reasons))
       and (v_q is null or s.full_name ilike '%' || v_q || '%' or s.code ilike '%' || v_q || '%' or c.code ilike '%' || v_q || '%')
  ), pg as (
    select * from f order by (ticket_id is not null), expected_end_date, student_code, class_code
     limit v_limit offset greatest(coalesce(p_offset, 0), 0)
  )
  select (select count(*) from f),
         coalesce((select jsonb_agg(jsonb_build_object(
                     'student_id', student_id, 'student_code', student_code, 'student_name', student_name,
                     'class_id', class_id, 'class_code', class_code,
                     'enrollment_codes', enrollment_codes, 'branch_code', branch_code,
                     'hours_left', hours_left, 'expected_end_date', expected_end_date,
                     'campaign_label', 'Tái tục ' || to_char(date_trunc('month', p_month), 'MM/YYYY'),
                     'ticket_id', ticket_id, 'ticket_code', ticket_code, 'ticket_origin', ticket_origin, 'missing_reason', missing_reason)
                   order by (ticket_id is not null), expected_end_date, student_code, class_code) from pg), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- Tên hiển thị của một giá trị nhóm (branch, campaign, reason); khoá trống: giao diện hiện «Chưa có».
create or replace function app.upsale_reconcile_group_label(p_field text, p_key text, p_month date)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case p_field
           when 'branch' then (select b.code from app.branch b where b.id = nullif(p_key, '')::uuid)
           when 'campaign' then 'Tái tục ' || to_char(date_trunc('month', p_month), 'MM/YYYY')
           when 'reason' then case p_key when 'DA_CO_PHIEU' then 'Đã có phiếu' when 'CO_PHIEU_L5' then 'Có phiếu L5 gần đây'
                                         when 'LOP_CHUA_CO_LICH' then 'Lớp chưa có lịch' when 'CHO_QUET_DEM' then 'Chờ đợt quét đêm' end
         end;
$$;

-- app.upsale_reconcile_group_counts(tháng, bộ lọc, trường nhóm): bộ lọc như list_upsale_reconcile (branch_id, only_missing, q, reason).
-- Kết quả {total, groups:[{k1, l1, k2, l2, count}]}.
create or replace function app.upsale_reconcile_group_counts(p_month date, p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_only_missing boolean := coalesce((p_filters ->> 'only_missing')::boolean, false);
  v_reasons text[] := case jsonb_typeof(p_filters -> 'reason') when 'array' then array(select jsonb_array_elements_text(p_filters -> 'reason'))
                           when 'string' then array[p_filters ->> 'reason'] else array[]::text[] end;
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  -- Luật Đ35: chỉ nhóm theo các trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('branch', 'campaign', 'reason'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (cơ sở, campaign, lý do chưa có phiếu).');
  end if;
  with f as (
    select b.*
      from app.upsale_reconcile_base(p_month, nullif(p_filters ->> 'branch_id', '')::uuid) b
      join app.student s on s.id = b.student_id
      join app.class c on c.id = b.class_id
     where (not v_only_missing or b.ticket_id is null)
       and (cardinality(v_reasons) = 0 or coalesce(b.missing_reason, 'DA_CO_PHIEU') = any (v_reasons))
       and (v_q is null or s.full_name ilike '%' || v_q || '%' or s.code ilike '%' || v_q || '%' or c.code ilike '%' || v_q || '%')
  ), keyed as (
    select case v_f1 when 'branch' then f.branch_id::text when 'campaign' then to_char(date_trunc('month', p_month), 'YYYY-MM')
                     when 'reason' then coalesce(f.missing_reason, 'DA_CO_PHIEU') end as k1,
           case v_f2 when 'branch' then f.branch_id::text when 'campaign' then to_char(date_trunc('month', p_month), 'YYYY-MM')
                     when 'reason' then coalesce(f.missing_reason, 'DA_CO_PHIEU') end as k2
      from f
  ), grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.upsale_reconcile_group_label(v_f1, g.k1, p_month),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.upsale_reconcile_group_label(v_f2, g.k2, p_month) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;
revoke execute on function app.upsale_reconcile_group_label(text, text, date) from public, anon, authenticated;
revoke execute on function app.upsale_reconcile_group_counts(date, jsonb, text[]) from public, anon;
grant execute on function app.upsale_reconcile_group_counts(date, jsonb, text[]) to authenticated;
