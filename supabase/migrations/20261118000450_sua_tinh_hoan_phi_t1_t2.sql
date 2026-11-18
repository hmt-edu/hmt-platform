-- Migration 450 (Code D, 18/11/2026): sửa lỗi T1 và T2 của Soát trong app.compute_refund (migration 212).
-- T1: hoàn hai lần cho cùng một khoản tiền (hoàn một phần rồi hoàn toàn bộ): trừ tiền gốc các lần hoàn đã duyệt, đã chi; hoàn một phần đã bị chặn theo giờ còn lại nên không cần chặn thêm.
-- T2: giờ tặng thành tiền khi hoàn một phần: giờ hoàn tối đa là giờ còn lại trừ giờ tặng đã cấp (R-TIEN-28).
-- Chỉ đổi thân hàm, chữ ký giữ nguyên; hai hàm tạo yêu cầu và lõi kế toán (231, 235) gọi lại như cũ.
-- app.compute_refund(ghi danh, loại, giờ hoàn): tính tiền hoàn.
-- Loại 'TOAN_BO' (dừng hẳn, R-TIEN-28): hoàn = (tiền đã đóng − giờ đã học × giá gốc) − phí xử lý trên số còn lại; giá gốc bỏ chiết khấu lộ trình.
-- Loại 'MOT_PHAN' (R-TIEN-31): hoàn = giờ hoàn × giá sau chiết khấu − phí xử lý trên số đó; giờ hoàn không quá giờ còn lại.
-- Giờ tặng không hoàn (R-TIEN-28). Phí = `refund_processing_fee_percent` (theo cơ sở), làm tròn đồng.
-- Kết quả jsonb: paid_amount, hours_used, unit_price_base, unit_price_net, hours_refund, base_amount, fee_percent, fee_amount, refund_amount.
-- Lỗi: HMT_HOAN_PHI_KHONG_CO_DON (ghi danh không có dòng đơn nên không có giá), HMT_HOAN_PHI_LOAI_SAI,
--   HMT_HOAN_PHI_GIO_SAI (giờ hoàn không dương hoặc quá giờ còn lại), HMT_HOAN_PHI_KHONG_CON_TIEN (số hoàn không dương).
create or replace function app.compute_refund(p_enrollment_id uuid, p_kind text, p_hours_refund numeric default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  l app.sales_order_line;
  v_paid bigint;
  v_used numeric;
  v_left numeric;
  v_fee_percent numeric;
  v_net numeric;
  v_hours numeric;
  v_base numeric;
  v_fee bigint;
  v_refund bigint;
  v_prior_base bigint;
  v_gift numeric;
  v_cap numeric;
begin
  select * into e from app.enrollment where id = p_enrollment_id;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  if p_kind not in ('TOAN_BO', 'MOT_PHAN') then
    perform app.raise_error('HMT_HOAN_PHI_LOAI_SAI', 'Loại hoàn phí không hợp lệ: chọn hoàn toàn bộ hoặc hoàn một phần.');
  end if;
  select * into l from app.sales_order_line where id = e.order_line_id;
  if l.id is null then
    perform app.raise_error('HMT_HOAN_PHI_KHONG_CO_DON', 'Ghi danh này không có dòng đơn nên chưa tính được tiền hoàn (cần giá).');
  end if;
  select coalesce(sum(a.amount), 0) into v_paid from app.money_in_allocation a where a.order_line_id = l.id;
  -- Giờ đã học: tổng giờ trừ theo buổi Done (R-GIO-04), giờ tặng cũng được dùng nên đã nằm trong số này.
  select coalesce(sum(-g.hours), 0) into v_used from app.hour_ledger g where g.enrollment_id = e.id and g.entry_type = 'TRU_BUOI';
  v_left := app.enrollment_hours_balance(e.id);
  -- Sửa T1 (R-TIEN-28, R-TIEN-31): tiền gốc của các lần hoàn trước đã duyệt hoặc đã chi cho cùng ghi danh không được hoàn lần nữa.
  select coalesce(sum(r.base_amount), 0) into v_prior_base
    from app.refund_request r where r.enrollment_id = e.id and r.status_code in ('DA_DUYET', 'DA_CHI');
  -- Sửa T2 (R-TIEN-28 «Giờ tặng không hoàn»): giờ hoàn một phần không vượt giờ còn lại trừ phần giờ tặng đã cấp.
  select coalesce(sum(g.hours), 0) into v_gift from app.hour_ledger g where g.enrollment_id = e.id and g.entry_type = 'CAP_TANG';
  v_cap := greatest(v_left - v_gift, 0);
  v_fee_percent := app.get_setting('refund_processing_fee_percent', e.branch_id)::numeric;
  -- Giá sau chiết khấu mỗi giờ: thành tiền dòng ÷ số giờ mua (chiết khấu lộ trình đã nằm trong thành tiền).
  v_net := l.line_total::numeric / l.quantity;

  if p_kind = 'TOAN_BO' then
    -- Luật R-TIEN-28: tiền hoàn tính trên giá gốc, bỏ chiết khấu lộ trình; giờ tặng không hoàn.
    v_hours := greatest(v_left, 0);
    v_base := v_paid - v_used * l.unit_price - v_prior_base;
  else
    -- Luật R-TIEN-31: hoàn một phần = giờ hoàn × giá sau chiết khấu.
    v_hours := p_hours_refund;
    if v_hours is null or v_hours <= 0 or v_hours > v_cap then
      perform app.raise_error('HMT_HOAN_PHI_GIO_SAI', 'Giờ hoàn phải lớn hơn 0 và không quá số giờ còn lại (không tính giờ tặng).');
    end if;
    v_base := v_hours * v_net;
  end if;

  -- Phí xử lý tính trên số còn lại (R-TIEN-28), làm tròn đồng.
  v_fee := round(v_base * v_fee_percent / 100); -- allow-number: đổi phần trăm sang tỉ lệ
  v_refund := round(v_base)::bigint - v_fee;
  if v_refund <= 0 then
    perform app.raise_error('HMT_HOAN_PHI_KHONG_CON_TIEN', 'Không còn tiền để hoàn sau khi trừ giờ đã học và phí xử lý.');
  end if;

  return jsonb_build_object('paid_amount', v_paid, 'hours_used', v_used, 'unit_price_base', l.unit_price, 'unit_price_net', v_net,
                            'hours_refund', v_hours, 'base_amount', round(v_base)::bigint, 'fee_percent', v_fee_percent,
                            'fee_amount', v_fee, 'refund_amount', v_refund);
end;
$$;

revoke execute on function app.compute_refund(uuid, text, numeric) from public, anon, authenticated;
