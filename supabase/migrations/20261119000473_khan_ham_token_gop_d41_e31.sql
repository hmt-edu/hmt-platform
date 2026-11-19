-- Migration 473 (Code D, 19/11/2026, KHẨN): dựng lại hàm token đúng sau khi migration 507 (E31) đè mất phần D41 của 472. Chạy SAU 507 (theo tên tệp).
-- Hàm token = thân 472 (hai bước theo tham số mfa_required_enabled: hmt_require_mfa, hmt_mfa_optional) + claim hmt_must_change_password của 507 (app.first_password_change_required).
-- Kiểm thử: bài 473 kiểm cả hai nhóm claim; lần sau viết lại hàm này phải lấy thân từ bản mới nhất (migration này).

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
    -- E31 (R-HT-03, CHUNG-07): cờ «phải đổi mật khẩu lần đầu» chỉ có hiệu lực khi tham số của loại tài khoản (học sinh hoặc nhân viên) đang Bật (app.first_password_change_required, migration 507).
    'hmt_must_change_password', app.first_password_change_required(v_account),
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
