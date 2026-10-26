-- ===========================================================================
-- P5a-DB0: cấu hình bán hàng (QĐ-Đ100 đến Đ107, Đ117 đến Đ120; 24/10/2026).
-- Gói bán (CH-01), bảng giá có ngày hiệu lực (CH-03), chính sách chiết khấu (CH-04), chính sách quà tặng (R-TIEN-30), điều khoản
-- thanh toán (CH-09, R-TIEN-07), đơn vị tính theo loại gói (Đ101), danh mục "Lý do huỷ đơn" (Đ104), "Áp dụng cho" của lý do từ chối
-- (Đ103), tham số debt_due_soon_days (Đ107), phiên bản ma trận quyền mới về Xuất báo giá (Đ105).
-- Quy ước: cấu hình có ngày hiệu lực hoặc phiên bản; bản ghi nghiệp vụ (báo giá, đơn, ở DB1) CHỤP LẠI giá trị lúc tạo
-- (R-TIEN-14). Bảng chỉ đọc qua quyền Cấu hình bán hàng · Xem; ghi chỉ qua các hàm bên dưới (Admin).
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Danh mục
-- ---------------------------------------------------------------------------
insert into app.catalog (code, name, kind, parent_catalog, linked_catalog, description, sort_order) values
  ('PACKAGE_UNIT', 'Đơn vị tính của gói', 'HE_THONG', null, null,
   'Giờ, tháng, bộ. Đơn vị theo loại gói: DV theo tháng, TL theo bộ, còn lại theo giờ (Đ101, app.package_unit).', 61),
  ('ORDER_CANCEL_REASON', 'Lý do huỷ đơn', 'MO', null, null,
   'Chọn khi huỷ đơn hàng (Đ104). Luôn có "Khác" bắt buộc ghi chú (R-HT-04). Chữ trong spec 06 chờ OK ĐƯA VÀO LUẬT SPEC06-LY-DO-HUY-DON.', 62);

insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note) values
  ('PACKAGE_UNIT', 'GIO', 'Giờ', 1, false),
  ('PACKAGE_UNIT', 'THANG', 'Tháng', 2, false),
  ('PACKAGE_UNIT', 'BO', 'Bộ', 3, false),
  ('ORDER_CANCEL_REASON', 'KHACH_DOI_Y', 'Khách đổi ý, không đăng ký nữa', 1, false),
  ('ORDER_CANCEL_REASON', 'CHON_NHAM_GOI_LOP', 'Chọn nhầm gói hoặc lớp', 2, false),
  ('ORDER_CANCEL_REASON', 'NHAP_SAI_THONG_TIN', 'Nhập sai thông tin', 3, false),
  ('ORDER_CANCEL_REASON', 'THAY_BANG_DON_KHAC', 'Thay bằng đơn khác', 4, false),
  ('ORDER_CANCEL_REASON', 'KHONG_LIEN_LAC_DUOC', 'Không liên lạc được', 5, false),
  ('ORDER_CANCEL_REASON', 'KHAC', 'Khác', 6, true);

-- Đ103: "Áp dụng cho" của lý do từ chối. Mục dùng chung (Thiếu thông tin, Khác) để trống = áp dụng mọi nơi (R-HT-04).
-- Mã loại: BAO_GIA, DON, PHIEU_THU (các loại LOP, TICKET, YEU_CAU_BUOI thêm sau).
update app.catalog_item set applies_to = array['PHIEU_THU']
 where catalog_code = 'REJECT_REASON' and code in ('SAI_SO_TIEN', 'SAI_CHUNG_TU');
update app.catalog_item set applies_to = array['BAO_GIA', 'DON']
 where catalog_code = 'REJECT_REASON' and code = 'KHONG_DUNG_CHINH_SACH';

-- ---------------------------------------------------------------------------
-- Tham số (Đ107): nhãn "Sắp đến hạn" của công nợ (TD10). Không ghi đè theo cơ sở.
-- ---------------------------------------------------------------------------
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('debt_due_soon_days', 'Công nợ: số ngày tính là "Sắp đến hạn"', 'INT', 'ngày', 1, 30, '3', false, 'BAN_HANG', 'Đ107, TD10',
   'Đợt đóng tiền còn chưa quá hạn mà hạn trong bấy nhiêu ngày tới thì hiện nhãn "Sắp đến hạn" (R-TIEN-07).');

