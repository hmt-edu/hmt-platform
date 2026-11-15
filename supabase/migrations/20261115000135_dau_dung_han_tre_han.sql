-- Dấu Đúng hạn/Trễ hạn của buổi (R-GV-05, R-GV-06; phần "để sau 17/11" Chat đã quyết 13/11, nay làm theo CHẾ ĐỘ TỰ CHỦ).
-- Ba cột mới ở app.class_session do hệ thống ghi MỘT lần lúc Done (app.mark_session_done): completion_stamped_at, completion_late, completion_late_hours.
-- Buổi Done trước migration này không có dấu (null), không suy ngược. app.session_overview trả thêm khoá 'completion'. Thân hai hàm giữ nguyên bản cũ
-- (mark_session_done: migration 102, session_overview: migration 121), chỉ thêm phần đóng dấu và khoá mới; quyền gọi giữ nguyên.
alter table app.class_session
  add column completion_stamped_at timestamptz,
  add column completion_late boolean,
  add column completion_late_hours numeric(6, 2) check (completion_late_hours is null or completion_late_hours >= 0);
comment on column app.class_session.completion_stamped_at is 'Lúc hệ thống đóng dấu Đúng hạn/Trễ hạn (một lần, lúc Done).';
comment on column app.class_session.completion_late is 'true = Trễ hạn so với hạn giáo viên hoàn tất (R-GV-05); null = chưa đóng dấu.';
comment on column app.class_session.completion_late_hours is 'Số giờ trễ lúc Done (0 khi đúng hạn).';
-- Báo cáo giáo viên trễ hạn hằng tháng (BC-08, R-GV-06) lọc buổi đã đóng dấu theo cơ sở và ngày: chỉ mục riêng, chỉ dòng có dấu.
create index class_session_completion_idx on app.class_session (branch_id, session_date) where completion_stamped_at is not null;

