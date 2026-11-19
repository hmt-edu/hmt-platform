-- E60 / CHUNG-20 (anh Trường duyệt 19/11/2026, phương án A): «Huỷ lead nhập nhầm», chỉ Admin, chỉ áp cho LEAD.
-- Không xoá cứng (CLAUDE.md): thêm giá trị record_status = 'DA_HUY' riêng cho lead (cơ hội, phụ huynh, học sinh không đổi).
-- Lead huỷ: ẩn khỏi danh sách mặc định (mọi danh sách đang lọc record_status = 'DANG_DUNG'), không tính trùng SĐT
-- (hàm dò trùng đang lọc 'DANG_DUNG'), không sửa được, không tạo cơ hội hay lịch hẹn mới (trigger bên dưới).
-- Mọi lần huỷ ghi audit_log (trigger audit sẵn có trên app.lead) và một ghi chú hệ thống trên lead.

-- Luật: giá trị trạng thái bản ghi của lead thêm DA_HUY; lý do và người huỷ đi kèm.
alter table app.lead drop constraint lead_record_status_check;
alter table app.lead add constraint lead_record_status_check check (record_status in ('DANG_DUNG', 'DA_GOP', 'DA_HUY'));
alter table app.lead
  add column cancel_reason text,
  add column cancelled_at timestamptz,
  add column cancelled_by uuid references app.user_account (id);
alter table app.lead add constraint lead_cancel_fields_check check (
  (record_status = 'DA_HUY') = (cancel_reason is not null and cancelled_at is not null and cancelled_by is not null)
);
-- Chỉ mục: thống kê và chip lọc «Đã huỷ» của Admin (chỉ vài dòng, nên chỉ mục một phần).
create index lead_cancelled_idx on app.lead (cancelled_at desc) where record_status = 'DA_HUY';

-- Luật: lead đã huỷ chỉ xem, không cho sửa (kể cả gộp trùng hay đổi giai đoạn). Chạy trước các trigger khác của lead.
create or replace function app.tg_lead_da_huy_chi_xem()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.record_status = 'DA_HUY' then
    perform app.raise_error('HMT_LEAD_DA_HUY', 'Lead này đã huỷ vì nhập nhầm, chỉ xem được.');
  end if;
  return new;
end;
$$;
create trigger lead_a_da_huy_chi_xem before update on app.lead
  for each row execute function app.tg_lead_da_huy_chi_xem();

-- Luật: không tạo cơ hội hay lịch hẹn mới cho lead đã huỷ (chặn ở bảng nên mọi hàm đều bị chặn).
create or replace function app.tg_chan_lead_da_huy()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.lead_id is not null and exists (select from app.lead where id = new.lead_id and record_status = 'DA_HUY') then
    perform app.raise_error('HMT_LEAD_DA_HUY', 'Lead này đã huỷ vì nhập nhầm, không tạo thêm cơ hội hay lịch hẹn được.');
  end if;
  return new;
end;
$$;
create trigger opportunity_chan_lead_da_huy before insert on app.opportunity
  for each row execute function app.tg_chan_lead_da_huy();
create trigger appointment_chan_lead_da_huy before insert on app.appointment
  for each row execute function app.tg_chan_lead_da_huy();

-- app.cancel_wrong_lead: huỷ một lead nhập nhầm.
-- Ai gọi: Admin (quyền ADMIN·TAO, như các hàm Admin khác). Vào: p_id lead, p_reason lý do (bắt buộc). Ra: jsonb {id, code}.
-- Luật: chỉ lead Đang dùng; lead đã có cơ hội hoặc lịch hẹn thì chặn (nêu số lượng); lý do bắt buộc; ghi nhật ký + ghi chú.
create or replace function app.cancel_wrong_lead(p_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lead app.lead;
  v_reason text := btrim(coalesce(p_reason, ''));
  v_opp integer;
  v_appt integer;
begin
  -- Luật: chỉ Admin.
  if not app.has_permission('ADMIN', 'TAO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ Admin được huỷ lead nhập nhầm.');
  end if;
  -- Luật: lý do bắt buộc.
  if v_reason = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Cần ghi lý do huỷ lead.');
  end if;
  select * into v_lead from app.lead where id = p_id for update;
  if v_lead.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead.');
  end if;
  -- Luật: chỉ huỷ lead đang dùng (đã gộp hoặc đã huỷ thì không).
  if v_lead.record_status <> 'DANG_DUNG' then
    perform app.raise_error('HMT_LEAD_KHONG_HUY_DUOC', 'Lead này đã gộp hoặc đã huỷ, không huỷ được nữa.');
  end if;
  -- Luật: đã có cơ hội (phiếu kiểm tra, báo giá, đơn đều đi qua cơ hội) thì không phải lead nhập nhầm.
  select count(*) into v_opp from app.opportunity where lead_id = p_id;
  if v_opp > 0 then
    perform app.raise_error('HMT_LEAD_CO_CO_HOI', format('Lead đã có %s cơ hội nên không huỷ được.', v_opp));
  end if;
  -- Luật: đã có lịch hẹn thì chặn (kể cả lịch đã làm hay đã huỷ: là dấu vết chăm sóc).
  select count(*) into v_appt from app.appointment where lead_id = p_id;
  if v_appt > 0 then
    perform app.raise_error('HMT_LEAD_CO_LICH_HEN', format('Lead đã có %s lịch hẹn nên không huỷ được.', v_appt));
  end if;
  -- Việc huỷ: đổi trạng thái, không xoá.
  update app.lead
     set record_status = 'DA_HUY', cancel_reason = v_reason, cancelled_at = now(), cancelled_by = auth.uid()
   where id = p_id;
  perform app.add_note('LEAD', p_id, 'Huỷ lead nhập nhầm: ' || v_reason);
  return jsonb_build_object('id', p_id, 'code', v_lead.code);
end;
$$;
revoke execute on function app.cancel_wrong_lead(uuid, text) from public, anon;
grant execute on function app.cancel_wrong_lead(uuid, text) to authenticated;
