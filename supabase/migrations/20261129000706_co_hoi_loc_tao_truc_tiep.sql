-- Migration 706 (E-27-14, Chat chọn phương án (a) 29/11/2026): lọc «Tạo trực tiếp» ở màn Cơ hội (KE-HOACH-26-11 C3).
-- Luật R-CRM-01: «tạo trực tiếp» = app.opportunity.lead_id TRỐNG (như migration 672).
-- Thêm khoá p_filters.direct_only (true/false) cho bốn hàm dùng chung bộ lọc: list_opportunities, opportunity_board,
-- opportunity_group_counts, export_opportunities. Thân hàm chép nguyên bản đang hiệu lực, chỉ thêm một điều kiện lọc.
-- Quyền, phạm vi dòng, quyền chạy hàm giữ nguyên (create or replace không đổi grant).
-- Chỉ mục: không thêm; opportunity_lead_idx đã có và điều kiện lead_id trống dùng được chỉ mục btree này.

-- app.list_opportunities: bản của 20261126000672_tao_co_hoi_truc_tiep.sql, thêm lọc direct_only (R-CRM-01).
CREATE OR REPLACE FUNCTION app.list_opportunities(p_filters jsonb DEFAULT '{}'::jsonb, p_sort text DEFAULT 'created_desc'::text, p_limit integer DEFAULT NULL::integer, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text := app.permission_scope('OPPORTUNITY', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_channel text[] := array(select jsonb_array_elements_text(p_filters -> 'channel'));
  v_campaign uuid := nullif(p_filters ->> 'campaign_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_support_mine boolean := coalesce((p_filters ->> 'supporter_mine')::boolean, false);
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_next_from timestamptz := nullif(p_filters ->> 'next_from', '')::timestamptz;
  v_next_to timestamptz := nullif(p_filters ->> 'next_to', '')::timestamptz;
  v_next_before timestamptz := nullif(p_filters ->> 'next_before', '')::timestamptz;
  v_no_appt boolean := coalesce((p_filters ->> 'no_appointment')::boolean, false);
  v_only_merged boolean := coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false) or coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_appt text[] := array(select jsonb_array_elements_text(p_filters -> 'appointment'));
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách cơ hội.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang); mặc định Postgres quét cả bảng rồi sắp xếp.
  with f as not materialized (
    select o.*
      from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and o.branch_id = v_my_branch))
       and (case when v_only_merged then o.record_status = 'DA_GOP'
             else (v_merged or o.record_status = 'DANG_DUNG'
                   or (v_q is not null and o.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or o.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or o.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or o.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or o.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or o.channel_code = any (v_channel))
       and (v_campaign is null or o.campaign_id = v_campaign)
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and o.owner_id = auth.uid())
        or ('SUPPORT' = any (v_mine_roles) and o.supporter_id = auth.uid()))
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (not coalesce((p_filters ->> 'direct_only')::boolean, false) or o.lead_id is null)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
       and (v_next_from is null or o.next_appointment_at >= v_next_from)
       and (v_next_to is null or o.next_appointment_at < v_next_to)
       and (v_next_before is null or o.next_appointment_at < v_next_before)
       and (not v_no_appt or o.next_appointment_at is null)
       and (cardinality(v_appt) = 0
        or ('OVERDUE' = any (v_appt) and o.next_appointment_at < v_day_start)
        or ('TODAY' = any (v_appt) and o.next_appointment_at >= v_day_start and o.next_appointment_at < v_day_end)
        or ('UPCOMING' = any (v_appt) and o.next_appointment_at >= v_day_end)
        or ('NONE' = any (v_appt) and o.next_appointment_at is null))
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'next_appointment_asc' then f.next_appointment_at end asc nulls last,
              case when p_sort = 'name_asc' then (app.opp_first(f.id)).full_name end asc nulls last,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'lead_id', p.lead_id, 'lead_code', l.code,
             'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
             'student_name', (app.opp_first(p.id)).full_name, 'student_birth_year', (app.opp_first(p.id)).birth_year,
             'stage_code', p.stage_code, 'substage_code', p.substage_code,
             'source_type_code', p.source_type_code, 'source_code', p.source_code, 'channel_code', p.channel_code,
             'campaign_id', p.campaign_id, 'campaign_name', c.name,
             'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'supporter_id', p.supporter_id, 'supporter_name', app.staff_display_name(p.supporter_id),
             'branch_code', b.code, 'assigned_at', p.assigned_at,
             'next_appointment_at', p.next_appointment_at, 'created_at', p.created_at,
             'record_status', p.record_status, 'merged_into_code', m.code)
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'next_appointment_asc' then p.next_appointment_at end asc nulls last,
                      case when p_sort = 'name_asc' then (app.opp_first(p.id)).full_name end asc nulls last,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent par on par.id = p.parent_id
    left join app.lead l on l.id = p.lead_id
    left join app.opportunity m on m.id = p.merged_into_id
    left join app.campaign c on c.id = p.campaign_id;
  return v_result;
