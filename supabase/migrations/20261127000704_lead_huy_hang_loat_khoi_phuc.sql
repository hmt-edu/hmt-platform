-- D-27-12 · B2, B3, B5, B6 (anh Trường chốt 26/11/2026): huỷ lead nhập nhầm theo ma trận quyền, huỷ hàng loạt, khôi phục, «Thùng rác».
-- Đổi luật CHUNG-20 (trước chỉ Admin): Admin huỷ hàng loạt mọi cơ sở; Trưởng cơ sở hàng loạt trong cơ sở mình, tối đa lead_cancel_bulk_max
-- mỗi lần; Tư vấn chỉ huỷ lead mình phụ trách, từng cái. Khôi phục: chỉ Admin. Không xoá cứng, mọi lần đổi vào audit_log và ghi chú.
-- Chỉ mục: không thêm. Huỷ và khôi phục đi theo khoá chính; lọc «Thùng rác» dùng cùng câu truy vấn danh sách (lead_cancelled_idx đã có).

select set_config('hmt.migration', 'on', false);

-- Tham số: trần số lead mỗi lần huỷ hàng loạt của người có phạm vi cơ sở.
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('lead_cancel_bulk_max', 'Huỷ lead hàng loạt: tối đa mỗi lần', 'INT', 'lead', 1, 500, '100', true, 'BAN_HANG', 'CHUNG-20',
   'Người có quyền huỷ ở phạm vi cơ sở không huỷ quá chừng này lead trong một lần. Phạm vi toàn hệ thống không bị giới hạn này.');

-- Ma trận quyền: Tư vấn được huỷ lead CỦA MÌNH (Trưởng cơ sở: cơ sở mình, Admin: toàn hệ thống đã có sẵn).
-- Ba vai Marketing có quyền như Tư vấn (R-V2-09) nên nhận cùng ô.
insert into app.permission (role_code, module_code, action_code, scope_code)
values ('SALES', 'LEAD', 'HUY', 'CUA_TOI'),
       ('MARKETER', 'LEAD', 'HUY', 'CUA_TOI'),
       ('MARKETING', 'LEAD', 'HUY', 'CUA_TOI'),
       ('MARKETING_MANAGER', 'LEAD', 'HUY', 'CUA_TOI')
on conflict (role_code, module_code, action_code) do update set scope_code = excluded.scope_code, is_active = true;

select set_config('hmt.migration', '', false);

-- app.lead_cancel_options: người đang đăng nhập được làm gì với huỷ lead (để giao diện ẩn hiện nút; máy chủ vẫn kiểm lại khi làm).
-- Ai gọi: người đã đăng nhập. Ra: {single, bulk, bulk_max (null = không giới hạn), restore}. Luật: R-CRM-45.
create function app.lead_cancel_options()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('LEAD', 'HUY');
begin
  return jsonb_build_object(
    'single', v_scope is not null,
    'bulk', coalesce(v_scope in ('TOAN_HE_THONG', 'CO_SO'), false),
    'bulk_max', case when v_scope = 'CO_SO' then app.get_setting_int('lead_cancel_bulk_max', app.current_branch_id()) end,
    'restore', app.has_permission('ADMIN', 'TAO'));
end;
$$;
revoke execute on function app.lead_cancel_options() from public, anon;
grant execute on function app.lead_cancel_options() to authenticated;

