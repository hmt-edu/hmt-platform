-- HT-02 Bài tập (3 nhóm), HT-03 Chi tiết bài, HT-05 Kết quả bài: hàm ĐỌC cho cổng học sinh (kế hoạch A-23-14 mục 3).
-- Quyền: app.portal_require_student (học sinh = chính mình, phụ huynh = con mình, công tắc HOC_TAP). Không hàm ghi: nộp bài (HT-04) chờ kho R2.
-- Luật: R-LMS-01 (bài giao cả lớp hoặc từng em, chụp danh sách em lúc giao), R-LMS-02 (quá hạn, «Nộp muộn», tắt nhận muộn thì khoá nút),
--       R-LMS-03 (nộp lại tới khi chấm, công tắc cho nộp lại), R-GV-11 (trạng thái chấm, điểm 1–5), R-V2-35 (bài do giáo viên giao; lớp không giao thì danh sách rỗng).

-- app.portal_assignments(p_student_id, p_group, p_limit, p_offset)
-- Làm gì: danh sách bài giao cho một học sinh theo nhóm: CAN_LAM (chưa nộp, kể cả quá hạn), DA_NOP (đã nộp, chưa chấm), DA_CHAM (đã chấm).
-- Ai gọi: học sinh (chính mình), phụ huynh (con mình). Chỉ bài đang giao (DANG_GIAO); bài đã gỡ không hiện.
-- Kết quả: {total, counts: {CAN_LAM, DA_NOP, DA_CHAM}, rows: [...]}; bài hạn gần nhất trước ở CAN_LAM, mới nhất trước ở hai nhóm kia. Phân trang ở máy chủ.
create or replace function app.portal_assignments(p_student_id uuid, p_group text, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_counts jsonb;
  v_total integer;
  v_rows jsonb;
begin
  -- Luật quyền riêng và công tắc Học tập.
  perform app.portal_require_student(p_student_id);
  if p_group not in ('CAN_LAM', 'DA_NOP', 'DA_CHAM') then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Nhóm bài tập không hợp lệ.');
  end if;

  -- Đếm ba nhóm một lần: nhóm theo bài nộp của em (đã chấm > đã nộp > cần làm).
  select jsonb_build_object('CAN_LAM', count(*) filter (where g.grp = 'CAN_LAM'), 'DA_NOP', count(*) filter (where g.grp = 'DA_NOP'),
                            'DA_CHAM', count(*) filter (where g.grp = 'DA_CHAM')),
         count(*) filter (where g.grp = p_group)
    into v_counts, v_total
    from (
      select case when m.graded_at is not null then 'DA_CHAM' when m.submitted_at is not null then 'DA_NOP' else 'CAN_LAM' end as grp
        from app.lms_assignment_target t
        join app.lms_assignment a on a.id = t.assignment_id and a.status = 'DANG_GIAO'
        left join app.lms_submission m on m.assignment_id = a.id and m.student_id = t.student_id
       where t.student_id = p_student_id
    ) g;

  select coalesce(jsonb_agg(x.j order by x.ord1, x.ord2 desc), '[]'::jsonb) into v_rows
    from (
      select case when p_group = 'CAN_LAM' then mine.due_at end as ord1, mine.created_at as ord2,
             jsonb_build_object(
               'assignment_id', mine.id, 'title', mine.title, 'due_at', mine.due_at, 'class_code', c.code, 'subject_name', sub.name,
               'is_overdue', mine.due_at < now(), 'allow_late', mine.allow_late,
               'submitted_at', mine.submitted_at, 'is_late', coalesce(mine.is_late, false),
               'grade_status_code', hr.status_code, 'grade_status_name', gs.name, 'score', hr.score) as j
        from (
          select a.id, a.title, a.due_at, a.allow_late, a.class_id, a.session_id, a.created_at, m.submitted_at, m.is_late, m.graded_at,
                 case when m.graded_at is not null then 'DA_CHAM' when m.submitted_at is not null then 'DA_NOP' else 'CAN_LAM' end as grp
            from app.lms_assignment_target t
            join app.lms_assignment a on a.id = t.assignment_id and a.status = 'DANG_GIAO'
            left join app.lms_submission m on m.assignment_id = a.id and m.student_id = t.student_id
           where t.student_id = p_student_id
        ) mine
        join app.class c on c.id = mine.class_id
        left join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
        left join app.homework_result hr on hr.session_id = mine.session_id and hr.student_id = p_student_id
        left join app.catalog_item gs on gs.catalog_code = 'HOMEWORK_STATUS' and gs.code = hr.status_code
       where mine.grp = p_group
       order by 1 nulls last, mine.created_at desc
       limit v_limit offset v_offset
    ) x;
  return jsonb_build_object('total', v_total, 'counts', v_counts, 'rows', v_rows);
end;
$$;
comment on function app.portal_assignments(uuid, text, integer, integer) is 'HT-02: bài tập của học sinh theo nhóm Cần làm, Đã nộp, Đã chấm; chỉ đọc; quyền theo app.portal_require_student.';

-- app.portal_assignment(p_student_id, p_assignment_id)
-- Làm gì: chi tiết một bài giao cho học sinh (HT-03) kèm kết quả chấm khi đã chấm (HT-05).
-- Kết quả: {assignment, window_state, can_submit, submission, result, files}.
--   window_state: CON_HAN | QUA_HAN_NHAN_MUON | QUA_HAN_KHONG_NHAN (R-LMS-02); can_submit: còn nộp được (chưa chấm, còn hạn hoặc nhận muộn, nộp lại theo công tắc R-LMS-03).
--   result chỉ có sau khi chấm; files là tên tệp đề (chưa có liên kết tải vì kho R2 chưa có).
create or replace function app.portal_assignment(p_student_id uuid, p_assignment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  a app.lms_assignment;
  m app.lms_submission;
  hr app.homework_result;
  v_overdue boolean;
  v_state text;
  v_can boolean;
  v_class_code text;
  v_subject text;
  v_files jsonb;
begin
  perform app.portal_require_student(p_student_id);
  -- Luật: chỉ bài giao cho em này (cả lớp hay chọn em đều đã chụp vào bảng target) và còn đang giao; ngoài ra báo như không thấy.
  select a2.* into a
    from app.lms_assignment a2
    join app.lms_assignment_target t on t.assignment_id = a2.id and t.student_id = p_student_id
   where a2.id = p_assignment_id and a2.status = 'DANG_GIAO';
  if a.id is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem dữ liệu này.');
  end if;
  select * into m from app.lms_submission where assignment_id = a.id and student_id = p_student_id;
  select * into hr from app.homework_result where session_id = a.session_id and student_id = p_student_id;
  select c.code, s.name into v_class_code, v_subject
    from app.class c left join app.catalog_item s on s.catalog_code = c.subject_catalog and s.code = c.subject_code
   where c.id = a.class_id;

  -- Luật R-LMS-02: còn hạn, quá hạn nhận muộn, quá hạn không nhận.
  v_overdue := a.due_at < now();
  v_state := case when not v_overdue then 'CON_HAN' when a.allow_late then 'QUA_HAN_NHAN_MUON' else 'QUA_HAN_KHONG_NHAN' end;
  -- Luật R-LMS-03: chấm rồi thì khoá; đã nộp thì nộp lại chỉ khi công tắc bật.
  v_can := m.graded_at is null and v_state <> 'QUA_HAN_KHONG_NHAN' and (m.submitted_at is null or a.allow_resubmit);

  select coalesce(jsonb_agg(jsonb_build_object('file_name', f.file_name, 'byte_size', f.byte_size, 'mime_type', f.mime_type) order by f.created_at), '[]'::jsonb)
    into v_files from app.lms_assignment_file f where f.assignment_id = a.id;

  return jsonb_build_object(
    'assignment', jsonb_build_object('id', a.id, 'title', a.title, 'description', a.description, 'due_at', a.due_at,
                                     'class_code', v_class_code, 'subject_name', v_subject,
                                     'allow_resubmit', a.allow_resubmit, 'allow_late', a.allow_late),
    'window_state', v_state,
    'can_submit', v_can,
    'submission', case when m.id is null then null
                       else jsonb_build_object('submitted_at', m.submitted_at, 'is_late', m.is_late, 'attempt_count', m.attempt_count, 'graded_at', m.graded_at) end,
    -- Kết quả chỉ lộ sau khi chấm (graded_at có giá trị).
    'result', case when m.graded_at is null or hr.id is null then null
                   else jsonb_build_object('status_code', hr.status_code,
                                      'status_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'HOMEWORK_STATUS' and ci.code = hr.status_code),
                                      'score', hr.score, 'note', hr.note) end,
    'files', v_files);
end;
$$;
comment on function app.portal_assignment(uuid, uuid) is 'HT-03, HT-05: chi tiết bài giao và kết quả chấm của một học sinh; chỉ đọc; quyền theo app.portal_require_student.';

revoke execute on function app.portal_assignments(uuid, text, integer, integer), app.portal_assignment(uuid, uuid) from public, anon;
grant execute on function app.portal_assignments(uuid, text, integer, integer), app.portal_assignment(uuid, uuid) to authenticated;
