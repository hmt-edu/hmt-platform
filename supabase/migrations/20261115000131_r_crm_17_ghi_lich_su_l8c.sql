-- Sửa lệch luật (a) R-CRM-17: khi duyệt phiếu thu làm cơ hội tự lên L8C, ghi thêm dòng lịch sử «Hệ thống chuyển L8C» vào Ghi chú và hoạt động của cơ hội.
-- Thân hàm giữ nguyên bản migration 126, chỉ thêm biến v_up, mệnh đề returning và lệnh ghi chú hệ thống. Quyền gọi giữ nguyên.
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
  v_up uuid;
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
  perform app.create_enrollments_for_order(r.order_id);
  -- Luật R-CRM-17: cơ hội L8A/L8B có ít nhất một đơn Đã duyệt và KHÔNG còn đơn Đã duyệt nào chưa thu đủ thì lên L8C.
  if v_o.opportunity_id is not null then
    update app.opportunity op
       set substage_code = 'L8C'
     where op.id = v_o.opportunity_id
       and op.stage_code = 'L8'
       and op.substage_code in ('L8A', 'L8B')
       and exists (select from app.sales_order s where s.opportunity_id = op.id and s.status_code = 'DA_DUYET')
       and not exists (select from app.sales_order s
                        where s.opportunity_id = op.id and s.status_code = 'DA_DUYET'
                          and app.order_paid_amount(s.id) < s.total_amount)
    returning op.id into v_up;
    -- Sửa lệch luật (a): lên L8C do hệ thống thì ghi một dòng vào Ghi chú và hoạt động của cơ hội (ngoài nhật ký thao tác).
    if v_up is not null then
      perform app.add_system_note('OPPORTUNITY', v_up, 'Hệ thống chuyển L8C: mọi đơn đã duyệt của cơ hội đều thu đủ.');
    end if;
  end if;
  return jsonb_build_object('id', p_id, 'money_in_id', v_money, 'money_in_code', v_code,
                            'paid', app.order_paid_amount(v_o.id), 'remaining', v_o.total_amount - app.order_paid_amount(v_o.id));
end;
$$;
