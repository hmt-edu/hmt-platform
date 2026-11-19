-- Migration 469 (Code D, 19/11/2026): thẻ D34, rà hiệu năng RLS. CLAUDE.md: hàm quyền trong chính sách viết dạng (select app.f(...)) để Postgres đánh giá MỘT lần mỗi câu (initplan), không mỗi dòng.
-- Quét mọi chính sách trên main: còn 20 chính sách gọi app.has_permission, app.current_user_ready, app.mfa_satisfied trần (không đối số theo dòng). Quan trọng nhất: audit_log (nhật ký thao tác, bảng lớn nhất),
-- export_log, permission_change, permission_version. Chỉ bọc lại, nghĩa chính sách giữ NGUYÊN. Không đụng app.can_see_branch(..., branch_id) vì phụ thuộc cột của dòng (không thể thành initplan).

alter policy audit_log_read_admin on app.audit_log
  using ((select app.has_permission('ADMIN', 'XEM')));

alter policy audited_table_read_admin on app.audited_table
  using ((select app.has_permission('ADMIN', 'XEM')));

alter policy export_log_read on app.export_log
  using ((select app.has_permission('ADMIN', 'XEM')) or (app.can_see_branch('REPORT', 'XEM', branch_id) and (select app.has_permission('REPORT', 'XEM'))));

alter policy permission_change_read on app.permission_change
  using ((select app.has_permission('ADMIN', 'XEM')));

alter policy permission_version_read on app.permission_version
  using ((select app.has_permission('ADMIN', 'XEM')));

alter policy academic_year_read on app.academic_year
  using ((select app.current_user_ready()));

alter policy branch_read on app.branch
  using ((select app.current_user_ready()));

alter policy feature_flag_read on app.feature_flag
  using ((select app.current_user_ready()));

alter policy holiday_read on app.holiday
  using ((select app.current_user_ready()));

alter policy notification_read_own on app.notification
  using (user_id = (select auth.uid()) and (select app.current_user_ready()) and (select app.mfa_satisfied()));

alter policy saved_filter_read on app.saved_filter
  using (not is_cancelled and (select app.current_user_ready()) and (select app.mfa_satisfied()) and (owner_id = (select auth.uid()) or is_shared));

alter policy permission_read on app.permission
  using ((select app.current_user_ready()) and ((select app.is_staff()) or role_code = any (app.current_roles())));

alter policy role_read on app.role
  using ((select app.current_user_ready()) and ((select app.is_staff()) or code = any (app.current_roles())));

alter policy setting_def_read on app.setting_def
  using ((select app.current_user_ready()) and ((select app.is_staff()) or key = 'student_idle_logout_minutes'));

alter policy setting_branch_read on app.setting_branch
  using ((select app.current_user_ready()) and (select app.is_staff()));

alter policy catalog_read on app.catalog
  using ((select app.current_user_ready()) and ((select app.is_staff()) or app.student_visible_catalog(code)));

alter policy catalog_item_read on app.catalog_item
  using ((select app.current_user_ready()) and ((select app.is_staff()) or app.student_visible_catalog(catalog_code)));

alter policy code_format_read on app.code_format
  using ((select app.current_user_ready()) and (select app.is_staff()));

alter policy room_read on app.room
  using ((select app.current_user_ready()) and (select app.is_staff()));

alter policy note_target_read on app.note_target
  using ((select app.current_user_ready()) and (select app.is_staff()));
