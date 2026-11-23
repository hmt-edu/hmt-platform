-- D-23-26 (Chat giao 23/11/2026 17:20; migration 632; rủi ro CAO: tiền). Phiếu Dừng học / Hoàn học phí: người duyệt (Trưởng cơ sở, Kế toán) thấy SỐ TIỀN sẽ hoàn hoặc sẽ đổi thành số dư ngay trên phiếu.
-- Làm gì: app.preview_stop_task_money(p_task_id) CHỈ ĐỌC, không ghi gì. Phiếu DUNG_HOC: trả cả hai cách xử lý và đánh dấu cách phiếu đã chọn (money_mode).
--   GIU_SO_DU = giờ mua còn lại × giá sau chiết khấu chụp lúc mua (app.compute_stop_balance, cùng nguồn với lúc thực hiện); giờ tặng còn lại huỷ, không thành tiền.
--   HOAN_TIEN = hoàn toàn bộ theo giá gốc, trừ phí xử lý (app.compute_refund 'TOAN_BO', cùng nguồn với apply_refund_request); không tính được (không còn tiền hoàn…) thì refund_error ghi mã lỗi, không chặn xem phiếu.
--   Phiếu HOAN_PHI: trả refund_amount của chính phiếu theo loại và giờ hoàn trong payload.
-- Ai: người xem được phiếu theo cơ sở: Ticket · Xem (cơ sở của phiếu). Số liệu tính lại lúc xem theo dữ liệu hiện tại; lúc thực hiện hệ thống tính lại và dùng số lúc đó (R-TIEN-28, R-TIEN-33), nên số xem trước là tham khảo.
-- Luật: R-TIEN-28, R-TIEN-33, R-GD-16, R-CS-02. Chỉ mục: không thêm (không bảng, cột mới; đọc theo khoá chính).
select set_config('hmt.migration', 'on', false);

-- app.preview_stop_task_money: bảng tiền xem trước của phiếu Dừng học hoặc Hoàn học phí. Đầu vào: id phiếu. Kết quả jsonb:
--   task_type, money_mode (chỉ Dừng học), hours_left, hours_cancelled, unit_price_net,
--   balance_amount (số dư giữ nếu Giữ số dư), paid_amount, fee_percent, fee_amount, refund_amount (số hoàn nếu Hoàn tiền; null khi không tính được), refund_error (mã lỗi khi null).
-- Lỗi: HMT_KHONG_TIM_THAY (không có phiếu), HMT_KHONG_CO_QUYEN, HMT_PHIEU_DU_LIEU_SAI (phiếu không phải Dừng học, Hoàn học phí).
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
      'refund_amount', v_ref -> 'refund_amount', 'refund_error', case when v_ref is null then coalesce(v_ref_err, 'HMT_HOAN_PHI_KHONG_CON_TIEN') end);
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
    'refund_error', case when v_ref is null then coalesce(v_ref_err, 'HMT_HOAN_PHI_KHONG_CON_TIEN') end);
end;
$$;
grant execute on function app.preview_stop_task_money(uuid) to authenticated;
