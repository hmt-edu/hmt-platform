-- Người dùng đợt 1 (anh chốt Q-M1, Q-M4 ngày 06/11): cột tên đăng nhập riêng (username) và Sửa email.
-- Làm gì: (1) cột `username` (duy nhất không phân biệt hoa thường, không đổi sau khi đã có), sao chép từ `legacy_ref` cho tài khoản đã nạp;
-- (2) hàm tạo tài khoản nhận thêm tên đăng nhập (kiểm dạng, trùng); (3) hàm kiểm tên đăng nhập, email còn trống (báo ngay ở ô); (4) đặt tên đăng nhập một lần
-- cho tài khoản chưa có (Admin tạo bằng Bootstrap admin); (5) Sửa email: Admin đổi email đăng nhập của NGƯỜI KHÁC (không tự đổi), không trùng,
-- thu hồi mọi phiên cũ, ghi nhật ký; tên đăng nhập không đổi. Đăng nhập vẫn bằng email; đăng nhập bằng tên đăng nhập làm sau (13 đến 14/11), chạy song song.
-- Luật: R-V2-08 (tên đăng nhập), R-HT-01 (Admin), luật mới Sửa email (docs/spec/04 mục R-HT-12, ghi ở PR tài liệu).
-- Chỉ mục: unique trên username (tìm theo tên đăng nhập khi đăng nhập, kiểm trùng).
select set_config('hmt.migration', 'on', false);

-- 1. Cột username
alter table app.user_account add column username text;
alter table app.user_account add constraint user_account_username_format check (username is null or username ~ '^[a-z][a-z0-9._-]{1,39}$');
create unique index user_account_username_uidx on app.user_account (lower(username)) where username is not null;
comment on column app.user_account.username is 'Tên đăng nhập (R-V2-08): viết thường không dấu; duy nhất không phân biệt hoa thường; không đổi sau khi đã có. Đăng nhập bằng email vẫn chạy song song.';

-- Sao chép từ legacy_ref cho tài khoản nhân sự đã nạp (tên đăng nhập cũ lưu ở legacy_ref khi nạp, T4b).
update app.user_account set username = lower(legacy_ref)
 where student_code is null and legacy_ref is not null and lower(legacy_ref) ~ '^[a-z][a-z0-9._-]{1,39}$';

-- 2. Luật không đổi: tên đăng nhập đã có thì không đổi; email đăng nhập (login_name) chỉ đổi qua hàm Sửa email (cờ cục bộ trong giao dịch).
create or replace function app.tg_user_account_fixed()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.login_name is distinct from old.login_name and coalesce(current_setting('hmt.email_change', true), '') <> 'on' then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không đổi tên đăng nhập của tài khoản.');
  end if;
  if new.username is distinct from old.username and old.username is not null then
    perform app.raise_error('HMT_TEN_DANG_NHAP_KHONG_DOI', 'Không đổi tên đăng nhập đã đặt.');
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

-- 3. Kiểm dạng, trùng của tên đăng nhập và email (dùng chung các hàm dưới).
create or replace function app.assert_username_ok(p_username text)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_username is null or lower(btrim(p_username)) !~ '^[a-z][a-z0-9._-]{1,39}$' then
    perform app.raise_error('HMT_TEN_DANG_NHAP_SAI', 'Tên đăng nhập gồm chữ thường không dấu, số, dấu chấm, gạch; bắt đầu bằng chữ; từ 2 đến 40 ký tự.');
  end if;
  if exists (select from app.user_account where lower(username) = lower(btrim(p_username))) then
    perform app.raise_error('HMT_TEN_DANG_NHAP_TRUNG', 'Tên đăng nhập này đã có người dùng.');
  end if;
end;
$$;

create or replace function app.assert_email_ok(p_email text, p_except uuid default null)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_email is null or lower(btrim(p_email)) !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    perform app.raise_error('HMT_EMAIL_SAI', 'Email không đúng dạng.');
  end if;
  if exists (select from app.user_account where login_name = lower(btrim(p_email)) and id is distinct from p_except) then
    perform app.raise_error('HMT_EMAIL_TRUNG', 'Email này đã dùng cho tài khoản khác.');
  end if;
end;
$$;

