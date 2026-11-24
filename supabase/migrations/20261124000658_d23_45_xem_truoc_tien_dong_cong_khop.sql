-- D-23-45: bảng «Số tiền dự kiến» của phiếu Dừng học, Hoàn học phí trả thêm các dòng đã học trừ, đã hoàn trước, còn lại, loại hoàn để người duyệt thấy số cộng khớp.
-- Chỉ thêm khoá vào JSON của app.preview_stop_task_money (migration 632); không đổi bảng, quyền, cách tính (R-TIEN-28, R-TIEN-31).

create or replace function app.preview_stop_task_money(p_task_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  v_enr uuid;
  v_bal jsonb;
  v_ref jsonb;
  v_ref_err text;
  v_kind text;
  v_hours numeric;
begin
  select * into k from app.ticket_task where id = p_task_id;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  -- Luật quyền: xem được phiếu của cơ sở mình (cùng mức với đọc phiếu).
  perform app.assert_can('TICKET', 'XEM', k.branch_id);
  if k.task_type not in ('DUNG_HOC', 'HOAN_PHI') then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Chỉ phiếu Dừng học hoặc Hoàn học phí có bảng tiền xem trước.');
  end if;
  v_enr := nullif(k.payload ->> 'enrollment_id', '')::uuid;
  if v_enr is null then
    perform app.raise_error('HMT_PHIEU_DU_LIEU_SAI', 'Phiếu thiếu ghi danh.');
  end if;

  if k.task_type = 'DUNG_HOC' then
    -- Luật R-GD-16, R-TIEN-33: số dư giữ = giờ mua còn lại × giá sau chiết khấu; giờ tặng còn lại huỷ.
    v_bal := app.compute_stop_balance(v_enr);
    -- Luật R-TIEN-28: hoàn toàn bộ; lỗi nghiệp vụ (không còn tiền hoàn…) trả về dạng mã, không làm hỏng trang phiếu.
    begin
      v_ref := app.compute_refund(v_enr, 'TOAN_BO');
    exception when others then
      get stacked diagnostics v_ref_err = pg_exception_hint;
      v_ref := null;
    end;
    return jsonb_build_object(
      'task_type', k.task_type, 'money_mode', coalesce(nullif(k.payload ->> 'money_mode', ''), 'GIU_SO_DU'),
      'hours_left', v_bal -> 'hours_left', 'hours_cancelled', v_bal -> 'hours_cancelled', 'unit_price_net', v_bal -> 'unit_price_net',
      'balance_amount', v_bal -> 'balance_amount',
      'paid_amount', v_ref -> 'paid_amount', 'fee_percent', v_ref -> 'fee_percent', 'fee_amount', v_ref -> 'fee_amount',
      'refund_amount', v_ref -> 'refund_amount', 'refund_error', case when v_ref is null then coalesce(v_ref_err, 'HMT_HOAN_PHI_KHONG_CON_TIEN') end,
      'refund_kind', 'TOAN_BO',
      'used_amount', round((v_ref ->> 'hours_used')::numeric * (v_ref ->> 'unit_price_base')::numeric)::bigint,
      'prior_refund_amount', greatest((v_ref ->> 'paid_amount')::bigint - round((v_ref ->> 'hours_used')::numeric * (v_ref ->> 'unit_price_base')::numeric)::bigint - (v_ref ->> 'base_amount')::bigint, 0),
      'base_amount', v_ref -> 'base_amount');
  end if;

  -- Phiếu Hoàn học phí: loại và giờ hoàn lấy từ payload của phiếu.
  v_kind := coalesce(nullif(k.payload ->> 'kind', ''), 'TOAN_BO');
  v_hours := nullif(k.payload ->> 'hours', '')::numeric;
  begin
    v_ref := app.compute_refund(v_enr, v_kind, v_hours);
  exception when others then
    get stacked diagnostics v_ref_err = pg_exception_hint;
    v_ref := null;
  end;
  return jsonb_build_object(
    'task_type', k.task_type, 'paid_amount', v_ref -> 'paid_amount', 'fee_percent', v_ref -> 'fee_percent', 'fee_amount', v_ref -> 'fee_amount',
    'unit_price_net', v_ref -> 'unit_price_net', 'refund_amount', v_ref -> 'refund_amount',
    'refund_error', case when v_ref is null then coalesce(v_ref_err, 'HMT_HOAN_PHI_KHONG_CON_TIEN') end,
    -- D-23-45: các dòng để bảng cộng khớp (cùng cách suy với phiếu chi, migration 654): hoàn toàn bộ = đã đóng − giờ đã học − đã hoàn trước = còn lại; hoàn một phần = giờ hoàn × giá sau chiết khấu.
    'refund_kind', v_kind, 'hours_refund', v_ref -> 'hours_refund', 'base_amount', v_ref -> 'base_amount',
    'used_amount', case when v_kind = 'TOAN_BO' then round((v_ref ->> 'hours_used')::numeric * (v_ref ->> 'unit_price_base')::numeric)::bigint end,
    'prior_refund_amount', case when v_kind = 'TOAN_BO' then greatest((v_ref ->> 'paid_amount')::bigint - round((v_ref ->> 'hours_used')::numeric * (v_ref ->> 'unit_price_base')::numeric)::bigint - (v_ref ->> 'base_amount')::bigint, 0) else 0 end);
end;
$$;
grant execute on function app.preview_stop_task_money(uuid) to authenticated;
