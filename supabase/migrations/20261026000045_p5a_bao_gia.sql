-- ===========================================================================
-- P5a-DB1a: báo giá (QĐ-Đ83, Đ93, Đ101, Đ102, Đ105, Đ106, Đ169 đến Đ174; R-CRM-19, 20; R-TIEN-02, 05, 13, 14, 29, 30, 35, 36).
-- Bảng báo giá, dòng, chiết khấu từng dòng; hàm tính tiền dùng chung (app.price_line, DB1b dùng lại); lưu, gửi, từ chối, huỷ;
-- danh sách, bản ghi, xuất; điểm nối giấy tờ của cơ hội (Đ106).
-- Quy ước: báo giá Nháp tính giá theo bảng giá hiệu lực LÚC LƯU; bấm Gửi thì đóng băng đơn giá, chiết khấu, số giờ (Đ169).
-- Dòng chọn em trong danh sách em của cơ hội (prospect_student_id), không có em mới trên dòng (Đ83).
-- Chưa có công tắc tính năng BAN_HANG trong hàm (Đ173): spec 06 chưa có tên công tắc, chờ anh quyết.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Danh mục tên hiển thị trạng thái báo giá (spec 06 mục 30). "Đã chuyển đơn" không lưu: tính từ dòng (R-TIEN-02).
-- ---------------------------------------------------------------------------
insert into app.catalog (code, name, kind, parent_catalog, linked_catalog, description, sort_order) values
  ('QUOTATION_STATUS', 'Trạng thái báo giá', 'HE_THONG', null, null,
   'Nháp, Đã gửi, Đã chuyển đơn (tính từ dòng, không lưu), Từ chối, Huỷ. Không có Hết hạn (R-TIEN-05).', 63);
insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note) values
  ('QUOTATION_STATUS', 'NHAP', 'Nháp', 1, false),
  ('QUOTATION_STATUS', 'DA_GUI', 'Đã gửi', 2, false),
  ('QUOTATION_STATUS', 'DA_CHUYEN_DON', 'Đã chuyển đơn', 3, false),
  ('QUOTATION_STATUS', 'TU_CHOI', 'Từ chối', 4, false),
  ('QUOTATION_STATUS', 'HUY', 'Huỷ', 5, false);

