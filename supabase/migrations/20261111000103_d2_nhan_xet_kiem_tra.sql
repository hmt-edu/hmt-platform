-- D2 (Code 2, 10/11/2026): nhận xét buổi học 9 tiêu chí, buổi Kiểm tra, dấu Đã xuất, mức gợi ý lời nhắn phụ huynh.
-- Luật: R-V2-18 (loại buổi, Q-176), R-V2-19 (9 tiêu chí), R-V2-20 (kiểm tra là một buổi học), R-V2-38 (dấu Đã xuất),
-- R-V2-39 (mức gợi ý, 24 mẫu câu), R-GV-02, 03, 04 (sửa theo R-V2-19), R-GV-08, R-GIO-06, R-V2-35 (BTVN tuỳ giáo viên).
-- Làm gì: thêm loại buổi KIEM_TRA (trừ giờ như buổi Chính); bảng tiêu chí và 9 tiêu chí nạp sẵn; tiêu chí của buổi; điểm từng em;
-- cấu hình và điểm buổi kiểm tra; nhận xét và dấu Đã xuất; ngưỡng mức gợi ý (Cài đặt); 24 mẫu câu; điều kiện Done thêm nhận xét/điểm.
-- Chưa có: BTVN (bài giao, tình trạng), màn cấu hình đánh giá, mô tả 5 mức của từng tiêu chí (chờ nội dung), bộ tiêu chí các môn ngoài Toán.
-- GỘP SAU #209 (nhánh xếp chồng trên D1). Chỉ mục: mỗi chỉ mục ghi lý do ngay bên dưới câu tạo.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- 1. Loại buổi Kiểm tra (R-V2-18, Q-176): trừ giờ như buổi Chính; form chấm riêng.
-- ---------------------------------------------------------------------------
insert into app.catalog_item (catalog_code, code, name, sort_order)
values ('SESSION_TYPE', 'KIEM_TRA', 'Kiểm tra', 5);

create or replace function app.session_type_deducts_hours(p_session_type text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
begin
  -- Luật: buổi chính, buổi củng cố trừ giờ; buổi kiểm tra trừ như buổi chính (R-V2-20, Q-176).
  if p_session_type in ('CHINH', 'CUNG_CO', 'KIEM_TRA') then
    return true;
  end if;
  -- Luật: học bù, học bổ trợ không trừ giờ.
  if p_session_type in ('HOC_BU', 'BO_TRO') then
    return false;
  end if;
  perform app.raise_error('HMT_LOAI_BUOI_SAI', format('Không có loại buổi "%s".', p_session_type));
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Tham số (R-V2-39, concept đánh giá): mức nút "Cả lớp", điểm tối đa mặc định, ngưỡng mức gợi ý.
-- ---------------------------------------------------------------------------
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('session_done_requires_review', 'Done buổi cần nhận xét hoặc điểm', 'BOOL', null, null, null, 'true', false, 'VAN_HANH_LOP', null,
   'Bật: buổi thường chỉ Done khi không còn ô nhận xét Chưa đánh giá, buổi Kiểm tra khi mọi em có mặt đã được chấm (R-V2-19, R-V2-20). Tắt: buổi Done khi đã điểm danh xong; giờ vẫn trừ (Q-198).'),
  ('review_all_class_level', 'Mức của nút "Cả lớp"', 'INT', 'mức', 1, 5, '3', false, 'CONG_GIAO_VIEN', null,
   'Nút "Cả lớp mức N" gán mức N cho mọi em có mặt ở tiêu chí đang chấm (nhận xét buổi).'),
  ('exam_default_max_score', 'Điểm tối đa mặc định của buổi kiểm tra', 'INT', 'điểm', 1, 100, '10', false, 'CONG_GIAO_VIEN', null,
   'Giá trị điền sẵn khi xếp lịch buổi kiểm tra; mỗi buổi chụp lại giá trị lúc đặt (R-V2-20).'),
  ('parent_hint_regular_level4', 'Mức gợi ý 4, buổi thường: điểm trung bình từ', 'NUMERIC', 'điểm', 1, 5, '4.5', false, 'CONG_GIAO_VIEN', null,
   'Điểm trung bình các tiêu chí đã đánh giá (thang 1 đến 5), so sánh trên điểm chưa làm tròn (R-V2-39).'),
  ('parent_hint_regular_level3', 'Mức gợi ý 3, buổi thường: điểm trung bình từ', 'NUMERIC', 'điểm', 1, 5, '3.5', false, 'CONG_GIAO_VIEN', null,
   'Dưới mức 4 và từ giá trị này trở lên là mức 3.'),
  ('parent_hint_regular_level2', 'Mức gợi ý 2, buổi thường: điểm trung bình từ', 'NUMERIC', 'điểm', 1, 5, '2.5', false, 'CONG_GIAO_VIEN', null,
   'Dưới mức 3 và từ giá trị này trở lên là mức 2; thấp hơn là mức 1.'),
  ('parent_hint_exam_level4', 'Mức gợi ý 4, buổi kiểm tra: điểm tổng từ (% tối đa)', 'NUMERIC', '%', 1, 100, '90', false, 'CONG_GIAO_VIEN', null,
   'Điểm tổng chia điểm tối đa, so sánh trên giá trị chưa làm tròn (R-V2-39).'),
  ('parent_hint_exam_level3', 'Mức gợi ý 3, buổi kiểm tra: điểm tổng từ (% tối đa)', 'NUMERIC', '%', 1, 100, '75', false, 'CONG_GIAO_VIEN', null,
   'Dưới mức 4 và từ giá trị này trở lên là mức 3.'),
  ('parent_hint_exam_level2', 'Mức gợi ý 2, buổi kiểm tra: điểm tổng từ (% tối đa)', 'NUMERIC', '%', 1, 100, '50', false, 'CONG_GIAO_VIEN', null,
   'Dưới mức 3 và từ giá trị này trở lên là mức 2; thấp hơn là mức 1.');

-- ---------------------------------------------------------------------------
-- 3. Bảng tiêu chí và mẫu câu (cấu hình; sửa qua màn cấu hình ở bước sau, chưa có hàm ghi)
-- ---------------------------------------------------------------------------
-- Nhóm môn dùng chung bộ tiêu chí (Q-189): Toán, Đại số, Hình học dùng bộ Toán; mọi môn khác dùng bộ môn phụ. Là dữ liệu, sửa được ở bước cấu hình sau.
create table app.review_subject_set (
  subject_catalog text not null default 'SUBJECT' check (subject_catalog = 'SUBJECT'),
  subject_code text primary key,
  subject_set text not null check (subject_set in ('TOAN', 'MON_PHU')),
  id uuid not null unique default gen_random_uuid(),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (subject_catalog, subject_code) references app.catalog_item (catalog_code, code)
);
comment on table app.review_subject_set is 'Môn thuộc bộ tiêu chí nào: TOAN (Toán, Đại số, Hình học) hay MON_PHU (các môn còn lại), Q-189.';
select app.apply_standard('app.review_subject_set');

-- Tiêu chí nhận xét (R-V2-19, Q-189): nhóm Thái độ / Tiếp thu / Vận dụng; bộ MOI_MON = chung mọi môn, TOAN, MON_PHU.
-- Đã dùng thì chỉ Ngừng, không xoá.
create table app.review_criterion (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z0-9_]+$'),
  group_code text not null check (group_code in ('THAI_DO', 'TIEP_THU', 'VAN_DUNG')),
  subject_set text not null check (subject_set in ('MOI_MON', 'TOAN', 'MON_PHU')),
  name text not null check (btrim(name) <> ''),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.review_criterion is 'Tiêu chí nhận xét buổi học (R-V2-19, Q-189). Buổi chụp lại tên tiêu chí lúc mở nhận xét.';
-- Chỉ mục (lý do): tìm tiêu chí đang dùng theo bộ khi mở nhận xét của buổi.
create index review_criterion_set_idx on app.review_criterion (subject_set, group_code, sort_order) where is_active;
select app.apply_standard('app.review_criterion');

-- Mô tả 5 mức của từng tiêu chí (Q-190), hiện khi giáo viên giữ ngón trên nút điểm.
create table app.review_level_desc (
  id uuid primary key default gen_random_uuid(),
  criterion_id uuid not null references app.review_criterion (id),
  level smallint not null check (level between 1 and 5),
  description text not null check (btrim(description) <> ''),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (criterion_id, level)
);
comment on table app.review_level_desc is 'Mô tả biểu hiện của mức 1 đến 5 cho từng tiêu chí (Q-190). Sửa được ở bước cấu hình sau.';
select app.apply_standard('app.review_level_desc');

-- "Biểu hiện gợi ý" theo môn cho tiêu chí Tiếp thu và Vận dụng của bộ môn phụ (Q-189): chữ hiện dưới tiêu chí khi chấm, không phải tiêu chí riêng.
create table app.review_hint (
  id uuid primary key default gen_random_uuid(),
  criterion_id uuid not null references app.review_criterion (id),
  subject_catalog text not null default 'SUBJECT' check (subject_catalog = 'SUBJECT'),
  subject_code text not null,
  hint text not null check (btrim(hint) <> ''),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (criterion_id, subject_code),
  foreign key (subject_catalog, subject_code) references app.catalog_item (catalog_code, code)
);
comment on table app.review_hint is 'Biểu hiện gợi ý theo môn của một tiêu chí (Q-189). Dữ liệu, không phải tiêu chí.';
-- Chỉ mục (lý do): khoá ngoại môn để tra gợi ý của một môn.
create index review_hint_subject_idx on app.review_hint (subject_code);
select app.apply_standard('app.review_hint');

-- Mẫu câu lời nhắn phụ huynh (R-V2-39): 2 loại buổi × 4 mức × 3 câu. Admin sửa được (màn cấu hình ở bước sau).
create table app.parent_phrase (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('THUONG', 'KIEM_TRA')),
  level smallint not null check (level between 1 and 4),
  seq smallint not null check (seq between 1 and 3),
  phrase text not null check (btrim(phrase) <> ''),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (kind, level, seq)
);
comment on table app.parent_phrase is 'Mẫu câu gợi ý lời nhắn phụ huynh theo loại buổi và mức (R-V2-39). Cố định, không dùng AI.';
select app.apply_standard('app.parent_phrase');

