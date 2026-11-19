-- Migration 478 (Code D, 19/11/2026): TC-15 Đối soát thu tiền (canvas 9933, 4 khung TC15*). Anh Trường chốt 20:46: danh mục «Tài khoản nhận» MỚI (Quản trị sửa),
-- cờ «đã khớp sao kê» trên phiếu thu; chỉ Kế toán và Admin đánh dấu. CAO (tiền).
-- (1) Danh mục RECEIVING_ACCOUNT «Tài khoản nhận tiền» (mở, Admin thêm/đổi tên/Ngừng ở QT-07): code, name, sort_order, is_active như mọi danh mục. Không có mục mẫu: Admin nhập tài khoản thật.
-- (2) app.receipt thêm receiving_account_code (tuỳ chọn), bank_matched_at, bank_matched_by. Lịch sử thay đổi do trigger audit chuẩn của bảng ghi lại.
-- (3) app.list_receipt_reconciliation: danh sách phiếu thu Đã duyệt kèm tổng; (4) app.mark_receipts_bank_matched: đánh dấu hoặc bỏ đánh dấu khớp, kèm gán tài khoản nhận.
-- Luật quyền (cả hai hàm): Xem Kế toán phạm vi toàn hệ thống VÀ Sửa phiếu thu phạm vi toàn hệ thống = Kế toán và Admin (R-HT-01 không đụng tới: không có Duyệt tiền ở đây).
-- Chỉ mục: receipt_reconcile_idx (paid_on desc, id) chỉ cho phiếu Đã duyệt, phục vụ lọc theo ngày và sắp xếp của màn này.
select set_config('hmt.migration', 'on', false);
insert into app.catalog (code, name, kind, parent_catalog, linked_catalog, description, sort_order)
values ('RECEIVING_ACCOUNT', 'Tài khoản nhận tiền', 'MO', null, null, 'Tài khoản ngân hàng, POS nhận tiền thu (TC-15 Đối soát thu tiền). Admin thêm, đổi tên, Ngừng; mã không đổi.', 39);
select set_config('hmt.migration', '', false);

alter table app.receipt add column receiving_account_catalog text not null default 'RECEIVING_ACCOUNT' check (receiving_account_catalog = 'RECEIVING_ACCOUNT');
alter table app.receipt add column receiving_account_code text;
alter table app.receipt add column bank_matched_at timestamptz;
alter table app.receipt add column bank_matched_by uuid;
alter table app.receipt add constraint receipt_receiving_account_fk
  foreign key (receiving_account_catalog, receiving_account_code) references app.catalog_item (catalog_code, code);
alter table app.receipt add constraint receipt_bank_matched_pair check ((bank_matched_at is null) = (bank_matched_by is null));
comment on column app.receipt.receiving_account_code is 'Tài khoản nhận tiền (danh mục RECEIVING_ACCOUNT), Kế toán ghi khi đối soát (TC-15). Tuỳ chọn.';
comment on column app.receipt.bank_matched_at is 'Thời điểm Kế toán, Admin đánh dấu «đã khớp sao kê» (TC-15); null = chưa khớp.';
create index receipt_reconcile_idx on app.receipt (paid_on desc, id) where status_code = 'DA_DUYET';
create index receipt_receiving_account_idx on app.receipt (receiving_account_code) where receiving_account_code is not null;

-- app.assert_reconcile_access(): chỉ Kế toán, Admin (phạm vi toàn hệ thống ở cả Xem Kế toán và Sửa phiếu thu).
create or replace function app.assert_reconcile_access()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if app.permission_scope('ACCOUNTING', 'XEM') is distinct from 'TOAN_HE_THONG'
     or app.permission_scope('RECEIPT', 'SUA') is distinct from 'TOAN_HE_THONG' then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Đối soát thu tiền dành cho Kế toán và Admin.');
  end if;
end;
$$;
revoke execute on function app.assert_reconcile_access() from public, anon, authenticated;

