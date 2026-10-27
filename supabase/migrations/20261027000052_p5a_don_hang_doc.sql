-- ===========================================================================
-- P5a-DB1b-2 (migration 052): đơn hàng, HÀM ĐỌC VÀ XUẤT: get_order, list_orders, export_orders. Chỉ thêm đối tượng mới.
-- R-TIEN-01, 03, 06, 07; R-HT-06; QĐ-Đ102, Đ105, Đ106, Đ187, Đ201, Đ202, Đ214. Đặt sau 051 (DB1b-1).
-- Quyền đọc: Đơn hàng · Xem (toàn hệ thống hoặc cơ sở mình). Đ173/Đ181: hàm đọc không chặn theo công tắc BAN_HANG.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Bản ghi đơn (BH-05): tiêu đề, gốc (cơ hội hoặc phiếu tái tục), báo giá gốc, dòng kèm chiết khấu và em, lịch đóng tiền, lịch sử.
-- Ai gọi: Đơn hàng · Xem ở cơ sở của đơn. Kết quả jsonb: cột của đơn (trừ ô tìm kiếm), tên hiển thị trạng thái, các mã và tên liên quan,
-- người lập, người duyệt đã chốt, người trình, lý do huỷ; mảng lines, installments, events.
-- ---------------------------------------------------------------------------
create or replace function app.get_order(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
begin
  select * into o from app.sales_order where id = p_id;
  if o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'XEM', o.branch_id);
  return (to_jsonb(o) - 'search_text') || jsonb_build_object(
    'status', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_STATUS' and c.code = o.status_code),
    'branch_code', (select b.code from app.branch b where b.id = o.branch_id),
    'opportunity_code', (select x.code from app.opportunity x where x.id = o.opportunity_id),
    'quotation_code', (select q.code from app.quotation q where q.id = o.quotation_id),
    'parent_code', (select p.code from app.parent p where p.id = o.parent_id),
    'parent_name', (select p.full_name from app.parent p where p.id = o.parent_id),
    'parent_phone', (select p.phone from app.parent p where p.id = o.parent_id),
    'payment_term_name', (select t.name from app.payment_term t where t.id = o.payment_term_id),
    'created_by_name', app.staff_display_name(o.created_by),
    'submitted_by_name', app.staff_display_name(o.submitted_by),
    'approver_name', app.staff_display_name(o.assigned_approver_id),
    'approved_by_name', app.staff_display_name(o.approved_by),
    'cancel_reason', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_CANCEL_REASON' and c.code = o.cancel_reason_code),
    'has_incomplete_students', exists (
      select from app.sales_order_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
        left join app.student s on s.id = l.student_id
       where l.order_id = o.id
         and (coalesce(s.full_name, v.full_name) is null or coalesce(s.birth_year, v.birth_year) is null)),
    'lines', coalesce((
      select jsonb_agg(to_jsonb(l) - 'order_id' || jsonb_build_object(
               'student_name', coalesce(s.full_name, v.full_name), 'student_birth_year', coalesce(s.birth_year, v.birth_year),
               'student_code', coalesce(s.code, v.student_code),
               'student_complete', (coalesce(s.full_name, v.full_name) is not null and coalesce(s.birth_year, v.birth_year) is not null),
               'gift_policy_name', (select g.name from app.gift_policy g where g.id = l.gift_policy_id),
               'discounts', coalesce((select jsonb_agg(to_jsonb(d) - 'line_id' - 'branch_id' order by d.created_at, d.id)
                                        from app.sales_order_line_discount d where d.line_id = l.id), '[]'::jsonb))
             order by l.line_no)
        from app.sales_order_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
        left join app.student s on s.id = l.student_id
       where l.order_id = o.id), '[]'::jsonb),
    'installments', coalesce((
      select jsonb_agg(jsonb_build_object('seq', i.seq, 'due_days', i.due_days, 'amount', i.amount, 'due_date', i.due_date) order by i.seq)
        from app.sales_order_installment i where i.order_id = o.id), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
               'seq', e.seq, 'event_code', e.event_code, 'from_status', e.from_status, 'to_status', e.to_status,
               'reason_code', e.reason_code, 'note', e.note, 'on_behalf', e.on_behalf, 'created_at', e.created_at,
               'actor_name', app.staff_display_name(e.created_by)) order by e.seq)
        from app.sales_order_event e where e.order_id = o.id), '[]'::jsonb));
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách đơn, phân trang ở máy chủ (50 mặc định, tối đa 100): BH-04, tab Đơn trên TS-08 và KH-02.
-- Ai gọi: Đơn hàng · Xem (phạm vi quyền: toàn hệ thống hoặc cơ sở mình).
-- Bộ lọc p_filters: q (mã, tên phụ huynh, SĐT, tên em), status[] (NHAP, DA_TRINH, DA_DUYET, HUY), branch_id, opportunity_id, quotation_id,
-- parent_id, mine (do tôi lập), waiting_me (Đã trình và tôi là người duyệt đã chốt), created_from, created_to.
-- Sắp xếp: created_desc, created_asc, total_desc. Kết quả: {total, rows: [...]}. Chỉ trả các cột màn hiện.
-- ---------------------------------------------------------------------------
create or replace function app.list_orders(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SALES_ORDER', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
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
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách đơn hàng.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang).
  with f as not materialized (
    select o.*
      from app.sales_order o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or o.status_code = any (v_status))
       and (v_branch is null or o.branch_id = v_branch)
       and (v_opp is null or o.opportunity_id = v_opp)
       and (v_quo is null or o.quotation_id = v_quo)
       and (v_parent is null or o.parent_id = v_parent)
       and (not v_mine or o.created_by = auth.uid())
       and (not v_waiting or (o.status_code = 'DA_TRINH' and o.assigned_approver_id = auth.uid()))
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'total_desc' then f.total_amount end desc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'status_code', p.status_code,
             'status', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_STATUS' and c.code = p.status_code),
             'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
             'opportunity_id', p.opportunity_id, 'opportunity_code', op.code,
             'quotation_id', p.quotation_id, 'quotation_code', q.code,
             'student_name', (select coalesce(s.full_name, v.full_name) from app.sales_order_line l
                                left join app.prospect_student_v v on v.id = l.prospect_student_id
                                left join app.student s on s.id = l.student_id
                               where l.order_id = p.id order by l.line_no limit 1),
             'line_count', (select count(*) from app.sales_order_line l where l.order_id = p.id),
             'total_amount', p.total_amount, 'needs_acknowledgement', p.needs_acknowledgement,
             'submitted_at', p.submitted_at, 'approved_at', p.approved_at, 'created_at', p.created_at, 'branch_code', b.code,
             'created_by_name', app.staff_display_name(p.created_by),
             'approver_name', app.staff_display_name(p.assigned_approver_id))
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'total_desc' then p.total_amount end desc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent par on par.id = p.parent_id
    left join app.opportunity op on op.id = p.opportunity_id
    left join app.quotation q on q.id = p.quotation_id;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Xuất danh sách đơn (Đ105): chỉ vai có quyền Đơn hàng · Xuất (Trưởng cơ sở trong cơ sở, Kế toán, Admin). Cùng bộ lọc với list_orders;
