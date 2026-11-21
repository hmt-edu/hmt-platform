-- C95 (thư Chat 05:18; migration 604, rủi ro CAO theo quy ước: sửa hàm danh sách, đếm tiền). Group By còn thiếu so canvas 9933 (doi-chieu-group-by.md): BH-01 «Người lập», BH-06 «Sale», TC-10 «Hình thức».
-- (TC-08 «Ngày» và TC-13 «Sale», «Tình trạng» ĐÃ có từ migration 435: rà lại thấy đúng, không cần sửa.) Một migration gộp ba màn.
-- Làm gì: (1) quotation_group_counts, order_group_counts, voucher_group_counts nhận thêm trường nhóm creator, sale, method; (2) ba hàm nhãn thêm tên người (staff_display_name) và tên hình thức;
-- (3) list_quotations, list_orders nhận bộ lọc creator_id (người lập), list_payment_vouchers nhận payment_method (mảng) để mở một nhóm; ba hàm đếm cũng nhận các bộ lọc này để số đếm khớp danh sách.
-- Giữ nguyên quyền, phạm vi cơ sở, hai cấp tối đa (Đ35) và mọi luật khác của các bản trước (list_quotations: 422, list_orders: 563, list_payment_vouchers: 581, các hàm đếm và nhãn: 432, 433, 436).
-- Chỉ đọc; không đổi bảng; không thêm chỉ mục (cột created_by và payment_method_code nằm trong tập đã lọc theo phạm vi cơ sở).
select set_config('hmt.migration', 'on', false);

create or replace function app.quotation_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'status' then coalesce((select name from app.catalog_item where catalog_code = 'QUOTATION_STATUS' and code = p_key), p_key)
    when p_field = 'branch' then coalesce((select code || ' ' || name from app.branch where id = p_key::uuid), p_key)
    when p_field = 'creator' then coalesce(app.staff_display_name(p_key::uuid), p_key)
    else p_key end;
$$;

