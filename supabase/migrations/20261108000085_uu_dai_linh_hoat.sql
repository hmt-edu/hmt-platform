-- Ưu đãi linh hoạt (Q-141, R-V2-45; hạn trước 12/11): chip "Ưu đãi linh hoạt" trên dòng báo giá và dòng đơn.
-- Làm gì:
--  (1) Tham số flexible_discount_max_percent: hạn mức mỗi dòng, mặc định 5%, Admin sửa 0 đến 20%, không ghi đè theo cơ sở.
--  (2) Cột app.discount_policy.is_flexible và một chính sách hệ thống UU_DAI_LINH_HOAT (kiểu PERCENT, nhân viên nhập tay): chính sách này không sửa,
--      không ngừng ở màn Chiết khấu (hạn mức chỉnh ở Cài đặt).
--  (3) price_apply_discounts: chính sách linh hoạt bắt buộc có % nhập tay, > 0 và không quá tham số; quá thì lỗi HMT_UU_DAI_VUOT_MUC
--      "Ưu đãi linh hoạt tối đa N%". % này cộng dồn vào trần tổng 20% như mọi chiết khấu % (vượt trần chỉ cảnh báo, R-V2-11).
--  (4) list_applicable_discount_policies: trả mức tối đa của chính sách linh hoạt từ tham số (không phải số cố định trong bảng) và cờ is_flexible.
-- Báo giá không có bước duyệt, Phiếu thu không đổi. Chỉ mục: không thêm (bảng discount_policy chỉ vài chục dòng, đã có chỉ mục hiệu lực).
--  (5) Nhật ký (Q-145): sự kiện TAO và SUA của đơn thêm dòng "Ưu đãi linh hoạt X% ở dòng N" (đơn từ báo giá: cuối dòng "(nhập ở báo giá BG-...)").
--      Báo giá chỉ dựa audit_log (quotation_line_discount, người nhập và % đã được ghi), không có bảng sự kiện hay dòng thời gian Báo giá ở phase này.

select set_config('hmt.migration', 'on', false);

insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('flexible_discount_max_percent', 'Ưu đãi linh hoạt tối đa mỗi dòng', 'NUMERIC', '%', 0, 20, '5', false, 'BAN_HANG', 'R-V2-45',
   'Hạn mức % của chip "Ưu đãi linh hoạt" trên một dòng báo giá hoặc dòng đơn. Nhập quá thì máy chủ từ chối. Tính vào trần tổng chiết khấu (vượt trần chỉ cảnh báo).');

alter table app.discount_policy add column is_flexible boolean not null default false;
comment on column app.discount_policy.is_flexible is 'Chính sách "Ưu đãi linh hoạt" (R-V2-45): % nhập tay, hạn mức đọc từ tham số flexible_discount_max_percent; không sửa, không ngừng ở màn Chiết khấu.';

-- max_value của chính sách linh hoạt chỉ là giá trị tạm của bảng (check max_value > 0); hạn mức thật đọc từ tham số.
insert into app.discount_policy (code, name, kind, max_value, fixed_value, requires_approval, valid_from, is_flexible)
values ('UU_DAI_LINH_HOAT', 'Ưu đãi linh hoạt', 'PERCENT', 5, false, false, date '2026-01-01', true);

-- Luật R-V2-45: chính sách linh hoạt là chính sách hệ thống: ngoài migration không tạo thêm, không sửa, không ngừng.
create or replace function app.tg_discount_policy_flexible_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if app.is_migration() then
    return new;
  end if;
  if TG_OP = 'INSERT' and new.is_flexible then
    perform app.raise_error('HMT_CHINH_SACH_HE_THONG', 'Chính sách "Ưu đãi linh hoạt" là chính sách hệ thống, không tạo thêm.');
  end if;
  if TG_OP = 'UPDATE' and old.is_flexible
     and (new.is_flexible is distinct from old.is_flexible or new.name is distinct from old.name or new.kind is distinct from old.kind
          or new.max_value is distinct from old.max_value or new.fixed_value is distinct from old.fixed_value
          or new.requires_approval is distinct from old.requires_approval or new.is_active is distinct from old.is_active
          or new.valid_from is distinct from old.valid_from or new.valid_to is distinct from old.valid_to
          or new.package_type_codes is distinct from old.package_type_codes or new.branch_ids is distinct from old.branch_ids) then
    perform app.raise_error('HMT_CHINH_SACH_HE_THONG',
      'Ưu đãi linh hoạt là chính sách hệ thống: chỉnh hạn mức ở Cài đặt (Ưu đãi linh hoạt tối đa mỗi dòng), không sửa hay ngừng ở đây.');
  end if;
  return new;
end;
$$;
create trigger discount_policy_flexible_guard before insert or update on app.discount_policy
  for each row execute function app.tg_discount_policy_flexible_guard();

