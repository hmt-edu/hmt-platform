-- C60 (Chat 16:44 mục 4): cột «Người duyệt kế tiếp» (CSN-05) và bảng Duyệt (CSN-06) hiện TÊN người duyệt dự kiến của cấp đang chờ, không chỉ tên vai.
-- Phương án an toàn (luật docs/spec/04 R-CS-07 chỉ nói vai theo cấp, không nói đích danh): cấp Quản lý cơ sở = người giữ vai Trưởng cơ sở (BRANCH_MANAGER) ĐANG HOẠT ĐỘNG của đúng cơ sở phiếu; cấp Kế toán = người giữ vai Kế toán (ACCOUNTANT) đang hoạt động. Có tối đa hai tên (xếp theo tên), nhiều hơn thì nối «…». Không có ai thì null (giao diện hiện tên vai).
-- Chỉ để hiển thị: quyền duyệt thật vẫn kiểm ở app.approve_ticket_task. Câu hỏi cho Chat: nếu cơ sở có nhiều Trưởng cơ sở thì «ai được gợi ý» chưa có luật, hiện liệt kê.
select set_config('hmt.migration', 'on', false);

create or replace function app.ticket_task_next_approver(p_branch_id uuid, p_level text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case when count(*) = 0 then null
              else string_agg(n.name, ', ' order by n.name) filter (where n.rn <= 2) || case when count(*) > 2 then ', …' else '' end end -- allow-number: hiện tối đa hai tên người duyệt dự kiến
    from (
      select app.staff_display_name(ur.user_id) as name, row_number() over (order by app.staff_display_name(ur.user_id)) as rn
        from app.user_role ur
        join app.user_account ua on ua.id = ur.user_id
       where ur.is_active
         and ((p_level = 'QUAN_LY_CO_SO' and ur.role_code = 'BRANCH_MANAGER' and ua.branch_id = p_branch_id)
              or (p_level = 'KE_TOAN' and ur.role_code = 'ACCOUNTANT'))
    ) n;
$$;
revoke execute on function app.ticket_task_next_approver(uuid, text) from public, anon;
grant execute on function app.ticket_task_next_approver(uuid, text) to authenticated;

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
  v_is_acc boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code = 'ACCOUNTANT');
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
                    'next_approver', case when k.status_code = 'CHO_DUYET' then app.ticket_task_next_approver(k.branch_id, k.levels[k.current_level]) end,
                    'ticket_id', k.ticket_id, 'ticket_code', t.code,
                    'student_name', (select s.full_name from app.student s where s.id = t.student_id),
                    'branch_code', (select b.code from app.branch b where b.id = k.branch_id),
                    'created_at', k.created_at, 'due_at', t.resolve_due_at) order by k.created_at desc, k.id)
                   from (select f.id from f order by f.created_at desc, f.id limit v_limit offset v_offset) x
                   join app.ticket_task k on k.id = x.id join app.ticket t on t.id = k.ticket_id), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

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
      -- C60: người duyệt dự kiến của cấp đang chờ (CSN-05, CSN-06).
      'next_approver', case when k.status_code = 'CHO_DUYET' then app.ticket_task_next_approver(k.branch_id, k.levels[k.current_level]) end,
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
select set_config('hmt.migration', '', false);
