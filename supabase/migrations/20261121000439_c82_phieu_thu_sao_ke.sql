-- C82 (KHO-VIEC dòng 14, TC-04 Chờ kế toán duyệt): list_receipts trả thêm `bank_matched` (đã khớp sao kê) và nhận bộ lọc `bank_matched` ('KHOP' | 'CHUA') cho cột và nhóm lọc «Sao kê» của canvas TC04.
-- Dữ liệu đối soát đã có từ migration 478 (TC-15: cột receipt.bank_matched_at, chỉ Kế toán và Admin đánh dấu). Giữ nguyên mọi luật, quyền, phạm vi của bản migration 434; chỉ đọc, không đổi bảng, không thêm chỉ mục.
select set_config('hmt.migration', 'on', false);

create or replace function app.list_receipts(p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc', p_limit integer default null,
                                             p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('RECEIPT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_method text[] := array(select jsonb_array_elements_text(p_filters -> 'payment_method'));
  -- C82: bộ lọc «Sao kê» của TC-04: 'KHOP' = đã khớp sao kê, 'CHUA' = chưa khớp; khác hoặc trống = không lọc.
  v_bank text := nullif(p_filters ->> 'bank_matched', '');
  v_order uuid := nullif(p_filters ->> 'order_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_wait_mgr boolean := coalesce((p_filters ->> 'waiting_manager')::boolean, false);
  v_wait_acc boolean := coalesce((p_filters ->> 'waiting_accounting')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu thu.');
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
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'amount_desc' then f.amount end desc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'status_code', p.status_code,
             'status', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_STATUS' and c.code = p.status_code),
             'order_id', p.order_id, 'order_code', o.code, 'is_opening_debt', p.is_opening_debt, 'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name,
             'amount', p.amount, 'payment_method_code', p.payment_method_code,
             'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = p.payment_method_code),
             'paid_on', p.paid_on, 'branch_code', b.code, 'collect_branch_code', cb.code,
             'created_at', p.created_at, 'created_by_name', app.staff_display_name(p.created_by),
             'approver_name', app.staff_display_name(p.assigned_approver_id), 'submitted_at', p.submitted_at,
             -- Người nhận tiền (cột của canvas TC01); bắt buộc có từ khi lập phiếu.
             'receiver_name', app.staff_display_name(p.receiver_id),
             -- C67 (Kho #14, TC-04): mã giao dịch của phiếu cho cột «Mã giao dịch» của hàng chờ kế toán.
             'txn_ref', p.txn_ref,
             -- C82 (Kho #14, TC-04): «Sao kê» = phiếu đã được Kế toán đánh dấu khớp ở TC-15 (cột bank_matched_at, migration 478).
             'bank_matched', p.bank_matched_at is not null)
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'amount_desc' then p.amount end desc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.branch cb on cb.id = p.collect_branch_id
    join app.parent par on par.id = p.parent_id
    left join app.sales_order o on o.id = p.order_id;
  return v_result;
end;
$$;
select set_config('hmt.migration', '', false);
