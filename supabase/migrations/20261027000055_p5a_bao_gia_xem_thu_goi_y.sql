-- ===========================================================================
-- P5a-DB1c-2 (migration 055): hàm CHỈ ĐỌC và ghi chú cho màn Báo giá (BH-02): xem thử giá khi sửa dòng, danh sách gói bán, danh sách chính sách
-- chiết khấu, ghi chú và lịch sử cho báo giá. QĐ-Đ173, Đ181, Đ226, Đ228; R-TIEN-10, 12, 13, 29, 30, 36, 37.
-- Không ghi tiền, không ghi nhật ký (kể cả xem thử). Ghi chú báo giá dùng hàm ghi chú chung.
-- Việc d (mã đơn từng dòng trong get_quotation) làm sau khi #107 (đơn hàng) gộp.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Tham số "Hay dùng" của hộp chọn gói (Đ228): N gói người dùng chọn nhiều nhất trên báo giá của mình trong M ngày gần nhất.
-- ---------------------------------------------------------------------------
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('quotation_popular_packages_count', 'Số gói "Hay dùng" của hộp chọn gói', 'INT', 'gói', 1, 20, '5', false, 'BAN_HANG', 'Đ228',
   'Hộp chọn gói báo giá hiện bấy nhiêu gói người dùng chọn nhiều nhất trên báo giá của mình.'),
  ('quotation_popular_window_days', 'Số ngày tính gói "Hay dùng"', 'INT', 'ngày', 7, 365, '90', false, 'BAN_HANG', 'Đ228',
   'Gói "Hay dùng" tính trên báo giá của người dùng lập trong bấy nhiêu ngày gần nhất.');

-- ---------------------------------------------------------------------------
-- Ghi chú và lịch sử cho báo giá: đăng ký loại bản ghi và quyền xem (Báo giá · Xem ở cơ sở của báo giá).
-- ---------------------------------------------------------------------------
insert into app.note_target (entity_type, table_name, name) values ('QUOTATION', 'app.quotation', 'Báo giá');

-- Hàm quyền xem ghi chú: thêm loại QUOTATION (giữ nguyên các loại cũ).
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


-- ---------------------------------------------------------------------------
-- Quyền dùng chung của ba hàm gợi ý: người lập hoặc sửa báo giá ở cơ sở của cơ hội, Bán hàng đang bật (Đ173), cơ hội chưa gộp.
-- Trả cơ hội để hàm gọi dùng tiếp. Nội bộ.
-- ---------------------------------------------------------------------------
create or replace function app.assert_quotation_helper_access(p_opportunity_id uuid)
returns app.opportunity
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_opp app.opportunity;
begin
  select * into v_opp from app.opportunity where id = p_opportunity_id;
  if v_opp.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
  end if;
  if not app.can_see_branch('QUOTATION', 'TAO', v_opp.branch_id) and not app.can_see_branch('QUOTATION', 'SUA', v_opp.branch_id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền lập báo giá ở cơ sở này.');
  end if;
  perform app.require_feature('BAN_HANG', v_opp.branch_id); -- Luật Đ173
  if v_opp.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không lập báo giá được.');
  end if;
  return v_opp;
end;
$$;

-- ---------------------------------------------------------------------------
-- Xem thử báo giá (BH-02): tính từng dòng và tổng như lúc Lưu nhưng KHÔNG ghi gì (không dòng, không nhật ký).
-- Ai gọi: người lập hoặc sửa báo giá ở cơ sở của cơ hội. Đầu vào: cơ hội, mảng dòng cùng khuôn với app.save_quotation
-- {kind, prospect_student_id, package_id, delivery_mode_code, quantity, discounts: [{policy_id, value}], gift_policy_id}.
-- Gọi CÙNG hàm tính giá (app.price_line) với đường lưu, cùng ngày tính giá (hôm nay, giờ Việt Nam) nên cùng đầu vào cho cùng kết quả.
-- Kết quả: {lines: [{line_no, unit_price, gross_amount, discount_percent, gift_percent, gifted_quantity, discount_amount, line_total,
-- over_cap, needs_acknowledgement, unit_code, package_code, package_name, delivery_mode_code, quantity, discounts}], total_amount,
-- warnings: [{code, line_no, message}]}. Lỗi của app.price_line (gói ngừng bán, hình thức không có giá, chính sách không áp dụng…) báo đúng dòng.
-- ---------------------------------------------------------------------------
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
    perform app.validate_line_student(v_n, v_opp.id, nullif(e ->> 'prospect_student_id', '')::uuid);
    r := app.price_line(v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), nullif(e ->> 'package_id', '')::uuid,
                        e ->> 'delivery_mode_code', nullif(e ->> 'quantity', '')::numeric, e -> 'discounts',
                        nullif(e ->> 'gift_policy_id', '')::uuid, v_opp.branch_id, v_on);
    v_lines := v_lines || (jsonb_build_object('line_no', v_n) || r);
    v_total := v_total + (r ->> 'line_total')::bigint;
    -- Luật R-TIEN-29 (D3): vượt trần là cảnh báo, không chặn.
    if (r ->> 'over_cap')::boolean then
      v_warnings := v_warnings || jsonb_build_object('code', 'HMT_VUOT_TRAN', 'line_no', v_n,
        'message', format('Dòng %s: chiết khấu (gồm giờ tặng) vượt trần %s%%. Đơn cần người duyệt tích đồng ý.', v_n,
                          app.get_setting('discount_total_cap_percent')));
    end if;
  end loop;
  return jsonb_build_object('lines', v_lines, 'total_amount', v_total, 'warnings', v_warnings);
