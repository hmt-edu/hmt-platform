-- TT-D2a Tạo ĐƠN từ phiếu tái tục (Code C, 18/11/2026; Chat 13:20: «mỗi bước tiền kiểm quyền riêng và tạo trong một giao dịch»). Luật R-GD-13, R-V2-25 chốt lại 18/11, Đ187.
-- Làm gì: (1) khoá ngoại sales_order.renewal_ticket_id → upsale_ticket (cột và ràng buộc «đúng một gốc: cơ hội hoặc phiếu» đã có từ migration 051);
-- (2) app.create_order_from_upsale_ticket: tạo đơn Nháp từ phiếu ở L6, dòng gắn đúng học sinh và lớp của phiếu, hình thức học giữ như ghi danh cũ, giá tính bằng app.price_line
-- như đơn thường, phiếu sang L7B (Đã có đơn, chờ đóng tiền) trong CÙNG giao dịch; (3) app.list_upsale_orders: đơn của phiếu cho tab «Báo giá và đơn»;
-- (4) app.reconcile_upsale_orders: đơn đóng đủ thì phiếu sang L8A, đơn Huỷ thì phiếu về L6. Ghi danh mới do hàm app.create_enrollments_for_order SẴN CÓ tạo khi đơn duyệt và đủ cọc
-- (dòng có học sinh và lớp thì xếp thẳng vào lớp của phiếu, không vào hàng chờ xếp lớp).
-- CHƯA làm (PR sau, ghi trong PR): báo giá từ phiếu (bảng quotation còn bắt buộc cơ hội); sửa đơn Nháp từ phiếu bằng save_order (đang gắn với cơ hội).
select set_config('hmt.migration', 'on', false);

alter table app.sales_order add constraint sales_order_renewal_ticket_fk foreign key (renewal_ticket_id) references app.upsale_ticket (id);
-- Chỉ mục (lý do): tra đơn của một phiếu (tab Báo giá và đơn, chặn tạo đơn thứ hai, đối soát).
create index sales_order_renewal_ticket_idx on app.sales_order (renewal_ticket_id) where renewal_ticket_id is not null;

