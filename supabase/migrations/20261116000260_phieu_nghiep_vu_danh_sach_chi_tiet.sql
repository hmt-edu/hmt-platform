-- Code B (16/11/2026), Aftersale phiếu nghiệp vụ, migration 260: hàm đọc cho màn CSN-05 (danh sách phiếu) và CSN-06 (chi tiết phiếu).
-- Luật: AS-09 (phạm vi xem theo ticket), AS-10 (trạng thái phiếu), R-CS-07 (cấp duyệt). Không security definer: RLS của bảng phiếu và ticket lọc theo phạm vi người xem.
select set_config('hmt.migration', 'on', false);

-- app.list_ticket_tasks(bộ lọc, số dòng, bỏ qua): danh sách phiếu nghiệp vụ phân trang ở máy chủ (CSN-05). Ai gọi: người thấy ticket của phiếu (RLS).
-- Bộ lọc (jsonb, tuỳ chọn): status_code, task_type, q (mã phiếu hoặc mã ticket), branch_id, cho_toi (true: phiếu Chờ duyệt mà cấp hiện tại tôi duyệt được),
-- cho_ke_toan (true: Chờ duyệt ở cấp kế toán). Số dòng mặc định list_page_size_default, tối đa list_page_size_max; mới nhất trước.
-- Kết quả {total, rows[]}; mỗi dòng có mã phiếu, loại, trạng thái, cấp (hiện tại/tổng, vai trò cấp kế tiếp), mã ticket gốc, tên học sinh, cơ sở.
create or replace function app.list_ticket_tasks(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_status text := nullif(p_filters ->> 'status_code', '');
  v_type text := nullif(p_filters ->> 'task_type', '');
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_for_me boolean := coalesce((p_filters ->> 'cho_toi')::boolean, false);
  v_for_acc boolean := coalesce((p_filters ->> 'cho_ke_toan')::boolean, false);
  v_can_approve boolean := app.has_permission('TICKET', 'DUYET');
  v_is_acc boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('ACCOUNTANT', 'ADMIN'));
  v_total bigint;
  v_rows jsonb;
begin
  with f as (
    select k.id, k.created_at
      from app.ticket_task k
      join app.ticket t on t.id = k.ticket_id
     where (v_status is null or k.status_code = v_status)
       and (v_type is null or k.task_type = v_type)
       and (v_branch is null or k.branch_id = v_branch)
       and (v_q is null or k.code ilike '%' || v_q || '%' or t.code ilike '%' || v_q || '%')
       and (not v_for_me or (k.status_code = 'CHO_DUYET' and v_can_approve and k.created_by is distinct from auth.uid()
                             and (k.levels[k.current_level] <> 'KE_TOAN' or v_is_acc)))
       and (not v_for_acc or (k.status_code = 'CHO_DUYET' and k.levels[k.current_level] = 'KE_TOAN')))
  select (select count(*) from f),
         coalesce((select jsonb_agg(jsonb_build_object(
                    'id', k.id, 'code', k.code, 'task_type', k.task_type, 'status_code', k.status_code,
                    'level', k.current_level, 'level_total', cardinality(k.levels),
                    'next_role', case when k.status_code = 'CHO_DUYET' then k.levels[k.current_level] end,
                    'ticket_id', k.ticket_id, 'ticket_code', t.code,
                    'student_name', (select s.full_name from app.student s where s.id = t.student_id),
                    'branch_code', (select b.code from app.branch b where b.id = k.branch_id),
                    'created_at', k.created_at) order by k.created_at desc, k.id)
                   from (select f.id from f order by f.created_at desc, f.id limit v_limit offset v_offset) x
                   join app.ticket_task k on k.id = x.id join app.ticket t on t.id = k.ticket_id), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.get_ticket_task(mã phiếu): chi tiết phiếu và dòng thời gian (CSN-06), một lần gọi. RLS lọc theo phạm vi; không thấy thì HMT_KHONG_TIM_THAY.
-- Kết quả {task, ticket, events[]}. «can_approve» cho biết người xem duyệt được cấp hiện tại không (giao diện chỉ gợi ý nút; hàm duyệt kiểm lại).
create or replace function app.get_ticket_task(p_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  k app.ticket_task;
  t app.ticket;
  v_is_acc boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('ACCOUNTANT', 'ADMIN'));
begin
  select * into k from app.ticket_task where id = p_id;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  select * into t from app.ticket where id = k.ticket_id;
  return jsonb_build_object(
    'task', jsonb_build_object(
      'id', k.id, 'code', k.code, 'task_type', k.task_type, 'status_code', k.status_code, 'reason', k.reason, 'payload', k.payload, 'result', k.result,
      'level', k.current_level, 'level_total', cardinality(k.levels), 'levels', to_jsonb(k.levels),
      'reject_reason', k.reject_reason, 'cancel_reason', k.cancel_reason, 'branch_id', k.branch_id,
      'branch_code', (select b.code from app.branch b where b.id = k.branch_id),
      'created_at', k.created_at, 'submitted_at', k.submitted_at, 'approved_at', k.approved_at, 'executed_at', k.executed_at,
      'created_by_name', app.staff_display_name(k.created_by),
      'can_approve', k.status_code = 'CHO_DUYET' and k.created_by is distinct from auth.uid() and app.has_permission('TICKET', 'DUYET')
                      and (k.levels[k.current_level] <> 'KE_TOAN' or v_is_acc),
      'is_creator', k.created_by is not distinct from auth.uid()),
    'ticket', jsonb_build_object('id', t.id, 'code', t.code, 'title', t.title, 'status_code', t.status_code,
                                  'student_name', (select s.full_name from app.student s where s.id = t.student_id)),
    'events', coalesce((select jsonb_agg(jsonb_build_object(
        'id', e.id, 'event_type', e.event_type, 'from_status', e.from_status, 'to_status', e.to_status, 'note', e.note,
        'created_at', e.created_at, 'created_by_name', app.staff_display_name(e.created_by)) order by e.seq)
      from app.ticket_task_event e where e.task_id = k.id), '[]'::jsonb));
end;
$$;

revoke execute on function app.list_ticket_tasks(jsonb, integer, integer), app.get_ticket_task(uuid) from public, anon, authenticated;
grant execute on function app.list_ticket_tasks(jsonb, integer, integer), app.get_ticket_task(uuid) to authenticated;

select set_config('hmt.migration', '', false);
