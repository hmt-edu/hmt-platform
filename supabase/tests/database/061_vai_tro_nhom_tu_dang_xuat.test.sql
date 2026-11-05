-- Nhóm tự đăng xuất của vai trò (R-HT-03): cột app.role.idle_group thay danh sách vai trò viết cứng trong giao diện.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select is((select count(*)::int from app.role where idle_group = 'staff'), 8,
  'Tám vai trò nhân viên (5 gốc + 3 Marketing) thuộc nhóm nhân viên');
select is((select string_agg(code, ',' order by code) from app.role where idle_group = 'teacher'), 'TA,TEACHER',
  'Giáo viên và Trợ giảng thuộc nhóm giáo viên');
select is((select string_agg(code, ',' order by code) from app.role where idle_group = 'student'), 'PARENT,STUDENT',
  'Học sinh và Phụ huynh thuộc nhóm học sinh');
select is((select idle_group from app.role where code = 'MARKETER'), 'staff',
  'Lỗi 05/11: vai trò Marketing không còn bị tính như học sinh');
select is((select column_default from information_schema.columns where table_schema = 'app' and table_name = 'role' and column_name = 'idle_group'),
  '''student''::text', 'Vai trò mới mặc định nhóm học sinh (không nới lỏng ngầm)');
select throws_ok($$update app.role set idle_group = 'khac' where code = 'TA'$$, '23514', null,
  'Nhóm ngoài staff, teacher, student bị chặn');

select * from finish();
rollback;
