-- GĐ0 bước 3 (sửa theo góp ý anh Trường 10/10/2026, PR #7):
-- 1. Không để hệ thống mất ADMIN cuối cùng còn hoạt động.
-- 2. Bỏ bớt vai trò, đổi cơ sở, khoá tài khoản → thu hồi mọi phiên: token cũ mất tác dụng ngay.
-- 3. Đăng nhập: tài khoản không có cũng bị khoá tạm như tài khoản có (không lộ ai có tài khoản).
-- Chi tiết: docs/nghiep-vu/phan-quyen.md.

-- ---------------------------------------------------------------------------
-- 1. ADMIN cuối cùng
-- ---------------------------------------------------------------------------

-- Số ADMIN còn hoạt động (vai trò ADMIN đang bật, tài khoản không khoá).
create or replace function app.active_admin_count()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
    from app.user_role ur join app.user_account a on a.id = ur.user_id
   where ur.role_code = 'ADMIN' and ur.is_active and not a.is_locked;
$$;

-- Trigger: sau khi tắt vai trò ADMIN hoặc khoá một ADMIN, phải còn ít nhất một ADMIN hoạt động.
-- Chạy ở mọi đường sửa (hàm quản trị, SQL trực tiếp). Khoá chung theo bảng user_role để hai giao dịch
-- song song không cùng lúc gỡ hai ADMIN cuối (giao dịch sau chờ, rồi đếm lại thấy đã hết).
create or replace function app.tg_keep_last_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if TG_TABLE_NAME = 'user_role' then
    -- Chỉ xét khi dòng ADMIN đang bật bị tắt.
    if not (old.role_code = 'ADMIN' and old.is_active and not new.is_active) then
      return null;
    end if;
  else
    -- Chỉ xét khi tài khoản đang có ADMIN bật bị khoá.
    if not (new.is_locked and not old.is_locked
            and exists (select from app.user_role where user_id = new.id and role_code = 'ADMIN' and is_active)) then
      return null;
    end if;
  end if;

  perform pg_advisory_xact_lock('app.user_role'::regclass::oid::bigint);
  -- Luật: luôn còn ít nhất một ADMIN hoạt động.
  if app.active_admin_count() = 0 then
    perform app.raise_error('HMT_ADMIN_CUOI_CUNG',
      'Không thể khoá hoặc bỏ vai trò của quản trị viên cuối cùng. Hãy cấp vai trò ADMIN cho người khác trước.');
  end if;
  return null;
end;
$$;

create trigger user_role_keep_last_admin after update of is_active on app.user_role
  for each row execute function app.tg_keep_last_admin();
create trigger user_account_keep_last_admin after update of is_locked on app.user_account
  for each row execute function app.tg_keep_last_admin();

-- ---------------------------------------------------------------------------
-- 2. Thu hồi phiên
-- Vai trò, cơ sở nằm trong token (RLS nhanh). Muốn bỏ quyền có tác dụng ngay thì token cũ phải chết:
-- mỗi tài khoản có số phiên bản phiên; token ghi số lúc cấp; RLS so với số hiện tại.
-- Thu hồi = tăng số (mọi token cũ chết) + xoá phiên ở Supabase Auth (không làm mới token được nữa, phải đăng nhập lại).
-- ---------------------------------------------------------------------------
alter table app.user_account add column session_version integer not null default 0;
comment on column app.user_account.session_version is
  'Tăng khi thu hồi phiên (khoá, bỏ vai trò, đổi cơ sở). Token mang số cũ mất tác dụng.';

-- Thu hồi mọi phiên của một người. Chỉ gọi từ hàm quản trị (không cấp cho người dùng).
create or replace function app.revoke_user_sessions(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update app.user_account set session_version = session_version + 1 where id = p_user_id;
  delete from auth.sessions where user_id = p_user_id;
end;
$$;
revoke execute on function app.revoke_user_sessions(uuid) from public, anon, authenticated;

-- Token còn hiệu lực: số phiên bản trong token bằng số hiện tại của tài khoản.
-- Đặt chung vào current_user_active / current_user_ready để mọi RLS, hàm kiểm quyền đều áp.
create or replace function app.current_user_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.user_account
                  where id = auth.uid() and not is_locked
                    and session_version::text = auth.jwt() ->> 'hmt_session_version');
$$;

create or replace function app.current_user_ready()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.user_account
                  where id = auth.uid() and not is_locked and not must_change_password
                    and session_version::text = auth.jwt() ->> 'hmt_session_version');
