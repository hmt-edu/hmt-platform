-- Migration 456 (Code D, 18/11/2026): sửa T5 của Soát (CAO) trong app.compute_stop_balance (migration 232).
-- Lỗi: dừng học sau khi hoàn một phần: giờ mua đã hoàn vẫn tính vào số dư (giờ tặng thành tiền; chi + số dư vượt tiền đã thu).
-- Sửa: giờ mua còn lại để quy số dư = giờ mua đã cấp − giờ đã học − giờ đã hoàn một phần (duyệt, chi), tối đa giờ còn lại; giờ tặng không thành tiền.
-- Chỉ đổi thân hàm, chữ ký giữ nguyên.

create or replace function app.compute_stop_balance(p_enrollment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  l app.sales_order_line;
  v_left numeric;
  v_granted numeric;
  v_used numeric;
  v_paid_left numeric;
  v_net numeric;
  v_refunded numeric;
begin
  select * into e from app.enrollment where id = p_enrollment_id;
  select * into l from app.sales_order_line where id = e.order_line_id;
  if l.id is null then
    perform app.raise_error('HMT_DUNG_HOC_KHONG_CO_DON', 'Ghi danh này không có dòng đơn nên chưa tính được số dư (cần giá).');
  end if;
  v_left := greatest(app.enrollment_hours_balance(e.id), 0);
  select coalesce(sum(g.hours), 0) into v_granted from app.hour_ledger g where g.enrollment_id = e.id and g.entry_type in ('CAP_MUA', 'DAU_KY');
  select coalesce(sum(-g.hours), 0) into v_used from app.hour_ledger g where g.enrollment_id = e.id and g.entry_type = 'TRU_BUOI';
  -- Luật R-GD-16: giờ tặng còn lại bị huỷ, không quy ra tiền; coi giờ tặng được dùng sau cùng.
  -- Sửa T5 (R-TIEN-28, R-GD-16): giờ mua đã hoàn một phần (yêu cầu hoàn phí đã duyệt, đã chi) không còn để quy thành số dư, nếu không tiền bị trả hai lần.
  select coalesce(sum(r.hours_refund), 0) into v_refunded
    from app.refund_request r where r.enrollment_id = e.id and r.kind_code = 'MOT_PHAN' and r.status_code in ('DA_DUYET', 'DA_CHI');
  v_paid_left := greatest(least(v_granted - v_used - v_refunded, v_left), 0);
  v_net := l.line_total::numeric / l.quantity;
  return jsonb_build_object('hours_left', v_left, 'hours_paid_left', v_paid_left, 'hours_cancelled', v_left - v_paid_left,
                            'unit_price_net', round(v_net, 2), -- allow-number: làm tròn 2 chữ số thập phân của đơn giá
                            'balance_amount', round(v_paid_left * v_net)::bigint);
end;
$$;
