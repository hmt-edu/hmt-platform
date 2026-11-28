-- D-27-12 · B4 (anh Trường chốt 26/11/2026): mã lần nhập ghi vào lead khi nhập từ file; lọc «Lần nhập» để huỷ cả lô (R-CRM-45).
-- Một lần nhập = một dòng app.lead_import_log đã có (không đặt thêm loại mã mới). Lead tạo tay hoặc nhập trước migration này để trống.
-- Huỷ cả lô dùng đúng đường huỷ hàng loạt của mig 704 (giữ mọi luật và trần mỗi lần).

select set_config('hmt.migration', 'on', false);

alter table app.lead add column import_batch_id uuid references app.lead_import_log (id);
comment on column app.lead.import_batch_id is 'Lần nhập từ file đã tạo lead này (app.lead_import_log). Trống: không phải lead nhập lô.';
-- Chỉ mục: khoá ngoại và lọc «Lần nhập» (chỉ các lead nhập lô).
create index lead_import_batch_idx on app.lead (import_batch_id, created_at desc) where import_batch_id is not null;

-- app.import_leads: chép nguyên định nghĩa của migration 032, chỉ thêm ghi mã lần nhập vào lead.
create or replace function app.import_leads(
  p_rows jsonb, p_commit boolean default false, p_defaults jsonb default '{}'::jsonb, p_file_name text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max integer := app.get_setting_int('lead_import_max_rows');
  v_branch uuid := coalesce(nullif(p_defaults ->> 'branch_id', '')::uuid, app.current_branch_id());
  v_defaults jsonb;
  v_total integer;
  v_result jsonb := '[]'::jsonb;
  v_ok integer := 0;
  v_dup integer := 0;
  v_err integer := 0;
  v_i integer := 0;
  v_rown integer;
  v_row jsonb;
  v_hint text;
  v_msg text;
  v_created jsonb;
  v_exist text;
  v_detail text;
  v_final jsonb;
  v_batch uuid := gen_random_uuid();
  v_ids uuid[] := '{}';
begin
  if jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows) = 0 then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chưa có dòng nào để nhập.');
  end if;
  -- Luật: quyền tạo lead ở cơ sở nhập (CSKH cũng nhập được).
  perform app.assert_can('LEAD', 'TAO', v_branch);
  v_total := jsonb_array_length(p_rows);
  -- Luật: tối đa lead_import_max_rows hàng mỗi lần, quá thì chặn cả lô.
  if v_total > v_max then
    perform app.raise_error('HMT_QUA_NHIEU_DONG', format('File có %s dòng, tối đa %s dòng mỗi lần nhập.', v_total, v_max));
  end if;
  v_defaults := p_defaults || jsonb_build_object('branch_id', v_branch,
                                                 'owner_id', coalesce(nullif(p_defaults ->> 'owner_id', ''), auth.uid()::text));

  -- Xem trước và nhập dùng chung một đường mã: xem trước chạy hết rồi hoàn tác (ném lỗi mang kết quả ra ngoài).
  begin
    for v_row in select value from jsonb_array_elements(p_rows) loop
      v_i := v_i + 1;
      -- Số dòng báo lỗi: số dòng trong file nếu có, không thì thứ tự trong lô.
      v_rown := case when (v_row ->> 'row') ~ '^[0-9]{1,9}$' then (v_row ->> 'row')::integer else v_i end;
      begin
        v_created := app.import_one_lead(v_row, v_defaults);
        v_ok := v_ok + 1;
        v_ids := v_ids || (v_created ->> 'id')::uuid;
        v_result := v_result || jsonb_build_object('row', v_rown, 'status', 'HOP_LE',
                                                   'code', v_created ->> 'code', 'message', null);
      exception when others then
        get stacked diagnostics v_hint = pg_exception_hint, v_msg = message_text;
        if v_hint = 'HMT_SDT_TRUNG' then
          -- Dòng trùng SĐT: nêu mã bản có sẵn (lead hoặc phụ huynh, kể cả dòng trước trong file).
          select d.code into v_exist from app.find_duplicate_contacts(v_row ->> 'parent_phone') d order by d.kind, d.code limit 1;
          v_dup := v_dup + 1;
          v_result := v_result || jsonb_build_object('row', v_rown, 'status', 'TRUNG',
                                                     'code', v_exist, 'message', format('Trùng với %s', coalesce(v_exist, 'hồ sơ có sẵn')));
        else
          v_err := v_err + 1;
          v_result := v_result || jsonb_build_object('row', v_rown, 'status', 'LOI',
                                                     'code', null, 'message', v_msg);
        end if;
      end;
    end loop;
    v_final := jsonb_build_object('mode', case when p_commit then 'NHAP' else 'XEM_TRUOC' end, 'total', v_total,
                                  'imported', v_ok, 'duplicates', v_dup, 'errors', v_err, 'rows', v_result);
    if not p_commit then
      raise exception using errcode = 'HMT01', message = 'Xem trước nhập lô (hoàn tác)', detail = v_final::text;
    end if;
  exception when sqlstate 'HMT01' then
    get stacked diagnostics v_detail = pg_exception_detail;
    v_final := v_detail::jsonb;
  end;

  -- Nhập thật: ghi nhật ký một dòng cho cả lô (cùng giao dịch với các lead đã nhập).
  if p_commit then
    insert into app.lead_import_log (id, importer_id, branch_id, file_name, rows_total, imported_count, duplicate_count, error_count)
    values (v_batch, auth.uid(), v_branch, nullif(btrim(coalesce(p_file_name, '')), ''), v_total, v_ok, v_dup, v_err);
    -- Luật: lead vừa tạo ghi lại mã lần nhập (B4), cùng giao dịch.
    update app.lead set import_batch_id = v_batch where id = any (v_ids);
  end if;
  return v_final;