-- ---------------------------------------------------------------------------
-- 4. Bảng của buổi: tiêu chí, điểm, nhận xét + Đã xuất, cấu hình và điểm kiểm tra
-- ---------------------------------------------------------------------------
-- Tiêu chí của buổi (chụp lại lúc mở). enabled = false: cả buổi Không áp dụng (công tắc tiêu chí).
create table app.session_review_criterion (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references app.class_session (id),
  branch_id uuid not null references app.branch (id),
  criterion_id uuid not null references app.review_criterion (id),
  group_code text not null,
  name text not null,
  sort_order integer not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (session_id, criterion_id)
);
comment on table app.session_review_criterion is 'Tiêu chí nhận xét của một buổi (chụp tên, nhóm lúc mở); enabled=false là Không áp dụng cả buổi.';
-- Chỉ mục (lý do): unique (session_id, criterion_id) phục vụ khoá ngoại buổi; tiêu chí gốc; cơ sở cho RLS.
create index session_review_criterion_criterion_idx on app.session_review_criterion (criterion_id);
create index session_review_criterion_branch_idx on app.session_review_criterion (branch_id);
select app.apply_standard('app.session_review_criterion');

-- Điểm từng em từng tiêu chí (R-V2-19): DA_DANH_GIA (1 đến 5) · KHONG_AP_DUNG · CHUA_DU_CAN_CU · CHUA_DANH_GIA. Ô trống ≠ điểm 0 (R-GV-02).
create table app.session_review_score (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references app.class_session (id),
  branch_id uuid not null references app.branch (id),
  session_criterion_id uuid not null references app.session_review_criterion (id),
  attendance_id uuid not null references app.session_attendance (id),
  state text not null default 'CHUA_DANH_GIA' check (state in ('DA_DANH_GIA', 'KHONG_AP_DUNG', 'CHUA_DU_CAN_CU', 'CHUA_DANH_GIA')),
  score smallint check (score between 1 and 5),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (session_criterion_id, attendance_id),
  check ((state = 'DA_DANH_GIA') = (score is not null))
);
comment on table app.session_review_score is 'Điểm 1 đến 5 của một em ở một tiêu chí của buổi. Điểm trung bình do DB tính (R-GV-03), chỉ trên ô Đã đánh giá.';
-- Chỉ mục (lý do): unique (tiêu chí, dòng điểm danh) phục vụ khoá ngoại; điểm của một em (trung bình, hồ sơ học tập); buổi; cơ sở cho RLS.
create index session_review_score_attendance_idx on app.session_review_score (attendance_id);
create index session_review_score_session_idx on app.session_review_score (session_id);
create index session_review_score_branch_idx on app.session_review_score (branch_id);
select app.apply_standard('app.session_review_score');

