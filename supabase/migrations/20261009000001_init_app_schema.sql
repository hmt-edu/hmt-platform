-- HMT Platform: schema nền `app` + hàm kiểm tra kết nối.
-- Migration chỉ thêm mới; không sửa sau khi đã gộp vào main.

-- ---------------------------------------------------------------------------
-- Schema app: chứa bảng và hàm nghiệp vụ. Không đưa vào api.schemas,
-- nên PostgREST không lộ trực tiếp; giao diện gọi qua hàm trong public.
-- ---------------------------------------------------------------------------
create schema if not exists app;

grant usage on schema app to anon, authenticated;

-- ---------------------------------------------------------------------------
-- app.system_info: một dòng duy nhất mô tả hệ thống (dữ liệu hệ thống, không phải seed).
-- ---------------------------------------------------------------------------
create table app.system_info (
  id smallint primary key check (id = 1),
  app_name text not null,
  schema_version text not null,
  updated_at timestamptz not null default now()
);

comment on table app.system_info is 'Thông tin hệ thống, đúng một dòng (id = 1).';

alter table app.system_info enable row level security;

create policy system_info_select_all
  on app.system_info
  for select
  to anon, authenticated
  using (true);

revoke all on table app.system_info from anon, authenticated;
grant select on table app.system_info to anon, authenticated;

insert into app.system_info (id, app_name, schema_version)
values (1, 'HMT Platform', '0001');

-- ---------------------------------------------------------------------------
-- app.heartbeat: dòng nhịp để giữ project Supabase Free không bị tạm dừng.
-- RLS bật, không có policy, không cấp quyền cho anon/authenticated.
-- ---------------------------------------------------------------------------
create table app.heartbeat (
  id smallint primary key check (id = 1),
  beat_at timestamptz not null
);

comment on table app.heartbeat is 'Nhịp giữ project hoạt động; chỉ role postgres (CI) ghi.';

alter table app.heartbeat enable row level security;

revoke all on table app.heartbeat from anon, authenticated;

-- ---------------------------------------------------------------------------
-- public.system_status(): giao diện gọi qua rpc để kiểm tra kết nối DB.
-- security invoker: chạy với quyền người gọi, đọc app.system_info qua RLS.
-- ---------------------------------------------------------------------------
create or replace function public.system_status()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'app_name', si.app_name,
    'schema_version', si.schema_version,
    'db_time', now()
  )
  from app.system_info as si
  where si.id = 1;
$$;

comment on function public.system_status() is 'Trạng thái hệ thống: tên ứng dụng, phiên bản schema, giờ DB.';

revoke execute on function public.system_status() from public;
grant execute on function public.system_status() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- app.heartbeat(): ghi nhịp. Chỉ role postgres (CI nối bằng chuỗi kết nối DB) gọi.
-- ---------------------------------------------------------------------------
create or replace function app.heartbeat()
returns timestamptz
language sql
volatile
security definer
set search_path = ''
as $$
  insert into app.heartbeat as hb (id, beat_at)
  values (1, now())
  on conflict (id) do update set beat_at = excluded.beat_at
  returning hb.beat_at;
$$;

comment on function app.heartbeat() is 'Ghi nhịp giữ project Supabase Free hoạt động.';

revoke execute on function app.heartbeat() from public, anon, authenticated;
