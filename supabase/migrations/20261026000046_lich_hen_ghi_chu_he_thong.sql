-- ===========================================================================
-- Lịch hẹn: Hoàn thành, Mở lại, Huỷ ghi một dòng vào dòng thời gian của hồ sơ gắn (lead, cơ hội hoặc phiếu kiểm tra).
-- R-CRM-04: Hoàn thành, Huỷ, Mở lại "ghi lịch sử"; hiện chỉ có Dời (R-CRM-38 c) ghi dòng lên hồ sơ. Không đổi giai đoạn,
-- không tạo việc, không gửi thông báo (R-CRM-04 giữ nguyên). Hành vi nghiệp vụ khác của ba hàm giữ nguyên.
-- ===========================================================================

-- Ghi một dòng hệ thống lên hồ sơ gắn của lịch hẹn. Hàm nội bộ cho các hàm lịch hẹn.
create or replace function app.add_appointment_note(p_appt app.appointment, p_text text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type text := case when p_appt.lead_id is not null then 'LEAD' when p_appt.opportunity_id is not null then 'OPPORTUNITY'
                      else 'STUDENT_TEST' end;
  v_id uuid := coalesce(p_appt.lead_id, p_appt.opportunity_id, p_appt.student_test_id);
begin
  perform app.add_system_note(v_type, v_id, p_text);
end;
$$;
revoke execute on function app.add_appointment_note(app.appointment, text) from public, anon, authenticated;

-- Hoàn thành: ghi "Hoàn thành lịch hẹn …".
create or replace function app.complete_appointment(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt app.appointment := app.appointment_for_update(p_id, 'SUA');
begin
  if v_appt.status <> 'CHUA_LAM' then
    perform app.raise_error('HMT_LICH_HEN_TRANG_THAI_SAI', 'Chỉ hoàn thành được lịch hẹn chưa làm.');
  end if;
  update app.appointment set status = 'HOAN_THANH', completed_at = now(), completed_by = auth.uid() where id = p_id;
  -- Luật R-CRM-04: ghi lịch sử, không đổi giai đoạn, không tạo việc, không báo ai.
  perform app.add_appointment_note(v_appt, format('Hoàn thành lịch hẹn "%s" (hẹn lúc %s).', v_appt.title,
    to_char(v_appt.scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI')));
end;
$$;

-- Mở lại: ghi "Mở lại lịch hẹn …" kèm trạng thái trước đó.
create or replace function app.reopen_appointment(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt app.appointment := app.appointment_for_update(p_id, 'SUA');
begin
  if v_appt.status = 'CHUA_LAM' then
    perform app.raise_error('HMT_LICH_HEN_TRANG_THAI_SAI', 'Lịch hẹn này chưa làm, không cần mở lại.');
  end if;
  update app.appointment
     set status = 'CHUA_LAM', cancel_reason_code = null, cancel_note = null,
         completed_at = null, completed_by = null, cancelled_at = null, cancelled_by = null,
         reopened_at = now(), reopened_by = auth.uid()
   where id = p_id;
  -- Luật R-CRM-04: mở lại ghi lịch sử, không đổi giai đoạn, không tạo việc, không báo ai.
  perform app.add_appointment_note(v_appt, format('Mở lại lịch hẹn "%s" (hẹn lúc %s), trước đó %s.', v_appt.title,
    to_char(v_appt.scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI'),
    case v_appt.status when 'HOAN_THANH' then 'đã hoàn thành' else 'đã huỷ' end));
end;
$$;

-- Huỷ: ghi "Huỷ lịch hẹn …" kèm lý do (danh mục 34) và ghi chú.
create or replace function app.cancel_appointment(p_id uuid, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt app.appointment := app.appointment_for_update(p_id, 'HUY');
  v_reason text;
  v_line text;
begin
  if v_appt.status <> 'CHUA_LAM' then
    perform app.raise_error('HMT_LICH_HEN_TRANG_THAI_SAI',
      'Chỉ huỷ được lịch hẹn chưa làm. Lịch đã hoàn thành phải mở lại trước.');
  end if;
  if p_reason_code is null then
    perform app.raise_error('HMT_THIEU_LY_DO', 'Chọn lý do huỷ lịch hẹn.');
  end if;
  perform app.assert_catalog_code_active('APPOINTMENT_CANCEL_REASON', p_reason_code);
  if (select requires_note from app.catalog_item
       where catalog_code = 'APPOINTMENT_CANCEL_REASON' and code = p_reason_code)
     and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_THIEU_GHI_CHU', 'Chọn "Khác" thì phải ghi chú lý do.');
  end if;
  update app.appointment
     set status = 'HUY', cancel_reason_code = p_reason_code, cancel_note = nullif(btrim(coalesce(p_note, '')), ''),
         cancelled_at = now(), cancelled_by = auth.uid()
   where id = p_id;
  -- Luật R-CRM-04: huỷ ghi lịch sử kèm lý do.
  select name into v_reason from app.catalog_item where catalog_code = 'APPOINTMENT_CANCEL_REASON' and code = p_reason_code;
  v_line := format('Huỷ lịch hẹn "%s" (hẹn lúc %s). Lý do: %s.', v_appt.title,
                   to_char(v_appt.scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI'), v_reason);
  if btrim(coalesce(p_note, '')) <> '' then
    v_line := v_line || format(' Ghi chú: %s', btrim(p_note));
  end if;
  perform app.add_appointment_note(v_appt, v_line);
end;
$$;