-- app.check_account_fields(tên đăng nhập, email): kiểm ngay ở ô khi tạo người dùng; không ghi gì. Ai gọi: Admin. Kết quả: {username: null|mã lỗi, email: null|mã lỗi}.
create or replace function app.check_account_fields(p_username text default null, p_email text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user text;
  v_mail text;
begin
  perform app.assert_account_admin();
  if p_username is not null and btrim(p_username) <> '' then
    begin
      perform app.assert_username_ok(p_username);
    exception when others then
      get stacked diagnostics v_user = pg_exception_hint;
    end;
  end if;
  if p_email is not null and btrim(p_email) <> '' then
    begin
      perform app.assert_email_ok(p_email);
    exception when others then
      get stacked diagnostics v_mail = pg_exception_hint;
    end;
  end if;
  return jsonb_build_object('username', v_user, 'email', v_mail);
end;
$$;

-- 4. Tạo tài khoản: thêm tên đăng nhập (bỏ chữ ký cũ rồi tạo chữ ký mới có p_username ở cuối, mặc định trống để lời gọi cũ còn chạy).
drop function app.admin_create_account(uuid, text, text, text, text[], text, text, text);
create or replace function app.admin_create_account(
  p_user_id uuid, p_display_name text, p_login_name text, p_branch_code text, p_roles text[],
  p_staff_code text default null, p_staff_kind text default null, p_student_code text default null, p_username text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
  v_staff_code text := p_staff_code;
  v_role text;
  v_username text := nullif(lower(btrim(coalesce(p_username, ''))), '');
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
  -- Luật R-V2-08: tên đăng nhập (nếu có) đúng dạng, không trùng; email không trùng.
  if v_username is not null then
    perform app.assert_username_ok(v_username);
  end if;
  if p_student_code is null then
    perform app.assert_email_ok(p_login_name);
  end if;
  -- Cấp mã nhân viên, giáo viên, trợ giảng mới nếu chưa truyền mã cũ.
  if v_staff_code is null and p_staff_kind is not null then
    v_staff_code := app.issue_person_code(p_staff_kind);
  end if;

  insert into app.user_account (id, display_name, login_name, branch_id, staff_code, student_code, must_change_password, username)
  values (p_user_id, btrim(p_display_name), lower(btrim(p_login_name)), v_branch_id, v_staff_code, p_student_code, true, v_username);
  perform app.remember_temp_password(p_user_id);

  insert into app.user_role (user_id, role_code) select p_user_id, unnest(p_roles);
  return p_user_id;
end;
$$;
revoke execute on function app.admin_create_account(uuid, text, text, text, text[], text, text, text, text) from public, anon;
grant execute on function app.admin_create_account(uuid, text, text, text, text[], text, text, text, text) to authenticated;
grant execute on function app.check_account_fields(text, text) to authenticated;
revoke execute on function app.check_account_fields(text, text) from public, anon;
revoke execute on function app.assert_username_ok(text), app.assert_email_ok(text, uuid) from public, anon, authenticated;

-- Nạp Người dùng: tên đăng nhập vào cột username (và legacy_ref như trước để nạp lại bỏ qua).
create or replace function app.import_user_create(p_user_id uuid, p_resolved jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kind text;
begin
  perform app.assert_account_admin();
  -- Luật: mã nhân viên cấp mới theo chuẩn mã, theo loại vai trò.
  v_kind := case p_resolved ->> 'role' when 'TEACHER' then 'GV' when 'TA' then 'TG' else 'NV' end;
  perform app.admin_create_account(p_user_id, p_resolved ->> 'display_name', p_resolved ->> 'email', p_resolved ->> 'branch_code',
                                   array[p_resolved ->> 'role'], null, v_kind, null, p_resolved ->> 'username');
  -- Luật R-V2-30: tên đăng nhập cũ lưu ở legacy_ref (tra cứu, nạp các loại sau, bỏ qua khi nạp lại).
  update app.user_account set legacy_ref = p_resolved ->> 'username' where id = p_user_id;
end;
$$;

-- 5. Đặt tên đăng nhập MỘT LẦN cho tài khoản chưa có (ví dụ Admin tạo bằng workflow Bootstrap admin). Ai gọi: Admin. Đã có thì chặn.
create or replace function app.admin_set_username(p_user_id uuid, p_username text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  a app.user_account;
begin
  perform app.assert_account_admin();
  select * into a from app.user_account where id = p_user_id and student_code is null;
  if a.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy tài khoản nhân sự.');
  end if;
  if a.username is not null then
    perform app.raise_error('HMT_TEN_DANG_NHAP_KHONG_DOI', 'Tài khoản này đã có tên đăng nhập, không đổi.');
  end if;
  perform app.assert_username_ok(p_username);
  update app.user_account set username = lower(btrim(p_username)) where id = p_user_id;
end;
$$;

-- 6. Sửa email (Q-M4): kiểm rồi áp dụng. Edge Function admin-users gọi: (1) admin_change_email_check, (2) đổi email ở Supabase Auth, (3) admin_change_email_apply.
-- Luật: chỉ Admin; đổi email của NGƯỜI KHÁC (không tự đổi); tài khoản nhân sự (học sinh dùng email nội bộ, không đổi); email mới đúng dạng, không trùng;
-- đổi xong thu hồi mọi phiên của người đó; nhật ký ghi email cũ, email mới, người đổi, thời điểm (audit_log của user_account); tên đăng nhập không đổi.
create or replace function app.admin_change_email_check(p_user_id uuid, p_new_email text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  a app.user_account;
begin
  perform app.assert_account_admin();
  if p_user_id = auth.uid() then
    perform app.raise_error('HMT_KHONG_TU_DOI_EMAIL', 'Admin không tự đổi email của mình ở đây; nhờ Admin khác.');
  end if;
  select * into a from app.user_account where id = p_user_id and student_code is null;
  if a.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy tài khoản nhân sự.');
  end if;
  perform app.assert_email_ok(p_new_email, p_user_id);
  if lower(btrim(p_new_email)) = a.login_name then
    perform app.raise_error('HMT_KHONG_THAY_DOI', 'Email mới trùng email hiện tại.');
  end if;
  return a.login_name;
end;
$$;

create or replace function app.admin_change_email_apply(p_user_id uuid, p_new_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old text;
begin
  v_old := app.admin_change_email_check(p_user_id, p_new_email);
  perform set_config('hmt.email_change', 'on', true);
  update app.user_account set login_name = lower(btrim(p_new_email)) where id = p_user_id;
  perform set_config('hmt.email_change', '', true);
  -- Luật: thu hồi mọi phiên đăng nhập cũ của người đó.
  perform app.revoke_user_sessions(p_user_id);
  return v_old;
end;
$$;
revoke execute on function app.admin_set_username(uuid, text), app.admin_change_email_check(uuid, text), app.admin_change_email_apply(uuid, text) from public, anon;
grant execute on function app.admin_set_username(uuid, text), app.admin_change_email_check(uuid, text), app.admin_change_email_apply(uuid, text) to authenticated;

-- 7. Bản ghi người dùng có thêm tên đăng nhập (màn QT-02 hiện, QT-03 sửa email lấy tên).
create or replace function app.get_user(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  u app.user_account;
  v_rows integer := app.get_setting_int('user_login_history_rows');
begin
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được xem người dùng.');
  end if;
  select * into u from app.user_account where id = p_id and student_code is null;
  if u.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy người dùng.');
  end if;
  return jsonb_build_object(
    'id', u.id, 'display_name', u.display_name, 'login_name', u.login_name, 'username', u.username, 'staff_code', u.staff_code,
    'branch', (select jsonb_build_object('id', b.id, 'code', b.code, 'name', b.name) from app.branch b where b.id = u.branch_id),
    'roles', coalesce((select jsonb_agg(jsonb_build_object('code', r.code, 'name', r.name, 'require_mfa', r.require_mfa)
                                         order by r.sort_order, r.code)
                         from app.user_role ur join app.role r on r.code = ur.role_code
                        where ur.user_id = u.id and ur.is_active), '[]'::jsonb),
    'manager', case when u.manager_id is null then null
                    else jsonb_build_object('id', u.manager_id, 'name', app.staff_display_name(u.manager_id)) end,
    'is_locked', u.is_locked, 'locked_at', u.locked_at, 'lock_reason', u.lock_reason,
    'must_change_password', u.must_change_password, 'failed_login_count', u.failed_login_count,
    'temp_locked_until', u.temp_locked_until, 'last_login_at', u.last_login_at, 'created_at', u.created_at,
    'mfa_devices', (select count(*) from auth.mfa_factors f where f.user_id = u.id and f.status = 'verified'),
    'mfa_required', exists (select from app.user_role ur join app.role r on r.code = ur.role_code
                             where ur.user_id = u.id and ur.is_active and r.require_mfa),
    'mfa_reset_at', u.mfa_reset_at, 'mfa_reset_by', app.staff_display_name(u.mfa_reset_by),
    'recent_logins', coalesce((select jsonb_agg(jsonb_build_object('at', e.at, 'result', e.result, 'ip', e.ip::text,
                                                                    'user_agent', e.user_agent) order by e.at desc)
                                 from (select * from app.login_event where login_name = u.login_name
                                        order by at desc limit v_rows) e), '[]'::jsonb));
end;
$$;

-- Giá trị mặc định cho form Tạo người dùng: tên miền email quy ước (tham số import_user_email_domain, không viết cứng ở giao diện). Ai gọi: Admin.
create or replace function app.get_account_form_defaults()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform app.assert_account_admin();
  return jsonb_build_object('email_domain', lower(app.get_setting('import_user_email_domain')));
end;
$$;
revoke execute on function app.get_account_form_defaults() from public, anon;
grant execute on function app.get_account_form_defaults() to authenticated;

select set_config('hmt.migration', '', false);
