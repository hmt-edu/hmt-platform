-- P3c-1b: lọc nhanh nhiều lựa chọn cùng nhóm (docs/spec/04 R-CRM-07: cùng nhóm HOẶC, khác nhóm VÀ).
-- Bản 033 chỉ có các khoảng lịch hẹn nối bằng VÀ, nên không chọn được "Quá hạn" cùng "Hôm nay". Thêm hai bộ lọc dạng danh sách:
--   appointment[]: OVERDUE (trước đầu ngày hôm nay), TODAY, UPCOMING (từ ngày mai), NONE (chưa có lịch hẹn); mốc theo giờ Việt Nam.
--   mine_roles[]: OWNER (tôi phụ trách), SUPPORT (tôi hỗ trợ).
-- Áp cho list_leads, lead_board, lead_group_counts, export_leads (cùng một khuôn bộ lọc). Các bộ lọc cũ vẫn dùng được.
-- Ở lead_board, appointment lọc tổng và thẻ của cột như next_*, không đổi số đếm thanh màu; mine_roles lọc cả thanh màu.

-- ---------------------------------------------------------------------------
-- Danh sách lead phân trang ở máy chủ (TS-01). Trả {total, rows}; chỉ các cột màn hiện. security definer có chủ ý (LIKE không
-- "leakproof" dưới RLS, như P3b1): phạm vi từ app.permission_scope('LEAD', 'XEM').
-- Bộ lọc (p_filters): q (tìm không dấu, mã, SĐT), stage[], substage[], source_type[], source[], channel[], campaign_id, branch_id,
--   owner_id, mine (tôi phụ trách), supporter_mine (tôi hỗ trợ), created_from, created_to, next_from, next_to (khoảng lịch hẹn kế
--   tiếp), next_before (quá hạn: lịch kế tiếp trước mốc này), no_appointment (chưa có lịch hẹn), include_merged (hiện bản "Đã gộp"),
--   only_merged (chỉ bản "Đã gộp"), appointment[] (OVERDUE, TODAY, UPCOMING, NONE: cùng nhóm HOẶC, mốc hôm nay theo giờ Việt Nam
--   tính trong DB), mine_roles[] (OWNER, SUPPORT: HOẶC).
-- Sắp xếp: created_desc (mặc định), created_asc, next_appointment_asc, name_asc.
-- Thêm so với P3b1: bộ lọc channel, campaign_id, next_from, next_to, next_before, no_appointment, only_merged; cột supporter_name,
-- campaign_name, assigned_at, student_birth_year.
-- ---------------------------------------------------------------------------
create or replace function app.list_leads(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc',
  p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
     where (v_scope = 'TOAN_HE_THONG' or l.branch_id = v_my_branch)
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
             'student_name', p.student_name, 'student_birth_year', p.student_birth_year,
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
$$;
-- ---------------------------------------------------------------------------
-- Kanban Lead (TS-01b K2): một lần gọi trả các cột giai đoạn lead (C1 đến C4): tổng của cột, N thẻ mới nhất (N theo tham số
-- kanban_cards_per_column, tối đa list_page_size_max) và số đếm cho thanh màu đầu cột TÍNH TRÊN CẢ CỘT (không chỉ N thẻ):
-- ok = lịch hẹn kế tiếp từ ngày mai trở đi, today = hôm nay, overdue = đã quá hạn (trước đầu ngày hôm nay), none = chưa có lịch.
-- Ngày "hôm nay" tính theo giờ Việt Nam (Asia/Ho_Chi_Minh), không theo múi giờ máy khách. Không hiện bản "Đã gộp".
-- Bộ lọc như list_leads (bỏ stage, substage, include_merged, only_merged). Các bộ lọc next_* chỉ lọc tổng và thẻ của cột (bấm một khúc
-- màu thì lọc cột), không đổi số đếm thanh màu.
-- ---------------------------------------------------------------------------
create or replace function app.lead_board(p_filters jsonb default '{}'::jsonb, p_per_column integer default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
     where (v_scope = 'TOAN_HE_THONG' or l.branch_id = v_my_branch)
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
               'student_name', t.student_name, 'source_type_code', t.source_type_code, 'source_code', t.source_code,
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
$$;
-- ---------------------------------------------------------------------------
-- Đếm nhóm cho Group By của danh sách Lead (một đến hai cấp, không tải cả bảng). p_fields: stage, substage, source_type, source,
-- owner, branch (tối đa hai, khác nhau). Bộ lọc như list_leads. Kết quả: {total, groups: [{k1, l1, k2, l2, count}]} (k2, l2 chỉ có khi
-- nhóm hai cấp); mở một nhóm thì giao diện gọi list_leads với bộ lọc của nhóm đó. Chỗ rỗng là "Chưa có".
-- ---------------------------------------------------------------------------
create or replace function app.lead_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách lead.');
  end if;
  -- Luật: chỉ nhóm theo các trường cho phép, tối đa hai cấp, hai cấp khác nhau (Group By K1_nhom).
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('stage', 'substage', 'source_type', 'source', 'owner', 'branch'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (giai đoạn, nhóm con, loại nguồn, nguồn, người phụ trách, cơ sở).');
  end if;
  with f as not materialized (
    select l.*
      from app.lead l
     where (v_scope = 'TOAN_HE_THONG' or l.branch_id = v_my_branch)
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
             'k1', coalesce(g.k1, ''), 'l1', app.lead_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.lead_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;
-- ---------------------------------------------------------------------------
-- Xuất danh sách lead ra file (CHUNG-18, R-CRM-29). Ai gọi: người có quyền Lead · Xuất theo ma trận quyền (hiện: Trưởng cơ sở trong cơ sở mình, Admin). R-CRM-29 chỉ nói phụ huynh và học sinh; xuất lead dựa trên ma trận quyền.
-- Gom việc kiểm quyền, ghi nhật ký xuất (app.log_export) và lấy dữ liệu trong MỘT giao dịch: ghi nhật ký không được thì không có
-- dữ liệu. Chỉ lấy tối đa export_max_rows dòng (mới nhất trước); quá thì truncated = true.
-- Bộ lọc (p_filters): q (tìm không dấu, mã, SĐT), stage[], substage[], source_type[], source[], channel[], campaign_id, branch_id,
--   owner_id, mine (tôi phụ trách), supporter_mine (tôi hỗ trợ), created_from, created_to, next_from, next_to (khoảng lịch hẹn kế
--   tiếp), next_before (quá hạn: lịch kế tiếp trước mốc này), no_appointment (chưa có lịch hẹn), include_merged (hiện bản "Đã gộp"),
--   only_merged (chỉ bản "Đã gộp"), appointment[] (OVERDUE, TODAY, UPCOMING, NONE: cùng nhóm HOẶC, mốc hôm nay theo giờ Việt Nam
--   tính trong DB), mine_roles[] (OWNER, SUPPORT: HOẶC).
-- Kết quả: {total, exported, truncated, rows}; rows có tên danh mục (không phải mã) cho người đọc file.
-- ---------------------------------------------------------------------------
create or replace function app.export_leads(p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
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
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Phạm vi dòng lấy từ quyền Xuất (không phải Xem): vai trò Xem toàn hệ thống nhưng Xuất trong cơ sở chỉ xuất được cơ sở mình.
  v_scope := app.permission_scope('LEAD', 'XUAT');
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất danh sách lead.');
  end if;
  select count(*) into v_total
    from app.lead l
     where (v_scope = 'TOAN_HE_THONG' or l.branch_id = v_my_branch)
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
;
  with f as (
    select l.*
      from app.lead l
     where (v_scope = 'TOAN_HE_THONG' or l.branch_id = v_my_branch)
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
     order by l.created_at desc, l.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', f.code, 'parent_name', f.parent_name, 'parent_phone', f.parent_phone,
           'student_name', f.student_name, 'student_birth_year', f.student_birth_year, 'school', f.school, 'need', f.need,
           'source_type', st.name, 'source', so.name, 'channel', ch.name, 'campaign', ca.name,
           'stage', sg.name, 'substage', ss.name,
           'owner', app.staff_display_name(f.owner_id), 'supporter', app.staff_display_name(f.supporter_id),
           'branch', b.code, 'next_appointment_at', f.next_appointment_at, 'created_at', f.created_at,
           'record_status', f.record_status) order by f.created_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id
    left join app.catalog_item st on st.catalog_code = 'SOURCE_TYPE' and st.code = f.source_type_code
    left join app.catalog_item so on so.catalog_code = 'SOURCE' and so.code = f.source_code
    left join app.catalog_item ch on ch.catalog_code = 'SOURCE_CHANNEL' and ch.code = f.channel_code
    left join app.campaign ca on ca.id = f.campaign_id
    left join app.catalog_item sg on sg.catalog_code = 'LEAD_STAGE' and sg.code = f.stage_code
    left join app.catalog_item ss on ss.catalog_code = 'LEAD_SUBSTAGE' and ss.code = f.substage_code;
  -- Ghi nhật ký xuất TRƯỚC khi trả dữ liệu (cùng giao dịch): lỗi ở đây thì không có file.
  perform app.log_export('LEAD', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$$;
