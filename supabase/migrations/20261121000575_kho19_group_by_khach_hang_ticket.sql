-- KHO #19 (docs/nghiep-vu/doi-chieu-group-by.md): Group By ở máy chủ cho KH-01 Phụ huynh và CS-01 Ticket (canvas: nút Group By, tối đa hai cấp, K1_nhom).
-- Hai hàm đếm: app.parent_group_counts và app.ticket_group_counts. Bộ lọc, phạm vi quyền GIỐNG hàm danh sách tương ứng; kết quả {total, groups: [{k1, l1, k2, l2, count}]}.
-- Mở một nhóm thì giao diện gọi lại hàm danh sách với bộ lọc của nhóm (parent: status, branch_id có sẵn; ticket: thêm group_code, assignee_id, no_assignee ở dưới).
-- Không thêm chỉ mục mới: đếm trên cùng tập dòng mà hàm danh sách đã quét; cột nhóm của ticket đã có chỉ mục (branch_id + status_code ở ticket_branch_status_due_idx, assignee_id ở ticket_assignee_status_idx),
-- phụ huynh nhóm theo branch_id (đã có chỉ mục theo cơ sở) và cờ đang học tính từ ghi danh như list_parents.
-- «Đang học tại» của KH-01 (nhiều cơ sở cùng lúc) KHÔNG làm trường nhóm: một phụ huynh lọt vào nhiều nhóm làm tổng đếm sai; ghi vào PR chờ Chat chốt.

-- ===== KH-01 Phụ huynh =====

-- app.parent_group_counts(bộ lọc, trường nhóm): ai có quyền «Phụ huynh · Xem» gọi được (như list_parents, R-CRM-27).
-- p_fields: status (Có con đang học / Chưa có con đang học), branch (cơ sở tiếp nhận). Chỗ rỗng không xảy ra (cả hai cột bắt buộc).
create or replace function app.parent_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('PARENT', 'XEM');
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_search text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phụ huynh.');
  end if;
  -- Luật: chỉ nhóm theo các trường cho phép, tối đa hai cấp, hai cấp khác nhau (Group By K1_nhom).
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status', 'branch'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, cơ sở tiếp nhận).');
  end if;
  with f as not materialized (
    select p.branch_id,
           exists (select from app.enrollment e where e.parent_id = p.id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC')) as studying
      from app.parent p
     where p.record_status = 'DANG_DUNG'
       and (v_branch is null or p.branch_id = v_branch)
       and (v_search is null or p.search_text like '%' || v_search || '%')
  ), g as (
    select * from f
     where cardinality(v_status) = 0
        or ('DANG_HOC' = any (v_status) and f.studying)
        or ('CHUA_DANG_HOC' = any (v_status) and not f.studying)
  ), keyed as (
    select case v_f1 when 'status' then case when g.studying then 'DANG_HOC' else 'CHUA_DANG_HOC' end when 'branch' then g.branch_id::text end as k1,
           case v_f2 when 'status' then case when g.studying then 'DANG_HOC' else 'CHUA_DANG_HOC' end when 'branch' then g.branch_id::text end as k2
      from g
  ), grouped as (select k1, k2, count(*) as n from keyed group by k1, k2), labeled as (
    select x.*,
           case when v_f1 = 'status' then case x.k1 when 'DANG_HOC' then 'Có con đang học' when 'CHUA_DANG_HOC' then 'Chưa có con đang học' end
                else (select b.code || ' ' || b.name from app.branch b where b.id = x.k1::uuid) end as l1,
           case when v_f2 = 'status' then case x.k2 when 'DANG_HOC' then 'Có con đang học' when 'CHUA_DANG_HOC' then 'Chưa có con đang học' end
                when v_f2 = 'branch' then (select b.code || ' ' || b.name from app.branch b where b.id = x.k2::uuid) end as l2
      from grouped x
  )
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(x.k1, ''), 'l1', x.l1,
             'k2', case when v_f2 is null then null else coalesce(x.k2, '') end,
             'l2', case when v_f2 is null then null else x.l2 end,
             'count', x.n) order by x.k1 nulls first, x.k2 nulls first), '[]'::jsonb))
    into v_result
    from labeled x;
  return v_result;
end;
$$;
revoke execute on function app.parent_group_counts(jsonb, text[]) from public, anon;
grant execute on function app.parent_group_counts(jsonb, text[]) to authenticated;

-- ===== CS-01 Ticket =====

-- app.ticket_filter_rows(bộ lọc): MỘT nơi định nghĩa bộ lọc ticket, dùng chung cho danh sách, Kanban (qua list_tickets) và đếm nhóm.
-- Không security definer: RLS của bảng ticket lọc theo quyền người gọi (như list_tickets trước đây).
-- Bộ lọc cũ giữ nguyên: ticket_type, status_code, category_code, priority_code, branch_id, mine, q, sla_state.
-- Thêm cho Group By (CS-01): group_code (nhóm ticket: nhóm cha của danh mục, hoặc chính danh mục nếu là nhóm), assignee_id, no_assignee (true: chưa có người phụ trách).
create or replace function app.ticket_filter_rows(p_filters jsonb default '{}'::jsonb)
returns setof app.ticket
language sql
stable
set search_path = ''
as $$
  select t.* from app.ticket t
   where (p_filters ->> 'ticket_type' is null or t.ticket_type = p_filters ->> 'ticket_type')
     and (p_filters ->> 'status_code' is null or t.status_code = p_filters ->> 'status_code')
     and (p_filters ->> 'category_code' is null or t.category_code = p_filters ->> 'category_code')
     and (p_filters ->> 'priority_code' is null or t.priority_code = p_filters ->> 'priority_code')
     and (p_filters ->> 'branch_id' is null or t.branch_id = (p_filters ->> 'branch_id')::uuid)
     and (p_filters ->> 'assignee_id' is null or t.assignee_id = (p_filters ->> 'assignee_id')::uuid)
     and (coalesce((p_filters ->> 'no_assignee')::boolean, false) = false or t.assignee_id is null)
     and (p_filters ->> 'group_code' is null
          or exists (select from app.ticket_category c where c.code = t.category_code and coalesce(c.parent_code, c.code) = p_filters ->> 'group_code'))
     and (coalesce((p_filters ->> 'mine')::boolean, false) = false or t.created_by = auth.uid() or t.assignee_id = auth.uid())
     and (nullif(btrim(coalesce(p_filters ->> 'q', '')), '') is null
          or t.code ilike '%' || btrim(p_filters ->> 'q') || '%' or t.title ilike '%' || btrim(p_filters ->> 'q') || '%')
     and (nullif(p_filters ->> 'sla_state', '') is null or app.ticket_row(t) ->> 'sla_state' = p_filters ->> 'sla_state');
