-- Migration 673 (Code C, 26/11/2026, C-26-02): số đếm lead, cơ hội trong báo cáo không tính bản «Đã gộp» (DA_GOP) và «Đã huỷ» (DA_HUY).
-- Luật: R-CRM-22 (bản đã gộp chỉ để xem), E60 (lead nhập nhầm đã huỷ). Lead «Không có nhu cầu» là lead thật, vẫn tính.
-- Không đổi bảng, không đổi tên hay thứ tự cột; create or replace giữ nguyên quyền đã cấp.

-- BC-02: phễu lead → cơ hội → chốt. Chỉ lead và cơ hội đang dùng.
create or replace view report.lead_funnel with (security_invoker = true) as
select l.branch_id,
       (l.created_at at time zone 'Asia/Ho_Chi_Minh')::date - extract(day from (l.created_at at time zone 'Asia/Ho_Chi_Minh'))::int + 1 as month_start,
       l.source_type_code, l.source_code, l.campaign_id, l.owner_id,
       count(distinct l.id) as leads,
       count(distinct o.id) as opportunities,
       count(distinct o.id) filter (where o.stage_code = 'L8') as opportunities_won
  from app.lead l
  left join app.opportunity o on o.lead_id = l.id and o.record_status = 'DANG_DUNG'
 where l.record_status = 'DANG_DUNG'
 group by 1, 2, 3, 4, 5, 6;

-- CH-08: danh sách chiến dịch; số lead gắn chỉ đếm lead đang dùng.
create or replace function app.list_campaigns(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(coalesce(p_limit, app.get_setting_int('list_page_size_default')), app.get_setting_int('list_page_size_max'));
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_status text := nullif(p_filters ->> 'status', '');
  v_admin boolean := 'ADMIN' = any (app.current_roles());
  v_total bigint;
  v_rows jsonb;
begin
  -- Luật quyền: mọi vai trò vào được cổng CRM.
  if not app.is_crm_user() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem chiến dịch.');
  end if;
  if v_status is not null and v_status not in ('DANG_DUNG', 'NGUNG') then
    perform app.raise_error('HMT_LOC_KHONG_HOP_LE', 'Tình trạng lọc không hợp lệ.');
  end if;
  with f as (
    select c.* from app.campaign c
     where (v_q is null or c.name ilike '%' || v_q || '%')
       and (v_status is null or c.is_active = (v_status = 'DANG_DUNG'))
  )
  select (select count(*) from f),
         coalesce((select jsonb_agg(jsonb_build_object(
                     'id', x.id, 'name', x.name, 'starts_on', x.starts_on, 'ends_on', x.ends_on, 'is_active', x.is_active,
                     'lead_count', (select count(*) from app.lead l where l.campaign_id = x.id and l.record_status = 'DANG_DUNG'),
                     'created_by_name', app.staff_display_name(x.created_by),
                     'can_toggle', v_admin or x.created_by = auth.uid())
                   order by x.created_at desc, x.id)
                     from (select * from f order by created_at desc, id limit v_limit offset greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;
