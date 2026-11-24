-- HT-08 Nhận xét các buổi (học sinh) và PH-02 «tất cả nhận xét» (phụ huynh): MỘT hàm dùng chung. Chỉ đọc.
-- Quyền: app.portal_require_student (học sinh = chính mình, phụ huynh = con mình, công tắc HOC_TAP), migration 637.

-- app.portal_reviews(p_student_id, p_limit, p_offset)
-- Làm gì: lời nhận xét của giáo viên cho từng buổi, mới nhất trước, phân trang ở máy chủ.
-- Ai gọi: học sinh (chính mình) hoặc phụ huynh (con mình) qua cổng /hoc, /ph.
-- Kết quả: {total, rows: [{session_id, session_no, session_date, class_code, subject_name, comment}]}
-- Luật:
--  * R-V2-39: chỉ lời nhắn là chữ giáo viên (session_student_review.teacher_comment); không hiện ghi chú cần cải thiện nội bộ (improvement_note).
--  * R-GV-04: em vắng không có nhận xét; chỉ buổi giáo viên điểm danh CO_MAT hoặc DI_MUON, lời nhắn không trống.
--  * Mức chặt (Chat chọn 03:35, nới sau được bằng cách bỏ điều kiện parent_sent_at): chỉ hiện khi buổi ở trạng thái DONE VÀ nhận xét đã gửi phụ huynh (parent_sent_at không rỗng); lời nhắn nháp thì không hiện.
--  * Số dòng mỗi trang mặc định list_page_size_default, tối đa list_page_size_max.
create or replace function app.portal_reviews(p_student_id uuid, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_total bigint;
  v_rows jsonb;
begin
  -- Luật quyền riêng và công tắc Học tập.
  perform app.portal_require_student(p_student_id);

  select count(*) into v_total
    from app.session_student_review r
    join app.session_attendance a on a.id = r.attendance_id
   where a.student_id = p_student_id and a.is_active and a.teacher_status_code in ('CO_MAT', 'DI_MUON')
     and nullif(btrim(coalesce(r.teacher_comment, '')), '') is not null
     and r.parent_sent_at is not null
     and exists (select 1 from app.class_session s0 where s0.id = r.session_id and s0.status_code = 'DONE');

  select coalesce(jsonb_agg(x.j order by x.session_date desc, x.session_no desc), '[]'::jsonb) into v_rows
    from (
      select cs.session_date, cs.session_no,
             jsonb_build_object('session_id', cs.id, 'session_no', cs.session_no, 'session_date', cs.session_date,
                                'class_code', c.code, 'subject_name', sub.name, 'comment', r.teacher_comment) as j
        from app.session_student_review r
        join app.session_attendance a on a.id = r.attendance_id
        join app.class_session cs on cs.id = r.session_id
        join app.class c on c.id = cs.class_id
        left join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
       where a.student_id = p_student_id and a.is_active and a.teacher_status_code in ('CO_MAT', 'DI_MUON')
         and nullif(btrim(coalesce(r.teacher_comment, '')), '') is not null
         and r.parent_sent_at is not null and cs.status_code = 'DONE'
       order by cs.session_date desc, cs.session_no desc
       limit v_limit offset v_offset
    ) x;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;
comment on function app.portal_reviews(uuid, integer, integer) is 'HT-08, PH-02: nhận xét của giáo viên theo buổi cho một học sinh; chỉ đọc; quyền theo app.portal_require_student.';

revoke execute on function app.portal_reviews(uuid, integer, integer) from public, anon;
grant execute on function app.portal_reviews(uuid, integer, integer) to authenticated;