-- ---------------------------------------------------------------------------
-- app.price_apply_discounts (thay bản migration 045): thêm nhánh chính sách linh hoạt (R-V2-45); các luật cũ giữ nguyên.
-- Ai gọi: hàm tính giá (price_line, xem thử báo giá, tạo, sửa đơn). Đầu vào: số dòng, loại gói, cơ sở, ngày, mảng {policy_id, value}.
-- ---------------------------------------------------------------------------
create or replace function app.price_apply_discounts(
  p_line_no integer, p_package_type text, p_branch_id uuid, p_on date, p_discounts jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e jsonb;
  d app.discount_policy;
  v_value numeric;
  v_percent numeric := 0;
  v_gift numeric := 0;
  v_gift_count integer := 0;
  v_ack boolean := false;
  v_applied jsonb := '[]'::jsonb;
  v_seen uuid[] := array[]::uuid[];
  v_flex_max numeric;
begin
  for e in select * from jsonb_array_elements(coalesce(p_discounts, '[]'::jsonb)) loop
    select * into d from app.discount_policy where id = nullif(e ->> 'policy_id', '')::uuid;
    if d.id is null then
      perform app.raise_error('HMT_CHINH_SACH_KHONG_CO', format('Dòng %s: chính sách chiết khấu không có.', p_line_no));
    end if;
    -- Luật: một chính sách chỉ áp một lần trên dòng.
    if d.id = any (v_seen) then
      perform app.raise_error('HMT_CHINH_SACH_TRUNG', format('Dòng %s: chính sách "%s" chọn hai lần.', p_line_no, d.name));
    end if;
    v_seen := v_seen || d.id;
    -- Luật R-TIEN-29: chính sách còn dùng, còn hiệu lực, đúng loại gói, đúng cơ sở.
    if not d.is_active or d.valid_from > p_on or (d.valid_to is not null and d.valid_to < p_on)
       or (cardinality(d.package_type_codes) > 0 and not p_package_type = any (d.package_type_codes))
       or (cardinality(d.branch_ids) > 0 and not p_branch_id = any (d.branch_ids)) then
      perform app.raise_error('HMT_CHINH_SACH_KHONG_AP_DUNG',
        format('Dòng %s: chính sách "%s" không áp dụng cho gói, cơ sở hoặc ngày này.', p_line_no, d.name));
    end if;
    -- Luật R-TIEN-36: mức do nhân viên điền, không quá mức tối đa; chính sách "áp đúng mức" lấy đúng mức tối đa.
    -- Luật R-V2-45 (Ưu đãi linh hoạt, Q-141): % do nhân viên nhập tay (bắt buộc nhập, không có mức mặc định), hạn mức mỗi dòng đọc từ
    -- tham số flexible_discount_max_percent (mặc định 5%, Admin sửa 0 đến 20%); nhập quá thì từ chối. Tính vào trần tổng như mọi chiết khấu %.
    if d.is_flexible then
      v_flex_max := app.get_setting('flexible_discount_max_percent')::numeric;
      v_value := nullif(e ->> 'value', '')::numeric;
      if v_value is null or v_value <= 0 then
        perform app.raise_error('HMT_UU_DAI_THIEU_MUC', format('Dòng %s: nhập %% ưu đãi linh hoạt lớn hơn 0.', p_line_no));
      end if;
      if v_value > v_flex_max then
        perform app.raise_error('HMT_UU_DAI_VUOT_MUC', format('Ưu đãi linh hoạt tối đa %s%%', trim_scale(v_flex_max)));
      end if;
    else
      v_value := case when d.fixed_value then d.max_value else nullif(e ->> 'value', '')::numeric end;
      v_value := coalesce(v_value, case when d.kind = 'PERCENT' then d.max_value end);
      if v_value is null or v_value <= 0 or v_value > d.max_value then
        perform app.raise_error('HMT_CHIET_KHAU_VUOT_MUC',
          format('Dòng %s: mức của chính sách "%s" phải lớn hơn 0 và không quá %s.', p_line_no, d.name, d.max_value));
      end if;
    end if;
    if d.kind = 'PERCENT' then
      v_percent := v_percent + v_value;
    else
      -- Luật Đ174: một dòng dùng tối đa MỘT chính sách tặng giờ.
      v_gift_count := v_gift_count + 1;
      if v_gift_count > 1 then
        perform app.raise_error('HMT_CHI_MOT_CHINH_SACH_TANG_GIO', format('Dòng %s: chỉ dùng được một chính sách tặng giờ.', p_line_no));
      end if;
      v_gift := v_value;
    end if;
    v_ack := v_ack or d.requires_approval;
    v_applied := v_applied || jsonb_build_object('policy_id', d.id, 'policy_code', d.code, 'policy_name', d.name,
                                                 'kind', d.kind, 'applied_value', v_value, 'requires_approval', d.requires_approval);
  end loop;
  if v_percent > 100 then -- allow-number: phần trăm tối đa 100
    perform app.raise_error('HMT_CHIET_KHAU_SAI', format('Dòng %s: tổng chiết khấu phần trăm không quá 100.', p_line_no));
  end if;
  return jsonb_build_object('percent', v_percent, 'gift_hours', v_gift, 'needs_acknowledgement', v_ack, 'applied', v_applied);
end;
$$;

-- ---------------------------------------------------------------------------
-- app.list_applicable_discount_policies (thay bản migration 055): thêm is_flexible và mức tối đa của chính sách linh hoạt từ tham số.
-- ---------------------------------------------------------------------------
create or replace function app.list_applicable_discount_policies(p_opportunity_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_opp app.opportunity;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  v_opp := app.assert_quotation_helper_access(p_opportunity_id);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', d.id, 'code', d.code, 'name', d.name, 'kind', d.kind,
             'max_value', case when d.is_flexible then app.get_setting('flexible_discount_max_percent')::numeric else d.max_value end,
             'is_flexible', d.is_flexible, 'fixed_value', d.fixed_value,
             'requires_approval', d.requires_approval, 'package_type_codes', to_jsonb(d.package_type_codes)) order by d.code)
      from app.discount_policy d
     where d.is_active and d.valid_from <= v_on and (d.valid_to is null or d.valid_to >= v_on)
       and (cardinality(d.branch_ids) = 0 or v_opp.branch_id = any (d.branch_ids))), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- Nhật ký đơn cho Ưu đãi linh hoạt (Q-145): các dòng "Ưu đãi linh hoạt X% ở dòng N" của một đơn, mỗi dòng đơn có ưu đãi một dòng chữ (xếp theo số
-- dòng). Không ghi tên người: sự kiện đã hiện người thực hiện. Đơn tạo từ báo giá (p_from_quotation): cuối dòng thêm "(nhập ở báo giá BG-...)" vì
-- % được nhập ở báo giá rồi chép sang đơn. Kết quả: nhiều dòng nối bằng xuống dòng, hoặc null nếu đơn không có ưu đãi linh hoạt.
-- Ai gọi: hàm tạo đơn (TAO). Chỉ đọc.
-- ---------------------------------------------------------------------------
create or replace function app.order_flexible_note(p_order_id uuid, p_from_quotation boolean default false)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select string_agg(
           format('Ưu đãi linh hoạt %s%% ở dòng %s', trim_scale(d.applied_value), s.line_no)
             || case when p_from_quotation and q.code is not null then format(' (nhập ở báo giá %s)', q.code) else '' end,
           E'\n' order by s.line_no)
    from app.sales_order_line s
    join app.sales_order_line_discount d on d.line_id = s.id and d.policy_code = 'UU_DAI_LINH_HOAT'
    join app.sales_order o on o.id = s.order_id
    left join app.quotation q on q.id = o.quotation_id
   where s.order_id = p_order_id;
