-- GĐ0 bước 2: khung chung cho bảng nghiệp vụ và nhật ký thao tác.
-- Spec: docs/spec/03-dac-ta-giai-doan-0.md mục "Nền dữ liệu"; CLAUDE.md mục "Kiến trúc".
-- Migration chỉ thêm mới; không sửa sau khi đã gộp vào main.

-- ---------------------------------------------------------------------------
-- Báo lỗi nghiệp vụ: mã lỗi (HMT_...) nằm ở HINT, câu tiếng Việt ở MESSAGE
-- để giao diện hiện thẳng (Quy ước SQL mục 5).
-- ---------------------------------------------------------------------------
create or replace function app.raise_error(p_code text, p_message text)
returns void
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = 'P0001', message = p_message, hint = p_code;
end;
$$;

comment on function app.raise_error(text, text) is
  'Báo lỗi nghiệp vụ: MESSAGE là câu tiếng Việt, HINT là mã lỗi HMT_*.';

-- ---------------------------------------------------------------------------
-- Ai đang thao tác: id người dùng đăng nhập (auth.uid()), NULL = hệ thống
-- (migration, việc chạy nền).
-- ---------------------------------------------------------------------------
create or replace function app.current_actor()
returns uuid
language sql
stable
set search_path = ''
as $$
  select auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- Quyền sửa cấu hình (danh mục, cài đặt, công tắc) tạm thời ở bước 2:
-- chỉ kết nối thẳng vào DB (migration, SQL Editor của chủ project) được ghi;
-- mọi lời gọi qua API (có JWT) bị chặn. Bước 3 thay bằng ma trận quyền.
-- ---------------------------------------------------------------------------
create or replace function app.assert_config_writer()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  -- Luật: lời gọi qua API (có vai trò trong JWT) chưa được sửa cấu hình ở bước 2.
  if nullif(auth.role(), '') is not null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN',
      'Bạn chưa có quyền sửa cấu hình. Quyền chi tiết sẽ bật ở bước phân quyền.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách bảng có nhật ký (để nhật ký lưu số nhỏ thay cho tên bảng).
-- ---------------------------------------------------------------------------
create table app.audited_table (
  id smallint generated always as identity primary key,
  table_name text not null unique
);

comment on table app.audited_table is 'Bảng được ghi nhật ký; audit_log.table_id trỏ về đây.';

alter table app.audited_table enable row level security;
revoke all on table app.audited_table from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Nhật ký thao tác: chỉ thêm, không ai sửa/xoá được.
-- action: I = tạo (không chép dữ liệu, chỉ ghi ai/lúc nào),
--         U = sửa (chỉ trường đổi: {"cột": [cũ, mới]}),
--         D = xoá (chép cả dòng cũ; chỉ xảy ra khi Admin xoá bản ghi nhập nhầm, bước 3).
-- ---------------------------------------------------------------------------
create table app.audit_log (
  id bigint generated always as identity primary key,
  table_id smallint not null references app.audited_table (id),
  record_id uuid not null,
  action char(1) not null check (action in ('I', 'U', 'D')),
  changes jsonb,
  actor uuid,
  at timestamptz not null default now()
);

comment on table app.audit_log is 'Nhật ký thao tác (chỉ thêm). Xem docs/nghiep-vu/nen-du-lieu.md.';

create index audit_log_record_idx on app.audit_log (table_id, record_id, at);

alter table app.audit_log enable row level security;
-- Không policy nào: qua API không ai đọc/ghi trực tiếp. Bước 3 mở quyền đọc cho Admin.
revoke all on table app.audit_log from public, anon, authenticated, service_role;

-- Luật: nhật ký không sửa, không xoá, không truncate được (kể cả qua API).
create or replace function app.tg_audit_log_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform app.raise_error('HMT_NHAT_KY_CHI_THEM', 'Nhật ký thao tác chỉ được thêm, không được sửa hay xoá.');
  return null;
end;
$$;

create trigger audit_log_no_update_delete
  before update or delete on app.audit_log
  for each row execute function app.tg_audit_log_immutable();

create trigger audit_log_no_truncate
  before truncate on app.audit_log
  for each statement execute function app.tg_audit_log_immutable();