end;
$function$;

-- app.opportunity_board: bản của 20261119000422_c28_pham_vi_hep_ham_va_chinh_sach.sql, thêm lọc direct_only (R-CRM-01).
CREATE OR REPLACE FUNCTION app.opportunity_board(p_filters jsonb DEFAULT '{}'::jsonb, p_per_column integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text := app.permission_scope('OPPORTUNITY', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_channel text[] := array(select jsonb_array_elements_text(p_filters -> 'channel'));
  v_campaign uuid := nullif(p_filters ->> 'campaign_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_support_mine boolean := coalesce((p_filters ->> 'supporter_mine')::boolean, false);
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_next_from timestamptz := nullif(p_filters ->> 'next_from', '')::timestamptz;
  v_next_to timestamptz := nullif(p_filters ->> 'next_to', '')::timestamptz;
  v_next_before timestamptz := nullif(p_filters ->> 'next_before', '')::timestamptz;
  v_no_appt boolean := coalesce((p_filters ->> 'no_appointment')::boolean, false);
  v_only_merged boolean := coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false) or coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_appt text[] := array(select jsonb_array_elements_text(p_filters -> 'appointment'));
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_per integer := least(greatest(coalesce(p_per_column, app.get_setting_int('kanban_cards_per_column')), 1),
                         app.get_setting_int('list_page_size_max'));
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem cơ hội.');
  end if;
  with base as not materialized (
    select o.*
      from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and o.branch_id = v_my_branch))
       and o.record_status = 'DANG_DUNG'
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_type) = 0 or o.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or o.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or o.channel_code = any (v_channel))
       and (v_campaign is null or o.campaign_id = v_campaign)
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and o.owner_id = auth.uid())
        or ('SUPPORT' = any (v_mine_roles) and o.supporter_id = auth.uid()))
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (not coalesce((p_filters ->> 'direct_only')::boolean, false) or o.lead_id is null)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
  ),
  stats as (
    select b.stage_code,
           count(*) filter (where (v_next_from is null or b.next_appointment_at >= v_next_from)

               and (v_next_to is null or b.next_appointment_at < v_next_to)

               and (v_next_before is null or b.next_appointment_at < v_next_before)

               and (not v_no_appt or b.next_appointment_at is null)

               and (cardinality(v_appt) = 0
                    or ('OVERDUE' = any (v_appt) and b.next_appointment_at < v_day_start)
                    or ('TODAY' = any (v_appt) and b.next_appointment_at >= v_day_start and b.next_appointment_at < v_day_end)
                    or ('UPCOMING' = any (v_appt) and b.next_appointment_at >= v_day_end)
                    or ('NONE' = any (v_appt) and b.next_appointment_at is null))) as total,
           count(*) filter (where b.next_appointment_at is null) as n_none,
           count(*) filter (where b.next_appointment_at < v_day_start) as n_overdue,
           count(*) filter (where b.next_appointment_at >= v_day_start and b.next_appointment_at < v_day_end) as n_today,
           count(*) filter (where b.next_appointment_at >= v_day_end) as n_ok
      from base b group by b.stage_code
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'stage_code', s.code, 'name', s.name, 'total', coalesce(st.total, 0),
           'bar', jsonb_build_object('ok', coalesce(st.n_ok, 0), 'today', coalesce(st.n_today, 0),
                                     'overdue', coalesce(st.n_overdue, 0), 'none', coalesce(st.n_none, 0)),
           'rows', cards.rows) order by s.sort_order), '[]'::jsonb)
    into v_result
    from app.catalog_item s
    left join stats st on st.stage_code = s.code
    cross join lateral (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', t.id, 'code', t.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
               'student_name', (app.opp_first(t.id)).full_name, 'source_type_code', t.source_type_code, 'source_code', t.source_code,
               'channel_code', t.channel_code, 'substage_code', t.substage_code, 'owner_id', t.owner_id,
               'owner_name', app.staff_display_name(t.owner_id), 'branch_code', b.code,
               'next_appointment_at', t.next_appointment_at, 'created_at', t.created_at)
               order by t.created_at desc, t.id), '[]'::jsonb) as rows
        from (select * from base bb where bb.stage_code = s.code
               and (v_next_from is null or bb.next_appointment_at >= v_next_from)
               and (v_next_to is null or bb.next_appointment_at < v_next_to)
               and (v_next_before is null or bb.next_appointment_at < v_next_before)
               and (not v_no_appt or bb.next_appointment_at is null)
               and (cardinality(v_appt) = 0
                    or ('OVERDUE' = any (v_appt) and bb.next_appointment_at < v_day_start)
                    or ('TODAY' = any (v_appt) and bb.next_appointment_at >= v_day_start and bb.next_appointment_at < v_day_end)
                    or ('UPCOMING' = any (v_appt) and bb.next_appointment_at >= v_day_end)
                    or ('NONE' = any (v_appt) and bb.next_appointment_at is null))
               order by bb.created_at desc, bb.id limit v_per) t
        join app.parent par on par.id = t.parent_id
        join app.branch b on b.id = t.branch_id
    ) cards
   where s.catalog_code = 'OPP_STAGE' and s.is_active;
  return v_result;
