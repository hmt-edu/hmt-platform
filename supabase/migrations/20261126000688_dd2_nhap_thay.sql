-- Migration 688 (Code C, 27/11/2026, C-26-05, PR-DD2): quản lý cơ sở, Admin NHẬP THAY giáo viên (R-GIO-11), ngoại lệ của R-GV-08.
-- Nhập thay bắt buộc lý do và chỉ khi buổi chưa Done. Từ đây người KHÔNG phải giáo viên, trợ giảng của buổi không còn gọi thẳng được
-- các hàm ghi điểm danh, nhận xét, điểm, chấm BTVN của giáo viên (R-DD-02, R-DD-05); phải đi qua app.enter_for_teacher.
-- Nội dung buổi (app.save_session_content) không đổi: R-GIO-11 không nhắc.

create table app.session_proxy_entry (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references app.class_session (id),
  branch_id uuid not null references app.branch (id),
  kind text not null check (kind in ('DIEM_DANH', 'NHAN_XET', 'DIEM', 'BTVN')),
  reason text not null check (btrim(reason) <> ''),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.session_proxy_entry is 'Mỗi lần nhập thay giáo viên (R-GIO-11): buổi, loại việc, lý do; người nhập là created_by. Chỉ ghi qua app.enter_for_teacher.';
-- Chỉ mục (lý do): session_id để xem lịch sử nhập thay của buổi (khoá ngoại); branch_id cho khoá ngoại và RLS.
create index session_proxy_entry_session_idx on app.session_proxy_entry (session_id, created_at);
create index session_proxy_entry_branch_idx on app.session_proxy_entry (branch_id);
select app.apply_standard('app.session_proxy_entry');

alter table app.session_proxy_entry enable row level security;
revoke all on app.session_proxy_entry from public, anon, authenticated;
grant select on app.session_proxy_entry to authenticated;
create policy session_proxy_entry_read on app.session_proxy_entry for select to authenticated
  using ((select app.permission_scope('ATTENDANCE', 'DUYET')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('ATTENDANCE', 'DUYET')) = 'CO_SO' and branch_id = (select app.current_branch_id())));

-- app.assert_teacher_or_proxy: chỉ giáo viên, trợ giảng của buổi, hoặc đang trong một lượt nhập thay của đúng buổi đó (nội bộ).
create or replace function app.assert_teacher_or_proxy(p_session app.class_session)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not distinct from p_session.teacher_id or auth.uid() is not distinct from p_session.assistant_id then
    return;
  end if;
  -- Cờ chỉ do app.enter_for_teacher đặt, trong phạm vi một giao dịch.
  if current_setting('hmt.proxy_session', true) is not distinct from p_session.id::text then
    return;
  end if;
  perform app.raise_error('HMT_CAN_NHAP_THAY', 'Chỉ giáo viên, trợ giảng của buổi nhập được. Quản lý cơ sở dùng «Nhập thay» và ghi lý do.');
end;
$$;
revoke execute on function app.assert_teacher_or_proxy(app.class_session) from public, anon, authenticated;

-- app.enter_for_teacher: nhập thay. Ai gọi: quản lý cơ sở, Admin (quyền ATTENDANCE · Duyệt ở cơ sở của buổi).
-- Vào: buổi; loại DIEM_DANH {entries}, NHAN_XET {criteria, scores, notes}, DIEM {scores, notes}, BTVN {items}; dữ liệu cùng dạng
-- với hàm của giáo viên; lý do bắt buộc. Ra: số ô đã ghi. Đủ điều kiện sau khi ghi thì buổi tự Done như giáo viên tự lưu.
create or replace function app.enter_for_teacher(p_session_id uuid, p_kind text, p_payload jsonb, p_reason text)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_n integer;
begin
  select * into s from app.class_session where id = p_session_id for update;
  if s.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy buổi học.');
  end if;
  perform app.assert_can('ATTENDANCE', 'DUYET', s.branch_id);
  if btrim(coalesce(p_reason, '')) = '' then
    perform app.raise_error('HMT_CAN_LY_DO', 'Nhập thay cần ghi lý do.');
  end if;
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: chỉ sửa được điểm danh, điểm theo chức năng sửa sau Done.');
  end if;
  insert into app.session_proxy_entry (session_id, branch_id, kind, reason) values (s.id, s.branch_id, p_kind, btrim(p_reason));
  perform set_config('hmt.proxy_session', s.id::text, true);
  v_n := app.apply_proxy_entry(s.id, p_kind, coalesce(p_payload, '{}'::jsonb));
  perform set_config('hmt.proxy_session', '', true);
  return v_n;
end;
$$;

