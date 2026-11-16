-- TC-02 Thu nợ đầu kỳ, phần DB (Code C, 16/11/2026). Luật R-V2-15: phiếu thu KHÔNG cần đơn: CSKH tạo, KẾ TOÁN duyệt (không qua quản lý trực tiếp), số tiền không vượt nợ đầu kỳ còn lại của học sinh;
-- duyệt xong ghi khoản tiền vào (KTV) và giảm nợ đầu kỳ. R-V2-32: nợ đầu kỳ nằm ở sổ số dư khách hàng (customer_balance_entry, DAU_KY_CONG_NO, số âm). R-HT-01: Admin không duyệt tiền. R-TIEN-26: hoàn tác khoản thu nợ đầu kỳ cộng lại nợ.
-- CỜ TẮT MẶC ĐỊNH: tham số opening_debt_receipt_enabled (ghi đè theo cơ sở). Ngày 17/11 chỉ nạp giờ (Q-227); chỉ bật khi Chat/anh chốt nạp công nợ.
-- AN TOÀN: KHÔNG sửa các hàm phiếu thu hiện có (create_receipt, submit_receipt, approve_receipt_accounting). Phiếu nợ đầu kỳ dùng hàm riêng; ràng buộc receipt_kind_check và money_in_kind_check
-- (đúng MỘT trong order_id hoặc opening_debt_student_id) khiến các hàm cũ KHÔNG thể tạo khoản tiền rỗng đơn. cancel_receipt và reject_receipt không đụng tới đơn nên dùng chung được.
-- Chỉ sửa hai hàm của chính TC-09/TC-08: reverse_money_in (xử lý khoản không có đơn: cộng lại nợ, không tính giờ) và list_money_in (nối trái đơn).

select set_config('hmt.migration', 'on', false);
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('opening_debt_receipt_enabled', 'Cho phép phiếu «Thu nợ đầu kỳ»', 'BOOL', null, null, null, 'false', true, 'BAN_HANG', 'R-V2-15',
   'Tắt: không tạo, gửi, duyệt được phiếu thu nợ đầu kỳ ở cơ sở. Bật: CSKH tạo phiếu không cần đơn, Kế toán duyệt, số tiền không vượt nợ đầu kỳ còn lại của học sinh.');

-- 1. Sổ số dư khách hàng: thêm hai loại dòng (thu nợ đầu kỳ dương, hoàn tác thu nợ đầu kỳ âm).
alter table app.customer_balance_entry drop constraint customer_balance_entry_check;
alter table app.customer_balance_entry drop constraint customer_balance_entry_entry_type_check;
alter table app.customer_balance_entry add constraint customer_balance_entry_entry_type_check
  check (entry_type in ('DAU_KY_THU_THUA', 'DAU_KY_CONG_NO', 'THU_NO_DAU_KY', 'DAO_THU_NO_DAU_KY'));
alter table app.customer_balance_entry add constraint customer_balance_entry_check
  check ((entry_type in ('DAU_KY_THU_THUA', 'THU_NO_DAU_KY') and amount > 0) or (entry_type in ('DAU_KY_CONG_NO', 'DAO_THU_NO_DAU_KY') and amount < 0));

-- 2. Phiếu thu và khoản tiền vào: cho rỗng đơn, kèm học sinh có nợ đầu kỳ; đúng một trong hai.
alter table app.receipt alter column order_id drop not null;
alter table app.receipt add column opening_debt_student_id uuid references app.student (id);
alter table app.receipt add constraint receipt_kind_check
  check ((order_id is not null and opening_debt_student_id is null) or (order_id is null and opening_debt_student_id is not null));
alter table app.money_in alter column order_id drop not null;
alter table app.money_in add column opening_debt_student_id uuid references app.student (id);
alter table app.money_in add constraint money_in_kind_check
  check ((order_id is not null and opening_debt_student_id is null) or (order_id is null and opening_debt_student_id is not null));
-- Chỉ mục (lý do): tính nợ còn lại và phiếu đang chờ của một học sinh; chỉ các dòng nợ đầu kỳ nên dùng chỉ mục cục bộ.
create index receipt_opening_student_idx on app.receipt (opening_debt_student_id) where opening_debt_student_id is not null;
create index money_in_opening_student_idx on app.money_in (opening_debt_student_id) where opening_debt_student_id is not null;

