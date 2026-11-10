-- Nối duyệt phiếu thu với ghi danh (R-TIEN-20, R-TIEN-21): app.approve_receipt_accounting gọi app.create_enrollments_for_order (migration 20261110000101)
-- sau khi phiếu thu thành Đã duyệt, cùng giao dịch. Thân hàm giữ nguyên bản migration 20261106000076, chỉ thêm một lệnh gọi.
-- Cần cho mốc 17/11: đơn bán mới tự sinh ghi danh.

-- app.approve_receipt_accounting(phiếu): kế toán duyệt (bước cuối). Ai gọi: người có quyền Kế toán · Duyệt (Admin không duyệt trực tiếp, R-HT-01).
-- Khi duyệt: sinh khoản tiền vào KTV (R-TIEN-01), chia tiền về các dòng của đơn (R-TIEN-22, 23). Kiểm lại số tiền không vượt phần còn thu được.
-- Thêm (migration 106, R-TIEN-20, R-TIEN-21): sau khi phiếu thành Đã duyệt thì tạo ghi danh cho đơn (app.create_enrollments_for_order) và cấp giờ theo tiền, trong cùng giao dịch.
create or replace function app.approve_receipt_accounting(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_o app.sales_order;
  v_code text;
  v_money uuid;
  v_branch_code text;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('ACCOUNTING', 'DUYET', r.branch_id);
  if r.status_code <> 'CHO_KE_TOAN' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt được phiếu thu Chờ kế toán.');
  end if;
  select * into v_o from app.sales_order where id = r.order_id for update;
  if r.amount > v_o.total_amount - app.order_paid_amount(v_o.id) then
    perform app.raise_error('HMT_SO_TIEN_VUOT', 'Số tiền phiếu vượt phần còn lại của đơn.');
  end if;
  select code into v_branch_code from app.branch where id = r.branch_id;
  v_code := app.issue_document_number('KTV', v_branch_code);
  insert into app.money_in (code, receipt_id, order_id, parent_id, branch_id, amount)
  values (v_code, r.id, r.order_id, r.parent_id, r.branch_id, r.amount)
  returning id into v_money;
  perform app.allocate_money_in(v_money, r.order_id, r.amount, r.target_line_id, r.branch_id);
  update app.receipt set status_code = 'DA_DUYET', accountant_approved_at = now(), accountant_approved_by = auth.uid() where id = p_id;
  perform app.receipt_add_event(p_id, 'DUYET_KT', 'CHO_KE_TOAN', 'DA_DUYET');
  -- Luật R-TIEN-20, R-TIEN-21: tổng tiền đã vào đạt tiền cọc tối thiểu thì tạo ghi danh cho các dòng giờ của đơn và cấp giờ theo tiền (sync_enrollment_hours).
  -- Hàm nội bộ tự bỏ qua khi chưa đủ cọc hoặc đơn chưa Đã duyệt; chạy lại không tạo trùng; lớp đầy thì vào hàng chờ xếp lớp, không chặn việc duyệt phiếu thu.
  perform app.create_enrollments_for_order(r.order_id);
  return jsonb_build_object('id', p_id, 'money_in_id', v_money, 'money_in_code', v_code,
                            'paid', app.order_paid_amount(v_o.id), 'remaining', v_o.total_amount - app.order_paid_amount(v_o.id));
end;
$$;
