-- GĐ0 bước 3: vai trò, tài khoản, ma trận quyền, hàm kiểm quyền, hook đưa vai trò vào token.
-- Spec: docs/spec/03 mục "Đăng nhập", "Phân quyền"; chốt với anh Trường 10/10/2026:
-- một người nhiều vai trò (quyền là hợp), một cơ sở; ma trận sửa là áp ngay + nhật ký.

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Danh mục hệ thống cho phân quyền.
-- PERM_SCOPE: thứ tự (sort_order) = độ rộng, nhỏ hơn là rộng hơn.
-- ---------------------------------------------------------------------------
insert into app.catalog (code, name, kind, description, sort_order) values
  ('PERM_MODULE', 'Phân hệ (ma trận quyền)', 'HE_THONG', 'Đơn vị cấp quyền; chi tiết hơn danh mục MODULE của công tắc.', 40),
  ('PERM_ACTION', 'Hành động (ma trận quyền)', 'HE_THONG', null, 41),
  ('PERM_SCOPE', 'Phạm vi dữ liệu', 'HE_THONG', 'Thứ tự từ rộng tới hẹp.', 42);

insert into app.catalog_item (catalog_code, code, name, sort_order, legacy_ref) values
  ('PERM_MODULE', 'LEAD', 'Lead', 1, 'lead'),
  ('PERM_MODULE', 'OPPORTUNITY', 'Cơ hội', 2, 'opportunity'),
  ('PERM_MODULE', 'STUDENT_TEST', 'Kiểm tra đầu vào', 3, 'student_test'),
  ('PERM_MODULE', 'QUOTATION', 'Báo giá', 4, 'quotation'),
  ('PERM_MODULE', 'SALES_ORDER', 'Đơn hàng', 5, 'sales_order'),
  ('PERM_MODULE', 'RECEIPT', 'Phiếu thu, phiếu chi', 6, 'receipt'),
  ('PERM_MODULE', 'ACCOUNTING', 'Đối soát kế toán', 7, 'so_accounting'),
  ('PERM_MODULE', 'PARENT', 'Phụ huynh', 8, 'parent'),
  ('PERM_MODULE', 'STUDENT', 'Học sinh', 9, 'student'),
  ('PERM_MODULE', 'ENROLLMENT', 'Ghi danh', 10, 'enrollment'),
  ('PERM_MODULE', 'CLASS', 'Lớp học', 11, 'batch'),
  ('PERM_MODULE', 'SESSION', 'Buổi học', 12, 'session'),
  ('PERM_MODULE', 'ATTENDANCE', 'Điểm danh', 13, 'attendance'),
  ('PERM_MODULE', 'GRADING', 'Nhận xét, chấm bài', 14, null),
  ('PERM_MODULE', 'UPSALE', 'Phiếu tái tục', 15, 'upsale'),
  ('PERM_MODULE', 'TICKET', 'Ticket đề nghị, khiếu nại', 16, null),
  ('PERM_MODULE', 'REPORT', 'Báo cáo', 17, null),
  ('PERM_MODULE', 'LEARNING', 'Học tập (bài tập, nộp bài)', 18, null),
  ('PERM_MODULE', 'ADMIN', 'Quản trị (tài khoản, quyền, danh mục, Cài đặt, nhật ký)', 19, null),
  ('PERM_ACTION', 'XEM', 'Xem', 1, 'Can Read'),
  ('PERM_ACTION', 'TAO', 'Tạo', 2, 'Can Create'),
  ('PERM_ACTION', 'SUA', 'Sửa', 3, 'Can Edit'),
  ('PERM_ACTION', 'HUY', 'Huỷ', 4, 'Can Delete'),
  ('PERM_ACTION', 'DUYET', 'Duyệt', 5, 'Can Approve'),
  ('PERM_ACTION', 'XUAT', 'Xuất file', 6, 'Can Export'),
  ('PERM_ACTION', 'GIAO_VIEC', 'Giao việc', 7, 'Assign'),
  ('PERM_SCOPE', 'TOAN_HE_THONG', 'Toàn hệ thống', 1, 'ALL'),
  ('PERM_SCOPE', 'CO_SO', 'Cơ sở mình', 2, 'BRANCH'),
  ('PERM_SCOPE', 'DUOC_PHAN_CONG', 'Được phân công', 3, null),
  ('PERM_SCOPE', 'CUA_TOI', 'Của tôi', 4, null),
  ('PERM_SCOPE', 'CHINH_MINH', 'Chính mình', 5, null);

