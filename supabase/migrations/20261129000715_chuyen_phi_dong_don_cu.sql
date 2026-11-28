-- Migration 715 (C-27-27, anh Trường OK 29/11/2026 01:32, phương án A; rủi ro CAO: tiền). Chuyển phí xong thì xử lý đơn cũ. Luật R-TIEN-32, R-TIEN-38.
-- Đơn cũ giữ tình trạng Đã duyệt, thêm DẤU «Đã chuyển phí» (hai cột): không thêm trạng thái đơn. Đơn có dấu: các đợt chưa thu không còn là nợ (Công nợ,
-- Việc của tôi, hồ sơ phụ huynh, mức gắn bó, cổng phụ huynh) và không nhận thêm tiền. Đợt thu, giá trị chuyển, giờ còn lại KHÔNG đổi (R-TIEN-33).
-- Chỉ đặt dấu khi mọi dòng có tiền của đơn đã đóng ghi danh (Dừng hoặc Hoàn phí); đơn còn dòng khác (ghi danh còn hiệu lực, dịch vụ, tài liệu) thì
-- giữ nguyên công nợ, chỉ ghi lịch sử. Không đụng đơn cũ không qua Chuyển phí, kể cả lần chuyển phí đã làm trước migration này.

alter table app.sales_order add column fee_transferred_at timestamptz, add column fee_transfer_ref text;
comment on column app.sales_order.fee_transferred_at is 'Đơn đã chuyển phí hết (C-27-27): đợt chưa thu hết hiệu lực, không nhận thêm tiền.';

alter table app.sales_order_event drop constraint sales_order_event_event_code_check;
alter table app.sales_order_event add constraint sales_order_event_event_code_check
  check (event_code in ('TAO', 'TRINH', 'DUYET', 'TU_CHOI', 'HUY', 'SUA', 'CANH_BAO_XEP_LOP', 'CHO_HOC_TRUOC', 'CHUYEN_NGUOI_DUYET', 'CHUYEN_PHI'));

