-- Migration 466 (Code D, 18/11/2026): sửa R2 của Soát (đề xuất docs/de-xuat/r2-hoc-sinh-doc-cau-hinh.md, Chat duyệt 00:47). CAO (RLS).
-- Lỗ: tài khoản Học sinh đọc được cấu hình nội bộ vì chính sách đọc chỉ kiểm «đã đăng nhập» (current_user_ready). Sửa: chỉ NHÂN VIÊN (vai trò có cổng crm hoặc gv)
-- đọc đủ; Học sinh chỉ đọc đúng phần cổng /hoc cần:
--   permission, role: chỉ dòng của CHÍNH vai trò mình (giao diện nạp quyền và nhóm tự đăng xuất theo vai trò của mình).
--   setting_def: chỉ khoá student_idle_logout_minutes (giờ tự đăng xuất của học sinh). setting_branch: chỉ nhân viên.
--   catalog, catalog_item: chỉ các danh mục hiển thị cho học sinh (môn, khối, cấp độ, loại buổi, trạng thái điểm danh).
--   code_format, room, note_target: chỉ nhân viên.
--   feature_flag: GIỮ NGUYÊN (giao diện nạp công tắc cho mọi cổng; đổi cần sửa giao diện); đã ghi vào mô tả PR.
-- branch, academic_year, holiday: không đổi (cổng cần). Thêm hàm app.is_staff() (một nguồn duy nhất) và app.student_portal_config() cho cổng /hoc.

-- app.is_staff(): người gọi có ít nhất một vai trò (trong phiên) mà cổng gồm crm hoặc gv. Ai gọi: mọi người dùng đăng nhập; chỉ trả đúng/sai.
create or replace function app.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from app.role r where r.code = any (app.current_roles()) and r.portals && array['crm', 'gv']);
$$;
revoke execute on function app.is_staff() from public, anon;
grant execute on function app.is_staff() to authenticated;

-- Danh mục hiển thị cho học sinh: môn, khối, cấp độ lớp, loại buổi, trạng thái điểm danh (không có số liệu nội bộ).
create or replace function app.student_visible_catalog(p_catalog_code text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_catalog_code in ('SUBJECT', 'GRADE', 'CLASS_TYPE', 'SESSION_TYPE', 'ATTENDANCE_STATUS');
$$;
revoke execute on function app.student_visible_catalog(text) from public, anon;
grant execute on function app.student_visible_catalog(text) to authenticated;

alter policy permission_read on app.permission
  using (app.current_user_ready() and ((select app.is_staff()) or role_code = any (app.current_roles())));
alter policy role_read on app.role
  using (app.current_user_ready() and ((select app.is_staff()) or code = any (app.current_roles())));
alter policy setting_def_read on app.setting_def
  using (app.current_user_ready() and ((select app.is_staff()) or key = 'student_idle_logout_minutes'));
alter policy setting_branch_read on app.setting_branch
  using (app.current_user_ready() and (select app.is_staff()));
alter policy catalog_read on app.catalog
  using (app.current_user_ready() and ((select app.is_staff()) or app.student_visible_catalog(code)));
alter policy catalog_item_read on app.catalog_item
  using (app.current_user_ready() and ((select app.is_staff()) or app.student_visible_catalog(catalog_code)));
alter policy code_format_read on app.code_format
  using (app.current_user_ready() and (select app.is_staff()));
alter policy room_read on app.room
  using (app.current_user_ready() and (select app.is_staff()));
alter policy note_target_read on app.note_target
  using (app.current_user_ready() and (select app.is_staff()));

-- app.student_portal_config(): cấu hình tối thiểu cho cổng /hoc, một lần gọi: số phút tự đăng xuất của học sinh và các danh mục hiển thị (mã, tên, thứ tự).
-- Ai gọi: người dùng đăng nhập đủ bước xác thực. Kết quả {idle_logout_minutes, catalogs{mã danh mục: [{code, name}]}}.
create or replace function app.student_portal_config()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app.current_user_ready() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn cần đăng nhập đủ bước xác thực.');
  end if;
  return jsonb_build_object(
    'idle_logout_minutes', (select d.value::int from app.setting_def d where d.key = 'student_idle_logout_minutes'),
    'catalogs', coalesce((select jsonb_object_agg(c.catalog_code, c.items)
                            from (select i.catalog_code, jsonb_agg(jsonb_build_object('code', i.code, 'name', i.name) order by i.sort_order, i.code) as items
                                    from app.catalog_item i
                                   where app.student_visible_catalog(i.catalog_code) and i.is_active
                                   group by i.catalog_code) c), '{}'::jsonb));
end;
$$;
revoke execute on function app.student_portal_config() from public, anon;
grant execute on function app.student_portal_config() to authenticated;
