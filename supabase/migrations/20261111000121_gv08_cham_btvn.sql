-- GV-08, GV-07 (Code 2, 11/11/2026): hàm đọc, lưu cho màn Chấm nhận xét (mục 6) và chấm BTVN của buổi trước. Bảng kết quả BTVN từng em, màn chấm, cập nhật bài Nộp sau, bước chấm BTVN trong tiến độ buổi.
-- Luật: R-GV-10 (BTVN buổi N chấm ở buổi N+1), R-GV-11 (5 trạng thái, điểm 1–5, vắng buổi giao bài = Không áp dụng, vắng buổi chấm = Nộp sau), R-GV-12 (không gộp Không làm thành 0),
-- R-GIO-06 + Q-272 (bước chặn Done chỉ khi tham số session_done_requires_review Bật), R-V2-35 (buổi trước không giao BTVN thì bỏ qua), R-GV-08, R-GV-13 (quyền như điểm danh, không thông tin phụ huynh).
-- Chạy sau migration 109 (thay app.session_overview của 109) và 107 (thay app.session_pending_reason của 107). Danh mục HOMEWORK_STATUS có từ migration 20261010000008.

-- ---------------------------------------------------------------------------
-- 1. Bảng kết quả BTVN: một dòng cho mỗi em mỗi bài BTVN (bài giao ở buổi session_id)
-- ---------------------------------------------------------------------------
create table app.homework_result (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references app.class_session (id),
  branch_id uuid not null references app.branch (id),
  student_id uuid not null references app.student (id),
  status_catalog text not null default 'HOMEWORK_STATUS' check (status_catalog = 'HOMEWORK_STATUS'),
  status_code text not null,
  score smallint check (score between 1 and 5),
  note text,
  -- Số phiên bản dòng để chặn ghi đè khi hai người cùng sửa (Q-243, HMT_XUNG_DOT).
  version integer not null default 1,
  graded_session_id uuid references app.class_session (id),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (session_id, student_id),
  foreign key (status_catalog, status_code) references app.catalog_item (catalog_code, code),
  -- Luật R-GV-11: chỉ Đã chấm và Làm chưa xong có điểm 1–5; các trạng thái khác không có điểm (Không làm không phải điểm 0, R-GV-12).
  check ((status_code in ('DA_CHAM', 'LAM_CHUA_XONG')) = (score is not null))
);
comment on table app.homework_result is 'Kết quả BTVN của một em cho bài giao ở buổi session_id (R-GV-11). graded_session_id là buổi chấm (buổi sau); null khi cập nhật bài Nộp sau về sau.';
-- Chỉ mục (lý do): unique (buổi giao, em) phục vụ khoá ngoại buổi và tra một em; em (hồ sơ học tập, báo cáo R-GV-12); cơ sở cho RLS; buổi chấm.
create index homework_result_student_idx on app.homework_result (student_id);
create index homework_result_branch_idx on app.homework_result (branch_id);
create index homework_result_graded_idx on app.homework_result (graded_session_id);
-- Danh sách bài Nộp sau chờ cập nhật (Việc cần làm): lọc theo trạng thái trong một buổi giao.
create index homework_result_pending_idx on app.homework_result (session_id) where status_code = 'NOP_SAU';
select app.apply_standard('app.homework_result');

alter table app.homework_result enable row level security;
grant select on app.homework_result to authenticated;
create policy homework_result_read on app.homework_result for select to authenticated
  using ((select app.session_visible(session_id)));

-- ---------------------------------------------------------------------------
-- 2. Buổi trước và tiến độ bước chấm BTVN
-- ---------------------------------------------------------------------------
-- app.previous_session(buổi): buổi liền trước của cùng lớp (bỏ buổi đã huỷ, đã thay); id null nếu là buổi đầu của lớp. Nội bộ.
create or replace function app.previous_session(p_session_id uuid)
returns app.class_session
language sql
stable
security definer
set search_path = ''
as $$
  select ps.* from app.class_session s
    join app.class_session ps on ps.class_id = s.class_id and ps.status_code in ('NHAP', 'DA_CHOT', 'DONE')
                             and (ps.session_date, ps.start_time, ps.id) < (s.session_date, s.start_time, s.id)
   where s.id = p_session_id
   order by ps.session_date desc, ps.start_time desc, ps.id desc
   limit 1;
$$;

