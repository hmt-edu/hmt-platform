-- Migration 598 (Code E, 21/11/2026): LMS chấm bài nộp online (GV-18), phần 2: danh sách em, phiếu chấm, lưu điểm, mở lại.
-- Đề xuất đã duyệt: docs/nghiep-vu/de-xuat-db-lms-gv17-gv18.md (Chat 02:29, phương án B: bài nộp chữ/chưa có tệp). Bảng ở migration 597.
-- Luật: R-GV-11 (thang 1–5, năm trạng thái BTVN; em vắng buổi giao mặc định Không áp dụng, giáo viên đổi được), R-LMS-02 (nhãn «Nộp muộn»,
-- em chưa nộp tới lúc chấm: Nộp sau hoặc Không làm), R-LMS-03 (chấm rồi thì khoá bài nộp, giáo viên mở lại được), R-GV-10 (điểm chấm ghi vào BTVN của buổi giao).
-- Quyết định Chat Q1 (giữ R-GV-10: không tạo bảng điểm thứ hai), Q5 (chọn Không làm, Nộp sau, Không áp dụng thì bỏ điểm), Q6, Q8, Q12, Q13, Q14.
-- Điểm và trạng thái chấm GHI VÀO app.homework_result (session_id = buổi giao, student_id); lms_submission giữ bài nộp và dấu «đã chấm».
-- Hàm nộp bài của học sinh (HT-05) làm sau; bài kiểm dựng bài nộp giả bằng quyền hệ thống.

