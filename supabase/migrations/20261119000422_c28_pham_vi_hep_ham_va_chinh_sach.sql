-- C28 (Soát S16, mức CAO; Chat giao 19/11/2026): đóng nốt R1c, R1d, R3. Lỗi gốc R1: phạm vi hẹp (Được phân công, Của tôi, Chính mình) bị coi là «cả cơ sở». Migration 460–463 đã đóng ở BẢNG;
-- migration này đóng ở HÀM (security definer, là đường giao diện dùng) và hai chính sách còn sót.
--  (1) R1c: hàm danh sách (list_leads, lead_board, list_opportunities, opportunity_board, list_appointments, list_quotations, list_orders, list_receipts, list_receivables):
--      điều kiện lọc cơ sở đổi từ «Toàn hệ thống hoặc cùng cơ sở» sang «Toàn hệ thống, hoặc phạm vi CO_SO và cùng cơ sở». Thân hàm giữ nguyên bản mới nhất, chỉ đổi đúng một điều kiện.
--  (2) R1c: hàm chi tiết (get_lead, get_opportunity, get_order, get_receipt) dùng app.assert_can_wide, app.can_see_branch_wide (mới): chỉ Toàn hệ thống hoặc Cơ sở mình mới thấy cơ sở.
--      KHÔNG đổi app.can_see_branch/app.assert_can chung vì giáo viên, trợ giảng có phạm vi Được phân công ở LỚP, BUỔI, ĐIỂM DANH, GHI DANH… và các hàm của họ đang dựa vào hàm chung.
--  (3) R1d: chính sách parent_read (giữ phụ huynh dùng chung cho Toàn hệ thống và Cơ sở mình, bỏ phạm vi hẹp), student_read (chỉ Cơ sở mình đọc theo cơ sở; Được phân công giữ student_assigned_to_me).
--  (4) R3: app.can_see_note_target nhánh BRANCH, ROOM đòi là nhân viên (app.is_staff), Học sinh, Phụ huynh không đọc ghi chú gắn Phòng, Cơ sở.
-- Hôm nay chưa vai nào đổi kết quả (mọi ô Xem của các phân hệ này là Toàn hệ thống hoặc Cơ sở); chỉ chặn lỗ mở khi Admin cấp phạm vi hẹp ở QT-05.
select set_config('hmt.migration', 'on', false);

