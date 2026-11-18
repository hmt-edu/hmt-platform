-- CH-07 Rubric nhận xét (phần DB): phiên bản mô tả mức, hàm ghi cho Admin, chụp mô tả vào buổi.
-- Luật: R-GV-01 (9 tiêu chí, 3 nhóm), R-V2-19, S03-10 (cấu hình có phiên bản). Khung: design/hmt-canvas-1aab (CH07_*).
-- Quy tắc từ canvas: mô tả sửa tự do nhưng CHỈ áp cho buổi tạo sau (buổi chụp mô tả lúc mở nhận xét); tiêu chí đã dùng chỉ Ngừng, không xoá;
-- Tạo phiên bản sao chép bản đang dùng; chỉ Admin. Phiên bản theo BỘ tiêu chí (TOAN: Toán, Đại số, Hình học; MON_PHU: các môn còn lại), Q-189.
-- Chưa làm ở PR này: câu mẫu lời nhắn phụ huynh (chờ Chat quyết vênh luật R-V2-39), màn hình.
-- Chỉ mục: mỗi chỉ mục ghi lý do ngay bên dưới.
select set_config('hmt.migration', 'on', false);

-- 1. Bảng phiên bản (theo bộ). Mỗi bộ đúng một bản Đang dùng.
create table app.review_rubric_version (
  id uuid primary key default gen_random_uuid(),
  subject_set text not null check (subject_set in ('TOAN', 'MON_PHU')),
  version_no integer not null check (version_no >= 1),
  status text not null default 'DANG_DUNG' check (status in ('DANG_DUNG', 'NGUNG')),
  note text,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (subject_set, version_no)
);
comment on table app.review_rubric_version is 'Phiên bản rubric nhận xét theo bộ tiêu chí (CH-07). Mỗi bộ một bản Đang dùng; bản cũ Ngừng, chỉ xem.';
-- Một bản Đang dùng mỗi bộ (luật CH-07) và tra nhanh bản đang dùng khi mở nhận xét của buổi.
create unique index review_rubric_version_active_idx on app.review_rubric_version (subject_set) where status = 'DANG_DUNG';
select app.apply_standard('app.review_rubric_version');
alter table app.review_rubric_version enable row level security;
grant select on app.review_rubric_version to authenticated;
create policy review_rubric_version_read on app.review_rubric_version for select to authenticated
  using ((select app.permission_scope('ATTENDANCE', 'XEM')) is not null);

insert into app.review_rubric_version (subject_set, version_no, status, note)
values ('TOAN', 1, 'DANG_DUNG', 'Bản đầu, từ migration 103 (chữ mẫu, chờ sheet Rubric chính thức)'),
       ('MON_PHU', 1, 'DANG_DUNG', 'Bản đầu, từ migration 103 (chữ mẫu, chờ sheet Rubric chính thức)');

-- 2. Mô tả mức gắn phiên bản. Bộ MOI_MON (Thái độ) có mặt ở cả hai bản: sao chép sang mỗi bộ.
alter table app.review_level_desc add column version_id uuid references app.review_rubric_version (id);
-- Bỏ ràng buộc cũ (criterion, level) trước khi sao chép: mỗi bản có bộ mô tả riêng.
alter table app.review_level_desc drop constraint review_level_desc_criterion_id_level_key;
-- Không xoá cứng (khung chung): gán bản cho các dòng đang có bằng UPDATE; bộ MOI_MON gán vào bản Toán rồi sao chép sang bản môn phụ.
update app.review_level_desc d set version_id = v.id
  from app.review_criterion c, app.review_rubric_version v
 where c.id = d.criterion_id and v.version_no = 1 and d.version_id is null
   and v.subject_set = case when c.subject_set = 'MOI_MON' then 'TOAN' else c.subject_set end;
insert into app.review_level_desc (criterion_id, level, description, version_id)
select d.criterion_id, d.level, d.description, (select id from app.review_rubric_version where subject_set = 'MON_PHU' and version_no = 1)
  from app.review_level_desc d
  join app.review_criterion c on c.id = d.criterion_id
 where c.subject_set = 'MOI_MON';
alter table app.review_level_desc alter column version_id set not null;
alter table app.review_level_desc add constraint review_level_desc_version_criterion_level_key unique (version_id, criterion_id, level);
-- Khoá ngoại tiêu chí (ràng buộc duy nhất cũ bắt đầu bằng criterion_id đã bỏ).
create index review_level_desc_criterion_idx on app.review_level_desc (criterion_id);

-- 3. Buổi chụp phiên bản và mô tả lúc mở nhận xét: sửa mô tả sau đó không đổi buổi cũ.
alter table app.session_review_criterion add column rubric_version_id uuid references app.review_rubric_version (id);
alter table app.session_review_criterion add column level_descs jsonb not null default '{}'::jsonb;
-- Khoá ngoại phiên bản: biết buổi nào dùng bản nào.
create index session_review_criterion_version_idx on app.session_review_criterion (rubric_version_id) where rubric_version_id is not null;
comment on column app.session_review_criterion.level_descs is 'Mô tả mức 1 đến 5 chụp lúc mở nhận xét: {"1": "...", ...}. Sửa rubric sau đó không đổi (CH-07).';

