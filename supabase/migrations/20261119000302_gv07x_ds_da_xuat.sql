-- GV-07X (A24, Chat duyệt 19/11/2026): danh sách em đã xuất nhận xét của một buổi, để màn chấm hiện dấu «Đã xuất» cạnh tên em (khung GV07X_xem_truoc, R-V2-38).
-- Cờ và hàm ghi đã có từ migration 103 (app.session_student_review.exported, app.set_review_exported); chỉ thiếu hàm ĐỌC gọn cho giao diện, không đụng
-- app.session_review_sheet (do lane E đang sửa).

-- app.review_exported_students(buổi) -> mảng mã học sinh đã đặt cờ Đã xuất. Ai gọi: người xem được điểm danh của buổi (giáo viên, trợ giảng được phân công; vận hành), như set_review_exported.
create or replace function app.review_exported_students(p_session_id uuid)
returns uuid[]
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  -- Luật: cùng quyền với việc đặt cờ (Điểm danh · Xem, trong phạm vi buổi): giáo viên khác không đọc được.
  perform app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  return coalesce((
    select array_agg(a.student_id order by a.student_id)
      from app.session_student_review r
      join app.session_attendance a on a.id = r.attendance_id
     where r.session_id = p_session_id and r.exported and a.is_active), '{}'::uuid[]);
end;
$$;
revoke execute on function app.review_exported_students(uuid) from public, anon, authenticated;
grant execute on function app.review_exported_students(uuid) to authenticated;
