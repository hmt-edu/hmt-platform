-- N1 (rà soát bảo mật 23/11, CAO): bảng app.teaching_hours_close (chốt tháng giờ dạy BC-09) chứa ảnh chụp giờ từng giáo viên, trợ giảng MỌI cơ sở (căn cứ lương).
-- Chính sách đọc cũ (migration 619) chỉ đòi Báo cáo · Xem, không xét phạm vi: Trưởng cơ sở (phạm vi cơ sở) đọc thẳng qua REST thấy mọi cơ sở.
-- Sửa: chỉ người có Báo cáo · Xem phạm vi TOÀN HỆ THỐNG đọc thẳng bảng (Kế toán, Admin, người chốt). Trưởng cơ sở vẫn xem tháng đã chốt qua
-- app.teaching_hours_view (security definer, tự lọc theo cơ sở mình), nên màn BC-09 không đổi; giao diện không đọc thẳng bảng (đã tìm trong src).
-- Không đổi bảng, không đổi hàm. Luật: R-GV-09, bản ghi nghiệp vụ chụp lại giá trị lúc chốt.
drop policy teaching_hours_close_read on app.teaching_hours_close;
create policy teaching_hours_close_read on app.teaching_hours_close for select to authenticated
  using ((select app.permission_scope('REPORT', 'XEM')) = 'TOAN_HE_THONG');

-- N2 (rà soát 23/11, THẤP): hàm trợ giúp security definer không tự kiểm quyền nhưng cấp cho authenticated (mặc định hệ thống): ai đăng nhập (kể cả người lạ tự đăng ký,
-- học sinh) gọi được qua rpc với uuid bất kỳ (giá gói, hạn mức thanh toán, tuyến duyệt, tên nhân viên...). Thu quyền gọi trực tiếp như migration 577.
-- Đã kiểm từng hàm: không nằm trong chính sách RLS, view, hàm security invoker nào; giao diện (src) không gọi qua rpc; các hàm nghiệp vụ gọi chúng là security definer nên không bị ảnh hưởng.
-- GIỮ NGUYÊN (có phụ thuộc, ghi để xử lý riêng): app.is_staff, app.lms_assignment_visible (dùng trong chính sách RLS); app.feature_enabled, app.staff_display_name, app.ticket_task_next_approver
-- (hàm security invoker gọi); app.enrollment_hours_balance (pg_cron tự Done gọi không có phiên đăng nhập, nên không thể chặn bằng kiểm người gọi; pgTAP gọi trực tiếp).
revoke execute on function app.approval_route(uuid, uuid, text) from public, anon, authenticated;
revoke execute on function app.assert_staff_in_branch(uuid, uuid) from public, anon, authenticated;
revoke execute on function app.class_operating_status(uuid) from public, anon, authenticated;
revoke execute on function app.enrollment_group_label(text, text) from public, anon, authenticated;
revoke execute on function app.is_branch_manager_at(uuid, text, uuid) from public, anon, authenticated;
revoke execute on function app.mfa_enforced() from public, anon, authenticated;
revoke execute on function app.package_price_at(uuid, text, date) from public, anon, authenticated;
revoke execute on function app.payment_term_amounts(uuid, bigint) from public, anon, authenticated;
revoke execute on function app.permission_current_version() from public, anon, authenticated;
revoke execute on function app.review_average(uuid) from public, anon, authenticated;
revoke execute on function app.review_criteria_for_subject(text) from public, anon, authenticated;
revoke execute on function app.session_group_label(text, text) from public, anon, authenticated;