-- 3. app.opening_debt_remaining(học sinh, trừ phiếu): nợ đầu kỳ còn lại (đồng, không âm) = nợ trong sổ số dư trừ các phiếu ĐANG CHỜ (Nháp, Đã gửi, Chờ kế toán) để không thu vượt.
create or replace function app.opening_debt_remaining(p_student_id uuid, p_except uuid default null)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select greatest(
           -coalesce((select sum(amount) from app.customer_balance_entry
                       where student_id = p_student_id and entry_type in ('DAU_KY_CONG_NO', 'THU_NO_DAU_KY', 'DAO_THU_NO_DAU_KY')), 0)
           - coalesce((select sum(amount) from app.receipt
                        where opening_debt_student_id = p_student_id and status_code in ('NHAP', 'DA_GUI', 'CHO_KE_TOAN')
                          and (p_except is null or id <> p_except)), 0),
           0)::bigint;
$$;

-- 4. app.create_opening_debt_receipt(học sinh, dữ liệu): CSKH tạo phiếu Thu nợ đầu kỳ (Nháp), không cần đơn. Ai gọi: Phiếu thu · Tạo ở cơ sở của học sinh; cần Bán hàng bật và cờ.
-- p_data: amount, payment_method_code, txn_ref, paid_on, collect_branch_id, receiver_id, note. Kết quả {id, code, remaining_after}.
create or replace function app.create_opening_debt_receipt(p_student_id uuid, p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  st app.student;
  v_amount bigint;
  v_method text := nullif(btrim(coalesce(p_data ->> 'payment_method_code', '')), '');
  v_paid_on date;
  v_collect uuid;
  v_receiver uuid;
  v_remaining bigint;
  v_id uuid;
  v_code text;
  v_branch_code text;
begin
  select * into st from app.student where id = p_student_id;
  if st.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy học sinh.');
  end if;
  perform app.assert_can('RECEIPT', 'TAO', st.branch_id);
  perform app.require_feature('BAN_HANG', st.branch_id);
  if not app.get_setting_bool('opening_debt_receipt_enabled', st.branch_id) then
    perform app.raise_error('HMT_TINH_NANG_TAT', 'Thu nợ đầu kỳ chưa được bật cho cơ sở này.');
  end if;
  -- Luật R-V2-15: số tiền là số nguyên đồng, lớn hơn 0, không vượt nợ đầu kỳ còn lại.
  begin
    v_amount := (p_data ->> 'amount')::bigint;
  exception when others then
    perform app.raise_error('HMT_SO_TIEN_SAI', 'Nhập số tiền là số nguyên đồng.');
  end;
  if v_amount is null or v_amount <= 0 then
    perform app.raise_error('HMT_SO_TIEN_SAI', 'Số tiền phiếu thu phải lớn hơn 0.');
  end if;
  v_remaining := app.opening_debt_remaining(st.id);
  if v_amount > v_remaining then
    perform app.raise_error('HMT_SO_TIEN_VUOT',
      format('Số tiền vượt nợ đầu kỳ còn lại của học sinh (còn %s đ).', to_char(v_remaining, 'FM999G999G999G999')));
  end if;
  if v_method is null then
    perform app.raise_error('HMT_THIEU_HINH_THUC', 'Chọn hình thức thanh toán.');
  end if;
  perform app.assert_catalog_code_active('PAYMENT_METHOD', v_method);
  v_paid_on := coalesce(nullif(p_data ->> 'paid_on', '')::date, current_date);
  if v_paid_on > current_date then
    perform app.raise_error('HMT_NGAY_THU_SAI', 'Ngày thu không được ở tương lai.');
  end if;
  v_collect := coalesce(nullif(p_data ->> 'collect_branch_id', '')::uuid, app.current_branch_id());
  if not exists (select from app.branch where id = v_collect and is_active and not is_office) then
    perform app.raise_error('HMT_CO_SO_SAI', 'Cơ sở thu tiền phải là cơ sở dạy học đang hoạt động.');
  end if;
  v_receiver := coalesce(nullif(p_data ->> 'receiver_id', '')::uuid, auth.uid());
  if not exists (select from app.user_account where id = v_receiver and student_code is null) then
    perform app.raise_error('HMT_NGUOI_NHAN_SAI', 'Người nhận tiền phải là nhân sự.');
  end if;
  select code into v_branch_code from app.branch where id = st.branch_id;
  v_code := app.issue_document_number('PT', v_branch_code);
  insert into app.receipt (code, order_id, opening_debt_student_id, parent_id, branch_id, collect_branch_id, receiver_id, amount,
                           payment_method_code, txn_ref, paid_on, note)
  values (v_code, null, st.id, st.parent_id, st.branch_id, v_collect, v_receiver, v_amount, v_method,
          nullif(btrim(coalesce(p_data ->> 'txn_ref', '')), ''), v_paid_on, nullif(btrim(coalesce(p_data ->> 'note', '')), ''))
  returning id into v_id;
  perform app.receipt_add_event(v_id, 'TAO', null, 'NHAP', 'Thu nợ đầu kỳ');
  return jsonb_build_object('id', v_id, 'code', v_code, 'remaining_after', v_remaining - v_amount);
end;
$$;

-- 5. app.submit_opening_debt_receipt(phiếu): gửi thẳng Kế toán (Nháp → Chờ kế toán), KHÔNG qua quản lý trực tiếp (R-V2-15). Ai gọi: Phiếu thu · Tạo ở cơ sở; cần cờ.
create or replace function app.submit_opening_debt_receipt(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null or r.opening_debt_student_id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu nợ đầu kỳ.');
  end if;
  perform app.assert_can('RECEIPT', 'TAO', r.branch_id);
  perform app.require_feature('BAN_HANG', r.branch_id);
  if not app.get_setting_bool('opening_debt_receipt_enabled', r.branch_id) then
    perform app.raise_error('HMT_TINH_NANG_TAT', 'Thu nợ đầu kỳ chưa được bật cho cơ sở này.');
  end if;
  if r.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ gửi được phiếu thu Nháp.');
  end if;
  -- Luật R-V2-15: kiểm lại không vượt nợ còn lại (nợ có thể đã đổi từ lúc tạo).
  if r.amount > app.opening_debt_remaining(r.opening_debt_student_id, r.id) then
    perform app.raise_error('HMT_SO_TIEN_VUOT', 'Số tiền vượt nợ đầu kỳ còn lại của học sinh.');
  end if;
  -- approval_route để trống: không có bước quản lý (R-V2-15), không có người duyệt chốt.
  update app.receipt set status_code = 'CHO_KE_TOAN', submitted_at = now(), submitted_by = auth.uid() where id = p_id;
  perform app.receipt_add_event(p_id, 'GUI', 'NHAP', 'CHO_KE_TOAN', 'Thu nợ đầu kỳ: gửi thẳng Kế toán');
end;
$$;

-- 6. app.approve_opening_debt_receipt(phiếu): KẾ TOÁN duyệt. Ai gọi: Kế toán · Duyệt ở cơ sở (Admin không, R-HT-01); cần cờ. Cùng một giao dịch: sinh khoản KTV (không đơn), ghi dòng THU_NO_DAU_KY
-- (số dương) vào sổ số dư để giảm nợ, phiếu sang Đã duyệt. Không chia theo dòng đơn, không cấp giờ.
create or replace function app.approve_opening_debt_receipt(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_code text;
  v_money uuid;
  v_branch_code text;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null or r.opening_debt_student_id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu nợ đầu kỳ.');
  end if;
  perform app.assert_can('ACCOUNTING', 'DUYET', r.branch_id);
  perform app.require_feature('BAN_HANG', r.branch_id);
  if not app.get_setting_bool('opening_debt_receipt_enabled', r.branch_id) then
    perform app.raise_error('HMT_TINH_NANG_TAT', 'Thu nợ đầu kỳ chưa được bật cho cơ sở này.');
  end if;
  if r.status_code <> 'CHO_KE_TOAN' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt được phiếu thu Chờ kế toán.');
  end if;
  -- Luật R-V2-15: không vượt nợ còn lại tại lúc duyệt.
  if r.amount > app.opening_debt_remaining(r.opening_debt_student_id, r.id) then
    perform app.raise_error('HMT_SO_TIEN_VUOT', 'Số tiền vượt nợ đầu kỳ còn lại của học sinh.');
  end if;
  select code into v_branch_code from app.branch where id = r.branch_id;
  v_code := app.issue_document_number('KTV', v_branch_code);
  insert into app.money_in (code, receipt_id, order_id, opening_debt_student_id, parent_id, branch_id, amount)
  values (v_code, r.id, null, r.opening_debt_student_id, r.parent_id, r.branch_id, r.amount)
  returning id into v_money;
  insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref)
  values (r.parent_id, r.opening_debt_student_id, r.branch_id, 'THU_NO_DAU_KY', r.amount, current_date, v_code);
  update app.receipt set status_code = 'DA_DUYET', accountant_approved_at = now(), accountant_approved_by = auth.uid() where id = p_id;
  perform app.receipt_add_event(p_id, 'DUYET_KT', 'CHO_KE_TOAN', 'DA_DUYET', 'Thu nợ đầu kỳ');
  return jsonb_build_object('id', p_id, 'money_in_id', v_money, 'money_in_code', v_code,
                            'remaining', app.opening_debt_remaining(r.opening_debt_student_id));
end;
$$;

revoke execute on function app.opening_debt_remaining(uuid, uuid), app.create_opening_debt_receipt(uuid, jsonb),
  app.submit_opening_debt_receipt(uuid), app.approve_opening_debt_receipt(uuid) from public, anon;
grant execute on function app.opening_debt_remaining(uuid, uuid), app.create_opening_debt_receipt(uuid, jsonb),
  app.submit_opening_debt_receipt(uuid), app.approve_opening_debt_receipt(uuid) to authenticated;

-- 7. TC-09: hoàn tác khoản tiền vào xử lý khoản nợ đầu kỳ (thân bản migration 180, chỉ thêm nhánh không đơn).
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
  v_opening uuid;
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
  v_opening := m.opening_debt_student_id;
  if m.order_id is not null then
    perform 1 from app.sales_order where id = m.order_id for update;
  end if;
  select code into v_branch_code from app.branch where id = m.branch_id;
  v_code := app.issue_document_number('KTV', v_branch_code);
  insert into app.money_in (code, receipt_id, order_id, opening_debt_student_id, parent_id, branch_id, amount, reversal_of, reason_code, reason_note)
  values (v_code, null, m.order_id, m.opening_debt_student_id, m.parent_id, m.branch_id, -m.amount, m.id, p_reason_code, nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_new;
  -- Phần chia về dòng đơn: đảo đúng từng phần của khoản gốc (tổng allocation âm = -amount).
  insert into app.money_in_allocation (money_in_id, order_line_id, branch_id, amount)
  select v_new, a.order_line_id, a.branch_id, -a.amount from app.money_in_allocation a where a.money_in_id = m.id;
  -- Luật R-TIEN-26: giờ đã cấp tính lại theo tiền còn lại (sổ giờ thêm dòng âm).
  if v_opening is not null then
    -- Luật R-V2-15, R-TIEN-26: hoàn tác khoản thu nợ đầu kỳ thì nợ đầu kỳ của học sinh được cộng lại (khoản âm trong sổ số dư), không có giờ để tính lại.
    insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref)
    values (m.parent_id, v_opening, m.branch_id, 'DAO_THU_NO_DAU_KY', -m.amount, current_date, v_code);
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

-- 8. TC-08: sổ khoản tiền vào nối trái đơn (khoản thu nợ đầu kỳ không có đơn; order_code rỗng). Thân bản migration 180, chỉ đổi join đơn thành nối trái.
create or replace function app.list_money_in(p_filters jsonb default '{}'::jsonb, p_sort text default 'date_desc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ACCOUNTING', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_kind text := nullif(p_filters ->> 'kind', '');
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem sổ khoản tiền vào.');
  end if;
  with f as not materialized (
    select m.*, r.code as receipt_code, r.search_text, orig.code as reversal_of_code,
           exists (select from app.money_in x where x.reversal_of = m.id) as is_reversed
      from app.money_in m
      left join app.receipt r on r.id = m.receipt_id
      left join app.money_in orig on orig.id = m.reversal_of
      left join app.receipt ro on ro.id = orig.receipt_id
     where (v_scope = 'TOAN_HE_THONG' or m.branch_id = v_my_branch)
       and (v_branch is null or m.branch_id = v_branch)
       and (v_from is null or m.created_at >= v_from)
       and (v_to is null or m.created_at < v_to)
       and (v_kind is null or (v_kind = 'THU' and m.amount > 0) or (v_kind = 'DAO' and m.amount < 0))
       and (v_q is null or coalesce(r.search_text, ro.search_text) like '%' || v_q || '%' or app.fold_text(m.code) like '%' || v_q || '%' or app.fold_text(orig.code) like '%' || v_q || '%')
  ),
  page as (
    select * from f
     order by case when p_sort = 'date_asc' then f.created_at end asc,
              case when p_sort = 'amount_desc' then f.amount end desc,
              case when p_sort = 'amount_asc' then f.amount end asc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'sum', (select coalesce(sum(amount), 0) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'receipt_id', p.receipt_id, 'receipt_code', p.receipt_code,
             'order_id', p.order_id, 'order_code', o.code, 'parent_id', p.parent_id, 'parent_name', par.full_name,
             'amount', p.amount, 'created_at', p.created_at, 'branch_code', b.code,
             'reversal_of_code', p.reversal_of_code, 'is_reversed', p.is_reversed, 'reason_code', p.reason_code)
             order by case when p_sort = 'date_asc' then p.created_at end asc,
                      case when p_sort = 'amount_desc' then p.amount end desc,
                      case when p_sort = 'amount_asc' then p.amount end asc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent par on par.id = p.parent_id
    left join app.sales_order o on o.id = p.order_id;
  return v_result;
end;
$$;

revoke execute on function app.reverse_money_in(uuid, text, text), app.list_money_in(jsonb, text, integer, integer) from public, anon;
grant execute on function app.reverse_money_in(uuid, text, text), app.list_money_in(jsonb, text, integer, integer) to authenticated;
