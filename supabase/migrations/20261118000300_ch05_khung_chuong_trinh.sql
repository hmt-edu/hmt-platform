-- CH-05, CH-06 Khung chương trình (Code A, 18/11/2026): bảng khung và bài học, hàm danh sách, xem, tạo khung, tạo bản mới, ngừng, thêm/sửa bài, đổi thứ tự bài.
-- Luật: R-LOP-07 (khung chương trình; 18/11/2026 anh Trường chốt: tạo bản mới SAO CHÉP TOÀN BỘ bài từ bản trước; bản đầu chưa khoá sửa bài, kể cả khi đã có lớp dùng vì lớp chỉ lưu tên khung dạng chữ),
-- spec 02 (mã khung `Môn-Khối-Cấpđộ-Năm`; bản đầu không hậu tố, bản kế `-v2`, `-v3`...; lớp cũ giữ khung cũ), khung canvas 1aab (CH05_*, CH06_*): trạng thái chỉ Đang dùng, Ngừng; không xoá bài; mã bài không đổi khi kéo.
-- Quyền: phân hệ CONFIG_TRAINING có sẵn (migration 22): Admin đủ quyền toàn hệ thống; Trưởng cơ sở, CSKH, giáo viên, trợ giảng chỉ Xem. Không đổi ma trận quyền.
-- Không xoá cứng: Ngừng là đổi trạng thái. Bài học không có hàm xoá.

-- ---------------------------------------------------------------------------
-- 1. Bảng khung và bài học
-- ---------------------------------------------------------------------------
create table app.curriculum_frame (
  id uuid not null unique default gen_random_uuid(),
  code text primary key,
  subject_catalog text not null default 'SUBJECT' check (subject_catalog = 'SUBJECT'),
  subject_code text not null,
  grade_catalog text not null default 'GRADE' check (grade_catalog = 'GRADE'),
  grade_code text not null,
  -- Cấp độ của khung: Cơ bản, Nâng cao (danh mục CLASS_TYPE, không dùng Lớp riêng).
  level_catalog text not null default 'CLASS_TYPE' check (level_catalog = 'CLASS_TYPE'),
  level_code text not null check (level_code in ('CB', 'NC')),
  -- Năm học dạng hai số cuối của hai năm liền nhau: 2627 là 2026–2027.
  year_code text not null check (year_code ~ '^[0-9]{4}$' and substr(year_code, 3, 2)::integer = substr(year_code, 1, 2)::integer + 1),
  version integer not null default 1 check (version >= 1),
  status_code text not null default 'DANG_DUNG' check (status_code in ('DANG_DUNG', 'NGUNG')),
  prev_frame_id uuid references app.curriculum_frame (id),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (subject_catalog, subject_code) references app.catalog_item (catalog_code, code),
  foreign key (grade_catalog, grade_code) references app.catalog_item (catalog_code, code),
  foreign key (level_catalog, level_code) references app.catalog_item (catalog_code, code),
  unique (subject_code, grade_code, level_code, year_code, version)
);
comment on table app.curriculum_frame is 'Khung chương trình (R-LOP-07, CH-05). Mã Môn-Khối-Cấpđộ-Năm, bản kế thêm -v2, -v3; sửa khung thì tạo bản mới, lớp cũ giữ khung cũ.';
-- Chỉ mục (lý do): danh sách lọc theo trạng thái, môn, khối, sắp theo mã; khoá ngoại bản trước; (môn, khối, cấp độ, năm) đã có chỉ mục duy nhất kèm phiên bản.
create index curriculum_frame_list_idx on app.curriculum_frame (status_code, subject_code, grade_code);
create index curriculum_frame_prev_idx on app.curriculum_frame (prev_frame_id) where prev_frame_id is not null;
select app.apply_standard('app.curriculum_frame');

