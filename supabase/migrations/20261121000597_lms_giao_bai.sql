-- Migration 597 (Code E, 21/11/2026): LMS giao bài (GV-17), phần 1: bảng + hàm giao, sửa, gỡ, danh sách.
-- Đề xuất đã duyệt: docs/nghiep-vu/de-xuat-db-lms-gv17-gv18.md (Chat 02:29: lưu tệp phương án B, chưa bật R2; giữ cột storage_key).
-- Luật: R-LMS-01 (giao cả lớp hoặc từng em; hạn mặc định là giờ vào buổi sau; công tắc Cho nộp lại, Nhận bài muộn),
-- R-LMS-02, R-LMS-03, R-LMS-04 (tệp tối đa 10 MB, 20 trang), R-GV-10, R-V2-35. Quyết định Chat Q2, Q4, Q10, Q11, Q14.
-- Phần chấm bài (migration 598) và nộp bài của học sinh (HT-03, HT-05) làm sau; bảng bài nộp tạo sẵn ở đây.
-- Quyền: không thêm mã quyền (Q14): dùng ATTENDANCE XEM/SUA phạm vi «được phân công»; thêm công tắc tính năng HOC_TAP (app.require_feature).

-- ---------------------------------------------------------------------------
-- 1. Bảng
-- ---------------------------------------------------------------------------
create table app.lms_assignment (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references app.class (id),
  session_id uuid not null references app.class_session (id), -- buổi giao (bài giao ở buổi N, chấm ở buổi N+1, R-GV-10)
  branch_id uuid not null references app.branch (id),
  title text not null check (length(btrim(title)) between 1 and 200), -- allow-number: độ dài tiêu đề hiển thị
  description text not null check (length(btrim(description)) > 0),
  due_at timestamptz not null,
  -- Chụp lại cấu hình lúc giao (CLAUDE.md: bản ghi nghiệp vụ không tham chiếu cấu hình hiện tại).
  allow_resubmit boolean not null default true,
  allow_late boolean not null default false,
  audience text not null check (audience in ('CA_LOP', 'CHON_EM')),
  status text not null default 'DANG_GIAO' check (status in ('DANG_GIAO', 'DA_GO')),
  -- Số phiên bản để chặn ghi đè khi hai người cùng sửa (HMT_XUNG_DOT).
  version integer not null default 1,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.lms_assignment is 'Bài giao trên LMS của giáo viên (GV-17). Ghi chỉ qua hàm lms_*; không xoá cứng, Gỡ = DA_GO (Q2).';
-- Chỉ mục (lý do): «Bài đã giao» của lớp mới nhất trước (phân trang); khoá ngoại buổi giao; cơ sở cho RLS.
create index lms_assignment_class_idx on app.lms_assignment (class_id, created_at desc);
create index lms_assignment_session_idx on app.lms_assignment (session_id);
create index lms_assignment_branch_idx on app.lms_assignment (branch_id);
select app.apply_standard('app.lms_assignment');

create table app.lms_assignment_target (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references app.lms_assignment (id),
  student_id uuid not null references app.student (id),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (assignment_id, student_id)
);
comment on table app.lms_assignment_target is 'Em được giao bài (chụp lúc giao, Q11: tối thiểu 1 em đang học).';
-- Chỉ mục (lý do): unique (bài, em) đã phục vụ khoá ngoại bài; em cho cổng học sinh (HT-03) tra bài của mình.
create index lms_assignment_target_student_idx on app.lms_assignment_target (student_id);
select app.apply_standard('app.lms_assignment_target');

create table app.lms_assignment_file (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references app.lms_assignment (id),
  storage_key text not null,
  file_name text not null,
  -- R-LMS-04: tối đa 10 MB mỗi tệp (luật lõi, đặt trong cấu trúc). Phương án B: chưa có hàm ghi tệp, cột để sẵn cho R2.
  byte_size bigint not null check (byte_size between 1 and 10485760), -- allow-number: R-LMS-04, 10 MB
  mime_type text not null,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.lms_assignment_file is 'Tệp đề của bài giao (khoá tệp trên Cloudflare R2). Giai đoạn này chưa bật R2 (Chat 02:29, phương án B).';
create index lms_assignment_file_assignment_idx on app.lms_assignment_file (assignment_id);
select app.apply_standard('app.lms_assignment_file');

create table app.lms_submission (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references app.lms_assignment (id),
  student_id uuid not null references app.student (id),
  attempt_count integer not null default 0,
  submitted_at timestamptz,
  is_late boolean not null default false, -- nhãn «Nộp muộn», không phải trạng thái (R-LMS-02)
  graded_at timestamptz,
  reopened_at timestamptz,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (assignment_id, student_id)
);
comment on table app.lms_submission is 'Bài nộp của một em cho một bài giao. Học sinh nộp ở HT-05 (làm sau); hàm chấm ở migration 598.';
-- Chỉ mục (lý do): em cho cổng học sinh; danh sách «Chưa chấm» của một bài (lọc nhanh).
create index lms_submission_student_idx on app.lms_submission (student_id);
create index lms_submission_ungraded_idx on app.lms_submission (assignment_id) where graded_at is null;
select app.apply_standard('app.lms_submission');

create table app.lms_submission_file (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references app.lms_submission (id),
  page_no integer not null check (page_no between 1 and 20), -- allow-number: R-LMS-04, tối đa 20 trang mỗi bài
  storage_key text not null,
  byte_size bigint not null check (byte_size between 1 and 10485760), -- allow-number: R-LMS-04, 10 MB
  mime_type text not null,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (submission_id, page_no)
);
comment on table app.lms_submission_file is 'Trang của bài nộp (ảnh hoặc PDF), tối đa 20 trang mỗi bài (R-LMS-04).';
select app.apply_standard('app.lms_submission_file');

-- ---------------------------------------------------------------------------
-- 2. Quyền đọc (RLS): theo buổi giao, cùng phạm vi với buổi học (app.session_visible)
-- ---------------------------------------------------------------------------
create or replace function app.lms_assignment_visible(p_assignment_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.lms_assignment a where a.id = p_assignment_id and app.session_visible(a.session_id));
$$;
revoke execute on function app.lms_assignment_visible(uuid) from public, anon, authenticated;
grant execute on function app.lms_assignment_visible(uuid) to authenticated;

alter table app.lms_assignment enable row level security;
alter table app.lms_assignment_target enable row level security;
alter table app.lms_assignment_file enable row level security;
alter table app.lms_submission enable row level security;
alter table app.lms_submission_file enable row level security;
grant select on app.lms_assignment, app.lms_assignment_target, app.lms_assignment_file, app.lms_submission, app.lms_submission_file to authenticated;
create policy lms_assignment_read on app.lms_assignment for select to authenticated
  using ((select app.session_visible(session_id)));
create policy lms_assignment_target_read on app.lms_assignment_target for select to authenticated
  using ((select app.lms_assignment_visible(assignment_id)));
create policy lms_assignment_file_read on app.lms_assignment_file for select to authenticated
  using ((select app.lms_assignment_visible(assignment_id)));
create policy lms_submission_read on app.lms_submission for select to authenticated
  using ((select app.lms_assignment_visible(assignment_id)));
create policy lms_submission_file_read on app.lms_submission_file for select to authenticated
  using (exists (select from app.lms_submission s where s.id = submission_id and (select app.lms_assignment_visible(s.assignment_id))));

-- ---------------------------------------------------------------------------
-- 3. Hàm trợ giúp: kiểm quyền và công tắc
-- ---------------------------------------------------------------------------
-- app.lms_assert_assignment(bài, thao tác) -> bài giao (khoá dòng khi sửa)
-- Ai được gọi: hàm lms_* trong file này (không cấp cho giao diện). Kiểm: bài có tồn tại, người gọi có quyền ATTENDANCE <thao tác> với buổi giao
-- (giáo viên hoặc trợ giảng của buổi, vận hành theo cơ sở), phân hệ HOC_TAP bật ở cơ sở của bài (công tắc tính năng).
create or replace function app.lms_assert_assignment(p_id uuid, p_action text)
returns app.lms_assignment
language plpgsql
security definer
set search_path = ''
as $$
declare
  a app.lms_assignment;
begin
  select * into a from app.lms_assignment where id = p_id;
  if a.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy bài giao.');
  end if;
  -- Luật Q14: quyền sẵn có của buổi (không thêm quyền mới).
  perform app.assert_session_access(a.session_id, 'ATTENDANCE', p_action);
  perform app.require_feature('HOC_TAP', a.branch_id);
  return a;
end;
$$;
revoke execute on function app.lms_assert_assignment(uuid, text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Giao bài
-- ---------------------------------------------------------------------------
-- app.lms_create_assignment(p_data jsonb) -> jsonb {id}
-- Ai được gọi: giáo viên hoặc trợ giảng của buổi giao (ATTENDANCE Sửa), phân hệ HOC_TAP bật.
-- Đầu vào p_data: session_id (buổi giao), title, description, due_at (bỏ trống = giờ vào buổi sau), allow_resubmit (mặc định true),
--   allow_late (mặc định false), audience (CA_LOP | CHON_EM), student_ids (mảng, bắt buộc khi CHON_EM).
-- Luật: R-LMS-01 (hạn mặc định là giờ vào buổi sau; hai công tắc; cả lớp hoặc từng em); Q4 (mặc định Cho nộp lại bật, Nhận bài muộn tắt);
--   Q10 (không có buổi sau thì bắt buộc nhập hạn tay); Q11 (tối thiểu 1 em, chỉ em đang học trong lớp); hạn không được trước thời điểm giao.
-- Bản ghi chụp lại hạn, hai công tắc, danh sách em lúc giao.
create or replace function app.lms_create_assignment(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_title text := btrim(coalesce(p_data ->> 'title', ''));
  v_desc text := btrim(coalesce(p_data ->> 'description', ''));
  v_audience text := coalesce(p_data ->> 'audience', 'CA_LOP');
  v_due timestamptz := nullif(p_data ->> 'due_at', '')::timestamptz;
  v_next uuid;
  v_students uuid[];
  v_id uuid;
begin
  s := app.assert_session_access((p_data ->> 'session_id')::uuid, 'ATTENDANCE', 'SUA');
  perform app.require_feature('HOC_TAP', s.branch_id);

  -- Luật: buổi giao phải là buổi thật của lớp (không phải buổi bị thay hoặc huỷ).
  if s.status_code not in ('NHAP', 'DA_CHOT', 'DONE') then
    perform app.raise_error('HMT_LMS_BUOI_KHONG_GIAO_DUOC', 'Buổi này đã huỷ hoặc bị thay nên không giao bài được.');
  end if;
  if v_title = '' then
    perform app.raise_error('HMT_LMS_THIEU_TIEU_DE', 'Nhập tiêu đề bài giao.');
  end if;
  -- Phương án B (chưa có tệp): bài giao cần mô tả.
  if v_desc = '' then
    perform app.raise_error('HMT_LMS_THIEU_MO_TA', 'Nhập mô tả bài giao (chưa bật đính kèm tệp).');
  end if;
  if v_audience not in ('CA_LOP', 'CHON_EM') then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Đối tượng giao bài không hợp lệ.');
  end if;

  -- Luật R-LMS-01, Q10: hạn mặc định = giờ vào buổi sau; không có buổi sau thì bắt buộc nhập hạn.
  if v_due is null then
    select ns.id into v_next
      from app.class_session ns
     where ns.class_id = s.class_id and ns.status_code in ('NHAP', 'DA_CHOT', 'DONE')
       and (ns.session_date, ns.start_time, ns.id) > (s.session_date, s.start_time, s.id)
     order by ns.session_date, ns.start_time, ns.id
     limit 1;
    if v_next is null then
      perform app.raise_error('HMT_LMS_CAN_HAN_NOP', 'Lớp chưa có buổi sau: hãy chọn hạn nộp.');
    end if;
    v_due := app.session_starts_at(v_next);
  end if;
  if v_due <= now() then
    perform app.raise_error('HMT_LMS_HAN_TRONG_QUA_KHU', 'Hạn nộp phải sau thời điểm giao bài.');
  end if;

  -- Luật Q11: người nhận chỉ là em đang học trong lớp; cả lớp thì lấy tất cả em đang học; tối thiểu 1 em.
  if v_audience = 'CA_LOP' then
    select coalesce(array_agg(distinct e.student_id), '{}') into v_students
      from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
     where ec.class_id = s.class_id and ec.end_date is null;
  else
    select coalesce(array_agg(distinct x.sid), '{}') into v_students
      from (select (j.value #>> '{}')::uuid as sid from jsonb_array_elements(coalesce(p_data -> 'student_ids', '[]'::jsonb)) j) x;
    if exists (select from unnest(v_students) u (sid)
                where not exists (select from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                   where ec.class_id = s.class_id and ec.end_date is null and e.student_id = u.sid)) then
      perform app.raise_error('HMT_LMS_EM_KHONG_TRONG_LOP', 'Chỉ giao cho em đang học trong lớp.');
    end if;
  end if;
  if coalesce(array_length(v_students, 1), 0) = 0 then
    perform app.raise_error('HMT_LMS_CHUA_CHON_EM', 'Chọn ít nhất một em đang học để giao bài.');
  end if;

  insert into app.lms_assignment (class_id, session_id, branch_id, title, description, due_at, allow_resubmit, allow_late, audience)
  values (s.class_id, s.id, s.branch_id, v_title, v_desc, v_due,
          coalesce((p_data ->> 'allow_resubmit')::boolean, true),  -- Q4: mặc định Cho nộp lại bật
          coalesce((p_data ->> 'allow_late')::boolean, false),     -- Q4: mặc định Nhận bài muộn tắt
          v_audience)
  returning id into v_id;
  insert into app.lms_assignment_target (assignment_id, student_id) select v_id, u from unnest(v_students) u;
  return jsonb_build_object('id', v_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Sửa bài đã giao
-- ---------------------------------------------------------------------------
-- app.lms_update_assignment(p_id uuid, p_data jsonb, p_version integer) -> jsonb {id, version, has_submissions}
-- Ai được gọi: giáo viên hoặc trợ giảng của buổi giao (ATTENDANCE Sửa), phân hệ HOC_TAP bật.
-- Đầu vào p_data: title, description, due_at, allow_resubmit, allow_late (chỉ gửi trường muốn đổi). p_version: số phiên bản lúc mở màn.
-- Luật Q2: chưa em nào nộp thì sửa được tiêu đề, mô tả, hạn, công tắc; ĐÃ có em nộp thì nội dung bài (tiêu đề, mô tả, tệp) khoá,
--   hạn và hai công tắc vẫn đổi được (UI cảnh báo). Chống ghi đè bằng version (HMT_XUNG_DOT). Bài đã gỡ không sửa.
-- Chưa gửi thông báo cho em nhận (làm cùng cổng học sinh, CHUNG-12).
create or replace function app.lms_update_assignment(p_id uuid, p_data jsonb, p_version integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  a app.lms_assignment;
  v_has boolean;
  v_title text;
  v_desc text;
  v_due timestamptz;
begin
  a := app.lms_assert_assignment(p_id, 'SUA');
  select * into a from app.lms_assignment where id = p_id for update;
  if a.status = 'DA_GO' then
    perform app.raise_error('HMT_LMS_DA_GO', 'Bài này đã gỡ, không sửa được.');
  end if;
  -- Luật Q-243: người khác vừa sửa thì từ chối, không ghi đè lặng lẽ.
  if p_version is distinct from a.version then
    perform app.raise_error('HMT_XUNG_DOT', 'Bài này vừa được người khác sửa, tải lại để xem.');
  end if;
  select exists (select from app.lms_submission m where m.assignment_id = a.id and m.submitted_at is not null) into v_has;

  -- Luật Q2: có bài nộp thì khoá nội dung bài.
  if v_has and (p_data ? 'title' or p_data ? 'description') then
    perform app.raise_error('HMT_LMS_DA_CO_BAI_NOP', 'Đã có em nộp bài: không sửa tiêu đề, mô tả. Chỉ đổi hạn nộp hoặc công tắc.');
  end if;
  v_title := case when p_data ? 'title' then btrim(coalesce(p_data ->> 'title', '')) else a.title end;
  v_desc := case when p_data ? 'description' then btrim(coalesce(p_data ->> 'description', '')) else a.description end;
  if v_title = '' then
    perform app.raise_error('HMT_LMS_THIEU_TIEU_DE', 'Nhập tiêu đề bài giao.');
  end if;
  if v_desc = '' then
    perform app.raise_error('HMT_LMS_THIEU_MO_TA', 'Nhập mô tả bài giao (chưa bật đính kèm tệp).');
  end if;
  v_due := case when p_data ? 'due_at' then (p_data ->> 'due_at')::timestamptz else a.due_at end;
  if v_due is null or (v_due is distinct from a.due_at and v_due <= now()) then
    perform app.raise_error('HMT_LMS_HAN_TRONG_QUA_KHU', 'Hạn nộp phải sau thời điểm hiện tại.');
  end if;

  update app.lms_assignment
     set title = v_title, description = v_desc, due_at = v_due,
         allow_resubmit = coalesce((p_data ->> 'allow_resubmit')::boolean, allow_resubmit),
         allow_late = coalesce((p_data ->> 'allow_late')::boolean, allow_late),
         version = version + 1
   where id = a.id;
  return jsonb_build_object('id', a.id, 'version', a.version + 1, 'has_submissions', v_has);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Gỡ bài
-- ---------------------------------------------------------------------------
-- app.lms_withdraw_assignment(p_id uuid, p_version integer) -> jsonb {id}
-- Ai được gọi: giáo viên hoặc trợ giảng của buổi giao (ATTENDANCE Sửa; Q14 theo ma trận quyền sẵn có), phân hệ HOC_TAP bật.
-- Luật Q2: chỉ gỡ khi chưa em nào nộp; Gỡ = đổi trạng thái DA_GO (không xoá cứng, CLAUDE.md).
create or replace function app.lms_withdraw_assignment(p_id uuid, p_version integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  a app.lms_assignment;
begin
  a := app.lms_assert_assignment(p_id, 'SUA');
  select * into a from app.lms_assignment where id = p_id for update;
  if a.status = 'DA_GO' then
    perform app.raise_error('HMT_LMS_DA_GO', 'Bài này đã gỡ rồi.');
  end if;
  if p_version is distinct from a.version then
    perform app.raise_error('HMT_XUNG_DOT', 'Bài này vừa được người khác sửa, tải lại để xem.');
  end if;
  if exists (select from app.lms_submission m where m.assignment_id = a.id and m.submitted_at is not null) then
    perform app.raise_error('HMT_LMS_DA_CO_BAI_NOP', 'Đã có em nộp bài nên không gỡ được.');
  end if;
  update app.lms_assignment set status = 'DA_GO', version = version + 1 where id = a.id;
  return jsonb_build_object('id', a.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Danh sách «Bài đã giao» của lớp và mở một bài
-- ---------------------------------------------------------------------------
-- app.lms_list_assignments(p_class_id uuid, p_limit integer, p_offset integer) -> jsonb {total, rows}
-- Ai được gọi: người có quyền ATTENDANCE Xem với lớp (giáo viên, trợ giảng của lớp; vận hành theo cơ sở), phân hệ HOC_TAP bật.
-- Kết quả: bài mới nhất trước, mỗi bài có số em nhận, số em đã nộp, số em đã chấm. Phân trang máy chủ, tối đa 100 dòng (quy ước hiệu năng).
create or replace function app.lms_list_assignments(p_class_id uuid, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c app.class;
  v_scope text;
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100); -- allow-number: trần phân trang theo quy ước hiệu năng
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_total bigint;
  v_rows jsonb;
begin
  select * into c from app.class where id = p_class_id;
  v_scope := app.permission_scope('ATTENDANCE', 'XEM');
  -- Luật R-GV-08: lớp không tồn tại, lớp của người khác, thiếu quyền: cùng một lỗi (không lộ sự tồn tại).
  if c.id is null or v_scope is null
     or (v_scope = 'CO_SO' and c.branch_id is distinct from app.current_branch_id())
     or (v_scope = 'DUOC_PHAN_CONG' and not app.is_assigned_to_class(c.id)) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem bài giao của lớp này.');
  end if;
  perform app.require_feature('HOC_TAP', c.branch_id);
  select count(*) into v_total from app.lms_assignment a where a.class_id = c.id;
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', x.id, 'title', x.title, 'description', x.description, 'due_at', x.due_at, 'status', x.status, 'version', x.version,
           'audience', x.audience, 'allow_resubmit', x.allow_resubmit, 'allow_late', x.allow_late, 'session_id', x.session_id,
           'session_no', x.session_no, 'created_at', x.created_at,
           'targets', x.targets, 'submitted', x.submitted, 'graded', x.graded) order by x.created_at desc, x.id), '[]'::jsonb)
    into v_rows
    from (
      select a.*, sn.session_no,
             (select count(*) from app.lms_assignment_target t where t.assignment_id = a.id) as targets,
             (select count(*) from app.lms_submission m where m.assignment_id = a.id and m.submitted_at is not null) as submitted,
             (select count(*) from app.lms_submission m where m.assignment_id = a.id and m.graded_at is not null) as graded
        from app.lms_assignment a join app.class_session sn on sn.id = a.session_id
       where a.class_id = c.id
       order by a.created_at desc, a.id
       limit v_limit offset v_offset
    ) x;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Quyền gọi hàm: chỉ người đăng nhập; kiểm quyền thật nằm trong hàm
-- ---------------------------------------------------------------------------
revoke execute on function app.lms_create_assignment(jsonb), app.lms_update_assignment(uuid, jsonb, integer),
  app.lms_withdraw_assignment(uuid, integer), app.lms_list_assignments(uuid, integer, integer) from public, anon, authenticated;
grant execute on function app.lms_create_assignment(jsonb), app.lms_update_assignment(uuid, jsonb, integer),
  app.lms_withdraw_assignment(uuid, integer), app.lms_list_assignments(uuid, integer, integer) to authenticated;