-- Nhận xét của em trong buổi + dấu Đã xuất (R-V2-38: một cờ mỗi em mỗi buổi, không lịch sử, không ràng buộc nghiệp vụ).
create table app.session_student_review (
  -- Cột id để nhật ký thao tác (app.tg_audit) ghi được; khoá chính vẫn là cột bên dưới.
  id uuid not null unique default gen_random_uuid(),
  attendance_id uuid primary key references app.session_attendance (id),
  session_id uuid not null references app.class_session (id),
  branch_id uuid not null references app.branch (id),
  teacher_comment text,
  improvement_note text,
  exported boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.session_student_review is 'Nhận xét chung, định hướng cải thiện (không bắt buộc) và cờ Đã xuất của một em trong một buổi (R-V2-38).';
-- Chỉ mục (lý do): các nhận xét của một buổi (màn xuất GV07X); cơ sở cho RLS.
create index session_student_review_session_idx on app.session_student_review (session_id);
create index session_student_review_branch_idx on app.session_student_review (branch_id);
select app.apply_standard('app.session_student_review');

-- Cấu hình buổi kiểm tra (R-V2-20): phạm vi kiến thức, điểm tối đa (chụp lúc đặt), cách nhập điểm, điểm tối đa từng nhóm.
create table app.session_exam (
  -- Cột id để nhật ký thao tác (app.tg_audit) ghi được; khoá chính vẫn là cột bên dưới.
  id uuid not null unique default gen_random_uuid(),
  session_id uuid primary key references app.class_session (id),
  branch_id uuid not null references app.branch (id),
  scope_text text,
  max_score numeric(5, 2) not null check (max_score > 0),
  entry_mode text not null check (entry_mode in ('TONG', 'NHOM')),
  max_memory numeric(5, 2) not null default 0 check (max_memory >= 0),
  max_understand numeric(5, 2) not null default 0 check (max_understand >= 0),
  max_apply numeric(5, 2) not null default 0 check (max_apply >= 0),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  -- Luật R-V2-20: nhập theo 3 nhóm thì tổng điểm tối đa 3 nhóm bằng điểm tối đa của buổi.
  check (entry_mode <> 'NHOM' or max_memory + max_understand + max_apply = max_score)
);
comment on table app.session_exam is 'Cấu hình buổi Kiểm tra (R-V2-20). Không có bảng đợt kiểm tra riêng: kiểm tra là một buổi học.';
-- Chỉ mục (lý do): cơ sở cho RLS.
create index session_exam_branch_idx on app.session_exam (branch_id);
select app.apply_standard('app.session_exam');

-- Điểm kiểm tra từng em (bảng điểm kiểm tra, R-V2-20). graded = Đã chấm; chưa chấm thì điểm trống (vắng không tự nhận 0).
create table app.exam_score (
  -- Cột id để nhật ký thao tác (app.tg_audit) ghi được; khoá chính vẫn là cột bên dưới.
  id uuid not null unique default gen_random_uuid(),
  attendance_id uuid primary key references app.session_attendance (id),
  session_id uuid not null references app.class_session (id),
  branch_id uuid not null references app.branch (id),
  total_score numeric(5, 2) check (total_score >= 0),
  memory_score numeric(5, 2) check (memory_score >= 0),
  understand_score numeric(5, 2) check (understand_score >= 0),
  apply_score numeric(5, 2) check (apply_score >= 0),
  graded boolean not null default false,
  correction_reason_code text,
  correction_note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (not graded or total_score is not null)
);
comment on table app.exam_score is 'Điểm kiểm tra của em: điểm tổng, hoặc 3 nhóm Ghi nhớ, Hiểu, Vận dụng (tổng tự cộng). Sửa sau Done có lý do.';
-- Chỉ mục (lý do): bảng điểm của một buổi; cơ sở cho RLS.
create index exam_score_session_idx on app.exam_score (session_id);
create index exam_score_branch_idx on app.exam_score (branch_id);
select app.apply_standard('app.exam_score');

-- ---------------------------------------------------------------------------
-- 5. RLS: chỉ đọc; ghi qua hàm nghiệp vụ. Phạm vi theo quyền Điểm danh · Xem (giáo viên chỉ buổi được phân công).
-- ---------------------------------------------------------------------------
create or replace function app.session_visible(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from app.class_session s
     where s.id = p_session_id
       and case app.permission_scope('ATTENDANCE', 'XEM')
             when 'TOAN_HE_THONG' then true
             when 'CO_SO' then s.branch_id = app.current_branch_id()
             when 'DUOC_PHAN_CONG' then auth.uid() in (s.teacher_id, s.assistant_id)
             else false
           end);
$$;

alter table app.review_criterion enable row level security;
alter table app.review_subject_set enable row level security;
alter table app.review_level_desc enable row level security;
alter table app.review_hint enable row level security;
alter table app.parent_phrase enable row level security;
alter table app.session_review_criterion enable row level security;
alter table app.session_review_score enable row level security;
alter table app.session_student_review enable row level security;
alter table app.session_exam enable row level security;
alter table app.exam_score enable row level security;

grant select on app.review_criterion, app.review_subject_set, app.review_level_desc, app.review_hint, app.parent_phrase, app.session_review_criterion, app.session_review_score,
  app.session_student_review, app.session_exam, app.exam_score to authenticated;

-- Cấu hình: ai có quyền xem điểm danh (hoặc lớp) thì đọc được.
create policy review_criterion_read on app.review_criterion for select to authenticated
  using ((select app.permission_scope('ATTENDANCE', 'XEM')) is not null);
create policy review_subject_set_read on app.review_subject_set for select to authenticated
  using ((select app.permission_scope('ATTENDANCE', 'XEM')) is not null);
create policy review_level_desc_read on app.review_level_desc for select to authenticated
  using ((select app.permission_scope('ATTENDANCE', 'XEM')) is not null);
create policy review_hint_read on app.review_hint for select to authenticated
  using ((select app.permission_scope('ATTENDANCE', 'XEM')) is not null);
create policy parent_phrase_read on app.parent_phrase for select to authenticated
  using ((select app.permission_scope('ATTENDANCE', 'XEM')) is not null);
create policy session_review_criterion_read on app.session_review_criterion for select to authenticated
  using ((select app.session_visible(session_id)));
create policy session_review_score_read on app.session_review_score for select to authenticated
  using ((select app.session_visible(session_id)));
create policy session_student_review_read on app.session_student_review for select to authenticated
  using ((select app.session_visible(session_id)));
create policy session_exam_read on app.session_exam for select to authenticated
  using ((select app.session_visible(session_id)));
create policy exam_score_read on app.exam_score for select to authenticated
  using ((select app.session_visible(session_id)));

-- ---------------------------------------------------------------------------
-- 6. Dữ liệu nạp sẵn: 9 tiêu chí (R-V2-19) và 24 mẫu câu (R-V2-39)
-- ---------------------------------------------------------------------------
-- Thái độ: chung mọi môn. Tiếp thu, Vận dụng: bộ Toán (Toán, Đại số, Hình học) và bộ môn phụ (mọi môn còn lại) theo Q-189.
-- Mô tả 5 mức (Q-190) viết một lần theo tên tiêu chí gốc; tiêu chí Toán dùng mô tả của tiêu chí gốc tương ứng.
insert into app.review_subject_set (subject_code, subject_set) values
  ('TOAN', 'TOAN'), ('DAI', 'TOAN'), ('HINH', 'TOAN'), ('LY', 'MON_PHU'), ('HOA', 'MON_PHU'), ('KHTN', 'MON_PHU'),
  ('ANH', 'MON_PHU'), ('VAN', 'MON_PHU'), ('TRUNG', 'MON_PHU'), ('SAT', 'MON_PHU');

insert into app.review_criterion (code, group_code, subject_set, name, sort_order) values
  ('TD_TAP_TRUNG', 'THAI_DO', 'MOI_MON', 'Tập trung', 1),
  ('TD_CHU_DONG', 'THAI_DO', 'MOI_MON', 'Chủ động', 2),
  ('TD_TU_GIAC', 'THAI_DO', 'MOI_MON', 'Tự giác', 3),
  ('TT_GHI_NHO', 'TIEP_THU', 'MON_PHU', 'Ghi nhớ kiến thức', 4),
  ('TT_HIEU', 'TIEP_THU', 'MON_PHU', 'Hiểu bản chất', 5),
  ('TT_NHAN_BIET', 'TIEP_THU', 'MON_PHU', 'Nhận biết dạng bài', 6),
  ('VD_LAM_BAI', 'VAN_DUNG', 'MON_PHU', 'Làm bài vận dụng', 7),
  ('VD_LAP_LUAN', 'VAN_DUNG', 'MON_PHU', 'Tư duy lập luận', 8),
  ('VD_TRINH_BAY', 'VAN_DUNG', 'MON_PHU', 'Trình bày chính xác', 9),
  ('TOAN_GHI_NHO', 'TIEP_THU', 'TOAN', 'Ghi nhớ công thức', 4),
  ('TOAN_HIEU', 'TIEP_THU', 'TOAN', 'Hiểu bản chất', 5),
  ('TOAN_NHAN_BIET', 'TIEP_THU', 'TOAN', 'Nhận biết dạng toán', 6),
  ('TOAN_LAM_BAI', 'VAN_DUNG', 'TOAN', 'Giải bài tập', 7),
  ('TOAN_LAP_LUAN', 'VAN_DUNG', 'TOAN', 'Tư duy lập luận', 8),
  ('TOAN_TRINH_BAY', 'VAN_DUNG', 'TOAN', 'Tính toán, trình bày', 9);

insert into app.review_level_desc (criterion_id, level, description)
select rc.id, v.level, v.description
  from (values
  ('TD_TAP_TRUNG', 1, 'Thường làm việc riêng, bỏ lỡ hướng dẫn'),
  ('TD_TAP_TRUNG', 2, 'Dễ mất tập trung, cần nhắc nhiều lần'),
  ('TD_TAP_TRUNG', 3, 'Theo dõi bài, đôi lúc cần nhắc'),
  ('TD_TAP_TRUNG', 4, 'Tập trung suốt buổi, ít cần nhắc'),
  ('TD_TAP_TRUNG', 5, 'Tập trung cao, tự ghi chép ý quan trọng'),
  ('TD_CHU_DONG', 1, 'Không phát biểu, không hỏi khi chưa hiểu'),
  ('TD_CHU_DONG', 2, 'Chỉ trả lời khi được gọi'),
  ('TD_CHU_DONG', 3, 'Thỉnh thoảng phát biểu, hỏi khi được gợi ý'),
  ('TD_CHU_DONG', 4, 'Thường phát biểu, tự hỏi chỗ chưa hiểu'),
  ('TD_CHU_DONG', 5, 'Dẫn dắt trao đổi, hỗ trợ bạn'),
  ('TD_TU_GIAC', 1, 'Ít bắt tay làm bài, dễ bỏ cuộc'),
  ('TD_TU_GIAC', 2, 'Làm khi được thúc, dừng sớm khi gặp khó'),
  ('TD_TU_GIAC', 3, 'Hoàn thành nhiệm vụ cơ bản'),
  ('TD_TU_GIAC', 4, 'Tự làm bài, kiên trì với bài khó'),
  ('TD_TU_GIAC', 5, 'Tự kiểm tra, sửa lỗi, luyện thêm'),
  ('TT_GHI_NHO', 1, 'Chưa nhớ kiến thức cơ bản của bài'),
  ('TT_GHI_NHO', 2, 'Nhớ một phần, cần xem lại'),
  ('TT_GHI_NHO', 3, 'Nhớ kiến thức cơ bản'),
  ('TT_GHI_NHO', 4, 'Nhớ chắc, dùng đúng khi làm bài'),
  ('TT_GHI_NHO', 5, 'Nhớ chắc, liên hệ được bài cũ'),
  ('TT_HIEU', 1, 'Chưa hiểu dù được hướng dẫn'),
  ('TT_HIEU', 2, 'Hiểu từng phần, cần giải thích nhiều lần'),
  ('TT_HIEU', 3, 'Hiểu ý chính sau hướng dẫn'),
  ('TT_HIEU', 4, 'Giải thích lại được bằng lời của mình'),
  ('TT_HIEU', 5, 'Hiểu sâu, giải thích được vì sao'),
  ('TT_NHAN_BIET', 1, 'Chưa nhận ra dạng bài'),
  ('TT_NHAN_BIET', 2, 'Nhận ra khi có gợi ý'),
  ('TT_NHAN_BIET', 3, 'Nhận ra dạng bài quen thuộc'),
  ('TT_NHAN_BIET', 4, 'Nhận ra cả dạng biến đổi'),
  ('TT_NHAN_BIET', 5, 'Nhận ra nhanh, chọn cách làm phù hợp nhất'),
  ('VD_LAM_BAI', 1, 'Chưa làm được bài cơ bản'),
  ('VD_LAM_BAI', 2, 'Làm được khi có mẫu hoặc gợi ý từng bước'),
  ('VD_LAM_BAI', 3, 'Tự làm được bài cơ bản'),
  ('VD_LAM_BAI', 4, 'Tự làm được bài vận dụng'),
  ('VD_LAM_BAI', 5, 'Làm được bài khó, ít quen thuộc'),
  ('VD_LAP_LUAN', 1, 'Chưa có hướng làm'),
  ('VD_LAP_LUAN', 2, 'Có hướng nhưng lập luận rời rạc'),
  ('VD_LAP_LUAN', 3, 'Lập luận đúng ở bài cơ bản'),
  ('VD_LAP_LUAN', 4, 'Lập luận chặt chẽ, có căn cứ'),
  ('VD_LAP_LUAN', 5, 'Lập luận sắc, tìm được nhiều cách'),
  ('VD_TRINH_BAY', 1, 'Rời rạc, nhiều lỗi'),
  ('VD_TRINH_BAY', 2, 'Còn lỗi, thiếu bước'),
  ('VD_TRINH_BAY', 3, 'Đủ bước chính, ít lỗi'),
  ('VD_TRINH_BAY', 4, 'Rõ ràng, chính xác'),
  ('VD_TRINH_BAY', 5, 'Chính xác, gọn, đầy đủ'),
  ('TOAN_GHI_NHO', 1, 'Chưa nhớ kiến thức cơ bản của bài'),
  ('TOAN_GHI_NHO', 2, 'Nhớ một phần, cần xem lại'),
  ('TOAN_GHI_NHO', 3, 'Nhớ kiến thức cơ bản'),
  ('TOAN_GHI_NHO', 4, 'Nhớ chắc, dùng đúng khi làm bài'),
  ('TOAN_GHI_NHO', 5, 'Nhớ chắc, liên hệ được bài cũ'),
  ('TOAN_HIEU', 1, 'Chưa hiểu dù được hướng dẫn'),
  ('TOAN_HIEU', 2, 'Hiểu từng phần, cần giải thích nhiều lần'),
  ('TOAN_HIEU', 3, 'Hiểu ý chính sau hướng dẫn'),
  ('TOAN_HIEU', 4, 'Giải thích lại được bằng lời của mình'),
  ('TOAN_HIEU', 5, 'Hiểu sâu, giải thích được vì sao'),
  ('TOAN_NHAN_BIET', 1, 'Chưa nhận ra dạng bài'),
  ('TOAN_NHAN_BIET', 2, 'Nhận ra khi có gợi ý'),
  ('TOAN_NHAN_BIET', 3, 'Nhận ra dạng bài quen thuộc'),
  ('TOAN_NHAN_BIET', 4, 'Nhận ra cả dạng biến đổi'),
  ('TOAN_NHAN_BIET', 5, 'Nhận ra nhanh, chọn cách làm phù hợp nhất'),
  ('TOAN_LAM_BAI', 1, 'Chưa làm được bài cơ bản'),
  ('TOAN_LAM_BAI', 2, 'Làm được khi có mẫu hoặc gợi ý từng bước'),
  ('TOAN_LAM_BAI', 3, 'Tự làm được bài cơ bản'),
  ('TOAN_LAM_BAI', 4, 'Tự làm được bài vận dụng'),
  ('TOAN_LAM_BAI', 5, 'Làm được bài khó, ít quen thuộc'),
  ('TOAN_LAP_LUAN', 1, 'Chưa có hướng làm'),
  ('TOAN_LAP_LUAN', 2, 'Có hướng nhưng lập luận rời rạc'),
  ('TOAN_LAP_LUAN', 3, 'Lập luận đúng ở bài cơ bản'),
  ('TOAN_LAP_LUAN', 4, 'Lập luận chặt chẽ, có căn cứ'),
  ('TOAN_LAP_LUAN', 5, 'Lập luận sắc, tìm được nhiều cách'),
  ('TOAN_TRINH_BAY', 1, 'Rời rạc, nhiều lỗi'),
  ('TOAN_TRINH_BAY', 2, 'Còn lỗi, thiếu bước'),
  ('TOAN_TRINH_BAY', 3, 'Đủ bước chính, ít lỗi'),
  ('TOAN_TRINH_BAY', 4, 'Rõ ràng, chính xác'),
  ('TOAN_TRINH_BAY', 5, 'Chính xác, gọn, đầy đủ')
  ) v (code, level, description)
  join app.review_criterion rc on rc.code = v.code;

-- Biểu hiện gợi ý theo môn (Q-189), chỉ cho bộ môn phụ.
insert into app.review_hint (criterion_id, subject_code, hint)
select rc.id, v.subject_code, v.hint
  from (values
  ('LY', 'TT_GHI_NHO', 'Công thức, đơn vị, định luật'),
  ('LY', 'TT_HIEU', 'Hiểu hiện tượng, ý nghĩa đại lượng'),
  ('LY', 'TT_NHAN_BIET', 'Nhận ra dạng bài, chọn đúng định luật'),
  ('LY', 'VD_LAM_BAI', 'Giải bài định lượng'),
  ('LY', 'VD_LAP_LUAN', 'Lập luận từ hiện tượng đến kết quả'),
  ('LY', 'VD_TRINH_BAY', 'Đơn vị, lời giải đủ bước'),
  ('HOA', 'TT_GHI_NHO', 'Công thức, tính chất, phương trình'),
  ('HOA', 'TT_HIEU', 'Hiểu cơ chế phản ứng'),
  ('HOA', 'TT_NHAN_BIET', 'Nhận ra dạng bài tập hoá'),
  ('HOA', 'VD_LAM_BAI', 'Giải bài tập, cân bằng, tính toán'),
  ('HOA', 'VD_LAP_LUAN', 'Suy luận từ dữ kiện thí nghiệm'),
  ('HOA', 'VD_TRINH_BAY', 'Viết phương trình, kí hiệu đúng'),
  ('KHTN', 'TT_GHI_NHO', 'Khái niệm, kiến thức nền'),
  ('KHTN', 'TT_HIEU', 'Hiểu hiện tượng, quy luật'),
  ('KHTN', 'TT_NHAN_BIET', 'Nhận ra phần Lý, Hoá hay Sinh'),
  ('KHTN', 'VD_LAM_BAI', 'Vận dụng kiến thức vào tình huống'),
  ('KHTN', 'VD_LAP_LUAN', 'Giải thích, dự đoán'),
  ('KHTN', 'VD_TRINH_BAY', 'Dùng đúng thuật ngữ'),
  ('ANH', 'TT_GHI_NHO', 'Từ vựng, cấu trúc, ngữ pháp'),
  ('ANH', 'TT_HIEU', 'Hiểu quy tắc, ngữ cảnh'),
  ('ANH', 'TT_NHAN_BIET', 'Nhận ra dạng bài, dạng câu hỏi'),
  ('ANH', 'VD_LAM_BAI', 'Làm bài, dùng ngôn ngữ đúng ngữ cảnh'),
  ('ANH', 'VD_LAP_LUAN', 'Suy luận từ ngữ cảnh, phân tích văn bản'),
  ('ANH', 'VD_TRINH_BAY', 'Chính tả, ngữ pháp, diễn đạt đúng'),
  ('VAN', 'TT_GHI_NHO', 'Kiến thức tác phẩm, tác giả, thể loại'),
  ('VAN', 'TT_HIEU', 'Hiểu nội dung, ý nghĩa'),
  ('VAN', 'TT_NHAN_BIET', 'Nhận ra dạng đề, kiểu bài'),
  ('VAN', 'VD_LAM_BAI', 'Làm bài đọc hiểu, viết đoạn'),
  ('VAN', 'VD_LAP_LUAN', 'Lập luận, dẫn chứng, phân tích'),
  ('VAN', 'VD_TRINH_BAY', 'Bố cục, diễn đạt, dùng từ'),
  ('TRUNG', 'TT_GHI_NHO', 'Từ vựng, chữ, ngữ pháp'),
  ('TRUNG', 'TT_HIEU', 'Hiểu quy tắc, ngữ cảnh'),
  ('TRUNG', 'TT_NHAN_BIET', 'Nhận ra dạng bài, mẫu câu'),
  ('TRUNG', 'VD_LAM_BAI', 'Làm bài, đặt câu, giao tiếp'),
  ('TRUNG', 'VD_LAP_LUAN', 'Suy luận từ ngữ cảnh'),
  ('TRUNG', 'VD_TRINH_BAY', 'Phát âm, viết chữ, ngữ pháp đúng'),
  ('SAT', 'TT_GHI_NHO', 'Kiến thức, quy tắc cần nhớ'),
  ('SAT', 'TT_HIEU', 'Hiểu bản chất câu hỏi'),
  ('SAT', 'TT_NHAN_BIET', 'Nhận ra dạng câu SAT'),
  ('SAT', 'VD_LAM_BAI', 'Làm đề, quản lý thời gian'),
  ('SAT', 'VD_LAP_LUAN', 'Chọn đáp án có căn cứ'),
  ('SAT', 'VD_TRINH_BAY', 'Chính xác, tránh lỗi cẩu thả')
  ) v (subject_code, code, hint)
  join app.review_criterion rc on rc.code = v.code;

-- 24 mẫu câu chính thức (Q-190): loại buổi × mức (4 Xuất sắc, 3 Tốt, 2 Đạt, 1 Cần cố gắng) × 3 câu.
insert into app.parent_phrase (kind, level, seq, phrase) values
  ('THUONG', 4, 1, 'Hôm nay con học rất tập trung, tiếp thu nhanh và làm tốt các bài vận dụng.'),
  ('THUONG', 4, 2, 'Con chủ động phát biểu, hiểu bài sâu và trình bày lời giải rõ ràng.'),
  ('THUONG', 4, 3, 'Con hoàn thành xuất sắc buổi học, gia đình động viên để con giữ phong độ nhé.'),
  ('THUONG', 3, 1, 'Hôm nay con học tốt, nắm chắc kiến thức và tự làm được phần lớn bài tập.'),
  ('THUONG', 3, 2, 'Con tập trung và tích cực, chỉ cần cẩn thận hơn khi trình bày.'),
  ('THUONG', 3, 3, 'Con tiến bộ tốt, gia đình nhắc con ôn lại bài để nhớ lâu.'),
  ('THUONG', 2, 1, 'Hôm nay con nắm được kiến thức cơ bản, cần luyện thêm bài vận dụng.'),
  ('THUONG', 2, 2, 'Con theo kịp bài, đôi lúc còn mất tập trung, cần chú ý hơn.'),
  ('THUONG', 2, 3, 'Con hoàn thành yêu cầu cơ bản, gia đình nhắc con làm bài tập về nhà đầy đủ.'),
  ('THUONG', 1, 1, 'Hôm nay con còn khó khăn với nội dung bài, thầy cô sẽ hỗ trợ thêm ở buổi sau.'),
  ('THUONG', 1, 2, 'Con cần tập trung hơn trong giờ học, gia đình nhắc con xem lại bài hôm nay.'),
  ('THUONG', 1, 3, 'Con chưa nắm vững bài, gia đình trao đổi với thầy cô để cùng giúp con.'),
  ('KIEM_TRA', 4, 1, 'Con làm bài kiểm tra rất tốt, nắm chắc kiến thức phần đã học.'),
  ('KIEM_TRA', 4, 2, 'Kết quả kiểm tra của con rất cao, thể hiện sự chăm chỉ thời gian qua.'),
  ('KIEM_TRA', 4, 3, 'Con làm bài cẩn thận, trình bày chính xác, gia đình khen con nhé.'),
  ('KIEM_TRA', 3, 1, 'Con làm bài kiểm tra tốt, còn vài lỗi nhỏ cần rút kinh nghiệm.'),
  ('KIEM_TRA', 3, 2, 'Kết quả của con khá tốt, con cần cẩn thận hơn ở phần vận dụng.'),
  ('KIEM_TRA', 3, 3, 'Con nắm kiến thức tốt, ôn thêm bài khó để đạt điểm cao hơn.'),
  ('KIEM_TRA', 2, 1, 'Con đạt yêu cầu bài kiểm tra, cần ôn lại phần còn sai.'),
  ('KIEM_TRA', 2, 2, 'Con nắm được phần cơ bản, phần vận dụng còn chưa chắc.'),
  ('KIEM_TRA', 2, 3, 'Gia đình cùng con xem lại bài kiểm tra để con hiểu lỗi sai.'),
  ('KIEM_TRA', 1, 1, 'Kết quả kiểm tra của con chưa như mong đợi, thầy cô sẽ giúp con ôn lại.'),
  ('KIEM_TRA', 1, 2, 'Con còn hổng kiến thức ở phần này, cần ôn thêm ở nhà.'),
  ('KIEM_TRA', 1, 3, 'Gia đình trao đổi với thầy cô để có kế hoạch ôn tập cho con.');

-- ---------------------------------------------------------------------------
-- 7. Hàm đọc: điểm trung bình (R-GV-03), mức gợi ý và câu gợi ý (R-V2-39)
-- ---------------------------------------------------------------------------
-- app.review_average(dòng điểm danh): điểm trung bình các tiêu chí đang bật và Đã đánh giá; null nếu chưa có ô nào. Không làm tròn.
-- Luật R-GV-03: do cơ sở dữ liệu tính. Luật R-GV-02: ô trống không phải điểm 0 nên không vào trung bình.
create or replace function app.review_average(p_attendance_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select avg(sc.score)::numeric
    from app.session_review_score sc
    join app.session_review_criterion rc on rc.id = sc.session_criterion_id
    join app.session_attendance sa on sa.id = sc.attendance_id
   where sc.attendance_id = p_attendance_id and rc.enabled and sc.state = 'DA_DANH_GIA'
     -- Luật R-GV-04: em đã bị đổi sang không có mặt thì điểm giữ nhưng không tính.
     and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
     and app.session_visible(sa.session_id);
$$;

-- app.parent_message_hint(buổi, em): mức 1 đến 4 và ba câu mẫu của mức đó. Ai gọi: người xem được điểm danh của buổi.
-- Luật R-V2-39: ngưỡng từ Cài đặt, so sánh trên điểm chưa làm tròn. Buổi thường: điểm trung bình; kiểm tra: điểm tổng ÷ tối đa.
create or replace function app.parent_message_hint(p_session_id uuid, p_student_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  sa app.session_attendance;
  ex app.session_exam;
  v_kind text;
  v_value numeric;
  v_l4 numeric;
  v_l3 numeric;
  v_l2 numeric;
  v_level smallint;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select * into sa from app.session_attendance where session_id = p_session_id and student_id = p_student_id and is_active;
  if sa.id is null then
    perform app.raise_error('HMT_EM_KHONG_TRONG_DANH_SACH', 'Em không nằm trong danh sách buổi này.');
  end if;
  if s.type_code = 'KIEM_TRA' then
    v_kind := 'KIEM_TRA';
    select * into ex from app.session_exam where session_id = p_session_id;
    select es.total_score / ex.max_score * 100 into v_value from app.exam_score es where es.attendance_id = sa.id and es.graded; -- allow-number: đổi điểm thành phần trăm
    v_l4 := app.get_setting_numeric('parent_hint_exam_level4', s.branch_id);
    v_l3 := app.get_setting_numeric('parent_hint_exam_level3', s.branch_id);
    v_l2 := app.get_setting_numeric('parent_hint_exam_level2', s.branch_id);
  else
    v_kind := 'THUONG';
    v_value := app.review_average(sa.id);
    v_l4 := app.get_setting_numeric('parent_hint_regular_level4', s.branch_id);
    v_l3 := app.get_setting_numeric('parent_hint_regular_level3', s.branch_id);
    v_l2 := app.get_setting_numeric('parent_hint_regular_level2', s.branch_id);
  end if;
  if v_value is null then
    return jsonb_build_object('kind', v_kind, 'level', null, 'phrases', '[]'::jsonb);
  end if;
  v_level := case when v_value >= v_l4 then 4 when v_value >= v_l3 then 3 when v_value >= v_l2 then 2 else 1 end; -- allow-number: số mức gợi ý cố định 1 đến 4 (R-V2-39)
  return jsonb_build_object('kind', v_kind, 'level', v_level,
    'phrases', coalesce((select jsonb_agg(pp.phrase order by pp.seq) from app.parent_phrase pp where pp.kind = v_kind and pp.level = v_level), '[]'::jsonb));
end;
$$;

-- app.session_review_sheet(buổi): dữ liệu màn chấm: mỗi tiêu chí của buổi kèm bật/tắt, biểu hiện gợi ý theo môn và mô tả 5 mức. Một lần gọi cho cả màn.
-- Ai gọi: người xem được điểm danh của buổi. Luật R-V2-19, Q-189, Q-190.
create or replace function app.session_review_sheet(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_subject text;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select subject_code into v_subject from app.class where id = s.class_id;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'criterion_id', src.criterion_id, 'name', src.name, 'group_code', src.group_code, 'enabled', src.enabled,
             'hint', (select h.hint from app.review_hint h where h.criterion_id = src.criterion_id and h.subject_code = v_subject),
             'levels', (select jsonb_agg(d.description order by d.level) from app.review_level_desc d where d.criterion_id = src.criterion_id))
           order by src.sort_order)
      from app.session_review_criterion src where src.session_id = p_session_id), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Nhận xét 9 tiêu chí: mở, công tắc tiêu chí, chấm, nút "Cả lớp", nhận xét chung
-- ---------------------------------------------------------------------------
-- Kiểm tra buổi cho phép giáo viên ghi nhận xét/điểm: đúng quyền, buổi Đã chốt (Done rồi giáo viên không sửa, R-GV-08; sửa qua ticket).
create or replace function app.assert_review_writable(p_session_id uuid, p_exam boolean)
returns app.class_session
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA');
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: giáo viên không sửa nhận xét, điểm. Tạo ticket cho vận hành để sửa kèm lý do.');
  end if;
  if s.status_code <> 'DA_CHOT' then
    perform app.raise_error('HMT_BUOI_CHUA_CHOT', 'Buổi chưa chốt danh sách nên chưa chấm được.');
  end if;
  if (s.type_code = 'KIEM_TRA') is distinct from p_exam then
    perform app.raise_error('HMT_SAI_LOAI_BUOI', case when p_exam then 'Buổi này không phải buổi kiểm tra.' else 'Buổi kiểm tra chấm bằng điểm, không dùng 9 tiêu chí.' end);
  end if;
  return s;
end;
$$;

-- app.review_criteria_for_subject(môn): tiêu chí đang dùng của môn: nhóm chung mọi môn + bộ của môn (Toán hoặc môn phụ), Q-189.
create or replace function app.review_criteria_for_subject(p_subject_code text)
returns setof app.review_criterion
language sql
stable
security definer
set search_path = ''
as $$
  select rc.* from app.review_criterion rc
   where rc.is_active
     and (rc.subject_set = 'MOI_MON'
          or rc.subject_set = (select ss.subject_set from app.review_subject_set ss where ss.subject_code = p_subject_code))
   order by rc.sort_order;
$$;

-- app.open_session_review(buổi): chụp tiêu chí đang dùng của môn (3 chung + tiêu chí riêng của môn) cho buổi, bật hết. Gọi lại không đổi gì.
-- Ai gọi: giáo viên, trợ giảng của buổi, hoặc vận hành có quyền Điểm danh · Sửa. Kết quả: số tiêu chí của buổi. Luật R-V2-19.
create or replace function app.open_session_review(p_session_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_subject text;
begin
  s := app.assert_review_writable(p_session_id, false);
  select subject_code into v_subject from app.class where id = s.class_id;
  insert into app.session_review_criterion (session_id, branch_id, criterion_id, group_code, name, sort_order)
  select s.id, s.branch_id, rc.id, rc.group_code, rc.name, rc.sort_order
    from app.review_criteria_for_subject(v_subject) rc
  on conflict (session_id, criterion_id) do nothing;
  return (select count(*) from app.session_review_criterion where session_id = p_session_id);
end;
$$;

-- app.set_review_criteria(buổi, [{criterion_id, enabled}]): công tắc tiêu chí của buổi. Tắt = cả lớp Không áp dụng tiêu chí đó (R-V2-19).
-- Luật: ít nhất một tiêu chí còn bật.
create or replace function app.set_review_criteria(p_session_id uuid, p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  e jsonb;
  v_n integer := 0;
begin
  s := app.assert_review_writable(p_session_id, false);
  for e in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    update app.session_review_criterion set enabled = (e ->> 'enabled')::boolean
     where session_id = p_session_id and criterion_id = (e ->> 'criterion_id')::uuid;
    if not found then
      perform app.raise_error('HMT_TIEU_CHI_KHONG_TIM_THAY', 'Tiêu chí không thuộc buổi này. Mở nhận xét của buổi trước.');
    end if;
    v_n := v_n + 1;
  end loop;
  if not exists (select from app.session_review_criterion where session_id = p_session_id and enabled) then
    perform app.raise_error('HMT_NHAN_XET_CAN_TIEU_CHI', 'Buổi phải còn ít nhất một tiêu chí được chấm.');
  end if;
  return v_n;
end;
$$;

-- app.set_review_scores(buổi, [{student_id, criterion_id, state, score}]): giáo viên chấm. Chỉ em có mặt hoặc đi muộn (R-GV-04: em vắng không chấm).
-- state: DA_DANH_GIA (score 1 đến 5), CHUA_DU_CAN_CU, CHUA_DANH_GIA. KHONG_AP_DUNG do công tắc tiêu chí, không đặt từng em.
create or replace function app.set_review_scores(p_session_id uuid, p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  e jsonb;
  v_state text;
  v_score smallint;
  v_att uuid;
  v_crit uuid;
  v_n integer := 0;
begin
  s := app.assert_review_writable(p_session_id, false);
  for e in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    v_state := e ->> 'state';
    v_score := nullif(e ->> 'score', '')::smallint;
    if v_state not in ('DA_DANH_GIA', 'CHUA_DU_CAN_CU', 'CHUA_DANH_GIA') then
      perform app.raise_error('HMT_TRANG_THAI_CHAM_SAI', 'Trạng thái chấm không hợp lệ.');
    end if;
    -- Luật R-V2-19: Đã đánh giá cần điểm 1 đến 5; các trạng thái khác không có điểm.
    if (v_state = 'DA_DANH_GIA') and (v_score is null or v_score not between 1 and 5) then -- allow-number: thang điểm 1 đến 5 cố định (R-V2-19)
      perform app.raise_error('HMT_DIEM_KHONG_HOP_LE', 'Điểm phải từ 1 đến 5.');
    end if;
    if v_state <> 'DA_DANH_GIA' then
      v_score := null;
    end if;
    select sa.id into v_att from app.session_attendance sa
     where sa.session_id = p_session_id and sa.student_id = (e ->> 'student_id')::uuid and sa.is_active
       and sa.teacher_status_code in ('CO_MAT', 'DI_MUON');
    if v_att is null then
      perform app.raise_error('HMT_EM_KHONG_CO_MAT', 'Chỉ chấm em có mặt trong buổi.');
    end if;
    select id into v_crit from app.session_review_criterion
     where session_id = p_session_id and criterion_id = (e ->> 'criterion_id')::uuid and enabled;
    if v_crit is null then
      perform app.raise_error('HMT_TIEU_CHI_KHONG_TIM_THAY', 'Tiêu chí không có hoặc đang tắt trong buổi này.');
    end if;
    insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score)
    values (p_session_id, s.branch_id, v_crit, v_att, v_state, v_score)
    on conflict (session_criterion_id, attendance_id) do update set state = excluded.state, score = excluded.score;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

-- app.set_review_all_class(buổi, tiêu chí, mức): nút "Cả lớp mức N": gán mức cho mọi em có mặt ở tiêu chí đó. Mức trống = tham số review_all_class_level.
create or replace function app.set_review_all_class(p_session_id uuid, p_criterion_id uuid, p_level integer default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_level integer;
  v_crit uuid;
  v_n integer;
begin
  s := app.assert_review_writable(p_session_id, false);
  v_level := coalesce(p_level, app.get_setting_int('review_all_class_level', s.branch_id));
  if v_level not between 1 and 5 then -- allow-number: thang điểm 1 đến 5 cố định (R-V2-19)
    perform app.raise_error('HMT_DIEM_KHONG_HOP_LE', 'Điểm phải từ 1 đến 5.');
  end if;
  select id into v_crit from app.session_review_criterion where session_id = p_session_id and criterion_id = p_criterion_id and enabled;
  if v_crit is null then
    perform app.raise_error('HMT_TIEU_CHI_KHONG_TIM_THAY', 'Tiêu chí không có hoặc đang tắt trong buổi này.');
  end if;
  insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score)
  select p_session_id, s.branch_id, v_crit, sa.id, 'DA_DANH_GIA', v_level
    from app.session_attendance sa
   where sa.session_id = p_session_id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
  on conflict (session_criterion_id, attendance_id) do update set state = 'DA_DANH_GIA', score = excluded.score;
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

-- app.set_student_review_note(buổi, em, nhận xét chung, định hướng cải thiện): không bắt buộc (R-V2-39; bỏ luật v1 bắt buộc viết lời nhắn).
-- Dùng cho cả buổi thường và buổi kiểm tra. Giáo viên sửa tới khi Done.
create or replace function app.set_student_review_note(p_session_id uuid, p_student_id uuid, p_comment text, p_improvement text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_att uuid;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA');
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: giáo viên không sửa nhận xét, điểm. Tạo ticket cho vận hành để sửa kèm lý do.');
  end if;
  select id into v_att from app.session_attendance
   where session_id = p_session_id and student_id = p_student_id and is_active and teacher_status_code in ('CO_MAT', 'DI_MUON');
  if v_att is null then
    perform app.raise_error('HMT_EM_KHONG_CO_MAT', 'Chỉ nhận xét em có mặt trong buổi.');
  end if;
  insert into app.session_student_review (attendance_id, session_id, branch_id, teacher_comment, improvement_note)
  values (v_att, p_session_id, s.branch_id, nullif(btrim(p_comment), ''), nullif(btrim(p_improvement), ''))
  on conflict (attendance_id) do update set teacher_comment = excluded.teacher_comment, improvement_note = excluded.improvement_note;
end;
$$;

-- app.set_review_exported(buổi, em, đã xuất): cờ Đã xuất (R-V2-38): xuất nhận xét ra PDF hoặc ảnh. Chỉ để nhìn, không ràng buộc; được đặt cả sau Done.
-- Ai gọi: người xem được điểm danh của buổi (giáo viên được phân công, vận hành).
create or replace function app.set_review_exported(p_session_id uuid, p_student_id uuid, p_exported boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_att uuid;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select id into v_att from app.session_attendance where session_id = p_session_id and student_id = p_student_id and is_active;
  if v_att is null then
    perform app.raise_error('HMT_EM_KHONG_TRONG_DANH_SACH', 'Em không nằm trong danh sách buổi này.');
  end if;
  insert into app.session_student_review (attendance_id, session_id, branch_id, exported)
  values (v_att, p_session_id, s.branch_id, coalesce(p_exported, false))
  on conflict (attendance_id) do update set exported = excluded.exported;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Buổi Kiểm tra: cấu hình và điểm (R-V2-20)
-- ---------------------------------------------------------------------------
-- app.set_exam_config(buổi, phạm vi, điểm tối đa, cách nhập, tối đa 3 nhóm): ai xếp lịch buổi thì đặt (không phải giáo viên). Buổi chưa Done.
-- Điểm tối đa trống = tham số exam_default_max_score (chụp lại). Nhập theo 3 nhóm: tổng 3 nhóm = điểm tối đa; nhóm không có đề đặt 0.
create or replace function app.set_exam_config(p_session_id uuid, p_scope text, p_max_score numeric, p_mode text,
                                               p_max_memory numeric default 0, p_max_understand numeric default 0, p_max_apply numeric default 0)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_max numeric;
begin
  s := app.assert_session_access(p_session_id, 'SESSION', 'SUA', true);
  if s.type_code <> 'KIEM_TRA' then
    perform app.raise_error('HMT_SAI_LOAI_BUOI', 'Buổi này không phải buổi kiểm tra.');
  end if;
  if s.status_code not in ('NHAP', 'DA_CHOT') then
    perform app.raise_error('HMT_BUOI_KHONG_SUA_DUOC', 'Chỉ đặt cấu hình kiểm tra cho buổi chưa Done và chưa huỷ.');
  end if;
  if p_mode not in ('TONG', 'NHOM') then
    perform app.raise_error('HMT_CACH_NHAP_DIEM_SAI', 'Cách nhập điểm là Điểm tổng hoặc Theo 3 nhóm.');
  end if;
  v_max := coalesce(p_max_score, app.get_setting_int('exam_default_max_score', s.branch_id));
  if v_max <= 0 then
    perform app.raise_error('HMT_DIEM_TOI_DA_SAI', 'Điểm tối đa phải lớn hơn 0.');
  end if;
  -- Luật R-V2-20: theo 3 nhóm thì tổng tối đa 3 nhóm bằng điểm tối đa của buổi.
  if p_mode = 'NHOM' and coalesce(p_max_memory, 0) + coalesce(p_max_understand, 0) + coalesce(p_max_apply, 0) <> v_max then
    perform app.raise_error('HMT_DIEM_NHOM_KHONG_KHOP', 'Tổng điểm tối đa của ba nhóm phải bằng điểm tối đa của buổi.');
  end if;
  insert into app.session_exam (session_id, branch_id, scope_text, max_score, entry_mode, max_memory, max_understand, max_apply)
  values (p_session_id, s.branch_id, nullif(btrim(p_scope), ''), v_max, p_mode,
          case when p_mode = 'NHOM' then coalesce(p_max_memory, 0) else 0 end,
          case when p_mode = 'NHOM' then coalesce(p_max_understand, 0) else 0 end,
          case when p_mode = 'NHOM' then coalesce(p_max_apply, 0) else 0 end)
  on conflict (session_id) do update set scope_text = excluded.scope_text, max_score = excluded.max_score, entry_mode = excluded.entry_mode,
         max_memory = excluded.max_memory, max_understand = excluded.max_understand, max_apply = excluded.max_apply;
end;
$$;

-- Tính điểm một em từ dữ liệu nhập; kiểm giới hạn. Trả về (tổng, ghi nhớ, hiểu, vận dụng). Nội bộ.
create or replace function app.exam_resolve_scores(p_exam app.session_exam, p_entry jsonb)
returns numeric[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_total numeric;
  v_m numeric := nullif(p_entry ->> 'memory', '')::numeric;
  v_u numeric := nullif(p_entry ->> 'understand', '')::numeric;
  v_a numeric := nullif(p_entry ->> 'apply', '')::numeric;
begin
  if p_exam.entry_mode = 'TONG' then
    v_total := (p_entry ->> 'total')::numeric;
    v_m := null; v_u := null; v_a := null;
  else
    -- Luật R-V2-20: nhóm không có đề (tối đa 0) bỏ qua; tổng tự cộng.
    v_m := case when p_exam.max_memory = 0 then 0 else v_m end;
    v_u := case when p_exam.max_understand = 0 then 0 else v_u end;
    v_a := case when p_exam.max_apply = 0 then 0 else v_a end;
    if v_m is null or v_u is null or v_a is null then
      perform app.raise_error('HMT_DIEM_KHONG_HOP_LE', 'Nhập đủ điểm các nhóm có đề.');
    end if;
    if v_m > p_exam.max_memory or v_u > p_exam.max_understand or v_a > p_exam.max_apply then
      perform app.raise_error('HMT_DIEM_VUOT_TOI_DA', 'Điểm một nhóm vượt điểm tối đa của nhóm.');
    end if;
    v_total := v_m + v_u + v_a;
  end if;
  if v_total is null or v_total < 0 or v_total > p_exam.max_score then
    perform app.raise_error('HMT_DIEM_VUOT_TOI_DA', 'Điểm phải từ 0 đến điểm tối đa của buổi.');
  end if;
  return array[v_total, v_m, v_u, v_a];
end;
$$;

-- app.set_exam_scores(buổi, [{student_id, total | memory, understand, apply}]): giáo viên nhập điểm. Chỉ em có mặt; vắng không tự nhận 0 (R-V2-20).
create or replace function app.set_exam_scores(p_session_id uuid, p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  ex app.session_exam;
  e jsonb;
  v_att uuid;
  v_r numeric[];
  v_n integer := 0;
begin
  s := app.assert_review_writable(p_session_id, true);
  select * into ex from app.session_exam where session_id = p_session_id;
  if ex.session_id is null then
    perform app.raise_error('HMT_KIEM_TRA_CHUA_CAU_HINH', 'Buổi kiểm tra chưa đặt điểm tối đa và cách nhập điểm.');
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    select sa.id into v_att from app.session_attendance sa
     where sa.session_id = p_session_id and sa.student_id = (e ->> 'student_id')::uuid and sa.is_active
       and sa.teacher_status_code in ('CO_MAT', 'DI_MUON');
    if v_att is null then
      perform app.raise_error('HMT_EM_KHONG_CO_MAT', 'Chỉ chấm em có mặt trong buổi.');
    end if;
    v_r := app.exam_resolve_scores(ex, e);
    insert into app.exam_score (attendance_id, session_id, branch_id, total_score, memory_score, understand_score, apply_score, graded)
    values (v_att, p_session_id, s.branch_id, v_r[1], v_r[2], v_r[3], v_r[4], true) -- allow-number: số mức gợi ý cố định 1 đến 4 (R-V2-39)
    on conflict (attendance_id) do update set total_score = excluded.total_score, memory_score = excluded.memory_score,
           understand_score = excluded.understand_score, apply_score = excluded.apply_score, graded = true;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

-- app.correct_exam_score_after_done(buổi, em, điểm, lý do, ghi chú): sửa điểm sau Done, chỉ quản lý đào tạo (Điểm danh · Duyệt), bắt buộc lý do (R-V2-20 mục 5).
create or replace function app.correct_exam_score_after_done(p_session_id uuid, p_student_id uuid, p_entry jsonb, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  ex app.session_exam;
  v_att uuid;
  v_r numeric[];
  v_requires_note boolean;
begin
  select * into s from app.class_session where id = p_session_id;
  if s.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy buổi học.');
  end if;
  perform app.assert_can('ATTENDANCE', 'DUYET', s.branch_id);
  if s.status_code <> 'DONE' or s.type_code <> 'KIEM_TRA' then
    perform app.raise_error('HMT_BUOI_CHUA_DONE', 'Chỉ sửa điểm sau Done cho buổi kiểm tra đã Done. Buổi chưa Done thì giáo viên sửa.');
  end if;
  perform app.assert_catalog_code_active('HOURS_ADJUST_REASON', p_reason_code);
  select requires_note into v_requires_note from app.catalog_item where catalog_code = 'HOURS_ADJUST_REASON' and code = p_reason_code;
  if v_requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_CAN_GHI_CHU', 'Lý do "Khác" cần ghi chú.');
  end if;
  select * into ex from app.session_exam where session_id = p_session_id;
  select id into v_att from app.session_attendance
   where session_id = p_session_id and student_id = p_student_id and is_active and teacher_status_code in ('CO_MAT', 'DI_MUON');
  if v_att is null then
    perform app.raise_error('HMT_EM_KHONG_CO_MAT', 'Chỉ sửa điểm của em có mặt trong buổi.');
  end if;
  v_r := app.exam_resolve_scores(ex, p_entry);
  insert into app.exam_score (attendance_id, session_id, branch_id, total_score, memory_score, understand_score, apply_score, graded,
                              correction_reason_code, correction_note)
  values (v_att, p_session_id, s.branch_id, v_r[1], v_r[2], v_r[3], v_r[4], true, p_reason_code, nullif(btrim(p_note), '')) -- allow-number: số mức gợi ý cố định 1 đến 4 (R-V2-39)
  on conflict (attendance_id) do update set total_score = excluded.total_score, memory_score = excluded.memory_score,
         understand_score = excluded.understand_score, apply_score = excluded.apply_score, graded = true,
         correction_reason_code = excluded.correction_reason_code, correction_note = excluded.correction_note;
end;
$$;

-- ---------------------------------------------------------------------------
-- 10. Điều kiện Done thêm nhận xét hoặc điểm (R-GIO-06, R-V2-35: không còn điều kiện BTVN)
-- ---------------------------------------------------------------------------
create or replace function app.session_pending_reason(p_session_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_missing integer;
begin
  select * into s from app.class_session where id = p_session_id;
  if s.status_code <> 'DA_CHOT' then
    return 'Buổi chưa chốt danh sách.';
  end if;
  if app.session_ends_at(p_session_id) > now() then
    return 'Buổi chưa kết thúc.';
  end if;
  select count(*) into v_missing from app.session_attendance where session_id = p_session_id and is_active and teacher_status_code is null;
  if v_missing > 0 then
    return format('Giáo viên chưa điểm danh %s em.', v_missing);
  end if;
  -- Luật Q-198: tham số tắt thì bỏ điều kiện nhận xét, điểm; điểm danh vẫn bắt buộc (kiểm ở trên).
  if not app.get_setting_bool('session_done_requires_review', s.branch_id) then
    return null;
  end if;
  if s.type_code = 'KIEM_TRA' then
    -- Luật R-V2-20: buổi kiểm tra chấm xong khi không còn em có mặt ở Chưa chấm.
    if not exists (select from app.session_exam where session_id = p_session_id) then
      return 'Buổi kiểm tra chưa đặt điểm tối đa và cách nhập điểm.';
    end if;
    select count(*) into v_missing from app.session_attendance sa
     where sa.session_id = p_session_id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
       and not exists (select from app.exam_score es where es.attendance_id = sa.id and es.graded);
    if v_missing > 0 then
      return format('Giáo viên chưa chấm điểm kiểm tra %s em.', v_missing);
    end if;
  else
    -- Luật R-V2-19, R-GV-04 (sửa 04/11): chấm xong khi mọi em có mặt không còn ô Chưa đánh giá ở tiêu chí đang bật.
    if not exists (select from app.session_review_criterion where session_id = p_session_id and enabled) then
      return 'Giáo viên chưa mở phần nhận xét của buổi.';
    end if;
    select count(*) into v_missing
      from app.session_attendance sa
      join app.session_review_criterion rc on rc.session_id = sa.session_id and rc.enabled
     where sa.session_id = p_session_id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
       and not exists (select from app.session_review_score sc
                        where sc.attendance_id = sa.id and sc.session_criterion_id = rc.id and sc.state <> 'CHUA_DANH_GIA');
    if v_missing > 0 then
      return format('Còn %s ô nhận xét chưa đánh giá.', v_missing);
    end if;
  end if;
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 11. Quyền gọi hàm
-- ---------------------------------------------------------------------------
revoke execute on function
  app.session_visible(uuid), app.review_average(uuid), app.assert_review_writable(uuid, boolean), app.exam_resolve_scores(app.session_exam, jsonb),
  app.parent_message_hint(uuid, uuid), app.review_criteria_for_subject(text), app.session_review_sheet(uuid), app.open_session_review(uuid), app.set_review_criteria(uuid, jsonb), app.set_review_scores(uuid, jsonb),
  app.set_review_all_class(uuid, uuid, integer), app.set_student_review_note(uuid, uuid, text, text), app.set_review_exported(uuid, uuid, boolean),
  app.set_exam_config(uuid, text, numeric, text, numeric, numeric, numeric), app.set_exam_scores(uuid, jsonb),
  app.correct_exam_score_after_done(uuid, uuid, jsonb, text, text), app.session_pending_reason(uuid)
  from public, anon, authenticated;
-- Giao diện gọi (kiểm quyền bên trong): mở nhận xét, công tắc, chấm, Cả lớp, nhận xét chung, Đã xuất, cấu hình và điểm kiểm tra, gợi ý, lý do chưa Done.
grant execute on function
  app.session_visible(uuid), app.review_average(uuid), app.parent_message_hint(uuid, uuid), app.review_criteria_for_subject(text), app.session_review_sheet(uuid), app.open_session_review(uuid),
  app.set_review_criteria(uuid, jsonb), app.set_review_scores(uuid, jsonb), app.set_review_all_class(uuid, uuid, integer),
  app.set_student_review_note(uuid, uuid, text, text), app.set_review_exported(uuid, uuid, boolean),
  app.set_exam_config(uuid, text, numeric, text, numeric, numeric, numeric), app.set_exam_scores(uuid, jsonb),
  app.correct_exam_score_after_done(uuid, uuid, jsonb, text, text), app.session_pending_reason(uuid)
  to authenticated;

select set_config('hmt.migration', '', false);