-- app.list_receipt_reconciliation(bộ lọc, sắp xếp, số dòng, bỏ qua): TC-15. Chỉ đọc. Ai gọi: Kế toán, Admin.
-- Bộ lọc (jsonb): from, to (ngày thu, to tính cả ngày), branch_id (cơ sở thu), account (mã tài khoản nhận, «NONE» = chưa ghi), method (hình thức), q (mã giao dịch, mã phiếu),
-- matched ('KHOP' | 'CHUA'). Sắp xếp: date_desc (mặc định), date_asc, amount_desc. Kết quả {total, sum_all, sum_matched, sum_unmatched, count_unmatched, rows[]}; các tổng tính trên cả bộ lọc.
create or replace function app.list_receipt_reconciliation(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'date_desc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_from date := nullif(p_filters ->> 'from', '')::date;
  v_to date := nullif(p_filters ->> 'to', '')::date;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_account text := nullif(p_filters ->> 'account', '');
  v_method text := nullif(p_filters ->> 'method', '');
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_matched text := nullif(p_filters ->> 'matched', '');
  v_result jsonb;
begin
  perform app.assert_reconcile_access();
  with f as not materialized (
    select r.id, r.code, r.paid_on, r.amount, r.txn_ref, r.payment_method_code, r.receiving_account_code, r.bank_matched_at,
           r.collect_branch_id, r.receiver_id, r.parent_id
      from app.receipt r
     where r.status_code = 'DA_DUYET'
       and (v_from is null or r.paid_on >= v_from)
       and (v_to is null or r.paid_on <= v_to)
       and (v_branch is null or r.collect_branch_id = v_branch)
       and (v_account is null or (v_account = 'NONE' and r.receiving_account_code is null) or r.receiving_account_code = v_account)
       and (v_method is null or r.payment_method_code = v_method)
       and (v_q is null or app.fold_text(coalesce(r.txn_ref, '') || ' ' || r.code) like '%' || v_q || '%')
       and (v_matched is null or (v_matched = 'KHOP' and r.bank_matched_at is not null) or (v_matched = 'CHUA' and r.bank_matched_at is null))
  ),
  page as (
    select * from f
     order by case when p_sort = 'date_asc' then f.paid_on end asc,
              case when p_sort = 'amount_desc' then f.amount end desc,
              f.paid_on desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'sum_all', (select coalesce(sum(amount), 0) from f),
           'sum_matched', (select coalesce(sum(amount) filter (where bank_matched_at is not null), 0) from f),
           'sum_unmatched', (select coalesce(sum(amount) filter (where bank_matched_at is null), 0) from f),
           'count_unmatched', (select count(*) filter (where bank_matched_at is null) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'paid_on', p.paid_on, 'amount', p.amount, 'txn_ref', p.txn_ref,
             'payment_method_code', p.payment_method_code, 'receiving_account_code', p.receiving_account_code,
             'matched', p.bank_matched_at is not null, 'bank_matched_at', p.bank_matched_at,
             'collect_branch_code', (select b.code from app.branch b where b.id = p.collect_branch_id),
             'receiver_name', app.staff_display_name(p.receiver_id),
             'parent_name', (select pa.full_name from app.parent pa where pa.id = p.parent_id))
             order by case when p_sort = 'date_asc' then p.paid_on end asc,
                      case when p_sort = 'amount_desc' then p.amount end desc,
                      p.paid_on desc, p.id), '[]'::jsonb))
    into v_result
    from page p;
  return v_result;
end;
$$;

-- app.mark_receipts_bank_matched(danh sách phiếu, đã khớp, tài khoản nhận): đánh dấu hoặc bỏ đánh dấu «đã khớp sao kê» và (tuỳ chọn) ghi tài khoản nhận cho các phiếu chọn.
-- Ai gọi: Kế toán, Admin. Một giao dịch; lỗi thì không phiếu nào đổi. Luật: chỉ phiếu Đã duyệt; số phiếu một lần không quá số dòng tối đa của trang (tham số); tài khoản nhận phải là
-- mục đang dùng của danh mục. Kết quả: số phiếu đã đổi. Lịch sử thay đổi do trigger audit ghi.
create or replace function app.mark_receipts_bank_matched(p_ids uuid[], p_matched boolean default true, p_account text default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  perform app.assert_reconcile_access();
  if p_ids is null or cardinality(p_ids) = 0 then
    perform app.raise_error('HMT_DOI_SOAT_CHUA_CHON', 'Chọn ít nhất một phiếu thu.');
  end if;
  if cardinality(p_ids) > app.get_setting_int('list_page_size_max') then
    perform app.raise_error('HMT_DOI_SOAT_QUA_NHIEU', 'Chọn quá nhiều phiếu một lần. Chia làm nhiều lượt.');
  end if;
  if p_account is not null and not exists (select from app.catalog_item ci where ci.catalog_code = 'RECEIVING_ACCOUNT' and ci.code = p_account and ci.is_active) then
    perform app.raise_error('HMT_TAI_KHOAN_NHAN_KHONG_CO', 'Tài khoản nhận không có hoặc đã ngừng dùng.');
  end if;
  -- Luật: chỉ phiếu thu Đã duyệt mới đối soát.
  if exists (select from unnest(p_ids) i left join app.receipt r on r.id = i where r.id is null or r.status_code <> 'DA_DUYET') then
    perform app.raise_error('HMT_DOI_SOAT_PHIEU_CHUA_DUYET', 'Chỉ đối soát phiếu thu Đã duyệt.');
  end if;
  update app.receipt r set
    bank_matched_at = case when p_matched then now() else null end,
    bank_matched_by = case when p_matched then auth.uid() else null end,
    receiving_account_code = coalesce(p_account, r.receiving_account_code)
   where r.id = any (p_ids);
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;
revoke execute on function app.list_receipt_reconciliation(jsonb, text, integer, integer), app.mark_receipts_bank_matched(uuid[], boolean, text) from public, anon;
grant execute on function app.list_receipt_reconciliation(jsonb, text, integer, integer), app.mark_receipts_bank_matched(uuid[], boolean, text) to authenticated;
