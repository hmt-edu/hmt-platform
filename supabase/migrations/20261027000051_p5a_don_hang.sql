-- ===========================================================================
-- P5a-DB1b-1 (migration 051): đơn hàng, phần BẢNG và HÀM GHI. Hàm đọc, xuất để DB1b-2.
-- QĐ-Đ201 đến Đ205; R-TIEN-01, 02, 03, 05, 06, 07, 12, 13, 14, 15, 29, 30, 35, 36, 37, 38; R-GD-06, R-GD-08; R-CRM-16, R-CRM-27;
-- R-HT-01, R-HT-06; QĐ-Đ83, Đ95, Đ101, Đ102, Đ106, Đ108, Đ173.
-- Gốc của đơn: cơ hội hoặc phiếu tái tục, ĐÚNG MỘT (Đ187). Cột phiếu tái tục chưa có khoá ngoại vì chưa có bảng phiếu tái tục (P5b);
-- hàm tạo đơn từ phiếu tái tục làm khi có bảng đó.
-- Lớp (R-GD-08): bảng lớp là P5b nên chưa có. Cột class_id để trống được, không khoá ngoại; ô lớp có giá trị thì hàm kiểm lớp báo
-- HMT_LOP_CHUA_CO_BANG cho tới khi P5b thay thân hàm app.check_order_line_class bằng kiểm thật (đã duyệt, đúng môn, khối, cơ sở, còn chỗ).
-- Phiếu thu (DB2): hàm app.order_has_receipt trả false cho tới DB2.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Danh mục tên hiển thị trạng thái đơn (spec 06 mục 30). Không có Từ chối: đơn bị từ chối về Nháp (R-TIEN-06), lịch sử ở sales_order_event.
-- ---------------------------------------------------------------------------
insert into app.catalog (code, name, kind, parent_catalog, linked_catalog, description, sort_order) values
  ('ORDER_STATUS', 'Trạng thái đơn hàng', 'HE_THONG', null, null,
   'Nháp, Đã trình, Đã duyệt, Huỷ. Từ chối đưa đơn về Nháp, lịch sử giữ lần từ chối (R-TIEN-06). Khoá khi duyệt không phải một trạng thái (R-TIEN-03).', 64);
insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note) values
  ('ORDER_STATUS', 'NHAP', 'Nháp', 1, false),
  ('ORDER_STATUS', 'DA_TRINH', 'Đã trình', 2, false),
  ('ORDER_STATUS', 'DA_DUYET', 'Đã duyệt', 3, false),
  ('ORDER_STATUS', 'HUY', 'Huỷ', 4, false);

-- ---------------------------------------------------------------------------
-- Đơn hàng. Mã cấp lúc tạo (DH-CS1-2610-0001). Ghi chỉ qua hàm.
-- ---------------------------------------------------------------------------
create table app.sales_order (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  branch_id uuid not null references app.branch (id),
  -- Gốc của đơn (Đ187): đúng một trong hai.
  opportunity_id uuid references app.opportunity (id),
  renewal_ticket_id uuid,
  parent_id uuid not null references app.parent (id),
  quotation_id uuid references app.quotation (id),
  status_catalog text not null default 'ORDER_STATUS' check (status_catalog = 'ORDER_STATUS'),
  status_code text not null default 'NHAP' check (status_code in ('NHAP', 'DA_TRINH', 'DA_DUYET', 'HUY')),
  payment_term_id uuid references app.payment_term (id),
  -- Ngày (giờ Việt Nam) tính giá: đơn thẳng từ cơ hội là NGÀY TẠO ĐƠN, lưu lại không đổi (R-TIEN-14); đơn từ báo giá lấy ngày của báo giá.
  priced_on date not null,
  total_amount bigint not null default 0 check (total_amount >= 0),
  -- Chốt lúc trình (R-HT-06): quản lý trực tiếp của người lập hoặc chính Trưởng cơ sở (tự duyệt).
  approval_route text check (approval_route in ('QUAN_LY', 'TU_DUYET')),
  assigned_approver_id uuid,
  needs_acknowledgement boolean not null default false,
  submitted_at timestamptz,
  submitted_by uuid,
  approved_at timestamptz,
  approved_by uuid,
  approved_on_behalf boolean not null default false,
  acknowledged boolean not null default false,
  cancel_reason_catalog text not null default 'ORDER_CANCEL_REASON' check (cancel_reason_catalog = 'ORDER_CANCEL_REASON'),
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
  check (num_nonnulls(opportunity_id, renewal_ticket_id) = 1)
);
comment on table app.sales_order is 'Đơn hàng (R-TIEN-01). Mã cấp lúc tạo. Đúng một gốc: cơ hội hoặc phiếu tái tục (Đ187). Ghi chỉ qua hàm.';
-- Chỉ mục (lý do):
-- danh sách theo cơ sở, trạng thái, mới nhất (RLS và lọc);
create index sales_order_branch_status_idx on app.sales_order (branch_id, status_code, created_at desc);
-- danh sách mặc định (không lọc trạng thái) theo cơ sở, mới nhất, đi thẳng theo chỉ mục;
create index sales_order_branch_created_idx on app.sales_order (branch_id, created_at desc, id);
-- đơn của một cơ hội (TS-08), của một báo giá, của phụ huynh (KH-02): khoá ngoại;
create index sales_order_opportunity_idx on app.sales_order (opportunity_id) where opportunity_id is not null;
create index sales_order_quotation_idx on app.sales_order (quotation_id) where quotation_id is not null;
create index sales_order_parent_idx on app.sales_order (parent_id);
create index sales_order_term_idx on app.sales_order (payment_term_id) where payment_term_id is not null;
-- việc chờ tôi duyệt (người duyệt đã chốt) và bộ lọc "của tôi";
create index sales_order_approver_idx on app.sales_order (assigned_approver_id, status_code) where assigned_approver_id is not null;
create index sales_order_creator_idx on app.sales_order (created_by, created_at desc);
-- tìm mã, tên phụ huynh, SĐT, tên em (D17).
create index sales_order_search_idx on app.sales_order using gin (search_text extensions.gin_trgm_ops);

