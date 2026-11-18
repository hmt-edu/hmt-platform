-- Migration 451 (Code D, 18/11/2026): sửa T3 và T4 của Soát.
-- T3 (R-TIEN-38, R-GD-12): app.cancel_order chặn huỷ đơn còn ghi danh hiệu lực (đơn «cho học trước» chưa có phiếu thu). Mã lỗi HMT_DON_CO_GHI_DANH.
-- T4 (R-GD-16, R-TIEN-26): app.sync_enrollment_hours bỏ qua ghi danh đã Dừng (DUNG) hoặc Hoàn phí (HOAN_PHI): không cấp lại, không điều chỉnh giờ khi thu thêm hoặc đảo tiền.
-- Chỉ đổi thân hàm, chữ ký giữ nguyên.

create or replace function app.cancel_order(p_id uuid, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_item app.catalog_item;
  v_on_behalf boolean := false;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'HUY', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code = 'HUY' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Đơn này đã huỷ.');
  end if;
  if v_o.status_code = 'NHAP' then
    -- Luật R-TIEN-38: đơn Nháp chỉ người lập huỷ.
    if v_o.created_by is distinct from auth.uid() then
      perform app.raise_error('HMT_KHONG_DUOC_HUY_DON', 'Đơn Nháp chỉ người lập huỷ được.');
    end if;
  else
    -- Luật R-TIEN-38: đơn Đã trình, Đã duyệt do người duyệt đã chốt huỷ (Admin thay khi vắng).
    if not app.can_approve_as_manager(v_o.created_by, 'DON', v_o.assigned_approver_id, v_o.approval_route, v_o.branch_id) then
      perform app.raise_error('HMT_KHONG_DUOC_HUY_DON', 'Đơn đã trình hoặc đã duyệt chỉ người duyệt đã chốt lúc trình huỷ được (Admin huỷ thay khi vắng).');
    end if;
    v_on_behalf := v_o.assigned_approver_id is distinct from auth.uid()
                  and not (v_o.approval_route = 'TRUONG_CS' and app.is_branch_manager_at(auth.uid(), 'SALES_ORDER', v_o.branch_id));
  end if;
  -- Luật R-TIEN-38: chỉ huỷ khi đơn chưa có phiếu thu.
  if app.order_has_receipt(p_id) then
    perform app.raise_error('HMT_DON_DA_CO_PHIEU_THU', 'Đơn đã có phiếu thu, không huỷ được.');
  end if;
  -- Sửa T3 (R-TIEN-38, R-GD-12): đơn «cho học trước» đã sinh ghi danh mà chưa có phiếu thu; còn ghi danh hiệu lực thì không huỷ đơn.
  if exists (select from app.enrollment e where e.order_id = p_id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU')) then
    perform app.raise_error('HMT_DON_CO_GHI_DANH', 'Đơn đã có ghi danh còn hiệu lực (cho học trước), không huỷ được. Dừng học hoặc hoàn phí ghi danh trước.');
  end if;
  select * into v_item from app.catalog_item
   where catalog_code = 'ORDER_CANCEL_REASON' and code = p_reason_code and is_active;
  if v_item.id is null then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn lý do huỷ đơn.');
  end if;
  if v_item.requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn "Khác" thì ghi chú lý do.');
  end if;
  update app.sales_order set status_code = 'HUY', cancel_reason_code = p_reason_code,
         cancel_note = nullif(btrim(coalesce(p_note, '')), ''), cancelled_at = now(), cancelled_by = auth.uid() where id = p_id;
  -- Trả dòng về báo giá: tắt cờ đang sống (trigger khoá cho phép riêng việc này).
  perform set_config('hmt.order_cancel', 'on', true);
  update app.sales_order_line set is_live = false where order_id = p_id;
  perform set_config('hmt.order_cancel', '', true);
  perform app.order_add_event(p_id, 'HUY', v_o.status_code, 'HUY', 'ORDER_CANCEL_REASON', p_reason_code, p_note, v_on_behalf);
end;
$$;

create or replace function app.sync_enrollment_hours(p_order_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_target numeric;
  v_have numeric;
  v_kind text;
  v_n integer := 0;
begin
  for r in select e.id, e.branch_id, e.order_line_id from app.enrollment e where e.order_id = p_order_id and e.order_line_id is not null
    and e.status_code not in ('DUNG', 'HOAN_PHI') loop -- Sửa T4: ghi danh đã Dừng, Hoàn phí không cấp lại, không điều chỉnh giờ
    foreach v_kind in array array['CAP_MUA', 'CAP_TANG'] loop
      v_target := app.enrollment_target_hours(r.order_line_id, v_kind);
      select coalesce(sum(hours), 0) into v_have from app.hour_ledger where enrollment_id = r.id and entry_type = v_kind;
      if v_target <> v_have then
        insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) values (r.id, r.branch_id, v_kind, v_target - v_have);
        v_n := v_n + 1;
      end if;
    end loop;
  end loop;
  return v_n;
end;
$$;