-- ---------------------------------------------------------------------------
-- Vai trò (spec 03). Mã cố định; Admin chỉ đổi tên hiển thị.
-- portals: cổng được vào (crm, gv, hoc). require_mfa: bắt xác thực hai bước.
-- ---------------------------------------------------------------------------
create table app.role (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z][A-Z_]*$'),
  name text not null check (btrim(name) <> ''),
  default_scope text not null,
  require_mfa boolean not null default false,
  portals text[] not null default '{}',
  -- Cổng chỉ xem (ADMIN vào cổng Giáo viên, Học tập để xem thử; chốt 10/10/2026).
  view_only_portals text[] not null default '{}',
  sort_order integer not null default 0,
  legacy_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  scope_catalog text not null default 'PERM_SCOPE' check (scope_catalog = 'PERM_SCOPE'),
  foreign key (scope_catalog, default_scope) references app.catalog_item (catalog_code, code)
);

comment on table app.role is 'Vai trò (spec 03). Mã và cấu trúc đổi qua migration; Admin đổi tên hiển thị.';

insert into app.role (code, name, default_scope, require_mfa, portals, view_only_portals, sort_order, legacy_ref) values
  ('ADMIN', 'Ban giám đốc, IT', 'TOAN_HE_THONG', true, '{crm,gv,hoc}', '{gv,hoc}', 1, 'ADMIN'),
  ('BRANCH_MANAGER', 'Trưởng cơ sở', 'CO_SO', false, '{crm}', '{}', 2, 'BRANCH_MANAGER'),
  ('SALES', 'Tuyển sinh', 'CO_SO', false, '{crm}', '{}', 3, 'SALES'),
  ('CSKH', 'Chăm sóc, vận hành lớp', 'CO_SO', false, '{crm}', '{}', 4, 'CSKH'),
  ('ACCOUNTANT', 'Kế toán', 'TOAN_HE_THONG', true, '{crm}', '{}', 5, 'ACCOUNTANT'),
  ('TEACHER', 'Giáo viên', 'DUOC_PHAN_CONG', false, '{gv}', '{}', 6, 'TEACHER'),
  ('TA', 'Trợ giảng', 'DUOC_PHAN_CONG', false, '{gv}', '{}', 7, null),
  ('STUDENT', 'Học sinh', 'CHINH_MINH', false, '{hoc}', '{}', 8, null),
  ('PARENT', 'Phụ huynh', 'CHINH_MINH', false, '{}', '{}', 9, null);

-- Luật: mã, phạm vi, cổng, xác thực hai bước của vai trò chỉ đổi qua migration.
create or replace function app.tg_role_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not app.is_migration() and (TG_OP = 'INSERT'
       or new.default_scope is distinct from old.default_scope
       or new.require_mfa is distinct from old.require_mfa
       or new.portals is distinct from old.portals
       or new.view_only_portals is distinct from old.view_only_portals) then
    perform app.raise_error('HMT_LUAT_LOI', 'Vai trò chỉ đổi được tên hiển thị; phạm vi, cổng, xác thực hai bước đổi qua migration.');
  end if;
  return new;
end;
$$;

create trigger role_rules before insert or update on app.role
  for each row execute function app.tg_role_rules();
create trigger role_code_immutable before update on app.role
  for each row execute function app.tg_code_immutable();
select app.apply_standard('app.role');

