-- D1b (Code 2, 10/11/2026): Ghi danh, dòng xếp lớp, sổ giờ.
-- Luật: R-GD-01..06, 08, 10, 15, 18; R-TIEN-20, 21, 24, 26 (giờ tính lại theo tiền còn lại); R-LOP-04 (đóng lớp); R-V2-33 (số dư đầu kỳ).
-- Làm gì: bảng ghi danh (mỗi dòng đơn một ghi danh), dòng xếp lớp, sổ giờ chỉ thêm; mã GD; hàm kiểm lớp trên dòng đơn (thay thân
-- app.check_order_line_class); tạo ghi danh khi đơn đủ cọc; cấp giờ theo tỉ lệ tiền đã thu; xếp lớp, chuyển lớp (nội bộ, chờ ticket A1);
-- điều chỉnh giờ; số dư đầu kỳ (cho nạp dữ liệu); thay thân app.class_students_with_hours.
-- Chưa có: trừ giờ khi buổi Done và danh sách buổi (D1c); bảo lưu, dừng, hoàn phí, chuyển phí (ticket A1, không thuộc đợt này).
-- Hàm app.create_enrollments_for_order và app.sync_enrollment_hours là nội bộ: nơi duyệt phiếu thu (Code 1, B2) gọi sau khi sinh khoản
-- tiền vào, trong cùng giao dịch. Chưa nối vì không sửa hàm của Code 1; đã ghi câu hỏi cho Chat.
-- GỘP SAU #205 và Q-137 và sau migration 100.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- 1. Mã ghi danh GD + 6 số (spec 02), cấp bằng bảng đếm khoá dòng.
-- ---------------------------------------------------------------------------
insert into app.code_format (code, name, prefix, pad_width, start_value) values ('GD', 'Ghi danh', 'GD', 6, 1);

create or replace function app.issue_enrollment_code()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_format app.code_format := app.code_format_of('GD');
begin
  return v_format.prefix || lpad(app.next_counter_value('GD', v_format.start_value)::text, v_format.pad_width, '0');
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Bảng ghi danh, dòng xếp lớp, sổ giờ
-- ---------------------------------------------------------------------------
create table app.enrollment (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  order_id uuid references app.sales_order (id),
  -- Mỗi dòng đơn sinh một ghi danh (R-GD-01). Null với ghi danh nạp từ hệ thống cũ (không có đơn).
  order_line_id uuid unique references app.sales_order_line (id),
  student_id uuid not null references app.student (id),
  parent_id uuid not null references app.parent (id),
  branch_id uuid not null references app.branch (id),
  package_id uuid references app.sales_package (id),
  subject_code text,
  delivery_mode_code text,
  status_catalog text not null default 'ENROLLMENT_STATUS' check (status_catalog = 'ENROLLMENT_STATUS'),
  status_code text not null default 'CHO_XEP_LOP',
  -- Chụp lại từ dòng đơn lúc tạo (CLAUDE.md, cấu hình có hiệu lực): giờ mua, giờ tặng.
  purchased_hours numeric(6, 2) not null default 0 check (purchased_hours >= 0),
  gifted_hours numeric(6, 2) not null default 0 check (gifted_hours >= 0),
  start_date date,
  legacy_ref text,
  search_text text generated always as (app.fold_text(code || ' ' || coalesce(legacy_ref, ''))) stored,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (status_catalog, status_code) references app.catalog_item (catalog_code, code)
);
comment on table app.enrollment is 'Ghi danh (R-GD-01): mỗi dòng đơn một ghi danh, một quỹ giờ (tính từ app.hour_ledger). Ghi chỉ qua hàm nghiệp vụ.';
-- Chỉ mục (lý do): học sinh (hồ sơ học sinh, tìm ghi danh); phụ huynh (khoá ngoại); đơn (cấp giờ khi có tiền); cơ sở + tình trạng cho danh sách và RLS.
create index enrollment_student_idx on app.enrollment (student_id, status_code);
create index enrollment_parent_idx on app.enrollment (parent_id);
create index enrollment_order_idx on app.enrollment (order_id) where order_id is not null;
create index enrollment_branch_status_idx on app.enrollment (branch_id, status_code, created_at desc);
-- Hàng chờ xếp lớp (GD-06): chỉ ghi danh Chờ xếp lớp, cũ nhất trước.
create index enrollment_waiting_idx on app.enrollment (branch_id, created_at) where status_code = 'CHO_XEP_LOP';
create index enrollment_search_idx on app.enrollment using gin (search_text gin_trgm_ops);
select app.apply_standard('app.enrollment');

