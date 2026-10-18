-- P3b2a: Cơ hội (docs/spec/04 R-CRM-01, 02, 03, 09, 13, 14, 16, 23, 26, 27, 28; TS-06 đến TS-09).
-- Gồm: bảng cơ hội, lịch hẹn gắn được cơ hội, hàm tạo / sửa / đổi giai đoạn, hàm danh sách và Kanban, tìm hoặc tạo
-- phụ huynh và học sinh (R-CRM-27), khoá nhóm con, RLS.
-- Chưa làm (cần bảng khác): R-CRM-12, 13, 15 chờ bảng phiếu kiểm tra (P3b2b); R-CRM-16 phần chặn tạo đơn, R-CRM-17, 18
-- chờ đơn hàng và phiếu thu. Điểm nối với phiếu: app.opportunity_test_state, app.opportunity_l5_substage.
-- Hiệu năng (CLAUDE.md): mỗi chỉ mục ghi lý do; RLS dùng (select ...); danh sách phân trang ở máy chủ.

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Tham số: số thẻ mỗi cột Kanban trả về một lần gọi (không viết cứng trong code).
-- ---------------------------------------------------------------------------
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('kanban_cards_per_column', 'Số thẻ mỗi cột Kanban (lần tải đầu)', 'INT', 'thẻ', 5, 100, '20', false, null, null,
   'Kanban Cơ hội: mỗi cột tải bấy nhiêu thẻ mới nhất kèm tổng số của cột; xem thêm thì mở danh sách đã lọc.');

-- ---------------------------------------------------------------------------
-- Cơ hội. Một cơ hội một học sinh (R-CRM-23). Thông tin học sinh giữ dạng chữ trên cơ hội; hồ sơ học sinh (app.student)
-- chỉ sinh khi tạo phiếu kiểm tra hoặc duyệt đơn (R-CRM-27), lúc đó student_id được gắn.
-- ---------------------------------------------------------------------------
create table app.opportunity (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  lead_id uuid not null references app.lead (id),
  parent_id uuid not null references app.parent (id),
  student_id uuid references app.student (id),
  branch_id uuid not null references app.branch (id),
  owner_id uuid not null references app.user_account (id),
  supporter_id uuid references app.user_account (id),
  need text,
  student_name text check (student_name is null or btrim(student_name) <> ''),
  student_birth_date date,
  student_birth_year integer check (student_birth_year is null or student_birth_year >= 1900),
  school text,
  self_rating text,
  goal text,
  -- Nguồn chép từ lead lúc tạo (không đổi theo lead sau đó).
  source_type_catalog text not null default 'SOURCE_TYPE' check (source_type_catalog = 'SOURCE_TYPE'),
  source_type_code text not null,
  source_catalog text not null default 'SOURCE' check (source_catalog = 'SOURCE'),
  source_code text not null,
  channel_catalog text not null default 'SOURCE_CHANNEL' check (channel_catalog = 'SOURCE_CHANNEL'),
  channel_code text,
  campaign_id uuid references app.campaign (id),
  -- Giai đoạn L1–L8 và nhóm con (danh mục 11). Chỉ đi tới (R-CRM-02).
  stage_catalog text not null default 'OPP_STAGE' check (stage_catalog = 'OPP_STAGE'),
  stage_code text not null default 'L1',
  substage_catalog text not null default 'OPP_SUBSTAGE' check (substage_catalog = 'OPP_SUBSTAGE'),
  substage_code text,
  -- Lý do bỏ qua test (danh mục 33), R-CRM-14.
  skip_reason_catalog text not null default 'TEST_SKIP_REASON' check (skip_reason_catalog = 'TEST_SKIP_REASON'),
  skip_reason_code text,
  skip_note text,
  -- Trạng thái bản ghi: Đang dùng / Đã gộp (R-CRM-22; hàm gộp làm ở P3b3).
  record_status text not null default 'DANG_DUNG' check (record_status in ('DANG_DUNG', 'DA_GOP')),
  merged_into_id uuid references app.opportunity (id),
  assigned_at timestamptz not null default now(),
  -- "Lịch hẹn kế tiếp": hệ thống tự tính từ lịch hẹn Chưa làm (R-CRM-04), không ai nhập tay.
  next_appointment_at timestamptz,
  legacy_ref text,
  -- Ô tìm kiếm (mã, tên và SĐT phụ huynh, tên học sinh, mã cũ) đã gấp chữ; trigger giữ cho đúng, cả khi phụ huynh đổi tên.
  search_text text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check ((record_status = 'DA_GOP') = (merged_into_id is not null)),
  check ((skip_reason_code is null) or (stage_code in ('L7', 'L8'))),
  foreign key (source_type_catalog, source_type_code) references app.catalog_item (catalog_code, code),
  foreign key (source_catalog, source_code) references app.catalog_item (catalog_code, code),
  foreign key (channel_catalog, channel_code) references app.catalog_item (catalog_code, code),
  foreign key (stage_catalog, stage_code) references app.catalog_item (catalog_code, code),
  foreign key (substage_catalog, substage_code) references app.catalog_item (catalog_code, code),
  foreign key (skip_reason_catalog, skip_reason_code) references app.catalog_item (catalog_code, code)
);
comment on table app.opportunity is 'Cơ hội (lead đã đủ điều kiện). Mã CO cấp lúc Lưu (R-CRM-19). Giai đoạn chỉ đi tới (R-CRM-02).';

-- Chỉ mục (lý do ghi từng dòng; đo trên bản nháp 10.000 dòng, xem mô tả PR):
-- Kiểm "lead đã có cơ hội chưa" (R-CRM-01) và smart button lead → cơ hội; khoá ngoại.
create index opportunity_lead_idx on app.opportunity (lead_id);
-- Smart button phụ huynh → cơ hội; khoá ngoại.
create index opportunity_parent_idx on app.opportunity (parent_id);
-- Khoá ngoại và smart button học sinh → cơ hội.
create index opportunity_student_idx on app.opportunity (student_id) where student_id is not null;
-- RLS (người một cơ sở) kèm danh sách và cột Kanban theo giai đoạn, mới nhất trước: quét chỉ mục rồi dừng sau N dòng.
create index opportunity_branch_stage_idx on app.opportunity (branch_id, stage_code, created_at desc, id) where record_status = 'DANG_DUNG';
-- Như trên cho người thấy mọi cơ sở (không lọc cơ sở).
create index opportunity_stage_idx on app.opportunity (stage_code, created_at desc, id) where record_status = 'DANG_DUNG';
-- Danh sách mặc định (mới nhất trước, bản đang dùng, không lọc giai đoạn): quét chỉ mục theo thứ tự rồi dừng sau 50 dòng;
-- đo trên 20.000 cơ hội: 27 ms (quét cả bảng) → xem mô tả PR. Một chỉ mục cho người một cơ sở (RLS), một cho người thấy mọi cơ sở.
create index opportunity_branch_created_idx on app.opportunity (branch_id, created_at desc, id) where record_status = 'DANG_DUNG';
create index opportunity_created_idx on app.opportunity (created_at desc, id) where record_status = 'DANG_DUNG';
-- Chip "Tôi phụ trách" (bật sẵn) và lọc theo người phụ trách.
create index opportunity_owner_idx on app.opportunity (owner_id, stage_code, created_at desc);
-- Chip "Tôi hỗ trợ".
create index opportunity_supporter_idx on app.opportunity (supporter_id) where supporter_id is not null;
-- Lọc, Group By theo nhóm con.
create index opportunity_substage_idx on app.opportunity (substage_code) where substage_code is not null;
-- Nhóm "thời gian" của bộ lọc nhanh (quá hạn, hôm nay, sắp tới) và sắp xếp theo lịch hẹn kế tiếp.
create index opportunity_next_appointment_idx on app.opportunity (next_appointment_at) where next_appointment_at is not null;
-- Khoá ngoại: tìm các bản đã gộp vào một cơ hội (R-CRM-22); danh sách mặc định ẩn bản "Đã gộp".
create index opportunity_merged_into_idx on app.opportunity (merged_into_id) where merged_into_id is not null;
create index opportunity_merged_status_idx on app.opportunity (record_status) where record_status <> 'DANG_DUNG';
-- Khoá ngoại và bộ lọc chiến dịch.
create index opportunity_campaign_idx on app.opportunity (campaign_id) where campaign_id is not null;
-- Ô tìm kiếm.
create index opportunity_search_idx on app.opportunity using gin (search_text extensions.gin_trgm_ops);
select app.apply_standard('app.opportunity');