-- Thấy cơ sở của chứng từ với (phân hệ, hành động) không, KHÔNG tính phạm vi hẹp: chỉ Toàn hệ thống hoặc Cơ sở mình.
create or replace function app.can_see_branch_wide(p_module text, p_action text, p_branch_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case
           when v.scope = 'TOAN_HE_THONG' then true
           when v.scope = 'CO_SO' then p_branch_id is not distinct from app.current_branch_id()
           else false
         end
    from (select app.permission_scope(p_module, p_action) as scope) as v;
$$;

create or replace function app.assert_can_wide(p_module text, p_action text, p_branch_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app.can_see_branch_wide(p_module, p_action, p_branch_id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền thực hiện thao tác này ở cơ sở này.');
  end if;
end;
$$;

-- list_leads: bản mới nhất ở 20261025000043_danh_sach_em_nen.sql; chỉ đổi điều kiện lọc cơ sở (R1c).
CREATE OR REPLACE FUNCTION app.list_leads(p_filters jsonb DEFAULT '{}'::jsonb, p_sort text DEFAULT 'created_desc'::text, p_limit integer DEFAULT NULL::integer, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text := app.permission_scope('LEAD', 'XEM');
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
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách lead.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang); mặc định Postgres quét cả bảng rồi sắp xếp.
  with f as not materialized (
    select l.*
      from app.lead l
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and l.branch_id = v_my_branch))
       -- Bản "Đã gộp" ẩn khỏi danh sách mặc định nhưng vẫn tìm được bằng mã (R-CRM-22); "chỉ bản đã gộp" là bộ lọc riêng.
       and (case when v_only_merged then l.record_status = 'DA_GOP'
                 else (v_merged or l.record_status = 'DANG_DUNG'
                       or (v_q is not null and l.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or l.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or l.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or l.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or l.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or l.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or l.channel_code = any (v_channel))
       and (v_campaign is null or l.campaign_id = v_campaign)
       and (v_branch is null or l.branch_id = v_branch)
       and (v_owner is null or l.owner_id = v_owner)
       and (not v_mine or l.owner_id = auth.uid())
       and (not v_support_mine or l.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
            or ('OWNER' = any (v_mine_roles) and l.owner_id = auth.uid())
            or ('SUPPORT' = any (v_mine_roles) and l.supporter_id = auth.uid()))
       and (v_from is null or l.created_at >= v_from)
       and (v_to is null or l.created_at < v_to)
       and (v_next_from is null or l.next_appointment_at >= v_next_from)
       and (v_next_to is null or l.next_appointment_at < v_next_to)
       and (v_next_before is null or l.next_appointment_at < v_next_before)
       and (not v_no_appt or l.next_appointment_at is null)
       and (cardinality(v_appt) = 0
            or ('OVERDUE' = any (v_appt) and l.next_appointment_at < v_day_start)
            or ('TODAY' = any (v_appt) and l.next_appointment_at >= v_day_start and l.next_appointment_at < v_day_end)
            or ('UPCOMING' = any (v_appt) and l.next_appointment_at >= v_day_end)
            or ('NONE' = any (v_appt) and l.next_appointment_at is null))
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'next_appointment_asc' then f.next_appointment_at end asc nulls last,
              case when p_sort = 'name_asc' then f.parent_name end asc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'parent_name', p.parent_name, 'parent_phone', p.parent_phone,
             'student_name', (app.lead_first(p.id)).full_name, 'student_birth_year', (app.lead_first(p.id)).birth_year,
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
                      case when p_sort = 'name_asc' then p.parent_name end asc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    left join app.lead m on m.id = p.merged_into_id
    left join app.campaign c on c.id = p.campaign_id;
  return v_result;
end;
$function$;

-- lead_board: bản mới nhất ở 20261025000043_danh_sach_em_nen.sql; chỉ đổi điều kiện lọc cơ sở (R1c).
CREATE OR REPLACE FUNCTION app.lead_board(p_filters jsonb DEFAULT '{}'::jsonb, p_per_column integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text := app.permission_scope('LEAD', 'XEM');
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
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lead.');
  end if;
  with base as not materialized (
    select l.*
      from app.lead l
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and l.branch_id = v_my_branch))
       and l.record_status = 'DANG_DUNG'
       and (v_q is null or l.search_text like '%' || v_q || '%')
       and (cardinality(v_type) = 0 or l.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or l.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or l.channel_code = any (v_channel))
       and (v_campaign is null or l.campaign_id = v_campaign)
       and (v_branch is null or l.branch_id = v_branch)
       and (v_owner is null or l.owner_id = v_owner)
       and (not v_mine or l.owner_id = auth.uid())
       and (not v_support_mine or l.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
            or ('OWNER' = any (v_mine_roles) and l.owner_id = auth.uid())
            or ('SUPPORT' = any (v_mine_roles) and l.supporter_id = auth.uid()))
       and (v_from is null or l.created_at >= v_from)
       and (v_to is null or l.created_at < v_to)
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
               'id', t.id, 'code', t.code, 'parent_name', t.parent_name, 'parent_phone', t.parent_phone,
               'student_name', (app.lead_first(t.id)).full_name, 'source_type_code', t.source_type_code, 'source_code', t.source_code,
               'channel_code', t.channel_code, 'substage_code', t.substage_code, 'owner_id', t.owner_id,
               'owner_name', app.staff_display_name(t.owner_id), 'branch_code', br.code,
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
        join app.branch br on br.id = t.branch_id
    ) cards
   where s.catalog_code = 'LEAD_STAGE' and s.is_active;
  return v_result;
end;
$function$;

-- list_opportunities: bản mới nhất ở 20261025000043_danh_sach_em_nen.sql; chỉ đổi điều kiện lọc cơ sở (R1c).
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
    join app.lead l on l.id = p.lead_id
    left join app.opportunity m on m.id = p.merged_into_id
    left join app.campaign c on c.id = p.campaign_id;
  return v_result;
end;
$function$;

-- opportunity_board: bản mới nhất ở 20261025000043_danh_sach_em_nen.sql; chỉ đổi điều kiện lọc cơ sở (R1c).
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

-- list_appointments: bản mới nhất ở 20261025000043_danh_sach_em_nen.sql; chỉ đổi điều kiện lọc cơ sở (R1c).
CREATE OR REPLACE FUNCTION app.list_appointments(p_filters jsonb DEFAULT '{}'::jsonb, p_sort text DEFAULT 'time_asc'::text, p_limit integer DEFAULT NULL::integer, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text := app.permission_scope('APPOINTMENT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_activity text[] := array(select jsonb_array_elements_text(p_filters -> 'activity'));
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_test uuid := nullif(p_filters ->> 'student_test_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_kind text[] := array(select jsonb_array_elements_text(p_filters -> 'kind'));
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lịch hẹn.');
  end if;
  with f as not materialized (
    select a.*
      from app.appointment a
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and a.branch_id = v_my_branch))
       and (cardinality(v_status) = 0 or a.status = any (v_status))
       and (cardinality(v_activity) = 0 or a.activity_code = any (v_activity))
       and (v_from is null or a.scheduled_at >= v_from)
       and (v_to is null or a.scheduled_at < v_to)
       and (not v_mine or a.owner_id = auth.uid())
       and (v_lead is null or a.lead_id = v_lead)
       and (v_opp is null or a.opportunity_id = v_opp)
       and (v_test is null or a.student_test_id = v_test)
       and (v_branch is null or a.branch_id = v_branch)
       and (v_owner is null or a.owner_id = v_owner)
       -- Loại hồ sơ gắn (Đ35, dùng khi mở một nhóm của Group By): LEAD, OPPORTUNITY hoặc STUDENT_TEST.
       and (cardinality(v_kind) = 0
            or (case when a.lead_id is not null then 'LEAD' when a.opportunity_id is not null then 'OPPORTUNITY'
                     else 'STUDENT_TEST' end) = any (v_kind))
       -- Tìm theo tên, SĐT, mã của hồ sơ gắn (lead hoặc cơ hội): dò hồ sơ bằng chỉ mục trigram trước, rồi nối về lịch hẹn.
       and (v_q is null
            or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
            or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%'))
  ),
  page as (
    select * from f
     order by case when p_sort = 'time_desc' then f.scheduled_at end desc,
              f.scheduled_at asc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'activity_code', p.activity_code, 'scheduled_at', p.scheduled_at, 'title', p.title,
             'status', p.status, 'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'lead_id', p.lead_id, 'lead_code', l.code,
             'lead_label', l.parent_name || coalesce(' · ' || nullif((app.lead_first(l.id)).full_name, ''), ''),
             'opportunity_id', p.opportunity_id, 'opportunity_code', o.code,
             'student_test_id', p.student_test_id, 'student_test_code', t.code, 'is_auto_reminder', p.is_auto_reminder,
             'record_code', coalesce(l.code, o.code, t.code),
             'record_label', coalesce(l.parent_name || coalesce(' · ' || nullif((app.lead_first(l.id)).full_name, ''), ''),
                                      po.full_name || coalesce(' · ' || nullif((app.opp_first(o.id)).full_name, ''), ''),
                                      ts.full_name || ' · Phiếu kiểm tra'),
             'cancel_reason_code', p.cancel_reason_code, 'branch_code', b.code)
             order by case when p_sort = 'time_desc' then p.scheduled_at end desc, p.scheduled_at asc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    left join app.lead l on l.id = p.lead_id
    left join app.opportunity o on o.id = p.opportunity_id
    left join app.parent po on po.id = o.parent_id
    left join app.student_test t on t.id = p.student_test_id
    left join app.student ts on ts.id = t.student_id;
  return v_result;
end;
$function$;

-- list_quotations: bản mới nhất ở 20261027000057_bao_gia_loc_tinh_trang_hien_thi.sql; chỉ đổi điều kiện lọc cơ sở (R1c).
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
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and q.branch_id = v_my_branch))
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

-- list_orders: bản mới nhất ở 20261108000083_duyet_truong_co_so_r_v2_12.sql; chỉ đổi điều kiện lọc cơ sở (R1c).
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
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and o.branch_id = v_my_branch))
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or o.status_code = any (v_status))
       and (v_branch is null or o.branch_id = v_branch)
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

