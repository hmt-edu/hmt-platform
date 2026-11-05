-- Nhóm tự đăng xuất của vai trò (kết quả rà số/danh sách viết cứng 05/11/2026).
-- Làm gì: thêm cột idle_group vào app.role (staff | teacher | student). Trước đây giao diện giữ danh sách vai trò cứng
-- (STAFF_ROLES, TEACHER_ROLES) nên 3 vai trò Marketing (T1, Đ286) bị tính như học sinh: tự đăng xuất 7 ngày thay vì 60 phút.
-- Luật: R-HT-03 (thời gian tự đăng xuất theo nhóm; người nhiều vai trò lấy nhóm chặt nhất, xử lý ở giao diện).
-- Mặc định 'student' để vai trò mới thêm không được nới lỏng ngầm; muốn thành nhân viên phải đặt rõ.
select set_config('hmt.migration', 'on', false);

-- Chỉ mục: không cần (bảng vai trò chỉ hơn chục dòng, đọc cả bảng).
alter table app.role
  add column idle_group text not null default 'student'
  check (idle_group in ('staff', 'teacher', 'student'));

update app.role set idle_group = 'staff'
 where code in ('ADMIN', 'BRANCH_MANAGER', 'SALES', 'CSKH', 'ACCOUNTANT', 'MARKETER', 'MARKETING_MANAGER', 'MARKETING');
update app.role set idle_group = 'teacher' where code in ('TEACHER', 'TA');
-- STUDENT, PARENT giữ 'student'.

comment on column app.role.idle_group is 'Nhóm tự đăng xuất (R-HT-03): staff | teacher | student. Tham số thời gian ở Cài đặt theo nhóm.';
