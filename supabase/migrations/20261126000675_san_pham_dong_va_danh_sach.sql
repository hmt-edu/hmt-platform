-- B-26-03 PR-DB1 (tiếp): dòng báo giá, đơn chụp môn, khối đã chọn; danh sách sản phẩm bán trả đủ.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Dòng báo giá, đơn chụp môn và khối đã chọn (loại lớp đã chụp ở package_type_code).
-- ---------------------------------------------------------------------------
alter table app.quotation_line add column subject_code text, add column grade_code text;
alter table app.sales_order_line add column subject_code text, add column grade_code text;
comment on column app.sales_order_line.grade_code is 'Khối đã chọn trên dòng (PRODUCT_GRADE), chụp lúc lưu. Null = sản phẩm không gắn khối hoặc chưa chọn.';

-- Chụp môn, khối khi ghi dòng. Khối đã chọn phải nằm trong khối của sản phẩm; sản phẩm một khối thì tự điền.
-- Dòng đơn tạo từ báo giá sao nguyên môn, khối của dòng báo giá (R-TIEN-14).
create or replace function app.tg_sales_line_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  p app.sales_package;
begin
  if TG_TABLE_NAME = 'sales_order_line' then
    if (to_jsonb(new) ->> 'quotation_line_id') is not null then
      select q.subject_code, q.grade_code into new.subject_code, new.grade_code
        from app.quotation_line q where q.id = (to_jsonb(new) ->> 'quotation_line_id')::uuid;
      return new;
    end if;
  end if;
  select * into p from app.sales_package where id = new.package_id;
  new.subject_code := p.subject_code;
  new.grade_code := nullif(new.grade_code, '');
  if new.grade_code is null then
    if cardinality(p.grade_codes) = 1 then
      new.grade_code := p.grade_codes[1];
    end if;
  elsif not new.grade_code = any (p.grade_codes) then
    perform app.raise_error('HMT_KHOI_KHONG_THUOC_SAN_PHAM',
      format('Dòng %s: khối đã chọn không thuộc sản phẩm %s.', new.line_no, p.code));
  end if;
  return new;
end;
$$;
revoke execute on function app.tg_sales_line_snapshot() from public, anon, authenticated;
create trigger quotation_line_snapshot before insert on app.quotation_line
  for each row execute function app.tg_sales_line_snapshot();
create trigger sales_order_line_snapshot before insert on app.sales_order_line
  for each row execute function app.tg_sales_line_snapshot();

-- Dòng đã có: môn lấy theo sản phẩm; khối chỉ điền khi sản phẩm có đúng một khối (không đoán khối của sản phẩm dải).
update app.quotation_line l
   set subject_code = p.subject_code, grade_code = case when cardinality(p.grade_codes) = 1 then p.grade_codes[1] end
  from app.sales_package p where p.id = l.package_id;
update app.sales_order_line l
   set subject_code = p.subject_code, grade_code = case when cardinality(p.grade_codes) = 1 then p.grade_codes[1] end
  from app.sales_package p where p.id = l.package_id;