$$;
revoke execute on function app.ticket_filter_rows(jsonb) from public, anon;
grant execute on function app.ticket_filter_rows(jsonb) to authenticated;

-- app.list_tickets: giữ nguyên chữ ký và kết quả, chỉ đổi nguồn bộ lọc sang app.ticket_filter_rows (một nơi định nghĩa).
create or replace function app.list_tickets(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_limit integer := least(coalesce(p_limit, app.get_setting_int('list_page_size_default')), app.get_setting_int('list_page_size_max'));
  v_total bigint;
  v_rows jsonb;
begin
  with f as (select t from app.ticket_filter_rows(p_filters) t)
  select (select count(*) from f),
         coalesce((select jsonb_agg(app.ticket_row(x.t) order by (x.t).created_at desc, (x.t).id)
                     from (select f.t from f order by (f.t).created_at desc, (f.t).id limit v_limit offset greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.ticket_group_label(trường, khoá): tên hiển thị của một nhóm ticket. Không security definer: đọc danh mục, cơ sở, người dùng dưới quyền người gọi như app.ticket_row.
create or replace function app.ticket_group_label(p_field text, p_key text)
returns text
language sql
stable
set search_path = ''
as $$
  select case
           when p_key is null or p_key = '' then null
           when p_field = 'type' then case p_key when 'DN' then 'Đề nghị' when 'KN' then 'Khiếu nại' when 'GV' then 'Giáo viên' end
           when p_field = 'group' then (select c.name from app.ticket_category c where c.code = p_key)
           when p_field = 'priority' then (select ci.name from app.catalog_item ci where ci.catalog_code = 'TICKET_PRIORITY' and ci.code = p_key)
           when p_field = 'status' then (select ci.name from app.catalog_item ci where ci.catalog_code = 'TICKET_STATUS' and ci.code = p_key)
           when p_field = 'assignee' then app.staff_display_name(p_key::uuid)
           when p_field = 'branch' then (select b.code || ' ' || b.name from app.branch b where b.id = p_key::uuid)
         end;
$$;
revoke execute on function app.ticket_group_label(text, text) from public, anon;
grant execute on function app.ticket_group_label(text, text) to authenticated;

-- app.ticket_group_counts(bộ lọc, trường nhóm): CS-01. Dưới quyền người gọi (RLS ticket như list_tickets): ai không thấy ticket nào thì nhận tổng 0.
-- p_fields: type (loại), group (nhóm ticket), priority (mức độ), status (trạng thái), assignee (người xử lý), branch (cơ sở). Chỗ rỗng: chỉ «người xử lý» (chưa giao), nhãn «Chưa có».
create or replace function app.ticket_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  -- Luật: chỉ nhóm theo các trường cho phép, tối đa hai cấp, hai cấp khác nhau (Group By K1_nhom).
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('type', 'group', 'priority', 'status', 'assignee', 'branch'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (loại, nhóm, mức độ, trạng thái, người xử lý, cơ sở).');
  end if;
  with f as not materialized (
    select g.ticket_type, g.category_code, g.priority_code, g.status_code, g.assignee_id, g.branch_id
      from app.ticket_filter_rows(p_filters) g
  ), keyed as (
    select case v_f1 when 'type' then f.ticket_type
                     when 'group' then (select coalesce(c.parent_code, c.code) from app.ticket_category c where c.code = f.category_code)
                     when 'priority' then f.priority_code when 'status' then f.status_code
                     when 'assignee' then f.assignee_id::text when 'branch' then f.branch_id::text end as k1,
           case v_f2 when 'type' then f.ticket_type
                     when 'group' then (select coalesce(c.parent_code, c.code) from app.ticket_category c where c.code = f.category_code)
                     when 'priority' then f.priority_code when 'status' then f.status_code
                     when 'assignee' then f.assignee_id::text when 'branch' then f.branch_id::text end as k2
      from f
  ), grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(x.k1, ''), 'l1', app.ticket_group_label(v_f1, x.k1),
             'k2', case when v_f2 is null then null else coalesce(x.k2, '') end,
             'l2', case when v_f2 is null then null else app.ticket_group_label(v_f2, x.k2) end,
             'count', x.n) order by x.k1 nulls first, x.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped x;
  return v_result;
end;
$$;
revoke execute on function app.ticket_group_counts(jsonb, text[]) from public, anon;
grant execute on function app.ticket_group_counts(jsonb, text[]) to authenticated;
