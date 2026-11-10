-- D1e (Code 2, 10/11/2026): nạp dữ liệu đào tạo từ hệ thống cũ: Lớp, Ghi danh (kèm số dư giờ đầu kỳ), Buổi học và Điểm danh để đối soát.
-- Luật: R-V2-30 (trùng mã cũ thì bỏ qua), R-V2-32, R-V2-33 (điểm danh cũ chỉ để đối soát; mỗi ghi danh một dòng "Số dư đầu kỳ"),
-- Q-177, Q-186, Q-187, Q-188, mốc nạp 17/11/2026. Hợp đồng giống app.import_records của Code 1: xem trước hoàn tác, nạp thật, nhật ký.
-- Làm gì: tham số opening_balance_date; cột ngày trên sổ giờ; bảng lưu buổi học và điểm danh cũ (chỉ đọc); bảng đối chiếu giờ;
-- hàm app.import_training_records(loại, hàng, nạp thật, tên file) với 4 loại LOP, GHI_DANH, BUOI_HOC, DIEM_DANH; hàm báo cáo đối soát giờ.
-- Tiền tố 20261111000105 lớn hơn mọi file trên main. Chỉ mục: mỗi chỉ mục ghi lý do ngay bên dưới câu tạo.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- 1. Tham số mốc nạp và cột ngày trên sổ giờ
-- ---------------------------------------------------------------------------
-- Ngày chốt số dư (Q-186, Q-194): ngày của dòng "Số dư đầu kỳ" và mốc sinh buổi cho lớp nạp. Con số nghiệp vụ nên là tham số, không viết trong hàm.
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('opening_balance_date', 'Ngày chốt số dư đầu kỳ', 'TEXT', null, null, null, '2026-11-17', false, 'VAN_HANH_LOP', null,
   'Dạng yyyy-mm-dd. Dòng "Số dư đầu kỳ" của sổ giờ mang ngày này; lớp nạp từ hệ thống cũ chỉ sinh buổi từ ngày này trở đi (R-V2-33, Q-186).');

alter table app.hour_ledger add column entry_date date;
comment on column app.hour_ledger.entry_date is 'Ngày hiệu lực của dòng sổ giờ. Dòng Số dư đầu kỳ mang ngày chốt (opening_balance_date); dòng khác để trống, dùng created_at.';

-- Nhật ký nạp thêm bốn loại đào tạo (giữ các loại đã có trên main: PHU_HUYNH, HOC_SINH, NGUOI_DUNG, CO_HOI).
alter table app.import_log drop constraint import_log_kind_check;
alter table app.import_log add constraint import_log_kind_check
  check (kind in ('PHU_HUYNH', 'HOC_SINH', 'NGUOI_DUNG', 'CO_HOI', 'LOP', 'GHI_DANH', 'BUOI_HOC', 'DIEM_DANH'));

-- app.add_opening_hours: như bản D1b, thêm ngày chốt trên dòng sổ giờ (Q-177).
create or replace function app.add_opening_hours(p_enrollment_id uuid, p_hours numeric, p_source_ref text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
begin
  select * into e from app.enrollment where id = p_enrollment_id;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  if p_hours is null or p_hours = 0 then
    return;
  end if;
  insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, source_ref, entry_date)
  values (e.id, e.branch_id, 'DAU_KY', p_hours, p_source_ref, app.get_setting('opening_balance_date')::date);
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Bảng lưu dữ liệu cũ chỉ để đối soát (R-V2-33): không tạo buổi Done, không trừ giờ
-- ---------------------------------------------------------------------------
create table app.legacy_session_record (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references app.branch (id),
  class_legacy_ref text not null,
  class_id uuid not null references app.class (id),
  session_date date not null,
  teacher_staff_code text,
  lesson_name text,
  count_x integer not null default 0 check (count_x >= 0),
  count_p integer not null default 0 check (count_p >= 0),
  count_kp integer not null default 0 check (count_kp >= 0),
  count_n integer not null default 0 check (count_n >= 0),
  count_m integer not null default 0 check (count_m >= 0),
  status_text text,
  is_cancelled boolean not null default false,
  source_tab text,
  source_row integer,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (class_legacy_ref, session_date)
);
comment on table app.legacy_session_record is 'Buổi học từ hệ thống cũ, chỉ để đối soát (R-V2-33). Không phải buổi học của hệ thống mới; buổi nghỉ lễ ghi is_cancelled (Q-186).';
-- Chỉ mục (lý do): lớp (khoá ngoại, báo cáo đối soát theo lớp); cơ sở cho RLS.
create index legacy_session_class_idx on app.legacy_session_record (class_id, session_date);
create index legacy_session_branch_idx on app.legacy_session_record (branch_id);
select app.apply_standard('app.legacy_session_record');