-- tối đa export_max_rows dòng; ghi nhật ký xuất TRƯỚC khi trả dữ liệu. Kết quả: {total, exported, truncated, rows}.
-- ---------------------------------------------------------------------------
create or replace function app.export_orders(p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SALES_ORDER', 'XUAT');
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
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Phạm vi dòng lấy từ quyền Xuất, không phải Xem.
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất danh sách đơn hàng.');
  end if;
  select count(*) into v_total
    from app.sales_order o
   where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
     and (v_q is null or o.search_text like '%' || v_q || '%')
     and (cardinality(v_status) = 0 or o.status_code = any (v_status))
     and (v_branch is null or o.branch_id = v_branch)
     and (v_opp is null or o.opportunity_id = v_opp)
     and (v_quo is null or o.quotation_id = v_quo)
     and (v_parent is null or o.parent_id = v_parent)
     and (not v_mine or o.created_by = auth.uid())
     and (not v_waiting or (o.status_code = 'DA_TRINH' and o.assigned_approver_id = auth.uid()))
     and (v_from is null or o.created_at >= v_from)
     and (v_to is null or o.created_at < v_to);
  with f as (
    select o.*
      from app.sales_order o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or o.status_code = any (v_status))
       and (v_branch is null or o.branch_id = v_branch)
       and (v_opp is null or o.opportunity_id = v_opp)
       and (v_quo is null or o.quotation_id = v_quo)
       and (v_parent is null or o.parent_id = v_parent)
       and (not v_mine or o.created_by = auth.uid())
       and (not v_waiting or (o.status_code = 'DA_TRINH' and o.assigned_approver_id = auth.uid()))
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
     order by o.created_at desc, o.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', f.code,
           'status', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_STATUS' and c.code = f.status_code),
           'parent_name', par.full_name, 'parent_phone', par.phone, 'opportunity', op.code, 'quotation', q.code,
           'students', (select string_agg(distinct coalesce(s.full_name, v.full_name), '; ') from app.sales_order_line l
                          left join app.prospect_student_v v on v.id = l.prospect_student_id
                          left join app.student s on s.id = l.student_id where l.order_id = f.id),
           'total_amount', f.total_amount, 'submitted_at', f.submitted_at, 'approved_at', f.approved_at,
           'branch', b.code, 'created_by', app.staff_display_name(f.created_by), 'created_at', f.created_at)
           order by f.created_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id
    join app.parent par on par.id = f.parent_id
    left join app.opportunity op on op.id = f.opportunity_id
    left join app.quotation q on q.id = f.quotation_id;
  perform app.log_export('SALES_ORDER', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.get_order(uuid), app.list_orders(jsonb, text, integer, integer), app.export_orders(jsonb) from public, anon;
grant execute on function app.get_order(uuid), app.list_orders(jsonb, text, integer, integer), app.export_orders(jsonb) to authenticated;
