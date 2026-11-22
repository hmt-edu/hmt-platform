-- QT-17 Tài khoản phụ huynh (bản đồ màn hình QT-17, CHUNG-23): phụ huynh đăng nhập bằng MÃ PH + mật khẩu trung tâm cấp, như học sinh (QT-13, migration 569).
-- Luật: R-CRM-32 (quyền như QT-13: chỉ Admin đã xác thực hai bước; CS để giai đoạn sau, cùng QT-13); mật khẩu tạm trả MỘT lần, không lưu, không
-- gửi email; không mang mật khẩu hệ thống cũ sang. Email nội bộ của phụ huynh là địa chỉ giả, hệ thống không bao giờ gửi thư tới đó.
select set_config('hmt.migration', 'on', false);

-- 1. Cột mã phụ huynh ở tài khoản (một phụ huynh một tài khoản). Unique đã kèm chỉ mục, dùng để nối tài khoản với app.parent.code và tìm theo mã PH.
alter table app.user_account
  add column parent_code text unique check (parent_code ~ '^PH[0-9]+$');
comment on column app.user_account.parent_code is 'Mã phụ huynh (PH...) của tài khoản phụ huynh; null với nhân viên, học sinh. Không đổi sau khi cấp.';

-- Luật: không đổi mã phụ huynh đã cấp (giống mã HS). Trigger riêng, không viết lại trigger tài khoản sẵn có (đã đổi qua nhiều migration).
create or replace function app.tg_user_account_parent_code_fixed()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.parent_code is distinct from old.parent_code and old.parent_code is not null then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không đổi mã phụ huynh đã cấp.');
  end if;
  return new;
end;
$$;
create trigger user_account_parent_code_fixed before update on app.user_account
  for each row execute function app.tg_user_account_parent_code_fixed();

-- 2. Nhiều hàm cũ nhận ra «nhân viên» bằng `student_code is null` (danh sách người dùng, chọn người phụ trách, quản lý trực tiếp, kiểm quyền nhân viên...).
-- Tài khoản phụ huynh cũng không có mã HS nên phải bị loại cùng chỗ đó: thêm `and parent_code is null` vào MỌI hàm app.* còn dùng điều kiện ấy.
-- SQL động có chủ đích (quy ước 6): hơn chục hàm, thân hàm đổi qua nhiều migration, viết lại tay dễ lệch; chạy một lần, có kiểm ở pgTAP (không còn hàm sót).
do $$
declare
  r record;
  v_def text;
  v_new text;
begin
  for r in select p.oid, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'app' and p.prosrc ~ '\mstudent_code is null' and p.prokind = 'f'
  loop
    v_def := pg_get_functiondef(r.oid);
    v_new := regexp_replace(v_def, '\m((?:\w+\.)?)student_code is null', '\1student_code is null and \1parent_code is null', 'g');
    if v_new = v_def then
      raise exception 'Không thay được điều kiện ở hàm %', r.proname;
    end if;
    execute v_new;
  end loop;
end $$;

-- 3. Mật khẩu tạm của phụ huynh theo cùng tham số với học sinh (người ngoài, không phải nhân viên): mặc định không bắt đổi lần đầu (anh chốt 19/11 cho học sinh).
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
   where key = case when p_account.student_code is not null or p_account.parent_code is not null
                    then 'first_password_change_required_student'
                    else 'first_password_change_required_staff' end;
  return coalesce(v_on, 'true') = 'true';
end;
$$;
revoke execute on function app.first_password_change_required(app.user_account) from public, anon, authenticated;

-- 4. Vai trò Phụ huynh có cổng riêng «ph» (trước đây không có cổng nào). Cổng đi vào token qua app.custom_access_token_hook (đọc app.role.portals).
update app.role set portals = '{ph}' where code = 'PARENT';

-- 5. app.admin_create_account thêm tham số mã phụ huynh (cuối, mặc định null: các nơi gọi cũ không đổi).
-- Luật: vai trò PARENT phải có mã PH (và ngược lại); phụ huynh đăng nhập bằng mã PH nên không kiểm email.
drop function app.admin_create_account(uuid, text, text, text, text[], text, text, text, text);
create or replace function app.admin_create_account(
  p_user_id uuid, p_display_name text, p_login_name text, p_branch_code text, p_roles text[],
  p_staff_code text default null, p_staff_kind text default null, p_student_code text default null, p_username text default null,
  p_parent_code text default null)
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
  -- Luật (QT-17): phụ huynh đăng nhập bằng mã PH; chỉ vai trò Phụ huynh mới có mã PH, và không gộp với vai trò khác.
  if 'PARENT' = any (p_roles) and (p_parent_code is null or cardinality(p_roles) <> 1) then
    perform app.raise_error('HMT_THIEU_MA_PH', 'Tài khoản phụ huynh phải có mã phụ huynh và chỉ có vai trò Phụ huynh.');
  end if;
  if p_parent_code is not null and not ('PARENT' = any (p_roles)) then
    perform app.raise_error('HMT_THIEU_MA_PH', 'Mã phụ huynh chỉ dùng cho tài khoản có vai trò Phụ huynh.');
  end if;
  -- Luật R-V2-08: tên đăng nhập (nếu có) đúng dạng, không trùng; email không trùng.
  if v_username is not null then
    perform app.assert_username_ok(v_username);
  end if;
  if p_student_code is null and p_parent_code is null then
    perform app.assert_email_ok(p_login_name);
  end if;
  -- Cấp mã nhân viên, giáo viên, trợ giảng mới nếu chưa truyền mã cũ.
  if v_staff_code is null and p_staff_kind is not null then
    v_staff_code := app.issue_person_code(p_staff_kind);
  end if;

  insert into app.user_account (id, display_name, login_name, branch_id, staff_code, student_code, parent_code, must_change_password, username)
  values (p_user_id, btrim(p_display_name), lower(btrim(p_login_name)), v_branch_id, v_staff_code, p_student_code, p_parent_code, true, v_username);
  perform app.remember_temp_password(p_user_id);

  insert into app.user_role (user_id, role_code) select p_user_id, unnest(p_roles);
  return p_user_id;