-- ---------------------------------------------------------------------------
-- Tài khoản người dùng: nối với auth.users. Khoá thay cho xoá.
-- ---------------------------------------------------------------------------
create table app.user_account (
  id uuid primary key references auth.users (id) on delete restrict,
  display_name text not null check (btrim(display_name) <> ''),
  -- Email đăng nhập (nhân viên) hoặc mã HS (học sinh). Không đổi.
  login_name text not null unique,
  branch_id uuid not null references app.branch (id),
  staff_code text unique check (staff_code ~ '^(NV|GV|TG)[0-9]+$'),
  student_code text unique check (student_code ~ '^HS[0-9]+$'),
  is_locked boolean not null default false,
  locked_at timestamptz,
  locked_by uuid,
  lock_reason text,
  must_change_password boolean not null default false,
  -- Khoá tạm sau nhiều lần đăng nhập sai (tham số login_lock_*).
  failed_login_count integer not null default 0,
  temp_locked_until timestamptz,
  last_login_at timestamptz,
  legacy_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

comment on table app.user_account is 'Tài khoản: vai trò ở user_role, một cơ sở. Nghỉ việc, dừng học thì khoá, không xoá.';
create index user_account_branch_idx on app.user_account (branch_id);

create table app.user_role (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references app.user_account (id),
  role_code text not null references app.role (code),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (user_id, role_code)
);

comment on table app.user_role is 'Vai trò của tài khoản (một người nhiều vai trò; quyền là hợp). Bỏ vai trò = is_active false.';

-- Luật: không đổi người, vai trò của một dòng gán vai trò; tài khoản không đổi login_name.
create or replace function app.tg_user_role_fixed()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id is distinct from old.user_id or new.role_code is distinct from old.role_code then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không đổi người hay vai trò của dòng gán vai trò; hãy thêm dòng mới.');
  end if;
  return new;
end;
$$;

create trigger user_role_fixed before update on app.user_role
  for each row execute function app.tg_user_role_fixed();

create or replace function app.tg_user_account_fixed()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.login_name is distinct from old.login_name then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không đổi tên đăng nhập của tài khoản.');
  end if;
  if new.staff_code is distinct from old.staff_code and old.staff_code is not null then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không đổi mã nhân viên, giáo viên đã cấp.');
  end if;
  if new.student_code is distinct from old.student_code and old.student_code is not null then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không đổi mã học sinh đã cấp.');
  end if;
  -- Luật: khoá thì ghi lúc khoá; mở khoá thì xoá thông tin khoá.
  if new.is_locked and not old.is_locked then
    new.locked_at := now();
    new.locked_by := app.current_actor();
  elsif not new.is_locked and old.is_locked then
    new.locked_at := null;
    new.locked_by := null;
    new.lock_reason := null;
  end if;
  return new;
end;
$$;

create trigger user_account_fixed before update on app.user_account
  for each row execute function app.tg_user_account_fixed();

select app.apply_standard('app.user_account');
select app.apply_standard('app.user_role');

-- ---------------------------------------------------------------------------
-- Ma trận quyền: vai trò × phân hệ × hành động → phạm vi. Bỏ quyền = is_active false.
-- ---------------------------------------------------------------------------
create table app.permission (
  id uuid primary key default gen_random_uuid(),
  role_code text not null references app.role (code),
  module_catalog text not null default 'PERM_MODULE' check (module_catalog = 'PERM_MODULE'),
  module_code text not null,
  action_catalog text not null default 'PERM_ACTION' check (action_catalog = 'PERM_ACTION'),
  action_code text not null,
  scope_catalog text not null default 'PERM_SCOPE' check (scope_catalog = 'PERM_SCOPE'),
  scope_code text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (role_code, module_code, action_code),
  foreign key (module_catalog, module_code) references app.catalog_item (catalog_code, code),
  foreign key (action_catalog, action_code) references app.catalog_item (catalog_code, code),
  foreign key (scope_catalog, scope_code) references app.catalog_item (catalog_code, code)
);

comment on table app.permission is 'Ma trận quyền. Sửa là áp ngay, có nhật ký (chốt 10/10/2026).';

create or replace function app.tg_permission_fixed()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_OP = 'UPDATE' and (new.role_code is distinct from old.role_code or new.module_code is distinct from old.module_code
     or new.action_code is distinct from old.action_code) then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không đổi vai trò, phân hệ, hành động của một dòng quyền; chỉ đổi phạm vi hoặc bật/tắt.');
  end if;
  -- Luật: phân hệ Quản trị chỉ cấp cho ADMIN.
  if new.module_code = 'ADMIN' and new.role_code <> 'ADMIN' and new.is_active then
    perform app.raise_error('HMT_QUYEN_QUAN_TRI', 'Phân hệ Quản trị chỉ cấp cho vai trò ADMIN.');
  end if;
  return new;
end;
$$;

create trigger permission_fixed before insert or update on app.permission
  for each row execute function app.tg_permission_fixed();
select app.apply_standard('app.permission');

select set_config('hmt.migration', '', false);

-- ---------------------------------------------------------------------------
-- Hàm đọc người đang thao tác. Vai trò, cơ sở lấy từ token (hook bên dưới) để RLS nhanh;
-- trạng thái khoá đọc trực tiếp mỗi lần để token cũ mất tác dụng ngay khi bị khoá.
-- ---------------------------------------------------------------------------

-- Vai trò trong token (mảng mã). Rỗng nếu chưa đăng nhập.
create or replace function app.current_roles()
returns text[]
language sql
stable
set search_path = ''
as $$
  select coalesce(array(select jsonb_array_elements_text(auth.jwt() -> 'hmt_roles')), '{}'::text[]);
$$;

-- Cơ sở trong token.
create or replace function app.current_branch_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select nullif(auth.jwt() ->> 'hmt_branch_id', '')::uuid;
$$;

-- Tài khoản đang dùng được: có tài khoản, không khoá, không đang khoá tạm.
-- security definer: đọc user_account mà không phụ thuộc RLS của người gọi.
create or replace function app.current_user_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.user_account
                  where id = auth.uid() and not is_locked);
