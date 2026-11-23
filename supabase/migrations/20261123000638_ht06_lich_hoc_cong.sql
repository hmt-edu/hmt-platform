-- HT-06 Lịch học (học sinh) và PH-05 Lịch học của con (phụ huynh): MỘT hàm dùng chung cho hai cổng (kế hoạch A-23-14 mục 3).
-- Chỉ đọc. Quyền: app.portal_require_student (học sinh = chính mình, phụ huynh = con mình, công tắc HOC_TAP).

-- app.portal_schedule(p_student_id, p_from, p_to)
-- Làm gì: các buổi học của một học sinh trong khoảng ngày [p_from, p_to], sắp theo ngày và giờ.
-- Ai gọi: học sinh (chính mình) hoặc phụ huynh (con mình) qua cổng /hoc, /ph.
-- Kết quả: {rows: [{session_id, session_date, start_time, end_time, class_code, subject_name, room_name, teacher_name, type_code, type_name, status_code, is_makeup}]}
-- Luật: buổi của lớp học sinh đang học ở ngày đó (dòng xếp lớp còn hiệu lực, R-GD-02) hoặc buổi học sinh có tên trong danh sách điểm danh (buổi bù, bổ trợ);
--       không hiện buổi «Nháp» của lịch cũ đã bị thay (DA_THAY); số dòng tối đa list_page_size_max.
create or replace function app.portal_schedule(p_student_id uuid, p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_max integer := app.get_setting_int('list_page_size_max');
  v_rows jsonb;
begin
  -- Luật quyền riêng và công tắc Học tập.
  perform app.portal_require_student(p_student_id);
  if p_from is null or p_to is null or p_to < p_from then
    perform app.raise_error('HMT_KHOANG_NGAY_SAI', 'Khoảng ngày không hợp lệ.');
  end if;

  select coalesce(jsonb_agg(x.j order by x.session_date, x.start_time), '[]'::jsonb) into v_rows
    from (
      select cs.session_date, cs.start_time,
             jsonb_build_object(
               'session_id', cs.id, 'session_date', cs.session_date, 'start_time', cs.start_time, 'end_time', cs.end_time,
               'class_code', c.code, 'subject_name', sub.name, 'room_name', r.name, 'teacher_name', t.display_name,
               'type_code', cs.type_code, 'type_name', ty.name, 'status_code', cs.status_code,
               -- Buổi bù, bổ trợ (không trừ giờ): nhãn riêng ở giao diện.
               'is_makeup', cs.type_code in ('HOC_BU', 'BO_TRO')) as j
        from app.class_session cs
        join app.class c on c.id = cs.class_id
        left join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
        left join app.catalog_item ty on ty.catalog_code = cs.type_catalog and ty.code = cs.type_code
        left join app.room r on r.id = cs.room_id
        left join app.user_account t on t.id = cs.teacher_id
       where cs.session_date between p_from and p_to
         and cs.status_code <> 'DA_THAY'
         and (
           exists (select 1
                     from app.enrollment e
                     join app.enrollment_class ec on ec.enrollment_id = e.id
                    where e.student_id = p_student_id and ec.class_id = cs.class_id
                      and ec.start_date <= cs.session_date and (ec.end_date is null or ec.end_date >= cs.session_date))
           or exists (select 1 from app.session_attendance sa
                       where sa.session_id = cs.id and sa.student_id = p_student_id and sa.is_active)
         )
       order by cs.session_date, cs.start_time
       limit v_max
    ) x;
  return jsonb_build_object('rows', v_rows);
end;
$$;
comment on function app.portal_schedule(uuid, date, date) is 'HT-06, PH-05: lịch học của một học sinh trong khoảng ngày; chỉ đọc; quyền theo app.portal_require_student.';

revoke execute on function app.portal_schedule(uuid, date, date) from public, anon;
grant execute on function app.portal_schedule(uuid, date, date) to authenticated;