$$;

-- Hook: ghi thêm số phiên bản phiên vào token (phần còn lại giữ như migration 009).
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
    'hmt_session_version', v_account.session_version,
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

-- Đổi vai trò. Luật: bỏ bớt vai trò thì thu hồi mọi phiên (quyền bị bỏ mất tác dụng ngay);
-- chỉ thêm vai trò thì không (áp từ lần cấp token sau).
create or replace function app.admin_set_roles(p_user_id uuid, p_roles text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_removed integer;
begin
  perform app.assert_account_admin();
  if p_roles is null or cardinality(p_roles) = 0 then
    perform app.raise_error('HMT_THIEU_VAI_TRO', 'Tài khoản phải có ít nhất một vai trò.');
  end if;

  update app.user_role set is_active = false
   where user_id = p_user_id and is_active and not (role_code = any (p_roles));
  get diagnostics v_removed = row_count;

  insert into app.user_role (user_id, role_code)
  select p_user_id, r from unnest(p_roles) as r
  on conflict (user_id, role_code) do update set is_active = true;

  if v_removed > 0 then
    perform app.revoke_user_sessions(p_user_id);
  end if;
end;
$$;

-- Đổi cơ sở. Luật: cơ sở nằm trong token nên đổi cơ sở cũng thu hồi phiên.
create or replace function app.admin_set_branch(p_user_id uuid, p_branch_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
begin
  perform app.assert_account_admin();
  select id into v_branch_id from app.branch where code = p_branch_code and is_active;
  if v_branch_id is null then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', format('Cơ sở %s không có hoặc đã Ngừng.', p_branch_code));
  end if;
  update app.user_account set branch_id = v_branch_id where id = p_user_id and branch_id <> v_branch_id;
  if found then
    perform app.revoke_user_sessions(p_user_id);
  end if;
end;
$$;

-- Khoá / mở khoá. Khoá thì thu hồi mọi phiên (ngoài việc RLS đã chặn tài khoản khoá).
create or replace function app.admin_set_locked(p_user_id uuid, p_locked boolean, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_account_admin();
  -- Luật: khoá bắt buộc lý do; không tự khoá chính mình.
  if p_locked and (p_reason is null or btrim(p_reason) = '') then
    perform app.raise_error('HMT_THIEU_LY_DO', 'Phải ghi lý do khoá tài khoản.');
  end if;
  if p_locked and p_user_id = auth.uid() then
    perform app.raise_error('HMT_KHONG_TU_KHOA', 'Không tự khoá tài khoản của mình.');
  end if;
  update app.user_account
     set is_locked = p_locked, lock_reason = case when p_locked then btrim(p_reason) end,
         failed_login_count = 0, temp_locked_until = null
   where id = p_user_id;
  if p_locked then
    perform app.revoke_user_sessions(p_user_id);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Khoá tạm cả tên đăng nhập không có tài khoản, cùng luật với tài khoản có:
-- sai liên tiếp login_lock_after_failures lần → chặn login_lock_minutes phút kể từ lần sai cuối.
-- Nhờ vậy người ngoài không phân biệt được tên nào có tài khoản qua việc có bị khoá tạm hay không.
-- ---------------------------------------------------------------------------
create or replace function app.login_precheck(p_login_name text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name text := lower(btrim(p_login_name));
  v_account app.user_account;
  v_failures integer;
  v_last_failure timestamptz;
begin
  select * into v_account from app.user_account where login_name = v_name;

  if v_account.id is not null then
    if v_account.is_locked then
      return 'TAI_KHOAN_KHOA';
    end if;
    if v_account.temp_locked_until is not null and v_account.temp_locked_until > now() then
      return 'KHOA_TAM';
    end if;
    return 'OK';
  end if;

  -- Tên không có tài khoản: không có lần đúng nào nên mọi lần sai đều là "liên tiếp".
  select count(*)::integer, max(at) into v_failures, v_last_failure
    from app.login_event where login_name = v_name and result = 'KHONG_CO_TAI_KHOAN';
  if v_failures >= app.get_setting_int('login_lock_after_failures')
     and v_last_failure + make_interval(mins => app.get_setting_int('login_lock_minutes')::integer) > now() then
    return 'KHOA_TAM';
  end if;
  return 'OK';
end;
$$;

revoke execute on function app.login_precheck(text), app.active_admin_count() from public, anon, authenticated;
grant execute on function app.login_precheck(text) to service_role;
