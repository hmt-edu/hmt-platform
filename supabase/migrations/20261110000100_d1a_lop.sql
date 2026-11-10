-- D1a (Code 2, 10/11/2026): Lớp, thời khoá biểu, nhóm lớp, duyệt lớp, sinh buổi học.
-- Luật: R-LOP-01..06, 08, 09, 10, 12, 13, 14, 15; R-BUOI-02 (tình trạng buổi), R-V2-10 (CS3 là cơ sở dạy học).
-- Làm gì: bảng lớp, khung giờ (thời khoá biểu), nhóm lớp, lịch sử lớp, buổi học (bảng, mới sinh ở tình trạng Nháp);
-- hàm tạo, sửa, trình, xác nhận, duyệt, từ chối, đưa về Nháp, đóng, huỷ lớp; hàm tính lịch buổi và sinh buổi khi duyệt;
-- xem trước và sinh lại buổi khi sửa thời khoá biểu; tham số class_slot_repeat_weeks_max; danh mục CLASS_STATUS, SESSION_STATUS.
-- Chưa có (làm ở migration sau): chốt buổi, Done, trừ giờ, điểm danh (D1c, D1d); ghi danh, xếp lớp (D1b). Hàm
-- app.class_students_with_hours là chỗ giữ chỗ trả rỗng, D1b thay bằng kiểm thật (R-LOP-04).
-- GỘP SAU #205 và Q-137 (số migration 100 nằm sau 085 nhưng PR 086, 087 chưa gộp).
-- Chỉ mục: mỗi chỉ mục ghi lý do ngay bên dưới câu tạo.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- 1. Tham số và danh mục
-- ---------------------------------------------------------------------------
-- R-LOP-13: số tuần lặp tối đa của khung giờ, mặc định 4, khoảng 1-8, một giá trị chung.
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('class_slot_repeat_weeks_max', 'Số tuần lặp tối đa của khung giờ', 'INT', 'tuần', 1, 8, '4', false, 'VAN_HANH_LOP', null,
   'Khung giờ trong thời khoá biểu lặp mỗi N tuần, N từ 1 đến giá trị này (R-LOP-13).');

insert into app.catalog (code, name, kind, description, sort_order)
select v.code, v.name, v.kind, v.description, (select coalesce(max(sort_order), 0) from app.catalog) + v.n
  from (values
    ('CLASS_STATUS', 'Tình trạng duyệt của lớp', 'HE_THONG', 'Nháp, Đã trình, Đã xác nhận, Đã duyệt, Đã đóng; Từ chối, Huỷ (R-LOP-01).', 1),
    ('SESSION_STATUS', 'Tình trạng buổi học', 'HE_THONG', 'Nháp, Đã chốt, Done; Huỷ có tính phí, Huỷ không tính phí (R-BUOI-02). DA_THAY là mã kỹ thuật: buổi Nháp bị thay khi sinh lại lịch (R-LOP-10), không hiện trong danh sách.', 2)
  ) v (code, name, kind, description, n);

insert into app.catalog_item (catalog_code, code, name, sort_order, requires_note)
values
  ('CLASS_STATUS', 'NHAP', 'Nháp', 1, false),
  ('CLASS_STATUS', 'DA_TRINH', 'Đã trình', 2, false),
  ('CLASS_STATUS', 'DA_XAC_NHAN', 'Đã xác nhận', 3, false),
  ('CLASS_STATUS', 'DA_DUYET', 'Đã duyệt', 4, false),
  ('CLASS_STATUS', 'DA_DONG', 'Đã đóng', 5, false),
  ('CLASS_STATUS', 'TU_CHOI', 'Từ chối', 6, false),
  ('CLASS_STATUS', 'HUY', 'Huỷ', 7, false),
  ('SESSION_STATUS', 'NHAP', 'Nháp', 1, false),
  ('SESSION_STATUS', 'DA_CHOT', 'Đã chốt', 2, false),
  ('SESSION_STATUS', 'DONE', 'Done', 3, false),
  ('SESSION_STATUS', 'HUY_CO_PHI', 'Huỷ có tính phí', 4, false),
  ('SESSION_STATUS', 'HUY_KHONG_PHI', 'Huỷ không tính phí', 5, false),
  ('SESSION_STATUS', 'DA_THAY', 'Đã thay bằng lịch mới', 6, false);

-- Tình trạng ghi danh "Đã xếp lớp" (12/10, R-GD-05) chưa có trong danh mục; D1b dùng.
insert into app.catalog_item (catalog_code, code, name, sort_order)
values ('ENROLLMENT_STATUS', 'DA_XEP_LOP', 'Đã xếp lớp', 2)
on conflict (catalog_code, code) do nothing;

