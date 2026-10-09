-- GĐ0 bước 2: công tắc tính năng theo cơ sở (phân hệ × cơ sở, mặc định tắt).
-- docs/spec/03 mục "Cấu hình trên giao diện". Kiểm cả ở giao diện và trong hàm DB.

create table app.feature_flag (
  id uuid primary key default gen_random_uuid(),
  module_catalog text not null default 'MODULE' check (module_catalog = 'MODULE'),
  module_code text not null,
  branch_id uuid not null references app.branch (id),
  enabled boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (module_code, branch_id),
  foreign key (module_catalog, module_code) references app.catalog_item (catalog_code, code)
);

comment on table app.feature_flag is 'Bật/tắt phân hệ theo cơ sở. Không có dòng = tắt.';

-- Không đổi phân hệ hay cơ sở của một dòng (chỉ bật/tắt).
create or replace function app.tg_feature_flag_fixed()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.module_code is distinct from old.module_code or new.branch_id is distinct from old.branch_id then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không đổi phân hệ hay cơ sở của công tắc; chỉ bật hoặc tắt.');
  end if;
  return new;
end;
$$;

create trigger feature_flag_fixed before update on app.feature_flag
  for each row execute function app.tg_feature_flag_fixed();

select app.apply_standard('app.feature_flag');

alter table app.feature_flag enable row level security;
create policy feature_flag_read on app.feature_flag for select to authenticated using (true);
revoke all on app.feature_flag from anon, authenticated;
grant select on app.feature_flag to authenticated;

-- Phân hệ có đang bật ở cơ sở này không. Không có dòng = tắt (mặc định).
create or replace function app.feature_enabled(p_module_code text, p_branch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select enabled from app.feature_flag
                    where module_code = p_module_code and branch_id = p_branch_id), false);
$$;

-- Hàm nghiệp vụ gọi ở đầu: báo lỗi nếu phân hệ đang tắt ở cơ sở.
create or replace function app.require_feature(p_module_code text, p_branch_id uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  v_module_name text;
  v_branch_code text;
begin
  if app.feature_enabled(p_module_code, p_branch_id) then
    return;
  end if;
  select name into v_module_name from app.catalog_item where catalog_code = 'MODULE' and code = p_module_code;
  select code into v_branch_code from app.branch where id = p_branch_id;
  perform app.raise_error('HMT_TINH_NANG_TAT',
    format('Phân hệ "%s" chưa bật ở cơ sở %s.', coalesce(v_module_name, p_module_code), coalesce(v_branch_code, '?')));
end;
$$;

-- Bật/tắt phân hệ ở một cơ sở.
create or replace function app.set_feature(p_module_code text, p_branch_id uuid, p_enabled boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_config_writer();
  perform app.assert_catalog_code_active('MODULE', p_module_code);
  insert into app.feature_flag (module_code, branch_id, enabled)
  values (p_module_code, p_branch_id, p_enabled)
  on conflict (module_code, branch_id) do update set enabled = excluded.enabled;
end;
$$;

revoke execute on function app.set_feature(text, uuid, boolean) from public, anon;
grant execute on function
  app.set_feature(text, uuid, boolean), app.feature_enabled(text, uuid), app.require_feature(text, uuid)
  to authenticated;