-- app.open_session_review: như migration 103, thêm chụp phiên bản đang dùng của bộ và mô tả 5 mức.
create or replace function app.open_session_review(p_session_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_subject text;
  v_version uuid;
begin
  s := app.assert_review_writable(p_session_id, false);
  select subject_code into v_subject from app.class where id = s.class_id;
  -- Luật CH-07: buổi dùng bản Đang dùng của bộ tiêu chí của môn tại thời điểm mở.
  select v.id into v_version
    from app.review_rubric_version v
   where v.status = 'DANG_DUNG'
     and v.subject_set = coalesce((select ss.subject_set from app.review_subject_set ss where ss.subject_code = v_subject), 'MON_PHU');
  insert into app.session_review_criterion (session_id, branch_id, criterion_id, group_code, name, sort_order, rubric_version_id, level_descs)
  select s.id, s.branch_id, rc.id, rc.group_code, rc.name, rc.sort_order, v_version,
         coalesce((select jsonb_object_agg(d.level::text, d.description) from app.review_level_desc d
                    where d.version_id = v_version and d.criterion_id = rc.id), '{}'::jsonb)
    from app.review_criteria_for_subject(v_subject) rc
  on conflict (session_id, criterion_id) do nothing;
  return (select count(*) from app.session_review_criterion where session_id = p_session_id);
end;
$$;

-- app.session_review_sheet: như migration 103, nhưng mô tả 5 mức lấy từ bản chụp của buổi (level_descs); buổi mở trước CH-07 chưa có bản chụp thì
-- lấy bản 1 của bộ môn (đúng chữ lúc đó). Luật R-V2-19, Q-190, CH-07 (sửa mô tả chỉ áp cho buổi mở sau).
create or replace function app.session_review_sheet(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_subject text;
  v_v1 uuid;
begin
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');
  select subject_code into v_subject from app.class where id = s.class_id;
  select v.id into v_v1 from app.review_rubric_version v
   where v.version_no = 1 and v.subject_set = coalesce((select ss.subject_set from app.review_subject_set ss where ss.subject_code = v_subject), 'MON_PHU');
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'criterion_id', src.criterion_id, 'name', src.name, 'group_code', src.group_code, 'enabled', src.enabled,
             'hint', (select h.hint from app.review_hint h where h.criterion_id = src.criterion_id and h.subject_code = v_subject),
             'levels', case
                         when src.level_descs <> '{}'::jsonb
                           then (select jsonb_agg(e.value order by e.key::integer) from jsonb_each_text(src.level_descs) e)
                         else (select jsonb_agg(d.description order by d.level) from app.review_level_desc d
                                where d.criterion_id = src.criterion_id and d.version_id = v_v1)
                       end)
           order by src.sort_order)
      from app.session_review_criterion src where src.session_id = p_session_id), '[]'::jsonb);
end;
$$;

-- 4. Hàm đọc: app.get_rubric(p_subject_set, p_version_id) -> jsonb. Ai gọi: Admin (quyền Quản trị · Xem). Không truyền bản thì lấy bản Đang dùng.
-- Kết quả: {version, versions: [...], criteria: [{id, code, group_code, subject_set, name, sort_order, is_active, levels: {"1": "..."}}]}. Luật CH-07.
create or replace function app.get_rubric(p_subject_set text, p_version_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v app.review_rubric_version;
begin
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên xem được rubric nhận xét.');
  end if;
  if p_subject_set not in ('TOAN', 'MON_PHU') then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Bộ tiêu chí phải là TOAN hoặc MON_PHU.');
  end if;
  if p_version_id is null then
    select * into v from app.review_rubric_version where subject_set = p_subject_set and status = 'DANG_DUNG';
  else
    select * into v from app.review_rubric_version where id = p_version_id and subject_set = p_subject_set;
  end if;
  if v.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiên bản rubric.');
  end if;
  return jsonb_build_object(
    'version', jsonb_build_object('id', v.id, 'version_no', v.version_no, 'status', v.status, 'note', v.note, 'created_at', v.created_at),
    'versions', (select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'version_no', x.version_no, 'status', x.status, 'created_at', x.created_at)
                                            order by x.version_no desc), '[]'::jsonb)
                   from app.review_rubric_version x where x.subject_set = p_subject_set),
    'criteria', (select coalesce(jsonb_agg(jsonb_build_object(
                    'id', c.id, 'code', c.code, 'group_code', c.group_code, 'subject_set', c.subject_set, 'name', c.name,
                    'sort_order', c.sort_order, 'is_active', c.is_active,
                    'levels', coalesce((select jsonb_object_agg(d.level::text, d.description) from app.review_level_desc d
                                         where d.version_id = v.id and d.criterion_id = c.id), '{}'::jsonb))
                  order by c.sort_order, c.code), '[]'::jsonb)
                   from app.review_criterion c where c.subject_set in ('MOI_MON', p_subject_set)));
end;
$$;