-- app.homework_progress(buổi): tiến độ bước chấm BTVN buổi trước (nội bộ, dùng cho session_overview, session_pending_reason, màn GV-08).
-- state: DAU_LOP (buổi đầu của lớp) | KHONG_GIAO (buổi trước không giao BTVN) | CAN_CHAM. Hai trạng thái đầu: bỏ qua, không chặn (R-GIO-06, R-V2-35).
-- present: số em có mặt (Có mặt, Đi muộn) ở buổi này. done: số em trong đó đã có trạng thái, hoặc vắng buổi giao bài (đặt sẵn Không áp dụng, R-GV-11).
-- missing: tên tối đa 10 em còn thiếu. Em vắng buổi này không bắt buộc chấm (vào danh sách Nộp sau).
create or replace function app.homework_progress(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_prev app.class_session;
  v_hw text;
  v_present integer;
  v_done integer;
  v_missing jsonb;
begin
  v_prev := app.previous_session(p_session_id);
  if v_prev.id is null then
    return jsonb_build_object('state', 'DAU_LOP', 'present', 0, 'done', 0, 'missing', '[]'::jsonb, 'prev_session_id', null, 'prev_session_no', null);
  end if;
  select homework_text into v_hw from app.session_content where session_id = v_prev.id;
  if v_hw is null then
    return jsonb_build_object('state', 'KHONG_GIAO', 'present', 0, 'done', 0, 'missing', '[]'::jsonb, 'prev_session_id', v_prev.id, 'prev_session_no', v_prev.session_no);
  end if;
  with present as (
    select sa.student_id, st.full_name,
           -- Có trạng thái = có dòng kết quả, hoặc em không có mặt ở buổi giao bài (Không áp dụng đặt sẵn).
           (exists (select from app.homework_result hr where hr.session_id = v_prev.id and hr.student_id = sa.student_id)
            or not exists (select from app.session_attendance pa
                            where pa.session_id = v_prev.id and pa.student_id = sa.student_id and pa.is_active
                              and pa.teacher_status_code in ('CO_MAT', 'DI_MUON'))) as has_state
      from app.session_attendance sa join app.student st on st.id = sa.student_id
     where sa.session_id = p_session_id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
  )
  select count(*), count(*) filter (where has_state),
         coalesce((select jsonb_agg(m.full_name) from (select full_name from present where not has_state order by full_name limit 10) m), '[]'::jsonb) -- allow-number: tối đa 10 tên em còn thiếu hiện trên màn
    into v_present, v_done, v_missing from present;
  return jsonb_build_object('state', 'CAN_CHAM', 'present', v_present, 'done', v_done, 'missing', v_missing, 'prev_session_id', v_prev.id, 'prev_session_no', v_prev.session_no);
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Màn GV-08: dữ liệu chấm
-- ---------------------------------------------------------------------------
-- app.homework_grading_sheet(buổi): dữ liệu màn chấm BTVN buổi trước, một lần gọi cho cả màn (GV-08).
-- Ai gọi: giáo viên, trợ giảng của buổi, hoặc vận hành có quyền Điểm danh · Xem (R-GV-08). Không trả thông tin phụ huynh, học phí (R-GV-13).
-- Kết quả: state (DAU_LOP | KHONG_GIAO | CAN_CHAM), prev (buổi giao bài: số buổi, ngày, nội dung BTVN), session (số buổi, ngày, giờ, mã lớp, tình trạng),
-- students (em có mặt: kết quả đã lưu hoặc mặc định Không áp dụng nếu vắng buổi giao bài, kèm phiên bản dòng),
-- absent_now (em có mặt ở buổi giao bài nhưng vắng buổi này: không bắt buộc chấm, bài vào Nộp sau), late (bài Nộp sau chờ cập nhật của cả lớp: dòng đã lưu và dòng suy ra).
-- Luật R-GV-10, R-GV-11.
create or replace function app.homework_grading_sheet(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  c app.class;
  v_hw jsonb;
  v_prev app.class_session;
  v_text text;
  v_students jsonb;
  v_absent jsonb;
  v_late jsonb;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select * into c from app.class where id = s.class_id;
  v_hw := app.homework_progress(s.id);
  if (v_hw ->> 'state') = 'CAN_CHAM' then
    select * into v_prev from app.class_session where id = (v_hw ->> 'prev_session_id')::uuid;
    select homework_text into v_text from app.session_content where session_id = v_prev.id;
    select coalesce(jsonb_agg(jsonb_build_object(
             'student_id', sa.student_id, 'full_name', st.full_name, 'attendance_code', sa.teacher_status_code,
             'absent_at_assignment', not exists (select from app.session_attendance pa
                                                  where pa.session_id = v_prev.id and pa.student_id = sa.student_id and pa.is_active
                                                    and pa.teacher_status_code in ('CO_MAT', 'DI_MUON')),
             'result', (select jsonb_build_object('status_code', hr.status_code, 'score', hr.score, 'note', hr.note, 'version', hr.version)
                          from app.homework_result hr where hr.session_id = v_prev.id and hr.student_id = sa.student_id))
           order by st.full_name), '[]'::jsonb)
      into v_students
      from app.session_attendance sa join app.student st on st.id = sa.student_id
     where sa.session_id = s.id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON');
    select coalesce(jsonb_agg(jsonb_build_object('student_id', sa.student_id, 'full_name', st.full_name, 'attendance_code', sa.teacher_status_code,
                                                 'attendance_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'ATTENDANCE_STATUS' and ci.code = sa.teacher_status_code))
                    order by st.full_name), '[]'::jsonb)
      into v_absent
      from app.session_attendance sa join app.student st on st.id = sa.student_id
     where sa.session_id = s.id and sa.is_active and sa.teacher_status_code is not null and sa.teacher_status_code not in ('CO_MAT', 'DI_MUON')
       and exists (select from app.session_attendance pa
                    where pa.session_id = v_prev.id and pa.student_id = sa.student_id and pa.is_active and pa.teacher_status_code in ('CO_MAT', 'DI_MUON'));
  else
    v_students := '[]'::jsonb;
    v_absent := '[]'::jsonb;
  end if;
  -- Bài Nộp sau chờ cập nhật của cả lớp (R-GV-11): dòng đã lưu Nộp sau, và em có mặt ở buổi giao bài, vắng ngay buổi kế tiếp, chưa có dòng nào (suy ra, Việc cần làm).
  with assigned as (
    select cs.id, cs.session_no, cs.session_date, sc.homework_text,
           (select ns.id from app.class_session ns
             where ns.class_id = cs.class_id and ns.status_code in ('NHAP', 'DA_CHOT', 'DONE') and (ns.session_date, ns.start_time, ns.id) > (cs.session_date, cs.start_time, cs.id)
             order by ns.session_date, ns.start_time, ns.id limit 1) as next_id
      from app.class_session cs join app.session_content sc on sc.session_id = cs.id and sc.homework_text is not null
     where cs.class_id = s.class_id and cs.status_code in ('NHAP', 'DA_CHOT', 'DONE')
       and (cs.session_date, cs.start_time, cs.id) < (s.session_date, s.start_time, s.id)
  ), late as (
    select a.id as assigned_id, a.session_no, a.session_date, a.homework_text, hr.student_id, hr.version, false as inferred
      from assigned a join app.homework_result hr on hr.session_id = a.id and hr.status_code = 'NOP_SAU'
    union all
    select a.id, a.session_no, a.session_date, a.homework_text, pa.student_id, 0, true
      from assigned a
      join app.session_attendance pa on pa.session_id = a.id and pa.is_active and pa.teacher_status_code in ('CO_MAT', 'DI_MUON')
      join app.session_attendance na on na.session_id = a.next_id and na.student_id = pa.student_id and na.is_active
                                    and na.teacher_status_code is not null and na.teacher_status_code not in ('CO_MAT', 'DI_MUON')
     where not exists (select from app.homework_result hr where hr.session_id = a.id and hr.student_id = pa.student_id)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'assigned_session_id', l.assigned_id, 'session_no', l.session_no, 'session_date', l.session_date, 'homework_text', l.homework_text,
           'student_id', l.student_id, 'full_name', st.full_name, 'version', l.version, 'inferred', l.inferred)
         order by l.session_date, st.full_name), '[]'::jsonb)
    into v_late from late l join app.student st on st.id = l.student_id;
  return jsonb_build_object(
    'state', v_hw ->> 'state',
    'session', jsonb_build_object('session_id', s.id, 'status_code', s.status_code, 'session_no', s.session_no, 'session_date', s.session_date,
                                  'start_time', s.start_time, 'end_time', s.end_time, 'class_code', c.code,
                                  'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code)),
    'prev', case when v_prev.id is null then null
                 else jsonb_build_object('session_id', v_prev.id, 'session_no', v_prev.session_no, 'session_date', v_prev.session_date, 'homework_text', v_text) end,
    'students', v_students, 'absent_now', v_absent, 'late', v_late,
    'present', (v_hw ->> 'present')::integer, 'done', (v_hw ->> 'done')::integer);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Lưu: chấm BTVN buổi trước, cập nhật bài Nộp sau
-- ---------------------------------------------------------------------------
-- Kiểm trạng thái, điểm của một kết quả BTVN. Nội bộ.
create or replace function app.assert_homework_entry(p_status text, p_score integer)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform app.assert_catalog_code_active('HOMEWORK_STATUS', p_status);
  -- Luật R-GV-11: Đã chấm và Làm chưa xong có điểm 1–5; trạng thái khác không có điểm.
  if p_status in ('DA_CHAM', 'LAM_CHUA_XONG') and (p_score is null or p_score not between 1 and 5) then -- allow-number: thang điểm BTVN 1 đến 5 cố định (R-GV-11)
    perform app.raise_error('HMT_DIEM_KHONG_HOP_LE', 'Điểm BTVN phải từ 1 đến 5.');
  end if;
end;
$$;

-- app.save_homework_grading(buổi, [{student_id, status_code, score, note, expected_version}]): lưu chấm BTVN buổi trước (GV-08).
-- Ai gọi: giáo viên, trợ giảng của buổi, hoặc vận hành có quyền Điểm danh · Sửa (như điểm danh). Buổi phải Đã chốt (chưa Done); buổi trước phải có giao BTVN.
-- Chỉ chấm em có mặt ở buổi này (Có mặt, Đi muộn); em vắng thì dùng app.update_late_homework khi em nộp bài.
-- expected_version: phiên bản dòng lúc mở màn (0 = chưa có dòng). Lệch = người khác vừa sửa: HMT_XUNG_DOT, cả lô không ghi (Q-243).
-- Luật R-GV-10, R-GV-11, R-GV-08.
create or replace function app.save_homework_grading(p_session_id uuid, p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_hw jsonb;
  e jsonb;
  v_student uuid;
  v_status text;
  v_score integer;
  v_prev uuid;
  v_current integer;
  v_expected integer;
  v_n integer := 0;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA');
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: giáo viên không sửa nữa. Bài Nộp sau thì cập nhật ở Cần làm.');
  end if;
  if s.status_code <> 'DA_CHOT' then
    perform app.raise_error('HMT_BUOI_CHUA_CHOT', 'Buổi chưa chốt danh sách nên chưa chấm được.');
  end if;
  v_hw := app.homework_progress(s.id);
  if (v_hw ->> 'state') <> 'CAN_CHAM' then
    perform app.raise_error('HMT_KHONG_CO_BTVN_DE_CHAM', 'Buổi trước không giao BTVN (hoặc đây là buổi đầu của lớp) nên không có gì để chấm.');
  end if;
  v_prev := (v_hw ->> 'prev_session_id')::uuid;
  for e in select * from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) loop
    v_student := (e ->> 'student_id')::uuid;
    v_status := e ->> 'status_code';
    v_score := nullif(e ->> 'score', '')::integer;
    v_expected := nullif(e ->> 'expected_version', '')::integer;
    perform app.assert_homework_entry(v_status, v_score);
    if v_status not in ('DA_CHAM', 'LAM_CHUA_XONG') then
      v_score := null;
    end if;
    if not exists (select from app.session_attendance sa
                    where sa.session_id = s.id and sa.student_id = v_student and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')) then
      perform app.raise_error('HMT_EM_KHONG_CO_MAT', 'Chỉ chấm BTVN cho em có mặt trong buổi này.');
    end if;
    select version into v_current from app.homework_result where session_id = v_prev and student_id = v_student for update;
    -- Luật Q-243: dòng đã bị người khác sửa kể từ lúc mở màn thì từ chối, không ghi đè lặng lẽ.
    if v_expected is not null and v_expected is distinct from coalesce(v_current, 0) then
      perform app.raise_error('HMT_XUNG_DOT', 'Ô này vừa được người khác sửa, tải lại để xem.');
    end if;
    insert into app.homework_result (session_id, branch_id, student_id, status_code, score, note, graded_session_id)
    values (v_prev, s.branch_id, v_student, v_status, v_score, nullif(btrim(e ->> 'note'), ''), s.id)
    on conflict (session_id, student_id) do update
      set status_code = excluded.status_code, score = excluded.score, note = excluded.note, graded_session_id = excluded.graded_session_id,
          version = app.homework_result.version + 1;
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

-- app.update_late_homework(buổi giao bài, em, trạng thái, điểm, ghi chú, phiên bản): cập nhật bài Nộp sau mà không mở lại buổi cũ (R-GV-11, GV-08).
-- Ai gọi: như điểm danh của buổi giao bài. Được gọi cả khi buổi giao bài đã Done. Chỉ áp dụng cho dòng đang Nộp sau, hoặc em có mặt ở buổi giao bài
-- mà vắng buổi kế tiếp và chưa có dòng nào. Phiên bản dòng chặn ghi đè như trên.
create or replace function app.update_late_homework(p_assigned_session_id uuid, p_student_id uuid, p_status_code text, p_score integer default null,
                                                    p_note text default null, p_expected_version integer default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_current integer;
  v_cur_status text;
  v_score integer := p_score;
begin
  s := app.assert_session_access(p_assigned_session_id, 'ATTENDANCE', 'SUA');
  if not exists (select from app.session_content where session_id = s.id and homework_text is not null) then
    perform app.raise_error('HMT_KHONG_CO_BTVN_DE_CHAM', 'Buổi này không giao BTVN.');
  end if;
  perform app.assert_homework_entry(p_status_code, v_score);
  if p_status_code not in ('DA_CHAM', 'LAM_CHUA_XONG') then
    v_score := null;
  end if;
  select version, status_code into v_current, v_cur_status from app.homework_result where session_id = s.id and student_id = p_student_id for update;
  if v_cur_status is null then
    -- Chưa có dòng: chỉ em có mặt ở buổi giao bài mới có bài (R-GV-11).
    if not exists (select from app.session_attendance sa
                    where sa.session_id = s.id and sa.student_id = p_student_id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')) then
      perform app.raise_error('HMT_EM_KHONG_CO_MAT', 'Em không có mặt ở buổi giao bài nên không có bài để cập nhật.');
    end if;
  elsif v_cur_status <> 'NOP_SAU' then
    perform app.raise_error('HMT_BTVN_DA_CHAM', 'Chỉ cập nhật được bài đang ở trạng thái Nộp sau.');
  end if;
  if p_expected_version is not null and p_expected_version is distinct from coalesce(v_current, 0) then
    perform app.raise_error('HMT_XUNG_DOT', 'Ô này vừa được người khác sửa, tải lại để xem.');
  end if;
  insert into app.homework_result (session_id, branch_id, student_id, status_code, score, note)
  values (s.id, s.branch_id, p_student_id, p_status_code, v_score, nullif(btrim(p_note), ''))
  on conflict (session_id, student_id) do update
    set status_code = excluded.status_code, score = excluded.score, note = excluded.note, version = app.homework_result.version + 1;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Bước chấm BTVN trong tiến độ buổi và lý do chưa Done
-- ---------------------------------------------------------------------------
-- app.session_pending_reason: thêm bước chấm BTVN buổi trước (Q-272); chỉ chặn khi session_done_requires_review Bật, chỉ khi buổi trước có giao BTVN.
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
  v_hw jsonb;
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
  -- Luật Q-272, R-GIO-06, R-GV-11: bước chấm BTVN buổi trước chặn Done khi tham số Bật (chỉ khi buổi trước có giao BTVN); Tắt thì không chặn (đã return ở trên).
  v_hw := app.homework_progress(p_session_id);
  if (v_hw ->> 'state') = 'CAN_CHAM' and (v_hw ->> 'done')::integer < (v_hw ->> 'present')::integer then
    return format('Giáo viên chưa chấm BTVN buổi trước cho %s em.', (v_hw ->> 'present')::integer - (v_hw ->> 'done')::integer);
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

-- app.session_overview: thêm tiến độ chấm BTVN (homework_present, homework_done, homework_missing) thay trạng thái tạm của migration 109.
create or replace function app.session_overview(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  c app.class;
  v_total integer;
  v_marked integer;
  v_homework text;
  v_lines jsonb;
  v_scored integer;
  v_exam jsonb;
  v_present integer;
  v_graded integer;
  v_missing jsonb;
  v_hw jsonb;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select * into c from app.class where id = s.class_id;
  select count(*), count(teacher_status_code) into v_total, v_marked
    from app.session_attendance where session_id = s.id and is_active;
  select coalesce(jsonb_agg(l.line_text order by l.sort_order), '[]'::jsonb) into v_lines
    from app.session_content_line l where l.session_id = s.id and l.is_active;
  select homework_text into v_homework from app.session_content where session_id = s.id;
  -- Buổi Kiểm tra: phạm vi kiến thức, điểm tối đa, cách nhập điểm do vận hành đặt (set_exam_config); giáo viên chỉ xem. Chưa đặt thì null.
  select jsonb_build_object('scope_text', e.scope_text, 'max_score', e.max_score, 'entry_mode', e.entry_mode,
                            'max_memory', e.max_memory, 'max_understand', e.max_understand, 'max_apply', e.max_apply)
    into v_exam from app.session_exam e where e.session_id = s.id;
  -- Số ô nhận xét đã chấm: màn GV-06 báo "sửa nội dung sau khi đã chấm" (điểm 9 tiêu chí không đổi khi sửa dòng nội dung, Q-245).
  select count(*) into v_scored from app.session_review_score where session_id = s.id and state <> 'CHUA_DANH_GIA';
  -- Bước chấm của GV-04 (R-GV-04, R-V2-20): em có mặt (Có mặt, Đi muộn) đã chấm đủ. Buổi thường: mọi tiêu chí đang bật đều có điểm hoặc trạng thái khác "Chưa đánh giá".
  -- Buổi Kiểm tra: đã chấm điểm. Kèm tên tối đa 10 em còn thiếu (giáo viên được thấy tên em trong lớp mình, R-GV-13).
  with present as (
    select sa.id, st.full_name,
           case when s.type_code = 'KIEM_TRA' then exists (select from app.exam_score es where es.attendance_id = sa.id and es.graded)
                else exists (select from app.session_review_criterion rc where rc.session_id = sa.session_id and rc.enabled)
                     and not exists (select from app.session_review_criterion rc
                                      where rc.session_id = sa.session_id and rc.enabled
                                        and not exists (select from app.session_review_score sc
                                                         where sc.attendance_id = sa.id and sc.session_criterion_id = rc.id and sc.state <> 'CHUA_DANH_GIA')) end as complete
      from app.session_attendance sa join app.student st on st.id = sa.student_id
     where sa.session_id = s.id and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
  )
  select count(*), count(*) filter (where complete),
         coalesce((select jsonb_agg(m.full_name) from (select full_name from present where not complete order by full_name limit 10) m), '[]'::jsonb) -- allow-number: tối đa 10 tên em còn thiếu hiện trên màn
    into v_present, v_graded, v_missing from present;
  -- Bước chấm BTVN buổi trước (GV-04, GV-08, R-V2-35, R-GV-11): tiến độ do app.homework_progress tính (DAU_LOP, KHONG_GIAO: bỏ qua, không chặn).
  v_hw := app.homework_progress(s.id);
  return jsonb_build_object(
    'session_id', s.id, 'status_code', s.status_code, 'type_code', s.type_code,
    'type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SESSION_TYPE' and ci.code = s.type_code),
    'class_code', c.code,
    'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
    'session_no', s.session_no, 'session_date', s.session_date, 'start_time', s.start_time, 'end_time', s.end_time,
    'attendance_total', v_total, 'attendance_marked', v_marked,
    'content_lines', jsonb_array_length(v_lines), 'has_content', jsonb_array_length(v_lines) > 0,
    'lines', v_lines, 'homework_text', v_homework, 'review_scored', v_scored, 'exam', v_exam,
    'grading_present', v_present, 'grading_done', v_graded, 'grading_missing', v_missing, 'prev_homework_state', v_hw ->> 'state', 'homework_present', (v_hw ->> 'present')::integer, 'homework_done', (v_hw ->> 'done')::integer,
    'homework_missing', v_hw -> 'missing', 'prev_session_no', (v_hw ->> 'prev_session_no')::integer,
    -- Số phiên bản để chặn ghi đè (Q-243): giao diện gửi lại giá trị này khi lưu; 0 = chưa có nội dung nào.
    'content_version', coalesce((select sc.version from app.session_content sc where sc.session_id = s.id), 0),
    'deadline_at', app.session_ends_at(s.id) + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', s.branch_id)::integer),
    'pending_reason', case when s.status_code = 'DONE' then null else app.session_pending_reason(s.id) end);
end;
$$;
-- ---------------------------------------------------------------------------
-- 6. GV-07: màn Chấm nhận xét từng em (đọc một lần, lưu một lần)
-- ---------------------------------------------------------------------------
-- app.review_grading_sheet(buổi): dữ liệu màn GV-07 một lần gọi. Ai gọi: người xem được điểm danh của buổi (R-GV-08). Không trả thông tin phụ huynh, học phí (R-GV-13).
-- Kết quả: buổi (số buổi, ngày, giờ, mã lớp, tình trạng, loại), criteria (tiêu chí đã mở của buổi kèm bật/tắt, biểu hiện gợi ý, mô tả 5 mức; rỗng nếu chưa mở),
-- students (mọi em đang trong danh sách buổi: trạng thái điểm danh, điểm từng tiêu chí {state, score} theo criterion_id, nhận xét chung, định hướng, điểm trung bình do DB tính, R-GV-03).
create or replace function app.review_grading_sheet(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  c app.class;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select * into c from app.class where id = s.class_id;
  return jsonb_build_object(
    'session', jsonb_build_object('session_id', s.id, 'status_code', s.status_code, 'type_code', s.type_code, 'session_no', s.session_no,
                                  'session_date', s.session_date, 'start_time', s.start_time, 'end_time', s.end_time, 'class_code', c.code,
                                  'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code)),
    'criteria', app.session_review_sheet(s.id),
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
               'student_id', sa.student_id, 'full_name', st.full_name, 'attendance_code', sa.teacher_status_code,
               'attendance_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'ATTENDANCE_STATUS' and ci.code = sa.teacher_status_code),
               'scores', coalesce((select jsonb_object_agg(rc.criterion_id::text, jsonb_build_object('state', sc.state, 'score', sc.score))
                                     from app.session_review_score sc join app.session_review_criterion rc on rc.id = sc.session_criterion_id
                                    where sc.attendance_id = sa.id), '{}'::jsonb),
               'comment', sr.teacher_comment, 'improvement', sr.improvement_note,
               'average', app.review_average(sa.id))
             order by st.full_name)
        from app.session_attendance sa join app.student st on st.id = sa.student_id
        left join app.session_student_review sr on sr.attendance_id = sa.id
       where sa.session_id = s.id and sa.is_active), '[]'::jsonb));
end;
$$;

-- app.save_review_grading(buổi, công tắc tiêu chí, điểm, nhận xét): lưu một lần cho cả màn GV-07, một giao dịch (hoặc lưu hết hoặc không lưu gì).
-- p_criteria: [{criterion_id, enabled}]; p_scores: [{student_id, criterion_id, state, score}]; p_notes: [{student_id, comment, improvement}].
-- Mở nhận xét của buổi nếu chưa mở. Luật R-V2-19, R-GV-02, R-GV-04: các hàm con kiểm quyền, buổi Đã chốt, em có mặt, điểm 1–5. Công tắc tắt trước khi chấm.
create or replace function app.save_review_grading(p_session_id uuid, p_criteria jsonb, p_scores jsonb, p_notes jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  n jsonb;
  v_count integer := 0;
begin
  perform app.open_session_review(p_session_id);
  if jsonb_array_length(coalesce(p_criteria, '[]'::jsonb)) > 0 then
    v_count := v_count + app.set_review_criteria(p_session_id, p_criteria);
  end if;
  if jsonb_array_length(coalesce(p_scores, '[]'::jsonb)) > 0 then
    v_count := v_count + app.set_review_scores(p_session_id, p_scores);
  end if;
  for n in select * from jsonb_array_elements(coalesce(p_notes, '[]'::jsonb)) loop
    perform app.set_student_review_note(p_session_id, (n ->> 'student_id')::uuid, n ->> 'comment', n ->> 'improvement');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

revoke execute on function app.previous_session(uuid), app.homework_progress(uuid), app.assert_homework_entry(text, integer) from public, anon, authenticated;
revoke execute on function app.homework_grading_sheet(uuid), app.save_homework_grading(uuid, jsonb), app.review_grading_sheet(uuid), app.save_review_grading(uuid, jsonb, jsonb, jsonb),
  app.update_late_homework(uuid, uuid, text, integer, text, integer) from public, anon, authenticated;
grant execute on function app.homework_grading_sheet(uuid), app.save_homework_grading(uuid, jsonb), app.review_grading_sheet(uuid), app.save_review_grading(uuid, jsonb, jsonb, jsonb),
  app.update_late_homework(uuid, uuid, text, integer, text, integer) to authenticated;
