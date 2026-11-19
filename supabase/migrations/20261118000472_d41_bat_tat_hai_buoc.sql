-- Migration 472 (Code D, 19/11/2026): thẻ D41, bỏ bắt buộc xác thực hai bước cho Admin và Kế toán (anh Trường chốt 19/11/2026: «mỗi lần vào phải xác thực là không cần thiết»). CAO (quyền, bảo mật).
-- Làm bằng MỘT tham số mfa_required_enabled (BOOL, mặc định TẮT) đọc qua MỘT hàm trợ giúp duy nhất app.mfa_required_for_role; cờ require_mfa của vai trò giữ nguyên làm «vai trò nào thuộc diện».
-- Hai nơi dùng: app.mfa_satisfied() (kiểm quyền ở DB: tắt thì Admin, Kế toán đăng nhập mật khẩu có đủ quyền theo ma trận) và hook token (claim hmt_require_mfa cho giao diện bỏ bước /xac-thuc-hai-buoc).
-- Bật lại tham số thì hai bước bắt buộc trở lại như cũ (thiết bị TOTP đã cài vẫn còn). Mọi vai trò khác không đổi.

select set_config('hmt.migration', 'on', false);
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('mfa_required_enabled', 'Bắt buộc xác thực hai bước cho Admin và Kế toán', 'BOOL', null, null, null, 'false', false, 'ADMIN', 'R-HT',
   'Tắt (mặc định, anh Trường chốt 19/11/2026): Admin và Kế toán đăng nhập bằng mật khẩu là đủ. Bật: các vai trò có cờ hai bước bắt buộc phiên đạt aal2 mới có quyền.');
select set_config('hmt.migration', '', false);

-- app.mfa_enforced(): tham số mfa_required_enabled đang bật (toàn hệ thống). NỘI BỘ, đọc thẳng bảng tham số (không qua get_setting để không dính chặn theo phiên).
create or replace function app.mfa_enforced()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select d.value = 'true' from app.setting_def d where d.key = 'mfa_required_enabled'), false);
$$;

-- app.mfa_required_for_role(vai trò): vai trò này đang bị bắt buộc hai bước? = (cờ require_mfa của vai trò) và (tham số bật). MỘT hàm trợ giúp duy nhất.
create or replace function app.mfa_required_for_role(p_role_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app.mfa_enforced() and coalesce((select r.require_mfa from app.role r where r.code = p_role_code), false);
$$;

-- app.mfa_satisfied(): phiên đạt hai bước, hoặc không có vai trò nào đang bị bắt buộc (luật 03: Admin, Kế toán chỉ có quyền khi aal2, nay theo tham số).
create or replace function app.mfa_satisfied()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(auth.jwt() ->> 'aal', '') = 'aal2'
      or not exists (select from unnest(app.current_roles()) as c(code) where app.mfa_required_for_role(c.code));
$$;

revoke execute on function app.mfa_enforced(), app.mfa_required_for_role(text) from public, anon;
grant execute on function app.mfa_enforced(), app.mfa_required_for_role(text) to authenticated;

-- Hook token: thân bản migration 014, chỉ đổi hmt_require_mfa và thêm hmt_mfa_optional.
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
    -- D41: bắt buộc hai bước chỉ khi tham số mfa_required_enabled bật (một hàm trợ giúp duy nhất app.mfa_required_for_role). hmt_mfa_optional: vai trò CÓ cờ nhưng tham số tắt,
    -- để giao diện vẫn cho người đó cài thiết bị hai bước tự nguyện.
    'hmt_require_mfa', exists (select from app.user_role ur where ur.user_id = v_user_id and ur.is_active and app.mfa_required_for_role(ur.role_code)),
    'hmt_mfa_optional', not app.mfa_enforced()
                        and exists (select from app.user_role ur join app.role r on r.code = ur.role_code
                                     where ur.user_id = v_user_id and ur.is_active and r.require_mfa));
  return jsonb_build_object('claims', v_claims);
end;
$$;
