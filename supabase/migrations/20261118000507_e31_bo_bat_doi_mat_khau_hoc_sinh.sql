-- E31 (anh Trường chốt 19/11/2026): «học sinh không cần đổi mật khẩu lần đầu, cần thì tự đổi sau».
-- Luật: R-HT-03 (mật khẩu tạm bắt đổi lần đầu), S03-02, CHUNG-07. Hai tham số Cài đặt, một hàm trợ giúp duy nhất:
--   first_password_change_required_student (mặc định TẮT) và first_password_change_required_staff (mặc định BẬT, giữ như cũ).
-- app.first_password_change_required(tài khoản) -> boolean: đúng khi tài khoản đang bị đánh dấu must_change_password VÀ tham số của loại tài khoản (có student_code = học sinh,
-- còn lại = nhân viên) đang Bật. Đọc thẳng app.setting_def (hàm định nghĩa quyền chủ DB) vì app.get_setting từ chối người không phải nhân viên đọc khoá lạ (D35, 470).
-- Dùng ở HAI chỗ duy nhất quyết định cờ này: app.current_user_ready (RLS, mọi hàm kiểm quyền) và token (hook đăng nhập: claim hmt_must_change_password cho giao diện).
-- Cờ must_change_password trong bảng vẫn giữ nguyên (mật khẩu tạm vẫn ngẫu nhiên, mỗi em một mật khẩu); tham số Bật lại thì áp lại cho người còn cờ.
-- Học sinh vẫn tự đổi mật khẩu ở màn tài khoản (NewPasswordForm) sau khi đăng nhập.
select set_config('hmt.migration', 'on', false);

insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, description)
values
  ('first_password_change_required_student', 'Học sinh bắt đổi mật khẩu lần đầu', 'BOOL', null, null, null, 'false', false, 'ADMIN',
   'Tắt (mặc định, anh Trường chốt 19/11): học sinh đăng nhập bằng mật khẩu tạm vào thẳng, tự đổi sau ở màn tài khoản. Bật: bắt đổi như nhân viên.'),
  ('first_password_change_required_staff', 'Nhân viên bắt đổi mật khẩu lần đầu', 'BOOL', null, null, null, 'true', false, 'ADMIN',
   'Bật (mặc định, giữ như cũ): nhân viên được cấp mật khẩu tạm phải đổi lần đầu. Tắt: vào thẳng.');

create or replace function app.first_password_change_required(p_account app.user_account)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_on text;
begin
  if p_account.id is null or not p_account.must_change_password then
    return false;
  end if;
  select value into v_on from app.setting_def
   where key = case when p_account.student_code is not null then 'first_password_change_required_student'
                    else 'first_password_change_required_staff' end;
  -- Thiếu tham số (không xảy ra sau migration này): coi như Bật, an toàn hơn.
  return coalesce(v_on, 'true') = 'true';
end;
$$;
revoke execute on function app.first_password_change_required(app.user_account) from public, anon, authenticated;

-- app.current_user_ready: như migration 13, chỉ đổi điều kiện «not must_change_password» thành «không bắt đổi mật khẩu lần đầu» (theo tham số).
create or replace function app.current_user_ready()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.user_account u
                  where u.id = auth.uid() and not u.is_locked and not app.first_password_change_required(u)
                    and u.session_version::text = auth.jwt() ->> 'hmt_session_version');
$$;

-- app.custom_access_token_hook: nguyên thân hàm của migration 14, chỉ đổi claim hmt_must_change_password.
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
    -- Luật R-HT-03, CHUNG-07 (E31): cờ «phải đổi mật khẩu lần đầu» chỉ có hiệu lực khi tham số của loại tài khoản (học sinh hoặc nhân viên) đang Bật.
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
    'hmt_require_mfa', exists (select from app.user_role ur join app.role r on r.code = ur.role_code
                                where ur.user_id = v_user_id and ur.is_active and r.require_mfa));
  return jsonb_build_object('claims', v_claims);
end;
$$;
