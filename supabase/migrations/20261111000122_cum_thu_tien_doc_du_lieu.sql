-- Cụm Thu tiền (Code 2, 11/11/2026): hàm đọc cho TC-08 (sổ Khoản tiền vào) và TC-13 (Công nợ). Chỉ đọc.
-- Luật: R-TIEN-01 (khoản tiền vào tự sinh khi kế toán duyệt, chỉ thêm), R-TIEN-07 (lịch đóng tiền từng đợt dùng để theo dõi công nợ, nhắc sắp đến hạn và quá hạn, không chặn học),
-- R-TIEN-26 (khoản âm là khoản đảo; thao tác Đảo khoản là màn TC-09, chưa có trong đợt này).
-- Quyền: TC-08 theo Đối soát kế toán · Xem (Kế toán, Admin toàn hệ thống; Trưởng cơ sở trong cơ sở); TC-13 theo Đơn hàng · Xem (như menu).

-- Tham số debt_due_soon_days (Sắp đến hạn, mặc định 3 ngày) đã khai báo từ migration 044 (Đ107, Đ118); không khai báo lại.

-- Chỉ mục (lý do): sổ Khoản tiền vào của mọi cơ sở (Kế toán, Admin) sắp mới nhất trước đi thẳng theo chỉ mục, không sắp lại cả bảng.
create index money_in_created_idx on app.money_in (created_at desc, id);

-- app.list_money_in(bộ lọc, sắp xếp, limit, offset): TC-08 sổ Khoản tiền vào, chỉ đọc.
-- Ai gọi: người có Đối soát kế toán · Xem (Kế toán, Admin: mọi cơ sở; Trưởng cơ sở: cơ sở mình). Bộ lọc: q (mã khoản, phiếu thu, đơn, phụ huynh, SĐT; không dấu), branch_id,
-- created_from, created_to (mốc giờ ghi sổ; từ mốc đầu đến trước mốc cuối), kind ('THU' = khoản dương, 'DAO' = khoản âm). Sắp xếp: date_desc (mặc định), date_asc, amount_desc, amount_asc. Kết quả {total, sum, rows[]}.
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
    select m.*, r.code as receipt_code, r.search_text
      from app.money_in m join app.receipt r on r.id = m.receipt_id
     where (v_scope = 'TOAN_HE_THONG' or m.branch_id = v_my_branch)
       and (v_branch is null or m.branch_id = v_branch)
       and (v_from is null or m.created_at >= v_from)
       and (v_to is null or m.created_at < v_to)
       and (v_kind is null or (v_kind = 'THU' and m.amount > 0) or (v_kind = 'DAO' and m.amount < 0))
       and (v_q is null or r.search_text like '%' || v_q || '%' or app.fold_text(m.code) like '%' || v_q || '%')
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
             'amount', p.amount, 'created_at', p.created_at, 'branch_code', b.code)
             order by case when p_sort = 'date_asc' then p.created_at end asc,
                      case when p_sort = 'amount_desc' then p.amount end desc,
                      case when p_sort = 'amount_asc' then p.amount end asc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent par on par.id = p.parent_id
    join app.sales_order o on o.id = p.order_id;
  return v_result;
end;
$$;

-- app.list_receivables(bộ lọc, sắp xếp, limit, offset): TC-13 Công nợ, chỉ đọc. Mỗi dòng là một ĐỢT đóng tiền còn nợ của đơn Đã duyệt.
-- Ai gọi: người có Đơn hàng · Xem (Kế toán, Admin: mọi cơ sở; Trưởng cơ sở, Sale, CSKH: cơ sở mình). Luật R-TIEN-07: lịch đợt từ điều khoản thanh toán, hạn chốt khi duyệt đơn.
-- Tiền đã vào của đơn (tổng khoản tiền vào, đã trừ khoản đảo) lấp lần lượt từ đợt 1: đợt i đã đóng = min(số phải đóng, max(0, tổng đã vào − tổng phải đóng các đợt trước)). Đợt đóng đủ thì không hiện.
-- Tình trạng: QUA_HAN (hạn trước hôm nay, giờ Việt Nam), SAP_DEN_HAN (hạn trong `debt_due_soon_days` ngày tới), CHUA_DEN_HAN. Không chặn học (R-TIEN-07).
-- Bộ lọc: q (mã đơn, phụ huynh, SĐT; không dấu), status[], branch_id, sale_id (người lập đơn), due_from, due_to. Sắp xếp: due_asc (mặc định), owed_desc, due_desc. Kết quả {total, owed_sum, rows[]}.
create or replace function app.list_receivables(p_filters jsonb default '{}'::jsonb, p_sort text default 'due_asc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SALES_ORDER', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_soon integer := app.get_setting_int('debt_due_soon_days');
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_sale uuid := nullif(p_filters ->> 'sale_id', '')::uuid;
  v_from date := nullif(p_filters ->> 'due_from', '')::date;
  v_to date := nullif(p_filters ->> 'due_to', '')::date;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem công nợ.');
  end if;
  with ord as not materialized (
    select o.id, o.code, o.branch_id, o.parent_id, o.created_by,
           (select coalesce(sum(m.amount), 0) from app.money_in m where m.order_id = o.id)::bigint as paid_total,
           (select count(*) from app.sales_order_installment c where c.order_id = o.id) as seq_count
      from app.sales_order o
     where o.status_code = 'DA_DUYET'
       and (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
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
  page as (
    select * from g
     order by case when p_sort = 'due_desc' then g.due_date end desc,
              case when p_sort = 'owed_desc' then g.owed end desc,
              g.due_date asc, g.order_code, g.seq
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from g),
           'owed_sum', (select coalesce(sum(owed), 0) from g),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'order_id', p.order_id, 'order_code', p.order_code, 'parent_id', p.parent_id, 'parent_name', p.parent_name,
             'branch_code', b.code, 'sale_name', app.staff_display_name(p.created_by), 'seq', p.seq, 'seq_count', p.seq_count,
             'due_date', p.due_date, 'due_amount', p.due_amount, 'paid_amount', p.paid_amount, 'owed', p.owed, 'status', p.status,
             'overdue_days', case when p.status = 'QUA_HAN' then v_today - p.due_date else null end)
             order by case when p_sort = 'due_desc' then p.due_date end desc,
                      case when p_sort = 'owed_desc' then p.owed end desc,
                      p.due_date asc, p.order_code, p.seq), '[]'::jsonb))
    into v_result
    from page p join app.branch b on b.id = p.branch_id;
  return v_result;
end;
$$;

revoke execute on function app.list_money_in(jsonb, text, integer, integer), app.list_receivables(jsonb, text, integer, integer) from public, anon, authenticated;
grant execute on function app.list_money_in(jsonb, text, integer, integer), app.list_receivables(jsonb, text, integer, integer) to authenticated;