create or replace function app.mark_session_done(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text;
  v_s app.class_session;
  v_deadline timestamptz;
begin
  perform 1 from app.class_session where id = p_session_id for update;
  v_reason := app.session_pending_reason(p_session_id);
  if v_reason is not null then
    perform app.raise_error('HMT_BUOI_CHUA_DONE_DUOC', v_reason);
  end if;
  perform app.deduct_session_hours(p_session_id);
  -- Luật R-GV-05, R-GV-06 (Chat chốt 13/11): hệ thống đóng dấu MỘT lần Đúng hạn hoặc Trễ hạn kèm số giờ trễ lúc Done, so với hạn giáo viên hoàn tất
  -- (giờ kết thúc buổi cộng teacher_session_complete_hours). Không dùng updated_at (đổi khi sửa sau Done). Sửa điểm sau Done không đổi dấu.
  select * into v_s from app.class_session where id = p_session_id;
  v_deadline := app.session_ends_at(p_session_id)
                + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', v_s.branch_id)::integer);
  update app.class_session
     set status_code = 'DONE',
         completion_stamped_at = coalesce(completion_stamped_at, now()),
         completion_late = coalesce(completion_late, now() > v_deadline),
         completion_late_hours = coalesce(completion_late_hours,
           greatest(0, round((extract(epoch from (now() - v_deadline)) / 3600.0)::numeric, 2))) -- allow-number: 3600 giây một giờ (đổi giây ra giờ)
   where id = p_session_id;
  update app.enrollment set status_code = 'DANG_HOC'
   where status_code = 'DA_XEP_LOP' and id in (select enrollment_id from app.session_attendance
                                               where session_id = p_session_id and is_active and enrollment_id is not null);
end;
$$;

create or replace function app.session_overview(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  c app.class;
  v_total integer;
  v_marked integer;
  v_homework text;
  v_lines jsonb;
  v_scored integer;
  v_exam jsonb;
  v_present integer;
  v_graded integer;
  v_missing jsonb;
  v_hw jsonb;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select * into c from app.class where id = s.class_id;
  select count(*), count(teacher_status_code) into v_total, v_marked
    from app.session_attendance where session_id = s.id and is_active;
  select coalesce(jsonb_agg(l.line_text order by l.sort_order), '[]'::jsonb) into v_lines
    from app.session_content_line l where l.session_id = s.id and l.is_active;
  select homework_text into v_homework from app.session_content where session_id = s.id;
  -- Buổi Kiểm tra: phạm vi kiến thức, điểm tối đa, cách nhập điểm do vận hành đặt (set_exam_config); giáo viên chỉ xem. Chưa đặt thì null.
  select jsonb_build_object('scope_text', e.scope_text, 'max_score', e.max_score, 'entry_mode', e.entry_mode,
                            'max_memory', e.max_memory, 'max_understand', e.max_understand, 'max_apply', e.max_apply)
    into v_exam from app.session_exam e where e.session_id = s.id;
  -- Số ô nhận xét đã chấm: màn GV-06 báo "sửa nội dung sau khi đã chấm" (điểm 9 tiêu chí không đổi khi sửa dòng nội dung, Q-245).
  select count(*) into v_scored from app.session_review_score where session_id = s.id and state <> 'CHUA_DANH_GIA';
  -- Bước chấm của GV-04 (R-GV-04, R-V2-20): em có mặt (Có mặt, Đi muộn) đã chấm đủ. Buổi thường: mọi tiêu chí đang bật đều có điểm hoặc trạng thái khác "Chưa đánh giá".
  -- Buổi Kiểm tra: đã chấm điểm. Kèm tên tối đa 10 em còn thiếu (giáo viên được thấy tên em trong lớp mình, R-GV-13).
  with present as (
    select sa.id, st.full_name,
           case when s.type_code = 'KIEM_TRA' then exists (select from app.exam_score es where es.attendance_id = sa.id and es.graded)
                else exists (select from app.session_review_criterion rc where rc.session_id = sa.session_id and rc.enabled)
                     and not exists (select from app.session_review_criterion rc
                                      where rc.session_id = sa.session_id and rc.enabled
                                        and not exists (select from app.session_review_score sc
                                                         where sc.attendance_id = sa.id and sc.session_criterion_id = rc.id and sc.state <> 'CHUA_DANH_GIA')) end as complete
      from app.session_attendance sa join app.student st on st.id = sa.student_id
     where sa.session_id = s.id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
  )
  select count(*), count(*) filter (where complete),
         coalesce((select jsonb_agg(m.full_name) from (select full_name from present where not complete order by full_name limit 10) m), '[]'::jsonb) -- allow-number: tối đa 10 tên em còn thiếu hiện trên màn
    into v_present, v_graded, v_missing from present;
  -- Bước chấm BTVN buổi trước (GV-04, GV-08, R-V2-35, R-GV-11): tiến độ do app.homework_progress tính (DAU_LOP, KHONG_GIAO: bỏ qua, không chặn).
  v_hw := app.homework_progress(s.id);
  return jsonb_build_object(
    'session_id', s.id, 'status_code', s.status_code, 'type_code', s.type_code,
    'type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SESSION_TYPE' and ci.code = s.type_code),
    'class_code', c.code,
    'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
    'session_no', s.session_no, 'session_date', s.session_date, 'start_time', s.start_time, 'end_time', s.end_time,
    'attendance_total', v_total, 'attendance_marked', v_marked,
    'content_lines', jsonb_array_length(v_lines), 'has_content', jsonb_array_length(v_lines) > 0,
    'lines', v_lines, 'homework_text', v_homework, 'review_scored', v_scored, 'exam', v_exam,
    'grading_present', v_present, 'grading_done', v_graded, 'grading_missing', v_missing, 'prev_homework_state', v_hw ->> 'state', 'homework_present', (v_hw ->> 'present')::integer, 'homework_done', (v_hw ->> 'done')::integer,
    'homework_missing', v_hw -> 'missing', 'prev_session_no', (v_hw ->> 'prev_session_no')::integer,
    -- Số phiên bản để chặn ghi đè (Q-243): giao diện gửi lại giá trị này khi lưu; 0 = chưa có nội dung nào.
    'content_version', coalesce((select sc.version from app.session_content sc where sc.session_id = s.id), 0),
    'deadline_at', app.session_ends_at(s.id) + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', s.branch_id)::integer),
    'pending_reason', case when s.status_code = 'DONE' then null else app.session_pending_reason(s.id) end,
    -- Dấu Đúng hạn/Trễ hạn do hệ thống đóng lúc Done (R-GV-05); buổi chưa Done hoặc Done trước khi có cột thì null.
    'completion', case when s.completion_stamped_at is null then null
                       else jsonb_build_object('late', s.completion_late, 'late_hours', s.completion_late_hours, 'stamped_at', s.completion_stamped_at) end);
end;
$$;
