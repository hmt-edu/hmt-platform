-- C69 (KHO-VIEC dòng 19 phần TT-01 Tái tục): Group By ở máy chủ (canvas K1_nhom, tối đa hai cấp), theo mẫu appointment_group_counts (Đ35).
-- Trường nhóm: stage (giai đoạn L1 đến L8), substage (nhóm con), campaign (đợt tái tục theo tháng hết giờ dự kiến), owner (phụ trách), branch (cơ sở).
-- Làm gì: (1) upsale_filtered (bản migration 419) thêm hai bộ lọc `owner_id`, `substage_code` để mở nhóm lá, KHÔNG đổi luật khác; (2) app.upsale_group_label, app.upsale_group_counts (cùng bộ lọc như list_upsale_tickets);
-- (3) vỏ bọc app.list_upsale_tickets_grouped (có p_sort để khung mở nhóm dùng được, hàm gốc không đổi). Chỉ đọc. Lỗi: HMT_NHOM_SAI. Quyền: như list_upsale_tickets (RLS của bảng).
select set_config('hmt.migration', 'on', false);

create or replace function app.upsale_filtered(p_filters jsonb)
returns table (id uuid, stage_code text, expected_end_date date, created_at timestamptz)
language sql
stable
set search_path = ''
as $$
  select t.id, t.stage_code, t.expected_end_date, t.created_at
    from app.upsale_ticket t
   where (p_filters ->> 'stage_code' is null or t.stage_code = p_filters ->> 'stage_code')
     and (p_filters ->> 'branch_id' is null or t.branch_id = (p_filters ->> 'branch_id')::uuid)
     and (nullif(p_filters ->> 'owner', '') is null
          or (p_filters ->> 'owner' = 'mine' and t.owner_id = auth.uid())
          or (p_filters ->> 'owner' = 'unassigned' and t.owner_id is null))
     and (nullif(p_filters ->> 'campaign_month', '') is null or to_char(t.expected_end_date, 'YYYY-MM') = p_filters ->> 'campaign_month')
     and (coalesce((p_filters ->> 'risk')::boolean, false) = false or t.risk_flag)
     -- C69 (Group By): mở nhóm theo người phụ trách cụ thể và nhóm con.
     and (nullif(p_filters ->> 'owner_id', '') is null or t.owner_id = (p_filters ->> 'owner_id')::uuid)
     and (nullif(p_filters ->> 'substage_code', '') is null or t.substage_code = p_filters ->> 'substage_code')
     -- Tìm chữ: chỉ khi có chữ mới tra tên học sinh, mã lớp (không nối hai bảng cho từng dòng khi không tìm).
     and (nullif(btrim(coalesce(p_filters ->> 'q', '')), '') is null
          or t.code ilike '%' || btrim(p_filters ->> 'q') || '%'
          or exists (select from app.student s where s.id = t.student_id and s.full_name ilike '%' || btrim(p_filters ->> 'q') || '%')
          or exists (select from app.class c where c.id = t.class_id and c.code ilike '%' || btrim(p_filters ->> 'q') || '%'));
$$;

create or replace function app.upsale_group_label(p_field text, p_key text)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'stage' then coalesce((select name from app.catalog_item where catalog_code = 'UPSALE_STAGE' and code = p_key), p_key)
    when p_field = 'substage' then p_key || ' ' || coalesce((select name from app.catalog_item where catalog_code = 'UPSALE_SUBSTAGE' and code = p_key), '')
    when p_field = 'campaign' then 'Tái tục ' || to_char(to_date(p_key || '-01', 'YYYY-MM-DD'), 'MM/YYYY')
    when p_field = 'owner' then coalesce(app.staff_display_name(p_key::uuid), p_key)
    when p_field = 'branch' then coalesce((select code || ' ' || name from app.branch where id = p_key::uuid), p_key)
    else p_key end;
$$;

create or replace function app.upsale_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
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
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('stage', 'substage', 'campaign', 'owner', 'branch'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (giai đoạn, nhóm con, đợt tái tục, phụ trách, cơ sở).');
  end if;
  with f as (select u.* from app.upsale_filtered(p_filters) x join app.upsale_ticket u on u.id = x.id),
  keyed as (
    select case v_f1 when 'stage' then f.stage_code when 'substage' then f.substage_code when 'campaign' then to_char(f.expected_end_date, 'YYYY-MM')
                     when 'owner' then f.owner_id::text when 'branch' then f.branch_id::text end as k1,
           case v_f2 when 'stage' then f.stage_code when 'substage' then f.substage_code when 'campaign' then to_char(f.expected_end_date, 'YYYY-MM')
                     when 'owner' then f.owner_id::text when 'branch' then f.branch_id::text end as k2
      from f
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.upsale_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.upsale_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

create or replace function app.list_upsale_tickets_grouped(p_filters jsonb default '{}'::jsonb, p_sort text default null, p_limit integer default null, p_offset integer default 0)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select app.list_upsale_tickets(p_filters, p_limit, p_offset);
$$;

-- Nhãn nhóm chạy bằng quyền người gọi (hàm đếm không security definer để RLS của phiếu tái tục áp dụng): cấp quyền gọi cho đăng nhập.
revoke execute on function app.upsale_group_label(text, text) from public, anon;
grant execute on function app.upsale_group_label(text, text) to authenticated;
revoke execute on function app.upsale_group_counts(jsonb, text[]), app.list_upsale_tickets_grouped(jsonb, text, integer, integer) from public, anon;
grant execute on function app.upsale_group_counts(jsonb, text[]), app.list_upsale_tickets_grouped(jsonb, text, integer, integer) to authenticated;
select set_config('hmt.migration', '', false);