-- ---------------------------------------------------------------------------
-- Báo giá
-- ---------------------------------------------------------------------------
create table app.quotation (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  branch_id uuid not null references app.branch (id),
  opportunity_id uuid not null references app.opportunity (id),
  parent_id uuid not null references app.parent (id),
  status_catalog text not null default 'QUOTATION_STATUS' check (status_catalog = 'QUOTATION_STATUS'),
  status_code text not null default 'NHAP' check (status_code in ('NHAP', 'DA_GUI', 'TU_CHOI', 'HUY')),
  -- Ngày (giờ Việt Nam) tra bảng giá của lần Lưu gần nhất (Đ169).
  priced_on date not null,
  valid_until date,
  sent_at timestamptz,
  sent_by uuid,
  reject_reason_catalog text not null default 'REJECT_REASON' check (reject_reason_catalog = 'REJECT_REASON'),
  reject_reason_code text,
  reject_note text,
  rejected_at timestamptz,
  rejected_by uuid,
  cancel_note text,
  cancelled_at timestamptz,
  cancelled_by uuid,
  total_amount bigint not null default 0 check (total_amount >= 0),
  legacy_ref text,
  search_text text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.quotation is 'Báo giá (R-TIEN-01). Mã cấp lúc Lưu (R-CRM-19). Hạn hiệu lực chỉ để hiển thị (R-TIEN-05). Ghi chỉ qua hàm.';
-- Chỉ mục (lý do):
-- danh sách theo cơ sở, trạng thái, mới nhất (RLS và lọc);
create index quotation_branch_status_idx on app.quotation (branch_id, status_code, created_at desc);
-- danh sách mặc định (không lọc trạng thái) theo cơ sở, mới nhất: đi thẳng theo chỉ mục, không sắp xếp lại;
create index quotation_branch_created_idx on app.quotation (branch_id, created_at desc, id);
-- tab Báo giá của cơ hội (TS-08) và của phụ huynh (KH-02), khoá ngoại;
create index quotation_opportunity_idx on app.quotation (opportunity_id);
create index quotation_parent_idx on app.quotation (parent_id);
-- bộ lọc "của tôi";
create index quotation_creator_idx on app.quotation (created_by, created_at desc);
-- tìm mã, tên phụ huynh, SĐT, tên em (D17).
create index quotation_search_idx on app.quotation using gin (search_text extensions.gin_trgm_ops);

select app.apply_standard('app.quotation');

-- ---------------------------------------------------------------------------
-- Dòng báo giá và chiết khấu từng dòng. Giá trị tiền, giờ, chiết khấu CHỤP LẠI lúc lưu (R-TIEN-14).
-- Dòng nháp được viết lại mỗi lần Lưu nên bảng dòng cho phép xoá trong báo giá Nháp (trigger dưới); sau Gửi thì khoá.
-- ---------------------------------------------------------------------------
create table app.quotation_line (
  id uuid primary key default gen_random_uuid(),
  quotation_id uuid not null references app.quotation (id),
  branch_id uuid not null references app.branch (id),
  line_no integer not null check (line_no >= 1),
  line_kind text not null default 'ENROL' check (line_kind in ('ENROL', 'GIFT')),
  -- Em trong danh sách em của cơ hội (Đ83). student_id chừa cho báo giá từ phiếu tái tục (em của ghi danh, Đ84, Đ93).
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
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (quotation_id, line_no),
  check (num_nonnulls(prospect_student_id, student_id) >= 1),
  check (line_kind <> 'GIFT' or (gift_policy_id is not null and unit_price = 0 and line_total = 0)),
  check (line_kind <> 'ENROL' or gift_policy_id is null)
);
comment on table app.quotation_line is 'Dòng báo giá: một em, một gói, một hình thức; tiền và giờ chụp lại lúc lưu.';
-- Chỉ mục (lý do): unique (quotation_id, line_no) là khoá ngoại và thứ tự dòng; RLS theo cơ sở; khoá ngoại tới em (gộp cơ hội chuyển dòng em),
-- gói, chính sách quà.
create index quotation_line_branch_idx on app.quotation_line (branch_id);
create index quotation_line_prospect_idx on app.quotation_line (prospect_student_id) where prospect_student_id is not null;
create index quotation_line_student_idx on app.quotation_line (student_id) where student_id is not null;
create index quotation_line_package_idx on app.quotation_line (package_id);
create index quotation_line_gift_policy_idx on app.quotation_line (gift_policy_id) where gift_policy_id is not null;

create table app.quotation_line_discount (
  id uuid primary key default gen_random_uuid(),
  line_id uuid not null references app.quotation_line (id),
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
comment on table app.quotation_line_discount is 'Chính sách chiết khấu áp trên dòng (chụp lại mã, tên, giá trị đã áp). Nhiều chính sách % cộng dồn; tối đa một chính sách tặng giờ (Đ174).';
-- Chỉ mục (lý do): unique (line_id, policy_id) là khoá ngoại; chính sách (tra dòng đã dùng); cơ sở cho RLS.
create index quotation_line_discount_policy_idx on app.quotation_line_discount (policy_id);
create index quotation_line_discount_branch_idx on app.quotation_line_discount (branch_id);

-- Cơ sở của dòng luôn là cơ sở của báo giá.
create or replace function app.tg_quotation_child_branch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_TABLE_NAME = 'quotation_line' then
    select q.branch_id into new.branch_id from app.quotation q where q.id = new.quotation_id;
  else
    select l.branch_id into new.branch_id from app.quotation_line l where l.id = new.line_id;
  end if;
  return new;
end;
$$;
create trigger quotation_line_branch before insert on app.quotation_line
  for each row execute function app.tg_quotation_child_branch();
create trigger quotation_line_discount_branch before insert on app.quotation_line_discount
  for each row execute function app.tg_quotation_child_branch();

-- Dòng và chiết khấu chỉ xoá được khi báo giá còn Nháp (viết lại nháp mỗi lần Lưu); sau Gửi thì khoá (R-TIEN-14, Đ169).
create or replace function app.tg_quotation_child_lock()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_status text;
begin
  if TG_TABLE_NAME = 'quotation_line' then
    select q.status_code into v_status from app.quotation q where q.id = coalesce(new.quotation_id, old.quotation_id);
  else
    select q.status_code into v_status
      from app.quotation_line l join app.quotation q on q.id = l.quotation_id where l.id = coalesce(new.line_id, old.line_id);
  end if;
  if v_status is distinct from 'NHAP' and not app.is_migration() then
    perform app.raise_error('HMT_BAO_GIA_DA_KHOA', 'Báo giá đã gửi: dòng và chiết khấu không sửa được.');
  end if;
  return coalesce(new, old);
end;
$$;
create trigger quotation_line_lock before update or delete on app.quotation_line
  for each row execute function app.tg_quotation_child_lock();
create trigger quotation_line_discount_lock before update or delete on app.quotation_line_discount
  for each row execute function app.tg_quotation_child_lock();

select app.apply_standard('app.quotation_line');
select app.apply_standard('app.quotation_line_discount');
-- apply_standard chặn xoá cứng; hai bảng dòng được xoá trong báo giá Nháp qua trigger khoá ở trên.
drop trigger quotation_line_no_delete on app.quotation_line;
drop trigger quotation_line_discount_no_delete on app.quotation_line_discount;

create or replace function app.quotation_search_text(p_quotation app.quotation)
returns text
language sql
stable
set search_path = ''
as $$
  select app.fold_text(p_quotation.code || ' ' || coalesce((select pa.full_name || ' ' || pa.phone from app.parent pa
                                                              where pa.id = p_quotation.parent_id), '')
                       || ' ' || coalesce((select string_agg(distinct v.full_name, ' ')
                                            from app.quotation_line l
                                            join app.prospect_student_v v on v.id = l.prospect_student_id
                                           where l.quotation_id = p_quotation.id), '')
                       || ' ' || coalesce(p_quotation.legacy_ref, ''));
$$;

-- Ô tìm kiếm của báo giá.
create or replace function app.tg_quotation_search_text()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.search_text := app.quotation_search_text(new);
  return new;
end;
$$;
create trigger quotation_search_text before insert or update on app.quotation
  for each row execute function app.tg_quotation_search_text();

-- Chuyển trạng thái chỉ theo bảng cho phép (R-TIEN-05, 06; Đ171). Hàm nghiệp vụ kiểm lần nữa với câu tiếng Việt.
create or replace function app.tg_quotation_status_flow()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_OP = 'UPDATE' and new.status_code is distinct from old.status_code and not app.is_migration() then
    if not (old.status_code = 'NHAP' and new.status_code in ('DA_GUI', 'HUY')
            or old.status_code = 'DA_GUI' and new.status_code in ('TU_CHOI', 'HUY')
            or old.status_code = 'TU_CHOI' and new.status_code = 'HUY') then
      perform app.raise_error('HMT_SAI_TRANG_THAI', 'Báo giá không chuyển được sang trạng thái này.');
    end if;
  end if;
  return new;
end;
$$;
create trigger quotation_status_flow before update on app.quotation
  for each row execute function app.tg_quotation_status_flow();

-- Mã và cơ hội của báo giá không đổi.
create trigger quotation_code_immutable before update on app.quotation
  for each row execute function app.tg_code_immutable();

-- ---------------------------------------------------------------------------
-- RLS: đọc theo quyền Báo giá · Xem (toàn hệ thống hoặc đúng cơ sở); ghi chỉ qua hàm.
-- ---------------------------------------------------------------------------
alter table app.quotation enable row level security;
alter table app.quotation_line enable row level security;
alter table app.quotation_line_discount enable row level security;
revoke all on app.quotation, app.quotation_line, app.quotation_line_discount from public, anon, authenticated;
grant select on app.quotation, app.quotation_line, app.quotation_line_discount to authenticated;
create policy quotation_read on app.quotation for select to authenticated
  using ((select app.permission_scope('QUOTATION', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('QUOTATION', 'XEM')) is not null and branch_id = (select app.current_branch_id())));
create policy quotation_line_read on app.quotation_line for select to authenticated
  using ((select app.permission_scope('QUOTATION', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('QUOTATION', 'XEM')) is not null and branch_id = (select app.current_branch_id())));
create policy quotation_line_discount_read on app.quotation_line_discount for select to authenticated
  using ((select app.permission_scope('QUOTATION', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('QUOTATION', 'XEM')) is not null and branch_id = (select app.current_branch_id())));

-- Báo giá đổi tên phụ huynh, tên em thì tìm kiếm tính lại.
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
  end if;
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Điểm nối với đơn (DB1b điền thật): báo giá có đơn đang sống, báo giá đã chuyển đơn.
-- ---------------------------------------------------------------------------
create or replace function app.quotation_has_live_order(p_quotation_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select false;
$$;
create or replace function app.quotation_converted(p_quotation_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select false;
$$;

-- Giấy tờ của cơ hội (TS-08, chặn gộp cơ hội, R-CRM-22): mã báo giá còn hiệu lực, trừ báo giá Từ chối và Huỷ (Đ106). DB1b thêm mã đơn.
create or replace function app.opportunity_sales_documents(p_opportunity_id uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(q.code order by q.code), array[]::text[])
    from app.quotation q
   where q.opportunity_id = p_opportunity_id and q.status_code in ('NHAP', 'DA_GUI');
$$;

-- ---------------------------------------------------------------------------
-- Tính tiền một dòng. Là nơi duy nhất tính tiền báo giá và đơn (R-TIEN-13, 29, 36); DB1b gọi lại.
-- ---------------------------------------------------------------------------
-- Chính sách chiết khấu áp trên dòng: kiểm hiệu lực, loại gói, cơ sở, mức tối đa; tối đa MỘT chính sách tặng giờ (Đ174).
-- Đầu vào: số dòng (để báo lỗi), loại gói, cơ sở, ngày tính, p_discounts: mảng {policy_id, value} (PERCENT: phần trăm, bỏ trống thì
-- dùng mức tối đa; chính sách "áp đúng mức" luôn dùng mức tối đa; GIFT_HOURS: số giờ tặng).
-- Kết quả: {percent, gift_hours, needs_acknowledgement, applied: [...]}.
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
    v_value := case when d.fixed_value then d.max_value else nullif(e ->> 'value', '')::numeric end;
    v_value := coalesce(v_value, case when d.kind = 'PERCENT' then d.max_value end);
    if v_value is null or v_value <= 0 or v_value > d.max_value then
      perform app.raise_error('HMT_CHIET_KHAU_VUOT_MUC',
        format('Dòng %s: mức của chính sách "%s" phải lớn hơn 0 và không quá %s.', p_line_no, d.name, d.max_value));
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

-- Tính tiền một dòng báo giá hoặc đơn.
-- Đầu vào: số dòng, loại (ENROL hoặc GIFT), gói, hình thức, số lượng mua, chính sách chiết khấu (jsonb), chính sách quà (GIFT), cơ sở, ngày.
-- Kết quả: jsonb đủ cột chụp lại của dòng (đơn giá, số lượng, đơn vị, thành tiền, % chiết khấu, tiền chiết khấu, cờ vượt trần, cờ cần tích).
-- Luật: R-TIEN-10, 12 (giá theo hình thức; hình thức không có giá thì lỗi); R-TIEN-13, 14 (máy chủ tính, giá hiệu lực tại ngày tính);
-- R-TIEN-29 (chiết khấu % cộng dồn; giờ tặng quy ra % = giờ tặng ÷ giờ mua và tính vào trần; vượt trần là cảnh báo, cờ over_cap);
-- R-TIEN-30 (quà tặng giá 0, ngoài trần); R-TIEN-36 (thành tiền = số lượng × đơn giá); Đ101 (đơn vị theo loại gói);
-- Đ102 (một cờ cần tích chung cho vượt trần và chính sách cần duyệt); Đ172 (tiền chiết khấu làm tròn xuống đồng).
create or replace function app.price_line(
  p_line_no integer, p_kind text, p_package_id uuid, p_mode text, p_quantity numeric, p_discounts jsonb,
  p_gift_policy_id uuid, p_branch_id uuid, p_on date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  pkg app.sales_package;
  gp app.gift_policy;
  v_price bigint;
  v_mode text := p_mode;
  v_disc jsonb;
  v_percent numeric := 0;
  v_gift_hours numeric := 0;
  v_gift_percent numeric := 0;
  v_cap numeric := app.get_setting('discount_total_cap_percent')::numeric;
  v_gross bigint;
  v_discount_amount bigint;
  v_over boolean := false;
  v_ack boolean := false;
  v_applied jsonb := '[]'::jsonb;
begin
  if p_quantity is null or p_quantity <= 0 then
    perform app.raise_error('HMT_DONG_THIEU', format('Dòng %s: nhập số lượng lớn hơn 0.', p_line_no));
  end if;
  if p_kind = 'GIFT' then
    -- Luật R-TIEN-30: quà tặng là gói dịch vụ, tài liệu của chính sách quà, giá 0, số lượng không quá mức tối đa, ngoài trần chiết khấu.
    select * into gp from app.gift_policy where id = p_gift_policy_id;
    if gp.id is null then
      perform app.raise_error('HMT_DONG_THIEU', format('Dòng %s: chọn chính sách quà tặng.', p_line_no));
    end if;
    if not gp.is_active or gp.valid_from > p_on or (gp.valid_to is not null and gp.valid_to < p_on)
       or (cardinality(gp.branch_ids) > 0 and not p_branch_id = any (gp.branch_ids)) then
      perform app.raise_error('HMT_CHINH_SACH_KHONG_AP_DUNG', format('Dòng %s: chính sách quà "%s" không áp dụng cho cơ sở hoặc ngày này.', p_line_no, gp.name));
    end if;
    if p_quantity > gp.max_quantity then
      perform app.raise_error('HMT_CHIET_KHAU_VUOT_MUC', format('Dòng %s: số lượng quà không quá %s.', p_line_no, gp.max_quantity));
    end if;
    select * into pkg from app.sales_package where id = gp.gift_package_id;
    v_price := 0;
    v_mode := 'OFF';
    v_ack := gp.requires_approval;
  else
    select * into pkg from app.sales_package where id = p_package_id;
    if pkg.id is null then
      perform app.raise_error('HMT_DONG_THIEU', format('Dòng %s: chọn gói.', p_line_no));
    end if;
    if not pkg.is_active then
      perform app.raise_error('HMT_GOI_DA_NGUNG', format('Dòng %s: gói %s đã ngừng bán.', p_line_no, pkg.code));
    end if;
    -- Luật R-TIEN-10, 12: giá theo hình thức; giá trống nghĩa là gói không bán hình thức đó.
    v_price := app.package_price_at(pkg.id, v_mode, p_on);
    if v_mode is null or v_price is null then
      perform app.raise_error('HMT_HINH_THUC_KHONG_CO_GIA', format('Dòng %s: gói %s không bán hình thức này.', p_line_no, pkg.code));
    end if;
    v_disc := app.price_apply_discounts(p_line_no, pkg.package_type_code, p_branch_id, p_on, p_discounts);
    v_percent := (v_disc ->> 'percent')::numeric;
    v_gift_hours := (v_disc ->> 'gift_hours')::numeric;
    v_applied := v_disc -> 'applied';
    v_ack := (v_disc ->> 'needs_acknowledgement')::boolean;
    -- Luật R-TIEN-29, 36: giờ tặng quy ra % = giờ tặng ÷ giờ mua, tính vào trần; vượt trần là cảnh báo, không chặn lưu.
    v_gift_percent := round(v_gift_hours / p_quantity * 100, 2); -- allow-number: quy ra phần trăm
    v_over := (v_percent + v_gift_percent) > v_cap;
    v_ack := v_ack or v_over;
  end if;
  v_gross := round(p_quantity * v_price)::bigint;
  -- Luật Đ172: tiền chiết khấu làm tròn xuống đồng.
  v_discount_amount := floor(v_gross * v_percent / 100)::bigint; -- allow-number: phần trăm
  return jsonb_build_object(
    'package_id', pkg.id, 'package_code', pkg.code, 'package_name', pkg.name, 'package_type_code', pkg.package_type_code,
    'delivery_mode_code', v_mode, 'unit_code', app.package_unit(pkg.package_type_code),
    'quantity', p_quantity, 'gifted_quantity', v_gift_hours, 'unit_price', v_price, 'gross_amount', v_gross,
    'discount_percent', v_percent, 'gift_percent', v_gift_percent, 'discount_amount', v_discount_amount,
    'line_total', v_gross - v_discount_amount, 'over_cap', v_over, 'needs_acknowledgement', v_ack,
    'gift_policy_id', case when p_kind = 'GIFT' then gp.id end, 'discounts', v_applied);
end;
$$;

-- Dòng chọn em trong danh sách em của cơ hội (Đ83). Em thiếu họ tên hoặc năm sinh vẫn cho lưu báo giá Nháp (Đ93, Đ170 chặn lúc Gửi).
create or replace function app.validate_line_student(p_line_no integer, p_opportunity_id uuid, p_prospect_student_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_prospect_student_id is null then
    perform app.raise_error('HMT_DONG_THIEU', format('Dòng %s: chọn học sinh.', p_line_no));
  end if;
  if not exists (select from app.prospect_student ps where ps.id = p_prospect_student_id and ps.opportunity_id = p_opportunity_id) then
    perform app.raise_error('HMT_EM_NGOAI_DANH_SACH',
      format('Dòng %s: em không nằm trong danh sách em của cơ hội. Chưa thấy em? Thêm em ở cơ hội.', p_line_no));
  end if;
end;
$$;

-- Mọi dòng phải có em đủ họ tên và năm sinh (Gửi báo giá, trình đơn): báo đúng dòng, đúng ô thiếu (Đ170).
create or replace function app.assert_line_students_complete(p_quotation_id uuid)
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
                           concat_ws(' và ', case when v.full_name is null then 'họ tên' end,
                                             case when v.birth_year is null then 'năm sinh' end)),
                    '; ' order by l.line_no)
    into v_msg
    from app.quotation_line l
    join app.prospect_student_v v on v.id = l.prospect_student_id
   where l.quotation_id = p_quotation_id and (v.full_name is null or v.birth_year is null);
  if v_msg is not null then
    perform app.raise_error('HMT_EM_THIEU_THONG_TIN', v_msg || '. Bổ sung ở danh sách em của cơ hội.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Lưu báo giá (tạo mới hoặc sửa Nháp). R-CRM-19: bấm Lưu mới tạo bản ghi và cấp mã (BG-CS1-2610-0001). R-CRM-20: cơ hội ở giai đoạn nào cũng được.
-- Ai gọi: Báo giá · Tạo (tạo) hoặc Sửa (sửa) ở cơ sở của cơ hội.
-- Đầu vào: p_id (null = tạo), p_opportunity_id (khi tạo), p_lines: mảng
--   {kind: ENROL|GIFT, prospect_student_id, package_id, delivery_mode_code, quantity, discounts: [{policy_id, value}], gift_policy_id}.
-- Kết quả: {id, code, total_amount, warnings: [{code, line_no, message}]} (vượt trần chỉ cảnh báo, D3).
-- Luật: Đ169 (tính lại toàn bộ theo bảng giá hiệu lực lúc lưu), R-TIEN-13, 14, 29, 35 và các luật của app.price_line.
-- Mỗi lần Lưu viết lại các dòng của báo giá Nháp; sau Gửi không lưu được.
-- ---------------------------------------------------------------------------
create or replace function app.save_quotation(p_id uuid, p_opportunity_id uuid, p_lines jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q app.quotation;
  v_opp app.opportunity;
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
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
    end if;
    -- Luật: quyền tạo báo giá ở cơ sở của cơ hội; cơ hội đã gộp thì không tạo (R-CRM-22).
    perform app.assert_can('QUOTATION', 'TAO', v_opp.branch_id);
    -- Luật Đ173: phân hệ Bán hàng phải bật ở cơ sở.
    perform app.require_feature('BAN_HANG', v_opp.branch_id);
    if v_opp.record_status = 'DA_GOP' then
      perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không tạo báo giá được.');
    end if;
    select code into v_branch_code from app.branch where id = v_opp.branch_id;
    v_code := app.issue_document_number('BG', v_branch_code);
    insert into app.quotation (code, branch_id, opportunity_id, parent_id, priced_on)
    values (v_code, v_opp.branch_id, v_opp.id, v_opp.parent_id, v_on)
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
    delete from app.quotation_line_discount where line_id in (select id from app.quotation_line where quotation_id = v_id);
    delete from app.quotation_line where quotation_id = v_id;
  end if;

  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_n := v_n + 1;
    -- Luật Đ83: học sinh chọn trong danh sách em của cơ hội.
    perform app.validate_line_student(v_n, v_opp.id, nullif(e ->> 'prospect_student_id', '')::uuid);
    r := app.price_line(v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), nullif(e ->> 'package_id', '')::uuid,
                        e ->> 'delivery_mode_code', nullif(e ->> 'quantity', '')::numeric, e -> 'discounts',
                        nullif(e ->> 'gift_policy_id', '')::uuid, v_opp.branch_id, v_on);
    insert into app.quotation_line (
      quotation_id, line_no, line_kind, prospect_student_id, package_id, package_code, package_name, package_type_code,
      delivery_mode_code, unit_code, quantity, gifted_quantity, unit_price, gross_amount, discount_percent, gift_percent,
      discount_amount, line_total, over_cap, needs_acknowledgement, gift_policy_id)
    values (
      v_id, v_n, coalesce(nullif(e ->> 'kind', ''), 'ENROL'), (e ->> 'prospect_student_id')::uuid,
      (r ->> 'package_id')::uuid, r ->> 'package_code', r ->> 'package_name', r ->> 'package_type_code',
      r ->> 'delivery_mode_code', r ->> 'unit_code', (r ->> 'quantity')::numeric, (r ->> 'gifted_quantity')::numeric,
      (r ->> 'unit_price')::bigint, (r ->> 'gross_amount')::bigint, (r ->> 'discount_percent')::numeric,
      (r ->> 'gift_percent')::numeric, (r ->> 'discount_amount')::bigint, (r ->> 'line_total')::bigint,
      (r ->> 'over_cap')::boolean, (r ->> 'needs_acknowledgement')::boolean, nullif(r ->> 'gift_policy_id', '')::uuid)
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
        'message', format('Dòng %s: chiết khấu (gồm giờ tặng) vượt trần %s%%. Đơn cần người duyệt tích đồng ý.', v_n,
                          app.get_setting('discount_total_cap_percent')));
    end if;
  end loop;

  update app.quotation set priced_on = v_on, total_amount = v_total where id = v_id;
  select code into v_code from app.quotation where id = v_id;
  return jsonb_build_object('id', v_id, 'code', v_code, 'total_amount', v_total, 'warnings', v_warnings);
end;
$$;

-- ---------------------------------------------------------------------------
-- Gửi báo giá: Nháp → Đã gửi, TÍNH LẠI mọi dòng theo giá và chính sách hiệu lực của NGÀY GỬI rồi đóng băng (Đ169, Đ175, R-TIEN-14).
-- Không tự gửi tin cho phụ huynh.
-- Ai gọi: Báo giá · Sửa, ở cơ sở có bật phân hệ Bán hàng (Đ173).
-- Kết quả: {id, total_amount, previous_total, warnings: [{code, message}]}; tổng sau tính lại khác lúc Lưu thì có cảnh báo HMT_TONG_TIEN_DOI.
-- Luật: cần ít nhất một dòng; mọi em đủ họ tên và năm sinh (Đ170); dùng đầu vào đã lưu (gói, hình thức, số lượng, chính sách);
-- gói ngừng bán, hình thức không còn giá, chính sách hết hiệu lực hoặc không áp dụng thì chặn Gửi, báo đúng dòng (mã lỗi của price_line);
-- hạn = ngày Gửi + quotation_validity_days (R-TIEN-05).
-- ---------------------------------------------------------------------------
create or replace function app.send_quotation(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q app.quotation;
  v_on date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_old_total bigint;
  v_new_total bigint := 0;
  v_warnings jsonb := '[]'::jsonb;
  l app.quotation_line;
  r jsonb;
  d jsonb;
  v_disc jsonb;
begin
  select * into v_q from app.quotation where id = p_id for update;
  if v_q.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy báo giá.');
  end if;
  perform app.assert_can('QUOTATION', 'SUA', v_q.branch_id);
  perform app.require_feature('BAN_HANG', v_q.branch_id); -- Luật Đ173
  if v_q.status_code <> 'NHAP' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ gửi được báo giá Nháp.');
  end if;
  if not exists (select from app.quotation_line where quotation_id = p_id) then
    perform app.raise_error('HMT_BAO_GIA_KHONG_DONG', 'Báo giá chưa có dòng nào, chưa gửi được.');
  end if;
  perform app.assert_line_students_complete(p_id);
  v_old_total := v_q.total_amount;
  -- Luật Đ175: tính lại từng dòng theo giá và chính sách hiệu lực ngày Gửi; lỗi của price_line chặn Gửi và nêu đúng dòng.
  for l in select * from app.quotation_line where quotation_id = p_id order by line_no loop
    select coalesce(jsonb_agg(jsonb_build_object('policy_id', x.policy_id, 'value', x.applied_value)), '[]'::jsonb)
      into v_disc from app.quotation_line_discount x where x.line_id = l.id;
    r := app.price_line(l.line_no, l.line_kind, l.package_id, l.delivery_mode_code, l.quantity, v_disc,
                        l.gift_policy_id, v_q.branch_id, v_on);
    update app.quotation_line set
      unit_price = (r ->> 'unit_price')::bigint, gross_amount = (r ->> 'gross_amount')::bigint,
      discount_percent = (r ->> 'discount_percent')::numeric, gift_percent = (r ->> 'gift_percent')::numeric,
      gifted_quantity = (r ->> 'gifted_quantity')::numeric, discount_amount = (r ->> 'discount_amount')::bigint,
      line_total = (r ->> 'line_total')::bigint, over_cap = (r ->> 'over_cap')::boolean,
      needs_acknowledgement = (r ->> 'needs_acknowledgement')::boolean
     where id = l.id;
    -- Chụp lại mức đã áp của từng chính sách (chính sách "áp đúng mức" có thể đổi mức tối đa).
    for d in select * from jsonb_array_elements(r -> 'discounts') loop
      update app.quotation_line_discount set applied_value = (d ->> 'applied_value')::numeric,
             requires_approval = (d ->> 'requires_approval')::boolean
       where line_id = l.id and policy_id = (d ->> 'policy_id')::uuid;
    end loop;
    v_new_total := v_new_total + (r ->> 'line_total')::bigint;
  end loop;
  if v_new_total <> v_old_total then
    v_warnings := jsonb_build_array(jsonb_build_object('code', 'HMT_TONG_TIEN_DOI',
      'message', format('Giá hoặc chính sách đã đổi từ lúc lưu: tổng báo giá từ %s đ thành %s đ.', v_old_total, v_new_total)));
  end if;
  update app.quotation set status_code = 'DA_GUI', sent_at = now(), sent_by = auth.uid(), priced_on = v_on, total_amount = v_new_total,
         valid_until = v_on + app.get_setting_int('quotation_validity_days', v_q.branch_id)::integer
   where id = p_id;
  return jsonb_build_object('id', p_id, 'total_amount', v_new_total, 'previous_total', v_old_total, 'warnings', v_warnings);
end;
$$;

-- Từ chối báo giá: Đã gửi → Từ chối, lý do từ danh mục "Lý do từ chối" áp dụng cho báo giá; "Khác" bắt ghi chú (R-HT-04).
-- Ai gọi: Báo giá · Sửa. Chặn nếu đã có đơn đang sống từ báo giá này.
create or replace function app.reject_quotation(p_id uuid, p_reason_code text, p_note text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q app.quotation;
  v_item app.catalog_item;
begin
  select * into v_q from app.quotation where id = p_id for update;
  if v_q.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy báo giá.');
  end if;
  perform app.assert_can('QUOTATION', 'SUA', v_q.branch_id);
  perform app.require_feature('BAN_HANG', v_q.branch_id); -- Luật Đ173
  if v_q.status_code <> 'DA_GUI' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ từ chối được báo giá đã gửi.');
  end if;
  if app.quotation_has_live_order(p_id) then
    perform app.raise_error('HMT_BAO_GIA_DA_CO_DON', 'Báo giá đã có đơn đang xử lý, không từ chối được.');
  end if;
  select * into v_item from app.catalog_item
   where catalog_code = 'REJECT_REASON' and code = p_reason_code and is_active
     and (cardinality(applies_to) = 0 or 'BAO_GIA' = any (applies_to));
  if v_item.id is null then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn lý do từ chối dành cho báo giá.');
  end if;
  if v_item.requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_LY_DO_THIEU', 'Chọn "Khác" thì ghi chú lý do.');
  end if;
  update app.quotation set status_code = 'TU_CHOI', reject_reason_code = p_reason_code,
         reject_note = nullif(btrim(coalesce(p_note, '')), ''), rejected_at = now(), rejected_by = auth.uid()
   where id = p_id;
end;
$$;

-- Huỷ báo giá (R-CRM-19, Đ171): Nháp, Đã gửi hoặc Từ chối → Huỷ; không xoá cứng. Chặn nếu đã có đơn đang sống.
-- Ai gọi: Báo giá · Sửa. Ghi chú tuỳ chọn.
create or replace function app.cancel_quotation(p_id uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_q app.quotation;
begin
  select * into v_q from app.quotation where id = p_id for update;
  if v_q.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy báo giá.');
  end if;
  perform app.assert_can('QUOTATION', 'SUA', v_q.branch_id);
  perform app.require_feature('BAN_HANG', v_q.branch_id); -- Luật Đ173
  if v_q.status_code = 'HUY' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Báo giá này đã huỷ.');
  end if;
  if app.quotation_has_live_order(p_id) then
    perform app.raise_error('HMT_BAO_GIA_DA_CO_DON', 'Báo giá đã có đơn đang xử lý, không huỷ được. Huỷ đơn trước.');
  end if;
  update app.quotation set status_code = 'HUY', cancel_note = nullif(btrim(coalesce(p_note, '')), ''),
         cancelled_at = now(), cancelled_by = auth.uid()
   where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Bản ghi báo giá cho TS-08 / BH-02: tiêu đề, dòng kèm chiết khấu, em (tên, năm sinh, mã HS nếu đã có hồ sơ), trạng thái hiển thị
-- (Đã chuyển đơn tính từ dòng), nhãn "Đã quá hạn N ngày" (R-TIEN-05).
-- Ai gọi: Báo giá · Xem ở cơ sở của báo giá.
-- ---------------------------------------------------------------------------
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
               'student_name', v.full_name, 'student_birth_year', v.birth_year, 'student_code', v.student_code,
               'student_complete', (v.full_name is not null and v.birth_year is not null),
               'gift_policy_name', (select g.name from app.gift_policy g where g.id = l.gift_policy_id),
               'discounts', coalesce((select jsonb_agg(to_jsonb(d) - 'line_id' - 'branch_id' order by d.created_at, d.id)
                                        from app.quotation_line_discount d where d.line_id = l.id), '[]'::jsonb))
             order by l.line_no)
        from app.quotation_line l
        left join app.prospect_student_v v on v.id = l.prospect_student_id
       where l.quotation_id = q.id), '[]'::jsonb));
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách báo giá, phân trang ở máy chủ (50 mặc định, tối đa 100): BH-01, tab Báo giá trên TS-08 và KH-02.
-- Ai gọi: Báo giá · Xem (phạm vi quyền: toàn hệ thống hoặc cơ sở mình).
-- Bộ lọc p_filters: q (mã, tên phụ huynh, SĐT, tên em), status[] (NHAP, DA_GUI, TU_CHOI, HUY), branch_id, opportunity_id, parent_id,
-- mine (do tôi tạo), expired (đã gửi và quá hạn), created_from, created_to. Sắp xếp: created_desc, created_asc, total_desc, valid_asc.
-- Kết quả: {total, rows: [...]}. Chỉ trả các cột màn hiện.
-- ---------------------------------------------------------------------------
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
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_expired boolean := coalesce((p_filters ->> 'expired')::boolean, false);
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
     where (v_scope = 'TOAN_HE_THONG' or q.branch_id = v_my_branch)
       and (v_q is null or q.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or q.status_code = any (v_status))
       and (v_branch is null or q.branch_id = v_branch)
       and (v_opp is null or q.opportunity_id = v_opp)
       and (v_parent is null or q.parent_id = v_parent)
       and (not v_mine or q.created_by = auth.uid())
       and (not v_expired or (q.status_code = 'DA_GUI' and q.valid_until < v_today))
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
             'student_name', (select v.full_name from app.quotation_line l join app.prospect_student_v v on v.id = l.prospect_student_id
                               where l.quotation_id = p.id order by l.line_no limit 1),
             'student_count', (select count(distinct l.prospect_student_id) from app.quotation_line l where l.quotation_id = p.id),
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
    join app.opportunity o on o.id = p.opportunity_id;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Xuất danh sách báo giá (BH-K10, Đ105): chỉ vai có quyền Báo giá · Xuất (Trưởng cơ sở trong cơ sở, Kế toán, Admin). Cùng bộ lọc với
-- list_quotations; tối đa export_max_rows dòng; ghi nhật ký xuất TRƯỚC khi trả dữ liệu. Kết quả: {total, exported, truncated, rows}.
-- ---------------------------------------------------------------------------
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
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_expired boolean := coalesce((p_filters ->> 'expired')::boolean, false);
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
     and (cardinality(v_status) = 0 or q.status_code = any (v_status))
     and (v_branch is null or q.branch_id = v_branch)
     and (v_opp is null or q.opportunity_id = v_opp)
     and (v_parent is null or q.parent_id = v_parent)
     and (not v_mine or q.created_by = auth.uid())
     and (not v_expired or (q.status_code = 'DA_GUI' and q.valid_until < v_today))
     and (v_from is null or q.created_at >= v_from)
     and (v_to is null or q.created_at < v_to);
  with f as (
    select q.*
      from app.quotation q
     where (v_scope = 'TOAN_HE_THONG' or q.branch_id = v_my_branch)
       and (v_q is null or q.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or q.status_code = any (v_status))
       and (v_branch is null or q.branch_id = v_branch)
       and (v_opp is null or q.opportunity_id = v_opp)
       and (v_parent is null or q.parent_id = v_parent)
       and (not v_mine or q.created_by = auth.uid())
       and (not v_expired or (q.status_code = 'DA_GUI' and q.valid_until < v_today))
       and (v_from is null or q.created_at >= v_from)
       and (v_to is null or q.created_at < v_to)
     order by q.created_at desc, q.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', f.code,
           'status', (select c.name from app.catalog_item c where c.catalog_code = 'QUOTATION_STATUS' and c.code = f.status_code),
           'parent_name', par.full_name, 'parent_phone', par.phone, 'opportunity', o.code,
           'students', (select string_agg(distinct v.full_name, '; ') from app.quotation_line l
                          join app.prospect_student_v v on v.id = l.prospect_student_id where l.quotation_id = f.id),
           'total_amount', f.total_amount, 'valid_until', f.valid_until, 'sent_at', f.sent_at,
           'branch', b.code, 'created_by', app.staff_display_name(f.created_by), 'created_at', f.created_at)
           order by f.created_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id
    join app.parent par on par.id = f.parent_id
    join app.opportunity o on o.id = f.opportunity_id;
  perform app.log_export('QUOTATION', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$$;

-- ---------------------------------------------------------------------------
-- Quyền gọi: chỉ người đăng nhập; mỗi hàm kiểm quyền ma trận bên trong.
-- ---------------------------------------------------------------------------
revoke execute on function app.quotation_search_text(app.quotation), app.tg_quotation_search_text(), app.tg_quotation_child_branch(),
  app.tg_quotation_child_lock(), app.tg_quotation_status_flow(), app.quotation_has_live_order(uuid), app.quotation_converted(uuid),
  app.price_apply_discounts(integer, text, uuid, date, jsonb),
  app.price_line(integer, text, uuid, text, numeric, jsonb, uuid, uuid, date),
  app.validate_line_student(integer, uuid, uuid), app.assert_line_students_complete(uuid) from public, anon, authenticated;
revoke execute on function app.save_quotation(uuid, uuid, jsonb), app.send_quotation(uuid), app.reject_quotation(uuid, text, text),
  app.cancel_quotation(uuid, text), app.get_quotation(uuid), app.list_quotations(jsonb, text, integer, integer),
  app.export_quotations(jsonb) from public, anon;
grant execute on function app.save_quotation(uuid, uuid, jsonb), app.send_quotation(uuid), app.reject_quotation(uuid, text, text),
  app.cancel_quotation(uuid, text), app.get_quotation(uuid), app.list_quotations(jsonb, text, integer, integer),
  app.export_quotations(jsonb) to authenticated;

select set_config('hmt.migration', '', false);
