-- C-27-10 / C-27-10b (anh Trường chốt 27/11, R-GD-13): báo giá và đơn tạo được từ phiếu tái tục ở MỌI giai đoạn, không giới hạn số đơn; bỏ mọi tự chuyển giai đoạn.
-- (1) app.quotation gắn đúng MỘT trong cơ hội hoặc phiếu tái tục (như app.sales_order từ migration 051). Cơ sở, phụ huynh lấy từ phiếu.
-- (2) Các hàm báo giá nhận «mã nguồn» ở tham số p_opportunity_id: mã cơ hội HOẶC mã phiếu tái tục (cùng một form báo giá, không thêm RPC).
-- (3) Quyền trên phiếu: Báo giá (hoặc Đơn hàng) như cũ VÀ Phiếu tái tục · Sửa ở cơ sở của phiếu, như hàm tạo đơn từ phiếu đã có.

alter table app.quotation alter column opportunity_id drop not null;
alter table app.quotation add column upsale_ticket_id uuid references app.upsale_ticket (id);
alter table app.quotation add constraint quotation_one_source check (num_nonnulls(opportunity_id, upsale_ticket_id) = 1);
comment on column app.quotation.upsale_ticket_id is 'Phiếu tái tục nguồn của báo giá; đúng một trong opportunity_id và upsale_ticket_id có giá trị (R-GD-13).';
-- Chỉ mục: khoá ngoại, và lọc «báo giá của phiếu này» ở tab Báo giá và đơn.
create index quotation_upsale_ticket_idx on app.quotation (upsale_ticket_id) where upsale_ticket_id is not null;

-- app.assert_upsale_sales_access(phiếu): phiếu tái tục dùng để lập báo giá hoặc đơn: Phiếu tái tục · Sửa ở cơ sở của phiếu, phân hệ Bán hàng bật. Hàm nội bộ.
-- Trả phiếu. Quyền Báo giá/Đơn hàng do hàm gọi kiểm thêm.
create function app.assert_upsale_sales_access(p_ticket_id uuid)
returns app.upsale_ticket
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
begin
  select * into t from app.upsale_ticket where id = p_ticket_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội hoặc phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'SUA', t.branch_id);
  perform app.require_feature('BAN_HANG', t.branch_id); -- Luật Đ173
  return t;
end;
$$;
revoke execute on function app.assert_upsale_sales_access(uuid) from public, anon, authenticated;

-- app.assert_quotation_helper_access(mã nguồn): quyền dùng các hàm đọc phụ của form báo giá (xem thử giá, gói bán, chính sách). Mã nguồn là cơ hội hoặc phiếu tái tục.
-- Với phiếu: trả dòng giả chỉ có cơ sở và phụ huynh (id để trống) để các hàm phụ dùng chung.
create or replace function app.assert_quotation_helper_access(p_opportunity_id uuid)
returns app.opportunity
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_opp app.opportunity;
  t app.upsale_ticket;
  v_branch uuid;
begin
  select * into v_opp from app.opportunity where id = p_opportunity_id;
  if v_opp.id is null then
    t := app.assert_upsale_sales_access(p_opportunity_id);
    v_opp.branch_id := t.branch_id;
    v_opp.parent_id := t.parent_id;
  end if;
  v_branch := v_opp.branch_id;
  -- Luật (Đ256, DB-O1a): người lập hoặc sửa báo giá HOẶC đơn hàng ở cơ sở đó.
  if not (app.can_see_branch('QUOTATION', 'TAO', v_branch) or app.can_see_branch('QUOTATION', 'SUA', v_branch)
          or app.can_see_branch('SALES_ORDER', 'TAO', v_branch) or app.can_see_branch('SALES_ORDER', 'SUA', v_branch)) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền lập báo giá hoặc đơn hàng ở cơ sở này.');
  end if;
  perform app.require_feature('BAN_HANG', v_branch); -- Luật Đ173
  if v_opp.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không lập báo giá hoặc đơn hàng được.');
  end if;
  return v_opp;
end;
$$;

-- Lấy từ 20261027000055_p5a_bao_gia_xem_thu_goi_y.sql, câu cảnh báo theo mig 697; chỉ bỏ kiểm học sinh khi nguồn là phiếu tái tục.
create or replace function app.preview_quotation_lines(p_opportunity_id uuid, p_lines jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_opp app.opportunity;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  e jsonb;
  r jsonb;
  v_n integer := 0;
  v_total bigint := 0;
  v_lines jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
begin
  if p_lines is not null and jsonb_typeof(p_lines) <> 'array' then
    perform app.raise_error('HMT_DONG_THIEU', 'Danh sách dòng báo giá không hợp lệ.');
  end if;
  v_opp := app.assert_quotation_helper_access(p_opportunity_id);
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_n := v_n + 1;
    -- Luật Đ83: học sinh chọn trong danh sách em của cơ hội (như lúc Lưu).
    -- Báo giá từ phiếu tái tục: học sinh là em của phiếu, không chọn.
    if v_opp.id is not null then
      perform app.validate_line_student(v_n, v_opp.id, nullif(e ->> 'prospect_student_id', '')::uuid);
    end if;
    r := app.price_line(v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), nullif(e ->> 'package_id', '')::uuid,
                        e ->> 'delivery_mode_code', nullif(e ->> 'quantity', '')::numeric, e -> 'discounts',
                        nullif(e ->> 'gift_policy_id', '')::uuid, v_opp.branch_id, v_on);
    v_lines := v_lines || (jsonb_build_object('line_no', v_n) || r);
    v_total := v_total + (r ->> 'line_total')::bigint;
    -- Luật R-TIEN-29 (D3): vượt trần là cảnh báo, không chặn.
    if (r ->> 'over_cap')::boolean then
      v_warnings := v_warnings || jsonb_build_object('code', 'HMT_VUOT_TRAN', 'line_no', v_n,
        'message', format('Dòng %s: ưu đãi (gồm giờ tặng) vượt trần %s%%. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được.', v_n,
                          app.get_setting('discount_total_cap_percent')));
    end if;
  end loop;
  return jsonb_build_object('lines', v_lines, 'total_amount', v_total, 'warnings', v_warnings);
