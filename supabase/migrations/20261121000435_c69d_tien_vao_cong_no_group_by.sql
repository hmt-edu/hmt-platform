-- C69 (KHO-VIEC dòng 18, TC-08 Khoản tiền vào và TC-13 Công nợ): Group By ở máy chủ (canvas K1_nhom, tối đa hai cấp), theo mẫu appointment_group_counts (Đ35).
-- TC-08: trường nhóm branch (cơ sở), day (ngày ghi, giờ Việt Nam). TC-13: branch (cơ sở), sale (người lập đơn), status (tình trạng nợ: quá hạn, sắp đến hạn, chưa đến hạn). «Đợt» của gợi ý F65 chưa làm.
-- Ai gọi: người có quyền Kế toán · Xem (TC-08) và Đơn hàng · Xem (TC-13), phạm vi như hàm danh sách; bộ lọc cùng khoá như list_money_in, list_receivables. Chỉ đọc. Lỗi: HMT_KHONG_CO_QUYEN, HMT_NHOM_SAI.
select set_config('hmt.migration', 'on', false);

create or replace function app.money_in_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ACCOUNTING', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_kind text := nullif(p_filters ->> 'kind', '');
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem sổ khoản tiền vào.');
  end if;
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('branch', 'day'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (cơ sở, ngày).');
  end if;
  with f as not materialized (
    select m.*, r.code as receipt_code, r.search_text, orig.code as reversal_of_code,
           exists (select from app.money_in x where x.reversal_of = m.id) as is_reversed
      from app.money_in m
      left join app.receipt r on r.id = m.receipt_id
      left join app.money_in orig on orig.id = m.reversal_of
      left join app.receipt ro on ro.id = orig.receipt_id
     where (v_scope = 'TOAN_HE_THONG' or m.branch_id = v_my_branch)
       and (v_branch is null or m.branch_id = v_branch)
       and (v_from is null or m.created_at >= v_from)
       and (v_to is null or m.created_at < v_to)
       and (v_kind is null or (v_kind = 'THU' and m.amount > 0) or (v_kind = 'DAO' and m.amount < 0))
       and (v_q is null or coalesce(r.search_text, ro.search_text) like '%' || v_q || '%' or app.fold_text(m.code) like '%' || v_q || '%' or app.fold_text(orig.code) like '%' || v_q || '%')
  ),
  keyed as (
    select case v_f1 when 'branch' then f.branch_id::text when 'day' then (f.created_at at time zone 'Asia/Ho_Chi_Minh')::date::text end as k1,
           case v_f2 when 'branch' then f.branch_id::text when 'day' then (f.created_at at time zone 'Asia/Ho_Chi_Minh')::date::text end as k2
      from f
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.treasury_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.treasury_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 desc nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

create or replace function app.receivable_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SALES_ORDER', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_soon integer := app.get_setting_int('debt_due_soon_days');
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_sale uuid := nullif(p_filters ->> 'sale_id', '')::uuid;
  v_from date := nullif(p_filters ->> 'due_from', '')::date;
  v_to date := nullif(p_filters ->> 'due_to', '')::date;
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem công nợ.');
  end if;
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('branch', 'sale', 'status'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (cơ sở, người lập đơn, tình trạng nợ).');
  end if;
  with ord as not materialized (
    select o.id, o.code, o.branch_id, o.parent_id, o.created_by,
           (select coalesce(sum(m.amount), 0) from app.money_in m where m.order_id = o.id)::bigint as paid_total,
           (select count(*) from app.sales_order_installment c where c.order_id = o.id) as seq_count
      from app.sales_order o
     where o.status_code = 'DA_DUYET'
       and (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and o.branch_id = v_my_branch))
       and (v_branch is null or o.branch_id = v_branch)
       and (v_sale is null or o.created_by = v_sale)
  ),
  inst as (
    select o.id as order_id, o.code as order_code, o.branch_id, o.parent_id, o.created_by, o.seq_count,
           i.seq, i.due_date, i.amount as due_amount,
           greatest(least(i.amount, o.paid_total - coalesce(sum(i.amount) over (partition by i.order_id order by i.seq rows between unbounded preceding and 1 preceding), 0)), 0)::bigint as paid_amount
      from ord o join app.sales_order_installment i on i.order_id = o.id
     where i.due_date is not null
  ),
  f as not materialized (
    select x.*, par.full_name as parent_name, (x.due_amount - x.paid_amount) as owed,
           case when x.due_date < v_today then 'QUA_HAN' when x.due_date <= v_today + v_soon then 'SAP_DEN_HAN' else 'CHUA_DEN_HAN' end as status
      from inst x join app.parent par on par.id = x.parent_id
     where x.due_amount > x.paid_amount
       and (v_from is null or x.due_date >= v_from)
       and (v_to is null or x.due_date <= v_to)
       and (v_q is null or app.fold_text(x.order_code) like '%' || v_q || '%' or app.fold_text(par.full_name) like '%' || v_q || '%' or par.phone like '%' || v_q || '%')
  ),
  g as (select * from f where cardinality(v_status) = 0 or status = any (v_status)),
  keyed as (
    select case v_f1 when 'branch' then g.branch_id::text when 'sale' then g.created_by::text when 'status' then g.status end as k1,
           case v_f2 when 'branch' then g.branch_id::text when 'sale' then g.created_by::text when 'status' then g.status end as k2
      from g
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.treasury_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.treasury_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

create or replace function app.treasury_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'branch' then coalesce((select code || ' ' || name from app.branch where id = p_key::uuid), p_key)
    when p_field = 'sale' then coalesce(app.staff_display_name(p_key::uuid), p_key)
    when p_field = 'day' then to_char(p_key::date, 'DD/MM/YYYY')
    when p_field = 'status' then case p_key when 'QUA_HAN' then 'Quá hạn' when 'SAP_DEN_HAN' then 'Sắp đến hạn' when 'CHUA_DEN_HAN' then 'Chưa đến hạn' else p_key end
    else p_key end;
$$;

revoke execute on function app.treasury_group_label(text, text) from public, anon, authenticated;
revoke execute on function app.money_in_group_counts(jsonb, text[]), app.receivable_group_counts(jsonb, text[]) from public, anon;
grant execute on function app.money_in_group_counts(jsonb, text[]), app.receivable_group_counts(jsonb, text[]) to authenticated;
select set_config('hmt.migration', '', false);