-- ---------------------------------------------------------------------------
-- app.create_order_from_upsale_ticket(phiếu, dòng, điều khoản, ngày vào lớp) -> {id, code, total_amount}
-- Ai gọi: người vừa có quyền Đơn hàng · Tạo vừa có quyền Phiếu tái tục · Sửa ở cơ sở của phiếu (mỗi bước kiểm riêng). Cần Bán hàng bật.
-- p_lines: mảng {kind (ENROL mặc định, hoặc GIFT), package_id, quantity, discounts, gift_policy_id, delivery_mode_code (tuỳ chọn)}. Học sinh và lớp lấy từ PHIẾU,
-- không nhận từ đầu vào; hình thức học mặc định giữ như ghi danh cũ của em ở lớp (R-GD-13). p_enrol_start_date: ngày vào lớp (mặc định hôm nay giờ Việt Nam).
-- Luật: phiếu phải ở L6 Đồng ý tái tục (HMT_PHIEU_CHUA_DONG_Y); mỗi phiếu tối đa một đơn đang sống (HMT_PHIEU_DA_CO_DON); học sinh phải còn học ở lớp.
-- ---------------------------------------------------------------------------
create or replace function app.create_order_from_upsale_ticket(p_ticket_id uuid, p_lines jsonb, p_payment_term_id uuid default null, p_enrol_start_date date default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_start date;
  v_mode text;
  e jsonb;
  d jsonb;
  r jsonb;
  v_n integer := 0;
  v_kind text;
  v_class uuid;
  v_line_id uuid;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn cần ít nhất một dòng.');
  end if;
  select * into t from app.upsale_ticket where id = p_ticket_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  -- Hai quyền, kiểm riêng từng bước (Chat 13:20).
  perform app.assert_can('SALES_ORDER', 'TAO', t.branch_id);
  perform app.assert_can('UPSALE', 'SUA', t.branch_id);
  perform app.require_feature('BAN_HANG', t.branch_id);
  -- Luật R-GD-13: chỉ phiếu đã Đồng ý tái tục (L6) tạo được đơn.
  if t.stage_code <> 'L6' then
    perform app.raise_error('HMT_PHIEU_CHUA_DONG_Y', 'Chỉ tạo được đơn khi phiếu tái tục ở giai đoạn Đồng ý tái tục (L6).');
  end if;
  -- Luật Đ187: mỗi phiếu tối đa một đơn đang sống (Nháp, Đã trình, Đã duyệt).
  if exists (select from app.sales_order where renewal_ticket_id = t.id and status_code in ('NHAP', 'DA_TRINH', 'DA_DUYET')) then
    perform app.raise_error('HMT_PHIEU_DA_CO_DON', 'Phiếu tái tục này đã có đơn đang xử lý.');
  end if;
  -- Luật R-GD-13: học sinh còn học ở lớp của phiếu; hình thức học giữ như ghi danh cũ.
  select e2.delivery_mode_code into v_mode
    from app.enrollment e2 join app.enrollment_class ec on ec.enrollment_id = e2.id and ec.class_id = t.class_id and ec.end_date is null
   where e2.student_id = t.student_id and e2.status_code in ('DA_XEP_LOP', 'DANG_HOC') order by e2.created_at desc limit 1;
  if not found then
    perform app.raise_error('HMT_HOC_SINH_KHONG_O_LOP', 'Học sinh này hiện không học ở lớp của phiếu nên chưa tạo được đơn tái tục.');
  end if;
  -- Ngày vào lớp: không truyền thì lấy buổi sắp tới gần nhất của lớp (ghi danh phải vào đúng một buổi sắp tới, R-GD-06); kiểm sớm để báo lỗi ngay thay vì rơi vào hàng chờ xếp lớp.
  v_start := coalesce(p_enrol_start_date,
                      (select min(s.session_date) from app.class_session s
                        where s.class_id = t.class_id and s.status_code in ('NHAP', 'DA_CHOT') and s.session_date >= v_on),
                      v_on);
  perform app.assert_enrol_start_date(t.class_id, v_start, 'Đơn tái tục');
  select code into v_branch_code from app.branch where id = t.branch_id;
  v_code := app.issue_document_number('DH', v_branch_code);
  insert into app.sales_order (code, branch_id, renewal_ticket_id, parent_id, priced_on)
  values (v_code, t.branch_id, t.id, t.parent_id, v_on)
  returning id into v_id;
  -- Dòng đơn: học sinh, lớp lấy từ phiếu; giá tính như đơn thường (R-TIEN-13, 14).
  for e in select * from jsonb_array_elements(p_lines) loop
    v_n := v_n + 1;
    v_kind := coalesce(nullif(e ->> 'kind', ''), 'ENROL');
    v_class := case when v_kind = 'ENROL' then t.class_id end;
    r := app.price_line(v_n, v_kind, nullif(e ->> 'package_id', '')::uuid, coalesce(nullif(e ->> 'delivery_mode_code', ''), v_mode),
                        nullif(e ->> 'quantity', '')::numeric, e -> 'discounts', nullif(e ->> 'gift_policy_id', '')::uuid, t.branch_id, v_on);
    perform app.check_order_line_class(v_n, v_class, (r ->> 'package_id')::uuid, t.branch_id);
    insert into app.sales_order_line (
      order_id, branch_id, line_no, line_kind, student_id, package_id, package_code, package_name, package_type_code,
      delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent, gift_percent,
      discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date)
    values (
      v_id, t.branch_id, v_n, v_kind, t.student_id,
      (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
      r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
      (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
      (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
      (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
      v_class, case when v_class is not null then v_start end)
    returning id into v_line_id;
    for d in select * from jsonb_array_elements(r -> 'discounts') loop
      insert into app.sales_order_line_discount (line_id, branch_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
      values (v_line_id, t.branch_id, (d ->> 'policy_id')::uuid, d ->> 'policy_code', d ->> 'policy_name', d ->> 'kind',
              (d ->> 'applied_value')::numeric, (d ->> 'requires_approval')::boolean);
    end loop;
  end loop;
  -- Điều khoản thanh toán áp ngay trong cùng giao dịch (Đ260, R-CRM-19); sai thì cả giao dịch lùi.
  if p_payment_term_id is not null then
    perform app.order_apply_term(v_id, p_payment_term_id);
  end if;
  perform app.order_refresh_totals(v_id);
  perform app.order_add_event(v_id, 'TAO', null, 'NHAP', null, null, 'Tạo từ phiếu tái tục ' || t.code);
  -- Phiếu sang L7B «Đã có đơn, chờ đóng tiền» trong cùng giao dịch (R-GD-13, 26/10).
  update app.upsale_ticket set stage_code = 'L7', substage_code = 'L7B' where id = t.id;
  perform app.upsale_add_event(t.id, 'DOI_GIAI_DOAN', 'L6', 'L7', 'Tạo đơn ' || v_code);
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', (select total_amount from app.sales_order where id = v_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- app.list_upsale_orders(phiếu): đơn của một phiếu cho tab «Báo giá và đơn». Ai gọi: Phiếu tái tục · Xem ở cơ sở của phiếu; chỉ trả đơn người gọi xem được (RLS của đơn).
-- ---------------------------------------------------------------------------
create or replace function app.list_upsale_orders(p_ticket_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  select branch_id into v_branch from app.upsale_ticket where id = p_ticket_id;
  if v_branch is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'XEM', v_branch);
  -- Người xem đơn cần quyền Đơn hàng · Xem; không có thì danh sách trống (không lộ tiền).
  if not app.can_see_branch('SALES_ORDER', 'XEM', v_branch) then
    return '[]'::jsonb;
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'code', o.code, 'status_code', o.status_code, 'total_amount', o.total_amount,
                                                       'created_at', o.created_at) order by o.created_at, o.id)
                     from app.sales_order o where o.renewal_ticket_id = p_ticket_id), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- app.reconcile_upsale_orders(): đối soát phiếu ở L7 với đơn của phiếu. Chạy cùng lịch đêm hoặc Admin (hai bước) gọi tay.
-- (a) Đơn Đã duyệt và đã thu đủ tổng tiền: phiếu sang L8A «Đã đóng đủ, đã cấp quỹ giờ mới» (ghi danh mới do create_enrollments_for_order cấp khi đủ cọc);
-- (b) mọi đơn của phiếu đều Huỷ: phiếu về L6 để tạo đơn khác. Kết quả {completed, reopened}.
-- ---------------------------------------------------------------------------
create or replace function app.reconcile_upsale_orders()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_done integer := 0;
  v_back integer := 0;
begin
  if auth.uid() is not null and not ('ADMIN' = any (app.current_roles()) and app.mfa_satisfied()) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ Admin (đã xác thực hai bước) chạy đối soát đơn của phiếu tái tục.');
  end if;
  for r in
    select t.id, t.branch_id from app.upsale_ticket t where t.stage_code = 'L7' and t.substage_code = 'L7B'
       and app.feature_enabled('BAN_HANG', t.branch_id) for update of t
  loop
    if exists (select from app.sales_order o where o.renewal_ticket_id = r.id and o.status_code = 'DA_DUYET'
                and app.order_paid_amount(o.id) >= o.total_amount) then
      update app.upsale_ticket set stage_code = 'L8', substage_code = 'L8A', closed_at = now() where id = r.id;
      perform app.upsale_add_event(r.id, 'DOI_GIAI_DOAN', 'L7', 'L8', 'Hệ thống: đơn đã đóng đủ');
      v_done := v_done + 1;
    elsif not exists (select from app.sales_order o where o.renewal_ticket_id = r.id and o.status_code <> 'HUY')
          and exists (select from app.sales_order o where o.renewal_ticket_id = r.id) then
      update app.upsale_ticket set stage_code = 'L6', substage_code = null where id = r.id;
      perform app.upsale_add_event(r.id, 'DOI_GIAI_DOAN', 'L7', 'L6', 'Hệ thống: đơn đã huỷ, phiếu về Đồng ý tái tục');
      v_back := v_back + 1;
    end if;
  end loop;
  return jsonb_build_object('completed', v_done, 'reopened', v_back);
end;
$$;

-- Lịch đêm chạy cả hai việc (thay bản của migration 415; vẫn KHÔNG tự đăng ký trong migration, chờ anh duyệt).
create or replace function app.sync_upsale_cron()
returns text
language plpgsql
security definer
set search_path = ''
as $$
begin
  if to_regnamespace('cron') is null then
    perform app.raise_error('HMT_PG_CRON_CHUA_BAT', 'pg_cron chưa được bật trên cơ sở dữ liệu này. Bật pg_cron rồi gọi lại.');
  end if;
  if auth.uid() is not null and not ('ADMIN' = any (app.current_roles()) and app.mfa_satisfied()) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ Admin (đã xác thực hai bước) đổi lịch tự sinh phiếu tái tục.');
  end if;
  perform cron.schedule('hmt-generate-upsale-tickets', '0 19 * * *', 'select app.generate_upsale_tickets(); select app.reconcile_upsale_orders()'); -- allow-number: 19 giờ UTC là 02 giờ sáng giờ Việt Nam
  return '0 19 * * * (02:00 giờ Việt Nam)';
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.create_order_from_upsale_ticket(uuid, jsonb, uuid, date), app.list_upsale_orders(uuid), app.reconcile_upsale_orders() from public, anon;
grant execute on function app.create_order_from_upsale_ticket(uuid, jsonb, uuid, date), app.list_upsale_orders(uuid), app.reconcile_upsale_orders() to authenticated;