-- list_receipts: bản mới nhất ở 20261116000252_tc02_ham_phieu_thu_nhanh_no_dau_ky.sql; chỉ đổi điều kiện lọc cơ sở (R1c).
create or replace function app.list_receipts(p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc', p_limit integer default null,
                                             p_offset integer default 0)
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
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_order uuid := nullif(p_filters ->> 'order_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_wait_mgr boolean := coalesce((p_filters ->> 'waiting_manager')::boolean, false);
  v_wait_acc boolean := coalesce((p_filters ->> 'waiting_accounting')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu thu.');
  end if;
  with f as not materialized (
    select r.*
      from app.receipt r
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and r.branch_id = v_my_branch))
       and (cardinality(v_status) = 0 or r.status_code = any (v_status))
       and (v_branch is null or r.branch_id = v_branch)
       and (v_order is null or r.order_id = v_order)
       and (v_parent is null or r.parent_id = v_parent)
       and (not v_mine or r.created_by = auth.uid())
       and (not v_wait_mgr or (r.status_code = 'DA_GUI' and (r.assigned_approver_id = auth.uid() or r.approval_route = 'TRUONG_CS' and (select app.is_branch_manager_at(auth.uid(), 'RECEIPT', r.branch_id)))))
       and (not v_wait_acc or r.status_code = 'CHO_KE_TOAN')
       and (v_from is null or r.created_at >= v_from)
       and (v_to is null or r.created_at < v_to)
       and (v_q is null or r.search_text like '%' || v_q || '%')
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'amount_desc' then f.amount end desc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'status_code', p.status_code,
             'status', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_STATUS' and c.code = p.status_code),
             'order_id', p.order_id, 'order_code', o.code, 'is_opening_debt', p.is_opening_debt, 'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name,
             'amount', p.amount, 'payment_method_code', p.payment_method_code,
             'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = p.payment_method_code),
             'paid_on', p.paid_on, 'branch_code', b.code, 'collect_branch_code', cb.code,
             'created_at', p.created_at, 'created_by_name', app.staff_display_name(p.created_by),
             'approver_name', app.staff_display_name(p.assigned_approver_id), 'submitted_at', p.submitted_at)
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'amount_desc' then p.amount end desc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.branch cb on cb.id = p.collect_branch_id
    join app.parent par on par.id = p.parent_id
    left join app.sales_order o on o.id = p.order_id;
  return v_result;