end;
$$;

-- app.list_lead_import_batches: các lần nhập gần đây còn lead để chọn ở ô lọc «Lần nhập».
-- Ai gọi: người có Lead · Xem. Ra: [{id, created_at, file_name, importer_name, branch_code, imported_count, active_count}], mới nhất trước,
-- tối đa list_page_size_max lần. Phạm vi: toàn hệ thống thấy mọi cơ sở; cơ sở thấy cơ sở mình; phạm vi hẹp thấy lần mình nhập.
create function app.list_lead_import_batches()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('LEAD', 'XEM');
  v_branch uuid := app.current_branch_id();
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách lead.');
  end if;
  with b as (
    select g.*
      from app.lead_import_log g
     where g.imported_count > 0
       and (v_scope = 'TOAN_HE_THONG'
            or (v_scope = 'CO_SO' and g.branch_id = v_branch)
            or g.importer_id = auth.uid())
       -- Lần nhập trước khi có cột mã lần nhập không gắn lead nào: không đưa vào ô chọn.
       and exists (select 1 from app.lead l where l.import_batch_id = g.id)
     order by g.created_at desc
     limit app.get_setting_int('list_page_size_max')
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', b.id, 'created_at', b.created_at, 'file_name', b.file_name,
           'importer_name', app.staff_display_name(b.importer_id), 'branch_code', br.code,
           'imported_count', b.imported_count,
           'active_count', (select count(*) from app.lead l where l.import_batch_id = b.id and l.record_status = 'DANG_DUNG'))
           order by b.created_at desc), '[]'::jsonb)
    into v_result
    from b join app.branch br on br.id = b.branch_id;
  return v_result;
end;
$$;
revoke execute on function app.list_lead_import_batches() from public, anon;
grant execute on function app.list_lead_import_batches() to authenticated;