create table app.curriculum_lesson (
  id uuid primary key default gen_random_uuid(),
  frame_id uuid not null references app.curriculum_frame (id),
  -- Vị trí hiện tại trong khung (đổi khi kéo); số «Bài N» hiển thị lấy từ đây.
  position integer not null check (position >= 1),
  -- Mã bài `<mã khung>-Bnn`: cấp một lần khi tạo bài, KHÔNG đổi khi kéo thứ tự (khung canvas 1aab).
  code text not null unique,
  title text not null check (btrim(title) <> ''),
  hint text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  -- Đổi chỗ hai bài trong một giao dịch: kiểm trùng vị trí ở cuối giao dịch.
  unique (frame_id, position) deferrable initially deferred
);
comment on table app.curriculum_lesson is 'Bài học của khung chương trình (CH-06): thứ tự, tên bài (dùng làm nhãn bài từng buổi), nội dung gợi ý. Không xoá bài.';
-- Chỉ mục (lý do): đọc bài theo khung theo thứ tự (khoá duy nhất (frame_id, position) phục vụ).
select app.apply_standard('app.curriculum_lesson');

alter table app.curriculum_frame enable row level security;
alter table app.curriculum_lesson enable row level security;
grant select on app.curriculum_frame, app.curriculum_lesson to authenticated;
-- Đọc: ai có Cấu hình đào tạo · Xem (mọi vai trò nhân viên); quyền thật kiểm cả trong hàm.
create policy curriculum_frame_read on app.curriculum_frame for select to authenticated
  using ((select app.permission_scope('CONFIG_TRAINING', 'XEM')) is not null);
create policy curriculum_lesson_read on app.curriculum_lesson for select to authenticated
  using ((select app.permission_scope('CONFIG_TRAINING', 'XEM')) is not null);

-- ---------------------------------------------------------------------------
-- 2. Hàm trợ giúp nội bộ
-- ---------------------------------------------------------------------------
-- Mã khung từ bốn phần và phiên bản: bản 1 không hậu tố, bản N (N >= 2) thêm -vN.
create or replace function app.curriculum_frame_code(p_subject text, p_grade text, p_level text, p_year text, p_version integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select p_subject || '-' || p_grade || '-' || p_level || '-' || p_year
         || case when p_version >= 2 then '-v' || p_version::text else '' end; -- allow-number: bản đầu không hậu tố
$$;

-- Kiểm quyền Cấu hình đào tạo theo hành động; báo lỗi có mã nếu thiếu.
create or replace function app.assert_curriculum_permission(p_action text)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if app.permission_scope('CONFIG_TRAINING', p_action) is distinct from 'TOAN_HE_THONG' then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', case p_action when 'XEM' then 'Bạn không có quyền xem khung chương trình.' else 'Bạn không có quyền thay đổi khung chương trình.' end);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Danh sách, xem khung
-- ---------------------------------------------------------------------------
-- app.list_curriculum_frames(bộ lọc, giới hạn, vị trí) -> {total, rows}
-- Ai gọi: Cấu hình đào tạo · Xem. Bộ lọc (jsonb): status (mảng), subject, grade, level, year. Phân trang ở máy chủ (mặc định 50, tối đa 100), sắp theo mã.
create or replace function app.list_curriculum_frames(p_filters jsonb default '{}'::jsonb, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100); -- allow-number: trần phân trang theo quy ước hiệu năng
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := case when jsonb_typeof(p_filters -> 'status') = 'array' then array(select jsonb_array_elements_text(p_filters -> 'status')) end;
  v_subject text := nullif(p_filters ->> 'subject', '');
  v_grade text := nullif(p_filters ->> 'grade', '');
  v_level text := nullif(p_filters ->> 'level', '');
  v_year text := nullif(p_filters ->> 'year', '');
  v_total bigint;
  v_rows jsonb;
begin
  -- Quyền xem: mọi vai trò có Cấu hình đào tạo · Xem.
  if app.permission_scope('CONFIG_TRAINING', 'XEM') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem khung chương trình.');
  end if;
  select count(*) into v_total from app.curriculum_frame f
   where (v_status is null or f.status_code = any (v_status))
     and (v_subject is null or f.subject_code = v_subject) and (v_grade is null or f.grade_code = v_grade)
     and (v_level is null or f.level_code = v_level) and (v_year is null or f.year_code = v_year);
  select coalesce(jsonb_agg(r order by r.sort_key), '[]'::jsonb) into v_rows
    from (
      select f.code as sort_key,
             jsonb_build_object(
               'id', f.id, 'code', f.code, 'subject_code', f.subject_code,
               'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = f.subject_code),
               'grade_code', f.grade_code,
               'grade_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'GRADE' and ci.code = f.grade_code),
               'level_code', f.level_code,
               'level_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_TYPE' and ci.code = f.level_code),
               'year_code', f.year_code, 'version', f.version, 'status_code', f.status_code,
               'lesson_count', (select count(*) from app.curriculum_lesson l where l.frame_id = f.id)) as r
        from app.curriculum_frame f
       where (v_status is null or f.status_code = any (v_status))
         and (v_subject is null or f.subject_code = v_subject) and (v_grade is null or f.grade_code = v_grade)
         and (v_level is null or f.level_code = v_level) and (v_year is null or f.year_code = v_year)
       order by f.code
       limit v_limit offset v_offset) q;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.get_curriculum_frame(id) -> {frame, lessons}: một khung kèm các bài theo thứ tự. Ai gọi: Cấu hình đào tạo · Xem.