-- Dòng xếp lớp (R-GD-02): bình thường một lớp đang học; chuyển lớp thì đóng dòng cũ, mở dòng mới.
create table app.enrollment_class (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references app.enrollment (id),
  class_id uuid not null references app.class (id),
  branch_id uuid not null references app.branch (id),
  start_date date not null,
  end_date date,
  end_reason text check (end_reason in ('CHUYEN_LOP', 'DUNG', 'KET_THUC', 'NHAP_NHAM')),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (end_date is null or end_date >= start_date),
  check ((end_date is null) = (end_reason is null))
);
comment on table app.enrollment_class is 'Dòng xếp lớp của ghi danh: lớp, ngày vào, ngày rời. Sĩ số, danh sách lớp đọc từ các dòng đang mở (end_date null).';
-- Bình thường một ghi danh có đúng một lớp đang học (R-GD-02).
create unique index enrollment_class_open_uq on app.enrollment_class (enrollment_id) where end_date is null;
-- Chỉ mục (lý do): danh sách học sinh của lớp, sĩ số (lớp đang mở); lịch sử của ghi danh; cơ sở cho RLS.
create index enrollment_class_class_open_idx on app.enrollment_class (class_id) where end_date is null;
create index enrollment_class_enrollment_idx on app.enrollment_class (enrollment_id, start_date);
create index enrollment_class_branch_idx on app.enrollment_class (branch_id);
select app.apply_standard('app.enrollment_class');

-- Sổ giờ (R-GD-04): chỉ thêm dòng; điều chỉnh bằng dòng ngược dấu kèm lý do; số dư luôn tính từ đây.
create table app.hour_ledger (
  id uuid primary key default gen_random_uuid(),
  seq bigint generated always as identity,
  enrollment_id uuid not null references app.enrollment (id),
  branch_id uuid not null references app.branch (id),
  entry_type text not null check (entry_type in ('CAP_MUA', 'CAP_TANG', 'DAU_KY', 'TRU_BUOI', 'DIEU_CHINH', 'CHUYEN_PHI')),
  hours numeric(6, 2) not null check (hours <> 0),
  session_id uuid references app.class_session (id),
  reason_catalog text not null default 'HOURS_ADJUST_REASON' check (reason_catalog = 'HOURS_ADJUST_REASON'),
  reason_code text,
  note text,
  -- Mã ticket (nghiệp vụ chuyển phí…), hoặc đợt nạp dữ liệu.
  source_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (reason_catalog, reason_code) references app.catalog_item (catalog_code, code),
  check (entry_type <> 'TRU_BUOI' or (session_id is not null and hours < 0)),
  check (entry_type <> 'DIEU_CHINH' or (reason_code is not null))
);
comment on table app.hour_ledger is 'Sổ giờ của ghi danh: cấp theo tiền (CAP_MUA, CAP_TANG), số dư đầu kỳ, trừ buổi Done, điều chỉnh. Chỉ thêm, không sửa, không xoá (R-GD-04).';
-- Chỉ mục (lý do): số dư và sổ của một ghi danh theo thứ tự ghi; trừ giờ đúng một lần mỗi buổi mỗi ghi danh (R-GIO-04); cơ sở cho RLS.
create index hour_ledger_enrollment_idx on app.hour_ledger (enrollment_id, seq);
create unique index hour_ledger_session_uq on app.hour_ledger (enrollment_id, session_id) where entry_type = 'TRU_BUOI';
create index hour_ledger_session_idx on app.hour_ledger (session_id) where session_id is not null;
create index hour_ledger_branch_idx on app.hour_ledger (branch_id);
select app.apply_standard('app.hour_ledger');
-- Luật R-GD-04: sổ giờ không sửa được (apply_standard đã chặn xoá).
create or replace function app.tg_hour_ledger_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform app.raise_error('HMT_SO_GIO_CHI_THEM', 'Sổ giờ chỉ thêm dòng, không sửa. Điều chỉnh bằng dòng ngược dấu kèm lý do.');
  return null;