create or replace function app.quotation_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('QUOTATION', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  -- Mã lưu trong DB cần xét trước: Đã chuyển đơn nằm trong các báo giá Đã gửi (Đ243).
  v_status_db text[] := array(select distinct case when x = 'DA_CHUYEN_DON' then 'DA_GUI' else x end from unnest(v_status) x);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  -- C95: người lập của bản ghi; dùng để mở một nhóm Group By «Người lập».
  v_creator uuid := nullif(p_filters ->> 'creator_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_expired boolean := coalesce((p_filters ->> 'expired')::boolean, false);
  v_converted boolean := (p_filters ->> 'converted')::boolean;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách báo giá.');
  end if;
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status', 'branch', 'creator'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, cơ sở, người lập).');
  end if;
  with f as not materialized (
    select q.*
      from app.quotation q
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and q.branch_id = v_my_branch))
       and (v_q is null or q.search_text like '%' || v_q || '%')
       -- Tình trạng hiển thị (Đ243): Đã gửi chỉ gồm báo giá chưa chuyển hết; Đã chuyển đơn là báo giá Đã gửi mà mọi dòng đã lên đơn. Các giá trị nối bằng HOẶC.
       and (cardinality(v_status) = 0 or (q.status_code = any (v_status_db)
            and (case when q.status_code = 'DA_GUI' and app.quotation_converted(q.id) then 'DA_CHUYEN_DON' else q.status_code end) = any (v_status)))
       and (v_branch is null or q.branch_id = v_branch)
       and (v_creator is null or q.created_by = v_creator)
       and (v_opp is null or q.opportunity_id = v_opp)
       and (v_parent is null or q.parent_id = v_parent)
       and (not v_mine or q.created_by = auth.uid())
       and (not v_expired or (q.status_code = 'DA_GUI' and q.valid_until < v_today))
       -- Đã chuyển đơn: báo giá Đã gửi mà mọi dòng đã lên đơn còn sống (app.quotation_converted); false thì loại các báo giá đó.
       and (v_converted is null or (q.status_code = 'DA_GUI' and app.quotation_converted(q.id)) = v_converted)
       and (v_from is null or q.created_at >= v_from)
       and (v_to is null or q.created_at < v_to)
  ),
  keyed as (
    select case v_f1 when 'status' then (case when f.status_code = 'DA_GUI' and app.quotation_converted(f.id) then 'DA_CHUYEN_DON' else f.status_code end)
                     when 'branch' then f.branch_id::text when 'creator' then f.created_by::text end as k1,
           case v_f2 when 'status' then (case when f.status_code = 'DA_GUI' and app.quotation_converted(f.id) then 'DA_CHUYEN_DON' else f.status_code end)
                     when 'branch' then f.branch_id::text when 'creator' then f.created_by::text end as k2
      from f
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.quotation_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.quotation_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

create or replace function app.list_quotations(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('QUOTATION', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  -- Mã lưu trong DB cần xét trước: Đã chuyển đơn nằm trong các báo giá Đã gửi (Đ243).
  v_status_db text[] := array(select distinct case when x = 'DA_CHUYEN_DON' then 'DA_GUI' else x end from unnest(v_status) x);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  -- C95: người lập của bản ghi; dùng để mở một nhóm Group By «Người lập».
  v_creator uuid := nullif(p_filters ->> 'creator_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_expired boolean := coalesce((p_filters ->> 'expired')::boolean, false);
  v_converted boolean := (p_filters ->> 'converted')::boolean;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách báo giá.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang).
  with f as not materialized (
    select q.*
      from app.quotation q
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and q.branch_id = v_my_branch))
       and (v_q is null or q.search_text like '%' || v_q || '%')
       -- Tình trạng hiển thị (Đ243): Đã gửi chỉ gồm báo giá chưa chuyển hết; Đã chuyển đơn là báo giá Đã gửi mà mọi dòng đã lên đơn. Các giá trị nối bằng HOẶC.
       and (cardinality(v_status) = 0 or (q.status_code = any (v_status_db)
            and (case when q.status_code = 'DA_GUI' and app.quotation_converted(q.id) then 'DA_CHUYEN_DON' else q.status_code end) = any (v_status)))
       and (v_branch is null or q.branch_id = v_branch)
       and (v_creator is null or q.created_by = v_creator)
       and (v_opp is null or q.opportunity_id = v_opp)
       and (v_parent is null or q.parent_id = v_parent)
       and (not v_mine or q.created_by = auth.uid())
       and (not v_expired or (q.status_code = 'DA_GUI' and q.valid_until < v_today))
       -- Đã chuyển đơn: báo giá Đã gửi mà mọi dòng đã lên đơn còn sống (app.quotation_converted); false thì loại các báo giá đó.
       and (v_converted is null or (q.status_code = 'DA_GUI' and app.quotation_converted(q.id)) = v_converted)
       and (v_from is null or q.created_at >= v_from)
       and (v_to is null or q.created_at < v_to)
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'total_desc' then f.total_amount end desc,
              case when p_sort = 'valid_asc' then f.valid_until end asc nulls last,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'status_code', p.status_code,
             'display_status_code', case when p.status_code = 'DA_GUI' and app.quotation_converted(p.id) then 'DA_CHUYEN_DON' else p.status_code end,
             'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
             'opportunity_id', p.opportunity_id, 'opportunity_code', o.code,
             'student_name', (select v.full_name from app.quotation_line l join app.prospect_student_v v on v.id = l.prospect_student_id
                               where l.quotation_id = p.id order by l.line_no limit 1),
             'student_names', (select coalesce(jsonb_agg(x.full_name order by x.first_line), '[]'::jsonb)
                                 from (select v.full_name, min(l.line_no) as first_line
                                         from app.quotation_line l join app.prospect_student_v v on v.id = l.prospect_student_id
                                        where l.quotation_id = p.id and v.full_name is not null group by v.full_name) x),
             'student_count', (select count(distinct l.prospect_student_id) from app.quotation_line l where l.quotation_id = p.id),
             'total_amount', p.total_amount, 'valid_until', p.valid_until,
             'overdue_days', case when p.status_code = 'DA_GUI' and p.valid_until < v_today then v_today - p.valid_until end,
             'sent_at', p.sent_at, 'created_at', p.created_at, 'branch_code', b.code,
             'created_by_name', app.staff_display_name(p.created_by))
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'total_desc' then p.total_amount end desc,
                      case when p_sort = 'valid_asc' then p.valid_until end asc nulls last,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent par on par.id = p.parent_id
    join app.opportunity o on o.id = p.opportunity_id;
  return v_result;
end;
$$;

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
    when p_field = 'sale' then coalesce(app.staff_display_name(p_key::uuid), p_key)
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
  -- C95: người lập của bản ghi; dùng để mở một nhóm Group By «Sale».
  v_creator uuid := nullif(p_filters ->> 'creator_id', '')::uuid;
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
     or exists (select from unnest(p_fields) x where x not in ('status', 'branch', 'sale'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, cơ sở, sale).');
  end if;
  with f as not materialized (
    select o.*
      from app.sales_order o
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and o.branch_id = v_my_branch))
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or o.status_code = any (v_status))
       and (v_branch is null or o.branch_id = v_branch)
       and (v_creator is null or o.created_by = v_creator)
       and (v_opp is null or o.opportunity_id = v_opp)
       and (v_quo is null or o.quotation_id = v_quo)
       and (v_parent is null or o.parent_id = v_parent)
       and (not v_mine or o.created_by = auth.uid())
       and (not v_waiting or (o.status_code = 'DA_TRINH' and (o.assigned_approver_id = auth.uid() or o.approval_route = 'TRUONG_CS' and (select app.is_branch_manager_at(auth.uid(), 'SALES_ORDER', o.branch_id)))))
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
  ),
  keyed as (
    select case v_f1 when 'status' then f.status_code when 'branch' then f.branch_id::text when 'sale' then f.created_by::text end as k1,
           case v_f2 when 'status' then f.status_code when 'branch' then f.branch_id::text when 'sale' then f.created_by::text end as k2
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
  -- C95: người lập của bản ghi; dùng để mở một nhóm Group By «Sale».
  v_creator uuid := nullif(p_filters ->> 'creator_id', '')::uuid;
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
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and o.branch_id = v_my_branch))
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or o.status_code = any (v_status))
       and (v_branch is null or o.branch_id = v_branch)
       and (v_creator is null or o.created_by = v_creator)
       and (v_opp is null or o.opportunity_id = v_opp)
       and (v_quo is null or o.quotation_id = v_quo)
       and (v_parent is null or o.parent_id = v_parent)
       and (not v_mine or o.created_by = auth.uid())
       and (not v_waiting or (o.status_code = 'DA_TRINH' and (o.assigned_approver_id = auth.uid() or o.approval_route = 'TRUONG_CS' and (select app.is_branch_manager_at(auth.uid(), 'SALES_ORDER', o.branch_id)))))
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
             -- Tiền đã thu của đơn (khoản tiền vào, kể cả khoản âm hoàn tác) cho cột «Đã thu», «Còn phải thu», «Thu tiền» của canvas BH06; chỉ tính cho đơn của trang đang hiện.
             'paid_amount', (select coalesce(sum(m.amount), 0)::bigint from app.money_in m where m.order_id = p.id),
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