end;
$$;

-- list_receivables: bản mới nhất ở 20261111000122_cum_thu_tien_doc_du_lieu.sql; chỉ đổi điều kiện lọc cơ sở (R1c).
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
     where o.status_code = 'DA_DUYET'
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

-- get_lead: bản mới nhất ở 20261025000043_danh_sach_em_nen.sql; kiểm cơ sở bằng bản «wide» (R1c).
CREATE OR REPLACE FUNCTION app.get_lead(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v app.lead;
begin
  select * into v from app.lead where id = p_id;
  if v.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead.');
  end if;
  -- Luật: xem lead cần quyền Lead · Xem ở cơ sở của lead.
  perform app.assert_can_wide('LEAD', 'XEM', v.branch_id);
  return (to_jsonb(v) - 'search_text') || app.prospect_compat_json(app.lead_first(v.id)) || jsonb_build_object(
    'students', app.prospect_students_json(v.id, null),
    'owner_name', app.staff_display_name(v.owner_id),
    'supporter_name', app.staff_display_name(v.supporter_id),
    'created_by_name', app.staff_display_name(v.created_by),
    'updated_by_name', app.staff_display_name(v.updated_by),
    'branch_code', (select b.code from app.branch b where b.id = v.branch_id),
    'branch_name', (select b.name from app.branch b where b.id = v.branch_id),
    'campaign_name', (select c.name from app.campaign c where c.id = v.campaign_id),
    'merged_into_code', (select m.code from app.lead m where m.id = v.merged_into_id),
    'appointments_total', (select count(*) from app.appointment a where a.lead_id = v.id),
    'appointments_open', (select count(*) from app.appointment a where a.lead_id = v.id and a.status = 'CHUA_LAM'),
    'opportunities_total', (select count(*) from app.opportunity o where o.lead_id = v.id and o.record_status = 'DANG_DUNG'));
end;
$function$;

-- get_opportunity: bản mới nhất ở 20261025000043_danh_sach_em_nen.sql; kiểm cơ sở bằng bản «wide» (R1c).
CREATE OR REPLACE FUNCTION app.get_opportunity(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v app.opportunity;
  v_tests jsonb := '[]'::jsonb;
  v_test_scope text := app.permission_scope('STUDENT_TEST', 'XEM');
begin
  select * into v from app.opportunity where id = p_id;
  if v.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
  end if;
  -- Luật: xem cơ hội cần quyền Cơ hội · Xem ở cơ sở của cơ hội.
  perform app.assert_can_wide('OPPORTUNITY', 'XEM', v.branch_id);
  -- Danh sách phiếu: chỉ khi có quyền xem phiếu ở cơ sở của cơ hội (người xem cơ hội mà không xem được phiếu thì tab rỗng).
  if v_test_scope = 'TOAN_HE_THONG' or (v_test_scope is not null and v.branch_id = app.current_branch_id()) then
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', t.id, 'code', t.code, 'status_code', t.status_code, 'status', st.name,
             'scheduled_at', t.scheduled_at, 'subject', su.name, 'mode', mo.name, 'level', le.name,
             'test_branch_code', tb.code, 'score', t.score,
             'cancel_reason', cr.name) order by t.scheduled_at desc, t.id), '[]'::jsonb)
      into v_tests
      from app.student_test t
      join app.branch tb on tb.id = t.test_branch_id
      left join app.catalog_item st on st.catalog_code = 'TEST_STATUS' and st.code = t.status_code
      left join app.catalog_item su on su.catalog_code = 'SUBJECT' and su.code = t.subject_code
      left join app.catalog_item mo on mo.catalog_code = 'TEST_MODE' and mo.code = t.mode_code
      left join app.catalog_item le on le.catalog_code = 'TEST_LEVEL' and le.code = t.level_code
      left join app.catalog_item cr on cr.catalog_code = 'TEST_CANCEL_REASON' and cr.code = t.cancel_reason_code
     where t.opportunity_id = v.id;
  end if;
  return (to_jsonb(v) - 'search_text') || app.prospect_compat_json(app.opp_first(v.id)) || jsonb_build_object(
    'students', app.prospect_students_json(null, v.id),
    'owner_name', app.staff_display_name(v.owner_id),
    'supporter_name', app.staff_display_name(v.supporter_id),
    'created_by_name', app.staff_display_name(v.created_by),
    'updated_by_name', app.staff_display_name(v.updated_by),
    'branch_code', (select b.code from app.branch b where b.id = v.branch_id),
    'branch_name', (select b.name from app.branch b where b.id = v.branch_id),
    'campaign_name', (select c.name from app.campaign c where c.id = v.campaign_id),
    'lead_code', (select l.code from app.lead l where l.id = v.lead_id),
    'merged_into_code', (select m.code from app.opportunity m where m.id = v.merged_into_id),
    'parent_code', (select p.code from app.parent p where p.id = v.parent_id),
    'parent_name', (select p.full_name from app.parent p where p.id = v.parent_id),
    'parent_phone', (select p.phone from app.parent p where p.id = v.parent_id),
    'parent_province_code', (select p.province_code from app.parent p where p.id = v.parent_id),
    'parent_ward_code', (select p.ward_code from app.parent p where p.id = v.parent_id),
    'parent_address', (select p.address from app.parent p where p.id = v.parent_id),
    'appointments_total', (select count(*) from app.appointment a where a.opportunity_id = v.id),
    'appointments_open', (select count(*) from app.appointment a where a.opportunity_id = v.id and a.status = 'CHUA_LAM'),
    'tests_total', (select count(*) from app.student_test t where t.opportunity_id = v.id),
    'sales_documents', to_jsonb(app.opportunity_sales_documents(v.id)),
    'test_state', (select to_jsonb(s) from app.opportunity_test_state(v.id) s),
    'tests', v_tests);
