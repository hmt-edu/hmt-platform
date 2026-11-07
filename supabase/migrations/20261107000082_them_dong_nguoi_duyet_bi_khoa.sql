-- ===========================================================================
-- Bước 3, PR A (anh chốt 07/11: Q-63, Q-67): Thêm dòng khi sửa đơn Nháp; câu lỗi riêng khi người duyệt bị khoá.
--  (1) app.order_add_priced_line: thêm MỘT dòng đã tính giá vào đơn Nháp (nối số dòng), cùng cách app.order_write_priced_lines dựng dòng (price_line theo
--      ngày tính giá của đơn, kiểm em thuộc cơ hội, kiểm lớp). Hàm nội bộ cho edit_order.
--  (2) app.edit_order: phần tử mới {add: {...}} trong p_edits; nhật ký SUA ghi "thêm dòng N (mã gói)". Phần còn lại giữ nguyên bản 080.
--  (3) app.submit_order, app.submit_receipt: người duyệt đã chốt đang BỊ KHOÁ thì mã HMT_NGUOI_DUYET_BI_KHOA và câu "Quản lý trực tiếp của người lập
--      đang bị khoá nên chưa trình được. Nhờ Admin mở khoá hoặc đặt lại Quản lý trực tiếp."; thiếu quyền Duyệt ở cơ sở giữ HMT_NGUOI_DUYET_THIEU_QUYEN.
--  (4) app.get_order: thêm expected_block (KHONG_CO_QUAN_LY, NGUOI_DUYET_BI_KHOA, NGUOI_DUYET_THIEU_QUYEN, null), chỉ khi đơn Nháp; các trường cũ giữ nguyên.
-- Không bảng, chỉ mục mới; không đổi quyền.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

-- Thêm một dòng đã tính giá vào đơn Nháp. Ai gọi: edit_order (đã kiểm quyền, trạng thái, công tắc). Đầu vào: đơn, cơ hội, cơ sở, mô tả dòng, ngày tính giá.
-- Kết quả: {line_no, package_code, line_total, quantity, discount_percent, gifted_quantity, over_cap} (số do price_line tính; edit_order ghi vào nhật ký). Lỗi có mã của price_line, validate_line_student, check_order_line_class.
create or replace function app.order_add_priced_line(p_order_id uuid, p_opportunity_id uuid, p_branch_id uuid, p_spec jsonb, p_on date)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d jsonb;
  r jsonb;
  v_n integer;
  v_line_id uuid;
  v_class uuid;
  v_start date;
