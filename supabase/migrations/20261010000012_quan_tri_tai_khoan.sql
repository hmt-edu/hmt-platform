-- GĐ0 bước 3: mở schema app qua API (quyền do RLS + GRANT quyết định), siết quyền chạy hàm,
-- hàm quản trị tài khoản (gọi từ Edge Function admin-users bằng token của Admin), đổi mật khẩu lần đầu.

-- ---------------------------------------------------------------------------
-- Siết quyền: mặc định Postgres cho PUBLIC chạy mọi hàm. Thu lại toàn bộ trong schema app,
-- rồi cấp lại đúng những hàm người đã đăng nhập cần (đọc quyền, RLS, sửa cấu hình qua hàm có kiểm quyền).
-- ---------------------------------------------------------------------------
revoke execute on all functions in schema app from public, anon;
alter default privileges in schema app revoke execute on functions from public, anon;

grant execute on function
  app.raise_error(text, text), app.current_actor(), app.is_migration(), app.assert_config_writer(),
  app.current_roles(), app.current_branch_id(), app.current_user_active(), app.current_user_ready(),
  app.mfa_satisfied(), app.permission_scope(text, text), app.has_permission(text, text),
  app.can_see_branch(text, text, uuid), app.can_see_note_target(text, uuid),
  app.catalog_item_id(text, text), app.assert_catalog_code_active(text, text), app.is_holiday(date, uuid),
  app.get_setting(text, uuid), app.get_setting_int(text, uuid), app.get_setting_numeric(text, uuid),
  app.get_setting_bool(text, uuid), app.feature_enabled(text, uuid), app.require_feature(text, uuid),
  app.build_framework_code(text, text, text, text, integer), app.build_lesson_code(text, integer),
  app.build_package_code(text, text, text, text), app.session_type_deducts_hours(text),
  app.catalog_add_item(text, text, text, integer, uuid, uuid), app.catalog_rename_item(uuid, text),
  app.catalog_reorder_item(uuid, integer), app.catalog_set_item_active(uuid, boolean),
  app.set_setting(text, text, uuid), app.clear_setting_override(text, uuid), app.set_feature(text, uuid, boolean),
  app.add_note(text, uuid, text), app.cancel_note(uuid, text), app.set_permission(text, text, text, text),
  app.log_export(text, jsonb, integer), app.admin_hard_delete(regclass, uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Ảnh chụp mật khẩu tạm: khi Admin cấp/đặt lại mật khẩu, lưu mã băm hiện tại để biết người dùng
-- đã thật sự đổi sang mật khẩu khác chưa (không lưu mật khẩu, chỉ so mã băm của Supabase Auth).
-- ---------------------------------------------------------------------------
alter table app.user_account add column temp_password_hash text;
revoke select (temp_password_hash) on app.user_account from authenticated;

-- Luật: chỉ Admin (đã xác thực hai bước) quản trị tài khoản.
create or replace function app.assert_account_admin()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if not app.has_permission('ADMIN', 'SUA') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được quản lý tài khoản.');
  end if;
end;
$$;

-- Khai báo tài khoản HMT cho một người dùng Supabase Auth vừa tạo.
-- Ai gọi: Edge Function admin-users, bằng token của Admin. Mã NV/GV/TG: truyền vào để giữ số cũ,
-- hoặc NULL + p_staff_kind để cấp số mới. Học sinh: p_student_code bắt buộc.
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

  insert into app.user_account (id, display_name, login_name, branch_id, staff_code, student_code,
                                must_change_password, temp_password_hash)
  values (p_user_id, btrim(p_display_name), lower(btrim(p_login_name)), v_branch_id, v_staff_code, p_student_code,
          true, (select encrypted_password from auth.users where id = p_user_id));

  insert into app.user_role (user_id, role_code) select p_user_id, unnest(p_roles);
  return p_user_id;
end;
$$;

-- Đổi vai trò (bật vai trò trong danh sách, tắt vai trò ngoài danh sách). Áp từ lần cấp token sau.
create or replace function app.admin_set_roles(p_user_id uuid, p_roles text[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_account_admin();
  if p_roles is null or cardinality(p_roles) = 0 then
    perform app.raise_error('HMT_THIEU_VAI_TRO', 'Tài khoản phải có ít nhất một vai trò.');
  end if;
  update app.user_role set is_active = (role_code = any (p_roles)) where user_id = p_user_id;
  insert into app.user_role (user_id, role_code)
  select p_user_id, r from unnest(p_roles) as r
  on conflict (user_id, role_code) do update set is_active = true;
end;
$$;

-- Đổi cơ sở (nhân viên chuyển cơ sở).
create or replace function app.admin_set_branch(p_user_id uuid, p_branch_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_account_admin();
  update app.user_account set branch_id = (select id from app.branch where code = p_branch_code and is_active)
   where id = p_user_id;
end;
$$;

-- Khoá / mở khoá. Khoá thì token cũ mất tác dụng ngay (RLS kiểm trạng thái khoá mỗi lần gọi),
-- hook không cấp token mới; Edge Function cấm đăng nhập ở Supabase Auth.
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
end;
$$;

-- Sau khi Admin đặt lại mật khẩu (Edge Function đã đổi ở Supabase Auth): bắt đổi lần đầu, chụp mã băm mới.
create or replace function app.admin_mark_password_reset(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_account_admin();
  update app.user_account
     set must_change_password = true,
         temp_password_hash = (select encrypted_password from auth.users where id = p_user_id),
         failed_login_count = 0, temp_locked_until = null
   where id = p_user_id;
end;
$$;

-- Người dùng báo đã đổi mật khẩu lần đầu (sau khi gọi supabase.auth.updateUser).
-- Luật: chỉ chấp nhận khi mã băm mật khẩu đã khác mật khẩu tạm.
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
  if (select encrypted_password from auth.users where id = v_account.id) is not distinct from v_account.temp_password_hash then
    perform app.raise_error('HMT_CHUA_DOI_MAT_KHAU', 'Bạn chưa đổi sang mật khẩu mới.');
  end if;
  update app.user_account set must_change_password = false, temp_password_hash = null where id = v_account.id;
end;
$$;

grant execute on function
  app.assert_account_admin(),
  app.admin_create_account(uuid, text, text, text, text[], text, text, text),
  app.admin_set_roles(uuid, text[]), app.admin_set_branch(uuid, text),
  app.admin_set_locked(uuid, boolean, text), app.admin_mark_password_reset(uuid),
  app.complete_first_password_change()
  to authenticated;
-- Edge Function login gọi bằng khoá secret (service_role).
grant usage on schema app to service_role;
grant execute on function app.login_precheck(text), app.login_record(text, text, text, text) to service_role;