create or replace function app.voucher_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'status' then case p_key when 'CHO_CHI' then 'Chờ chi' when 'DA_CHI' then 'Đã chi' else p_key end
    when p_field = 'branch' then coalesce((select code || ' ' || name from app.branch where id = p_key::uuid), p_key)
    when p_field = 'method' then coalesce((select name from app.catalog_item where catalog_code = 'PAYMENT_METHOD' and code = p_key), p_key)
    else p_key end;
$$;

create or replace function app.voucher_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('RECEIPT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  -- C95: hình thức chi (mảng mã PAYMENT_METHOD); dùng để mở một nhóm Group By «Hình thức».
  v_method text[] := array(select jsonb_array_elements_text(p_filters -> 'payment_method'));
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu chi.');
  end if;
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status', 'branch', 'method'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, cơ sở, hình thức).');
  end if;
  with f as (
    select v.status_code, v.branch_id, v.payment_method_code
      from app.payment_voucher v
      join app.refund_request r on r.id = v.refund_request_id
      join app.parent p on p.id = v.parent_id
     where (v_scope = 'TOAN_HE_THONG' or v.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or v.status_code = any (v_status))
       and (v_branch is null or v.branch_id = v_branch)
       and (cardinality(v_method) = 0 or v.payment_method_code = any (v_method))
       and (v_from is null or v.created_at >= v_from)
       and (v_to is null or v.created_at < v_to)
       and (v_q is null or v.code ilike '%' || v_q || '%' or r.ticket_ref ilike '%' || v_q || '%'
            or p.full_name ilike '%' || v_q || '%' or p.code ilike '%' || v_q || '%')
  ),
  keyed as (
    select case v_f1 when 'status' then f.status_code when 'branch' then f.branch_id::text when 'method' then f.payment_method_code end as k1,
           case v_f2 when 'status' then f.status_code when 'branch' then f.branch_id::text when 'method' then f.payment_method_code end as k2
      from f
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.voucher_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.voucher_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

create or replace function app.list_payment_vouchers(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
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
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  -- C95: hình thức chi (mảng mã PAYMENT_METHOD); dùng để mở một nhóm Group By «Hình thức».
  v_method text[] := array(select jsonb_array_elements_text(p_filters -> 'payment_method'));
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_total bigint;
  v_rows jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu chi.');
  end if;
  with f as (
    select v.id, v.created_at
      from app.payment_voucher v
      join app.refund_request r on r.id = v.refund_request_id
      join app.parent p on p.id = v.parent_id
     where (v_scope = 'TOAN_HE_THONG' or v.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or v.status_code = any (v_status))
       and (v_branch is null or v.branch_id = v_branch)
       and (cardinality(v_method) = 0 or v.payment_method_code = any (v_method))
       and (v_from is null or v.created_at >= v_from)
       and (v_to is null or v.created_at < v_to)
       and (v_q is null or v.code ilike '%' || v_q || '%' or r.ticket_ref ilike '%' || v_q || '%'
            or p.full_name ilike '%' || v_q || '%' or p.code ilike '%' || v_q || '%')
  )
  select (select count(*) from f),
         coalesce((select jsonb_agg(jsonb_build_object(
                    'id', v.id, 'code', v.code, 'status_code', v.status_code, 'amount', v.amount,
                    'ticket_ref', r.ticket_ref, 'refund_request_id', r.id, 'kind_code', r.kind_code,
                    'parent_id', p.id, 'parent_code', p.code, 'parent_name', p.full_name,
                    'branch_code', (select b.code from app.branch b where b.id = v.branch_id),
                    'created_at', v.created_at, 'paid_at', v.paid_at,
                    'planned_on', v.planned_on, 'payout_account_note', v.payout_account_note,
                    'payment_method_code', v.payment_method_code,
                    'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = v.payment_method_code)) order by v.created_at desc, v.id)
                   from (select f.id from f order by f.created_at desc, f.id limit v_limit offset v_offset) x
                   join app.payment_voucher v on v.id = x.id
                   join app.refund_request r on r.id = v.refund_request_id
                   join app.parent p on p.id = v.parent_id), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function app.quotation_group_label(text, text), app.order_group_label(text, text), app.voucher_group_label(text, text) from public, anon, authenticated;
revoke execute on function app.quotation_group_counts(jsonb, text[]), app.order_group_counts(jsonb, text[]), app.voucher_group_counts(jsonb, text[]) from public, anon;
grant execute on function app.quotation_group_counts(jsonb, text[]), app.order_group_counts(jsonb, text[]), app.voucher_group_counts(jsonb, text[]) to authenticated;
select set_config('hmt.migration', '', false);
