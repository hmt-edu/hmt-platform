-- P3b3a: gộp trùng lead, cơ hội, phụ huynh, học sinh (docs/spec/04 R-CRM-22, 25, 37) và lịch nhắc tự đóng khi phiếu sang Đang test.
-- Gộp: một giao dịch, khoá hai hồ sơ theo thứ tự id, kiểm quyền Duyệt cho CẢ HAI hồ sơ (người một cơ sở chỉ gộp khi cả hai ở
-- cơ sở mình; hai cơ sở khác nhau chỉ Admin), không hoàn tác, bản bị gộp thành "Đã gộp" (chỉ đọc), ghi chú hệ thống trên cả hai bản.
-- Điều kiện chặn từng loại nằm ở các hàm kiểm riêng (merge_check_*): xem trước (merge_preview) và gộp dùng chung một nguồn.
-- Chưa làm: điều kiện chặn "học sinh cùng học hai lớp trùng giờ" và báo giá, đơn xung đột của R-CRM-25 (còn [CHỜ]).

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Bảng: phụ huynh, học sinh có trạng thái bản ghi như lead, cơ hội (Đang dùng / Đã gộp + gộp vào ai).
-- ---------------------------------------------------------------------------
alter table app.parent
  add column record_status text not null default 'DANG_DUNG' check (record_status in ('DANG_DUNG', 'DA_GOP')),
  add column merged_into_id uuid references app.parent (id),
  add constraint parent_merged_check check ((record_status = 'DA_GOP') = (merged_into_id is not null));
alter table app.student
  add column record_status text not null default 'DANG_DUNG' check (record_status in ('DANG_DUNG', 'DA_GOP')),
  add column merged_into_id uuid references app.student (id),
  add constraint student_merged_check check ((record_status = 'DA_GOP') = (merged_into_id is not null));
-- Khoá ngoại: tìm các bản đã gộp vào một hồ sơ (làm phẳng chuỗi gộp); danh sách mặc định ẩn bản "Đã gộp" (hiếm).
create index parent_merged_into_idx on app.parent (merged_into_id) where merged_into_id is not null;
create index parent_merged_status_idx on app.parent (record_status) where record_status <> 'DANG_DUNG';
create index student_merged_into_idx on app.student (merged_into_id) where merged_into_id is not null;
create index student_merged_status_idx on app.student (record_status) where record_status <> 'DANG_DUNG';

-- Ghi chú gắn được vào phụ huynh, học sinh (cần cho ghi chú hệ thống "Đã gộp…").
insert into app.note_target (entity_type, table_name, name) values
  ('PARENT', 'app.parent', 'Phụ huynh'), ('STUDENT', 'app.student', 'Học sinh');

-- ---------------------------------------------------------------------------
-- Ghi chú: luật "không chuyển ghi chú sang bản ghi khác" giữ nguyên, trừ bên trong hàm gộp (R-CRM-22, 25: ghi chú của bản bị
-- gộp chuyển sang bản giữ lại). Hàm nội bộ app.move_notes bật cờ trong giao dịch; không ai khác chuyển được.
-- ---------------------------------------------------------------------------
create or replace function app.tg_note_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_table regclass;
  v_exists boolean;
begin
  if TG_OP = 'UPDATE' and (new.entity_type is distinct from old.entity_type or new.entity_id is distinct from old.entity_id)
     and coalesce(current_setting('hmt.merge', true), '') <> 'on' then
    perform app.raise_error('HMT_MA_KHONG_DOI_DUOC', 'Không chuyển ghi chú sang bản ghi khác được.');
  end if;

  select table_name into v_table from app.note_target where entity_type = new.entity_type;
  if v_table is null then
    perform app.raise_error('HMT_GHI_CHU_LOAI_KHONG_CO',
      format('Loại bản ghi "%s" chưa được đăng ký để gắn ghi chú.', new.entity_type));
  end if;
  execute format('select exists (select from %s where id = $1)', v_table) into v_exists using new.entity_id;
  if not v_exists then
    perform app.raise_error('HMT_GHI_CHU_DOI_TUONG_KHONG_CO', 'Bản ghi cần gắn ghi chú không tồn tại.');
  end if;

  -- Luật: huỷ thì ghi lại ai, lúc nào.
  if TG_OP = 'UPDATE' and new.is_cancelled and not old.is_cancelled then
    new.cancelled_at := now();
    new.cancelled_by := app.current_actor();
  end if;
  return new;
