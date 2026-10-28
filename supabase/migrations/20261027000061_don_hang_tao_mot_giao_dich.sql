-- ===========================================================================
-- P5a-DB-O1b (migration 061, Đ256, Đ260): đường ghi đơn.
--   (b) app.find_student_match tách thuần tuý từ app.find_or_create_student (R-CRM-27); app.order_student_duplicates tách thuần tuý từ
--       app.order_link_students; app.preview_order_students (hàm đọc, hộp BH-07).
--   (c) app.create_order_from_quotation, app.create_order_from_opportunity nhận thêm điều khoản thanh toán (tuỳ chọn) và áp trong MỘT giao dịch
--       (app.order_apply_term, dùng chung với app.save_order), để khớp R-CRM-19: bấm Lưu mới tạo bản ghi và cấp mã, lỗi thì không để lại đơn Nháp rác.
-- Hai chữ ký cũ bị bỏ (drop) và tạo lại với tham số mới có mặc định, nên mọi lời gọi cũ (hai tham số) vẫn chạy. Không bảng, chỉ mục mới.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Tìm hồ sơ học sinh khớp (R-CRM-27): khớp theo phụ huynh + tên chuẩn hoá + năm sinh; hồ sơ đã gộp thì trả bản giữ lại (R-CRM-25). Không khớp thì null.
-- Tách thuần tuý từ app.find_or_create_student (hành vi không đổi) để app.preview_order_students dùng đúng một quy tắc khớp. Hàm nội bộ, không mở cho rpc.
-- ---------------------------------------------------------------------------
create or replace function app.find_student_match(p_parent_id uuid, p_name text, p_birth_year integer)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(merged_into_id, id) from app.student
   where parent_id = p_parent_id and app.normalize_person_name(full_name) = app.normalize_person_name(p_name)
     and birth_year = p_birth_year
   order by (record_status = 'DANG_DUNG') desc, created_at, id limit 1;
$$;

