-- Migration 475 (Code D, 19/11/2026): thẻ D50, rà UI/UX Quản trị. Danh sách Người dùng (QT-01) theo canvas dc47 khung QT03: cột «Tên đăng nhập» riêng.
-- app.list_users thêm khoá username vào mỗi dòng và cho tìm theo tên đăng nhập. Thân hàm lấy từ migration 042 (bản hiện hành duy nhất), chỉ thêm hai chỗ; không đổi quyền, phân trang, sắp xếp.
-- Không chỉ mục mới: tìm theo chuỗi trên trang đã lọc như cũ.

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
            or app.fold_text(u.display_name || ' ' || u.login_name || ' ' || coalesce(u.username, '') || ' ' || coalesce(u.staff_code, '')) like '%' || v_q || '%')
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
             'id', p.id, 'display_name', p.display_name, 'login_name', p.login_name, 'username', p.username, 'staff_code', p.staff_code,
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