select app.apply_standard('app.sales_order');

-- ---------------------------------------------------------------------------
-- Dòng đơn. Giá trị tiền, giờ, chiết khấu CHỤP LẠI lúc tạo (R-TIEN-14). Dòng viết lại được khi đơn còn Nháp (trigger khoá dưới).
-- is_live: dòng còn "đang sống" trong một đơn chưa huỷ; đơn Huỷ tắt cờ để trả dòng về báo giá (R-TIEN-02).
-- ---------------------------------------------------------------------------
create table app.sales_order_line (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references app.sales_order (id),
  branch_id uuid not null references app.branch (id),
  line_no integer not null check (line_no >= 1),
  line_kind text not null default 'ENROL' check (line_kind in ('ENROL', 'GIFT')),
  quotation_line_id uuid references app.quotation_line (id),
  prospect_student_id uuid references app.prospect_student (id),
  student_id uuid references app.student (id),
  package_id uuid not null references app.sales_package (id),
  package_code text not null,
  package_name text not null,
  package_type_code text not null,
  delivery_mode_code text not null,
  unit_code text not null check (unit_code in ('GIO', 'THANG', 'BO')),
  quantity numeric(6, 2) not null check (quantity > 0),
  gifted_quantity numeric(6, 2) not null default 0 check (gifted_quantity >= 0),
  unit_price bigint not null check (unit_price >= 0),
  gross_amount bigint not null check (gross_amount >= 0),
  discount_percent numeric(5, 2) not null default 0 check (discount_percent >= 0 and discount_percent <= 100), -- allow-number: phần trăm tối đa 100
  gift_percent numeric(7, 2) not null default 0 check (gift_percent >= 0),
  discount_amount bigint not null default 0 check (discount_amount >= 0),
  line_total bigint not null check (line_total >= 0),
  over_cap boolean not null default false,
  needs_acknowledgement boolean not null default false,
  gift_policy_id uuid references app.gift_policy (id),
  -- Lớp và ngày vào lớp (R-GD-06, R-GD-08). Chưa khoá ngoại: bảng lớp thuộc P5b.
  class_id uuid,
  enrol_start_date date,
  is_live boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (order_id, line_no),
  check (num_nonnulls(prospect_student_id, student_id) >= 1),
  check (line_kind <> 'GIFT' or (gift_policy_id is not null and unit_price = 0 and line_total = 0)),
  check (line_kind <> 'ENROL' or gift_policy_id is null),
  check (class_id is null or enrol_start_date is not null)
);
comment on table app.sales_order_line is 'Dòng đơn: một em, một gói, một hình thức; tiền và giờ chụp lại lúc tạo; is_live tắt khi đơn Huỷ.';
-- Chỉ mục (lý do): unique (order_id, line_no) là khoá ngoại và thứ tự dòng; RLS theo cơ sở; khoá ngoại tới em, gói, chính sách quà.
create index sales_order_line_branch_idx on app.sales_order_line (branch_id);
create index sales_order_line_prospect_idx on app.sales_order_line (prospect_student_id) where prospect_student_id is not null;
create index sales_order_line_student_idx on app.sales_order_line (student_id) where student_id is not null;
create index sales_order_line_package_idx on app.sales_order_line (package_id);
create index sales_order_line_gift_policy_idx on app.sales_order_line (gift_policy_id) where gift_policy_id is not null;
-- Một dòng báo giá không nằm trong hai đơn đang sống (R-TIEN-02): chỉ mục duy nhất từng phần theo cờ đang sống.
create unique index sales_order_line_quotation_live_uidx on app.sales_order_line (quotation_line_id)
  where quotation_line_id is not null and is_live;

create table app.sales_order_line_discount (
  id uuid primary key default gen_random_uuid(),
  line_id uuid not null references app.sales_order_line (id),
  branch_id uuid not null references app.branch (id),
  policy_id uuid not null references app.discount_policy (id),
  policy_code text not null,
  policy_name text not null,
  kind text not null check (kind in ('PERCENT', 'GIFT_HOURS')),
  applied_value numeric(7, 2) not null check (applied_value > 0),
  requires_approval boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (line_id, policy_id)
);
comment on table app.sales_order_line_discount is 'Chính sách chiết khấu áp trên dòng đơn (chụp lại mã, tên, giá trị đã áp).';
-- Chỉ mục (lý do): unique (line_id, policy_id) là khoá ngoại; chính sách (tra dòng đã dùng); cơ sở cho RLS.
create index sales_order_line_discount_policy_idx on app.sales_order_line_discount (policy_id);
create index sales_order_line_discount_branch_idx on app.sales_order_line_discount (branch_id);

-- Lịch đóng tiền từng đợt (R-TIEN-07): tính lại mỗi lần lưu Nháp, chốt khi duyệt (hạn đóng = ngày duyệt + số ngày của đợt).
create table app.sales_order_installment (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references app.sales_order (id),
  branch_id uuid not null references app.branch (id),
  seq integer not null check (seq >= 1),
  due_days integer not null check (due_days >= 0),
  amount bigint not null check (amount >= 0),
  due_date date,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (order_id, seq)
);
comment on table app.sales_order_installment is 'Lịch đóng tiền từng đợt của đơn. Tính từ điều khoản thanh toán; hạn đóng chốt khi duyệt đơn.';
-- Chỉ mục (lý do): unique (order_id, seq) là khoá ngoại; cơ sở cho RLS; hạn đóng cho công nợ (DB2).
create index sales_order_installment_branch_idx on app.sales_order_installment (branch_id);
create index sales_order_installment_due_idx on app.sales_order_installment (due_date) where due_date is not null;