create or replace function app.find_or_create_student(
  p_parent_id uuid, p_name text, p_birth_year integer, p_birth_date date, p_school text, p_self_rating text,
  p_goal text, p_branch_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if btrim(coalesce(p_name, '')) = '' or p_birth_year is null then
    perform app.raise_error('HMT_THIEU_HOC_SINH', 'Cần tên và năm sinh của học sinh để tạo hồ sơ học sinh.');
  end if;
  -- Luật R-CRM-27: khớp theo phụ huynh + tên chuẩn hoá + năm sinh.
  -- Hồ sơ đã gộp thì trả bản giữ lại (R-CRM-25).
  v_id := app.find_student_match(p_parent_id, p_name, p_birth_year);
  if v_id is not null then
    return v_id;
  end if;
  insert into app.student (code, parent_id, full_name, birth_date, birth_year, school, self_rating, goal, branch_id)
  values (app.issue_person_code('HS'), p_parent_id, btrim(p_name), p_birth_date, p_birth_year, p_school, p_self_rating,
          p_goal, p_branch_id)
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Các em trùng họ tên (chuẩn hoá) và năm sinh trong cùng một đơn (KD6: hệ thống không tự gộp): trả chuỗi "Tên (năm), …" hoặc null nếu không trùng.
-- Tách thuần tuý từ app.order_link_students để app.preview_order_students báo đúng như lúc duyệt. Hàm nội bộ, không mở cho rpc.
-- ---------------------------------------------------------------------------
create or replace function app.order_student_duplicates(p_order_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select string_agg(distinct format('%s (%s)', x.nm, x.yr), ', ')
    from (select coalesce(v.full_name, s.full_name) as nm, coalesce(v.birth_year, s.birth_year) as yr,
                 app.normalize_person_name(coalesce(v.full_name, s.full_name)) as norm,
                 coalesce(l.prospect_student_id::text, l.student_id::text) as who
            from app.sales_order_line l
            left join app.prospect_student_v v on v.id = l.prospect_student_id
            left join app.student s on s.id = l.student_id
           where l.order_id = p_order_id) x
   where x.norm is not null
     and exists (select from (select app.normalize_person_name(coalesce(v2.full_name, s2.full_name)) as norm2,
                                     coalesce(v2.birth_year, s2.birth_year) as yr2,
                                     coalesce(l2.prospect_student_id::text, l2.student_id::text) as who2
                                from app.sales_order_line l2
                                left join app.prospect_student_v v2 on v2.id = l2.prospect_student_id
                                left join app.student s2 on s2.id = l2.student_id
                               where l2.order_id = p_order_id) y
                  where y.norm2 = x.norm and y.yr2 = x.yr and y.who2 <> x.who);
$$;

-- Tìm hoặc tạo hồ sơ học sinh cho các em trên dòng đơn (R-CRM-27, R-TIEN-35), gắn vào dòng đơn và dòng em. Dùng lại
-- app.find_or_create_student của PR danh sách em. Hai em KHÁC dòng danh sách nhưng cùng họ tên chuẩn hoá và năm sinh trong một đơn
-- (KD6, còn [CHỜ]) thì chặn bằng HMT_EM_TRUNG_TEN_NAM_SINH, không tự gộp.
create or replace function app.order_link_students(p_order_id uuid, p_parent_id uuid, p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dup text;
  r record;
  v_student uuid;
begin
  v_dup := app.order_student_duplicates(p_order_id);
  if v_dup is not null then
    perform app.raise_error('HMT_EM_TRUNG_TEN_NAM_SINH',
      format('Đơn có hai em trùng họ tên và năm sinh: %s. Hệ thống không tự gộp; xử lý ở danh sách em của cơ hội.', v_dup));
  end if;
  for r in select distinct l.prospect_student_id as ps_id
             from app.sales_order_line l where l.order_id = p_order_id and l.prospect_student_id is not null loop
    select v.student_id into v_student from app.prospect_student_v v where v.id = r.ps_id;
    if v_student is null then
      select app.find_or_create_student(p_parent_id, v.full_name, v.birth_year, v.birth_date, v.school, v.self_rating, v.goal, p_branch_id)
        into v_student from app.prospect_student_v v where v.id = r.ps_id;
      -- Dòng em gắn hồ sơ vừa tìm hoặc tạo; từ đây đọc thẳng từ hồ sơ (Đ86).
      update app.prospect_student set student_id = v_student, full_name = null, birth_date = null, birth_year = null,
             school = null, self_rating = null, goal = null where id = r.ps_id;
    end if;
    update app.sales_order_line set student_id = v_student where order_id = p_order_id and prospect_student_id = r.ps_id;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Gán điều khoản thanh toán cho đơn (R-TIEN-07): điều khoản phải còn dùng. Dùng chung cho lưu đơn Nháp và cho tạo đơn kèm điều khoản trong MỘT giao dịch
-- (Đ260, R-CRM-19). Hàm nội bộ, không mở cho rpc; người gọi đã kiểm quyền. Không tính lại lịch đợt: nơi gọi gọi app.order_refresh_totals sau đó.
-- ---------------------------------------------------------------------------
create or replace function app.order_apply_term(p_order_id uuid, p_term_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1 from app.payment_term t where t.id = p_term_id and t.is_active;
  if not found then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy điều khoản thanh toán đang dùng.');
  end if;
  update app.sales_order set payment_term_id = p_term_id where id = p_order_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Lưu đơn Nháp: điều khoản thanh toán, lớp, ngày vào lớp, và (đơn thẳng từ cơ hội) cả dòng, giờ.
-- Ai gọi: Đơn hàng · Sửa ở cơ sở của đơn; KHÔNG kiểm người gọi có phải người lập (Đ215): đồng nghiệp có quyền Sửa cùng cơ sở lưu được đơn Nháp của nhau. Đầu vào: p_lines và p_payment_term_id (null = giữ nguyên).
--   Đơn từ báo giá: p_lines là mảng {line_no, class_id, enrol_start_date}; giá, giờ, chiết khấu giữ nguyên đã đóng băng (R-TIEN-14).
--   Đơn thẳng từ cơ hội: p_lines là danh sách dòng đầy đủ (khuôn như lúc tạo), tính lại theo giá và chính sách của NGÀY TẠO ĐƠN (R-TIEN-14).
-- Luật: chỉ đơn Nháp; R-GD-06 (chọn lớp thì cần ngày vào lớp); R-GD-08 (kiểm lớp khi lưu); R-TIEN-07 (lịch đóng tiền tính lại mỗi lần lưu).
-- ---------------------------------------------------------------------------
create or replace function app.save_order(p_id uuid, p_lines jsonb default null, p_payment_term_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  e jsonb;
  l app.sales_order_line;
  v_class uuid;
  v_start date;
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
  if p_payment_term_id is not null then
    perform app.order_apply_term(p_id, p_payment_term_id);
  end if;
  if p_lines is not null then
    if jsonb_typeof(p_lines) <> 'array' then
      perform app.raise_error('HMT_DONG_THIEU', 'Danh sách dòng đơn không hợp lệ.');
    end if;
    if v_o.quotation_id is null then
      -- Đơn thẳng từ cơ hội: viết lại dòng, tính theo giá hôm nay.
      if jsonb_array_length(p_lines) = 0 then
        perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn cần ít nhất một dòng.');
      end if;
      -- Luật R-TIEN-14: đơn thẳng tính theo giá và chính sách hiệu lực NGÀY TẠO ĐƠN, lưu lại vẫn dùng ngày đó (priced_on không đổi).
      perform app.order_write_priced_lines(p_id, v_o.opportunity_id, v_o.branch_id, p_lines, v_o.priced_on);
    else
      -- Đơn từ báo giá: chỉ đổi lớp và ngày vào lớp theo số dòng.
      for e in select * from jsonb_array_elements(p_lines) loop
        select * into l from app.sales_order_line where order_id = p_id and line_no = (e ->> 'line_no')::integer;
        if l.id is null then
          perform app.raise_error('HMT_DONG_KHONG_CO', format('Không có dòng %s trong đơn.', e ->> 'line_no'));
        end if;
        v_class := nullif(e ->> 'class_id', '')::uuid;
        v_start := nullif(e ->> 'enrol_start_date', '')::date;
        if v_class is not null and v_start is null then
          perform app.raise_error('HMT_THIEU_NGAY_VAO_LOP', format('Dòng %s: chọn lớp thì cần ngày vào lớp.', l.line_no));
        end if;
        perform app.check_order_line_class(l.line_no, v_class, l.package_id, v_o.branch_id);
        update app.sales_order_line set class_id = v_class, enrol_start_date = v_start where id = l.id;
      end loop;
    end if;
  end if;
  perform app.order_refresh_totals(p_id);
  return jsonb_build_object('id', p_id, 'code', v_o.code, 'total_amount', (select total_amount from app.sales_order where id = p_id));
end;
$$;

drop function app.create_order_from_quotation(uuid, integer[]);
drop function app.create_order_from_opportunity(uuid, jsonb);

-- ---------------------------------------------------------------------------
-- Tạo đơn từ báo giá (R-TIEN-02, R-TIEN-14, R-CRM-16, Đ201). Một báo giá tạo được nhiều đơn, mỗi đơn lấy một số dòng.
-- Ai gọi: Đơn hàng · Tạo ở cơ sở của báo giá. Đầu vào: báo giá, danh sách số dòng muốn chuyển (null = mọi dòng chưa nằm trong đơn sống).
-- Luật: chỉ báo giá Đã gửi chuyển đơn; cơ hội phải ở L8 (chặn trong hàm); dòng sao NGUYÊN giá, chiết khấu, giờ đã đóng băng lúc Gửi,
-- không tính lại, kể cả khi báo giá quá hạn (R-TIEN-05); một dòng không nằm trong hai đơn đang sống.
-- Đầu vào thêm (Đ260): điều khoản thanh toán (tuỳ chọn), áp trong cùng giao dịch.
-- ---------------------------------------------------------------------------
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
begin
  select * into v_q from app.quotation where id = p_quotation_id for update;
  if v_q.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy báo giá.');
  end if;
  perform app.assert_can('SALES_ORDER', 'TAO', v_q.branch_id);
  perform app.require_feature('BAN_HANG', v_q.branch_id); -- Luật Đ173
  select * into v_opp from app.opportunity where id = v_q.opportunity_id;
  if v_opp.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không tạo đơn được.');
  end if;
  -- Luật R-TIEN-14: chỉ báo giá Đã gửi chuyển được đơn.
  if v_q.status_code <> 'DA_GUI' then
    perform app.raise_error('HMT_BAO_GIA_CHUA_GUI', 'Chỉ báo giá Đã gửi mới chuyển được thành đơn.');
  end if;
  -- Luật R-CRM-16: chưa ở L8 thì không tạo được đơn từ cơ hội.
  if v_opp.stage_code <> 'L8' then
    perform app.raise_error('HMT_CHUA_O_L8', 'Cơ hội cần ở L8 (phụ huynh đã thanh toán) mới tạo được đơn hàng.');
  end if;
  if p_line_nos is not null and exists (
       select from unnest(p_line_nos) n where not exists (select from app.quotation_line x where x.quotation_id = v_q.id and x.line_no = n)) then
    perform app.raise_error('HMT_DONG_KHONG_CO', 'Có dòng không thuộc báo giá này.');
  end if;
  select code into v_branch_code from app.branch where id = v_q.branch_id;
  v_code := app.issue_document_number('DH', v_branch_code);
  insert into app.sales_order (code, branch_id, opportunity_id, parent_id, quotation_id, priced_on)
  values (v_code, v_q.branch_id, v_q.opportunity_id, v_q.parent_id, v_q.id, v_q.priced_on)
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
    insert into app.sales_order_line (
      order_id, line_no, line_kind, quotation_line_id, prospect_student_id, student_id, package_id, package_code, package_name,
      package_type_code, delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent,
      gift_percent, discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id)
    values (
      v_id, v_n, l.line_kind, l.id, l.prospect_student_id, l.student_id, l.package_id, l.package_code, l.package_name,
      l.package_type_code, l.delivery_mode_code, l.unit_code, l.quantity, l.gifted_quantity, l.unit_price, l.gross_amount,
      l.discount_percent, l.gift_percent, l.discount_amount, l.line_total, l.over_cap, l.needs_acknowledgement, l.gift_policy_id)
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
  perform app.order_add_event(v_id, 'TAO', null, 'NHAP');
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

-- ---------------------------------------------------------------------------
-- Tạo đơn thẳng từ cơ hội, không qua báo giá (R-TIEN-02, R-CRM-16, R-TIEN-14: tính theo bảng giá và chính sách hiệu lực NGÀY TẠO ĐƠN).
-- Ai gọi: Đơn hàng · Tạo ở cơ sở của cơ hội. Đầu vào: cơ hội, mảng dòng (khuôn như app.save_quotation, thêm class_id, enrol_start_date), điều khoản thanh toán
-- (tuỳ chọn, Đ260: áp trong cùng giao dịch).
-- ---------------------------------------------------------------------------
create or replace function app.create_order_from_opportunity(p_opportunity_id uuid, p_lines jsonb, p_payment_term_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_opp app.opportunity;
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn cần ít nhất một dòng.');
  end if;
  select * into v_opp from app.opportunity where id = p_opportunity_id;
  if v_opp.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
  end if;
  perform app.assert_can('SALES_ORDER', 'TAO', v_opp.branch_id);
  perform app.require_feature('BAN_HANG', v_opp.branch_id); -- Luật Đ173
  if v_opp.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không tạo đơn được.');
  end if;
  -- Luật R-CRM-16: chưa ở L8 thì không tạo được đơn từ cơ hội.
  if v_opp.stage_code <> 'L8' then
    perform app.raise_error('HMT_CHUA_O_L8', 'Cơ hội cần ở L8 (phụ huynh đã thanh toán) mới tạo được đơn hàng.');
  end if;
  select code into v_branch_code from app.branch where id = v_opp.branch_id;
  v_code := app.issue_document_number('DH', v_branch_code);
  insert into app.sales_order (code, branch_id, opportunity_id, parent_id, priced_on)
  values (v_code, v_opp.branch_id, v_opp.id, v_opp.parent_id, v_on)
  returning id into v_id;
  perform app.order_write_priced_lines(v_id, v_opp.id, v_opp.branch_id, p_lines, v_on);
  -- Luật Đ260, R-CRM-19: điều khoản thanh toán áp ngay trong cùng giao dịch tạo đơn; điều khoản sai thì cả giao dịch lùi.
  if p_payment_term_id is not null then
    perform app.order_apply_term(v_id, p_payment_term_id);
  end if;
  perform app.order_refresh_totals(v_id);
  perform app.order_add_event(v_id, 'TAO', null, 'NHAP');
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', (select total_amount from app.sales_order where id = v_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- Xem trước học sinh của đơn cho hộp Duyệt, Từ chối (BH-07): mỗi dòng đơn ghi hệ thống SẼ làm gì với em khi duyệt (R-CRM-27, R-TIEN-35, Đ86).
-- Ai gọi: Đơn hàng · Xem ở cơ sở của đơn (hàm đọc thuần, không bị chặn khi tắt Bán hàng, Đ181). Đầu vào: đơn.
-- Kết quả: {order_id, lines: [{line_no, student_name, birth_year, student_code, outcome}], duplicates}; outcome là DA_CO_HO_SO (em đã có hồ sơ học sinh),
-- DUNG_HO_SO (khớp hồ sơ có sẵn theo phụ huynh + tên chuẩn hoá + năm sinh, app.find_student_match), TAO_MOI (sẽ tạo hồ sơ mới) hoặc THIEU_THONG_TIN
-- (thiếu họ tên hoặc năm sinh, chặn lúc trình, R-TIEN-35). `duplicates` là chuỗi "Tên (năm), …" của các em trùng họ tên và năm sinh trong đơn
-- (app.order_student_duplicates, như lúc duyệt) hoặc null. Không ghi gì.
-- ---------------------------------------------------------------------------
create or replace function app.preview_order_students(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
begin
  select * into v_o from app.sales_order where id = p_order_id;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'XEM', v_o.branch_id);
  return jsonb_build_object(
    'order_id', v_o.id,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
               'line_no', y.line_no, 'student_name', y.nm, 'birth_year', y.yr, 'student_code', y.code,
               'outcome', case when y.sid is not null then 'DA_CO_HO_SO'
                               when y.mid is not null then 'DUNG_HO_SO'
                               when btrim(coalesce(y.nm, '')) = '' or y.yr is null then 'THIEU_THONG_TIN'
                               else 'TAO_MOI' end) order by y.line_no)
        from (select x.*, (select st.code from app.student st where st.id = coalesce(x.sid, x.mid)) as code
                from (select l.line_no, coalesce(s.full_name, v.full_name) as nm, coalesce(s.birth_year, v.birth_year) as yr,
                             coalesce(l.student_id, v.student_id) as sid,
                             case when coalesce(l.student_id, v.student_id) is null and btrim(coalesce(v.full_name, '')) <> '' and v.birth_year is not null
                                  then app.find_student_match(v_o.parent_id, v.full_name, v.birth_year) end as mid
                        from app.sales_order_line l
                        left join app.prospect_student_v v on v.id = l.prospect_student_id
                        left join app.student s on s.id = l.student_id
                       where l.order_id = p_order_id) x) y), '[]'::jsonb),
    'duplicates', app.order_student_duplicates(p_order_id));
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.find_student_match(uuid, text, integer), app.order_student_duplicates(uuid), app.order_apply_term(uuid, uuid)
  from public, anon, authenticated;
revoke execute on function app.create_order_from_quotation(uuid, integer[], uuid), app.create_order_from_opportunity(uuid, jsonb, uuid),
  app.preview_order_students(uuid), app.save_order(uuid, jsonb, uuid) from public, anon;
grant execute on function app.create_order_from_quotation(uuid, integer[], uuid), app.create_order_from_opportunity(uuid, jsonb, uuid),
  app.preview_order_students(uuid), app.save_order(uuid, jsonb, uuid) to authenticated;
