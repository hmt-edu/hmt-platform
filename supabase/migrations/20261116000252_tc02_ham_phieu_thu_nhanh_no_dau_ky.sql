-- TC-02 Thu nợ đầu kỳ, phần 2: các hàm phiếu thu CŨ biết phiếu không đơn (Code C, 16/11/2026; Chat 15:28 (a): order_id rỗng, kiểm kê MỌI chỗ giả định order_id NOT NULL).
-- Kiểm kê (bản mới nhất mỗi hàm) cho 5 chỗ: save_receipt (076), submit_receipt (083), approve_receipt_accounting (131), list_receipts (083), get_receipt (083).
-- Cách sửa tối thiểu, mỗi hàm đúng một nhánh, thân giữ nguyên bản cũ:
--  - save_receipt, submit_receipt, approve_receipt_accounting: phiếu is_opening_debt chuyển sang hàm nợ đầu kỳ (giao diện dùng chung một tên hàm); đơn không đổi hành vi.
--  - list_receipts: nối TRÁI đơn (phiếu nợ đầu kỳ không bị mất khỏi danh sách), thêm cờ is_opening_debt.
--  - get_receipt: đơn rỗng thì order = null, payment = {opening_debt_remaining}; thêm is_opening_debt và học sinh tham chiếu.
-- Hàm mới app.save_opening_debt_receipt: sửa phiếu nợ đầu kỳ Nháp (cùng luật tạo, trừ chính phiếu khi tính nợ còn lại).
-- Cờ opening_debt_receipt_enabled (migration 251) vẫn TẮT mặc định; hàm tạo/gửi/duyệt/sửa nợ đầu kỳ kiểm cờ nên phiếu nợ đầu kỳ không tồn tại khi cờ tắt.

