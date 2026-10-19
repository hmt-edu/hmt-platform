-- P3c-2: dữ liệu trang Lead (TS-02) và dời lịch hẹn (TS-13; docs/spec/04 R-CRM-04, R-CRM-38).
-- Gồm: get_lead (một lần gọi đủ thông tin trang bản ghi) và reschedule_appointment mở rộng (đổi người phụ trách, ghi chú).

-- ---------------------------------------------------------------------------
-- Đọc một lead cho trang bản ghi (TS-02). Ai gọi: người có quyền Lead · Xem ở cơ sở của lead (R-CRM-26 phạm vi cơ sở).
-- Đầu vào: id lead. Kết quả: các cột của lead (trừ cột tìm kiếm) kèm tên người phụ trách, người hỗ trợ, người tạo, người sửa,
-- cơ sở, chiến dịch, mã bản giữ lại (bản "Đã gộp", R-CRM-22), và ba số đếm cho nút liên kết: tổng lịch hẹn, lịch hẹn chưa làm,
-- cơ hội đang dùng. Cần hàm riêng vì người xem lead có thể không đọc được bảng tài khoản, chiến dịch để lấy tên.
-- security definer có chủ ý: quyền kiểm bên trong bằng app.assert_can.
-- ---------------------------------------------------------------------------
create or replace function app.get_lead(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v app.lead;
begin
  select * into v from app.lead where id = p_id;
  if v.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead.');
  end if;
  -- Luật: xem lead cần quyền Lead · Xem ở cơ sở của lead.
  perform app.assert_can('LEAD', 'XEM', v.branch_id);
  return (to_jsonb(v) - 'search_text') || jsonb_build_object(
    'owner_name', app.staff_display_name(v.owner_id),
    'supporter_name', app.staff_display_name(v.supporter_id),
    'created_by_name', app.staff_display_name(v.created_by),
    'updated_by_name', app.staff_display_name(v.updated_by),
    'branch_code', (select b.code from app.branch b where b.id = v.branch_id),
    'branch_name', (select b.name from app.branch b where b.id = v.branch_id),
    'campaign_name', (select c.name from app.campaign c where c.id = v.campaign_id),
    'merged_into_code', (select m.code from app.lead m where m.id = v.merged_into_id),
    'appointments_total', (select count(*) from app.appointment a where a.lead_id = v.id),
    'appointments_open', (select count(*) from app.appointment a where a.lead_id = v.id and a.status = 'CHUA_LAM'),
    'opportunities_total', (select count(*) from app.opportunity o where o.lead_id = v.id and o.record_status = 'DANG_DUNG'));
end;
$$;

-- ---------------------------------------------------------------------------
-- Dời lịch hẹn (R-CRM-38, R-CRM-04). Ai gọi: người có quyền Lịch hẹn · Sửa ở cơ sở của lịch hẹn.
-- Đầu vào: id lịch hẹn, giờ mới, người phụ trách mới (tuỳ chọn), ghi chú (tuỳ chọn).
-- Luật R-CRM-38: (a) chỉ lịch hẹn Chưa làm dời được; (b) đổi người phụ trách khi dời cần quyền Lịch hẹn · Giao việc (người
-- không có quyền thì không đổi được, vẫn dời giờ được nếu không truyền người khác), người mới là nhân sự đúng cơ sở;
-- (c) mọi thay đổi ghi lịch sử: nhật ký của lịch hẹn (giờ, người phụ trách) và MỘT ghi chú trên hồ sơ gắn (lead, cơ hội hoặc
-- phiếu) nêu giờ cũ, giờ mới, người phụ trách mới và ghi chú dời. Ghi chú dời không ghi đè cột note của lịch hẹn.
-- Bỏ hàm cũ hai tham số để lời gọi hai tham số không bị trùng với bản mới (các tham số thêm có giá trị mặc định).
-- ---------------------------------------------------------------------------
drop function app.reschedule_appointment(uuid, timestamptz);
create or replace function app.reschedule_appointment(
  p_id uuid, p_scheduled_at timestamptz, p_owner_id uuid default null, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt app.appointment := app.appointment_for_update(p_id, 'SUA');
  v_owner uuid := coalesce(p_owner_id, v_appt.owner_id);
  v_entity_type text;
  v_entity_id uuid;
  v_line text;
begin
  -- Luật R-CRM-38 (a): chỉ lịch hẹn Chưa làm dời được.
  if v_appt.status <> 'CHUA_LAM' then
    perform app.raise_error('HMT_LICH_HEN_TRANG_THAI_SAI', 'Chỉ dời được lịch hẹn chưa làm. Mở lại trước nếu cần dời.');
  end if;
  if p_scheduled_at is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ngày giờ mới của lịch hẹn.');
  end if;
  -- Luật R-CRM-38 (b): đổi người phụ trách cần quyền Giao việc; người mới thuộc đúng cơ sở của lịch hẹn.
  if v_owner <> v_appt.owner_id then
    perform app.assert_can('APPOINTMENT', 'GIAO_VIEC', v_appt.branch_id);
    perform app.assert_staff_in_branch(v_owner, v_appt.branch_id);
  end if;

  update app.appointment set scheduled_at = p_scheduled_at, owner_id = v_owner where id = p_id;

  -- Luật R-CRM-38 (c): ghi chú dời trên hồ sơ gắn (nhật ký của lịch hẹn đã tự ghi giờ và người phụ trách).
  select case when v_appt.lead_id is not null then 'LEAD' when v_appt.opportunity_id is not null then 'OPPORTUNITY'
              else 'STUDENT_TEST' end,
         coalesce(v_appt.lead_id, v_appt.opportunity_id, v_appt.student_test_id)
    into v_entity_type, v_entity_id;
  v_line := format('Dời lịch hẹn "%s" từ %s sang %s.', v_appt.title,
                   to_char(v_appt.scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI'),
                   to_char(p_scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI'));
  if v_owner <> v_appt.owner_id then
    v_line := v_line || format(' Người phụ trách mới: %s.', app.staff_display_name(v_owner));
  end if;
  if btrim(coalesce(p_note, '')) <> '' then
    v_line := v_line || format(' Ghi chú: %s', btrim(p_note));
  end if;
  perform app.add_system_note(v_entity_type, v_entity_id, v_line);
end;
$$;

revoke execute on function app.get_lead(uuid), app.reschedule_appointment(uuid, timestamptz, uuid, text) from public, anon;
grant execute on function app.get_lead(uuid), app.reschedule_appointment(uuid, timestamptz, uuid, text) to authenticated;
