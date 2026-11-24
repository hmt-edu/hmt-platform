-- F-23-46 (a): bảng sổ tệp `stored_file` cho kho tệp Cloudflare R2 (ảnh/tệp bài nộp HT-04, tệp đính kèm giáo viên GV-18/CHUNG-21) + RLS + chỉ mục + tham số cài đặt.
-- Thiết kế đã duyệt: docs/ke-hoach/luu-tru-tep-r2.md (#691). Chỉ lưu KHOÁ tệp trên R2 và cờ, không lưu nội dung (không dùng Supabase Storage).
-- Chưa có hàm ghi: Edge Function (file-upload-url, file-upload-done, file-view-url, việc dọn) ghi bằng khoá dịch vụ ở PR sau; giao diện chỉ ĐỌC qua RLS.
-- Vênh spec: R-LMS-04 ghi 10 MB mỗi tệp, 20 trang; anh chốt 24/11 giới hạn mới 20 MB mỗi tệp, 10 tệp mỗi lần, 50 MB tổng. Giới hạn nằm ở tham số (không viết cứng);
-- bảng lms_submission_file (597) giữ nguyên, PR sau (HT-04) quyết nối sang stored_file.
select set_config('hmt.migration', 'on', false);

create table app.stored_file (
  id uuid primary key default gen_random_uuid(),
  r2_key text not null unique, -- khoá tệp trong bucket: môi trường/cơ sở/lớp/năm-tháng/uuid (không chứa tên hay số điện thoại)
  thumb_r2_key text, -- ảnh thu nhỏ 20-30 KB (rỗng với PDF)
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'), -- chặn nộp trùng
  kind text not null check (kind in ('BAI_NOP', 'DINH_KEM_GV')),
  branch_id uuid not null references app.branch (id),
  class_id uuid not null references app.class (id),
  assignment_id uuid not null references app.lms_assignment (id),
  submission_id uuid references app.lms_submission (id), -- chỉ có với BAI_NOP
  student_id uuid references app.student (id), -- chủ ảnh (học sinh); rỗng với tệp giáo viên đính kèm
  owner_user_id uuid, -- người tải lên
  mime_type text not null check (mime_type in ('image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf')),
  size_bytes bigint not null check (size_bytes > 0),
  is_color boolean not null default false, -- ảnh giáo viên đính kèm giữ màu, ảnh học sinh thang xám (anh OK 24/11)
  delete_after date not null, -- chụp lúc tạo từ file_retention_days (luật cấu hình có hiệu lực: không tính lại)
  status text not null default 'CHO_TAI' check (status in ('CHO_TAI', 'DANG_DUNG', 'DA_XOA')),
  cleaned_at timestamptz, -- lúc việc dọn xoá khỏi R2
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check ((kind = 'BAI_NOP') = (student_id is not null)),
  check (kind = 'BAI_NOP' or submission_id is null)
);
comment on table app.stored_file is 'Sổ tệp trên Cloudflare R2 (khoá tệp + cờ). Chỉ Edge Function ghi (khoá dịch vụ); đọc theo quyền xem bài giao.';

-- Chỉ mục (lý do): lớp + thời điểm cho danh sách theo lớp; bài giao và bài nộp cho khoá ngoại và màn chấm; học sinh cho việc dọn theo hạng;
-- (bài, học sinh, mã băm) duy nhất khi còn dùng: chặn nộp trùng; delete_after cho việc dọn hằng đêm; CHO_TAI cho dọn tệp tải dở.
create index stored_file_class_created_idx on app.stored_file (class_id, created_at);
create index stored_file_assignment_idx on app.stored_file (assignment_id);
create index stored_file_submission_idx on app.stored_file (submission_id) where submission_id is not null;
create index stored_file_student_idx on app.stored_file (student_id) where student_id is not null;
create index stored_file_branch_idx on app.stored_file (branch_id);
create unique index stored_file_dedup_uq on app.stored_file (assignment_id, student_id, sha256) where kind = 'BAI_NOP' and status <> 'DA_XOA';
create index stored_file_due_idx on app.stored_file (delete_after) where status = 'DANG_DUNG';
create index stored_file_pending_idx on app.stored_file (created_at) where status = 'CHO_TAI';
select app.apply_standard('app.stored_file');

-- RLS: đọc theo quyền xem bài giao (cùng luật bảng LMS, 597). Học sinh và phụ huynh KHÔNG đọc trực tiếp: cổng đi qua Edge Function file-view-url
-- (kiểm chính em / phụ huynh của em). Không cấp ghi cho ai: chỉ Edge Function bằng khoá dịch vụ.
alter table app.stored_file enable row level security;
grant select on app.stored_file to authenticated;
create policy stored_file_read on app.stored_file for select to authenticated
  using ((select app.lms_assignment_visible(assignment_id)));

-- Tham số cài đặt (anh duyệt 23/11 và 24/11): hạn giữ, dọn, giới hạn tệp, chặn mềm dung lượng. Chỉ Admin đổi.
insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description) values
  ('file_retention_days', 'Hạn giữ ảnh bài làm (học sinh đang học)', 'INT', 'ngày', 30, 365, '90', false, 'HOC_TAP', 'F-23-46',
   'Quá hạn này, ảnh của học sinh đang học vào hạng 3 (xuất Drive rồi xoá). Rút còn 60 nếu ảnh nén ra lớn hơn 150 KB. Chụp vào delete_after lúc tải lên.'),
  ('file_retention_after_leave_days', 'Số ngày giữ ảnh sau khi học sinh Dừng học', 'INT', 'ngày', 7, 180, '30', false, 'HOC_TAP', 'F-23-46',
   'Học sinh đã Dừng học quá số ngày này: ảnh vào hạng 1 (xoá, không xuất Drive). Quay lại trong hạn thì thoát hạng 1.'),
  ('file_cleanup_dry_run', 'Việc dọn tệp chỉ chạy thử', 'BOOL', null, null, null, 'true', false, 'HOC_TAP', 'F-23-46',
   'Bật: việc dọn hằng đêm chỉ liệt kê, chưa xoá. Admin tắt khi đã kiểm danh sách.'),
  ('file_max_bytes', 'Dung lượng tối đa mỗi tệp', 'INT', 'MB', 1, 50, '20', false, 'HOC_TAP', 'F-23-46', 'Anh chốt 24/11: 20 MB mỗi tệp (thay 10 MB của R-LMS-04).'),
  ('file_max_count_per_upload', 'Số tệp tối đa mỗi lần nộp', 'INT', 'tệp', 1, 30, '10', false, 'HOC_TAP', 'F-23-46', 'Anh chốt 24/11: 10 tệp mỗi lần.'),
  ('file_max_total_mb_per_upload', 'Tổng dung lượng tối đa mỗi lần nộp', 'INT', 'MB', 1, 200, '50', false, 'HOC_TAP', 'F-23-46', 'Anh chốt 24/11: 50 MB tổng mỗi lần.'),
  ('file_storage_soft_limit_percent', 'Chặn mềm dung lượng kho tệp', 'INT', '%', 50, 100, '80', false, 'HOC_TAP', 'F-23-46',
   'Tổng dung lượng chạm mức này (so với hạn mức miễn phí R2) thì chặn tải mới và báo Admin, để không tự phát sinh tiền.'),
  ('file_storage_free_gb', 'Hạn mức miễn phí của kho tệp', 'INT', 'GB', 1, 1000, '10', false, 'HOC_TAP', 'F-23-46', 'Cloudflare R2 gói Free: 10 GB mỗi tháng (spec 01).')
on conflict (key) do nothing;