end;
$$;

-- ---------------------------------------------------------------------------
-- Gói bán cho hộp chọn gói (BH-02): gói đang bán hôm nay, giá theo hình thức (giá trống = không bán hình thức đó, R-TIEN-10),
-- nhóm "Hay dùng" (Đ228), nhóm "Gợi ý theo cơ hội" (môn và khối của các phiếu kiểm tra chưa huỷ của cơ hội).
-- Ai gọi: người lập hoặc sửa báo giá ở cơ sở của cơ hội (Sale không cần quyền Cấu hình bán hàng). Đầu vào: cơ hội, loại gói (lọc, tuỳ chọn),
-- chữ tìm (mã, tên, tuỳ chọn). Kết quả: {types: [{code, name}], popular: [mã gói], suggested: [mã gói], total, packages: [{id, code, name,
-- package_type_code, subject_code, grade_from_code, grade_to_code, unit_code, prices: {OFF, ONL}}]} (tối đa list_page_size_max gói, sắp theo mã).
-- Chỉ trả cột màn dùng. Gói chưa có giá nào hôm nay không hiện.
-- ---------------------------------------------------------------------------
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
  v_limit integer := app.get_setting_int('list_page_size_max');
  v_popular_n integer := app.get_setting_int('quotation_popular_packages_count');
  v_popular_days integer := app.get_setting_int('quotation_popular_window_days');
  v_result jsonb;
begin
  v_opp := app.assert_quotation_helper_access(p_opportunity_id);
  with priced as (
    select p.id, p.code, p.name, p.package_type_code, p.subject_code, p.grade_from_code, p.grade_to_code,
           jsonb_strip_nulls(jsonb_build_object(
             'OFF', app.package_price_at(p.id, 'OFF', v_on), 'ONL', app.package_price_at(p.id, 'ONL', v_on))) as prices
      from app.sales_package p
     where p.is_active
       and (p_type is null or p.package_type_code = p_type)
       and (v_q is null or app.fold_text(p.code || ' ' || p.name) like '%' || v_q || '%')
  ),
  sellable as (select * from priced where prices <> '{}'::jsonb),
  page as (select * from sellable order by code limit v_limit),
  popular as (
    select p.code
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
     where exists (select from app.student_test t
                    where t.opportunity_id = v_opp.id and t.status_code <> 'CANCELLED'
                      and t.subject_code = p.subject_code
                      and t.grade_code >= p.grade_from_code and t.grade_code <= coalesce(p.grade_to_code, p.grade_from_code))
     order by p.code
  )
  select jsonb_build_object(
           'types', coalesce((select jsonb_agg(jsonb_build_object('code', c.code, 'name', c.name) order by c.sort_order)
                                from app.catalog_item c where c.catalog_code = 'PACKAGE_TYPE' and c.is_active), '[]'::jsonb),
           'popular', coalesce((select jsonb_agg(code) from popular), '[]'::jsonb),
           'suggested', coalesce((select jsonb_agg(code) from suggested), '[]'::jsonb),
           'total', (select count(*) from sellable),
           'packages', coalesce((select jsonb_agg(jsonb_build_object(
               'id', g.id, 'code', g.code, 'name', g.name, 'package_type_code', g.package_type_code, 'subject_code', g.subject_code,
               'grade_from_code', g.grade_from_code, 'grade_to_code', g.grade_to_code,
               'unit_code', app.package_unit(g.package_type_code), 'prices', g.prices) order by g.code) from page g), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Chính sách chiết khấu áp dụng được hôm nay cho cơ hội (Đ226, R-TIEN-29): đang dùng, còn hiệu lực, đúng cơ sở của cơ hội.
-- Mỗi chính sách: mã, tên, loại (PERCENT hoặc GIFT_HOURS), mức tối đa, áp đúng mức hay chọn mức, có cần duyệt không, loại gói áp dụng
-- (rỗng = mọi loại gói; giao diện lọc theo gói đang chọn trên dòng). Ai gọi như app.list_sellable_packages.
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
             'id', d.id, 'code', d.code, 'name', d.name, 'kind', d.kind, 'max_value', d.max_value, 'fixed_value', d.fixed_value,
             'requires_approval', d.requires_approval, 'package_type_codes', to_jsonb(d.package_type_codes)) order by d.code)
      from app.discount_policy d
     where d.is_active and d.valid_from <= v_on and (d.valid_to is null or d.valid_to >= v_on)
       and (cardinality(d.branch_ids) = 0 or v_opp.branch_id = any (d.branch_ids))), '[]'::jsonb);
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.assert_quotation_helper_access(uuid) from public, anon, authenticated;
revoke execute on function app.preview_quotation_lines(uuid, jsonb), app.list_sellable_packages(uuid, text, text),
  app.list_applicable_discount_policies(uuid) from public, anon;
grant execute on function app.preview_quotation_lines(uuid, jsonb), app.list_sellable_packages(uuid, text, text),
  app.list_applicable_discount_policies(uuid) to authenticated;
