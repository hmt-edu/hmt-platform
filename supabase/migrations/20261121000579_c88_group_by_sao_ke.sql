-- C88 (KHO-VIEC dòng 14; anh Trường duyệt 20/11 20:38, thư Chat 20:44; migration 579, rủi ro CAO theo quy ước: sửa hàm danh sách tiền). TC-04 Group By «Sao kê» (canvas TC04: nhóm Sao kê, Đã khớp / Chưa khớp).
-- Làm gì: receipt_group_counts nhận thêm trường nhóm `bank` (KHOP | CHUA) và bộ lọc `bank_matched` (cùng nghĩa với list_receipts, migration 576) để số đếm khớp danh sách; receipt_group_label thêm nhãn. Giữ nguyên quyền, phạm vi cơ sở, hai cấp tối đa (Đ35).
-- Chỉ đọc; không đổi bảng, không thêm chỉ mục (nhóm trên cột bank_matched_at đã có trong bảng, phạm vi lọc theo cơ sở như cũ).
select set_config('hmt.migration', 'on', false);

create or replace function app.receipt_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'status' then coalesce((select name from app.catalog_item where catalog_code = 'RECEIPT_STATUS' and code = p_key), p_key)
    when p_field = 'method' then coalesce((select name from app.catalog_item where catalog_code = 'PAYMENT_METHOD' and code = p_key), p_key)
    when p_field = 'branch' then coalesce((select code || ' ' || name from app.branch where id = p_key::uuid), p_key)
    -- C88: nhóm «Sao kê» của TC-04: KHOP = Đã khớp, CHUA = Chưa khớp (cờ bank_matched_at, TC-15).
    when p_field = 'bank' then case p_key when 'KHOP' then 'Đã khớp' when 'CHUA' then 'Chưa khớp' else p_key end
    else p_key end;
$$;

create or replace function app.receipt_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('RECEIPT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_method text[] := array(select jsonb_array_elements_text(p_filters -> 'payment_method'));
  -- C88: bộ lọc «Sao kê» như list_receipts ('KHOP' | 'CHUA'), để số đếm khớp danh sách.
  v_bank text := nullif(p_filters ->> 'bank_matched', '');
  v_order uuid := nullif(p_filters ->> 'order_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_wait_mgr boolean := coalesce((p_filters ->> 'waiting_manager')::boolean, false);
  v_wait_acc boolean := coalesce((p_filters ->> 'waiting_accounting')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu thu.');
  end if;
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status', 'method', 'branch', 'bank'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, hình thức, cơ sở, sao kê).');
  end if;
  with f as not materialized (
    select r.*
      from app.receipt r
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and r.branch_id = v_my_branch))
       and (cardinality(v_status) = 0 or r.status_code = any (v_status))
       and (v_branch is null or r.branch_id = v_branch)
       and (cardinality(v_method) = 0 or r.payment_method_code = any (v_method))
       and (v_bank is null or (v_bank = 'KHOP' and r.bank_matched_at is not null) or (v_bank = 'CHUA' and r.bank_matched_at is null))
       and (v_order is null or r.order_id = v_order)
       and (v_parent is null or r.parent_id = v_parent)
       and (not v_mine or r.created_by = auth.uid())
       and (not v_wait_mgr or (r.status_code = 'DA_GUI' and (r.assigned_approver_id = auth.uid() or r.approval_route = 'TRUONG_CS' and (select app.is_branch_manager_at(auth.uid(), 'RECEIPT', r.branch_id)))))
       and (not v_wait_acc or r.status_code = 'CHO_KE_TOAN')
       and (v_from is null or r.created_at >= v_from)
       and (v_to is null or r.created_at < v_to)
       and (v_q is null or r.search_text like '%' || v_q || '%')
  ),
  keyed as (
    select case v_f1 when 'status' then f.status_code when 'method' then f.payment_method_code when 'branch' then f.branch_id::text
                   when 'bank' then case when f.bank_matched_at is not null then 'KHOP' else 'CHUA' end end as k1,
           case v_f2 when 'status' then f.status_code when 'method' then f.payment_method_code when 'branch' then f.branch_id::text
                   when 'bank' then case when f.bank_matched_at is not null then 'KHOP' else 'CHUA' end end as k2
      from f
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.receipt_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.receipt_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

revoke execute on function app.receipt_group_label(text, text) from public, anon, authenticated;
revoke execute on function app.receipt_group_counts(jsonb, text[]) from public, anon;
grant execute on function app.receipt_group_counts(jsonb, text[]) to authenticated;
select set_config('hmt.migration', '', false);
