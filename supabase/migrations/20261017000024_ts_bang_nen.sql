-- P3b1 (2/3): bảng nền của Tuyển sinh: chiến dịch, phụ huynh, học sinh, lead, lịch hẹn.
-- Cơ hội và phiếu kiểm tra thêm ở P3b2 (lịch hẹn khi đó thêm hai cột gắn cơ hội, phiếu).
-- Chuẩn: id uuid, cột người/giờ, nhật ký, không xoá cứng (apply_standard), RLS bật, ghi chỉ qua hàm.
-- Hiệu năng (CLAUDE.md): mỗi chỉ mục ghi lý do; chính sách RLS dùng (select ...) để tính một lần.

select set_config('hmt.migration', 'on', false);

create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------------
-- Chiến dịch marketing (tối giản cho hộp "Tạo chiến dịch mới" ở TS-03; màn quản lý CH-08 làm sau).
-- ---------------------------------------------------------------------------
create table app.campaign (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  starts_on date,
  ends_on date,
  is_active boolean not null default true,
  legacy_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check (ends_on is null or starts_on is null or ends_on >= starts_on)
);
comment on table app.campaign is 'Chiến dịch marketing gắn vào lead (R-CRM-11 giữ như bản cũ).';
-- Tên chiến dịch không trùng (không phân biệt hoa thường): tránh tạo trùng ở hộp tạo nhanh.
create unique index campaign_name_uq on app.campaign (lower(name));
select app.apply_standard('app.campaign');

-- ---------------------------------------------------------------------------
-- Phụ huynh, học sinh: bản tối giản cho P3 (màn Khách hàng làm sau). Tạo khi bấm "Tạo cơ hội".
-- ---------------------------------------------------------------------------
create table app.parent (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  full_name text not null check (btrim(full_name) <> ''),
  phone text not null check (phone ~ '^0[0-9]{9}$'),
  ward_catalog text not null default 'WARD' check (ward_catalog = 'WARD'),
  ward_code text,
  province_catalog text not null default 'PROVINCE' check (province_catalog = 'PROVINCE'),
  province_code text,
  address text,
  branch_id uuid not null references app.branch (id),
  legacy_ref text,
  search_text text generated always as (
    app.fold_text(code || ' ' || full_name || ' ' || phone || ' ' || coalesce(legacy_ref, ''))
  ) stored,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  foreign key (ward_catalog, ward_code) references app.catalog_item (catalog_code, code),
  foreign key (province_catalog, province_code) references app.catalog_item (catalog_code, code)
);
comment on table app.parent is 'Phụ huynh (bản tối giản của P3). Mã PH cấp bằng app.issue_person_code.';
-- Kiểm trùng số điện thoại khi tạo lead, tạo cơ hội (TS-03, TS-14): tra đúng một giá trị.
create index parent_phone_idx on app.parent (phone);
-- RLS và lọc theo cơ sở: cột branch_id nằm trong chính sách đọc.
create index parent_branch_idx on app.parent (branch_id);
-- Ô tìm kiếm (tên, SĐT, mã, mã cũ): LIKE '%...%' trên cột đã gấp chữ cần chỉ mục trigram.
create index parent_search_idx on app.parent using gin (search_text extensions.gin_trgm_ops);
select app.apply_standard('app.parent');