-- Danh sách, Kanban, đếm nhóm, xuất file: thêm bộ lọc import_batch_id. Chép nguyên định nghĩa đang chạy, chỉ thêm biến và điều kiện đó.

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
  v_batch uuid := nullif(p_filters ->> 'import_batch_id', '')::uuid;
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
  v_trash boolean := coalesce((p_filters ->> 'trash')::boolean, false);
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
       and (case when v_trash then l.record_status in ('DA_GOP', 'DA_HUY')
                 when v_only_merged then l.record_status = 'DA_GOP'
                 else (l.record_status = 'DANG_DUNG' or (v_merged and l.record_status = 'DA_GOP')
                       or (v_q is not null and l.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or l.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or l.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or l.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or l.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or l.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or l.channel_code = any (v_channel))
       and (v_campaign is null or l.campaign_id = v_campaign)
       and (v_batch is null or l.import_batch_id = v_batch)
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
             'record_status', p.record_status, 'merged_into_code', m.code, 'cancel_reason', p.cancel_reason)
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
$function$
;

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
  v_batch uuid := nullif(p_filters ->> 'import_batch_id', '')::uuid;
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
       and (v_batch is null or l.import_batch_id = v_batch)
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

CREATE OR REPLACE FUNCTION app.lead_group_counts(p_filters jsonb DEFAULT '{}'::jsonb, p_fields text[] DEFAULT ARRAY[]::text[])
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
  v_batch uuid := nullif(p_filters ->> 'import_batch_id', '')::uuid;
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
  v_trash boolean := coalesce((p_filters ->> 'trash')::boolean, false);
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
       and (case when v_trash then l.record_status in ('DA_GOP', 'DA_HUY')
                 when v_only_merged then l.record_status = 'DA_GOP'
                 else (l.record_status = 'DANG_DUNG' or (v_merged and l.record_status = 'DA_GOP')
                       or (v_q is not null and l.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or l.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or l.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or l.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or l.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or l.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or l.channel_code = any (v_channel))
       and (v_campaign is null or l.campaign_id = v_campaign)
       and (v_batch is null or l.import_batch_id = v_batch)
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
$function$
;

CREATE OR REPLACE FUNCTION app.export_leads(p_filters jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
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
  v_batch uuid := nullif(p_filters ->> 'import_batch_id', '')::uuid;
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
  v_trash boolean := coalesce((p_filters ->> 'trash')::boolean, false);
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
       and (case when v_trash then l.record_status in ('DA_GOP', 'DA_HUY')
                 when v_only_merged then l.record_status = 'DA_GOP'
                 else (l.record_status = 'DANG_DUNG' or (v_merged and l.record_status = 'DA_GOP')
                       or (v_q is not null and l.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or l.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or l.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or l.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or l.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or l.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or l.channel_code = any (v_channel))
       and (v_campaign is null or l.campaign_id = v_campaign)
       and (v_batch is null or l.import_batch_id = v_batch)
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
       and (case when v_trash then l.record_status in ('DA_GOP', 'DA_HUY')
                 when v_only_merged then l.record_status = 'DA_GOP'
                 else (l.record_status = 'DANG_DUNG' or (v_merged and l.record_status = 'DA_GOP')
                       or (v_q is not null and l.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or l.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or l.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or l.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or l.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or l.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or l.channel_code = any (v_channel))
       and (v_campaign is null or l.campaign_id = v_campaign)
       and (v_batch is null or l.import_batch_id = v_batch)
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
           'student_name', (app.lead_first(f.id)).full_name, 'student_birth_year', (app.lead_first(f.id)).birth_year, 'school', (app.lead_first(f.id)).school, 'need', f.need,
           'source_type', st.name, 'source', so.name, 'channel', ch.name, 'campaign', ca.name,
           'stage', sg.name, 'substage', ss.name,
           'owner', app.staff_display_name(f.owner_id), 'supporter', app.staff_display_name(f.supporter_id),
           'branch', b.code, 'next_appointment_at', f.next_appointment_at, 'created_at', f.created_at,
           'record_status', f.record_status, 'cancel_reason', f.cancel_reason) order by f.created_at desc, f.id), '[]'::jsonb),
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
$function$
;

-- Kèm sửa app.restore_cancelled_leads (soát #852): khôi phục không được tạo hai bản Đang dùng cùng số điện thoại (R-CRM-46).

-- app.restore_cancelled_leads: khôi phục lead Đã huỷ về Đang dùng (một hoặc nhiều).
-- Ai gọi: chỉ Admin (quyền ADMIN·TAO). Vào: danh sách id. Ra: {done, skipped: [{id, code, reason}]}.
-- Luật R-CRM-46: chỉ lead Đã huỷ; số điện thoại đang có lead hoặc cơ hội Đang dùng thì bỏ qua (app.assert_no_phone_duplicate);
-- lý do huỷ cũ được ghi lại vào ghi chú trước khi xoá khỏi hồ sơ.
create or replace function app.restore_cancelled_leads(p_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ids uuid[] := array(select distinct x from unnest(p_ids) as x where x is not null);
  v_id uuid;
  v_lead app.lead;
  v_done integer := 0;
  v_skipped jsonb := '[]'::jsonb;
  v_hint text;
  v_message text;
begin
  -- Luật: chỉ Admin.
  if not app.has_permission('ADMIN', 'TAO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ Admin được khôi phục lead đã huỷ.');
  end if;
  if cardinality(v_ids) = 0 then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ít nhất một lead để khôi phục.');
  end if;
  foreach v_id in array v_ids loop
    select * into v_lead from app.lead where id = v_id for update;
    -- Luật: chỉ lead Đã huỷ mới khôi phục được.
    if v_lead.id is null or v_lead.record_status <> 'DA_HUY' then
      v_skipped := v_skipped || app.lead_skip_row(v_id, 'Lead không ở trạng thái Đã huỷ.');
      continue;
    end if;
    -- Luật: lead đã huỷ không tính trùng, nên trong lúc huỷ có thể đã có bản mới cùng số: khôi phục không được tạo bản trùng.
    begin
      perform app.assert_no_phone_duplicate(
        array_remove(array[v_lead.parent_phone, v_lead.parent_phone_2], null), v_lead.parent_id);
    exception when raise_exception then
      get stacked diagnostics v_hint = pg_exception_hint, v_message = message_text;
      if coalesce(v_hint, '') <> 'HMT_SDT_TRUNG' then raise; end if;
      -- Câu của hàm trùng số nói về «tạo mới»: ở đây chỉ giữ phần nêu mã bản đang dùng.
      v_skipped := v_skipped || app.lead_skip_row(v_id, split_part(v_message, '. ', 1) || '. Không khôi phục được.');
      continue;
    end;
    perform set_config('hmt.restore_lead', 'on', true);
    update app.lead
       set record_status = 'DANG_DUNG', cancel_reason = null, cancelled_at = null, cancelled_by = null
     where id = v_id;
    perform set_config('hmt.restore_lead', '', true);
    perform app.add_note('LEAD', v_id, 'Khôi phục lead đã huỷ. Lý do huỷ trước đó: ' || v_lead.cancel_reason);
    v_done := v_done + 1;
  end loop;
  return jsonb_build_object('done', v_done, 'skipped', v_skipped);
end;
$$;

select set_config('hmt.migration', '', false);
