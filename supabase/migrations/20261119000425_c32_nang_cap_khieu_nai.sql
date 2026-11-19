-- C32 (CS-13 Nâng cấp khiếu nại thủ công; Chat 10:00 mục 3; R-CS-06, R-CS-08, R-HT-01): người xử lý nâng cấp khiếu nại lên Quản lý cơ sở rồi Ban giám đốc, lý do bắt buộc, có nhật ký.
-- Phạm vi: CHỈ thủ công. Tự động nâng cấp khi quá hạn SLA (pg_cron) làm ở thẻ riêng sau.
-- Làm gì: (1) ba cột trên app.ticket: escalation_level (QUAN_LY_CO_SO, BAN_GIAM_DOC; null = chưa), escalated_at, escalated_by; (2) loại nhật ký NANG_CAP; (3) app.escalate_ticket(ticket, lý do); (4) app.ticket_row trả thêm mức nâng cấp.
select set_config('hmt.migration', 'on', false);

alter table app.ticket
  add column escalation_level text check (escalation_level in ('QUAN_LY_CO_SO', 'BAN_GIAM_DOC')),
  add column escalated_at timestamptz,
  add column escalated_by uuid references app.user_account (id);
comment on column app.ticket.escalation_level is 'Mức nâng cấp khiếu nại (R-CS-06): null = chưa; QUAN_LY_CO_SO rồi BAN_GIAM_DOC. Chỉ đi lên, không hạ.';
-- Chỉ mục (lý do): khoá ngoại escalated_by (chuẩn); bảng nhỏ theo cơ sở, danh sách lọc theo mức nâng cấp để sau khi có màn báo cáo (chưa lọc, chưa cần chỉ mục riêng cho mức).
create index ticket_escalated_by_idx on app.ticket (escalated_by) where escalated_by is not null;

alter table app.ticket_event drop constraint ticket_event_event_type_check;
alter table app.ticket_event add constraint ticket_event_event_type_check
  check (event_type in ('TAO', 'GIAO', 'DOI_TRANG_THAI', 'DOI_NHOM_CON', 'DOI_MUC_DO', 'GHI_CHU', 'SUA_KHIEU_NAI', 'NANG_CAP'));

-- app.escalate_ticket(mã ticket, lý do): nâng cấp khiếu nại thêm một mức: chưa nâng cấp → Quản lý cơ sở → Ban giám đốc.
-- Ai gọi: Ticket · Sửa ở cơ sở của ticket (CSKH, Trưởng cơ sở, Admin). Cờ AFTERSALE bật.
-- Luật: chỉ khiếu nại (R-CS-06); ticket đã đóng hoặc huỷ thì không (AS-02); lý do bắt buộc; đã ở Ban giám đốc thì không nâng thêm; ghi nhật ký NANG_CAP (AS-02).
-- Lỗi: HMT_KHONG_TIM_THAY, HMT_TICKET_LOAI_SAI, HMT_TICKET_TRANG_THAI_SAI, HMT_LY_DO_BAT_BUOC, HMT_TICKET_DA_NANG_CAP_TOI_DA.
create or replace function app.escalate_ticket(p_id uuid, p_reason text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_next text;
begin
  select * into t from app.ticket where id = p_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  -- Luật R-CS-06: chỉ khiếu nại có nâng cấp.
  if t.ticket_type <> 'KN' then
    perform app.raise_error('HMT_TICKET_LOAI_SAI', 'Chỉ nâng cấp được ticket khiếu nại.');
  end if;
  -- Luật AS-02: ticket đã đóng hoặc huỷ thì chỉ xem.
  if t.status_code in ('DA_DONG', 'DA_HUY') then
    perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Ticket đã đóng hoặc đã huỷ, không nâng cấp được.');
  end if;
  -- Luật R-CS-06: lý do bắt buộc.
  if btrim(coalesce(p_reason, '')) = '' then
    perform app.raise_error('HMT_LY_DO_BAT_BUOC', 'Nhập lý do nâng cấp.');
  end if;
  -- Luật R-CS-06: lên Quản lý cơ sở rồi Ban giám đốc; không nâng quá mức cao nhất.
  v_next := case when t.escalation_level is null then 'QUAN_LY_CO_SO' when t.escalation_level = 'QUAN_LY_CO_SO' then 'BAN_GIAM_DOC' end;
  if v_next is null then
    perform app.raise_error('HMT_TICKET_DA_NANG_CAP_TOI_DA', 'Khiếu nại đã nâng cấp lên Ban giám đốc, không nâng thêm được.');
  end if;
  update app.ticket set escalation_level = v_next, escalated_at = now(), escalated_by = (select auth.uid()) where id = t.id;
  insert into app.ticket_event (ticket_id, branch_id, event_type, note)
  values (t.id, t.branch_id, 'NANG_CAP',
          case v_next when 'QUAN_LY_CO_SO' then 'Nâng cấp lên Quản lý cơ sở' else 'Nâng cấp lên Ban giám đốc' end || ': ' || btrim(p_reason));
  return v_next;
end;
$$;
revoke execute on function app.escalate_ticket(uuid, text) from public, anon;
grant execute on function app.escalate_ticket(uuid, text) to authenticated;

create or replace function app.ticket_row(t app.ticket)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id, 'code', t.code, 'title', t.title, 'ticket_type', t.ticket_type, 'branch_code', (select b.code from app.branch b where b.id = t.branch_id),
    'category_name', (select c.name from app.ticket_category c where c.code = t.category_code),
    -- Thêm cho danh sách theo khuôn CSN01: cột «Nhóm · Nhóm con» và «Học sinh».
    'group_name', (select g.name from app.ticket_category c join app.ticket_category g on g.code = c.parent_code where c.code = t.category_code),
    'student_name', (select st.full_name from app.student st where st.id = t.student_id),
    'priority_code', t.priority_code, 'status_code', t.status_code,
    'assignee_name', app.staff_display_name(t.assignee_id),
    'sender_name', coalesce((select p.full_name from app.parent p where p.id = t.parent_id), app.staff_display_name(t.sender_user_id)),
    'resolve_due_at', t.resolve_due_at, 'created_at', t.created_at,
    'sla_state', case
      when t.status_code = 'DA_XU_LY' and t.resolved_at < now() - make_interval(days => app.get_setting_int('as_close_wait_days')::integer) then 'CHO_DONG'
      when t.status_code in ('DA_XU_LY', 'DA_DONG', 'DA_HUY') then 'KHONG'
      when now() > t.resolve_due_at then 'QUA_HAN'
      when t.resolve_due_at - now() < (t.resolve_due_at - t.created_at) * (app.get_setting_int('as_sla_warn_percent') / 100.0)::double precision then 'SAP_QUA_HAN' -- allow-number: phần trăm chia 100
      else 'KHONG' end,
    -- C32: mức nâng cấp hiện tại (null = chưa nâng cấp) và lúc nâng cấp gần nhất.
    'escalation_level', t.escalation_level, 'escalated_at', t.escalated_at);
$$;
select set_config('hmt.migration', '', false);