-- ---------------------------------------------------------------------------
-- Trigger ghi nhật ký dùng chung.
-- Đầu vào: TG_ARGV[0] = audited_table.id của bảng.
-- Bỏ qua các cột tự điền (created_*, updated_*) khi so sánh.
-- ---------------------------------------------------------------------------
create or replace function app.tg_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_table_id smallint := TG_ARGV[0]::smallint;
  v_old jsonb;
  v_new jsonb;
  v_changes jsonb;
begin
  -- Luật: tạo mới chỉ ghi "đã tạo", không chép dữ liệu (dữ liệu nằm ở bản ghi).
  if TG_OP = 'INSERT' then
    insert into app.audit_log (table_id, record_id, action, actor)
    values (v_table_id, new.id, 'I', app.current_actor());
    return new;
  end if;

  -- Luật: xoá chép cả dòng cũ để còn dấu vết.
  if TG_OP = 'DELETE' then
    insert into app.audit_log (table_id, record_id, action, changes, actor)
    values (v_table_id, old.id, 'D', to_jsonb(old), app.current_actor());
    return old;
  end if;

  -- Luật: sửa chỉ ghi trường thay đổi, dạng {"cột": [cũ, mới]}.
  v_old := to_jsonb(old) - array['created_at', 'created_by', 'updated_at', 'updated_by'];
  v_new := to_jsonb(new) - array['created_at', 'created_by', 'updated_at', 'updated_by'];
  select jsonb_object_agg(n.key, jsonb_build_array(v_old -> n.key, n.value))
    into v_changes
    from jsonb_each(v_new) as n
   where (v_old -> n.key) is distinct from n.value;

  -- Không có gì đổi thật (chỉ updated_*) thì không ghi.
  if v_changes is not null then
    insert into app.audit_log (table_id, record_id, action, changes, actor)
    values (v_table_id, new.id, 'U', v_changes, app.current_actor());
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Trigger tự điền người/giờ tạo, sửa. Không cho sửa created_*.
-- ---------------------------------------------------------------------------
create or replace function app.tg_fill_standard_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_OP = 'INSERT' then
    new.created_at := now();
    new.created_by := app.current_actor();
  else
    new.created_at := old.created_at;
    new.created_by := old.created_by;
  end if;
  new.updated_at := now();
  new.updated_by := app.current_actor();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Trigger chặn xoá: huỷ là đổi trạng thái (bảng nghiệp vụ) hoặc Ngừng (danh mục).
-- ---------------------------------------------------------------------------
create or replace function app.tg_block_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform app.raise_error('HMT_KHONG_XOA',
    'Không xoá được bản ghi. Hãy chuyển sang trạng thái Huỷ hoặc Ngừng.');
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- Gắn khung chung cho một bảng: tự điền người/giờ, ghi nhật ký, chặn xoá,
-- chỉ mục legacy_ref nếu có cột đó.
-- Ai gọi: chỉ migration. Bảng phải có cột id uuid, created_at/by, updated_at/by.
-- SQL động bắt buộc ở đây (Quy ước SQL mục 6): tạo trigger, chỉ mục cho bảng
-- truyền vào; tên bảng được quote bằng format(%s) từ regclass.
-- ---------------------------------------------------------------------------
create or replace function app.apply_standard(p_table regclass)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_name text := p_table::text;
  v_table_id smallint;
  v_short text := replace(replace(p_table::text, 'app.', ''), '.', '_');
begin
  insert into app.audited_table (table_name) values (v_name)
  on conflict (table_name) do update set table_name = excluded.table_name
  returning id into v_table_id;

  execute format('create trigger %I before insert or update on %s for each row execute function app.tg_fill_standard_columns()',
                 v_short || '_fill_standard', p_table);
  execute format('create trigger %I after insert or update or delete on %s for each row execute function app.tg_audit(%L)',
                 v_short || '_audit', p_table, v_table_id);
  execute format('create trigger %I before delete on %s for each row execute function app.tg_block_delete()',
                 v_short || '_no_delete', p_table);

  if exists (select from pg_attribute
              where attrelid = p_table and attname = 'legacy_ref' and not attisdropped) then
    execute format('create index if not exists %I on %s (legacy_ref)', v_short || '_legacy_ref_idx', p_table);
  end if;
end;
$$;

revoke execute on function app.apply_standard(regclass) from public, anon, authenticated;
revoke execute on function app.raise_error(text, text) from public, anon;
grant execute on function app.raise_error(text, text) to authenticated;