-- app.save_opening_debt_receipt(phiếu, dữ liệu): sửa phiếu thu nợ đầu kỳ ở trạng thái Nháp (người lập). Gọi từ save_receipt. Cùng luật tạo (R-V2-15): số tiền > 0 và không vượt nợ còn lại (trừ chính phiếu), hình thức, ngày thu, cơ sở thu, người nhận.
create or replace function app.save_opening_debt_receipt(p_id uuid, p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_amount bigint;
  v_method text := nullif(btrim(coalesce(p_data ->> 'payment_method_code', '')), '');
  v_paid_on date;
  v_collect uuid;
  v_receiver uuid;
  v_remaining bigint;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null or not r.is_opening_debt then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu nợ đầu kỳ.');
  end if;
  perform app.assert_can('RECEIPT', 'TAO', r.branch_id);
  perform app.require_feature('BAN_HANG', r.branch_id);
  if not app.get_setting_bool('opening_debt_receipt_enabled', r.branch_id) then
    perform app.raise_error('HMT_TINH_NANG_TAT', 'Thu nợ đầu kỳ chưa được bật cho cơ sở này.');
  end if;
  if r.created_by is distinct from auth.uid() then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_LAP', 'Chỉ người lập mới sửa được phiếu thu của mình.');
  end if;
  if r.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ sửa được phiếu thu Nháp.');
  end if;
  begin
    v_amount := (p_data ->> 'amount')::bigint;
  exception when others then
    perform app.raise_error('HMT_SO_TIEN_SAI', 'Nhập số tiền là số nguyên đồng.');
  end;
  if v_amount is null or v_amount <= 0 then
    perform app.raise_error('HMT_SO_TIEN_SAI', 'Số tiền phiếu thu phải lớn hơn 0.');
  end if;
  v_remaining := app.opening_debt_remaining(r.parent_id, r.id);
  if v_amount > v_remaining then
    perform app.raise_error('HMT_SO_TIEN_VUOT',
      format('Số tiền vượt nợ đầu kỳ còn lại của phụ huynh (còn %s đ).', to_char(v_remaining, 'FM999G999G999G999')));
  end if;
  if v_method is null then
    perform app.raise_error('HMT_THIEU_HINH_THUC', 'Chọn hình thức thanh toán.');
  end if;
  perform app.assert_catalog_code_active('PAYMENT_METHOD', v_method);
  v_paid_on := coalesce(nullif(p_data ->> 'paid_on', '')::date, r.paid_on);
  if v_paid_on > current_date then
    perform app.raise_error('HMT_NGAY_THU_SAI', 'Ngày thu không được ở tương lai.');
  end if;
  v_collect := coalesce(nullif(p_data ->> 'collect_branch_id', '')::uuid, r.collect_branch_id);
  if not exists (select from app.branch where id = v_collect and is_active and not is_office) then
    perform app.raise_error('HMT_CO_SO_SAI', 'Cơ sở thu tiền phải là cơ sở dạy học đang hoạt động.');
  end if;
  v_receiver := coalesce(nullif(p_data ->> 'receiver_id', '')::uuid, r.receiver_id);
  if not exists (select from app.user_account where id = v_receiver and student_code is null) then
    perform app.raise_error('HMT_NGUOI_NHAN_SAI', 'Người nhận tiền phải là nhân sự.');
  end if;
  update app.receipt set amount = v_amount, payment_method_code = v_method, txn_ref = nullif(btrim(coalesce(p_data ->> 'txn_ref', '')), ''),
         paid_on = v_paid_on, collect_branch_id = v_collect, receiver_id = v_receiver, note = nullif(btrim(coalesce(p_data ->> 'note', '')), '')
   where id = p_id;
  perform app.receipt_add_event(p_id, 'SUA', 'NHAP', 'NHAP');
  return jsonb_build_object('id', p_id, 'warnings', '[]'::jsonb);
end;
$$;
revoke execute on function app.save_opening_debt_receipt(uuid, jsonb) from public, anon;
grant execute on function app.save_opening_debt_receipt(uuid, jsonb) to authenticated;

-- save_receipt (thân bản migration 076, thêm nhánh nợ đầu kỳ).
create or replace function app.save_receipt(p_id uuid, p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_o app.sales_order;
  v jsonb;
  v_warnings jsonb := '[]'::jsonb;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('RECEIPT', 'TAO', r.branch_id);
  if r.created_by is distinct from auth.uid() then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_LAP', 'Chỉ người lập mới sửa được phiếu thu của mình.');
  end if;
  if r.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ sửa được phiếu thu Nháp.');
  end if;
  -- R-V2-15 (TC-02): phiếu thu nợ đầu kỳ không có đơn nên không đi qua chuẩn hoá theo đơn; có hàm riêng.
  if r.is_opening_debt then
    return app.save_opening_debt_receipt(p_id, p_data);
  end if;
  select * into v_o from app.sales_order where id = r.order_id;
  v := app.receipt_normalize(v_o, p_data, r.id);
  update app.receipt set amount = (v ->> 'amount')::bigint, payment_method_code = v ->> 'payment_method_code', txn_ref = v ->> 'txn_ref',
         paid_on = (v ->> 'paid_on')::date, collect_branch_id = (v ->> 'collect_branch_id')::uuid, receiver_id = (v ->> 'receiver_id')::uuid,
         target_line_id = (v ->> 'target_line_id')::uuid, note = v ->> 'note'
   where id = p_id;
  perform app.receipt_add_event(p_id, 'SUA', 'NHAP', 'NHAP');
  if (v ->> 'collect_branch_id')::uuid <> v_o.branch_id then
    v_warnings := v_warnings || to_jsonb('Cơ sở thu tiền khác cơ sở của đơn hàng.'::text);
  end if;
  return jsonb_build_object('id', p_id, 'warnings', v_warnings);
end;
$$;

-- submit_receipt (thân bản migration 083, thêm nhánh nợ đầu kỳ).
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
  -- R-V2-15 (TC-02): phiếu thu nợ đầu kỳ gửi thẳng Kế toán, KHÔNG qua quản lý trực tiếp; hàm riêng làm việc này.
  if r.is_opening_debt then
    perform app.submit_opening_debt_receipt(p_id);
    return jsonb_build_object('id', p_id, 'approver_id', null, 'route', null, 'status', 'CHO_KE_TOAN', 'auto_approved', false);
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
  select x.route, x.approver_id into v_route, v_approver from app.approval_route(r.created_by, r.branch_id, 'PHIEU_THU') x;
  -- Luật Q-63 (anh chốt 07/11): người duyệt đã chốt đang bị KHOÁ thì nói rõ, KHÁC với người duyệt thiếu quyền (câu bên dưới giữ nguyên).
  if v_approver is not null and exists (select from app.user_account a where a.id = v_approver and a.is_locked) then
    perform app.raise_error('HMT_NGUOI_DUYET_BI_KHOA',
      'Quản lý trực tiếp của người lập đang bị khoá nên chưa trình được. Nhờ Admin mở khoá hoặc đặt lại Quản lý trực tiếp.');
  end if;
  if v_route <> 'TRUONG_CS' and not app.user_can_at_branch(v_approver, 'RECEIPT', 'DUYET', r.branch_id) then
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

-- approve_receipt_accounting (thân bản migration 131, thêm nhánh nợ đầu kỳ).
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
  -- R-V2-15 (TC-02): phiếu thu nợ đầu kỳ (không đơn) do hàm riêng duyệt: khoản KTV không đơn, giảm nợ đầu kỳ, không cấp giờ.
  if r.is_opening_debt then
    return app.approve_opening_debt_receipt(p_id);
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

-- list_receipts (thân bản migration 083, nối trái đơn và thêm cờ).
create or replace function app.list_receipts(p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc', p_limit integer default null,
                                             p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('RECEIPT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_order uuid := nullif(p_filters ->> 'order_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_wait_mgr boolean := coalesce((p_filters ->> 'waiting_manager')::boolean, false);
  v_wait_acc boolean := coalesce((p_filters ->> 'waiting_accounting')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu thu.');
  end if;
  with f as not materialized (
    select r.*
      from app.receipt r
     where (v_scope = 'TOAN_HE_THONG' or r.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or r.status_code = any (v_status))
       and (v_branch is null or r.branch_id = v_branch)
       and (v_order is null or r.order_id = v_order)
       and (v_parent is null or r.parent_id = v_parent)
       and (not v_mine or r.created_by = auth.uid())
       and (not v_wait_mgr or (r.status_code = 'DA_GUI' and (r.assigned_approver_id = auth.uid() or r.approval_route = 'TRUONG_CS' and (select app.is_branch_manager_at(auth.uid(), 'RECEIPT', r.branch_id)))))
       and (not v_wait_acc or r.status_code = 'CHO_KE_TOAN')
       and (v_from is null or r.created_at >= v_from)
       and (v_to is null or r.created_at < v_to)
       and (v_q is null or r.search_text like '%' || v_q || '%')
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'amount_desc' then f.amount end desc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'status_code', p.status_code,
             'status', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_STATUS' and c.code = p.status_code),
             'order_id', p.order_id, 'order_code', o.code, 'is_opening_debt', p.is_opening_debt, 'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name,
             'amount', p.amount, 'payment_method_code', p.payment_method_code,
             'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = p.payment_method_code),
             'paid_on', p.paid_on, 'branch_code', b.code, 'collect_branch_code', cb.code,
             'created_at', p.created_at, 'created_by_name', app.staff_display_name(p.created_by),
             'approver_name', app.staff_display_name(p.assigned_approver_id), 'submitted_at', p.submitted_at)
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'amount_desc' then p.amount end desc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.branch cb on cb.id = p.collect_branch_id
    join app.parent par on par.id = p.parent_id
    left join app.sales_order o on o.id = p.order_id;
  return v_result;
end;
$$;

-- get_receipt (thân bản migration 083, chịu đơn rỗng).
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
  perform app.assert_can('RECEIPT', 'XEM', r.branch_id);
  if r.order_id is not null then
    select * into v_o from app.sales_order where id = r.order_id;
  end if;
  if r.status_code = 'NHAP' and r.created_by is not distinct from v_me and app.can_see_branch('RECEIPT', 'TAO', r.branch_id) then
    v_actions := v_actions || array['sua', 'gui'];
  end if;
  if r.status_code = 'DA_GUI' and app.can_see_branch('RECEIPT', 'DUYET', r.branch_id)
     and app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id, r.approval_route, r.branch_id) then
    v_actions := v_actions || array['duyet_quan_ly', 'tu_choi'];
  end if;
  if r.status_code = 'CHO_KE_TOAN' and app.can_see_branch('ACCOUNTING', 'DUYET', r.branch_id) then
    v_actions := v_actions || array['duyet_ke_toan', 'tu_choi'];
  end if;
  if r.status_code in ('NHAP', 'DA_GUI', 'CHO_KE_TOAN')
     and (r.created_by is not distinct from v_me and app.can_see_branch('RECEIPT', 'TAO', r.branch_id) or app.can_see_branch('RECEIPT', 'HUY', r.branch_id)) then
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