end;
$$;
create trigger hour_ledger_no_update before update on app.hour_ledger
  for each row execute function app.tg_hour_ledger_append_only();

-- ---------------------------------------------------------------------------
-- 3. RLS: đọc theo quyền Xem ghi danh; giáo viên thấy ghi danh của lớp mình; ghi chỉ qua hàm
-- ---------------------------------------------------------------------------
alter table app.enrollment enable row level security;
alter table app.enrollment_class enable row level security;
alter table app.hour_ledger enable row level security;
revoke all on app.enrollment, app.enrollment_class, app.hour_ledger from public, anon, authenticated;
grant select on app.enrollment, app.enrollment_class, app.hour_ledger to authenticated;

-- Người dùng hiện tại được phân công vào một lớp mà ghi danh đang (hoặc từng) xếp. Security definer để tránh vòng lặp RLS.
create or replace function app.is_assigned_to_enrollment(p_enrollment_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.enrollment_class ec where ec.enrollment_id = p_enrollment_id and app.is_assigned_to_class(ec.class_id));
$$;

create policy enrollment_read on app.enrollment for select to authenticated
  using ((select app.permission_scope('ENROLLMENT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('ENROLLMENT', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id()))
         or ((select app.permission_scope('ENROLLMENT', 'XEM')) = 'DUOC_PHAN_CONG' and (select app.is_assigned_to_enrollment(id))));
create policy enrollment_class_read on app.enrollment_class for select to authenticated
  using ((select app.permission_scope('ENROLLMENT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('ENROLLMENT', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id()))
         or ((select app.permission_scope('ENROLLMENT', 'XEM')) = 'DUOC_PHAN_CONG' and (select app.is_assigned_to_class(class_id))));
-- Sổ giờ: không cho giáo viên đọc (R-GV-13: giáo viên không thấy học phí, giờ mua); chỉ vận hành.
create policy hour_ledger_read on app.hour_ledger for select to authenticated
  using ((select app.permission_scope('ENROLLMENT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('ENROLLMENT', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id())));

-- ---------------------------------------------------------------------------
-- 4. Số dư và kiểm lớp
-- ---------------------------------------------------------------------------
-- Số dư quỹ giờ của ghi danh = tổng sổ giờ (R-GD-03, R-GD-04).
create or replace function app.enrollment_hours_balance(p_enrollment_id uuid)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(hours), 0)::numeric(6, 2) from app.hour_ledger where enrollment_id = p_enrollment_id;
$$;

-- Môn của gói khớp môn của lớp: gói TOAN xếp được lớp TOAN, DAI, HINH (spec 02 mục 8); môn khác phải trùng.
create or replace function app.package_matches_class_subject(p_package_subject text, p_class_subject text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_package_subject is null or p_package_subject = p_class_subject
         or (p_package_subject = 'TOAN' and p_class_subject in ('DAI', 'HINH'));
$$;

-- Số chỗ còn lại của lớp; null = không giới hạn (max_students = 0, R-GD-08). Đếm dòng xếp lớp đang mở của ghi danh còn hiệu lực.
create or replace function app.class_seats_left(p_class_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select case when c.max_students = 0 then null
              else c.max_students - (select count(*) from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                                      where ec.class_id = c.id and ec.end_date is null
                                        and e.status_code in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU'))::integer
         end
    from app.class c where c.id = p_class_id;
$$;

-- Lớp hợp lệ cho gói, cơ sở (R-GD-08): đã duyệt, đúng môn, khối, cơ sở, còn chỗ. Báo lỗi có mã, nêu số dòng (p_label).
-- p_enrollment: ghi danh đang xếp (bỏ ra khỏi sĩ số khi chuyển trong cùng lớp), null khi kiểm trên đơn.
create or replace function app.assert_class_fits(p_class_id uuid, p_package_id uuid, p_branch_id uuid, p_label text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c app.class;
  p app.sales_package;
begin
  select * into c from app.class where id = p_class_id;
  if c.id is null then
    perform app.raise_error('HMT_LOP_KHONG_TIM_THAY', format('%s: không tìm thấy lớp.', p_label));
  end if;
  -- Luật R-GD-08: lớp đã duyệt.
  if c.status_code <> 'DA_DUYET' then
    perform app.raise_error('HMT_LOP_CHUA_DUYET', format('%s: lớp chưa duyệt hoặc đã đóng, không xếp được.', p_label));
  end if;
  if c.branch_id <> p_branch_id then
    perform app.raise_error('HMT_LOP_SAI_CO_SO', format('%s: lớp thuộc cơ sở khác.', p_label));
  end if;
  select * into p from app.sales_package where id = p_package_id;
  if p.id is not null then
    if not app.package_matches_class_subject(p.subject_code, c.subject_code) then
      perform app.raise_error('HMT_LOP_SAI_MON', format('%s: lớp không đúng môn của gói.', p_label));
    end if;
    if p.grade_from_code is not null and (c.grade_code < p.grade_from_code or c.grade_code > coalesce(p.grade_to_code, p.grade_from_code)) then
      perform app.raise_error('HMT_LOP_SAI_KHOI', format('%s: lớp không đúng khối của gói.', p_label));
    end if;
  end if;
  if coalesce(app.class_seats_left(p_class_id), 1) <= 0 then
    perform app.raise_error('HMT_LOP_HET_CHO', format('%s: lớp đã đủ sĩ số tối đa.', p_label));
  end if;
end;
$$;

-- Thay thân hàm kiểm lớp trên dòng đơn (migration 051 giữ chỗ): nay kiểm thật (R-GD-08, 26/10). Chỗ gọi (lưu, trình, duyệt) không đổi.
create or replace function app.check_order_line_class(p_line_no integer, p_class_id uuid, p_package_id uuid, p_branch_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_class_id is not null then
    perform app.assert_class_fits(p_class_id, p_package_id, p_branch_id, format('Dòng %s', p_line_no));
  end if;
end;
$$;

-- Thay thân giữ chỗ ở migration 100: lớp chưa đóng được khi còn học sinh còn giờ (R-LOP-04), liệt kê tên.
create or replace function app.class_students_with_hours(p_class_id uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(s.full_name order by s.full_name), '{}'::text[])
    from app.enrollment_class ec
    join app.enrollment e on e.id = ec.enrollment_id
    join app.student s on s.id = e.student_id
   where ec.class_id = p_class_id and ec.end_date is null
     and e.status_code in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU')
     and app.enrollment_hours_balance(e.id) > 0;
$$;

-- ---------------------------------------------------------------------------
-- 5. Xếp lớp: ngày vào lớp, trùng giờ
-- ---------------------------------------------------------------------------
-- Luật R-GD-06: ngày vào lớp. Lớp đã có buổi thì chọn một trong các buổi sắp tới; chưa có buổi thì chọn ngày đúng thứ có lịch
-- và không trước ngày khai giảng.
create or replace function app.assert_enrol_start_date(p_class_id uuid, p_start date, p_label text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c app.class;
begin
  select * into c from app.class where id = p_class_id;
  if p_start is null then
    perform app.raise_error('HMT_NGAY_VAO_LOP_THIEU', format('%s: cần chọn ngày vào lớp.', p_label));
  end if;
  if exists (select from app.class_session where class_id = p_class_id and status_code in ('NHAP', 'DA_CHOT', 'DONE')) then
    if not exists (select from app.class_session where class_id = p_class_id and session_date = p_start and status_code in ('NHAP', 'DA_CHOT')) then
      perform app.raise_error('HMT_NGAY_VAO_LOP_SAI', format('%s: ngày vào lớp phải là một buổi sắp tới của lớp.', p_label));
    end if;
  else
    if p_start < c.start_date or not exists (select from app.class_slot s where s.class_id = p_class_id and s.is_active
                                                and s.weekday = extract(isodow from p_start)) then
      perform app.raise_error('HMT_NGAY_VAO_LOP_SAI', format('%s: ngày vào lớp phải đúng thứ có lịch và không trước ngày khai giảng.', p_label));
    end if;
  end if;
end;
$$;

-- Luật R-GD-15: xếp lớp chặn nếu có buổi trùng giờ (cùng ngày, giờ chồng nhau, tính cả buổi sắp sinh) với lớp em đang học,
-- kể cả lớp của ghi danh khác. Chỉ xét buổi từ ngày vào lớp. Hai lớp luân phiên (không buổi nào trùng) không bị chặn.
create or replace function app.assert_no_time_clash(p_student_id uuid, p_class_id uuid, p_start date, p_except_enrollment uuid, p_label text)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  select count(*) into v_n
    from app.enrollment e
    join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null and ec.class_id <> p_class_id
    join app.class_session b on b.class_id = ec.class_id and b.status_code in ('NHAP', 'DA_CHOT')
    join app.class_session a on a.class_id = p_class_id and a.status_code in ('NHAP', 'DA_CHOT') and a.session_date = b.session_date
         and b.start_time < a.end_time and a.start_time < b.end_time
   where e.student_id = p_student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC') and e.id is distinct from p_except_enrollment
     and a.session_date >= p_start;
  if v_n > 0 then
    perform app.raise_error('HMT_XEP_LOP_TRUNG_GIO',
      format('%s: có %s buổi trùng giờ với lớp em đang học, không xếp được.', p_label, v_n));
  end if;
end;
$$;

-- app.assign_enrollment_class(ghi danh, lớp, ngày vào): xếp lớp lần đầu cho ghi danh Chờ xếp lớp (GD-03, R-GD-05, R-GD-06).
-- Ai gọi: Ghi danh · Sửa ở cơ sở của ghi danh. Kết quả: ghi danh sang Đã xếp lớp.
create or replace function app.assign_enrollment_class(p_enrollment_id uuid, p_class_id uuid, p_start_date date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  c app.class;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.assert_can('ENROLLMENT', 'SUA', e.branch_id);
  perform app.require_feature('VAN_HANH_LOP', e.branch_id);
  -- Luật R-GD-05: chỉ ghi danh Chờ xếp lớp xếp lớp lần đầu; đổi lớp đi qua ticket (R-GD-10).
  if e.status_code <> 'CHO_XEP_LOP' then
    perform app.raise_error('HMT_GHI_DANH_KHONG_CHO_XEP', 'Chỉ ghi danh Chờ xếp lớp mới xếp lớp lần đầu. Đổi lớp đi qua ticket đề nghị.');
  end if;
  perform app.assert_class_fits(p_class_id, e.package_id, e.branch_id, 'Xếp lớp');
  perform app.assert_enrol_start_date(p_class_id, p_start_date, 'Xếp lớp');
  perform app.assert_no_time_clash(e.student_id, p_class_id, p_start_date, e.id, 'Xếp lớp');
  select * into c from app.class where id = p_class_id;
  insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values (e.id, p_class_id, c.branch_id, p_start_date);
  update app.enrollment set status_code = 'DA_XEP_LOP', start_date = p_start_date where id = e.id;
end;
$$;

-- app.move_enrollment_class(ghi danh, lớp mới, ngày vào, mã ticket): chuyển lớp (R-GD-10): đóng dòng xếp lớp cũ, mở dòng mới, giờ còn lại
-- đi theo ghi danh. NỘI BỘ: chỉ nghiệp vụ ticket đề nghị đã duyệt (A1) được gọi; không cấp cho giao diện.
create or replace function app.move_enrollment_class(p_enrollment_id uuid, p_new_class_id uuid, p_start_date date, p_ticket_ref text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  c app.class;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  if e.status_code not in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU') then
    perform app.raise_error('HMT_GHI_DANH_KHONG_CHUYEN_DUOC', 'Ghi danh này không còn hiệu lực để chuyển lớp.');
  end if;
  select * into c from app.class where id = p_new_class_id;
  if c.id is null then
    perform app.raise_error('HMT_LOP_KHONG_TIM_THAY', 'Chuyển lớp: không tìm thấy lớp.');
  end if;
  -- Chuyển cơ sở giữ nguyên giờ (R-GD-10): lớp mới có thể ở cơ sở khác; kiểm môn, khối, chỗ theo cơ sở của lớp mới.
  perform app.assert_class_fits(p_new_class_id, e.package_id, c.branch_id, 'Chuyển lớp');
  perform app.assert_enrol_start_date(p_new_class_id, p_start_date, 'Chuyển lớp');
  perform app.assert_no_time_clash(e.student_id, p_new_class_id, p_start_date, e.id, 'Chuyển lớp');
  update app.enrollment_class set end_date = greatest(p_start_date - 1, start_date), end_reason = 'CHUYEN_LOP'
   where enrollment_id = e.id and end_date is null;
  insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values (e.id, p_new_class_id, c.branch_id, p_start_date);
  update app.enrollment set branch_id = c.branch_id where id = e.id and branch_id <> c.branch_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Tạo ghi danh khi đơn đủ cọc, cấp giờ theo tiền (R-TIEN-20, 21, 24)
-- ---------------------------------------------------------------------------
-- Số giờ phải có trong sổ cho một loại cấp, theo tiền đã chia về dòng (R-TIEN-21): giờ dòng × tiền dòng đã nhận ÷ thành tiền dòng.
--   Giờ tặng chỉ cấp khi đơn đã thu đủ (R-TIEN-24).
create or replace function app.enrollment_target_hours(p_order_line_id uuid, p_kind text)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when p_kind = 'CAP_MUA' then
             case when l.line_total = 0 then 0
                  else round(l.quantity * least(coalesce(a.paid, 0), l.line_total)::numeric / l.line_total, 2) end -- allow-number: làm tròn 2 chữ số thập phân của giờ (numeric(6,2))
           else
             case when o.total_amount > 0 and coalesce(op.paid, 0) >= o.total_amount then l.gifted_quantity else 0 end
         end
    from app.sales_order_line l
    join app.sales_order o on o.id = l.order_id
    left join lateral (select sum(m.amount) paid from app.money_in_allocation m where m.order_line_id = l.id) a on true
    left join lateral (select sum(m.amount) paid from app.money_in m where m.order_id = o.id) op on true
   where l.id = p_order_line_id;
$$;

-- app.sync_enrollment_hours(đơn): đưa sổ giờ khớp tiền đã thu. Mỗi loại cấp, thêm dòng chênh lệch giữa số phải có và số đã ghi
-- (dương khi thu thêm; âm khi khoản tiền bị đảo, R-TIEN-26). Chạy lại nhiều lần không đổi kết quả. NỘI BỘ: gọi sau khi sinh khoản tiền vào.
create or replace function app.sync_enrollment_hours(p_order_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_target numeric;
  v_have numeric;
  v_kind text;
  v_n integer := 0;
begin
  for r in select e.id, e.branch_id, e.order_line_id from app.enrollment e where e.order_id = p_order_id and e.order_line_id is not null loop
    foreach v_kind in array array['CAP_MUA', 'CAP_TANG'] loop
      v_target := app.enrollment_target_hours(r.order_line_id, v_kind);
      select coalesce(sum(hours), 0) into v_have from app.hour_ledger where enrollment_id = r.id and entry_type = v_kind;
      if v_target <> v_have then
        insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) values (r.id, r.branch_id, v_kind, v_target - v_have);
        v_n := v_n + 1;
      end if;
    end loop;
  end loop;
  return v_n;
end;
$$;

-- app.create_enrollments_for_order(đơn): tạo ghi danh cho các dòng đơn khi tổng tiền đã vào ≥ tiền cọc tối thiểu (R-TIEN-20).
--   Mỗi dòng đơn giờ (ENROL, tính theo giờ) có học sinh một ghi danh, một quỹ giờ (R-GD-01); chạy lại không tạo trùng.
--   Dòng có lớp: kiểm chỗ lần cuối (R-GD-08); lớp đầy hoặc không còn hợp lệ thì ghi danh vào hàng chờ xếp lớp, không chặn thu tiền.
--   Rồi cấp giờ theo tiền (sync_enrollment_hours). NỘI BỘ: gọi sau khi kế toán duyệt phiếu thu, trong cùng giao dịch.
-- Kết quả: {created, queued (số ghi danh vào hàng chờ vì lớp không xếp được)}.
create or replace function app.create_enrollments_for_order(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
  l record;
  v_id uuid;
  v_created integer := 0;
  v_queued integer := 0;
  v_ok boolean;
  v_class app.class;
begin
  select * into o from app.sales_order where id = p_order_id for update;
  if o.id is null or o.status_code <> 'DA_DUYET' then
    return jsonb_build_object('created', 0, 'queued', 0);
  end if;
  -- Luật R-TIEN-20: chưa đủ cọc thì chưa tạo ghi danh.
  if coalesce((select sum(amount) from app.money_in where order_id = o.id), 0) < app.get_setting_int('deposit_min_amount', o.branch_id) then
    return jsonb_build_object('created', 0, 'queued', 0);
  end if;
  for l in select sl.*, p.subject_code as pkg_subject from app.sales_order_line sl
             left join app.sales_package p on p.id = sl.package_id
            where sl.order_id = o.id and sl.is_live and sl.line_kind = 'ENROL' and sl.unit_code = 'GIO' and sl.student_id is not null
              and not exists (select from app.enrollment e where e.order_line_id = sl.id)
            order by sl.line_no loop
    insert into app.enrollment (code, order_id, order_line_id, student_id, parent_id, branch_id, package_id, subject_code, delivery_mode_code,
                                purchased_hours, gifted_hours, start_date)
    values (app.issue_enrollment_code(), o.id, l.id, l.student_id, o.parent_id, o.branch_id, l.package_id, l.pkg_subject, l.delivery_mode_code,
            l.quantity, l.gifted_quantity, l.enrol_start_date)
    returning id into v_id;
    v_created := v_created + 1;
    -- Có lớp: kiểm lần cuối rồi xếp (Đã xếp lớp); không thì Chờ xếp lớp.
    if l.class_id is not null then
      v_ok := true;
      begin
        perform app.assert_class_fits(l.class_id, l.package_id, o.branch_id, 'Ghi danh');
        perform app.assert_enrol_start_date(l.class_id, l.enrol_start_date, 'Ghi danh');
        perform app.assert_no_time_clash(l.student_id, l.class_id, l.enrol_start_date, v_id, 'Ghi danh');
      exception when others then
        v_ok := false;
      end;
      if v_ok then
        select * into v_class from app.class where id = l.class_id;
        insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date) values (v_id, l.class_id, v_class.branch_id, l.enrol_start_date);
        update app.enrollment set status_code = 'DA_XEP_LOP' where id = v_id;
      else
        v_queued := v_queued + 1;
      end if;
    end if;
  end loop;
  perform app.sync_enrollment_hours(o.id);
  return jsonb_build_object('created', v_created, 'queued', v_queued);
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Điều chỉnh giờ, số dư đầu kỳ
-- ---------------------------------------------------------------------------
-- app.adjust_enrollment_hours(ghi danh, giờ, lý do, ghi chú): thêm dòng điều chỉnh vào sổ giờ (GD-05, R-GD-04). Không sửa dòng cũ.
-- Ai gọi: Ghi danh · Duyệt (Trưởng cơ sở, Admin) ở cơ sở của ghi danh. Giờ khác 0 (dương thêm, âm bớt). Bắt buộc lý do (danh mục 25);
-- lý do "Khác" bắt buộc ghi chú. Không để quỹ âm khi bớt giờ (R-GD-18) trừ khi ghi danh đang trong hạn mức cho học trước.
create or replace function app.adjust_enrollment_hours(p_enrollment_id uuid, p_hours numeric, p_reason_code text, p_note text default null)
returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  e app.enrollment;
  v_requires_note boolean;
begin
  select * into e from app.enrollment where id = p_enrollment_id for update;
  if e.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;
  perform app.assert_can('ENROLLMENT', 'DUYET', e.branch_id);
  if p_hours is null or p_hours = 0 then
    perform app.raise_error('HMT_GIO_DIEU_CHINH_SAI', 'Số giờ điều chỉnh phải khác 0.');
  end if;
  perform app.assert_catalog_code_active('HOURS_ADJUST_REASON', p_reason_code);
  select requires_note into v_requires_note from app.catalog_item where catalog_code = 'HOURS_ADJUST_REASON' and code = p_reason_code;
  if v_requires_note and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_CAN_GHI_CHU', 'Lý do "Khác" cần ghi chú.');
  end if;
  -- Luật R-GD-18: không cho quỹ âm bằng điều chỉnh tay.
  if p_hours < 0 and app.enrollment_hours_balance(e.id) + p_hours < 0 then
    perform app.raise_error('HMT_QUY_GIO_AM', 'Quỹ giờ của ghi danh không đủ để bớt số giờ này.');
  end if;
  insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, reason_code, note)
  values (e.id, e.branch_id, 'DIEU_CHINH', p_hours, p_reason_code, nullif(btrim(p_note), ''));
  return app.enrollment_hours_balance(e.id);
end;
$$;

-- app.add_opening_hours(ghi danh, giờ, mã đợt nạp): dòng "Số dư đầu kỳ" cho nạp dữ liệu cũ (R-V2-33). NỘI BỘ (hàm nạp gọi).
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
  insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, source_ref) values (e.id, e.branch_id, 'DAU_KY', p_hours, p_source_ref);
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Quyền gọi hàm
-- ---------------------------------------------------------------------------
revoke execute on function
  app.issue_enrollment_code(), app.is_assigned_to_enrollment(uuid), app.enrollment_hours_balance(uuid),
  app.package_matches_class_subject(text, text), app.class_seats_left(uuid), app.assert_class_fits(uuid, uuid, uuid, text),
  app.check_order_line_class(integer, uuid, uuid, uuid), app.class_students_with_hours(uuid),
  app.assert_enrol_start_date(uuid, date, text), app.assert_no_time_clash(uuid, uuid, date, uuid, text),
  app.assign_enrollment_class(uuid, uuid, date), app.move_enrollment_class(uuid, uuid, date, text),
  app.enrollment_target_hours(uuid, text), app.sync_enrollment_hours(uuid), app.create_enrollments_for_order(uuid),
  app.adjust_enrollment_hours(uuid, numeric, text, text), app.add_opening_hours(uuid, numeric, text)
  from public, anon, authenticated;
-- Giao diện gọi: xếp lớp, điều chỉnh giờ, số dư, chỗ còn lại, hàm kiểm lớp trên dòng đơn (hàm đơn hàng cũ gọi bằng quyền người dùng).
grant execute on function
  app.is_assigned_to_enrollment(uuid), app.enrollment_hours_balance(uuid), app.class_seats_left(uuid),
  app.check_order_line_class(integer, uuid, uuid, uuid), app.assign_enrollment_class(uuid, uuid, date),
  app.adjust_enrollment_hours(uuid, numeric, text, text)
  to authenticated;

select set_config('hmt.migration', '', false);