create table app.legacy_attendance_record (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references app.branch (id),
  class_legacy_ref text not null,
  class_id uuid not null references app.class (id),
  student_legacy_ref text not null,
  student_id uuid not null references app.student (id),
  session_date date not null,
  symbol text,
  status_text text,
  counts_hours boolean not null default false,
  btvn_score numeric(5, 2),
  btvn_score_original numeric(5, 2),
  teacher_comment text,
  source_tab text,
  source_row integer,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (class_legacy_ref, student_legacy_ref, session_date)
);
comment on table app.legacy_attendance_record is 'Điểm danh từ hệ thống cũ, chỉ để đối soát (R-V2-33). x, P, KP, M tính giờ; N không tính (counts_hours). Không ghi sổ giờ.';
-- Chỉ mục (lý do): học sinh và lớp (báo cáo đối soát giờ); cơ sở cho RLS.
create index legacy_attendance_student_idx on app.legacy_attendance_record (student_id, class_id);
create index legacy_attendance_class_idx on app.legacy_attendance_record (class_id, session_date);
create index legacy_attendance_branch_idx on app.legacy_attendance_record (branch_id);
select app.apply_standard('app.legacy_attendance_record');

-- Số liệu giờ ghi trong file ghi danh, để so với điểm danh cũ (Q-187). Mỗi ghi danh một dòng.
create table app.legacy_enrollment_check (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null unique references app.enrollment (id),
  branch_id uuid not null references app.branch (id),
  class_id uuid not null references app.class (id),
  student_id uuid not null references app.student (id),
  student_legacy_ref text not null,
  class_legacy_ref text not null,
  session_hours numeric(6, 2) not null,
  studied_before_hours numeric(6, 2) not null default 0,
  planned_hours numeric(6, 2) not null,
  studied_hours numeric(6, 2) not null,
  remaining_hours numeric(6, 2) not null,
  source_tab text,
  source_row integer,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.legacy_enrollment_check is 'Giờ dự kiến, đã học, còn lại ghi trong file ghi danh cũ; dùng cho báo cáo đối soát (app.legacy_hours_reconciliation).';
-- Chỉ mục (lý do): học sinh và lớp (ghép với điểm danh cũ); lớp, cơ sở cho RLS.
create index legacy_enrollment_check_student_idx on app.legacy_enrollment_check (student_id, class_id);
create index legacy_enrollment_check_class_idx on app.legacy_enrollment_check (class_id);
create index legacy_enrollment_check_branch_idx on app.legacy_enrollment_check (branch_id);
select app.apply_standard('app.legacy_enrollment_check');

alter table app.legacy_session_record enable row level security;
alter table app.legacy_attendance_record enable row level security;
alter table app.legacy_enrollment_check enable row level security;
grant select on app.legacy_session_record, app.legacy_attendance_record, app.legacy_enrollment_check to authenticated;
-- Đọc: người duyệt điểm danh (quản lý cơ sở, Admin); chỉ trong cơ sở của mình.
create policy legacy_session_read on app.legacy_session_record for select to authenticated
  using ((select app.permission_scope('ATTENDANCE', 'DUYET')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('ATTENDANCE', 'DUYET')) = 'CO_SO' and branch_id = (select app.current_branch_id())));
create policy legacy_attendance_read on app.legacy_attendance_record for select to authenticated
  using ((select app.permission_scope('ATTENDANCE', 'DUYET')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('ATTENDANCE', 'DUYET')) = 'CO_SO' and branch_id = (select app.current_branch_id())));
create policy legacy_enrollment_check_read on app.legacy_enrollment_check for select to authenticated
  using ((select app.permission_scope('ATTENDANCE', 'DUYET')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('ATTENDANCE', 'DUYET')) = 'CO_SO' and branch_id = (select app.current_branch_id())));

-- ---------------------------------------------------------------------------
-- 3. Hàm phụ: đọc ô, số, ngày, lịch học
-- ---------------------------------------------------------------------------
create or replace function app.import_txt(p_row jsonb, p_key text)
returns text
language sql
immutable
set search_path = ''
as $$ select nullif(btrim(p_row ->> p_key), '') $$;

-- Số (giờ, điểm): chấp nhận dấu phẩy thập phân; sai dạng thì báo lỗi nêu tên cột.
create or replace function app.import_num(p_row jsonb, p_key text, p_required boolean default true)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text := app.import_txt(p_row, p_key);
begin
  if v_text is null then
    if p_required then
      perform app.raise_error('HMT_NAP_THIEU_COT', format('Thiếu giá trị cột %s.', p_key));
    end if;
    return null;
  end if;
  v_text := replace(v_text, ',', '.');
  if v_text !~ '^-?[0-9]+(\.[0-9]+)?$' then
    perform app.raise_error('HMT_NAP_SO_SAI', format('Cột %s phải là số, ví dụ 2.5.', p_key));
  end if;
  return v_text::numeric;
end;
$$;

