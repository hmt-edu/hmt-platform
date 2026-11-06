-- B2 (anh chốt 05/11, đường găng trước 12/11): Phiếu thu tối thiểu. Luật: R-TIEN-01, 02, 04, 06, 22, 23, 26 (khoản đảo làm sau), R-V2-14;
-- anh chốt Đ258 (Hình thức thanh toán, Cơ sở thu tiền, Người nhận tiền ở PHIẾU THU, không ở đơn hàng).
-- Làm gì: bảng phiếu thu, lịch sử phiếu thu, khoản tiền vào (KTV, sinh khi kế toán duyệt), chia tiền về dòng đơn; hàm tạo, sửa, gửi, quản lý duyệt,
-- từ chối, huỷ, kế toán duyệt; quyền; RLS; chỉ mục. Phiếu thu chỉ tạo từ đơn Đã duyệt (R-TIEN-02). Chưa có: cấp giờ theo tiền đã thu và ghi danh
-- khi đủ cọc (cần Đào tạo), đảo khoản, sổ thu tiền, Thu nợ đầu kỳ (làm sau 12/11).
-- Chỉ mục: mỗi chỉ mục ghi lý do ngay bên dưới câu tạo.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- 1. Danh mục: trạng thái phiếu thu (R-V2-14), lý do huỷ phiếu thu, loại chứng từ KTV (khoản tiền vào, R-TIEN-26 dùng chung dãy KTV).
-- ---------------------------------------------------------------------------
insert into app.catalog (code, name, kind, description, sort_order)
select v.code, v.name, v.kind, v.description, (select coalesce(max(sort_order), 0) from app.catalog) + v.n
  from (values
    ('RECEIPT_STATUS', 'Trạng thái phiếu thu', 'HE_THONG', 'Nháp, Đã gửi, Chờ kế toán, Đã duyệt; Huỷ (R-V2-14).', 1),
    ('RECEIPT_CANCEL_REASON', 'Lý do huỷ phiếu thu', 'MO', 'Bắt buộc chọn khi huỷ phiếu thu chưa duyệt.', 2)
  ) v (code, name, kind, description, n);

insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note)
values
  ('RECEIPT_STATUS', 'NHAP', 'Nháp', 1, false),
  ('RECEIPT_STATUS', 'DA_GUI', 'Đã gửi', 2, false),
  ('RECEIPT_STATUS', 'CHO_KE_TOAN', 'Chờ kế toán', 3, false),
  ('RECEIPT_STATUS', 'DA_DUYET', 'Đã duyệt', 4, false),
  ('RECEIPT_STATUS', 'HUY', 'Huỷ', 5, false),
  ('RECEIPT_CANCEL_REASON', 'SAI_SO_TIEN', 'Sai số tiền', 1, false),
  ('RECEIPT_CANCEL_REASON', 'KHACH_DOI_Y', 'Khách đổi ý', 2, false),
  ('RECEIPT_CANCEL_REASON', 'TRUNG_PHIEU', 'Trùng phiếu', 3, false),
  ('RECEIPT_CANCEL_REASON', 'KHAC', 'Khác', 4, true),
  ('DOC_TYPE', 'KTV', 'Khoản tiền vào', 7, false);

-- ---------------------------------------------------------------------------
-- 2. Quyền: Trưởng cơ sở có quyền Duyệt phiếu thu ở cơ sở mình (bước quản lý, R-TIEN-01). Kế toán đã có Duyệt (RECEIPT, ACCOUNTING); Admin không duyệt (R-HT-01).
-- ---------------------------------------------------------------------------
select app.save_permission_matrix(
  app.permission_current_version(),
  (select jsonb_agg(jsonb_build_object('role', v.role, 'module', v.module, 'action', v.action, 'scope', v.scope))
     from (values ('BRANCH_MANAGER', 'RECEIPT', 'DUYET', 'CO_SO')) as v (role, module, action, scope)),
  'B2, R-TIEN-01: Trưởng cơ sở có quyền Duyệt phiếu thu (bước quản lý) ở cơ sở mình');

-- ---------------------------------------------------------------------------
-- 3. Bảng phiếu thu
-- ---------------------------------------------------------------------------
create table app.receipt (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  order_id uuid not null references app.sales_order (id),
  parent_id uuid not null references app.parent (id),
  -- Cơ sở của đơn (dùng cho quyền xem); Cơ sở thu tiền chọn riêng ở phiếu (Đ258), mặc định cơ sở người lập.
  branch_id uuid not null references app.branch (id),
  collect_branch_id uuid not null references app.branch (id),
  receiver_id uuid references app.user_account (id),
  status_catalog text not null default 'RECEIPT_STATUS' check (status_catalog = 'RECEIPT_STATUS'),
  status_code text not null default 'NHAP',
  amount bigint not null check (amount > 0),
  payment_method_catalog text not null default 'PAYMENT_METHOD' check (payment_method_catalog = 'PAYMENT_METHOD'),
  payment_method_code text not null,
  txn_ref text,
  paid_on date not null default current_date,
  -- "Cấn vào dòng" (R-TIEN-23): để trống = chia tỉ lệ; khoá khi phiếu rời Nháp.
  target_line_id uuid references app.sales_order_line (id),
  note text,
  approval_route text check (approval_route in ('QUAN_LY', 'TU_DUYET')),
  assigned_approver_id uuid references app.user_account (id),
  submitted_at timestamptz,
  submitted_by uuid,
  manager_approved_at timestamptz,
  manager_approved_by uuid,
  accountant_approved_at timestamptz,
  accountant_approved_by uuid,
  cancel_reason_catalog text not null default 'RECEIPT_CANCEL_REASON' check (cancel_reason_catalog = 'RECEIPT_CANCEL_REASON'),
  cancel_reason_code text,
  cancel_note text,
  cancelled_at timestamptz,
  cancelled_by uuid,
  legacy_ref text,
  search_text text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (status_catalog, status_code) references app.catalog_item (catalog_code, code),
  foreign key (payment_method_catalog, payment_method_code) references app.catalog_item (catalog_code, code),
  foreign key (cancel_reason_catalog, cancel_reason_code) references app.catalog_item (catalog_code, code)
);
comment on table app.receipt is 'Phiếu thu (R-TIEN-01): Nháp, Đã gửi, Chờ kế toán, Đã duyệt; Huỷ. Chỉ tạo từ đơn Đã duyệt (R-TIEN-02). Ghi chỉ qua hàm nghiệp vụ.';

