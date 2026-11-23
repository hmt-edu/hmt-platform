-- D-23-22 (anh duyệt 23/11/2026 15:54; Chat chốt 16:04; migration 628; rủi ro VỪA). Hộp «Hoàn thành lịch hẹn» (TS-13): ghi KẾT QUẢ cuộc gọi khi hoàn thành lịch hẹn và tuỳ chọn HẸN LẦN SAU.
-- Làm gì: (1) danh mục mở APPOINTMENT_RESULT (6 mã seed, quản trị ở QT-07); (2) cột result_code, result_note, next_appointment_id trên app.appointment;
-- (3) tham số appointment_call_result_required (mặc định TẮT cho tới khi giao diện hộp mới lên: bật thì Gọi điện BẮT BUỘC có kết quả); (4) app.complete_appointment mở rộng (hàm cũ một tham số vẫn chạy: các tham số mới có mặc định);
-- (5) app.reopen_appointment xoá kết quả, ghi chú kết quả.
-- Luật: R-CRM-04 (hoàn thành không đổi giai đoạn, không tạo việc, không báo ai: «Đã chốt đăng ký» CHỈ là nhãn); lịch tự nhắc (is_auto_reminder) bỏ qua yêu cầu kết quả; ghi chú kết quả không bắt buộc.
-- Chỉ mục: không thêm (cột kết quả chưa dùng để lọc, sắp xếp; khi báo cáo lọc theo kết quả thì thêm (branch_id, result_code) kèm lý do).
select set_config('hmt.migration', 'on', false);

-- 1. Danh mục «Kết quả cuộc gọi» (kiểu mở, đổi tên được, không xoá).
insert into app.catalog (code, name, kind, description, sort_order)
select 'APPOINTMENT_RESULT', 'Kết quả cuộc gọi', 'MO', 'Kết quả khi hoàn thành lịch hẹn, nhất là cuộc gọi (TS-13); dùng cho báo cáo tuyển sinh.',
       (select coalesce(max(sort_order), 0) from app.catalog) + 1
where not exists (select from app.catalog where code = 'APPOINTMENT_RESULT');
insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('APPOINTMENT_RESULT', 'DA_TU_VAN_QUAN_TAM', 'Đã tư vấn, quan tâm', 1),
  ('APPOINTMENT_RESULT', 'HEN_GOI_LAI', 'Hẹn gọi lại', 2),
  ('APPOINTMENT_RESULT', 'KHONG_NGHE_MAY', 'Không nghe máy', 3),
  ('APPOINTMENT_RESULT', 'KHACH_TU_CHOI', 'Khách từ chối', 4),
  ('APPOINTMENT_RESULT', 'SAI_SO', 'Sai số', 5),
  ('APPOINTMENT_RESULT', 'DA_CHOT_DANG_KY', 'Đã chốt đăng ký', 6)
on conflict (catalog_code, code) do nothing;

-- 2. Cột trên lịch hẹn. Kết quả chỉ có khi Hoàn thành (mở lại thì xoá, như lý do huỷ).
alter table app.appointment
  add column result_catalog text not null default 'APPOINTMENT_RESULT' check (result_catalog = 'APPOINTMENT_RESULT'),
  add column result_code text,
  add column result_note text,
  add column next_appointment_id uuid references app.appointment (id),
  add constraint appointment_result_note_len check (result_note is null or char_length(result_note) <= 1000), -- allow-number: độ dài tối đa ghi chú kết quả
  add constraint appointment_result_only_done check (result_code is null or status = 'HOAN_THANH'),
  add constraint appointment_result_fk foreign key (result_catalog, result_code) references app.catalog_item (catalog_code, code);
comment on column app.appointment.result_code is 'Kết quả cuộc gọi (danh mục APPOINTMENT_RESULT), ghi khi Hoàn thành; mở lại thì xoá.';
comment on column app.appointment.next_appointment_id is 'Lịch hẹn kế do hộp Hoàn thành tạo (hẹn lần sau); giữ cả khi mở lại.';
-- Chỉ mục (lý do): khoá ngoại tới lịch hẹn kế, tra ngược lịch cha khi cần; thưa vì hầu hết lịch không có lịch kế.
create index appointment_next_idx on app.appointment (next_appointment_id) where next_appointment_id is not null;

-- 3. Tham số: bắt buộc kết quả với Gọi điện. TẮT mặc định cho tới khi hộp giao diện mới lên (Chat bật sau).
insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values ('appointment_call_result_required', 'Bắt buộc kết quả khi hoàn thành cuộc gọi', 'BOOL', null, null, null, 'false', false, 'BAN_HANG', 'R-CRM-04',
        'Bật: hoàn thành lịch hẹn loại Gọi điện phải chọn Kết quả cuộc gọi (lịch tự nhắc được bỏ qua). Tắt: kết quả tuỳ chọn.')
on conflict (key) do nothing;