-- app.cancel_wrong_lead: huỷ MỘT lead nhập nhầm.
-- Ai gọi: người có Lead · Huỷ (toàn hệ thống, cơ sở mình, hoặc lead mình phụ trách). Vào: p_id lead, p_reason lý do. Ra: {id, code}.
-- Luật R-CRM-45: chỉ lead Đang dùng; đã có cơ hội hoặc lịch hẹn thì chặn; lý do bắt buộc; ghi ghi chú.
create or replace function app.cancel_wrong_lead(p_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lead app.lead;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_scope text := app.permission_scope('LEAD', 'HUY');
  v_opp integer;
  v_appt integer;
begin
  -- Luật: phải có quyền huỷ lead.
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền huỷ lead.');
  end if;
  -- Luật: lý do bắt buộc.
  if v_reason = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Cần ghi lý do huỷ lead.');
  end if;
  select * into v_lead from app.lead where id = p_id for update;
  if v_lead.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead.');
  end if;
  -- Luật: phạm vi cơ sở chỉ lead cơ sở mình; phạm vi hẹp chỉ lead mình phụ trách.
  if v_scope = 'CO_SO' and not app.can_see_branch_wide('LEAD', 'HUY', v_lead.branch_id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn chỉ huỷ được lead của cơ sở mình.');
  end if;
  if v_scope not in ('TOAN_HE_THONG', 'CO_SO') and v_lead.owner_id is distinct from auth.uid() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn chỉ huỷ được lead mình phụ trách.');
  end if;
  -- Luật: chỉ huỷ lead đang dùng (đã gộp hoặc đã huỷ thì không).
  if v_lead.record_status <> 'DANG_DUNG' then
    perform app.raise_error('HMT_LEAD_KHONG_HUY_DUOC', 'Lead này đã gộp hoặc đã huỷ, không huỷ được nữa.');
  end if;
  -- Luật: đã có cơ hội (phiếu kiểm tra, báo giá, đơn đều đi qua cơ hội) thì không phải lead nhập nhầm.
  select count(*) into v_opp from app.opportunity where lead_id = p_id;
  if v_opp > 0 then
    perform app.raise_error('HMT_LEAD_CO_CO_HOI', format('Lead đã có %s cơ hội nên không huỷ được.', v_opp));
  end if;
  -- Luật: đã có lịch hẹn thì chặn (kể cả lịch đã làm hay đã huỷ: là dấu vết chăm sóc).
  select count(*) into v_appt from app.appointment where lead_id = p_id;
  if v_appt > 0 then
    perform app.raise_error('HMT_LEAD_CO_LICH_HEN', format('Lead đã có %s lịch hẹn nên không huỷ được.', v_appt));
  end if;
  -- Việc huỷ: đổi trạng thái, không xoá.
  update app.lead
     set record_status = 'DA_HUY', cancel_reason = v_reason, cancelled_at = now(), cancelled_by = auth.uid()
   where id = p_id;
  perform app.add_note('LEAD', p_id, 'Huỷ lead nhập nhầm: ' || v_reason);
  return jsonb_build_object('id', p_id, 'code', v_lead.code);
end;
$$;

-- app.lead_skip_row: một dòng «bỏ qua» của thao tác hàng loạt; chỉ nêu mã khi người gọi xem được lead đó.
-- Ai gọi: chỉ các hàm huỷ, khôi phục hàng loạt (không cấp cho người dùng).
create function app.lead_skip_row(p_id uuid, p_message text)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_id,
    'code', (select l.code from app.lead l where l.id = p_id and app.can_see_branch('LEAD', 'XEM', l.branch_id)),
    'reason', p_message);
$$;
revoke execute on function app.lead_skip_row(uuid, text) from public, anon, authenticated;

-- app.cancel_wrong_leads: huỷ nhiều lead cùng một lý do.
-- Ai gọi: người có Lead · Huỷ ở phạm vi cơ sở hoặc toàn hệ thống. Vào: danh sách id, lý do. Ra: {done, skipped: [{id, code, reason}]}.
-- Luật R-CRM-45: mỗi lead qua đủ luật của app.cancel_wrong_lead; lead vướng luật thì bỏ qua, lead khác vẫn huỷ.
create function app.cancel_wrong_leads(p_ids uuid[], p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('LEAD', 'HUY');
  v_ids uuid[] := array(select distinct x from unnest(p_ids) as x where x is not null);
  v_max integer;
  v_id uuid;
  v_done integer := 0;
  v_skipped jsonb := '[]'::jsonb;
  v_hint text;
  v_message text;
begin
  -- Luật: huỷ hàng loạt cần phạm vi rộng.
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền huỷ nhiều lead một lúc.');
  end if;
  if cardinality(v_ids) = 0 then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ít nhất một lead để huỷ.');
  end if;
  -- Luật: lý do bắt buộc (một lý do chung).
  if btrim(coalesce(p_reason, '')) = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Cần ghi lý do huỷ lead.');
  end if;
  -- Luật: trần mỗi lần cho phạm vi cơ sở.
  if v_scope = 'CO_SO' then
    v_max := app.get_setting_int('lead_cancel_bulk_max', app.current_branch_id());
    if cardinality(v_ids) > v_max then
      perform app.raise_error('HMT_HUY_QUA_NHIEU', format('Mỗi lần chỉ huỷ tối đa %s lead. Bạn đang chọn %s.', v_max, cardinality(v_ids)));
    end if;
  end if;
  foreach v_id in array v_ids loop
    begin
      perform app.cancel_wrong_lead(v_id, p_reason);
      v_done := v_done + 1;
    exception when raise_exception then
      get stacked diagnostics v_hint = pg_exception_hint, v_message = message_text;
      if coalesce(v_hint, '') not like 'HMT\_%' then raise; end if;
      v_skipped := v_skipped || app.lead_skip_row(v_id, v_message);
    end;
  end loop;
  return jsonb_build_object('done', v_done, 'skipped', v_skipped);
end;
$$;
revoke execute on function app.cancel_wrong_leads(uuid[], text) from public, anon;
grant execute on function app.cancel_wrong_leads(uuid[], text) to authenticated;

-- Luật: lead đã huỷ chỉ xem; ngoại lệ duy nhất là app.restore_cancelled_leads đưa về Đang dùng.
-- (Người dùng không có quyền UPDATE bảng lead nên không tự bật được cờ này qua API.)
create or replace function app.tg_lead_da_huy_chi_xem()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.record_status = 'DA_HUY'
     and not (new.record_status = 'DANG_DUNG' and coalesce(current_setting('hmt.restore_lead', true), '') = 'on') then
    perform app.raise_error('HMT_LEAD_DA_HUY', 'Lead này đã huỷ vì nhập nhầm, chỉ xem được.');
  end if;
  return new;
end;
$$;

-- app.restore_cancelled_leads: khôi phục lead Đã huỷ về Đang dùng (một hoặc nhiều).
-- Ai gọi: chỉ Admin (quyền ADMIN·TAO). Vào: danh sách id. Ra: {done, skipped: [{id, code, reason}]}.
-- Luật R-CRM-46: chỉ lead Đã huỷ; lý do huỷ cũ được ghi lại vào ghi chú trước khi xoá khỏi hồ sơ.
create function app.restore_cancelled_leads(p_ids uuid[])
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
revoke execute on function app.restore_cancelled_leads(uuid[]) from public, anon;
grant execute on function app.restore_cancelled_leads(uuid[]) to authenticated;


-- Danh sách, đếm nhóm, xuất file: thêm bộ lọc trash («Thùng rác» = Đã gộp + Đã huỷ); «hiện lead đã gộp» không kéo theo lead đã huỷ;
-- trả thêm cancel_reason. Chép nguyên định nghĩa đang chạy, chỉ đổi các đoạn đó. Kanban không đổi (chỉ lead Đang dùng).

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
