-- C91 (KHO-VIEC dòng 14; anh Trường duyệt 20/11 20:38, thư Chat 20:44; migration 582, rủi ro CAO: phiếu thu, tiền vào). TC-17, TC-02: «Tài khoản nhận» ở khối «Nơi nhận tiền» (canvas 9933 TC17_*, TC02_*).
-- Anh chốt: nhân viên lập phiếu HOẶC Kế toán đều chọn được, không bắt buộc. Cột receiving_account_code đã có từ migration 478 (danh mục RECEIVING_ACCOUNT do Quản trị quản lý ở QT-07); Kế toán vẫn ghi được khi đối soát ở TC-15.
-- Làm gì: (1) app.set_receipt_receiving_account(phiếu, mã): ghi hoặc xoá tài khoản nhận; (2) get_receipt trả thêm receiving_account_code và receiving_account (tên).
-- Vì sao hàm riêng mà không sửa create_receipt, save_receipt, receipt_normalize: ba hàm đó là lõi tiền vào, nhiều nhánh; trường này tuỳ chọn, không ảnh hưởng số tiền hay chia tiền nên tách ra để giảm rủi ro. Giao diện lưu phiếu rồi gọi hàm này.
-- Chỉ mục: không thêm (đã có receipt_receiving_account_idx ở 478). Mọi sửa ghi vào audit_log qua trigger chuẩn của bảng.
select set_config('hmt.migration', 'on', false);

