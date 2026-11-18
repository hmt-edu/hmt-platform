-- Migration 454 (Code D, 18/11/2026): TC-16 «Dùng số dư khách hàng cho đơn mới» (R-CS-03, R-TIEN-33). CAO (tiền).
-- Thiết kế (Chat chọn phương án A): số dư của phụ huynh được cấn vào đơn Đã duyệt như MỘT KHOẢN TIỀN VÀO không qua phiếu thu:
--   1. Hàm app.apply_customer_balance_to_order(đơn, số tiền): Kế toán · Duyệt; khoá đơn và phụ huynh; số tiền ≤ số dư hiện tại và ≤ phần còn thu của đơn;
--      ghi dòng sổ số dư DUNG_CHO_DON (âm), sinh khoản tiền vào (receipt_id rỗng, trỏ dòng sổ), chia về dòng đơn, tạo ghi danh và cấp giờ như duyệt phiếu thu.
--   2. Không sửa phiếu thu cũ, không sửa ràng buộc nền: chỉ thêm cột money_in.balance_entry_id và nới money_in_sign_check cho khoản dương không phiếu thu nhưng có dòng sổ.
--   3. Hoàn tác khoản cấn (app.reverse_money_in) trả lại số dư bằng dòng DIEU_CHINH (+), tính lại giờ.
--   4. order_has_receipt tính cả khoản cấn chưa bị đảo: không huỷ đơn đã cấn số dư (R-TIEN-02).
-- Cờ tham số customer_balance_apply_enabled mặc định TẮT (theo cơ sở), kiểm trong hàm DB.

alter table app.money_in add column balance_entry_id uuid references app.customer_balance_entry (id);
-- Chỉ mục (lý do): tìm khoản tiền vào sinh từ một dòng sổ số dư (một dòng sổ chỉ sinh một khoản).
create unique index money_in_balance_entry_uq on app.money_in (balance_entry_id) where balance_entry_id is not null;
alter table app.money_in drop constraint money_in_sign_check;
alter table app.money_in add constraint money_in_sign_check check (
  (amount > 0 and receipt_id is not null and balance_entry_id is null and reversal_of is null and reason_code is null)
  or (amount > 0 and receipt_id is null and balance_entry_id is not null and reversal_of is null and reason_code is null)
  or (amount < 0 and receipt_id is null and reversal_of is not null and reason_code is not null));

select set_config('hmt.migration', 'on', false);
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('customer_balance_apply_enabled', 'Cho phép cấn số dư khách hàng vào đơn (TC-16)', 'BOOL', null, null, null, 'false', true, 'BAN_HANG', 'R-TIEN-33',
   'Tắt: không cấn được số dư khách hàng vào đơn. Bật: Kế toán cấn số dư của phụ huynh vào đơn Đã duyệt còn phần phải thu; số cấn không vượt số dư và phần còn thu.');
select set_config('hmt.migration', '', false);

-- app.order_has_receipt: thêm khoản cấn số dư còn hiệu lực (chưa bị đảo) vào điều kiện chặn huỷ đơn.
create or replace function app.order_has_receipt(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.receipt where order_id = p_order_id and status_code <> 'HUY')
      or exists (select from app.money_in m where m.order_id = p_order_id and m.balance_entry_id is not null
                  and not exists (select from app.money_in x where x.reversal_of = m.id));
$$;

-- app.apply_customer_balance_to_order(đơn, số tiền): cấn số dư khách hàng vào đơn (TC-16). Ai gọi: người có Kế toán · Duyệt ở cơ sở của đơn (Admin không, R-HT-01).
-- Đầu vào: id đơn (Đã duyệt), số tiền đồng (> 0). Kết quả: {money_in_id, money_in_code, amount, balance_after, paid, remaining}.
-- Luật: R-TIEN-33 (số dư là tổng sổ, chỉ thêm dòng); số tiền ≤ số dư hiện tại; ≤ phần còn thu của đơn (trừ cả phiếu đang chờ duyệt); khoá đơn và phụ huynh nên hai lần cấn song song không vượt số dư.
-- Lỗi: HMT_TINH_NANG_TAT, HMT_KHONG_CO_QUYEN, HMT_KHONG_TIM_THAY, HMT_SAI_TRANG_THAI (đơn chưa Đã duyệt), HMT_SO_TIEN_SAI, HMT_SO_DU_KHONG_DU, HMT_SO_TIEN_VUOT.
create or replace function app.apply_customer_balance_to_order(p_order_id uuid, p_amount bigint)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
  v_balance bigint;
  v_entry uuid;
  v_money uuid;
  v_code text;
  v_branch_code text;
