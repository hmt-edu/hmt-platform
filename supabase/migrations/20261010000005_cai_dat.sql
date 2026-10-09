-- GĐ0 bước 2: Cài đặt (tham số nghiệp vụ, tầng 2). docs/spec/03 mục "Cấu hình trên giao diện".
-- Khai báo: key, kiểu, đơn vị, min/max, mô tả, giá trị chung; ghi đè theo cơ sở nếu cho phép.
-- Code đọc qua app.get_setting*(key, branch_id). Thêm tham số mới = migration mới.

create table app.setting_def (
  id uuid primary key default gen_random_uuid(),
  key text not null unique check (key ~ '^[a-z][a-z0-9_]*$'),
  name text not null check (btrim(name) <> ''),
  value_type text not null check (value_type in ('INT', 'NUMERIC', 'BOOL', 'TEXT')),
  unit text,
  min_value numeric,
  max_value numeric,
  description text not null,
  value text not null,
  allow_branch_override boolean not null default true,
  module text,
  legacy_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (min_value is null or max_value is null or min_value <= max_value)
);

comment on table app.setting_def is 'Tham số nghiệp vụ: khai báo + giá trị chung. Ghi đè theo cơ sở ở setting_branch.';

create table app.setting_branch (
  id uuid primary key default gen_random_uuid(),
  setting_key text not null references app.setting_def (key),
  branch_id uuid not null references app.branch (id),
  value text not null,
  -- Bỏ ghi đè = is_active false (không xoá).
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (setting_key, branch_id)
);

comment on table app.setting_branch is 'Giá trị tham số ghi đè theo cơ sở.';

-- ---------------------------------------------------------------------------
-- Kiểm một giá trị đúng kiểu và trong khoảng của tham số. Báo lỗi nếu sai.
-- ---------------------------------------------------------------------------
create or replace function app.validate_setting_value(p_def app.setting_def, p_value text)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  v_number numeric;
begin
  -- Luật: giá trị không để trống.
  if p_value is null or btrim(p_value) = '' then
    perform app.raise_error('HMT_CAI_DAT_SAI_KIEU', format('Tham số "%s" không được để trống.', p_def.name));
  end if;

  -- Luật: đúng kiểu khai báo.
  if p_def.value_type = 'BOOL' then
    if p_value not in ('true', 'false') then
      perform app.raise_error('HMT_CAI_DAT_SAI_KIEU', format('Tham số "%s" chỉ nhận true hoặc false.', p_def.name));
    end if;
    return;
  end if;
  if p_def.value_type = 'TEXT' then
    return;
  end if;
  if p_def.value_type = 'INT' and p_value !~ '^-?[0-9]+$' then
    perform app.raise_error('HMT_CAI_DAT_SAI_KIEU', format('Tham số "%s" phải là số nguyên.', p_def.name));
  end if;
  if p_def.value_type = 'NUMERIC' and p_value !~ '^-?[0-9]+(\.[0-9]+)?$' then
    perform app.raise_error('HMT_CAI_DAT_SAI_KIEU', format('Tham số "%s" phải là số.', p_def.name));
  end if;

  -- Luật: nằm trong khoảng cho phép.
  v_number := p_value::numeric;
  if (p_def.min_value is not null and v_number < p_def.min_value)
     or (p_def.max_value is not null and v_number > p_def.max_value) then
    perform app.raise_error('HMT_CAI_DAT_NGOAI_KHOANG',
      format('Tham số "%s" phải từ %s đến %s %s.', p_def.name, p_def.min_value, p_def.max_value, coalesce(p_def.unit, '')));
  end if;
end;
$$;

-- Trigger kiểm giá trị chung (cả khi sửa thẳng trong Table Editor).
-- Khai báo (kiểu, khoảng, có cho ghi đè) chỉ đổi qua migration.
create or replace function app.tg_setting_def_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not app.is_migration() and (TG_OP = 'INSERT'
       or new.key is distinct from old.key
       or new.value_type is distinct from old.value_type
       or new.min_value is distinct from old.min_value
       or new.max_value is distinct from old.max_value
       or new.unit is distinct from old.unit
       or new.allow_branch_override is distinct from old.allow_branch_override) then
    perform app.raise_error('HMT_LUAT_LOI', 'Khai báo tham số (kiểu, khoảng, đơn vị) chỉ đổi qua migration; màn Cài đặt chỉ sửa giá trị.');
  end if;
  perform app.validate_setting_value(new, new.value);
  return new;