create or replace function app.import_date(p_row jsonb, p_key text, p_required boolean default true)
returns date
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text := app.import_txt(p_row, p_key);
begin
  if v_text is null then
    if p_required then
      perform app.raise_error('HMT_NAP_THIEU_COT', format('Thiếu giá trị cột %s.', p_key));
    end if;
    return null;
  end if;
  if v_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
    perform app.raise_error('HMT_NAP_NGAY_SAI', format('Cột %s phải có dạng yyyy-mm-dd, ví dụ 2026-11-17.', p_key));
  end if;
  begin
    return v_text::date;
  exception when others then
    perform app.raise_error('HMT_NAP_NGAY_SAI', format('Cột %s không phải ngày hợp lệ.', p_key));
  end;
  return null;
end;
$$;

-- app.import_parse_schedule(lich_hoc, ngày chốt): tách "Thứ 5 (19h00-21h00); Thứ 7 (18h30-20h30)" thành mảng khung giờ cho app.create_class.
-- Mỗi khung lặp mỗi tuần, ngày đầu là ngày đầu tiên không trước ngày chốt rơi đúng thứ đó (Q-186: lớp nạp chỉ sinh buổi từ ngày chốt).
-- Thứ 2 đến Thứ 7 là 1 đến 6 (số thứ tự theo chuẩn ISO), "Chủ nhật" hoặc "CN" là 7. Sai dạng thì báo lỗi, không đoán (Q-187).
create or replace function app.import_parse_schedule(p_text text, p_from date)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_part text;
  m text[];
  v_out jsonb := '[]'::jsonb;
  v_weekday integer;
  v_first date;
begin
  if p_text is null or btrim(p_text) = '' then
    perform app.raise_error('HMT_NAP_LICH_SAI', 'Thiếu lịch học. Dạng đúng: Thứ 5 (19h00-21h00); Thứ 7 (18h30-20h30).');
  end if;
  foreach v_part in array string_to_array(p_text, ';') loop
    m := regexp_match(btrim(v_part), '^(?:th[ứu]\s*([2-7])|(?:ch[ủu]\s*nh[ậa]t|cn))\s*\(\s*([0-9]{1,2})h([0-9]{2})\s*-\s*([0-9]{1,2})h([0-9]{2})\s*\)$', 'i');
    if m is null then
      perform app.raise_error('HMT_NAP_LICH_SAI', 'Lịch học sai dạng. Dạng đúng: Thứ 5 (19h00-21h00); Thứ 7 (18h30-20h30).');
    end if;
    v_weekday := coalesce((m[1])::integer - 1, 7); -- allow-number: Chủ nhật là thứ 7 theo ISO; chỉ số nhóm regex
    if (m[2])::integer > 23 or (m[4])::integer > 23 or (m[3])::integer > 59 or (m[5])::integer > 59 then -- allow-number: giới hạn giờ, phút của một ngày
      perform app.raise_error('HMT_NAP_LICH_SAI', 'Giờ trong lịch học không hợp lệ.');
    end if;
    v_first := p_from + ((v_weekday - extract(isodow from p_from)::integer + 7) % 7); -- allow-number: 7 ngày một tuần
    v_out := v_out || jsonb_build_object('weekday', v_weekday,
               'start_time', format('%s:%s', lpad(m[2], 2, '0'), m[3]), 'end_time', format('%s:%s', lpad(m[4], 2, '0'), m[5]), -- allow-number: chỉ số nhóm regex và độ rộng 2 chữ số của giờ
               'repeat_weeks', 1, 'first_date', v_first);
  end loop;
  return v_out;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Từng loại hàng
