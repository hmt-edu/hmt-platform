-- Migration 459 (Code D, 18/11/2026): sửa T6 của Soát (CAO). Anh Trường chốt 18/11 15:31: hoàn phí và dừng học BẮT BUỘC qua ticket Aftersale
-- (ticket tồn tại, đúng nhóm, cùng học sinh); tạo thẳng không ticket chỉ giữ cho Kế toán kèm cờ. Luật: R-TIEN-28, R-GD-16, R-V2-24.
-- Làm gì: (1) cờ refund_direct_without_ticket_enabled (mặc định TẮT, theo cơ sở); (2) hàm app.assert_refund_ticket kiểm ticket; (3) create_refund_request và create_enrollment_stop
-- gọi hàm kiểm trước khi ghi (sau mọi kiểm cũ nên các mã lỗi cũ không đổi). Hàm apply_* (ticket_task, migration 235) không đổi: phiếu nghiệp vụ đã gắn ticket.
-- Lỗi mới: HMT_CAN_TICKET (thiếu ticket), HMT_TICKET_KHONG_TON_TAI, HMT_TICKET_SAI_LOAI (không phải Đề nghị đang mở), HMT_TICKET_SAI_NHOM (nhóm con không phải hoàn phí, dừng học),
-- HMT_TICKET_SAI_HOC_SINH, HMT_TICKET_SAI_CO_SO.

select set_config('hmt.migration', 'on', false);
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('refund_direct_without_ticket_enabled', 'Cho Kế toán tạo hoàn phí, dừng học không qua ticket', 'BOOL', null, null, null, 'false', true, 'BAN_HANG', 'R-V2-24',
   'Tắt (mặc định): hoàn phí và dừng học bắt buộc có ticket Aftersale Đề nghị đang mở, đúng nhóm, cùng học sinh. Bật: người có Kế toán · Duyệt ở cơ sở được tạo thẳng khi không nhập ticket (ghi lý do vào ghi chú).');
select set_config('hmt.migration', '', false);