begin
  select * into o from app.sales_order where id = p_order_id for update;
  if o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  -- Luật R-HT-01: chỉ Kế toán (Kế toán · Duyệt); công tắc Bán hàng và cờ TC-16 kiểm trong hàm DB.
  perform app.assert_can('ACCOUNTING', 'DUYET', o.branch_id);
  perform app.require_feature('BAN_HANG', o.branch_id);
  if not app.get_setting_bool('customer_balance_apply_enabled', o.branch_id) then
    perform app.raise_error('HMT_TINH_NANG_TAT', 'Cấn số dư khách hàng vào đơn chưa được bật cho cơ sở này.');
  end if;
  if o.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ cấn số dư vào đơn Đã duyệt.');
  end if;
  if p_amount is null or p_amount <= 0 then
    perform app.raise_error('HMT_SO_TIEN_SAI', 'Số tiền cấn phải lớn hơn 0.');
  end if;
  -- Luật R-TIEN-33: khoá phụ huynh (tuần tự hoá hai lần cấn), rồi kiểm số dư hiện tại là tổng sổ.
  perform 1 from app.parent where id = o.parent_id for update;
  select coalesce(sum(amount), 0)::bigint into v_balance from app.customer_balance_entry where parent_id = o.parent_id;
  if p_amount > v_balance then
    perform app.raise_error('HMT_SO_DU_KHONG_DU', 'Số tiền cấn vượt số dư khách hàng hiện có.');
  end if;
  -- Luật R-TIEN-22: số tiền không vượt phần còn thu của đơn.
  if p_amount > app.order_receivable(o.id) then
    perform app.raise_error('HMT_SO_TIEN_VUOT', 'Số tiền cấn vượt phần còn phải thu của đơn.');
  end if;
  select code into v_branch_code from app.branch where id = o.branch_id;
  v_code := app.issue_document_number('KTV', v_branch_code);
  insert into app.customer_balance_entry (parent_id, branch_id, entry_type, amount, entry_date, source_ref, note)
  values (o.parent_id, o.branch_id, 'DUNG_CHO_DON', -p_amount, (now() at time zone 'Asia/Ho_Chi_Minh')::date, v_code, 'Cấn vào đơn ' || o.code)
  returning id into v_entry;
  insert into app.money_in (code, receipt_id, balance_entry_id, order_id, parent_id, branch_id, amount)
  values (v_code, null, v_entry, o.id, o.parent_id, o.branch_id, p_amount)
  returning id into v_money;
  perform app.allocate_money_in(v_money, o.id, p_amount, null, o.branch_id);
  -- Như duyệt phiếu thu (R-TIEN-20, R-TIEN-21): đủ cọc thì tạo ghi danh và cấp giờ theo tiền.
  perform app.create_enrollments_for_order(o.id);
  return jsonb_build_object('money_in_id', v_money, 'money_in_code', v_code, 'amount', p_amount, 'balance_after', v_balance - p_amount,
                            'paid', app.order_paid_amount(o.id), 'remaining', o.total_amount - app.order_paid_amount(o.id));
end;
$$;
revoke execute on function app.apply_customer_balance_to_order(uuid, bigint) from public, anon;
grant execute on function app.apply_customer_balance_to_order(uuid, bigint) to authenticated;