-- Chỉ mục (lý do): các phiếu của một đơn (khoá ngoại, tính còn lại của đơn); phụ huynh (khoá ngoại, công nợ theo phụ huynh sau này).
create index receipt_order_idx on app.receipt (order_id, status_code);
create index receipt_parent_idx on app.receipt (parent_id);
-- Danh sách theo cơ sở và trạng thái (cột lọc, RLS); hàng chờ kế toán.
create index receipt_branch_status_idx on app.receipt (branch_id, status_code, created_at desc);
create index receipt_collect_branch_idx on app.receipt (collect_branch_id);
-- Hàng chờ kế toán (TC-04) xem MỌI cơ sở: chỉ mục riêng cho phiếu Chờ kế toán, đã xếp mới nhất trước (EXPLAIN 20.000 phiếu: trước đó quét cả bảng).
create index receipt_waiting_accounting_idx on app.receipt (created_at desc, id) where status_code = 'CHO_KE_TOAN';
-- Hàng chờ "việc của tôi duyệt" ở bước quản lý.
create index receipt_approver_idx on app.receipt (assigned_approver_id) where status_code = 'DA_GUI';
create index receipt_target_line_idx on app.receipt (target_line_id) where target_line_id is not null;
create index receipt_receiver_idx on app.receipt (receiver_id) where receiver_id is not null;
-- Tìm theo mã phiếu, mã đơn, mã và tên phụ huynh, SĐT (ô tìm của TC-01): cột search_text đã gấp dấu, chỉ mục trigram để LIKE '%…%' không quét cả bảng.
create index receipt_search_idx on app.receipt using gin (search_text gin_trgm_ops);

select app.apply_standard('app.receipt');

-- Chữ để tìm của phiếu thu: mã phiếu, mã đơn, mã cũ, mã và tên phụ huynh, SĐT; đã gấp dấu, chữ thường.
create or replace function app.receipt_search_text(p_receipt app.receipt)
returns text
language sql
stable
set search_path = ''
as $$
  select app.fold_text(p_receipt.code || ' ' || coalesce((select o.code from app.sales_order o where o.id = p_receipt.order_id), '')
                       || ' ' || coalesce((select pa.code || ' ' || pa.full_name || ' ' || pa.phone from app.parent pa where pa.id = p_receipt.parent_id), '')
                       || ' ' || coalesce(p_receipt.legacy_ref, '') || ' ' || coalesce(p_receipt.txn_ref, ''));
$$;
create or replace function app.tg_receipt_search_text()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.search_text := app.receipt_search_text(new);
  return new;
end;
$$;
create trigger receipt_search_text before insert or update of txn_ref, legacy_ref on app.receipt
  for each row execute function app.tg_receipt_search_text();
-- Phụ huynh đổi tên hoặc SĐT thì chữ để tìm của các phiếu thu tính lại (như đơn hàng).
create or replace function app.tg_parent_refresh_receipt_search()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.full_name is distinct from old.full_name or new.phone is distinct from old.phone then
    update app.receipt r set search_text = app.receipt_search_text(r) where r.parent_id = new.id;
  end if;
  return null;
end;
$$;
create trigger parent_refresh_receipt_search after update on app.parent
  for each row execute function app.tg_parent_refresh_receipt_search();