end;
$$;

-- Lấy từ 20261126000676_dong_tang_tinh_tien.sql, câu cảnh báo theo mig 697; thêm nguồn phiếu tái tục.
create or replace function app.save_quotation(p_id uuid, p_opportunity_id uuid, p_lines jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q app.quotation;
  v_opp app.opportunity;
  t app.upsale_ticket;
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
      -- Luật R-GD-13: báo giá từ phiếu tái tục, ở mọi giai đoạn; cơ sở và phụ huynh lấy từ phiếu.
      t := app.assert_upsale_sales_access(p_opportunity_id);
      v_opp.branch_id := t.branch_id;
      v_opp.parent_id := t.parent_id;
    end if;
    -- Luật: quyền tạo báo giá ở cơ sở của nguồn; cơ hội đã gộp thì không tạo (R-CRM-22).
    perform app.assert_can('QUOTATION', 'TAO', v_opp.branch_id);
    -- Luật Đ173: phân hệ Bán hàng phải bật ở cơ sở.
    perform app.require_feature('BAN_HANG', v_opp.branch_id);
    if v_opp.record_status = 'DA_GOP' then
      perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không tạo báo giá được.');
    end if;
    select code into v_branch_code from app.branch where id = v_opp.branch_id;
    v_code := app.issue_document_number('BG', v_branch_code);
    insert into app.quotation (code, branch_id, opportunity_id, upsale_ticket_id, parent_id, priced_on)
    values (v_code, v_opp.branch_id, v_opp.id, t.id, v_opp.parent_id, v_on)
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
    if v_q.upsale_ticket_id is not null then
      -- Luật R-GD-13: sửa báo giá của phiếu cũng cần Phiếu tái tục · Sửa.
      t := app.assert_upsale_sales_access(v_q.upsale_ticket_id);
      v_opp.branch_id := v_q.branch_id;
    end if;
    delete from app.quotation_line_discount where line_id in (select id from app.quotation_line where quotation_id = v_id);
    delete from app.quotation_line where quotation_id = v_id;
  end if;

  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_n := v_n + 1;
    -- Luật Đ83: học sinh chọn trong danh sách em của cơ hội.
    -- Báo giá từ phiếu tái tục: mọi dòng là em của phiếu.
    if t.id is null then
      perform app.validate_line_student(v_n, v_opp.id, nullif(e ->> 'prospect_student_id', '')::uuid);
    end if;
    r := app.price_line(v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), nullif(e ->> 'package_id', '')::uuid,
                        e ->> 'delivery_mode_code', nullif(e ->> 'quantity', '')::numeric, e -> 'discounts',
                        nullif(e ->> 'gift_policy_id', '')::uuid, v_opp.branch_id, v_on);
    insert into app.quotation_line (
      quotation_id, line_no, line_kind, prospect_student_id, student_id, package_id, package_code, package_name, package_type_code,
      delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent, gift_percent,
      discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, grade_code, is_gift_line, list_unit_price)
    values (
      v_id, v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), case when t.id is null then (e ->> 'prospect_student_id')::uuid end, t.student_id,
      (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
      r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
      (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
      (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
      (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
      e ->> 'grade_code',
      (r ->> 'is_gift_line')::boolean, (r ->> 'list_unit_price')::bigint)
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
        'message', format('Dòng %s: ưu đãi (gồm giờ tặng) vượt trần %s%%. Vượt trần chỉ cảnh báo, vẫn lưu và gửi được.', v_n,
                          app.get_setting('discount_total_cap_percent')));
    end if;
  end loop;

  update app.quotation set priced_on = v_on, total_amount = v_total where id = v_id;
  select code into v_code from app.quotation where id = v_id;
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', v_total, 'warnings', v_warnings);
end;
$$;

-- Lấy từ 20261126000676_dong_tang_tinh_tien.sql; thêm mã phiếu; tên em lấy từ hồ sơ khi dòng không có em của cơ hội.
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
    'upsale_ticket_code', (select u.code from app.upsale_ticket u where u.id = q.upsale_ticket_id),
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
               'student_name', coalesce(v.full_name, s.full_name), 'student_birth_year', coalesce(v.birth_year, s.birth_year),
               'student_code', coalesce(v.student_code, s.code),
               'student_complete', (coalesce(v.full_name, s.full_name) is not null and coalesce(v.birth_year, s.birth_year) is not null),
               'gift_policy_name', (select g.name from app.gift_policy g where g.id = l.gift_policy_id),
               -- Đơn đang sống của dòng (Đ106: tối đa một); chưa lên đơn hoặc đơn đã huỷ thì rỗng.
               'order_id', ol.order_id, 'order_code', ol.order_code, 'order_status_code', ol.order_status_code,
               'discounts', coalesce((select jsonb_agg(to_jsonb(d) - 'line_id' - 'branch_id' order by d.created_at, d.id)
                                        from app.quotation_line_discount d where d.line_id = l.id), '[]'::jsonb))
             order by l.line_no)
        from app.quotation_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
        left join app.student s on s.id = l.student_id
        left join lateral (select o.id as order_id, o.code as order_code, o.status_code as order_status_code
                             from app.sales_order_line sl join app.sales_order o on o.id = sl.order_id
                            where sl.quotation_line_id = l.id and sl.is_live) ol on true
       where l.quotation_id = q.id), '[]'::jsonb),
    -- Tổng niêm yết và tổng chiết khấu do DB cộng từ các dòng đã đóng băng, không tính lại; dòng quà tặng không tính (R-TIEN-30).
    'gross_total', (select coalesce(sum(l3.gross_amount), 0)::bigint from app.quotation_line l3
                     where l3.quotation_id = q.id and l3.line_kind = 'ENROL' and not l3.is_gift_line),
    'discount_total', (select coalesce(sum(l3.discount_amount), 0)::bigint from app.quotation_line l3
                        where l3.quotation_id = q.id and l3.line_kind = 'ENROL' and not l3.is_gift_line),
    -- Số đơn đang sống sinh từ báo giá này (cho nút "Đơn hàng" của BH-02).
    'live_order_count', (select count(distinct sl.order_id)::integer
                           from app.quotation_line l2 join app.sales_order_line sl on sl.quotation_line_id = l2.id and sl.is_live
                          where l2.quotation_id = q.id));
