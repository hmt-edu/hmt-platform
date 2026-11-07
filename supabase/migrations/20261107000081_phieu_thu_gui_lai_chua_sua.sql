-- ===========================================================================
-- Phiếu thu: gửi lại mà chưa sửa từ lần bị từ chối (anh chốt 07/11: Q-58, R-TIEN-06; giống đơn hàng Q-29).
--  (1) app.receipt_resubmitted_unedited(phiếu): phiếu từng bị từ chối và chưa có sự kiện Sửa (SUA) nào sau lần từ chối cuối.
--  (2) submit_receipt thay thế: giữ MỌI kiểm cũ, chỉ thêm ghi chú "Gửi lại, chưa sửa từ lần bị từ chối" vào sự kiện Gửi (GUI) đúng trường hợp đó.
--      KHÔNG chặn: R-TIEN-06 cho phép gửi lại y nguyên; bị kế toán từ chối thì gửi lại vẫn đi từ bước quản lý (TD14, không đổi).
-- Không bảng, chỉ mục mới; không đổi quyền.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

-- Phiếu vừa bị từ chối và chưa sửa từ lần từ chối cuối (dùng ở submit_receipt).
create or replace function app.receipt_resubmitted_unedited(p_receipt_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.receipt_event r
                  where r.receipt_id = p_receipt_id and r.event_code = 'TU_CHOI'
                    and r.seq = (select max(x.seq) from app.receipt_event x where x.receipt_id = p_receipt_id and x.event_code = 'TU_CHOI')
                    and not exists (select from app.receipt_event s
                                     where s.receipt_id = p_receipt_id and s.event_code = 'SUA' and s.seq > r.seq));
$$;

create or replace function app.submit_receipt(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_o app.sales_order;
  v_route text;
  v_approver uuid;
  v_auto boolean;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('RECEIPT', 'TAO', r.branch_id);
  perform app.require_feature('BAN_HANG', r.branch_id);
  if r.created_by is distinct from auth.uid() then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_LAP', 'Chỉ người lập mới gửi được phiếu thu của mình.');
  end if;
  if r.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ gửi được phiếu thu Nháp.');
  end if;
  select * into v_o from app.sales_order where id = r.order_id;
  if v_o.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_DON_CHUA_DUYET', 'Đơn hàng không còn ở trạng thái đã duyệt.');
  end if;
  -- Kiểm lại số tiền với phần còn thu được (các phiếu khác có thể đã gửi từ lúc lập).
  perform app.receipt_normalize(v_o, jsonb_build_object('amount', r.amount, 'payment_method_code', r.payment_method_code,
            'paid_on', r.paid_on, 'collect_branch_id', r.collect_branch_id, 'receiver_id', r.receiver_id, 'target_line_id', r.target_line_id), r.id);
  select x.route, x.approver_id into v_route, v_approver from app.approval_route(r.created_by) x;
  if not app.user_can_at_branch(v_approver, 'RECEIPT', 'DUYET', r.branch_id) then
    perform app.raise_error('HMT_NGUOI_DUYET_THIEU_QUYEN',
      'Quản lý trực tiếp của người lập chưa có quyền Duyệt phiếu thu ở cơ sở này nên chưa gửi được. Nhờ Admin đặt lại Quản lý trực tiếp hoặc cấp quyền.');
  end if;
  update app.receipt set status_code = 'DA_GUI', approval_route = v_route, assigned_approver_id = v_approver,
         submitted_at = now(), submitted_by = auth.uid() where id = p_id;
  -- Luật Q-58 (anh chốt 07/11, giống đơn Q-29): gửi lại mà chưa sửa gì từ lần bị từ chối thì sự kiện Gửi ghi rõ (không chặn, hộp xác nhận ở giao diện).
  perform app.receipt_add_event(p_id, 'GUI', 'NHAP', 'DA_GUI',
                                case when app.receipt_resubmitted_unedited(p_id) then 'Gửi lại, chưa sửa từ lần bị từ chối' end);
  -- Trưởng cơ sở lập và chính họ gửi: tự duyệt bước quản lý ngay, trong cùng giao dịch.
  v_auto := v_route = 'TU_DUYET' and r.created_by is not distinct from auth.uid();
  if v_auto then
    perform app.receipt_manager_step_done(p_id, 'TU_DUYET_QL');
  end if;
  return jsonb_build_object('id', p_id, 'approver_id', v_approver, 'route', v_route,
                            'status', case when v_auto then 'CHO_KE_TOAN' else 'DA_GUI' end, 'auto_approved', v_auto);
end;
$$;

revoke execute on function app.receipt_resubmitted_unedited(uuid) from public, anon, authenticated;
revoke execute on function app.submit_receipt(uuid) from public, anon;
grant execute on function app.submit_receipt(uuid) to authenticated;

select set_config('hmt.migration', '', false);
