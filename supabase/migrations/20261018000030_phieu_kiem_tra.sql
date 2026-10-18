-- P3b2b: Phiếu kiểm tra đầu vào (docs/spec/04 R-CRM-05, 06, 10, 11, 12, 13, 14, 15, 21, 27; TS-15, 16, 17).
-- Gồm: bảng phiếu, lịch hẹn gắn được phiếu (kèm lịch hẹn nhắc tự sinh), hàm tạo / đổi lịch / sửa / bắt đầu / nộp bài /
-- nhập kết quả / hoàn thành / lùi bước / huỷ / mở lại, hàm danh sách và Kanban, thay hai điểm nối của P3b2a
-- (app.opportunity_test_state, app.opportunity_l5_substage) bằng truy vấn thật, tự lên L6 khi phiếu hoàn thành.
-- Hiệu năng (CLAUDE.md): mỗi chỉ mục ghi lý do; RLS dùng (select ...); danh sách phân trang ở máy chủ.

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Phiếu kiểm tra. Học sinh gắn lúc tạo (tìm hoặc tạo hồ sơ học sinh theo R-CRM-27). `branch_id` là cơ sở của cơ hội
-- (chép lúc tạo, dùng cho RLS); `test_branch_id` là cơ sở test (xếp lịch, lọc); `created_branch_id` tự ghi, chỉ đọc.
-- ---------------------------------------------------------------------------
create table app.student_test (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  opportunity_id uuid not null references app.opportunity (id),
  student_id uuid not null references app.student (id),
  branch_id uuid not null references app.branch (id),
  test_branch_id uuid not null references app.branch (id),
  created_branch_id uuid not null references app.branch (id),
  subject_catalog text not null default 'SUBJECT' check (subject_catalog = 'SUBJECT'),
  subject_code text not null,
  grade_catalog text not null default 'GRADE' check (grade_catalog = 'GRADE'),
  grade_code text not null,
  mode_catalog text not null default 'TEST_MODE' check (mode_catalog = 'TEST_MODE'),
  mode_code text not null,
  level_catalog text not null default 'TEST_LEVEL' check (level_catalog = 'TEST_LEVEL'),
  level_code text not null,
  exam_name text,
  scheduled_at timestamptz not null,
  room_id uuid references app.room (id),
  grader_id uuid references app.user_account (id),
  owner_id uuid not null references app.user_account (id),
  -- Trạng thái (danh mục TEST_STATUS): Nháp, Đang test, Chờ giáo viên chấm, Hoàn thành, Đã huỷ.
  status_catalog text not null default 'TEST_STATUS' check (status_catalog = 'TEST_STATUS'),
  status_code text not null default 'DRAFT'
    check (status_code in ('DRAFT', 'TESTING', 'TEACHER_REVIEW', 'COMPLETED', 'CANCELLED')),
  -- Lý do của lần đưa về Nháp, mở lại gần nhất (R-CRM-10, 21); các lần trước nằm trong nhật ký.
  status_reason text,
  cancel_reason_catalog text not null default 'TEST_CANCEL_REASON' check (cancel_reason_catalog = 'TEST_CANCEL_REASON'),
  cancel_reason_code text,
  cancel_note text,
  cancelled_at timestamptz,
  cancelled_by uuid,
  completed_at timestamptz,
  completed_by uuid,
  -- Kết quả (R-CRM-10): điểm 0–10 một chữ số thập phân, nhận xét, trình độ đề xuất S/A/B/C, phân loại đề xuất CB/NC.
  score numeric(3, 1) check (score is null or (score >= 0 and score <= 10)), -- allow-number: thang điểm 0–10 của R-CRM-10
  result_note text,
  suggested_level_catalog text not null default 'LEVEL' check (suggested_level_catalog = 'LEVEL'),
  suggested_level_code text,
  suggested_framework_catalog text not null default 'FRAMEWORK_LEVEL' check (suggested_framework_catalog = 'FRAMEWORK_LEVEL'),
  suggested_framework_code text,
  -- Người nhập kết quả và cờ "nhập thay" (R-CRM-11): người nhập không phải giáo viên chấm.
  result_entered_by uuid references app.user_account (id),
  result_entered_at timestamptz,
  result_on_behalf boolean,
  legacy_ref text,
  search_text text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  check ((status_code = 'CANCELLED') = (cancel_reason_code is not null)),
  foreign key (subject_catalog, subject_code) references app.catalog_item (catalog_code, code),
  foreign key (grade_catalog, grade_code) references app.catalog_item (catalog_code, code),
  foreign key (mode_catalog, mode_code) references app.catalog_item (catalog_code, code),
  foreign key (level_catalog, level_code) references app.catalog_item (catalog_code, code),
  foreign key (status_catalog, status_code) references app.catalog_item (catalog_code, code),
  foreign key (cancel_reason_catalog, cancel_reason_code) references app.catalog_item (catalog_code, code),
  foreign key (suggested_level_catalog, suggested_level_code) references app.catalog_item (catalog_code, code),
  foreign key (suggested_framework_catalog, suggested_framework_code) references app.catalog_item (catalog_code, code)
);
comment on table app.student_test is 'Phiếu kiểm tra đầu vào. Mã PKT cấp lúc Lưu (R-CRM-19). Một cơ hội có nhiều phiếu (R-CRM-05).';

-- Chỉ mục (lý do ghi từng dòng):
-- Khoá ngoại và tab "Kiểm tra đầu vào" của cơ hội; hàm tính trạng thái phiếu của cơ hội (R-CRM-12, 14, 15).
create index student_test_opportunity_idx on app.student_test (opportunity_id, status_code);
-- Khoá ngoại và smart button học sinh → phiếu.
create index student_test_student_idx on app.student_test (student_id);
-- RLS (người một cơ sở), danh sách và Kanban theo trạng thái, xếp theo giờ test.
create index student_test_branch_status_idx on app.student_test (branch_id, status_code, scheduled_at);
-- Như trên cho người thấy mọi cơ sở; Calendar tuần (khoảng giờ test).
create index student_test_status_time_idx on app.student_test (status_code, scheduled_at);
create index student_test_time_idx on app.student_test (scheduled_at);
-- Calendar "Ngày" (cột = phòng) và lọc theo cơ sở test.
create index student_test_room_time_idx on app.student_test (test_branch_id, room_id, scheduled_at);
-- Chip "Tôi phụ trách" và phạm vi được phân công (người phụ trách).
create index student_test_owner_idx on app.student_test (owner_id, scheduled_at);
-- Chip "Tôi chấm bài" và phạm vi được phân công (giáo viên chấm).
create index student_test_grader_idx on app.student_test (grader_id, scheduled_at) where grader_id is not null;
-- Chip "Tôi tạo".
create index student_test_created_by_idx on app.student_test (created_by, scheduled_at);
-- Khoá ngoại.
create index student_test_room_idx on app.student_test (room_id) where room_id is not null;
-- Ô tìm kiếm (mã, tên học sinh, tên phụ huynh, SĐT, tên đề).
create index student_test_search_idx on app.student_test using gin (search_text extensions.gin_trgm_ops);
select app.apply_standard('app.student_test');