end;
$$;

-- Lấy từ 20261121000604_c95_group_by_nguoi_lap_sale_hinh_thuc.sql; báo giá của phiếu tái tục không có cơ hội; thêm lọc upsale_ticket_id.
create or replace function app.list_quotations(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('QUOTATION', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  -- Mã lưu trong DB cần xét trước: Đã chuyển đơn nằm trong các báo giá Đã gửi (Đ243).
  v_status_db text[] := array(select distinct case when x = 'DA_CHUYEN_DON' then 'DA_GUI' else x end from unnest(v_status) x);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  -- C95: người lập của bản ghi; dùng để mở một nhóm Group By «Người lập».
  v_creator uuid := nullif(p_filters ->> 'creator_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  -- Tab «Báo giá và đơn» của phiếu tái tục.
  v_ticket uuid := nullif(p_filters ->> 'upsale_ticket_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_expired boolean := coalesce((p_filters ->> 'expired')::boolean, false);
  v_converted boolean := (p_filters ->> 'converted')::boolean;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách báo giá.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang).
  with f as not materialized (
    select q.*
      from app.quotation q
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and q.branch_id = v_my_branch))
       and (v_q is null or q.search_text like '%' || v_q || '%')
       -- Tình trạng hiển thị (Đ243): Đã gửi chỉ gồm báo giá chưa chuyển hết; Đã chuyển đơn là báo giá Đã gửi mà mọi dòng đã lên đơn. Các giá trị nối bằng HOẶC.
       and (cardinality(v_status) = 0 or (q.status_code = any (v_status_db)
            and (case when q.status_code = 'DA_GUI' and app.quotation_converted(q.id) then 'DA_CHUYEN_DON' else q.status_code end) = any (v_status)))
       and (v_branch is null or q.branch_id = v_branch)
       and (v_creator is null or q.created_by = v_creator)
       and (v_opp is null or q.opportunity_id = v_opp)
       and (v_parent is null or q.parent_id = v_parent)
       and (v_ticket is null or q.upsale_ticket_id = v_ticket)
       and (not v_mine or q.created_by = auth.uid())
       and (not v_expired or (q.status_code = 'DA_GUI' and q.valid_until < v_today))
       -- Đã chuyển đơn: báo giá Đã gửi mà mọi dòng đã lên đơn còn sống (app.quotation_converted); false thì loại các báo giá đó.
       and (v_converted is null or (q.status_code = 'DA_GUI' and app.quotation_converted(q.id)) = v_converted)
       and (v_from is null or q.created_at >= v_from)
       and (v_to is null or q.created_at < v_to)
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'total_desc' then f.total_amount end desc,
              case when p_sort = 'valid_asc' then f.valid_until end asc nulls last,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'status_code', p.status_code,
             'display_status_code', case when p.status_code = 'DA_GUI' and app.quotation_converted(p.id) then 'DA_CHUYEN_DON' else p.status_code end,
             'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
             'opportunity_id', p.opportunity_id, 'opportunity_code', o.code,
             'upsale_ticket_id', p.upsale_ticket_id,
             'upsale_ticket_code', (select u.code from app.upsale_ticket u where u.id = p.upsale_ticket_id),
             'student_name', (select coalesce(v.full_name, s.full_name) from app.quotation_line l
                               left join app.prospect_student_v v on v.id = l.prospect_student_id
                               left join app.student s on s.id = l.student_id
                               where l.quotation_id = p.id order by l.line_no limit 1),
             'student_names', (select coalesce(jsonb_agg(x.full_name order by x.first_line), '[]'::jsonb)
                                 from (select coalesce(v.full_name, s.full_name) as full_name, min(l.line_no) as first_line
                                         from app.quotation_line l
                                         left join app.prospect_student_v v on v.id = l.prospect_student_id
                                         left join app.student s on s.id = l.student_id
                                        where l.quotation_id = p.id and coalesce(v.full_name, s.full_name) is not null
                                        group by coalesce(v.full_name, s.full_name)) x),
             'student_count', (select count(distinct coalesce(l.prospect_student_id, l.student_id)) from app.quotation_line l where l.quotation_id = p.id),
             'total_amount', p.total_amount, 'valid_until', p.valid_until,
             'overdue_days', case when p.status_code = 'DA_GUI' and p.valid_until < v_today then v_today - p.valid_until end,
             'sent_at', p.sent_at, 'created_at', p.created_at, 'branch_code', b.code,
             'created_by_name', app.staff_display_name(p.created_by))
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'total_desc' then p.total_amount end desc,
                      case when p_sort = 'valid_asc' then p.valid_until end asc nulls last,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent par on par.id = p.parent_id
    left join app.opportunity o on o.id = p.opportunity_id;
  return v_result;
end;
$$;

-- Lấy từ 20261027000057_bao_gia_loc_tinh_trang_hien_thi.sql; xuất cả báo giá của phiếu tái tục.
create or replace function app.export_quotations(p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('QUOTATION', 'XUAT');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  -- Mã lưu trong DB cần xét trước: Đã chuyển đơn nằm trong các báo giá Đã gửi (Đ243).
  v_status_db text[] := array(select distinct case when x = 'DA_CHUYEN_DON' then 'DA_GUI' else x end from unnest(v_status) x);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_expired boolean := coalesce((p_filters ->> 'expired')::boolean, false);
  v_converted boolean := (p_filters ->> 'converted')::boolean;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Phạm vi dòng lấy từ quyền Xuất, không phải Xem.
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất danh sách báo giá.');
  end if;
  select count(*) into v_total
    from app.quotation q
   where (v_scope = 'TOAN_HE_THONG' or q.branch_id = v_my_branch)
     and (v_q is null or q.search_text like '%' || v_q || '%')
     -- Tình trạng hiển thị (Đ243): Đã gửi chỉ gồm báo giá chưa chuyển hết; Đã chuyển đơn là báo giá Đã gửi mà mọi dòng đã lên đơn. Các giá trị nối bằng HOẶC.
     and (cardinality(v_status) = 0 or (q.status_code = any (v_status_db)
          and (case when q.status_code = 'DA_GUI' and app.quotation_converted(q.id) then 'DA_CHUYEN_DON' else q.status_code end) = any (v_status)))
     and (v_branch is null or q.branch_id = v_branch)
     and (v_opp is null or q.opportunity_id = v_opp)
     and (v_parent is null or q.parent_id = v_parent)
     and (not v_mine or q.created_by = auth.uid())
     and (not v_expired or (q.status_code = 'DA_GUI' and q.valid_until < v_today))
     -- Đã chuyển đơn: báo giá Đã gửi mà mọi dòng đã lên đơn còn sống (app.quotation_converted); false thì loại các báo giá đó.
     and (v_converted is null or (q.status_code = 'DA_GUI' and app.quotation_converted(q.id)) = v_converted)
     and (v_from is null or q.created_at >= v_from)
     and (v_to is null or q.created_at < v_to);
  with f as (
    select q.*
      from app.quotation q
     where (v_scope = 'TOAN_HE_THONG' or q.branch_id = v_my_branch)
       and (v_q is null or q.search_text like '%' || v_q || '%')
       -- Tình trạng hiển thị (Đ243): Đã gửi chỉ gồm báo giá chưa chuyển hết; Đã chuyển đơn là báo giá Đã gửi mà mọi dòng đã lên đơn. Các giá trị nối bằng HOẶC.
       and (cardinality(v_status) = 0 or (q.status_code = any (v_status_db)
            and (case when q.status_code = 'DA_GUI' and app.quotation_converted(q.id) then 'DA_CHUYEN_DON' else q.status_code end) = any (v_status)))
       and (v_branch is null or q.branch_id = v_branch)
       and (v_opp is null or q.opportunity_id = v_opp)
       and (v_parent is null or q.parent_id = v_parent)
       and (not v_mine or q.created_by = auth.uid())
       and (not v_expired or (q.status_code = 'DA_GUI' and q.valid_until < v_today))
       -- Đã chuyển đơn: báo giá Đã gửi mà mọi dòng đã lên đơn còn sống (app.quotation_converted); false thì loại các báo giá đó.
       and (v_converted is null or (q.status_code = 'DA_GUI' and app.quotation_converted(q.id)) = v_converted)
       and (v_from is null or q.created_at >= v_from)
       and (v_to is null or q.created_at < v_to)
     order by q.created_at desc, q.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', f.code,
           'status', (select c.name from app.catalog_item c where c.catalog_code = 'QUOTATION_STATUS' and c.code = f.status_code),
           'parent_name', par.full_name, 'parent_phone', par.phone, 'opportunity', coalesce(o.code, (select u.code from app.upsale_ticket u where u.id = f.upsale_ticket_id)),
           'students', (select string_agg(distinct coalesce(v.full_name, s.full_name), '; ') from app.quotation_line l
                          left join app.prospect_student_v v on v.id = l.prospect_student_id
                          left join app.student s on s.id = l.student_id where l.quotation_id = f.id),
           'total_amount', f.total_amount, 'valid_until', f.valid_until, 'sent_at', f.sent_at,
           'branch', b.code, 'created_by', app.staff_display_name(f.created_by), 'created_at', f.created_at)
           order by f.created_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id
    join app.parent par on par.id = f.parent_id
    left join app.opportunity o on o.id = f.opportunity_id;
  perform app.log_export('QUOTATION', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$$;

-- Lấy từ 20261026000045_p5a_bao_gia.sql; tìm được theo tên em của phiếu tái tục.
create or replace function app.quotation_search_text(p_quotation app.quotation)
returns text
language sql
stable
set search_path = ''
as $$
  select app.fold_text(p_quotation.code || ' ' || coalesce((select pa.full_name || ' ' || pa.phone from app.parent pa
                                                              where pa.id = p_quotation.parent_id), '')
                       || ' ' || coalesce((select string_agg(distinct coalesce(v.full_name, s.full_name), ' ')
                                            from app.quotation_line l
                                            left join app.prospect_student_v v on v.id = l.prospect_student_id
                                            left join app.student s on s.id = l.student_id
                                           where l.quotation_id = p_quotation.id), '')
                       || ' ' || coalesce(p_quotation.legacy_ref, ''));
$$;

-- app.upsale_order_context(phiếu, ngày vào lớp) -> (hình thức học, ngày vào lớp): dùng chung cho đơn tạo thẳng từ phiếu và đơn từ báo giá của phiếu. Hàm nội bộ.
-- Luật R-GD-13: học sinh còn học ở lớp của phiếu, hình thức học giữ như ghi danh cũ. Ngày vào lớp không truyền thì lấy buổi sắp tới gần nhất của lớp (R-GD-06).
create function app.upsale_order_context(p_ticket app.upsale_ticket, p_start date, out delivery_mode_code text, out start_date date)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  select e.delivery_mode_code into delivery_mode_code
    from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = p_ticket.class_id and ec.end_date is null
   where e.student_id = p_ticket.student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC') order by e.created_at desc limit 1;
  if not found then
    perform app.raise_error('HMT_HOC_SINH_KHONG_O_LOP', 'Học sinh này hiện không học ở lớp của phiếu nên chưa tạo được đơn tái tục.');
  end if;
  start_date := coalesce(p_start,
                         (select min(s.session_date) from app.class_session s
                           where s.class_id = p_ticket.class_id and s.status_code in ('NHAP', 'DA_CHOT') and s.session_date >= v_on),
                         v_on);
  perform app.assert_enrol_start_date(p_ticket.class_id, start_date, 'Đơn tái tục');
end;
$$;
revoke execute on function app.upsale_order_context(app.upsale_ticket, date) from public, anon, authenticated;

-- Lấy từ 20261126000676_dong_tang_tinh_tien.sql; bỏ chặn L6, bỏ giới hạn một đơn sống, không tự chuyển giai đoạn.
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
  -- Luật R-GD-13 (27/11): mọi giai đoạn, không giới hạn số đơn; giai đoạn chỉ đổi bằng tay.
  select c.delivery_mode_code, c.start_date into v_mode, v_start from app.upsale_order_context(t, p_enrol_start_date) c;
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
      discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date, grade_code, is_gift_line, list_unit_price)
    values (
      v_id, t.branch_id, v_n, v_kind, t.student_id,
      (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
      r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
      (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
      (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
      (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
      v_class, case when v_class is not null then v_start end, e ->> 'grade_code',
      (r ->> 'is_gift_line')::boolean, (r ->> 'list_unit_price')::bigint)
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
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', (select total_amount from app.sales_order where id = v_id));
end;
$$;

-- Lấy từ 20261108000085_uu_dai_linh_hoat.sql; báo giá của phiếu tái tục tạo đơn gắn phiếu và lớp.
create or replace function app.create_order_from_quotation(p_quotation_id uuid, p_line_nos integer[] default null, p_payment_term_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q app.quotation;
  v_opp app.opportunity;
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_n integer := 0;
  l app.quotation_line;
  v_new_line uuid;
  v_picked integer := 0;
  v_constraint text;
  t app.upsale_ticket;
  v_mode text;
  v_start date;
  v_class uuid;
begin
  select * into v_q from app.quotation where id = p_quotation_id for update;
  if v_q.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy báo giá.');
  end if;
  perform app.assert_can('SALES_ORDER', 'TAO', v_q.branch_id);
  perform app.require_feature('BAN_HANG', v_q.branch_id); -- Luật Đ173
  -- Báo giá của phiếu tái tục: cần thêm Phiếu tái tục · Sửa; không áp luật giai đoạn của cơ hội.
  if v_q.upsale_ticket_id is not null then
    t := app.assert_upsale_sales_access(v_q.upsale_ticket_id);
  end if;
  select * into v_opp from app.opportunity where id = v_q.opportunity_id;
  if v_opp.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không tạo đơn được.');
  end if;
  -- Luật R-TIEN-14: chỉ báo giá Đã gửi chuyển được đơn.
  if v_q.status_code <> 'DA_GUI' then
    perform app.raise_error('HMT_BAO_GIA_CHUA_GUI', 'Chỉ báo giá Đã gửi mới chuyển được thành đơn.');
  end if;
  -- Luật R-CRM-16: chưa ở L8 thì không tạo được đơn từ cơ hội.
  if t.id is null and v_opp.stage_code <> 'L8' then
    perform app.raise_error('HMT_CHUA_O_L8', 'Cơ hội cần ở L8 (phụ huynh đã thanh toán) mới tạo được đơn hàng.');
  end if;
  if p_line_nos is not null and exists (
       select from unnest(p_line_nos) n where not exists (select from app.quotation_line x where x.quotation_id = v_q.id and x.line_no = n)) then
    perform app.raise_error('HMT_DONG_KHONG_CO', 'Có dòng không thuộc báo giá này.');
  end if;
  select code into v_branch_code from app.branch where id = v_q.branch_id;
  v_code := app.issue_document_number('DH', v_branch_code);
  if t.id is not null then
    select c.start_date into v_start from app.upsale_order_context(t, null) c;
  end if;
  insert into app.sales_order (code, branch_id, opportunity_id, renewal_ticket_id, parent_id, quotation_id, priced_on)
  values (v_code, v_q.branch_id, v_q.opportunity_id, v_q.upsale_ticket_id, v_q.parent_id, v_q.id, v_q.priced_on)
  returning id into v_id;
  for l in select * from app.quotation_line x
            where x.quotation_id = v_q.id and (p_line_nos is null or x.line_no = any (p_line_nos)) order by x.line_no loop
    -- Luật R-TIEN-02: dòng đã nằm trong đơn đang sống thì chặn (lệnh chọn tay) hoặc bỏ qua (chọn mọi dòng).
    if exists (select from app.sales_order_line o where o.quotation_line_id = l.id and o.is_live) then
      if p_line_nos is not null then
        perform app.raise_error('HMT_DONG_DA_CO_DON', format('Dòng %s của báo giá đã nằm trong một đơn đang xử lý.', l.line_no));
      end if;
      continue;
    end if;
    v_n := v_n + 1;
    -- Đơn tái tục: dòng ghi danh vào đúng lớp của phiếu (R-GD-13).
    v_class := case when l.line_kind = 'ENROL' then t.class_id end;
    if v_class is not null then
      perform app.check_order_line_class(v_n, v_class, l.package_id, v_q.branch_id);
    end if;
    insert into app.sales_order_line (
      order_id, line_no, line_kind, quotation_line_id, prospect_student_id, student_id, package_id, package_code, package_name,
      package_type_code, delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent,
      gift_percent, discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date)
    values (
      v_id, v_n, l.line_kind, l.id, l.prospect_student_id, l.student_id, l.package_id, l.package_code, l.package_name,
      l.package_type_code, l.delivery_mode_code, l.unit_code, l.quantity, l.gifted_quantity, l.unit_price, l.gross_amount,
      l.discount_percent, l.gift_percent, l.discount_amount, l.line_total, l.over_cap, l.needs_acknowledgement, l.gift_policy_id,
      v_class, case when v_class is not null then v_start end)
    returning id into v_new_line;
    insert into app.sales_order_line_discount (line_id, policy_id, policy_code, policy_name, kind, applied_value, requires_approval)
    select v_new_line, d.policy_id, d.policy_code, d.policy_name, d.kind, d.applied_value, d.requires_approval
      from app.quotation_line_discount d where d.line_id = l.id;
    v_picked := v_picked + 1;
  end loop;
  if v_picked = 0 then
    perform app.raise_error('HMT_KHONG_CO_DONG_DE_CHUYEN', 'Không còn dòng nào của báo giá để chuyển thành đơn.');
  end if;
  -- Luật Đ260, R-CRM-19: điều khoản thanh toán áp ngay trong cùng giao dịch tạo đơn; điều khoản sai thì cả giao dịch lùi (không có đơn Nháp rác, mã không nhảy số).
  if p_payment_term_id is not null then
    perform app.order_apply_term(v_id, p_payment_term_id);
  end if;
  perform app.order_refresh_totals(v_id);
  -- Nhật ký (Q-145): dòng ưu đãi linh hoạt được nhập ở báo giá, kèm mã báo giá.
  perform app.order_add_event(v_id, 'TAO', null, 'NHAP', null, null, app.order_flexible_note(v_id, true));
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', (select total_amount from app.sales_order where id = v_id));
exception
  when unique_violation then
    -- Chỉ lỗi trùng đúng chỉ mục "một dòng báo giá không nằm trong hai đơn sống" mới đổi thành lỗi có mã; lỗi trùng khác ném lại.
    get stacked diagnostics v_constraint = constraint_name;
    if v_constraint = 'sales_order_line_quotation_live_uidx' then
      perform app.raise_error('HMT_DONG_DA_CO_DON', 'Có dòng của báo giá đã nằm trong một đơn đang xử lý.');
    end if;
    raise;
end;
$$;

-- Luật R-GD-13 (27/11): đổi giai đoạn bằng tay; bỏ tự chuyển L7 sang L8 và tự lùi L7 về L6 khi đơn huỷ.
-- Lấy từ 20261118000417_tt_d2a_don_tu_phieu_tai_tuc.sql; lịch đêm chỉ còn sinh phiếu.
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
  perform cron.schedule('hmt-generate-upsale-tickets', '0 19 * * *', 'select app.generate_upsale_tickets()'); -- allow-number: 19 giờ UTC là 02 giờ sáng giờ Việt Nam
  return '0 19 * * * (02:00 giờ Việt Nam)';
end;
$$;

drop function app.reconcile_upsale_orders();
-- Môi trường đã đặt lịch thì đặt lại lịch (lệnh cũ gọi hàm vừa bỏ); chưa đặt thì thôi.
do $$
begin
  if to_regnamespace('cron') is not null then
    if exists (select from cron.job where jobname = 'hmt-generate-upsale-tickets') then
      perform app.sync_upsale_cron();
    end if;
  end if;
end;
$$;
-- Lấy từ 20261126000685_dd1_hai_cot_diem_danh.sql; thêm tao_bao_gia, tao_don.
create or replace function app.get_upsale_ticket(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_open boolean;
  v_window integer;
begin
  select * into t from app.upsale_ticket where id = p_id;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'XEM', t.branch_id);
  v_open := t.stage_code not in ('L5', 'L8');
  v_window := app.get_setting_int('absence_risk_window_days', t.branch_id)::integer;
  return jsonb_build_object(
    'ticket', app.upsale_ticket_row(t) || jsonb_build_object(
      'lost_reason_code', t.lost_reason_code, 'lost_note', t.lost_note, 'next_goal', t.next_goal, 'next_roadmap', t.next_roadmap,
      'closed_at', t.closed_at, 'created_by_name', app.staff_display_name(t.created_by),
      'branch_id', t.branch_id), -- cho form báo giá từ phiếu: hạn hiệu lực theo cơ sở của phiếu
    'parent', (select jsonb_build_object('id', p.id, 'code', p.code, 'name', p.full_name, 'phone', p.phone, 'email', null, 'zalo', null)
                 from app.parent p where p.id = t.parent_id),
    'student', (select jsonb_build_object('id', s.id, 'code', s.code, 'name', s.full_name, 'birth_year', s.birth_year)
                  from app.student s where s.id = t.student_id),
    'class', jsonb_build_object('id', t.class_id, 'code', (select code from app.class where id = t.class_id),
      'teacher_name', (select u.display_name from app.class_slot cs join app.user_account u on u.id = cs.teacher_id
                        where cs.class_id = t.class_id and cs.is_active order by cs.weekday, cs.start_time limit 1)),
    'enrollments', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'code', e.code, 'status_code', e.status_code,
                       'hours_left', coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = e.id), 0)) order by e.code)
                  from app.enrollment e join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                 where e.student_id = t.student_id), '[]'::jsonb),
    'hours', jsonb_build_object(
      'bought', (select coalesce(sum(h.hours), 0) from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id
                  join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                  where e.student_id = t.student_id and h.entry_type in ('CAP_MUA', 'CAP_TANG', 'DAU_KY')),
      'used', (select coalesce(-sum(h.hours), 0) from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id
                join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                where e.student_id = t.student_id and h.entry_type = 'TRU_BUOI'),
      'absences_window', (select count(*) from app.session_attendance sa join app.class_session s on s.id = sa.session_id
                           where sa.student_id = t.student_id and s.class_id = t.class_id and sa.is_active
                             and sa.teacher_status_code in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')
                             and s.session_date > (now() at time zone 'Asia/Ho_Chi_Minh')::date - v_window),
      'window_days', v_window,
      -- TT-02: lần cấp giờ mua (CAP_MUA) mới nhất của em ở lớp này.
      'last_purchase', (select jsonb_build_object('hours', h.hours, 'at', h.created_at)
                          from app.hour_ledger h join app.enrollment e on e.id = h.enrollment_id
                          join app.enrollment_class ec on ec.enrollment_id = e.id and ec.class_id = t.class_id and ec.end_date is null
                         where e.student_id = t.student_id and h.entry_type = 'CAP_MUA'
                         order by h.created_at desc, h.seq desc limit 1)),
    'events', coalesce((select jsonb_agg(jsonb_build_object('id', ev.id, 'event_type', ev.event_type, 'from_stage', ev.from_stage, 'to_stage', ev.to_stage,
                       'note', ev.note, 'created_at', ev.created_at, 'created_by_name', app.staff_display_name(ev.created_by)) order by ev.seq)
                  from app.upsale_ticket_event ev where ev.ticket_id = t.id), '[]'::jsonb),
    'actions', to_jsonb(array_remove(array[
      case when v_open and app.can_see_branch('UPSALE', 'GIAO_VIEC', t.branch_id) then 'giao' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'doi_giai_doan' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) then 'sua_ghi_chu' end,
      -- Luật R-GD-13 (27/11): tạo báo giá, tạo đơn ở mọi giai đoạn, theo quyền.
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) and app.can_see_branch('QUOTATION', 'TAO', t.branch_id) then 'tao_bao_gia' end,
      case when app.can_see_branch('UPSALE', 'SUA', t.branch_id) and app.can_see_branch('SALES_ORDER', 'TAO', t.branch_id) then 'tao_don' end], null)));
