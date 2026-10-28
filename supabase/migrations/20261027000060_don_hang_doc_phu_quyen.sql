-- ===========================================================================
-- P5a-DB-O1a (migration 060, Đ256), CHỈ ĐỌC:
--   (a) app.assert_quotation_helper_access cho phép Báo giá Tạo/Sửa HOẶC Đơn hàng Tạo/Sửa, để đơn tạo thẳng từ cơ hội dùng được bốn hàm đọc phụ;
--   (d) app.list_orders trả thêm `student_names` (mảng tên các em theo thứ tự dòng), chỉ gom cho các đơn của trang đang hiện.
-- Không bảng, chỉ mục mới. Ma trận quyền không đổi.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Kiểm quyền chung của các hàm đọc phụ cho màn lập báo giá và đơn (xem thử giá, gói bán, chính sách chiết khấu, chính sách quà tặng): cho phép
-- Báo giá Tạo hoặc Sửa HOẶC Đơn hàng Tạo hoặc Sửa ở cơ sở của cơ hội. Vẫn kiểm công tắc Bán hàng theo cơ sở (Đ173) và cơ hội đã gộp. Chữ ký và
-- nguồn tính tiền của bốn hàm đọc phụ giữ nguyên (preview_quotation_lines gọi app.price_line, R-TIEN-13). Hàm nội bộ, không mở cho rpc.
-- ---------------------------------------------------------------------------
create or replace function app.assert_quotation_helper_access(p_opportunity_id uuid)
returns app.opportunity
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_opp app.opportunity;
begin
  select * into v_opp from app.opportunity where id = p_opportunity_id;
  if v_opp.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
  end if;
  -- Luật (Đ256, DB-O1a): người lập hoặc sửa báo giá HOẶC đơn hàng ở cơ sở của cơ hội dùng được các hàm đọc phụ (xem thử giá, gói bán, chính sách).
  if not (app.can_see_branch('QUOTATION', 'TAO', v_opp.branch_id) or app.can_see_branch('QUOTATION', 'SUA', v_opp.branch_id)
          or app.can_see_branch('SALES_ORDER', 'TAO', v_opp.branch_id) or app.can_see_branch('SALES_ORDER', 'SUA', v_opp.branch_id)) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền lập báo giá hoặc đơn hàng ở cơ sở này.');
  end if;
  perform app.require_feature('BAN_HANG', v_opp.branch_id); -- Luật Đ173
  if v_opp.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không lập báo giá hoặc đơn hàng được.');
  end if;
  return v_opp;
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
             -- Tên các em theo thứ tự dòng, không trùng; chỉ gom cho các đơn của trang đang hiện (p là trang, không quét cả bảng).
             'student_names', (select coalesce(jsonb_agg(x.nm order by x.first_line), '[]'::jsonb)
                                 from (select coalesce(s.full_name, v.full_name) as nm, min(l.line_no) as first_line
                                         from app.sales_order_line l
                                         left join app.prospect_student_v v on v.id = l.prospect_student_id
                                         left join app.student s on s.id = l.student_id
                                        where l.order_id = p.id and coalesce(s.full_name, v.full_name) is not null
                                        group by coalesce(s.full_name, v.full_name)) x),
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

select set_config('hmt.migration', '', false);

revoke execute on function app.assert_quotation_helper_access(uuid) from public, anon, authenticated;
revoke execute on function app.list_orders(jsonb, text, integer, integer) from public, anon;
grant execute on function app.list_orders(jsonb, text, integer, integer) to authenticated;