end;
$function$;

-- app.opportunity_group_counts: bản của 20261019000038_co_hoi_ban_ghi_danh_sach.sql, thêm lọc direct_only (R-CRM-01).
create or replace function app.opportunity_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('OPPORTUNITY', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_channel text[] := array(select jsonb_array_elements_text(p_filters -> 'channel'));
  v_campaign uuid := nullif(p_filters ->> 'campaign_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_support_mine boolean := coalesce((p_filters ->> 'supporter_mine')::boolean, false);
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_next_from timestamptz := nullif(p_filters ->> 'next_from', '')::timestamptz;
  v_next_to timestamptz := nullif(p_filters ->> 'next_to', '')::timestamptz;
  v_next_before timestamptz := nullif(p_filters ->> 'next_before', '')::timestamptz;
  v_no_appt boolean := coalesce((p_filters ->> 'no_appointment')::boolean, false);
  v_only_merged boolean := coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false) or coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_appt text[] := array(select jsonb_array_elements_text(p_filters -> 'appointment'));
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách cơ hội.');
  end if;
  -- Luật: chỉ nhóm theo các trường cho phép, tối đa hai cấp, hai cấp khác nhau (Group By K1_nhom).
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('stage', 'substage', 'source_type', 'source', 'owner', 'branch'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (giai đoạn, nhóm con, loại nguồn, nguồn, người phụ trách, cơ sở).');
  end if;
  with f as not materialized (
    select o.*
      from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (case when v_only_merged then o.record_status = 'DA_GOP'
             else (v_merged or o.record_status = 'DANG_DUNG'
                   or (v_q is not null and o.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or o.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or o.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or o.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or o.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or o.channel_code = any (v_channel))
       and (v_campaign is null or o.campaign_id = v_campaign)
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and o.owner_id = auth.uid())
        or ('SUPPORT' = any (v_mine_roles) and o.supporter_id = auth.uid()))
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (not coalesce((p_filters ->> 'direct_only')::boolean, false) or o.lead_id is null)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
       and (v_next_from is null or o.next_appointment_at >= v_next_from)
       and (v_next_to is null or o.next_appointment_at < v_next_to)
       and (v_next_before is null or o.next_appointment_at < v_next_before)
       and (not v_no_appt or o.next_appointment_at is null)
       and (cardinality(v_appt) = 0
        or ('OVERDUE' = any (v_appt) and o.next_appointment_at < v_day_start)
        or ('TODAY' = any (v_appt) and o.next_appointment_at >= v_day_start and o.next_appointment_at < v_day_end)
        or ('UPCOMING' = any (v_appt) and o.next_appointment_at >= v_day_end)
        or ('NONE' = any (v_appt) and o.next_appointment_at is null))
  ),
  keyed as (
    select case v_f1 when 'stage' then f.stage_code when 'substage' then f.substage_code when 'source_type' then f.source_type_code
                     when 'source' then f.source_code when 'owner' then f.owner_id::text when 'branch' then f.branch_id::text end as k1,
           case v_f2 when 'stage' then f.stage_code when 'substage' then f.substage_code when 'source_type' then f.source_type_code
                     when 'source' then f.source_code when 'owner' then f.owner_id::text when 'branch' then f.branch_id::text end as k2
      from f
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.opportunity_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.opportunity_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

-- app.export_opportunities: bản của 20261126000672_tao_co_hoi_truc_tiep.sql, thêm lọc direct_only (R-CRM-01).
CREATE OR REPLACE FUNCTION app.export_opportunities(p_filters jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text;
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_channel text[] := array(select jsonb_array_elements_text(p_filters -> 'channel'));
  v_campaign uuid := nullif(p_filters ->> 'campaign_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_support_mine boolean := coalesce((p_filters ->> 'supporter_mine')::boolean, false);
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_next_from timestamptz := nullif(p_filters ->> 'next_from', '')::timestamptz;
  v_next_to timestamptz := nullif(p_filters ->> 'next_to', '')::timestamptz;
  v_next_before timestamptz := nullif(p_filters ->> 'next_before', '')::timestamptz;
  v_no_appt boolean := coalesce((p_filters ->> 'no_appointment')::boolean, false);
  v_only_merged boolean := coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false) or coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_appt text[] := array(select jsonb_array_elements_text(p_filters -> 'appointment'));
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Phạm vi dòng lấy từ quyền Xuất (không phải Xem): vai trò Xem toàn hệ thống nhưng Xuất trong cơ sở chỉ xuất được cơ sở mình.
  v_scope := app.permission_scope('OPPORTUNITY', 'XUAT');
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất danh sách cơ hội.');
  end if;
  select count(*) into v_total
    from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (case when v_only_merged then o.record_status = 'DA_GOP'
             else (v_merged or o.record_status = 'DANG_DUNG'
                   or (v_q is not null and o.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or o.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or o.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or o.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or o.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or o.channel_code = any (v_channel))
       and (v_campaign is null or o.campaign_id = v_campaign)
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and o.owner_id = auth.uid())
        or ('SUPPORT' = any (v_mine_roles) and o.supporter_id = auth.uid()))
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (not coalesce((p_filters ->> 'direct_only')::boolean, false) or o.lead_id is null)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
       and (v_next_from is null or o.next_appointment_at >= v_next_from)
       and (v_next_to is null or o.next_appointment_at < v_next_to)
       and (v_next_before is null or o.next_appointment_at < v_next_before)
       and (not v_no_appt or o.next_appointment_at is null)
       and (cardinality(v_appt) = 0
        or ('OVERDUE' = any (v_appt) and o.next_appointment_at < v_day_start)
        or ('TODAY' = any (v_appt) and o.next_appointment_at >= v_day_start and o.next_appointment_at < v_day_end)
        or ('UPCOMING' = any (v_appt) and o.next_appointment_at >= v_day_end)
        or ('NONE' = any (v_appt) and o.next_appointment_at is null));
  with f as (
    select o.*
      from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (case when v_only_merged then o.record_status = 'DA_GOP'
             else (v_merged or o.record_status = 'DANG_DUNG'
                   or (v_q is not null and o.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or o.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or o.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or o.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or o.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or o.channel_code = any (v_channel))
       and (v_campaign is null or o.campaign_id = v_campaign)
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and o.owner_id = auth.uid())
        or ('SUPPORT' = any (v_mine_roles) and o.supporter_id = auth.uid()))
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (not coalesce((p_filters ->> 'direct_only')::boolean, false) or o.lead_id is null)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
       and (v_next_from is null or o.next_appointment_at >= v_next_from)
       and (v_next_to is null or o.next_appointment_at < v_next_to)
       and (v_next_before is null or o.next_appointment_at < v_next_before)
       and (not v_no_appt or o.next_appointment_at is null)
       and (cardinality(v_appt) = 0
        or ('OVERDUE' = any (v_appt) and o.next_appointment_at < v_day_start)
        or ('TODAY' = any (v_appt) and o.next_appointment_at >= v_day_start and o.next_appointment_at < v_day_end)
        or ('UPCOMING' = any (v_appt) and o.next_appointment_at >= v_day_end)
        or ('NONE' = any (v_appt) and o.next_appointment_at is null))
     order by o.created_at desc, o.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', f.code, 'lead', l.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
           'student_name', (app.opp_first(f.id)).full_name, 'student_birth_year', (app.opp_first(f.id)).birth_year, 'school', (app.opp_first(f.id)).school, 'need', f.need,
           'source_type', st.name, 'source', so.name, 'channel', ch.name, 'campaign', ca.name,
           'stage', sg.name, 'substage', ss.name,
           'owner', app.staff_display_name(f.owner_id), 'supporter', app.staff_display_name(f.supporter_id),
           'branch', b.code, 'next_appointment_at', f.next_appointment_at, 'created_at', f.created_at,
           'record_status', f.record_status) order by f.created_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id
    join app.parent par on par.id = f.parent_id
    left join app.lead l on l.id = f.lead_id
    left join app.catalog_item st on st.catalog_code = 'SOURCE_TYPE' and st.code = f.source_type_code
    left join app.catalog_item so on so.catalog_code = 'SOURCE' and so.code = f.source_code
    left join app.catalog_item ch on ch.catalog_code = 'SOURCE_CHANNEL' and ch.code = f.channel_code
    left join app.campaign ca on ca.id = f.campaign_id
    left join app.catalog_item sg on sg.catalog_code = 'OPP_STAGE' and sg.code = f.stage_code
    left join app.catalog_item ss on ss.catalog_code = 'OPP_SUBSTAGE' and ss.code = f.substage_code;
  -- Ghi nhật ký xuất TRƯỚC khi trả dữ liệu (cùng giao dịch): lỗi ở đây thì không có file.
  perform app.log_export('OPPORTUNITY', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$function$;