end;
$$;

create trigger setting_def_rules before insert or update on app.setting_def
  for each row execute function app.tg_setting_def_rules();

-- Trigger kiểm giá trị ghi đè theo cơ sở.
create or replace function app.tg_setting_branch_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_def app.setting_def;
begin
  select * into v_def from app.setting_def where key = new.setting_key;
  -- Luật: chỉ tham số cho phép ghi đè mới có giá trị riêng theo cơ sở.
  if not v_def.allow_branch_override then
    perform app.raise_error('HMT_KHONG_DUOC_GHI_DE',
      format('Tham số "%s" dùng chung, không ghi đè theo cơ sở được.', v_def.name));
  end if;
  if TG_OP = 'UPDATE' and (new.setting_key is distinct from old.setting_key or new.branch_id is distinct from old.branch_id) then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không đổi tham số hay cơ sở của một dòng ghi đè; hãy tạo dòng mới.');
  end if;
  perform app.validate_setting_value(v_def, new.value);
  return new;
end;
$$;

create trigger setting_branch_rules before insert or update on app.setting_branch
  for each row execute function app.tg_setting_branch_rules();

select app.apply_standard('app.setting_def');
select app.apply_standard('app.setting_branch');

alter table app.setting_def enable row level security;
alter table app.setting_branch enable row level security;
create policy setting_def_read on app.setting_def for select to authenticated using (true);
create policy setting_branch_read on app.setting_branch for select to authenticated using (true);
revoke all on app.setting_def, app.setting_branch from anon, authenticated;
grant select on app.setting_def, app.setting_branch to authenticated;

-- ---------------------------------------------------------------------------
-- Đọc tham số: giá trị ghi đè của cơ sở (nếu có, đang dùng) hoặc giá trị chung.
-- Ai gọi: mọi hàm nghiệp vụ. Kết quả dạng chữ; dùng các hàm get_setting_int/... bên dưới.
-- ---------------------------------------------------------------------------
create or replace function app.get_setting(p_key text, p_branch_id uuid default null)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_value text;
begin
  if not exists (select from app.setting_def where key = p_key) then
    perform app.raise_error('HMT_CAI_DAT_KHONG_CO', format('Chưa khai báo tham số "%s".', p_key));
  end if;
  select sb.value into v_value
    from app.setting_branch sb
   where sb.setting_key = p_key and sb.branch_id = p_branch_id and sb.is_active;
  if v_value is null then
    select value into v_value from app.setting_def where key = p_key;
  end if;
  return v_value;
end;
$$;

create or replace function app.get_setting_int(p_key text, p_branch_id uuid default null)
returns bigint
language sql
stable
set search_path = ''
as $$
  select app.get_setting(p_key, p_branch_id)::bigint;
$$;

create or replace function app.get_setting_numeric(p_key text, p_branch_id uuid default null)
returns numeric
language sql
stable
set search_path = ''
as $$
  select app.get_setting(p_key, p_branch_id)::numeric;
$$;

create or replace function app.get_setting_bool(p_key text, p_branch_id uuid default null)
returns boolean
language sql
stable
set search_path = ''
as $$
  select app.get_setting(p_key, p_branch_id)::boolean;
$$;