end;
$$;
revoke execute on function app.admin_create_account(uuid, text, text, text, text[], text, text, text, text, text) from public, anon;
grant execute on function app.admin_create_account(uuid, text, text, text, text[], text, text, text, text, text) to authenticated;

-- 6. Danh sách phụ huynh + tình trạng tài khoản (QT-17). Ai gọi: Admin (đã xác thực hai bước). Lọc: q (tên, mã PH, số điện thoại), branch_id,
-- state (CHUA_CAP, HOAT_DONG, BI_KHOA). Phân trang ở máy chủ, sắp theo mã PH. «Số con» đếm học sinh có phụ huynh này.
create or replace function app.list_parent_accounts(
  p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_state text := nullif(p_filters ->> 'state', '');
  v_result jsonb;
begin
  -- Luật: chỉ Admin (Quản trị · Xem, cần đã xác thực hai bước), giống QT-13.
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được xem tài khoản phụ huynh.');
  end if;
  with f as not materialized (
    select p.id, p.code, p.full_name, p.branch_id, u.id as user_id, u.is_locked, u.must_change_password, u.last_login_at,
           case when u.id is null then 'CHUA_CAP' when u.is_locked then 'BI_KHOA' else 'HOAT_DONG' end as state
      from app.parent p
      left join app.user_account u on u.parent_code = p.code
     where (v_q is null or p.search_text like '%' || v_q || '%')
       and (v_branch is null or p.branch_id = v_branch)
       and (v_state is null
            or v_state = case when u.id is null then 'CHUA_CAP' when u.is_locked then 'BI_KHOA' else 'HOAT_DONG' end)
  ),
  page as (select * from f order by f.code, f.id limit v_limit offset v_offset)
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'parent_id', g.id, 'parent_code', g.code, 'full_name', g.full_name, 'branch_code', b.code,
             'children_count', (select count(*) from app.student s where s.parent_id = g.id),
             'user_id', g.user_id, 'state', g.state,
             'must_change_password', coalesce(g.must_change_password, false), 'last_login_at', g.last_login_at)
             order by g.code, g.id), '[]'::jsonb))
    into v_result
    from page g
    join app.branch b on b.id = g.branch_id;
  return v_result;
end;
$$;
comment on function app.list_parent_accounts(jsonb, integer, integer) is
  'QT-17: phụ huynh kèm tình trạng tài khoản (CHUA_CAP, HOAT_DONG, BI_KHOA) và số con. Chỉ Admin. Phân trang máy chủ.';

-- 7. Kiểm trước khi cấp tài khoản cho một phụ huynh (Edge Function admin-users gọi trước khi tạo ở Supabase Auth).
-- Luật: phụ huynh phải có thật và chưa có tài khoản. Trả tên và mã cơ sở.
create or replace function app.admin_check_parent_account(p_parent_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_parent record;
begin
  perform app.assert_account_admin();
  select p.full_name, b.code as branch_code into v_parent
    from app.parent p join app.branch b on b.id = p.branch_id
   where p.code = p_parent_code;
  if not found then
    perform app.raise_error('HMT_KHONG_TIM_THAY', format('Không có phụ huynh mã %s.', p_parent_code));
  end if;
  if exists (select from app.user_account where parent_code = p_parent_code) then
    perform app.raise_error('HMT_TAI_KHOAN_DA_CO', format('Phụ huynh %s đã có tài khoản. Dùng Đặt lại mật khẩu nếu quên.', p_parent_code));
  end if;
  return jsonb_build_object('display_name', v_parent.full_name, 'branch_code', v_parent.branch_code);
end;
$$;
comment on function app.admin_check_parent_account(text) is 'QT-17: phụ huynh có thật và chưa có tài khoản; trả tên, cơ sở. Chỉ Admin.';

revoke execute on function app.list_parent_accounts(jsonb, integer, integer), app.admin_check_parent_account(text) from public, anon;
grant execute on function app.list_parent_accounts(jsonb, integer, integer), app.admin_check_parent_account(text) to authenticated;
