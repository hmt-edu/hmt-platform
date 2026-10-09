-- GĐ0 bước 2: cấp mã nghiệp vụ theo docs/spec/02-chuan-ma-va-danh-muc.md mục "Mã các đối tượng".
-- Cách cấp: bảng đếm khoá dòng (code_counter), không dùng sequence, để KHÔNG nhảy số:
-- giao dịch xin mã bị huỷ thì bộ đếm cũng lùi lại; hai người xin cùng lúc thì người sau
-- chờ người trước (khoá dòng), không trùng. Chốt với anh Trường 10/10/2026.

-- ---------------------------------------------------------------------------
-- Định dạng mã: tiền tố, số chữ số, số bắt đầu. Khai báo ở đây (dữ liệu), không viết
-- cứng trong hàm. Đây là luật lõi (tầng 4): chỉ đổi qua migration.
-- ---------------------------------------------------------------------------
create table app.code_format (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z][A-Z0-9_]*$'),
  name text not null,
  prefix text,
  pad_width integer not null check (pad_width > 0),
  start_value bigint not null check (start_value > 0),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

comment on table app.code_format is 'Định dạng mã nghiệp vụ (tầng 4, luật lõi): đổi qua migration.';

select app.apply_standard('app.code_format');
create trigger code_format_code_immutable before update on app.code_format
  for each row execute function app.tg_code_immutable();

-- Chỉ migration được thêm, sửa định dạng mã.
create or replace function app.tg_code_format_migration_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not app.is_migration() then
    perform app.raise_error('HMT_LUAT_LOI', 'Định dạng mã là luật lõi, chỉ đổi qua migration.');
  end if;
  return new;
end;
$$;

create trigger code_format_migration_only before insert or update on app.code_format
  for each row execute function app.tg_code_format_migration_only();

select set_config('hmt.migration', 'on', false);
insert into app.code_format (code, name, prefix, pad_width, start_value) values
  ('HS', 'Học sinh', 'HS', 6, 1),
  ('PH', 'Phụ huynh', 'PH', 6, 1),
  ('NV', 'Nhân viên', 'NV', 4, 1),
  -- GV/TG giữ số hiện tại; khi nhập dữ liệu thật đặt lại số bắt đầu = số lớn nhất + 1.
  ('GV', 'Giáo viên', 'GV', 4, 2001),
  ('TG', 'Trợ giảng', 'TG', 4, 8001),
  ('LOP', 'Số thứ tự lớp', null, 3, 1),
  ('BAI', 'Số bài trong khung', 'B', 2, 1),
  ('CHUNG_TU', 'Số thứ tự chứng từ theo cơ sở, tháng', null, 4, 1),
  ('PHIEN_BAN_KHUNG', 'Hậu tố phiên bản khung (V2, V3…)', 'V', 1, 1);
select set_config('hmt.migration', '', false);

alter table app.code_format enable row level security;
create policy code_format_read on app.code_format for select to authenticated using (true);
revoke all on app.code_format from anon, authenticated;
grant select on app.code_format to authenticated;

-- ---------------------------------------------------------------------------
-- Bộ đếm: mỗi khoá một dòng (vd 'HS', 'LOP:CS5-2627-TOAN-K08-CB-A', 'CT:PT-CS1-2610').
-- Không ghi nhật ký (đổi mỗi lần cấp mã); mã cấp ra nằm ở bản ghi nghiệp vụ.
-- ---------------------------------------------------------------------------
create table app.code_counter (
  counter_key text primary key,
  last_value bigint not null,
  updated_at timestamptz not null default now()
);

comment on table app.code_counter is 'Bộ đếm cấp mã (khoá dòng, không nhảy số). Chỉ hàm cấp mã ghi.';

alter table app.code_counter enable row level security;
revoke all on app.code_counter from public, anon, authenticated;

-- Luật: bộ đếm không xoá được, không lùi số.
create or replace function app.tg_code_counter_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_OP = 'DELETE' then
    perform app.raise_error('HMT_KHONG_XOA', 'Không xoá được bộ đếm mã.');
  end if;
  if new.last_value < old.last_value then
    perform app.raise_error('HMT_MA_KHONG_LUI', 'Bộ đếm mã không được lùi số (mã đã cấp không dùng lại).');
  end if;
  return new;
end;
$$;

create trigger code_counter_guard before update or delete on app.code_counter
  for each row execute function app.tg_code_counter_guard();

-- ---------------------------------------------------------------------------
-- Lấy số tiếp theo của một khoá. Khoá dòng trong giao dịch hiện tại cho tới khi
-- giao dịch kết thúc; giao dịch huỷ thì số được trả lại (không nhảy số).
-- Ai gọi: chỉ các hàm cấp mã bên dưới (không mở cho API).
-- ---------------------------------------------------------------------------
create or replace function app.next_counter_value(p_key text, p_start bigint)
returns bigint
language plpgsql
set search_path = ''
as $$
declare
  v_value bigint;
