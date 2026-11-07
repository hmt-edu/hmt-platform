-- ===========================================================================
-- Dòng thời gian một cột cho Đơn hàng và Phiếu thu (anh chốt 07/11: Q-48, Q-51, Q-52, Q-53).
--  (1) sales_order_event.total_amount: ảnh chụp tổng tiền của đơn lúc ghi sự kiện (bigint đồng). order_add_event ghi cho mọi sự kiện mới. Giao diện hiện
--      "Tổng tiền" ở Tạo, Sửa (cũ → mới, lấy từ sự kiện liền trước), Duyệt, không còn mục "Tổng tiền" riêng từ nhật ký thay đổi. Sự kiện cũ để trống.
--  (2) edit_order: lời nhật ký SUA một tiêu đề cộng mỗi thay đổi một dòng ("dòng 1 (LC-TOAN-K09): số giờ 48 → 50"), để giao diện hiện từng dòng.
--  (3) get_order trả thêm total_amount của từng sự kiện.
--  (4) Phiếu thu thành loại ghi chú RECEIPT (note_target) và nhánh quyền xem trong can_see_note_target: Phiếu thu · Xem ở cơ sở của phiếu.
-- Không bảng mới, không đổi ma trận quyền. Cột mới cho phép trống (sự kiện cũ).
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

alter table app.sales_order_event add column total_amount bigint check (total_amount is null or total_amount >= 0);
comment on column app.sales_order_event.total_amount is 'Tổng tiền của đơn lúc ghi sự kiện (ảnh chụp, đồng). Trống ở sự kiện ghi trước 07/11.';

-- Ghi sự kiện đơn: thêm ảnh chụp tổng tiền hiện tại của đơn.
create or replace function app.order_add_event(
  p_order_id uuid, p_event text, p_from text, p_to text, p_reason_catalog text default null, p_reason_code text default null,
  p_note text default null, p_on_behalf boolean default false)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into app.sales_order_event (order_id, event_code, from_status, to_status, reason_catalog, reason_code, note, on_behalf, total_amount)
  select o.id, p_event, p_from, p_to, p_reason_catalog, p_reason_code, nullif(btrim(coalesce(p_note, '')), ''), p_on_behalf, o.total_amount
    from app.sales_order o where o.id = p_order_id;
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
      -- Q-51 (anh chốt 07/11): dòng đầu là tiêu đề, mỗi thay đổi một dòng (giao diện tách theo dòng); tổng tiền cũ, mới lấy từ ảnh chụp tổng tiền
      -- của hai sự kiện liền nhau (cột total_amount), không viết lại ở đây.
      case when v_qcode is not null then format('Đơn đã sửa so với báo giá %s', v_qcode) else 'Sửa đơn' end
        || E'\n' || array_to_string(v_changes, E'\n'));
  end if;
  return jsonb_build_object('id', p_id, 'code', v_o.code, 'total_amount', (select total_amount from app.sales_order where id = p_id),
                            'changed', cardinality(v_changes) > 0);
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

CREATE OR REPLACE FUNCTION app.can_see_note_target(p_entity_type text, p_entity_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_branch_id uuid;
  v_test app.student_test;
begin
  if not app.current_user_ready() then
    return false;
  end if;
  if not app.mfa_satisfied() then
    return false;
  end if;
  if app.has_permission('ADMIN', 'XEM') then
    return true;
  end if;
  if p_entity_type = 'USER_ACCOUNT' then
    select branch_id into v_branch_id from app.user_account where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('ACCOUNT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'LEAD' then
    select branch_id into v_branch_id from app.lead where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('LEAD', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'OPPORTUNITY' then
    select branch_id into v_branch_id from app.opportunity where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('OPPORTUNITY', 'XEM', v_branch_id);
  end if;
  -- Luật: phiếu theo quyền Kiểm tra đầu vào · Xem và phạm vi của phiếu (cơ sở, hoặc được phân công).
  if p_entity_type = 'STUDENT_TEST' then
    select * into v_test from app.student_test where id = p_entity_id;
    return v_test.id is not null and app.test_scope_ok('XEM', v_test);
  end if;
  -- Luật: phụ huynh, học sinh theo quyền Xem của phân hệ: toàn hệ thống, hoặc đúng cơ sở tiếp nhận.
  -- Luật (27/10): báo giá theo quyền Báo giá · Xem ở cơ sở của báo giá (BH-02, Ghi chú và hoạt động).
  if p_entity_type = 'QUOTATION' then
    select branch_id into v_branch_id from app.quotation where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('QUOTATION', 'XEM', v_branch_id);
  end if;
  -- Luật (28/10): đơn hàng theo quyền Đơn hàng · Xem ở cơ sở của đơn, giống hệt báo giá (BH-05, Ghi chú và hoạt động).
  if p_entity_type = 'SALES_ORDER' then
    select branch_id into v_branch_id from app.sales_order where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('SALES_ORDER', 'XEM', v_branch_id);
  end if;
  -- Luật (07/11, Q-52): phiếu thu theo quyền Phiếu thu · Xem ở cơ sở của phiếu (cơ sở của đơn), giống hệt đơn hàng; Kế toán (toàn hệ thống) thấy mọi cơ sở.
  if p_entity_type = 'RECEIPT' then
    select branch_id into v_branch_id from app.receipt where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('RECEIPT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'PARENT' then
    select branch_id into v_branch_id from app.parent where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('PARENT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'STUDENT' then
    select branch_id into v_branch_id from app.student where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('STUDENT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'BRANCH' then
    v_branch_id := p_entity_id;
  elsif p_entity_type = 'ROOM' then
    select branch_id into v_branch_id from app.room where id = p_entity_id;
  else
    return false;
  end if;
  return v_branch_id is not distinct from app.current_branch_id()
      or exists (select from app.role r where r.code = any (app.current_roles()) and r.default_scope = 'TOAN_HE_THONG');
end;
$function$;

-- Phiếu thu là loại ghi chú: đăng ký ở note_target (bảng cho lịch sử thay đổi), quyền xem ở hàm trên.
insert into app.note_target (entity_type, table_name, name) values ('RECEIPT', 'app.receipt', 'Phiếu thu');

revoke execute on function app.edit_order(uuid, jsonb, uuid) from public, anon;
grant execute on function app.edit_order(uuid, jsonb, uuid) to authenticated;
revoke execute on function app.get_order(uuid) from public, anon;
grant execute on function app.get_order(uuid) to authenticated;
revoke execute on function app.order_add_event(uuid, text, text, text, text, text, text, boolean) from public, anon, authenticated;

select set_config('hmt.migration', '', false);