-- 5. app.update_review_level_desc(p_version_id, p_criterion_id, p_level, p_description): sửa mô tả một mức của bản Đang dùng.
-- Ai gọi: Admin (Quản trị · Sửa). Luật CH-07: bản Ngừng chỉ xem; mô tả không rỗng; mức 1 đến 5; chỉ áp cho buổi mở nhận xét sau (buổi cũ giữ bản chụp).
create or replace function app.update_review_level_desc(p_version_id uuid, p_criterion_id uuid, p_level integer, p_description text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v app.review_rubric_version;
  c app.review_criterion;
  v_text text := nullif(btrim(coalesce(p_description, '')), '');
begin
  perform app.assert_config_writer();
  select * into v from app.review_rubric_version where id = p_version_id for update;
  select * into c from app.review_criterion where id = p_criterion_id;
  if v.id is null or c.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiên bản hoặc tiêu chí.');
  end if;
  -- Luật CH-07: chỉ bản Đang dùng được sửa.
  if v.status <> 'DANG_DUNG' then
    perform app.raise_error('HMT_RUBRIC_BAN_NGUNG', 'Phiên bản này đã Ngừng, chỉ xem. Sửa ở phiên bản đang dùng.');
  end if;
  if c.subject_set not in ('MOI_MON', v.subject_set) then
    perform app.raise_error('HMT_RUBRIC_TIEU_CHI_SAI', 'Tiêu chí không thuộc bộ của phiên bản này.');
  end if;
  if p_level is null or p_level not between 1 and 5 then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Mức phải từ 1 đến 5.');
  end if;
  if v_text is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Mô tả mức không được để trống.');
  end if;
  insert into app.review_level_desc (version_id, criterion_id, level, description)
  values (p_version_id, p_criterion_id, p_level, v_text)
  on conflict (version_id, criterion_id, level) do update set description = excluded.description;
end;
$$;

-- 6. app.create_rubric_version(p_subject_set, p_note) -> uuid: Tạo phiên bản mới = sao chép bản Đang dùng, bản cũ chuyển Ngừng.
-- Ai gọi: Admin. Một giao dịch; khoá bản đang dùng để hai người không tạo trùng.
create or replace function app.create_rubric_version(p_subject_set text, p_note text default null)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old app.review_rubric_version;
  v_new uuid;
begin
  perform app.assert_config_writer();
  if p_subject_set not in ('TOAN', 'MON_PHU') then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Bộ tiêu chí phải là TOAN hoặc MON_PHU.');
  end if;
  select * into v_old from app.review_rubric_version where subject_set = p_subject_set and status = 'DANG_DUNG' for update;
  if v_old.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Chưa có phiên bản đang dùng để sao chép.');
  end if;
  update app.review_rubric_version set status = 'NGUNG' where id = v_old.id;
  insert into app.review_rubric_version (subject_set, version_no, status, note)
  values (p_subject_set, (select max(version_no) + 1 from app.review_rubric_version where subject_set = p_subject_set), 'DANG_DUNG',
          nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_new;
  insert into app.review_level_desc (version_id, criterion_id, level, description)
  select v_new, d.criterion_id, d.level, d.description from app.review_level_desc d where d.version_id = v_old.id;
  return v_new;
end;
$$;

-- 7. app.set_review_criterion_active(p_criterion_id, p_active): Ngừng hoặc dùng lại một tiêu chí. Không xoá (CH-07).
-- Ai gọi: Admin. Luật: mỗi nhóm của mỗi bộ còn ít nhất một tiêu chí đang dùng (giữ 3 nhóm). Buổi đã mở giữ tiêu chí đã chụp.
create or replace function app.set_review_criterion_active(p_criterion_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.review_criterion;
  v_set text;
begin
  perform app.assert_config_writer();
  select * into c from app.review_criterion where id = p_criterion_id for update;
  if c.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy tiêu chí.');
  end if;
  if p_active is null then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Cần chọn Ngừng hoặc Dùng lại.');
  end if;
  update app.review_criterion set is_active = p_active where id = p_criterion_id;
  if not p_active then
    -- Luật CH-07: mỗi bộ bị ảnh hưởng phải còn ít nhất một tiêu chí đang dùng trong nhóm này.
    for v_set in select unnest(case when c.subject_set = 'MOI_MON' then array['TOAN', 'MON_PHU'] else array[c.subject_set] end) loop
      if not exists (select from app.review_criterion x
                      where x.is_active and x.group_code = c.group_code and x.subject_set in ('MOI_MON', v_set)) then
        perform app.raise_error('HMT_RUBRIC_NHOM_TRONG', 'Nhóm này phải còn ít nhất một tiêu chí đang dùng.');
      end if;
    end loop;
  end if;
end;
$$;

revoke execute on function app.get_rubric(text, uuid), app.update_review_level_desc(uuid, uuid, integer, text),
  app.create_rubric_version(text, text), app.set_review_criterion_active(uuid, boolean) from public, anon, authenticated;
grant execute on function app.get_rubric(text, uuid), app.update_review_level_desc(uuid, uuid, integer, text),
  app.create_rubric_version(text, text), app.set_review_criterion_active(uuid, boolean) to authenticated;
