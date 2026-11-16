-- QT-04 Vai trò (danh sách + mô tả), chỉ đọc (Code C, 16/11/2026). Luật S03-06: các vai trò hệ thống và phạm vi mặc định; mở ma trận quyền (QT-05).
-- app.list_roles_summary(): mỗi vai trò kèm số người đang dùng (đang được gán, tài khoản không bị khoá) và số ô quyền đang bật. Ai gọi: người có Quản trị · Xem (Admin). Không ghi gì.
-- Chỉ mục: không thêm (bảng vai trò 12 dòng; đếm theo user_role.role_code và permission.role_code đã có chỉ mục khoá ngoại).
create or replace function app.list_roles_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  -- Luật: chỉ người có quyền Quản trị · Xem (Admin) thấy danh sách vai trò kèm số người, số ô quyền.
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách vai trò.');
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'code', r.code, 'name', r.name, 'default_scope', r.default_scope,
             'portals', to_jsonb(r.portals), 'view_only_portals', to_jsonb(r.view_only_portals),
             'require_mfa', r.require_mfa, 'idle_group', r.idle_group, 'sort_order', r.sort_order,
             'users', (select count(*) from app.user_role ur
                         join app.user_account ua on ua.id = ur.user_id
                        where ur.role_code = r.code and ur.is_active and not ua.is_locked),
             'cells', (select count(*) from app.permission p where p.role_code = r.code and p.is_active))
           order by r.sort_order)
      from app.role r), '[]'::jsonb);
end;
$$;
revoke execute on function app.list_roles_summary() from public, anon;
grant execute on function app.list_roles_summary() to authenticated;