end;
$$;

-- Chuyển ghi chú của bản ghi bị gộp sang bản ghi giữ lại. Chỉ gọi từ hàm gộp (không cấp cho giao diện). Trả số ghi chú đã chuyển.
create or replace function app.move_notes(p_entity_type text, p_from uuid, p_to uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  perform set_config('hmt.merge', 'on', true);
  update app.note set entity_id = p_to where entity_type = p_entity_type and entity_id = p_from;
  get diagnostics v_count = row_count;
  perform set_config('hmt.merge', '', true);
  return v_count;
end;
$$;

-- Ghi chú hệ thống ("Đã gộp …") trên một bản ghi, người ghi là người đang thao tác. Hàm nội bộ.
create or replace function app.add_system_note(p_entity_type text, p_entity_id uuid, p_body text)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into app.note (entity_type, entity_id, body) values (p_entity_type, p_entity_id, p_body);
$$;

-- Thêm vào app.can_see_note_target: phụ huynh, học sinh (như P3b2b cho phiếu). Phần còn lại giữ nguyên.
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
  -- Luật: phụ huynh, học sinh theo quyền Xem của phân hệ: toàn hệ thống, hoặc đúng cơ sở tiếp nhận.
  if p_entity_type = 'PARENT' then
    select branch_id into v_branch_id from app.parent where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('PARENT', 'XEM', v_branch_id);
  end if;
  if p_entity_type = 'STUDENT' then
    select branch_id into v_branch_id from app.student where id = p_entity_id;
    return v_branch_id is not null and app.can_see_branch('STUDENT', 'XEM', v_branch_id);
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
-- Kiểm trùng SĐT: phụ huynh đã gộp trỏ về bản giữ lại (R-CRM-25). Nội dung khác giữ nguyên như P3b1.
-- ---------------------------------------------------------------------------
create or replace function app.find_duplicate_contacts(p_phone text, p_exclude_lead_id uuid default null)
returns table (kind text, id uuid, code text, label text, branch_code text, visible boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
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
                  then l.parent_name || coalesce(' · ' || nullif(l.student_name, ''), '') end as label,
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
$$;

-- Tìm hoặc tạo phụ huynh, học sinh: gặp hồ sơ đã gộp thì trả bản giữ lại (R-CRM-25).
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
  -- Hồ sơ đã gộp thì trả bản giữ lại (R-CRM-25); ưu tiên hồ sơ còn dùng, rồi cũ nhất.
  select coalesce(merged_into_id, id) into v_id from app.parent where phone = v_phone
   order by (record_status = 'DANG_DUNG') desc, created_at, id limit 1;
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
  -- Hồ sơ đã gộp thì trả bản giữ lại (R-CRM-25).
  select coalesce(merged_into_id, id) into v_id from app.student
   where parent_id = p_parent_id and app.normalize_person_name(full_name) = app.normalize_person_name(p_name)
     and birth_year = p_birth_year
   order by (record_status = 'DANG_DUNG') desc, created_at, id limit 1;
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

-- Danh sách lead, cơ hội: bản "Đã gộp" vẫn tìm được bằng mã (R-CRM-22). Nội dung khác giữ nguyên.
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
       -- Bản "Đã gộp" ẩn khỏi danh sách mặc định nhưng vẫn tìm được bằng mã (R-CRM-22).
       and (v_merged or l.record_status = 'DANG_DUNG'
            or (v_q is not null and l.code = upper(btrim(p_filters ->> 'q'))))
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
       -- Bản "Đã gộp" ẩn khỏi danh sách mặc định nhưng vẫn tìm được bằng mã (R-CRM-22).
       and (v_merged or o.record_status = 'DANG_DUNG'
            or (v_q is not null and o.code = upper(btrim(p_filters ->> 'q'))))
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
-- Lịch nhắc của phiếu (anh chốt 18/10): tự đóng bằng Huỷ khi phiếu sang Đang test. Hàm sinh lịch nhắc thêm tham số p_reopen
-- (chỉ mở lại phiếu đã huỷ mới bật lại lịch nhắc đã huỷ theo phiếu); hàm huỷ lịch nhắc thêm ghi chú và chế độ "chỉ lịch chưa sửa tay".
-- ---------------------------------------------------------------------------
drop function app.ensure_test_reminder(uuid, timestamptz, text);
drop function app.cancel_test_reminder(uuid);
create or replace function app.ensure_test_reminder(p_test_id uuid, p_at timestamptz default null, p_activity text default null,
  p_reopen boolean default false)
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
    -- Chỉ khi mở lại phiếu đã huỷ mới bật lại lịch nhắc đã bị huỷ theo phiếu. Lịch nhắc đã đóng vì phiếu bắt đầu test, hoặc đổi
    -- lịch sau khi lùi về Nháp: không sinh lại, không mở lại (anh chốt 18/10).
    if p_reopen and v_appt.cancel_note = 'Phiếu kiểm tra đã huỷ' then
      update app.appointment
         set status = 'CHUA_LAM', cancel_reason_code = null, cancel_note = null, cancelled_at = null, cancelled_by = null,
             scheduled_at = v_at, auto_scheduled_at = v_auto, owner_id = v_test.owner_id
       where id = v_appt.id;
    end if;
  elsif v_appt.status = 'CHUA_LAM' then
    update app.appointment
       set scheduled_at = case when p_at is not null or scheduled_at is not distinct from auto_scheduled_at
                               then v_at else scheduled_at end,
           auto_scheduled_at = v_auto, owner_id = v_test.owner_id
     where id = v_appt.id;
  end if;
end;
$$;
create or replace function app.cancel_test_reminder(p_test_id uuid, p_note text default 'Phiếu kiểm tra đã huỷ',
  p_only_untouched boolean default false)
returns void
language sql
security definer
set search_path = ''
as $$
  update app.appointment
     set status = 'HUY', cancel_reason_code = 'KHAC', cancel_note = p_note, cancelled_at = now(), cancelled_by = auth.uid()
   where student_test_id = p_test_id and is_auto_reminder and status = 'CHUA_LAM'
     and (not p_only_untouched or scheduled_at is not distinct from auto_scheduled_at);
$$;

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
  -- Lịch nhắc tự sinh còn Chưa làm và chưa sửa tay thì đóng bằng Huỷ (lý do Khác, ghi chú "Phiếu đã bắt đầu"), để thẻ QUÁ HẠN
  -- và thanh đỏ Kanban không tăng oan. Lịch người dùng sửa tay hoặc tự tạo giữ nguyên (anh chốt 18/10).
  perform app.cancel_test_reminder(p_id, 'Phiếu đã bắt đầu', true);
  perform app.refresh_opportunity_l5_substage(v_test.opportunity_id);
end;
$$;

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
    perform app.ensure_test_reminder(p_id, null, null, true);
  end if;
  perform app.refresh_opportunity_l5_substage(v_test.opportunity_id);
end;
$$;
revoke execute on function app.ensure_test_reminder(uuid, timestamptz, text, boolean), app.cancel_test_reminder(uuid, text, boolean)
  from public, anon, authenticated;

-- ===========================================================================
-- HÀM GỘP
-- ===========================================================================

-- Điểm nối báo giá, đơn hàng (P5 thay thân): mã các báo giá, đơn của một cơ hội. Hiện chưa có bảng nên trả rỗng.
create or replace function app.opportunity_sales_documents(p_opportunity_id uuid)
returns text[]
language sql
stable
set search_path = ''
as $$
  select array[]::text[];
$$;

-- ---------------------------------------------------------------------------
-- Kiểm chung trước khi gộp hoặc xem trước: hai hồ sơ khác nhau, có thật, cùng loại, còn dùng, và người gọi có quyền Duyệt với CẢ HAI
-- (R-CRM-22, 25): người một cơ sở chỉ gộp khi cả hai ở cơ sở mình; hai cơ sở khác nhau chỉ Admin (phạm vi toàn hệ thống).
-- p_entity: LEAD, OPPORTUNITY, PARENT, STUDENT. p_lock: khoá hai hồ sơ theo thứ tự id (khi gộp thật).
-- Kết quả: {keep_code, merge_code, keep_name, merge_name}. Hàm nội bộ.
-- ---------------------------------------------------------------------------
create or replace function app.merge_common(p_entity text, p_keep uuid, p_merge uuid, p_lock boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope text;
  v_cur uuid := app.current_branch_id();
  v_keep_code text;
  v_merge_code text;
  v_keep_branch uuid;
  v_merge_branch uuid;
  v_keep_status text;
  v_merge_status text;
begin
  if p_keep is null or p_merge is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn bản giữ lại và bản gộp vào.');
  end if;
  if p_keep = p_merge then
    perform app.raise_error('HMT_GOP_CUNG_BAN_GHI', 'Phải chọn hai hồ sơ khác nhau để gộp.');
  end if;
  if p_entity not in ('LEAD', 'OPPORTUNITY', 'PARENT', 'STUDENT') then
    perform app.raise_error('HMT_LOAI_BAN_GHI_SAI', 'Chưa gộp được loại bản ghi này.');
  end if;

  -- Đọc (và khoá nếu gộp thật) hai hồ sơ theo thứ tự id để hai người gộp chéo không kẹt nhau.
  if p_entity = 'LEAD' then
    if p_lock then perform 1 from app.lead where id in (p_keep, p_merge) order by id for update; end if;
    select code, branch_id, record_status into v_keep_code, v_keep_branch, v_keep_status from app.lead where id = p_keep;
    select code, branch_id, record_status into v_merge_code, v_merge_branch, v_merge_status from app.lead where id = p_merge;
  elsif p_entity = 'OPPORTUNITY' then
    if p_lock then perform 1 from app.opportunity where id in (p_keep, p_merge) order by id for update; end if;
    select code, branch_id, record_status into v_keep_code, v_keep_branch, v_keep_status from app.opportunity where id = p_keep;
    select code, branch_id, record_status into v_merge_code, v_merge_branch, v_merge_status from app.opportunity where id = p_merge;
  elsif p_entity = 'PARENT' then
    if p_lock then perform 1 from app.parent where id in (p_keep, p_merge) order by id for update; end if;
    select code, branch_id, record_status into v_keep_code, v_keep_branch, v_keep_status from app.parent where id = p_keep;
    select code, branch_id, record_status into v_merge_code, v_merge_branch, v_merge_status from app.parent where id = p_merge;
  else
    if p_lock then perform 1 from app.student where id in (p_keep, p_merge) order by id for update; end if;
    select code, branch_id, record_status into v_keep_code, v_keep_branch, v_keep_status from app.student where id = p_keep;
    select code, branch_id, record_status into v_merge_code, v_merge_branch, v_merge_status from app.student where id = p_merge;
  end if;
  if v_keep_code is null or v_merge_code is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy hồ sơ cần gộp.');
  end if;

  -- Luật R-CRM-22, 25: quyền Duyệt với cả hai hồ sơ; khác cơ sở chỉ Admin.
  v_scope := app.permission_scope(p_entity, 'DUYET');
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền gộp loại hồ sơ này.');
  end if;
  if v_scope <> 'TOAN_HE_THONG' and (v_keep_branch is distinct from v_cur or v_merge_branch is distinct from v_cur) then
    if v_keep_branch is distinct from v_merge_branch then
      perform app.raise_error('HMT_GOP_KHAC_CO_SO', 'Hai hồ sơ thuộc hai cơ sở khác nhau: chỉ Admin gộp được.');
    end if;
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền gộp hồ sơ của cơ sở khác.');
  end if;
  if v_keep_status <> 'DANG_DUNG' or v_merge_status <> 'DANG_DUNG' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP',
      format('Hồ sơ %s đã gộp vào bản khác, không gộp được.', case when v_keep_status <> 'DANG_DUNG' then v_keep_code else v_merge_code end));
  end if;
  return jsonb_build_object('keep_code', v_keep_code, 'merge_code', v_merge_code);
end;
$$;

-- Điều kiện gộp CƠ HỘI (R-CRM-22, 37a): cùng phụ huynh (khác thì gộp phụ huynh trước); học sinh không khác nhau (khác thì gộp học
-- sinh trước; một bên chưa có học sinh thì lấy của bên kia); chặn nếu bản bị gộp đã có báo giá, đơn. Cảnh báo (không chặn): bản bị
-- gộp đang ở giai đoạn cao hơn bản giữ lại (giai đoạn bản giữ lại giữ nguyên, R-CRM-02). Kết quả: {blockers: [...], warnings: [...]}.
create or replace function app.merge_check_opportunities(p_keep uuid, p_merge uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
  if (k.student_id is not null and m.student_id is not null and k.student_id <> m.student_id)
     or (k.student_name is not null and k.student_birth_year is not null and m.student_name is not null
         and m.student_birth_year is not null
         and (app.normalize_person_name(k.student_name) <> app.normalize_person_name(m.student_name)
              or k.student_birth_year <> m.student_birth_year)) then
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
$$;

-- Điều kiện gộp HỌC SINH (R-CRM-37b): cùng phụ huynh; khác thì gộp phụ huynh trước.
create or replace function app.merge_check_students(p_keep uuid, p_merge uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_same boolean;
begin
  select k.parent_id = m.parent_id into v_same from app.student k, app.student m where k.id = p_keep and m.id = p_merge;
  return jsonb_build_object(
    'blockers', case when v_same then '[]'::jsonb
                     else jsonb_build_array(jsonb_build_object('code', 'HMT_GOP_KHAC_PHU_HUYNH',
                            'message', 'Hai học sinh khác phụ huynh: gộp phụ huynh trước.')) end,
    'warnings', '[]'::jsonb);
end;
$$;

-- Báo các cặp học sinh trùng tên (chuẩn hoá) và năm sinh dưới cùng một phụ huynh (R-CRM-37c), để người dùng gộp học sinh.
create or replace function app.duplicate_students_of_parent(p_parent_id uuid)
returns table (student_name text, birth_year integer, student_ids uuid[], student_codes text[])
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if app.permission_scope('STUDENT', 'XEM') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem học sinh.');
  end if;
  return query
    select min(s.full_name), s.birth_year, array_agg(s.id order by s.created_at, s.id), array_agg(s.code order by s.created_at, s.id)
      from app.student s
     where s.parent_id = p_parent_id and s.record_status = 'DANG_DUNG'
     group by app.normalize_person_name(s.full_name), s.birth_year
    having count(*) > 1;
end;
$$;

-- ---------------------------------------------------------------------------
-- Xem trước gộp (TS-10, KH-07): số bản ghi sẽ chuyển sang, điều kiện chặn, cảnh báo. Cùng kiểm quyền với gộp thật, không đổi gì.
-- Kết quả: {keep_code, merge_code, move: {…}, blockers: [{code, message}], warnings: [{code, message}]}.
-- ---------------------------------------------------------------------------
create or replace function app.merge_preview(p_entity text, p_keep uuid, p_merge uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_info jsonb := app.merge_common(p_entity, p_keep, p_merge);
  v_check jsonb := '{"blockers": [], "warnings": []}'::jsonb;
  v_move jsonb;
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
      'opportunities', (select count(*) from app.opportunity where student_id = p_merge),
      'tests', (select count(*) from app.student_test where student_id = p_merge),
      'notes', (select count(*) from app.note where entity_type = 'STUDENT' and entity_id = p_merge));
  else
    v_move := jsonb_build_object(
      'leads', (select count(*) from app.lead where parent_id = p_merge),
      'opportunities', (select count(*) from app.opportunity where parent_id = p_merge),
      'students', (select count(*) from app.student where parent_id = p_merge),
      'notes', (select count(*) from app.note where entity_type = 'PARENT' and entity_id = p_merge));
  end if;
  return v_info || jsonb_build_object('move', v_move) || v_check;
end;
$$;

-- Dừng ở điều kiện chặn đầu tiên (có mã lỗi và câu tiếng Việt), dùng chung cho các hàm gộp. Hàm nội bộ.
create or replace function app.merge_raise_first_blocker(p_check jsonb)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if jsonb_array_length(p_check -> 'blockers') > 0 then
    perform app.raise_error(p_check -> 'blockers' -> 0 ->> 'code', p_check -> 'blockers' -> 0 ->> 'message');
  end if;
end;
$$;

-- Bắt buộc người dùng xác nhận "Gộp không hoàn tác được". Hàm nội bộ.
create or replace function app.merge_require_confirm(p_confirm boolean)
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if not coalesce(p_confirm, false) then
    perform app.raise_error('HMT_CAN_XAC_NHAN', 'Gộp không hoàn tác được: xác nhận để tiếp tục.');
  end if;
end;
$$;

-- Ghi chú hệ thống "Đã gộp …" trên cả hai bản, kèm người gộp. Hàm nội bộ.
create or replace function app.merge_write_notes(p_entity text, p_keep uuid, p_merge uuid, p_info jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_who text := coalesce(app.staff_display_name(auth.uid()), 'hệ thống');
begin
  perform app.add_system_note(p_entity, p_keep,
    format('Hệ thống: đã gộp %s vào hồ sơ này (người gộp: %s).', p_info ->> 'merge_code', v_who));
  perform app.add_system_note(p_entity, p_merge,
    format('Hệ thống: đã gộp vào %s (người gộp: %s). Hồ sơ này chỉ còn đọc.', p_info ->> 'keep_code', v_who));
end;
$$;

-- ---------------------------------------------------------------------------
-- Gộp LEAD (R-CRM-22): lịch hẹn, ghi chú, cơ hội của lead bị gộp chuyển sang lead giữ lại; thông tin lead giữ lại giữ nguyên.
-- Ai gọi: người có quyền Lead · Duyệt với cả hai lead (khác cơ sở chỉ Admin). Không hoàn tác; cần p_confirm.
-- Kết quả: {keep_code, merge_code, moved: {appointments, notes, opportunities}}.
-- ---------------------------------------------------------------------------
create or replace function app.merge_leads(p_keep uuid, p_merge uuid, p_confirm boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_info jsonb := app.merge_common('LEAD', p_keep, p_merge, true);
  v_appt integer;
  v_notes integer;
  v_opps integer;
begin
  perform app.merge_require_confirm(p_confirm);
  update app.appointment set lead_id = p_keep where lead_id = p_merge;
  get diagnostics v_appt = row_count;
  v_notes := app.move_notes('LEAD', p_merge, p_keep);
  update app.opportunity set lead_id = p_keep where lead_id = p_merge;
  get diagnostics v_opps = row_count;
  -- Làm phẳng chuỗi gộp: các bản từng gộp vào bản này giờ trỏ thẳng về bản giữ lại.
  update app.lead set merged_into_id = p_keep where merged_into_id = p_merge;
  update app.lead set record_status = 'DA_GOP', merged_into_id = p_keep where id = p_merge;
  perform app.merge_write_notes('LEAD', p_keep, p_merge, v_info);
  return v_info || jsonb_build_object('moved', jsonb_build_object('appointments', v_appt, 'notes', v_notes, 'opportunities', v_opps));
end;
$$;

-- ---------------------------------------------------------------------------
-- Gộp CƠ HỘI (R-CRM-22, 37a): lịch hẹn, ghi chú, phiếu kiểm tra của cơ hội bị gộp chuyển sang cơ hội giữ lại; ô nào của bản giữ lại
-- còn trống (học sinh, nhu cầu, người hỗ trợ) thì lấy của bản kia. Giai đoạn bản giữ lại giữ nguyên (R-CRM-02).
-- Điều kiện chặn: merge_check_opportunities. Kết quả: {keep_code, merge_code, moved: {…}, warnings: [...]}.
-- ---------------------------------------------------------------------------
create or replace function app.merge_opportunities(p_keep uuid, p_merge uuid, p_confirm boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_info jsonb := app.merge_common('OPPORTUNITY', p_keep, p_merge, true);
  v_check jsonb := app.merge_check_opportunities(p_keep, p_merge);
  m app.opportunity;
  v_appt integer;
  v_notes integer;
  v_tests integer;
begin
  perform app.merge_raise_first_blocker(v_check);
  perform app.merge_require_confirm(p_confirm);
  select * into m from app.opportunity where id = p_merge;
  update app.appointment set opportunity_id = p_keep where opportunity_id = p_merge;
  get diagnostics v_appt = row_count;
  v_notes := app.move_notes('OPPORTUNITY', p_merge, p_keep);
  update app.student_test set opportunity_id = p_keep where opportunity_id = p_merge;
  get diagnostics v_tests = row_count;
  -- Ô còn trống của bản giữ lại lấy của bản kia (R-CRM-37a: một bên chưa có học sinh thì lấy học sinh của bên kia).
  update app.opportunity set
    student_id = coalesce(student_id, m.student_id), student_name = coalesce(student_name, m.student_name),
    student_birth_date = coalesce(student_birth_date, m.student_birth_date),
    student_birth_year = coalesce(student_birth_year, m.student_birth_year), school = coalesce(school, m.school),
    self_rating = coalesce(self_rating, m.self_rating), goal = coalesce(goal, m.goal), need = coalesce(need, m.need),
    supporter_id = coalesce(supporter_id, m.supporter_id)
   where id = p_keep;
  update app.opportunity set merged_into_id = p_keep where merged_into_id = p_merge;
  update app.opportunity set record_status = 'DA_GOP', merged_into_id = p_keep where id = p_merge;
  -- Phiếu vừa chuyển sang có thể đổi nhóm con L5 của bản giữ lại (R-CRM-15).
  perform app.refresh_opportunity_l5_substage(p_keep);
  perform app.merge_write_notes('OPPORTUNITY', p_keep, p_merge, v_info);
  return v_info || jsonb_build_object('moved', jsonb_build_object('appointments', v_appt, 'notes', v_notes, 'tests', v_tests))
                || jsonb_build_object('warnings', v_check -> 'warnings');
end;
$$;

-- ---------------------------------------------------------------------------
-- Gộp HỌC SINH (R-CRM-25, 37b): cơ hội, phiếu, ghi chú của học sinh bị gộp chuyển sang học sinh giữ lại; ô còn trống của bản giữ lại
-- (ngày sinh, trường, học lực, mục tiêu) lấy của bản kia. Chỉ khi cùng phụ huynh. Kết quả: {keep_code, merge_code, moved: {…}}.
-- ---------------------------------------------------------------------------
create or replace function app.merge_students(p_keep uuid, p_merge uuid, p_confirm boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
  update app.opportunity set student_id = p_keep where student_id = p_merge;
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
$$;

-- ---------------------------------------------------------------------------
-- Gộp PHỤ HUYNH (R-CRM-25, 37c): lead, cơ hội, học sinh, ghi chú của phụ huynh bị gộp chuyển sang phụ huynh giữ lại (đơn, ghi danh
-- sau này đi theo nguyên vẹn). KHÔNG tự gộp học sinh; sau khi gộp, báo các cặp học sinh trùng tên và năm sinh để người dùng gộp.
-- Không có điều kiện chặn báo giá, đơn (R-CRM-25 chưa chốt, còn [CHỜ]). Kết quả: {keep_code, merge_code, moved, duplicate_students}.
-- ---------------------------------------------------------------------------
create or replace function app.merge_parents(p_keep uuid, p_merge uuid, p_confirm boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_info jsonb := app.merge_common('PARENT', p_keep, p_merge, true);
  v_leads integer;
  v_opps integer;
  v_students integer;
  v_notes integer;
  v_dup jsonb;
begin
  perform app.merge_require_confirm(p_confirm);
  update app.lead set parent_id = p_keep where parent_id = p_merge;
  get diagnostics v_leads = row_count;
  update app.opportunity set parent_id = p_keep where parent_id = p_merge;
  get diagnostics v_opps = row_count;
  update app.student set parent_id = p_keep where parent_id = p_merge;
  get diagnostics v_students = row_count;
  v_notes := app.move_notes('PARENT', p_merge, p_keep);
  update app.parent set merged_into_id = p_keep where merged_into_id = p_merge;
  update app.parent set record_status = 'DA_GOP', merged_into_id = p_keep where id = p_merge;
  -- Ô tìm kiếm của phiếu có tên phụ huynh: tính lại cho các học sinh vừa chuyển sang.
  update app.student_test t set search_text = app.student_test_search_text(t)
   where t.student_id in (select s.id from app.student s where s.parent_id = p_keep);
  perform app.merge_write_notes('PARENT', p_keep, p_merge, v_info);
  select coalesce(jsonb_agg(jsonb_build_object('student_name', d.student_name, 'birth_year', d.birth_year,
                                                'student_codes', d.student_codes)), '[]'::jsonb)
    into v_dup from app.duplicate_students_of_parent(p_keep) d;
  return v_info || jsonb_build_object('moved', jsonb_build_object('leads', v_leads, 'opportunities', v_opps,
                                                                    'students', v_students, 'notes', v_notes))
                || jsonb_build_object('duplicate_students', v_dup);
end;
$$;

-- ---------------------------------------------------------------------------
-- Quyền gọi: chỉ người đã đăng nhập; mỗi hàm tự kiểm quyền bên trong. Hàm nội bộ không cấp cho giao diện.
-- ---------------------------------------------------------------------------
revoke execute on function
  app.move_notes(text, uuid, uuid), app.add_system_note(text, uuid, text), app.opportunity_sales_documents(uuid),
  app.merge_common(text, uuid, uuid, boolean), app.merge_check_opportunities(uuid, uuid), app.merge_check_students(uuid, uuid),
  app.merge_raise_first_blocker(jsonb), app.merge_require_confirm(boolean), app.merge_write_notes(text, uuid, uuid, jsonb)
  from public, anon, authenticated;
revoke execute on function
  app.merge_preview(text, uuid, uuid), app.merge_leads(uuid, uuid, boolean), app.merge_opportunities(uuid, uuid, boolean),
  app.merge_students(uuid, uuid, boolean), app.merge_parents(uuid, uuid, boolean), app.duplicate_students_of_parent(uuid)
  from public, anon;
grant execute on function
  app.merge_preview(text, uuid, uuid), app.merge_leads(uuid, uuid, boolean), app.merge_opportunities(uuid, uuid, boolean),
  app.merge_students(uuid, uuid, boolean), app.merge_parents(uuid, uuid, boolean), app.duplicate_students_of_parent(uuid)
  to authenticated;

select set_config('hmt.migration', '', false);
