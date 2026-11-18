-- TT hiệu năng: Kanban phiếu tái tục chạy MỘT lượt (Code C, 18/11/2026). Đo trên 50.000 phiếu (CSKH, có RLS): danh sách 130 đến 290 ms, nhưng app.upsale_board gọi
-- app.list_upsale_tickets 16 lần (đếm và lấy thẻ cho 8 cột) mất 1,3 giây, vượt mục tiêu dưới 1 giây (CLAUDE.md, Hiệu năng).
-- Cách sửa: tách luật lọc vào một hàm dùng chung app.upsale_filtered(bộ lọc) (chạy quyền người gọi, RLS vẫn lọc), danh sách và Kanban cùng gọi nó; Kanban lọc một lần rồi xếp hạng
-- theo cột bằng cửa sổ. Kết quả JSON giữ nguyên hình dạng cũ; pgTAP 414 giữ nguyên.
select set_config('hmt.migration', 'on', false);

-- Luật lọc dùng chung (bộ lọc như app.list_upsale_tickets, trừ phân trang): id, giai đoạn, ngày hết giờ dự kiến, ngày tạo.
create or replace function app.upsale_filtered(p_filters jsonb)
returns table (id uuid, stage_code text, expected_end_date date, created_at timestamptz)
language sql
stable
set search_path = ''
as $$
  select t.id, t.stage_code, t.expected_end_date, t.created_at
    from app.upsale_ticket t
    join app.student s on s.id = t.student_id
    join app.class c on c.id = t.class_id
   where (p_filters ->> 'stage_code' is null or t.stage_code = p_filters ->> 'stage_code')
     and (p_filters ->> 'branch_id' is null or t.branch_id = (p_filters ->> 'branch_id')::uuid)
     and (nullif(p_filters ->> 'owner', '') is null
          or (p_filters ->> 'owner' = 'mine' and t.owner_id = auth.uid())
          or (p_filters ->> 'owner' = 'unassigned' and t.owner_id is null))
     and (nullif(p_filters ->> 'campaign_month', '') is null or to_char(t.expected_end_date, 'YYYY-MM') = p_filters ->> 'campaign_month')
     and (coalesce((p_filters ->> 'risk')::boolean, false) = false or t.risk_flag)
     and (nullif(btrim(coalesce(p_filters ->> 'q', '')), '') is null
          or t.code ilike '%' || btrim(p_filters ->> 'q') || '%' or s.full_name ilike '%' || btrim(p_filters ->> 'q') || '%'
          or c.code ilike '%' || btrim(p_filters ->> 'q') || '%');
$$;

-- Danh sách: dùng luật lọc chung (hành vi giữ nguyên migration 414).
create or replace function app.list_upsale_tickets(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
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
  with f as (select * from app.upsale_filtered(p_filters))
  select (select count(*) from f),
         coalesce((select jsonb_agg(app.upsale_ticket_row(u) order by x.expected_end_date nulls last, x.created_at desc, x.id)
                     from (select * from f order by expected_end_date nulls last, created_at desc, id
                            limit v_limit offset greatest(coalesce(p_offset, 0), 0)) x
                     join app.upsale_ticket u on u.id = x.id), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- Kanban L1..L8 một lượt: lọc một lần, xếp hạng trong từng cột, chỉ dựng JSON cho thẻ nằm trong trần mỗi cột.
create or replace function app.upsale_board(p_filters jsonb default '{}'::jsonb, p_per_column integer default 20)
returns jsonb
language sql
stable
set search_path = ''
as $$
  with f as (select * from app.upsale_filtered(p_filters - 'stage_code')),
  ranked as (
    select f.id, f.stage_code,
           row_number() over (partition by f.stage_code order by f.expected_end_date nulls last, f.created_at desc, f.id) as rn,
           count(*) over (partition by f.stage_code) as total
      from f),
  cards as (
    select r.stage_code, r.rn, r.total, app.upsale_ticket_row(u) as row_json
      from ranked r join app.upsale_ticket u on u.id = r.id
     where r.rn <= least(greatest(p_per_column, 1), 50) -- allow-number: trần 50 dòng mỗi cột Kanban
  )
  select coalesce(jsonb_agg(jsonb_build_object('stage_code', s.code, 'name', s.name,
           'total', coalesce((select max(c.total) from cards c where c.stage_code = s.code), 0),
           'rows', coalesce((select jsonb_agg(c.row_json order by c.rn) from cards c where c.stage_code = s.code), '[]'::jsonb))
         order by s.sort_order), '[]'::jsonb)
    from app.catalog_item s where s.catalog_code = 'UPSALE_STAGE' and s.is_active;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.upsale_filtered(jsonb) from public, anon;
grant execute on function app.upsale_filtered(jsonb) to authenticated;
