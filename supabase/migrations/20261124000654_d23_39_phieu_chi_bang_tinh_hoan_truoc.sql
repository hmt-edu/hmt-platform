-- D-23-39 (TC-11): bảng tính phiếu chi Hoàn toàn bộ không cộng khớp khi ghi danh đã có lần hoàn trước (compute_refund trừ tiền gốc các lần hoàn trước, migration 450).
-- Hàm đọc trả thêm used_amount (tiền giờ đã học × giá gốc, tính ở máy chủ) và prior_refund_amount (đã hoàn các lần trước = đã đóng − giờ đã học − còn lại),
-- để giao diện và bản in chỉ hiện số, không nhân tiền ở trình duyệt. Không đổi bảng, không đổi quyền: chỉ thêm hai khoá vào JSON.

create or replace function app.get_payment_voucher(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('RECEIPT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v app.payment_voucher;
  r app.refund_request;
  e app.enrollment;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phiếu chi.');
  end if;
  select * into v from app.payment_voucher where id = p_id;
  if v.id is null or not (v_scope = 'TOAN_HE_THONG' or v.branch_id = v_my_branch) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu chi.');
  end if;
  select * into r from app.refund_request where id = v.refund_request_id;
  select * into e from app.enrollment where id = r.enrollment_id;
  return jsonb_build_object(
    'voucher', jsonb_build_object(
      'id', v.id, 'code', v.code, 'status_code', v.status_code, 'amount', v.amount, 'pay_note', v.pay_note,
      'planned_on', v.planned_on, 'payout_account_note', case when app.has_permission('ACCOUNTING', 'DUYET') then v.payout_account_note end,
      'payment_method_code', v.payment_method_code,
      'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = v.payment_method_code),
      'created_at', v.created_at, 'paid_at', v.paid_at, 'created_by_name', app.staff_display_name(v.created_by),
      'paid_by_name', app.staff_display_name(v.paid_by),
      'branch_code', (select b.code from app.branch b where b.id = v.branch_id),
      'parent_id', v.parent_id,
      'parent_code', (select p.code from app.parent p where p.id = v.parent_id),
      'parent_name', (select p.full_name from app.parent p where p.id = v.parent_id),
      'can_pay', v.status_code = 'CHO_CHI' and app.has_permission('ACCOUNTING', 'DUYET')),
    'refund', jsonb_build_object(
      'id', r.id, 'kind_code', r.kind_code, 'reason_code', r.reason_code, 'note', r.note, 'ticket_ref', r.ticket_ref,
      'hours_refund', r.hours_refund, 'paid_amount', r.paid_amount, 'hours_used', r.hours_used,
      -- Tiền giờ đã học (giá gốc) và tiền gốc các lần hoàn trước, suy từ số đã chụp lúc tạo để bảng tính cộng khớp (R-TIEN-28, sửa T1).
      'used_amount', round(r.hours_used * r.unit_price_base)::bigint,
      'prior_refund_amount', case when r.kind_code = 'TOAN_BO'
        then greatest(r.paid_amount - round(r.hours_used * r.unit_price_base)::bigint - r.base_amount, 0) else 0 end,
      'unit_price_base', r.unit_price_base, 'unit_price_net', r.unit_price_net, 'base_amount', r.base_amount,
      'fee_percent', r.fee_percent, 'fee_amount', r.fee_amount, 'refund_amount', r.refund_amount),
    'enrollment', jsonb_build_object(
      'id', e.id, 'code', e.code, 'status_code', e.status_code,
      'student_name', (select s.full_name from app.student s where s.id = e.student_id)));
end;
$$;