-- Lịch sử đơn (R-TIEN-06): mỗi lần tạo, trình, duyệt, từ chối, huỷ ghi người, lý do, thời điểm. Chỉ thêm.
create table app.sales_order_event (
  id uuid primary key default gen_random_uuid(),
  -- Thứ tự ghi (nhiều sự kiện cùng một giao dịch có cùng thời điểm).
  seq bigint generated always as identity,
  order_id uuid not null references app.sales_order (id),
  branch_id uuid not null references app.branch (id),
  event_code text not null check (event_code in ('TAO', 'TRINH', 'DUYET', 'TU_CHOI', 'HUY')),
  from_status text,
  to_status text not null,
  reason_catalog text,
  reason_code text,
  note text,
  on_behalf boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.sales_order_event is 'Lịch sử đơn hàng: tạo, trình, duyệt, từ chối, huỷ (ai, khi nào, lý do). Chỉ thêm, giữ lần từ chối (R-TIEN-06).';
-- Chỉ mục (lý do): lịch sử một đơn theo thứ tự ghi (khoá ngoại); cơ sở cho RLS.
create index sales_order_event_order_idx on app.sales_order_event (order_id, seq);
create index sales_order_event_branch_idx on app.sales_order_event (branch_id);

select app.apply_standard('app.sales_order_line');
select app.apply_standard('app.sales_order_line_discount');
select app.apply_standard('app.sales_order_installment');
select app.apply_standard('app.sales_order_event');
-- apply_standard chặn xoá cứng; dòng, chiết khấu, lịch đóng tiền được xoá trong đơn Nháp (viết lại nháp) qua trigger khoá dưới.
drop trigger sales_order_line_no_delete on app.sales_order_line;
drop trigger sales_order_line_discount_no_delete on app.sales_order_line_discount;
drop trigger sales_order_installment_no_delete on app.sales_order_installment;

-- Cơ sở của dòng, chiết khấu, lịch đóng tiền, sự kiện luôn theo đơn.
create or replace function app.tg_sales_order_child_branch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_TABLE_NAME in ('sales_order_line', 'sales_order_installment', 'sales_order_event') then
    select o.branch_id into new.branch_id from app.sales_order o where o.id = new.order_id;
  else
    select l.branch_id into new.branch_id from app.sales_order_line l where l.id = new.line_id;
  end if;
  return new;
end;
$$;
create trigger sales_order_line_branch before insert on app.sales_order_line
  for each row execute function app.tg_sales_order_child_branch();
create trigger sales_order_installment_branch before insert on app.sales_order_installment
  for each row execute function app.tg_sales_order_child_branch();
create trigger sales_order_event_branch before insert on app.sales_order_event
  for each row execute function app.tg_sales_order_child_branch();
create trigger sales_order_line_discount_branch before insert on app.sales_order_line_discount
  for each row execute function app.tg_sales_order_child_branch();

-- Dòng, chiết khấu, lịch đóng tiền chỉ sửa, xoá khi đơn còn Nháp (R-TIEN-03: khoá khi trình, duyệt). Ngoại lệ: huỷ đơn tắt cờ is_live
-- (hàm huỷ đơn đặt hmt.order_cancel trong giao dịch); duyệt đơn chốt hạn đóng tiền (hmt.order_approve).
create or replace function app.tg_sales_order_child_lock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_status text;
begin
  if TG_TABLE_NAME in ('sales_order_line', 'sales_order_installment') then
    select o.status_code into v_status from app.sales_order o where o.id = coalesce(new.order_id, old.order_id);
  else
    select o.status_code into v_status
      from app.sales_order_line l join app.sales_order o on o.id = l.order_id where l.id = coalesce(new.line_id, old.line_id);
  end if;
  if v_status is distinct from 'NHAP' and not app.is_migration()
     and not (coalesce(current_setting('hmt.order_cancel', true), '') = 'on' and TG_TABLE_NAME = 'sales_order_line' and TG_OP = 'UPDATE')
     and not (coalesce(current_setting('hmt.order_approve', true), '') = 'on'
              and TG_TABLE_NAME in ('sales_order_installment', 'sales_order_line') and TG_OP = 'UPDATE') then
    perform app.raise_error('HMT_DON_DA_KHOA', 'Đơn đã trình hoặc đã khoá: dòng và lịch đóng tiền không sửa được.');
  end if;
  return coalesce(new, old);
end;
$$;
create trigger sales_order_line_lock before insert or update or delete on app.sales_order_line
  for each row execute function app.tg_sales_order_child_lock();
create trigger sales_order_line_discount_lock before insert or update or delete on app.sales_order_line_discount
  for each row execute function app.tg_sales_order_child_lock();
create trigger sales_order_installment_lock before insert or update or delete on app.sales_order_installment
  for each row execute function app.tg_sales_order_child_lock();

-- Đơn đã trình hoặc đã khoá không đổi tổng tiền, điều khoản, ngày tính giá, cơ sở, gốc, báo giá (R-TIEN-03). Chỉ trạng thái, người duyệt,
-- hạn huỷ và các cột ghi việc trình, duyệt, huỷ được đổi. (Đơn Nháp sửa tự do qua hàm.)
create or replace function app.tg_sales_order_lock()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status_code <> 'NHAP' and not app.is_migration() and (
       new.total_amount is distinct from old.total_amount or new.payment_term_id is distinct from old.payment_term_id
       or new.priced_on is distinct from old.priced_on or new.branch_id is distinct from old.branch_id
       or new.opportunity_id is distinct from old.opportunity_id or new.renewal_ticket_id is distinct from old.renewal_ticket_id
       or new.parent_id is distinct from old.parent_id or new.quotation_id is distinct from old.quotation_id
       or new.needs_acknowledgement is distinct from old.needs_acknowledgement) then
    perform app.raise_error('HMT_DON_DA_KHOA', 'Đơn đã trình hoặc đã khoá: tổng tiền, điều khoản và thông tin gốc không sửa được.');
  end if;
  return new;
end;
$$;
create trigger sales_order_lock before update on app.sales_order
  for each row execute function app.tg_sales_order_lock();

-- Sự kiện chỉ thêm: không ai sửa, xoá (kể cả hàm nghiệp vụ).
create or replace function app.tg_sales_order_event_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not app.is_migration() then
    perform app.raise_error('HMT_LICH_SU_CHI_THEM', 'Lịch sử đơn chỉ thêm, không sửa hay xoá.');
  end if;
  return coalesce(new, old);
end;
$$;
create trigger sales_order_event_append_only before update or delete on app.sales_order_event
  for each row execute function app.tg_sales_order_event_append_only();

-- Chuyển trạng thái chỉ theo bảng cho phép (R-TIEN-06). Hàm nghiệp vụ kiểm lần nữa với câu tiếng Việt.
create or replace function app.tg_sales_order_status_flow()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_OP = 'UPDATE' and new.status_code is distinct from old.status_code and not app.is_migration() then
    if not (old.status_code = 'NHAP' and new.status_code in ('DA_TRINH', 'HUY')
            or old.status_code = 'DA_TRINH' and new.status_code in ('DA_DUYET', 'NHAP', 'HUY')
            or old.status_code = 'DA_DUYET' and new.status_code = 'HUY') then
      perform app.raise_error('HMT_SAI_TRANG_THAI', 'Đơn hàng không chuyển được sang trạng thái này.');
    end if;
  end if;
  return new;
end;
$$;
create trigger sales_order_status_flow before update on app.sales_order
  for each row execute function app.tg_sales_order_status_flow();
create trigger sales_order_code_immutable before update on app.sales_order
  for each row execute function app.tg_code_immutable();

-- Ô tìm kiếm của đơn: mã, tên phụ huynh, SĐT, tên em (theo dòng đơn), mã cũ.
create or replace function app.sales_order_search_text(p_order app.sales_order)
returns text
language sql
stable
set search_path = ''
as $$
  select app.fold_text(p_order.code || ' ' || coalesce((select pa.full_name || ' ' || pa.phone from app.parent pa
                                                          where pa.id = p_order.parent_id), '')
                       || ' ' || coalesce((select string_agg(distinct coalesce(s.full_name, v.full_name), ' ')
                                             from app.sales_order_line l
                                             left join app.prospect_student_v v on v.id = l.prospect_student_id
                                             left join app.student s on s.id = l.student_id
                                            where l.order_id = p_order.id), '')
                       || ' ' || coalesce(p_order.legacy_ref, ''));
$$;
create or replace function app.tg_sales_order_search_text()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.search_text := app.sales_order_search_text(new);
  return new;
end;
$$;
create trigger sales_order_search_text before insert or update on app.sales_order
  for each row execute function app.tg_sales_order_search_text();

-- Phụ huynh, em đổi tên thì ô tìm kiếm của đơn tính lại (thêm đơn vào ba hàm của báo giá).
create or replace function app.tg_parent_refresh_opportunity_search()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.full_name is distinct from old.full_name or new.phone is distinct from old.phone then
    update app.opportunity o set search_text = app.opportunity_search_text(o) where o.parent_id = new.id;
    update app.student_test t set search_text = app.student_test_search_text(t)
     where t.student_id in (select s.id from app.student s where s.parent_id = new.id);
    update app.quotation q set search_text = app.quotation_search_text(q) where q.parent_id = new.id;
    update app.sales_order so set search_text = app.sales_order_search_text(so) where so.parent_id = new.id;
  end if;
  return null;
end;
$$;
create or replace function app.tg_prospect_refresh_parent_search()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lead uuid := coalesce(new.lead_id, old.lead_id);
  v_opp uuid := coalesce(new.opportunity_id, old.opportunity_id);
begin
  if v_lead is not null then
    update app.lead l set search_text = app.lead_search_text(l) where l.id = v_lead;
  end if;
  if v_opp is not null then
    update app.opportunity o set search_text = app.opportunity_search_text(o) where o.id = v_opp;
    update app.quotation q set search_text = app.quotation_search_text(q) where q.opportunity_id = v_opp;
    update app.sales_order so set search_text = app.sales_order_search_text(so) where so.opportunity_id = v_opp;
  end if;
  return null;
end;
$$;
create or replace function app.tg_student_refresh_test_search()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.full_name is distinct from old.full_name then
    update app.student_test t set search_text = app.student_test_search_text(t) where t.student_id = new.id;
    update app.opportunity o set search_text = app.opportunity_search_text(o)
     where o.id in (select ps.opportunity_id from app.prospect_student ps where ps.student_id = new.id and ps.opportunity_id is not null);
    update app.quotation q set search_text = app.quotation_search_text(q)
     where q.opportunity_id in (select ps.opportunity_id from app.prospect_student ps
                                 where ps.student_id = new.id and ps.opportunity_id is not null);
    update app.sales_order so set search_text = app.sales_order_search_text(so)
     where so.opportunity_id in (select ps.opportunity_id from app.prospect_student ps
                                  where ps.student_id = new.id and ps.opportunity_id is not null);
  end if;
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS: đọc theo quyền Đơn hàng · Xem (toàn hệ thống hoặc đúng cơ sở); ghi chỉ qua hàm.
-- ---------------------------------------------------------------------------
alter table app.sales_order enable row level security;
alter table app.sales_order_line enable row level security;
alter table app.sales_order_line_discount enable row level security;
alter table app.sales_order_installment enable row level security;
alter table app.sales_order_event enable row level security;
revoke all on app.sales_order, app.sales_order_line, app.sales_order_line_discount, app.sales_order_installment,
  app.sales_order_event from public, anon, authenticated;
grant select on app.sales_order, app.sales_order_line, app.sales_order_line_discount, app.sales_order_installment,
  app.sales_order_event to authenticated;
create policy sales_order_read on app.sales_order for select to authenticated
  using ((select app.permission_scope('SALES_ORDER', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('SALES_ORDER', 'XEM')) is not null and branch_id = (select app.current_branch_id())));
create policy sales_order_line_read on app.sales_order_line for select to authenticated
  using ((select app.permission_scope('SALES_ORDER', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('SALES_ORDER', 'XEM')) is not null and branch_id = (select app.current_branch_id())));
create policy sales_order_line_discount_read on app.sales_order_line_discount for select to authenticated
  using ((select app.permission_scope('SALES_ORDER', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('SALES_ORDER', 'XEM')) is not null and branch_id = (select app.current_branch_id())));
create policy sales_order_installment_read on app.sales_order_installment for select to authenticated
  using ((select app.permission_scope('SALES_ORDER', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('SALES_ORDER', 'XEM')) is not null and branch_id = (select app.current_branch_id())));
create policy sales_order_event_read on app.sales_order_event for select to authenticated
  using ((select app.permission_scope('SALES_ORDER', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('SALES_ORDER', 'XEM')) is not null and branch_id = (select app.current_branch_id())));

-- ---------------------------------------------------------------------------
-- Điểm nối của báo giá với đơn (thay hai hàm trống của DB1a): báo giá có đơn đang sống; báo giá đã chuyển đơn (R-TIEN-02).
-- "Đã chuyển đơn" khi MỌI dòng của báo giá đều nằm trong đơn đang sống.
-- ---------------------------------------------------------------------------
create or replace function app.quotation_has_live_order(p_quotation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.sales_order_line l
                   join app.quotation_line ql on ql.id = l.quotation_line_id
                  where ql.quotation_id = p_quotation_id and l.is_live);
$$;
create or replace function app.quotation_converted(p_quotation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.quotation_line ql where ql.quotation_id = p_quotation_id)
     and not exists (select from app.quotation_line ql
                      where ql.quotation_id = p_quotation_id
                        and not exists (select from app.sales_order_line l where l.quotation_line_id = ql.id and l.is_live));
$$;

-- Giấy tờ của cơ hội (TS-08, chặn gộp cơ hội, R-CRM-22): mã báo giá còn hiệu lực (Nháp, Đã gửi) và mã đơn chưa huỷ (Đ106).
create or replace function app.opportunity_sales_documents(p_opportunity_id uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(d.code order by d.code), array[]::text[])
    from (select q.code from app.quotation q where q.opportunity_id = p_opportunity_id and q.status_code in ('NHAP', 'DA_GUI')
          union all
          select o.code from app.sales_order o where o.opportunity_id = p_opportunity_id and o.status_code <> 'HUY') d;
$$;

-- Đơn đã có phiếu thu chưa (R-TIEN-38). Phiếu thu làm ở DB2 nên trả false cho tới lúc đó.
create or replace function app.order_has_receipt(p_order_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select false;
$$;

-- Kiểm lớp trên dòng đơn (R-GD-08: lớp đã duyệt, đúng môn, khối, cơ sở, còn chỗ). Bảng lớp thuộc P5b chưa có: lớp có giá trị thì báo
-- HMT_LOP_CHUA_CO_BANG. P5b thay thân hàm này bằng kiểm thật; chỗ gọi (lưu, trình, duyệt) không đổi.
create or replace function app.check_order_line_class(p_line_no integer, p_class_id uuid, p_package_id uuid, p_branch_id uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_class_id is not null then
    perform app.raise_error('HMT_LOP_CHUA_CO_BANG',
      format('Dòng %s: chưa chọn được lớp vì màn Lớp chưa có. Để trống lớp (em vào hàng chờ xếp lớp).', p_line_no));
  end if;
end;
$$;

-- Người có (phân hệ, hành động) ở cơ sở đó không: dùng cho người duyệt đã chốt (không phải người đang đăng nhập). Đ205.
create or replace function app.user_can_at_branch(p_user_id uuid, p_module text, p_action text, p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select from app.user_account a
      join app.user_role ur on ur.user_id = a.id and ur.is_active
      join app.permission p on p.role_code = ur.role_code and p.is_active and p.module_code = p_module and p.action_code = p_action
     where a.id = p_user_id and not a.is_locked
       and (p.scope_code = 'TOAN_HE_THONG' or a.branch_id = p_branch_id));
$$;

-- ---------------------------------------------------------------------------
-- Dựng dòng đơn từ danh sách dòng nhập (đơn thẳng từ cơ hội): tính tiền bằng app.price_line theo ngày p_on (R-TIEN-13, 14).
-- p_lines: mảng {kind, prospect_student_id, package_id, delivery_mode_code, quantity, discounts, gift_policy_id, class_id, enrol_start_date}.
-- Trả tổng tiền. Viết lại toàn bộ dòng của đơn (đơn Nháp).
-- ---------------------------------------------------------------------------
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
      discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id, class_id, enrol_start_date)
    values (
      p_order_id, v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), (e ->> 'prospect_student_id')::uuid,
      (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
      r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
      (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
      (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
      (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid,
      v_class, v_start)
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

-- Tính lại tổng đơn, cờ cần tích đồng ý (Đ102) và lịch đóng tiền theo điều khoản đã chọn (R-TIEN-07); gọi mỗi lần đơn Nháp đổi.
-- Điều khoản chưa chọn hoặc tổng bằng 0 thì chưa sinh lịch. Điều khoản không hợp với tổng thì báo lỗi của payment_term_amounts.
create or replace function app.order_refresh_totals(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_total bigint;
  v_ack boolean;
begin
  select * into v_o from app.sales_order where id = p_order_id;
  select coalesce(sum(line_total), 0), coalesce(bool_or(needs_acknowledgement), false)
    into v_total, v_ack from app.sales_order_line where order_id = p_order_id;
  update app.sales_order set total_amount = v_total, needs_acknowledgement = v_ack where id = p_order_id;
  delete from app.sales_order_installment where order_id = p_order_id;
  if v_o.payment_term_id is not null and v_total > 0 then
    insert into app.sales_order_installment (order_id, seq, due_days, amount)
    select p_order_id, t.seq, t.due_days, t.amount from app.payment_term_amounts(v_o.payment_term_id, v_total) t;
  end if;
end;
$$;

-- Ghi một sự kiện vào lịch sử đơn.
create or replace function app.order_add_event(
  p_order_id uuid, p_event text, p_from text, p_to text, p_reason_catalog text default null, p_reason_code text default null,
  p_note text default null, p_on_behalf boolean default false)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into app.sales_order_event (order_id, event_code, from_status, to_status, reason_catalog, reason_code, note, on_behalf)
  values (p_order_id, p_event, p_from, p_to, p_reason_catalog, p_reason_code, nullif(btrim(coalesce(p_note, '')), ''), p_on_behalf);
$$;

-- ---------------------------------------------------------------------------
-- Tạo đơn từ báo giá (R-TIEN-02, R-TIEN-14, R-CRM-16, Đ201). Một báo giá tạo được nhiều đơn, mỗi đơn lấy một số dòng.
-- Ai gọi: Đơn hàng · Tạo ở cơ sở của báo giá. Đầu vào: báo giá, danh sách số dòng muốn chuyển (null = mọi dòng chưa nằm trong đơn sống).
-- Luật: chỉ báo giá Đã gửi chuyển đơn; cơ hội phải ở L8 (chặn trong hàm); dòng sao NGUYÊN giá, chiết khấu, giờ đã đóng băng lúc Gửi,
-- không tính lại, kể cả khi báo giá quá hạn (R-TIEN-05); một dòng không nằm trong hai đơn đang sống.
-- ---------------------------------------------------------------------------
create or replace function app.create_order_from_quotation(p_quotation_id uuid, p_line_nos integer[] default null)
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
  perform app.order_refresh_totals(v_id);
  perform app.order_add_event(v_id, 'TAO', null, 'NHAP');
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', (select total_amount from app.sales_order where id = v_id));
exception
  when unique_violation then
    perform app.raise_error('HMT_DONG_DA_CO_DON', 'Có dòng của báo giá đã nằm trong một đơn đang xử lý.');
end;
$$;

-- ---------------------------------------------------------------------------
-- Tạo đơn thẳng từ cơ hội, không qua báo giá (R-TIEN-02, R-CRM-16, R-TIEN-14: tính theo bảng giá và chính sách hiệu lực NGÀY TẠO ĐƠN).
-- Ai gọi: Đơn hàng · Tạo ở cơ sở của cơ hội. Đầu vào: cơ hội, mảng dòng (khuôn như app.save_quotation, thêm class_id, enrol_start_date).
-- ---------------------------------------------------------------------------
create or replace function app.create_order_from_opportunity(p_opportunity_id uuid, p_lines jsonb)
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
  perform app.order_refresh_totals(v_id);
  perform app.order_add_event(v_id, 'TAO', null, 'NHAP');
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', (select total_amount from app.sales_order where id = v_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- Lưu đơn Nháp: điều khoản thanh toán, lớp, ngày vào lớp, và (đơn thẳng từ cơ hội) cả dòng, giờ.
-- Ai gọi: Đơn hàng · Sửa ở cơ sở của đơn. Đầu vào: p_lines và p_payment_term_id (null = giữ nguyên).
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
    perform 1 from app.payment_term t where t.id = p_payment_term_id and t.is_active;
    if not found then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy điều khoản thanh toán đang dùng.');
    end if;
    update app.sales_order set payment_term_id = p_payment_term_id where id = p_id;
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

-- Mọi em trên dòng đơn đủ họ tên và năm sinh (R-TIEN-35, Đ203): báo đúng dòng, đúng ô thiếu. Gọi lúc trình và lúc duyệt.
create or replace function app.assert_order_students_complete(p_order_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_msg text;
begin
  select string_agg(format('Dòng %s: thiếu %s của em', l.line_no,
                           concat_ws(' và ', case when coalesce(s.full_name, v.full_name) is null then 'họ tên' end,
                                             case when coalesce(s.birth_year, v.birth_year) is null then 'năm sinh' end)),
                    '; ' order by l.line_no)
    into v_msg
    from app.sales_order_line l
    left join app.prospect_student_v v on v.id = l.prospect_student_id
    left join app.student s on s.id = l.student_id
   where l.order_id = p_order_id
     and (coalesce(s.full_name, v.full_name) is null or coalesce(s.birth_year, v.birth_year) is null);
  if v_msg is not null then
    perform app.raise_error('HMT_EM_THIEU_THONG_TIN', v_msg || '. Bổ sung ở danh sách em của cơ hội.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Trình đơn: Nháp → Đã trình (R-TIEN-06, R-HT-06, Đ203, Đ205).
-- Ai gọi: Đơn hàng · Sửa ở cơ sở của đơn. Kết quả: {id, approver_id, route}.
-- Luật: cần ít nhất một dòng; mọi em đủ họ tên, năm sinh (R-TIEN-35); điều khoản thanh toán đã chọn và lịch đóng tiền hợp lệ (R-TIEN-07);
-- lớp trên dòng kiểm lại, chọn lớp thì có ngày vào lớp (R-GD-06, R-GD-08); chốt người duyệt lúc trình (R-HT-06): quản lý trực tiếp của
-- NGƯỜI LẬP, hoặc chính Trưởng cơ sở lập (tự duyệt); không có quản lý thì không trình được (HMT_KHONG_CO_QUAN_LY);
-- Đ205: người duyệt đã chốt không có quyền Duyệt đơn ở cơ sở này thì chặn trình (HMT_NGUOI_DUYET_THIEU_QUYEN).
-- ---------------------------------------------------------------------------
create or replace function app.submit_order(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_route text;
  v_approver uuid;
  l app.sales_order_line;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'SUA', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ trình được đơn Nháp.');
  end if;
  if not exists (select from app.sales_order_line where order_id = p_id) then
    perform app.raise_error('HMT_DON_KHONG_DONG', 'Đơn chưa có dòng nào, chưa trình được.');
  end if;
  -- Luật R-TIEN-35: em đủ họ tên và năm sinh.
  perform app.assert_order_students_complete(p_id);
  -- Luật R-TIEN-07: phải chọn điều khoản thanh toán; lịch đóng tiền tính lại để báo sớm nếu điều khoản không hợp tổng đơn.
  if v_o.payment_term_id is null then
    perform app.raise_error('HMT_THIEU_DIEU_KHOAN', 'Chọn điều khoản thanh toán trước khi trình đơn.');
  end if;
  perform app.order_refresh_totals(p_id);
  -- Luật R-GD-06, R-GD-08: lớp trên dòng kiểm lại lúc trình.
  for l in select * from app.sales_order_line where order_id = p_id order by line_no loop
    perform app.check_order_line_class(l.line_no, l.class_id, l.package_id, v_o.branch_id);
  end loop;
  -- Luật R-HT-06: chốt người duyệt lúc trình theo NGƯỜI LẬP.
  select r.route, r.approver_id into v_route, v_approver from app.approval_route(v_o.created_by) r;
  -- Luật Đ205: người duyệt đã chốt phải có quyền Duyệt đơn ở cơ sở này.
  if not app.user_can_at_branch(v_approver, 'SALES_ORDER', 'DUYET', v_o.branch_id) then
    perform app.raise_error('HMT_NGUOI_DUYET_THIEU_QUYEN',
      'Quản lý trực tiếp của người lập chưa có quyền Duyệt đơn hàng ở cơ sở này nên chưa trình được. Nhờ Admin đặt lại Quản lý trực tiếp hoặc cấp quyền.');
  end if;
  update app.sales_order set status_code = 'DA_TRINH', approval_route = v_route, assigned_approver_id = v_approver,
         submitted_at = now(), submitted_by = auth.uid() where id = p_id;
  perform app.order_add_event(p_id, 'TRINH', 'NHAP', 'DA_TRINH');
  return jsonb_build_object('id', p_id, 'approver_id', v_approver, 'route', v_route);
end;
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
  select string_agg(distinct format('%s (%s)', x.nm, x.yr), ', ')
    into v_dup
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
-- Duyệt đơn: Đã trình → Đã duyệt, khoá đơn (R-TIEN-03, R-TIEN-06, R-HT-06, Đ102, Đ203, Đ205).
-- Ai gọi: phải có cả hai điều kiện (Đ205): có quyền Duyệt đơn ở cơ sở, VÀ là người duyệt đã chốt lúc trình hoặc Admin duyệt thay khi vắng
-- (R-HT-01, cần xác thực hai bước). Đầu vào: p_acknowledged (người duyệt tích đồng ý khi đơn vượt trần hoặc có chính sách cần duyệt, Đ102).
-- Luật: kiểm lại mọi em đủ họ tên, năm sinh (R-TIEN-35); lớp (R-GD-08); tìm hoặc tạo hồ sơ học sinh (R-CRM-27); chốt hạn đóng từng đợt.
-- ---------------------------------------------------------------------------
create or replace function app.approve_order(p_id uuid, p_acknowledged boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_on_behalf boolean;
  l app.sales_order_line;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'DUYET', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code <> 'DA_TRINH' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt được đơn Đã trình.');
  end if;
  if not app.can_approve_as_manager(v_o.created_by, 'DON', v_o.assigned_approver_id) then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_DUYET', 'Đơn này do người duyệt đã chốt lúc trình duyệt (Admin duyệt thay khi vắng).');
  end if;
  v_on_behalf := v_o.assigned_approver_id is distinct from auth.uid();
  -- Luật Đ102: một ô tích chung cho vượt trần và chính sách cần duyệt, người tích là người duyệt.
  if v_o.needs_acknowledgement and not coalesce(p_acknowledged, false) then
    perform app.raise_error('HMT_CAN_TICH_DONG_Y', 'Đơn vượt trần chiết khấu hoặc có chính sách cần duyệt: tích đồng ý rồi mới duyệt.');
  end if;
  -- Luật R-TIEN-35: kiểm lại em đủ họ tên, năm sinh; R-GD-08: kiểm lại lớp.
  perform app.assert_order_students_complete(p_id);
  for l in select * from app.sales_order_line where order_id = p_id order by line_no loop
    perform app.check_order_line_class(l.line_no, l.class_id, l.package_id, v_o.branch_id);
  end loop;
  -- Trigger khoá dòng cho phép riêng việc gắn hồ sơ học sinh và chốt hạn đóng trong lúc duyệt (hmt.order_approve).
  perform set_config('hmt.order_approve', 'on', true);
  -- Luật R-CRM-27: tìm hoặc tạo hồ sơ học sinh; trùng tên và năm sinh trong đơn thì chặn (KD6).
  perform app.order_link_students(p_id, v_o.parent_id, v_o.branch_id);
  -- Lịch đóng tiền đã tính lúc lưu và lúc trình (đơn khoá từ khi trình): chốt hạn đóng (ngày duyệt + số ngày của đợt).
  update app.sales_order_installment set due_date = v_today + due_days where order_id = p_id;
  perform set_config('hmt.order_approve', '', true);
  update app.sales_order set status_code = 'DA_DUYET', approved_at = now(), approved_by = auth.uid(),
         approved_on_behalf = v_on_behalf, acknowledged = coalesce(p_acknowledged, false) where id = p_id;
  perform app.order_add_event(p_id, 'DUYET', 'DA_TRINH', 'DA_DUYET', null, null,
                              case when v_on_behalf then 'Admin duyệt thay'
                                   when v_o.approval_route = 'TU_DUYET' then 'Tự duyệt' end, v_on_behalf);
  return jsonb_build_object('id', p_id, 'code', v_o.code, 'on_behalf', v_on_behalf);
end;
$$;

-- ---------------------------------------------------------------------------
-- Từ chối đơn: Đã trình → Nháp, kèm lý do (R-TIEN-06, R-HT-04); lịch sử giữ lần từ chối. Ai gọi: người duyệt (như duyệt đơn).
-- Lý do từ danh mục "Lý do từ chối" áp dụng cho đơn; "Khác" bắt ghi chú. Người duyệt chốt lại lúc trình lại.
-- ---------------------------------------------------------------------------
create or replace function app.reject_order(p_id uuid, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_item app.catalog_item;
  v_on_behalf boolean;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'DUYET', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code <> 'DA_TRINH' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ từ chối được đơn Đã trình.');
  end if;
  if not app.can_approve_as_manager(v_o.created_by, 'DON', v_o.assigned_approver_id) then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_DUYET', 'Đơn này do người duyệt đã chốt lúc trình xử lý (Admin thay khi vắng).');
  end if;
  select * into v_item from app.catalog_item
   where catalog_code = 'REJECT_REASON' and code = p_reason_code and is_active
     and (cardinality(applies_to) = 0 or 'DON' = any (applies_to));
  if v_item.id is null then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn lý do từ chối dành cho đơn hàng.');
  end if;
  if v_item.requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn "Khác" thì ghi chú lý do.');
  end if;
  v_on_behalf := v_o.assigned_approver_id is distinct from auth.uid();
  update app.sales_order set status_code = 'NHAP', approval_route = null, assigned_approver_id = null,
         submitted_at = null, submitted_by = null where id = p_id;
  perform app.order_add_event(p_id, 'TU_CHOI', 'DA_TRINH', 'NHAP', 'REJECT_REASON', p_reason_code, p_note, v_on_behalf);
end;
$$;

-- ---------------------------------------------------------------------------
-- Huỷ đơn (R-TIEN-38, Đ202, Đ204): Nháp, Đã trình, Đã duyệt → Huỷ; không xoá cứng.
-- Ai gọi: có quyền Huỷ đơn ở cơ sở (Sale, CSKH, Trưởng cơ sở, Admin) VÀ:
--   đơn Nháp: chỉ NGƯỜI LẬP huỷ được;
--   đơn Đã trình, Đã duyệt: người duyệt đã chốt lúc trình huỷ được, Admin huỷ thay khi vắng (như R-HT-06, cần xác thực hai bước).
-- Chỉ huỷ được khi đơn chưa có phiếu thu. Bắt buộc lý do từ danh mục "Lý do huỷ đơn" ("Khác" bắt ghi chú).
-- Đơn huỷ trả các dòng về báo giá (tắt cờ đang sống, R-TIEN-02).
-- ---------------------------------------------------------------------------
create or replace function app.cancel_order(p_id uuid, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_o app.sales_order;
  v_item app.catalog_item;
  v_on_behalf boolean := false;
begin
  select * into v_o from app.sales_order where id = p_id for update;
  if v_o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'HUY', v_o.branch_id);
  perform app.require_feature('BAN_HANG', v_o.branch_id); -- Luật Đ173
  if v_o.status_code = 'HUY' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Đơn này đã huỷ.');
  end if;
  if v_o.status_code = 'NHAP' then
    -- Luật R-TIEN-38: đơn Nháp chỉ người lập huỷ.
    if v_o.created_by is distinct from auth.uid() then
      perform app.raise_error('HMT_KHONG_DUOC_HUY_DON', 'Đơn Nháp chỉ người lập huỷ được.');
    end if;
  else
    -- Luật R-TIEN-38: đơn Đã trình, Đã duyệt do người duyệt đã chốt huỷ (Admin thay khi vắng).
    if not app.can_approve_as_manager(v_o.created_by, 'DON', v_o.assigned_approver_id) then
      perform app.raise_error('HMT_KHONG_DUOC_HUY_DON', 'Đơn đã trình hoặc đã duyệt chỉ người duyệt đã chốt lúc trình huỷ được (Admin huỷ thay khi vắng).');
    end if;
    v_on_behalf := v_o.assigned_approver_id is distinct from auth.uid();
  end if;
  -- Luật R-TIEN-38: chỉ huỷ khi đơn chưa có phiếu thu.
  if app.order_has_receipt(p_id) then
    perform app.raise_error('HMT_DON_DA_CO_PHIEU_THU', 'Đơn đã có phiếu thu, không huỷ được.');
  end if;
  select * into v_item from app.catalog_item
   where catalog_code = 'ORDER_CANCEL_REASON' and code = p_reason_code and is_active;
  if v_item.id is null then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn lý do huỷ đơn.');
  end if;
  if v_item.requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn "Khác" thì ghi chú lý do.');
  end if;
  update app.sales_order set status_code = 'HUY', cancel_reason_code = p_reason_code,
         cancel_note = nullif(btrim(coalesce(p_note, '')), ''), cancelled_at = now(), cancelled_by = auth.uid() where id = p_id;
  -- Trả dòng về báo giá: tắt cờ đang sống (trigger khoá cho phép riêng việc này).
  perform set_config('hmt.order_cancel', 'on', true);
  update app.sales_order_line set is_live = false where order_id = p_id;
  perform set_config('hmt.order_cancel', '', true);
  perform app.order_add_event(p_id, 'HUY', v_o.status_code, 'HUY', 'ORDER_CANCEL_REASON', p_reason_code, p_note, v_on_behalf);
end;
$$;

select set_config('hmt.migration', '', false);

revoke execute on function app.tg_sales_order_child_branch(), app.tg_sales_order_child_lock(), app.tg_sales_order_event_append_only(),
  app.tg_sales_order_status_flow(), app.tg_sales_order_search_text(), app.sales_order_search_text(app.sales_order),
  app.order_has_receipt(uuid), app.check_order_line_class(integer, uuid, uuid, uuid),
  app.user_can_at_branch(uuid, text, text, uuid),
  app.order_write_priced_lines(uuid, uuid, uuid, jsonb, date), app.order_refresh_totals(uuid),
  app.order_add_event(uuid, text, text, text, text, text, text, boolean), app.assert_order_students_complete(uuid),
  app.order_link_students(uuid, uuid, uuid) from public, anon, authenticated;
revoke execute on function app.create_order_from_quotation(uuid, integer[]), app.create_order_from_opportunity(uuid, jsonb),
  app.save_order(uuid, jsonb, uuid), app.submit_order(uuid), app.approve_order(uuid, boolean),
  app.reject_order(uuid, text, text), app.cancel_order(uuid, text, text) from public, anon;
grant execute on function app.create_order_from_quotation(uuid, integer[]), app.create_order_from_opportunity(uuid, jsonb),
  app.save_order(uuid, jsonb, uuid), app.submit_order(uuid), app.approve_order(uuid, boolean),
  app.reject_order(uuid, text, text), app.cancel_order(uuid, text, text) to authenticated;
