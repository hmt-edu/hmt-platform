-- Rà security definer cụm 3: hàm trợ giúp không cấp cho authenticated (migration 577).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is(has_function_privilege('authenticated', 'app.opening_debt_remaining(uuid, uuid)', 'execute'), false, 'opening_debt_remaining: người đăng nhập không gọi thẳng (tiền)');
select is(has_function_privilege('authenticated', 'app.class_seats_left(uuid)', 'execute'), false, 'class_seats_left: không gọi thẳng');
select is(has_function_privilege('authenticated', 'app.session_hours(uuid)', 'execute'), false, 'session_hours: không gọi thẳng');
select is(has_function_privilege('authenticated', 'app.session_pending_reason(uuid)', 'execute'), false, 'session_pending_reason: không gọi thẳng');
select is(has_function_privilege('authenticated', 'app.class_clash_warnings(uuid)', 'execute'), false, 'class_clash_warnings: không gọi thẳng');
select is(has_function_privilege('anon', 'app.opening_debt_remaining(uuid, uuid)', 'execute'), false, 'opening_debt_remaining: khách chưa đăng nhập cũng không gọi được');

select * from finish();
rollback;
