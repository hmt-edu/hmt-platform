-- PR 6d: phiên bản ma trận quyền. Mỗi lần "Lưu thay đổi" là MỘT phiên bản mới, có hiệu lực ngay, không hẹn ngày;
-- lịch sử chỉ xem, không khôi phục (anh Trường chốt 10/10, 12/10; gói thiết kế P2 màn QT-05).
-- Spec: docs/spec/04 mục 12 (R-HT-*), docs/nghiep-vu/phan-quyen.md.

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Phiên bản: số thứ tự liền nhau, ai lưu, lúc nào, đổi bao nhiêu ô. Chỉ thêm, không sửa, không xoá.
-- ---------------------------------------------------------------------------
create table app.permission_version (
  id uuid primary key default gen_random_uuid(),
  version_no integer not null unique check (version_no >= 1),
  saved_by uuid,
  saved_at timestamptz not null default now(),
  changed_count integer not null check (changed_count >= 0),
  note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.permission_version is
  'Phiên bản ma trận quyền: mỗi lần Lưu một phiên bản, hiệu lực ngay. Chỉ thêm. Phiên bản 1 là bản khởi tạo.';

-- Ô đã đổi trong một phiên bản: từ → sang. "sang" rỗng (to_scope null) = bỏ quyền.
create table app.permission_change (
  id uuid primary key default gen_random_uuid(),
  version_id uuid not null references app.permission_version (id),
  role_code text not null references app.role (code),
  module_code text not null,
  action_code text not null,
  from_scope text,
  to_scope text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (version_id, role_code, module_code, action_code)
);
comment on table app.permission_change is
  'Ô quyền đổi trong một phiên bản (vai trò, phân hệ, hành động, phạm vi cũ → mới; rỗng = không có quyền). Chỉ thêm.';
create index permission_change_version_idx on app.permission_change (version_id);

select app.apply_standard('app.permission_version');
select app.apply_standard('app.permission_change');

-- Chỉ thêm: không sửa, không xoá (kể cả bằng migration thường).
create or replace function app.tg_permission_history_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform app.raise_error('HMT_LICH_SU_QUYEN_CHI_THEM',
    'Lịch sử phiên bản ma trận quyền chỉ thêm, không sửa hay xoá.');
  return null;
end;
$$;
create trigger permission_version_append_only before update on app.permission_version
  for each row execute function app.tg_permission_history_append_only();
create trigger permission_change_append_only before update on app.permission_change
  for each row execute function app.tg_permission_history_append_only();

-- Phiên bản 1: bản khởi tạo (ma trận lúc triển khai), không liệt kê từng ô.
insert into app.permission_version (version_no, saved_by, changed_count, note)
values (1, null, 0, 'Khởi tạo');

-- RLS: chỉ Quản trị xem lịch sử; không ai ghi trực tiếp (chỉ qua app.save_permission_matrix).
alter table app.permission_version enable row level security;
alter table app.permission_change enable row level security;
revoke all on app.permission_version, app.permission_change from public, anon, authenticated;
create policy permission_version_read on app.permission_version for select to authenticated
  using (app.has_permission('ADMIN', 'XEM'));
create policy permission_change_read on app.permission_change for select to authenticated
  using (app.has_permission('ADMIN', 'XEM'));
grant select on app.permission_version, app.permission_change to authenticated;

-- ---------------------------------------------------------------------------
-- app.permission_current_version(): số phiên bản hiện hành (mới nhất).
-- Ai gọi: người đã đăng nhập (màn QT-05 cần số này để gửi kèm khi Lưu).
-- ---------------------------------------------------------------------------
create or replace function app.permission_current_version()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select max(version_no) from app.permission_version;
$$;

-- ---------------------------------------------------------------------------
-- app.save_permission_matrix(phiên bản đang xem, danh sách ô đổi) → số phiên bản mới.
-- Làm gì: lưu một lần nhiều ô quyền của ma trận thành MỘT phiên bản mới, có hiệu lực ngay, trong một giao dịch:
--   hoặc đổi hết, hoặc không đổi ô nào.
-- Ai gọi: Quản trị · Sửa (ADMIN đã xác thực hai bước), hoặc kết nối thẳng DB (migration).
-- Đầu vào: p_base_version = phiên bản người dùng đang xem; p_changes = mảng JSON, mỗi phần tử
--   {"role": mã vai trò, "module": mã phân hệ, "action": mã hành động, "scope": mã phạm vi hoặc null (bỏ quyền)}.
-- Kết quả: số phiên bản mới. Ô không đổi thật (cùng phạm vi, hoặc bỏ ô đang không có) bị bỏ qua, không tính.
-- Luật:
--   (1) Phiên bản đang xem phải là phiên bản hiện hành, nếu không báo HMT_PHIEN_BAN_CU (có người vừa lưu).
--   (2) Phải có ít nhất một ô đổi thật, nếu không báo HMT_KHONG_CO_THAY_DOI và không tạo phiên bản.
--   (3) Vai trò, phân hệ, hành động, phạm vi phải có trong danh mục; một ô không xuất hiện hai lần.
--   (4) Phân hệ Quản trị chỉ cấp cho ADMIN (trigger của bảng quyền, báo HMT_QUYEN_QUAN_TRI).
-- ---------------------------------------------------------------------------
create or replace function app.save_permission_matrix(p_base_version integer, p_changes jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current integer;
  v_new_no integer;
  v_version_id uuid;
  v_count integer;
  v_cell record;
  v_eff jsonb;
begin
  perform app.assert_config_writer();

  -- Chỉ một người lưu tại một thời điểm.
  perform pg_advisory_xact_lock(hashtext('app.permission_matrix'));

  -- Luật (1): phiên bản đang xem phải là hiện hành.
  v_current := app.permission_current_version();
  if p_base_version is distinct from v_current then
    perform app.raise_error('HMT_PHIEN_BAN_CU',
      format('Ma trận quyền vừa được lưu thành phiên bản %s. Hãy tải lại rồi sửa tiếp.', v_current));
  end if;

  if p_changes is null or jsonb_typeof(p_changes) <> 'array' or jsonb_array_length(p_changes) = 0 then
    perform app.raise_error('HMT_KHONG_CO_THAY_DOI', 'Chưa có ô quyền nào thay đổi.');
  end if;

  -- Luật (3): một ô không xuất hiện hai lần; vai trò, phân hệ, hành động, phạm vi phải có trong danh mục.
  if exists (select from jsonb_array_elements(p_changes) e
             group by e ->> 'role', e ->> 'module', e ->> 'action' having count(*) > 1) then
    perform app.raise_error('HMT_O_QUYEN_SAI', 'Một ô quyền xuất hiện hai lần trong cùng lần lưu.');
  end if;
  select e ->> 'role' as role, e ->> 'module' as module, e ->> 'action' as action into v_cell
  from jsonb_array_elements(p_changes) e
  where not exists (select from app.role where code = e ->> 'role')
     or not exists (select from app.catalog_item where catalog_code = 'PERM_MODULE' and code = e ->> 'module')
     or not exists (select from app.catalog_item where catalog_code = 'PERM_ACTION' and code = e ->> 'action')
     or (nullif(e ->> 'scope', '') is not null
         and not exists (select from app.catalog_item where catalog_code = 'PERM_SCOPE' and code = e ->> 'scope'))
  limit 1;
  if v_cell.role is not null or v_cell.module is not null or v_cell.action is not null then
    perform app.raise_error('HMT_O_QUYEN_SAI',
      format('Ô quyền không hợp lệ: vai trò %s, phân hệ %s, hành động %s.', v_cell.role, v_cell.module, v_cell.action));
  end if;

  -- Chỉ giữ ô đổi thật, kèm phạm vi cũ (rỗng nếu chưa có hoặc đang tắt).
  select coalesce(jsonb_agg(jsonb_build_object(
           'role', r.role_code, 'module', r.module_code, 'action', r.action_code,
           'from', case when p.is_active then p.scope_code end, 'to', r.scope_code)), '[]'::jsonb)
    into v_eff
  from (select e ->> 'role' as role_code, e ->> 'module' as module_code, e ->> 'action' as action_code,
               nullif(e ->> 'scope', '') as scope_code
        from jsonb_array_elements(p_changes) e) r
  left join app.permission p
    on p.role_code = r.role_code and p.module_code = r.module_code and p.action_code = r.action_code
  where (case when p.is_active then p.scope_code end) is distinct from r.scope_code;

  -- Luật (2): phải có ô đổi thật.
  v_count := jsonb_array_length(v_eff);
  if v_count = 0 then
    perform app.raise_error('HMT_KHONG_CO_THAY_DOI', 'Không có ô quyền nào khác với hiện tại.');
  end if;

  -- Áp ngay từng ô (luật 4 nằm trong trigger bảng quyền); lỗi ở ô nào thì hoàn tác cả lần lưu.
  for v_cell in select e ->> 'role' as role, e ->> 'module' as module, e ->> 'action' as action, e ->> 'to' as to_scope
                from jsonb_array_elements(v_eff) e loop
    perform app.set_permission(v_cell.role, v_cell.module, v_cell.action, v_cell.to_scope);
  end loop;

  -- Ghi phiên bản và các ô đã đổi, cùng giao dịch.
  v_new_no := v_current + 1;
  insert into app.permission_version (version_no, saved_by, changed_count)
  values (v_new_no, auth.uid(), v_count)
  returning id into v_version_id;

  insert into app.permission_change (version_id, role_code, module_code, action_code, from_scope, to_scope)
  select v_version_id, e ->> 'role', e ->> 'module', e ->> 'action', e ->> 'from', e ->> 'to'
  from jsonb_array_elements(v_eff) e;

  return v_new_no;
end;
$$;

-- Ma trận chỉ đổi qua app.save_permission_matrix (mỗi lần một phiên bản). Hàm sửa từng ô là hàm nội bộ:
-- chỉ migration và kết nối thẳng DB gọi được, giao diện không gọi.
revoke execute on function app.set_permission(text, text, text, text) from authenticated;

revoke execute on function app.save_permission_matrix(integer, jsonb), app.permission_current_version()
  from public, anon;
grant execute on function app.save_permission_matrix(integer, jsonb), app.permission_current_version() to authenticated;

select set_config('hmt.migration', '', false);
