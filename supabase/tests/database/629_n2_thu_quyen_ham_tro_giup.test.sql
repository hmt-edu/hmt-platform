-- N2 (migration 629): hàm trợ giúp security definer không tự kiểm quyền không còn gọi trực tiếp được bởi người đăng nhập. Chỉ kiểm quyền gọi, không cần dữ liệu.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is(has_function_privilege('authenticated', 'app.assert_staff_in_branch(uuid, uuid)', 'execute'), false, 'N2: assert_staff_in_branch không gọi trực tiếp được');
select is(has_function_privilege('authenticated', 'app.class_operating_status(uuid)', 'execute'), false, 'N2: class_operating_status không gọi trực tiếp được');
select is(has_function_privilege('authenticated', 'app.enrollment_group_label(text, text)', 'execute'), false, 'N2: enrollment_group_label không gọi trực tiếp được');
select is(has_function_privilege('authenticated', 'app.is_branch_manager_at(uuid, text, uuid)', 'execute'), false, 'N2: is_branch_manager_at không gọi trực tiếp được');
select is(has_function_privilege('authenticated', 'app.mfa_enforced()', 'execute'), false, 'N2: mfa_enforced không gọi trực tiếp được');
select is(has_function_privilege('authenticated', 'app.package_price_at(uuid, text, date)', 'execute'), false, 'N2: package_price_at (giá gói) không gọi trực tiếp được');
select is(has_function_privilege('authenticated', 'app.payment_term_amounts(uuid, bigint)', 'execute'), false, 'N2: payment_term_amounts không gọi trực tiếp được');
select is(has_function_privilege('authenticated', 'app.review_average(uuid)', 'execute'), false, 'N2: review_average không gọi trực tiếp được');
select is(has_function_privilege('authenticated', 'app.review_criteria_for_subject(text)', 'execute'), false, 'N2: review_criteria_for_subject không gọi trực tiếp được');
select is(has_function_privilege('authenticated', 'app.session_group_label(text, text)', 'execute'), false, 'N2: session_group_label không gọi trực tiếp được');
select is(has_function_privilege('authenticated', 'app.approval_route(uuid, uuid, text)', 'execute'), true, 'N2: approval_route 3 tham số còn được hàm 1 tham số gọi nên giữ quyền');
-- Hàm còn phụ thuộc (chính sách RLS, hàm security invoker) vẫn phải gọi được, nếu không đăng nhập hỏng.
select is(has_function_privilege('authenticated', 'app.is_staff()', 'execute'), true, 'N2: is_staff còn dùng trong chính sách RLS nên giữ quyền gọi');
select is(has_function_privilege('authenticated', 'app.lms_assignment_visible(uuid)', 'execute'), true, 'N2: lms_assignment_visible còn dùng trong chính sách RLS nên giữ quyền gọi');
select is(has_function_privilege('authenticated', 'app.staff_display_name(uuid)', 'execute'), true, 'N2: staff_display_name còn được hàm security invoker gọi nên giữ quyền gọi');

select * from finish();
rollback;
