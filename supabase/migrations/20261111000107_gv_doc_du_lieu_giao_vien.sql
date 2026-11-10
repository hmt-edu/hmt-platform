-- GV (Code 2, 10/11/2026): dữ liệu đọc cho cổng Giáo viên và bảng nội dung buổi (GV-02, GV-04, GV-05, GV-06, GV-12).
-- Luật: R-GV-08, R-GV-13, R-GIO-06, R-GIO-08, R-V2-35 (BTVN tuỳ giáo viên, để trống = không giao), R-V2-37 (GV-02 chỉ buổi trong ngày), Q-208.
-- Làm gì: bảng nội dung buổi; hàm lưu nội dung; hàm "buổi của tôi"; hàm danh sách em của buổi; điều kiện "có nội dung buổi" của lý do chưa Done khi tham số Tắt.
-- Chạy sau migration 103 (D2): dùng app.session_visible và app.session_pending_reason của D2.

-- ---------------------------------------------------------------------------
-- 1. Nội dung buổi và BTVN giao mới (GV-06)
-- ---------------------------------------------------------------------------
-- Một dòng cho mỗi buổi; BTVN để trống nghĩa là buổi này không giao (R-V2-35), không có ô tích riêng.
create table app.session_content (
  -- Cột id để nhật ký thao tác (app.tg_audit) ghi được; khoá chính vẫn là session_id.
  id uuid not null unique default gen_random_uuid(),
  session_id uuid primary key references app.class_session (id),
  branch_id uuid not null references app.branch (id),
  homework_text text check (homework_text is null or btrim(homework_text) <> ''),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.session_content is 'Nội dung buổi và BTVN giao mới (GV-06). BTVN trống = buổi này không giao (R-V2-35). Ghi chỉ qua app.save_session_content.';
-- Chỉ mục (lý do): cơ sở cho RLS.
create index session_content_branch_idx on app.session_content (branch_id);
select app.apply_standard('app.session_content');

-- Mỗi dòng nội dung là một mục dạy trong buổi (GV-06: cần ít nhất một dòng).
create table app.session_content_line (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references app.class_session (id),
  branch_id uuid not null references app.branch (id),
  sort_order integer not null check (sort_order >= 1),
  line_text text not null check (btrim(line_text) <> ''),
  -- Không xoá cứng: dòng bị bỏ khi lưu lại thì đặt is_active = false.
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (session_id, sort_order)
);
comment on table app.session_content_line is 'Các dòng nội dung buổi (GV-06). Lưu lại là thay cả bộ dòng của buổi: dòng bị bỏ đặt is_active = false (không xoá cứng).';
-- Chỉ mục (lý do): khoá (session_id, sort_order) đã phủ việc đọc dòng của một buổi; cơ sở cho RLS.
create index session_content_line_branch_idx on app.session_content_line (branch_id);
select app.apply_standard('app.session_content_line');

alter table app.session_content enable row level security;
alter table app.session_content_line enable row level security;
grant select on app.session_content, app.session_content_line to authenticated;
create policy session_content_read on app.session_content for select to authenticated
  using ((select app.session_visible(session_id)));
create policy session_content_line_read on app.session_content_line for select to authenticated
  using ((select app.session_visible(session_id)));

-- ---------------------------------------------------------------------------
-- 2. Lưu nội dung buổi
-- ---------------------------------------------------------------------------
-- app.session_has_content(buổi): đã có ít nhất một dòng nội dung. Dùng cho lý do chưa Done và màn tiến độ (R-V2-35).
create or replace function app.session_has_content(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.session_content_line where session_id = p_session_id and is_active);
$$;

-- app.save_session_content(buổi, các dòng, BTVN): lưu cả bộ nội dung buổi một lần (không tự lưu, GV-06).
-- Ai gọi: giáo viên, trợ giảng của buổi, hoặc vận hành có quyền Điểm danh · Sửa. Kết quả: số dòng đã lưu.
-- Luật: R-V2-35 cần ít nhất một dòng nội dung, BTVN trống = không giao; R-GIO-08 nhập được trước khi chốt; R-GV-08 buổi Done thì giáo viên không sửa.
create or replace function app.save_session_content(p_session_id uuid, p_lines text[], p_homework text default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_lines text[];
  v_homework text := nullif(btrim(coalesce(p_homework, '')), '');
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA');
  -- Luật R-GV-08: buổi Done, huỷ hoặc đã bị thay thì không sửa nội dung (sửa qua ticket cho vận hành).
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: giáo viên không sửa nội dung buổi. Tạo ticket cho vận hành để sửa kèm lý do.');
  end if;
  if s.status_code not in ('NHAP', 'DA_CHOT') then
    perform app.raise_error('HMT_BUOI_KHONG_SUA', 'Buổi đã huỷ hoặc đã được thay bằng lịch mới nên không lưu nội dung.');
  end if;
  -- Luật R-V2-35: cần ít nhất một dòng nội dung (bỏ dòng trống).
  select coalesce(array_agg(btrim(t) order by o), '{}') into v_lines
    from unnest(coalesce(p_lines, '{}')) with ordinality as x (t, o) where btrim(coalesce(t, '')) <> '';
  if cardinality(v_lines) = 0 then
    perform app.raise_error('HMT_THIEU_NOI_DUNG', 'Cần ít nhất một dòng nội dung buổi.');
  end if;
  insert into app.session_content (session_id, branch_id, homework_text) values (s.id, s.branch_id, v_homework)
  on conflict (session_id) do update set homework_text = excluded.homework_text, updated_at = now(), updated_by = auth.uid();
  -- Không xoá cứng: tắt cả bộ dòng cũ rồi ghi đè theo số thứ tự (dòng nào còn thì bật lại).
  update app.session_content_line set is_active = false where session_id = s.id and is_active;
  insert into app.session_content_line (session_id, branch_id, sort_order, line_text)
  select s.id, s.branch_id, o::integer, t from unnest(v_lines) with ordinality as x (t, o)
  on conflict (session_id, sort_order) do update set line_text = excluded.line_text, is_active = true, updated_at = now(), updated_by = auth.uid();
  return cardinality(v_lines);
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Đọc dữ liệu cho giáo viên
-- ---------------------------------------------------------------------------
-- app.teacher_my_sessions(chế độ, từ ngày, đến ngày, số dòng, bỏ qua): buổi mà người đang đăng nhập là giáo viên hoặc trợ giảng.
-- Chế độ 'NGAY': buổi có ngày trong khoảng (GV-02 Hôm nay, GV-03 Lịch: không hiện buổi huỷ hay đã bị thay; R-V2-37 chỉ trong ngày).
-- Chế độ 'CAN_LAM': buổi đã kết thúc mà chưa Done và không huỷ, kể cả quá hạn (GV-12 Cần làm, R-V2-37).
-- Kết quả: json gồm tổng và các dòng; mỗi dòng có hạn hoàn tất (R-GV-05) và lý do chưa Done. Phân trang ở máy chủ, mặc định 50, tối đa 100.
-- Luật: R-GV-08 chỉ buổi của mình; R-GV-13 không có thông tin phụ huynh, học phí.
create or replace function app.teacher_my_sessions(p_mode text default 'NGAY', p_from date default null, p_to date default null,
                                                   p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100); -- allow-number: trần phân trang theo quy ước hiệu năng
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_from date := coalesce(p_from, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
  v_to date := coalesce(p_to, coalesce(p_from, (now() at time zone 'Asia/Ho_Chi_Minh')::date));
  v_total bigint;
  v_rows jsonb;
begin
  if app.permission_scope('ATTENDANCE', 'XEM') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem buổi dạy.');
  end if;
  if p_mode not in ('NGAY', 'CAN_LAM') then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Chế độ xem buổi không hợp lệ.');
  end if;
  with mine as (
    select s.* from app.class_session s
     where auth.uid() in (s.teacher_id, s.assistant_id)
       and s.status_code <> 'DA_THAY'
       and case p_mode
             when 'NGAY' then s.session_date between v_from and v_to and s.status_code in ('NHAP', 'DA_CHOT', 'DONE')
             else s.status_code in ('NHAP', 'DA_CHOT') and app.session_ends_at(s.id) <= now()
           end
  ), page as (
    select * from mine order by session_date, start_time, id limit v_limit offset v_offset
  )
  select (select count(*) from mine),
         coalesce(jsonb_agg(jsonb_build_object(
           'session_id', p.id, 'class_id', p.class_id, 'class_code', c.code,
           'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
           'session_no', p.session_no, 'session_date', p.session_date, 'start_time', p.start_time, 'end_time', p.end_time,
           'type_code', p.type_code, 'status_code', p.status_code,
           'my_role', case when p.teacher_id = auth.uid() then 'GIAO_VIEN' else 'TRO_GIANG' end,
           'has_content', app.session_has_content(p.id),
           'deadline_at', app.session_ends_at(p.id) + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', p.branch_id)::integer),
           'pending_reason', case when p.status_code = 'DONE' then null else app.session_pending_reason(p.id) end)
           order by p.session_date, p.start_time, p.id), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.class c on c.id = p.class_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.teacher_session_students(buổi): danh sách em của buổi cho giáo viên (GV-05, GV-07).
-- Luật: R-GIO-08 chưa Đã chốt thì không hiện danh sách; R-GV-13 chỉ tên, mã và trạng thái điểm danh, không có số điện thoại, học phí, phụ huynh;
-- em bị loại khỏi danh sách (R-DD) không hiện.
create or replace function app.teacher_session_students(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  if s.status_code not in ('DA_CHOT', 'DONE') then
    return jsonb_build_object('status_code', s.status_code, 'listed', false, 'students', '[]'::jsonb);
  end if;
  return jsonb_build_object('status_code', s.status_code, 'listed', true, 'students', coalesce((
    select jsonb_agg(jsonb_build_object(
             'attendance_id', sa.id, 'student_id', st.id, 'student_code', st.code, 'full_name', st.full_name,
             'is_trial', sa.is_trial, 'teacher_status_code', sa.teacher_status_code)
           order by st.full_name, st.id)
      from app.session_attendance sa join app.student st on st.id = sa.student_id
     where sa.session_id = s.id and sa.is_active), '[]'::jsonb));
end;
$$;

-- app.session_overview(buổi): tiến độ các bước của một buổi cho GV-04: điểm danh, nội dung, nhận xét; kèm hạn hoàn tất và lý do chưa Done.
-- Luật: R-GIO-06, R-GV-05, R-V2-35 (nội dung chỉ cần có dòng, BTVN không bắt buộc).
create or replace function app.session_overview(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_total integer;
  v_marked integer;
  v_lines integer;
  v_homework text;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select count(*), count(teacher_status_code) into v_total, v_marked
    from app.session_attendance where session_id = s.id and is_active;
  select count(*) into v_lines from app.session_content_line where session_id = s.id and is_active;
  select homework_text into v_homework from app.session_content where session_id = s.id;
  return jsonb_build_object(
    'session_id', s.id, 'status_code', s.status_code, 'type_code', s.type_code,
    'attendance_total', v_total, 'attendance_marked', v_marked,
    'content_lines', v_lines, 'has_content', v_lines > 0, 'homework_text', v_homework,
    'deadline_at', app.session_ends_at(s.id) + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', s.branch_id)::integer),
    'pending_reason', case when s.status_code = 'DONE' then null else app.session_pending_reason(s.id) end);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Điều kiện "có nội dung buổi" cho buổi thường (Q-231, Q-208)
-- ---------------------------------------------------------------------------
-- Bản này thay app.session_pending_reason của migration 103: thêm đoạn kiểm nội dung buổi cho buổi thường, cả hai nhánh Bật và Tắt (Q-231).
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
  -- Luật Q-231, R-V2-35: buổi thường cần ít nhất một dòng nội dung buổi (BTVN không bắt buộc), cả khi tham số Bật lẫn Tắt.
  -- Buổi Kiểm tra: khung GV-06 kiểm tra để phạm vi kiến thức và BTVN tuỳ giáo viên nên không đòi dòng nội dung; vẫn cần cấu hình điểm (R-V2-20).
  if s.type_code <> 'KIEM_TRA' and not app.session_has_content(p_session_id) then
    return 'Giáo viên chưa nhập nội dung buổi.';
  end if;
  -- Luật Q-198: tham số tắt thì bỏ điều kiện nhận xét, điểm; điểm danh và nội dung buổi vẫn bắt buộc (kiểm ở trên).
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
-- 5. Quyền gọi hàm
-- ---------------------------------------------------------------------------
revoke execute on function
  app.session_has_content(uuid), app.save_session_content(uuid, text[], text), app.teacher_my_sessions(text, date, date, integer, integer),
  app.teacher_session_students(uuid), app.session_overview(uuid)
  from public, anon, authenticated;
-- Giao diện gọi (kiểm quyền bên trong): lưu nội dung, buổi của tôi, danh sách em, tiến độ buổi.
grant execute on function
  app.save_session_content(uuid, text[], text), app.teacher_my_sessions(text, date, date, integer, integer),
  app.teacher_session_students(uuid), app.session_overview(uuid)
  to authenticated;
