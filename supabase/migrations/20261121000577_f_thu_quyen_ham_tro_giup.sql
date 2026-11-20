-- Rà security definer cụm 3 (Code F, 20/11/2026): thu quyền gọi trực tiếp của các hàm trợ giúp chỉ dùng bên trong hàm khác.
-- Các hàm này chạy với quyền chủ (security definer) và KHÔNG tự kiểm quyền hay phạm vi, nhưng mặc định hệ thống cấp cho authenticated
-- (alter default privileges chỉ thu của public, anon), nên người đăng nhập gọi được qua rpc với id bất kỳ:
--   opening_debt_remaining (nợ đầu kỳ còn lại của phụ huynh: TIỀN), class_seats_left, session_hours, session_pending_reason, class_clash_warnings.
-- Giao diện không gọi các hàm này (đã tìm trong src); các hàm nghiệp vụ gọi chúng chạy bằng quyền chủ nên không bị ảnh hưởng.
-- Không đổi thân hàm. Hàm enrollment_hours_balance, staff_display_name giữ nguyên quyền (hàm ticket kiểu invoker còn gọi staff_display_name; 42 bài pgTAP gọi enrollment_hours_balance).
revoke execute on function app.opening_debt_remaining(uuid, uuid) from public, anon, authenticated;
revoke execute on function app.class_seats_left(uuid) from public, anon, authenticated;
revoke execute on function app.session_hours(uuid) from public, anon, authenticated;
revoke execute on function app.session_pending_reason(uuid) from public, anon, authenticated;
revoke execute on function app.class_clash_warnings(uuid) from public, anon, authenticated;