end;
$function$;

-- get_order: bản mới nhất ở 20261108000083_duyet_truong_co_so_r_v2_12.sql; kiểm cơ sở bằng bản «wide» (R1c).
create or replace function app.get_order(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
  v_route text;
  v_approver uuid;
  v_hint text;
  v_feature boolean;
  v_can_approve boolean;
  v_can_cancel boolean;
begin
  select * into o from app.sales_order where id = p_id;
  if o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can_wide('SALES_ORDER', 'XEM', o.branch_id);
  -- Người duyệt dự kiến của đơn Nháp: ĐÚNG đầu vào và hàm mà submit_order dùng để chốt assigned_approver_id (R-HT-06): người LẬP đơn
  -- (created_by) qua app.approval_route. Chưa có quản lý trực tiếp thì KHÔNG báo lỗi: đường duyệt THIEU, người duyệt rỗng, để giao diện
  -- hiện khung "chưa có quản lý trực tiếp". Đơn đã trình trở đi thì không trả (đã có assigned_approver_id).
  if o.status_code = 'NHAP' then
    begin
      select r.route, r.approver_id into v_route, v_approver from app.approval_route(o.created_by, o.branch_id, 'DON') r;
    -- Chủ ý bắt mọi lỗi: tra người duyệt dự kiến chỉ để hiển thị, KHÔNG được chặn việc mở màn đơn. Chưa có quản lý thì THIEU; lỗi khác thì để
    -- trống (route null); luật chặn thật vẫn nằm ở submit_order lúc Trình.
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      if v_hint = 'HMT_KHONG_CO_QUAN_LY' then
        v_route := 'THIEU';
        v_approver := null;
      else
        v_route := null;
        v_approver := null;
      end if;
    end;
  end if;
  -- Bốn cờ cho giao diện (Đ283): tính bằng ĐÚNG các hàm không báo lỗi mà hàm ghi dùng (can_see_branch của assert_can, feature_enabled của
  -- require_feature, can_approve_as_manager, order_has_receipt), nên giao diện không tự đoán quyền. Cờ chỉ xét QUYỀN và TRẠNG THÁI, không xét
  -- dữ liệu: thiếu điều khoản, em thiếu năm sinh, chưa có quản lý trực tiếp... vẫn do hàm ghi báo lúc bấm (cờ đúng, lỗi cấu hình khi Trình).
  v_feature := app.feature_enabled('BAN_HANG', o.branch_id);
  -- Duyệt và Từ chối (approve_order, reject_order kiểm y hệt): đơn Đã trình, quyền Duyệt, đúng người duyệt đã chốt (Admin thay khi vắng).
  v_can_approve := coalesce(o.status_code = 'DA_TRINH' and v_feature
                            and app.can_see_branch_wide('SALES_ORDER', 'DUYET', o.branch_id)
                            and app.can_approve_as_manager(o.created_by, 'DON', o.assigned_approver_id, o.approval_route, o.branch_id), false);
  -- Huỷ (cancel_order, R-TIEN-38): đơn Nháp chỉ người lập; đơn Đã trình, Đã duyệt do người duyệt đã chốt; chỉ khi chưa có phiếu thu.
  v_can_cancel := coalesce(o.status_code <> 'HUY' and v_feature
                  and app.can_see_branch_wide('SALES_ORDER', 'HUY', o.branch_id)
                  and case when o.status_code = 'NHAP' then o.created_by is not distinct from auth.uid()
                           else app.can_approve_as_manager(o.created_by, 'DON', o.assigned_approver_id, o.approval_route, o.branch_id) end
                  and not app.order_has_receipt(o.id), false);
  return (to_jsonb(o) - 'search_text') || jsonb_build_object(
    -- Trình (submit_order): đơn Nháp, quyền Sửa ở cơ sở, Bán hàng bật.
    'can_submit', coalesce(o.status_code = 'NHAP' and v_feature and app.can_see_branch_wide('SALES_ORDER', 'SUA', o.branch_id), false),
    'can_cancel', v_can_cancel,
    'can_approve', v_can_approve,
    'can_reject', v_can_approve,
    'status', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_STATUS' and c.code = o.status_code),
    'branch_code', (select b.code from app.branch b where b.id = o.branch_id),
    'opportunity_code', (select x.code from app.opportunity x where x.id = o.opportunity_id),
    'quotation_code', (select q.code from app.quotation q where q.id = o.quotation_id),
    'parent_code', (select p.code from app.parent p where p.id = o.parent_id),
    'parent_name', (select p.full_name from app.parent p where p.id = o.parent_id),
    'parent_phone', (select p.phone from app.parent p where p.id = o.parent_id),
    'payment_term_name', (select t.name from app.payment_term t where t.id = o.payment_term_id),
    -- Tổng niêm yết và tổng chiết khấu: DB cộng từ các dòng đã đóng băng, không tính lại; dòng quà tặng không tính (R-TIEN-30).
    'gross_total', (select coalesce(sum(l3.gross_amount), 0)::bigint from app.sales_order_line l3
                     where l3.order_id = o.id and l3.line_kind = 'ENROL'),
    'discount_total', (select coalesce(sum(l3.discount_amount), 0)::bigint from app.sales_order_line l3
                        where l3.order_id = o.id and l3.line_kind = 'ENROL'),
    -- Chỉ khi đơn Nháp: QUAN_LY, TU_DUYET hoặc THIEU; người duyệt dự kiến; và người đó có quyền Duyệt đơn ở cơ sở này không (Đ205).
    'expected_route', v_route,
    'expected_approver_id', v_approver,
    'expected_approver_name', app.staff_display_name(v_approver),
    'expected_approver_can_approve', case when v_approver is null then null
                                          else app.user_can_at_branch(v_approver, 'SALES_ORDER', 'DUYET', o.branch_id) end,
    -- Q-63, Q-62: MỘT lý do chặn phía người duyệt cho giao diện (dải thông báo cạnh nút trình dùng lại, không đổi DB nữa); chỉ khi đơn Nháp.
    -- KHONG_CO_QUAN_LY, NGUOI_DUYET_BI_KHOA (người duyệt dự kiến đang bị khoá), NGUOI_DUYET_THIEU_QUYEN (không bị khoá nhưng thiếu quyền Duyệt
    -- ở cơ sở), null (không chặn). Trùng mã lỗi của submit_order.
    'expected_block', case when o.status_code <> 'NHAP' then null
                           when v_route = 'THIEU' then 'KHONG_CO_QUAN_LY'
                           when v_approver is null then null
                           when exists (select from app.user_account a where a.id = v_approver and a.is_locked) then 'NGUOI_DUYET_BI_KHOA'
                           when not app.user_can_at_branch(v_approver, 'SALES_ORDER', 'DUYET', o.branch_id) then 'NGUOI_DUYET_THIEU_QUYEN'
                           else null end,
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
               'reason_code', e.reason_code, 'note', e.note, 'on_behalf', e.on_behalf, 'created_at', e.created_at, 'total_amount', e.total_amount,
               'actor_name', app.staff_display_name(e.created_by)) order by e.seq)
        from app.sales_order_event e where e.order_id = o.id), '[]'::jsonb));
