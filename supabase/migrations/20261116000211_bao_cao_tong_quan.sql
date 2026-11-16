-- Migration 211 (Code D, 16/11/2026): hàm đọc báo cáo tổng quan Ban giám đốc BC-01 (R-BC-01, 02, 04, 05).
-- Chỉ đọc, không bảng mới. Tỉ lệ tái tục (R-BC-03) để sau: chưa có bảng phiếu tái tục trên main.
-- Quyết định tạm của Code D (chờ Chat xác nhận, ghi trong code-d.md và docs/nghiep-vu/bao-cao-tong-quan.md):
--   (1) Đơn giá ghi nhận = tiền ĐÃ THU của dòng đơn ÷ (giờ mua + giờ tặng) (R-BC-05: «bằng đúng tiền đã thu»).
--   (2) Ghi danh không có dòng đơn (nạp từ hệ thống cũ) không có giá: doanh thu 0 đ, đếm riêng ở `hours_without_price`.

-- Đơn giá ghi nhận (đồng mỗi giờ, chưa làm tròn) của từng ghi danh có dòng đơn và có giờ (R-BC-04).
create or replace function app.enrollment_recognized_prices()
returns table (enrollment_id uuid, unit_price numeric)
language sql
stable
security definer
set search_path = ''
as $$
  select e.id,
         coalesce(sum(a.amount), 0)::numeric / nullif(e.purchased_hours + e.gifted_hours, 0)
    from app.enrollment e
    join app.money_in_allocation a on a.order_line_id = e.order_line_id
   group by e.id, e.purchased_hours, e.gifted_hours;
$$;

-- app.report_overview(từ, đến, cơ sở): số liệu tổng quan Ban giám đốc.
-- Ai gọi: quyền Báo cáo · Xem. Phạm vi Toàn hệ thống thấy mọi cơ sở (hoặc chọn một); phạm vi Cơ sở chỉ thấy cơ sở của mình.
-- Đầu vào: khoảng ngày (theo giờ Việt Nam), cơ sở (trống = mọi cơ sở được xem).
-- Kết quả jsonb: students_active, students_on_hold (R-BC-02), revenue_recognized, revenue_hours (R-BC-04),
--   hours_without_price, cash_received, hours_fund_value, hours_fund_hours (R-BC-05).
-- Lưu ý R-BC-02: «đang học» đọc tình trạng ghi danh HIỆN TẠI (chưa có lịch sử tình trạng theo ngày); as_of ghi ngày đọc.
create or replace function app.report_overview(p_from date, p_to date, p_branch_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('REPORT', 'XEM');
  v_branch uuid := p_branch_id;
  v_active integer;
  v_hold integer;
  v_revenue bigint;
  v_rev_hours numeric;
  v_no_price numeric;
  v_cash bigint;
  v_fund bigint;
  v_fund_hours numeric;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem báo cáo.');
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    perform app.raise_error('HMT_BAO_CAO_KHOANG_NGAY_SAI', 'Khoảng ngày không hợp lệ: ngày đến phải sau hoặc bằng ngày từ.');
  end if;
  -- Phạm vi: chỉ Toàn hệ thống được chọn cơ sở tuỳ ý; phạm vi hẹp hơn bị khoá vào cơ sở của mình.
  if v_scope <> 'TOAN_HE_THONG' then
    if v_branch is not null and v_branch <> (select app.current_branch_id()) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn chỉ xem được báo cáo của cơ sở mình.');
    end if;
    v_branch := (select app.current_branch_id());
  end if;

  -- Luật R-BC-02: học sinh đang học = số em có ít nhất một ghi danh Đang học; em bảo lưu đếm riêng, không cộng vào.
  select count(distinct e.student_id) filter (where e.status_code = 'DANG_HOC'),
         count(distinct e.student_id) filter (where e.status_code = 'BAO_LUU'
                                               and not exists (select from app.enrollment x
                                                                where x.student_id = e.student_id and x.status_code = 'DANG_HOC'))
    into v_active, v_hold
    from app.enrollment e
   where v_branch is null or e.branch_id = v_branch;

  -- Luật R-BC-04: doanh thu ghi nhận = giờ trừ của buổi Done (kể cả huỷ có tính phí) × đơn giá ghi nhận,
  -- tính cho cơ sở nơi buổi diễn ra (R-GD-10). Học bù, học bổ trợ ghi nhận 0 đ (không có dòng trừ giờ).
  select coalesce(round(sum(-l.hours * p.unit_price)), 0)::bigint, coalesce(sum(-l.hours), 0)
    into v_revenue, v_rev_hours
    from app.hour_ledger l
    join app.class_session s on s.id = l.session_id
    join app.enrollment_recognized_prices() p on p.enrollment_id = l.enrollment_id
   where l.entry_type = 'TRU_BUOI'
     and s.type_code in ('CHINH', 'CUNG_CO')
     and s.session_date between p_from and p_to
     and (v_branch is null or s.branch_id = v_branch);

  -- Giờ đã trừ nhưng ghi danh không có giá (nạp từ hệ thống cũ): đếm riêng để không bịa số.
  select coalesce(sum(-l.hours), 0)
    into v_no_price
    from app.hour_ledger l
    join app.class_session s on s.id = l.session_id
   where l.entry_type = 'TRU_BUOI'
     and s.type_code in ('CHINH', 'CUNG_CO')
     and s.session_date between p_from and p_to
     and (v_branch is null or s.branch_id = v_branch)
     and not exists (select from app.enrollment_recognized_prices() p where p.enrollment_id = l.enrollment_id);

  -- Tiền đã thu trong khoảng (khoản tiền vào, kể cả khoản âm do đảo, R-TIEN-26), ngày theo giờ Việt Nam.
  select coalesce(sum(m.amount), 0)::bigint
    into v_cash
    from app.money_in m
   where (m.created_at at time zone 'Asia/Ho_Chi_Minh')::date between p_from and p_to
     and (v_branch is null or m.branch_id = v_branch);

  -- Luật R-BC-05: quỹ giờ còn quy ra tiền = tổng (giờ còn của từng ghi danh còn hiệu lực × đơn giá ghi nhận).
  select coalesce(round(sum(b.hours_left * p.unit_price)), 0)::bigint, coalesce(sum(b.hours_left), 0)
    into v_fund, v_fund_hours
    from (select e.id, e.branch_id, app.enrollment_hours_balance(e.id) hours_left
            from app.enrollment e
           where e.status_code in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU')
             and (v_branch is null or e.branch_id = v_branch)) b
    join app.enrollment_recognized_prices() p on p.enrollment_id = b.id
   where b.hours_left > 0;

  return jsonb_build_object(
    'as_of', current_date, 'from', p_from, 'to', p_to, 'branch_id', v_branch,
    'students_active', v_active, 'students_on_hold', v_hold,
    'revenue_recognized', v_revenue, 'revenue_hours', v_rev_hours, 'hours_without_price', v_no_price,
    'cash_received', v_cash, 'hours_fund_value', v_fund, 'hours_fund_hours', v_fund_hours);
end;
$$;

revoke execute on function app.enrollment_recognized_prices() from public, anon, authenticated;
revoke execute on function app.report_overview(date, date, uuid) from public, anon;
grant execute on function app.report_overview(date, date, uuid) to authenticated;
