-- N1 (Soát S14, mức CAO, tiền; Chat giao thẻ C26, 19/11/2026): Kế toán tự lập, tự gửi, tự duyệt phiếu thu nợ đầu kỳ. Phiếu nợ đầu kỳ không qua bước quản lý (R-V2-15) nên chốt
-- «cùng người không duyệt hai bước» của migration 455 không bắt ca này. Sửa: app.approve_opening_debt_receipt chặn người duyệt trùng người LẬP hoặc người GỬI phiếu
-- (mã lỗi sẵn có HMT_CUNG_NGUOI_DUYET_HAI_BUOC). approve_receipt_accounting (migration 252) chuyển phiếu nợ đầu kỳ sang hàm này nên đường cũ cũng bị chặn.
-- Thân hàm giữ nguyên bản migration 251, chỉ thêm đúng một luật.
select set_config('hmt.migration', 'on', false);

create or replace function app.approve_opening_debt_receipt(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_code text;
  v_money uuid;
  v_branch_code text;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null or not r.is_opening_debt then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu nợ đầu kỳ.');
  end if;
  perform app.assert_can('ACCOUNTING', 'DUYET', r.branch_id);
  perform app.require_feature('BAN_HANG', r.branch_id);
  if not app.get_setting_bool('opening_debt_receipt_enabled', r.branch_id) then
    perform app.raise_error('HMT_TINH_NANG_TAT', 'Thu nợ đầu kỳ chưa được bật cho cơ sở này.');
  end if;
  if r.status_code <> 'CHO_KE_TOAN' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt được phiếu thu Chờ kế toán.');
  end if;
  -- Luật N1 (Soát S14, R-V2-15, R-HT-01): phiếu nợ đầu kỳ không có bước quản lý, nên người lập hoặc người gửi KHÔNG tự duyệt phiếu của chính mình
  -- (Kế toán có cả quyền Tạo lẫn Duyệt: nếu không chặn thì một người lập, gửi, duyệt, nợ về 0 mà không ai khác biết).
  if auth.uid() is not distinct from r.created_by or auth.uid() is not distinct from r.submitted_by then
    perform app.raise_error('HMT_CUNG_NGUOI_DUYET_HAI_BUOC',
      'Người lập hoặc người gửi phiếu thu nợ đầu kỳ không tự duyệt phiếu của mình. Nhờ một Kế toán khác duyệt.');
  end if;
  -- Luật R-V2-15: không vượt nợ còn lại tại lúc duyệt.
  if r.amount > app.opening_debt_remaining(r.parent_id, r.id) then
    perform app.raise_error('HMT_SO_TIEN_VUOT', 'Số tiền vượt nợ đầu kỳ còn lại của phụ huynh.');
  end if;
  select code into v_branch_code from app.branch where id = r.branch_id;
  v_code := app.issue_document_number('KTV', v_branch_code);
  insert into app.money_in (code, receipt_id, order_id, is_opening_debt, opening_debt_student_id, parent_id, branch_id, amount)
  values (v_code, r.id, null, true, r.opening_debt_student_id, r.parent_id, r.branch_id, r.amount)
  returning id into v_money;
  insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref)
  values (r.parent_id, r.opening_debt_student_id, r.branch_id, 'THU_NO_DAU_KY', r.amount, current_date, v_code);
  update app.receipt set status_code = 'DA_DUYET', accountant_approved_at = now(), accountant_approved_by = auth.uid() where id = p_id;
  perform app.receipt_add_event(p_id, 'DUYET_KT', 'CHO_KE_TOAN', 'DA_DUYET', 'Thu nợ đầu kỳ');
  return jsonb_build_object('id', p_id, 'money_in_id', v_money, 'money_in_code', v_code,
                            'remaining', app.opening_debt_remaining(r.parent_id));
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.approve_opening_debt_receipt(uuid) from public, anon;
grant execute on function app.approve_opening_debt_receipt(uuid) to authenticated;
