-- ===========================================================================
-- Danh sách em của lead và cơ hội, PR DB-1 (nền và chuyển dữ liệu). QĐ-Đ75, Đ81, Đ86, Đ87, Đ88 (24/10/2026).
--
-- Việc của migration này: tạo bảng app.prospect_student (một dòng một em, của lead HOẶC của cơ hội), chuyển thông tin học sinh dạng
-- chữ đang nằm ở lead và cơ hội (student_name, student_birth_date, student_birth_year, school, self_rating, goal) và cơ hội.student_id
-- sang dòng đầu của danh sách, bỏ các cột cũ, rồi chuyển mọi hàm đang đọc hoặc ghi các cột đó sang bảng mới.
--
-- GIỮ ĐÚNG HÀNH VI CŨ: mỗi hồ sơ vẫn một em (dòng 1); các hàm danh sách, bản ghi vẫn trả khoá student_name,
-- student_birth_year… (lấy từ em đầu) kèm mảng "students". Mọi luật mới (tối đa số em, thêm, sửa, bỏ em, kiểm trùng, gộp hợp
-- danh sách, ít nhất một em đủ tên và năm sinh) làm ở PR DB-2, sau khi spec có luật.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Tham số: số em tối đa mỗi lead, cơ hội (Đ88). Khai báo ở đây; hàm thêm em kiểm ở DB-2.
-- ---------------------------------------------------------------------------
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('prospect_max_students', 'Số em tối đa mỗi lead, cơ hội', 'INT', 'em', 1, 20, '5', false, 'BAN_HANG', 'Đ88',
   'Một lead, một cơ hội có tối đa bấy nhiêu em trong danh sách em. Gộp mà vượt thì chặn.');

-- ---------------------------------------------------------------------------
-- Bảng danh sách em. Đúng một trong lead_id, opportunity_id (như lịch hẹn). branch_id chép từ hồ sơ cha để RLS không phải nối bảng.
-- Đ86: đã gắn hồ sơ học sinh (student_id) thì tên, ngày sinh, năm sinh, trường, học lực, mục tiêu đọc thẳng từ hồ sơ học sinh;
-- dòng không giữ bản sao (ràng buộc prospect_student_read_through).
-- ---------------------------------------------------------------------------
create table app.prospect_student (
  id uuid primary key default gen_random_uuid(),
  lead_id uuid references app.lead (id),
  opportunity_id uuid references app.opportunity (id),
  branch_id uuid not null references app.branch (id),
  position integer not null default 1 check (position >= 1),
  student_id uuid references app.student (id),
  full_name text check (full_name is null or btrim(full_name) <> ''),
  birth_date date,
  birth_year integer check (birth_year is null or birth_year >= 1900), -- allow-number: năm sinh tối thiểu, như app.student
  school text,
  self_rating text,
  goal text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  constraint prospect_student_one_parent check (num_nonnulls(lead_id, opportunity_id) = 1),
  constraint prospect_student_read_through check (
    student_id is null
    or (full_name is null and birth_date is null and birth_year is null and school is null and self_rating is null and goal is null))
);
comment on table app.prospect_student is
  'Danh sách em của lead hoặc cơ hội (Đ75). Đã gắn hồ sơ học sinh thì đọc thẳng từ hồ sơ (Đ86). Ghi chỉ qua hàm nghiệp vụ.';

-- Chỉ mục (lý do): thứ tự em trong một hồ sơ và "em đầu" của danh sách (unique từng phần theo hồ sơ cha).
create unique index prospect_student_opp_pos_uidx on app.prospect_student (opportunity_id, position)
  where opportunity_id is not null;
create unique index prospect_student_lead_pos_uidx on app.prospect_student (lead_id, position)
  where lead_id is not null;
-- Khoá ngoại tới hồ sơ học sinh: gộp học sinh, tìm các dòng của một học sinh.
create index prospect_student_student_idx on app.prospect_student (student_id) where student_id is not null;
-- Cột dùng trong chính sách RLS.
create index prospect_student_branch_idx on app.prospect_student (branch_id);

select app.apply_standard('app.prospect_student');

alter table app.prospect_student enable row level security;
revoke all on app.prospect_student from public, anon, authenticated;
grant select on app.prospect_student to authenticated;
-- RLS: đọc theo quyền Xem của hồ sơ cha (Lead hoặc Cơ hội) ở đúng cơ sở; ghi chỉ qua hàm nghiệp vụ.
create policy prospect_student_read on app.prospect_student for select to authenticated
  using (
    (lead_id is not null
     and ((select app.permission_scope('LEAD', 'XEM')) = 'TOAN_HE_THONG'
          or ((select app.permission_scope('LEAD', 'XEM')) is not null and branch_id = (select app.current_branch_id()))))
    or (opportunity_id is not null
        and ((select app.permission_scope('OPPORTUNITY', 'XEM')) = 'TOAN_HE_THONG'
             or ((select app.permission_scope('OPPORTUNITY', 'XEM')) is not null
                 and branch_id = (select app.current_branch_id())))));

-- Luật (bổ sung b): branch_id luôn là cơ sở của hồ sơ cha, kể cả khi cha đổi cơ sở.
create or replace function app.tg_prospect_student_branch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  select coalesce((select l.branch_id from app.lead l where l.id = new.lead_id),
                  (select o.branch_id from app.opportunity o where o.id = new.opportunity_id),
                  new.branch_id)
    into new.branch_id;
  return new;
end;
$$;
create trigger prospect_student_branch before insert or update of lead_id, opportunity_id on app.prospect_student
  for each row execute function app.tg_prospect_student_branch();

create or replace function app.tg_prospect_parent_branch_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.branch_id is distinct from old.branch_id then
    if TG_TABLE_NAME = 'lead' then
      update app.prospect_student set branch_id = new.branch_id where lead_id = new.id;
    else
      update app.prospect_student set branch_id = new.branch_id where opportunity_id = new.id;
    end if;
  end if;
  return null;
end;
$$;
create trigger lead_prospect_branch_sync after update of branch_id on app.lead
  for each row execute function app.tg_prospect_parent_branch_sync();
create trigger opportunity_prospect_branch_sync after update of branch_id on app.opportunity
  for each row execute function app.tg_prospect_parent_branch_sync();

-- ---------------------------------------------------------------------------
-- Dạng đã giải: dòng gắn hồ sơ thì lấy tên, năm sinh… từ hồ sơ học sinh (Đ86). Chỉ hàm nghiệp vụ (security definer) đọc.
-- ---------------------------------------------------------------------------
create view app.prospect_student_v as
select ps.id, ps.lead_id, ps.opportunity_id, ps.branch_id, ps.position, ps.student_id, s.code as student_code,
       coalesce(s.full_name, ps.full_name) as full_name,
       coalesce(s.birth_date, ps.birth_date) as birth_date,
       coalesce(s.birth_year, ps.birth_year) as birth_year,
       coalesce(s.school, ps.school) as school,
       coalesce(s.self_rating, ps.self_rating) as self_rating,
       coalesce(s.goal, ps.goal) as goal
  from app.prospect_student ps
  left join app.student s on s.id = ps.student_id;
revoke all on app.prospect_student_v from public, anon, authenticated;

-- Em đầu của một lead, một cơ hội (dòng có position nhỏ nhất); không có em thì trả dòng rỗng (mọi cột null).
create or replace function app.lead_first(p_lead_id uuid)
returns app.prospect_student_v
language sql
stable
set search_path = ''
as $$
  select v from app.prospect_student_v v where v.lead_id = p_lead_id order by v.position limit 1;
$$;
create or replace function app.opp_first(p_opportunity_id uuid)
returns app.prospect_student_v
language sql
stable
set search_path = ''
as $$
  select v from app.prospect_student_v v where v.opportunity_id = p_opportunity_id order by v.position limit 1;
$$;

-- Mọi tên em của một hồ sơ, nối bằng khoảng trắng: dùng cho ô tìm kiếm (search_text).
create or replace function app.prospect_names(p_lead_id uuid, p_opportunity_id uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(string_agg(v.full_name, ' ' order by v.position), '')
    from app.prospect_student_v v
   where (p_lead_id is not null and v.lead_id = p_lead_id)
      or (p_opportunity_id is not null and v.opportunity_id = p_opportunity_id);
$$;

-- Danh sách em của một hồ sơ dạng JSON (dùng chung cho get_lead, get_opportunity).
create or replace function app.prospect_students_json(p_lead_id uuid, p_opportunity_id uuid)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', v.id, 'position', v.position, 'student_id', v.student_id, 'student_code', v.student_code,
           'full_name', v.full_name, 'birth_date', v.birth_date, 'birth_year', v.birth_year,
           'school', v.school, 'self_rating', v.self_rating, 'goal', v.goal) order by v.position), '[]'::jsonb)
    from app.prospect_student_v v
   where (p_lead_id is not null and v.lead_id = p_lead_id)
      or (p_opportunity_id is not null and v.opportunity_id = p_opportunity_id);
$$;