-- app.close_transferred_order(đơn, mã ticket): gọi từ app.apply_fee_transfer, cùng giao dịch. Đặt dấu nếu đủ điều kiện, luôn ghi lịch sử. Nội bộ.
create function app.close_transferred_order(p_order_id uuid, p_ticket_ref text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
  v_ref text := nullif(btrim(coalesce(p_ticket_ref, '')), '');
  v_done boolean;
begin
  select * into o from app.sales_order where id = p_order_id for update;
  if o.id is null or o.status_code <> 'DA_DUYET' or o.fee_transferred_at is not null then
    return false;
  end if;
  -- Dòng có tiền mà chưa có ghi danh, hoặc ghi danh chưa đóng, thì đơn còn phải thu cho dòng đó.
  v_done := not exists (
    select from app.sales_order_line l
     where l.order_id = o.id and l.is_live and l.line_total > 0
       and (not exists (select from app.enrollment e where e.order_line_id = l.id)
            or exists (select from app.enrollment e where e.order_line_id = l.id and e.status_code not in ('DUNG', 'HOAN_PHI'))));
  if v_done then
    update app.sales_order set fee_transferred_at = now(), fee_transfer_ref = v_ref where id = o.id;
  end if;
  perform app.order_add_event(o.id, 'CHUYEN_PHI', o.status_code, o.status_code, null, null,
    concat_ws(' ', case when v_done then 'Đơn đã chuyển phí, các đợt chưa thu không còn phải thu.'
                        else 'Chuyển phí một phần: đơn còn dòng khác nên công nợ giữ nguyên.' end, 'Ticket ' || v_ref));
  return v_done;
end;
$$;
revoke execute on function app.close_transferred_order(uuid, text) from public, anon, authenticated;

-- Đơn đã chuyển phí không nhận thêm tiền: chặn lập phiếu thu, gửi duyệt, duyệt và khoản tiền vào dương (kể cả dùng số dư). Huỷ, từ chối về Nháp và
-- hoàn tác (khoản âm) vẫn làm được.
create function app.tg_block_transferred_order_money()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if app.is_migration() or new.order_id is null then
    return new;
  end if;
  if tg_table_name = 'money_in' then
    if new.amount <= 0 then
      return new;
    end if;
  elsif tg_op = 'UPDATE' then
    if new.status_code = old.status_code and new.order_id is not distinct from old.order_id then
      return new;
    end if;
    if new.status_code in ('NHAP', 'HUY') and new.order_id is not distinct from old.order_id then
      return new;
    end if;
  end if;
  if exists (select from app.sales_order o where o.id = new.order_id and o.fee_transferred_at is not null) then
    perform app.raise_error('HMT_DON_DA_CHUYEN_PHI', 'Đơn đã chuyển phí, không thu thêm được. Thu vào đơn mới.');
  end if;
  return new;
end;
$$;
revoke execute on function app.tg_block_transferred_order_money() from public, anon, authenticated;
create trigger receipt_block_transferred_order before insert or update of status_code, order_id on app.receipt
  for each row execute function app.tg_block_transferred_order_money();
create trigger money_in_block_transferred_order before insert on app.money_in
  for each row execute function app.tg_block_transferred_order_money();

-- app.apply_fee_transfer: sau khi dừng ghi danh thì xử lý đơn cũ. Thân còn lại giữ bản 663.
create or replace function app.apply_fee_transfer(p_enrollment_id uuid, p_to_parent_id uuid, p_reason_code text, p_note text default null, p_ticket_ref text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v jsonb;
  v_hours numeric;
  v_amount bigint;
  v_parent uuid;
  v_id uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  if e.status_code not in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_CHUYEN_PHI_GHI_DANH_SAI', 'Ghi danh này không còn hiệu lực để chuyển phí.');
  end if;
  perform app.assert_catalog_code_active('TRANSFER_REASON', p_reason_code);
  v_parent := coalesce(p_to_parent_id, e.parent_id);
  if not exists (select from app.parent where id = v_parent) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh nhận số dư.');
  end if;
  -- Luật R-TIEN-28, R-GD-16: tiền còn = giờ mua còn lại × giá sau chiết khấu chụp trên dòng đơn lúc mua; giờ tặng không thành tiền.
  v := app.compute_stop_balance(e.id);
  v_hours := (v ->> 'hours_left')::numeric;
  v_amount := (v ->> 'balance_amount')::bigint;
  if v_hours > 0 then
    insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, reason_code, note, source_ref)
    values (e.id, e.branch_id, 'DIEU_CHINH', -v_hours, 'KHAC', 'Chuyển phí, giữ số dư', 'FEE-' || coalesce(nullif(btrim(p_ticket_ref), ''), e.id::text));
  end if;
  update app.enrollment_class set end_date = greatest(current_date, start_date), end_reason = 'DUNG'
   where enrollment_id = e.id and end_date is null;
  update app.enrollment set status_code = 'DUNG' where id = e.id;
  if v_amount > 0 then
    insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, enrollment_id, source_ref, note)
    values (v_parent, e.student_id, e.branch_id, 'TU_CHUYEN_PHI', v_amount, (now() at time zone 'Asia/Ho_Chi_Minh')::date, e.id,
            'FEE-' || coalesce(nullif(btrim(p_ticket_ref), ''), e.id::text), coalesce(nullif(btrim(p_note), ''), 'Chuyển phí, giữ thành số dư'))
    returning id into v_id;
  end if;
  -- C-27-27: xử lý đơn cũ trong cùng giao dịch.
  if e.order_id is not null then
    perform app.close_transferred_order(e.order_id, p_ticket_ref);
  end if;
  return v_id;
end;
$$;

-- app.list_receivables: bỏ đơn đã chuyển phí. Thân còn lại giữ bản 422.
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
     where o.status_code = 'DA_DUYET' and o.fee_transferred_at is null
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

-- app.receivable_group_counts: bỏ đơn đã chuyển phí. Thân còn lại giữ bản 435.
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
     where o.status_code = 'DA_DUYET' and o.fee_transferred_at is null
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

-- app.work_debts_overdue: bỏ đơn đã chuyển phí. Thân còn lại giữ bản 703.
create or replace function app.work_debts_overdue(p_mine boolean, p_branch uuid)
returns setof app.work_item
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SALES_ORDER', 'XEM');
  v_my uuid := app.current_branch_id();
  v_me uuid := auth.uid();
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    return;
  end if;
  return query
  with o as (
    select so.id, so.code, so.branch_id, so.parent_id, so.created_by
      from app.sales_order so
     where so.status_code = 'DA_DUYET' and so.fee_transferred_at is null
       and (v_scope = 'TOAN_HE_THONG' or so.branch_id = v_my)
       and (p_branch is null or so.branch_id = p_branch)
       and (not p_mine or so.created_by = v_me)
       and exists (select from app.sales_order_installment i where i.order_id = so.id and i.due_date < v_today)
  )
  select 'DEBT_OVERDUE', 'SALES_ORDER', o.id, o.parent_id, null::text, 'NOW',
         'Công nợ ' || o.code,
         'Quá hạn ' || (v_today - d.first_due) || ' ngày, còn ' || replace(to_char(d.owed, 'FM999G999G999G999'), ',', '.') || ' đ',
         (d.first_due::timestamp at time zone 'Asia/Ho_Chi_Minh'), 'OPEN_ORDER', o.created_by, o.branch_id
    from o
   cross join lateral (
     select coalesce(sum(m.amount), 0)::bigint as paid from app.money_in m where m.order_id = o.id
   ) p
   cross join lateral (
     select min(c.due_date) as first_due,
            sum(c.amount - greatest(least(c.amount, p.paid - c.before), 0))::bigint as owed
       from (
         select i.due_date, i.amount,
                coalesce(sum(i.amount) over (order by i.seq rows between unbounded preceding and 1 preceding), 0) as before
           from app.sales_order_installment i
          where i.order_id = o.id and i.due_date is not null
       ) c
      where c.due_date < v_today and c.amount > greatest(least(c.amount, p.paid - c.before), 0)
   ) d
   where d.first_due is not null;
