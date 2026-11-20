-- Rà hàm security definer (Code F, 20/11/2026), cùng loại lỗi E67 (migration 514) và migration 570.
-- app.duplicate_students_of_parent trả tên và mã học sinh trùng dưới một phụ huynh; trước đây chỉ kiểm "có quyền Xem học sinh"
-- chứ không kiểm cơ sở của từng học sinh, nên người có phạm vi Xem hẹp (CO_SO) đọc được tên, mã học sinh của cơ sở khác
-- bằng cách gọi thẳng hàm với id phụ huynh bất kỳ.
-- Sửa (R-CRM-26: phạm vi Xem theo ma trận quyền): chỉ tính học sinh mà người gọi xem được (app.can_see_branch('STUDENT', 'XEM', ...)).
-- Với người có Xem toàn hệ thống (Sale, CSKH, Trưởng cơ sở theo ma trận hiện hành) kết quả không đổi.
-- Hàm vẫn dùng ở app.merge_parents (cảnh báo học sinh trùng sau gộp): người gộp có quyền Duyệt, các em ngoài phạm vi Xem của họ
-- không nêu tên trong cảnh báo (an toàn hơn: không lộ).
-- Không đổi chữ ký, không đổi quyền gọi (create or replace giữ nguyên grant).

create or replace function app.duplicate_students_of_parent(p_parent_id uuid)
returns table (student_name text, birth_year integer, student_ids uuid[], student_codes text[])
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if app.permission_scope('STUDENT', 'XEM') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem học sinh.');
  end if;
  return query
    select min(s.full_name), s.birth_year, array_agg(s.id order by s.created_at, s.id), array_agg(s.code order by s.created_at, s.id)
      from app.student s
     where s.parent_id = p_parent_id and s.record_status = 'DANG_DUNG'
       -- Chỉ nêu học sinh trong phạm vi Xem của người gọi (cùng loại E67).
       and app.can_see_branch('STUDENT', 'XEM', s.branch_id)
     group by app.normalize_person_name(s.full_name), s.birth_year
    having count(*) > 1;
end;
$$;
