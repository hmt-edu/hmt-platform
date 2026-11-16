-- TC-09 Hoàn tác (đảo) khoản tiền vào (Code C, 16/11/2026). Luật: R-TIEN-26 (đảo một khoản: giữ khoản gốc, thêm khoản âm trỏ về khoản gốc, cùng dãy mã KTV, chặn đảo hai lần,
-- bắt buộc lý do từ danh mục REVERSAL_REASON; giờ đã cấp tính lại theo tiền còn lại), R-HT-01 (Admin không duyệt tiền: chỉ người có Kế toán · Duyệt, tức Kế toán), R-HT-04 (lý do "Khác" bắt buộc ghi chú),
-- R-GD-12 (giờ có thể âm sau khi tính lại; hàm trả cảnh báo, không chặn).
-- Việc chạm tiền: hàm kiểm cờ tham số money_reversal_enabled (mặc định TẮT, bật theo cơ sở) nên gộp vào main không đổi hành vi bản chạy thật cho tới khi Chat bật.

-- 1. Khoản tiền vào: thêm cột đảo; khoản âm không có phiếu thu, bắt buộc trỏ về khoản gốc.
alter table app.money_in alter column receipt_id drop not null;
alter table app.money_in
  add column reversal_of uuid references app.money_in (id),
  add column reason_catalog text not null default 'REVERSAL_REASON' check (reason_catalog = 'REVERSAL_REASON'),
  add column reason_code text,
  add column reason_note text;
alter table app.money_in
  add constraint money_in_reason_fk foreign key (reason_catalog, reason_code) references app.catalog_item (catalog_code, code),
  -- Khoản dương: có phiếu thu, không phải khoản đảo. Khoản âm: không phiếu thu, trỏ về khoản gốc, có lý do.
  add constraint money_in_sign_check check (
    (amount > 0 and receipt_id is not null and reversal_of is null and reason_code is null)
    or (amount < 0 and receipt_id is null and reversal_of is not null and reason_code is not null));
-- Chặn đảo hai lần (R-TIEN-26): mỗi khoản gốc có tối đa một khoản đảo. Chỉ mục này cũng phục vụ tìm "khoản này đã bị đảo chưa".
create unique index money_in_reversal_of_uq on app.money_in (reversal_of) where reversal_of is not null;

-- 2. Phần chia về dòng đơn: cho phép âm (phần đảo), không cho bằng 0.
alter table app.money_in_allocation drop constraint money_in_allocation_amount_check;
alter table app.money_in_allocation add constraint money_in_allocation_amount_check check (amount <> 0);

-- 3. Cờ tham số: mặc định TẮT; Admin hoặc Chat bật theo cơ sở sau khi Tester đạt.
select set_config('hmt.migration', 'on', false);
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('money_reversal_enabled', 'Cho phép hoàn tác khoản tiền vào (TC-09)', 'BOOL', null, null, null, 'false', true, 'BAN_HANG', 'R-TIEN-26',
   'Tắt: không ai hoàn tác (đảo) được khoản tiền vào của cơ sở. Bật: Kế toán hoàn tác được từng khoản, có lý do; giờ đã cấp tính lại theo tiền còn lại.');

-- 4. app.reverse_money_in(khoản, mã lý do, ghi chú): Kế toán hoàn tác một khoản tiền vào.
-- Ai gọi: người có Kế toán · Duyệt trong cơ sở của khoản (Kế toán; Admin không, R-HT-01). Đầu vào: id khoản gốc, mã lý do (REVERSAL_REASON), ghi chú (bắt buộc khi lý do Khác).
-- Kết quả: {id, code (khoản đảo mới), reversed_code, amount, enrollments_negative (số ghi danh có giờ còn lại âm sau khi tính lại)}.
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
  perform 1 from app.sales_order where id = m.order_id for update;
  select code into v_branch_code from app.branch where id = m.branch_id;
  v_code := app.issue_document_number('KTV', v_branch_code);
  insert into app.money_in (code, receipt_id, order_id, parent_id, branch_id, amount, reversal_of, reason_code, reason_note)
  values (v_code, null, m.order_id, m.parent_id, m.branch_id, -m.amount, m.id, p_reason_code, nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_new;
  -- Phần chia về dòng đơn: đảo đúng từng phần của khoản gốc (tổng allocation âm = -amount).
  insert into app.money_in_allocation (money_in_id, order_line_id, branch_id, amount)
  select v_new, a.order_line_id, a.branch_id, -a.amount from app.money_in_allocation a where a.money_in_id = m.id;
  -- Luật R-TIEN-26: giờ đã cấp tính lại theo tiền còn lại (sổ giờ thêm dòng âm).
  perform app.sync_enrollment_hours(m.order_id);
  -- Luật R-GD-12: giờ âm cho phép; báo số ghi danh của đơn đang âm để Kế toán biết.
  select count(*) into v_neg from app.enrollment e
   where e.order_id = m.order_id
     and (select coalesce(sum(h.hours), 0) from app.hour_ledger h where h.enrollment_id = e.id) < 0;
  return jsonb_build_object('id', v_new, 'code', v_code, 'reversed_code', m.code, 'amount', -m.amount, 'enrollments_negative', v_neg);
end;
$$;
revoke execute on function app.reverse_money_in(uuid, text, text) from public, anon;
grant execute on function app.reverse_money_in(uuid, text, text) to authenticated;

-- 5. Sổ TC-08: khoản đảo không có phiếu thu nên nối trái; tìm kiếm dùng chữ tìm của phiếu thu khoản gốc; thêm mã khoản gốc, cờ đã bị đảo, mã lý do.
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
    join app.sales_order o on o.id = p.order_id;
  return v_result;
end;
$$;
revoke execute on function app.list_money_in(jsonb, text, integer, integer) from public, anon;
grant execute on function app.list_money_in(jsonb, text, integer, integer) to authenticated;