begin
  insert into app.code_counter as c (counter_key, last_value)
  values (p_key, p_start)
  on conflict (counter_key)
    do update set last_value = c.last_value + 1, updated_at = now()
  returning c.last_value into v_value;
  return v_value;
end;
$$;

-- Lấy định dạng; báo lỗi nếu chưa khai báo.
create or replace function app.code_format_of(p_code text)
returns app.code_format
language plpgsql
stable
set search_path = ''
as $$
declare
  v_format app.code_format;
begin
  select * into v_format from app.code_format where code = p_code;
  if v_format.id is null then
    perform app.raise_error('HMT_DINH_DANG_MA_KHONG_CO', format('Chưa khai báo định dạng mã %s.', p_code));
  end if;
  return v_format;
end;
$$;

-- ---------------------------------------------------------------------------
-- Cấp mã người: HS000123, PH000045, NV0012, GV2007, TG8002 (spec 02).
-- Ai gọi: hàm nghiệp vụ tạo hồ sơ, trong cùng giao dịch với lệnh tạo.
-- ---------------------------------------------------------------------------
create or replace function app.issue_person_code(p_kind text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_format app.code_format;
  v_number bigint;
begin
  -- Luật: chỉ các loại người trong spec 02.
  if p_kind not in ('HS', 'PH', 'NV', 'GV', 'TG') then
    perform app.raise_error('HMT_LOAI_MA_SAI', format('Không có loại mã người "%s".', p_kind));
  end if;
  v_format := app.code_format_of(p_kind);
  v_number := app.next_counter_value(p_kind, v_format.start_value);
  return v_format.prefix || lpad(v_number::text, v_format.pad_width, '0');
end;
$$;

-- ---------------------------------------------------------------------------
-- Cấp mã lớp: CS-Năm-Môn-Khối-Phânloại-Trìnhđộ-STT (lớp chung),
--             CS-Năm-Môn-Khối-LR-STT (lớp riêng, không có trình độ). Spec 02.
-- STT riêng theo từng tổ hợp đứng trước nó.
-- ---------------------------------------------------------------------------
create or replace function app.issue_class_code(
  p_branch_code text, p_year_code text, p_subject_code text, p_grade_code text,
  p_class_type text, p_level_code text default null)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_format app.code_format := app.code_format_of('LOP');
  v_prefix text;
  v_number bigint;
begin
  -- Luật: cơ sở, năm học đang dùng.
  if not exists (select from app.branch where code = p_branch_code and is_active) then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', format('Cơ sở %s không có hoặc đã Ngừng.', p_branch_code));
  end if;
  if not exists (select from app.academic_year where code = p_year_code and is_active) then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', format('Năm học %s không có hoặc đã Ngừng.', p_year_code));
  end if;

  -- Luật: môn, khối, phân loại lớp đúng danh mục.
  perform app.assert_catalog_code_active('SUBJECT', p_subject_code);
  perform app.assert_catalog_code_active('GRADE', p_grade_code);
  perform app.assert_catalog_code_active('CLASS_TYPE', p_class_type);

  -- Luật: lớp riêng (LR) không có trình độ; lớp CB, NC bắt buộc có trình độ.
  if p_class_type = 'LR' and p_level_code is not null then
    perform app.raise_error('HMT_MA_LOP_SAI', 'Lớp riêng không có trình độ.');
  end if;
  if p_class_type <> 'LR' then
    if p_level_code is null then
      perform app.raise_error('HMT_MA_LOP_SAI', 'Lớp cơ bản, nâng cao phải có trình độ.');
    end if;
    perform app.assert_catalog_code_active('LEVEL', p_level_code);
  end if;

  v_prefix := concat_ws('-', p_branch_code, p_year_code, p_subject_code, p_grade_code, p_class_type, p_level_code);
  v_number := app.next_counter_value('LOP:' || v_prefix, v_format.start_value);
  return v_prefix || '-' || lpad(v_number::text, v_format.pad_width, '0');
end;
$$;

-- ---------------------------------------------------------------------------
-- Mã khung chương trình: Môn-Khối-Cấpđộ-Năm, bản sửa trong cùng năm thêm -V2, -V3…
-- (chốt 10/10/2026). Không có bộ đếm: phiên bản do hàm tạo khung truyền vào;
-- bảng khung (giai đoạn sau) chặn trùng mã.
-- ---------------------------------------------------------------------------
create or replace function app.build_framework_code(
  p_subject_code text, p_grade_code text, p_framework_level text, p_year_code text,
  p_version integer default 1)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_version_format app.code_format := app.code_format_of('PHIEN_BAN_KHUNG');
  v_code text;
begin
  perform app.assert_catalog_code_active('SUBJECT', p_subject_code);
  perform app.assert_catalog_code_active('GRADE', p_grade_code);
  perform app.assert_catalog_code_active('FRAMEWORK_LEVEL', p_framework_level);
  if not exists (select from app.academic_year where code = p_year_code) then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', format('Năm học %s không có.', p_year_code));
  end if;

  -- Luật: phiên bản bắt đầu từ 1; bản 1 không có hậu tố.
  if p_version is null or p_version < v_version_format.start_value then
    perform app.raise_error('HMT_PHIEN_BAN_SAI', 'Phiên bản khung phải từ 1 trở lên.');
  end if;

  v_code := concat_ws('-', p_subject_code, p_grade_code, p_framework_level, p_year_code);
  if p_version > v_version_format.start_value then
    v_code := v_code || '-' || v_version_format.prefix || p_version::text;
  end if;
  return v_code;
end;
$$;

-- Mã bài học: mã khung + -B + số bài (2 chữ số), vd TOAN-K03-CB-2627-B05.
create or replace function app.build_lesson_code(p_framework_code text, p_lesson_no integer)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v_format app.code_format := app.code_format_of('BAI');
begin
  if p_lesson_no is null or p_lesson_no < v_format.start_value then
    perform app.raise_error('HMT_SO_BAI_SAI', 'Số bài phải từ 1 trở lên.');
  end if;
  return p_framework_code || '-' || v_format.prefix || lpad(p_lesson_no::text, v_format.pad_width, '0');
end;
$$;

-- Mã gói bán: Loại-Môn-Khối-Hìnhthức, vd LC-TOAN-K09-OFF. Giá ở bảng giá riêng.
create or replace function app.build_package_code(
  p_package_type text, p_subject_code text, p_grade_code text, p_study_mode text)
returns text
language plpgsql
stable
set search_path = ''
as $$
begin
  -- Luật: loại gói viết hoa không dấu (danh mục loại gói khai báo ở giai đoạn 1).
  if p_package_type is null or p_package_type !~ '^[A-Z][A-Z0-9]*$' then
    perform app.raise_error('HMT_LOAI_GOI_SAI', 'Loại gói phải viết hoa, không dấu, không khoảng trắng.');
  end if;
  -- Luật: gói chỉ có môn TOAN, không có DAI, HINH (spec 02 mục Toán tách Đại/Hình).
  if p_subject_code in ('DAI', 'HINH') then
    perform app.raise_error('HMT_GOI_KHONG_TACH_DAI_HINH', 'Gói bán dùng môn TOAN, không có gói Đại số, Hình học riêng.');
  end if;
  perform app.assert_catalog_code_active('SUBJECT', p_subject_code);
  perform app.assert_catalog_code_active('GRADE', p_grade_code);
  perform app.assert_catalog_code_active('STUDY_MODE', p_study_mode);
  return concat_ws('-', p_package_type, p_subject_code, p_grade_code, p_study_mode);
end;
$$;

-- ---------------------------------------------------------------------------
-- Cấp số chứng từ: Loại-CS-NămTháng-STT, vd PT-CS1-2610-0001 (spec 02).
-- Số thứ tự riêng từng cơ sở, từng tháng (giờ Việt Nam), liên tục, không nhảy số.
-- Ai gọi: hàm tạo chứng từ, trong cùng giao dịch với lệnh tạo.
-- ---------------------------------------------------------------------------
create or replace function app.issue_document_number(
  p_doc_type text, p_branch_code text, p_at timestamptz default now())
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_format app.code_format := app.code_format_of('CHUNG_TU');
  v_prefix text;
  v_number bigint;
begin
  perform app.assert_catalog_code_active('DOC_TYPE', p_doc_type);
  if not exists (select from app.branch where code = p_branch_code and is_active) then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', format('Cơ sở %s không có hoặc đã Ngừng.', p_branch_code));
  end if;

  -- Luật: tháng tính theo giờ Việt Nam.
  v_prefix := concat_ws('-', p_doc_type, p_branch_code, to_char(p_at at time zone 'Asia/Ho_Chi_Minh', 'YYMM'));
  v_number := app.next_counter_value('CT:' || v_prefix, v_format.start_value);
  return v_prefix || '-' || lpad(v_number::text, v_format.pad_width, '0');
end;
$$;

-- ---------------------------------------------------------------------------
-- Luật lõi loại buổi (chốt 10/10/2026): CHINH, CUNG_CO trừ giờ; HOC_BU, BO_TRO không.
-- ---------------------------------------------------------------------------
create or replace function app.session_type_deducts_hours(p_session_type text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
begin
  -- Luật: buổi chính, buổi củng cố trừ giờ.
  if p_session_type in ('CHINH', 'CUNG_CO') then
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

revoke execute on function
  app.next_counter_value(text, bigint),
  app.issue_person_code(text),
  app.issue_class_code(text, text, text, text, text, text),
  app.issue_document_number(text, text, timestamptz)
  from public, anon, authenticated;
grant execute on function
  app.build_framework_code(text, text, text, text, integer),
  app.build_lesson_code(text, integer),
  app.build_package_code(text, text, text, text),
  app.session_type_deducts_hours(text)
  to authenticated;
