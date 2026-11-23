-- C-23-23 (Chat 17:20, THẤP: chỉ đọc; migration 634). CSN07_duyet_chuyen_lop (canvas 9189 v58): hộp Duyệt phiếu Chuyển lớp tóm tắt lớp hiện tại, lớp mới (lịch, giáo viên), ngày bắt đầu, giờ còn lại.
-- Làm gì: (1) app.task_class_summary(lớp): mã lớp và các buổi trong tuần (thứ, giờ, giáo viên); (2) app.get_ticket_task (bản 428) thêm khoá 'transfer' cho phiếu Chuyển lớp.
-- Ai gọi: giao diện (get_ticket_task đã kiểm quyền xem như cũ). Không đổi quyền, không ghi dữ liệu. Chỉ mục: không thêm (đọc theo khoá class_id, enrollment_id đã có chỉ mục).
-- Luật: R-CS-03 (chuyển lớp cùng môn, đã chặn ở migration 625), R-GD-10.
select set_config('hmt.migration', 'on', false);

-- app.task_class_summary(lớp): {code, slots: [{weekday, start_time, end_time, teacher_name}]}; lớp trống hoặc không thấy được (RLS) thì null. Chạy với quyền người gọi (không security definer) để RLS của lớp vẫn áp dụng.
create or replace function app.task_class_summary(p_class_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object('code', c.code, 'slots', coalesce((
    select jsonb_agg(jsonb_build_object('weekday', s.weekday, 'start_time', to_char(s.start_time, 'HH24:MI'), 'end_time', to_char(s.end_time, 'HH24:MI'),
                                        'teacher_name', app.staff_display_name(s.teacher_id)) order by s.weekday, s.start_time)
      from app.class_slot s where s.class_id = c.id and s.is_active), '[]'::jsonb))
    from app.class c where c.id = p_class_id;
$$;
revoke execute on function app.task_class_summary(uuid) from public, anon;
grant execute on function app.task_class_summary(uuid) to authenticated;

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
    -- C-23-23 (CSN07_duyet_chuyen_lop): tóm tắt cho hộp Duyệt phiếu Chuyển lớp: lớp hiện tại, lớp mới, ngày bắt đầu, giờ còn lại (chỉ đọc, giờ do sổ giờ tính).
    'transfer', case when k.task_type = 'CHUYEN_LOP' then jsonb_build_object(
      'from_class', app.task_class_summary((select ec.class_id from app.enrollment_class ec
                                              where ec.enrollment_id = nullif(k.payload ->> 'enrollment_id', '')::uuid and ec.end_date is null limit 1)),
      'to_class', app.task_class_summary(nullif(k.payload ->> 'to_class_id', '')::uuid),
      'start_date', k.payload ->> 'start_date',
      'hours_left', coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = nullif(k.payload ->> 'enrollment_id', '')::uuid), 0)::numeric(6, 2)) end,
    'events', coalesce((select jsonb_agg(jsonb_build_object(
        'id', e.id, 'event_type', e.event_type, 'from_status', e.from_status, 'to_status', e.to_status, 'note', e.note,
        'created_at', e.created_at, 'created_by_name', app.staff_display_name(e.created_by)) order by e.seq)
      from app.ticket_task_event e where e.task_id = k.id), '[]'::jsonb));
end;
$$;
select set_config('hmt.migration', '', false);