-- ---------------------------------------------------------------------------
-- LOP (tab 03_LOP): ma_lop_cu, loai_lop, mon, khoi, lich_hoc, ma_gv, ngay_khai_giang, si_so_toi_da, tinh_trang, co_so + 4 cột mới
-- phan_loai (CB, NC), trinh_do, so_buoi (số buổi CÒN LẠI kể từ ngày chốt), nam_hoc (ví dụ 2627). Trùng mã lớp cũ thì bỏ qua (R-V2-30).
-- Giáo viên ghép "GV" + ma_gv với mã nhân sự; không thấy thì cảnh báo, lớp vẫn nạp (Q-187).
create or replace function app.import_one_class(p_row jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_legacy text := app.import_txt(p_row, 'ma_lop_cu');
  v_existing text;
  v_branch uuid;
  v_subject text;
  v_grade text;
  v_type text;
  v_level text;
  v_status text;
  v_open boolean;
  v_teacher uuid;
  v_gv text := app.import_txt(p_row, 'ma_gv');
  v_cutover date := app.get_setting('opening_balance_date')::date;
  v_slots jsonb;
  v_total integer;
  v_created jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_no_teacher boolean := false;
  v_loai text := app.import_txt(p_row, 'loai_lop');
begin
  if v_legacy is null then
    perform app.raise_error('HMT_NAP_THIEU_COT', 'Thiếu giá trị cột ma_lop_cu.');
  end if;
  -- Luật R-V2-30: trùng mã cũ thì bỏ qua, không ghi đè.
  select code into v_existing from app.class where legacy_ref = v_legacy limit 1;
  if v_existing is not null then
    return jsonb_build_object('status', 'TRUNG', 'code', v_existing, 'message', null, 'warnings', '[]'::jsonb, 'no_teacher', false);
  end if;
  select id into v_branch from app.branch where code = upper(app.import_txt(p_row, 'co_so'));
  if v_branch is null then
    perform app.raise_error('HMT_NAP_CO_SO_SAI', 'Cột co_so không đúng mã cơ sở (ví dụ CS5).');
  end if;
  v_subject := app.import_match_catalog('SUBJECT', coalesce(app.import_txt(p_row, 'mon'), ''));
  if v_subject is null then
    perform app.raise_error('HMT_NAP_MON_SAI', 'Cột mon không có trong danh mục môn.');
  end if;
  if app.import_txt(p_row, 'khoi') !~ '^[0-9]{1,2}$' then
    perform app.raise_error('HMT_NAP_KHOI_SAI', 'Cột khoi phải là số khối, ví dụ 8.');
  end if;
  v_grade := 'K' || lpad(app.import_txt(p_row, 'khoi'), 2, '0'); -- allow-number: độ rộng 2 chữ số của mã khối
  if not exists (select from app.catalog_item where catalog_code = 'GRADE' and code = v_grade and is_active) then
    perform app.raise_error('HMT_NAP_KHOI_SAI', 'Khối không có trong danh mục khối.');
  end if;
  -- Bốn cột mới (Q-187): thiếu thì báo lỗi, không đoán.
  if app.import_txt(p_row, 'nam_hoc') is null or app.import_txt(p_row, 'so_buoi') is null then
    perform app.raise_error('HMT_NAP_THIEU_COT', 'Thiếu cột nam_hoc hoặc so_buoi.');
  end if;
  if v_loai is not null and app.fold_text(v_loai) like '%rieng%' then
    v_type := 'LR';
  else
    v_type := upper(coalesce(app.import_txt(p_row, 'phan_loai'), ''));
    if v_type not in ('CB', 'NC') then
      perform app.raise_error('HMT_NAP_THIEU_COT', 'Lớp chung cần cột phan_loai là CB hoặc NC.');
    end if;
    v_level := upper(coalesce(app.import_txt(p_row, 'trinh_do'), ''));
    if not exists (select from app.catalog_item where catalog_code = 'LEVEL' and code = v_level and is_active) then
      perform app.raise_error('HMT_NAP_THIEU_COT', 'Lớp chung cần cột trinh_do có trong danh mục trình độ (ví dụ A).');
    end if;
  end if;
  v_total := app.import_num(p_row, 'so_buoi')::integer;
  if v_total <= 0 then
    perform app.raise_error('HMT_NAP_SO_SAI', 'Cột so_buoi phải lớn hơn 0 (số buổi còn lại kể từ ngày chốt).');
  end if;
  v_status := app.import_txt(p_row, 'tinh_trang');
  if v_status is null then
    perform app.raise_error('HMT_NAP_THIEU_COT', 'Thiếu giá trị cột tinh_trang.');
  end if;
  v_open := app.fold_text(v_status) not like '%dong%';
  v_slots := app.import_parse_schedule(app.import_txt(p_row, 'lich_hoc'), v_cutover);
  -- Giáo viên (Q-187): ghép GV + ma_gv; không thấy thì cảnh báo và để trống.
  if v_gv is not null then
    select id into v_teacher from app.user_account where staff_code = 'GV' || v_gv;
  end if;
  if v_teacher is null then
    v_no_teacher := true;
    v_warnings := v_warnings || to_jsonb('Chưa ghép được giáo viên (ma_gv) cho lớp này.'::text);
  else
    select jsonb_agg(s || jsonb_build_object('teacher_id', v_teacher)) into v_slots from jsonb_array_elements(v_slots) s;
  end if;
  v_created := app.create_class(jsonb_build_object('branch_id', v_branch, 'year_code', app.import_txt(p_row, 'nam_hoc'), 'subject_code', v_subject,
    'grade_code', v_grade, 'class_type_code', v_type, 'level_code', v_level,
    'max_students', coalesce(app.import_num(p_row, 'si_so_toi_da', false), 0)::integer,
    'start_date', coalesce(app.import_date(p_row, 'ngay_khai_giang', false), v_cutover), 'total_sessions', v_total,
    'legacy_ref', v_legacy, 'slots', v_slots));
  perform app.transition_class((v_created ->> 'id')::uuid, 'DA_TRINH');
  perform app.transition_class((v_created ->> 'id')::uuid, 'DA_XAC_NHAN');
  perform app.transition_class((v_created ->> 'id')::uuid, 'DA_DUYET');
  if not v_open then
    perform app.transition_class((v_created ->> 'id')::uuid, 'DA_DONG');
  end if;
  return jsonb_build_object('status', 'HOP_LE', 'code', v_created ->> 'code', 'message', null, 'warnings', v_warnings,
                            'no_teacher', v_no_teacher, 'legacy_ref', v_legacy);
end;
$$;

-- GHI_DANH (tab 04_GHIDANH): hoc_sinh_ma_cu, ma_lop_cu, tinh_trang_moi, ngay_vao_lop, thoi_luong_buoi, gio_da_hoc_cu, gio_du_kien, gio_da_hoc, gio_con_lai.
-- Mỗi ghi danh một dòng "Số dư đầu kỳ" bằng gio_con_lai, mang ngày chốt (R-V2-33, Q-177). Luật file: gio_con_lai = gio_du_kien − gio_da_hoc (R-V2-32).
-- Học sinh và lớp phải nạp trước (tra theo mã cũ). Trùng (mã học sinh cũ, mã lớp cũ) thì bỏ qua (R-V2-30).
create or replace function app.import_one_enrollment(p_row jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_student_ref text := app.import_txt(p_row, 'hoc_sinh_ma_cu');
  v_class_ref text := app.import_txt(p_row, 'ma_lop_cu');
  v_legacy text;
  v_existing text;
  st app.student;
  c app.class;
  v_status text;
  v_start date;
  v_planned numeric;
  v_studied numeric;
  v_remaining numeric;
  v_hours numeric;
  v_id uuid;
  v_code text;
  v_warnings jsonb := '[]'::jsonb;
begin
  if v_student_ref is null or v_class_ref is null then
    perform app.raise_error('HMT_NAP_THIEU_COT', 'Thiếu cột hoc_sinh_ma_cu hoặc ma_lop_cu.');
  end if;
  v_legacy := v_student_ref || '|' || v_class_ref;
  select code into v_existing from app.enrollment where legacy_ref = v_legacy limit 1;
  if v_existing is not null then
    return jsonb_build_object('status', 'TRUNG', 'code', v_existing, 'message', null, 'warnings', '[]'::jsonb);
  end if;
  select * into st from app.student where legacy_ref = v_student_ref order by created_at, id limit 1;
  if st.id is null then
    perform app.raise_error('HMT_NAP_HOC_SINH_CHUA_CO', 'Không tìm thấy học sinh theo hoc_sinh_ma_cu. Nạp tab Học sinh trước.');
  end if;
  select * into c from app.class where legacy_ref = v_class_ref limit 1;
  if c.id is null then
    perform app.raise_error('HMT_NAP_LOP_CHUA_CO', 'Không tìm thấy lớp theo ma_lop_cu. Nạp tab Lớp trước.');
  end if;
  if st.branch_id is distinct from c.branch_id then
    perform app.raise_error('HMT_NAP_KHAC_CO_SO', 'Học sinh và lớp thuộc hai cơ sở khác nhau.');
  end if;
  v_status := app.import_match_catalog('ENROLLMENT_STATUS', coalesce(app.import_txt(p_row, 'tinh_trang_moi'), ''));
  if v_status is null then
    perform app.raise_error('HMT_NAP_TINH_TRANG_SAI', 'Cột tinh_trang_moi không thuộc 7 tình trạng ghi danh (ví dụ Đang học).');
  end if;
  v_planned := app.import_num(p_row, 'gio_du_kien');
  v_studied := app.import_num(p_row, 'gio_da_hoc');
  v_remaining := app.import_num(p_row, 'gio_con_lai');
  -- Luật R-V2-32: số dư giờ phải khớp dự kiến trừ đã học (sai lệch tối đa 0,01 giờ do làm tròn).
  if abs(v_remaining - (v_planned - v_studied)) > 0.01 then -- allow-number: sai số làm tròn của giờ học
    perform app.raise_error('HMT_NAP_GIO_LECH', 'Giờ còn lại phải bằng giờ dự kiến trừ giờ đã học.');
  end if;
  v_hours := app.import_num(p_row, 'thoi_luong_buoi');
  v_start := app.import_date(p_row, 'ngay_vao_lop', v_status in ('DANG_HOC', 'BAO_LUU'));
  v_code := app.issue_enrollment_code();
  insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code, start_date, legacy_ref)
  values (v_code, st.id, st.parent_id, c.branch_id, c.subject_code, v_status, v_start, v_legacy)
  returning id into v_id;
  -- Tình trạng đang học, bảo lưu: có dòng xếp lớp đang mở (ngày vào lớp). Tình trạng khác: chỉ ghi danh, không xếp lớp.
  if v_status in ('DANG_HOC', 'BAO_LUU') then
    insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values (v_id, c.id, c.branch_id, v_start);
  end if;
  -- Dòng Số dư đầu kỳ, mỗi ghi danh một dòng (R-V2-33). Số dư âm là học trước, vẫn nạp.
  perform app.add_opening_hours(v_id, v_remaining, 'NAP-' || to_char(now(), 'YYYYMMDD'));
  insert into app.legacy_enrollment_check (enrollment_id, branch_id, class_id, student_id, student_legacy_ref, class_legacy_ref, session_hours,
                                           studied_before_hours, planned_hours, studied_hours, remaining_hours, source_tab, source_row)
  values (v_id, c.branch_id, c.id, st.id, v_student_ref, v_class_ref, v_hours, coalesce(app.import_num(p_row, 'gio_da_hoc_cu', false), 0),
          v_planned, v_studied, v_remaining, app.import_txt(p_row, 'nguon_tab'), nullif(app.import_txt(p_row, 'nguon_dong'), '')::integer);
  if v_status in ('DANG_HOC', 'BAO_LUU') and c.status_code <> 'DA_DUYET' then
    v_warnings := v_warnings || to_jsonb('Lớp đã đóng nhưng ghi danh còn đang học.'::text);
  end if;
  return jsonb_build_object('status', 'HOP_LE', 'code', v_code, 'message', null, 'warnings', v_warnings);
end;
$$;

-- BUOI_HOC (tab 07_BUOIHOC): ma_lop_cu, ngay, ma_gv, ten_bai, so_x, so_P, so_KP, so_N, so_M, tinh_trang. Chỉ lưu để đối soát (R-V2-33).
-- Buổi nghỉ lễ ("Huỷ không tính phí" hoặc có so_N) ghi is_cancelled, giờ trừ 0, không tạo buổi bù (Q-186).
create or replace function app.import_one_legacy_session(p_row jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.class;
  v_date date := app.import_date(p_row, 'ngay');
  v_ref text := app.import_txt(p_row, 'ma_lop_cu');
  v_status text := app.import_txt(p_row, 'tinh_trang');
  v_n integer := coalesce(app.import_num(p_row, 'so_N', false), 0)::integer;
begin
  if v_ref is null then
    perform app.raise_error('HMT_NAP_THIEU_COT', 'Thiếu giá trị cột ma_lop_cu.');
  end if;
  select * into c from app.class where legacy_ref = v_ref limit 1;
  if c.id is null then
    perform app.raise_error('HMT_NAP_LOP_CHUA_CO', 'Không tìm thấy lớp theo ma_lop_cu. Nạp tab Lớp trước.');
  end if;
  if exists (select from app.legacy_session_record where class_legacy_ref = v_ref and session_date = v_date) then
    return jsonb_build_object('status', 'TRUNG', 'code', null, 'message', null, 'warnings', '[]'::jsonb);
  end if;
  insert into app.legacy_session_record (branch_id, class_legacy_ref, class_id, session_date, teacher_staff_code, lesson_name,
                                         count_x, count_p, count_kp, count_n, count_m, status_text, is_cancelled, source_tab, source_row)
  values (c.branch_id, v_ref, c.id, v_date, 'GV' || app.import_txt(p_row, 'ma_gv'), app.import_txt(p_row, 'ten_bai'),
          coalesce(app.import_num(p_row, 'so_x', false), 0)::integer, coalesce(app.import_num(p_row, 'so_P', false), 0)::integer,
          coalesce(app.import_num(p_row, 'so_KP', false), 0)::integer, v_n, coalesce(app.import_num(p_row, 'so_M', false), 0)::integer, v_status,
          v_n > 0 and app.fold_text(coalesce(v_status, '')) like '%huy%', app.import_txt(p_row, 'nguon_tab'),
          nullif(app.import_txt(p_row, 'nguon_dong'), '')::integer);
  return jsonb_build_object('status', 'HOP_LE', 'code', null, 'message', null, 'warnings', '[]'::jsonb);
end;
$$;

-- DIEM_DANH (tab 08_DIEMDANH): ma_lop_cu, hoc_sinh_ma_cu, ngay, ky_hieu, trang_thai_moi, tinh_gio, diem_btvn, diem_btvn_goc, nhan_xet. Chỉ lưu để đối soát.
-- Luật R-V2-33: x, P, KP, M tính giờ; N không tính (đọc từ cột tinh_gio của file: "Có" tính giờ).
create or replace function app.import_one_legacy_attendance(p_row jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.class;
  st app.student;
  v_date date := app.import_date(p_row, 'ngay');
  v_class_ref text := app.import_txt(p_row, 'ma_lop_cu');
  v_student_ref text := app.import_txt(p_row, 'hoc_sinh_ma_cu');
  v_counts text := app.import_txt(p_row, 'tinh_gio');
begin
  if v_class_ref is null or v_student_ref is null then
    perform app.raise_error('HMT_NAP_THIEU_COT', 'Thiếu cột ma_lop_cu hoặc hoc_sinh_ma_cu.');
  end if;
  select * into c from app.class where legacy_ref = v_class_ref limit 1;
  if c.id is null then
    perform app.raise_error('HMT_NAP_LOP_CHUA_CO', 'Không tìm thấy lớp theo ma_lop_cu. Nạp tab Lớp trước.');
  end if;
  select * into st from app.student where legacy_ref = v_student_ref order by created_at, id limit 1;
  if st.id is null then
    perform app.raise_error('HMT_NAP_HOC_SINH_CHUA_CO', 'Không tìm thấy học sinh theo hoc_sinh_ma_cu. Nạp tab Học sinh trước.');
  end if;
  if v_counts is null then
    perform app.raise_error('HMT_NAP_THIEU_COT', 'Thiếu giá trị cột tinh_gio (Có hoặc Không).');
  end if;
  if exists (select from app.legacy_attendance_record where class_legacy_ref = v_class_ref and student_legacy_ref = v_student_ref and session_date = v_date) then
    return jsonb_build_object('status', 'TRUNG', 'code', null, 'message', null, 'warnings', '[]'::jsonb);
  end if;
  insert into app.legacy_attendance_record (branch_id, class_legacy_ref, class_id, student_legacy_ref, student_id, session_date, symbol, status_text,
                                            counts_hours, btvn_score, btvn_score_original, teacher_comment, source_tab, source_row)
  values (c.branch_id, v_class_ref, c.id, v_student_ref, st.id, v_date, app.import_txt(p_row, 'ky_hieu'), app.import_txt(p_row, 'trang_thai_moi'),
          app.fold_text(v_counts) in ('co', 'x', 'true', '1'), app.import_num(p_row, 'diem_btvn', false), app.import_num(p_row, 'diem_btvn_goc', false),
          app.import_txt(p_row, 'nhan_xet'), app.import_txt(p_row, 'nguon_tab'), nullif(app.import_txt(p_row, 'nguon_dong'), '')::integer);
  return jsonb_build_object('status', 'HOP_LE', 'code', null, 'message', null, 'warnings', '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Hàm nạp chung: app.import_training_records(loại, hàng, nạp thật, tên file) (Q-188)
-- ---------------------------------------------------------------------------
-- Cùng hợp đồng với app.import_records: chỉ Admin (hai bước); tối đa import_max_rows hàng; xem trước chạy hết rồi hoàn tác; nạp thật ghi nhật ký.
-- Kết quả: {mode, kind, total, imported, duplicates, errors, rows[], summary}. summary.errors_by_type: mã lỗi → các số dòng lỗi;
-- summary.classes_without_teacher: các mã lớp cũ chưa có giáo viên (Q-187).
create or replace function app.import_training_records(
  p_kind text, p_rows jsonb, p_commit boolean default false, p_file_name text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max integer := app.get_setting_int('import_max_rows');
  v_total integer;
  v_result jsonb := '[]'::jsonb;
  v_ok integer := 0;
  v_dup integer := 0;
  v_err integer := 0;
  v_i integer := 0;
  v_rown integer;
  v_row jsonb;
  v_one jsonb;
  v_hint text;
  v_msg text;
  v_state text;
  v_detail text;
  v_final jsonb;
  v_by_type jsonb := '{}'::jsonb;
  v_no_teacher jsonb := '[]'::jsonb;
begin
  -- Luật: chỉ Admin (đã xác thực hai bước) nạp dữ liệu cũ.
  if not app.has_permission('ADMIN', 'TAO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên được nạp dữ liệu cũ.');
  end if;
  if p_kind not in ('LOP', 'GHI_DANH', 'BUOI_HOC', 'DIEM_DANH') then
    perform app.raise_error('HMT_LOAI_NAP_SAI', 'Loại dữ liệu nạp không hợp lệ.');
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows) = 0 then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chưa có dòng nào để nạp.');
  end if;
  v_total := jsonb_array_length(p_rows);
  if v_total > v_max then
    perform app.raise_error('HMT_QUA_NHIEU_DONG', format('File có %s dòng, tối đa %s dòng mỗi lần nạp.', v_total, v_max));
  end if;

  -- Xem trước và nạp dùng chung một đường mã: xem trước chạy hết rồi hoàn tác (ném lỗi mang kết quả ra ngoài).
  begin
    for v_row in select value from jsonb_array_elements(p_rows) loop
      v_i := v_i + 1;
      v_rown := case when jsonb_typeof(v_row) = 'object' and (v_row ->> 'row') ~ '^[0-9]{1,9}$' then (v_row ->> 'row')::integer else v_i end;
      begin
        v_one := case p_kind when 'LOP' then app.import_one_class(v_row) when 'GHI_DANH' then app.import_one_enrollment(v_row)
                             when 'BUOI_HOC' then app.import_one_legacy_session(v_row) else app.import_one_legacy_attendance(v_row) end;
        if v_one ->> 'status' = 'TRUNG' then
          v_dup := v_dup + 1;
        else
          v_ok := v_ok + 1;
          if coalesce((v_one ->> 'no_teacher')::boolean, false) then
            v_no_teacher := v_no_teacher || to_jsonb(v_one ->> 'legacy_ref');
          end if;
        end if;
        v_result := v_result || jsonb_build_object('row', v_rown, 'label', format('Dòng %s', v_rown), 'status', v_one ->> 'status',
                                                   'code', v_one ->> 'code', 'message', v_one ->> 'message',
                                                   'warnings', coalesce(v_one -> 'warnings', '[]'::jsonb));
      exception when others then
        get stacked diagnostics v_hint = pg_exception_hint, v_msg = message_text, v_state = returned_sqlstate;
        v_err := v_err + 1;
        -- Chỉ lấy câu lỗi nghiệp vụ của ta (HMT_*); lỗi lạ chỉ báo mã, không chép nội dung (có thể chứa dữ liệu cá nhân).
        if v_hint not like 'HMT\_%' then
          v_msg := format('Không ghi được dòng này (lỗi hệ thống, mã %s).', v_state);
          v_hint := 'LOI_HE_THONG';
        end if;
        v_by_type := jsonb_set(v_by_type, array[v_hint], coalesce(v_by_type -> v_hint, '[]'::jsonb) || to_jsonb(v_rown));
        v_result := v_result || jsonb_build_object('row', v_rown, 'label', format('Dòng %s', v_rown), 'status', 'LOI', 'code', null,
                                                   'error_code', v_hint, 'message', v_msg);
      end;
    end loop;
    v_final := jsonb_build_object('mode', case when p_commit then 'NHAP' else 'XEM_TRUOC' end, 'kind', p_kind, 'total', v_total,
                                  'imported', v_ok, 'duplicates', v_dup, 'errors', v_err, 'rows', v_result,
                                  'summary', jsonb_build_object('errors_by_type', v_by_type, 'classes_without_teacher', v_no_teacher));
    if not p_commit then
      raise exception using errcode = 'HMT01', message = 'Xem trước nạp dữ liệu (hoàn tác)', detail = v_final::text;
    end if;
  exception when sqlstate 'HMT01' then
    get stacked diagnostics v_detail = pg_exception_detail;
    v_final := v_detail::jsonb;
  end;

  if p_commit then
    insert into app.import_log (kind, importer_id, file_name, rows_total, imported_count, duplicate_count, error_count)
    values (p_kind, auth.uid(), left(nullif(btrim(coalesce(p_file_name, '')), ''), 200), v_total, v_ok, v_dup, v_err); -- allow-number: độ dài tối đa tên file ghi nhật ký
  end if;
  return v_final;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Báo cáo đối soát giờ (Q-187): giờ đã học trong file ghi danh so với điểm danh cũ
-- ---------------------------------------------------------------------------
-- app.legacy_hours_reconciliation(mã lớp cũ): mỗi ghi danh nạp một dòng: giờ đã học ghi trong file ghi danh (gio_da_hoc), giờ tính từ điểm danh cũ
-- (số buổi tính giờ × thời lượng buổi, cộng giờ đã học trước năm gio_da_hoc_cu) và chênh lệch. Chỉ liệt kê dòng lệch khi only_diff = true.
-- Ai gọi: Điểm danh · Duyệt (quản lý cơ sở, Admin), trong cơ sở của mình (RLS bảng đối soát).
create or replace function app.legacy_hours_reconciliation(p_class_legacy_ref text default null, p_only_diff boolean default false)
returns table (class_legacy_ref text, student_legacy_ref text, file_studied_hours numeric, attendance_hours numeric, diff_hours numeric)
language sql
stable
set search_path = ''
as $$
  select r.* from (
    select ec.class_legacy_ref, ec.student_legacy_ref, ec.studied_hours as file_studied_hours,
           ec.studied_before_hours + coalesce((select count(*) from app.legacy_attendance_record a
                                                where a.class_id = ec.class_id and a.student_id = ec.student_id and a.counts_hours), 0) * ec.session_hours as attendance_hours,
           ec.studied_hours - (ec.studied_before_hours + coalesce((select count(*) from app.legacy_attendance_record a
                                                where a.class_id = ec.class_id and a.student_id = ec.student_id and a.counts_hours), 0) * ec.session_hours) as diff_hours
      from app.legacy_enrollment_check ec
     where p_class_legacy_ref is null or ec.class_legacy_ref = p_class_legacy_ref) r
   where not p_only_diff or r.diff_hours <> 0
   order by r.class_legacy_ref, r.student_legacy_ref;
$$;

-- ---------------------------------------------------------------------------
-- 7. Quyền gọi hàm
-- ---------------------------------------------------------------------------
revoke execute on function
  app.import_txt(jsonb, text), app.import_num(jsonb, text, boolean), app.import_date(jsonb, text, boolean), app.import_parse_schedule(text, date),
  app.import_one_class(jsonb), app.import_one_enrollment(jsonb), app.import_one_legacy_session(jsonb), app.import_one_legacy_attendance(jsonb),
  app.import_training_records(text, jsonb, boolean, text), app.legacy_hours_reconciliation(text, boolean)
  from public, anon, authenticated;
grant execute on function app.import_training_records(text, jsonb, boolean, text), app.legacy_hours_reconciliation(text, boolean) to authenticated;

select set_config('hmt.migration', '', false);