-- ---------------------------------------------------------------------------
-- Dùng chung
-- ---------------------------------------------------------------------------
-- Chỉ Admin (phạm vi toàn hệ thống) ghi cấu hình bán hàng: quyền Cấu hình bán hàng · <hành động>.
create or replace function app.assert_config_sales(p_action text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if app.permission_scope('CONFIG_SALES', p_action) is distinct from 'TOAN_HE_THONG' then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên được sửa cấu hình bán hàng.');
  end if;
end;
$$;

-- Đơn vị tính theo loại gói (Đ101, R-TIEN-15): DV theo tháng, TL theo bộ, các loại còn lại theo giờ.
-- Luật lõi nên nằm trong code; bảng gói không có cột đơn vị riêng để không thể lệch.
create or replace function app.package_unit(p_package_type_code text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_package_type_code when 'DV' then 'THANG' when 'TL' then 'BO' else 'GIO' end;
$$;

-- Cấu hình đã tạo chỉ thêm bản mới, không sửa (giá, đợt của điều khoản).
create or replace function app.tg_config_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not app.is_migration() then
    perform app.raise_error('HMT_CAU_HINH_CHI_THEM',
      'Giá và đợt thanh toán đã tạo không sửa được. Thêm bản mới có ngày hiệu lực mới.');
  end if;
  return new;
end;
$$;

-- Phạm vi áp dụng của chính sách: loại gói và cơ sở phải có thật (cơ sở văn phòng không nhận dữ liệu bán hàng, R-HT-02).
create or replace function app.tg_policy_scope_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_code text;
  v_branch uuid;
begin
  if new.valid_to is not null and new.valid_to < new.valid_from then
    perform app.raise_error('HMT_NGAY_HIEU_LUC_SAI', 'Ngày hết hiệu lực không được trước ngày bắt đầu.');
  end if;
  foreach v_code in array new.package_type_codes loop
    perform app.assert_catalog_code_active('PACKAGE_TYPE', v_code);
  end loop;
  foreach v_branch in array new.branch_ids loop
    if not exists (select from app.branch b where b.id = v_branch and not b.is_office) then
      perform app.raise_error('HMT_CO_SO_SAI', 'Cơ sở áp dụng không có hoặc là cơ sở văn phòng.');
    end if;
  end loop;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Gói bán (CH-01, spec 02: Loại-Môn-Khối). Không có số giờ, không có loại lớp: giờ do nhân viên điền trên dòng (R-TIEN-36).
-- ---------------------------------------------------------------------------
create table app.sales_package (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z]+(-[A-Z0-9]+)+$'),
  name text not null check (btrim(name) <> ''),
  package_type_catalog text not null default 'PACKAGE_TYPE' check (package_type_catalog = 'PACKAGE_TYPE'),
  package_type_code text not null,
  subject_catalog text not null default 'SUBJECT' check (subject_catalog = 'SUBJECT'),
  subject_code text,
  grade_catalog text not null default 'GRADE' check (grade_catalog = 'GRADE'),
  grade_from_code text,
  grade_to_code text,
  is_active boolean not null default true,
  legacy_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.sales_package is 'Gói bán (R-TIEN-10, 15). Một gói có hai giá (offline, online) ở app.package_price. Ngừng bằng is_active, không xoá.';
-- Chỉ mục (lý do): chọn gói đang bán theo loại; lọc theo môn, khối trong ô chọn gói của báo giá, đơn.
create index sales_package_type_idx on app.sales_package (package_type_code, is_active);
create index sales_package_subject_grade_idx on app.sales_package (subject_code, grade_from_code) where subject_code is not null;

create or replace function app.tg_sales_package_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_expected text;
  v_from integer;
  v_to integer;
begin
  if TG_OP = 'UPDATE' then
    -- Luật: mã, loại, môn, khối không đổi (mã chứa chúng); muốn khác thì tạo gói mới.
    if new.package_type_code is distinct from old.package_type_code or new.subject_code is distinct from old.subject_code
       or new.grade_from_code is distinct from old.grade_from_code or new.grade_to_code is distinct from old.grade_to_code then
      perform app.raise_error('HMT_GOI_KHONG_DOI', 'Loại gói, môn, khối không đổi được. Tạo gói mới.');
    end if;
    return new;
  end if;
  perform app.assert_catalog_code_active('PACKAGE_TYPE', new.package_type_code);
  if new.package_type_code in ('LC', 'VIP', 'VNN', 'KR') then
    -- Luật spec 02: gói giờ học có môn và khối; mã = Loại-Môn-Khối hoặc Loại-Môn-KhốiđầuKhốicuối, không chứa hình thức.
    if new.subject_code is null or new.grade_from_code is null then
      perform app.raise_error('HMT_THIEU_THONG_TIN', 'Gói giờ học cần môn và khối.');
    end if;
    perform app.assert_catalog_code_active('SUBJECT', new.subject_code);
    perform app.assert_catalog_code_active('GRADE', new.grade_from_code);
    select sort_order into v_from from app.catalog_item where catalog_code = 'GRADE' and code = new.grade_from_code;
    if new.grade_to_code is not null and new.grade_to_code <> new.grade_from_code then
      perform app.assert_catalog_code_active('GRADE', new.grade_to_code);
      select sort_order into v_to from app.catalog_item where catalog_code = 'GRADE' and code = new.grade_to_code;
      if v_to < v_from then
        perform app.raise_error('HMT_KHOI_SAI', 'Khối đầu không được lớn hơn khối cuối.');
      end if;
      v_expected := new.package_type_code || '-' || new.subject_code || '-' || new.grade_from_code || new.grade_to_code;
    else
      v_expected := new.package_type_code || '-' || new.subject_code || '-' || new.grade_from_code;
      new.grade_to_code := null;
    end if;
    if new.code <> v_expected then
      perform app.raise_error('HMT_MA_GOI_SAI', format('Mã gói phải là %s (Loại-Môn-Khối, không chứa hình thức).', v_expected));
    end if;
  else
    -- Dịch vụ, tài liệu: không gắn môn, khối; mã Loại-Tên (DV-CSGK, TL-MATOAN).
    if new.subject_code is not null or new.grade_from_code is not null or new.grade_to_code is not null then
      perform app.raise_error('HMT_GOI_KHONG_DOI', 'Gói dịch vụ, tài liệu không gắn môn, khối.');
    end if;
    if new.code !~ ('^' || new.package_type_code || '-[A-Z0-9]+$') then
      perform app.raise_error('HMT_MA_GOI_SAI', format('Mã gói %s phải có dạng %s-TÊN.', new.package_type_code, new.package_type_code));
    end if;
  end if;
  return new;
end;
$$;
create trigger sales_package_rules before insert or update on app.sales_package
  for each row execute function app.tg_sales_package_rules();
create trigger sales_package_code_immutable before update on app.sales_package
  for each row execute function app.tg_code_immutable();
select app.apply_standard('app.sales_package');

-- ---------------------------------------------------------------------------
-- Bảng giá có ngày hiệu lực (CH-03, R-TIEN-10, 14). Mỗi (gói, hình thức) nhiều dòng theo ngày hiệu lực; giá hiệu lực tại ngày X
-- là dòng có effective_from lớn nhất không quá X. unit_price null = từ ngày đó ngừng bán hình thức này (giá trống = không bán).
-- Chỉ thêm, không sửa, không xoá.
-- ---------------------------------------------------------------------------
create table app.package_price (
  id uuid primary key default gen_random_uuid(),
  package_id uuid not null references app.sales_package (id),
  delivery_mode_catalog text not null default 'STUDY_MODE' check (delivery_mode_catalog = 'STUDY_MODE'),
  delivery_mode_code text not null,
  unit_price bigint check (unit_price is null or unit_price > 0),
  effective_from date not null,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (package_id, delivery_mode_code, effective_from)
);
comment on table app.package_price is 'Giá theo giờ (hoặc tháng, bộ) của gói, theo hình thức và ngày hiệu lực. Chỉ thêm. Giá null = ngừng bán hình thức đó từ ngày hiệu lực.';
-- Chỉ mục (lý do): duy nhất (gói, hình thức, ngày) cũng là chỉ mục tra giá hiệu lực tại ngày X (quét ngược theo ngày, lấy dòng đầu).

create or replace function app.tg_package_price_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_type text;
  v_active boolean;
begin
  select package_type_code, is_active into v_type, v_active from app.sales_package where id = new.package_id;
  perform app.assert_catalog_code_active('STUDY_MODE', new.delivery_mode_code);
  -- Luật R-TIEN-15: dịch vụ, tài liệu không có giá online.
  if v_type in ('DV', 'TL') and new.delivery_mode_code = 'ONL' then
    perform app.raise_error('HMT_GOI_KHONG_CO_ONLINE', 'Gói dịch vụ, tài liệu không có giá online.');
  end if;
  if not v_active then
    perform app.raise_error('HMT_GOI_DA_NGUNG', 'Gói đã ngừng, không thêm giá mới.');
  end if;
  return new;
end;
$$;
create trigger package_price_rules before insert on app.package_price
  for each row execute function app.tg_package_price_rules();
create trigger package_price_append_only before update on app.package_price
  for each row execute function app.tg_config_append_only();
select app.apply_standard('app.package_price');

-- Giá hiệu lực của (gói, hình thức) tại một ngày: null nếu chưa có giá hoặc đã ngừng bán hình thức đó (R-TIEN-10, 14).
create or replace function app.package_price_at(p_package_id uuid, p_delivery_mode_code text, p_on date)
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select p.unit_price
    from app.package_price p
   where p.package_id = p_package_id and p.delivery_mode_code = p_delivery_mode_code and p.effective_from <= p_on
   order by p.effective_from desc
   limit 1;
$$;

-- ---------------------------------------------------------------------------
-- Chính sách chiết khấu (CH-04, R-TIEN-29). Phần trăm hoặc giờ tặng; max_value là mức tối đa; fixed_value bật thì áp đúng
-- max_value, tắt thì nhân viên điền từ 0 đến max_value; tặng giờ luôn là loại điền (R-TIEN-36). requires_approval và vượt trần
-- dùng chung một ô tích của người duyệt (Đ102). package_type_codes, branch_ids để trống = áp cho mọi loại gói, mọi cơ sở.
-- ---------------------------------------------------------------------------
create table app.discount_policy (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z0-9_]+$'),
  name text not null check (btrim(name) <> ''),
  kind text not null check (kind in ('PERCENT', 'GIFT_HOURS')),
  max_value numeric(7, 2) not null check (max_value > 0),
  fixed_value boolean not null default false,
  requires_approval boolean not null default false,
  valid_from date not null,
  valid_to date,
  package_type_codes text[] not null default '{}',
  branch_ids uuid[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (kind <> 'PERCENT' or max_value <= 100), -- allow-number: phần trăm tối đa 100
  check (kind <> 'GIFT_HOURS' or not fixed_value)
);
comment on table app.discount_policy is 'Chính sách chiết khấu: % hoặc giờ tặng. Sửa được (có nhật ký); đơn đã chụp lại giá trị (R-TIEN-14).';
-- Chỉ mục (lý do): bảng chỉ vài chục dòng, đọc nguyên danh sách đang hiệu lực; chỉ mục theo (còn dùng, ngày) cho câu "đang hiệu lực hôm nay".
create index discount_policy_valid_idx on app.discount_policy (is_active, valid_from, valid_to);
create trigger discount_policy_scope_rules before insert or update on app.discount_policy
  for each row execute function app.tg_policy_scope_rules();
create trigger discount_policy_code_immutable before update on app.discount_policy
  for each row execute function app.tg_code_immutable();
create or replace function app.tg_discount_policy_fixed_kind()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.kind is distinct from old.kind then
    perform app.raise_error('HMT_CHINH_SACH_KHONG_DOI', 'Loại chính sách (phần trăm hay giờ tặng) không đổi được. Tạo chính sách mới.');
  end if;
  return new;
end;
$$;
create trigger discount_policy_kind_fixed before update on app.discount_policy
  for each row execute function app.tg_discount_policy_fixed_kind();
select app.apply_standard('app.discount_policy');

-- ---------------------------------------------------------------------------
-- Chính sách quà tặng (R-TIEN-30): tặng gói dịch vụ, tài liệu giá 0 đ, không tính vào trần chiết khấu.
-- ---------------------------------------------------------------------------
create table app.gift_policy (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z0-9_]+$'),
  name text not null check (btrim(name) <> ''),
  gift_package_id uuid not null references app.sales_package (id),
  max_quantity numeric(6, 2) not null check (max_quantity > 0),
  requires_approval boolean not null default false,
  valid_from date not null,
  valid_to date,
  package_type_codes text[] not null default '{}',
  branch_ids uuid[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.gift_policy is 'Chính sách quà tặng: gói quà (DV hoặc TL), số lượng tối đa, có cần duyệt không, hiệu lực.';
-- Chỉ mục (lý do): khoá ngoại tới gói quà; lọc chính sách đang hiệu lực.
create index gift_policy_package_idx on app.gift_policy (gift_package_id);
create index gift_policy_valid_idx on app.gift_policy (is_active, valid_from, valid_to);
create or replace function app.tg_gift_policy_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Luật R-TIEN-30: quà tặng là dòng dịch vụ hoặc tài liệu.
  if not exists (select from app.sales_package p where p.id = new.gift_package_id and p.package_type_code in ('DV', 'TL')) then
    perform app.raise_error('HMT_QUA_TANG_SAI', 'Gói quà tặng phải là dịch vụ (DV) hoặc tài liệu (TL).');
  end if;
  return new;
end;
$$;
create trigger gift_policy_package_rules before insert or update on app.gift_policy
  for each row execute function app.tg_gift_policy_rules();
create trigger gift_policy_scope_rules before insert or update on app.gift_policy
  for each row execute function app.tg_policy_scope_rules();
create trigger gift_policy_code_immutable before update on app.gift_policy
  for each row execute function app.tg_code_immutable();
select app.apply_standard('app.gift_policy');

-- ---------------------------------------------------------------------------
-- Điều khoản thanh toán (CH-09, R-TIEN-07). Mỗi bản (code, version) là một mẫu chia đợt; sửa = tạo bản mới, ngừng bản cũ.
-- Đợt 1 có thể là số tiền cố định (đặt cọc); các đợt sau chia % của phần còn lại (tổng 100%). Chọn trên đơn để sinh lịch đóng tiền.
-- ---------------------------------------------------------------------------
create table app.payment_term (
  id uuid primary key default gen_random_uuid(),
  code text not null check (code ~ '^[A-Z0-9_]+$'),
  version integer not null check (version >= 1),
  name text not null check (btrim(name) <> ''),
  valid_from date not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (code, version)
);
comment on table app.payment_term is 'Điều khoản thanh toán: mẫu chia đợt. Bản đã tạo không sửa (chỉ Ngừng); đổi nội dung = tạo bản mới.';
create table app.payment_term_installment (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references app.payment_term (id),
  seq integer not null check (seq >= 1),
  share_percent numeric(5, 2) check (share_percent is null or (share_percent > 0 and share_percent <= 100)), -- allow-number: phần trăm tối đa 100
  fixed_amount bigint check (fixed_amount is null or fixed_amount > 0),
  due_days integer not null check (due_days >= 0),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (term_id, seq),
  check (num_nonnulls(share_percent, fixed_amount) = 1),
  -- Chỉ đợt 1 được là số tiền cố định (Đ117 phần c).
  check (fixed_amount is null or seq = 1)
);
-- Chỉ mục (lý do): duy nhất (term_id, seq) là chỉ mục khoá ngoại và lấy các đợt theo thứ tự.
comment on table app.payment_term_installment is 'Đợt của điều khoản: % hoặc (đợt 1) số tiền cố định, số ngày đến hạn tính từ ngày duyệt đơn.';
create or replace function app.tg_payment_term_fixed()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.code is distinct from old.code or new.version is distinct from old.version or new.name is distinct from old.name
     or new.valid_from is distinct from old.valid_from then
    perform app.raise_error('HMT_CAU_HINH_CHI_THEM', 'Điều khoản đã tạo không sửa được. Tạo bản mới.');
  end if;
  return new;
end;
$$;
create trigger payment_term_fixed before update on app.payment_term
  for each row execute function app.tg_payment_term_fixed();
create trigger payment_term_installment_append_only before update on app.payment_term_installment
  for each row execute function app.tg_config_append_only();
select app.apply_standard('app.payment_term');
select app.apply_standard('app.payment_term_installment');

-- Số tiền từng đợt khi áp điều khoản vào đơn có tổng p_total (DB2 dùng khi duyệt đơn để sinh lịch đóng tiền).
-- Cách tính (anh chốt 24/10, phần c): đợt 1 là số tiền cố định A thì A phải nhỏ hơn tổng đơn; phần còn lại R = tổng − A chia cho các
-- đợt sau theo % (làm tròn xuống đồng), đợt cuối nhận phần dư để tổng các đợt đúng bằng tổng đơn. Toàn % thì R = tổng.
-- R-TIEN-07 ghi "% hoặc số tiền mỗi đợt"; bản này chỉ cho số tiền ở đợt 1 theo quyết định c (ghi vênh vào PR).
-- Kết quả: (seq, due_days, amount) theo thứ tự đợt.
create or replace function app.payment_term_amounts(p_term_id uuid, p_total bigint)
returns table (seq integer, due_days integer, amount bigint)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_fixed bigint;
  v_rest bigint;
  v_last integer;
  v_given bigint := 0;
  r record;
  v_amount bigint;
begin
  if p_total is null or p_total <= 0 then
    perform app.raise_error('HMT_TONG_DON_SAI', 'Tổng đơn phải lớn hơn 0 để chia đợt.');
  end if;
  select max(i.seq) into v_last from app.payment_term_installment i where i.term_id = p_term_id;
  if v_last is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy điều khoản thanh toán.');
  end if;
  select i.fixed_amount into v_fixed from app.payment_term_installment i where i.term_id = p_term_id and i.seq = 1;
  if v_fixed is not null and v_fixed >= p_total then
    perform app.raise_error('HMT_COC_VUOT_DON', 'Tiền đợt đầu không nhỏ hơn tổng đơn. Chọn điều khoản khác hoặc thanh toán một lần.');
  end if;
  v_rest := p_total - coalesce(v_fixed, 0);
  for r in select i.seq as s, i.due_days as d, i.share_percent as p, i.fixed_amount as f
             from app.payment_term_installment i where i.term_id = p_term_id order by i.seq loop
    if r.f is not null then
      v_amount := r.f;
    elsif r.s = v_last then
      v_amount := p_total - v_given;
    else
      v_amount := floor(v_rest * r.p / 100); -- allow-number: phần trăm
    end if;
    v_given := v_given + v_amount;
    seq := r.s; due_days := r.d; amount := v_amount;
    return next;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS: đọc theo quyền Cấu hình bán hàng · Xem (Admin, Trưởng cơ sở, Sale, CSKH, Kế toán); ghi chỉ qua hàm bên dưới.
-- ---------------------------------------------------------------------------
alter table app.sales_package enable row level security;
alter table app.package_price enable row level security;
alter table app.discount_policy enable row level security;
alter table app.gift_policy enable row level security;
alter table app.payment_term enable row level security;
alter table app.payment_term_installment enable row level security;
revoke all on app.sales_package, app.package_price, app.discount_policy, app.gift_policy, app.payment_term,
  app.payment_term_installment from public, anon, authenticated;
grant select on app.sales_package, app.package_price, app.discount_policy, app.gift_policy, app.payment_term,
  app.payment_term_installment to authenticated;
create policy sales_package_read on app.sales_package for select to authenticated
  using ((select app.has_permission('CONFIG_SALES', 'XEM')));
create policy package_price_read on app.package_price for select to authenticated
  using ((select app.has_permission('CONFIG_SALES', 'XEM')));
create policy discount_policy_read on app.discount_policy for select to authenticated
  using ((select app.has_permission('CONFIG_SALES', 'XEM')));
create policy gift_policy_read on app.gift_policy for select to authenticated
  using ((select app.has_permission('CONFIG_SALES', 'XEM')));
create policy payment_term_read on app.payment_term for select to authenticated
  using ((select app.has_permission('CONFIG_SALES', 'XEM')));
create policy payment_term_installment_read on app.payment_term_installment for select to authenticated
  using ((select app.has_permission('CONFIG_SALES', 'XEM')));

-- ---------------------------------------------------------------------------
-- Hàm ghi của Admin
-- ---------------------------------------------------------------------------
-- Tạo hoặc sửa gói. Ai gọi: Admin (Cấu hình bán hàng · Tạo / Sửa).
-- Đầu vào: p_id null = tạo; p_data: code, name, package_type_code, subject_code, grade_from_code, grade_to_code, legacy_ref.
-- Sửa chỉ đổi được name, legacy_ref (mã, loại, môn, khối không đổi). Kết quả: id gói. Luật: R-TIEN-10, 15; spec 02.
create or replace function app.save_sales_package(p_id uuid, p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_id;
begin
  if p_id is null then
    perform app.assert_config_sales('TAO');
    if btrim(coalesce(p_data ->> 'name', '')) = '' or btrim(coalesce(p_data ->> 'code', '')) = '' then
      perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập mã và tên gói.');
    end if;
    begin
      insert into app.sales_package (code, name, package_type_code, subject_code, grade_from_code, grade_to_code, legacy_ref)
      values (btrim(p_data ->> 'code'), btrim(p_data ->> 'name'), p_data ->> 'package_type_code',
              nullif(p_data ->> 'subject_code', ''), nullif(p_data ->> 'grade_from_code', ''),
              nullif(p_data ->> 'grade_to_code', ''), nullif(p_data ->> 'legacy_ref', ''))
      returning id into v_id;
    exception when unique_violation then
      perform app.raise_error('HMT_MA_GOI_TRUNG', 'Mã gói này đã có.');
    end;
  else
    perform app.assert_config_sales('SUA');
    if not exists (select from app.sales_package where id = p_id) then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy gói.');
    end if;
    update app.sales_package set
      name = case when p_data ? 'name' then btrim(coalesce(p_data ->> 'name', '')) else name end,
      legacy_ref = case when p_data ? 'legacy_ref' then nullif(p_data ->> 'legacy_ref', '') else legacy_ref end,
      package_type_code = coalesce(p_data ->> 'package_type_code', package_type_code),
      subject_code = case when p_data ? 'subject_code' then nullif(p_data ->> 'subject_code', '') else subject_code end,
      grade_from_code = case when p_data ? 'grade_from_code' then nullif(p_data ->> 'grade_from_code', '') else grade_from_code end,
      grade_to_code = case when p_data ? 'grade_to_code' then nullif(p_data ->> 'grade_to_code', '') else grade_to_code end
     where id = p_id;
  end if;
  return v_id;
end;
$$;

-- Thêm một dòng giá (không sửa giá cũ). Ai gọi: Admin (Cấu hình bán hàng · Tạo). p_unit_price null = ngừng bán hình thức đó từ ngày hiệu lực.
-- effective_from được ở quá khứ (nhập dữ liệu cũ); báo giá mới luôn tính giá theo ngày tạo. Luật: R-TIEN-10, 14, 15.
create or replace function app.add_package_price(p_package_id uuid, p_delivery_mode_code text, p_unit_price bigint, p_effective_from date)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform app.assert_config_sales('TAO');
  if p_effective_from is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ngày hiệu lực của giá.');
  end if;
  if not exists (select from app.sales_package where id = p_package_id) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy gói.');
  end if;
  begin
    insert into app.package_price (package_id, delivery_mode_code, unit_price, effective_from)
    values (p_package_id, p_delivery_mode_code, p_unit_price, p_effective_from)
    returning id into v_id;
  exception
    when unique_violation then
      perform app.raise_error('HMT_GIA_DA_CO', 'Gói này đã có giá cho hình thức này từ ngày đó. Chọn ngày hiệu lực khác.');
    when check_violation then
      perform app.raise_error('HMT_GIA_SAI', 'Giá phải lớn hơn 0 (hoặc để trống nếu ngừng bán hình thức này).');
  end;
  return v_id;
end;
$$;

-- Tạo hoặc sửa chính sách chiết khấu. Ai gọi: Admin. p_data: code, name, kind, max_value, fixed_value, requires_approval,
-- valid_from, valid_to, package_type_codes (mảng), branch_ids (mảng), legacy không có. Mã và loại không đổi. Luật: R-TIEN-29, 36; Đ102.
create or replace function app.save_discount_policy(p_id uuid, p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_id;
  v_types text[] := array(select jsonb_array_elements_text(coalesce(p_data -> 'package_type_codes', '[]'::jsonb)));
  v_branches uuid[] := array(select jsonb_array_elements_text(coalesce(p_data -> 'branch_ids', '[]'::jsonb))::uuid);
begin
  if p_id is null then
    perform app.assert_config_sales('TAO');
    if btrim(coalesce(p_data ->> 'code', '')) = '' or btrim(coalesce(p_data ->> 'name', '')) = ''
       or nullif(p_data ->> 'valid_from', '') is null or nullif(p_data ->> 'max_value', '') is null then
      perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập mã, tên, mức tối đa và ngày bắt đầu hiệu lực.');
    end if;
    begin
      insert into app.discount_policy (code, name, kind, max_value, fixed_value, requires_approval, valid_from, valid_to,
                                       package_type_codes, branch_ids)
      values (btrim(p_data ->> 'code'), btrim(p_data ->> 'name'), p_data ->> 'kind', (p_data ->> 'max_value')::numeric,
              coalesce((p_data ->> 'fixed_value')::boolean, false), coalesce((p_data ->> 'requires_approval')::boolean, false),
              (p_data ->> 'valid_from')::date, nullif(p_data ->> 'valid_to', '')::date, v_types, v_branches)
      returning id into v_id;
    exception
      when unique_violation then
        perform app.raise_error('HMT_MA_TRUNG', 'Mã chính sách này đã có.');
      when check_violation then
        perform app.raise_error('HMT_CHINH_SACH_SAI',
          'Chính sách không hợp lệ: phần trăm từ 0 đến 100; tặng giờ không đặt "áp đúng mức".');
    end;
  else
    perform app.assert_config_sales('SUA');
    if not exists (select from app.discount_policy where id = p_id) then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy chính sách.');
    end if;
    begin
      update app.discount_policy set
        name = coalesce(nullif(btrim(p_data ->> 'name'), ''), name),
        kind = coalesce(p_data ->> 'kind', kind),
        max_value = coalesce((p_data ->> 'max_value')::numeric, max_value),
        fixed_value = coalesce((p_data ->> 'fixed_value')::boolean, fixed_value),
        requires_approval = coalesce((p_data ->> 'requires_approval')::boolean, requires_approval),
        valid_from = coalesce((p_data ->> 'valid_from')::date, valid_from),
        valid_to = case when p_data ? 'valid_to' then nullif(p_data ->> 'valid_to', '')::date else valid_to end,
        package_type_codes = case when p_data ? 'package_type_codes' then v_types else package_type_codes end,
        branch_ids = case when p_data ? 'branch_ids' then v_branches else branch_ids end
       where id = p_id;
    exception when check_violation then
      perform app.raise_error('HMT_CHINH_SACH_SAI',
        'Chính sách không hợp lệ: phần trăm từ 0 đến 100; tặng giờ không đặt "áp đúng mức".');
    end;
  end if;
  return v_id;
end;
$$;

-- Tạo hoặc sửa chính sách quà tặng. Ai gọi: Admin. p_data: code, name, gift_package_id, max_quantity, requires_approval, valid_from,
-- valid_to, package_type_codes, branch_ids. Luật: R-TIEN-30.
create or replace function app.save_gift_policy(p_id uuid, p_data jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_id;
  v_types text[] := array(select jsonb_array_elements_text(coalesce(p_data -> 'package_type_codes', '[]'::jsonb)));
  v_branches uuid[] := array(select jsonb_array_elements_text(coalesce(p_data -> 'branch_ids', '[]'::jsonb))::uuid);
begin
  if p_id is null then
    perform app.assert_config_sales('TAO');
    if btrim(coalesce(p_data ->> 'code', '')) = '' or btrim(coalesce(p_data ->> 'name', '')) = ''
       or nullif(p_data ->> 'valid_from', '') is null or nullif(p_data ->> 'max_quantity', '') is null
       or nullif(p_data ->> 'gift_package_id', '') is null then
      perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập mã, tên, gói quà, số lượng tối đa và ngày bắt đầu hiệu lực.');
    end if;
    begin
      insert into app.gift_policy (code, name, gift_package_id, max_quantity, requires_approval, valid_from, valid_to,
                                   package_type_codes, branch_ids)
      values (btrim(p_data ->> 'code'), btrim(p_data ->> 'name'), (p_data ->> 'gift_package_id')::uuid,
              (p_data ->> 'max_quantity')::numeric, coalesce((p_data ->> 'requires_approval')::boolean, false),
              (p_data ->> 'valid_from')::date, nullif(p_data ->> 'valid_to', '')::date, v_types, v_branches)
      returning id into v_id;
    exception
      when unique_violation then
        perform app.raise_error('HMT_MA_TRUNG', 'Mã chính sách này đã có.');
      when check_violation then
        perform app.raise_error('HMT_CHINH_SACH_SAI', 'Số lượng tối đa phải lớn hơn 0.');
    end;
  else
    perform app.assert_config_sales('SUA');
    if not exists (select from app.gift_policy where id = p_id) then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy chính sách.');
    end if;
    begin
      update app.gift_policy set
        name = coalesce(nullif(btrim(p_data ->> 'name'), ''), name),
        gift_package_id = coalesce((p_data ->> 'gift_package_id')::uuid, gift_package_id),
        max_quantity = coalesce((p_data ->> 'max_quantity')::numeric, max_quantity),
        requires_approval = coalesce((p_data ->> 'requires_approval')::boolean, requires_approval),
        valid_from = coalesce((p_data ->> 'valid_from')::date, valid_from),
        valid_to = case when p_data ? 'valid_to' then nullif(p_data ->> 'valid_to', '')::date else valid_to end,
        package_type_codes = case when p_data ? 'package_type_codes' then v_types else package_type_codes end,
        branch_ids = case when p_data ? 'branch_ids' then v_branches else branch_ids end
       where id = p_id;
    exception when check_violation then
      perform app.raise_error('HMT_CHINH_SACH_SAI', 'Số lượng tối đa phải lớn hơn 0.');
    end;
  end if;
  return v_id;
end;
$$;

-- Tạo một bản điều khoản thanh toán (R-TIEN-07). Ai gọi: Admin (Cấu hình bán hàng · Tạo).
-- Đầu vào: mã, tên, ngày bắt đầu hiệu lực, p_installments: mảng {seq, share_percent | fixed_amount, due_days}.
-- Kết quả: id bản mới; version = bản lớn nhất của mã đó + 1 (bản cũ giữ nguyên, Ngừng riêng).
-- Luật (anh chốt 24/10, phần c): đợt đánh số 1, 2, 3… liên tục; đợt 1 có thể là số tiền cố định (cọc) thì phải còn ít nhất một đợt sau;
-- các đợt còn lại chia % của phần còn lại và tổng đúng 100%; toàn % thì tổng 100%; số ngày đến hạn không âm, tính từ ngày duyệt đơn.
create or replace function app.create_payment_term(p_code text, p_name text, p_valid_from date, p_installments jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_version integer;
  v_n integer;
  v_fixed_first boolean;
  v_pct numeric;
  r record;
begin
  perform app.assert_config_sales('TAO');
  if btrim(coalesce(p_code, '')) = '' or btrim(coalesce(p_name, '')) = '' or p_valid_from is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập mã, tên và ngày bắt đầu hiệu lực.');
  end if;
  if p_installments is null or jsonb_typeof(p_installments) <> 'array' or jsonb_array_length(p_installments) = 0 then
    perform app.raise_error('HMT_DIEU_KHOAN_SAI', 'Điều khoản cần ít nhất một đợt.');
  end if;
  v_n := jsonb_array_length(p_installments);
  -- Luật: đợt đánh số liên tục từ 1.
  if exists (select from generate_series(1, v_n) g
              where not exists (select from jsonb_array_elements(p_installments) e where (e ->> 'seq')::integer = g)) then
    perform app.raise_error('HMT_DIEU_KHOAN_SAI', 'Các đợt phải đánh số liên tục 1, 2, 3…');
  end if;
  -- Luật: mỗi đợt đúng một trong % hoặc số tiền; số tiền chỉ ở đợt 1.
  for r in select (e ->> 'seq')::integer as seq, nullif(e ->> 'share_percent', '')::numeric as pct,
                  nullif(e ->> 'fixed_amount', '')::bigint as amt, (e ->> 'due_days')::integer as due
             from jsonb_array_elements(p_installments) e loop
    if num_nonnulls(r.pct, r.amt) <> 1 then
      perform app.raise_error('HMT_DIEU_KHOAN_SAI', format('Đợt %s cần đúng một trong hai: phần trăm hoặc số tiền.', r.seq));
    end if;
    if r.amt is not null and r.seq <> 1 then
      perform app.raise_error('HMT_DIEU_KHOAN_SAI', 'Chỉ đợt 1 (đặt cọc) được là số tiền cố định; các đợt sau chia phần trăm.');
    end if;
    if r.due is null or r.due < 0 then
      perform app.raise_error('HMT_DIEU_KHOAN_SAI', format('Đợt %s: số ngày đến hạn không được âm.', r.seq));
    end if;
  end loop;
  v_fixed_first := exists (select from jsonb_array_elements(p_installments) e
                            where (e ->> 'seq')::integer = 1 and nullif(e ->> 'fixed_amount', '') is not null);
  if v_fixed_first and v_n < 2 then -- allow-number: cọc cố định cần ít nhất 2 đợt (một đợt cọc và một đợt chia phần còn lại)
    perform app.raise_error('HMT_DIEU_KHOAN_SAI', 'Đợt 1 là số tiền cố định thì cần ít nhất một đợt sau để chia phần còn lại.');
  end if;
  -- Luật: tổng phần trăm các đợt chia % đúng 100.
  select coalesce(sum(nullif(e ->> 'share_percent', '')::numeric), 0) into v_pct from jsonb_array_elements(p_installments) e;
  if v_pct <> 100 then -- allow-number: tổng phần trăm phải đủ 100
    perform app.raise_error('HMT_DIEU_KHOAN_SAI', format('Tổng phần trăm các đợt chia theo %% phải đúng 100 (đang %s).', v_pct));
  end if;
  select coalesce(max(version), 0) + 1 into v_version from app.payment_term where code = btrim(p_code);
  insert into app.payment_term (code, version, name, valid_from) values (btrim(p_code), v_version, btrim(p_name), p_valid_from)
  returning id into v_id;
  insert into app.payment_term_installment (term_id, seq, share_percent, fixed_amount, due_days)
  select v_id, (e ->> 'seq')::integer, nullif(e ->> 'share_percent', '')::numeric, nullif(e ->> 'fixed_amount', '')::bigint,
         (e ->> 'due_days')::integer
    from jsonb_array_elements(p_installments) e;
  return v_id;
end;
$$;

-- Ngừng hoặc dùng lại một mục cấu hình (không xoá). Ai gọi: Admin (Cấu hình bán hàng · Sửa).
-- p_entity: PACKAGE, DISCOUNT_POLICY, GIFT_POLICY, PAYMENT_TERM.
create or replace function app.set_config_active(p_entity text, p_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  perform app.assert_config_sales('SUA');
  if p_entity = 'PACKAGE' then
    update app.sales_package set is_active = p_active where id = p_id;
  elsif p_entity = 'DISCOUNT_POLICY' then
    update app.discount_policy set is_active = p_active where id = p_id;
  elsif p_entity = 'GIFT_POLICY' then
    update app.gift_policy set is_active = p_active where id = p_id;
  elsif p_entity = 'PAYMENT_TERM' then
    update app.payment_term set is_active = p_active where id = p_id;
  else
    perform app.raise_error('HMT_LOAI_CAU_HINH_SAI', 'Loại cấu hình không có.');
  end if;
  get diagnostics v_count = row_count;
  if v_count = 0 then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy mục cấu hình.');
  end if;
end;
$$;

revoke execute on function app.assert_config_sales(text), app.tg_config_append_only(), app.tg_policy_scope_rules(),
  app.tg_sales_package_rules(), app.tg_package_price_rules(), app.tg_gift_policy_rules(), app.tg_discount_policy_fixed_kind(),
  app.tg_payment_term_fixed() from public, anon, authenticated;
revoke execute on function app.package_price_at(uuid, text, date), app.payment_term_amounts(uuid, bigint),
  app.save_sales_package(uuid, jsonb), app.add_package_price(uuid, text, bigint, date), app.save_discount_policy(uuid, jsonb),
  app.save_gift_policy(uuid, jsonb), app.create_payment_term(text, text, date, jsonb),
  app.set_config_active(text, uuid, boolean) from public, anon;
grant execute on function app.package_unit(text), app.package_price_at(uuid, text, date), app.payment_term_amounts(uuid, bigint),
  app.save_sales_package(uuid, jsonb), app.add_package_price(uuid, text, bigint, date), app.save_discount_policy(uuid, jsonb),
  app.save_gift_policy(uuid, jsonb), app.create_payment_term(text, text, date, jsonb),
  app.set_config_active(text, uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- Phiên bản ma trận quyền mới (Đ105): Xuất báo giá, đơn, phiếu thu chỉ Trưởng cơ sở (cơ sở mình), Kế toán, Admin.
-- So với ma trận hiện hành: bỏ Xuất báo giá của Sale và CSKH (2 ô); thêm cho Kế toán Xem và Xuất báo giá toàn hệ thống (2 ô; Xuất
-- đi kèm Xem, chỉ đọc). Xuất đơn và phiếu thu đã đúng (Trưởng cơ sở cơ sở mình, Kế toán, Admin). Sale vẫn in báo giá của mình
-- bằng quyền Xem (R-TIEN-08).
-- ---------------------------------------------------------------------------
select app.save_permission_matrix(
  app.permission_current_version(),
  (select jsonb_agg(jsonb_build_object('role', v.role, 'module', v.module, 'action', v.action, 'scope', v.scope))
   from (values
     ('SALES', 'QUOTATION', 'XUAT', null), ('CSKH', 'QUOTATION', 'XUAT', null),
     ('ACCOUNTANT', 'QUOTATION', 'XEM', 'TOAN_HE_THONG'), ('ACCOUNTANT', 'QUOTATION', 'XUAT', 'TOAN_HE_THONG')
   ) as v(role, module, action, scope)),
  'Đ105: Xuất báo giá, đơn, phiếu thu chỉ Trưởng cơ sở (cơ sở mình), Kế toán, Admin; Sale và CSKH bỏ Xuất báo giá');

select set_config('hmt.migration', '', false);