end;
$$;

-- app.parent_money_summary: bỏ đơn đã chuyển phí khỏi nợ. Thân còn lại giữ bản 695.
create or replace function app.parent_money_summary(p_parent app.parent)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with ord as (
    select o.id, o.total_amount, app.order_paid_amount(o.id) as paid,
           app.can_see_branch_wide('SALES_ORDER', 'XEM', o.branch_id) as seen
      from app.sales_order o where o.parent_id = p_parent.id and o.status_code = 'DA_DUYET' and o.fee_transferred_at is null
  ), inst as (
    -- Cùng cách chia tiền đã vào theo thứ tự đợt như list_receivables.
    select i.due_date, i.amount,
           o.paid - coalesce(sum(i.amount) over (partition by i.order_id order by i.seq rows between unbounded preceding and 1 preceding), 0) as paid_left
      from ord o join app.sales_order_installment i on i.order_id = o.id
     where o.seen
  )
  select jsonb_build_object(
    'paid_total', case when app.can_see_branch_wide('RECEIPT', 'XEM', p_parent.branch_id) then
        coalesce((select sum(m.amount) from app.money_in m where m.parent_id = p_parent.id and app.can_see_branch_wide('RECEIPT', 'XEM', m.branch_id)), 0)
        + coalesce((select sum(b.amount) from app.customer_balance_entry b where b.parent_id = p_parent.id and b.entry_type in ('THU_NO_DAU_KY', 'DAO_THU_NO_DAU_KY')
                   and app.can_see_branch_wide('RECEIPT', 'XEM', b.branch_id)), 0) end,
    'debt', case when app.can_see_branch_wide('SALES_ORDER', 'XEM', p_parent.branch_id) then
        coalesce((select sum(greatest(o.total_amount - o.paid, 0)) from ord o where o.seen), 0)
        + greatest(-coalesce((select sum(b.amount) from app.customer_balance_entry b
                               where b.parent_id = p_parent.id and b.entry_type in ('DAU_KY_CONG_NO', 'THU_NO_DAU_KY', 'DAO_THU_NO_DAU_KY')
                                 and app.can_see_branch_wide('SALES_ORDER', 'XEM', b.branch_id)), 0), 0) end,
    'balance', case when app.can_see_branch_wide('RECEIPT', 'XEM', p_parent.branch_id) then
        coalesce((select sum(b.amount) from app.customer_balance_entry b
                   where b.parent_id = p_parent.id and app.can_see_branch_wide('RECEIPT', 'XEM', b.branch_id)), 0) end,
    'overdue_days', (select (now() at time zone 'Asia/Ho_Chi_Minh')::date - min(i.due_date) from inst i
                      where i.due_date < (now() at time zone 'Asia/Ho_Chi_Minh')::date and i.amount > greatest(i.paid_left, 0)));
$$;

