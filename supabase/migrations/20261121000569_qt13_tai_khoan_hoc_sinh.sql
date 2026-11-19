-- QT-13 Tài khoản học sinh (R-CRM-32, bản đồ màn hình QT-13): danh sách học sinh kèm tình trạng tài khoản đăng nhập app học tập, để Admin
-- cấp, đặt lại mật khẩu, khoá. Hai hàm đọc (Admin, đã xác thực hai bước); việc cấp, đặt lại, khoá vẫn qua Edge Function admin-users
-- (cần khoá secret của Supabase Auth). Mật khẩu tạm trả MỘT lần, không lưu (luật cũ của QT-02, QT-03); không mang mật khẩu hệ thống cũ sang.

-- Danh sách học sinh + tình trạng tài khoản. Ai gọi: Admin (quyền Quản trị · Xem). Lọc: q (tên, mã HS, tên phụ huynh), branch_id,
-- state (CHUA_CAP chưa có tài khoản; HOAT_DONG; BI_KHOA). Phân trang ở máy chủ, sắp theo mã HS.
create or replace function app.list_student_accounts(
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
  -- Luật: chỉ Admin (Quản trị · Xem, cần đã xác thực hai bước), giống danh sách người dùng QT-01.
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được xem tài khoản học sinh.');
  end if;
  with f as not materialized (
    select s.id, s.code, s.full_name, s.branch_id, s.parent_id, u.id as user_id, u.is_locked, u.must_change_password, u.last_login_at,
           case when u.id is null then 'CHUA_CAP' when u.is_locked then 'BI_KHOA' else 'HOAT_DONG' end as state
      from app.student s
      left join app.user_account u on u.student_code = s.code
     where (v_q is null
            or s.search_text like '%' || v_q || '%'
            or exists (select from app.parent p where p.id = s.parent_id and app.fold_text(p.full_name) like '%' || v_q || '%'))
       and (v_branch is null or s.branch_id = v_branch)
       and (v_state is null
            or v_state = case when u.id is null then 'CHUA_CAP' when u.is_locked then 'BI_KHOA' else 'HOAT_DONG' end)
  ),
  page as (select * from f order by f.code, f.id limit v_limit offset v_offset)
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'student_id', p.id, 'student_code', p.code, 'full_name', p.full_name, 'branch_code', b.code,
             'parent_name', pr.full_name, 'user_id', p.user_id, 'state', p.state,
             'must_change_password', coalesce(p.must_change_password, false), 'last_login_at', p.last_login_at)
             order by p.code, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent pr on pr.id = p.parent_id;
  return v_result;
end;
$$;
comment on function app.list_student_accounts(jsonb, integer, integer) is
  'QT-13: học sinh kèm tình trạng tài khoản (CHUA_CAP, HOAT_DONG, BI_KHOA). Chỉ Admin. Phân trang máy chủ.';

-- Kiểm trước khi cấp tài khoản cho một học sinh (Edge Function admin-users gọi trước khi tạo ở Supabase Auth).
-- Luật: học sinh phải có thật và chưa có tài khoản. Trả tên và mã cơ sở để Edge Function khai báo tài khoản.
create or replace function app.admin_check_student_account(p_student_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_student record;
begin
  perform app.assert_account_admin();
  select s.full_name, b.code as branch_code into v_student
    from app.student s join app.branch b on b.id = s.branch_id
   where s.code = p_student_code;
  if not found then
    perform app.raise_error('HMT_KHONG_TIM_THAY', format('Không có học sinh mã %s.', p_student_code));
  end if;
  if exists (select from app.user_account where student_code = p_student_code) then
    perform app.raise_error('HMT_TAI_KHOAN_DA_CO', format('Học sinh %s đã có tài khoản. Dùng Đặt lại mật khẩu nếu em quên.', p_student_code));
  end if;
  return jsonb_build_object('display_name', v_student.full_name, 'branch_code', v_student.branch_code);
end;
$$;
comment on function app.admin_check_student_account(text) is 'QT-13: học sinh có thật và chưa có tài khoản; trả tên, cơ sở. Chỉ Admin.';

-- Quyền gọi: người đã đăng nhập (hàm tự kiểm quyền Admin bên trong); không cho ẩn danh, không cho công khai.
revoke execute on function app.list_student_accounts(jsonb, integer, integer), app.admin_check_student_account(text) from public, anon;
grant execute on function app.list_student_accounts(jsonb, integer, integer), app.admin_check_student_account(text) to authenticated;
