-- F-24-06 (4) (CAO): số trang tối đa mỗi bài nộp thành THAM SỐ, thay số 20 viết cứng trong app.lms_submit_assignment (mig 670; ra-soat 02:17, CLAUDE.md mục Cấu hình 2).
-- Luật R-LMS-04 (docs/spec/04): tối đa 20 trang mỗi bài; mặc định giữ 20. Chỉ đổi số, không đổi luật nào khác của hàm.
select set_config('hmt.migration', 'on', false);

insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description) values
  ('file_max_pages_per_submission', 'Số trang tối đa mỗi bài nộp', 'INT', 'trang', 1, 50, '20', true, 'HOC_TAP', 'F-24-06',
   'R-LMS-04: tối đa 20 trang mỗi bài nộp của học sinh. Hàm lms_submit_assignment đọc tham số này; giao diện tải theo đợt rồi chốt một lần.');

create or replace function app.lms_submit_assignment(p_assignment_id uuid, p_file_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student app.student;
  a app.lms_assignment;
  v_sub app.lms_submission;
  v_count integer := coalesce(cardinality(p_file_ids), 0);
  v_max_pages integer;
  v_attempt integer;
  v_late boolean;
begin
  -- Luật quyền riêng: chỉ chính học sinh; mọi lý do không phải em này báo chung một lỗi (không lộ bài của em khác).
  select s.* into v_student from app.student s
   where exists (select from app.user_account u where u.id = (select auth.uid()) and u.student_code = s.code and (select app.current_user_ready()));
  if v_student.id is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền nộp bài này.');
  end if;
  perform app.require_feature('HOC_TAP', v_student.branch_id);
  select * into a from app.lms_assignment where id = p_assignment_id;
  if a.id is null or not exists (select from app.lms_assignment_target t where t.assignment_id = a.id and t.student_id = v_student.id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền nộp bài này.');
  end if;
  if a.status <> 'DANG_GIAO' then
    perform app.raise_error('HMT_LMS_BAI_DA_GO', 'Bài này đã được gỡ.');
  end if;
  -- Luật R-LMS-02: quá hạn chỉ nộp được khi bài nhận bài muộn; nộp muộn chỉ là nhãn.
  v_late := now() > a.due_at;
  if v_late and not a.allow_late then
    perform app.raise_error('HMT_LMS_QUA_HAN', 'Đã quá hạn nộp bài này.');
  end if;
  -- Luật số trang (R-LMS-04 và tham số): ít nhất một tệp, không quá số trang cho phép (tham số file_max_pages_per_submission), không trùng tệp trong danh sách.
  if v_count = 0 then
    perform app.raise_error('HMT_TEP_THIEU', 'Chưa có ảnh nào để nộp.');
  end if;
  v_max_pages := app.file_setting_int('file_max_pages_per_submission', v_student.branch_id);
  if v_count > v_max_pages then
    perform app.raise_error('HMT_TEP_QUA_NHIEU', format('Mỗi bài nộp tối đa %s trang.', v_max_pages));
  end if;
  if (select count(distinct x) from unnest(p_file_ids) as x) <> v_count then
    perform app.raise_error('HMT_TEP_KHONG_HOP_LE', 'Danh sách ảnh có ảnh bị lặp.');
  end if;
  -- Khoá dòng bài nộp: hai lần bấm Nộp cùng lúc không nhân đôi lần nộp.
  select * into v_sub from app.lms_submission where assignment_id = a.id and student_id = v_student.id for update;
  if v_sub.id is null then
    perform app.raise_error('HMT_TEP_KHONG_HOP_LE', 'Chưa tải ảnh nào lên cho bài này.');
  end if;
  -- Luật R-LMS-03: đã chấm thì khoá (giáo viên mở lại thì graded_at được gỡ); đã nộp mà bài không cho nộp lại thì chặn.
  if v_sub.graded_at is not null then
    perform app.raise_error('HMT_LMS_DA_CHAM', 'Bài này đã được chấm, không nộp lại được.');
  end if;
  if v_sub.submitted_at is not null and not a.allow_resubmit then
    perform app.raise_error('HMT_LMS_KHONG_NOP_LAI', 'Bài này không cho nộp lại.');
  end if;
  -- Luật tệp hợp lệ: đủ mọi tệp trong danh sách là tệp bài nộp (BAI_NOP) của chính em, của bài nộp này, đã tải xong.
  if (select count(*) from app.stored_file f
       where f.id = any (p_file_ids) and f.kind = 'BAI_NOP' and f.status = 'DANG_DUNG'
         and f.submission_id = v_sub.id and f.student_id = v_student.id and f.assignment_id = a.id) <> v_count then
    perform app.raise_error('HMT_TEP_KHONG_HOP_LE', 'Có ảnh chưa tải xong hoặc không thuộc bài nộp này.');
  end if;

  v_attempt := v_sub.attempt_count + 1;
  update app.lms_submission
     set attempt_count = v_attempt, submitted_at = now(), is_late = v_late, version = version + 1
   where id = v_sub.id returning * into v_sub;
  -- Chụp bộ trang của lần nộp này theo thứ tự danh sách (số trang = vị trí); bộ của các lần trước giữ nguyên.
  insert into app.lms_submission_file (submission_id, attempt, page_no, storage_key, byte_size, mime_type, stored_file_id)
  select v_sub.id, v_attempt, p.ord, f.storage_key, f.size_bytes, f.mime_type, f.id
    from unnest(p_file_ids) with ordinality as p (id, ord) join app.stored_file f on f.id = p.id;
  return jsonb_build_object('submission_id', v_sub.id, 'attempt', v_attempt, 'is_late', v_sub.is_late, 'submitted_at', v_sub.submitted_at);
end;
$$;
comment on function app.lms_submit_assignment(uuid, uuid[]) is 'Học sinh chốt lần nộp bài: gắn các ảnh đã tải (đúng thứ tự trang) vào bài nộp; R-LMS-02, R-LMS-03, R-LMS-04 (số trang đọc từ file_max_pages_per_submission).';

-- app.file_upload_limits() -> {max_mb, max_count, max_total_mb, max_pages}: giới hạn tệp cho màn Nộp bài (HT-04).
-- Ai gọi: mọi người đã đăng nhập. Học sinh không đọc được tham số bằng get_setting (chỉ vài khoá cho phép, mig 467), nên màn nộp bài lấy giới hạn qua hàm này.
-- Chỉ trả 4 số giới hạn tệp, không lộ tham số khác. Máy chủ vẫn kiểm lại mọi giới hạn lúc tải lên và lúc chốt.
create or replace function app.file_upload_limits()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn chưa đăng nhập.');
  end if;
  return jsonb_build_object(
    'max_mb', app.file_setting_int('file_max_mb', null),
    'max_count', app.file_setting_int('file_max_count_per_upload', null),
    'max_total_mb', app.file_setting_int('file_max_total_mb_per_upload', null),
    'max_pages', app.file_setting_int('file_max_pages_per_submission', null));
end;
$$;
comment on function app.file_upload_limits() is 'Giới hạn tệp khi nộp bài (số tệp, MB mỗi tệp, tổng MB, số trang) cho giao diện; R-LMS-04.';
revoke execute on function app.file_upload_limits() from public, anon;
grant execute on function app.file_upload_limits() to authenticated;