-- ---------------------------------------------------------------------------
-- Chuẩn hoá tên người để khớp hồ sơ (R-CRM-27): bỏ dấu, chữ thường, một dấu cách giữa các từ.
-- ---------------------------------------------------------------------------
create or replace function app.normalize_person_name(p_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  select btrim(regexp_replace(app.fold_text(p_name), '\s+', ' ', 'g'));
$$;

-- Ô tìm kiếm của cơ hội: mã, tên và SĐT phụ huynh, tên học sinh, mã cũ.
create or replace function app.opportunity_search_text(p_opp app.opportunity)
returns text
language sql
stable
set search_path = ''
as $$
  select app.fold_text(p_opp.code || ' ' || coalesce((select p.full_name || ' ' || p.phone from app.parent p
                                                       where p.id = p_opp.parent_id), '')
                       || ' ' || coalesce(p_opp.student_name, '') || ' ' || coalesce(p_opp.legacy_ref, ''));
$$;

create or replace function app.tg_opportunity_search_text()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.search_text := app.opportunity_search_text(new);
  return new;
end;
$$;
create trigger opportunity_search_text before insert or update on app.opportunity
  for each row execute function app.tg_opportunity_search_text();

-- Phụ huynh đổi tên hoặc SĐT thì ô tìm kiếm của các cơ hội của họ đổi theo (người sửa phụ huynh được ghi là người cập nhật).
create or replace function app.tg_parent_refresh_opportunity_search()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.full_name is distinct from old.full_name or new.phone is distinct from old.phone then
    update app.opportunity o set search_text = app.opportunity_search_text(o) where o.parent_id = new.id;
  end if;
  return null;
end;
$$;
create trigger parent_refresh_opportunity_search after update on app.parent
  for each row execute function app.tg_parent_refresh_opportunity_search();

-- ---------------------------------------------------------------------------
-- Luật nhất quán của cơ hội, chặn ở cơ sở dữ liệu (không chỉ ẩn nút):
--   R-CRM-02 chỉ đi tới; R-CRM-03 từ L5 trở lên bắt tên và năm sinh học sinh; danh mục đúng cấp; cơ sở dạy học (R-HT-02).
-- Người chạy migration (sửa dữ liệu cũ) không bị chặn hai luật đầu.
-- ---------------------------------------------------------------------------
create or replace function app.tg_opportunity_checks()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_old_order integer;
  v_new_order integer;
  v_l5_order integer;
begin
  -- Luật: nguồn thuộc đúng loại nguồn, kênh thuộc đúng nguồn (như lead).
  if not exists (select from app.catalog_item s join app.catalog_item t on t.id = s.parent_id
                  where s.catalog_code = 'SOURCE' and s.code = new.source_code
                    and t.catalog_code = 'SOURCE_TYPE' and t.code = new.source_type_code) then
    perform app.raise_error('HMT_NGUON_SAI', 'Nguồn không thuộc loại nguồn đã chọn.');
  end if;
  if new.channel_code is not null and not exists (
       select from app.catalog_item c join app.catalog_item s on s.id = c.parent_id
        where c.catalog_code = 'SOURCE_CHANNEL' and c.code = new.channel_code
          and s.catalog_code = 'SOURCE' and s.code = new.source_code) then
    perform app.raise_error('HMT_NGUON_SAI', 'Kênh không thuộc nguồn đã chọn.');
  end if;
  -- Luật: nhóm con thuộc đúng giai đoạn.
  if new.substage_code is not null and not exists (
       select from app.catalog_item c join app.catalog_item s on s.id = c.parent_id
        where c.catalog_code = 'OPP_SUBSTAGE' and c.code = new.substage_code
          and s.catalog_code = 'OPP_STAGE' and s.code = new.stage_code) then
    perform app.raise_error('HMT_NHOM_CON_SAI', 'Nhóm con không thuộc giai đoạn đã chọn.');
  end if;
  -- Luật: dữ liệu nghiệp vụ không ghi cơ sở văn phòng (Hội sở CS3, R-HT-02).
  if not exists (select from app.branch where id = new.branch_id and not is_office) then
    perform app.raise_error('HMT_CO_SO_VAN_PHONG', 'Cơ sở văn phòng (Hội sở) không có cơ hội.');
  end if;

  if not app.is_migration() then
    -- Luật R-CRM-02: giai đoạn cơ hội chỉ đi tới, không lùi.
    if TG_OP = 'UPDATE' and new.stage_code is distinct from old.stage_code then
      select sort_order into v_old_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = old.stage_code;
      select sort_order into v_new_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = new.stage_code;
      if v_new_order < v_old_order then
        perform app.raise_error('HMT_CO_HOI_KHONG_LUI', 'Giai đoạn cơ hội chỉ đi tới, không lùi lại.');
      end if;
    end if;
    -- Luật R-CRM-03: từ L5 trở lên bắt buộc có tên và năm sinh học sinh.
    select sort_order into v_l5_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5';
    select sort_order into v_new_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = new.stage_code;
    if v_new_order >= v_l5_order and (new.student_name is null or new.student_birth_year is null) then
      perform app.raise_error('HMT_THIEU_HOC_SINH',
        'Từ giai đoạn L5 trở lên cơ hội bắt buộc có tên và năm sinh của học sinh.');
    end if;
  end if;
  return new;
end;
$$;
create trigger opportunity_checks before insert or update on app.opportunity
  for each row execute function app.tg_opportunity_checks();

-- ---------------------------------------------------------------------------
-- Lịch hẹn gắn được cơ hội (R-CRM-04): đúng một hồ sơ trong (lead, cơ hội); phiếu kiểm tra thêm ở P3b2b.
-- ---------------------------------------------------------------------------
alter table app.appointment add column opportunity_id uuid references app.opportunity (id);
alter table app.appointment drop constraint appointment_one_parent;
alter table app.appointment add constraint appointment_one_parent check (num_nonnulls(lead_id, opportunity_id) = 1);
-- Khoá ngoại: lịch hẹn của một cơ hội (smart button, "Hoạt động sắp tới").
create index appointment_opportunity_idx on app.appointment (opportunity_id, scheduled_at) where opportunity_id is not null;

-- "Lịch hẹn kế tiếp" của cơ hội: lịch Chưa làm gần nhất (kể cả quá hạn, để Kanban hiện thanh đỏ). Chạy cùng giao dịch.
create or replace function app.refresh_opportunity_next_appointment(p_opportunity_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update app.opportunity o
     set next_appointment_at = (select min(a.scheduled_at) from app.appointment a
                                 where a.opportunity_id = o.id and a.status = 'CHUA_LAM')
   where o.id = p_opportunity_id;
$$;

create or replace function app.tg_appointment_refresh_next()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if TG_OP in ('UPDATE', 'DELETE') then
    if old.lead_id is not null then
      perform app.refresh_lead_next_appointment(old.lead_id);
    end if;
    if old.opportunity_id is not null then
      perform app.refresh_opportunity_next_appointment(old.opportunity_id);
    end if;
  end if;
  if TG_OP in ('INSERT', 'UPDATE') then
    if new.lead_id is not null and (TG_OP = 'INSERT' or new.lead_id is distinct from old.lead_id) then
      perform app.refresh_lead_next_appointment(new.lead_id);
    end if;
    if new.opportunity_id is not null
       and (TG_OP = 'INSERT' or new.opportunity_id is distinct from old.opportunity_id) then
      perform app.refresh_opportunity_next_appointment(new.opportunity_id);
    end if;
  end if;
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS: đọc theo ma trận quyền (toàn hệ thống hoặc đúng cơ sở); ghi chỉ qua hàm nghiệp vụ.
-- ---------------------------------------------------------------------------
alter table app.opportunity enable row level security;
revoke all on app.opportunity from public, anon, authenticated;
grant select on app.opportunity to authenticated;
create policy opportunity_read on app.opportunity for select to authenticated
  using ((select app.permission_scope('OPPORTUNITY', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('OPPORTUNITY', 'XEM')) is not null
             and branch_id = (select app.current_branch_id())));

-- ---------------------------------------------------------------------------
-- Ghi chú, lịch sử gắn vào cơ hội; cột kỹ thuật ẩn khỏi lịch sử.
-- ---------------------------------------------------------------------------
insert into app.note_target (entity_type, table_name, name) values ('OPPORTUNITY', 'app.opportunity', 'Cơ hội');
insert into app.history_hidden_column (table_name, column_name) values
  ('app.opportunity', 'search_text'), ('app.opportunity', 'next_appointment_at');

-- Thêm vào app.can_see_note_target: cơ hội xét theo quyền Cơ hội · Xem của cơ sở cơ hội. Phần còn lại giữ nguyên (như P3b1).
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
  if not app.mfa_satisfied() then
    return false;
  end if;
  if app.has_permission('ADMIN', 'XEM') then
    return true;
  end if;
  if p_entity_type = 'USER_ACCOUNT' then
    select branch_id into v_branch_id from app.user_account where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('ACCOUNT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'LEAD' then
    select branch_id into v_branch_id from app.lead where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('LEAD', 'XEM', v_branch_id);
  end if;
  -- Luật: cơ hội theo quyền Cơ hội · Xem của cơ sở cơ hội.
  if p_entity_type = 'OPPORTUNITY' then
    select branch_id into v_branch_id from app.opportunity where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('OPPORTUNITY', 'XEM', v_branch_id);
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

-- ---------------------------------------------------------------------------
-- Khoá nhóm con cơ hội cùng hàm dùng chúng (không Ngừng được, đổi tên được):
--   L5A, L5B, L5P, L5C…L5Q do hệ thống gắn (R-CRM-15); L6A hệ thống gắn (R-CRM-13); L8A, L8B, L8C (R-CRM-16, 17).
-- L7A, L7B của giai đoạn phiếu tái tục khoá khi viết hàm tái tục.
-- ---------------------------------------------------------------------------
update app.catalog_item set is_locked = true
 where catalog_code = 'OPP_SUBSTAGE'
   and code in ('L5A', 'L5B', 'L5P', 'L5C', 'L5D', 'L5E', 'L5F', 'L5G', 'L5H', 'L5I', 'L5K', 'L5N', 'L5M', 'L5O', 'L5Q',
                'L6A', 'L8A', 'L8B', 'L8C');

-- ===========================================================================
-- HÀM NGHIỆP VỤ
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Tìm hoặc tạo phụ huynh (R-CRM-27, 28). Hàm nội bộ (giao diện không gọi), chạy trong hàm tạo cơ hội.
-- Làm gì: khớp theo số điện thoại đã chuẩn hoá. Khớp thì dùng hồ sơ có sẵn (nhiều hồ sơ cùng số thì lấy hồ sơ cũ nhất),
--   KHÔNG ghi đè tên (bố, mẹ dùng chung số). Không khớp thì tạo mới, cấp mã PH; cơ sở tiếp nhận là cơ sở của cơ hội
--   đầu tiên sinh ra hồ sơ và chỉ Admin sửa (R-CRM-28).
-- Kết quả: id phụ huynh.
-- ---------------------------------------------------------------------------
create or replace function app.find_or_create_parent(
  p_phone text, p_name text, p_ward_code text, p_province_code text, p_address text, p_branch_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone text := app.normalize_phone(p_phone);
  v_id uuid;
begin
  -- Luật R-CRM-27: khớp theo SĐT đã chuẩn hoá; khớp thì dùng hồ sơ cũ nhất, không ghi đè tên.
  select id into v_id from app.parent where phone = v_phone order by created_at, id limit 1;
  if v_id is not null then
    return v_id;
  end if;
  if v_phone !~ '^0[0-9]{9}$' then
    perform app.raise_error('HMT_SDT_SAI', 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.');
  end if;
  -- Luật R-CRM-28: tạo mới thì cơ sở tiếp nhận là cơ sở của cơ hội.
  insert into app.parent (code, full_name, phone, ward_code, province_code, address, branch_id)
  values (app.issue_person_code('PH'), btrim(p_name), v_phone, p_ward_code, p_province_code, p_address, p_branch_id)
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tìm hoặc tạo học sinh (R-CRM-27). Hàm nội bộ: phiếu kiểm tra (P3b2b) và duyệt đơn gọi.
-- Làm gì: khớp theo phụ huynh + tên đã chuẩn hoá + năm sinh. Khớp thì dùng hồ sơ có sẵn. Không khớp thì tạo mới, kể cả
--   khi cùng tên nhưng khác năm sinh (hai hồ sơ riêng). Cơ sở tiếp nhận là cơ sở của cơ hội.
-- Kết quả: id học sinh.
-- ---------------------------------------------------------------------------
create or replace function app.find_or_create_student(
  p_parent_id uuid, p_name text, p_birth_year integer, p_birth_date date, p_school text, p_self_rating text,
  p_goal text, p_branch_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if btrim(coalesce(p_name, '')) = '' or p_birth_year is null then
    perform app.raise_error('HMT_THIEU_HOC_SINH', 'Cần tên và năm sinh của học sinh để tạo hồ sơ học sinh.');
  end if;
  -- Luật R-CRM-27: khớp theo phụ huynh + tên chuẩn hoá + năm sinh.
  select id into v_id from app.student
   where parent_id = p_parent_id and app.normalize_person_name(full_name) = app.normalize_person_name(p_name)
     and birth_year = p_birth_year
   order by created_at, id limit 1;
  if v_id is not null then
    return v_id;
  end if;
  insert into app.student (code, parent_id, full_name, birth_date, birth_year, school, self_rating, goal, branch_id)
  values (app.issue_person_code('HS'), p_parent_id, btrim(p_name), p_birth_date, p_birth_year, p_school, p_self_rating,
          p_goal, p_branch_id)
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Điểm nối với phiếu kiểm tra (P3b2b thay thân hai hàm này bằng truy vấn bảng phiếu).
-- opportunity_test_state: số phiếu dang dở (Nháp, Đang test, Chờ giáo viên chấm), đã Hoàn thành, đã Huỷ của cơ hội và
--   mã các phiếu dang dở (R-CRM-12, 14). Chưa có bảng phiếu nên mọi cơ hội đều "không có phiếu nào".
-- opportunity_l5_substage: nhóm con L5 theo các phiếu của cơ hội (R-CRM-15); không có phiếu nào tính được thì L5A.
-- ---------------------------------------------------------------------------
create or replace function app.opportunity_test_state(p_opportunity_id uuid)
returns table (in_progress integer, completed integer, cancelled integer, in_progress_codes text[])
language sql
stable
set search_path = ''
as $$
  select 0, 0, 0, array[]::text[];
$$;

create or replace function app.opportunity_l5_substage(p_opportunity_id uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select 'L5A'::text;
$$;

-- ---------------------------------------------------------------------------
-- Tạo cơ hội từ lead (TS-06). R-CRM-19: mã CO cấp lúc Lưu.
-- Ai gọi: người có quyền Cơ hội · Tạo và Lead · Xem ở cơ sở của lead; giao cho người khác cần Giao việc.
-- Đầu vào: p_lead_id; p_data (ô được đổi so với lead: need, student_name, student_birth_date, student_birth_year, school,
--   self_rating, goal, owner_id, supporter_id); p_confirm_existing: đã xem cảnh báo lead đã có cơ hội, chọn tạo thêm.
-- Kết quả: {id, code, parent_id, parent_code}.
-- Luật: R-CRM-01 (lead đã có cơ hội thì cảnh báo kèm mã, xác nhận lần hai mới tạo thêm; KHÔNG chặn theo C4C);
--   R-CRM-09 (tạo xong, lead tự về C4D "Tạo cơ hội thành công"); R-CRM-27, 28 (tìm hoặc tạo phụ huynh theo SĐT,
--   hồ sơ cũ khớp thì không ghi đè tên); R-CRM-23 (một học sinh). Giai đoạn đầu L1 (anh chốt 18/10, luật chưa nói).
-- ---------------------------------------------------------------------------
create or replace function app.create_opportunity(
  p_lead_id uuid, p_data jsonb default '{}'::jsonb, p_confirm_existing boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lead app.lead;
  v app.opportunity;
  v_existing text;
  v_parent_id uuid;
  v_parent_code text;
  v_owner uuid;
  v_year integer;
  v_id uuid;
  v_code text;
begin
  select * into v_lead from app.lead where id = p_lead_id;
  if v_lead.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead.');
  end if;
  -- Luật: quyền tạo cơ hội và xem lead ở cơ sở của lead.
  perform app.assert_can('OPPORTUNITY', 'TAO', v_lead.branch_id);
  perform app.assert_can('LEAD', 'XEM', v_lead.branch_id);
  if v_lead.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Lead này đã gộp vào bản khác, không tạo cơ hội được.');
  end if;

  -- Luật R-CRM-01: lead đã có cơ hội đang dùng thì cảnh báo kèm mã cũ; xác nhận lần hai mới tạo thêm.
  select string_agg(code, ', ' order by created_at) into v_existing
    from app.opportunity where lead_id = p_lead_id and record_status = 'DANG_DUNG';
  if v_existing is not null and not coalesce(p_confirm_existing, false) then
    perform app.raise_error('HMT_LEAD_DA_CO_CO_HOI',
      format('Lead này đã có cơ hội %s. Xác nhận nếu vẫn muốn tạo thêm.', v_existing));
  end if;

  v := jsonb_populate_record(null::app.opportunity, p_data);

  -- Luật: người phụ trách mặc định là người phụ trách lead; giao cho người khác cần quyền Giao việc.
  v_owner := coalesce(v.owner_id, v_lead.owner_id);
  if v_owner <> v_lead.owner_id and v_owner <> auth.uid() then
    perform app.assert_can('OPPORTUNITY', 'GIAO_VIEC', v_lead.branch_id);
  end if;
  perform app.assert_staff_in_branch(v_owner, v_lead.branch_id);
  if coalesce(v.supporter_id, v_lead.supporter_id) is not null then
    perform app.assert_staff_in_branch(coalesce(v.supporter_id, v_lead.supporter_id), v_lead.branch_id);
  end if;

  -- Luật R-CRM-27, 28: phụ huynh có sẵn (lead đã gắn) hoặc khớp theo SĐT; không thì tạo mới. Không ghi đè tên.
  v_parent_id := coalesce(v_lead.parent_id,
    app.find_or_create_parent(v_lead.parent_phone, v_lead.parent_name, v_lead.ward_code, v_lead.province_code,
                              v_lead.address, v_lead.branch_id));
  select code into v_parent_code from app.parent where id = v_parent_id;

  -- Thông tin học sinh: ô nào p_data có thì lấy, không thì chép từ lead.
  v_year := case when p_data ? 'student_birth_year' then v.student_birth_year
                 when p_data ? 'student_birth_date' then extract(year from v.student_birth_date)::integer
                 else v_lead.student_birth_year end;

  v_code := app.issue_crm_code('CO');
  insert into app.opportunity (
    code, lead_id, parent_id, branch_id, owner_id, supporter_id, need,
    student_name, student_birth_date, student_birth_year, school, self_rating, goal,
    source_type_code, source_code, channel_code, campaign_id, stage_code, substage_code)
  values (
    v_code, p_lead_id, v_parent_id, v_lead.branch_id, v_owner, coalesce(v.supporter_id, v_lead.supporter_id),
    case when p_data ? 'need' then v.need else v_lead.need end,
    nullif(btrim(coalesce(case when p_data ? 'student_name' then v.student_name else v_lead.student_name end, '')), ''),
    case when p_data ? 'student_birth_date' then v.student_birth_date else v_lead.student_birth_date end,
    v_year,
    case when p_data ? 'school' then v.school else v_lead.school end,
    case when p_data ? 'self_rating' then v.self_rating else v_lead.self_rating end,
    case when p_data ? 'goal' then v.goal else v_lead.goal end,
    v_lead.source_type_code, v_lead.source_code, v_lead.channel_code, v_lead.campaign_id, 'L1', null)
  returning id into v_id;

  -- Luật R-CRM-09: lead tự về C4D "Tạo cơ hội thành công" (người dùng không chọn được nhóm con này) và nhận phụ huynh.
  update app.lead set stage_code = 'C4', substage_code = 'C4D', parent_id = v_parent_id where id = p_lead_id;

  return jsonb_build_object('id', v_id, 'code', v_code, 'parent_id', v_parent_id, 'parent_code', v_parent_code);
end;
$$;

-- ---------------------------------------------------------------------------
-- Sửa cơ hội: các ô thông tin (nhu cầu, học sinh, người hỗ trợ). Giai đoạn, người phụ trách, trạng thái có hàm riêng.
-- Ai gọi: người có quyền Cơ hội · Sửa ở cơ sở của cơ hội. Bản "Đã gộp" chỉ đọc (R-CRM-22).
-- Luật: R-CRM-03 (từ L5 trở lên không được xoá tên, năm sinh học sinh); đã có hồ sơ học sinh thì sửa ở đây là sửa luôn
--   hồ sơ học sinh trong cùng giao dịch (một nguồn, anh chốt 18/10 cho bốn câu P3b2), cần quyền Học sinh · Sửa ở cơ sở của hồ sơ.
-- ---------------------------------------------------------------------------
create or replace function app.update_opportunity(p_id uuid, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old app.opportunity;
  v app.opportunity;
  v_student app.student;
  v_year integer;
begin
  select * into v_old from app.opportunity where id = p_id for update;
  if v_old.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
  end if;
  perform app.assert_can('OPPORTUNITY', 'SUA', v_old.branch_id);
  if v_old.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, chỉ xem được.');
  end if;

  v := jsonb_populate_record(v_old, p_data);
  v_year := case when p_data ? 'student_birth_year' then v.student_birth_year
                 when p_data ? 'student_birth_date' then extract(year from v.student_birth_date)::integer
                 else v_old.student_birth_year end;
  if v.supporter_id is not null and v.supporter_id is distinct from v_old.supporter_id then
    perform app.assert_staff_in_branch(v.supporter_id, v_old.branch_id);
  end if;

  -- Luật R-CRM-26, 27: đã có hồ sơ học sinh thì sửa luôn hồ sơ đó.
  if v_old.student_id is not null
     and (p_data ?| array['student_name', 'student_birth_date', 'student_birth_year', 'school', 'self_rating', 'goal']) then
    select * into v_student from app.student where id = v_old.student_id;
    perform app.assert_can('STUDENT', 'SUA', v_student.branch_id);
    if btrim(coalesce(v.student_name, '')) = '' or v_year is null then
      perform app.raise_error('HMT_THIEU_HOC_SINH', 'Hồ sơ học sinh bắt buộc có tên và năm sinh.');
    end if;
    update app.student set full_name = btrim(v.student_name), birth_date = v.student_birth_date, birth_year = v_year,
           school = v.school, self_rating = v.self_rating, goal = v.goal
     where id = v_old.student_id;
  end if;

  -- Luật R-CRM-03 (kiểm lại ở trigger): từ L5 trở lên tên và năm sinh học sinh không được trống.
  update app.opportunity set
    need = v.need, student_name = nullif(btrim(coalesce(v.student_name, '')), ''), student_birth_date = v.student_birth_date,
    student_birth_year = v_year, school = v.school, self_rating = v.self_rating, goal = v.goal,
    supporter_id = v.supporter_id
   where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Đổi giai đoạn, nhóm con của cơ hội (TS-09). Không có Hoàn tác.
-- Ai gọi: người có quyền Cơ hội · Sửa ở cơ sở của cơ hội.
-- Đầu vào: giai đoạn đích; nhóm con (không bắt buộc, trừ L8); lý do bỏ qua test (danh mục 33) và ghi chú; xác nhận
--   "chuyển L8 không hoàn tác được".
-- Luật, kiểm theo thứ tự R-CRM-03 → R-CRM-12 → R-CRM-14 → R-CRM-16 (giao diện kiểm trước để hiện đúng hộp, hàm kiểm lại tất cả):
--   R-CRM-02 chỉ đi tới (trigger của bảng kiểm lại); R-CRM-03 từ L5 bắt tên, năm sinh học sinh, kể cả bấm thẳng L7, L8;
--   R-CRM-13 người dùng không bấm L6, không tay đổi về L6A; R-CRM-15 nhóm con L5 do hệ thống gắn;
--   R-CRM-12 còn phiếu dang dở thì không sang L7, L8; R-CRM-14 không có phiếu hoàn thành thì sang L7, L8 bắt lý do bỏ
--   qua test ("Khác" bắt ghi chú); R-CRM-16 L8 bắt nhóm con L8A, L8B, L8C và xác nhận.
-- Đổi nhóm con trong cùng giai đoạn (R-CRM-35): được, cả lùi, có lịch sử (nhật ký), trừ: rời L8C (R-CRM-17), đổi tay nhóm con L5
--   (R-CRM-15), chọn lại L6A (R-CRM-34). Ở L6, người dùng chọn L6B…L6F sau khi hệ thống gắn L6A (R-CRM-34).
-- ---------------------------------------------------------------------------
create or replace function app.change_opportunity_stage(
  p_id uuid, p_stage_code text, p_substage_code text default null, p_skip_reason_code text default null,
  p_skip_note text default null, p_confirm_l8 boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_opp app.opportunity;
  v_old_order integer;
  v_new_order integer;
  v_l5_order integer;
  v_state record;
  v_missing text[] := array[]::text[];
  v_skip_code text;
  v_skip_note text;
  v_substage text := p_substage_code;
begin
  select * into v_opp from app.opportunity where id = p_id for update;
  if v_opp.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
  end if;
  perform app.assert_can('OPPORTUNITY', 'SUA', v_opp.branch_id);
  if v_opp.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, chỉ xem được.');
  end if;
  perform app.assert_catalog_code_active('OPP_STAGE', p_stage_code);
  if p_substage_code is not null then
    perform app.assert_catalog_code_active('OPP_SUBSTAGE', p_substage_code);
  end if;

  select sort_order into v_old_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = v_opp.stage_code;
  select sort_order into v_new_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = p_stage_code;
  select sort_order into v_l5_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5';

  -- Luật R-CRM-02: giai đoạn chỉ đi tới.
  if v_new_order < v_old_order then
    perform app.raise_error('HMT_CO_HOI_KHONG_LUI', 'Giai đoạn cơ hội chỉ đi tới, không lùi lại.');
  end if;

  -- ===== Cùng giai đoạn: chỉ đổi nhóm con =====
  if p_stage_code = v_opp.stage_code then
    if p_substage_code is null then
      perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn nhóm con mới của giai đoạn này.');
    end if;
    if p_substage_code is not distinct from v_opp.substage_code then
      perform app.raise_error('HMT_KHONG_THAY_DOI', 'Cơ hội đã ở nhóm con này.');
    end if;
    -- Luật R-CRM-17: đã L8C thì không rời nhóm con L8C.
    if v_opp.substage_code = 'L8C' then
      perform app.raise_error('HMT_L8C_GIU_NGUYEN', 'Cơ hội đã ở nhóm con L8C (đã đóng đủ học phí), không đổi sang nhóm con khác.');
    end if;
    -- Luật R-CRM-15: nhóm con L5 do hệ thống gắn theo các phiếu kiểm tra, không đổi tay.
    if p_stage_code = 'L5' then
      perform app.raise_error('HMT_NHOM_CON_L5_HE_THONG', 'Nhóm con của L5 do hệ thống tự gắn theo phiếu kiểm tra, không đổi tay.');
    end if;
    -- Luật R-CRM-13: không tay đổi về L6A (hệ thống gắn khi phiếu Hoàn thành).
    if p_substage_code = 'L6A' then
      perform app.raise_error('HMT_L6A_HE_THONG', 'Nhóm con L6A do hệ thống tự gắn khi có kết quả test, không đổi tay.');
    end if;
    update app.opportunity set substage_code = p_substage_code where id = p_id;
    return;
  end if;

  -- ===== Sang giai đoạn phía trước =====
  -- Luật R-CRM-13: L6 chỉ do hệ thống chuyển (khi phiếu kiểm tra Hoàn thành), người dùng không bấm tay.
  if p_stage_code = 'L6' then
    perform app.raise_error('HMT_L6_HE_THONG', 'Giai đoạn L6 do hệ thống tự chuyển khi phiếu kiểm tra hoàn thành, không bấm tay.');
  end if;
  -- Luật R-CRM-15: vào L5 thì nhóm con do hệ thống gắn; người dùng không chọn.
  if p_stage_code = 'L5' then
    if p_substage_code is not null then
      perform app.raise_error('HMT_NHOM_CON_L5_HE_THONG', 'Nhóm con của L5 do hệ thống tự gắn theo phiếu kiểm tra, không chọn tay.');
    end if;
    v_substage := app.opportunity_l5_substage(p_id);
  end if;

  -- Luật R-CRM-03: từ L5 trở lên bắt buộc tên và năm sinh học sinh, kể cả khi bấm thẳng L7, L8.
  if v_new_order >= v_l5_order then
    if v_opp.student_name is null then
      v_missing := array_append(v_missing, 'tên học sinh');
    end if;
    if v_opp.student_birth_year is null then
      v_missing := array_append(v_missing, 'năm sinh học sinh');
    end if;
    if cardinality(v_missing) > 0 then
      perform app.raise_error('HMT_THIEU_HOC_SINH',
        format('Chưa chuyển được: cơ hội còn thiếu %s.', array_to_string(v_missing, ' và ')));
    end if;
  end if;

  if p_stage_code in ('L7', 'L8') then
    select * into v_state from app.opportunity_test_state(p_id);
    -- Luật R-CRM-12: còn phiếu dang dở thì không sang L7, L8; nêu rõ mã phiếu.
    if v_state.in_progress > 0 then
      perform app.raise_error('HMT_PHIEU_DANG_DO',
        format('Cơ hội còn phiếu kiểm tra đang dở: %s. Hoàn thành hoặc huỷ phiếu trước.',
               array_to_string(v_state.in_progress_codes, ', ')));
    end if;
    -- Luật R-CRM-14: không có phiếu Hoàn thành (không có phiếu, hoặc mọi phiếu đều Huỷ) thì bắt lý do bỏ qua test.
    if v_state.completed = 0 then
      v_skip_code := coalesce(p_skip_reason_code, v_opp.skip_reason_code);
      v_skip_note := case when p_skip_reason_code is not null then nullif(btrim(coalesce(p_skip_note, '')), '')
                          else v_opp.skip_note end;
      if v_skip_code is null then
        perform app.raise_error('HMT_THIEU_LY_DO', 'Cơ hội chưa có phiếu kiểm tra hoàn thành: chọn lý do bỏ qua test.');
      end if;
      perform app.assert_catalog_code_active('TEST_SKIP_REASON', v_skip_code);
      if (select requires_note from app.catalog_item where catalog_code = 'TEST_SKIP_REASON' and code = v_skip_code)
         and v_skip_note is null then
        perform app.raise_error('HMT_THIEU_GHI_CHU', 'Chọn "Khác" thì phải ghi chú lý do bỏ qua test.');
      end if;
    end if;
  end if;

  -- Luật R-CRM-16: sang L8 bắt chọn L8A, L8B hoặc L8C và xác nhận (không có Hoàn tác).
  if p_stage_code = 'L8' then
    if p_substage_code is null or p_substage_code not in ('L8A', 'L8B', 'L8C') then
      perform app.raise_error('HMT_L8_CAN_NHOM_CON', 'Chuyển L8 phải chọn nhóm con L8A, L8B hoặc L8C.');
    end if;
    if not coalesce(p_confirm_l8, false) then
      perform app.raise_error('HMT_L8_CAN_XAC_NHAN', 'Chuyển sang L8 không hoàn tác được: xác nhận để tiếp tục.');
    end if;
  end if;

  update app.opportunity
     set stage_code = p_stage_code, substage_code = v_substage,
         skip_reason_code = v_skip_code, skip_note = v_skip_note
   where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Giao người phụ trách (TS-05): mở rộng cho cơ hội. Ai gọi: người có quyền Giao việc ở cơ sở của bản ghi.
-- Đầu vào: loại bản ghi (LEAD, OPPORTUNITY), danh sách id (tối đa list_page_size_max), người phụ trách mới (cùng cơ sở).
-- Kết quả: số bản ghi đã giao.
-- ---------------------------------------------------------------------------
create or replace function app.assign_owner(p_entity_type text, p_ids uuid[], p_owner_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lead app.lead;
  v_opp app.opportunity;
  v_id uuid;
  v_count integer := 0;
begin
  if p_entity_type not in ('LEAD', 'OPPORTUNITY') then
    perform app.raise_error('HMT_LOAI_BAN_GHI_SAI', 'Chưa giao việc được cho loại bản ghi này.');
  end if;
  if coalesce(cardinality(p_ids), 0) = 0 then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ít nhất một bản ghi để giao.');
  end if;
  if cardinality(p_ids) > app.get_setting_int('list_page_size_max') then
    perform app.raise_error('HMT_QUA_NHIEU_BAN_GHI', 'Giao quá nhiều bản ghi một lần, hãy chia nhỏ.');
  end if;
  for v_id in select distinct unnest(p_ids) loop
    if p_entity_type = 'LEAD' then
      select * into v_lead from app.lead where id = v_id;
      if v_lead.id is null then
        perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead cần giao.');
      end if;
      perform app.assert_can('LEAD', 'GIAO_VIEC', v_lead.branch_id);
      if v_lead.record_status = 'DA_GOP' then
        perform app.raise_error('HMT_BAN_GHI_DA_GOP', format('Lead %s đã gộp vào bản khác, không giao được.', v_lead.code));
      end if;
      perform app.assert_staff_in_branch(p_owner_id, v_lead.branch_id);
      update app.lead set owner_id = p_owner_id, assigned_at = now() where id = v_id;
    else
      select * into v_opp from app.opportunity where id = v_id;
      if v_opp.id is null then
        perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội cần giao.');
      end if;
      perform app.assert_can('OPPORTUNITY', 'GIAO_VIEC', v_opp.branch_id);
      if v_opp.record_status = 'DA_GOP' then
        perform app.raise_error('HMT_BAN_GHI_DA_GOP', format('Cơ hội %s đã gộp vào bản khác, không giao được.', v_opp.code));
      end if;
      perform app.assert_staff_in_branch(p_owner_id, v_opp.branch_id);
      update app.opportunity set owner_id = p_owner_id, assigned_at = now() where id = v_id;
    end if;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tạo lịch hẹn gắn một lead HOẶC một cơ hội (R-CRM-04: đúng một hồ sơ, không có lịch hẹn mồ côi).
-- Thay hàm cũ (chỉ gắn lead) bằng bản có thêm tham số cuối p_opportunity_id; gọi như cũ (gắn lead) vẫn chạy.
-- Ai gọi: quyền Lịch hẹn · Tạo ở cơ sở của hồ sơ; đặt người phụ trách khác mình cần Giao việc.
-- ---------------------------------------------------------------------------
drop function app.create_appointment(uuid, text, timestamptz, text, text, uuid);
create or replace function app.create_appointment(
  p_lead_id uuid, p_activity_code text, p_scheduled_at timestamptz, p_title text,
  p_note text default null, p_owner_id uuid default null, p_opportunity_id uuid default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
  v_status text;
  v_owner uuid := coalesce(p_owner_id, auth.uid());
  v_id uuid;
begin
  -- Luật: lịch hẹn gắn đúng một hồ sơ (lead hoặc cơ hội), không mồ côi, không gắn hai nơi.
  if num_nonnulls(p_lead_id, p_opportunity_id) <> 1 then
    perform app.raise_error('HMT_LICH_HEN_MO_COI', 'Lịch hẹn phải gắn với đúng một hồ sơ.');
  end if;
  if p_lead_id is not null then
    select branch_id, record_status into v_branch_id, v_status from app.lead where id = p_lead_id;
  else
    select branch_id, record_status into v_branch_id, v_status from app.opportunity where id = p_opportunity_id;
  end if;
  if v_branch_id is null then
    perform app.raise_error('HMT_LICH_HEN_MO_COI', 'Lịch hẹn phải gắn với một hồ sơ.');
  end if;
  perform app.assert_can('APPOINTMENT', 'TAO', v_branch_id);
  if v_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Hồ sơ này đã gộp vào bản khác, không thêm lịch hẹn được.');
  end if;
  if v_owner <> auth.uid() then
    perform app.assert_can('APPOINTMENT', 'GIAO_VIEC', v_branch_id);
  end if;
  perform app.assert_staff_in_branch(v_owner, v_branch_id);
  perform app.assert_catalog_code_active('ACTIVITY_TYPE', p_activity_code);
  if p_scheduled_at is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ngày giờ của lịch hẹn.');
  end if;
  if btrim(coalesce(p_title, '')) = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập nội dung lịch hẹn.');
  end if;
  insert into app.appointment (lead_id, opportunity_id, activity_code, scheduled_at, title, note, owner_id, branch_id)
  values (p_lead_id, p_opportunity_id, p_activity_code, p_scheduled_at, btrim(p_title), p_note, v_owner, v_branch_id)
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách lịch hẹn: thêm cơ hội (bộ lọc opportunity_id; cột opportunity_id, record_code, record_label). Cột cũ giữ nguyên.
-- record_code, record_label: mã và nhãn của hồ sơ gắn (lead hoặc cơ hội), để màn không phải tự chọn.
-- ---------------------------------------------------------------------------
create or replace function app.list_appointments(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'time_asc',
  p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('APPOINTMENT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_activity text[] := array(select jsonb_array_elements_text(p_filters -> 'activity'));
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lịch hẹn.');
  end if;
  with f as not materialized (
    select a.*
      from app.appointment a
     where (v_scope = 'TOAN_HE_THONG' or a.branch_id = v_my_branch)
       and (cardinality(v_status) = 0 or a.status = any (v_status))
       and (cardinality(v_activity) = 0 or a.activity_code = any (v_activity))
       and (v_from is null or a.scheduled_at >= v_from)
       and (v_to is null or a.scheduled_at < v_to)
       and (not v_mine or a.owner_id = auth.uid())
       and (v_lead is null or a.lead_id = v_lead)
       and (v_opp is null or a.opportunity_id = v_opp)
       and (v_branch is null or a.branch_id = v_branch)
  ),
  page as (
    select * from f
     order by case when p_sort = 'time_desc' then f.scheduled_at end desc,
              f.scheduled_at asc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'activity_code', p.activity_code, 'scheduled_at', p.scheduled_at, 'title', p.title,
             'status', p.status, 'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'lead_id', p.lead_id, 'lead_code', l.code,
             'lead_label', l.parent_name || coalesce(' · ' || nullif(l.student_name, ''), ''),
             'opportunity_id', p.opportunity_id, 'opportunity_code', o.code,
             'record_code', coalesce(l.code, o.code),
             'record_label', coalesce(l.parent_name || coalesce(' · ' || nullif(l.student_name, ''), ''),
                                      po.full_name || coalesce(' · ' || nullif(o.student_name, ''), '')),
             'cancel_reason_code', p.cancel_reason_code, 'branch_code', b.code)
             order by case when p_sort = 'time_desc' then p.scheduled_at end desc, p.scheduled_at asc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    left join app.lead l on l.id = p.lead_id
    left join app.opportunity o on o.id = p.opportunity_id
    left join app.parent po on po.id = o.parent_id;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách cơ hội phân trang ở máy chủ (TS-07). Trả {total, rows}; chỉ các cột màn hiện. security definer có chủ ý, cùng
-- lý do với list_leads (LIKE không "leakproof" dưới RLS nên chỉ mục trigram không dùng được): phạm vi từ
-- app.permission_scope('OPPORTUNITY', 'XEM'), toàn hệ thống hoặc đúng cơ sở của người gọi.
-- Bộ lọc: q, stage[], substage[], branch_id, owner_id, mine, supporter_mine, parent_id, lead_id, created_from, created_to,
--   next_from, next_to (khoảng lịch hẹn kế tiếp), next_before (quá hạn: lịch kế tiếp trước mốc này), no_appointment,
--   include_merged. Sắp xếp: created_desc (mặc định), created_asc, next_appointment_asc, name_asc (tên học sinh).
-- ---------------------------------------------------------------------------
create or replace function app.list_opportunities(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc',
  p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('OPPORTUNITY', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_support_mine boolean := coalesce((p_filters ->> 'supporter_mine')::boolean, false);
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_next_from timestamptz := nullif(p_filters ->> 'next_from', '')::timestamptz;
  v_next_to timestamptz := nullif(p_filters ->> 'next_to', '')::timestamptz;
  v_next_before timestamptz := nullif(p_filters ->> 'next_before', '')::timestamptz;
  v_no_appt boolean := coalesce((p_filters ->> 'no_appointment')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false);
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách cơ hội.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang); nếu để mặc định Postgres quét cả bảng rồi sắp xếp (đo: 106 ms → 1 ms).
  with f as not materialized (
    select o.*
      from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (v_merged or o.record_status = 'DANG_DUNG')
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or o.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or o.substage_code = any (v_substage))
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
       and (v_next_from is null or o.next_appointment_at >= v_next_from)
       and (v_next_to is null or o.next_appointment_at < v_next_to)
       and (v_next_before is null or o.next_appointment_at < v_next_before)
       and (not v_no_appt or o.next_appointment_at is null)
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'next_appointment_asc' then f.next_appointment_at end asc nulls last,
              case when p_sort = 'name_asc' then f.student_name end asc nulls last,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'lead_id', p.lead_id, 'lead_code', l.code,
             'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
             'student_name', p.student_name, 'student_birth_year', p.student_birth_year,
             'stage_code', p.stage_code, 'substage_code', p.substage_code,
             'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'supporter_id', p.supporter_id, 'branch_code', b.code,
             'next_appointment_at', p.next_appointment_at, 'created_at', p.created_at,
             'record_status', p.record_status, 'merged_into_code', m.code)
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'next_appointment_asc' then p.next_appointment_at end asc nulls last,
                      case when p_sort = 'name_asc' then p.student_name end asc nulls last,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent par on par.id = p.parent_id
    join app.lead l on l.id = p.lead_id
    left join app.opportunity m on m.id = p.merged_into_id;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Kanban Cơ hội (TS-07 K2): một lần gọi trả mọi cột L1–L8: tổng số của cột và N thẻ mới nhất (N mặc định theo tham số
-- kanban_cards_per_column, tối đa list_page_size_max). Bộ lọc như list_opportunities (bỏ stage, substage).
-- Phạm vi quyền giống list_opportunities.
-- ---------------------------------------------------------------------------
create or replace function app.opportunity_board(p_filters jsonb default '{}'::jsonb, p_per_column integer default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('OPPORTUNITY', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_per integer := least(greatest(coalesce(p_per_column, app.get_setting_int('kanban_cards_per_column')), 1),
                         app.get_setting_int('list_page_size_max'));
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_support_mine boolean := coalesce((p_filters ->> 'supporter_mine')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_next_from timestamptz := nullif(p_filters ->> 'next_from', '')::timestamptz;
  v_next_to timestamptz := nullif(p_filters ->> 'next_to', '')::timestamptz;
  v_next_before timestamptz := nullif(p_filters ->> 'next_before', '')::timestamptz;
  v_no_appt boolean := coalesce((p_filters ->> 'no_appointment')::boolean, false);
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem cơ hội.');
  end if;
  with f as not materialized (
    select o.*
      from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and o.record_status = 'DANG_DUNG'
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
       and (v_next_from is null or o.next_appointment_at >= v_next_from)
       and (v_next_to is null or o.next_appointment_at < v_next_to)
       and (v_next_before is null or o.next_appointment_at < v_next_before)
       and (not v_no_appt or o.next_appointment_at is null)
  ),
  counts as (select stage_code, count(*) as n from f group by stage_code)
  select coalesce(jsonb_agg(jsonb_build_object(
           'stage_code', s.code, 'name', s.name, 'total', coalesce(c.n, 0), 'rows', cards.rows) order by s.sort_order),
           '[]'::jsonb)
    into v_result
    from app.catalog_item s
    left join counts c on c.stage_code = s.code
    cross join lateral (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', t.id, 'code', t.code, 'parent_name', par.full_name, 'student_name', t.student_name,
               'substage_code', t.substage_code, 'owner_id', t.owner_id, 'owner_name', app.staff_display_name(t.owner_id),
               'branch_code', b.code, 'next_appointment_at', t.next_appointment_at, 'created_at', t.created_at)
               order by t.created_at desc, t.id), '[]'::jsonb) as rows
        from (select * from f where f.stage_code = s.code order by f.created_at desc, f.id limit v_per) t
        join app.parent par on par.id = t.parent_id
        join app.branch b on b.id = t.branch_id
    ) cards
   where s.catalog_code = 'OPP_STAGE' and s.is_active;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Sửa hiệu năng list_leads (phát hiện khi đo cơ hội trên 50.000 lead): CTE f dùng hai lần nên bị Postgres cho "materialized":
-- quét cả bảng, sắp xếp rồi mới lấy 50 dòng (50 đến 100 ms). Thêm "not materialized" để quét chỉ mục rồi dừng. Nội dung hàm giữ nguyên.
-- ---------------------------------------------------------------------------
create or replace function app.list_leads(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'created_desc',
  p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('LEAD', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_support_mine boolean := coalesce((p_filters ->> 'supporter_mine')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'created_from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'created_to', '')::timestamptz;
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false);
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách lead.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang); mặc định Postgres quét cả bảng rồi sắp xếp.
  with f as not materialized (
    select l.*
      from app.lead l
     where (v_scope = 'TOAN_HE_THONG' or l.branch_id = v_my_branch)
       and (v_merged or l.record_status = 'DANG_DUNG')
       and (v_q is null or l.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or l.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or l.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or l.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or l.source_code = any (v_source))
       and (v_branch is null or l.branch_id = v_branch)
       and (v_owner is null or l.owner_id = v_owner)
       and (not v_mine or l.owner_id = auth.uid())
       and (not v_support_mine or l.supporter_id = auth.uid())
       and (v_from is null or l.created_at >= v_from)
       and (v_to is null or l.created_at < v_to)
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'next_appointment_asc' then f.next_appointment_at end asc nulls last,
              case when p_sort = 'name_asc' then f.parent_name end asc,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'parent_name', p.parent_name, 'parent_phone', p.parent_phone,
             'student_name', p.student_name, 'stage_code', p.stage_code, 'substage_code', p.substage_code,
             'source_type_code', p.source_type_code, 'source_code', p.source_code, 'channel_code', p.channel_code,
             'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'supporter_id', p.supporter_id, 'branch_code', b.code,
             'next_appointment_at', p.next_appointment_at, 'created_at', p.created_at,
             'record_status', p.record_status, 'merged_into_code', m.code)
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'next_appointment_asc' then p.next_appointment_at end asc nulls last,
                      case when p_sort = 'name_asc' then p.parent_name end asc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    left join app.lead m on m.id = p.merged_into_id;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Quyền gọi: chỉ người đã đăng nhập; mỗi hàm tự kiểm quyền bên trong. Hàm nội bộ không cấp cho giao diện.
-- ---------------------------------------------------------------------------
revoke execute on function
  app.normalize_person_name(text), app.opportunity_search_text(app.opportunity),
  app.find_or_create_parent(text, text, text, text, text, uuid),
  app.find_or_create_student(uuid, text, integer, date, text, text, text, uuid),
  app.opportunity_test_state(uuid), app.opportunity_l5_substage(uuid),
  app.refresh_opportunity_next_appointment(uuid)
  from public, anon, authenticated;
revoke execute on function
  app.create_opportunity(uuid, jsonb, boolean), app.update_opportunity(uuid, jsonb),
  app.change_opportunity_stage(uuid, text, text, text, text, boolean),
  app.create_appointment(uuid, text, timestamptz, text, text, uuid, uuid),
  app.list_opportunities(jsonb, text, integer, integer), app.opportunity_board(jsonb, integer)
  from public, anon;
grant execute on function
  app.create_opportunity(uuid, jsonb, boolean), app.update_opportunity(uuid, jsonb),
  app.change_opportunity_stage(uuid, text, text, text, text, boolean),
  app.create_appointment(uuid, text, timestamptz, text, text, uuid, uuid),
  app.list_opportunities(jsonb, text, integer, integer), app.opportunity_board(jsonb, integer)
  to authenticated;
grant execute on function app.normalize_person_name(text) to authenticated;

select set_config('hmt.migration', '', false);