-- app.set_receipt_receiving_account(p_receipt_id, p_account_code): ghi tài khoản nhận của phiếu thu (trống = xoá).
-- Ai gọi: (a) người LẬP phiếu, khi phiếu còn Nháp, có quyền Phiếu thu · Tạo ở cơ sở của phiếu; (b) Kế toán, Admin có quyền Sửa phiếu thu phạm vi toàn hệ thống, khi phiếu Đã gửi hoặc Chờ kế toán.
-- Phiếu Đã duyệt: dùng TC-15 (mark_receipts_bank_matched). Phiếu Huỷ không sửa. Lỗi: HMT_KHONG_TIM_THAY, HMT_KHONG_CO_QUYEN, HMT_PHIEU_THU_DA_KHOA (sai tình trạng), HMT_TAI_KHOAN_NHAN_KHONG_HOP_LE.
create or replace function app.set_receipt_receiving_account(p_receipt_id uuid, p_account_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_code text := nullif(btrim(coalesce(p_account_code, '')), '');
  v_me uuid := (select auth.uid());
  v_accountant boolean;
begin
  select * into r from app.receipt where id = p_receipt_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  v_accountant := app.permission_scope('RECEIPT', 'SUA') = 'TOAN_HE_THONG' and app.permission_scope('ACCOUNTING', 'XEM') = 'TOAN_HE_THONG';
  -- Luật quyền: người lập (phiếu Nháp) hoặc Kế toán (phiếu Đã gửi, Chờ kế toán).
  if r.status_code = 'NHAP' and r.created_by is not distinct from v_me and app.can_see_branch_wide('RECEIPT', 'TAO', r.branch_id) then
    null;
  elsif r.status_code in ('DA_GUI', 'CHO_KE_TOAN') and v_accountant then
    null;
  elsif r.status_code in ('NHAP', 'DA_GUI', 'CHO_KE_TOAN') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ người lập (phiếu Nháp) hoặc Kế toán (phiếu đã gửi) ghi tài khoản nhận.');
  else
    perform app.raise_error('HMT_PHIEU_THU_DA_KHOA', 'Phiếu này không còn sửa tài khoản nhận được (phiếu đã duyệt dùng màn Đối soát thu tiền).');
  end if;
  -- Luật: tài khoản nhận lấy từ danh mục RECEIVING_ACCOUNT (mục còn dùng); không bắt buộc.
  if v_code is not null and not exists (
       select from app.catalog_item c where c.catalog_code = 'RECEIVING_ACCOUNT' and c.code = v_code and c.is_active) then
    perform app.raise_error('HMT_TAI_KHOAN_NHAN_KHONG_HOP_LE', 'Tài khoản nhận không có trong danh mục tài khoản nhận tiền.');
  end if;
  update app.receipt set receiving_account_code = v_code where id = r.id;
end;
$$;
revoke execute on function app.set_receipt_receiving_account(uuid, text) from public, anon;
grant execute on function app.set_receipt_receiving_account(uuid, text) to authenticated;

-- app.get_receipt: như migration 422, thêm receiving_account_code và receiving_account (tên hiển thị).
create or replace function app.get_receipt(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_o app.sales_order;
  v_actions text[] := array[]::text[];
  v_me uuid := auth.uid();
begin
  select * into r from app.receipt where id = p_id;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can_wide('RECEIPT', 'XEM', r.branch_id);
  if r.order_id is not null then
    select * into v_o from app.sales_order where id = r.order_id;
  end if;
  if r.status_code = 'NHAP' and r.created_by is not distinct from v_me and app.can_see_branch_wide('RECEIPT', 'TAO', r.branch_id) then
    v_actions := v_actions || array['sua', 'gui'];
  end if;
  if r.status_code = 'DA_GUI' and app.can_see_branch_wide('RECEIPT', 'DUYET', r.branch_id)
     and app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id, r.approval_route, r.branch_id) then
    v_actions := v_actions || array['duyet_quan_ly', 'tu_choi'];
  end if;
  if r.status_code = 'CHO_KE_TOAN' and app.can_see_branch_wide('ACCOUNTING', 'DUYET', r.branch_id) then
    v_actions := v_actions || array['duyet_ke_toan', 'tu_choi'];
  end if;
  if r.status_code in ('NHAP', 'DA_GUI', 'CHO_KE_TOAN')
     and (r.created_by is not distinct from v_me and app.can_see_branch_wide('RECEIPT', 'TAO', r.branch_id) or app.can_see_branch_wide('RECEIPT', 'HUY', r.branch_id)) then
    v_actions := v_actions || array['huy'];
  end if;
  return jsonb_build_object(
    'id', r.id, 'code', r.code, 'status_code', r.status_code,
    'status', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_STATUS' and c.code = r.status_code),
    'is_opening_debt', r.is_opening_debt,
    'opening_student', (select jsonb_build_object('id', s.id, 'code', s.code, 'name', s.full_name) from app.student s where s.id = r.opening_debt_student_id),
    'order', case when r.order_id is null then null else jsonb_build_object('id', v_o.id, 'code', v_o.code, 'total_amount', v_o.total_amount, 'status_code', v_o.status_code) end,
    'parent', (select jsonb_build_object('id', p.id, 'code', p.code, 'name', p.full_name, 'phone', p.phone) from app.parent p where p.id = r.parent_id),
    'amount', r.amount, 'payment_method_code', r.payment_method_code,
    'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = r.payment_method_code),
    'txn_ref', r.txn_ref, 'paid_on', r.paid_on, 'note', r.note, 'target_line_id', r.target_line_id,
    -- C91 (TC-17): tài khoản nhận tiền (danh mục RECEIVING_ACCOUNT, tuỳ chọn) và tên hiển thị.
    'receiving_account_code', r.receiving_account_code,
    'receiving_account', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIVING_ACCOUNT' and c.code = r.receiving_account_code),
    'branch_code', (select code from app.branch where id = r.branch_id), 'collect_branch_id', r.collect_branch_id,
    'collect_branch_code', (select code from app.branch where id = r.collect_branch_id),
    'receiver_id', r.receiver_id, 'receiver_name', app.staff_display_name(r.receiver_id),
    'created_at', r.created_at, 'created_by', r.created_by, 'created_by_name', app.staff_display_name(r.created_by),
    'approver_name', app.staff_display_name(r.assigned_approver_id), 'approval_route', r.approval_route,
    'submitted_at', r.submitted_at, 'manager_approved_at', r.manager_approved_at, 'accountant_approved_at', r.accountant_approved_at,
    'cancel_reason', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_CANCEL_REASON' and c.code = r.cancel_reason_code),
    'cancel_note', r.cancel_note, 'cancelled_at', r.cancelled_at,
    'payment', case when r.order_id is null then jsonb_build_object('opening_debt_remaining', app.opening_debt_remaining(r.parent_id, r.id)) else app.order_payment_summary(r.order_id) end,
    'actions', to_jsonb(v_actions),
    'events', coalesce((select jsonb_agg(jsonb_build_object('event_code', e.event_code, 'from_status', e.from_status, 'to_status', e.to_status,
                                                            'note', e.note, 'at', e.created_at, 'by_name', app.staff_display_name(e.created_by))
                                         order by e.seq) from app.receipt_event e where e.receipt_id = r.id), '[]'::jsonb),
    'money_in', (select jsonb_build_object('code', m.code, 'amount', m.amount,
                   'allocations', (select coalesce(jsonb_agg(jsonb_build_object('line_no', l.line_no, 'package_name', l.package_name, 'amount', a.amount)
                                                             order by l.line_no), '[]'::jsonb)
                                     from app.money_in_allocation a join app.sales_order_line l on l.id = a.order_line_id where a.money_in_id = m.id))
                   from app.money_in m where m.receipt_id = r.id));
end;
$$;
select set_config('hmt.migration', '', false);
