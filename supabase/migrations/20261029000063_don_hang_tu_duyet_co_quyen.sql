-- ===========================================================================
-- P5a-DB-O2c (migration 063, Đ283, Q-B2): tự duyệt khi Trưởng cơ sở trình (Q-P6, anh chốt 19/10) và bốn cờ quyền của get_order.
--  (1) app.order_approve_core: phần LÕI của duyệt đơn (Đ102, R-TIEN-35, R-GD-08, R-CRM-27, chốt hạn đóng tiền, đổi Đã duyệt, sự kiện DUYET),
--      tách từ approve_order để approve_order và submit_order dùng chung, không chép code. Đọc lại đơn theo id (không dùng bản đã đọc trước).
--  (2) app.submit_order(p_id, p_acknowledged default false): đường QUAN_LY giữ nguyên (p_acknowledged bị bỏ qua); đường TU_DUYET mà NGƯỜI GỌI
--      chính là người lập thì trong CÙNG giao dịch: Đã trình (sự kiện TRINH) rồi Đã duyệt (sự kiện DUYET, ghi chú "Tự duyệt"), kiểm đúng các
--      điều kiện của approve_order; lỗi ở bước nào thì cả giao dịch lùi (đơn vẫn Nháp, mã không nhảy). Người khác trình đơn của Trưởng cơ sở
--      thì chỉ thành Đã trình.
--  (3) app.get_order trả thêm can_submit, can_cancel, can_approve, can_reject (chỉ xét quyền và trạng thái, không báo lỗi).
-- Chỉ đụng đường ghi tiền (duyệt đơn): có kiểm độc lập (Đ209, Đ216).
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Lõi của duyệt đơn. Nội bộ (không mở cho rpc), chỉ gọi từ approve_order và submit_order SAU KHI các hàm đó đã kiểm quyền, công tắc Bán hàng,
-- trạng thái Đã trình và đúng người duyệt. Đầu vào: đơn, người duyệt đã tích đồng ý chưa, duyệt thay không, ghi chú sự kiện.
-- Luật: Đ102 (ô tích chung cho vượt trần và chính sách cần duyệt; người tích là người duyệt); R-TIEN-35 (em đủ họ tên, năm sinh);
-- R-GD-08 (kiểm lại lớp); R-CRM-27, KD6 (tìm hoặc tạo hồ sơ học sinh, trùng tên và năm sinh trong đơn thì chặn); chốt hạn đóng tiền (R-TIEN-07).
-- ---------------------------------------------------------------------------
create or replace function app.order_approve_core(p_id uuid, p_acknowledged boolean, p_on_behalf boolean, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  l app.sales_order_line;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  -- Đọc LẠI đơn: order_refresh_totals ở submit_order có thể đã đổi needs_acknowledgement sau khi hàm gọi đọc đơn.
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  -- Luật Đ102: một ô tích chung cho vượt trần và chính sách cần duyệt, người tích là người duyệt.
  if v_o.needs_acknowledgement and not coalesce(p_acknowledged, false) then
    perform app.raise_error('HMT_CAN_TICH_DONG_Y', 'Đơn vượt trần chiết khấu hoặc có chính sách cần duyệt: tích đồng ý rồi mới duyệt.');
  end if;
  -- Luật R-TIEN-35: kiểm lại em đủ họ tên, năm sinh; R-GD-08: kiểm lại lớp.
  perform app.assert_order_students_complete(p_id);
  for l in select * from app.sales_order_line where order_id = p_id order by line_no loop
    perform app.check_order_line_class(l.line_no, l.class_id, l.package_id, v_o.branch_id);
  end loop;
  -- Trigger khoá dòng cho phép riêng việc gắn hồ sơ học sinh và chốt hạn đóng trong lúc duyệt (hmt.order_approve).
  perform set_config('hmt.order_approve', 'on', true);
  -- Luật R-CRM-27: tìm hoặc tạo hồ sơ học sinh; trùng tên và năm sinh trong đơn thì chặn (KD6).
  perform app.order_link_students(p_id, v_o.parent_id, v_o.branch_id);
  -- Lịch đóng tiền đã tính lúc lưu và lúc trình (đơn khoá từ khi trình): chốt hạn đóng (ngày duyệt + số ngày của đợt).
  update app.sales_order_installment set due_date = v_today + due_days where order_id = p_id;
  perform set_config('hmt.order_approve', '', true);
  update app.sales_order set status_code = 'DA_DUYET', approved_at = now(), approved_by = auth.uid(),
         approved_on_behalf = coalesce(p_on_behalf, false), acknowledged = coalesce(p_acknowledged, false) where id = p_id;
  perform app.order_add_event(p_id, 'DUYET', 'DA_TRINH', 'DA_DUYET', null, null, p_note, coalesce(p_on_behalf, false));
end;
$$;

-- ---------------------------------------------------------------------------
-- Duyệt đơn (approve_order): giữ nguyên chữ ký, quyền và các kiểm; phần thân sau khi kiểm gọi order_approve_core.
-- Ai gọi: Đơn hàng · Duyệt ở cơ sở, đúng người duyệt đã chốt lúc trình (Admin duyệt thay khi vắng). Kết quả: {id, code, on_behalf}.
-- ---------------------------------------------------------------------------
create or replace function app.approve_order(p_id uuid, p_acknowledged boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_on_behalf boolean;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'DUYET', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code <> 'DA_TRINH' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt được đơn Đã trình.');
  end if;
  if not app.can_approve_as_manager(v_o.created_by, 'DON', v_o.assigned_approver_id) then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_DUYET', 'Đơn này do người duyệt đã chốt lúc trình duyệt (Admin duyệt thay khi vắng).');
  end if;
  v_on_behalf := v_o.assigned_approver_id is distinct from auth.uid();
  perform app.order_approve_core(p_id, p_acknowledged, v_on_behalf,
                                 case when v_on_behalf then 'Admin duyệt thay'
                                      when v_o.approval_route = 'TU_DUYET' then 'Tự duyệt' end);
  return jsonb_build_object('id', p_id, 'code', v_o.code, 'on_behalf', v_on_behalf);
end;
$$;

-- ---------------------------------------------------------------------------
-- Trình đơn (submit_order): chữ ký mới có p_acknowledged. Bỏ chữ ký cũ một tham số TRƯỚC (không thì có hai hàm và lời gọi một tham số báo trùng).
-- Ai gọi, luật: như cũ (R-TIEN-06, R-HT-06, Đ203, Đ205, Đ215, R-TIEN-35, R-TIEN-07, R-GD-06, R-GD-08). Thêm Q-P6 (Đ283): đường TU_DUYET mà người gọi
-- chính là người lập (Trưởng cơ sở) thì trình = tự duyệt trong cùng giao dịch, qua app.order_approve_core (đúng điều kiện của approve_order, kể cả
-- Đ102 ô tích đồng ý ở p_acknowledged). Đường QUAN_LY: p_acknowledged bị bỏ qua. Kết quả: {id, approver_id, route, status, auto_approved}.
-- ---------------------------------------------------------------------------
drop function app.submit_order(uuid);

create or replace function app.submit_order(p_id uuid, p_acknowledged boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_route text;
  v_approver uuid;
  l app.sales_order_line;
  v_auto boolean;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'SUA', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ trình được đơn Nháp.');
  end if;
  if not exists (select from app.sales_order_line where order_id = p_id) then
    perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn chưa có dòng nào, chưa trình được.');
  end if;
  -- Luật R-TIEN-35: em đủ họ tên và năm sinh.
  perform app.assert_order_students_complete(p_id);
  -- Luật R-TIEN-07: phải chọn điều khoản thanh toán; lịch đóng tiền tính lại để báo sớm nếu điều khoản không hợp tổng đơn.
  if v_o.payment_term_id is null then
    perform app.raise_error('HMT_THIEU_DIEU_KHOAN', 'Chọn điều khoản thanh toán trước khi trình đơn.');
  end if;
  perform app.order_refresh_totals(p_id);
  -- Luật R-GD-06, R-GD-08: lớp trên dòng kiểm lại lúc trình.
  for l in select * from app.sales_order_line where order_id = p_id order by line_no loop
    perform app.check_order_line_class(l.line_no, l.class_id, l.package_id, v_o.branch_id);
  end loop;
  -- Luật R-HT-06: chốt người duyệt lúc trình theo NGƯỜI LẬP.
  select r.route, r.approver_id into v_route, v_approver from app.approval_route(v_o.created_by) r;
  -- Luật Đ205: người duyệt đã chốt phải có quyền Duyệt đơn ở cơ sở này.
  if not app.user_can_at_branch(v_approver, 'SALES_ORDER', 'DUYET', v_o.branch_id) then
    perform app.raise_error('HMT_NGUOI_DUYET_THIEU_QUYEN',
      'Quản lý trực tiếp của người lập chưa có quyền Duyệt đơn hàng ở cơ sở này nên chưa trình được. Nhờ Admin đặt lại Quản lý trực tiếp hoặc cấp quyền.');
  end if;
  update app.sales_order set status_code = 'DA_TRINH', approval_route = v_route, assigned_approver_id = v_approver,
         submitted_at = now(), submitted_by = auth.uid() where id = p_id;
  perform app.order_add_event(p_id, 'TRINH', 'NHAP', 'DA_TRINH');
  -- Luật Q-P6 (Đ283): Trưởng cơ sở lập và chính họ trình thì tự duyệt ngay, trong cùng giao dịch. Mọi điều kiện của approve_order áp lại; lỗi thì
  -- cả giao dịch lùi (đơn vẫn Nháp). Người khác trình đơn của Trưởng cơ sở thì dừng ở Đã trình, Trưởng cơ sở duyệt sau.
  v_auto := v_route = 'TU_DUYET' and v_o.created_by is not distinct from auth.uid();
  if v_auto then
    perform app.assert_can('SALES_ORDER', 'DUYET', v_o.branch_id);
    if not app.can_approve_as_manager(v_o.created_by, 'DON', v_approver) then
      perform app.raise_error('HMT_KHONG_PHAI_NGUOI_DUYET', 'Đơn này do người duyệt đã chốt lúc trình duyệt (Admin duyệt thay khi vắng).');
    end if;
    perform app.order_approve_core(p_id, p_acknowledged, false, 'Tự duyệt');
  end if;
  return jsonb_build_object('id', p_id, 'approver_id', v_approver, 'route', v_route,
                            'status', case when v_auto then 'DA_DUYET' else 'DA_TRINH' end, 'auto_approved', v_auto);
end;
$$;

-- ---------------------------------------------------------------------------
-- Bản ghi đơn (get_order): thêm can_submit, can_cancel, can_approve, can_reject (xem chú thích ở thân hàm). Còn lại như migration 062.
-- ---------------------------------------------------------------------------
create or replace function app.get_order(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
  v_route text;
  v_approver uuid;
  v_hint text;
  v_feature boolean;
  v_can_approve boolean;
  v_can_cancel boolean;
begin
  select * into o from app.sales_order where id = p_id;
  if o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'XEM', o.branch_id);
  -- Người duyệt dự kiến của đơn Nháp: ĐÚNG đầu vào và hàm mà submit_order dùng để chốt assigned_approver_id (R-HT-06): người LẬP đơn
  -- (created_by) qua app.approval_route. Chưa có quản lý trực tiếp thì KHÔNG báo lỗi: đường duyệt THIEU, người duyệt rỗng, để giao diện
  -- hiện khung "chưa có quản lý trực tiếp". Đơn đã trình trở đi thì không trả (đã có assigned_approver_id).
  if o.status_code = 'NHAP' then
    begin
      select r.route, r.approver_id into v_route, v_approver from app.approval_route(o.created_by) r;
    -- Chủ ý bắt mọi lỗi: tra người duyệt dự kiến chỉ để hiển thị, KHÔNG được chặn việc mở màn đơn. Chưa có quản lý thì THIEU; lỗi khác thì để
    -- trống (route null); luật chặn thật vẫn nằm ở submit_order lúc Trình.
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      if v_hint = 'HMT_KHONG_CO_QUAN_LY' then
        v_route := 'THIEU';
        v_approver := null;
      else
        v_route := null;
        v_approver := null;
      end if;
    end;
  end if;
  -- Bốn cờ cho giao diện (Đ283): tính bằng ĐÚNG các hàm không báo lỗi mà hàm ghi dùng (can_see_branch của assert_can, feature_enabled của
  -- require_feature, can_approve_as_manager, order_has_receipt), nên giao diện không tự đoán quyền. Cờ chỉ xét QUYỀN và TRẠNG THÁI, không xét
  -- dữ liệu: thiếu điều khoản, em thiếu năm sinh, chưa có quản lý trực tiếp... vẫn do hàm ghi báo lúc bấm (cờ đúng, lỗi cấu hình khi Trình).
  v_feature := app.feature_enabled('BAN_HANG', o.branch_id);
  -- Duyệt và Từ chối (approve_order, reject_order kiểm y hệt): đơn Đã trình, quyền Duyệt, đúng người duyệt đã chốt (Admin thay khi vắng).
  v_can_approve := coalesce(o.status_code = 'DA_TRINH' and v_feature
                            and app.can_see_branch('SALES_ORDER', 'DUYET', o.branch_id)
                            and app.can_approve_as_manager(o.created_by, 'DON', o.assigned_approver_id), false);
  -- Huỷ (cancel_order, R-TIEN-38): đơn Nháp chỉ người lập; đơn Đã trình, Đã duyệt do người duyệt đã chốt; chỉ khi chưa có phiếu thu.
  v_can_cancel := coalesce(o.status_code <> 'HUY' and v_feature
                  and app.can_see_branch('SALES_ORDER', 'HUY', o.branch_id)
                  and case when o.status_code = 'NHAP' then o.created_by is not distinct from auth.uid()
                           else app.can_approve_as_manager(o.created_by, 'DON', o.assigned_approver_id) end
                  and not app.order_has_receipt(o.id), false);
  return (to_jsonb(o) - 'search_text') || jsonb_build_object(
    -- Trình (submit_order): đơn Nháp, quyền Sửa ở cơ sở, Bán hàng bật.
    'can_submit', coalesce(o.status_code = 'NHAP' and v_feature and app.can_see_branch('SALES_ORDER', 'SUA', o.branch_id), false),
    'can_cancel', v_can_cancel,
    'can_approve', v_can_approve,
    'can_reject', v_can_approve,
    'status', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_STATUS' and c.code = o.status_code),
    'branch_code', (select b.code from app.branch b where b.id = o.branch_id),
    'opportunity_code', (select x.code from app.opportunity x where x.id = o.opportunity_id),
    'quotation_code', (select q.code from app.quotation q where q.id = o.quotation_id),
    'parent_code', (select p.code from app.parent p where p.id = o.parent_id),
    'parent_name', (select p.full_name from app.parent p where p.id = o.parent_id),
    'parent_phone', (select p.phone from app.parent p where p.id = o.parent_id),
    'payment_term_name', (select t.name from app.payment_term t where t.id = o.payment_term_id),
    -- Tổng niêm yết và tổng chiết khấu: DB cộng từ các dòng đã đóng băng, không tính lại; dòng quà tặng không tính (R-TIEN-30).
    'gross_total', (select coalesce(sum(l3.gross_amount), 0)::bigint from app.sales_order_line l3
                     where l3.order_id = o.id and l3.line_kind = 'ENROL'),
    'discount_total', (select coalesce(sum(l3.discount_amount), 0)::bigint from app.sales_order_line l3
                        where l3.order_id = o.id and l3.line_kind = 'ENROL'),
    -- Chỉ khi đơn Nháp: QUAN_LY, TU_DUYET hoặc THIEU; người duyệt dự kiến; và người đó có quyền Duyệt đơn ở cơ sở này không (Đ205).
    'expected_route', v_route,
    'expected_approver_id', v_approver,
    'expected_approver_name', app.staff_display_name(v_approver),
    'expected_approver_can_approve', case when v_approver is null then null
                                          else app.user_can_at_branch(v_approver, 'SALES_ORDER', 'DUYET', o.branch_id) end,
    'created_by_name', app.staff_display_name(o.created_by),
    'submitted_by_name', app.staff_display_name(o.submitted_by),
    'approver_name', app.staff_display_name(o.assigned_approver_id),
    'approved_by_name', app.staff_display_name(o.approved_by),
    'cancel_reason', (select c.name from app.catalog_item c where c.catalog_code = 'ORDER_CANCEL_REASON' and c.code = o.cancel_reason_code),
    'has_incomplete_students', exists (
      select from app.sales_order_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
        left join app.student s on s.id = l.student_id
       where l.order_id = o.id
         and (coalesce(s.full_name, v.full_name) is null or coalesce(s.birth_year, v.birth_year) is null)),
    'lines', coalesce((
      select jsonb_agg(to_jsonb(l) - 'order_id' || jsonb_build_object(
               'student_name', coalesce(s.full_name, v.full_name), 'student_birth_year', coalesce(s.birth_year, v.birth_year),
               'student_code', coalesce(s.code, v.student_code),
               'student_complete', (coalesce(s.full_name, v.full_name) is not null and coalesce(s.birth_year, v.birth_year) is not null),
               'gift_policy_name', (select g.name from app.gift_policy g where g.id = l.gift_policy_id),
               'discounts', coalesce((select jsonb_agg(to_jsonb(d) - 'line_id' - 'branch_id' order by d.created_at, d.id)
                                        from app.sales_order_line_discount d where d.line_id = l.id), '[]'::jsonb))
             order by l.line_no)
        from app.sales_order_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
        left join app.student s on s.id = l.student_id
       where l.order_id = o.id), '[]'::jsonb),
    'installments', coalesce((
      select jsonb_agg(jsonb_build_object('seq', i.seq, 'due_days', i.due_days, 'amount', i.amount, 'due_date', i.due_date) order by i.seq)
        from app.sales_order_installment i where i.order_id = o.id), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
               'seq', e.seq, 'event_code', e.event_code, 'from_status', e.from_status, 'to_status', e.to_status,
               'reason_code', e.reason_code, 'note', e.note, 'on_behalf', e.on_behalf, 'created_at', e.created_at,
               'actor_name', app.staff_display_name(e.created_by)) order by e.seq)
        from app.sales_order_event e where e.order_id = o.id), '[]'::jsonb));
end;
$$;

select set_config('hmt.migration', '', false);

-- Quyền thực thi: lõi duyệt là hàm nội bộ (như order_link_students); submit_order chữ ký mới cấp lại như cũ.
revoke execute on function app.order_approve_core(uuid, boolean, boolean, text) from public, anon, authenticated;
revoke execute on function app.submit_order(uuid, boolean), app.approve_order(uuid, boolean), app.get_order(uuid) from public, anon;
grant execute on function app.submit_order(uuid, boolean), app.approve_order(uuid, boolean), app.get_order(uuid) to authenticated;