create table app.student (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  parent_id uuid not null references app.parent (id),
  full_name text not null check (btrim(full_name) <> ''),
  birth_date date,
  birth_year integer not null check (birth_year >= 1900),
  school text,
  self_rating text,
  goal text,
  branch_id uuid not null references app.branch (id),
  legacy_ref text,
  search_text text generated always as (
    app.fold_text(code || ' ' || full_name || ' ' || coalesce(school, '') || ' ' || coalesce(legacy_ref, ''))
  ) stored,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.student is 'Học sinh (bản tối giản của P3). Chỉ tạo khi có tên và năm sinh (R-CRM-03). Mã HS cấp bằng app.issue_person_code.';
-- Khoá ngoại: mở danh sách học sinh của một phụ huynh (smart button).
create index student_parent_idx on app.student (parent_id);
-- RLS và lọc theo cơ sở.
create index student_branch_idx on app.student (branch_id);
create index student_search_idx on app.student using gin (search_text extensions.gin_trgm_ops);
select app.apply_standard('app.student');

-- ---------------------------------------------------------------------------
-- Lead (docs/spec/04 R-CRM-01, 09; docs/spec/06 mục 1.1, 1.2).
-- ---------------------------------------------------------------------------
create table app.lead (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  -- Thông tin phụ huynh (chữ nhập tay; bản ghi phụ huynh chỉ tạo khi bấm "Tạo cơ hội").
  parent_name text not null check (btrim(parent_name) <> ''),
  parent_phone text not null check (parent_phone ~ '^0[0-9]{9}$'),
  ward_catalog text not null default 'WARD' check (ward_catalog = 'WARD'),
  ward_code text,
  province_catalog text not null default 'PROVINCE' check (province_catalog = 'PROVINCE'),
  province_code text,
  address text,
  need text,
  -- Thông tin học sinh (chữ nhập tay; bắt buộc tên, năm sinh ở cơ hội từ L5, R-CRM-03).
  student_name text,
  student_birth_date date,
  student_birth_year integer check (student_birth_year is null or student_birth_year >= 1900),
  school text,
  self_rating text,
  goal text,
  -- Phụ huynh có sẵn mà người dùng chọn "Gắn vào hồ sơ có sẵn" (TS-14).
  parent_id uuid references app.parent (id),
  branch_id uuid not null references app.branch (id),
  owner_id uuid not null references app.user_account (id),
  supporter_id uuid references app.user_account (id),
  -- Nguồn ba tầng (danh mục 9): loại → nguồn → kênh.
  source_type_catalog text not null default 'SOURCE_TYPE' check (source_type_catalog = 'SOURCE_TYPE'),
  source_type_code text not null,
  source_catalog text not null default 'SOURCE' check (source_catalog = 'SOURCE'),
  source_code text not null,
  channel_catalog text not null default 'SOURCE_CHANNEL' check (channel_catalog = 'SOURCE_CHANNEL'),
  channel_code text,
  campaign_id uuid references app.campaign (id),
  -- Giai đoạn lead C1–C4 + nhóm con (danh mục 10).
  stage_catalog text not null default 'LEAD_STAGE' check (stage_catalog = 'LEAD_STAGE'),
  stage_code text not null default 'C1',
  substage_catalog text not null default 'LEAD_SUBSTAGE' check (substage_catalog = 'LEAD_SUBSTAGE'),
  substage_code text,
  -- Trạng thái bản ghi: Đang dùng / Đã gộp (R-CRM-22).
  record_status text not null default 'DANG_DUNG' check (record_status in ('DANG_DUNG', 'DA_GOP')),
  merged_into_id uuid references app.lead (id),
  assigned_at timestamptz not null default now(),
  -- "Lịch hẹn kế tiếp": hệ thống tự tính từ lịch hẹn Chưa làm (R-CRM-04), không ai nhập tay.
  next_appointment_at timestamptz,
  legacy_ref text,
  search_text text generated always as (
    app.fold_text(code || ' ' || parent_name || ' ' || parent_phone || ' ' || coalesce(student_name, '') || ' '
                  || coalesce(legacy_ref, ''))
  ) stored,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check ((record_status = 'DA_GOP') = (merged_into_id is not null)),
  foreign key (ward_catalog, ward_code) references app.catalog_item (catalog_code, code),
  foreign key (province_catalog, province_code) references app.catalog_item (catalog_code, code),
  foreign key (source_type_catalog, source_type_code) references app.catalog_item (catalog_code, code),
  foreign key (source_catalog, source_code) references app.catalog_item (catalog_code, code),
  foreign key (channel_catalog, channel_code) references app.catalog_item (catalog_code, code),
  foreign key (stage_catalog, stage_code) references app.catalog_item (catalog_code, code),
  foreign key (substage_catalog, substage_code) references app.catalog_item (catalog_code, code)
);
comment on table app.lead is 'Lead (khách tiềm năng chưa thành cơ hội). Mã LD cấp lúc Lưu (R-CRM-19).';

-- Chỉ mục (lý do ghi từng dòng):
-- RLS và bộ lọc cơ sở: chính sách đọc so branch_id.
create index lead_branch_idx on app.lead (branch_id, created_at desc);
-- Chip "Tôi phụ trách" (bật sẵn) và lọc theo người phụ trách; có created_at để sắp xếp mặc định không phải sắp lại.
create index lead_owner_idx on app.lead (owner_id, created_at desc);
-- Chip "Tôi hỗ trợ" (nhân sự hỗ trợ).
create index lead_supporter_idx on app.lead (supporter_id) where supporter_id is not null;
-- Danh sách mặc định (mới nhất trước, bản đang dùng): quét chỉ mục theo thứ tự rồi dừng sau 50 dòng; đo trên 50.000 lead:
-- 52 ms (quét cả bảng) → 2 ms.
create index lead_created_idx on app.lead (created_at desc, id) where record_status = 'DANG_DUNG';
-- Lọc, Group By, Kanban theo giai đoạn và nhóm con.
create index lead_stage_idx on app.lead (stage_code, substage_code);
-- Lọc, Group By theo nguồn.
create index lead_source_idx on app.lead (source_type_code, source_code);
-- Khoá ngoại và bộ lọc chiến dịch.
create index lead_campaign_idx on app.lead (campaign_id) where campaign_id is not null;
-- Khoá ngoại và smart button "Phụ huynh".
create index lead_parent_idx on app.lead (parent_id) where parent_id is not null;
-- Kiểm trùng SĐT khi tạo lead (TS-03, TS-14).
create index lead_phone_idx on app.lead (parent_phone);
-- Khoá ngoại: tìm các bản ghi đã gộp vào một lead (R-CRM-22).
create index lead_merged_into_idx on app.lead (merged_into_id) where merged_into_id is not null;
-- Danh sách mặc định ẩn bản "Đã gộp"; chỉ mục nhỏ cho bản đã gộp (hiếm).
create index lead_merged_status_idx on app.lead (record_status) where record_status <> 'DANG_DUNG';
-- Sắp xếp và Kanban theo "Lịch hẹn kế tiếp".
create index lead_next_appointment_idx on app.lead (next_appointment_at) where next_appointment_at is not null;
-- Ô tìm kiếm (tên, SĐT, mã, mã cũ).
create index lead_search_idx on app.lead using gin (search_text extensions.gin_trgm_ops);
select app.apply_standard('app.lead');

-- Nhất quán danh mục của lead: nguồn đúng loại, kênh đúng nguồn, nhóm con đúng giai đoạn, cơ sở dạy học (R-HT-02).
create or replace function app.tg_lead_checks()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Luật: nguồn thuộc đúng loại nguồn.
  if not exists (select from app.catalog_item s join app.catalog_item t on t.id = s.parent_id
                  where s.catalog_code = 'SOURCE' and s.code = new.source_code
                    and t.catalog_code = 'SOURCE_TYPE' and t.code = new.source_type_code) then
    perform app.raise_error('HMT_NGUON_SAI', 'Nguồn không thuộc loại nguồn đã chọn.');
  end if;
  -- Luật: kênh thuộc đúng nguồn.
  if new.channel_code is not null and not exists (
       select from app.catalog_item c join app.catalog_item s on s.id = c.parent_id
        where c.catalog_code = 'SOURCE_CHANNEL' and c.code = new.channel_code
          and s.catalog_code = 'SOURCE' and s.code = new.source_code) then
    perform app.raise_error('HMT_NGUON_SAI', 'Kênh không thuộc nguồn đã chọn.');
  end if;
  -- Luật: nhóm con thuộc đúng giai đoạn.
  if new.substage_code is not null and not exists (
       select from app.catalog_item c join app.catalog_item s on s.id = c.parent_id
        where c.catalog_code = 'LEAD_SUBSTAGE' and c.code = new.substage_code
          and s.catalog_code = 'LEAD_STAGE' and s.code = new.stage_code) then
    perform app.raise_error('HMT_NHOM_CON_SAI', 'Nhóm con không thuộc giai đoạn đã chọn.');
  end if;
  -- Luật: dữ liệu nghiệp vụ không ghi cơ sở văn phòng (Hội sở CS3, R-HT-02).
  if not exists (select from app.branch where id = new.branch_id and not is_office) then
    perform app.raise_error('HMT_CO_SO_VAN_PHONG', 'Cơ sở văn phòng (Hội sở) không có lead.');
  end if;
  return new;
end;
$$;
create trigger lead_checks before insert or update on app.lead
  for each row execute function app.tg_lead_checks();

-- ---------------------------------------------------------------------------
-- Lịch hẹn (R-CRM-04): gắn đúng một hồ sơ. P3b1 chỉ gắn lead; P3b2 thêm cơ hội, phiếu kiểm tra.
-- ---------------------------------------------------------------------------
create table app.appointment (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references app.lead (id),
  activity_catalog text not null default 'ACTIVITY_TYPE' check (activity_catalog = 'ACTIVITY_TYPE'),
  activity_code text not null,
  scheduled_at timestamptz not null,
  title text not null check (btrim(title) <> ''),
  note text,
  owner_id uuid not null references app.user_account (id),
  -- Cơ sở của hồ sơ gắn (chép lúc tạo): để RLS và bộ lọc không phải nối bảng.
  branch_id uuid not null references app.branch (id),
  status text not null default 'CHUA_LAM' check (status in ('CHUA_LAM', 'HOAN_THANH', 'HUY')),
  cancel_reason_catalog text not null default 'APPOINTMENT_CANCEL_REASON' check (cancel_reason_catalog = 'APPOINTMENT_CANCEL_REASON'),
  cancel_reason_code text,
  cancel_note text,
  completed_at timestamptz,
  completed_by uuid,
  cancelled_at timestamptz,
  cancelled_by uuid,
  reopened_at timestamptz,
  reopened_by uuid,
  legacy_ref text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  constraint appointment_one_parent check (num_nonnulls(lead_id) = 1),
  -- Huỷ thì có lý do; không huỷ thì không còn lý do (mở lại xoá lý do).
  constraint appointment_cancel_reason check ((status = 'HUY') = (cancel_reason_code is not null)),
  foreign key (activity_catalog, activity_code) references app.catalog_item (catalog_code, code),
  foreign key (cancel_reason_catalog, cancel_reason_code) references app.catalog_item (catalog_code, code)
);
comment on table app.appointment is 'Lịch hẹn (hoạt động). Hoàn thành, Huỷ, Mở lại không đổi giai đoạn, không tạo việc, không gửi thông báo (R-CRM-04).';
-- Khoá ngoại: lịch hẹn của một lead (smart button, "Hoạt động sắp tới").
create index appointment_lead_idx on app.appointment (lead_id, scheduled_at) where lead_id is not null;
-- Chip "Tôi phụ trách" và danh sách lịch hẹn của một người.
create index appointment_owner_idx on app.appointment (owner_id, scheduled_at);
-- RLS và lọc theo cơ sở kèm khoảng thời gian (mặc định "Tuần này").
create index appointment_branch_time_idx on app.appointment (branch_id, scheduled_at);
-- Lọc theo trạng thái và tính "Lịch hẹn kế tiếp", dải nhắc "Quá hạn".
create index appointment_status_time_idx on app.appointment (status, scheduled_at);
select app.apply_standard('app.appointment');

-- "Lịch hẹn kế tiếp" của lead: lịch Chưa làm gần nhất (kể cả quá hạn, để Kanban hiện thanh đỏ). Chạy cùng giao dịch.
create or replace function app.refresh_lead_next_appointment(p_lead_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update app.lead l
     set next_appointment_at = (select min(a.scheduled_at) from app.appointment a
                                 where a.lead_id = l.id and a.status = 'CHUA_LAM')
   where l.id = p_lead_id;
$$;

create or replace function app.tg_appointment_refresh_next()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_OP in ('UPDATE', 'DELETE') and old.lead_id is not null then
    perform app.refresh_lead_next_appointment(old.lead_id);
  end if;
  if TG_OP in ('INSERT', 'UPDATE') and new.lead_id is not null
     and (TG_OP = 'INSERT' or new.lead_id is distinct from old.lead_id) then
    perform app.refresh_lead_next_appointment(new.lead_id);
  end if;
  return null;
end;
$$;
create trigger appointment_refresh_next after insert or update or delete on app.appointment
  for each row execute function app.tg_appointment_refresh_next();

-- ---------------------------------------------------------------------------
-- RLS: đọc theo ma trận quyền (phạm vi toàn hệ thống hoặc đúng cơ sở); ghi chỉ qua hàm nghiệp vụ.
-- Hàm quyền viết dạng (select ...) để tính một lần cho cả câu lệnh (CLAUDE.md, Hiệu năng).
-- ---------------------------------------------------------------------------
alter table app.campaign enable row level security;
alter table app.parent enable row level security;
alter table app.student enable row level security;
alter table app.lead enable row level security;
alter table app.appointment enable row level security;
revoke all on app.campaign, app.parent, app.student, app.lead, app.appointment from public, anon, authenticated;
grant select on app.campaign, app.parent, app.student, app.lead, app.appointment to authenticated;

-- Chiến dịch dùng chung mọi cơ sở: ai xem được lead thì xem được chiến dịch.
create policy campaign_read on app.campaign for select to authenticated
  using ((select app.has_permission('LEAD', 'XEM')));

create policy parent_read on app.parent for select to authenticated
  using ((select app.permission_scope('PARENT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('PARENT', 'XEM')) is not null
             and branch_id = (select app.current_branch_id())));
create policy student_read on app.student for select to authenticated
  using ((select app.permission_scope('STUDENT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('STUDENT', 'XEM')) is not null
             and branch_id = (select app.current_branch_id())));
create policy lead_read on app.lead for select to authenticated
  using ((select app.permission_scope('LEAD', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('LEAD', 'XEM')) is not null
             and branch_id = (select app.current_branch_id())));
create policy appointment_read on app.appointment for select to authenticated
  using ((select app.permission_scope('APPOINTMENT', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('APPOINTMENT', 'XEM')) is not null
             and branch_id = (select app.current_branch_id())));

-- ---------------------------------------------------------------------------
-- Ghi chú, lịch sử gắn vào lead; cột kỹ thuật ẩn khỏi lịch sử.
-- ---------------------------------------------------------------------------
insert into app.note_target (entity_type, table_name, name) values ('LEAD', 'app.lead', 'Lead');
insert into app.history_hidden_column (table_name, column_name) values
  ('app.lead', 'search_text'), ('app.lead', 'next_appointment_at'), ('app.parent', 'search_text'), ('app.student', 'search_text');

-- Thêm vào app.can_see_note_target: lead xét theo quyền Lead · Xem của cơ sở lead (P3b1). Phần còn lại giữ nguyên.
create or replace function app.can_see_note_target(p_entity_type text, p_entity_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
begin
  if not app.current_user_ready() then
    return false;
  end if;
  -- Luật: vai trò bắt xác thực hai bước chưa đạt aal2 thì không có quyền gì (như has_permission).
  if not app.mfa_satisfied() then
    return false;
  end if;
  if app.has_permission('ADMIN', 'XEM') then
    return true;
  end if;
  -- Luật: tài khoản người dùng theo ma trận quyền (Trưởng cơ sở thấy tài khoản cơ sở mình).
  if p_entity_type = 'USER_ACCOUNT' then
    select branch_id into v_branch_id from app.user_account where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('ACCOUNT', 'XEM', v_branch_id);
  end if;
  -- Luật: lead theo quyền Lead · Xem của cơ sở lead.
  if p_entity_type = 'LEAD' then
    select branch_id into v_branch_id from app.lead where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('LEAD', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'BRANCH' then
    v_branch_id := p_entity_id;
  elsif p_entity_type = 'ROOM' then
    select branch_id into v_branch_id from app.room where id = p_entity_id;
  else
    return false;
  end if;
  return v_branch_id is not distinct from app.current_branch_id()
      or exists (select from app.role r where r.code = any (app.current_roles()) and r.default_scope = 'TOAN_HE_THONG');
end;
$$;

select set_config('hmt.migration', '', false);
