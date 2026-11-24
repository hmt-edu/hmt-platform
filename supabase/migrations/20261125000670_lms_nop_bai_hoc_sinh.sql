-- F-24-05 PR-1 (CAO): hàm nộp bài của học sinh (HT-04/HT-05). Chốt lần nộp: gắn các ảnh/tệp đã tải (stored_file, mig 664, 665) vào bài nộp.
-- Trước đây chỉ có app.file_authorize_upload tạo bài nộp NHÁP; chưa có hàm đặt submitted_at. Luật áp dụng: docs/spec/04 R-LMS-02 (nộp muộn là NHÃN, tắt
-- «Nhận bài muộn» thì quá hạn không nộp được), R-LMS-03 (nộp lại không giới hạn số lần trước khi chấm; chấm rồi thì khoá, trừ khi giáo viên mở lại),
-- R-LMS-04 (tối đa 20 trang mỗi bài), công tắc HOC_TAP, chỉ chính học sinh nộp (phụ huynh và nhân viên không nộp thay).
select set_config('hmt.migration', 'on', false);

-- 0. app.lms_submission_file nay trỏ tới dòng sổ tệp và nhớ LẦN NỘP: nộp lại tạo bộ trang mới (không xoá cứng bộ cũ; huỷ là đổi trạng thái).
--    Ràng buộc cũ «một trang một số cho cả bài» đổi thành «một trang một số trong mỗi lần nộp». Giới hạn cỡ tệp nay đọc từ tham số file_max_mb
--    (anh chốt 24/11: 20 MB mỗi tệp; vênh R-LMS-04 cũ 10 MB, cần cập nhật spec khi anh duyệt) nên bỏ chặn cứng 10 MB ở cột.
alter table app.lms_submission_file add column stored_file_id uuid references app.stored_file (id);
alter table app.lms_submission_file add column attempt integer not null default 1 check (attempt >= 1);
alter table app.lms_submission_file drop constraint lms_submission_file_submission_id_page_no_key;
alter table app.lms_submission_file add constraint lms_submission_file_attempt_page_key unique (submission_id, attempt, page_no);
alter table app.lms_submission_file drop constraint if exists lms_submission_file_byte_size_check;
alter table app.lms_submission_file add constraint lms_submission_file_byte_size_check check (byte_size >= 1);
-- Chỉ mục (lý do): khoá ngoại sang sổ tệp (tra trang theo tệp, và dọn tệp); unique mới (bài nộp, lần nộp, trang) đã phục vụ tra trang của lần nộp.
create index lms_submission_file_stored_idx on app.lms_submission_file (stored_file_id) where stored_file_id is not null;

-- 1. app.lms_submit_assignment(bài giao, danh sách tệp theo thứ tự trang) -> {submission_id, attempt, is_late, submitted_at}.
-- Ai gọi: học sinh đăng nhập, bài được giao cho chính em. Các tệp phải là ảnh/PDF của CHÍNH em cho bài này, đã tải xong (DANG_DUNG), thuộc bài nộp nháp của em.
-- Lỗi: HMT_KHONG_CO_QUYEN, HMT_TINH_NANG_TAT, HMT_LMS_BAI_DA_GO, HMT_LMS_QUA_HAN, HMT_LMS_KHONG_NOP_LAI, HMT_LMS_DA_CHAM, HMT_TEP_THIEU, HMT_TEP_QUA_NHIEU, HMT_TEP_KHONG_HOP_LE.
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
  -- Luật số trang (R-LMS-04 và tham số): ít nhất một tệp, không quá 20 trang, không trùng tệp trong danh sách.
  if v_count = 0 then
    perform app.raise_error('HMT_TEP_THIEU', 'Chưa có ảnh nào để nộp.');
  end if;
  if v_count > 20 then -- allow-number: R-LMS-04, tối đa 20 trang mỗi bài
    perform app.raise_error('HMT_TEP_QUA_NHIEU', 'Mỗi bài nộp tối đa 20 trang.');
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
comment on function app.lms_submit_assignment(uuid, uuid[]) is 'Học sinh chốt lần nộp bài: gắn các ảnh đã tải (đúng thứ tự trang) vào bài nộp; R-LMS-02, R-LMS-03, R-LMS-04.';
revoke execute on function app.lms_submit_assignment(uuid, uuid[]) from public, anon;
grant execute on function app.lms_submit_assignment(uuid, uuid[]) to authenticated;