-- Từ giai đoạn L5 trở lên (R-CRM-03).
create or replace function app.stage_is_l5_or_later(p_stage_code text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select (select sort_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = p_stage_code)
         >= (select sort_order from app.catalog_item where catalog_code = 'OPP_STAGE' and code = 'L5');
$$;

-- ---------------------------------------------------------------------------
-- Ghi em đầu từ dữ liệu kiểu cũ (các khoá student_name, student_birth_date, student_birth_year, school, self_rating, goal).
-- Ai gọi: các hàm tạo, sửa lead, cơ hội (đã kiểm quyền Sửa); không mở cho API.
-- Đầu vào: loại (LEAD hoặc OPPORTUNITY), id hồ sơ, p_data (khoá nào có thì ghi đè, khoá vắng thì giữ), p_derive_year (cơ hội:
--   không có năm sinh mà có ngày sinh thì lấy năm của ngày sinh, như hàm cũ).
-- Luật: R-CRM-26, 27 (em đã gắn hồ sơ học sinh thì sửa luôn hồ sơ đó, cần quyền Học sinh · Sửa; tên và năm sinh bắt buộc);
--   R-CRM-03 (cơ hội từ L5 trở lên không được xoá tên, năm sinh của em đầu). Không có khoá nào của em thì không làm gì.
-- ---------------------------------------------------------------------------
create or replace function app.set_first_prospect(p_entity text, p_id uuid, p_data jsonb, p_derive_year boolean default false)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line app.prospect_student;
  v_cur app.prospect_student_v;
  v_student app.student;
  v_stage text;
  v_name text;
  v_date date;
  v_year integer;
  v_school text;
  v_rating text;
  v_goal text;
begin
  if not (p_data ?| array['student_name', 'student_birth_date', 'student_birth_year', 'school', 'self_rating', 'goal']) then
    return;
  end if;
  if p_entity = 'LEAD' then
    select * into v_line from app.prospect_student where lead_id = p_id order by position limit 1 for update;
  else
    select * into v_line from app.prospect_student where opportunity_id = p_id order by position limit 1 for update;
    select stage_code into v_stage from app.opportunity where id = p_id;
  end if;
  if v_line.id is not null then
    select * into v_cur from app.prospect_student_v where id = v_line.id;
  end if;

  -- Ô nào p_data có thì ghi đè, không có thì giữ giá trị hiện tại của em đầu.
  v_name := case when p_data ? 'student_name' then nullif(btrim(coalesce(p_data ->> 'student_name', '')), '') else v_cur.full_name end;
  v_date := case when p_data ? 'student_birth_date' then nullif(p_data ->> 'student_birth_date', '')::date else v_cur.birth_date end;
  v_year := case when p_data ? 'student_birth_year' then nullif(p_data ->> 'student_birth_year', '')::integer
                 when p_derive_year and p_data ? 'student_birth_date' then extract(year from v_date)::integer
                 else v_cur.birth_year end;
  v_school := case when p_data ? 'school' then p_data ->> 'school' else v_cur.school end;
  v_rating := case when p_data ? 'self_rating' then p_data ->> 'self_rating' else v_cur.self_rating end;
  v_goal := case when p_data ? 'goal' then p_data ->> 'goal' else v_cur.goal end;

  if v_line.student_id is not null then
    -- Luật R-CRM-26, 27: đã có hồ sơ học sinh thì sửa luôn hồ sơ đó.
    select * into v_student from app.student where id = v_line.student_id;
    perform app.assert_can('STUDENT', 'SUA', v_student.branch_id);
    if v_name is null or v_year is null then
      perform app.raise_error('HMT_THIEU_HOC_SINH', 'Hồ sơ học sinh bắt buộc có tên và năm sinh.');
    end if;
    update app.student set full_name = v_name, birth_date = v_date, birth_year = v_year,
           school = v_school, self_rating = v_rating, goal = v_goal
     where id = v_line.student_id;
    return;
  end if;

  -- Luật R-CRM-03: từ L5 trở lên cơ hội bắt buộc có tên và năm sinh học sinh.
  if p_entity = 'OPPORTUNITY' and app.stage_is_l5_or_later(v_stage) and (v_name is null or v_year is null) then
    perform app.raise_error('HMT_THIEU_HOC_SINH',
      'Từ giai đoạn L5 trở lên cơ hội bắt buộc có tên và năm sinh của học sinh.');
  end if;

  if v_line.id is null then
    if v_name is null and v_date is null and v_year is null and v_school is null and v_rating is null and v_goal is null then
      return;
    end if;
    if p_entity = 'LEAD' then
      insert into app.prospect_student (lead_id, branch_id, position, full_name, birth_date, birth_year, school, self_rating, goal)
      values (p_id, (select branch_id from app.lead where id = p_id), 1, v_name, v_date, v_year, v_school, v_rating, v_goal);
    else
      insert into app.prospect_student (opportunity_id, branch_id, position, full_name, birth_date, birth_year, school, self_rating, goal)
      values (p_id, (select branch_id from app.opportunity where id = p_id), 1, v_name, v_date, v_year, v_school, v_rating, v_goal);
    end if;
  else
    update app.prospect_student set full_name = v_name, birth_date = v_date, birth_year = v_year,
           school = v_school, self_rating = v_rating, goal = v_goal
     where id = v_line.id;
  end if;
end;
$$;
revoke execute on function app.set_first_prospect(text, uuid, jsonb, boolean) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Chuyển dữ liệu: mỗi lead, cơ hội có thông tin học sinh thì thành dòng 1. Cơ hội đã gắn hồ sơ học sinh: dòng gắn student_id,
-- bỏ chữ (hồ sơ học sinh là nguồn duy nhất).
-- ---------------------------------------------------------------------------
insert into app.prospect_student (lead_id, branch_id, position, full_name, birth_date, birth_year, school, self_rating, goal,
                                  created_at, created_by, updated_at, updated_by)
select l.id, l.branch_id, 1, l.student_name, l.student_birth_date, l.student_birth_year, l.school, l.self_rating, l.goal,
       l.created_at, l.created_by, l.updated_at, l.updated_by
  from app.lead l
 where l.student_name is not null or l.student_birth_date is not null or l.student_birth_year is not null
    or l.school is not null or l.self_rating is not null or l.goal is not null;

insert into app.prospect_student (opportunity_id, branch_id, position, student_id, full_name, birth_date, birth_year, school,
                                  self_rating, goal, created_at, created_by, updated_at, updated_by)
select o.id, o.branch_id, 1, o.student_id,
       case when o.student_id is null then o.student_name end, case when o.student_id is null then o.student_birth_date end,
       case when o.student_id is null then o.student_birth_year end, case when o.student_id is null then o.school end,
       case when o.student_id is null then o.self_rating end, case when o.student_id is null then o.goal end,
       o.created_at, o.created_by, o.updated_at, o.updated_by
  from app.opportunity o
 where o.student_id is not null or o.student_name is not null or o.student_birth_date is not null
    or o.student_birth_year is not null or o.school is not null or o.self_rating is not null or o.goal is not null;

-- Kiểm số dòng trước và sau chuyển (bổ sung e): sai một dòng là huỷ cả migration.
do $$
declare
  v_expected_lead bigint;
  v_expected_opp bigint;
  v_lead bigint;
  v_opp bigint;
begin
  select count(*) into v_expected_lead from app.lead l
   where l.student_name is not null or l.student_birth_date is not null or l.student_birth_year is not null
      or l.school is not null or l.self_rating is not null or l.goal is not null;
  select count(*) into v_expected_opp from app.opportunity o
   where o.student_id is not null or o.student_name is not null or o.student_birth_date is not null
      or o.student_birth_year is not null or o.school is not null or o.self_rating is not null or o.goal is not null;
  select count(*) into v_lead from app.prospect_student where lead_id is not null;
  select count(*) into v_opp from app.prospect_student where opportunity_id is not null;
  if v_lead <> v_expected_lead or v_opp <> v_expected_opp then
    raise exception 'Chuyển danh sách em lệch số dòng: lead % trên %, cơ hội % trên %', v_lead, v_expected_lead, v_opp, v_expected_opp;
  end if;
end;
$$;

-- Phiếu kiểm tra trỏ tới dòng em (giữ student_id hồ sơ học sinh như cũ).
alter table app.student_test add column prospect_student_id uuid references app.prospect_student (id);
update app.student_test t set prospect_student_id =
  (select ps.id from app.prospect_student ps where ps.opportunity_id = t.opportunity_id order by ps.position limit 1);
-- Phiếu cũ không dòng em (cơ hội không có thông tin học sinh) không thể có: phiếu luôn có hồ sơ học sinh từ cơ hội.
do $$
begin
  if exists (select from app.student_test where prospect_student_id is null) then
    raise exception 'Có phiếu kiểm tra chưa gắn được vào dòng em';
  end if;
end;
$$;
alter table app.student_test alter column prospect_student_id set not null;
-- Chỉ mục (lý do): khoá ngoại, gộp cơ hội/chuyển dòng em kéo theo phiếu.
create index student_test_prospect_idx on app.student_test (prospect_student_id);

-- ---------------------------------------------------------------------------
-- Bỏ cột chữ cũ. Cột search_text của lead đang là cột sinh từ student_name nên bỏ trước, dựng lại bằng trigger như cơ hội.
-- ---------------------------------------------------------------------------
drop index app.lead_search_idx;
alter table app.lead drop column search_text;
alter table app.lead
  drop column student_name, drop column student_birth_date, drop column student_birth_year,
  drop column school, drop column self_rating, drop column goal;
alter table app.opportunity
  drop column student_id, drop column student_name, drop column student_birth_date, drop column student_birth_year,
  drop column school, drop column self_rating, drop column goal;
alter table app.lead add column search_text text not null default '';

-- Ô tìm kiếm của lead (mã, phụ huynh, SĐT, tên các em, mã cũ), giống cơ hội.
create or replace function app.lead_search_text(p_lead app.lead)
returns text
language sql
stable
set search_path = ''
as $$
  select app.fold_text(p_lead.code || ' ' || p_lead.parent_name || ' ' || p_lead.parent_phone || ' '
                       || app.prospect_names(p_lead.id, null) || ' ' || coalesce(p_lead.legacy_ref, ''));
$$;
create or replace function app.tg_lead_search_text()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.search_text := app.lead_search_text(new);
  return new;
end;
$$;
create trigger lead_search_text before insert or update on app.lead
  for each row execute function app.tg_lead_search_text();

-- Ô tìm kiếm của cơ hội lấy tên các em từ danh sách em.
create or replace function app.opportunity_search_text(p_opp app.opportunity)
returns text
language sql
stable
set search_path = ''
as $$
  select app.fold_text(p_opp.code || ' ' || coalesce((select p.full_name || ' ' || p.phone from app.parent p
                                                       where p.id = p_opp.parent_id), '')
                       || ' ' || app.prospect_names(null, p_opp.id) || ' ' || coalesce(p_opp.legacy_ref, ''));
$$;

-- Tính lại ô tìm kiếm cho mọi lead, cơ hội (tên em đã đổi nguồn).
update app.lead l set search_text = app.lead_search_text(l);
update app.opportunity o set search_text = app.opportunity_search_text(o);
-- Chỉ mục tìm kiếm (lý do): tìm "chứa chuỗi" trong danh sách lead, như cơ hội (opportunity_search_idx).
create index lead_search_idx on app.lead using gin (search_text extensions.gin_trgm_ops);

-- Dòng em đổi (thêm, sửa, gắn hồ sơ) thì ô tìm kiếm của lead, cơ hội cha tính lại.
create or replace function app.tg_prospect_refresh_parent_search()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lead uuid := coalesce(new.lead_id, old.lead_id);
  v_opp uuid := coalesce(new.opportunity_id, old.opportunity_id);
begin
  if v_lead is not null then
    update app.lead l set search_text = app.lead_search_text(l) where l.id = v_lead;
  end if;
  if v_opp is not null then
    update app.opportunity o set search_text = app.opportunity_search_text(o) where o.id = v_opp;
  end if;
  return null;
end;
$$;
create trigger prospect_student_refresh_search after insert or update or delete on app.prospect_student
  for each row execute function app.tg_prospect_refresh_parent_search();

-- Hồ sơ học sinh đổi tên thì tìm kiếm của phiếu và của các lead, cơ hội có em gắn hồ sơ đó tính lại.
create or replace function app.tg_student_refresh_test_search()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.full_name is distinct from old.full_name then
    update app.student_test t set search_text = app.student_test_search_text(t) where t.student_id = new.id;
    update app.opportunity o set search_text = app.opportunity_search_text(o)
     where o.id in (select ps.opportunity_id from app.prospect_student ps where ps.student_id = new.id and ps.opportunity_id is not null);
  end if;
  return null;
end;
$$;


-- Khoá tương thích của bản ghi lead, cơ hội: tên, năm sinh… của em đầu (giao diện P3 cũ vẫn đọc student_name…); student_id/student_code của cơ hội.
create or replace function app.prospect_compat_json(p_first app.prospect_student_v)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object('student_name', p_first.full_name, 'student_birth_date', p_first.birth_date,
                            'student_birth_year', p_first.birth_year, 'school', p_first.school,
                            'self_rating', p_first.self_rating, 'goal', p_first.goal,
                            'student_id', p_first.student_id, 'student_code', p_first.student_code);
$$;

-- ===========================================================================
-- Chuyển các hàm đang đọc, ghi cột cũ sang danh sách em (giữ khoá kết quả cũ).
-- ===========================================================================
-- ---------------------------------------------------------------------------
-- Danh sách lead: tên, năm sinh em lấy từ em đầu của danh sách em (Đ75).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.list_leads(p_filters jsonb DEFAULT '{}'::jsonb, p_sort text DEFAULT 'created_desc'::text, p_limit integer DEFAULT NULL::integer, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text := app.permission_scope('LEAD', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_channel text[] := array(select jsonb_array_elements_text(p_filters -> 'channel'));
  v_campaign uuid := nullif(p_filters ->> 'campaign_id', '')::uuid;
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
  v_only_merged boolean := coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false) or coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_appt text[] := array(select jsonb_array_elements_text(p_filters -> 'appointment'));
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
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
       -- Bản "Đã gộp" ẩn khỏi danh sách mặc định nhưng vẫn tìm được bằng mã (R-CRM-22); "chỉ bản đã gộp" là bộ lọc riêng.
       and (case when v_only_merged then l.record_status = 'DA_GOP'
                 else (v_merged or l.record_status = 'DANG_DUNG'
                       or (v_q is not null and l.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or l.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or l.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or l.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or l.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or l.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or l.channel_code = any (v_channel))
       and (v_campaign is null or l.campaign_id = v_campaign)
       and (v_branch is null or l.branch_id = v_branch)
       and (v_owner is null or l.owner_id = v_owner)
       and (not v_mine or l.owner_id = auth.uid())
       and (not v_support_mine or l.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
            or ('OWNER' = any (v_mine_roles) and l.owner_id = auth.uid())
            or ('SUPPORT' = any (v_mine_roles) and l.supporter_id = auth.uid()))
       and (v_from is null or l.created_at >= v_from)
       and (v_to is null or l.created_at < v_to)
       and (v_next_from is null or l.next_appointment_at >= v_next_from)
       and (v_next_to is null or l.next_appointment_at < v_next_to)
       and (v_next_before is null or l.next_appointment_at < v_next_before)
       and (not v_no_appt or l.next_appointment_at is null)
       and (cardinality(v_appt) = 0
            or ('OVERDUE' = any (v_appt) and l.next_appointment_at < v_day_start)
            or ('TODAY' = any (v_appt) and l.next_appointment_at >= v_day_start and l.next_appointment_at < v_day_end)
            or ('UPCOMING' = any (v_appt) and l.next_appointment_at >= v_day_end)
            or ('NONE' = any (v_appt) and l.next_appointment_at is null))
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
             'student_name', (app.lead_first(p.id)).full_name, 'student_birth_year', (app.lead_first(p.id)).birth_year,
             'stage_code', p.stage_code, 'substage_code', p.substage_code,
             'source_type_code', p.source_type_code, 'source_code', p.source_code, 'channel_code', p.channel_code,
             'campaign_id', p.campaign_id, 'campaign_name', c.name,
             'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'supporter_id', p.supporter_id, 'supporter_name', app.staff_display_name(p.supporter_id),
             'branch_code', b.code, 'assigned_at', p.assigned_at,
             'next_appointment_at', p.next_appointment_at, 'created_at', p.created_at,
             'record_status', p.record_status, 'merged_into_code', m.code)
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'next_appointment_asc' then p.next_appointment_at end asc nulls last,
                      case when p_sort = 'name_asc' then p.parent_name end asc,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    left join app.lead m on m.id = p.merged_into_id
    left join app.campaign c on c.id = p.campaign_id;
  return v_result;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Bảng Kanban lead: tên em đầu.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.lead_board(p_filters jsonb DEFAULT '{}'::jsonb, p_per_column integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text := app.permission_scope('LEAD', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_channel text[] := array(select jsonb_array_elements_text(p_filters -> 'channel'));
  v_campaign uuid := nullif(p_filters ->> 'campaign_id', '')::uuid;
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
  v_only_merged boolean := coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false) or coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_appt text[] := array(select jsonb_array_elements_text(p_filters -> 'appointment'));
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_per integer := least(greatest(coalesce(p_per_column, app.get_setting_int('kanban_cards_per_column')), 1),
                         app.get_setting_int('list_page_size_max'));
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lead.');
  end if;
  with base as not materialized (
    select l.*
      from app.lead l
     where (v_scope = 'TOAN_HE_THONG' or l.branch_id = v_my_branch)
       and l.record_status = 'DANG_DUNG'
       and (v_q is null or l.search_text like '%' || v_q || '%')
       and (cardinality(v_type) = 0 or l.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or l.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or l.channel_code = any (v_channel))
       and (v_campaign is null or l.campaign_id = v_campaign)
       and (v_branch is null or l.branch_id = v_branch)
       and (v_owner is null or l.owner_id = v_owner)
       and (not v_mine or l.owner_id = auth.uid())
       and (not v_support_mine or l.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
            or ('OWNER' = any (v_mine_roles) and l.owner_id = auth.uid())
            or ('SUPPORT' = any (v_mine_roles) and l.supporter_id = auth.uid()))
       and (v_from is null or l.created_at >= v_from)
       and (v_to is null or l.created_at < v_to)
  ),
  stats as (
    select b.stage_code,
           count(*) filter (where (v_next_from is null or b.next_appointment_at >= v_next_from)
               and (v_next_to is null or b.next_appointment_at < v_next_to)
               and (v_next_before is null or b.next_appointment_at < v_next_before)
               and (not v_no_appt or b.next_appointment_at is null)
               and (cardinality(v_appt) = 0
                    or ('OVERDUE' = any (v_appt) and b.next_appointment_at < v_day_start)
                    or ('TODAY' = any (v_appt) and b.next_appointment_at >= v_day_start and b.next_appointment_at < v_day_end)
                    or ('UPCOMING' = any (v_appt) and b.next_appointment_at >= v_day_end)
                    or ('NONE' = any (v_appt) and b.next_appointment_at is null))) as total,
           count(*) filter (where b.next_appointment_at is null) as n_none,
           count(*) filter (where b.next_appointment_at < v_day_start) as n_overdue,
           count(*) filter (where b.next_appointment_at >= v_day_start and b.next_appointment_at < v_day_end) as n_today,
           count(*) filter (where b.next_appointment_at >= v_day_end) as n_ok
      from base b group by b.stage_code
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'stage_code', s.code, 'name', s.name, 'total', coalesce(st.total, 0),
           'bar', jsonb_build_object('ok', coalesce(st.n_ok, 0), 'today', coalesce(st.n_today, 0),
                                     'overdue', coalesce(st.n_overdue, 0), 'none', coalesce(st.n_none, 0)),
           'rows', cards.rows) order by s.sort_order), '[]'::jsonb)
    into v_result
    from app.catalog_item s
    left join stats st on st.stage_code = s.code
    cross join lateral (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', t.id, 'code', t.code, 'parent_name', t.parent_name, 'parent_phone', t.parent_phone,
               'student_name', (app.lead_first(t.id)).full_name, 'source_type_code', t.source_type_code, 'source_code', t.source_code,
               'channel_code', t.channel_code, 'substage_code', t.substage_code, 'owner_id', t.owner_id,
               'owner_name', app.staff_display_name(t.owner_id), 'branch_code', br.code,
               'next_appointment_at', t.next_appointment_at, 'created_at', t.created_at)
               order by t.created_at desc, t.id), '[]'::jsonb) as rows
        from (select * from base bb where bb.stage_code = s.code
                 and (v_next_from is null or bb.next_appointment_at >= v_next_from)
               and (v_next_to is null or bb.next_appointment_at < v_next_to)
               and (v_next_before is null or bb.next_appointment_at < v_next_before)
               and (not v_no_appt or bb.next_appointment_at is null)
       and (cardinality(v_appt) = 0
            or ('OVERDUE' = any (v_appt) and bb.next_appointment_at < v_day_start)
            or ('TODAY' = any (v_appt) and bb.next_appointment_at >= v_day_start and bb.next_appointment_at < v_day_end)
            or ('UPCOMING' = any (v_appt) and bb.next_appointment_at >= v_day_end)
            or ('NONE' = any (v_appt) and bb.next_appointment_at is null))
               order by bb.created_at desc, bb.id limit v_per) t
        join app.branch br on br.id = t.branch_id
    ) cards
   where s.catalog_code = 'LEAD_STAGE' and s.is_active;
  return v_result;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Bảng Kanban cơ hội: tên em đầu.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.opportunity_board(p_filters jsonb DEFAULT '{}'::jsonb, p_per_column integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text := app.permission_scope('OPPORTUNITY', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_channel text[] := array(select jsonb_array_elements_text(p_filters -> 'channel'));
  v_campaign uuid := nullif(p_filters ->> 'campaign_id', '')::uuid;
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
  v_only_merged boolean := coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false) or coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_appt text[] := array(select jsonb_array_elements_text(p_filters -> 'appointment'));
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_per integer := least(greatest(coalesce(p_per_column, app.get_setting_int('kanban_cards_per_column')), 1),
                         app.get_setting_int('list_page_size_max'));
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem cơ hội.');
  end if;
  with base as not materialized (
    select o.*
      from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and o.record_status = 'DANG_DUNG'
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_type) = 0 or o.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or o.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or o.channel_code = any (v_channel))
       and (v_campaign is null or o.campaign_id = v_campaign)
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and o.owner_id = auth.uid())
        or ('SUPPORT' = any (v_mine_roles) and o.supporter_id = auth.uid()))
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
  ),
  stats as (
    select b.stage_code,
           count(*) filter (where (v_next_from is null or b.next_appointment_at >= v_next_from)

               and (v_next_to is null or b.next_appointment_at < v_next_to)

               and (v_next_before is null or b.next_appointment_at < v_next_before)

               and (not v_no_appt or b.next_appointment_at is null)

               and (cardinality(v_appt) = 0
                    or ('OVERDUE' = any (v_appt) and b.next_appointment_at < v_day_start)
                    or ('TODAY' = any (v_appt) and b.next_appointment_at >= v_day_start and b.next_appointment_at < v_day_end)
                    or ('UPCOMING' = any (v_appt) and b.next_appointment_at >= v_day_end)
                    or ('NONE' = any (v_appt) and b.next_appointment_at is null))) as total,
           count(*) filter (where b.next_appointment_at is null) as n_none,
           count(*) filter (where b.next_appointment_at < v_day_start) as n_overdue,
           count(*) filter (where b.next_appointment_at >= v_day_start and b.next_appointment_at < v_day_end) as n_today,
           count(*) filter (where b.next_appointment_at >= v_day_end) as n_ok
      from base b group by b.stage_code
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'stage_code', s.code, 'name', s.name, 'total', coalesce(st.total, 0),
           'bar', jsonb_build_object('ok', coalesce(st.n_ok, 0), 'today', coalesce(st.n_today, 0),
                                     'overdue', coalesce(st.n_overdue, 0), 'none', coalesce(st.n_none, 0)),
           'rows', cards.rows) order by s.sort_order), '[]'::jsonb)
    into v_result
    from app.catalog_item s
    left join stats st on st.stage_code = s.code
    cross join lateral (
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', t.id, 'code', t.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
               'student_name', (app.opp_first(t.id)).full_name, 'source_type_code', t.source_type_code, 'source_code', t.source_code,
               'channel_code', t.channel_code, 'substage_code', t.substage_code, 'owner_id', t.owner_id,
               'owner_name', app.staff_display_name(t.owner_id), 'branch_code', b.code,
               'next_appointment_at', t.next_appointment_at, 'created_at', t.created_at)
               order by t.created_at desc, t.id), '[]'::jsonb) as rows
        from (select * from base bb where bb.stage_code = s.code
               and (v_next_from is null or bb.next_appointment_at >= v_next_from)
               and (v_next_to is null or bb.next_appointment_at < v_next_to)
               and (v_next_before is null or bb.next_appointment_at < v_next_before)
               and (not v_no_appt or bb.next_appointment_at is null)
               and (cardinality(v_appt) = 0
                    or ('OVERDUE' = any (v_appt) and bb.next_appointment_at < v_day_start)
                    or ('TODAY' = any (v_appt) and bb.next_appointment_at >= v_day_start and bb.next_appointment_at < v_day_end)
                    or ('UPCOMING' = any (v_appt) and bb.next_appointment_at >= v_day_end)
                    or ('NONE' = any (v_appt) and bb.next_appointment_at is null))
               order by bb.created_at desc, bb.id limit v_per) t
        join app.parent par on par.id = t.parent_id
        join app.branch b on b.id = t.branch_id
    ) cards
   where s.catalog_code = 'OPP_STAGE' and s.is_active;
  return v_result;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Danh sách cơ hội: tên, năm sinh em lấy từ em đầu; sắp xếp theo tên em đầu.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.list_opportunities(p_filters jsonb DEFAULT '{}'::jsonb, p_sort text DEFAULT 'created_desc'::text, p_limit integer DEFAULT NULL::integer, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text := app.permission_scope('OPPORTUNITY', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_channel text[] := array(select jsonb_array_elements_text(p_filters -> 'channel'));
  v_campaign uuid := nullif(p_filters ->> 'campaign_id', '')::uuid;
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
  v_only_merged boolean := coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false) or coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_appt text[] := array(select jsonb_array_elements_text(p_filters -> 'appointment'));
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách cơ hội.');
  end if;
  -- not materialized: f dùng hai lần (đếm và lấy trang); mặc định Postgres quét cả bảng rồi sắp xếp.
  with f as not materialized (
    select o.*
      from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (case when v_only_merged then o.record_status = 'DA_GOP'
             else (v_merged or o.record_status = 'DANG_DUNG'
                   or (v_q is not null and o.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or o.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or o.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or o.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or o.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or o.channel_code = any (v_channel))
       and (v_campaign is null or o.campaign_id = v_campaign)
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and o.owner_id = auth.uid())
        or ('SUPPORT' = any (v_mine_roles) and o.supporter_id = auth.uid()))
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
       and (v_next_from is null or o.next_appointment_at >= v_next_from)
       and (v_next_to is null or o.next_appointment_at < v_next_to)
       and (v_next_before is null or o.next_appointment_at < v_next_before)
       and (not v_no_appt or o.next_appointment_at is null)
       and (cardinality(v_appt) = 0
        or ('OVERDUE' = any (v_appt) and o.next_appointment_at < v_day_start)
        or ('TODAY' = any (v_appt) and o.next_appointment_at >= v_day_start and o.next_appointment_at < v_day_end)
        or ('UPCOMING' = any (v_appt) and o.next_appointment_at >= v_day_end)
        or ('NONE' = any (v_appt) and o.next_appointment_at is null))
  ),
  page as (
    select * from f
     order by case when p_sort = 'created_asc' then f.created_at end asc,
              case when p_sort = 'next_appointment_asc' then f.next_appointment_at end asc nulls last,
              case when p_sort = 'name_asc' then (app.opp_first(f.id)).full_name end asc nulls last,
              f.created_at desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'lead_id', p.lead_id, 'lead_code', l.code,
             'parent_id', p.parent_id, 'parent_code', par.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
             'student_name', (app.opp_first(p.id)).full_name, 'student_birth_year', (app.opp_first(p.id)).birth_year,
             'stage_code', p.stage_code, 'substage_code', p.substage_code,
             'source_type_code', p.source_type_code, 'source_code', p.source_code, 'channel_code', p.channel_code,
             'campaign_id', p.campaign_id, 'campaign_name', c.name,
             'owner_id', p.owner_id, 'owner_name', app.staff_display_name(p.owner_id),
             'supporter_id', p.supporter_id, 'supporter_name', app.staff_display_name(p.supporter_id),
             'branch_code', b.code, 'assigned_at', p.assigned_at,
             'next_appointment_at', p.next_appointment_at, 'created_at', p.created_at,
             'record_status', p.record_status, 'merged_into_code', m.code)
             order by case when p_sort = 'created_asc' then p.created_at end asc,
                      case when p_sort = 'next_appointment_asc' then p.next_appointment_at end asc nulls last,
                      case when p_sort = 'name_asc' then (app.opp_first(p.id)).full_name end asc nulls last,
                      p.created_at desc, p.id), '[]'::jsonb))
    into v_result
    from page p
    join app.branch b on b.id = p.branch_id
    join app.parent par on par.id = p.parent_id
    join app.lead l on l.id = p.lead_id
    left join app.opportunity m on m.id = p.merged_into_id
    left join app.campaign c on c.id = p.campaign_id;
  return v_result;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Xuất lead: em đầu.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.export_leads(p_filters jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text := app.permission_scope('LEAD', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_channel text[] := array(select jsonb_array_elements_text(p_filters -> 'channel'));
  v_campaign uuid := nullif(p_filters ->> 'campaign_id', '')::uuid;
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
  v_only_merged boolean := coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false) or coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_appt text[] := array(select jsonb_array_elements_text(p_filters -> 'appointment'));
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Phạm vi dòng lấy từ quyền Xuất (không phải Xem): vai trò Xem toàn hệ thống nhưng Xuất trong cơ sở chỉ xuất được cơ sở mình.
  v_scope := app.permission_scope('LEAD', 'XUAT');
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất danh sách lead.');
  end if;
  select count(*) into v_total
    from app.lead l
     where (v_scope = 'TOAN_HE_THONG' or l.branch_id = v_my_branch)
       -- Bản "Đã gộp" ẩn khỏi danh sách mặc định nhưng vẫn tìm được bằng mã (R-CRM-22); "chỉ bản đã gộp" là bộ lọc riêng.
       and (case when v_only_merged then l.record_status = 'DA_GOP'
                 else (v_merged or l.record_status = 'DANG_DUNG'
                       or (v_q is not null and l.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or l.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or l.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or l.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or l.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or l.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or l.channel_code = any (v_channel))
       and (v_campaign is null or l.campaign_id = v_campaign)
       and (v_branch is null or l.branch_id = v_branch)
       and (v_owner is null or l.owner_id = v_owner)
       and (not v_mine or l.owner_id = auth.uid())
       and (not v_support_mine or l.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
            or ('OWNER' = any (v_mine_roles) and l.owner_id = auth.uid())
            or ('SUPPORT' = any (v_mine_roles) and l.supporter_id = auth.uid()))
       and (v_from is null or l.created_at >= v_from)
       and (v_to is null or l.created_at < v_to)
       and (v_next_from is null or l.next_appointment_at >= v_next_from)
       and (v_next_to is null or l.next_appointment_at < v_next_to)
       and (v_next_before is null or l.next_appointment_at < v_next_before)
       and (not v_no_appt or l.next_appointment_at is null)
       and (cardinality(v_appt) = 0
            or ('OVERDUE' = any (v_appt) and l.next_appointment_at < v_day_start)
            or ('TODAY' = any (v_appt) and l.next_appointment_at >= v_day_start and l.next_appointment_at < v_day_end)
            or ('UPCOMING' = any (v_appt) and l.next_appointment_at >= v_day_end)
            or ('NONE' = any (v_appt) and l.next_appointment_at is null))
;
  with f as (
    select l.*
      from app.lead l
     where (v_scope = 'TOAN_HE_THONG' or l.branch_id = v_my_branch)
       -- Bản "Đã gộp" ẩn khỏi danh sách mặc định nhưng vẫn tìm được bằng mã (R-CRM-22); "chỉ bản đã gộp" là bộ lọc riêng.
       and (case when v_only_merged then l.record_status = 'DA_GOP'
                 else (v_merged or l.record_status = 'DANG_DUNG'
                       or (v_q is not null and l.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or l.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or l.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or l.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or l.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or l.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or l.channel_code = any (v_channel))
       and (v_campaign is null or l.campaign_id = v_campaign)
       and (v_branch is null or l.branch_id = v_branch)
       and (v_owner is null or l.owner_id = v_owner)
       and (not v_mine or l.owner_id = auth.uid())
       and (not v_support_mine or l.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
            or ('OWNER' = any (v_mine_roles) and l.owner_id = auth.uid())
            or ('SUPPORT' = any (v_mine_roles) and l.supporter_id = auth.uid()))
       and (v_from is null or l.created_at >= v_from)
       and (v_to is null or l.created_at < v_to)
       and (v_next_from is null or l.next_appointment_at >= v_next_from)
       and (v_next_to is null or l.next_appointment_at < v_next_to)
       and (v_next_before is null or l.next_appointment_at < v_next_before)
       and (not v_no_appt or l.next_appointment_at is null)
       and (cardinality(v_appt) = 0
            or ('OVERDUE' = any (v_appt) and l.next_appointment_at < v_day_start)
            or ('TODAY' = any (v_appt) and l.next_appointment_at >= v_day_start and l.next_appointment_at < v_day_end)
            or ('UPCOMING' = any (v_appt) and l.next_appointment_at >= v_day_end)
            or ('NONE' = any (v_appt) and l.next_appointment_at is null))
     order by l.created_at desc, l.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', f.code, 'parent_name', f.parent_name, 'parent_phone', f.parent_phone,
           'student_name', (app.lead_first(f.id)).full_name, 'student_birth_year', (app.lead_first(f.id)).birth_year, 'school', (app.lead_first(f.id)).school, 'need', f.need,
           'source_type', st.name, 'source', so.name, 'channel', ch.name, 'campaign', ca.name,
           'stage', sg.name, 'substage', ss.name,
           'owner', app.staff_display_name(f.owner_id), 'supporter', app.staff_display_name(f.supporter_id),
           'branch', b.code, 'next_appointment_at', f.next_appointment_at, 'created_at', f.created_at,
           'record_status', f.record_status) order by f.created_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id
    left join app.catalog_item st on st.catalog_code = 'SOURCE_TYPE' and st.code = f.source_type_code
    left join app.catalog_item so on so.catalog_code = 'SOURCE' and so.code = f.source_code
    left join app.catalog_item ch on ch.catalog_code = 'SOURCE_CHANNEL' and ch.code = f.channel_code
    left join app.campaign ca on ca.id = f.campaign_id
    left join app.catalog_item sg on sg.catalog_code = 'LEAD_STAGE' and sg.code = f.stage_code
    left join app.catalog_item ss on ss.catalog_code = 'LEAD_SUBSTAGE' and ss.code = f.substage_code;
  -- Ghi nhật ký xuất TRƯỚC khi trả dữ liệu (cùng giao dịch): lỗi ở đây thì không có file.
  perform app.log_export('LEAD', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$function$;

-- ---------------------------------------------------------------------------
-- Xuất cơ hội: em đầu.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.export_opportunities(p_filters jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text;
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_stage text[] := array(select jsonb_array_elements_text(p_filters -> 'stage'));
  v_substage text[] := array(select jsonb_array_elements_text(p_filters -> 'substage'));
  v_type text[] := array(select jsonb_array_elements_text(p_filters -> 'source_type'));
  v_source text[] := array(select jsonb_array_elements_text(p_filters -> 'source'));
  v_channel text[] := array(select jsonb_array_elements_text(p_filters -> 'channel'));
  v_campaign uuid := nullif(p_filters ->> 'campaign_id', '')::uuid;
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
  v_only_merged boolean := coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_merged boolean := coalesce((p_filters ->> 'include_merged')::boolean, false) or coalesce((p_filters ->> 'only_merged')::boolean, false);
  v_appt text[] := array(select jsonb_array_elements_text(p_filters -> 'appointment'));
  v_mine_roles text[] := array(select jsonb_array_elements_text(p_filters -> 'mine_roles'));
  v_day_start timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  v_day_end timestamptz := (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day') at time zone 'Asia/Ho_Chi_Minh';
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Phạm vi dòng lấy từ quyền Xuất (không phải Xem): vai trò Xem toàn hệ thống nhưng Xuất trong cơ sở chỉ xuất được cơ sở mình.
  v_scope := app.permission_scope('OPPORTUNITY', 'XUAT');
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất danh sách cơ hội.');
  end if;
  select count(*) into v_total
    from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (case when v_only_merged then o.record_status = 'DA_GOP'
             else (v_merged or o.record_status = 'DANG_DUNG'
                   or (v_q is not null and o.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or o.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or o.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or o.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or o.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or o.channel_code = any (v_channel))
       and (v_campaign is null or o.campaign_id = v_campaign)
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and o.owner_id = auth.uid())
        or ('SUPPORT' = any (v_mine_roles) and o.supporter_id = auth.uid()))
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
       and (v_next_from is null or o.next_appointment_at >= v_next_from)
       and (v_next_to is null or o.next_appointment_at < v_next_to)
       and (v_next_before is null or o.next_appointment_at < v_next_before)
       and (not v_no_appt or o.next_appointment_at is null)
       and (cardinality(v_appt) = 0
        or ('OVERDUE' = any (v_appt) and o.next_appointment_at < v_day_start)
        or ('TODAY' = any (v_appt) and o.next_appointment_at >= v_day_start and o.next_appointment_at < v_day_end)
        or ('UPCOMING' = any (v_appt) and o.next_appointment_at >= v_day_end)
        or ('NONE' = any (v_appt) and o.next_appointment_at is null));
  with f as (
    select o.*
      from app.opportunity o
     where (v_scope = 'TOAN_HE_THONG' or o.branch_id = v_my_branch)
       and (case when v_only_merged then o.record_status = 'DA_GOP'
             else (v_merged or o.record_status = 'DANG_DUNG'
                   or (v_q is not null and o.code = upper(btrim(p_filters ->> 'q')))) end)
       and (v_q is null or o.search_text like '%' || v_q || '%')
       and (cardinality(v_stage) = 0 or o.stage_code = any (v_stage))
       and (cardinality(v_substage) = 0 or o.substage_code = any (v_substage))
       and (cardinality(v_type) = 0 or o.source_type_code = any (v_type))
       and (cardinality(v_source) = 0 or o.source_code = any (v_source))
       and (cardinality(v_channel) = 0 or o.channel_code = any (v_channel))
       and (v_campaign is null or o.campaign_id = v_campaign)
       and (v_branch is null or o.branch_id = v_branch)
       and (v_owner is null or o.owner_id = v_owner)
       and (not v_mine or o.owner_id = auth.uid())
       and (not v_support_mine or o.supporter_id = auth.uid())
       and (cardinality(v_mine_roles) = 0
        or ('OWNER' = any (v_mine_roles) and o.owner_id = auth.uid())
        or ('SUPPORT' = any (v_mine_roles) and o.supporter_id = auth.uid()))
       and (v_parent is null or o.parent_id = v_parent)
       and (v_lead is null or o.lead_id = v_lead)
       and (v_from is null or o.created_at >= v_from)
       and (v_to is null or o.created_at < v_to)
       and (v_next_from is null or o.next_appointment_at >= v_next_from)
       and (v_next_to is null or o.next_appointment_at < v_next_to)
       and (v_next_before is null or o.next_appointment_at < v_next_before)
       and (not v_no_appt or o.next_appointment_at is null)
       and (cardinality(v_appt) = 0
        or ('OVERDUE' = any (v_appt) and o.next_appointment_at < v_day_start)
        or ('TODAY' = any (v_appt) and o.next_appointment_at >= v_day_start and o.next_appointment_at < v_day_end)
        or ('UPCOMING' = any (v_appt) and o.next_appointment_at >= v_day_end)
        or ('NONE' = any (v_appt) and o.next_appointment_at is null))
     order by o.created_at desc, o.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', f.code, 'lead', l.code, 'parent_name', par.full_name, 'parent_phone', par.phone,
           'student_name', (app.opp_first(f.id)).full_name, 'student_birth_year', (app.opp_first(f.id)).birth_year, 'school', (app.opp_first(f.id)).school, 'need', f.need,
           'source_type', st.name, 'source', so.name, 'channel', ch.name, 'campaign', ca.name,
           'stage', sg.name, 'substage', ss.name,
           'owner', app.staff_display_name(f.owner_id), 'supporter', app.staff_display_name(f.supporter_id),
           'branch', b.code, 'next_appointment_at', f.next_appointment_at, 'created_at', f.created_at,
           'record_status', f.record_status) order by f.created_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id
    join app.parent par on par.id = f.parent_id
    join app.lead l on l.id = f.lead_id
    left join app.catalog_item st on st.catalog_code = 'SOURCE_TYPE' and st.code = f.source_type_code
    left join app.catalog_item so on so.catalog_code = 'SOURCE' and so.code = f.source_code
    left join app.catalog_item ch on ch.catalog_code = 'SOURCE_CHANNEL' and ch.code = f.channel_code
    left join app.campaign ca on ca.id = f.campaign_id
    left join app.catalog_item sg on sg.catalog_code = 'OPP_STAGE' and sg.code = f.stage_code
    left join app.catalog_item ss on ss.catalog_code = 'OPP_SUBSTAGE' and ss.code = f.substage_code;
  -- Ghi nhật ký xuất TRƯỚC khi trả dữ liệu (cùng giao dịch): lỗi ở đây thì không có file.
  perform app.log_export('OPPORTUNITY', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$function$;

-- ---------------------------------------------------------------------------
-- Lịch hẹn: nhãn hồ sơ lấy tên em đầu.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.export_appointments(p_filters jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text := app.permission_scope('APPOINTMENT', 'XUAT');
  v_my_branch uuid := app.current_branch_id();
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_activity text[] := array(select jsonb_array_elements_text(p_filters -> 'activity'));
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_mine boolean := coalesce((p_filters ->> 'mine')::boolean, false);
  v_lead uuid := nullif(p_filters ->> 'lead_id', '')::uuid;
  v_opp uuid := nullif(p_filters ->> 'opportunity_id', '')::uuid;
  v_test uuid := nullif(p_filters ->> 'student_test_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_kind text[] := array(select jsonb_array_elements_text(p_filters -> 'kind'));
  v_max integer := app.get_setting_int('export_max_rows');
  v_total bigint;
  v_rows jsonb;
  v_count integer;
begin
  -- Luật: quyền Xuất (phạm vi dòng lấy từ quyền Xuất, không phải Xem).
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất danh sách lịch hẹn.');
  end if;
  select count(*) into v_total
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
     and (v_owner is null or a.owner_id = v_owner)
     and (cardinality(v_kind) = 0
          or (case when a.lead_id is not null then 'LEAD' when a.opportunity_id is not null then 'OPPORTUNITY'
                   else 'STUDENT_TEST' end) = any (v_kind))
     and (v_q is null
          or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
          or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%'));
  with f as (
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
       and (v_owner is null or a.owner_id = v_owner)
       and (cardinality(v_kind) = 0
            or (case when a.lead_id is not null then 'LEAD' when a.opportunity_id is not null then 'OPPORTUNITY'
                     else 'STUDENT_TEST' end) = any (v_kind))
       and (v_q is null
            or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
            or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%'))
     order by a.scheduled_at desc, a.id
     limit v_max
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'kind', case when f.lead_id is not null then 'Lead' when f.opportunity_id is not null then 'Cơ hội' else 'Phiếu kiểm tra' end,
           'record_code', coalesce(l.code, o.code, t.code),
           'record_label', coalesce(l.parent_name || coalesce(' · ' || nullif((app.lead_first(l.id)).full_name, ''), ''),
                                    po.full_name || coalesce(' · ' || nullif((app.opp_first(o.id)).full_name, ''), ''),
                                    ts.full_name || ' · Phiếu kiểm tra'),
           'activity', ac.name, 'title', f.title, 'scheduled_at', f.scheduled_at,
           'status', app.appointment_group_label('status', f.status),
           'owner', app.staff_display_name(f.owner_id), 'branch', b.code,
           'auto_reminder', f.is_auto_reminder,
           'cancel_reason', cr.name, 'cancel_note', f.cancel_note, 'created_at', f.created_at)
           order by f.scheduled_at desc, f.id), '[]'::jsonb),
         count(*)::integer
    into v_rows, v_count
    from f
    join app.branch b on b.id = f.branch_id
    left join app.catalog_item ac on ac.catalog_code = 'ACTIVITY_TYPE' and ac.code = f.activity_code
    left join app.catalog_item cr on cr.catalog_code = 'APPOINTMENT_CANCEL_REASON' and cr.code = f.cancel_reason_code
    left join app.lead l on l.id = f.lead_id
    left join app.opportunity o on o.id = f.opportunity_id
    left join app.parent po on po.id = o.parent_id
    left join app.student_test t on t.id = f.student_test_id
    left join app.student ts on ts.id = t.student_id;
  -- Luật: ghi nhật ký xuất (ai, module, bộ lọc, số dòng).
  perform app.log_export('APPOINTMENT', p_filters, v_count);
  return jsonb_build_object('total', v_total, 'exported', v_count, 'truncated', v_total > v_count, 'rows', v_rows);
end;
$function$;

-- ---------------------------------------------------------------------------
-- Lịch hẹn: nhãn hồ sơ lấy tên em đầu.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.list_appointments(p_filters jsonb DEFAULT '{}'::jsonb, p_sort text DEFAULT 'time_asc'::text, p_limit integer DEFAULT NULL::integer, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  v_owner uuid := nullif(p_filters ->> 'owner_id', '')::uuid;
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_kind text[] := array(select jsonb_array_elements_text(p_filters -> 'kind'));
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
       and (v_owner is null or a.owner_id = v_owner)
       -- Loại hồ sơ gắn (Đ35, dùng khi mở một nhóm của Group By): LEAD, OPPORTUNITY hoặc STUDENT_TEST.
       and (cardinality(v_kind) = 0
            or (case when a.lead_id is not null then 'LEAD' when a.opportunity_id is not null then 'OPPORTUNITY'
                     else 'STUDENT_TEST' end) = any (v_kind))
       -- Tìm theo tên, SĐT, mã của hồ sơ gắn (lead hoặc cơ hội): dò hồ sơ bằng chỉ mục trigram trước, rồi nối về lịch hẹn.
       and (v_q is null
            or a.lead_id in (select l.id from app.lead l where l.search_text like '%' || v_q || '%')
            or a.opportunity_id in (select o.id from app.opportunity o where o.search_text like '%' || v_q || '%'))
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
             'lead_label', l.parent_name || coalesce(' · ' || nullif((app.lead_first(l.id)).full_name, ''), ''),
             'opportunity_id', p.opportunity_id, 'opportunity_code', o.code,
             'student_test_id', p.student_test_id, 'student_test_code', t.code, 'is_auto_reminder', p.is_auto_reminder,
             'record_code', coalesce(l.code, o.code, t.code),
             'record_label', coalesce(l.parent_name || coalesce(' · ' || nullif((app.lead_first(l.id)).full_name, ''), ''),
                                      po.full_name || coalesce(' · ' || nullif((app.opp_first(o.id)).full_name, ''), ''),
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
$function$;

-- ---------------------------------------------------------------------------
-- Tìm liên hệ trùng: nhãn lead lấy tên em đầu.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.find_duplicate_contacts(p_phone text, p_exclude_lead_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(kind text, id uuid, code text, label text, branch_code text, visible boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_phone text := app.normalize_phone(p_phone);
begin
  if app.permission_scope('LEAD', 'TAO') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền tạo lead.');
  end if;
  if v_phone !~ '^0[0-9]{9}$' then
    return;
  end if;
  return query
    select * from (
      select 'LEAD'::text as kind, l.id as id, l.code as code,
             case when app.can_see_branch('LEAD', 'XEM', l.branch_id)
                  then l.parent_name || coalesce(' · ' || nullif((app.lead_first(l.id)).full_name, ''), '') end as label,
             b.code as branch_code, app.can_see_branch('LEAD', 'XEM', l.branch_id) as visible
        from app.lead l join app.branch b on b.id = l.branch_id
       where l.parent_phone = v_phone and l.record_status = 'DANG_DUNG' and l.id is distinct from p_exclude_lead_id
      union all
      select 'PARENT'::text, r.id, r.code,
             case when app.can_see_branch('PARENT', 'XEM', r.branch_id)
                  then r.full_name || ' · ' || (select count(*) from app.student s where s.parent_id = r.id and s.record_status = 'DANG_DUNG') || ' con' end,
             b.code, app.can_see_branch('PARENT', 'XEM', r.branch_id)
        -- Hồ sơ đã gộp thì trỏ về bản giữ lại (R-CRM-25): số điện thoại vẫn báo trùng, nhưng với hồ sơ còn dùng.
        from (select distinct coalesce(p.merged_into_id, p.id) as rid from app.parent p where p.phone = v_phone) x
        join app.parent r on r.id = x.rid
        join app.branch b on b.id = r.branch_id
    ) q
    order by q.kind, q.code
    limit app.get_setting_int('search_result_max');
end;
$function$;

-- ---------------------------------------------------------------------------
-- Gợi ý bản trùng: tên và so sánh học sinh dựa trên em đầu (hành vi cũ).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.merge_candidates(p_entity text, p_id uuid)
 RETURNS TABLE(id uuid, code text, label text, branch_code text, stage_code text, created_at timestamp with time zone, can_merge boolean, blocker_code text, blocker_message text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_scope text;
  v_cur uuid := app.current_branch_id();
  v_max integer := app.get_setting_int('merge_preview_max_items');
  v_phone text;
  v_parent uuid;
  v_student uuid;
  v_student_name text;
  v_student_year integer;
  v_branch uuid;
  v_status text;
begin
  if p_entity not in ('LEAD', 'OPPORTUNITY') then
    perform app.raise_error('HMT_LOAI_BAN_GHI_SAI', 'Chỉ gợi ý bản trùng cho lead và cơ hội.');
  end if;
  -- Luật R-CRM-22: quyền Duyệt (gộp).
  v_scope := app.permission_scope(p_entity, 'DUYET');
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền gộp loại hồ sơ này.');
  end if;

  if p_entity = 'LEAD' then
    select l.parent_phone, l.branch_id, l.record_status into v_phone, v_branch, v_status from app.lead l where l.id = p_id;
  else
    select o.parent_id, (app.opp_first(o.id)).student_id, (app.opp_first(o.id)).full_name, (app.opp_first(o.id)).birth_year, o.branch_id, o.record_status
      into v_parent, v_student, v_student_name, v_student_year, v_branch, v_status from app.opportunity o where o.id = p_id;
  end if;
  -- Hồ sơ gốc ngoài phạm vi xem được coi như không có (không lộ sự tồn tại).
  if v_branch is null or not app.can_see_branch(p_entity, 'XEM', v_branch) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy hồ sơ.');
  end if;
  if v_status <> 'DANG_DUNG' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Hồ sơ này đã gộp vào bản khác, không gộp tiếp được.');
  end if;

  if p_entity = 'LEAD' then
    return query
      select l.id, l.code, l.parent_name || coalesce(' · ' || nullif((app.lead_first(l.id)).full_name, ''), ''), b.code, l.stage_code, l.created_at,
             x.blocker is null, x.blocker, x.msg
        from app.lead l
        join app.branch b on b.id = l.branch_id
        cross join lateral (
          -- Luật R-CRM-22: khác cơ sở thì chỉ phạm vi toàn hệ thống gộp được.
          select case when v_scope <> 'TOAN_HE_THONG' and (v_branch is distinct from v_cur or l.branch_id is distinct from v_cur)
                      then case when v_branch is distinct from l.branch_id then 'HMT_GOP_KHAC_CO_SO' else 'HMT_KHONG_CO_QUYEN' end end as blocker,
                 case when v_scope <> 'TOAN_HE_THONG' and (v_branch is distinct from v_cur or l.branch_id is distinct from v_cur)
                      then case when v_branch is distinct from l.branch_id
                                then 'Hai hồ sơ thuộc hai cơ sở khác nhau: chỉ Admin gộp được.'
                                else 'Bạn không có quyền gộp hồ sơ của cơ sở khác.' end end as msg) x
       where l.parent_phone = v_phone and l.id <> p_id and l.record_status = 'DANG_DUNG'
         and app.can_see_branch('LEAD', 'XEM', l.branch_id)
       order by l.created_at desc, l.id
       limit v_max;
  else
    return query
      select o.id, o.code, p.full_name || coalesce(' · ' || nullif((app.opp_first(o.id)).full_name, ''), ''), b.code, o.stage_code, o.created_at,
             x.blocker is null, x.blocker, x.msg
        from app.opportunity o
        join app.parent p on p.id = o.parent_id
        join app.branch b on b.id = o.branch_id
        cross join lateral (
          -- Luật R-CRM-22 (cơ sở) rồi R-CRM-37a (khác học sinh thì gộp học sinh trước).
          select case
                   when v_scope <> 'TOAN_HE_THONG' and (v_branch is distinct from v_cur or o.branch_id is distinct from v_cur)
                     then case when v_branch is distinct from o.branch_id then 'HMT_GOP_KHAC_CO_SO' else 'HMT_KHONG_CO_QUYEN' end
                   when (v_student is not null and (app.opp_first(o.id)).student_id is not null and v_student <> (app.opp_first(o.id)).student_id)
                        or (v_student_name is not null and v_student_year is not null and (app.opp_first(o.id)).full_name is not null
                            and (app.opp_first(o.id)).birth_year is not null
                            and (app.normalize_person_name(v_student_name) <> app.normalize_person_name((app.opp_first(o.id)).full_name)
                                 or v_student_year <> (app.opp_first(o.id)).birth_year))
                     then 'HMT_GOP_KHAC_HOC_SINH' end as blocker,
                 case
                   when v_scope <> 'TOAN_HE_THONG' and (v_branch is distinct from v_cur or o.branch_id is distinct from v_cur)
                     then case when v_branch is distinct from o.branch_id then 'Hai hồ sơ thuộc hai cơ sở khác nhau: chỉ Admin gộp được.'
                               else 'Bạn không có quyền gộp hồ sơ của cơ sở khác.' end
                   when (v_student is not null and (app.opp_first(o.id)).student_id is not null and v_student <> (app.opp_first(o.id)).student_id)
                        or (v_student_name is not null and v_student_year is not null and (app.opp_first(o.id)).full_name is not null
                            and (app.opp_first(o.id)).birth_year is not null
                            and (app.normalize_person_name(v_student_name) <> app.normalize_person_name((app.opp_first(o.id)).full_name)
                                 or v_student_year <> (app.opp_first(o.id)).birth_year))
                     then 'Hai cơ hội khác học sinh: gộp học sinh trước.' end as msg) x
       where o.parent_id = v_parent and o.id <> p_id and o.record_status = 'DANG_DUNG'
         and app.can_see_branch('OPPORTUNITY', 'XEM', o.branch_id)
       order by o.created_at desc, o.id
       limit v_max;
  end if;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Điều kiện gộp cơ hội: so học sinh qua em đầu (hành vi cũ, R-CRM-37a).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.merge_check_opportunities(p_keep uuid, p_merge uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  k app.opportunity;
  m app.opportunity;
  v_blockers jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_docs text[];
  v_ko integer;
  v_mo integer;
begin
  select * into k from app.opportunity where id = p_keep;
  select * into m from app.opportunity where id = p_merge;
  -- Luật R-CRM-37(a): cùng phụ huynh.
  if k.parent_id <> m.parent_id then
    v_blockers := v_blockers || jsonb_build_object('code', 'HMT_GOP_KHAC_PHU_HUYNH',
      'message', 'Hai cơ hội khác phụ huynh: gộp phụ huynh trước.');
  end if;
  -- Luật R-CRM-37(a): học sinh không khác nhau. Có hồ sơ học sinh cả hai bên mà khác nhau, hoặc cả hai bên đã ghi tên và năm
  -- sinh mà khác nhau, thì gộp học sinh trước. Một bên chưa có học sinh thì lấy của bên kia (không chặn).
  if ((app.opp_first(k.id)).student_id is not null and (app.opp_first(m.id)).student_id is not null and (app.opp_first(k.id)).student_id <> (app.opp_first(m.id)).student_id)
     or ((app.opp_first(k.id)).full_name is not null and (app.opp_first(k.id)).birth_year is not null and (app.opp_first(m.id)).full_name is not null
         and (app.opp_first(m.id)).birth_year is not null
         and (app.normalize_person_name((app.opp_first(k.id)).full_name) <> app.normalize_person_name((app.opp_first(m.id)).full_name)
              or (app.opp_first(k.id)).birth_year <> (app.opp_first(m.id)).birth_year)) then
    v_blockers := v_blockers || jsonb_build_object('code', 'HMT_GOP_KHAC_HOC_SINH',
      'message', 'Hai cơ hội khác học sinh: gộp học sinh trước.');
  end if;
  -- Luật R-CRM-22: chặn gộp cơ hội nếu bản bị gộp đã có báo giá hoặc đơn hàng (nêu rõ mã).
  v_docs := app.opportunity_sales_documents(p_merge);
  if cardinality(v_docs) > 0 then
    v_blockers := v_blockers || jsonb_build_object('code', 'HMT_GOP_CO_BAO_GIA_DON',
      'message', format('Cơ hội %s đã có báo giá hoặc đơn hàng (%s): không gộp được.', m.code, array_to_string(v_docs, ', ')));
  end if;
  -- Cảnh báo: giai đoạn bản bị gộp cao hơn bản giữ lại; giai đoạn bản giữ lại giữ nguyên (R-CRM-02), người dùng cân nhắc chọn lại.
  select sort_order into v_ko from app.catalog_item where catalog_code = 'OPP_STAGE' and code = k.stage_code;
  select sort_order into v_mo from app.catalog_item where catalog_code = 'OPP_STAGE' and code = m.stage_code;
  if v_mo > v_ko then
    v_warnings := v_warnings || jsonb_build_object('code', 'HMT_GOP_GIAI_DOAN_CAO_HON',
      'message', format('Cơ hội bị gộp (%s) đang ở giai đoạn %s, cao hơn bản giữ lại (%s, %s). Giai đoạn của bản giữ lại giữ nguyên; cân nhắc chọn bản giữ lại khác.',
                        m.code, m.stage_code, k.code, k.stage_code));
  end if;
  return jsonb_build_object('blockers', v_blockers, 'warnings', v_warnings);
end;
$function$;

-- ---------------------------------------------------------------------------
-- Xem trước gộp: tên em đầu.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.merge_side(p_entity text, p_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select case when p_entity = 'LEAD' then
    (select jsonb_build_object(
        'code', l.code, 'parent_name', l.parent_name, 'phone', l.parent_phone, 'student_name', (app.lead_first(l.id)).full_name,
        'source', (select c.name from app.catalog_item c where c.catalog_code = l.source_catalog and c.code = l.source_code),
        'owner', (select u.display_name from app.user_account u where u.id = l.owner_id),
        'branch_code', (select b.code from app.branch b where b.id = l.branch_id), 'created_at', l.created_at,
        'opportunities', (select count(*) from app.opportunity o where o.lead_id = l.id),
        'appointments', (select count(*) from app.appointment a where a.lead_id = l.id),
        'notes', (select count(*) from app.note n where n.entity_type = 'LEAD' and n.entity_id = l.id))
       from app.lead l where l.id = p_id)
  else
    (select jsonb_build_object(
        'code', o.code, 'parent_name', p.full_name, 'phone', p.phone, 'student_name', (app.opp_first(o.id)).full_name, 'stage_code', o.stage_code,
        'owner', (select u.display_name from app.user_account u where u.id = o.owner_id),
        'branch_code', (select b.code from app.branch b where b.id = o.branch_id), 'created_at', o.created_at,
        'tests', (select count(*) from app.student_test t where t.opportunity_id = o.id),
        'appointments', (select count(*) from app.appointment a where a.opportunity_id = o.id),
        'notes', (select count(*) from app.note n where n.entity_type = 'OPPORTUNITY' and n.entity_id = o.id))
       from app.opportunity o join app.parent p on p.id = o.parent_id where o.id = p_id)
  end;
$function$;

-- ---------------------------------------------------------------------------
-- Xem trước gộp học sinh: đếm các dòng em của cơ hội gắn học sinh bị gộp.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.merge_preview(p_entity text, p_keep uuid, p_merge uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_info jsonb := app.merge_common(p_entity, p_keep, p_merge);
  v_check jsonb := '{"blockers": [], "warnings": []}'::jsonb;
  v_move jsonb;
  v_extra jsonb := '{}'::jsonb;
begin
  if p_entity = 'LEAD' then
    v_move := jsonb_build_object(
      'appointments', (select count(*) from app.appointment where lead_id = p_merge),
      'notes', (select count(*) from app.note where entity_type = 'LEAD' and entity_id = p_merge),
      'opportunities', (select count(*) from app.opportunity where lead_id = p_merge));
  elsif p_entity = 'OPPORTUNITY' then
    v_check := app.merge_check_opportunities(p_keep, p_merge);
    v_move := jsonb_build_object(
      'appointments', (select count(*) from app.appointment where opportunity_id = p_merge),
      'notes', (select count(*) from app.note where entity_type = 'OPPORTUNITY' and entity_id = p_merge),
      'tests', (select count(*) from app.student_test where opportunity_id = p_merge));
  elsif p_entity = 'STUDENT' then
    v_check := app.merge_check_students(p_keep, p_merge);
    v_move := jsonb_build_object(
      'opportunities', (select count(*) from app.prospect_student where student_id = p_merge and opportunity_id is not null),
      'tests', (select count(*) from app.student_test where student_id = p_merge),
      'notes', (select count(*) from app.note where entity_type = 'STUDENT' and entity_id = p_merge));
  else
    v_move := jsonb_build_object(
      'leads', (select count(*) from app.lead where parent_id = p_merge),
      'opportunities', (select count(*) from app.opportunity where parent_id = p_merge),
      'students', (select count(*) from app.student where parent_id = p_merge),
      'notes', (select count(*) from app.note where entity_type = 'PARENT' and entity_id = p_merge));
  end if;
  -- Hộp TS-10 (lead, cơ hội): so sánh hai bên và liệt kê mục sẽ chuyển.
  if p_entity in ('LEAD', 'OPPORTUNITY') then
    v_extra := jsonb_build_object(
      'sides', jsonb_build_object('keep', app.merge_side(p_entity, p_keep), 'merge', app.merge_side(p_entity, p_merge)),
      'items', app.merge_items(p_entity, p_merge));
  end if;
  return v_info || jsonb_build_object('move', v_move) || v_check || v_extra;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Gộp học sinh: các dòng em trỏ sang học sinh giữ lại.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.merge_students(p_keep uuid, p_merge uuid, p_confirm boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_info jsonb := app.merge_common('STUDENT', p_keep, p_merge, true);
  m app.student;
  v_opps integer;
  v_tests integer;
  v_notes integer;
begin
  perform app.merge_raise_first_blocker(app.merge_check_students(p_keep, p_merge));
  perform app.merge_require_confirm(p_confirm);
  select * into m from app.student where id = p_merge;
  -- Danh sách em: dòng gắn học sinh bị gộp trỏ sang học sinh giữ lại (dòng chỉ đọc từ hồ sơ, không giữ bản sao).
  update app.prospect_student set student_id = p_keep where student_id = p_merge;
  get diagnostics v_opps = row_count;
  update app.student_test set student_id = p_keep where student_id = p_merge;
  get diagnostics v_tests = row_count;
  v_notes := app.move_notes('STUDENT', p_merge, p_keep);
  update app.student set birth_date = coalesce(birth_date, m.birth_date), school = coalesce(school, m.school),
         self_rating = coalesce(self_rating, m.self_rating), goal = coalesce(goal, m.goal)
   where id = p_keep;
  update app.student set merged_into_id = p_keep where merged_into_id = p_merge;
  update app.student set record_status = 'DA_GOP', merged_into_id = p_keep where id = p_merge;
  perform app.merge_write_notes('STUDENT', p_keep, p_merge, v_info);
  return v_info || jsonb_build_object('moved', jsonb_build_object('opportunities', v_opps, 'tests', v_tests, 'notes', v_notes));
end;
$function$;

-- ---------------------------------------------------------------------------
-- Tạo phiếu kiểm tra: dùng em đầu của danh sách em; gắn hồ sơ học sinh vào dòng em.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.create_student_test(p_opportunity_id uuid, p_data jsonb, p_reminder_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_reminder_activity text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  v_line app.prospect_student_v;
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
  -- Danh sách em: phiếu dùng em đầu của cơ hội (hành vi cũ; chọn em trong danh sách làm ở DB-2).
  select * into v_line from app.prospect_student_v where opportunity_id = v_opp.id order by position limit 1;
  v_student_id := v_line.student_id;
  if v_student_id is null then
    v_student_id := app.find_or_create_student(v_opp.parent_id, v_line.full_name, v_line.birth_year,
                                               v_line.birth_date, v_line.school, v_line.self_rating, v_line.goal,
                                               v_opp.branch_id);
    -- Dòng em gắn hồ sơ học sinh vừa tìm hoặc tạo; từ đây đọc thẳng từ hồ sơ (Đ86).
    update app.prospect_student set student_id = v_student_id, full_name = null, birth_date = null, birth_year = null,
           school = null, self_rating = null, goal = null where id = v_line.id;
  end if;
  select code into v_student_code from app.student where id = v_student_id;

  v_code := app.issue_crm_code('PKT');
  insert into app.student_test (
    code, opportunity_id, student_id, branch_id, test_branch_id, created_branch_id, subject_code, grade_code, mode_code,
    level_code, exam_name, scheduled_at, room_id, grader_id, owner_id, prospect_student_id)
  values (
    v_code, v_opp.id, v_student_id, v_opp.branch_id, v_test_branch, coalesce(app.current_branch_id(), v_opp.branch_id),
    v_subject, v_grade, v_mode, v_level, nullif(btrim(coalesce(p_data ->> 'exam_name', '')), ''), v_scheduled, v_room,
    v_grader, v_owner, v_line.id)
  returning id into v_id;

  -- Luật R-CRM-05: tự sinh lịch hẹn nhắc cùng phiếu.
  perform app.ensure_test_reminder(v_id, p_reminder_at, p_reminder_activity);
  -- Luật R-CRM-15: cơ hội đang ở L5 thì nhóm con tính lại (có phiếu Nháp → L5B).
  perform app.refresh_opportunity_l5_substage(v_opp.id);

  return jsonb_build_object('id', v_id, 'code', v_code, 'student_id', v_student_id, 'student_code', v_student_code);
end;
$function$;

-- ---------------------------------------------------------------------------
-- Tạo lead: thông tin học sinh ghi vào dòng 1 của danh sách em.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.create_lead(p_data jsonb, p_confirm_duplicate boolean DEFAULT false, p_parent_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v app.lead;
  v_parent app.parent;
  v_dup integer;
  v_id uuid;
  v_code text;
begin
  v := jsonb_populate_record(null::app.lead, p_data);
  v.parent_phone := app.normalize_phone(p_data ->> 'parent_phone');
  v.branch_id := coalesce(v.branch_id, app.current_branch_id());

  -- Luật: thông tin bắt buộc (TS-03).
  if btrim(coalesce(v.parent_name, '')) = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập họ tên phụ huynh.');
  end if;
  if v.parent_phone !~ '^0[0-9]{9}$' then
    perform app.raise_error('HMT_SDT_SAI', 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.');
  end if;
  if v.branch_id is null then
    perform app.raise_error('HMT_THIEU_CO_SO', 'Chọn cơ sở của lead.');
  end if;

  -- Luật: quyền tạo lead ở cơ sở này.
  perform app.assert_can('LEAD', 'TAO', v.branch_id);

  -- Luật: người phụ trách mặc định là người tạo; giao cho người khác cần quyền Giao việc (R-CRM, TS-05).
  v.owner_id := coalesce(v.owner_id, auth.uid());
  if v.owner_id <> auth.uid() then
    perform app.assert_can('LEAD', 'GIAO_VIEC', v.branch_id);
  end if;
  perform app.assert_staff_in_branch(v.owner_id, v.branch_id);
  if v.supporter_id is not null then
    perform app.assert_staff_in_branch(v.supporter_id, v.branch_id);
  end if;

  -- Luật: nguồn bắt buộc loại và nguồn; kênh bắt buộc khi nguồn có kênh con (spec 06 mục 1.1).
  if v.source_type_code is null or v.source_code is null then
    perform app.raise_error('HMT_THIEU_NGUON', 'Chọn loại nguồn và nguồn của lead.');
  end if;
  if v.channel_code is null and exists (
       select from app.catalog_item c join app.catalog_item s on s.id = c.parent_id
        where c.catalog_code = 'SOURCE_CHANNEL' and c.is_active and s.catalog_code = 'SOURCE' and s.code = v.source_code) then
    perform app.raise_error('HMT_THIEU_NGUON', 'Chọn kênh (sub-source) của nguồn này.');
  end if;
  if v.campaign_id is not null and not exists (select from app.campaign where id = v.campaign_id and is_active) then
    perform app.raise_error('HMT_CHIEN_DICH_SAI', 'Chiến dịch không có hoặc đã ngừng.');
  end if;

  -- Luật: phụ huynh có sẵn được chọn gắn vào phải nhìn thấy được.
  if p_parent_id is not null then
    select * into v_parent from app.parent where id = p_parent_id;
    if v_parent.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh để gắn vào.');
    end if;
    perform app.assert_can('PARENT', 'XEM', v_parent.branch_id);
  end if;

  -- Luật: số điện thoại đã có lead hoặc phụ huynh thì phải xác nhận lần hai (TS-03, TS-14), trừ khi gắn vào hồ sơ có sẵn.
  if p_parent_id is null and not coalesce(p_confirm_duplicate, false) then
    select (select count(*) from app.lead where parent_phone = v.parent_phone and record_status = 'DANG_DUNG')
         + (select count(*) from app.parent where phone = v.parent_phone) into v_dup;
    if v_dup > 0 then
      perform app.raise_error('HMT_SDT_TRUNG', 'Số điện thoại này đã có hồ sơ. Gắn vào hồ sơ có sẵn hoặc xác nhận vẫn tạo mới.');
    end if;
  end if;

  v_code := app.issue_crm_code('LD');
  insert into app.lead (
    code, parent_name, parent_phone, ward_code, province_code, address, need,
    parent_id, branch_id, owner_id, supporter_id, source_type_code, source_code, channel_code, campaign_id,
    stage_code, substage_code, legacy_ref)
  values (
    v_code, btrim(v.parent_name), v.parent_phone, v.ward_code, v.province_code, v.address, v.need,
    p_parent_id, v.branch_id, v.owner_id, v.supporter_id, v.source_type_code, v.source_code, v.channel_code, v.campaign_id,
    'C1', null, v.legacy_ref)
  returning id into v_id;

  -- Danh sách em (Đ81): nhập nhanh vẫn một em, ghi vào dòng 1.
  perform app.set_first_prospect('LEAD', v_id, p_data);

  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$function$;

-- ---------------------------------------------------------------------------
-- Sửa lead: thông tin học sinh ghi vào em đầu của danh sách em.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.update_lead(p_id uuid, p_data jsonb, p_confirm_duplicate boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_old app.lead;
  v app.lead;
begin
  select * into v_old from app.lead where id = p_id;
  if v_old.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead.');
  end if;
  perform app.assert_can('LEAD', 'SUA', v_old.branch_id);
  if v_old.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Lead này đã gộp vào bản khác, chỉ xem được.');
  end if;

  v := jsonb_populate_record(v_old, p_data);
  v.parent_phone := app.normalize_phone(v.parent_phone);

  if btrim(coalesce(v.parent_name, '')) = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập họ tên phụ huynh.');
  end if;
  if v.parent_phone !~ '^0[0-9]{9}$' then
    perform app.raise_error('HMT_SDT_SAI', 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.');
  end if;
  if v.supporter_id is not null and v.supporter_id is distinct from v_old.supporter_id then
    perform app.assert_staff_in_branch(v.supporter_id, v_old.branch_id);
  end if;
  if v.source_type_code is null or v.source_code is null then
    perform app.raise_error('HMT_THIEU_NGUON', 'Chọn loại nguồn và nguồn của lead.');
  end if;
  if v.channel_code is null and exists (
       select from app.catalog_item c join app.catalog_item s on s.id = c.parent_id
        where c.catalog_code = 'SOURCE_CHANNEL' and c.is_active and s.catalog_code = 'SOURCE' and s.code = v.source_code) then
    perform app.raise_error('HMT_THIEU_NGUON', 'Chọn kênh (sub-source) của nguồn này.');
  end if;
  -- Luật: đổi số điện thoại sang số đã có hồ sơ thì xác nhận lần hai.
  if v.parent_phone <> v_old.parent_phone and not coalesce(p_confirm_duplicate, false)
     and (exists (select from app.lead where parent_phone = v.parent_phone and record_status = 'DANG_DUNG' and id <> p_id)
          or exists (select from app.parent where phone = v.parent_phone)) then
    perform app.raise_error('HMT_SDT_TRUNG', 'Số điện thoại này đã có hồ sơ. Xác nhận nếu vẫn muốn dùng số này.');
  end if;

  update app.lead set
    parent_name = btrim(v.parent_name), parent_phone = v.parent_phone, ward_code = v.ward_code,
    province_code = v.province_code, address = v.address, need = v.need,
    supporter_id = v.supporter_id, source_type_code = v.source_type_code, source_code = v.source_code,
    channel_code = v.channel_code, campaign_id = v.campaign_id
   where id = p_id;
  -- Danh sách em: thông tin học sinh kiểu cũ ghi vào em đầu.
  perform app.set_first_prospect('LEAD', p_id, p_data);
end;
$function$;

-- ---------------------------------------------------------------------------
-- Tạo cơ hội từ lead: em đầu của lead chép sang danh sách em của cơ hội.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.create_opportunity(p_lead_id uuid, p_data jsonb DEFAULT '{}'::jsonb, p_confirm_existing boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_lead app.lead;
  v app.opportunity;
  v_existing text;
  v_parent_id uuid;
  v_parent_code text;
  v_owner uuid;
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

  v_code := app.issue_crm_code('CO');
  insert into app.opportunity (
    code, lead_id, parent_id, branch_id, owner_id, supporter_id, need,
    source_type_code, source_code, channel_code, campaign_id, stage_code, substage_code)
  values (
    v_code, p_lead_id, v_parent_id, v_lead.branch_id, v_owner, coalesce(v.supporter_id, v_lead.supporter_id),
    case when p_data ? 'need' then v.need else v_lead.need end,
    v_lead.source_type_code, v_lead.source_code, v_lead.channel_code, v_lead.campaign_id, 'L1', null)
  returning id into v_id;

  -- Danh sách em (Đ81): em đầu của lead chép sang cơ hội; ô nào p_data có thì lấy, không thì chép từ lead.
  -- (Chọn nhiều em từ lead đưa sang làm ở DB-2.) Có ngày sinh mà không có năm sinh thì năm lấy từ ngày sinh.
  perform app.set_first_prospect('OPPORTUNITY', v_id,
    (select jsonb_strip_nulls(jsonb_build_object('student_name', f.full_name, 'student_birth_date', f.birth_date,
                               'student_birth_year', case when p_data ? 'student_birth_date' and not p_data ? 'student_birth_year'
                                                          then null else f.birth_year end,
                               'school', f.school, 'self_rating', f.self_rating, 'goal', f.goal))
       from (select (app.lead_first(p_lead_id)).*) f)
    || coalesce((select jsonb_object_agg(k, p_data -> k)
                   from unnest(array['student_name', 'student_birth_date', 'student_birth_year', 'school', 'self_rating', 'goal']) k
                  where p_data ? k), '{}'::jsonb),
    true);

  -- Luật R-CRM-09: lead tự về C4D "Tạo cơ hội thành công" (người dùng không chọn được nhóm con này) và nhận phụ huynh.
  update app.lead set stage_code = 'C4', substage_code = 'C4D', parent_id = v_parent_id where id = p_lead_id;

  return jsonb_build_object('id', v_id, 'code', v_code, 'parent_id', v_parent_id, 'parent_code', v_parent_code);
end;
$function$;

-- ---------------------------------------------------------------------------
-- Sửa cơ hội: thông tin học sinh kiểu cũ ghi vào em đầu của danh sách em.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.update_opportunity(p_id uuid, p_data jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_old app.opportunity;
  v app.opportunity;
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
  if v.supporter_id is not null and v.supporter_id is distinct from v_old.supporter_id then
    perform app.assert_staff_in_branch(v.supporter_id, v_old.branch_id);
  end if;

  -- Luật R-CRM-03 (kiểm lại ở trigger): từ L5 trở lên tên và năm sinh học sinh không được trống.
  update app.opportunity set need = v.need, supporter_id = v.supporter_id where id = p_id;
  -- Danh sách em: thông tin học sinh kiểu cũ ghi vào em đầu. Luật R-CRM-26, 27 (em đã gắn hồ sơ học sinh thì sửa luôn hồ sơ đó)
  -- và R-CRM-03 (từ L5 trở lên không được xoá tên, năm sinh) nằm trong app.set_first_prospect.
  perform app.set_first_prospect('OPPORTUNITY', p_id, p_data, true);
end;
$function$;

-- ---------------------------------------------------------------------------
-- Đổi giai đoạn cơ hội: R-CRM-03 kiểm tên, năm sinh của em đầu.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.change_opportunity_stage(p_id uuid, p_stage_code text, p_substage_code text DEFAULT NULL::text, p_skip_reason_code text DEFAULT NULL::text, p_skip_note text DEFAULT NULL::text, p_confirm_l8 boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_opp app.opportunity;
  v_old_order integer;
  v_new_order integer;
  v_l5_order integer;
  v_state record;
  v_missing text[] := array[]::text[];
  v_first app.prospect_student_v;
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
    -- Em đầu của danh sách em (hành vi cũ; "ít nhất một em đủ tên và năm sinh" làm ở DB-2).
    select * into v_first from app.prospect_student_v where opportunity_id = p_id order by position limit 1;
    if v_first.full_name is null then
      v_missing := array_append(v_missing, 'tên học sinh');
    end if;
    if v_first.birth_year is null then
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
$function$;

-- ---------------------------------------------------------------------------
-- Trigger cơ hội: R-CRM-03 kiểm tên, năm sinh của em đầu.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.tg_opportunity_checks()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
  v_old_order integer;
  v_new_order integer;
  v_l5_order integer;
  v_first app.prospect_student_v;
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
    if v_new_order >= v_l5_order then
      select * into v_first from app.prospect_student_v where opportunity_id = new.id order by position limit 1;
    end if;
    if v_new_order >= v_l5_order and (v_first.full_name is null or v_first.birth_year is null) then
      perform app.raise_error('HMT_THIEU_HOC_SINH',
        'Từ giai đoạn L5 trở lên cơ hội bắt buộc có tên và năm sinh của học sinh.');
    end if;
  end if;
  return new;
end;
$function$;

-- ---------------------------------------------------------------------------
-- Gộp cơ hội: danh sách em (hành vi cũ, một em mỗi bên).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.merge_opportunities(p_keep uuid, p_merge uuid, p_confirm boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_info jsonb := app.merge_common('OPPORTUNITY', p_keep, p_merge, true);
  v_check jsonb := app.merge_check_opportunities(p_keep, p_merge);
  m app.opportunity;
  v_appt integer;
  v_notes integer;
  v_tests integer;
  v_keep_line uuid;
  v_merge_line uuid;
  k_first app.prospect_student_v;
  m_first app.prospect_student_v;
begin
  perform app.merge_raise_first_blocker(v_check);
  perform app.merge_require_confirm(p_confirm);
  select * into m from app.opportunity where id = p_merge;
  update app.appointment set opportunity_id = p_keep where opportunity_id = p_merge;
  get diagnostics v_appt = row_count;
  v_notes := app.move_notes('OPPORTUNITY', p_merge, p_keep);
  -- Danh sách em (hành vi cũ: mỗi bên một em). Bản giữ lại chưa có em thì nhận dòng em của bản kia; có rồi thì ô còn trống của
  -- dòng giữ lại lấy của dòng kia (R-CRM-37a: một bên chưa có học sinh thì lấy học sinh của bên kia).
  select id into v_keep_line from app.prospect_student where opportunity_id = p_keep order by position limit 1;
  select id into v_merge_line from app.prospect_student where opportunity_id = p_merge order by position limit 1;
  if v_merge_line is not null then
    if v_keep_line is null then
      update app.prospect_student set opportunity_id = p_keep where id = v_merge_line;
    else
      select * into k_first from app.prospect_student_v where id = v_keep_line;
      select * into m_first from app.prospect_student_v where id = v_merge_line;
      if k_first.student_id is null and m_first.student_id is not null then
        update app.prospect_student set student_id = m_first.student_id, full_name = null, birth_date = null, birth_year = null,
               school = null, self_rating = null, goal = null where id = v_keep_line;
      elsif k_first.student_id is null then
        update app.prospect_student set full_name = coalesce(full_name, m_first.full_name),
               birth_date = coalesce(birth_date, m_first.birth_date), birth_year = coalesce(birth_year, m_first.birth_year),
               school = coalesce(school, m_first.school), self_rating = coalesce(self_rating, m_first.self_rating),
               goal = coalesce(goal, m_first.goal) where id = v_keep_line;
      end if;
      update app.student_test set prospect_student_id = v_keep_line where prospect_student_id = v_merge_line;
    end if;
  end if;
  update app.student_test set opportunity_id = p_keep where opportunity_id = p_merge;
  get diagnostics v_tests = row_count;
  -- Ô còn trống của bản giữ lại lấy của bản kia.
  update app.opportunity set
    need = coalesce(need, m.need), supporter_id = coalesce(supporter_id, m.supporter_id)
   where id = p_keep;
  update app.opportunity set merged_into_id = p_keep where merged_into_id = p_merge;
  update app.opportunity set record_status = 'DA_GOP', merged_into_id = p_keep where id = p_merge;
  -- Phiếu vừa chuyển sang có thể đổi nhóm con L5 của bản giữ lại (R-CRM-15).
  perform app.refresh_opportunity_l5_substage(p_keep);
  perform app.merge_write_notes('OPPORTUNITY', p_keep, p_merge, v_info);
  return v_info || jsonb_build_object('moved', jsonb_build_object('appointments', v_appt, 'notes', v_notes, 'tests', v_tests))
                || jsonb_build_object('warnings', v_check -> 'warnings');
end;
$function$;

-- ---------------------------------------------------------------------------
-- Bản ghi lead: thêm khoá student_* của em đầu (tương thích) và mảng students.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.get_lead(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v app.lead;
begin
  select * into v from app.lead where id = p_id;
  if v.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lead.');
  end if;
  -- Luật: xem lead cần quyền Lead · Xem ở cơ sở của lead.
  perform app.assert_can('LEAD', 'XEM', v.branch_id);
  return (to_jsonb(v) - 'search_text') || app.prospect_compat_json(app.lead_first(v.id)) || jsonb_build_object(
    'students', app.prospect_students_json(v.id, null),
    'owner_name', app.staff_display_name(v.owner_id),
    'supporter_name', app.staff_display_name(v.supporter_id),
    'created_by_name', app.staff_display_name(v.created_by),
    'updated_by_name', app.staff_display_name(v.updated_by),
    'branch_code', (select b.code from app.branch b where b.id = v.branch_id),
    'branch_name', (select b.name from app.branch b where b.id = v.branch_id),
    'campaign_name', (select c.name from app.campaign c where c.id = v.campaign_id),
    'merged_into_code', (select m.code from app.lead m where m.id = v.merged_into_id),
    'appointments_total', (select count(*) from app.appointment a where a.lead_id = v.id),
    'appointments_open', (select count(*) from app.appointment a where a.lead_id = v.id and a.status = 'CHUA_LAM'),
    'opportunities_total', (select count(*) from app.opportunity o where o.lead_id = v.id and o.record_status = 'DANG_DUNG'));
end;
$function$;

-- ---------------------------------------------------------------------------
-- Bản ghi cơ hội: thêm khoá student_* của em đầu (tương thích) và mảng students.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION app.get_opportunity(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v app.opportunity;
  v_tests jsonb := '[]'::jsonb;
  v_test_scope text := app.permission_scope('STUDENT_TEST', 'XEM');
begin
  select * into v from app.opportunity where id = p_id;
  if v.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ hội.');
  end if;
  -- Luật: xem cơ hội cần quyền Cơ hội · Xem ở cơ sở của cơ hội.
  perform app.assert_can('OPPORTUNITY', 'XEM', v.branch_id);
  -- Danh sách phiếu: chỉ khi có quyền xem phiếu ở cơ sở của cơ hội (người xem cơ hội mà không xem được phiếu thì tab rỗng).
  if v_test_scope = 'TOAN_HE_THONG' or (v_test_scope is not null and v.branch_id = app.current_branch_id()) then
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', t.id, 'code', t.code, 'status_code', t.status_code, 'status', st.name,
             'scheduled_at', t.scheduled_at, 'subject', su.name, 'mode', mo.name, 'level', le.name,
             'test_branch_code', tb.code, 'score', t.score,
             'cancel_reason', cr.name) order by t.scheduled_at desc, t.id), '[]'::jsonb)
      into v_tests
      from app.student_test t
      join app.branch tb on tb.id = t.test_branch_id
      left join app.catalog_item st on st.catalog_code = 'TEST_STATUS' and st.code = t.status_code
      left join app.catalog_item su on su.catalog_code = 'SUBJECT' and su.code = t.subject_code
      left join app.catalog_item mo on mo.catalog_code = 'TEST_MODE' and mo.code = t.mode_code
      left join app.catalog_item le on le.catalog_code = 'TEST_LEVEL' and le.code = t.level_code
      left join app.catalog_item cr on cr.catalog_code = 'TEST_CANCEL_REASON' and cr.code = t.cancel_reason_code
     where t.opportunity_id = v.id;
  end if;
  return (to_jsonb(v) - 'search_text') || app.prospect_compat_json(app.opp_first(v.id)) || jsonb_build_object(
    'students', app.prospect_students_json(null, v.id),
    'owner_name', app.staff_display_name(v.owner_id),
    'supporter_name', app.staff_display_name(v.supporter_id),
    'created_by_name', app.staff_display_name(v.created_by),
    'updated_by_name', app.staff_display_name(v.updated_by),
    'branch_code', (select b.code from app.branch b where b.id = v.branch_id),
    'branch_name', (select b.name from app.branch b where b.id = v.branch_id),
    'campaign_name', (select c.name from app.campaign c where c.id = v.campaign_id),
    'lead_code', (select l.code from app.lead l where l.id = v.lead_id),
    'merged_into_code', (select m.code from app.opportunity m where m.id = v.merged_into_id),
    'parent_code', (select p.code from app.parent p where p.id = v.parent_id),
    'parent_name', (select p.full_name from app.parent p where p.id = v.parent_id),
    'parent_phone', (select p.phone from app.parent p where p.id = v.parent_id),
    'parent_province_code', (select p.province_code from app.parent p where p.id = v.parent_id),
    'parent_ward_code', (select p.ward_code from app.parent p where p.id = v.parent_id),
    'parent_address', (select p.address from app.parent p where p.id = v.parent_id),
    'appointments_total', (select count(*) from app.appointment a where a.opportunity_id = v.id),
    'appointments_open', (select count(*) from app.appointment a where a.opportunity_id = v.id and a.status = 'CHUA_LAM'),
    'tests_total', (select count(*) from app.student_test t where t.opportunity_id = v.id),
    'sales_documents', to_jsonb(app.opportunity_sales_documents(v.id)),
    'test_state', (select to_jsonb(s) from app.opportunity_test_state(v.id) s),
    'tests', v_tests);
end;
$function$;

select set_config('hmt.migration', '', false);