-- app.reverse_money_in: thân bản migration 251 (TC-02), thêm nhánh khoản cấn số dư (trả lại số dư). Mọi luật cũ giữ nguyên.
create or replace function app.reverse_money_in(p_money_in_id uuid, p_reason_code text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  m app.money_in;
  v_new uuid;
  v_code text;
  v_branch_code text;
  v_neg integer;
  v_opening boolean;
begin
  select * into m from app.money_in where id = p_money_in_id for update;
  if m.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy khoản tiền vào.');
  end if;
  -- Luật R-HT-01: chỉ người có quyền Kế toán · Duyệt (Admin không có) trong cơ sở của khoản.
  perform app.assert_can('ACCOUNTING', 'DUYET', m.branch_id);
  -- Công tắc: tính năng chưa bật cho cơ sở thì chặn (kiểm trong hàm DB, ngoài giao diện).
  perform app.require_feature('BAN_HANG', m.branch_id);
  if not app.get_setting_bool('money_reversal_enabled', m.branch_id) then
    perform app.raise_error('HMT_TINH_NANG_TAT', 'Hoàn tác khoản tiền chưa được bật cho cơ sở này.');
  end if;
  -- Luật R-TIEN-26: không đảo khoản âm; chặn đảo hai lần.
  if m.amount < 0 then
    perform app.raise_error('HMT_KHONG_DAO_KHOAN_AM', 'Đây là khoản đảo, không hoàn tác lại được.');
  end if;
  if exists (select from app.money_in x where x.reversal_of = m.id) then
    perform app.raise_error('HMT_DA_DAO_KHOAN', 'Khoản tiền này đã được hoàn tác rồi.');
  end if;
  -- Luật R-TIEN-26, R-HT-04: bắt buộc lý do từ danh mục; "Khác" phải có ghi chú.
  if p_reason_code is null then
    perform app.raise_error('HMT_THIEU_LY_DO', 'Chọn lý do hoàn tác khoản tiền.');
  end if;
  perform app.assert_catalog_code_active('REVERSAL_REASON', p_reason_code);
  if (select requires_note from app.catalog_item where catalog_code = 'REVERSAL_REASON' and code = p_reason_code)
     and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_THIEU_GHI_CHU', 'Chọn lý do "Khác" thì phải ghi chú.');
  end if;
  -- Khoá đơn để không lẫn với duyệt phiếu thu đang chạy.
  v_opening := m.is_opening_debt;
  if m.order_id is not null then
    perform 1 from app.sales_order where id = m.order_id for update;
  end if;
  select code into v_branch_code from app.branch where id = m.branch_id;
  v_code := app.issue_document_number('KTV', v_branch_code);
  insert into app.money_in (code, receipt_id, order_id, is_opening_debt, opening_debt_student_id, parent_id, branch_id, amount, reversal_of, reason_code, reason_note)
  values (v_code, null, m.order_id, m.is_opening_debt, m.opening_debt_student_id, m.parent_id, m.branch_id, -m.amount, m.id, p_reason_code, nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_new;
  -- Phần chia về dòng đơn: đảo đúng từng phần của khoản gốc (tổng allocation âm = -amount).
  insert into app.money_in_allocation (money_in_id, order_line_id, branch_id, amount)
  select v_new, a.order_line_id, a.branch_id, -a.amount from app.money_in_allocation a where a.money_in_id = m.id;
  -- Luật R-TIEN-26: giờ đã cấp tính lại theo tiền còn lại (sổ giờ thêm dòng âm).
  if m.balance_entry_id is not null then
    -- TC-16 (R-TIEN-33): khoản tiền đã cấn từ số dư khách hàng thì hoàn tác trả lại số dư (dòng điều chỉnh dương), không có tiền mặt để trả.
    insert into app.customer_balance_entry (parent_id, branch_id, entry_type, amount, entry_date, source_ref, note)
    values (m.parent_id, m.branch_id, 'DIEU_CHINH', m.amount, current_date, v_code, 'Hoàn tác khoản cấn số dư ' || m.code);
    perform app.sync_enrollment_hours(m.order_id);
  elsif v_opening then
    -- Luật R-V2-15, R-TIEN-26: hoàn tác khoản thu nợ đầu kỳ thì nợ đầu kỳ của học sinh được cộng lại (khoản âm trong sổ số dư), không có giờ để tính lại.
    insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref)
    values (m.parent_id, m.opening_debt_student_id, m.branch_id, 'DAO_THU_NO_DAU_KY', -m.amount, current_date, v_code);
  else
    perform app.sync_enrollment_hours(m.order_id);
  end if;
  -- Luật R-GD-12: giờ âm cho phép; báo số ghi danh của đơn đang âm để Kế toán biết.
  select count(*) into v_neg from app.enrollment e
   where m.order_id is not null and e.order_id = m.order_id
     and (select coalesce(sum(h.hours), 0) from app.hour_ledger h where h.enrollment_id = e.id) < 0;
  return jsonb_build_object('id', v_new, 'code', v_code, 'reversed_code', m.code, 'amount', -m.amount, 'enrollments_negative', v_neg);
end;
$$;
revoke execute on function app.reverse_money_in(uuid, text, text) from public, anon;
grant execute on function app.reverse_money_in(uuid, text, text) to authenticated;