end;
$$;

-- app.change_upsale_stage(phiếu, giai đoạn mới, lý do, ghi chú, nhóm con): người có Phiếu tái tục · Sửa đổi giai đoạn BẰNG TAY. Trả {id, stage_code, substage_code}.
-- Luật R-GD-13 (anh chốt 27/11): đổi được giữa mọi giai đoạn L1 đến L8, đi tới hoặc lùi; hệ thống không còn tự đặt L7, L8.
-- Lấy từ 20261118000410_tt_a_phieu_tai_tuc.sql; thêm tham số nhóm con nên bỏ hàm cũ.
drop function app.change_upsale_stage(uuid, text, text, text);
create function app.change_upsale_stage(p_id uuid, p_to text, p_reason_code text default null, p_note text default null, p_substage text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  t app.upsale_ticket;
  v_item app.catalog_item;
  v_sub text;
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
begin
  select * into t from app.upsale_ticket where id = p_id for update;
  if t.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu tái tục.');
  end if;
  perform app.assert_can('UPSALE', 'SUA', t.branch_id);
  perform app.require_feature('BAN_HANG', t.branch_id);
  if p_to is null or p_to not in ('L1', 'L2', 'L3', 'L4', 'L5', 'L6', 'L7', 'L8') then
    perform app.raise_error('HMT_GIAI_DOAN_KHONG_HOP_LE', 'Giai đoạn mới không hợp lệ.');
  end if;
  -- Nhóm con (danh mục 06 mục 1.4): L1 theo nguồn phiếu, L7 người dùng chọn L7A hoặc L7B, L8 chỉ có L8A.
  v_sub := case p_to
             when 'L1' then case t.origin_code when 'HE_THONG' then 'L1A' else 'L1B' end
             when 'L7' then p_substage
             when 'L8' then 'L8A'
           end;
  if p_to = 'L7' and coalesce(p_substage, '') not in ('L7A', 'L7B') then
    perform app.raise_error('HMT_GIAI_DOAN_KHONG_HOP_LE', 'Chọn nhóm con của Dự thu.');
  end if;
  -- Cùng giai đoạn chỉ được đổi nhóm con.
  if p_to = t.stage_code and v_sub is not distinct from t.substage_code then
    perform app.raise_error('HMT_GIAI_DOAN_KHONG_HOP_LE', 'Phiếu đang ở giai đoạn này.');
  end if;
  -- Luật R-GD-13: L5 Không tái tục bắt buộc lý do từ danh mục; «Khác» cần ghi chú.
  if p_to = 'L5' then
    select * into v_item from app.catalog_item where catalog_code = 'RENEWAL_LOST_REASON' and code = p_reason_code and is_active;
    if v_item.id is null then
      perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn lý do không tái tục.');
    end if;
    if v_item.requires_note and v_note is null then
      perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn "Khác" thì ghi chú lý do.');
    end if;
  end if;
  -- Luật R-GD-13: mỗi học sinh ở mỗi lớp tối đa một phiếu đang mở; mở lại phiếu đã kết thúc thì kiểm trước.
  if t.stage_code in ('L5', 'L8') and p_to not in ('L5', 'L8')
     and exists (select from app.upsale_ticket o
                  where o.student_id = t.student_id and o.class_id = t.class_id and o.id <> t.id and o.stage_code not in ('L5', 'L8')) then
    perform app.raise_error('HMT_DA_CO_PHIEU_TAI_TUC', 'Học sinh này đã có phiếu tái tục đang mở ở lớp này.');
  end if;
  -- L5, L8 là kết thúc: ghi thời điểm đóng; rời khỏi thì bỏ ngày đóng và lý do.
  update app.upsale_ticket
     set stage_code = p_to, substage_code = v_sub,
         lost_reason_code = case when p_to = 'L5' then p_reason_code end,
         lost_note = case when p_to = 'L5' then v_note end,
         closed_at = case when p_to in ('L5', 'L8') then now() end
   where id = p_id;
  perform app.upsale_add_event(p_id, 'DOI_GIAI_DOAN', t.stage_code, p_to, p_note);
  return jsonb_build_object('id', p_id, 'stage_code', p_to, 'substage_code', v_sub);
end;
$$;
revoke execute on function app.change_upsale_stage(uuid, text, text, text, text) from public, anon;
grant execute on function app.change_upsale_stage(uuid, text, text, text, text) to authenticated;