$$;
revoke execute on function app.order_flexible_note(uuid, boolean) from public, anon;
grant execute on function app.order_flexible_note(uuid, boolean) to authenticated;

-- app.create_order_from_opportunity (thay bản migration 061): sự kiện TAO ghi dòng ưu đãi linh hoạt (Q-145); luật cũ giữ nguyên.
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
  -- Nhật ký (Q-145): dòng ưu đãi linh hoạt nhập thẳng ở đơn.
  perform app.order_add_event(v_id, 'TAO', null, 'NHAP', null, null, app.order_flexible_note(v_id, false));
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', (select total_amount from app.sales_order where id = v_id));
end;
$$;

-- app.create_order_from_quotation (thay bản migration 061): như trên, kèm mã báo giá.
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

-- app.edit_order (thay bản migration 082): sự kiện SUA ghi dòng ưu đãi linh hoạt mới hoặc đổi mức (Q-145); luật cũ giữ nguyên.
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
  v_flex numeric;
  v_old_flex numeric;
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
        -- Nhật ký (Q-145): dòng mới có ưu đãi linh hoạt thì thêm một dòng "Ưu đãi linh hoạt X% ở dòng N".
        select d.applied_value into v_flex from app.sales_order_line s
          join app.sales_order_line_discount d on d.line_id = s.id and d.policy_code = 'UU_DAI_LINH_HOAT'
         where s.order_id = p_id and s.line_no = (r ->> 'line_no')::integer;
        if v_flex is not null then
          v_changes := array_append(v_changes, format('Ưu đãi linh hoạt %s%% ở dòng %s', trim_scale(v_flex), r ->> 'line_no'));
        end if;
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
      select d.applied_value into v_old_flex from app.sales_order_line_discount d where d.line_id = l.id and d.policy_code = 'UU_DAI_LINH_HOAT';
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
      -- Nhật ký (Q-145): ưu đãi linh hoạt mới hoặc đổi mức thì thêm một dòng "Ưu đãi linh hoạt X% ở dòng N" (không đổi mức thì không ghi).
      select d.applied_value into v_flex from app.sales_order_line_discount d where d.line_id = l.id and d.policy_code = 'UU_DAI_LINH_HOAT';
      if v_flex is not null and v_flex is distinct from v_old_flex then
        v_changes := array_append(v_changes, format('Ưu đãi linh hoạt %s%% ở dòng %s', trim_scale(v_flex), l.line_no));
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

select set_config('hmt.migration', '', false);
