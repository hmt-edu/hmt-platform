-- TT-D1 Phiếu tái tục, bản ghi TT-02 chỉ đọc kèm thao tác sẵn có (Code C, 18/11/2026; canvas 9933 TT02_*). Chưa có báo giá, đơn từ phiếu (TT-D2, đề xuất riêng vì dính tiền).
-- app.get_upsale_ticket(phiếu): một lần gọi cho cả màn: phiếu, phụ huynh, học sinh, lớp và giáo viên lớp, các ghi danh liên quan kèm giờ còn, giờ đã mua, đã học,
-- số buổi vắng trong absence_risk_window_days ngày, dòng thời gian, và các việc người gọi làm được (giao, đổi giai đoạn, sửa ghi chú). Mọi con số do hàm DB trả.
-- Ai gọi: người có quyền Phiếu tái tục · Xem ở cơ sở của phiếu. Email, Zalo của phụ huynh: hồ sơ phụ huynh chưa có cột nên trả null (chờ Chat chốt nguồn).
select set_config('hmt.migration', 'on', false);

create or replace function app.get_upsale_ticket(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_open boolean;
  v_window integer;
begin
  select * into t from app.upsale_ticket where id = p_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'XEM', t.branch_id);
  v_open := t.stage_code not in ('L5', 'L8');
  v_window := app.get_setting_int('absence_risk_window_days', t.branch_id)::integer;
  return jsonb_build_object(
    'ticket', app.upsale_ticket_row(t) || jsonb_build_object(
      'lost_reason_code', t.lost_reason_code, 'lost_note', t.lost_note, 'next_goal', t.next_goal, 'next_roadmap', t.next_roadmap,
      'closed_at', t.closed_at, 'created_by_name', app.staff_display_name(t.created_by)),
    'parent', (select jsonb_build_object('id', p.id, 'code', p.code, 'name', p.full_name, 'phone', p.phone, 'email', null, 'zalo', null)
                 from app.parent p where p.id = t.parent_id),
    'student', (select jsonb_build_object('id', s.id, 'code', s.code, 'name', s.full_name) from app.student s where s.id = t.student_id),
    'class', jsonb_build_object('id', t.class_id, 'code', (select code from app.class where id = t.class_id),
      'teacher_name', (select u.display_name from app.class_slot cs join app.user_account u on u.id = cs.teacher_id
                        where cs.class_id = t.class_id and cs.is_active order by cs.weekday, cs.start_time limit 1)),
    'enrollments', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'code', e.code, 'status_code', e.status_code,
                       'hours_left', coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = e.id), 0)) order by e.code)
                  from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                 where e.student_id = t.student_id), '[]'::jsonb),
    'hours', jsonb_build_object(
      'bought', (select coalesce(sum(h.hours), 0) from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id
                  join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                  where e.student_id = t.student_id and h.entry_type in ('CAP_MUA', 'CAP_TANG', 'DAU_KY')),
      'used', (select coalesce(-sum(h.hours), 0) from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id
                join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                where e.student_id = t.student_id and h.entry_type = 'TRU_BUOI'),
      'absences_window', (select count(*) from app.session_attendance sa join app.class_session s on s.id = sa.session_id
                           where sa.student_id = t.student_id and s.class_id = t.class_id and sa.is_active
                             and coalesce(sa.teacher_status_code, sa.ops_status_code) in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')
                             and s.session_date > (now() at time zone 'Asia/Ho_Chi_Minh')::date - v_window),
      'window_days', v_window),
    'events', coalesce((select jsonb_agg(jsonb_build_object('id', ev.id, 'event_type', ev.event_type, 'from_stage', ev.from_stage, 'to_stage', ev.to_stage,
                       'note', ev.note, 'created_at', ev.created_at, 'created_by_name', app.staff_display_name(ev.created_by)) order by ev.seq)
                  from app.upsale_ticket_event ev where ev.ticket_id = t.id), '[]'::jsonb),
    'actions', to_jsonb(array_remove(array[
      case when v_open and app.can_see_branch('UPSALE', 'GIAO_VIEC', t.branch_id) then 'giao' end,
      case when t.stage_code in ('L1', 'L2', 'L3', 'L4', 'L6') and app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'doi_giai_doan' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'sua_ghi_chu' end], null)));
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.get_upsale_ticket(uuid) from public, anon;
grant execute on function app.get_upsale_ticket(uuid) to authenticated;