-- Lấy từ 20261026000045_p5a_bao_gia.sql; chỉ đổi phần chụp khối, môn (B-26-03).
create or replace function app.save_quotation(p_id uuid, p_opportunity_id uuid, p_lines jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q app.quotation;
  v_opp app.opportunity;
  v_branch_code text;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_id uuid;
  v_code text;
  v_total bigint := 0;
  v_warnings jsonb := '[]'::jsonb;
  v_line_id uuid;
  e jsonb;
  d jsonb;
  v_n integer := 0;
  r jsonb;
begin
  if p_lines is not null and jsonb_typeof(p_lines) <> 'array' then
    perform app.raise_error('HMT_DONG_THIEU', 'Danh sách dòng báo giá không hợp lệ.');
  end if;
  if p_id is null then
    select * into v_opp from app.opportunity where id = p_opportunity_id;
    if v_opp.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
    end if;
    -- Luật: quyền tạo báo giá ở cơ sở của cơ hội; cơ hội đã gộp thì không tạo (R-CRM-22).
    perform app.assert_can('QUOTATION', 'TAO', v_opp.branch_id);
    -- Luật Đ173: phân hệ Bán hàng phải bật ở cơ sở.
    perform app.require_feature('BAN_HANG', v_opp.branch_id);
    if v_opp.record_status = 'DA_GOP' then
      perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không tạo báo giá được.');
    end if;
    select code into v_branch_code from app.branch where id = v_opp.branch_id;
    v_code := app.issue_document_number('BG', v_branch_code);
    insert into app.quotation (code, branch_id, opportunity_id, parent_id, priced_on)
    values (v_code, v_opp.branch_id, v_opp.id, v_opp.parent_id, v_on)
    returning id into v_id;
    select * into v_q from app.quotation where id = v_id;
  else
    select * into v_q from app.quotation where id = p_id for update;
    if v_q.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy báo giá.');
    end if;
    perform app.assert_can('QUOTATION', 'SUA', v_q.branch_id);
    perform app.require_feature('BAN_HANG', v_q.branch_id); -- Luật Đ173
    -- Luật Đ169: chỉ báo giá Nháp lưu được; Gửi rồi thì đóng băng.
    if v_q.status_code <> 'NHAP' then
      perform app.raise_error('HMT_BAO_GIA_DA_KHOA', 'Báo giá đã gửi: không sửa được. Tạo báo giá mới nếu cần đổi.');
    end if;
    v_id := v_q.id;
    v_opp := (select o from app.opportunity o where o.id = v_q.opportunity_id);
    delete from app.quotation_line_discount where line_id in (select id from app.quotation_line where quotation_id = v_id);
    delete from app.quotation_line where quotation_id = v_id;
  end if;

  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_n := v_n + 1;
    -- Luật Đ83: học sinh chọn trong danh sách em của cơ hội.
    perform app.validate_line_student(v_n, v_opp.id, nullif(e ->> 'prospect_student_id', '')::uuid);
    r := app.price_line(v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), nullif(e ->> 'package_id', '')::uuid,
                        e ->> 'delivery_mode_code', nullif(e ->> 'quantity', '')::numeric, e -> 'discounts',
                        nullif(e ->> 'gift_policy_id', '')::uuid, v_opp.branch_id, v_on);
    insert into app.quotation_line (
      quotation_id, line_no, line_kind, prospect_student_id, package_id, package_code, package_name, package_type_code,
      delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent, gift_percent,
      discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, grade_code)
    values (
      v_id, v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), (e ->> 'prospect_student_id')::uuid,
      (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
      r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
      (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
      (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
      (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
      e ->> 'grade_code')
    returning id into v_line_id;
    for d in select * from jsonb_array_elements(r -> 'discounts') loop
      insert into app.quotation_line_discount (line_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
      values (v_line_id, (d ->> 'policy_id')::uuid, d ->> 'policy_code', d ->> 'policy_name', d ->> 'kind',
              (d ->> 'applied_value')::numeric, (d ->> 'requires_approval')::boolean);
    end loop;
    v_total := v_total + (r ->> 'line_total')::bigint;
    -- Luật R-TIEN-29 (D3): vượt trần vẫn lưu, trả cảnh báo.
    if (r ->> 'over_cap')::boolean then
      v_warnings := v_warnings || jsonb_build_object('code', 'HMT_VUOT_TRAN', 'line_no', v_n,
        'message', format('Dòng %s: chiết khấu (gồm giờ tặng) vượt trần %s%%. Đơn cần người duyệt tích đồng ý.', v_n,
                          app.get_setting('discount_total_cap_percent')));
    end if;
  end loop;

  update app.quotation set priced_on = v_on, total_amount = v_total where id = v_id;
  select code into v_code from app.quotation where id = v_id;
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', v_total, 'warnings', v_warnings);
end;
$$;

-- Lấy từ 20261027000051_p5a_don_hang.sql; chỉ đổi phần chụp khối, môn (B-26-03).
create or replace function app.order_write_priced_lines(p_order_id uuid, p_opportunity_id uuid, p_branch_id uuid, p_lines jsonb, p_on date)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  e jsonb;
  d jsonb;
  r jsonb;
  v_n integer := 0;
  v_total bigint := 0;
  v_line_id uuid;
  v_class uuid;
  v_start date;
begin
  delete from app.sales_order_line_discount where line_id in (select id from app.sales_order_line where order_id = p_order_id);
  delete from app.sales_order_line where order_id = p_order_id;
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_n := v_n + 1;
    -- Luật Đ83: học sinh chọn trong danh sách em của cơ hội.
    perform app.validate_line_student(v_n, p_opportunity_id, nullif(e ->> 'prospect_student_id', '')::uuid);
    v_class := nullif(e ->> 'class_id', '')::uuid;
    v_start := nullif(e ->> 'enrol_start_date', '')::date;
    if v_class is not null and v_start is null then
      perform app.raise_error('HMT_THIEU_NGAY_VAO_LOP', format('Dòng %s: chọn lớp thì cần ngày vào lớp.', v_n));
    end if;
    r := app.price_line(v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), nullif(e ->> 'package_id', '')::uuid,
                        e ->> 'delivery_mode_code', nullif(e ->> 'quantity', '')::numeric, e -> 'discounts',
                        nullif(e ->> 'gift_policy_id', '')::uuid, p_branch_id, p_on);
    perform app.check_order_line_class(v_n, v_class, (r ->> 'package_id')::uuid, p_branch_id);
    insert into app.sales_order_line (
      order_id, line_no, line_kind, prospect_student_id, package_id, package_code, package_name, package_type_code,
      delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent, gift_percent,
      discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date, grade_code)
    values (
      p_order_id, v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), (e ->> 'prospect_student_id')::uuid,
      (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
      r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
      (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
      (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
      (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
      v_class, v_start, e ->> 'grade_code')
    returning id into v_line_id;
    for d in select * from jsonb_array_elements(r -> 'discounts') loop
      insert into app.sales_order_line_discount (line_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
      values (v_line_id, (d ->> 'policy_id')::uuid, d ->> 'policy_code', d ->> 'policy_name', d ->> 'kind',
              (d ->> 'applied_value')::numeric, (d ->> 'requires_approval')::boolean);
    end loop;
    v_total := v_total + (r ->> 'line_total')::bigint;
  end loop;
  return v_total;
end;
$$;

-- Lấy từ 20261107000082_them_dong_nguoi_duyet_bi_khoa.sql; chỉ đổi phần chụp khối, môn (B-26-03).
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
    discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date, grade_code)
  values (
    p_order_id, v_n, coalesce(nullif(p_spec ->> 'kind', ''), 'ENROL'), (p_spec ->> 'prospect_student_id')::uuid,
    (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
    r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
    (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
    (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
    (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
    v_class, v_start, p_spec ->> 'grade_code')
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

-- Lấy từ 20261118000417_tt_d2a_don_tu_phieu_tai_tuc.sql; chỉ đổi phần chụp khối, môn (B-26-03).
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
      discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date, grade_code)
    values (
      v_id, t.branch_id, v_n, v_kind, t.student_id,
      (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
      r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
      (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
      (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
      (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
      v_class, case when v_class is not null then v_start end, e ->> 'grade_code')
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

-- Trả MỌI sản phẩm đang bán (không cắt theo list_page_size_max): cấu hình vài trăm dòng, ô chọn lọc theo loại, môn, khối.
-- Lấy từ 20261027000055_p5a_bao_gia_xem_thu_goi_y.sql; chỉ đổi phần chụp khối, môn (B-26-03).
create or replace function app.list_sellable_packages(p_opportunity_id uuid, p_type text default null, p_q text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_opp app.opportunity;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_q text := app.fold_text(nullif(btrim(coalesce(p_q, '')), ''));
  v_popular_n integer := app.get_setting_int('quotation_popular_packages_count');
  v_popular_days integer := app.get_setting_int('quotation_popular_window_days');
  v_result jsonb;
begin
  v_opp := app.assert_quotation_helper_access(p_opportunity_id);
  with priced as (
    select p.id, p.code, p.name, p.package_type_code, p.subject_code, p.grade_from_code, p.grade_to_code, p.grade_codes, p.grade_label,
           jsonb_strip_nulls(jsonb_build_object(
             'OFF', app.package_price_at(p.id, 'OFF', v_on), 'ONL', app.package_price_at(p.id, 'ONL', v_on))) as prices
      from app.sales_package p
     where p.is_active
       and (p_type is null or p.package_type_code = p_type)
       and (v_q is null or app.fold_text(p.code || ' ' || p.name) like '%' || v_q || '%')
  ),
  sellable as (select * from priced where prices <> '{}'::jsonb),
  popular as (
    select p.code, u.n
      from (select l.package_id, count(*) as n
              from app.quotation_line l join app.quotation q on q.id = l.quotation_id
             where q.created_by = auth.uid() and q.created_at >= now() - make_interval(days => v_popular_days)
             group by l.package_id) u
      join sellable p on p.id = u.package_id
     order by u.n desc, p.code
     limit v_popular_n
  ),
  suggested as (
    select p.code
      from sellable p
      left join app.catalog_item gf on gf.catalog_code = 'GRADE' and gf.code = p.grade_from_code
      left join app.catalog_item gt on gt.catalog_code = 'GRADE' and gt.code = coalesce(p.grade_to_code, p.grade_from_code)
     where exists (select from app.student_test t
                     join app.catalog_item g on g.catalog_code = 'GRADE' and g.code = t.grade_code
                    where t.opportunity_id = v_opp.id and t.status_code <> 'CANCELLED'
                      and t.subject_code = p.subject_code
                      and g.sort_order between gf.sort_order and gt.sort_order)
     order by p.code
  )
  select jsonb_build_object(
           'types', coalesce((select jsonb_agg(jsonb_build_object('code', c.code, 'name', c.name) order by c.sort_order)
                                from app.catalog_item c where c.catalog_code = 'PACKAGE_TYPE' and c.is_active), '[]'::jsonb),
           'popular', coalesce((select jsonb_agg(code order by n desc, code) from popular), '[]'::jsonb),
           'suggested', coalesce((select jsonb_agg(code order by code) from suggested), '[]'::jsonb),
           'total', (select count(*) from sellable),
           'packages', coalesce((select jsonb_agg(jsonb_build_object(
               'id', g.id, 'code', g.code, 'name', g.name, 'package_type_code', g.package_type_code, 'subject_code', g.subject_code,
               'grade_from_code', g.grade_from_code, 'grade_to_code', g.grade_to_code,
               'grade_codes', to_jsonb(g.grade_codes), 'grade_label', g.grade_label,
               'unit_code', app.package_unit(g.package_type_code), 'prices', g.prices) order by g.code) from sellable g), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

select set_config('hmt.migration', '', false);