end;
$$;

-- get_receipt: bản mới nhất ở 20261116000252_tc02_ham_phieu_thu_nhanh_no_dau_ky.sql; kiểm cơ sở bằng bản «wide» (R1c).
create or replace function app.get_receipt(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_o app.sales_order;
  v_actions text[] := array[]::text[];
  v_me uuid := auth.uid();
begin
  select * into r from app.receipt where id = p_id;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can_wide('RECEIPT', 'XEM', r.branch_id);
  if r.order_id is not null then
    select * into v_o from app.sales_order where id = r.order_id;
  end if;
  if r.status_code = 'NHAP' and r.created_by is not distinct from v_me and app.can_see_branch_wide('RECEIPT', 'TAO', r.branch_id) then
    v_actions := v_actions || array['sua', 'gui'];
  end if;
  if r.status_code = 'DA_GUI' and app.can_see_branch_wide('RECEIPT', 'DUYET', r.branch_id)
     and app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id, r.approval_route, r.branch_id) then
    v_actions := v_actions || array['duyet_quan_ly', 'tu_choi'];
  end if;
  if r.status_code = 'CHO_KE_TOAN' and app.can_see_branch_wide('ACCOUNTING', 'DUYET', r.branch_id) then
    v_actions := v_actions || array['duyet_ke_toan', 'tu_choi'];
  end if;
  if r.status_code in ('NHAP', 'DA_GUI', 'CHO_KE_TOAN')
     and (r.created_by is not distinct from v_me and app.can_see_branch_wide('RECEIPT', 'TAO', r.branch_id) or app.can_see_branch_wide('RECEIPT', 'HUY', r.branch_id)) then
    v_actions := v_actions || array['huy'];
  end if;
  return jsonb_build_object(
    'id', r.id, 'code', r.code, 'status_code', r.status_code,
    'status', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_STATUS' and c.code = r.status_code),
    'is_opening_debt', r.is_opening_debt,
    'opening_student', (select jsonb_build_object('id', s.id, 'code', s.code, 'name', s.full_name) from app.student s where s.id = r.opening_debt_student_id),
    'order', case when r.order_id is null then null else jsonb_build_object('id', v_o.id, 'code', v_o.code, 'total_amount', v_o.total_amount, 'status_code', v_o.status_code) end,
    'parent', (select jsonb_build_object('id', p.id, 'code', p.code, 'name', p.full_name, 'phone', p.phone) from app.parent p where p.id = r.parent_id),
    'amount', r.amount, 'payment_method_code', r.payment_method_code,
    'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = r.payment_method_code),
    'txn_ref', r.txn_ref, 'paid_on', r.paid_on, 'note', r.note, 'target_line_id', r.target_line_id,
    'branch_code', (select code from app.branch where id = r.branch_id), 'collect_branch_id', r.collect_branch_id,
    'collect_branch_code', (select code from app.branch where id = r.collect_branch_id),
    'receiver_id', r.receiver_id, 'receiver_name', app.staff_display_name(r.receiver_id),
    'created_at', r.created_at, 'created_by', r.created_by, 'created_by_name', app.staff_display_name(r.created_by),
    'approver_name', app.staff_display_name(r.assigned_approver_id), 'approval_route', r.approval_route,
    'submitted_at', r.submitted_at, 'manager_approved_at', r.manager_approved_at, 'accountant_approved_at', r.accountant_approved_at,
    'cancel_reason', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_CANCEL_REASON' and c.code = r.cancel_reason_code),
    'cancel_note', r.cancel_note, 'cancelled_at', r.cancelled_at,
    'payment', case when r.order_id is null then jsonb_build_object('opening_debt_remaining', app.opening_debt_remaining(r.parent_id, r.id)) else app.order_payment_summary(r.order_id) end,
    'actions', to_jsonb(v_actions),
    'events', coalesce((select jsonb_agg(jsonb_build_object('event_code', e.event_code, 'from_status', e.from_status, 'to_status', e.to_status,
                                                            'note', e.note, 'at', e.created_at, 'by_name', app.staff_display_name(e.created_by))
                                         order by e.seq) from app.receipt_event e where e.receipt_id = r.id), '[]'::jsonb),
    'money_in', (select jsonb_build_object('code', m.code, 'amount', m.amount,
                   'allocations', (select coalesce(jsonb_agg(jsonb_build_object('line_no', l.line_no, 'package_name', l.package_name, 'amount', a.amount)
                                                             order by l.line_no), '[]'::jsonb)
                                     from app.money_in_allocation a join app.sales_order_line l on l.id = a.order_line_id where a.money_in_id = m.id))
                   from app.money_in m where m.receipt_id = r.id));
