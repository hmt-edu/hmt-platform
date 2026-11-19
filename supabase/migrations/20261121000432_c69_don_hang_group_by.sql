-- C69 (KHO-VIEC dòng 18, BH-06 Đơn hàng): Group By ở máy chủ cho danh sách Đơn hàng (canvas K1_nhom: tối đa hai cấp). Theo mẫu appointment_group_counts (Đ35).
-- Trường nhóm: status (tình trạng), branch (cơ sở). «Sale» và «Thu tiền» của gợi ý F65 chưa làm (cần lọc theo người lập và tình trạng thu ở list_orders).
-- Ai gọi: người có quyền Đơn hàng · Xem (phạm vi như list_orders). Bộ lọc cùng khoá như list_orders. Chỉ đọc.
-- Lỗi: HMT_KHONG_CO_QUYEN, HMT_NHOM_SAI.
select set_config('hmt.migration', 'on', false);

create or replace function app.order_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'status' then coalesce((select name from app.catalog_item where catalog_code = 'ORDER_STATUS' and code = p_key), p_key)
    when p_field = 'branch' then coalesce((select code || ' ' || name from app.branch where id = p_key::uuid), p_key)
    else p_key end;
$$;

create or replace function app.order_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SALES_ORDER', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_quo uuid := nullif(p_filters ->> 'quotation_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_waiting boolean := coalesce((p_filters ->> 'waiting_me')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  -- Luật: quyền xem đơn hàng.
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách đơn hàng.');
  end if;
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status', 'branch'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, cơ sở).');
  end if;
  with f as not materialized (
    select o.*
      from app.sales_order o
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and o.branch_id = v_my_branch))
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or o.status_code = any (v_status))
       and (v_branch is null or o.branch_id = v_branch)
       and (v_opp is null or o.opportunity_id = v_opp)
       and (v_quo is null or o.quotation_id = v_quo)
       and (v_parent is null or o.parent_id = v_parent)
       and (not v_mine or o.created_by = auth.uid())
       and (not v_waiting or (o.status_code = 'DA_TRINH' and (o.assigned_approver_id = auth.uid() or o.approval_route = 'TRUONG_CS' and (select app.is_branch_manager_at(auth.uid(), 'SALES_ORDER', o.branch_id)))))
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
  ),
  keyed as (
    select case v_f1 when 'status' then f.status_code when 'branch' then f.branch_id::text end as k1,
           case v_f2 when 'status' then f.status_code when 'branch' then f.branch_id::text end as k2
      from f
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.order_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.order_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

revoke execute on function app.order_group_label(text, text) from public, anon, authenticated;
revoke execute on function app.order_group_counts(jsonb, text[]) from public, anon;
grant execute on function app.order_group_counts(jsonb, text[]) to authenticated;
select set_config('hmt.migration', '', false);
