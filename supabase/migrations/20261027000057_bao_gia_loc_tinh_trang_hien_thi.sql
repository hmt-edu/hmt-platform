-- ===========================================================================
-- P5a-DB1c-5 (migration 057, Đ243): bộ lọc `status` của app.list_quotations và app.export_quotations lọc theo TÌNH TRẠNG HIỂN THỊ: nhận thêm
-- giá trị DA_CHUYEN_DON, các giá trị nối bằng HOẶC, DA_GUI chỉ gồm báo giá Đã gửi chưa chuyển hết. Khoá `converted` (migration 054) giữ
-- nguyên; `expired` giữ nguyên. Chỉ đọc; không bảng, chỉ mục mới.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

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
     where (v_scope = 'TOAN_HE_THONG' or q.branch_id = v_my_branch)
       and (v_q is null or q.search_text like '%' || v_q || '%')
       -- Tình trạng hiển thị (Đ243): Đã gửi chỉ gồm báo giá chưa chuyển hết; Đã chuyển đơn là báo giá Đã gửi mà mọi dòng đã lên đơn. Các giá trị nối bằng HOẶC.
       and (cardinality(v_status) = 0 or (q.status_code = any (v_status_db)
            and (case when q.status_code = 'DA_GUI' and app.quotation_converted(q.id) then 'DA_CHUYEN_DON' else q.status_code end) = any (v_status)))
       and (v_branch is null or q.branch_id = v_branch)
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


create or replace function app.export_quotations(p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('QUOTATION', 'XUAT');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  -- Mã lưu trong DB cần xét trước: Đã chuyển đơn nằm trong các báo giá Đã gửi (Đ243).
  v_status_db text[] := array(select distinct case when x = 'DA_CHUYEN_DON' then 'DA_GUI' else x end from unnest(v_status) x);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_expired boolean := coalesce((p_filters ->> 'expired')::boolean, false);
  v_converted boolean := (p_filters ->> 'converted')::boolean;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Phạm vi dòng lấy từ quyền Xuất, không phải Xem.
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất danh sách báo giá.');
  end if;
  select count(*) into v_total
    from app.quotation q
   where (v_scope = 'TOAN_HE_THONG' or q.branch_id = v_my_branch)
     and (v_q is null or q.search_text like '%' || v_q || '%')
     -- Tình trạng hiển thị (Đ243): Đã gửi chỉ gồm báo giá chưa chuyển hết; Đã chuyển đơn là báo giá Đã gửi mà mọi dòng đã lên đơn. Các giá trị nối bằng HOẶC.
     and (cardinality(v_status) = 0 or (q.status_code = any (v_status_db)
          and (case when q.status_code = 'DA_GUI' and app.quotation_converted(q.id) then 'DA_CHUYEN_DON' else q.status_code end) = any (v_status)))
     and (v_branch is null or q.branch_id = v_branch)
     and (v_opp is null or q.opportunity_id = v_opp)
     and (v_parent is null or q.parent_id = v_parent)
     and (not v_mine or q.created_by = auth.uid())
     and (not v_expired or (q.status_code = 'DA_GUI' and q.valid_until < v_today))
     -- Đã chuyển đơn: báo giá Đã gửi mà mọi dòng đã lên đơn còn sống (app.quotation_converted); false thì loại các báo giá đó.
     and (v_converted is null or (q.status_code = 'DA_GUI' and app.quotation_converted(q.id)) = v_converted)
     and (v_from is null or q.created_at >= v_from)
     and (v_to is null or q.created_at < v_to);
  with f as (
    select q.*
      from app.quotation q
     where (v_scope = 'TOAN_HE_THONG' or q.branch_id = v_my_branch)
       and (v_q is null or q.search_text like '%' || v_q || '%')
       -- Tình trạng hiển thị (Đ243): Đã gửi chỉ gồm báo giá chưa chuyển hết; Đã chuyển đơn là báo giá Đã gửi mà mọi dòng đã lên đơn. Các giá trị nối bằng HOẶC.
       and (cardinality(v_status) = 0 or (q.status_code = any (v_status_db)
            and (case when q.status_code = 'DA_GUI' and app.quotation_converted(q.id) then 'DA_CHUYEN_DON' else q.status_code end) = any (v_status)))
       and (v_branch is null or q.branch_id = v_branch)
       and (v_opp is null or q.opportunity_id = v_opp)
       and (v_parent is null or q.parent_id = v_parent)
       and (not v_mine or q.created_by = auth.uid())
       and (not v_expired or (q.status_code = 'DA_GUI' and q.valid_until < v_today))
       -- Đã chuyển đơn: báo giá Đã gửi mà mọi dòng đã lên đơn còn sống (app.quotation_converted); false thì loại các báo giá đó.
       and (v_converted is null or (q.status_code = 'DA_GUI' and app.quotation_converted(q.id)) = v_converted)
       and (v_from is null or q.created_at >= v_from)
       and (v_to is null or q.created_at < v_to)
     order by q.created_at desc, q.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', f.code,
           'status', (select c.name from app.catalog_item c where c.catalog_code = 'QUOTATION_STATUS' and c.code = f.status_code),
           'parent_name', par.full_name, 'parent_phone', par.phone, 'opportunity', o.code,
           'students', (select string_agg(distinct v.full_name, '; ') from app.quotation_line l
                          join app.prospect_student_v v on v.id = l.prospect_student_id where l.quotation_id = f.id),
           'total_amount', f.total_amount, 'valid_until', f.valid_until, 'sent_at', f.sent_at,
           'branch', b.code, 'created_by', app.staff_display_name(f.created_by), 'created_at', f.created_at)
           order by f.created_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id
    join app.parent par on par.id = f.parent_id
    join app.opportunity o on o.id = f.opportunity_id;
  perform app.log_export('QUOTATION', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.list_quotations(jsonb, text, integer, integer) from public, anon;
grant execute on function app.list_quotations(jsonb, text, integer, integer) to authenticated;
revoke execute on function app.export_quotations(jsonb) from public, anon;
grant execute on function app.export_quotations(jsonb) to authenticated;
