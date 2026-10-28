-- ===========================================================================
-- P5a-DB-O1c (migration 062), CHỈ ĐỌC (Đ270, Đ271, Đ256; R-TIEN-13, R-TIEN-30, R-HT-06):
--  (1) get_quotation và get_order trả thêm `gross_total` (tổng niêm yết) và `discount_total` (tổng chiết khấu), bigint, do DB cộng từ các
--      dòng ĐÃ ĐÓNG BĂNG (không tính lại); dòng quà tặng không tính. Bản in báo giá (BH-03) dùng, giao diện không cộng.
--  (2) get_order trả thêm, CHỈ khi đơn Nháp, `expected_route` (QUAN_LY, TU_DUYET, THIEU), `expected_approver_id`, `expected_approver_name`
--      và `expected_approver_can_approve`: tính bằng app.approval_route(created_by), đúng đầu vào submit_order dùng để chốt người duyệt.
--      Người lập chưa có quản lý trực tiếp thì KHÔNG báo lỗi: THIEU, người duyệt rỗng.
--  (3) Ghi chú và lịch sử cho đơn hàng: đăng ký loại SALES_ORDER ở note_target và nhánh quyền xem trong app.can_see_note_target, GIỐNG HỆT
--      nhánh báo giá của migration 055 (Đơn hàng · Xem ở cơ sở của đơn; không chặn theo công tắc Bán hàng, Đ181).
-- Không bảng, chỉ mục mới; không đổi ma trận quyền; không ghi tiền, không ghi nhật ký.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

insert into app.note_target (entity_type, table_name, name) values ('SALES_ORDER', 'app.sales_order', 'Đơn hàng');

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

create or replace function app.get_quotation(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  q app.quotation;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_display text;
begin
  select * into q from app.quotation where id = p_id;
  if q.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy báo giá.');
  end if;
  perform app.assert_can('QUOTATION', 'XEM', q.branch_id);
  v_display := case when q.status_code = 'DA_GUI' and app.quotation_converted(q.id) then 'DA_CHUYEN_DON' else q.status_code end;
  return (to_jsonb(q) - 'search_text') || jsonb_build_object(
    'display_status_code', v_display,
    'display_status', (select c.name from app.catalog_item c where c.catalog_code = 'QUOTATION_STATUS' and c.code = v_display),
    'overdue_days', case when q.status_code = 'DA_GUI' and q.valid_until < v_today then v_today - q.valid_until end,
    'branch_code', (select b.code from app.branch b where b.id = q.branch_id),
    'opportunity_code', (select o.code from app.opportunity o where o.id = q.opportunity_id),
    'parent_code', (select p.code from app.parent p where p.id = q.parent_id),
    'parent_name', (select p.full_name from app.parent p where p.id = q.parent_id),
    'parent_phone', (select p.phone from app.parent p where p.id = q.parent_id),
    'created_by_name', app.staff_display_name(q.created_by),
    'sent_by_name', app.staff_display_name(q.sent_by),
    'reject_reason', (select c.name from app.catalog_item c where c.catalog_code = 'REJECT_REASON' and c.code = q.reject_reason_code),
    'has_incomplete_students', exists (
      select from app.quotation_line l join app.prospect_student_v v on v.id = l.prospect_student_id
       where l.quotation_id = q.id and (v.full_name is null or v.birth_year is null)),
    'lines', coalesce((
      select jsonb_agg(to_jsonb(l) - 'quotation_id' || jsonb_build_object(
               'student_name', v.full_name, 'student_birth_year', v.birth_year, 'student_code', v.student_code,
               'student_complete', (v.full_name is not null and v.birth_year is not null),
               'gift_policy_name', (select g.name from app.gift_policy g where g.id = l.gift_policy_id),
               -- Đơn đang sống của dòng (Đ106: tối đa một); chưa lên đơn hoặc đơn đã huỷ thì rỗng.
               'order_id', ol.order_id, 'order_code', ol.order_code, 'order_status_code', ol.order_status_code,
               'discounts', coalesce((select jsonb_agg(to_jsonb(d) - 'line_id' - 'branch_id' order by d.created_at, d.id)
                                        from app.quotation_line_discount d where d.line_id = l.id), '[]'::jsonb))
             order by l.line_no)
        from app.quotation_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
        left join lateral (select o.id as order_id, o.code as order_code, o.status_code as order_status_code
                             from app.sales_order_line sl join app.sales_order o on o.id = sl.order_id
                            where sl.quotation_line_id = l.id and sl.is_live) ol on true
       where l.quotation_id = q.id), '[]'::jsonb),
    -- Tổng niêm yết và tổng chiết khấu do DB cộng từ các dòng đã đóng băng, không tính lại; dòng quà tặng không tính (R-TIEN-30).
    'gross_total', (select coalesce(sum(l3.gross_amount), 0)::bigint from app.quotation_line l3
                     where l3.quotation_id = q.id and l3.line_kind = 'ENROL'),
    'discount_total', (select coalesce(sum(l3.discount_amount), 0)::bigint from app.quotation_line l3
                        where l3.quotation_id = q.id and l3.line_kind = 'ENROL'),
    -- Số đơn đang sống sinh từ báo giá này (cho nút "Đơn hàng" của BH-02).
    'live_order_count', (select count(distinct sl.order_id)::integer
                           from app.quotation_line l2 join app.sales_order_line sl on sl.quotation_line_id = l2.id and sl.is_live
                          where l2.quotation_id = q.id));
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
  return (to_jsonb(o) - 'search_text') || jsonb_build_object(
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

revoke execute on function app.get_quotation(uuid), app.get_order(uuid) from public, anon;
grant execute on function app.get_quotation(uuid), app.get_order(uuid) to authenticated;
