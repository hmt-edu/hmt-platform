-- GĐ0 bước 2: danh mục (hệ thống và mở), cơ sở, năm học, phòng học, ngày nghỉ.
-- Spec: docs/spec/02-chuan-ma-va-danh-muc.md; docs/spec/03 mục "Cấu hình trên giao diện" tầng 1.
-- Luật chung: mã (code) không đổi, không xoá (chỉ Ngừng); danh mục hệ thống chỉ đổi tên, thứ tự.

-- ---------------------------------------------------------------------------
-- Định nghĩa các danh mục.
-- kind: HE_THONG = mã gắn với luật trong code (Admin chỉ đổi tên, thứ tự);
--       MO       = Admin thêm, đổi tên, đổi thứ tự, Ngừng.
-- parent_catalog: danh mục nhiều tầng (vd OPP_SUBSTAGE thuộc OPP_STAGE).
-- linked_catalog: mục được nối sang mục của danh mục khác (vd lý do huỷ test → OPP_SUBSTAGE).
-- ---------------------------------------------------------------------------
create table app.catalog (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z][A-Z0-9_]*$'),
  name text not null check (btrim(name) <> ''),
  kind text not null check (kind in ('HE_THONG', 'MO')),
  parent_catalog text references app.catalog (code),
  linked_catalog text references app.catalog (code),
  description text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

comment on table app.catalog is 'Định nghĩa danh mục. Mục nằm ở app.catalog_item.';

-- ---------------------------------------------------------------------------
-- Mục trong danh mục.
-- ---------------------------------------------------------------------------
create table app.catalog_item (
  id uuid primary key default gen_random_uuid(),
  catalog_code text not null references app.catalog (code),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_]*$'),
  name text not null check (btrim(name) <> ''),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  -- Mục có luật trong code bám vào (vd L5 tạo lịch test): đổi tên được, không Ngừng được.
  is_locked boolean not null default false,
  parent_id uuid references app.catalog_item (id),
  linked_item_id uuid references app.catalog_item (id),
  extra jsonb not null default '{}'::jsonb,
  legacy_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (catalog_code, code)
);

comment on table app.catalog_item is 'Mục danh mục: code không đổi, không xoá, Ngừng bằng is_active.';
create index catalog_item_parent_idx on app.catalog_item (parent_id);

