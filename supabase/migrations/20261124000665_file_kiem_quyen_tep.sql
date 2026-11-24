-- F-23-49: hàm DB kiểm quyền cho Edge Function lưu tệp (thiết kế docs/ke-hoach/luu-tru-tep-drive.md mục 2, 3). Chồng trên migration 664 (stored_file).
-- Edge Function gọi các hàm này BẰNG TOKEN CỦA NGƯỜI GỌI; hàm tự kiểm quyền và trả mọi thứ Edge Function cần để ghi dòng stored_file bằng khoá dịch vụ.
-- Luật: học sinh nộp bài của CHÍNH MÌNH (phụ huynh xem, không nộp thay); giáo viên có quyền Sửa buổi giao đính kèm tệp đề; xem theo quyền xem bài giao
-- hoặc học sinh/phụ huynh của em; công tắc HOC_TAP kiểm trong hàm; R-LMS-02/03 (hạn nộp, nộp lại). Không viết số: giới hạn đọc từ tham số cài đặt.
select set_config('hmt.migration', 'on', false);

-- 0. app.file_setting_int(khoá, cơ sở): đọc tham số file_* cho hàm kiểm quyền tệp.
-- Vì sao cần: app.get_setting chặn phiên học sinh đọc tham số (migration 467), mà học sinh phải biết giới hạn tệp và hạn giữ lúc nộp bài.
-- Chỉ cho khoá bắt đầu bằng file_ (không mở rộng quyền đọc cấu hình khác); không cấp cho giao diện, chỉ hàm trong file này gọi.
create or replace function app.file_setting_int(p_key text, p_branch_id uuid)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_value text;
begin
  if p_key not like 'file\_%' then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền đọc tham số này.');
  end if;
  select sb.value into v_value from app.setting_branch sb where sb.setting_key = p_key and sb.branch_id = p_branch_id and sb.is_active;
  if v_value is null then
    select value into v_value from app.setting_def where key = p_key;
  end if;
  return v_value::integer;
end;
$$;
revoke execute on function app.file_setting_int(text, uuid) from public, anon, authenticated;