-- ---------------------------------------------------------------------------
-- 2. Bảng nhóm lớp, lớp, khung giờ, lịch sử lớp, buổi học
-- ---------------------------------------------------------------------------
-- Nhóm lớp (R-LOP-14): không có mã riêng; tên chung là tham chiếu tự do. Tối đa một lớp mỗi môn, một lớp không thuộc quá một nhóm.
create table app.class_group (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references app.branch (id),
  grade_code text not null,
  display_name text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.class_group is 'Nhóm lớp (R-LOP-14): gắn lớp DAI và HINH cùng khối, cùng cơ sở. Không có mã riêng.';
-- Chỉ mục (lý do): khoá ngoại cơ sở, dùng cho RLS và lọc.
create index class_group_branch_idx on app.class_group (branch_id);
select app.apply_standard('app.class_group');

create table app.class (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  branch_id uuid not null references app.branch (id),
  year_code text not null,
  subject_catalog text not null default 'SUBJECT' check (subject_catalog = 'SUBJECT'),
  subject_code text not null,
  grade_catalog text not null default 'GRADE' check (grade_catalog = 'GRADE'),
  grade_code text not null,
  class_type_catalog text not null default 'CLASS_TYPE' check (class_type_catalog = 'CLASS_TYPE'),
  class_type_code text not null,
  level_catalog text not null default 'LEVEL' check (level_catalog = 'LEVEL'),
  level_code text,
  status_catalog text not null default 'CLASS_STATUS' check (status_catalog = 'CLASS_STATUS'),
  status_code text not null default 'NHAP',
  -- 0 = không giới hạn sĩ số (R-GD-08).
  max_students integer not null default 0 check (max_students >= 0),
  start_date date not null,
  -- Số buổi của khoá; ngày kết thúc dự kiến tính từ đây (R-LOP-09).
  total_sessions integer not null check (total_sessions > 0),
  expected_end_date date,
  -- Khung chương trình (R-LOP-07): chưa có bảng khung; D1 lưu mã khung và bài bắt đầu dạng chữ (đề xuất, chờ anh OK).
  curriculum_ref text,
  start_lesson text,
  cskh_id uuid references app.user_account (id),
  group_id uuid references app.class_group (id),
  legacy_ref text,
  submitted_by uuid,
  search_text text generated always as (app.fold_text(code || ' ' || coalesce(legacy_ref, ''))) stored,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (subject_catalog, subject_code) references app.catalog_item (catalog_code, code),
  foreign key (grade_catalog, grade_code) references app.catalog_item (catalog_code, code),
  foreign key (class_type_catalog, class_type_code) references app.catalog_item (catalog_code, code),
  foreign key (status_catalog, status_code) references app.catalog_item (catalog_code, code),
  -- Lớp riêng (LR) không có trình độ; lớp CB, NC bắt buộc có (spec 02).
  check ((class_type_code = 'LR') = (level_code is null))
);
comment on table app.class is 'Lớp học (R-LOP-01..): tình trạng duyệt ở status_code; tình trạng vận hành tính từ buổi (app.class_operating_status). Mã cấp một lần, không đổi.';
-- Chỉ mục (lý do): cơ sở + tình trạng cho danh sách và RLS; môn, khối là cột lọc; nhóm lớp là khoá ngoại; người CSKH phụ trách lọc "của tôi".
create index class_branch_status_idx on app.class (branch_id, status_code, created_at desc);
create index class_subject_grade_idx on app.class (subject_code, grade_code);
create index class_group_idx on app.class (group_id) where group_id is not null;
create index class_cskh_idx on app.class (cskh_id) where cskh_id is not null;
-- Tìm theo mã lớp và mã cũ (R-LOP-15): trigram cho LIKE '%…%'.
create index class_search_idx on app.class using gin (search_text gin_trgm_ops);
-- Một lớp không quá một nhóm; tối đa một lớp mỗi môn trong nhóm (R-LOP-14).
create unique index class_group_subject_uq on app.class (group_id, subject_code) where group_id is not null and status_code <> 'HUY';
select app.apply_standard('app.class');

-- Khung giờ của thời khoá biểu (R-LOP-08, 13).
create table app.class_slot (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references app.class (id),
  branch_id uuid not null references app.branch (id),
  weekday smallint not null check (weekday between 1 and 7),
  start_time time not null,
  end_time time not null,
  teacher_id uuid references app.user_account (id),
  assistant_id uuid references app.user_account (id),
  room_id uuid references app.room (id),
  -- "Lặp mỗi N tuần" và "buổi đầu tiên vào ngày" (R-LOP-13).
  repeat_weeks smallint not null default 1 check (repeat_weeks >= 1),
  first_date date not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (end_time > start_time),
  check (extract(isodow from first_date) = weekday)
);
comment on table app.class_slot is 'Khung giờ của lớp: thứ, giờ, giáo viên, trợ giảng, phòng, cách lặp (R-LOP-08, 13). Đổi thì đóng khung cũ (is_active = false), thêm khung mới.';
-- Chỉ mục (lý do): các khung của một lớp; lịch dạy của giáo viên, trợ giảng (cổng GV và kiểm trùng); phòng (kiểm trùng).
create index class_slot_class_idx on app.class_slot (class_id) where is_active;
create index class_slot_teacher_idx on app.class_slot (teacher_id) where teacher_id is not null and is_active;
create index class_slot_assistant_idx on app.class_slot (assistant_id) where assistant_id is not null and is_active;
create index class_slot_room_idx on app.class_slot (room_id) where room_id is not null and is_active;
create index class_slot_branch_idx on app.class_slot (branch_id);
select app.apply_standard('app.class_slot');

-- Lịch sử lớp (chỉ thêm).
create table app.class_event (
  id uuid primary key default gen_random_uuid(),
  seq bigint generated always as identity,
  class_id uuid not null references app.class (id),
  branch_id uuid not null references app.branch (id),
  event_code text not null check (event_code in ('TAO', 'SUA', 'SUA_LICH', 'TRINH', 'XAC_NHAN', 'DUYET', 'TU_CHOI', 'VE_NHAP', 'DONG', 'HUY')),
  from_status text,
  to_status text not null,
  note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.class_event is 'Lịch sử lớp: tạo, sửa, đổi lịch, trình, xác nhận, duyệt, từ chối (kèm lý do), đưa về Nháp, đóng, huỷ. Chỉ thêm.';
-- Chỉ mục (lý do): lịch sử một lớp theo thứ tự ghi; cơ sở cho RLS.
create index class_event_class_idx on app.class_event (class_id, seq);
create index class_event_branch_idx on app.class_event (branch_id);
select app.apply_standard('app.class_event');

-- Buổi học (R-BUOI-02, 08): không có mã cho người đọc; hiển thị "tên lớp · Buổi N · ngày".
create table app.class_session (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references app.class (id),
  branch_id uuid not null references app.branch (id),
  slot_id uuid references app.class_slot (id),
  session_no integer,
  session_date date not null,
  start_time time not null,
  end_time time not null,
  teacher_id uuid references app.user_account (id),
  assistant_id uuid references app.user_account (id),
  room_id uuid references app.room (id),
  type_catalog text not null default 'SESSION_TYPE' check (type_catalog = 'SESSION_TYPE'),
  type_code text not null default 'CHINH',
  status_catalog text not null default 'SESSION_STATUS' check (status_catalog = 'SESSION_STATUS'),
  status_code text not null default 'NHAP',
  -- Buổi đã chỉnh lẻ tay (dời, đổi người dạy): sinh lại lịch giữ nguyên (R-LOP-10).
  is_manual boolean not null default false,
  legacy_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (type_catalog, type_code) references app.catalog_item (catalog_code, code),
  foreign key (status_catalog, status_code) references app.catalog_item (catalog_code, code),
  check (end_time > start_time)
);
comment on table app.class_session is 'Buổi học của lớp. Sinh khi duyệt lớp (R-LOP-03). Ghi chỉ qua hàm nghiệp vụ.';
-- Chỉ mục (lý do): các buổi của một lớp theo ngày; lịch theo cơ sở và ngày (BUOI-01, LOP-08); lịch giáo viên, trợ giảng, phòng (cổng GV, kiểm trùng).
create index class_session_class_idx on app.class_session (class_id, session_date, start_time);
create index class_session_branch_date_idx on app.class_session (branch_id, session_date);
create index class_session_teacher_idx on app.class_session (teacher_id, session_date) where teacher_id is not null;
create index class_session_assistant_idx on app.class_session (assistant_id, session_date) where assistant_id is not null;
create index class_session_room_idx on app.class_session (room_id, session_date) where room_id is not null;
-- Hàng chờ chốt và tự chốt (R-GIO-05): buổi chưa Done.
create index class_session_open_idx on app.class_session (session_date, start_time) where status_code in ('NHAP', 'DA_CHOT');
create index class_session_slot_idx on app.class_session (slot_id) where slot_id is not null;
select app.apply_standard('app.class_session');

-- ---------------------------------------------------------------------------
-- 3. RLS: đọc theo quyền Xem; ghi chỉ qua hàm nghiệp vụ. Giáo viên, trợ giảng chỉ thấy lớp và buổi được phân công (R-GV-08).
-- ---------------------------------------------------------------------------
-- Người dùng hiện tại được phân công vào lớp (khung giờ hoặc buổi) không. Security definer để tránh vòng lặp RLS.
create or replace function app.is_assigned_to_class(p_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.class_slot s where s.class_id = p_class_id and s.is_active
                    and (select auth.uid()) in (s.teacher_id, s.assistant_id))
      or exists (select from app.class_session x where x.class_id = p_class_id
                    and (select auth.uid()) in (x.teacher_id, x.assistant_id));
$$;

alter table app.class_group enable row level security;
alter table app.class enable row level security;
alter table app.class_slot enable row level security;
alter table app.class_event enable row level security;
alter table app.class_session enable row level security;
revoke all on app.class_group, app.class, app.class_slot, app.class_event, app.class_session from public, anon, authenticated;
grant select on app.class_group, app.class, app.class_slot, app.class_event, app.class_session to authenticated;

create policy class_group_read on app.class_group for select to authenticated
  using ((select app.permission_scope('CLASS', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('CLASS', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id())));
create policy class_read on app.class for select to authenticated
  using ((select app.permission_scope('CLASS', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('CLASS', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id()))
         or ((select app.permission_scope('CLASS', 'XEM')) = 'DUOC_PHAN_CONG' and (select app.is_assigned_to_class(id))));
create policy class_slot_read on app.class_slot for select to authenticated
  using ((select app.permission_scope('CLASS', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('CLASS', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id()))
         or ((select app.permission_scope('CLASS', 'XEM')) = 'DUOC_PHAN_CONG' and (select app.is_assigned_to_class(class_id))));
create policy class_event_read on app.class_event for select to authenticated
  using ((select app.permission_scope('CLASS', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('CLASS', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id())));
create policy class_session_read on app.class_session for select to authenticated
  using ((select app.permission_scope('SESSION', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('SESSION', 'XEM')) = 'CO_SO' and branch_id = (select app.current_branch_id()))
         or ((select app.permission_scope('SESSION', 'XEM')) = 'DUOC_PHAN_CONG'
             and ((select auth.uid()) in (teacher_id, assistant_id) or (select app.is_assigned_to_class(class_id)))));

-- ---------------------------------------------------------------------------
-- 4. Hàm trợ giúp
-- ---------------------------------------------------------------------------
-- Ghi một dòng lịch sử lớp.
create or replace function app.class_add_event(p_class_id uuid, p_event text, p_from text, p_to text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into app.class_event (class_id, branch_id, event_code, from_status, to_status, note)
  select c.id, c.branch_id, p_event, p_from, p_to, p_note from app.class c where c.id = p_class_id;
end;
$$;

-- Lớp chưa tồn tại học sinh còn giờ ở D1a. D1b thay thân hàm bằng kiểm thật (R-LOP-04): trả danh sách tên học sinh còn giờ trong lớp.
create or replace function app.class_students_with_hours(p_class_id uuid)
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select '{}'::text[];
$$;

-- Tình trạng vận hành của lớp (R-LOP-05): chỉ có giá trị từ lớp Đã duyệt; tính, không lưu.
--   Chưa khai giảng = chưa có buổi Done; Đang học = có buổi Done và lớp chưa đóng; Đã kết thúc = lớp Đã đóng. Trước Đã duyệt trả null (hiện '—').
create or replace function app.class_operating_status(p_class_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when c.status_code = 'DA_DONG' then 'DA_KET_THUC'
           when c.status_code <> 'DA_DUYET' then null
           when exists (select from app.class_session s where s.class_id = c.id and s.status_code = 'DONE') then 'DANG_HOC'
           else 'CHUA_KHAI_GIANG'
         end
    from app.class c where c.id = p_class_id;
$$;

-- Tính lịch buổi (R-LOP-09, R-LOP-13). Thuần tính, không ghi.
-- Đầu vào: cơ sở (để bỏ ngày nghỉ lễ chung và riêng, R-LOP-12), ngày bắt đầu, số buổi cần sinh, mảng khung giờ
--   [{weekday, start_time, end_time, repeat_weeks, first_date}], tính từ ngày p_from (không sớm hơn start).
-- Mỗi khung: các ngày first_date + 7 × N × k, bỏ ngày nghỉ lễ; gộp mọi khung, sắp theo ngày, giờ, lấy đủ p_total buổi.
create or replace function app.compute_class_schedule(p_branch_id uuid, p_from date, p_total integer, p_slots jsonb)
returns table (slot_no integer, session_date date, start_time time, end_time time)
language sql
stable
set search_path = ''
as $$
  with slots as (
    select (ord - 1)::integer as slot_no,
           (e ->> 'start_time')::time as start_time, (e ->> 'end_time')::time as end_time,
           (e ->> 'repeat_weeks')::integer as repeat_weeks, (e ->> 'first_date')::date as first_date
      from jsonb_array_elements(coalesce(p_slots, '[]'::jsonb)) with ordinality as t (e, ord)
  ),
  cand as (
    -- Ứng viên mỗi khung: đủ nhiều để bù ngày nghỉ lễ (gấp ba số buổi cần cộng 60).
    select s.slot_no, (s.first_date + (7 * s.repeat_weeks * k))::date as d, s.start_time, s.end_time -- allow-number: 7 ngày một tuần, 3 và 60 là biên dự phòng ngày nghỉ lễ khi sinh ứng viên, không phải luật nghiệp vụ
      from slots s cross join generate_series(0, p_total * 3 + 60) as k -- allow-number: 7 ngày một tuần, 3 và 60 là biên dự phòng ngày nghỉ lễ khi sinh ứng viên, không phải luật nghiệp vụ
     where s.first_date + (7 * s.repeat_weeks * k) >= p_from -- allow-number: 7 ngày một tuần, 3 và 60 là biên dự phòng ngày nghỉ lễ khi sinh ứng viên, không phải luật nghiệp vụ
  ),
  ok as (
    select c.* from cand c
     where not exists (select from app.holiday h where h.holiday_date = c.d and h.is_active
                          and (h.branch_id is null or h.branch_id = p_branch_id))
  )
  select o.slot_no, o.d, o.start_time, o.end_time
    from ok o
   order by o.d, o.start_time, o.slot_no
   limit greatest(p_total, 0);
$$;

-- Chuẩn hoá và kiểm mảng khung giờ (R-LOP-08, R-LOP-13). Trả mảng đã chuẩn (đủ trường); sai thì báo lỗi có mã.
create or replace function app.class_normalize_slots(p_branch_id uuid, p_start_date date, p_slots jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  e jsonb;
  v_out jsonb := '[]'::jsonb;
  v_max integer := app.get_setting_int('class_slot_repeat_weeks_max');
  v_repeat integer;
  v_first date;
  v_weekday integer;
  v_n integer := 0;
begin
  if p_slots is null or jsonb_typeof(p_slots) <> 'array' then
    perform app.raise_error('HMT_LOP_KHUNG_GIO_SAI', 'Thời khoá biểu phải là danh sách khung giờ.');
  end if;
  for e in select * from jsonb_array_elements(p_slots) loop
    v_n := v_n + 1;
    v_weekday := (e ->> 'weekday')::integer;
    v_repeat := coalesce(nullif(e ->> 'repeat_weeks', '')::integer, 1);
    v_first := (e ->> 'first_date')::date;
    -- Luật R-LOP-13: lặp mỗi N tuần, N từ 1 đến tham số class_slot_repeat_weeks_max.
    if v_repeat < 1 or v_repeat > v_max then
      perform app.raise_error('HMT_LOP_LAP_TUAN_SAI', format('Khung giờ %s: lặp mỗi N tuần, N từ 1 đến %s.', v_n, v_max));
    end if;
    if v_weekday is null or v_weekday not between 1 and 7 or e ->> 'start_time' is null or e ->> 'end_time' is null -- allow-number: thứ trong tuần 1 đến 7 (ISO)
       or (e ->> 'end_time')::time <= (e ->> 'start_time')::time then
      perform app.raise_error('HMT_LOP_KHUNG_GIO_SAI', format('Khung giờ %s: thiếu thứ hoặc giờ kết thúc không sau giờ bắt đầu.', v_n));
    end if;
    -- Luật R-LOP-13: buổi đầu tiên đúng thứ của khung và không trước ngày khai giảng.
    if v_first is null or extract(isodow from v_first) <> v_weekday then
      perform app.raise_error('HMT_LOP_NGAY_DAU_SAI_THU', format('Khung giờ %s: ngày buổi đầu tiên phải đúng thứ của khung.', v_n));
    end if;
    if v_first < p_start_date then
      perform app.raise_error('HMT_LOP_NGAY_DAU_TRUOC_KHAI_GIANG', format('Khung giờ %s: ngày buổi đầu tiên không được trước ngày khai giảng.', v_n));
    end if;
    v_out := v_out || jsonb_build_object('weekday', v_weekday, 'start_time', e ->> 'start_time', 'end_time', e ->> 'end_time',
                                         'repeat_weeks', v_repeat, 'first_date', v_first,
                                         'teacher_id', nullif(e ->> 'teacher_id', ''), 'assistant_id', nullif(e ->> 'assistant_id', ''),
                                         'room_id', nullif(e ->> 'room_id', ''));
  end loop;
  return v_out;
end;
$$;

-- Cảnh báo trùng phòng, trùng giáo viên ở cấp buổi thật (R-LOP-08, 23/10): chỉ cảnh báo, không chặn.
--   Lớp luân phiên (cùng khung, buổi không trùng ngày giờ) không bị coi là trùng vì xét theo buổi thật.
create or replace function app.class_clash_warnings(p_class_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_room integer;
  v_teacher integer;
  v_out jsonb := '[]'::jsonb;
begin
  select count(*) into v_room
    from app.class_session a join app.class_session b
      on b.class_id <> a.class_id and b.session_date = a.session_date and b.room_id = a.room_id
         and b.start_time < a.end_time and a.start_time < b.end_time
         and b.status_code in ('NHAP', 'DA_CHOT', 'DONE')
   where a.class_id = p_class_id and a.status_code in ('NHAP', 'DA_CHOT') and a.room_id is not null and a.session_date >= current_date;
  select count(*) into v_teacher
    from app.class_session a join app.class_session b
      on b.class_id <> a.class_id and b.session_date = a.session_date and b.teacher_id = a.teacher_id
         and b.start_time < a.end_time and a.start_time < b.end_time
         and b.status_code in ('NHAP', 'DA_CHOT', 'DONE')
   where a.class_id = p_class_id and a.status_code in ('NHAP', 'DA_CHOT') and a.teacher_id is not null and a.session_date >= current_date;
  if v_room > 0 then
    v_out := v_out || to_jsonb(format('Có %s buổi trùng phòng với lớp khác.', v_room));
  end if;
  if v_teacher > 0 then
    v_out := v_out || to_jsonb(format('Có %s buổi trùng giáo viên với lớp khác.', v_teacher));
  end if;
  return v_out;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Sinh buổi (R-LOP-03, R-LOP-10)
-- ---------------------------------------------------------------------------
-- Sinh buổi cho lớp từ ngày p_from theo các khung giờ đang dùng. Nội bộ, gọi từ hàm duyệt và hàm sửa thời khoá biểu.
--   Giữ nguyên: buổi trước p_from, buổi không còn Nháp, buổi đã chỉnh lẻ tay (R-LOP-10).
--   Buổi Nháp từ p_from còn lại và chưa chỉnh lẻ tay: đổi sang DA_THAY (không xoá cứng), rồi sinh mới.
--   Số buổi cần sinh = total_sessions trừ số buổi đang sống (Nháp giữ lại, Đã chốt, Done, Huỷ có tính phí vẫn là buổi đã tính).
--   Ngày kết thúc dự kiến = ngày buổi cuối đang sống (R-LOP-09). Đánh lại "Buổi N" theo ngày, giờ.
create or replace function app.generate_class_sessions(p_class_id uuid, p_from date)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.class;
  v_slots jsonb;
  v_kept integer;
  v_made integer;
begin
  select * into c from app.class where id = p_class_id;
  -- Luật R-LOP-10: buổi Nháp từ ngày áp dụng, chưa chỉnh lẻ tay, bị thay.
  update app.class_session set status_code = 'DA_THAY'
   where class_id = p_class_id and status_code = 'NHAP' and not is_manual and session_date >= p_from;
  select count(*) into v_kept from app.class_session
   where class_id = p_class_id and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI');
  select coalesce(jsonb_agg(jsonb_build_object('start_time', s.start_time, 'end_time', s.end_time,
                                               'repeat_weeks', s.repeat_weeks, 'first_date', s.first_date, 'id', s.id)), '[]'::jsonb)
    into v_slots from app.class_slot s where s.class_id = p_class_id and s.is_active;
  -- Sinh mới: mỗi dòng lịch trỏ về khung (slot_no là thứ tự trong mảng); lấy giáo viên, trợ giảng, phòng từ khung.
  with sched as (
    select * from app.compute_class_schedule(c.branch_id, greatest(p_from, c.start_date), greatest(c.total_sessions - v_kept, 0), v_slots)
  ), ins as (
    insert into app.class_session (class_id, branch_id, slot_id, session_date, start_time, end_time, teacher_id, assistant_id, room_id)
    select c.id, c.branch_id, (v_slots -> sc.slot_no ->> 'id')::uuid, sc.session_date, sc.start_time, sc.end_time,
           sl.teacher_id, sl.assistant_id, sl.room_id
      from sched sc join app.class_slot sl on sl.id = (v_slots -> sc.slot_no ->> 'id')::uuid
    returning 1
  )
  select count(*) into v_made from ins;
  -- Đánh lại số buổi theo ngày, giờ (buổi đang sống).
  update app.class_session x set session_no = n.rn
    from (select id, row_number() over (order by session_date, start_time, id) as rn
            from app.class_session
           where class_id = p_class_id and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI')) n
   where x.id = n.id and x.session_no is distinct from n.rn;
  update app.class set expected_end_date = (select max(session_date) from app.class_session
                                             where class_id = p_class_id and status_code in ('NHAP', 'DA_CHOT', 'DONE', 'HUY_CO_PHI'))
   where id = p_class_id;
  return v_made;
end;
$$;

-- Thay các khung giờ của lớp bằng mảng đã chuẩn hoá (đóng khung cũ, thêm khung mới). Nội bộ.
create or replace function app.class_replace_slots(p_class_id uuid, p_branch_id uuid, p_slots jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  e jsonb;
begin
  update app.class_slot set is_active = false where class_id = p_class_id and is_active;
  for e in select * from jsonb_array_elements(p_slots) loop
    insert into app.class_slot (class_id, branch_id, weekday, start_time, end_time, teacher_id, assistant_id, room_id, repeat_weeks, first_date)
    values (p_class_id, p_branch_id, (e ->> 'weekday')::smallint, (e ->> 'start_time')::time, (e ->> 'end_time')::time,
            (e ->> 'teacher_id')::uuid, (e ->> 'assistant_id')::uuid, (e ->> 'room_id')::uuid,
            (e ->> 'repeat_weeks')::smallint, (e ->> 'first_date')::date);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Hàm nghiệp vụ: tạo, sửa
-- ---------------------------------------------------------------------------
-- app.create_class(dữ liệu): tạo lớp ở Nháp, cấp mã (spec 02, không nhảy số).
-- Ai gọi: Lớp học · Tạo, ở cơ sở của lớp (R-LOP-06: nhân sự chỉ mở lớp cơ sở mình; Admin mọi cơ sở).
-- Đầu vào: {branch_id, year_code, subject_code, grade_code, class_type_code, level_code, max_students, start_date, total_sessions,
--   curriculum_ref, start_lesson, cskh_id, group_id, legacy_ref, slots[]}. Kết quả: {id, code, warnings[]}.
-- Mã lớp gồm cơ sở, năm, môn, khối, phân loại, trình độ nên các trường này không sửa sau khi tạo (nhầm thì Huỷ và tạo lớp mới).
create or replace function app.create_class(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid := (p_data ->> 'branch_id')::uuid;
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_start date := (p_data ->> 'start_date')::date;
  v_slots jsonb;
  v_group app.class_group;
  v_cskh uuid := nullif(p_data ->> 'cskh_id', '')::uuid;
begin
  perform app.assert_can('CLASS', 'TAO', v_branch);
  perform app.require_feature('VAN_HANH_LOP', v_branch);
  if v_start is null or coalesce((p_data ->> 'total_sessions')::integer, 0) <= 0 then
    perform app.raise_error('HMT_LOP_THIEU_THONG_TIN', 'Lớp cần ngày khai giảng và số buổi lớn hơn 0.');
  end if;
  select code into v_branch_code from app.branch where id = v_branch;
  v_code := app.issue_class_code(v_branch_code, p_data ->> 'year_code', p_data ->> 'subject_code', p_data ->> 'grade_code',
                                 p_data ->> 'class_type_code', nullif(p_data ->> 'level_code', ''));
  -- Luật R-LOP-14: nhóm lớp cùng cơ sở, cùng khối, mỗi môn một lớp, chỉ môn DAI và HINH.
  if nullif(p_data ->> 'group_id', '') is not null then
    select * into v_group from app.class_group where id = (p_data ->> 'group_id')::uuid;
    if v_group.id is null or v_group.branch_id <> v_branch or v_group.grade_code <> p_data ->> 'grade_code'
       or p_data ->> 'subject_code' not in ('DAI', 'HINH') then
      perform app.raise_error('HMT_LOP_NHOM_SAI', 'Nhóm lớp phải cùng cơ sở, cùng khối và chỉ gồm lớp Đại hoặc Hình.');
    end if;
    if exists (select from app.class where group_id = v_group.id and subject_code = p_data ->> 'subject_code' and status_code <> 'HUY') then
      perform app.raise_error('HMT_LOP_NHOM_TRUNG_MON', 'Nhóm lớp này đã có một lớp cùng môn.');
    end if;
  end if;
  v_slots := app.class_normalize_slots(v_branch, v_start, coalesce(p_data -> 'slots', '[]'::jsonb));
  insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, max_students,
                         start_date, total_sessions, curriculum_ref, start_lesson, cskh_id, group_id, legacy_ref)
  values (v_code, v_branch, p_data ->> 'year_code', p_data ->> 'subject_code', p_data ->> 'grade_code', p_data ->> 'class_type_code',
          nullif(p_data ->> 'level_code', ''), coalesce((p_data ->> 'max_students')::integer, 0), v_start,
          (p_data ->> 'total_sessions')::integer, nullif(p_data ->> 'curriculum_ref', ''), nullif(p_data ->> 'start_lesson', ''),
          v_cskh, nullif(p_data ->> 'group_id', '')::uuid, nullif(p_data ->> 'legacy_ref', ''))
  returning id into v_id;
  perform app.class_replace_slots(v_id, v_branch, v_slots);
  perform app.class_add_event(v_id, 'TAO', null, 'NHAP');
  return jsonb_build_object('id', v_id, 'code', v_code, 'warnings', '[]'::jsonb);
end;
$$;

-- app.save_class_info(lớp, dữ liệu): sửa thông tin lớp.
-- Luật R-LOP-02: thông tin chỉ sửa ở Nháp hoặc Từ chối; riêng lớp Đã duyệt vẫn sửa được CSKH phụ trách và sĩ số tối đa.
-- Không sửa mã, cơ sở, năm, môn, khối, phân loại, trình độ (đã nằm trong mã lớp).
create or replace function app.save_class_info(p_id uuid, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.class;
begin
  select * into c from app.class where id = p_id for update;
  if c.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lớp.');
  end if;
  perform app.assert_can('CLASS', 'SUA', c.branch_id);
  if c.status_code in ('NHAP', 'TU_CHOI') then
    update app.class set
      max_students = coalesce((p_data ->> 'max_students')::integer, max_students),
      start_date = coalesce((p_data ->> 'start_date')::date, start_date),
      total_sessions = coalesce((p_data ->> 'total_sessions')::integer, total_sessions),
      curriculum_ref = case when p_data ? 'curriculum_ref' then nullif(p_data ->> 'curriculum_ref', '') else curriculum_ref end,
      start_lesson = case when p_data ? 'start_lesson' then nullif(p_data ->> 'start_lesson', '') else start_lesson end,
      cskh_id = case when p_data ? 'cskh_id' then nullif(p_data ->> 'cskh_id', '')::uuid else cskh_id end,
      legacy_ref = case when p_data ? 'legacy_ref' then nullif(p_data ->> 'legacy_ref', '') else legacy_ref end
     where id = p_id;
  elsif c.status_code = 'DA_DUYET' then
    -- Lớp Đã duyệt: chỉ CSKH phụ trách và sĩ số tối đa; mọi trường khác bị khoá.
    if exists (select from jsonb_object_keys(p_data) k where k not in ('max_students', 'cskh_id')) then
      perform app.raise_error('HMT_LOP_DA_KHOA', 'Lớp đã duyệt chỉ sửa được CSKH phụ trách và sĩ số tối đa.');
    end if;
    update app.class set
      max_students = coalesce((p_data ->> 'max_students')::integer, max_students),
      cskh_id = case when p_data ? 'cskh_id' then nullif(p_data ->> 'cskh_id', '')::uuid else cskh_id end
     where id = p_id;
  else
    perform app.raise_error('HMT_LOP_DA_KHOA', 'Chỉ sửa thông tin lớp ở Nháp hoặc Từ chối.');
  end if;
  perform app.class_add_event(p_id, 'SUA', c.status_code, c.status_code);
end;
$$;

-- app.save_class_timetable(lớp, khung giờ, ngày áp dụng, xem trước): sửa thời khoá biểu (R-LOP-02, R-LOP-10).
-- Sửa được ở Nháp, Từ chối, Đã trình, Đã xác nhận, Đã duyệt. Đã xác nhận mà sửa thì lớp quay về Đã trình (quản lý duyệt đúng bản cuối).
-- Lớp Đã duyệt: bắt buộc "Áp dụng từ ngày" không sớm hơn hôm nay; xem trước (p_preview = true) chỉ trả số buổi chưa diễn ra sẽ đổi, không ghi.
-- Kết quả: {replaced, created, warnings[]}.
create or replace function app.save_class_timetable(p_id uuid, p_slots jsonb, p_apply_from date default null, p_preview boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.class;
  v_slots jsonb;
  v_replaced integer;
  v_created integer := 0;
  v_from date;
begin
  select * into c from app.class where id = p_id for update;
  if c.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lớp.');
  end if;
  perform app.assert_can('CLASS', 'SUA', c.branch_id);
  if c.status_code not in ('NHAP', 'TU_CHOI', 'DA_TRINH', 'DA_XAC_NHAN', 'DA_DUYET') then
    perform app.raise_error('HMT_LOP_DA_KHOA', 'Lớp đã đóng hoặc đã huỷ không sửa được thời khoá biểu.');
  end if;
  v_slots := app.class_normalize_slots(c.branch_id, c.start_date, p_slots);
  if c.status_code = 'DA_DUYET' then
    -- Luật R-LOP-10: áp dụng từ ngày không sớm hơn hôm nay.
    v_from := coalesce(p_apply_from, current_date);
    if v_from < current_date then
      perform app.raise_error('HMT_LOP_NGAY_AP_DUNG_SAI', 'Ngày áp dụng không được sớm hơn hôm nay.');
    end if;
    select count(*) into v_replaced from app.class_session
     where class_id = p_id and status_code = 'NHAP' and not is_manual and session_date >= v_from;
    if p_preview then
      return jsonb_build_object('replaced', v_replaced, 'preview', true);
    end if;
    perform app.class_replace_slots(p_id, c.branch_id, v_slots);
    v_created := app.generate_class_sessions(p_id, v_from);
  else
    if p_preview then
      return jsonb_build_object('replaced', 0, 'preview', true);
    end if;
    perform app.class_replace_slots(p_id, c.branch_id, v_slots);
    if c.status_code = 'DA_XAC_NHAN' then
      update app.class set status_code = 'DA_TRINH' where id = p_id;
    end if;
    v_replaced := 0;
  end if;
  perform app.class_add_event(p_id, 'SUA_LICH', c.status_code, case when c.status_code = 'DA_XAC_NHAN' then 'DA_TRINH' else c.status_code end);
  return jsonb_build_object('replaced', v_replaced, 'created', v_created, 'warnings', app.class_clash_warnings(p_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Hàm nghiệp vụ: bước duyệt (R-LOP-01, R-LOP-02, R-LOP-03, R-LOP-04)
-- ---------------------------------------------------------------------------
-- app.transition_class(lớp, đích, ghi chú): đổi tình trạng duyệt. Mỗi đường đi một đoạn kiểm, theo R-LOP-01:
--   Nháp→[Đã trình, Huỷ]; Đã trình→[Đã xác nhận, Từ chối, Nháp, Huỷ]; Đã xác nhận→[Đã duyệt, Từ chối, Nháp, Huỷ];
--   Đã duyệt→[Đã đóng, Huỷ]; Từ chối→[Nháp, Huỷ].
-- Quyền: Trình, Từ chối→Nháp, Nháp→Huỷ: Lớp học · Sửa; Xác nhận, Duyệt, Từ chối, Đóng: Lớp học · Duyệt; Đưa về Nháp (từ Đã trình, Đã xác nhận):
--   người trình hoặc người có quyền Duyệt; Huỷ lớp đã trình trở đi: Lớp học · Huỷ.
-- Kết quả: {to, sessions_created, warnings[]}.
create or replace function app.transition_class(p_id uuid, p_to text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.class;
  v_event text;
  v_created integer := 0;
  v_names text[];
begin
  select * into c from app.class where id = p_id for update;
  if c.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lớp.');
  end if;
  -- Luật R-LOP-01: đường đi hợp lệ.
  if not ((c.status_code = 'NHAP' and p_to in ('DA_TRINH', 'HUY'))
       or (c.status_code = 'DA_TRINH' and p_to in ('DA_XAC_NHAN', 'TU_CHOI', 'NHAP', 'HUY'))
       or (c.status_code = 'DA_XAC_NHAN' and p_to in ('DA_DUYET', 'TU_CHOI', 'NHAP', 'HUY'))
       or (c.status_code = 'DA_DUYET' and p_to in ('DA_DONG', 'HUY'))
       or (c.status_code = 'TU_CHOI' and p_to in ('NHAP', 'HUY'))) then
    perform app.raise_error('HMT_LOP_CHUYEN_SAI', format('Lớp đang ở "%s" không chuyển được sang "%s".',
      (select name from app.catalog_item where catalog_code = 'CLASS_STATUS' and code = c.status_code),
      (select name from app.catalog_item where catalog_code = 'CLASS_STATUS' and code = p_to)));
  end if;

  -- Quyền theo từng đường đi (R-LOP-02).
  if p_to = 'DA_TRINH' or (c.status_code = 'TU_CHOI' and p_to = 'NHAP') or (c.status_code = 'NHAP' and p_to = 'HUY') then
    perform app.assert_can('CLASS', 'SUA', c.branch_id);
  elsif p_to = 'NHAP' then
    -- Đưa về Nháp từ Đã trình, Đã xác nhận: người trình hoặc quản lý cơ sở đều bấm được.
    if c.submitted_by is distinct from auth.uid() then
      perform app.assert_can('CLASS', 'DUYET', c.branch_id);
    else
      perform app.assert_can('CLASS', 'SUA', c.branch_id);
    end if;
  elsif p_to = 'HUY' then
    perform app.assert_can('CLASS', 'HUY', c.branch_id);
  else
    perform app.assert_can('CLASS', 'DUYET', c.branch_id);
  end if;

  -- Luật R-LOP-03: trình lớp bắt buộc có thời khoá biểu.
  if p_to = 'DA_TRINH' and not exists (select from app.class_slot where class_id = p_id and is_active) then
    perform app.raise_error('HMT_LOP_THIEU_THOI_KHOA_BIEU', 'Trình lớp cần có thời khoá biểu (ít nhất một khung giờ).');
  end if;
  -- Từ chối bắt buộc nêu lý do.
  if p_to = 'TU_CHOI' and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_LOP_CAN_LY_DO', 'Từ chối lớp cần ghi lý do.');
  end if;
  -- Luật R-LOP-04: đóng lớp bị chặn nếu còn học sinh còn giờ (liệt kê tên).
  if p_to = 'DA_DONG' then
    v_names := app.class_students_with_hours(p_id);
    if coalesce(array_length(v_names, 1), 0) > 0 then
      perform app.raise_error('HMT_LOP_CON_HOC_SINH_CON_GIO', 'Không đóng được lớp, còn học sinh còn giờ: ' || array_to_string(v_names, ', ') || '.');
    end if;
  end if;
  -- Luật R-LOP-04: huỷ lớp bị chặn nếu đã có buổi Done.
  if p_to = 'HUY' and exists (select from app.class_session where class_id = p_id and status_code = 'DONE') then
    perform app.raise_error('HMT_LOP_DA_CO_BUOI_DONE', 'Không huỷ được lớp đã có buổi Done.');
  end if;

  update app.class set status_code = p_to,
         submitted_by = case when p_to = 'DA_TRINH' then auth.uid() when p_to = 'NHAP' then null else submitted_by end
   where id = p_id;

  -- Luật R-LOP-03: duyệt xong thì tự sinh buổi từ thời khoá biểu.
  if p_to = 'DA_DUYET' then
    v_created := app.generate_class_sessions(p_id, c.start_date);
  end if;
  -- Huỷ lớp: các buổi chưa Done chuyển Huỷ không tính phí.
  if p_to = 'HUY' then
    update app.class_session set status_code = 'HUY_KHONG_PHI' where class_id = p_id and status_code in ('NHAP', 'DA_CHOT');
  end if;

  v_event := case p_to when 'DA_TRINH' then 'TRINH' when 'DA_XAC_NHAN' then 'XAC_NHAN' when 'DA_DUYET' then 'DUYET'
                       when 'TU_CHOI' then 'TU_CHOI' when 'NHAP' then 'VE_NHAP' when 'DA_DONG' then 'DONG' else 'HUY' end;
  perform app.class_add_event(p_id, v_event, c.status_code, p_to, p_note);
  return jsonb_build_object('to', p_to, 'sessions_created', v_created,
                            'warnings', case when p_to = 'DA_DUYET' then app.class_clash_warnings(p_id) else '[]'::jsonb end);
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Nhóm lớp (R-LOP-14)
-- ---------------------------------------------------------------------------
-- app.create_class_group(cơ sở, khối, tên chung): tạo nhóm để gắn lớp DAI và HINH. Tên chung là tham chiếu tự do, tuỳ chọn.
create or replace function app.create_class_group(p_branch_id uuid, p_grade_code text, p_display_name text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform app.assert_can('CLASS', 'TAO', p_branch_id);
  perform app.assert_catalog_code_active('GRADE', p_grade_code);
  insert into app.class_group (branch_id, grade_code, display_name) values (p_branch_id, p_grade_code, nullif(btrim(p_display_name), ''))
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Quyền gọi hàm
-- ---------------------------------------------------------------------------
revoke execute on function
  app.is_assigned_to_class(uuid), app.class_add_event(uuid, text, text, text, text), app.class_students_with_hours(uuid),
  app.class_operating_status(uuid), app.compute_class_schedule(uuid, date, integer, jsonb), app.class_normalize_slots(uuid, date, jsonb),
  app.class_clash_warnings(uuid), app.generate_class_sessions(uuid, date), app.class_replace_slots(uuid, uuid, jsonb),
  app.create_class(jsonb), app.save_class_info(uuid, jsonb), app.save_class_timetable(uuid, jsonb, date, boolean),
  app.transition_class(uuid, text, text), app.create_class_group(uuid, text, text)
  from public, anon;
-- Giao diện chỉ gọi các hàm nghiệp vụ; hàm sinh buổi, ghi lịch sử là nội bộ (security definer, không cấp cho authenticated).
grant execute on function
  app.is_assigned_to_class(uuid), app.class_operating_status(uuid), app.class_clash_warnings(uuid),
  app.compute_class_schedule(uuid, date, integer, jsonb),
  app.create_class(jsonb), app.save_class_info(uuid, jsonb), app.save_class_timetable(uuid, jsonb, date, boolean),
  app.transition_class(uuid, text, text), app.create_class_group(uuid, text, text)
  to authenticated;

select set_config('hmt.migration', '', false);