end;
$$;

-- can_see_note_target: bản mới nhất ở 20261118000502_ghi_chu_hoc_sinh_giao_vien_duoc_phan_cong.sql; nhánh BRANCH, ROOM đòi nhân viên (R3).
CREATE OR REPLACE FUNCTION app.can_see_note_target(p_entity_type text, p_entity_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_branch_id uuid;
  v_test app.student_test;
begin
  if not app.current_user_ready() then
    return false;
  end if;
  if not app.mfa_satisfied() then
    return false;
  end if;
  if app.has_permission('ADMIN', 'XEM') then
    return true;
  end if;
  if p_entity_type = 'USER_ACCOUNT' then
    select branch_id into v_branch_id from app.user_account where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('ACCOUNT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'LEAD' then
    select branch_id into v_branch_id from app.lead where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('LEAD', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'OPPORTUNITY' then
    select branch_id into v_branch_id from app.opportunity where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('OPPORTUNITY', 'XEM', v_branch_id);
  end if;
  -- Luật: phiếu theo quyền Kiểm tra đầu vào · Xem và phạm vi của phiếu (cơ sở, hoặc được phân công).
  if p_entity_type = 'STUDENT_TEST' then
    select * into v_test from app.student_test where id = p_entity_id;
    return v_test.id is not null and app.test_scope_ok('XEM', v_test);
  end if;
  -- Luật: phụ huynh, học sinh theo quyền Xem của phân hệ: toàn hệ thống, hoặc đúng cơ sở tiếp nhận.
  -- Luật (27/10): báo giá theo quyền Báo giá · Xem ở cơ sở của báo giá (BH-02, Ghi chú và hoạt động).
  if p_entity_type = 'QUOTATION' then
    select branch_id into v_branch_id from app.quotation where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('QUOTATION', 'XEM', v_branch_id);
  end if;
  -- Luật (28/10): đơn hàng theo quyền Đơn hàng · Xem ở cơ sở của đơn, giống hệt báo giá (BH-05, Ghi chú và hoạt động).
  if p_entity_type = 'SALES_ORDER' then
    select branch_id into v_branch_id from app.sales_order where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('SALES_ORDER', 'XEM', v_branch_id);
  end if;
  -- Luật (07/11, Q-52): phiếu thu theo quyền Phiếu thu · Xem ở cơ sở của phiếu (cơ sở của đơn), giống hệt đơn hàng; Kế toán (toàn hệ thống) thấy mọi cơ sở.
  if p_entity_type = 'RECEIPT' then
    select branch_id into v_branch_id from app.receipt where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('RECEIPT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'PARENT' then
    select branch_id into v_branch_id from app.parent where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('PARENT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'STUDENT' then
    select branch_id into v_branch_id from app.student where id = p_entity_id;
    -- Luật R-GV-13 (E10, Soát G1): phạm vi DUOC_PHAN_CONG (giáo viên, trợ giảng) chỉ thấy ghi chú của em trong lớp mình, không phải cả cơ sở.
    if (select app.permission_scope('STUDENT', 'XEM')) = 'DUOC_PHAN_CONG' then
      return app.student_assigned_to_me(p_entity_id);
    end if;
    return v_branch_id is not null and app.can_see_branch('STUDENT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'BRANCH' then
    v_branch_id := p_entity_id;
  elsif p_entity_type = 'ROOM' then
    select branch_id into v_branch_id from app.room where id = p_entity_id;
  else
    return false;
  end if;
  -- R3 (Soát S16): ghi chú gắn Phòng, Cơ sở chỉ dành cho nhân viên (Học sinh, Phụ huynh không đọc).
  return app.is_staff()
    and (v_branch_id is not distinct from app.current_branch_id()
         or exists (select from app.role r where r.code = any (app.current_roles()) and r.default_scope = 'TOAN_HE_THONG'));
end;
$function$;

-- R1d: chính sách đọc phụ huynh, học sinh: phạm vi hẹp không còn đọc theo cơ sở.
-- parent_read: phụ huynh dùng chung toàn hệ thống cho người có quyền xem (migration 64, chống trùng): GIỮ nguyên điều đó với Toàn hệ thống và Cơ sở mình; chỉ phạm vi hẹp (Của tôi, Chính mình…) không còn đọc tất cả.
alter policy parent_read on app.parent
  using ((select app.permission_scope('PARENT', 'XEM')) in ('TOAN_HE_THONG', 'CO_SO'));
alter policy student_read on app.student
  using (((select app.permission_scope('STUDENT', 'XEM')) = 'TOAN_HE_THONG')
         or ((select app.permission_scope('STUDENT', 'XEM')) = 'DUOC_PHAN_CONG' and app.student_assigned_to_me(id))
         or ((select app.permission_scope('STUDENT', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id())));

select set_config('hmt.migration', '', false);

revoke execute on function app.can_see_branch_wide(text, text, uuid), app.assert_can_wide(text, text, uuid) from public, anon;
grant execute on function app.can_see_branch_wide(text, text, uuid), app.assert_can_wide(text, text, uuid) to authenticated;