-- app.assert_refund_ticket(mã ticket, học sinh, loại nghiệp vụ, cơ sở): kiểm ticket cho yêu cầu hoàn phí (HOAN_PHI) hoặc dừng học (DUNG_HOC). NỘI BỘ.
-- Mã ticket trống: chỉ qua được khi người gọi có Kế toán · Duyệt ở cơ sở và cờ refund_direct_without_ticket_enabled bật; còn lại HMT_CAN_TICKET.
-- Mã ticket có nhập: luôn kiểm đủ (kể cả Kế toán).
create or replace function app.assert_refund_ticket(p_ticket_ref text, p_student_id uuid, p_business_type text, p_branch_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.ticket;
  v_ref text := nullif(btrim(coalesce(p_ticket_ref, '')), '');
  v_biz text;
begin
  if v_ref is null then
    -- Luật R-V2-24 (T6): thiếu ticket thì chỉ Kế toán kèm cờ được tạo thẳng.
    if app.has_permission('ACCOUNTING', 'DUYET') and app.can_see_branch('ACCOUNTING', 'DUYET', p_branch_id)
       and app.get_setting_bool('refund_direct_without_ticket_enabled', p_branch_id) then
      return;
    end if;
    perform app.raise_error('HMT_CAN_TICKET', 'Hoàn phí và dừng học phải đi qua ticket Aftersale: nhập mã ticket Đề nghị đang mở của học sinh.');
  end if;
  select * into t from app.ticket where code = v_ref;
  if t.id is null then
    perform app.raise_error('HMT_TICKET_KHONG_TON_TAI', 'Không tìm thấy ticket ' || v_ref || '.');
  end if;
  if t.ticket_type <> 'DN' or t.status_code in ('DA_DONG', 'DA_HUY') then
    perform app.raise_error('HMT_TICKET_SAI_LOAI', 'Ticket phải là Đề nghị đang mở (chưa đóng, chưa huỷ).');
  end if;
  select c.business_type into v_biz from app.ticket_category c where c.code = t.category_code;
  if v_biz is distinct from p_business_type then
    perform app.raise_error('HMT_TICKET_SAI_NHOM', 'Nhóm của ticket không phải ' || case p_business_type when 'HOAN_PHI' then 'Hoàn học phí' else 'Dừng học' end || '.');
  end if;
  if t.student_id is distinct from p_student_id then
    perform app.raise_error('HMT_TICKET_SAI_HOC_SINH', 'Ticket không thuộc học sinh của ghi danh này.');
  end if;
  if t.branch_id <> p_branch_id then
    perform app.raise_error('HMT_TICKET_SAI_CO_SO', 'Ticket thuộc cơ sở khác với ghi danh.');
  end if;
end;
$$;
revoke execute on function app.assert_refund_ticket(text, uuid, text, uuid) from public, anon, authenticated;

-- app.create_refund_request: thân bản migration 231, thêm một lệnh kiểm ticket. Mọi luật khác giữ nguyên.
create or replace function app.create_refund_request(
  p_enrollment_id uuid, p_kind text, p_hours numeric, p_reason_code text, p_note text default null, p_ticket_ref text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v jsonb;
  v_id uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.assert_can('ENROLLMENT', 'SUA', e.branch_id);
  perform app.require_feature('HOAN_PHI', e.branch_id);
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_HOAN_PHI_GHI_DANH_SAI', 'Ghi danh này không còn hiệu lực để hoàn phí.');
  end if;
  perform app.assert_catalog_code_active('REFUND_REASON', p_reason_code);
  if exists (select from app.refund_request where enrollment_id = e.id and status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN', 'DA_DUYET')) then
    perform app.raise_error('HMT_HOAN_PHI_DANG_MO', 'Ghi danh này đã có một yêu cầu hoàn phí chưa xong.');
  end if;
  v := app.compute_refund(e.id, p_kind, p_hours);
  -- Luật R-V2-24 (T6): bắt buộc ticket Aftersale Hoàn học phí đúng học sinh (đặt sau các kiểm cũ để mã lỗi cũ không đổi).
  perform app.assert_refund_ticket(p_ticket_ref, e.student_id, 'HOAN_PHI', e.branch_id);
  insert into app.refund_request (enrollment_id, student_id, branch_id, kind_code, reason_code, note, ticket_ref,
                                  hours_refund, paid_amount, hours_used, unit_price_base, unit_price_net,
                                  base_amount, fee_percent, fee_amount, refund_amount)
  values (e.id, e.student_id, e.branch_id, p_kind, p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''),
          (v ->> 'hours_refund')::numeric, (v ->> 'paid_amount')::bigint, (v ->> 'hours_used')::numeric,
          (v ->> 'unit_price_base')::bigint, round((v ->> 'unit_price_net')::numeric, 2), -- allow-number: làm tròn 2 chữ số thập phân của đơn giá
          (v ->> 'base_amount')::bigint,
          (v ->> 'fee_percent')::numeric, (v ->> 'fee_amount')::bigint, (v ->> 'refund_amount')::bigint)
  returning id into v_id;
  return v_id;
end;
$$;

-- app.create_enrollment_stop: thân bản migration 232, thêm một lệnh kiểm ticket.
create or replace function app.create_enrollment_stop(p_enrollment_id uuid, p_reason_code text, p_note text default null, p_ticket_ref text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v jsonb;
  v_id uuid;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.assert_can('ENROLLMENT', 'SUA', e.branch_id);
  perform app.require_feature('DUNG_HOC', e.branch_id);
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_DUNG_HOC_GHI_DANH_SAI', 'Ghi danh này không còn hiệu lực để dừng học.');
  end if;
  perform app.assert_catalog_code_active('STOP_REASON', p_reason_code);
  -- Chưa kiểm chéo với yêu cầu Hoàn phí đang mở (bảng nằm ở migration 231); ghi danh sang Dừng/Hoàn phí khi duyệt nên yêu cầu thứ hai bị chặn ở bước duyệt.
  if exists (select from app.enrollment_stop where enrollment_id = e.id and status_code in ('NHAP', 'CHO_QL', 'CHO_KE_TOAN')) then
    perform app.raise_error('HMT_DUNG_HOC_DANG_MO', 'Ghi danh này đã có một yêu cầu dừng học chưa xong.');
  end if;
  v := app.compute_stop_balance(e.id);
  -- Luật R-V2-24 (T6): bắt buộc ticket Aftersale Dừng học đúng học sinh.
  perform app.assert_refund_ticket(p_ticket_ref, e.student_id, 'DUNG_HOC', e.branch_id);
  insert into app.enrollment_stop (enrollment_id, student_id, parent_id, branch_id, reason_code, note, ticket_ref,
                                   hours_left, hours_paid_left, hours_cancelled, unit_price_net, balance_amount)
  values (e.id, e.student_id, e.parent_id, e.branch_id, p_reason_code, nullif(btrim(p_note), ''), nullif(btrim(p_ticket_ref), ''),
          (v ->> 'hours_left')::numeric, (v ->> 'hours_paid_left')::numeric, (v ->> 'hours_cancelled')::numeric,
          (v ->> 'unit_price_net')::numeric, (v ->> 'balance_amount')::bigint)
  returning id into v_id;
  return v_id;
end;
$$;
