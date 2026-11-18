-- E1 (Soát Q9): giáo viên, trợ giảng đọc được MỌI học sinh của cơ sở qua bảng app.student.
-- Gốc lỗi: chính sách student_read (migration 24) coi mọi phạm vi «không rỗng» là «cả cơ sở»; ô STUDENT.XEM của TEACHER, TA là
-- DUOC_PHAN_CONG nên rơi vào nhánh cơ sở. Luật: R-GV-13 (giáo viên, trợ giảng chỉ thấy học sinh trong lớp được phân công), R-GV-08.
--
-- app.student_assigned_to_me(p_student_id) -> boolean
-- Ai gọi: chính sách RLS của app.student (mọi người đã đăng nhập; chỉ trả đúng/sai cho người gọi). Đúng khi em đang ghi danh (chưa kết thúc) ở một lớp
-- mà người gọi được phân công (app.is_assigned_to_class). Cùng điều kiện với app.get_student_record để hai đường không lệch nhau.
create or replace function app.student_assigned_to_me(p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select from app.enrollment e
      join app.enrollment_class ec on ec.enrollment_id = e.id
     where e.student_id = p_student_id and ec.end_date is null and app.is_assigned_to_class(ec.class_id));
$$;
revoke execute on function app.student_assigned_to_me(uuid) from public, anon, authenticated;
grant execute on function app.student_assigned_to_me(uuid) to authenticated;

-- Chính sách mới: TOAN_HE_THONG thấy hết; DUOC_PHAN_CONG chỉ thấy em trong lớp mình; các phạm vi khác còn lại (CO_SO...) như cũ: cả cơ sở.
drop policy student_read on app.student;
create policy student_read on app.student for select to authenticated
  using ((select app.permission_scope('STUDENT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('STUDENT', 'XEM')) = 'DUOC_PHAN_CONG' and app.student_assigned_to_me(id))
         or ((select app.permission_scope('STUDENT', 'XEM')) is not null
             and (select app.permission_scope('STUDENT', 'XEM')) <> 'DUOC_PHAN_CONG'
             and branch_id = (select app.current_branch_id())));
