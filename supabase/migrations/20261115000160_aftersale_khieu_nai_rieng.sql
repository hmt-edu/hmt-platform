-- Code B (16/11/2026), Aftersale lát 3c, migration 160: phần «Riêng khiếu nại» và danh sách ticket con của CSN-03 (canvas 9189: CSN03_khieu_nai_co_con, CSN03_gv).
-- Luật: docs/spec/de-xuat-luat-aftersale.md (AS-04 khiếu nại, AS-05 ticket giáo viên, AS-09 quyền). Chưa có luật riêng cho bốn ô mới: chọn phương án an toàn,
-- chỉ lưu CHỮ, KHÔNG sinh tiền (ô «Bồi hoàn» là ghi chú bằng chữ, không có số tiền); Chat xác nhận hoặc đổi sau.
select set_config('hmt.migration', 'on', false);

alter table app.ticket
  add column complaint_date date,
  add column customer_wish text,
  add column root_cause text,
  add column compensation_note text;
comment on column app.ticket.complaint_date is 'Ngày xảy ra việc bị khiếu nại (chỉ khiếu nại).';
comment on column app.ticket.customer_wish is 'Mong muốn của khách (chỉ khiếu nại).';
comment on column app.ticket.root_cause is 'Nguyên nhân gốc, người xử lý ghi (chỉ khiếu nại).';
comment on column app.ticket.compensation_note is 'Bồi hoàn: ghi chú bằng chữ, KHÔNG phải số tiền và không sinh phiếu chi (nhóm tiền chưa làm).';
-- Không thêm chỉ mục: bốn cột chỉ đọc theo mã ticket, không lọc, không sắp xếp.

alter table app.ticket_event drop constraint ticket_event_event_type_check;
alter table app.ticket_event add constraint ticket_event_event_type_check
  check (event_type in ('TAO', 'GIAO', 'DOI_TRANG_THAI', 'DOI_NHOM_CON', 'DOI_MUC_DO', 'GHI_CHU', 'SUA_KHIEU_NAI'));

-- app.update_ticket_complaint(mã ticket, dữ liệu): sửa phần «Riêng khiếu nại»: người bị khiếu nại, ngày xảy ra, mong muốn, nguyên nhân gốc, bồi hoàn (chữ).
-- Ai gọi: Ticket · Sửa ở cơ sở của ticket. Khoá khi ticket đã đóng hoặc huỷ. Chỉ ticket loại Khiếu nại (AS-04). Ghi nhật ký SUA_KHIEU_NAI.
-- Dữ liệu (jsonb, khoá nào có mới đổi): accused_user_id, complaint_date, customer_wish, root_cause, compensation_note.
create or replace function app.update_ticket_complaint(p_id uuid, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_accused uuid;
begin
  select * into t from app.ticket where id = p_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ticket.');
  end if;
  perform app.require_feature('AFTERSALE', t.branch_id);
  perform app.assert_can('TICKET', 'SUA', t.branch_id);
  -- Luật AS-04: phần riêng chỉ có ở khiếu nại.
  if t.ticket_type <> 'KN' then
    perform app.raise_error('HMT_TICKET_LOAI_SAI', 'Phần riêng này chỉ có ở ticket khiếu nại.');
  end if;
  -- Luật AS-02: ticket đã đóng hoặc huỷ thì chỉ xem.
  if t.status_code in ('DA_DONG', 'DA_HUY') then
    perform app.raise_error('HMT_TICKET_TRANG_THAI_SAI', 'Ticket đã đóng hoặc đã huỷ, không sửa được.');
  end if;
  -- Luật AS-09: người bị khiếu nại phải là nhân sự đúng cơ sở.
  if p_data ? 'accused_user_id' then
    v_accused := nullif(p_data ->> 'accused_user_id', '')::uuid;
    if v_accused is not null then
      perform app.assert_staff_in_branch(v_accused, t.branch_id);
    end if;
  end if;
  update app.ticket set
    accused_user_id = case when p_data ? 'accused_user_id' then v_accused else accused_user_id end,
    complaint_date = case when p_data ? 'complaint_date' then nullif(p_data ->> 'complaint_date', '')::date else complaint_date end,
    customer_wish = case when p_data ? 'customer_wish' then nullif(btrim(p_data ->> 'customer_wish'), '') else customer_wish end,
    root_cause = case when p_data ? 'root_cause' then nullif(btrim(p_data ->> 'root_cause'), '') else root_cause end,
    compensation_note = case when p_data ? 'compensation_note' then nullif(btrim(p_data ->> 'compensation_note'), '') else compensation_note end
   where id = p_id;
  insert into app.ticket_event (ticket_id, branch_id, event_type) values (p_id, t.branch_id, 'SUA_KHIEU_NAI');
end;
$$;
revoke execute on function app.update_ticket_complaint(uuid, jsonb) from public, anon, authenticated;
grant execute on function app.update_ticket_complaint(uuid, jsonb) to authenticated;

-- app.get_ticket: thêm phần riêng khiếu nại, tính chất (ticket giáo viên) và danh sách ticket liên quan (con) trong một lần gọi.
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
      'response_due_at', t.response_due_at, 'first_response_at', t.first_response_at, 'resolved_at', t.resolved_at, 'closed_at', t.closed_at,
      'nature_code', (select c.nature_code from app.ticket_category c where c.code = t.category_code),
      'accused_user_id', t.accused_user_id, 'accused_name', app.staff_display_name(t.accused_user_id),
      'complaint_date', t.complaint_date, 'customer_wish', t.customer_wish, 'root_cause', t.root_cause, 'compensation_note', t.compensation_note),
    'children', coalesce((select jsonb_agg(app.ticket_row(c) order by c.created_at, c.id) from app.ticket c where c.related_ticket_id = t.id), '[]'::jsonb),
    'events', coalesce((select jsonb_agg(jsonb_build_object(
        'id', e.id, 'event_type', e.event_type, 'from_status', e.from_status, 'to_status', e.to_status, 'note', e.note,
        'created_at', e.created_at, 'created_by_name', app.staff_display_name(e.created_by)) order by e.seq)
      from app.ticket_event e where e.ticket_id = t.id), '[]'::jsonb));
end;
$$;

select set_config('hmt.migration', '', false);
