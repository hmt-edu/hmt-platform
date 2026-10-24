-- Quản trị người dùng (QT-01, QT-02, QT-03; anh duyệt 24/10, QĐ-Đ44 đến Đ50): dữ liệu cho danh sách, bản ghi, Xuất, và hai thao tác
-- Admin của QT-02 chưa có hàm: Thu hồi phiên, Đặt lại hai bước (B16 của docs/nghiep-vu/doi-chieu-luat-1210.md, từ Edge Function
-- sang hàm DB theo Đ49).
--   1. app.list_users: danh sách tài khoản nhân viên, giáo viên, trợ giảng (không gồm học sinh), lọc, sắp xếp, phân trang.
--   2. app.get_user: một bản ghi (thông tin, vai trò, quản lý trực tiếp, thiết bị hai bước, lịch sử đăng nhập gần đây).
--   3. app.export_users: Xuất (chỉ Admin, Đ45), ghi nhật ký xuất.
--   4. app.admin_revoke_sessions: Thu hồi phiên của một người.
--   5. app.admin_reset_mfa: Đặt lại hai bước (xoá thiết bị hai bước ở Supabase Auth và thu hồi phiên; người thuộc vai trò bắt buộc hai
--      bước, như Admin, Kế toán, phải thiết lập lại ở lần đăng nhập sau).
--   6. Tham số user_login_history_rows (số dòng lịch sử đăng nhập hiện ở bản ghi).
--   7. Cột mfa_reset_at, mfa_reset_by của app.user_account: việc đặt lại hai bước ghi vào nhật ký thao tác (bảng tài khoản đã được ghi nhật ký).
-- Chỉ mục: không thêm. Danh sách tài khoản nhỏ (hàng trăm dòng, một công ty); lịch sử đăng nhập tra theo login_event_login_idx
-- (login_name, at) đã có. Tìm theo tên, email, mã bằng fold_text trên tập này (không cần chỉ mục trigram).

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Cột ghi việc đặt lại hai bước (nhật ký thao tác tự ghi thay đổi cột này: ai, lúc nào).
-- ---------------------------------------------------------------------------
alter table app.user_account add column mfa_reset_at timestamptz, add column mfa_reset_by uuid;
comment on column app.user_account.mfa_reset_at is 'Lần cuối Admin đặt lại hai bước (xoá thiết bị hai bước) cho tài khoản này.';

insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('user_login_history_rows', 'Số dòng lịch sử đăng nhập hiện ở bản ghi người dùng', 'INT', 'dòng', 5, 50, '10', false, null, null,
   'QT-02: số lần đăng nhập gần nhất hiện ở bản ghi người dùng.');

-- ---------------------------------------------------------------------------
-- Danh sách người dùng (QT-01).
-- Ai gọi: Admin đã xác thực hai bước (quyền Quản trị · Xem).
-- Đầu vào: p_filters {q, role[] (mã vai trò, HOẶC), branch_id, status ('ACTIVE' | 'LOCKED'), kind ('NV' | 'GV' | 'TG')},
--   p_sort ('name_asc' mặc định, 'last_login_desc', 'created_desc'), p_limit, p_offset.
-- Kết quả: {total, rows: [{id, display_name, login_name, staff_code, branch_code, roles: [{code, name}], is_locked, last_login_at,
--   must_change_password, manager_name}]}.
-- Luật: chỉ tài khoản nhân viên, giáo viên, trợ giảng (không có học sinh); phân trang ở máy chủ, tối đa list_page_size_max.
-- ---------------------------------------------------------------------------
create or replace function app.list_users(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'name_asc', p_limit integer default null, p_offset integer default 0)
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
  v_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'role'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_status text := nullif(p_filters ->> 'status', '');
  v_kind text := nullif(p_filters ->> 'kind', '');
  v_result jsonb;
