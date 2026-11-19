-- C76 (TC-09, so canvas): list_money_in trả thêm `reversed_by_code` (mã khoản đảo đã hoàn tác khoản này) để cột Ghi chú hiện «Đã hoàn tác bằng …» như canvas TC09_dao. Chỉ thêm một khoá vào kết quả; mọi luật, phạm vi, bộ lọc giữ nguyên bản migration 251. Chỉ đọc.
select set_config('hmt.migration', 'on', false);

create or replace function app.list_money_in(p_filters jsonb default '{}'::jsonb, p_sort text default 'date_desc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ACCOUNTING', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_kind text := nullif(p_filters ->> 'kind', '');
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem sổ khoản tiền vào.');
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
  page as (
    select * from f
     order by case when p_sort = 'date_asc' then f.created_at end asc,
              case when p_sort = 'amount_desc' then f.amount end desc,
              case when p_sort = 'amount_asc' then f.amount end asc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'sum', (select coalesce(sum(amount), 0) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'receipt_id', p.receipt_id, 'receipt_code', p.receipt_code,
             'order_id', p.order_id, 'order_code', o.code, 'parent_id', p.parent_id, 'parent_name', par.full_name,
             'amount', p.amount, 'created_at', p.created_at, 'branch_code', b.code,
             'reversal_of_code', p.reversal_of_code, 'is_reversed', p.is_reversed, 'reason_code', p.reason_code,
             -- C76 (TC-09): mã khoản đảo đã hoàn tác khoản này, cho ghi chú «Đã hoàn tác bằng …».
             'reversed_by_code', (select x.code from app.money_in x where x.reversal_of = p.id order by x.created_at desc limit 1))
             order by case when p_sort = 'date_asc' then p.created_at end asc,
                      case when p_sort = 'amount_desc' then p.amount end desc,
                      case when p_sort = 'amount_asc' then p.amount end asc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent par on par.id = p.parent_id
    left join app.sales_order o on o.id = p.order_id;
  return v_result;
end;
$$;
select set_config('hmt.migration', '', false);