begin
  select coalesce(max(line_no), 0) + 1 into v_n from app.sales_order_line where order_id = p_order_id;
  -- Luật Đ83: học sinh chọn trong danh sách em của cơ hội.
  perform app.validate_line_student(v_n, p_opportunity_id, nullif(p_spec ->> 'prospect_student_id', '')::uuid);
  v_class := nullif(p_spec ->> 'class_id', '')::uuid;
  v_start := nullif(p_spec ->> 'enrol_start_date', '')::date;
  if v_class is not null and v_start is null then
    perform app.raise_error('HMT_THIEU_NGAY_VAO_LOP', format('Dòng %s: chọn lớp thì cần ngày vào lớp.', v_n));
  end if;
  r := app.price_line(v_n, coalesce(nullif(p_spec ->> 'kind', ''), 'ENROL'), nullif(p_spec ->> 'package_id', '')::uuid,
                      p_spec ->> 'delivery_mode_code', nullif(p_spec ->> 'quantity', '')::numeric, p_spec -> 'discounts',
                      nullif(p_spec ->> 'gift_policy_id', '')::uuid, p_branch_id, p_on);
  perform app.check_order_line_class(v_n, v_class, (r ->> 'package_id')::uuid, p_branch_id);
  insert into app.sales_order_line (
    order_id, line_no, line_kind, prospect_student_id, package_id, package_code, package_name, package_type_code,
    delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent, gift_percent,
    discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date)
  values (
    p_order_id, v_n, coalesce(nullif(p_spec ->> 'kind', ''), 'ENROL'), (p_spec ->> 'prospect_student_id')::uuid,
    (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
    r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
    (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
    (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
    (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
    v_class, v_start)
  returning id into v_line_id;
  for d in select * from jsonb_array_elements(r -> 'discounts') loop
    insert into app.sales_order_line_discount (line_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
    values (v_line_id, (d ->> 'policy_id')::uuid, d ->> 'policy_code', d ->> 'policy_name', d ->> 'kind',
            (d ->> 'applied_value')::numeric, (d ->> 'requires_approval')::boolean);
  end loop;
  return jsonb_build_object('line_no', v_n, 'package_code', r ->> 'package_code', 'line_total', (r ->> 'line_total')::bigint,
                            'quantity', (r ->> 'quantity')::numeric, 'discount_percent', (r ->> 'discount_percent')::numeric,
                            'gifted_quantity', (r ->> 'gifted_quantity')::numeric, 'over_cap', (r ->> 'over_cap')::boolean);
end;
$$;

-- app.edit_order(đơn, danh sách sửa, điều khoản). Ai gọi: người có quyền Đơn hàng · Sửa ở cơ sở của đơn (Bán hàng bật, Đ173), đơn Nháp.
-- Đầu vào: p_edits mảng {line_no, quantity, delivery_mode_code, discounts [{policy_id, value}], remove}; p_payment_term_id (đổi điều khoản).
-- Kết quả: {id, code, total_amount, changed}. Lỗi có mã: HMT_DON_DA_KHOA, HMT_DONG_KHONG_CO, HMT_DON_KHONG_DONG, các lỗi của price_line.
create or replace function app.edit_order(p_id uuid, p_edits jsonb default null, p_payment_term_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  e jsonb;
  l app.sales_order_line;
  n app.sales_order_line;
  r jsonb;
  v_discounts jsonb;
  v_changes text[] := array[]::text[];
  v_diff text;
  v_old_term text;
  v_new_term text;
  v_qcode text;
  v_i integer;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'SUA', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code <> 'NHAP' then
    perform app.raise_error('HMT_DON_DA_KHOA', 'Đơn đã trình: không sửa được. Nhờ người duyệt từ chối để đưa về Nháp.');
  end if;
  -- Điều khoản thanh toán.
  if p_payment_term_id is not null and p_payment_term_id is distinct from v_o.payment_term_id then
    select coalesce((select name from app.payment_term where id = v_o.payment_term_id), 'chưa chọn') into v_old_term;
    perform app.order_apply_term(p_id, p_payment_term_id);
    select name into v_new_term from app.payment_term where id = p_payment_term_id;
    v_changes := array_append(v_changes, format('điều khoản thanh toán %s → %s', v_old_term, v_new_term));
  end if;
  -- Sửa từng dòng tại chỗ (giữ học sinh, gói, liên kết dòng báo giá); tính lại theo ngày tính giá của đơn (R-TIEN-14).
  if p_edits is not null then
    if jsonb_typeof(p_edits) <> 'array' then
      perform app.raise_error('HMT_DONG_THIEU', 'Danh sách sửa dòng không hợp lệ.');
    end if;
    for e in select * from jsonb_array_elements(p_edits) loop
      -- Thêm dòng mới (Q-67, canvas BH05_nhap_sua): phần tử {add: {kind, prospect_student_id, package_id, delivery_mode_code, quantity, discounts,
      -- gift_policy_id}}; tính giá theo ngày tính giá của đơn (R-TIEN-14), kiểm em thuộc cơ hội (Đ83), nối số dòng. Nhật ký ghi mã gói.
      if e ? 'add' then
        if v_o.opportunity_id is null then
          perform app.raise_error('HMT_DON_KHONG_CO_CO_HOI', 'Đơn này không sinh từ cơ hội nên chưa thêm dòng được.');
        end if;
        r := app.order_add_priced_line(p_id, v_o.opportunity_id, v_o.branch_id, e -> 'add', v_o.priced_on);
        -- Nhật ký (Q-69): mã gói, số giờ, chiết khấu % và giờ tặng do máy chủ tính. Vượt trần chiết khấu chỉ cảnh báo (R-V2-11), KHÔNG chặn ở đây: cảnh báo hiện ở hộp Duyệt.
        v_changes := array_append(v_changes, format('thêm dòng %s (%s): số giờ %s%s%s', r ->> 'line_no', r ->> 'package_code',
          trim_scale((r ->> 'quantity')::numeric),
          case when (r ->> 'discount_percent')::numeric > 0 then format(', chiết khấu %s%%', trim_scale((r ->> 'discount_percent')::numeric)) else '' end,
          case when (r ->> 'gifted_quantity')::numeric > 0 then format(', tặng %s giờ', trim_scale((r ->> 'gifted_quantity')::numeric)) else '' end));
        continue;
      end if;
      select * into l from app.sales_order_line where order_id = p_id and line_no = (e ->> 'line_no')::integer;
      if l.id is null then
        perform app.raise_error('HMT_DONG_KHONG_CO', format('Không có dòng %s trong đơn.', e ->> 'line_no'));
      end if;
      if coalesce((e ->> 'remove')::boolean, false) then
        delete from app.sales_order_line_discount where line_id = l.id;
        delete from app.sales_order_line where id = l.id;
        v_changes := array_append(v_changes, format('bỏ dòng %s (%s)', l.line_no, l.package_code));
        continue;
      end if;
      if l.line_kind = 'GIFT' then
        continue; -- dòng quà tặng chỉ bỏ được, không tính lại
      end if;
      -- Chính sách giữ nguyên nếu không gửi: chính sách cố định không truyền giá trị, còn lại truyền giá trị đã áp.
      v_discounts := case when e ? 'discounts' then e -> 'discounts' else coalesce((
        select jsonb_agg(jsonb_build_object('policy_id', d.policy_id, 'value', case when p.fixed_value then null else d.applied_value end))
          from app.sales_order_line_discount d join app.discount_policy p on p.id = d.policy_id where d.line_id = l.id), '[]'::jsonb) end;
      r := app.price_line(l.line_no, l.line_kind, l.package_id, coalesce(nullif(e ->> 'delivery_mode_code', ''), l.delivery_mode_code),
                          coalesce(nullif(e ->> 'quantity', '')::numeric, l.quantity), v_discounts, null, v_o.branch_id, v_o.priced_on);
      update app.sales_order_line set delivery_mode_code = r ->> 'delivery_mode_code', quantity = (r ->> 'quantity')::numeric,
             gifted_quantity = (r ->> 'gifted_quantity')::numeric, unit_price = (r ->> 'unit_price')::bigint,
             gross_amount = (r ->> 'gross_amount')::bigint, discount_percent = (r ->> 'discount_percent')::numeric,
             gift_percent = (r ->> 'gift_percent')::numeric, discount_amount = (r ->> 'discount_amount')::bigint,
             line_total = (r ->> 'line_total')::bigint, over_cap = (r ->> 'over_cap')::boolean,
             needs_acknowledgement = (r ->> 'needs_acknowledgement')::boolean
       where id = l.id returning * into n;
      delete from app.sales_order_line_discount where line_id = l.id;
      insert into app.sales_order_line_discount (line_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
      select l.id, (d ->> 'policy_id')::uuid, d ->> 'policy_code', d ->> 'policy_name', d ->> 'kind', (d ->> 'applied_value')::numeric,
             (d ->> 'requires_approval')::boolean from jsonb_array_elements(r -> 'discounts') d;
      v_diff := app.order_line_diff_text(l, n);
      if v_diff is not null then
        v_changes := array_append(v_changes, format('dòng %s (%s): %s', l.line_no, l.package_code, v_diff));
      end if;
    end loop;
    if not exists (select from app.sales_order_line where order_id = p_id) then
      perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn cần ít nhất một dòng.');
    end if;
    -- Đánh lại số dòng liên tục sau khi bỏ dòng (hai bước để không đụng ràng buộc duy nhất của số dòng).
    update app.sales_order_line s set line_no = x.rn + 100000 -- allow-number: số đệm tránh trùng khi đánh lại số dòng
      from (select id, row_number() over (order by line_no)::integer as rn from app.sales_order_line where order_id = p_id) x where s.id = x.id;
    update app.sales_order_line set line_no = line_no - 100000 where order_id = p_id; -- allow-number: số đệm tránh trùng khi đánh lại số dòng
  end if;
  perform app.order_refresh_totals(p_id);
  -- Nhật ký (Q-31): đơn từ báo giá ghi "Đơn đã sửa so với báo giá <mã>" kèm cũ, mới; không chặn.
  if cardinality(v_changes) > 0 then
    select code into v_qcode from app.quotation where id = v_o.quotation_id;
    perform app.order_add_event(p_id, 'SUA', 'NHAP', 'NHAP', null, null,
      -- Q-51 (anh chốt 07/11): dòng đầu là tiêu đề, mỗi thay đổi một dòng (giao diện tách theo dòng); tổng tiền cũ, mới lấy từ ảnh chụp tổng tiền
      -- của hai sự kiện liền nhau (cột total_amount), không viết lại ở đây.
      case when v_qcode is not null then format('Đơn đã sửa so với báo giá %s', v_qcode) else 'Sửa đơn' end
        || E'\n' || array_to_string(v_changes, E'\n'));
  end if;
  return jsonb_build_object('id', p_id, 'code', v_o.code, 'total_amount', (select total_amount from app.sales_order where id = p_id),
                            'changed', cardinality(v_changes) > 0);
end;
$$;

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
  -- Luật Q-63 (anh chốt 07/11): người duyệt đã chốt đang bị KHOÁ thì nói rõ, KHÁC với người duyệt thiếu quyền (câu bên dưới giữ nguyên).
  if v_approver is not null and exists (select from app.user_account a where a.id = v_approver and a.is_locked) then
    perform app.raise_error('HMT_NGUOI_DUYET_BI_KHOA',
      'Quản lý trực tiếp của người lập đang bị khoá nên chưa trình được. Nhờ Admin mở khoá hoặc đặt lại Quản lý trực tiếp.');
  end if;
  -- Luật Đ205: người duyệt đã chốt phải có quyền Duyệt đơn ở cơ sở này.
  if not app.user_can_at_branch(v_approver, 'SALES_ORDER', 'DUYET', v_o.branch_id) then
    perform app.raise_error('HMT_NGUOI_DUYET_THIEU_QUYEN',
      'Quản lý trực tiếp của người lập chưa có quyền Duyệt đơn hàng ở cơ sở này nên chưa trình được. Nhờ Admin đặt lại Quản lý trực tiếp hoặc cấp quyền.');
  end if;
  update app.sales_order set status_code = 'DA_TRINH', approval_route = v_route, assigned_approver_id = v_approver,
         submitted_at = now(), submitted_by = auth.uid() where id = p_id;
  -- Luật Q-29 (anh chốt 06/11): trình lại mà chưa sửa gì từ lần bị từ chối thì nhật ký ghi rõ (không chặn, hộp xác nhận ở giao diện).
  perform app.order_add_event(p_id, 'TRINH', 'NHAP', 'DA_TRINH', null, null,
                              case when app.order_resubmitted_unedited(p_id) then 'Trình lại, chưa sửa từ lần bị từ chối' end);
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
  -- Luật Q-63 (anh chốt 07/11): người duyệt đã chốt đang bị KHOÁ thì nói rõ, KHÁC với người duyệt thiếu quyền (câu bên dưới giữ nguyên).
  if v_approver is not null and exists (select from app.user_account a where a.id = v_approver and a.is_locked) then
    perform app.raise_error('HMT_NGUOI_DUYET_BI_KHOA',
      'Quản lý trực tiếp của người lập đang bị khoá nên chưa trình được. Nhờ Admin mở khoá hoặc đặt lại Quản lý trực tiếp.');
  end if;
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
    -- Q-63, Q-62: MỘT lý do chặn phía người duyệt cho giao diện (dải thông báo cạnh nút trình dùng lại, không đổi DB nữa); chỉ khi đơn Nháp.
    -- KHONG_CO_QUAN_LY, NGUOI_DUYET_BI_KHOA (người duyệt dự kiến đang bị khoá), NGUOI_DUYET_THIEU_QUYEN (không bị khoá nhưng thiếu quyền Duyệt
    -- ở cơ sở), null (không chặn). Trùng mã lỗi của submit_order.
    'expected_block', case when o.status_code <> 'NHAP' then null
                           when v_route = 'THIEU' then 'KHONG_CO_QUAN_LY'
                           when v_approver is null then null
                           when exists (select from app.user_account a where a.id = v_approver and a.is_locked) then 'NGUOI_DUYET_BI_KHOA'
                           when not app.user_can_at_branch(v_approver, 'SALES_ORDER', 'DUYET', o.branch_id) then 'NGUOI_DUYET_THIEU_QUYEN'
                           else null end,
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
               'reason_code', e.reason_code, 'note', e.note, 'on_behalf', e.on_behalf, 'created_at', e.created_at, 'total_amount', e.total_amount,
               'actor_name', app.staff_display_name(e.created_by)) order by e.seq)
        from app.sales_order_event e where e.order_id = o.id), '[]'::jsonb));
end;
$$;

revoke execute on function app.order_add_priced_line(uuid, uuid, uuid, jsonb, date) from public, anon, authenticated;
revoke execute on function app.edit_order(uuid, jsonb, uuid) from public, anon;
grant execute on function app.edit_order(uuid, jsonb, uuid) to authenticated;
revoke execute on function app.submit_order(uuid, boolean) from public, anon;
grant execute on function app.submit_order(uuid, boolean) to authenticated;
revoke execute on function app.submit_receipt(uuid) from public, anon;
grant execute on function app.submit_receipt(uuid) to authenticated;
revoke execute on function app.get_order(uuid) from public, anon;
grant execute on function app.get_order(uuid) to authenticated;

select set_config('hmt.migration', '', false);