create or replace function app.get_curriculum_frame(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  f app.curriculum_frame;
begin
  if app.permission_scope('CONFIG_TRAINING', 'XEM') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem khung chương trình.');
  end if;
  select * into f from app.curriculum_frame where id = p_id;
  if f.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy khung chương trình.');
  end if;
  return jsonb_build_object(
    'frame', jsonb_build_object(
      'id', f.id, 'code', f.code, 'status_code', f.status_code, 'version', f.version, 'year_code', f.year_code,
      'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = f.subject_code),
      'grade_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'GRADE' and ci.code = f.grade_code),
      'level_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_TYPE' and ci.code = f.level_code)),
    'lessons', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'position', l.position, 'code', l.code, 'title', l.title, 'hint', l.hint) order by l.position)
                           from app.curriculum_lesson l where l.frame_id = f.id), '[]'::jsonb));
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Tạo khung, tạo bản mới, ngừng
-- ---------------------------------------------------------------------------
-- app.create_curriculum_frame(môn, khối, cấp độ, năm học) -> {id, code}: tạo bản đầu (không hậu tố, chưa có bài). Ai gọi: Cấu hình đào tạo · Tạo (Admin).
-- Luật: môn, khối, cấp độ phải còn dùng trong danh mục; cấp độ chỉ CB, NC; một bộ (môn, khối, cấp độ, năm) chỉ có một bản đầu, muốn sửa thì Tạo bản mới.
create or replace function app.create_curriculum_frame(p_subject text, p_grade text, p_level text, p_year text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_code text;
begin
  perform app.assert_curriculum_permission('TAO');
  perform app.assert_catalog_code_active('SUBJECT', p_subject);
  perform app.assert_catalog_code_active('GRADE', p_grade);
  if p_level is null or p_level not in ('CB', 'NC') then
    perform app.raise_error('HMT_CAP_DO_KHONG_HOP_LE', 'Cấp độ khung chương trình chỉ là Cơ bản hoặc Nâng cao.');
  end if;
  if p_year is null or p_year !~ '^[0-9]{4}$' or substr(p_year, 3, 2)::integer <> substr(p_year, 1, 2)::integer + 1 then
    perform app.raise_error('HMT_NAM_HOC_KHONG_HOP_LE', 'Năm học phải có dạng hai số cuối của hai năm liền nhau, ví dụ 2627 là 2026–2027.');
  end if;
  if exists (select from app.curriculum_frame where subject_code = p_subject and grade_code = p_grade and level_code = p_level and year_code = p_year) then
    perform app.raise_error('HMT_KHUNG_DA_CO', 'Khung này đã có. Muốn thay đổi, bấm Tạo bản mới ở dòng của khung.');
  end if;
  v_code := app.curriculum_frame_code(p_subject, p_grade, p_level, p_year, 1);
  insert into app.curriculum_frame (code, subject_code, grade_code, level_code, year_code, version)
  values (v_code, p_subject, p_grade, p_level, p_year, 1) returning id into v_id;
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

-- app.create_curriculum_version(id khung nguồn) -> {id, code}: tạo bản kế (-v2, -v3...) và SAO CHÉP TOÀN BỘ bài từ bản nguồn (R-LOP-07, 18/11/2026).
-- Ai gọi: Cấu hình đào tạo · Tạo. Bản kế lấy số lớn nhất của cùng (môn, khối, cấp độ, năm) cộng một; bản nguồn giữ nguyên. Bài sao chép giữ thứ tự, tên, gợi ý, đuôi mã bài (Bnn), đổi tiền tố theo mã khung mới.
create or replace function app.create_curriculum_version(p_from_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  src app.curriculum_frame;
  v_next integer;
  v_id uuid;
  v_code text;
begin
  perform app.assert_curriculum_permission('TAO');
  select * into src from app.curriculum_frame where id = p_from_id for update;
  if src.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy khung chương trình.');
  end if;
  -- Khoá cả nhóm cùng (môn, khối, cấp độ, năm) để hai người tạo bản kế cùng lúc không trùng số.
  perform pg_advisory_xact_lock(hashtextextended(src.subject_code || src.grade_code || src.level_code || src.year_code, 0));
  select max(version) + 1 into v_next from app.curriculum_frame
   where subject_code = src.subject_code and grade_code = src.grade_code and level_code = src.level_code and year_code = src.year_code;
  v_code := app.curriculum_frame_code(src.subject_code, src.grade_code, src.level_code, src.year_code, v_next);
  insert into app.curriculum_frame (code, subject_code, grade_code, level_code, year_code, version, prev_frame_id)
  values (v_code, src.subject_code, src.grade_code, src.level_code, src.year_code, v_next, src.id) returning id into v_id;
  insert into app.curriculum_lesson (frame_id, position, code, title, hint)
  select v_id, l.position, v_code || substr(l.code, length(src.code) + 1), l.title, l.hint
    from app.curriculum_lesson l where l.frame_id = src.id;
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

-- app.set_curriculum_frame_active(id, dùng) -> void: Ngừng hoặc Dùng lại một khung. Ai gọi: Cấu hình đào tạo · Huỷ (ngừng), Sửa (dùng lại). Không xoá khung.
create or replace function app.set_curriculum_frame_active(p_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_curriculum_permission(case when p_active then 'SUA' else 'HUY' end);
  update app.curriculum_frame set status_code = case when p_active then 'DANG_DUNG' else 'NGUNG' end where id = p_id;
  if not found then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy khung chương trình.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Bài học: thêm, sửa, đổi thứ tự (không có hàm xoá)
-- ---------------------------------------------------------------------------
-- app.save_curriculum_lesson(khung, bài, tên, gợi ý) -> {id, code}: thêm bài (bài rỗng) vào cuối khung hoặc sửa tên, gợi ý một bài. Ai gọi: Cấu hình đào tạo · Sửa.
-- Luật: tên bài bắt buộc (dùng làm nhãn bài từng buổi); mã bài cấp một lần `<mã khung>-Bnn` (nn = số lớn nhất đã cấp cộng một), không đổi khi sửa hay kéo; bản đầu chưa khoá sửa bài kể cả khi đã có lớp dùng (R-LOP-07).
create or replace function app.save_curriculum_lesson(p_frame_id uuid, p_lesson_id uuid, p_title text, p_hint text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  f app.curriculum_frame;
  l app.curriculum_lesson;
  v_title text := btrim(coalesce(p_title, ''));
  v_next integer;
  v_id uuid;
  v_code text;
begin
  perform app.assert_curriculum_permission('SUA');
  select * into f from app.curriculum_frame where id = p_frame_id for update;
  if f.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy khung chương trình.');
  end if;
  if v_title = '' then
    perform app.raise_error('HMT_THIEU_TEN_BAI', 'Nhập tên bài.');
  end if;
  if p_lesson_id is null then
    -- Thêm vào cuối khung; số mã bài không dùng lại vì bài không bao giờ bị xoá.
    select coalesce(max(substr(code, length(f.code) + 3)::integer), 0) + 1 into v_next from app.curriculum_lesson where frame_id = f.id;
    v_code := f.code || '-B' || lpad(v_next::text, 2, '0'); -- allow-number: độ rộng hai chữ số của số bài trong mã
    insert into app.curriculum_lesson (frame_id, position, code, title, hint)
    values (f.id, coalesce((select max(position) from app.curriculum_lesson where frame_id = f.id), 0) + 1, v_code, v_title, nullif(btrim(coalesce(p_hint, '')), ''))
    returning id into v_id;
  else
    select * into l from app.curriculum_lesson where id = p_lesson_id and frame_id = f.id for update;
    if l.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy bài học trong khung này.');
    end if;
    update app.curriculum_lesson set title = v_title, hint = nullif(btrim(coalesce(p_hint, '')), '') where id = l.id;
    v_id := l.id;
    v_code := l.code;
  end if;
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

-- app.reorder_curriculum_lessons(khung, danh sách mã bài mới theo thứ tự) -> void: đổi thứ tự bài. Ai gọi: Cấu hình đào tạo · Sửa.
-- Luật: danh sách phải gồm đúng tất cả bài của khung, mỗi bài một lần (không thêm, không bớt bài); mã bài KHÔNG đổi, chỉ đổi vị trí.
create or replace function app.reorder_curriculum_lessons(p_frame_id uuid, p_order uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  perform app.assert_curriculum_permission('SUA');
  perform 1 from app.curriculum_frame where id = p_frame_id for update;
  if not found then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy khung chương trình.');
  end if;
  select count(*) into v_count from app.curriculum_lesson where frame_id = p_frame_id;
  if p_order is null or coalesce(array_length(p_order, 1), 0) <> v_count
     or (select count(distinct x) from unnest(p_order) x) <> v_count
     or exists (select from unnest(p_order) x where not exists (select from app.curriculum_lesson l where l.id = x and l.frame_id = p_frame_id)) then
    perform app.raise_error('HMT_THU_TU_BAI_SAI', 'Danh sách thứ tự phải gồm đúng tất cả bài của khung, mỗi bài một lần.');
  end if;
  update app.curriculum_lesson l set position = o.n
    from (select x as id, row_number() over () as n from unnest(p_order) x) o
   where l.id = o.id and l.frame_id = p_frame_id and l.position is distinct from o.n;
end;
$$;

revoke execute on function
  app.curriculum_frame_code(text, text, text, text, integer), app.assert_curriculum_permission(text),
  app.list_curriculum_frames(jsonb, integer, integer), app.get_curriculum_frame(uuid), app.create_curriculum_frame(text, text, text, text),
  app.create_curriculum_version(uuid), app.set_curriculum_frame_active(uuid, boolean), app.save_curriculum_lesson(uuid, uuid, text, text),
  app.reorder_curriculum_lessons(uuid, uuid[])
  from public, anon, authenticated;
grant execute on function
  app.list_curriculum_frames(jsonb, integer, integer), app.get_curriculum_frame(uuid), app.create_curriculum_frame(text, text, text, text),
  app.create_curriculum_version(uuid), app.set_curriculum_frame_active(uuid, boolean), app.save_curriculum_lesson(uuid, uuid, text, text),
  app.reorder_curriculum_lessons(uuid, uuid[])
  to authenticated;