-- Lịch sử phiếu thu (chỉ thêm).
create table app.receipt_event (
  id uuid primary key default gen_random_uuid(),
  seq bigint generated always as identity,
  receipt_id uuid not null references app.receipt (id),
  branch_id uuid not null references app.branch (id),
  event_code text not null check (event_code in ('TAO', 'SUA', 'GUI', 'DUYET_QL', 'TU_DUYET_QL', 'DUYET_KT', 'TU_CHOI', 'HUY')),
  from_status text,
  to_status text not null,
  note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.receipt_event is 'Lịch sử phiếu thu: tạo, sửa, gửi, duyệt, từ chối (kèm lý do), huỷ. Chỉ thêm.';
-- Chỉ mục (lý do): lịch sử một phiếu theo thứ tự ghi; cơ sở cho RLS.
create index receipt_event_receipt_idx on app.receipt_event (receipt_id, seq);
create index receipt_event_branch_idx on app.receipt_event (branch_id);
select app.apply_standard('app.receipt_event');

-- Khoản tiền vào (R-TIEN-01): hệ thống sinh khi kế toán duyệt, không ai tạo tay; chỉ thêm (đảo khoản làm sau, R-TIEN-26).
create table app.money_in (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  receipt_id uuid not null unique references app.receipt (id),
  order_id uuid not null references app.sales_order (id),
  parent_id uuid not null references app.parent (id),
  branch_id uuid not null references app.branch (id),
  amount bigint not null check (amount <> 0),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.money_in is 'Khoản tiền vào (KTV): sinh khi kế toán duyệt phiếu thu; chỉ thêm, không sửa, không xoá.';
-- Chỉ mục (lý do): tiền đã vào của một đơn (tính còn lại); theo phụ huynh; cơ sở cho RLS.
create index money_in_order_idx on app.money_in (order_id);
create index money_in_parent_idx on app.money_in (parent_id);
create index money_in_branch_idx on app.money_in (branch_id, created_at desc);
select app.apply_standard('app.money_in');

-- Tiền của một khoản vào chia về từng dòng của đơn (R-TIEN-21, 22, 23).
create table app.money_in_allocation (
  id uuid primary key default gen_random_uuid(),
  money_in_id uuid not null references app.money_in (id),
  order_line_id uuid not null references app.sales_order_line (id),
  branch_id uuid not null references app.branch (id),
  amount bigint not null check (amount >= 0),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (money_in_id, order_line_id)
);
comment on table app.money_in_allocation is 'Phần tiền của khoản tiền vào chia về từng dòng đơn theo tỉ lệ thành tiền, có thể cấn vào một dòng (R-TIEN-22, 23).';
-- Chỉ mục (lý do): tiền đã chia cho một dòng (tính phần còn nhận được ở lần chia sau, giờ cấp theo tiền đã thu); cơ sở cho RLS.
create index money_in_allocation_line_idx on app.money_in_allocation (order_line_id);
create index money_in_allocation_branch_idx on app.money_in_allocation (branch_id);
select app.apply_standard('app.money_in_allocation');

-- Chỉ thêm: không ai sửa, xoá lịch sử phiếu thu, khoản tiền vào và phần chia (kể cả hàm nghiệp vụ).
create or replace function app.tg_receipt_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not app.is_migration() then
    perform app.raise_error('HMT_CHI_THEM', 'Lịch sử phiếu thu, khoản tiền vào chỉ thêm, không sửa hay xoá.');
  end if;
  return coalesce(new, old);
end;
$$;
create trigger receipt_event_append_only before update or delete on app.receipt_event
  for each row execute function app.tg_receipt_append_only();
create trigger money_in_append_only before update or delete on app.money_in
  for each row execute function app.tg_receipt_append_only();
create trigger money_in_allocation_append_only before update or delete on app.money_in_allocation
  for each row execute function app.tg_receipt_append_only();

-- Chuyển trạng thái phiếu thu chỉ theo bảng cho phép (R-TIEN-06, R-V2-14). Hàm nghiệp vụ kiểm lần nữa với câu tiếng Việt.
create or replace function app.tg_receipt_status_flow()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_OP = 'UPDATE' and new.status_code is distinct from old.status_code and not app.is_migration() then
    if not (old.status_code = 'NHAP' and new.status_code in ('DA_GUI', 'CHO_KE_TOAN', 'HUY')
            or old.status_code = 'DA_GUI' and new.status_code in ('CHO_KE_TOAN', 'NHAP', 'HUY')
            or old.status_code = 'CHO_KE_TOAN' and new.status_code in ('DA_DUYET', 'NHAP', 'HUY')) then
      perform app.raise_error('HMT_SAI_TRANG_THAI', 'Phiếu thu không chuyển được từ trạng thái này sang trạng thái kia.');
    end if;
  end if;
  return new;
end;
$$;
create trigger receipt_status_flow before update on app.receipt
  for each row execute function app.tg_receipt_status_flow();

-- Phiếu đã rời Nháp thì số tiền, đơn, dòng cấn, hình thức không đổi (R-TIEN-23: khoá lựa chọn khi phiếu rời nháp).
create or replace function app.tg_receipt_lock()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_OP = 'UPDATE' and old.status_code <> 'NHAP' and old.status_code = new.status_code and not app.is_migration() then
    if new.amount is distinct from old.amount or new.order_id is distinct from old.order_id
       or new.target_line_id is distinct from old.target_line_id or new.payment_method_code is distinct from old.payment_method_code then
      perform app.raise_error('HMT_PHIEU_THU_DA_KHOA', 'Phiếu thu đã gửi không sửa được số tiền, dòng cấn, hình thức thanh toán.');
    end if;
  end if;
  return new;
end;
$$;
create trigger receipt_lock before update on app.receipt
  for each row execute function app.tg_receipt_lock();

-- ---------------------------------------------------------------------------
-- 4. RLS: đọc theo quyền Xem phiếu thu (phạm vi cơ sở của đơn hoặc toàn hệ thống); ghi chỉ qua hàm nghiệp vụ.
-- ---------------------------------------------------------------------------
alter table app.receipt enable row level security;
alter table app.receipt_event enable row level security;
alter table app.money_in enable row level security;
alter table app.money_in_allocation enable row level security;
revoke all on app.receipt, app.receipt_event, app.money_in, app.money_in_allocation from public, anon, authenticated;
grant select on app.receipt, app.receipt_event, app.money_in, app.money_in_allocation to authenticated;
create policy receipt_read on app.receipt for select to authenticated
  using ((select app.permission_scope('RECEIPT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('RECEIPT', 'XEM')) is not null and branch_id = (select app.current_branch_id())));
create policy receipt_event_read on app.receipt_event for select to authenticated
  using ((select app.permission_scope('RECEIPT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('RECEIPT', 'XEM')) is not null and branch_id = (select app.current_branch_id())));
create policy money_in_read on app.money_in for select to authenticated
  using ((select app.permission_scope('RECEIPT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('RECEIPT', 'XEM')) is not null and branch_id = (select app.current_branch_id())));
create policy money_in_allocation_read on app.money_in_allocation for select to authenticated
  using ((select app.permission_scope('RECEIPT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('RECEIPT', 'XEM')) is not null and branch_id = (select app.current_branch_id())));

-- ---------------------------------------------------------------------------
-- 5. Hàm trợ giúp
-- ---------------------------------------------------------------------------
-- Tiền đã vào của một đơn (tổng khoản tiền vào).
create or replace function app.order_paid_amount(p_order_id uuid)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(amount), 0)::bigint from app.money_in where order_id = p_order_id;
$$;

-- Tiền còn có thể thu của một đơn = tổng đơn − tiền đã vào − tiền các phiếu đang chờ duyệt (Đã gửi, Chờ kế toán), trừ phiếu p_except.
create or replace function app.order_receivable(p_order_id uuid, p_except uuid default null)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select o.total_amount - app.order_paid_amount(o.id)
         - coalesce((select sum(r.amount) from app.receipt r
                      where r.order_id = o.id and r.status_code in ('DA_GUI', 'CHO_KE_TOAN') and r.id is distinct from p_except), 0)::bigint
    from app.sales_order o where o.id = p_order_id;
$$;

-- Đơn có phiếu thu còn sống (khác Huỷ): chặn huỷ đơn (R-TIEN-02). Thay hàm trống của P5a.
create or replace function app.order_has_receipt(p_order_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.receipt where order_id = p_order_id and status_code <> 'HUY');
$$;

-- Ghi lịch sử phiếu thu.
create or replace function app.receipt_add_event(p_receipt_id uuid, p_event text, p_from text, p_to text, p_note text default null)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into app.receipt_event (receipt_id, branch_id, event_code, from_status, to_status, note)
  select r.id, r.branch_id, p_event, p_from, p_to, nullif(btrim(coalesce(p_note, '')), '') from app.receipt r where r.id = p_receipt_id;
$$;

-- Kiểm và chuẩn hoá dữ liệu nhập của phiếu thu (dùng chung tạo và sửa). Trả jsonb đã chuẩn hoá.
-- Luật: số tiền > 0 và không vượt tiền còn có thể thu của đơn (R-TIEN-04: nhiều phiếu một đơn); hình thức thanh toán là mục đang dùng của
-- danh mục; ngày thu không ở tương lai; dòng cấn thuộc đơn (R-TIEN-23); Cơ sở thu tiền là cơ sở dạy học đang hoạt động (Đ258).
create or replace function app.receipt_normalize(p_order app.sales_order, p_data jsonb, p_except uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_amount bigint;
  v_method text := nullif(btrim(coalesce(p_data ->> 'payment_method_code', '')), '');
  v_paid_on date;
  v_collect uuid;
  v_receiver uuid;
  v_line uuid;
  v_limit bigint;
begin
  begin
    v_amount := (p_data ->> 'amount')::bigint;
  exception when others then
    perform app.raise_error('HMT_SO_TIEN_SAI', 'Nhập số tiền là số nguyên đồng.');
  end;
  if v_amount is null or v_amount <= 0 then
    perform app.raise_error('HMT_SO_TIEN_SAI', 'Số tiền phiếu thu phải lớn hơn 0.');
  end if;
  v_limit := app.order_receivable(p_order.id, p_except);
  if v_amount > v_limit then
    perform app.raise_error('HMT_SO_TIEN_VUOT',
      format('Số tiền vượt phần còn có thể thu của đơn (còn %s đ).', to_char(greatest(v_limit, 0), 'FM999G999G999G999')));
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
  v_line := nullif(p_data ->> 'target_line_id', '')::uuid;
  if v_line is not null and not exists (select from app.sales_order_line where id = v_line and order_id = p_order.id and is_live) then
    perform app.raise_error('HMT_DONG_SAI', 'Dòng cấn không thuộc đơn này.');
  end if;
  return jsonb_build_object('amount', v_amount, 'payment_method_code', v_method, 'paid_on', v_paid_on, 'collect_branch_id', v_collect,
                            'receiver_id', v_receiver, 'target_line_id', v_line,
                            'txn_ref', nullif(btrim(coalesce(p_data ->> 'txn_ref', '')), ''),
                            'note', nullif(btrim(coalesce(p_data ->> 'note', '')), ''));
end;
$$;

-- Chia tiền của một khoản vào về các dòng của đơn (R-TIEN-22, 23). Dòng cấn nhận trước, tối đa phần còn nhận được (thành tiền − đã chia);
-- phần còn lại chia theo tỉ lệ thành tiền các dòng khác còn nhận được; dòng cuối nhận phần dư làm tròn. Ghi vào money_in_allocation.
create or replace function app.allocate_money_in(p_money_in_id uuid, p_order_id uuid, p_amount bigint, p_target uuid, p_branch uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ids uuid[];
  v_room bigint[];
  v_give bigint[];
  v_rest bigint := p_amount;
  v_total_room bigint := 0;
  v_i integer;
  v_part bigint;
  v_last integer;
begin
  select array_agg(l.id order by l.line_no), array_agg(greatest(l.line_total - coalesce(a.paid, 0), 0) order by l.line_no)
    into v_ids, v_room
    from app.sales_order_line l
    left join lateral (select sum(m.amount) paid from app.money_in_allocation m where m.order_line_id = l.id) a on true
   where l.order_id = p_order_id and l.is_live and l.line_total > 0;
  if v_ids is null then
    perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn không có dòng nào nhận tiền.');
  end if;
  v_give := array_fill(0::bigint, array[cardinality(v_ids)]);
  -- Cấn vào dòng được chọn trước.
  if p_target is not null then
    v_i := array_position(v_ids, p_target);
    if v_i is not null then
      v_part := least(v_rest, v_room[v_i]);
      v_give[v_i] := v_part;
      v_room[v_i] := v_room[v_i] - v_part;
      v_rest := v_rest - v_part;
    end if;
  end if;
  -- Phần còn lại chia theo tỉ lệ phần còn nhận được của các dòng (dòng cấn đã đầy nếu còn dư).
  for v_i in 1 .. cardinality(v_ids) loop
    v_total_room := v_total_room + v_room[v_i];
    if v_room[v_i] > 0 then
      v_last := v_i;
    end if;
  end loop;
  if v_rest > 0 then
    if v_total_room < v_rest then
      perform app.raise_error('HMT_SO_TIEN_VUOT', 'Số tiền vượt phần còn nhận được của các dòng đơn.');
    end if;
    declare
      v_assigned bigint := 0;
    begin
      for v_i in 1 .. cardinality(v_ids) loop
        if v_room[v_i] > 0 then
          if v_i = v_last then
            v_part := v_rest - v_assigned;
          else
            v_part := least(floor(v_rest::numeric * v_room[v_i] / v_total_room)::bigint, v_room[v_i]);
          end if;
          v_give[v_i] := v_give[v_i] + v_part;
          v_assigned := v_assigned + v_part;
        end if;
      end loop;
    end;
  end if;
  for v_i in 1 .. cardinality(v_ids) loop
    if v_give[v_i] > 0 then
      insert into app.money_in_allocation (money_in_id, order_line_id, branch_id, amount)
      values (p_money_in_id, v_ids[v_i], p_branch, v_give[v_i]);
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Hàm nghiệp vụ
-- ---------------------------------------------------------------------------
-- app.create_receipt(đơn, dữ liệu): tạo phiếu thu Nháp từ đơn Đã duyệt. Ai gọi: người có quyền Phiếu thu · Tạo ở cơ sở của đơn (Bán hàng bật, Đ173).
-- Đầu vào p_data: amount, payment_method_code, txn_ref, paid_on, collect_branch_id, receiver_id, target_line_id, note.
-- Kết quả: {id, code, warnings}. Luật: R-TIEN-02 (chỉ từ đơn Đã duyệt), R-TIEN-04, Đ258 (cơ sở thu tiền khác cơ sở đơn chỉ nhắc, không chặn).
create or replace function app.create_receipt(p_order_id uuid, p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v jsonb;
  v_id uuid;
  v_code text;
  v_branch_code text;
  v_warnings jsonb := '[]'::jsonb;
begin
  select * into v_o from app.sales_order where id = p_order_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('RECEIPT', 'TAO', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id);
  -- Luật R-TIEN-02: phiếu thu chỉ tạo từ đơn Đã duyệt.
  if v_o.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_DON_CHUA_DUYET', 'Chỉ tạo phiếu thu từ đơn đã duyệt.');
  end if;
  v := app.receipt_normalize(v_o, p_data);
  select code into v_branch_code from app.branch where id = v_o.branch_id;
  v_code := app.issue_document_number('PT', v_branch_code);
  insert into app.receipt (code, order_id, parent_id, branch_id, collect_branch_id, receiver_id, amount, payment_method_code, txn_ref,
                           paid_on, target_line_id, note)
  values (v_code, v_o.id, v_o.parent_id, v_o.branch_id, (v ->> 'collect_branch_id')::uuid, (v ->> 'receiver_id')::uuid,
          (v ->> 'amount')::bigint, v ->> 'payment_method_code', v ->> 'txn_ref', (v ->> 'paid_on')::date,
          (v ->> 'target_line_id')::uuid, v ->> 'note')
  returning id into v_id;
  perform app.receipt_add_event(v_id, 'TAO', null, 'NHAP');
  -- Luật Đ258: Cơ sở thu tiền khác cơ sở của đơn thì nhắc nhẹ, không chặn.
  if (v ->> 'collect_branch_id')::uuid <> v_o.branch_id then
    v_warnings := v_warnings || to_jsonb('Cơ sở thu tiền khác cơ sở của đơn hàng.'::text);
  end if;
  return jsonb_build_object('id', v_id, 'code', v_code, 'warnings', v_warnings);
end;
$$;

-- app.save_receipt(phiếu, dữ liệu): sửa phiếu Nháp (người lập). Luật R-TIEN-23: dòng cấn chỉ đổi được khi còn Nháp.
create or replace function app.save_receipt(p_id uuid, p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_o app.sales_order;
  v jsonb;
  v_warnings jsonb := '[]'::jsonb;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('RECEIPT', 'TAO', r.branch_id);
  if r.created_by is distinct from auth.uid() then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_LAP', 'Chỉ người lập mới sửa được phiếu thu của mình.');
  end if;
  if r.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ sửa được phiếu thu Nháp.');
  end if;
  select * into v_o from app.sales_order where id = r.order_id;
  v := app.receipt_normalize(v_o, p_data, r.id);
  update app.receipt set amount = (v ->> 'amount')::bigint, payment_method_code = v ->> 'payment_method_code', txn_ref = v ->> 'txn_ref',
         paid_on = (v ->> 'paid_on')::date, collect_branch_id = (v ->> 'collect_branch_id')::uuid, receiver_id = (v ->> 'receiver_id')::uuid,
         target_line_id = (v ->> 'target_line_id')::uuid, note = v ->> 'note'
   where id = p_id;
  perform app.receipt_add_event(p_id, 'SUA', 'NHAP', 'NHAP');
  if (v ->> 'collect_branch_id')::uuid <> v_o.branch_id then
    v_warnings := v_warnings || to_jsonb('Cơ sở thu tiền khác cơ sở của đơn hàng.'::text);
  end if;
  return jsonb_build_object('id', p_id, 'warnings', v_warnings);
end;
$$;

-- Bước quản lý duyệt xong: Chờ kế toán (dùng chung cho duyệt tay và tự duyệt của Trưởng cơ sở).
create or replace function app.receipt_manager_step_done(p_id uuid, p_event text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update app.receipt set status_code = 'CHO_KE_TOAN', manager_approved_at = now(), manager_approved_by = auth.uid() where id = p_id;
  perform app.receipt_add_event(p_id, p_event, 'DA_GUI', 'CHO_KE_TOAN');
end;
$$;

-- app.submit_receipt(phiếu): gửi phiếu Nháp (người lập). Chốt người duyệt bước quản lý theo người lập (R-HT-06, R-TIEN-01): quản lý trực tiếp,
-- hoặc Trưởng cơ sở lập thì tự duyệt bước này (lịch sử ghi "tự duyệt"). Gửi lại sau khi bị từ chối đi lại từ bước quản lý (TD14).
create or replace function app.submit_receipt(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_o app.sales_order;
  v_route text;
  v_approver uuid;
  v_auto boolean;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('RECEIPT', 'TAO', r.branch_id);
  perform app.require_feature('BAN_HANG', r.branch_id);
  if r.created_by is distinct from auth.uid() then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_LAP', 'Chỉ người lập mới gửi được phiếu thu của mình.');
  end if;
  if r.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ gửi được phiếu thu Nháp.');
  end if;
  select * into v_o from app.sales_order where id = r.order_id;
  if v_o.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_DON_CHUA_DUYET', 'Đơn hàng không còn ở trạng thái đã duyệt.');
  end if;
  -- Kiểm lại số tiền với phần còn thu được (các phiếu khác có thể đã gửi từ lúc lập).
  perform app.receipt_normalize(v_o, jsonb_build_object('amount', r.amount, 'payment_method_code', r.payment_method_code,
            'paid_on', r.paid_on, 'collect_branch_id', r.collect_branch_id, 'receiver_id', r.receiver_id, 'target_line_id', r.target_line_id), r.id);
  select x.route, x.approver_id into v_route, v_approver from app.approval_route(r.created_by) x;
  if not app.user_can_at_branch(v_approver, 'RECEIPT', 'DUYET', r.branch_id) then
    perform app.raise_error('HMT_NGUOI_DUYET_THIEU_QUYEN',
      'Quản lý trực tiếp của người lập chưa có quyền Duyệt phiếu thu ở cơ sở này nên chưa gửi được. Nhờ Admin đặt lại Quản lý trực tiếp hoặc cấp quyền.');
  end if;
  update app.receipt set status_code = 'DA_GUI', approval_route = v_route, assigned_approver_id = v_approver,
         submitted_at = now(), submitted_by = auth.uid() where id = p_id;
  perform app.receipt_add_event(p_id, 'GUI', 'NHAP', 'DA_GUI');
  -- Trưởng cơ sở lập và chính họ gửi: tự duyệt bước quản lý ngay, trong cùng giao dịch.
  v_auto := v_route = 'TU_DUYET' and r.created_by is not distinct from auth.uid();
  if v_auto then
    perform app.receipt_manager_step_done(p_id, 'TU_DUYET_QL');
  end if;
  return jsonb_build_object('id', p_id, 'approver_id', v_approver, 'route', v_route,
                            'status', case when v_auto then 'CHO_KE_TOAN' else 'DA_GUI' end, 'auto_approved', v_auto);
end;
$$;

-- app.approve_receipt_manager(phiếu): bước quản lý duyệt. Ai gọi: người duyệt đã chốt lúc gửi (R-HT-06), có quyền Phiếu thu · Duyệt ở cơ sở.
-- Admin KHÔNG duyệt thay bước quản lý của phiếu thu (R-TIEN-01).
create or replace function app.approve_receipt_manager(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('RECEIPT', 'DUYET', r.branch_id);
  if r.status_code <> 'DA_GUI' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt bước quản lý được phiếu thu Đã gửi.');
  end if;
  if not app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id) then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_DUYET', 'Phiếu thu này do người duyệt đã chốt lúc gửi duyệt (Admin không duyệt thay bước quản lý).');
  end if;
  perform app.receipt_manager_step_done(p_id, 'DUYET_QL');
end;
$$;

-- app.reject_receipt(phiếu, lý do): từ chối, phiếu về Nháp kèm lý do (R-TIEN-06). Ở Đã gửi: người duyệt bước quản lý; ở Chờ kế toán: kế toán.
-- Gửi lại sau đó đi lại từ bước quản lý (TD14); lịch sử giữ lần từ chối và lý do.
create or replace function app.reject_receipt(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    perform app.raise_error('HMT_THIEU_LY_DO', 'Nhập lý do từ chối.');
  end if;
  if r.status_code = 'DA_GUI' then
    perform app.assert_can('RECEIPT', 'DUYET', r.branch_id);
    if not app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id) then
      perform app.raise_error('HMT_KHONG_PHAI_NGUOI_DUYET', 'Phiếu thu này do người duyệt đã chốt lúc gửi duyệt.');
    end if;
  elsif r.status_code = 'CHO_KE_TOAN' then
    perform app.assert_can('ACCOUNTING', 'DUYET', r.branch_id);
  else
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ từ chối được phiếu thu Đã gửi hoặc Chờ kế toán.');
  end if;
  update app.receipt set status_code = 'NHAP', approval_route = null, assigned_approver_id = null, submitted_at = null, submitted_by = null,
         manager_approved_at = null, manager_approved_by = null where id = p_id;
  perform app.receipt_add_event(p_id, 'TU_CHOI', r.status_code, 'NHAP', p_reason);
end;
$$;

-- app.cancel_receipt(phiếu, mã lý do, ghi chú): huỷ phiếu chưa duyệt. Ai gọi: người lập (phiếu của mình) hoặc người có quyền Phiếu thu · Huỷ.
-- Phiếu đã duyệt không huỷ được ở đây (đảo khoản làm sau, R-TIEN-26).
create or replace function app.cancel_receipt(p_id uuid, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  if r.created_by is distinct from auth.uid() then
    perform app.assert_can('RECEIPT', 'HUY', r.branch_id);
  else
    perform app.assert_can('RECEIPT', 'TAO', r.branch_id);
  end if;
  if r.status_code = 'DA_DUYET' then
    perform app.raise_error('HMT_PHIEU_DA_DUYET', 'Phiếu thu đã duyệt không huỷ được; dùng đảo khoản.');
  end if;
  if r.status_code = 'HUY' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Phiếu thu đã huỷ.');
  end if;
  perform app.assert_catalog_code_active('RECEIPT_CANCEL_REASON', p_reason_code);
  if exists (select from app.catalog_item where catalog_code = 'RECEIPT_CANCEL_REASON' and code = p_reason_code and requires_note)
     and nullif(btrim(coalesce(p_note, '')), '') is null then
    perform app.raise_error('HMT_THIEU_GHI_CHU', 'Lý do này cần ghi chú.');
  end if;
  update app.receipt set status_code = 'HUY', cancel_reason_code = p_reason_code, cancel_note = nullif(btrim(coalesce(p_note, '')), ''),
         cancelled_at = now(), cancelled_by = auth.uid() where id = p_id;
  perform app.receipt_add_event(p_id, 'HUY', r.status_code, 'HUY', p_note);
end;
$$;

-- app.approve_receipt_accounting(phiếu): kế toán duyệt (bước cuối). Ai gọi: người có quyền Kế toán · Duyệt (Admin không duyệt trực tiếp, R-HT-01).
-- Khi duyệt: sinh khoản tiền vào KTV (R-TIEN-01), chia tiền về các dòng của đơn (R-TIEN-22, 23). Kiểm lại số tiền không vượt phần còn thu được.
create or replace function app.approve_receipt_accounting(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_o app.sales_order;
  v_code text;
  v_money uuid;
  v_branch_code text;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('ACCOUNTING', 'DUYET', r.branch_id);
  if r.status_code <> 'CHO_KE_TOAN' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt được phiếu thu Chờ kế toán.');
  end if;
  select * into v_o from app.sales_order where id = r.order_id for update;
  if r.amount > v_o.total_amount - app.order_paid_amount(v_o.id) then
    perform app.raise_error('HMT_SO_TIEN_VUOT', 'Số tiền phiếu vượt phần còn lại của đơn.');
  end if;
  select code into v_branch_code from app.branch where id = r.branch_id;
  v_code := app.issue_document_number('KTV', v_branch_code);
  insert into app.money_in (code, receipt_id, order_id, parent_id, branch_id, amount)
  values (v_code, r.id, r.order_id, r.parent_id, r.branch_id, r.amount)
  returning id into v_money;
  perform app.allocate_money_in(v_money, r.order_id, r.amount, r.target_line_id, r.branch_id);
  update app.receipt set status_code = 'DA_DUYET', accountant_approved_at = now(), accountant_approved_by = auth.uid() where id = p_id;
  perform app.receipt_add_event(p_id, 'DUYET_KT', 'CHO_KE_TOAN', 'DA_DUYET');
  return jsonb_build_object('id', p_id, 'money_in_id', v_money, 'money_in_code', v_code,
                            'paid', app.order_paid_amount(v_o.id), 'remaining', v_o.total_amount - app.order_paid_amount(v_o.id));
end;
$$;

-- Tóm tắt thanh toán của đơn (đã thu, còn lại, cờ đủ cọc R-TIEN-20) cho màn Đơn hàng và Phiếu thu. Ai gọi: người xem được đơn.
create or replace function app.order_payment_summary(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_paid bigint;
begin
  select * into v_o from app.sales_order where id = p_order_id;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'XEM', v_o.branch_id);
  v_paid := app.order_paid_amount(v_o.id);
  return jsonb_build_object('order_id', v_o.id, 'total', v_o.total_amount, 'paid', v_paid, 'remaining', v_o.total_amount - v_paid,
                            'receivable', app.order_receivable(v_o.id),
                            'deposit_reached', v_paid >= app.get_setting_int('deposit_min_amount', v_o.branch_id),
                            'fully_paid', v_paid >= v_o.total_amount);
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Hàm đọc: danh sách và bản ghi phiếu thu (TC-01, TC-02, TC-04)
-- ---------------------------------------------------------------------------
-- app.list_receipts(bộ lọc, sắp xếp, số dòng, vị trí): danh sách phiếu thu có phân trang ở máy chủ (R-HT, hiệu năng: mặc định theo tham số, tối đa
-- list_page_size_max). Ai gọi: người có quyền Phiếu thu · Xem (phạm vi cơ sở hoặc toàn hệ thống). Bộ lọc p_filters: q (tìm mã phiếu, mã đơn, tên và
-- SĐT phụ huynh), status (mảng), branch_id, order_id, parent_id, mine (phiếu của tôi), waiting_manager (Đã gửi chờ tôi duyệt bước quản lý),
-- waiting_accounting (Chờ kế toán, TC-04), created_from, created_to. Kết quả: {total, rows}.
create or replace function app.list_receipts(p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc', p_limit integer default null,
                                             p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('RECEIPT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_order uuid := nullif(p_filters ->> 'order_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_wait_mgr boolean := coalesce((p_filters ->> 'waiting_manager')::boolean, false);
  v_wait_acc boolean := coalesce((p_filters ->> 'waiting_accounting')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu thu.');
  end if;
  with f as not materialized (
    select r.*
      from app.receipt r
     where (v_scope = 'TOAN_HE_THONG' or r.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or r.status_code = any (v_status))
       and (v_branch is null or r.branch_id = v_branch)
       and (v_order is null or r.order_id = v_order)
       and (v_parent is null or r.parent_id = v_parent)
       and (not v_mine or r.created_by = auth.uid())
       and (not v_wait_mgr or (r.status_code = 'DA_GUI' and r.assigned_approver_id = auth.uid()))
       and (not v_wait_acc or r.status_code = 'CHO_KE_TOAN')
       and (v_from is null or r.created_at >= v_from)
       and (v_to is null or r.created_at < v_to)
       and (v_q is null or r.search_text like '%' || v_q || '%')
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'amount_desc' then f.amount end desc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'status_code', p.status_code,
             'status', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_STATUS' and c.code = p.status_code),
             'order_id', p.order_id, 'order_code', o.code, 'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name,
             'amount', p.amount, 'payment_method_code', p.payment_method_code,
             'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = p.payment_method_code),
             'paid_on', p.paid_on, 'branch_code', b.code, 'collect_branch_code', cb.code,
             'created_at', p.created_at, 'created_by_name', app.staff_display_name(p.created_by),
             'approver_name', app.staff_display_name(p.assigned_approver_id), 'submitted_at', p.submitted_at)
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'amount_desc' then p.amount end desc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.branch cb on cb.id = p.collect_branch_id
    join app.parent par on par.id = p.parent_id
    join app.sales_order o on o.id = p.order_id;
  return v_result;
end;
$$;

-- app.get_receipt(phiếu): bản ghi phiếu thu kèm đơn, tóm tắt thanh toán của đơn, lịch sử, khoản tiền vào và phần chia, và các việc người gọi làm được
-- ở trạng thái hiện tại (actions) để giao diện chỉ hiện nút đúng, không lặp luật quyền. Ai gọi: người có quyền Phiếu thu · Xem ở cơ sở của phiếu.
create or replace function app.get_receipt(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_o app.sales_order;
  v_actions text[] := array[]::text[];
  v_me uuid := auth.uid();
begin
  select * into r from app.receipt where id = p_id;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('RECEIPT', 'XEM', r.branch_id);
  select * into v_o from app.sales_order where id = r.order_id;
  if r.status_code = 'NHAP' and r.created_by is not distinct from v_me and app.can_see_branch('RECEIPT', 'TAO', r.branch_id) then
    v_actions := v_actions || array['sua', 'gui'];
  end if;
  if r.status_code = 'DA_GUI' and app.can_see_branch('RECEIPT', 'DUYET', r.branch_id)
     and app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id) then
    v_actions := v_actions || array['duyet_quan_ly', 'tu_choi'];
  end if;
  if r.status_code = 'CHO_KE_TOAN' and app.can_see_branch('ACCOUNTING', 'DUYET', r.branch_id) then
    v_actions := v_actions || array['duyet_ke_toan', 'tu_choi'];
  end if;
  if r.status_code in ('NHAP', 'DA_GUI', 'CHO_KE_TOAN')
     and (r.created_by is not distinct from v_me and app.can_see_branch('RECEIPT', 'TAO', r.branch_id) or app.can_see_branch('RECEIPT', 'HUY', r.branch_id)) then
    v_actions := v_actions || array['huy'];
  end if;
  return jsonb_build_object(
    'id', r.id, 'code', r.code, 'status_code', r.status_code,
    'status', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_STATUS' and c.code = r.status_code),
    'order', jsonb_build_object('id', v_o.id, 'code', v_o.code, 'total_amount', v_o.total_amount, 'status_code', v_o.status_code),
    'parent', (select jsonb_build_object('id', p.id, 'code', p.code, 'name', p.full_name, 'phone', p.phone) from app.parent p where p.id = r.parent_id),
    'amount', r.amount, 'payment_method_code', r.payment_method_code,
    'payment_method', (select c.name from app.catalog_item c where c.catalog_code = 'PAYMENT_METHOD' and c.code = r.payment_method_code),
    'txn_ref', r.txn_ref, 'paid_on', r.paid_on, 'note', r.note, 'target_line_id', r.target_line_id,
    'branch_code', (select code from app.branch where id = r.branch_id), 'collect_branch_id', r.collect_branch_id,
    'collect_branch_code', (select code from app.branch where id = r.collect_branch_id),
    'receiver_id', r.receiver_id, 'receiver_name', app.staff_display_name(r.receiver_id),
    'created_at', r.created_at, 'created_by', r.created_by, 'created_by_name', app.staff_display_name(r.created_by),
    'approver_name', app.staff_display_name(r.assigned_approver_id), 'approval_route', r.approval_route,
    'submitted_at', r.submitted_at, 'manager_approved_at', r.manager_approved_at, 'accountant_approved_at', r.accountant_approved_at,
    'cancel_reason', (select c.name from app.catalog_item c where c.catalog_code = 'RECEIPT_CANCEL_REASON' and c.code = r.cancel_reason_code),
    'cancel_note', r.cancel_note, 'cancelled_at', r.cancelled_at,
    'payment', app.order_payment_summary(r.order_id),
    'actions', to_jsonb(v_actions),
    'events', coalesce((select jsonb_agg(jsonb_build_object('event_code', e.event_code, 'from_status', e.from_status, 'to_status', e.to_status,
                                                            'note', e.note, 'at', e.created_at, 'by_name', app.staff_display_name(e.created_by))
                                         order by e.seq) from app.receipt_event e where e.receipt_id = r.id), '[]'::jsonb),
    'money_in', (select jsonb_build_object('code', m.code, 'amount', m.amount,
                   'allocations', (select coalesce(jsonb_agg(jsonb_build_object('line_no', l.line_no, 'package_name', l.package_name, 'amount', a.amount)
                                                             order by l.line_no), '[]'::jsonb)
                                     from app.money_in_allocation a join app.sales_order_line l on l.id = a.order_line_id where a.money_in_id = m.id))
                   from app.money_in m where m.receipt_id = r.id));
end;
$$;

revoke execute on function app.order_paid_amount(uuid), app.order_receivable(uuid, uuid), app.receipt_add_event(uuid, text, text, text, text),
  app.receipt_normalize(app.sales_order, jsonb, uuid), app.allocate_money_in(uuid, uuid, bigint, uuid, uuid),
  app.receipt_manager_step_done(uuid, text) from public, anon, authenticated;
revoke execute on function app.create_receipt(uuid, jsonb), app.save_receipt(uuid, jsonb), app.submit_receipt(uuid),
  app.approve_receipt_manager(uuid), app.reject_receipt(uuid, text), app.cancel_receipt(uuid, text, text),
  app.approve_receipt_accounting(uuid), app.order_payment_summary(uuid), app.list_receipts(jsonb, text, integer, integer), app.get_receipt(uuid) from public, anon;
grant execute on function app.create_receipt(uuid, jsonb), app.save_receipt(uuid, jsonb), app.submit_receipt(uuid),
  app.approve_receipt_manager(uuid), app.reject_receipt(uuid, text), app.cancel_receipt(uuid, text, text),
  app.approve_receipt_accounting(uuid), app.order_payment_summary(uuid), app.list_receipts(jsonb, text, integer, integer), app.get_receipt(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 8. Ô chọn "Người nhận tiền" của phiếu thu (TC-02): nhân sự đang hoạt động, cùng cơ sở với người gọi xếp đầu.
-- app.receipt_receiver_options(tìm, số dòng): Ai gọi: người có quyền Phiếu thu · Tạo hoặc Sửa. Kết quả: mảng {id, name, branch_code, same_branch}.
-- Chỉ nhân sự (không học sinh), không bị khoá; tìm theo tên; số dòng tối đa list_page_size_max (ô chọn có tìm, không tải cả bảng).
-- ---------------------------------------------------------------------------
create or replace function app.receipt_receiver_options(p_search text default null, p_limit integer default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_q text := nullif(app.fold_text(btrim(coalesce(p_search, ''))), '');
begin
  if not (app.has_permission('RECEIPT', 'TAO') or app.has_permission('RECEIPT', 'SUA')) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền chọn người nhận tiền.');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', t.id, 'name', t.display_name, 'branch_code', t.branch_code, 'same_branch', t.same_branch)
                     order by t.same_branch desc, t.display_name)
      from (select u.id, u.display_name, b.code as branch_code, (u.branch_id = app.current_branch_id()) as same_branch
              from app.user_account u join app.branch b on b.id = u.branch_id
             where u.student_code is null and not u.is_locked
               and (v_q is null or app.fold_text(u.display_name) like '%' || v_q || '%')
             order by (u.branch_id = app.current_branch_id()) desc, u.display_name
             limit least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'))) t), '[]'::jsonb);
end;
$$;
revoke execute on function app.receipt_receiver_options(text, integer) from public, anon;
grant execute on function app.receipt_receiver_options(text, integer) to authenticated;

select set_config('hmt.migration', '', false);