-- 1. app.file_authorize_upload(kind, bài giao, học sinh): kiểm quyền tải lên.
-- Ai gọi: học sinh (kind BAI_NOP, p_student_id là chính mình) hoặc giáo viên/trợ giảng của buổi giao (kind DINH_KEM_GV, không có p_student_id).
-- Kết quả: {branch_id, class_id, assignment_id, submission_id (BAI_NOP), student_id, kind, is_color, delete_after, limits {max_bytes, max_count, max_total_bytes}}.
-- BAI_NOP tạo (hoặc lấy) bài nộp NHÁP của em cho bài giao (chưa có submitted_at); việc chốt lần nộp là hàm nộp bài (HT-05), không ở đây.
-- Lỗi: HMT_KHONG_CO_QUYEN, HMT_TINH_NANG_TAT, HMT_LMS_BAI_DA_GO, HMT_LMS_QUA_HAN, HMT_LMS_KHONG_NOP_LAI, HMT_TEP_LOAI_SAI.
create or replace function app.file_authorize_upload(p_kind text, p_assignment_id uuid, p_student_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  a app.lms_assignment;
  v_student app.student;
  v_sub app.lms_submission;
begin
  if p_kind not in ('BAI_NOP', 'DINH_KEM_GV') then
    perform app.raise_error('HMT_TEP_LOAI_SAI', 'Loại tệp không đúng.');
  end if;

  if p_kind = 'DINH_KEM_GV' then
    -- Luật Q14: quyền sẵn có của buổi giao (giáo viên hoặc trợ giảng, vận hành theo cơ sở); kèm công tắc HOC_TAP.
    a := app.lms_assert_assignment(p_assignment_id, 'SUA');
  else
    -- Luật quyền riêng: chỉ chính học sinh nộp bài; phụ huynh và nhân viên bị chặn, báo chung một lỗi.
    select s.* into v_student from app.student s
     where s.id = p_student_id
       and exists (select from app.user_account u where u.id = (select auth.uid()) and u.student_code = s.code and (select app.current_user_ready()));
    if v_student.id is null then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền nộp bài này.');
    end if;
    perform app.require_feature('HOC_TAP', v_student.branch_id);
    select * into a from app.lms_assignment where id = p_assignment_id;
    -- Luật: bài phải được giao cho em này (không tiết lộ bài của em khác: cùng một lỗi).
    if a.id is null or not exists (select from app.lms_assignment_target t where t.assignment_id = a.id and t.student_id = v_student.id) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền nộp bài này.');
    end if;
    if a.status <> 'DANG_GIAO' then
      perform app.raise_error('HMT_LMS_BAI_DA_GO', 'Bài này đã được gỡ.');
    end if;
    -- Luật R-LMS-02: quá hạn chỉ nộp được khi bài cho phép nhận bài muộn.
    if now() > a.due_at and not a.allow_late then
      perform app.raise_error('HMT_LMS_QUA_HAN', 'Đã quá hạn nộp bài này.');
    end if;
    insert into app.lms_submission (assignment_id, student_id) values (a.id, v_student.id) on conflict (assignment_id, student_id) do nothing;
    select * into v_sub from app.lms_submission where assignment_id = a.id and student_id = v_student.id;
    -- Luật R-LMS-03: đã nộp mà bài không cho nộp lại thì chặn.
    if v_sub.submitted_at is not null and not a.allow_resubmit then
      perform app.raise_error('HMT_LMS_KHONG_NOP_LAI', 'Bài này không cho nộp lại.');
    end if;
  end if;

  return jsonb_build_object(
    'branch_id', a.branch_id, 'class_id', a.class_id, 'assignment_id', a.id, 'kind', p_kind,
    'submission_id', v_sub.id, 'student_id', v_student.id,
    -- Ảnh học sinh thang xám, ảnh giáo viên giữ màu (anh OK 24/11).
    'is_color', p_kind = 'DINH_KEM_GV',
    -- Chụp hạn giữ lúc tải lên (cấu hình có hiệu lực: không tính lại sau này).
    'delete_after', ((now() at time zone 'Asia/Ho_Chi_Minh')::date + app.file_setting_int('file_retention_days', a.branch_id)::integer),
    'limits', jsonb_build_object(
      'max_bytes', app.file_setting_int('file_max_bytes', a.branch_id)::bigint * 1048576, -- allow-number: MB sang byte
      'max_count', app.file_setting_int('file_max_count_per_upload', a.branch_id)::integer,
      'max_total_bytes', app.file_setting_int('file_max_total_mb_per_upload', a.branch_id)::bigint * 1048576)); -- allow-number: MB sang byte
end;
$$;
comment on function app.file_authorize_upload(text, uuid, uuid) is 'Kiểm quyền tải tệp lên (học sinh nộp bài của mình, giáo viên đính kèm); trả thông tin để Edge Function ghi stored_file.';

-- 2. app.file_authorize_view(id tệp): kiểm quyền xem một tệp.
-- Ai gọi: nhân viên có quyền xem bài giao (giáo viên lớp, quản lý cơ sở theo phạm vi); học sinh chủ ảnh; phụ huynh của em; với tệp giáo viên đính kèm: em được giao bài và phụ huynh của em.
-- Kết quả: {storage_key, thumb_storage_key, mime_type, size_bytes}. Tệp đã dọn: HMT_TEP_DA_DON («Ảnh đã được dọn theo quy định lưu trữ»); tệp chưa tải xong: không tìm thấy.
create or replace function app.file_authorize_view(p_file_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  f app.stored_file;
  v_ok boolean;
begin
  select * into f from app.stored_file where id = p_file_id;
  -- Không có tệp và không có quyền cùng một lỗi (không lộ tệp tồn tại hay không).
  if f.id is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem tệp này.');
  end if;
  -- Nhân viên: theo quyền xem bài giao (cùng luật RLS bảng LMS).
  v_ok := app.lms_assignment_visible(f.assignment_id);
  if not v_ok then
    -- Học sinh, phụ huynh: ảnh của em mình (BAI_NOP), hoặc tệp đề của bài giao cho em mình (DINH_KEM_GV); cơ sở phải bật Học tập.
    v_ok := exists (
      select from app.student s
       where s.id in (select app.portal_student_ids())
         and app.feature_enabled('HOC_TAP', s.branch_id)
         and ((f.kind = 'BAI_NOP' and s.id = f.student_id)
           or (f.kind = 'DINH_KEM_GV' and exists (select from app.lms_assignment_target t where t.assignment_id = f.assignment_id and t.student_id = s.id))));
  end if;
  if not v_ok then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem tệp này.');
  end if;
  if f.status = 'DA_XOA' then
    perform app.raise_error('HMT_TEP_DA_DON', 'Ảnh đã được dọn theo quy định lưu trữ.');
  end if;
  if f.status <> 'DANG_DUNG' then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Tệp chưa tải xong.');
  end if;
  return jsonb_build_object('storage_key', f.storage_key, 'thumb_storage_key', f.thumb_storage_key, 'mime_type', f.mime_type, 'size_bytes', f.size_bytes);
end;
$$;
comment on function app.file_authorize_view(uuid) is 'Kiểm quyền xem một tệp; trả khoá tệp ở nơi lưu cho Edge Function file-view làm trung gian.';

revoke execute on function app.file_authorize_upload(text, uuid, uuid), app.file_authorize_view(uuid) from public, anon;
grant execute on function app.file_authorize_upload(text, uuid, uuid), app.file_authorize_view(uuid) to authenticated;