-- Ô tìm kiếm của phiếu: mã, tên học sinh, tên và SĐT phụ huynh, tên đề, mã cũ; đã gấp chữ.
create or replace function app.student_test_search_text(p_test app.student_test)
returns text
language sql
stable
set search_path = ''
as $$
  select app.fold_text(p_test.code || ' ' || coalesce((select s.full_name || ' ' || pa.full_name || ' ' || pa.phone
                                                          from app.student s join app.parent pa on pa.id = s.parent_id
                                                         where s.id = p_test.student_id), '')
                       || ' ' || coalesce(p_test.exam_name, '') || ' ' || coalesce(p_test.legacy_ref, ''));
$$;
create or replace function app.tg_student_test_search_text()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.search_text := app.student_test_search_text(new);
  return new;
end;
$$;
create trigger student_test_search_text before insert or update on app.student_test
  for each row execute function app.tg_student_test_search_text();

-- Phụ huynh hoặc học sinh đổi tên, SĐT thì ô tìm kiếm của phiếu đổi theo (cơ hội đã làm cho phụ huynh ở P3b2a).
create or replace function app.tg_parent_refresh_opportunity_search()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.full_name is distinct from old.full_name or new.phone is distinct from old.phone then
    update app.opportunity o set search_text = app.opportunity_search_text(o) where o.parent_id = new.id;
    update app.student_test t set search_text = app.student_test_search_text(t)
     where t.student_id in (select s.id from app.student s where s.parent_id = new.id);
  end if;
  return null;
end;
$$;
create or replace function app.tg_student_refresh_test_search()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.full_name is distinct from old.full_name then
    update app.student_test t set search_text = app.student_test_search_text(t) where t.student_id = new.id;
  end if;
  return null;
end;
$$;
create trigger student_refresh_test_search after update on app.student
  for each row execute function app.tg_student_refresh_test_search();

-- Nhất quán của phiếu: phòng thuộc cơ sở test, cơ sở test là cơ sở dạy học (R-HT-02).
create or replace function app.tg_student_test_checks()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (select from app.branch where id = new.test_branch_id and not is_office) then
    perform app.raise_error('HMT_CO_SO_VAN_PHONG', 'Cơ sở test phải là cơ sở dạy học, không phải Hội sở.');
  end if;
  if new.room_id is not null and not exists (
       select from app.room where id = new.room_id and branch_id = new.test_branch_id and is_active) then
    perform app.raise_error('HMT_PHONG_SAI', 'Phòng phải đang hoạt động và thuộc cơ sở test.');
  end if;
  return new;
end;
$$;
create trigger student_test_checks before insert or update on app.student_test
  for each row execute function app.tg_student_test_checks();

-- ---------------------------------------------------------------------------
-- Lịch hẹn gắn được phiếu (R-CRM-04: đúng một hồ sơ trong lead, cơ hội, phiếu). Lịch hẹn nhắc tự sinh cùng phiếu:
-- is_auto_reminder đánh dấu, auto_scheduled_at là giờ hệ thống tính; giờ hẹn khác giờ này nghĩa là đã sửa tay (không ghi đè).
-- ---------------------------------------------------------------------------
alter table app.appointment add column student_test_id uuid references app.student_test (id);
alter table app.appointment add column is_auto_reminder boolean not null default false;
alter table app.appointment add column auto_scheduled_at timestamptz;
alter table app.appointment drop constraint appointment_one_parent;
alter table app.appointment add constraint appointment_one_parent
  check (num_nonnulls(lead_id, opportunity_id, student_test_id) = 1);
-- Khoá ngoại: lịch hẹn của một phiếu (smart button, tìm lịch nhắc để đổi giờ).
create index appointment_student_test_idx on app.appointment (student_test_id, scheduled_at) where student_test_id is not null;

-- ---------------------------------------------------------------------------
-- RLS: đọc theo ma trận quyền. Phạm vi toàn hệ thống, đúng cơ sở của cơ hội, hoặc "được phân công" (giáo viên chấm hoặc
-- người phụ trách phiếu). Ghi chỉ qua hàm nghiệp vụ.
-- ---------------------------------------------------------------------------
alter table app.student_test enable row level security;
revoke all on app.student_test from public, anon, authenticated;
grant select on app.student_test to authenticated;
create policy student_test_read on app.student_test for select to authenticated
  using ((select app.permission_scope('STUDENT_TEST', 'XEM')) = 'TOAN_HE_THONG'
         or ((select app.permission_scope('STUDENT_TEST', 'XEM')) = 'CO_SO'
             and branch_id = (select app.current_branch_id()))
         or ((select app.permission_scope('STUDENT_TEST', 'XEM')) = 'DUOC_PHAN_CONG'
             and (grader_id = (select auth.uid()) or owner_id = (select auth.uid()))));

-- Ghi chú, lịch sử gắn vào phiếu; cột kỹ thuật ẩn khỏi lịch sử.
insert into app.note_target (entity_type, table_name, name) values ('STUDENT_TEST', 'app.student_test', 'Phiếu kiểm tra');
insert into app.history_hidden_column (table_name, column_name) values ('app.student_test', 'search_text');

-- ---------------------------------------------------------------------------
-- Quyền theo phạm vi của một phiếu: toàn hệ thống; đúng cơ sở của cơ hội; hoặc được phân công (giáo viên chấm, người phụ trách).
-- Làm đúng cả phạm vi "được phân công" (ghi chú P3b1: can_see_branch coi mọi phạm vi khác là cùng cơ sở).
-- ---------------------------------------------------------------------------
create or replace function app.test_scope_ok(p_action text, p_test app.student_test)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('STUDENT_TEST', p_action);
begin
  if v_scope is null then
    return false;
  end if;
  if v_scope = 'TOAN_HE_THONG' then
    return true;
  end if;
  if v_scope = 'CO_SO' then
    return p_test.branch_id is not distinct from app.current_branch_id();
  end if;
  if v_scope = 'DUOC_PHAN_CONG' then
    -- coalesce: giáo viên chấm có thể chưa chọn (null), so với null cho ra null chứ không phải false.
    return auth.uid() is not null
       and (coalesce(p_test.grader_id = auth.uid(), false) or coalesce(p_test.owner_id = auth.uid(), false));
  end if;
  return false;
end;
$$;

create or replace function app.assert_test_access(p_action text, p_test app.student_test)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app.test_scope_ok(p_action, p_test) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền thực hiện thao tác này với phiếu kiểm tra này.');
  end if;
end;
$$;