-- app.student_overdue_days: bỏ đơn đã chuyển phí. Thân còn lại giữ bản 700.
create or replace function app.student_overdue_days(p_student_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  with ord as (
    select o.id, app.order_paid_amount(o.id) as paid
      from app.sales_order o
     where o.id in (select l.order_id from app.sales_order_line l where l.student_id = p_student_id)
       and o.status_code = 'DA_DUYET' and o.fee_transferred_at is null and app.can_see_branch_wide('SALES_ORDER', 'XEM', o.branch_id)
  ), inst as (
    select i.due_date, i.amount,
           o.paid - coalesce(sum(i.amount) over (partition by i.order_id order by i.seq rows between unbounded preceding and 1 preceding), 0) as paid_left
      from ord o join app.sales_order_installment i on i.order_id = o.id
  )
  select (now() at time zone 'Asia/Ho_Chi_Minh')::date - min(i.due_date) from inst i
   where i.due_date < (now() at time zone 'Asia/Ho_Chi_Minh')::date and i.amount > greatest(i.paid_left, 0);
$$;

-- app.ph_hours_orders: đơn đã chuyển phí không còn thiếu. Thân còn lại giữ bản 645.
create or replace function app.ph_hours_orders(p_student_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := app.portal_require_student(p_student_id);
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_left numeric;
  v_weekly numeric;
  v_end date;
  v_orders jsonb;
  v_receipts jsonb;
begin
  -- Giờ còn và giờ học mỗi tuần.
  select coalesce(sum(h.hours), 0) into v_left
    from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id
   where e.student_id = p_student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC');
  select coalesce(sum(extract(epoch from (s.end_time - s.start_time)) / 3600.0 / s.repeat_weeks), 0) into v_weekly -- allow-number: 3600 giây một giờ
    from app.class_slot s
   where s.is_active and s.class_id in (select ec.class_id from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
                                         where e.student_id = p_student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC'));
  if v_left > 0 and v_weekly > 0 then
    v_end := v_today + ceil(v_left / v_weekly * 7)::integer; -- allow-number: 7 ngày một tuần
  end if;
  -- Đơn của phụ huynh có dòng dành cho em (Đã duyệt).
  select coalesce(jsonb_agg(x.j order by x.created_at desc), '[]'::jsonb) into v_orders
    from (select o.created_at, jsonb_build_object(
            'id', o.id, 'code', o.code,
            'name', (select string_agg(l.package_name, ', ' order by l.line_no) from app.sales_order_line l where l.order_id = o.id and l.student_id = p_student_id),
            'hours', (select sum(l.quantity + l.gifted_quantity) from app.sales_order_line l where l.order_id = o.id and l.student_id = p_student_id and l.unit_code = 'GIO'),
            'total', o.total_amount, 'paid', app.order_paid_amount(o.id), 'remaining', case when o.fee_transferred_at is null then greatest(o.total_amount - app.order_paid_amount(o.id), 0) else 0 end,
            'status', case when o.fee_transferred_at is not null then 'DA_CHUYEN_PHI' end) as j
            from app.sales_order o
           where o.status_code = 'DA_DUYET' and o.parent_id in (select app.portal_parent_ids())
             and exists (select 1 from app.sales_order_line l where l.order_id = o.id and l.student_id = p_student_id)
           order by o.created_at desc limit 20) x; -- allow-number: trần số đơn hiện trên màn
  select coalesce(jsonb_agg(r.j order by r.paid_on desc), '[]'::jsonb) into v_receipts
    from (select rc.paid_on, jsonb_build_object('code', rc.code, 'paid_on', rc.paid_on, 'amount', rc.amount, 'order_code', o.code) as j
            from app.receipt rc join app.sales_order o on o.id = rc.order_id
           where rc.status_code = 'DA_DUYET' and rc.parent_id in (select app.portal_parent_ids())
             and exists (select 1 from app.sales_order_line l where l.order_id = o.id and l.student_id = p_student_id)
           order by rc.paid_on desc limit 5) r; -- allow-number: năm phiếu thu gần nhất theo khung PH03
  return jsonb_build_object('hours_left', v_left, 'projected_end', v_end,
                            'is_low', v_left <= app.portal_low_hours_threshold(v_branch),
                            'orders', v_orders, 'receipts', v_receipts);
end;
$$;

-- app.ph_order: đơn đã chuyển phí không còn thiếu, tình trạng riêng. Thân còn lại giữ bản 645.
create or replace function app.ph_order(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
  v_paid bigint;
begin
  select * into o from app.sales_order where id = p_order_id and parent_id in (select app.portal_parent_ids()) and status_code = 'DA_DUYET';
  -- Luật quyền riêng: đơn người khác báo như không có.
  if o.id is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem dữ liệu này.');
  end if;
  perform app.require_feature('HOC_TAP', o.branch_id);
  v_paid := app.order_paid_amount(o.id);
  return jsonb_build_object(
    'code', o.code,
    'name', (select string_agg(l.package_name, ', ' order by l.line_no) from app.sales_order_line l where l.order_id = o.id),
    'hours', (select sum(l.quantity + l.gifted_quantity) from app.sales_order_line l where l.order_id = o.id and l.unit_code = 'GIO'),
    'total', o.total_amount, 'paid', v_paid, 'remaining', case when o.fee_transferred_at is null then greatest(o.total_amount - v_paid, 0) else 0 end,
    'status', case when o.fee_transferred_at is not null then 'DA_CHUYEN_PHI' when v_paid >= o.total_amount then 'DA_THU_DU' else 'CON_THIEU' end,
    'receipts', (select coalesce(jsonb_agg(jsonb_build_object('code', rc.code, 'paid_on', rc.paid_on, 'amount', rc.amount) order by rc.paid_on desc), '[]'::jsonb)
                   from app.receipt rc where rc.order_id = o.id and rc.status_code = 'DA_DUYET'));
end;
$$;
