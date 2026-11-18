-- Code B (18/11/2026), Aftersale B3 (CS-02/03 bản ghi ticket), migration 352: app.get_ticket trả thêm class_code, enrollment_code, related_ticket_code cho khung «Liên kết» của canvas CSN-03.
-- Chỉ thêm ba khoá vào kết quả; khoá cũ giữ nguyên, quyền và RLS không đổi (hàm không security definer, các truy vấn con theo khoá chính). R-CS-01, R-V2-23.
create or replace function app.get_ticket(p_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  t app.ticket;
begin
  select * into t from app.ticket where id = p_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  return jsonb_build_object(
    'ticket', app.ticket_row(t) || jsonb_build_object(
      'branch_id', t.branch_id, 'description', t.description, 'channel_code', t.channel_code, 'category_code', t.category_code, 'team_code', t.team_code,
      'student_name', (select s.full_name from app.student s where s.id = t.student_id),
      'class_id', t.class_id, 'related_ticket_id', t.related_ticket_id,
      -- Thêm cho khung liên kết của CSN-03: mã lớp, mã ghi danh, mã ticket gốc (RLS của lớp, ghi danh, ticket áp dụng như mọi truy vấn khác: không thấy thì null).
      'class_code', (select c.code from app.class c where c.id = t.class_id),
      'enrollment_code', (select e.code from app.enrollment e where e.id = t.enrollment_id),
      'related_ticket_code', (select r.code from app.ticket r where r.id = t.related_ticket_id),
      'resolution', t.resolution, 'cancel_reason', t.cancel_reason, 'satisfaction', t.satisfaction,
      'response_due_at', t.response_due_at, 'first_response_at', t.first_response_at, 'resolved_at', t.resolved_at, 'closed_at', t.closed_at,
      'nature_code', (select c.nature_code from app.ticket_category c where c.code = t.category_code),
      'business_type', (select c.business_type from app.ticket_category c where c.code = t.category_code),
      'accused_user_id', t.accused_user_id, 'accused_name', app.staff_display_name(t.accused_user_id),
      'complaint_date', t.complaint_date, 'customer_wish', t.customer_wish, 'root_cause', t.root_cause, 'compensation_note', t.compensation_note),
    'tasks', coalesce((select jsonb_agg(jsonb_build_object('id', k.id, 'code', k.code, 'task_type', k.task_type, 'status_code', k.status_code, 'created_at', k.created_at) order by k.created_at desc, k.id) from app.ticket_task k where k.ticket_id = t.id), '[]'::jsonb),
    'children', coalesce((select jsonb_agg(app.ticket_row(c) order by c.created_at, c.id) from app.ticket c where c.related_ticket_id = t.id), '[]'::jsonb),
    'events', coalesce((select jsonb_agg(jsonb_build_object(
        'id', e.id, 'event_type', e.event_type, 'from_status', e.from_status, 'to_status', e.to_status, 'note', e.note,
        'created_at', e.created_at, 'created_by_name', app.staff_display_name(e.created_by)) order by e.seq)
      from app.ticket_event e where e.ticket_id = t.id), '[]'::jsonb));
end;
$$;

select set_config('hmt.migration', '', false);