-- 4. app.complete_appointment: hoàn thành lịch hẹn kèm kết quả và hẹn lần sau (tuỳ chọn).
-- Ai gọi: người có quyền Lịch hẹn · Sửa theo cơ sở của lịch. Đầu vào: p_result_code (danh mục APPOINTMENT_RESULT), p_result_note (tối đa 1000 ký tự),
-- p_next_at + p_next_activity_code + p_next_title (hẹn lần sau, cùng hồ sơ; loại hoạt động mặc định = loại lịch vừa làm; chủ = người hoàn thành; tiêu đề mặc định «Gọi lại: <tiêu đề cũ>»).
-- Lỗi: HMT_LICH_HEN_TRANG_THAI_SAI, HMT_THIEU_KET_QUA, HMT_KET_QUA_KHONG_HOP_LE, HMT_GHI_CHU_DAI, HMT_HEN_LAN_SAU_QUA_KHU, HMT_LICH_HEN_KHONG_HEN_LAN_SAU. Một giao dịch: lỗi thì không hoàn thành.
drop function app.complete_appointment(uuid);
create or replace function app.complete_appointment(
  p_id uuid, p_result_code text default null, p_result_note text default null,
  p_next_at timestamptz default null, p_next_activity_code text default null, p_next_title text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt app.appointment := app.appointment_for_update(p_id, 'SUA');
  v_result text := nullif(btrim(coalesce(p_result_code, '')), '');
  v_note text := nullif(btrim(coalesce(p_result_note, '')), '');
  v_next uuid;
  v_text text;
begin
  -- Luật R-CRM-04: chỉ hoàn thành lịch Chưa làm.
  if v_appt.status <> 'CHUA_LAM' then
    perform app.raise_error('HMT_LICH_HEN_TRANG_THAI_SAI', 'Chỉ hoàn thành được lịch hẹn chưa làm.');
  end if;
  -- Luật TS-13: Gọi điện phải có kết quả khi tham số bật; lịch tự nhắc bỏ qua.
  if v_result is null and v_appt.activity_code = 'GOI_DIEN' and not v_appt.is_auto_reminder
     and app.get_setting_bool('appointment_call_result_required', v_appt.branch_id) then
    perform app.raise_error('HMT_THIEU_KET_QUA', 'Chọn kết quả cuộc gọi trước khi hoàn thành.');
  end if;
  if v_result is not null and not exists (
       select from app.catalog_item c where c.catalog_code = 'APPOINTMENT_RESULT' and c.code = v_result and c.is_active) then
    perform app.raise_error('HMT_KET_QUA_KHONG_HOP_LE', 'Kết quả cuộc gọi không có trong danh mục.');
  end if;
  if v_note is not null and char_length(v_note) > 1000 then -- allow-number: độ dài tối đa ghi chú kết quả, trùng ràng buộc cột
    perform app.raise_error('HMT_GHI_CHU_DAI', 'Ghi chú kết quả quá dài.');
  end if;
  -- Luật: hẹn lần sau phải ở tương lai, gắn cùng hồ sơ (lead hoặc cơ hội); lịch gắn phiếu kiểm tra không có hồ sơ để hẹn tiếp.
  if p_next_at is not null then
    if p_next_at <= now() then
      perform app.raise_error('HMT_HEN_LAN_SAU_QUA_KHU', 'Hẹn lần sau phải sau thời điểm hiện tại.');
    end if;
    if v_appt.lead_id is null and v_appt.opportunity_id is null then
      perform app.raise_error('HMT_LICH_HEN_KHONG_HEN_LAN_SAU', 'Lịch hẹn này không gắn lead hoặc cơ hội nên không hẹn lần sau được.');
    end if;
    v_next := app.create_appointment(
      v_appt.lead_id, coalesce(nullif(btrim(coalesce(p_next_activity_code, '')), ''), v_appt.activity_code), p_next_at,
      coalesce(nullif(btrim(coalesce(p_next_title, '')), ''), 'Gọi lại: ' || v_appt.title), null, auth.uid(), v_appt.opportunity_id);
  end if;
  update app.appointment
     set status = 'HOAN_THANH', completed_at = now(), completed_by = auth.uid(),
         result_code = v_result, result_note = v_note, next_appointment_id = v_next
   where id = p_id;
  -- Luật R-CRM-04: ghi lịch sử, không đổi giai đoạn, không tạo việc, không báo ai.
  v_text := format('Hoàn thành lịch hẹn "%s" (hẹn lúc %s).', v_appt.title,
    to_char(v_appt.scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI'));
  if v_result is not null then
    v_text := v_text || format(' Kết quả: %s.', (select c.name from app.catalog_item c where c.catalog_code = 'APPOINTMENT_RESULT' and c.code = v_result));
  end if;
  if v_note is not null then
    v_text := v_text || format(' Ghi chú: %s.', v_note);
  end if;
  if v_next is not null then
    v_text := v_text || format(' Hẹn lần sau lúc %s.', to_char(p_next_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI'));
  end if;
  perform app.add_appointment_note(v_appt, v_text);
end;
$$;

revoke execute on function app.complete_appointment(uuid, text, text, timestamptz, text, text) from public, anon;
grant execute on function app.complete_appointment(uuid, text, text, timestamptz, text, text) to authenticated;

-- 5. app.reopen_appointment: như bản 046, thêm xoá kết quả và ghi chú kết quả (giữ next_appointment_id: lịch kế vẫn sống).
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
         result_code = null, result_note = null,
         reopened_at = now(), reopened_by = auth.uid()
   where id = p_id;
  -- Luật R-CRM-04: mở lại ghi lịch sử, không đổi giai đoạn, không tạo việc, không báo ai.
  perform app.add_appointment_note(v_appt, format('Mở lại lịch hẹn "%s" (hẹn lúc %s), trước đó %s.', v_appt.title,
    to_char(v_appt.scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'DD/MM/YYYY HH24:MI'),
    case v_appt.status when 'HOAN_THANH' then 'đã hoàn thành' else 'đã huỷ' end));
end;
$$;

select set_config('hmt.migration', '', false);