-- ---------------------------------------------------------------------------
-- Sửa tham số: giá trị chung (p_branch_id NULL) hoặc ghi đè của một cơ sở.
-- Kiểm kiểu và khoảng ở trigger; mọi lần sửa vào nhật ký (khung chung).
-- ---------------------------------------------------------------------------
create or replace function app.set_setting(p_key text, p_value text, p_branch_id uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_config_writer();
  if not exists (select from app.setting_def where key = p_key) then
    perform app.raise_error('HMT_CAI_DAT_KHONG_CO', format('Chưa khai báo tham số "%s".', p_key));
  end if;

  if p_branch_id is null then
    update app.setting_def set value = p_value where key = p_key;
    return;
  end if;

  insert into app.setting_branch (setting_key, branch_id, value)
  values (p_key, p_branch_id, p_value)
  on conflict (setting_key, branch_id) do update set value = excluded.value, is_active = true;
end;
$$;

-- Bỏ ghi đè của một cơ sở (dùng lại giá trị chung).
create or replace function app.clear_setting_override(p_key text, p_branch_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_config_writer();
  update app.setting_branch set is_active = false where setting_key = p_key and branch_id = p_branch_id;
end;
$$;

revoke execute on function app.set_setting(text, text, uuid), app.clear_setting_override(text, uuid) from public, anon;
grant execute on function
  app.set_setting(text, text, uuid), app.clear_setting_override(text, uuid),
  app.get_setting(text, uuid), app.get_setting_int(text, uuid),
  app.get_setting_numeric(text, uuid), app.get_setting_bool(text, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Khai báo tham số (chốt với anh Trường 10/10/2026). Mã luật cũ ở legacy_ref.
-- ---------------------------------------------------------------------------
select set_config('hmt.migration', 'on', false);
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('max_sessions_ahead', 'Cho học trước tối đa', 'INT', 'buổi', 0, 10, '2', true, 'VAN_HANH_LOP', null,
   'Số buổi học sinh được học vượt quá số giờ đã đóng.'),
  ('session_autoclose_before_minutes', 'Tự chốt buổi trước giờ học', 'INT', 'phút', 0, 240, '30', true, 'VAN_HANH_LOP', null,
   'Buổi tự chốt danh sách trước giờ học bao nhiêu phút.'),
  ('session_autoclose_scan_hours', 'Khoảng quét tự chốt buổi', 'INT', 'giờ', 1, 24, '2', true, 'VAN_HANH_LOP', null,
   'Mỗi lần quét, xét các buổi bắt đầu trong bao nhiêu giờ tới.'),
  ('teacher_session_complete_hours', 'Hạn giáo viên hoàn tất buổi', 'INT', 'giờ', 1, 72, '8', true, 'CONG_GIAO_VIEN', null,
   'Sau khi buổi kết thúc, giáo viên phải điểm danh và nhận xét đủ cả lớp trong bao nhiêu giờ.'),
  ('algebra_geometry_split_grade', 'Khối bắt đầu tách Đại/Hình', 'INT', 'khối', 2, 12, '7', false, 'VAN_HANH_LOP', null,
   'Từ khối này, lớp Toán chia thành lớp Đại số và lớp Hình học (spec 02).'),
  ('package_default_validity_months', 'Thời hạn gói mặc định', 'INT', 'tháng', 1, 24, '6', true, 'BAN_HANG', null,
   'Thời hạn dùng gói kể từ ngày bắt đầu, nếu gói không ghi thời hạn riêng.'),
  ('upsale_hours_left_threshold', 'Ngưỡng tái tục theo giờ còn lại', 'NUMERIC', 'giờ', 0, 100, '10', true, 'BAN_HANG', 'BR-UPSALE-HOUR',
   'Còn bằng hoặc ít hơn số giờ này thì cảnh báo, sinh phiếu tái tục. Chạy song song với ngưỡng theo ngày; chạm ngưỡng nào trước thì báo.'),
  ('upsale_days_left_threshold', 'Ngưỡng tái tục theo ngày hết giờ', 'INT', 'ngày', 0, 180, '30', true, 'BAN_HANG', 'BR-UPSALE-DAY',
   'Ngày hết giờ dự kiến còn bằng hoặc ít hơn số ngày này thì cảnh báo, sinh phiếu tái tục.'),
  ('absence_risk_sessions', 'Số buổi vắng gắn cờ rủi ro', 'INT', 'buổi', 1, 20, '3', true, 'VAN_HANH_LOP', null,
   'Học sinh vắng từ số buổi này trở lên thì gắn cờ rủi ro.'),
  ('quotation_validity_days', 'Hạn hiệu lực báo giá', 'INT', 'ngày', 1, 90, '14', true, 'BAN_HANG', null,
   'Báo giá hết hiệu lực sau số ngày này kể từ ngày lập.'),
  ('deposit_min_amount', 'Tiền cọc tối thiểu', 'INT', 'đồng', 0, 100000000, '1000000', true, 'BAN_HANG', null,
   'Số tiền đặt cọc tối thiểu khi giữ chỗ.'),
  ('reservation_max_months', 'Bảo lưu tối đa một lần', 'INT', 'tháng', 1, 24, '6', true, 'VAN_HANH_LOP', null,
   'Mỗi lần bảo lưu kéo dài tối đa số tháng này.');
select set_config('hmt.migration', '', false);