begin
  -- Luật: chỉ Admin (quyền Quản trị · Xem, cần đã xác thực hai bước).
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được xem danh sách người dùng.');
  end if;
  with f as not materialized (
    select u.*
      from app.user_account u
     where u.student_code is null
       and (v_q is null
            or app.fold_text(u.display_name || ' ' || u.login_name || ' ' || coalesce(u.staff_code, '')) like '%' || v_q || '%')
       and (cardinality(v_roles) = 0
            or exists (select from app.user_role ur where ur.user_id = u.id and ur.is_active and ur.role_code = any (v_roles)))
       and (v_branch is null or u.branch_id = v_branch)
       and (v_status is null or (v_status = 'LOCKED') = u.is_locked)
       and (v_kind is null or u.staff_code like v_kind || '%')
  ),
  page as (
    select * from f
     order by case when p_sort = 'last_login_desc' then f.last_login_at end desc nulls last,
              case when p_sort = 'created_desc' then f.created_at end desc,
              f.display_name, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'display_name', p.display_name, 'login_name', p.login_name, 'staff_code', p.staff_code,
             'branch_code', b.code,
             'roles', coalesce((select jsonb_agg(jsonb_build_object('code', r.code, 'name', r.name) order by r.sort_order, r.code)
                                  from app.user_role ur join app.role r on r.code = ur.role_code
                                 where ur.user_id = p.id and ur.is_active), '[]'::jsonb),
             'is_locked', p.is_locked, 'last_login_at', p.last_login_at, 'must_change_password', p.must_change_password,
             'manager_name', app.staff_display_name(p.manager_id))
             order by case when p_sort = 'last_login_desc' then p.last_login_at end desc nulls last,
                      case when p_sort = 'created_desc' then p.created_at end desc,
                      p.display_name, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Bản ghi người dùng (QT-02). Ai gọi: Admin đã xác thực hai bước.
-- Kết quả: thông tin tài khoản, cơ sở, vai trò, quản lý trực tiếp, trạng thái khoá, số thiết bị hai bước (không lộ bí mật),
--   vai trò có bắt buộc hai bước không, và lịch sử đăng nhập gần đây (user_login_history_rows dòng).
-- Luật: không có tài khoản học sinh ở màn này (HMT_KHONG_TIM_THAY).
-- ---------------------------------------------------------------------------
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
    'id', u.id, 'display_name', u.display_name, 'login_name', u.login_name, 'staff_code', u.staff_code,
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

