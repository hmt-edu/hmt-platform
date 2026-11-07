-- ===========================================================================
-- Đơn hàng bước 2: sửa đơn Nháp (anh chốt 06/11: B1 đổi, Q-29, Q-31).
--  (1) Sự kiện mới SUA của đơn (lịch sử đơn): ghi mỗi lần sửa có đổi gì, kèm giá trị cũ và mới (không lộ dữ liệu cá nhân: chỉ mã gói, số giờ, hình thức, %).
--  (2) app.edit_order(đơn, danh sách sửa, điều khoản): sửa đơn Nháp TẠI CHỖ, cả đơn lập thẳng từ cơ hội lẫn đơn chuyển từ báo giá. Mỗi phần tử
--      {line_no, quantity?, delivery_mode_code?, discounts?, remove?}; dòng không nêu giữ nguyên. Tính lại bằng app.price_line theo ngày tính giá của đơn
--      (priced_on: đơn thẳng là ngày tạo đơn, đơn từ báo giá là ngày của báo giá; R-TIEN-14). Dòng giữ nguyên học sinh, gói, liên kết dòng báo giá.
--      Anh chốt 07/11: báo giá chỉ là giấy in gửi phụ huynh, chuyển lên đơn là đi tắt; sau khi thành đơn Nháp thì sửa y như đơn thường, tính theo bảng giá tại
--      priced_on cho mọi dòng được sửa (đóng băng chỉ áp dụng lúc chuyển báo giá thành đơn, sao nguyên). Nhật ký ghi "đơn giá X → Y" khi đơn giá đổi.
--      Luật khoá cũ của save_order cho đơn từ báo giá (chỉ đổi lớp, ngày vào lớp) xuất phát từ R-TIEN-14 (đơn từ báo giá sao nguyên đơn giá, chiết khấu,
--      số giờ đã đóng băng lúc Gửi, R-TIEN-05): để giá đã báo cho phụ huynh không đổi. Anh chốt 06/11 (B1) đơn Nháp từ báo giá được sửa như đơn Nháp
--      thường, nhưng PHẢI ghi nhật ký "Đơn đã sửa so với báo giá <mã>" kèm cũ, mới (Q-31); không chặn. save_order giữ nguyên (lớp, ngày vào lớp).
--  (3) app.order_resubmitted_unedited(đơn): đơn vừa bị từ chối và chưa có sự kiện SUA nào sau lần từ chối cuối. submit_order thay thế: giữ MỌI kiểm cũ,
--      chỉ thêm ghi chú "Trình lại, chưa sửa từ lần bị từ chối" vào sự kiện TRINH khi đúng trường hợp đó (Q-29).
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

alter table app.sales_order_event drop constraint sales_order_event_event_code_check;
alter table app.sales_order_event add constraint sales_order_event_event_code_check
  check (event_code in ('TAO', 'TRINH', 'DUYET', 'TU_CHOI', 'HUY', 'SUA'));

-- Đơn vừa bị từ chối và chưa sửa từ lần từ chối cuối (dùng ở submit_order).
create or replace function app.order_resubmitted_unedited(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.sales_order_event r where r.order_id = p_order_id and r.event_code = 'TU_CHOI'
                  and r.seq = (select max(seq) from app.sales_order_event where order_id = p_order_id and event_code = 'TU_CHOI')
                  and not exists (select from app.sales_order_event s where s.order_id = p_order_id and s.event_code = 'SUA' and s.seq > r.seq));
$$;

-- Chữ cho một thay đổi của dòng: "dòng 2 (LC-TOAN-K09): số giờ 24 → 20; chiết khấu 10% → 5%".
create or replace function app.order_line_diff_text(p_old app.sales_order_line, p_new app.sales_order_line)
returns text
language sql
stable
set search_path = ''
as $$
  select nullif(concat_ws('; ',
    case when p_old.quantity <> p_new.quantity then format('số giờ %s → %s', trim_scale(p_old.quantity), trim_scale(p_new.quantity)) end,
    case when p_old.unit_price <> p_new.unit_price then format('đơn giá %s → %s',
      replace(to_char(p_old.unit_price, 'FM999,999,999,999'), ',', '.'), replace(to_char(p_new.unit_price, 'FM999,999,999,999'), ',', '.')) end,
    case when p_old.delivery_mode_code <> p_new.delivery_mode_code then format('hình thức %s → %s', p_old.delivery_mode_code, p_new.delivery_mode_code) end,
    case when p_old.discount_percent <> p_new.discount_percent then format('chiết khấu %s%% → %s%%', trim_scale(p_old.discount_percent), trim_scale(p_new.discount_percent)) end,
    case when p_old.gifted_quantity <> p_new.gifted_quantity then format('giờ tặng %s → %s', trim_scale(p_old.gifted_quantity), trim_scale(p_new.gifted_quantity)) end
  ), '');
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
      case when v_qcode is not null then format('Đơn đã sửa so với báo giá %s: %s', v_qcode, array_to_string(v_changes, '; '))
           else format('Sửa đơn: %s', array_to_string(v_changes, '; ')) end);
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

revoke execute on function app.order_resubmitted_unedited(uuid), app.order_line_diff_text(app.sales_order_line, app.sales_order_line) from public, anon, authenticated;
revoke execute on function app.edit_order(uuid, jsonb, uuid) from public, anon;
grant execute on function app.edit_order(uuid, jsonb, uuid) to authenticated;

select set_config('hmt.migration', '', false);
