-- GĐ0 bước 2: ghi chú trao đổi dùng chung, gắn được vào mọi loại bản ghi.
-- docs/spec/03 mục "Nền dữ liệu" (Ghi chú trao đổi).

-- ---------------------------------------------------------------------------
-- Các loại bản ghi được gắn ghi chú. Bảng nghiệp vụ mới đăng ký thêm bằng migration.
-- ---------------------------------------------------------------------------
create table app.note_target (
  entity_type text primary key check (entity_type ~ '^[A-Z][A-Z0-9_]*$'),
  table_name regclass not null unique,
  name text not null
);

comment on table app.note_target is 'Loại bản ghi được gắn ghi chú (đăng ký qua migration).';

alter table app.note_target enable row level security;
create policy note_target_read on app.note_target for select to authenticated using (true);
revoke all on app.note_target from anon, authenticated;
grant select on app.note_target to authenticated;

insert into app.note_target (entity_type, table_name, name) values
  ('BRANCH', 'app.branch', 'Cơ sở'),
  ('ROOM', 'app.room', 'Phòng học'),
  ('CATALOG_ITEM', 'app.catalog_item', 'Mục danh mục'),
  ('SETTING', 'app.setting_def', 'Tham số');

-- ---------------------------------------------------------------------------
-- Ghi chú. Huỷ thay cho xoá; sửa nội dung có nhật ký.
-- ---------------------------------------------------------------------------
create table app.note (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null references app.note_target (entity_type),
  entity_id uuid not null,
  body text not null check (btrim(body) <> ''),
  is_cancelled boolean not null default false,
  cancelled_at timestamptz,
  cancelled_by uuid,
  cancel_reason text,
  legacy_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

comment on table app.note is 'Ghi chú trao đổi gắn vào bản ghi bất kỳ đã đăng ký ở note_target.';
create index note_entity_idx on app.note (entity_type, entity_id, created_at);

-- Luật: ghi chú phải gắn vào bản ghi có thật; không chuyển sang bản ghi khác.
-- SQL động bắt buộc (Quy ước SQL mục 6): bảng đích tuỳ loại bản ghi, lấy từ note_target
-- (regclass, không do người dùng gõ).
create or replace function app.tg_note_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_table regclass;
  v_exists boolean;
begin
  if TG_OP = 'UPDATE' and (new.entity_type is distinct from old.entity_type or new.entity_id is distinct from old.entity_id) then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không chuyển ghi chú sang bản ghi khác được.');
  end if;

  select table_name into v_table from app.note_target where entity_type = new.entity_type;
  if v_table is null then
    perform app.raise_error('HMT_GHI_CHU_LOAI_KHONG_CO',
      format('Loại bản ghi "%s" chưa được đăng ký để gắn ghi chú.', new.entity_type));
  end if;
  execute format('select exists (select from %s where id = $1)', v_table) into v_exists using new.entity_id;
  if not v_exists then
    perform app.raise_error('HMT_GHI_CHU_DOI_TUONG_KHONG_CO', 'Bản ghi cần gắn ghi chú không tồn tại.');
  end if;

  -- Luật: huỷ thì ghi lại ai, lúc nào.
  if TG_OP = 'UPDATE' and new.is_cancelled and not old.is_cancelled then
    new.cancelled_at := now();
    new.cancelled_by := app.current_actor();
  end if;
  return new;
end;
$$;

create trigger note_rules before insert or update on app.note
  for each row execute function app.tg_note_rules();

select app.apply_standard('app.note');

alter table app.note enable row level security;
-- Bước 2 chưa mở đọc/ghi ghi chú qua API (ghi chú có thể chứa thông tin nhạy cảm);
-- bước 3 thêm policy theo quyền của bản ghi được gắn.
revoke all on app.note from anon, authenticated;

-- Thêm ghi chú. Trả về id ghi chú.
create or replace function app.add_note(p_entity_type text, p_entity_id uuid, p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform app.assert_config_writer();
  insert into app.note (entity_type, entity_id, body) values (p_entity_type, p_entity_id, btrim(p_body))
  returning id into v_id;
  return v_id;
end;
$$;

-- Huỷ ghi chú (không xoá).
create or replace function app.cancel_note(p_note_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_config_writer();
  update app.note set is_cancelled = true, cancel_reason = p_reason where id = p_note_id and not is_cancelled;
  if not found then
    perform app.raise_error('HMT_GHI_CHU_KHONG_CO', 'Không tìm thấy ghi chú, hoặc ghi chú đã huỷ.');
  end if;
end;
$$;

revoke execute on function app.add_note(text, uuid, text), app.cancel_note(uuid, text) from public, anon;
grant execute on function app.add_note(text, uuid, text), app.cancel_note(uuid, text) to authenticated;