-- ---------------------------------------------------------------------------
-- Xuất danh sách người dùng (Đ45). Ai gọi: CHỈ Admin (quyền Quản trị · Xuất, đã xác thực hai bước).
-- Cột: mã NV/GV/TG, tên, email đăng nhập, vai trò, cơ sở, trạng thái. KHÔNG có mật khẩu, mật khẩu tạm, dữ liệu hai bước.
-- Đầu vào: cùng bộ lọc như list_users. Kết quả: {total, exported, truncated, rows}; tối đa export_max_rows dòng.
-- Luật: ghi nhật ký xuất (app.log_export: ai, module, bộ lọc, số dòng).
-- ---------------------------------------------------------------------------
create or replace function app.export_users(p_filters jsonb default '{}'::jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'role'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_status text := nullif(p_filters ->> 'status', '');
  v_kind text := nullif(p_filters ->> 'kind', '');
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Luật Đ45: chỉ Admin được xuất.
  if not app.has_permission('ADMIN', 'XUAT') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được xuất danh sách người dùng.');
  end if;
  select count(*) into v_total
    from app.user_account u
   where u.student_code is null
     and (v_q is null or app.fold_text(u.display_name || ' ' || u.login_name || ' ' || coalesce(u.staff_code, '')) like '%' || v_q || '%')
     and (cardinality(v_roles) = 0
          or exists (select from app.user_role ur where ur.user_id = u.id and ur.is_active and ur.role_code = any (v_roles)))
     and (v_branch is null or u.branch_id = v_branch)
     and (v_status is null or (v_status = 'LOCKED') = u.is_locked)
     and (v_kind is null or u.staff_code like v_kind || '%');
  with f as (
    select u.*
      from app.user_account u
     where u.student_code is null
       and (v_q is null or app.fold_text(u.display_name || ' ' || u.login_name || ' ' || coalesce(u.staff_code, '')) like '%' || v_q || '%')
       and (cardinality(v_roles) = 0
            or exists (select from app.user_role ur where ur.user_id = u.id and ur.is_active and ur.role_code = any (v_roles)))
       and (v_branch is null or u.branch_id = v_branch)
       and (v_status is null or (v_status = 'LOCKED') = u.is_locked)
       and (v_kind is null or u.staff_code like v_kind || '%')
     order by u.display_name, u.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'staff_code', f.staff_code, 'display_name', f.display_name, 'login_name', f.login_name,
           'roles', coalesce((select string_agg(r.name, ', ' order by r.sort_order, r.code)
                                from app.user_role ur join app.role r on r.code = ur.role_code
                               where ur.user_id = f.id and ur.is_active), ''),
           'branch', b.code, 'status', case when f.is_locked then 'Đã khoá' else 'Đang hoạt động' end)
           order by f.display_name, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id;
  perform app.log_export('ADMIN', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$$;

-- ---------------------------------------------------------------------------
-- Kiểm chung cho hai thao tác Admin lên tài khoản người khác. Hàm nội bộ.
-- Luật: Admin đã xác thực hai bước (assert_account_admin); KHÔNG tự thao tác lên chính mình (Đ50): thiết bị hai bước của mình
-- quản lý ở hồ sơ cá nhân, Admin mất cả hai thiết bị thì khôi phục bằng workflow bootstrap; tài khoản phải có thật và không phải học sinh.
-- ---------------------------------------------------------------------------
create or replace function app.assert_admin_target(p_user_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform app.assert_account_admin();
  if p_user_id is not distinct from auth.uid() then
    perform app.raise_error('HMT_THAO_TAC_CHINH_MINH',
      'Không dùng thao tác này cho chính mình. Thiết bị hai bước của mình quản lý ở hồ sơ cá nhân.');
  end if;
  if not exists (select from app.user_account where id = p_user_id and student_code is null) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy người dùng.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Thu hồi phiên (QT-02). Ai gọi: Admin đã xác thực hai bước. Đầu vào: id tài khoản (không phải của chính mình).
-- Làm gì: tăng số phiên bản (mọi token cũ chết ngay) và xoá phiên ở Supabase Auth: người đó phải đăng nhập lại.
-- Nhật ký thao tác tự ghi việc tăng số phiên bản (bảng tài khoản).
-- ---------------------------------------------------------------------------
create or replace function app.admin_revoke_sessions(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_admin_target(p_user_id);
  perform app.revoke_user_sessions(p_user_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Đặt lại hai bước (QT-02; Đ49). Ai gọi: Admin đã xác thực hai bước. Đầu vào: id tài khoản (không phải của chính mình).
-- Làm gì: xoá mọi thiết bị hai bước của người đó ở Supabase Auth và thu hồi phiên (phiên cũ mang mức xác thực hai bước phải chết).
--   Người thuộc vai trò bắt buộc hai bước (Admin, Kế toán) phải thiết lập lại thiết bị ở lần đăng nhập sau; chưa thiết lập xong thì
--   không vào được (mọi RLS đòi mức xác thực hai bước). Người khác không bị buộc (hai bước là tuỳ chọn với họ).
-- Kết quả: {removed}: số thiết bị đã xoá. Nhật ký: mfa_reset_at, mfa_reset_by của tài khoản (nhật ký thao tác tự ghi ai, lúc nào).
-- Ghi thẳng vào bảng Auth (auth.mfa_factors) như revoke_user_sessions ghi auth.sessions; hàm do chủ sở hữu bản migration chạy.
-- ---------------------------------------------------------------------------
create or replace function app.admin_reset_mfa(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_removed integer;
begin
  perform app.assert_admin_target(p_user_id);
  delete from auth.mfa_factors where user_id = p_user_id;
  get diagnostics v_removed = row_count;
  update app.user_account set mfa_reset_at = now(), mfa_reset_by = auth.uid() where id = p_user_id;
  perform app.revoke_user_sessions(p_user_id);
  return jsonb_build_object('removed', v_removed);
end;
$$;

revoke execute on function app.assert_admin_target(uuid) from public, anon, authenticated;
revoke execute on function
  app.list_users(jsonb, text, integer, integer), app.get_user(uuid), app.export_users(jsonb),
  app.admin_revoke_sessions(uuid), app.admin_reset_mfa(uuid)
  from public, anon;
grant execute on function
  app.list_users(jsonb, text, integer, integer), app.get_user(uuid), app.export_users(jsonb),
  app.admin_revoke_sessions(uuid), app.admin_reset_mfa(uuid)
  to authenticated;

select set_config('hmt.migration', '', false);