-- ---------------------------------------------------------------------------
-- Cơ sở, năm học, phòng học, ngày nghỉ: bảng riêng vì có cột riêng.
-- ---------------------------------------------------------------------------
create table app.branch (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^CS[0-9]+$'),
  name text not null check (btrim(name) <> ''),
  address text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  legacy_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

comment on table app.branch is 'Cơ sở (danh mục mở). Không có CS3; không đánh số lại.';

create table app.academic_year (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[0-9]{4}$'),
  name text not null check (btrim(name) <> ''),
  start_date date not null,
  end_date date not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (end_date > start_date)
);

comment on table app.academic_year is 'Năm học: mã 2 số cuối năm đầu + 2 số cuối năm sau, vd 2627.';

create table app.room (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references app.branch (id),
  code text not null check (code ~ '^[A-Z0-9][A-Z0-9_]*$'),
  name text not null check (btrim(name) <> ''),
  capacity integer check (capacity > 0),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (branch_id, code)
);

comment on table app.room is 'Phòng học theo cơ sở (danh mục mở).';

create table app.holiday (
  id uuid primary key default gen_random_uuid(),
  holiday_date date not null,
  name text not null check (btrim(name) <> ''),
  -- NULL = áp cho mọi cơ sở.
  branch_id uuid references app.branch (id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique nulls not distinct (holiday_date, branch_id)
);

comment on table app.holiday is 'Ngày nghỉ lễ (thay BR-HOLIDAY-* cũ). branch_id NULL = mọi cơ sở.';

-- ---------------------------------------------------------------------------
-- Luật: mã không đổi được (mọi bảng danh mục).
-- ---------------------------------------------------------------------------
create or replace function app.tg_code_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.code is distinct from old.code then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC',
      format('Không đổi được mã "%s". Mã cấp một lần và giữ nguyên mãi.', old.code));
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Luật danh mục hệ thống: không thêm mục, không Ngừng, không đổi cấu trúc;
-- chỉ đổi tên hiển thị, thứ tự. Ngoại lệ duy nhất: migration đặt
-- hmt.migration = 'on' trong giao dịch (lời gọi qua API không đặt được biến này).
-- ---------------------------------------------------------------------------
create or replace function app.is_migration()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(current_setting('hmt.migration', true), '') = 'on';
$$;

create or replace function app.tg_catalog_item_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_catalog app.catalog%rowtype;
  v_parent app.catalog_item%rowtype;
  v_linked app.catalog_item%rowtype;
begin
  select * into v_catalog from app.catalog where code = new.catalog_code;

  -- Luật: mục không chuyển sang danh mục khác.
  if TG_OP = 'UPDATE' and new.catalog_code is distinct from old.catalog_code then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không chuyển mục sang danh mục khác được.');
  end if;

  -- Luật: danh mục hệ thống không thêm mục (trừ migration).
  if v_catalog.kind = 'HE_THONG' and TG_OP = 'INSERT' and not app.is_migration() then
    perform app.raise_error('HMT_DANH_MUC_HE_THONG',
      format('Danh mục hệ thống "%s" không thêm mục được; chỉ đổi tên hiển thị và thứ tự.', v_catalog.name));
  end if;

  -- Luật: danh mục hệ thống không Ngừng mục, không đổi mục cha/mục nối (trừ migration).
  if v_catalog.kind = 'HE_THONG' and TG_OP = 'UPDATE' and not app.is_migration()
     and (new.is_active is distinct from old.is_active
          or new.parent_id is distinct from old.parent_id
          or new.linked_item_id is distinct from old.linked_item_id
          or new.is_locked is distinct from old.is_locked) then
    perform app.raise_error('HMT_DANH_MUC_HE_THONG',
      format('Danh mục hệ thống "%s" chỉ đổi được tên hiển thị và thứ tự.', v_catalog.name));
  end if;

  -- Luật: mục bị khoá (có luật trong code bám vào) không Ngừng được.
  if TG_OP = 'UPDATE' and old.is_locked and old.is_active and not new.is_active and not app.is_migration() then
    perform app.raise_error('HMT_MUC_BI_KHOA',
      format('Mục "%s" đang được luật nghiệp vụ dùng nên không Ngừng được.', old.name));
  end if;

  -- Luật: danh mục nhiều tầng phải có mục cha đúng danh mục cha; một tầng thì không có mục cha.
  if v_catalog.parent_catalog is null and new.parent_id is not null then
    perform app.raise_error('HMT_MUC_CHA_SAI', format('Danh mục "%s" không có tầng cha.', v_catalog.name));
  end if;
  if v_catalog.parent_catalog is not null then
    select * into v_parent from app.catalog_item where id = new.parent_id;
    if v_parent.id is null or v_parent.catalog_code <> v_catalog.parent_catalog then
      perform app.raise_error('HMT_MUC_CHA_SAI',
        format('Mục "%s" phải thuộc một mục của danh mục %s.', new.name, v_catalog.parent_catalog));
    end if;
  end if;

  -- Luật: mục nối phải thuộc đúng danh mục được khai báo để nối.
  if new.linked_item_id is not null then
    select * into v_linked from app.catalog_item where id = new.linked_item_id;
    if v_catalog.linked_catalog is null or v_linked.catalog_code is distinct from v_catalog.linked_catalog then
      perform app.raise_error('HMT_MUC_NOI_SAI',
        format('Mục "%s" nối sai danh mục.', new.name));
    end if;
  end if;

  return new;
end;
$$;

create trigger catalog_item_rules
  before insert or update on app.catalog_item
  for each row execute function app.tg_catalog_item_rules();

-- Luật: định nghĩa danh mục chỉ đổi qua migration (tên, mô tả, thứ tự thì được).
create or replace function app.tg_catalog_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not app.is_migration() and (TG_OP = 'INSERT'
       or new.kind is distinct from old.kind
       or new.parent_catalog is distinct from old.parent_catalog
       or new.linked_catalog is distinct from old.linked_catalog) then
    perform app.raise_error('HMT_DANH_MUC_HE_THONG',
      'Thêm danh mục hoặc đổi loại, cấu trúc danh mục phải làm qua migration.');
  end if;
  return new;
end;
$$;

create trigger catalog_rules
  before insert or update on app.catalog
  for each row execute function app.tg_catalog_rules();

-- Gắn khung chung + chặn đổi mã cho các bảng danh mục.
select app.apply_standard('app.catalog');
select app.apply_standard('app.catalog_item');
select app.apply_standard('app.branch');
select app.apply_standard('app.academic_year');
select app.apply_standard('app.room');
select app.apply_standard('app.holiday');

create trigger catalog_code_immutable before update on app.catalog
  for each row execute function app.tg_code_immutable();
create trigger catalog_item_code_immutable before update on app.catalog_item
  for each row execute function app.tg_code_immutable();
create trigger branch_code_immutable before update on app.branch
  for each row execute function app.tg_code_immutable();
create trigger academic_year_code_immutable before update on app.academic_year
  for each row execute function app.tg_code_immutable();
create trigger room_code_immutable before update on app.room
  for each row execute function app.tg_code_immutable();

-- Phòng không chuyển cơ sở (mã phòng chỉ có nghĩa trong một cơ sở).
create or replace function app.tg_room_branch_fixed()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.branch_id is distinct from old.branch_id then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không chuyển phòng sang cơ sở khác được; hãy tạo phòng mới.');
  end if;
  return new;
end;
$$;

create trigger room_branch_fixed before update on app.room
  for each row execute function app.tg_room_branch_fixed();

-- ---------------------------------------------------------------------------
-- RLS: bước 2 chỉ cho người đã đăng nhập đọc; ghi qua hàm.
-- ---------------------------------------------------------------------------
alter table app.catalog enable row level security;
alter table app.catalog_item enable row level security;
alter table app.branch enable row level security;
alter table app.academic_year enable row level security;
alter table app.room enable row level security;
alter table app.holiday enable row level security;

create policy catalog_read on app.catalog for select to authenticated using (true);
create policy catalog_item_read on app.catalog_item for select to authenticated using (true);
create policy branch_read on app.branch for select to authenticated using (true);
create policy academic_year_read on app.academic_year for select to authenticated using (true);
create policy room_read on app.room for select to authenticated using (true);
create policy holiday_read on app.holiday for select to authenticated using (true);

revoke all on app.catalog, app.catalog_item, app.branch, app.academic_year, app.room, app.holiday
  from anon, authenticated;
grant select on app.catalog, app.catalog_item, app.branch, app.academic_year, app.room, app.holiday
  to authenticated;

-- ---------------------------------------------------------------------------
-- Hàm sửa danh mục (Admin dùng sau bước 3; bước 2 chỉ kết nối thẳng vào DB).
-- ---------------------------------------------------------------------------

-- Thêm mục vào danh mục mở. Trả về id mục mới.
-- Luật: chỉ danh mục MO; mã viết hoa không dấu (ràng buộc bảng); mục cha đúng tầng (trigger).
create or replace function app.catalog_add_item(
  p_catalog_code text, p_code text, p_name text,
  p_sort_order integer default null, p_parent_id uuid default null, p_linked_item_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform app.assert_config_writer();
  insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id, linked_item_id)
  values (p_catalog_code, upper(btrim(p_code)), btrim(p_name),
          coalesce(p_sort_order,
                   (select coalesce(max(sort_order), 0) + 1 from app.catalog_item where catalog_code = p_catalog_code)),
          p_parent_id, p_linked_item_id)
  returning id into v_id;
  return v_id;
end;
$$;

-- Đổi tên hiển thị (mọi danh mục).
create or replace function app.catalog_rename_item(p_item_id uuid, p_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_config_writer();
  update app.catalog_item set name = btrim(p_name) where id = p_item_id;
  if not found then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', 'Không tìm thấy mục danh mục.');
  end if;
end;
$$;

-- Đổi thứ tự (mọi danh mục).
create or replace function app.catalog_reorder_item(p_item_id uuid, p_sort_order integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_config_writer();
  update app.catalog_item set sort_order = p_sort_order where id = p_item_id;
  if not found then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', 'Không tìm thấy mục danh mục.');
  end if;
end;
$$;

-- Ngừng / dùng lại một mục (danh mục mở; luật danh mục hệ thống và mục khoá ở trigger).
create or replace function app.catalog_set_item_active(p_item_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_config_writer();
  update app.catalog_item set is_active = p_active where id = p_item_id;
  if not found then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', 'Không tìm thấy mục danh mục.');
  end if;
end;
$$;

-- Tìm id mục theo (danh mục, mã); báo lỗi nếu không có. Dùng trong hàm nghiệp vụ.
create or replace function app.catalog_item_id(p_catalog_code text, p_code text)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  v_id uuid;
begin
  select id into v_id from app.catalog_item where catalog_code = p_catalog_code and code = p_code;
  if v_id is null then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO',
      format('Không có mã "%s" trong danh mục %s.', p_code, p_catalog_code));
  end if;
  return v_id;
end;
$$;

-- Kiểm một mã đang dùng (có và chưa Ngừng); báo lỗi nếu không.
create or replace function app.assert_catalog_code_active(p_catalog_code text, p_code text)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if not exists (select from app.catalog_item
                  where catalog_code = p_catalog_code and code = p_code and is_active) then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO',
      format('Mã "%s" không có hoặc đã Ngừng trong danh mục %s.', p_code, p_catalog_code));
  end if;
end;
$$;

-- Ngày nghỉ: có phải ngày nghỉ của cơ sở này không (ngày nghỉ chung hoặc riêng cơ sở).
create or replace function app.is_holiday(p_date date, p_branch_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select from app.holiday
                  where holiday_date = p_date and is_active
                    and (branch_id is null or branch_id = p_branch_id));
$$;

revoke execute on function
  app.catalog_add_item(text, text, text, integer, uuid, uuid),
  app.catalog_rename_item(uuid, text),
  app.catalog_reorder_item(uuid, integer),
  app.catalog_set_item_active(uuid, boolean)
  from public, anon;
grant execute on function
  app.catalog_add_item(text, text, text, integer, uuid, uuid),
  app.catalog_rename_item(uuid, text),
  app.catalog_reorder_item(uuid, integer),
  app.catalog_set_item_active(uuid, boolean),
  app.catalog_item_id(text, text),
  app.assert_catalog_code_active(text, text),
  app.is_holiday(date, uuid)
  to authenticated;