-- app.apply_proxy_entry: gọi đúng hàm ghi của giáo viên theo loại (nội bộ; loại sai đã bị chặn bởi check của bảng).
create or replace function app.apply_proxy_entry(p_session_id uuid, p_kind text, p_payload jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
begin
  case p_kind
    when 'DIEM_DANH' then
      return app.set_attendance_teacher(p_session_id, p_payload -> 'entries');
    when 'NHAN_XET' then
      return app.save_review_grading(p_session_id, p_payload -> 'criteria', p_payload -> 'scores', p_payload -> 'notes');
    when 'DIEM' then
      return app.save_exam_grading(p_session_id, p_payload -> 'scores', p_payload -> 'notes');
    when 'BTVN' then
      return app.save_homework_grading(p_session_id, p_payload -> 'items');
  end case;
end;
$$;
revoke execute on function app.apply_proxy_entry(uuid, text, jsonb) from public, anon, authenticated;

-- Lấy từ 20261126000685; chỉ thêm app.assert_teacher_or_proxy.
create or replace function app.set_attendance_teacher(p_session_id uuid, p_entries jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  e jsonb;
  v_status text;
  v_n integer := 0;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA');
  perform app.assert_teacher_or_proxy(s);
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: giáo viên không sửa điểm danh. Nhờ quản lý cơ sở sửa kèm lý do.');
  end if;
  if s.status_code <> 'DA_CHOT' then
    perform app.raise_error('HMT_BUOI_CHUA_CHOT', 'Buổi chưa chốt danh sách nên chưa điểm danh được.');
  end if;
  for e in select * from jsonb_array_elements(coalesce(p_entries, '[]'::jsonb)) loop
    v_status := nullif(e ->> 'status_code', '');
    if v_status is not null then
      perform app.assert_catalog_code_active('ATTENDANCE_STATUS', v_status);
    end if;
    update app.session_attendance set teacher_status_code = v_status,
           teacher_marked_by = case when v_status is null then null else auth.uid() end,
           teacher_marked_at = case when v_status is null then null else now() end,
           -- DD-04, C1: ô vận hành trống hoặc còn là ô do chép thì đi theo ô giáo viên; vận hành đã tự tích thì không đè.
           ops_status_code = case when ops_status_code is null or ops_source = 'GIAO_VIEN' then v_status else ops_status_code end,
           ops_source = case when ops_status_code is null or ops_source = 'GIAO_VIEN'
                             then case when v_status is null then null else 'GIAO_VIEN' end else ops_source end
     where session_id = p_session_id and student_id = (e ->> 'student_id')::uuid and is_active;
    if not found then
      perform app.raise_error('HMT_EM_KHONG_TRONG_DANH_SACH', 'Có em không nằm trong danh sách buổi này.');
    end if;
    v_n := v_n + 1;
  end loop;
  -- A-23-12: bước giáo viên vừa lưu có thể là bước cuối; đủ bốn bước và buổi đã kết thúc thì Done ngay (QĐ-Đ21, anh chốt 23/11).
  perform app.complete_session_if_ready(p_session_id);
  return v_n;
end;
$$;

-- Lấy từ 20261119000305; chỉ thêm app.assert_teacher_or_proxy (tiêu chí, nhận xét, điểm kiểm tra đều đi qua hàm này).
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
  perform app.assert_teacher_or_proxy(s);
  if s.status_code = 'DONE' then
    perform app.raise_error('HMT_BUOI_DA_DONE', 'Buổi đã Done: giáo viên không sửa nhận xét, điểm. Tạo ticket cho vận hành để sửa kèm lý do.');
  end if;
  if s.status_code <> 'DA_CHOT' then
    perform app.raise_error('HMT_BUOI_CHUA_CHOT', 'Buổi chưa chốt danh sách nên chưa chấm được.');
  end if;
  if app.session_is_exam(s) is distinct from p_exam then
    perform app.raise_error('HMT_SAI_LOAI_BUOI', case when p_exam then 'Buổi này không phải buổi kiểm tra.' else 'Buổi kiểm tra chấm bằng điểm, không dùng 9 tiêu chí.' end);
  end if;
  return s;
end;
$$;

-- Lấy từ 20261111000103; chỉ thêm app.assert_teacher_or_proxy.
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
  perform app.assert_teacher_or_proxy(s);
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

-- Lấy từ 20261123000624; chỉ thêm app.assert_teacher_or_proxy.
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
  perform app.assert_teacher_or_proxy(s);
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
  -- A-23-12: bước giáo viên vừa lưu có thể là bước cuối; đủ bốn bước và buổi đã kết thúc thì Done ngay (QĐ-Đ21, anh chốt 23/11).
  perform app.complete_session_if_ready(p_session_id);
  return v_n;
end;
$$;
