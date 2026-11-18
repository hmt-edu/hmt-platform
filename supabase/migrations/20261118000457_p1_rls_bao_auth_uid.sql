-- Migration 457 (Code D, 18/11/2026): sửa P1 của Soát ở phần CHÍNH SÁCH RLS (hiệu năng, CLAUDE.md «viết dạng (select ...)»).
-- Bốn chính sách còn so cột với auth.uid() trần: Postgres gọi lại auth.uid() cho từng dòng và không đưa được vào kế hoạch một lần (initplan).
-- Bọc thành (select auth.uid()). Nghĩa của chính sách giữ NGUYÊN; chỉ đổi cách viết. Các hàm danh sách (33 hàm) làm ở PR riêng.
--   app.user_account (user_account_read), app.user_role (user_role_read), app.notification (notification_read_own), app.saved_filter (saved_filter_read).
-- Chỉ mục: không đổi (id, user_id, owner_id đã có chỉ mục khoá).

alter policy user_account_read on app.user_account
  using (id = (select auth.uid()) or app.can_see_branch('ACCOUNT', 'XEM', branch_id));

alter policy user_role_read on app.user_role
  using (user_id = (select auth.uid())
         or exists (select from app.user_account a
                     where a.id = user_id and app.can_see_branch('ACCOUNT', 'XEM', a.branch_id)));

alter policy notification_read_own on app.notification
  using (user_id = (select auth.uid()) and app.current_user_ready() and app.mfa_satisfied());

alter policy saved_filter_read on app.saved_filter
  using (not is_cancelled and app.current_user_ready() and app.mfa_satisfied()
         and (owner_id = (select auth.uid()) or is_shared));
