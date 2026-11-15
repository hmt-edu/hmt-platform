-- Code B (16/11/2026), Aftersale lát 3a, migration 158: đọc chi tiết ticket kèm dòng thời gian; thêm ghi chú vào ticket (CSN-03).
-- Luật: docs/spec/de-xuat-luat-aftersale.md (AS-02 nhật ký, AS-09 quyền), R-V2-23.
-- Làm gì: thêm loại sự kiện GHI_CHU cho nhật ký ticket; app.get_ticket; app.add_ticket_note.
select set_config('hmt.migration', 'on', false);

-- Loại sự kiện mới GHI_CHU (ghi chú tay trên dòng thời gian). Bảng chưa có dữ liệu thật; chỉ nới điều kiện kiểm.
alter table app.ticket_event drop constraint ticket_event_event_type_check;
alter table app.ticket_event add constraint ticket_event_event_type_check
  check (event_type in ('TAO', 'GIAO', 'DOI_TRANG_THAI', 'DOI_NHOM_CON', 'DOI_MUC_DO', 'GHI_CHU'));

-- app.get_ticket(mã ticket): chi tiết một ticket và dòng thời gian (nhật ký, mới nhất cuối). Ai gọi: người có quyền xem ticket đó.
-- Không security definer: RLS bảng ticket và ticket_event lọc theo phạm vi (AS-09). Không thấy hoặc không có thì báo HMT_KHONG_TIM_THAY.
-- Kết quả {ticket: {...ticket_row, mô tả, kênh, nhóm, đội, liên kết, hạn, kết quả}, events: [...]}. Một lần gọi, không gọi lặp.
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
      'resolution', t.resolution, 'cancel_reason', t.cancel_reason, 'satisfaction', t.satisfaction,
      'response_due_at', t.response_due_at, 'first_response_at', t.first_response_at, 'resolved_at', t.resolved_at, 'closed_at', t.closed_at),
    'events', coalesce((select jsonb_agg(jsonb_build_object(
        'id', e.id, 'event_type', e.event_type, 'from_status', e.from_status, 'to_status', e.to_status, 'note', e.note,
        'created_at', e.created_at, 'created_by_name', app.staff_display_name(e.created_by)) order by e.seq)
      from app.ticket_event e where e.ticket_id = t.id), '[]'::jsonb));
end;
$$;

-- app.add_ticket_note(mã ticket, nội dung): thêm ghi chú vào dòng thời gian. Ai gọi: Ticket · Sửa ở cơ sở của ticket.
-- Luật: phân hệ AFTERSALE phải bật (công tắc); ghi chú không rỗng; ticket đã đóng hoặc huỷ không thêm ghi chú (AS-02). Chỉ thêm dòng nhật ký, không đổi ticket.
create or replace function app.add_ticket_note(p_id uuid, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  select * into t from app.ticket where id = p_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  -- Luật: ghi chú không rỗng.
  if v_note is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập nội dung ghi chú.');
  end if;
  -- Luật AS-02: ticket đã đóng hoặc đã huỷ thì chỉ xem.
  if t.status_code in ('DA_DONG', 'DA_HUY') then
    perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Ticket đã đóng hoặc đã huỷ, không thêm ghi chú được.');
  end if;
  insert into app.ticket_event (ticket_id, branch_id, event_type, note) values (p_id, t.branch_id, 'GHI_CHU', v_note);
end;
$$;

revoke execute on function app.get_ticket(uuid), app.add_ticket_note(uuid, text) from public, anon, authenticated;
grant execute on function app.get_ticket(uuid), app.add_ticket_note(uuid, text) to authenticated;

select set_config('hmt.migration', '', false);