-- Thêm vào app.can_see_note_target: phiếu xét theo quyền Kiểm tra đầu vào · Xem. Phần còn lại giữ nguyên (như P3b2a).
create or replace function app.can_see_note_target(p_entity_type text, p_entity_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
  v_test app.student_test;
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
  if p_entity_type = 'OPPORTUNITY' then
    select branch_id into v_branch_id from app.opportunity where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('OPPORTUNITY', 'XEM', v_branch_id);
  end if;
  -- Luật: phiếu theo quyền Kiểm tra đầu vào · Xem và phạm vi của phiếu (cơ sở, hoặc được phân công).
  if p_entity_type = 'STUDENT_TEST' then
    select * into v_test from app.student_test where id = p_entity_id;
    return v_test.id is not null and app.test_scope_ok('XEM', v_test);
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

-- ===========================================================================
-- HÀM NGHIỆP VỤ
-- ===========================================================================

-- Giáo viên chấm phải là nhân sự vai trò Giáo viên, đang hoạt động, ở cơ sở nào cũng được (anh chốt 16/10).
create or replace function app.assert_grader(p_user_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (select from app.user_account u join app.user_role r on r.user_id = u.id and r.is_active
                  where u.id = p_user_id and not u.is_locked and r.role_code = 'TEACHER') then
    perform app.raise_error('HMT_GIAO_VIEN_CHAM_SAI', 'Giáo viên chấm phải là giáo viên đang hoạt động.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Thay hai điểm nối của P3b2a bằng truy vấn bảng phiếu thật.
-- opportunity_test_state: số phiếu dang dở (Nháp, Đang test, Chờ giáo viên chấm), Hoàn thành, Huỷ của cơ hội và mã các phiếu
--   dang dở (R-CRM-12, 14).
-- opportunity_l5_substage: nhóm con L5 theo các phiếu của cơ hội (R-CRM-15), xét theo thứ tự ưu tiên: (1) còn phiếu Chờ giáo viên
--   chấm → L5P; (2) còn phiếu Nháp hoặc Đang test → L5B; (3) mọi phiếu đều Huỷ → nhóm con nối với lý do huỷ của phiếu huỷ gần nhất,
--   bỏ qua phiếu huỷ vì "Tạo phiếu sai"; (4) không còn phiếu nào tính được → L5A. Phiếu Hoàn thành theo R-CRM-13 (lên L6).
-- ---------------------------------------------------------------------------
create or replace function app.opportunity_test_state(p_opportunity_id uuid)
returns table (in_progress integer, completed integer, cancelled integer, in_progress_codes text[])
language sql
stable
security definer
set search_path = ''
as $$
  select count(*) filter (where t.status_code in ('DRAFT', 'TESTING', 'TEACHER_REVIEW'))::integer,
         count(*) filter (where t.status_code = 'COMPLETED')::integer,
         count(*) filter (where t.status_code = 'CANCELLED')::integer,
         coalesce(array_agg(t.code order by t.code) filter (where t.status_code in ('DRAFT', 'TESTING', 'TEACHER_REVIEW')),
                  array[]::text[])
    from app.student_test t
   where t.opportunity_id = p_opportunity_id;
$$;

create or replace function app.opportunity_l5_substage(p_opportunity_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    -- Luật R-CRM-15 (1): còn phiếu Chờ giáo viên chấm.
    when exists (select from app.student_test where opportunity_id = p_opportunity_id and status_code = 'TEACHER_REVIEW') then 'L5P'
    -- Luật R-CRM-15 (2): còn phiếu Nháp hoặc Đang test.
    when exists (select from app.student_test where opportunity_id = p_opportunity_id
                  and status_code in ('DRAFT', 'TESTING')) then 'L5B'
    -- Luật R-CRM-15 (3): mọi phiếu đều Huỷ (trừ phiếu "Tạo phiếu sai"): nhóm con nối với lý do của phiếu huỷ gần nhất.
    -- Luật R-CRM-15 (4): không có phiếu nào tính được thì L5A.
    else coalesce((
      select i.code
        from app.student_test t
        join app.catalog_item r on r.catalog_code = 'TEST_CANCEL_REASON' and r.code = t.cancel_reason_code
        join app.catalog_item i on i.id = r.linked_item_id
       where t.opportunity_id = p_opportunity_id and t.status_code = 'CANCELLED' and t.cancel_reason_code <> 'TAO_PHIEU_SAI'
         and not exists (select from app.student_test x where x.opportunity_id = p_opportunity_id and x.status_code <> 'CANCELLED')
       order by t.cancelled_at desc, t.id
       limit 1), 'L5A')
  end;
$$;

-- Tính lại nhóm con L5 sau mỗi lần phiếu đổi, chỉ khi cơ hội đang ở L5 (R-CRM-15). Hàm nội bộ, cùng giao dịch với phiếu.
create or replace function app.refresh_opportunity_l5_substage(p_opportunity_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new text;
begin
  v_new := app.opportunity_l5_substage(p_opportunity_id);
  update app.opportunity set substage_code = v_new
   where id = p_opportunity_id and stage_code = 'L5' and substage_code is distinct from v_new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Giờ nhắc của lịch hẹn nhắc phiếu (TS-15), theo ba tham số Cài đặt (không viết cứng):
--   test_reminder_time_minutes: giờ nhắc mặc định tính bằng phút kể từ 0 giờ của ngày hôm trước (1020 = 17:00);
--   test_reminder_short_window_hours / test_reminder_short_lead_hours: test bắt đầu trong khoảng này kể từ lúc tạo thì nhắc
--   trước giờ test bấy nhiêu giờ. Giờ nhắc luôn trước giờ test; tính ra đã qua thì nhắc ngay (anh chốt 18/10).
-- ---------------------------------------------------------------------------
create or replace function app.test_reminder_time(p_test_at timestamptz, p_now timestamptz default now())
returns timestamptz
language plpgsql
stable
set search_path = ''
as $$
declare
  v_minutes integer := app.get_setting_int('test_reminder_time_minutes');
  v_window integer := app.get_setting_int('test_reminder_short_window_hours');
  v_lead integer := app.get_setting_int('test_reminder_short_lead_hours');
  v_at timestamptz;
begin
  if p_test_at - p_now <= make_interval(hours => v_window) then
    v_at := p_test_at - make_interval(hours => v_lead);
  else
    v_at := (((p_test_at at time zone 'Asia/Ho_Chi_Minh')::date - 1)::timestamp + make_interval(mins => v_minutes))
            at time zone 'Asia/Ho_Chi_Minh';
  end if;
  return least(greatest(v_at, p_now), p_test_at - interval '1 minute'); -- allow-number: giờ nhắc kém giờ test ít nhất một phút
end;
$$;

-- Bảo đảm phiếu có lịch hẹn nhắc (Gọi điện mặc định, người phụ trách phiếu): tạo mới; đổi giờ nếu chưa ai sửa tay hoặc người
-- dùng chỉ định giờ; mở lại lịch nhắc đã huỷ tự động. Sửa tay (giờ khác auto_scheduled_at) thì không bị ghi đè.
create or replace function app.ensure_test_reminder(p_test_id uuid, p_at timestamptz default null, p_activity text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test;
  v_auto timestamptz;
  v_at timestamptz;
  v_appt app.appointment;
begin
  select * into v_test from app.student_test where id = p_test_id;
  v_auto := app.test_reminder_time(v_test.scheduled_at);
  v_at := coalesce(p_at, v_auto);
  -- Luật TS-15: giờ nhắc phải trước giờ test.
  if v_at >= v_test.scheduled_at then
    perform app.raise_error('HMT_GIO_NHAC_SAI', 'Giờ nhắc phải trước giờ test.');
  end if;
  if p_activity is not null then
    perform app.assert_catalog_code_active('ACTIVITY_TYPE', p_activity);
  end if;
  select * into v_appt from app.appointment where student_test_id = p_test_id and is_auto_reminder
   order by created_at desc limit 1;
  if v_appt.id is null then
    insert into app.appointment (student_test_id, is_auto_reminder, auto_scheduled_at, activity_code, scheduled_at, title,
                                 owner_id, branch_id)
    values (p_test_id, true, v_auto, coalesce(p_activity, 'GOI_DIEN'), v_at, 'Nhắc phiếu kiểm tra ' || v_test.code,
            v_test.owner_id, v_test.branch_id);
  elsif v_appt.status = 'HUY' then
    update app.appointment
       set status = 'CHUA_LAM', cancel_reason_code = null, cancel_note = null, cancelled_at = null, cancelled_by = null,
           scheduled_at = v_at, auto_scheduled_at = v_auto, owner_id = v_test.owner_id
     where id = v_appt.id;
  elsif v_appt.status = 'CHUA_LAM' then
    update app.appointment
       set scheduled_at = case when p_at is not null or scheduled_at is not distinct from auto_scheduled_at
                               then v_at else scheduled_at end,
           auto_scheduled_at = v_auto, owner_id = v_test.owner_id
     where id = v_appt.id;
  end if;
end;
$$;

-- Huỷ lịch hẹn nhắc tự sinh khi phiếu bị huỷ (không tạo việc, không gửi thông báo: R-CRM-04). Hàm nội bộ.
create or replace function app.cancel_test_reminder(p_test_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update app.appointment
     set status = 'HUY', cancel_reason_code = 'KHAC', cancel_note = 'Phiếu kiểm tra đã huỷ',
         cancelled_at = now(), cancelled_by = auth.uid()
   where student_test_id = p_test_id and is_auto_reminder and status = 'CHUA_LAM';
$$;

-- Đọc và khoá một phiếu, kiểm quyền theo phạm vi của phiếu (dùng chung cho các hàm đổi phiếu dưới đây).
create or replace function app.test_for_update(p_id uuid, p_action text)
returns app.student_test
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test;
begin
  select * into v_test from app.student_test where id = p_id for update;
  if v_test.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu kiểm tra.');
  end if;
  perform app.assert_test_access(p_action, v_test);
  return v_test;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tạo phiếu kiểm tra từ cơ hội (TS-15). R-CRM-19: mã PKT cấp lúc Lưu.
-- Ai gọi: người có quyền Kiểm tra đầu vào · Tạo ở cơ sở của cơ hội; giao người phụ trách khác mình cần Giao việc.
-- Đầu vào: p_opportunity_id; p_data (subject_code, grade_code, mode_code, level_code, scheduled_at bắt buộc; exam_name,
--   test_branch_id (mặc định cơ sở người tạo), owner_id (mặc định người tạo), room_id, grader_id: không bắt buộc);
--   p_reminder_at: giờ lịch hẹn nhắc do người dùng chọn (mặc định theo tham số), p_reminder_activity (mặc định Gọi điện).
-- Kết quả: {id, code, student_id, student_code}.
-- Luật: R-CRM-05 (cơ hội từ L5 trở đi, ngày giờ test bắt buộc và ở tương lai, nhiều phiếu một cơ hội, tự sinh lịch hẹn nhắc;
--   phiếu tạo khi cơ hội ở L6 trở đi không đổi giai đoạn); R-CRM-27 (tìm hoặc tạo hồ sơ học sinh theo phụ huynh + tên +
--   năm sinh, gắn vào cơ hội); R-CRM-15 (tính lại nhóm con L5).
-- ---------------------------------------------------------------------------
create or replace function app.create_student_test(
  p_opportunity_id uuid, p_data jsonb, p_reminder_at timestamptz default null, p_reminder_activity text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_opp app.opportunity;
  v_stage_order integer;
  v_l5_order integer;
  v_scheduled timestamptz := nullif(p_data ->> 'scheduled_at', '')::timestamptz;
  v_subject text := nullif(p_data ->> 'subject_code', '');
  v_grade text := nullif(p_data ->> 'grade_code', '');
  v_mode text := nullif(p_data ->> 'mode_code', '');
  v_level text := nullif(p_data ->> 'level_code', '');
  v_owner uuid;
  v_test_branch uuid;
  v_room uuid := nullif(p_data ->> 'room_id', '')::uuid;
  v_grader uuid := nullif(p_data ->> 'grader_id', '')::uuid;
  v_student_id uuid;
  v_student_code text;
  v_id uuid;
  v_code text;
begin
  select * into v_opp from app.opportunity where id = p_opportunity_id for update;
  if v_opp.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
  end if;
  perform app.assert_can('STUDENT_TEST', 'TAO', v_opp.branch_id);
  if v_opp.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Cơ hội này đã gộp vào bản khác, không tạo phiếu được.');
  end if;

  -- Luật R-CRM-05: chỉ tạo khi cơ hội đang ở L5 trở đi (chặn trong hàm; nút mờ ở giao diện chỉ là gợi ý).
  select sort_order into v_stage_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = v_opp.stage_code;
  select sort_order into v_l5_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5';
  if v_stage_order < v_l5_order then
    perform app.raise_error('HMT_CO_HOI_CHUA_DEN_L5', 'Chỉ tạo phiếu kiểm tra khi cơ hội đang ở L5 trở đi. Chuyển cơ hội sang L5 trước.');
  end if;

  -- Luật R-CRM-05: ngày giờ test bắt buộc và ở tương lai (anh chốt 18/10).
  if v_scheduled is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ngày và giờ test.');
  end if;
  if v_scheduled <= now() then
    perform app.raise_error('HMT_GIO_TEST_QUA_KHU', 'Giờ test phải ở tương lai.');
  end if;
  -- Luật: môn, khối, hình thức, cấp độ đề bắt buộc, lấy từ danh mục đang dùng (R-CRM-10).
  if v_subject is null or v_grade is null or v_mode is null or v_level is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn đủ môn, khối, hình thức test và cấp độ đề.');
  end if;
  perform app.assert_catalog_code_active('SUBJECT', v_subject);
  perform app.assert_catalog_code_active('GRADE', v_grade);
  perform app.assert_catalog_code_active('TEST_MODE', v_mode);
  perform app.assert_catalog_code_active('TEST_LEVEL', v_level);

  -- Luật: người phụ trách mặc định là người tạo; giao cho người khác cần quyền Giao việc.
  v_owner := coalesce(nullif(p_data ->> 'owner_id', '')::uuid, auth.uid());
  if v_owner <> auth.uid() then
    perform app.assert_can('STUDENT_TEST', 'GIAO_VIEC', v_opp.branch_id);
    perform app.assert_staff_in_branch(v_owner, v_opp.branch_id);
  end if;
  v_test_branch := coalesce(nullif(p_data ->> 'test_branch_id', '')::uuid, app.current_branch_id(), v_opp.branch_id);
  if v_grader is not null then
    perform app.assert_grader(v_grader);
  end if;

  -- Luật R-CRM-27: tìm hoặc tạo hồ sơ học sinh (phụ huynh + tên chuẩn hoá + năm sinh), gắn vào cơ hội.
  v_student_id := v_opp.student_id;
  if v_student_id is null then
    v_student_id := app.find_or_create_student(v_opp.parent_id, v_opp.student_name, v_opp.student_birth_year,
                                               v_opp.student_birth_date, v_opp.school, v_opp.self_rating, v_opp.goal,
                                               v_opp.branch_id);
    update app.opportunity set student_id = v_student_id where id = v_opp.id;
  end if;
  select code into v_student_code from app.student where id = v_student_id;

  v_code := app.issue_crm_code('PKT');
  insert into app.student_test (
    code, opportunity_id, student_id, branch_id, test_branch_id, created_branch_id, subject_code, grade_code, mode_code,
    level_code, exam_name, scheduled_at, room_id, grader_id, owner_id)
  values (
    v_code, v_opp.id, v_student_id, v_opp.branch_id, v_test_branch, coalesce(app.current_branch_id(), v_opp.branch_id),
    v_subject, v_grade, v_mode, v_level, nullif(btrim(coalesce(p_data ->> 'exam_name', '')), ''), v_scheduled, v_room,
    v_grader, v_owner)
  returning id into v_id;

  -- Luật R-CRM-05: tự sinh lịch hẹn nhắc cùng phiếu.
  perform app.ensure_test_reminder(v_id, p_reminder_at, p_reminder_activity);
  -- Luật R-CRM-15: cơ hội đang ở L5 thì nhóm con tính lại (có phiếu Nháp → L5B).
  perform app.refresh_opportunity_l5_substage(v_opp.id);

  return jsonb_build_object('id', v_id, 'code', v_code, 'student_id', v_student_id, 'student_code', v_student_code);
end;
$$;

-- ---------------------------------------------------------------------------
-- Đổi lịch phiếu (TS-15 chế độ Đổi lịch): chỉ phiếu Nháp; giờ mới ở tương lai; lịch hẹn nhắc đổi theo nếu chưa ai sửa tay
-- (hoặc người dùng chỉ định giờ nhắc mới). Ai gọi: người có quyền Kiểm tra đầu vào · Sửa.
-- ---------------------------------------------------------------------------
create or replace function app.reschedule_student_test(p_id uuid, p_scheduled_at timestamptz, p_reminder_at timestamptz default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test := app.test_for_update(p_id, 'SUA');
begin
  if v_test.status_code <> 'DRAFT' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ đổi lịch được phiếu ở trạng thái Nháp.');
  end if;
  if p_scheduled_at is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn ngày và giờ test mới.');
  end if;
  if p_scheduled_at <= now() then
    perform app.raise_error('HMT_GIO_TEST_QUA_KHU', 'Giờ test phải ở tương lai.');
  end if;
  update app.student_test set scheduled_at = p_scheduled_at where id = p_id;
  perform app.ensure_test_reminder(p_id, p_reminder_at, null);
end;
$$;

-- ---------------------------------------------------------------------------
-- Sửa phiếu: người phụ trách, cơ sở test, phòng, giáo viên chấm, tên đề (TS-17). Phiếu đã huỷ chỉ đọc. Sau Hoàn thành vẫn sửa
-- được, mỗi lần sửa ghi lịch sử (nhật ký, R-CRM-21). Đổi người phụ trách sang người khác cần quyền Giao việc.
-- ---------------------------------------------------------------------------
create or replace function app.update_student_test(p_id uuid, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test := app.test_for_update(p_id, 'SUA');
  v_owner uuid := v_test.owner_id;
  v_branch uuid := v_test.test_branch_id;
  v_room uuid := v_test.room_id;
  v_grader uuid := v_test.grader_id;
  v_exam text := v_test.exam_name;
begin
  if v_test.status_code = 'CANCELLED' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Phiếu đã huỷ chỉ xem được. Mở lại phiếu trước nếu cần sửa.');
  end if;
  if p_data ? 'owner_id' then
    v_owner := (p_data ->> 'owner_id')::uuid;
    if v_owner is distinct from v_test.owner_id then
      perform app.assert_test_access('GIAO_VIEC', v_test);
      perform app.assert_staff_in_branch(v_owner, v_test.branch_id);
    end if;
  end if;
  if p_data ? 'test_branch_id' then
    v_branch := (p_data ->> 'test_branch_id')::uuid;
    -- Đổi cơ sở test thì phòng cũ không còn hợp lệ: bỏ phòng trừ khi chọn phòng mới cùng lúc.
    if v_branch is distinct from v_test.test_branch_id and not (p_data ? 'room_id') then
      v_room := null;
    end if;
  end if;
  if p_data ? 'room_id' then
    v_room := nullif(p_data ->> 'room_id', '')::uuid;
  end if;
  if p_data ? 'grader_id' then
    v_grader := nullif(p_data ->> 'grader_id', '')::uuid;
    if v_grader is not null then
      perform app.assert_grader(v_grader);
    end if;
  end if;
  if p_data ? 'exam_name' then
    v_exam := nullif(btrim(coalesce(p_data ->> 'exam_name', '')), '');
  end if;
  update app.student_test
     set owner_id = v_owner, test_branch_id = v_branch, room_id = v_room, grader_id = v_grader, exam_name = v_exam
   where id = p_id;
  -- Lịch hẹn nhắc chưa làm theo người phụ trách mới.
  if v_owner is distinct from v_test.owner_id then
    update app.appointment set owner_id = v_owner
     where student_test_id = p_id and is_auto_reminder and status = 'CHUA_LAM';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Bước trạng thái: Bắt đầu test (Nháp → Đang test), Nộp bài (Đang test → Chờ giáo viên chấm). Ai gọi: quyền Sửa phiếu.
-- Luật R-CRM-15: mỗi lần đổi tính lại nhóm con L5 của cơ hội (Chờ giáo viên chấm → L5P).
-- ---------------------------------------------------------------------------
create or replace function app.start_student_test(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test := app.test_for_update(p_id, 'SUA');
begin
  if v_test.status_code <> 'DRAFT' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ bắt đầu test được với phiếu ở trạng thái Nháp.');
  end if;
  update app.student_test set status_code = 'TESTING' where id = p_id;
  perform app.refresh_opportunity_l5_substage(v_test.opportunity_id);
end;
$$;

create or replace function app.submit_student_test(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test := app.test_for_update(p_id, 'SUA');
begin
  if v_test.status_code <> 'TESTING' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ nộp bài được với phiếu ở trạng thái Đang test.');
  end if;
  update app.student_test set status_code = 'TEACHER_REVIEW' where id = p_id;
  perform app.refresh_opportunity_l5_substage(v_test.opportunity_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Nhập kết quả (R-CRM-10, 11): điểm 0–10 một chữ số thập phân, nhận xét, trình độ đề xuất (S/A/B/C), phân loại (CB/NC).
-- Ai gọi: giáo viên chấm của phiếu, hoặc người có quyền Sửa phiếu nhập thay (ghi "nhập thay" và người nhập, R-CRM-11).
-- Chỉ khi phiếu ở Chờ giáo viên chấm hoặc Hoàn thành (sau Hoàn thành sửa được, có lịch sử). p_grader_id: chọn giáo viên chấm
-- cùng lúc (không truyền thì giữ nguyên).
-- ---------------------------------------------------------------------------
create or replace function app.enter_test_result(
  p_id uuid, p_score numeric, p_note text, p_level_code text default null, p_framework_code text default null,
  p_grader_id uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test := app.test_for_update(p_id, 'SUA');
  v_grader uuid := coalesce(p_grader_id, v_test.grader_id);
begin
  if v_test.status_code not in ('TEACHER_REVIEW', 'COMPLETED') then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ nhập kết quả khi phiếu ở trạng thái Chờ giáo viên chấm hoặc Hoàn thành.');
  end if;
  if p_score is not null and (p_score < 0 or p_score > 10 or p_score <> round(p_score, 1)) then -- allow-number: thang điểm 0–10, một chữ số thập phân (R-CRM-10)
    perform app.raise_error('HMT_DIEM_SAI', 'Điểm từ 0 đến 10, tối đa một chữ số thập phân.');
  end if;
  if p_grader_id is not null then
    perform app.assert_grader(p_grader_id);
  end if;
  if p_level_code is not null then
    perform app.assert_catalog_code_active('LEVEL', p_level_code);
  end if;
  if p_framework_code is not null then
    perform app.assert_catalog_code_active('FRAMEWORK_LEVEL', p_framework_code);
  end if;
  update app.student_test
     set score = p_score, result_note = nullif(btrim(coalesce(p_note, '')), ''), suggested_level_code = p_level_code,
         suggested_framework_code = p_framework_code, grader_id = v_grader,
         result_entered_by = auth.uid(), result_entered_at = now(),
         -- Luật R-CRM-11: người nhập không phải giáo viên chấm thì ghi "nhập thay".
         result_on_behalf = (v_grader is distinct from auth.uid())
   where id = p_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Hoàn thành phiếu (Chờ giáo viên chấm → Hoàn thành): cần giáo viên chấm, điểm, nhận xét (TS-17).
-- Luật R-CRM-13: cơ hội đang ở L5 trở xuống thì tự lên L6, nhóm con L6A; cơ hội đã ở L6 trở đi không đổi.
-- ---------------------------------------------------------------------------
create or replace function app.complete_student_test(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test := app.test_for_update(p_id, 'SUA');
  v_missing text[] := array[]::text[];
  v_opp app.opportunity;
  v_opp_order integer;
  v_l5_order integer;
begin
  if v_test.status_code <> 'TEACHER_REVIEW' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ hoàn thành được phiếu ở trạng thái Chờ giáo viên chấm.');
  end if;
  if v_test.grader_id is null then
    v_missing := array_append(v_missing, 'giáo viên chấm');
  end if;
  if v_test.score is null then
    v_missing := array_append(v_missing, 'điểm');
  end if;
  if btrim(coalesce(v_test.result_note, '')) = '' then
    v_missing := array_append(v_missing, 'nhận xét');
  end if;
  if cardinality(v_missing) > 0 then
    perform app.raise_error('HMT_THIEU_KET_QUA', format('Chưa hoàn thành được: phiếu còn thiếu %s.', array_to_string(v_missing, ', ')));
  end if;
  update app.student_test set status_code = 'COMPLETED', completed_at = now(), completed_by = auth.uid(), status_reason = null
   where id = p_id;

  -- Luật R-CRM-13: cơ hội từ L5 trở xuống tự lên L6A (chỉ hệ thống chuyển); từ L6 trở đi giữ nguyên (R-CRM-02).
  select * into v_opp from app.opportunity where id = v_test.opportunity_id for update;
  select sort_order into v_opp_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = v_opp.stage_code;
  select sort_order into v_l5_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5';
  if v_opp_order <= v_l5_order then
    update app.opportunity set stage_code = 'L6', substage_code = 'L6A' where id = v_opp.id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Lùi bước (R-CRM-21): Đang test → Nháp, Chờ giáo viên chấm → Đang test chỉ ghi lịch sử (nhật ký), không hỏi lý do;
-- Hoàn thành → Nháp bắt buộc lý do. Phiếu đưa về Nháp không kéo cơ hội lùi giai đoạn (R-CRM-02).
-- ---------------------------------------------------------------------------
create or replace function app.step_back_student_test(p_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test := app.test_for_update(p_id, 'SUA');
begin
  if v_test.status_code = 'TESTING' then
    update app.student_test set status_code = 'DRAFT' where id = p_id;
  elsif v_test.status_code = 'TEACHER_REVIEW' then
    update app.student_test set status_code = 'TESTING' where id = p_id;
  elsif v_test.status_code = 'COMPLETED' then
    -- Luật R-CRM-21: đưa phiếu Hoàn thành về Nháp bắt buộc nhập lý do.
    if btrim(coalesce(p_reason, '')) = '' then
      perform app.raise_error('HMT_THIEU_LY_DO', 'Đưa phiếu đã hoàn thành về Nháp phải nhập lý do.');
    end if;
    update app.student_test set status_code = 'DRAFT', status_reason = btrim(p_reason), completed_at = null, completed_by = null
     where id = p_id;
  else
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Phiếu ở trạng thái này không lùi được.');
  end if;
  perform app.refresh_opportunity_l5_substage(v_test.opportunity_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Huỷ phiếu (R-CRM-06): bắt buộc lý do danh mục 13 ("Khác" bắt ghi chú); ai có quyền Huỷ cũng huỷ được, kể cả khi học sinh đã
-- làm bài. Phiếu đã Hoàn thành phải đưa về Nháp (có lý do) trước (anh chốt 18/10). Lịch hẹn nhắc tự sinh được huỷ theo.
-- Luật R-CRM-15: tính lại nhóm con L5 theo lý do huỷ.
-- ---------------------------------------------------------------------------
create or replace function app.cancel_student_test(p_id uuid, p_reason_code text, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test := app.test_for_update(p_id, 'HUY');
begin
  if v_test.status_code = 'CANCELLED' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Phiếu này đã huỷ rồi.');
  end if;
  if v_test.status_code = 'COMPLETED' then
    perform app.raise_error('HMT_PHIEU_HOAN_THANH_PHAI_VE_NHAP', 'Phiếu đã hoàn thành: đưa về Nháp (có lý do) trước rồi mới huỷ.');
  end if;
  if p_reason_code is null then
    perform app.raise_error('HMT_THIEU_LY_DO', 'Chọn lý do huỷ phiếu.');
  end if;
  perform app.assert_catalog_code_active('TEST_CANCEL_REASON', p_reason_code);
  if (select requires_note from app.catalog_item where catalog_code = 'TEST_CANCEL_REASON' and code = p_reason_code)
     and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_THIEU_GHI_CHU', 'Chọn "Huỷ test, lý do khác" thì phải ghi chú lý do.');
  end if;
  update app.student_test
     set status_code = 'CANCELLED', cancel_reason_code = p_reason_code, cancel_note = nullif(btrim(coalesce(p_note, '')), ''),
         cancelled_at = now(), cancelled_by = auth.uid()
   where id = p_id;
  perform app.cancel_test_reminder(p_id);
  perform app.refresh_opportunity_l5_substage(v_test.opportunity_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Mở lại phiếu đã huỷ về Nháp: bắt buộc lý do (R-CRM-10). Giờ test còn ở tương lai thì lịch hẹn nhắc được bật lại.
-- ---------------------------------------------------------------------------
create or replace function app.reopen_student_test(p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_test app.student_test := app.test_for_update(p_id, 'SUA');
begin
  if v_test.status_code <> 'CANCELLED' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ mở lại được phiếu đã huỷ.');
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    perform app.raise_error('HMT_THIEU_LY_DO', 'Mở lại phiếu đã huỷ phải nhập lý do.');
  end if;
  update app.student_test
     set status_code = 'DRAFT', status_reason = btrim(p_reason), cancel_reason_code = null, cancel_note = null,
         cancelled_at = null, cancelled_by = null
   where id = p_id;
  if v_test.scheduled_at > now() then
    perform app.ensure_test_reminder(p_id, null, null);
  end if;
  perform app.refresh_opportunity_l5_substage(v_test.opportunity_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách lịch hẹn: thêm phiếu kiểm tra (bộ lọc student_test_id; cột student_test_id, student_test_code, is_auto_reminder;
-- record_code, record_label có cả hồ sơ là phiếu). Cột cũ giữ nguyên.
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
  v_test uuid := nullif(p_filters ->> 'student_test_id', '')::uuid;
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
       and (v_test is null or a.student_test_id = v_test)
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
             'student_test_id', p.student_test_id, 'student_test_code', t.code, 'is_auto_reminder', p.is_auto_reminder,
             'record_code', coalesce(l.code, o.code, t.code),
             'record_label', coalesce(l.parent_name || coalesce(' · ' || nullif(l.student_name, ''), ''),
                                      po.full_name || coalesce(' · ' || nullif(o.student_name, ''), ''),
                                      ts.full_name || ' · Phiếu kiểm tra'),
             'cancel_reason_code', p.cancel_reason_code, 'branch_code', b.code)
             order by case when p_sort = 'time_desc' then p.scheduled_at end desc, p.scheduled_at asc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    left join app.lead l on l.id = p.lead_id
    left join app.opportunity o on o.id = p.opportunity_id
    left join app.parent po on po.id = o.parent_id
    left join app.student_test t on t.id = p.student_test_id
    left join app.student ts on ts.id = t.student_id;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách phiếu phân trang ở máy chủ (TS-16). Trả {total, rows}; chỉ các cột màn hiện. security definer có chủ ý, cùng
-- lý do với list_leads (LIKE không "leakproof" dưới RLS): phạm vi từ app.permission_scope('STUDENT_TEST', 'XEM'), gồm
-- toàn hệ thống, đúng cơ sở của cơ hội, hoặc được phân công (giáo viên chấm, người phụ trách).
-- Bộ lọc: q, status[], branch_id (cơ sở của cơ hội), test_branch_id, room_id, owner_id, grader_id, mine (tôi phụ trách),
--   created_by_me (tôi tạo), grader_mine (tôi chấm bài), opportunity_id, student_id, from, to (giờ test), late_before
--   (phiếu Nháp có giờ test trước mốc này: nhãn "Quá giờ"). Sắp xếp: time_asc (mặc định), time_desc, created_desc.
-- ---------------------------------------------------------------------------
create or replace function app.list_student_tests(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'time_asc',
  p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('STUDENT_TEST', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_me uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_test_branch uuid := nullif(p_filters ->> 'test_branch_id', '')::uuid;
  v_room uuid := nullif(p_filters ->> 'room_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_grader uuid := nullif(p_filters ->> 'grader_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_created_by_me boolean := coalesce((p_filters ->> 'created_by_me')::boolean, false);
  v_grader_mine boolean := coalesce((p_filters ->> 'grader_mine')::boolean, false);
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_student uuid := nullif(p_filters ->> 'student_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_late timestamptz := nullif(p_filters ->> 'late_before', '')::timestamptz;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách phiếu kiểm tra.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang); mặc định Postgres quét cả bảng rồi sắp xếp.
  with f as not materialized (
    select t.*
      from app.student_test t
     where (v_scope = 'TOAN_HE_THONG'
            or (v_scope = 'CO_SO' and t.branch_id = v_my_branch)
            or (v_scope = 'DUOC_PHAN_CONG' and (t.grader_id = v_me or t.owner_id = v_me)))
       and (v_q is null or t.search_text like '%' || v_q || '%')
       and (cardinality(v_status) = 0 or t.status_code = any (v_status))
       and (v_branch is null or t.branch_id = v_branch)
       and (v_test_branch is null or t.test_branch_id = v_test_branch)
       and (v_room is null or t.room_id = v_room)
       and (v_owner is null or t.owner_id = v_owner)
       and (v_grader is null or t.grader_id = v_grader)
       and (not v_mine or t.owner_id = v_me)
       and (not v_created_by_me or t.created_by = v_me)
       and (not v_grader_mine or t.grader_id = v_me)
       and (v_opp is null or t.opportunity_id = v_opp)
       and (v_student is null or t.student_id = v_student)
       and (v_from is null or t.scheduled_at >= v_from)
       and (v_to is null or t.scheduled_at < v_to)
       and (v_late is null or (t.status_code = 'DRAFT' and t.scheduled_at < v_late))
  ),
  page as (
    select * from f
     order by case when p_sort = 'time_desc' then f.scheduled_at end desc,
              case when p_sort = 'created_desc' then f.created_at end desc,
              f.scheduled_at asc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'opportunity_id', p.opportunity_id, 'opportunity_code', o.code,
             'student_id', p.student_id, 'student_code', s.code, 'student_name', s.full_name, 'parent_name', pa.full_name,
             'subject_code', p.subject_code, 'grade_code', p.grade_code, 'mode_code', p.mode_code, 'level_code', p.level_code,
             'exam_name', p.exam_name, 'scheduled_at', p.scheduled_at, 'status_code', p.status_code,
             'branch_code', b.code, 'test_branch_code', tb.code, 'room_id', p.room_id, 'room_name', r.name,
             'grader_id', p.grader_id, 'grader_name', app.staff_display_name(p.grader_id),
             'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'score', p.score, 'cancel_reason_code', p.cancel_reason_code, 'created_at', p.created_at)
             order by case when p_sort = 'time_desc' then p.scheduled_at end desc,
                      case when p_sort = 'created_desc' then p.created_at end desc,
                      p.scheduled_at asc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.opportunity o on o.id = p.opportunity_id
    join app.student s on s.id = p.student_id
    join app.parent pa on pa.id = s.parent_id
    join app.branch b on b.id = p.branch_id
    join app.branch tb on tb.id = p.test_branch_id
    left join app.room r on r.id = p.room_id;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Kanban phiếu (TS-16 K2): một lần gọi trả bốn cột Nháp, Đang test, Chờ giáo viên chấm, Hoàn thành và cột Đã huỷ: tổng của
-- cột và N phiếu (N theo kanban_cards_per_column, tối đa list_page_size_max). Bộ lọc như list_student_tests (bỏ status).
-- Cột đang làm xếp theo giờ test gần nhất trước; Hoàn thành, Đã huỷ xếp theo giờ test mới nhất trước.
-- ---------------------------------------------------------------------------
create or replace function app.student_test_board(p_filters jsonb default '{}'::jsonb, p_per_column integer default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('STUDENT_TEST', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_me uuid := auth.uid();
  v_per integer := least(greatest(coalesce(p_per_column, app.get_setting_int('kanban_cards_per_column')), 1),
                         app.get_setting_int('list_page_size_max'));
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_test_branch uuid := nullif(p_filters ->> 'test_branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_grader uuid := nullif(p_filters ->> 'grader_id', '')::uuid;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_created_by_me boolean := coalesce((p_filters ->> 'created_by_me')::boolean, false);
  v_grader_mine boolean := coalesce((p_filters ->> 'grader_mine')::boolean, false);
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phiếu kiểm tra.');
  end if;
  with f as not materialized (
    select t.*
      from app.student_test t
     where (v_scope = 'TOAN_HE_THONG'
            or (v_scope = 'CO_SO' and t.branch_id = v_my_branch)
            or (v_scope = 'DUOC_PHAN_CONG' and (t.grader_id = v_me or t.owner_id = v_me)))
       and (v_q is null or t.search_text like '%' || v_q || '%')
       and (v_branch is null or t.branch_id = v_branch)
       and (v_test_branch is null or t.test_branch_id = v_test_branch)
       and (v_owner is null or t.owner_id = v_owner)
       and (v_grader is null or t.grader_id = v_grader)
       and (not v_mine or t.owner_id = v_me)
       and (not v_created_by_me or t.created_by = v_me)
       and (not v_grader_mine or t.grader_id = v_me)
       and (v_from is null or t.scheduled_at >= v_from)
       and (v_to is null or t.scheduled_at < v_to)
  ),
  counts as (select status_code, count(*) as n from f group by status_code)
  select coalesce(jsonb_agg(jsonb_build_object(
           'status_code', s.code, 'name', s.name, 'total', coalesce(c.n, 0), 'rows', cards.rows) order by s.sort_order),
           '[]'::jsonb)
    into v_result
    from app.catalog_item s
    left join counts c on c.status_code = s.code
    cross join lateral (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', t.id, 'code', t.code, 'student_name', st.full_name, 'parent_name', pa.full_name,
               'subject_code', t.subject_code, 'grade_code', t.grade_code, 'mode_code', t.mode_code,
               'scheduled_at', t.scheduled_at, 'test_branch_code', tb.code, 'room_name', r.name,
               'grader_name', app.staff_display_name(t.grader_id), 'owner_name', app.staff_display_name(t.owner_id),
               'score', t.score, 'status_code', t.status_code)
               order by case when s.code in ('COMPLETED', 'CANCELLED') then t.scheduled_at end desc,
                        t.scheduled_at asc, t.id), '[]'::jsonb) as rows
        from (select * from f where f.status_code = s.code
               order by case when s.code in ('COMPLETED', 'CANCELLED') then f.scheduled_at end desc, f.scheduled_at asc, f.id
               limit v_per) t
        join app.student st on st.id = t.student_id
        join app.parent pa on pa.id = st.parent_id
        join app.branch tb on tb.id = t.test_branch_id
        left join app.room r on r.id = t.room_id
    ) cards
   where s.catalog_code = 'TEST_STATUS' and s.is_active;
  return v_result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Quyền gọi: chỉ người đã đăng nhập; mỗi hàm tự kiểm quyền bên trong. Hàm nội bộ không cấp cho giao diện.
-- ---------------------------------------------------------------------------
revoke execute on function
  app.student_test_search_text(app.student_test), app.test_scope_ok(text, app.student_test),
  app.assert_test_access(text, app.student_test), app.assert_grader(uuid),
  app.opportunity_test_state(uuid), app.opportunity_l5_substage(uuid), app.refresh_opportunity_l5_substage(uuid),
  app.test_reminder_time(timestamptz, timestamptz), app.ensure_test_reminder(uuid, timestamptz, text),
  app.cancel_test_reminder(uuid), app.test_for_update(uuid, text)
  from public, anon, authenticated;
revoke execute on function
  app.create_student_test(uuid, jsonb, timestamptz, text), app.reschedule_student_test(uuid, timestamptz, timestamptz),
  app.update_student_test(uuid, jsonb), app.start_student_test(uuid), app.submit_student_test(uuid),
  app.enter_test_result(uuid, numeric, text, text, text, uuid), app.complete_student_test(uuid),
  app.step_back_student_test(uuid, text), app.cancel_student_test(uuid, text, text), app.reopen_student_test(uuid, text),
  app.list_student_tests(jsonb, text, integer, integer), app.student_test_board(jsonb, integer)
  from public, anon;
grant execute on function
  app.create_student_test(uuid, jsonb, timestamptz, text), app.reschedule_student_test(uuid, timestamptz, timestamptz),
  app.update_student_test(uuid, jsonb), app.start_student_test(uuid), app.submit_student_test(uuid),
  app.enter_test_result(uuid, numeric, text, text, text, uuid), app.complete_student_test(uuid),
  app.step_back_student_test(uuid, text), app.cancel_student_test(uuid, text, text), app.reopen_student_test(uuid, text),
  app.list_student_tests(jsonb, text, integer, integer), app.student_test_board(jsonb, integer)
  to authenticated;

select set_config('hmt.migration', '', false);
