-- GĐ0 bước 3: sửa các lỗ hổng tìm thấy khi soát bảo mật (10/10/2026, PR #7). Mỗi mục có bài tái hiện trong
-- supabase/tests/database/008_soat_bao_mat.test.sql. Chi tiết: docs/nghiep-vu/phan-quyen.md mục "Soát bảo mật".

select set_config('hmt.migration', 'on', false);

-- ===========================================================================
-- C1. Mã băm mật khẩu tạm: chuyển sang bảng riêng không ai đọc được qua API, không ghi nhật ký thao tác.
-- (Thu quyền một cột không có tác dụng khi quyền đọc cả bảng user_account còn.)
-- ===========================================================================
create table app.user_temp_password (
  user_id uuid primary key references app.user_account (id),
  password_hash text not null,
  created_at timestamptz not null default now()
);
comment on table app.user_temp_password is
  'Mã băm mật khẩu tạm do Admin cấp, để biết người dùng đã đổi chưa. Chỉ hàm định nghĩa sẵn đọc; không ghi nhật ký.';
alter table app.user_temp_password enable row level security;
revoke all on app.user_temp_password from public, anon, authenticated, service_role;

insert into app.user_temp_password (user_id, password_hash)
select id, temp_password_hash from app.user_account where temp_password_hash is not null;
alter table app.user_account drop column temp_password_hash;

-- Ghi lại mã băm mật khẩu hiện tại của người dùng làm "mật khẩu tạm". Chỉ gọi từ hàm quản trị.
create or replace function app.remember_temp_password(p_user_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into app.user_temp_password (user_id, password_hash, created_at)
  select id, encrypted_password, now() from auth.users where id = p_user_id
  on conflict (user_id) do update set password_hash = excluded.password_hash, created_at = excluded.created_at;
$$;

-- Khai báo tài khoản HMT cho một người dùng Supabase Auth vừa tạo (như migration 012, đổi chỗ lưu mật khẩu tạm).
-- Ai gọi: Edge Function admin-users, bằng token của Admin.
create or replace function app.admin_create_account(
  p_user_id uuid, p_display_name text, p_login_name text, p_branch_code text, p_roles text[],
  p_staff_code text default null, p_staff_kind text default null, p_student_code text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
  v_staff_code text := p_staff_code;
  v_role text;
begin
  perform app.assert_account_admin();

  select id into v_branch_id from app.branch where code = p_branch_code and is_active;
  if v_branch_id is null then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', format('Cơ sở %s không có hoặc đã Ngừng.', p_branch_code));
  end if;
  -- Luật: phải có ít nhất một vai trò, và vai trò phải có thật.
  if p_roles is null or cardinality(p_roles) = 0 then
    perform app.raise_error('HMT_THIEU_VAI_TRO', 'Tài khoản phải có ít nhất một vai trò.');
  end if;
  foreach v_role in array p_roles loop
    if not exists (select from app.role where code = v_role) then
      perform app.raise_error('HMT_DANH_MUC_KHONG_CO', format('Không có vai trò %s.', v_role));
    end if;
  end loop;
  -- Luật: học sinh đăng nhập bằng mã HS; nhân viên không có mã HS.
  if 'STUDENT' = any (p_roles) and p_student_code is null then
    perform app.raise_error('HMT_THIEU_MA_HS', 'Tài khoản học sinh phải có mã học sinh.');
  end if;
  -- Cấp mã nhân viên, giáo viên, trợ giảng mới nếu chưa truyền mã cũ.
  if v_staff_code is null and p_staff_kind is not null then
    v_staff_code := app.issue_person_code(p_staff_kind);
  end if;

  insert into app.user_account (id, display_name, login_name, branch_id, staff_code, student_code, must_change_password)
  values (p_user_id, btrim(p_display_name), lower(btrim(p_login_name)), v_branch_id, v_staff_code, p_student_code, true);
  perform app.remember_temp_password(p_user_id);

  insert into app.user_role (user_id, role_code) select p_user_id, unnest(p_roles);
  return p_user_id;
end;
$$;

-- Sau khi Admin đặt lại mật khẩu (Edge Function đã đổi ở Supabase Auth): bắt đổi lần đầu, ghi mật khẩu tạm mới.
create or replace function app.admin_mark_password_reset(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_account_admin();
  update app.user_account
     set must_change_password = true, failed_login_count = 0, temp_locked_until = null
   where id = p_user_id;
  perform app.remember_temp_password(p_user_id);
end;
$$;

-- Người dùng báo đã đổi mật khẩu lần đầu. Luật: chỉ nhận khi mã băm đã khác mật khẩu tạm.
create or replace function app.complete_first_password_change()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account app.user_account;
begin
  select * into v_account from app.user_account where id = auth.uid() and not is_locked;
  if v_account.id is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Tài khoản không dùng được.');
  end if;
  if exists (select from app.user_temp_password t join auth.users u on u.id = t.user_id
              where t.user_id = v_account.id and u.encrypted_password is not distinct from t.password_hash) then
    perform app.raise_error('HMT_CHUA_DOI_MAT_KHAU', 'Bạn chưa đổi sang mật khẩu mới.');
  end if;
  update app.user_account set must_change_password = false where id = v_account.id;
  delete from app.user_temp_password where user_id = v_account.id;
end;
$$;

-- ===========================================================================
-- C2. Đang khoá tạm thì hook không cấp token (chặn đường gọi thẳng Supabase Auth đúng mật khẩu).
-- Khoá tạm là lớp thứ hai; lớp chính: Turnstile, giới hạn theo IP của Supabase Auth, xác thực hai bước.
-- ===========================================================================
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

  -- Luật: đang khoá tạm (sai mật khẩu nhiều lần) không được cấp token, kể cả khi gọi thẳng Supabase Auth.
  if v_account.temp_locked_until is not null and v_account.temp_locked_until > now() then
    return jsonb_build_object('error', jsonb_build_object(
      'http_code', 429, 'message', 'Đăng nhập tạm thời bị chặn, thử lại sau.')); -- allow-number: mã HTTP 429 theo chuẩn hook Supabase
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

-- ===========================================================================
-- T1. Ghi chú: vai trò bắt hai bước (ADMIN, Kế toán) chưa xác thực hai bước thì không thấy, không ghi.
-- ===========================================================================
create or replace function app.can_see_note_target(p_entity_type text, p_entity_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
begin
  if not app.current_user_ready() then
    return false;
  end if;
  -- Luật: vai trò bắt xác thực hai bước chưa đạt aal2 thì không có quyền gì (như has_permission).
  if not app.mfa_satisfied() then
    return false;
  end if;
  if app.has_permission('ADMIN', 'XEM') then
    return true;
  end if;
  if p_entity_type = 'BRANCH' then
    v_branch_id := p_entity_id;
  elsif p_entity_type = 'ROOM' then
    select branch_id into v_branch_id from app.room where id = p_entity_id;
  else
    return false;
  end if;
  return v_branch_id is not distinct from app.current_branch_id()
      or exists (select from app.role r where r.code = any (app.current_roles()) and r.default_scope = 'TOAN_HE_THONG');
end;
$$;

-- ===========================================================================
-- T2. Huỷ ghi chú: người viết chỉ huỷ được khi tài khoản còn dùng được (không khoá, token chưa bị thu hồi).
-- ===========================================================================
create or replace function app.cancel_note(p_note_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if nullif(auth.role(), '') is not null
     and not (app.current_user_ready()
              and exists (select from app.note where id = p_note_id and created_by = auth.uid()))
     and not app.has_permission('ADMIN', 'HUY') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ người viết hoặc quản trị viên được huỷ ghi chú.');
  end if;
  update app.note set is_cancelled = true, cancel_reason = p_reason where id = p_note_id and not is_cancelled;
  if not found then
    perform app.raise_error('HMT_GHI_CHU_KHONG_CO', 'Không tìm thấy ghi chú, hoặc ghi chú đã huỷ.');
  end if;
end;
$$;

-- ===========================================================================
-- T4. Khoá tạm: mỗi tên đăng nhập chỉ ghi một dòng KHOA_TAM trong mỗi đợt khoá
-- (đường này không qua Turnstile nên không được ghi vô hạn, tránh làm đầy DB).
-- ===========================================================================
create or replace function app.login_record(p_login_name text, p_result text, p_ip text, p_user_agent text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account app.user_account;
  v_name text := lower(btrim(p_login_name));
begin
  select * into v_account from app.user_account where login_name = v_name;

  -- Luật: đang khoá tạm thì chỉ ghi lần đầu trong login_lock_minutes phút.
  if p_result = 'KHOA_TAM' and exists (
       select from app.login_event
        where login_name = v_name and result = 'KHOA_TAM'
          and at > now() - make_interval(mins => app.get_setting_int('login_lock_minutes', v_account.branch_id)::integer)) then
    return;
  end if;

  insert into app.login_event (login_name, user_id, branch_id, result, ip, user_agent)
  values (v_name, v_account.id, v_account.branch_id,
          case when v_account.id is null and p_result = 'SAI_MAT_KHAU' then 'KHONG_CO_TAI_KHOAN' else p_result end,
          nullif(p_ip, '')::inet, left(p_user_agent, app.get_setting_int('login_user_agent_max_length')::integer));

  if v_account.id is null then
    return;
  end if;

  -- Luật: đăng nhập thành công → xoá đếm sai.
  if p_result = 'THANH_CONG' then
    update app.user_account
       set failed_login_count = 0, temp_locked_until = null, last_login_at = now()
     where id = v_account.id;
    return;
  end if;

  -- Luật: sai mật khẩu liên tiếp đủ login_lock_after_failures lần → khoá tạm login_lock_minutes phút.
  if p_result = 'SAI_MAT_KHAU' then
    update app.user_account
       set failed_login_count = failed_login_count + 1,
           temp_locked_until = case
             when failed_login_count + 1 >= app.get_setting_int('login_lock_after_failures', branch_id)
               then now() + make_interval(mins => app.get_setting_int('login_lock_minutes', branch_id)::integer)
             else temp_locked_until end
     where id = v_account.id;
  end if;
end;
$$;

-- ===========================================================================
-- L1. Xem tài khoản, vai trò, nhật ký đăng nhập theo ma trận quyền (phân hệ ACCOUNT), không viết cứng vai trò.
-- ===========================================================================
insert into app.catalog_item (catalog_code, code, name, sort_order)
values ('PERM_MODULE', 'ACCOUNT', 'Tài khoản người dùng (xem tài khoản, vai trò, nhật ký đăng nhập)', 20);

insert into app.permission (role_code, module_code, action_code, scope_code) values
  ('ADMIN', 'ACCOUNT', 'XEM', 'TOAN_HE_THONG'),
  ('ADMIN', 'ACCOUNT', 'XUAT', 'TOAN_HE_THONG'),
  ('BRANCH_MANAGER', 'ACCOUNT', 'XEM', 'CO_SO');

drop policy user_account_read on app.user_account;
create policy user_account_read on app.user_account for select to authenticated
  using (id = auth.uid() or app.can_see_branch('ACCOUNT', 'XEM', branch_id));

drop policy user_role_read on app.user_role;
create policy user_role_read on app.user_role for select to authenticated
  using (user_id = auth.uid()
         or exists (select from app.user_account a
                     where a.id = user_id and app.can_see_branch('ACCOUNT', 'XEM', a.branch_id)));

drop policy login_event_read on app.login_event;
create policy login_event_read on app.login_event for select to authenticated
  using (app.can_see_branch('ACCOUNT', 'XEM', branch_id));

-- ===========================================================================
-- T3. Hàm mới mặc định không ai ngoài chủ chạy được; khách (anon) không chạy được hàm nào trong app.
-- Thu ở mức toàn cục: thu theo schema (migration 012) không gỡ được quyền PUBLIC mặc định của Postgres.
-- Hàm nào cần cho người dùng thì cấp rõ bằng GRANT trong migration tạo ra nó.
-- ===========================================================================
alter default privileges for role postgres revoke execute on functions from public;
revoke execute on all functions in schema app from public, anon;
revoke execute on function app.remember_temp_password(uuid) from authenticated, service_role;

select set_config('hmt.migration', '', false);