$$;

-- Đã đổi mật khẩu lần đầu (nếu bị bắt đổi) chưa.
create or replace function app.current_user_ready()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.user_account
                  where id = auth.uid() and not is_locked and not must_change_password);
$$;

-- Luật: vai trò bắt xác thực hai bước (ADMIN, ACCOUNTANT) chỉ có quyền khi phiên đạt aal2.
create or replace function app.mfa_satisfied()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
      or not exists (select from app.role r
                      where r.code = any (app.current_roles()) and r.require_mfa);
$$;

-- Phạm vi rộng nhất người đang thao tác có với (phân hệ, hành động); NULL nếu không có quyền.
create or replace function app.permission_scope(p_module text, p_action text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select s.code
    from app.permission p
    join app.catalog_item s on s.catalog_code = 'PERM_SCOPE' and s.code = p.scope_code
   where p.role_code = any (app.current_roles())
     and p.module_code = p_module and p.action_code = p_action and p.is_active
     and app.current_user_ready() and app.mfa_satisfied()
   order by s.sort_order
   limit 1;
$$;

-- Có quyền (phân hệ, hành động) không, bất kể phạm vi.
create or replace function app.has_permission(p_module text, p_action text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select app.permission_scope(p_module, p_action) is not null;
$$;

-- Thấy được dữ liệu của cơ sở này với (phân hệ, hành động) không:
-- phạm vi Toàn hệ thống → mọi cơ sở; phạm vi hẹp hơn → chỉ cơ sở của mình.
-- (Phạm vi Được phân công, Của tôi, Chính mình còn lọc thêm ở bảng nghiệp vụ.)
create or replace function app.can_see_branch(p_module text, p_action text, p_branch_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case
           when v.scope is null then false
           when v.scope = 'TOAN_HE_THONG' then true
           else p_branch_id is not distinct from app.current_branch_id()
         end
    from (select app.permission_scope(p_module, p_action) as scope) as v;
$$;

-- ---------------------------------------------------------------------------
-- Hook Supabase Auth (custom access token): đưa vai trò, cơ sở vào token.
-- Tài khoản bị khoá: từ chối cấp token (không đăng nhập, không làm mới được).
-- Chạy với vai trò supabase_auth_admin.
-- ---------------------------------------------------------------------------
create or replace function app.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (event ->> 'user_id')::uuid;
  v_account app.user_account;
  v_claims jsonb := event -> 'claims';
  v_roles jsonb;
begin
  select * into v_account from app.user_account where id = v_user_id;

  -- Tài khoản chưa khai báo (vd tài khoản giả tạo tay): token không có vai trò → không có quyền gì.
  if v_account.id is null then
    return jsonb_build_object('claims', v_claims || jsonb_build_object('hmt_roles', '[]'::jsonb));
  end if;

  -- Luật: tài khoản bị khoá không được cấp token.
  if v_account.is_locked then
    return jsonb_build_object('error', jsonb_build_object(
      'http_code', 403, 'message', 'Tài khoản đã bị khoá. Liên hệ quản trị viên.')); -- allow-number: mã HTTP 403 theo chuẩn hook Supabase
  end if;

  select coalesce(jsonb_agg(ur.role_code order by r.sort_order), '[]'::jsonb) into v_roles
    from app.user_role ur join app.role r on r.code = ur.role_code
   where ur.user_id = v_user_id and ur.is_active;

  v_claims := v_claims || jsonb_build_object(
    'hmt_roles', v_roles,
    'hmt_branch_id', v_account.branch_id,
    'hmt_branch_code', (select code from app.branch where id = v_account.branch_id),
    'hmt_must_change_password', v_account.must_change_password,
    'hmt_name', v_account.display_name,
    -- Cổng dùng đầy đủ: vai trò nào đó cấp cổng mà không ghi là chỉ xem. Cổng chỉ xem: còn lại.
    'hmt_portals', (select coalesce(jsonb_agg(distinct p), '[]'::jsonb)
                      from app.user_role ur join app.role r on r.code = ur.role_code, unnest(r.portals) as p
                     where ur.user_id = v_user_id and ur.is_active and not (p = any (r.view_only_portals))),
    'hmt_view_only_portals', (select coalesce(jsonb_agg(distinct p), '[]'::jsonb)
                      from app.user_role ur join app.role r on r.code = ur.role_code, unnest(r.view_only_portals) as p
                     where ur.user_id = v_user_id and ur.is_active
                       and not exists (select from app.user_role ur2 join app.role r2 on r2.code = ur2.role_code
                                        where ur2.user_id = v_user_id and ur2.is_active
                                          and p = any (r2.portals) and not (p = any (r2.view_only_portals)))),
    'hmt_require_mfa', exists (select from app.user_role ur join app.role r on r.code = ur.role_code
                                where ur.user_id = v_user_id and ur.is_active and r.require_mfa));
  return jsonb_build_object('claims', v_claims);
end;
$$;

grant usage on schema app to supabase_auth_admin;
grant execute on function app.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function app.custom_access_token_hook(jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- RLS cho bảng mới.
-- ---------------------------------------------------------------------------
alter table app.role enable row level security;
alter table app.user_account enable row level security;
alter table app.user_role enable row level security;
alter table app.permission enable row level security;

create policy role_read on app.role for select to authenticated using (true);
create policy permission_read on app.permission for select to authenticated using (true);

-- Tài khoản: chính mình; người có quyền xem Quản trị (ADMIN) mọi tài khoản;
-- Trưởng cơ sở xem tài khoản cơ sở mình (quyền xem Học sinh/nhân sự cơ sở cấp sau).
create policy user_account_read on app.user_account for select to authenticated
  using (id = auth.uid()
         or app.has_permission('ADMIN', 'XEM')
         or ('BRANCH_MANAGER' = any (app.current_roles()) and app.current_user_ready()
             and branch_id = app.current_branch_id()));
create policy user_role_read on app.user_role for select to authenticated
  using (user_id = auth.uid()
         or app.has_permission('ADMIN', 'XEM')
         or exists (select from app.user_account a
                     where a.id = user_id and 'BRANCH_MANAGER' = any (app.current_roles())
                       and app.current_user_ready() and a.branch_id = app.current_branch_id()));

revoke all on app.role, app.user_account, app.user_role, app.permission from anon, authenticated;
grant select on app.role, app.user_account, app.user_role, app.permission to authenticated;

grant execute on function
  app.current_roles(), app.current_branch_id(), app.current_user_active(), app.current_user_ready(),
  app.mfa_satisfied(), app.permission_scope(text, text), app.has_permission(text, text),
  app.can_see_branch(text, text, uuid)
  to authenticated;