-- ---------------------------------------------------------------------------
-- 1. Em có mặt ở buổi giao? (Q6: em vắng buổi giao mà chưa nộp mặc định Không áp dụng)
-- ---------------------------------------------------------------------------
create or replace function app.lms_student_absent(p_session_id uuid, p_student_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  -- Vắng = có dòng điểm danh nhưng không phải Có mặt, Đi muộn; chưa điểm danh thì không coi là vắng.
  select exists (select from app.session_attendance sa
                  where sa.session_id = p_session_id and sa.student_id = p_student_id and sa.is_active
                    and sa.teacher_status_code is not null and sa.teacher_status_code not in ('CO_MAT', 'DI_MUON'));
$$;
revoke execute on function app.lms_student_absent(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Danh sách em của một bài
-- ---------------------------------------------------------------------------
-- app.lms_grading_list(p_assignment_id uuid, p_filter text) -> jsonb {assignment, rows}
-- Ai được gọi: người có quyền ATTENDANCE Xem với buổi giao (giáo viên, trợ giảng của buổi; vận hành theo cơ sở), phân hệ HOC_TAP bật.
-- p_filter: null (tất cả), 'CHUA_CHAM' hoặc 'DA_CHAM'. Mỗi em: trạng thái nộp (CHUA_NOP | DA_NOP; «Nộp muộn» là nhãn is_late, R-LMS-02),
--   trạng thái chấm (mã BTVN, điểm). Chỉ tên và mã học sinh (R-GV-13). Tiến độ «đã chấm x/y» nằm ở assignment.graded và assignment.targets.
create or replace function app.lms_grading_list(p_assignment_id uuid, p_filter text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  a app.lms_assignment;
  v_rows jsonb;
begin
  a := app.lms_assert_assignment(p_assignment_id, 'XEM');
  if p_filter is not null and p_filter not in ('CHUA_CHAM', 'DA_CHAM') then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Bộ lọc không hợp lệ.');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'student_id', x.student_id, 'student_code', x.code, 'full_name', x.full_name,
           'submit_state', case when x.submitted_at is null then 'CHUA_NOP' else 'DA_NOP' end,
           'is_late', coalesce(x.is_late, false), 'attempt_count', coalesce(x.attempt_count, 0), 'submitted_at', x.submitted_at,
           'grade_status_code', x.status_code, 'score', x.score, 'graded', x.graded_at is not null) order by x.full_name, x.student_id), '[]'::jsonb)
    into v_rows
    from (
      select st.id as student_id, st.code, st.full_name, m.submitted_at, m.is_late, m.attempt_count, m.graded_at, hr.status_code, hr.score
        from app.lms_assignment_target t
        join app.student st on st.id = t.student_id
        left join app.lms_submission m on m.assignment_id = t.assignment_id and m.student_id = t.student_id
        left join app.homework_result hr on hr.session_id = a.session_id and hr.student_id = t.student_id
       where t.assignment_id = a.id
         and case p_filter when 'CHUA_CHAM' then m.graded_at is null when 'DA_CHAM' then m.graded_at is not null else true end
    ) x;
  return jsonb_build_object(
    'assignment', jsonb_build_object(
      'id', a.id, 'title', a.title, 'due_at', a.due_at, 'status', a.status, 'version', a.version,
      'targets', (select count(*) from app.lms_assignment_target t where t.assignment_id = a.id),
      'submitted', (select count(*) from app.lms_submission m where m.assignment_id = a.id and m.submitted_at is not null),
      'graded', (select count(*) from app.lms_submission m where m.assignment_id = a.id and m.graded_at is not null)),
    'rows', v_rows);
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Phiếu chấm một em
-- ---------------------------------------------------------------------------
-- app.lms_grading_sheet(p_assignment_id uuid, p_student_id uuid) -> jsonb
-- Ai được gọi: như lms_grading_list. Kết quả: bài, em, bài nộp (số lần nộp, giờ nộp, nhãn muộn, các trang), điểm hiện có (kèm version),
--   các trạng thái được chọn (allowed_statuses) và trạng thái gợi ý (default_status).
-- Luật R-LMS-02: em chưa nộp (em có mặt) chỉ chọn Nộp sau hoặc Không làm; R-GV-11, Q6: em vắng buổi giao mà chưa nộp mặc định Không áp dụng,
--   đổi được sang Nộp sau hoặc Không làm. Em đã nộp: đủ năm trạng thái.
create or replace function app.lms_grading_sheet(p_assignment_id uuid, p_student_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  a app.lms_assignment;
  st app.student;
  m app.lms_submission;
  hr app.homework_result;
  v_absent boolean;
  v_allowed text[];
  v_default text;
begin
  a := app.lms_assert_assignment(p_assignment_id, 'XEM');
  select * into st from app.student where id = p_student_id;
  if st.id is null or not exists (select from app.lms_assignment_target t where t.assignment_id = a.id and t.student_id = st.id) then
    perform app.raise_error('HMT_LMS_EM_KHONG_NHAN_BAI', 'Em này không nhận bài giao này.');
  end if;
  select * into m from app.lms_submission where assignment_id = a.id and student_id = st.id;
  select * into hr from app.homework_result where session_id = a.session_id and student_id = st.id;
  v_absent := app.lms_student_absent(a.session_id, st.id);
  if m.submitted_at is not null then
    v_allowed := array['DA_CHAM', 'LAM_CHUA_XONG', 'KHONG_LAM', 'NOP_SAU', 'KHONG_AP_DUNG'];
    v_default := null;
  elsif v_absent then
    v_allowed := array['KHONG_AP_DUNG', 'NOP_SAU', 'KHONG_LAM'];
    v_default := 'KHONG_AP_DUNG';
  else
    v_allowed := array['NOP_SAU', 'KHONG_LAM'];
    v_default := null;
  end if;
  return jsonb_build_object(
    'assignment', jsonb_build_object('id', a.id, 'title', a.title, 'description', a.description, 'due_at', a.due_at, 'status', a.status),
    'student', jsonb_build_object('id', st.id, 'code', st.code, 'full_name', st.full_name, 'absent_at_session', v_absent),
    'submission', case when m.id is null then null else jsonb_build_object(
      'attempt_count', m.attempt_count, 'submitted_at', m.submitted_at, 'is_late', m.is_late, 'graded_at', m.graded_at,
      'pages', coalesce((select jsonb_agg(jsonb_build_object('page_no', f.page_no, 'storage_key', f.storage_key, 'mime_type', f.mime_type,
                                                              'byte_size', f.byte_size) order by f.page_no)
                           from app.lms_submission_file f where f.submission_id = m.id), '[]'::jsonb)) end,
    'grade', case when hr.id is null then null else jsonb_build_object(
      'status_code', hr.status_code, 'score', hr.score, 'note', hr.note, 'version', hr.version) end,
    'allowed_statuses', to_jsonb(v_allowed),
    'default_status', v_default);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Lưu điểm và trạng thái
-- ---------------------------------------------------------------------------
-- app.lms_save_grade(p_assignment_id uuid, p_student_id uuid, p_status text, p_score integer, p_note text, p_version integer) -> jsonb {version}
-- Ai được gọi: giáo viên hoặc trợ giảng của buổi giao (ATTENDANCE Sửa), phân hệ HOC_TAP bật.
-- Luật: R-GV-11 (điểm 1–5 chỉ với Đã chấm, Làm chưa xong; các trạng thái khác không điểm: chọn Không làm, Nộp sau, Không áp dụng thì bỏ điểm đã chọn, Q5);
--   R-LMS-02 (em chưa nộp: Nộp sau hoặc Không làm; em vắng buổi giao chưa nộp: thêm Không áp dụng, Q6); R-LMS-03 (chấm xong đóng dấu «đã chấm» và khoá
--   bài nộp, trừ khi mở lại; «Nộp sau» chưa phải chấm xong); Q-243 (p_version = số phiên bản dòng BTVN lúc mở màn, lệch thì HMT_XUNG_DOT).
-- Ghi vào app.homework_result của buổi giao (không tạo bảng điểm thứ hai, Q1); tạo dòng bài nộp rỗng nếu em chưa nộp.
create or replace function app.lms_save_grade(
  p_assignment_id uuid, p_student_id uuid, p_status text, p_score integer, p_note text default null, p_version integer default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  a app.lms_assignment;
  m app.lms_submission;
  v_score integer := p_score;
  v_current integer;
  v_submitted boolean;
  v_absent boolean;
  v_new integer;
begin
  a := app.lms_assert_assignment(p_assignment_id, 'SUA');
  if a.status = 'DA_GO' then
    perform app.raise_error('HMT_LMS_DA_GO', 'Bài này đã gỡ, không chấm được.');
  end if;
  if not exists (select from app.lms_assignment_target t where t.assignment_id = a.id and t.student_id = p_student_id) then
    perform app.raise_error('HMT_LMS_EM_KHONG_NHAN_BAI', 'Em này không nhận bài giao này.');
  end if;
  -- Luật R-GV-11: trạng thái hợp lệ, điểm 1–5 đúng trạng thái.
  perform app.assert_homework_entry(p_status, p_score);
  -- Luật Q5: trạng thái không có điểm thì bỏ điểm đã chọn.
  if p_status not in ('DA_CHAM', 'LAM_CHUA_XONG') then
    v_score := null;
  end if;
  select * into m from app.lms_submission where assignment_id = a.id and student_id = p_student_id for update;
  v_submitted := m.submitted_at is not null;
  v_absent := app.lms_student_absent(a.session_id, p_student_id);
  -- Luật R-LMS-02, Q6: em chưa nộp thì không có gì để chấm điểm.
  if not v_submitted and p_status in ('DA_CHAM', 'LAM_CHUA_XONG') then
    perform app.raise_error('HMT_LMS_CHUA_NOP_BAI', 'Em chưa nộp bài: chỉ chọn được Nộp sau hoặc Không làm.');
  end if;
  if not v_submitted and p_status = 'KHONG_AP_DUNG' and not v_absent then
    perform app.raise_error('HMT_LMS_CHUA_NOP_BAI', 'Em có mặt buổi giao bài mà chưa nộp: chỉ chọn được Nộp sau hoặc Không làm.');
  end if;
  -- Luật Q-243: dòng BTVN đã bị người khác sửa kể từ lúc mở màn thì từ chối, không ghi đè lặng lẽ.
  select version into v_current from app.homework_result where session_id = a.session_id and student_id = p_student_id for update;
  if p_version is not null and p_version is distinct from coalesce(v_current, 0) then
    perform app.raise_error('HMT_XUNG_DOT', 'Em này vừa được người khác chấm, tải lại để xem.');
  end if;
  insert into app.homework_result (session_id, branch_id, student_id, status_code, score, note)
  values (a.session_id, a.branch_id, p_student_id, p_status, v_score, nullif(btrim(p_note), ''))
  on conflict (session_id, student_id) do update
    set status_code = excluded.status_code, score = excluded.score, note = excluded.note, version = app.homework_result.version + 1
  returning version into v_new;
  -- Luật R-LMS-03: chấm xong thì đóng dấu (khoá bài nộp); «Nộp sau» còn chờ nên chưa đóng dấu.
  insert into app.lms_submission (assignment_id, student_id, graded_at)
  values (a.id, p_student_id, case when p_status = 'NOP_SAU' then null else now() end)
  on conflict (assignment_id, student_id) do update
    set graded_at = case when p_status = 'NOP_SAU' then null else now() end, version = app.lms_submission.version + 1;
  return jsonb_build_object('version', v_new);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Mở lại bài đã chấm
-- ---------------------------------------------------------------------------
-- app.lms_reopen_submission(p_assignment_id uuid, p_student_id uuid) -> jsonb {id}
-- Ai được gọi: giáo viên hoặc trợ giảng của buổi giao (ATTENDANCE Sửa; Q14 theo ma trận sẵn có), phân hệ HOC_TAP bật. Giao diện có hộp xác nhận (Q12).
-- Luật R-LMS-03: bài đã chấm thì khoá; mở lại để em nộp lại được. Gỡ dấu «đã chấm», ghi giờ mở lại; điểm cũ giữ đến khi chấm lại.
create or replace function app.lms_reopen_submission(p_assignment_id uuid, p_student_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  a app.lms_assignment;
  m app.lms_submission;
begin
  a := app.lms_assert_assignment(p_assignment_id, 'SUA');
  if a.status = 'DA_GO' then
    perform app.raise_error('HMT_LMS_DA_GO', 'Bài này đã gỡ, không mở lại được.');
  end if;
  select * into m from app.lms_submission where assignment_id = a.id and student_id = p_student_id for update;
  if m.id is null or m.graded_at is null then
    perform app.raise_error('HMT_LMS_CHUA_CHAM', 'Bài này chưa chấm nên không cần mở lại.');
  end if;
  update app.lms_submission set graded_at = null, reopened_at = now(), version = version + 1 where id = m.id;
  return jsonb_build_object('id', m.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Quyền gọi hàm
-- ---------------------------------------------------------------------------
revoke execute on function app.lms_grading_list(uuid, text), app.lms_grading_sheet(uuid, uuid),
  app.lms_save_grade(uuid, uuid, text, integer, text, integer), app.lms_reopen_submission(uuid, uuid) from public, anon, authenticated;
grant execute on function app.lms_grading_list(uuid, text), app.lms_grading_sheet(uuid, uuid),
  app.lms_save_grade(uuid, uuid, text, integer, text, integer), app.lms_reopen_submission(uuid, uuid) to authenticated;
