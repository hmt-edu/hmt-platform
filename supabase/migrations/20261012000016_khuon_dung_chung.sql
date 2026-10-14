-- GĐ0 bước 4b: nền dữ liệu cho khuôn giao diện dùng chung.
--   1. Tìm không dấu (S03-15): hàm gấp chữ + cột tìm kiếm trên tài khoản.
--   2. Ghi chú gắn vào tài khoản người dùng; nhắc tên đồng nghiệp sinh thông báo (CHUNG-22, CHUNG-12).
--   3. Lịch sử thay đổi của một bản ghi cho người thấy được bản ghi đó (CHUNG-22).
--   4. Bộ lọc yêu thích (CHUNG-19).
--   5. Tìm kiếm toàn hệ thống (CHUNG-11): giai đoạn 0 mới có tài khoản người dùng.
-- Luật: docs/spec/03 mục "Nền dữ liệu" và "Giao diện"; mã S03-13, S03-15, S03-16, S03-17 trong
-- docs/design/ma-luat-S02-S03.md.

select set_config('hmt.migration', 'on', false);

-- ===========================================================================
-- 0. Danh mục, tham số mới (không viết số, danh sách trong code)
-- ===========================================================================
insert into app.catalog (code, name, kind, parent_catalog, linked_catalog, description, sort_order) values
  ('NOTIFICATION_KIND', 'Loại thông báo', 'HE_THONG', null, null,
   'Loại thông báo trong trung tâm thông báo. Giai đoạn 0 chỉ có "được nhắc tên"; loại khác thêm theo giai đoạn.', 60);
insert into app.catalog_item (catalog_code, code, name, sort_order, is_locked) values
  ('NOTIFICATION_KIND', 'MENTION', 'Được nhắc tên', 1, true);

insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('list_page_size', 'Số dòng mỗi trang danh sách', 'INT', 'dòng', 10, 100, '25', false, null, null,
   'Số dòng mỗi trang ở các màn danh sách, lịch sử thay đổi, trung tâm thông báo.'),
  ('note_mention_max', 'Số người nhắc tên tối đa trong một ghi chú', 'INT', 'người', 1, 50, '10', false, null, null,
   'Một ghi chú nhắc tên tối đa bấy nhiêu đồng nghiệp (mỗi người nhận một thông báo).'),
  ('search_result_max', 'Số kết quả tìm nhanh', 'INT', 'dòng', 5, 50, '8', false, null, null,
   'Số kết quả tối đa của ô tìm kiếm toàn hệ thống và ô gõ @ nhắc tên.'),
  ('search_min_length', 'Số ký tự tối thiểu để tìm', 'INT', 'ký tự', 1, 5, '2', false, null, null,
   'Ô tìm kiếm toàn hệ thống chỉ tìm khi đã gõ đủ bấy nhiêu ký tự.');

-- ===========================================================================
-- 1. Tìm không dấu
-- ===========================================================================
create extension if not exists unaccent with schema extensions;

-- Gấp chữ để tìm: bỏ dấu tiếng Việt, đổi về chữ thường ("Đặng Quốc Huy" -> "dang quoc huy").
-- Ai gọi: mọi nơi cần so chữ không dấu (cột tìm kiếm, hàm tìm). Đầu vào: chuỗi bất kỳ. Kết quả: chuỗi đã gấp.
-- Khai IMMUTABLE để dùng được trong cột sinh tự động: từ điển unaccent đi kèm Postgres, không đổi khi chạy.
create or replace function app.fold_text(p_text text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select lower(extensions.unaccent('extensions.unaccent'::regdictionary, coalesce(p_text, '')));
$$;
grant execute on function app.fold_text(text) to authenticated;

-- Cột tìm kiếm của tài khoản: tên, tên đăng nhập, mã nhân viên/học sinh, mã cũ (S03-15), đã gấp chữ.
alter table app.user_account
  add column search_text text generated always as (
    app.fold_text(display_name || ' ' || login_name || ' ' || coalesce(staff_code, '') || ' '
                  || coalesce(student_code, '') || ' ' || coalesce(legacy_ref, ''))
  ) stored;

-- ===========================================================================
-- 2. Ghi chú gắn vào tài khoản người dùng
-- ===========================================================================
insert into app.note_target (entity_type, table_name, name) values
  ('USER_ACCOUNT', 'app.user_account', 'Tài khoản người dùng');

-- Người đang thao tác có thấy bản ghi được gắn ghi chú không (thấy thì đọc và viết ghi chú được).
-- Ai gọi: policy của app.note, các hàm ghi chú, lịch sử. Đầu vào: loại bản ghi, id. Kết quả: true/false.
-- Thêm so với migration 014: tài khoản người dùng xét theo quyền Tài khoản · Xem của cơ sở tài khoản đó.
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
-- 3. Nhắc tên và thông báo
-- ===========================================================================
create table app.note_mention (
  note_id uuid not null references app.note (id),
  user_id uuid not null references app.user_account (id),
  primary key (note_id, user_id)
);
comment on table app.note_mention is 'Ai được nhắc tên trong ghi chú nào (chỉ thêm qua app.add_note_mentioning).';
create index note_mention_user_idx on app.note_mention (user_id);
alter table app.note_mention enable row level security;
revoke all on app.note_mention from public, anon, authenticated;
-- Luật: thấy được ghi chú (tức thấy bản ghi) thì thấy ai được nhắc tên trong đó.
create policy note_mention_read on app.note_mention for select to authenticated
  using (exists (select from app.note n where n.id = note_id));
grant select on app.note_mention to authenticated;

-- Thông báo của từng người. Không chép nội dung ghi chú: người nhận mở bản ghi mới đọc được,
-- lúc đó quyền xem bản ghi vẫn do RLS quyết định (S03-16).
create table app.notification (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references app.user_account (id),
  kind text not null,
  title text not null check (btrim(title) <> ''),
  entity_type text references app.note_target (entity_type),
  entity_id uuid,
  note_id uuid references app.note (id),
  actor_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
comment on table app.notification is 'Thông báo cho từng người dùng. Tạo qua hàm nghiệp vụ; người nhận chỉ đánh dấu đã đọc.';
create index notification_user_idx on app.notification (user_id, created_at desc);
create index notification_unread_idx on app.notification (user_id) where read_at is null;
alter table app.notification enable row level security;
revoke all on app.notification from public, anon, authenticated;
-- Luật: mỗi người chỉ thấy thông báo của mình; tài khoản bị khoá hoặc chưa đủ bước đăng nhập thì không thấy.
create policy notification_read_own on app.notification for select to authenticated
  using (user_id = auth.uid() and app.current_user_ready() and app.mfa_satisfied());
grant select on app.notification to authenticated;

-- Luật: loại thông báo phải là mục đang dùng của danh mục NOTIFICATION_KIND.
create or replace function app.tg_notification_rules()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform app.assert_catalog_code_active('NOTIFICATION_KIND', new.kind);
  return new;
end;
$$;
create trigger notification_rules before insert on app.notification
  for each row execute function app.tg_notification_rules();

-- Người đang thao tác có phải nhân viên, giáo viên (không phải học sinh) đang hoạt động không.
-- Ai gọi: các hàm nhắc tên. Kết quả: true/false.
create or replace function app.current_user_is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app.current_user_ready() and app.mfa_satisfied()
     and exists (select from app.user_account where id = auth.uid() and student_code is null);
$$;

-- Gợi ý đồng nghiệp khi gõ @ trong ghi chú.
-- Ai gọi: nhân viên, giáo viên đã đăng nhập (học sinh không gọi được).
-- Đầu vào: chữ đang gõ (có dấu hay không đều được). Kết quả: id, tên, vai trò, mã cơ sở.
-- Luật: chỉ trả tài khoản nhân viên, giáo viên chưa khoá; chỉ trả tên, vai trò, cơ sở (không email, không mã),
-- vì người gõ có thể không có quyền xem danh sách tài khoản. Số dòng theo tham số search_result_max.
create or replace function app.mention_candidates(p_query text)
returns table (id uuid, display_name text, role_names text, branch_code text)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app.current_user_is_staff() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền nhắc tên đồng nghiệp.');
  end if;
  return query
    select a.id, a.display_name,
           (select string_agg(r.name, ', ' order by r.sort_order)
              from app.user_role ur join app.role r on r.code = ur.role_code
             where ur.user_id = a.id and ur.is_active),
           b.code
      from app.user_account a
      join app.branch b on b.id = a.branch_id
     where not a.is_locked
       and a.student_code is null
       and a.id <> auth.uid()
       and app.fold_text(a.display_name) like '%' || app.fold_text(btrim(p_query)) || '%'
     order by a.display_name
     limit app.get_setting_int('search_result_max');
end;
$$;

-- Thêm ghi chú có nhắc tên đồng nghiệp; mỗi người được nhắc nhận một thông báo.
-- Ai gọi: người thấy được bản ghi (kiểm trong app.add_note). Đầu vào: loại bản ghi, id, nội dung, danh sách id
-- người được nhắc (rỗng cũng được). Kết quả: id ghi chú.
create or replace function app.add_note_mentioning(
  p_entity_type text, p_entity_id uuid, p_body text, p_mention_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note_id uuid;
  v_ids uuid[];
  v_actor_name text;
  v_target_name text;
begin
  -- Quyền ghi chú và các luật của ghi chú: dùng lại hàm đã có.
  v_note_id := app.add_note(p_entity_type, p_entity_id, p_body);

  -- Bỏ trùng và bỏ chính mình (tự nhắc tên mình thì không báo).
  select coalesce(array_agg(distinct m), '{}') into v_ids
    from unnest(coalesce(p_mention_ids, '{}'::uuid[])) as m
   where m is not null and m is distinct from auth.uid();
  if cardinality(v_ids) = 0 then
    return v_note_id;
  end if;

  -- Luật: chỉ nhân viên, giáo viên được nhắc tên người khác.
  if not app.current_user_is_staff() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền nhắc tên đồng nghiệp.');
  end if;

  -- Luật: số người nhắc tên trong một ghi chú không vượt tham số note_mention_max.
  if cardinality(v_ids) > app.get_setting_int('note_mention_max') then
    perform app.raise_error('HMT_NHAC_TEN_QUA_NHIEU',
      format('Một ghi chú chỉ nhắc tên tối đa %s người.', app.get_setting_int('note_mention_max')));
  end if;

  -- Luật: chỉ nhắc tên được nhân viên, giáo viên đang hoạt động (không khoá, không phải học sinh).
  if exists (select from unnest(v_ids) as m
              where not exists (select from app.user_account a
                                 where a.id = m and not a.is_locked and a.student_code is null)) then
    perform app.raise_error('HMT_NHAC_TEN_KHONG_HOP_LE',
      'Có người được nhắc tên không còn hoạt động hoặc không phải nhân viên, giáo viên.');
  end if;

  insert into app.note_mention (note_id, user_id) select v_note_id, m from unnest(v_ids) as m;

  -- Thông báo chỉ nói ai nhắc, ở loại bản ghi nào; không chép nội dung ghi chú.
  select display_name into v_actor_name from app.user_account where id = auth.uid();
  select name into v_target_name from app.note_target where entity_type = p_entity_type;
  insert into app.notification (user_id, kind, title, entity_type, entity_id, note_id, actor_id)
  select m, 'MENTION',
         format('%s nhắc tên bạn trong một ghi chú (%s)', coalesce(v_actor_name, 'Hệ thống'), v_target_name),
         p_entity_type, p_entity_id, v_note_id, auth.uid()
    from unnest(v_ids) as m;
  return v_note_id;
end;
$$;

-- Ghi chú của một bản ghi kèm tên người viết và tên người được nhắc (CHUNG-22).
-- Ai gọi: người thấy được bản ghi. Đầu vào: loại bản ghi, id. Kết quả: ghi chú chưa huỷ, mới nhất trước.
-- Cần hàm riêng vì người đọc ghi chú có thể không có quyền xem bảng tài khoản để lấy tên người viết;
-- hàm chỉ trả tên hiển thị, không trả email hay mã.
create or replace function app.record_notes(p_entity_type text, p_entity_id uuid)
returns table (id uuid, at timestamptz, author_id uuid, author_name text, body text, mention_names text[])
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  -- Luật: không thấy bản ghi thì không đọc được ghi chú của nó.
  if not app.can_see_note_target(p_entity_type, p_entity_id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem ghi chú của bản ghi này.');
  end if;
  return query
    select n.id, n.created_at, n.created_by, coalesce(a.display_name, 'Hệ thống'), n.body,
           coalesce((select array_agg(m.display_name order by m.display_name)
                       from app.note_mention nm join app.user_account m on m.id = nm.user_id
                      where nm.note_id = n.id), '{}')
      from app.note n
      left join app.user_account a on a.id = n.created_by
     where n.entity_type = p_entity_type and n.entity_id = p_entity_id and not n.is_cancelled
     order by n.created_at desc;
end;
$$;

-- Đánh dấu đã đọc. Ai gọi: chính người nhận. Đầu vào: id một thông báo, hoặc p_all = true để đánh dấu mọi
-- thông báo chưa đọc của mình (không truyền gì thì không làm gì). Kết quả: số thông báo vừa đánh dấu.
create or replace function app.mark_notifications_read(p_id uuid default null, p_all boolean default false)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  if not (app.current_user_ready() and app.mfa_satisfied()) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn chưa đăng nhập đủ bước.');
  end if;
  -- Luật: chỉ đánh dấu thông báo của chính mình.
  update app.notification set read_at = now()
   where user_id = auth.uid() and read_at is null and (coalesce(p_all, false) or id = p_id);
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ===========================================================================
-- 4. Lịch sử thay đổi của một bản ghi
-- ===========================================================================
-- Cột kỹ thuật không đưa vào lịch sử cho người dùng xem (vẫn nằm đủ trong nhật ký thao tác của Admin).
create table app.history_hidden_column (
  table_name text not null,
  column_name text not null,
  primary key (table_name, column_name)
);
comment on table app.history_hidden_column is 'Cột kỹ thuật ẩn khỏi lịch sử thay đổi trên bản ghi (khai qua migration).';
alter table app.history_hidden_column enable row level security;
revoke all on app.history_hidden_column from public, anon, authenticated;

insert into app.history_hidden_column (table_name, column_name) values
  ('app.user_account', 'failed_login_count'),
  ('app.user_account', 'temp_locked_until'),
  ('app.user_account', 'last_login_at'),
  ('app.user_account', 'session_version'),
  ('app.user_account', 'locked_at'),
  ('app.user_account', 'locked_by'),
  ('app.user_account', 'search_text'),
  ('app.user_role', 'user_id'),
  ('app.user_role', 'role_code');

-- Lịch sử thay đổi của một bản ghi: ai đổi trường nào, từ gì sang gì, lúc nào (CHUNG-22).
-- Ai gọi: người thấy được bản ghi (cùng điều kiện với đọc ghi chú). Nhật ký toàn hệ thống vẫn chỉ ADMIN đọc.
-- Đầu vào: loại bản ghi, id, số dòng tối đa, mốc "trước lúc" để xem tiếp (NULL = mới nhất).
-- Kết quả: mỗi dòng một lần thay đổi; changes dạng {"cột": [cũ, mới]}, đã bỏ cột kỹ thuật.
-- Riêng tài khoản người dùng: gộp cả thay đổi vai trò (bảng user_role), cột hiện là "role:<tên vai trò>".
create or replace function app.record_history(
  p_entity_type text, p_entity_id uuid, p_limit integer default null, p_before timestamptz default null
)
returns table (id bigint, at timestamptz, actor_name text, action text, changes jsonb)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_table text;
begin
  -- Luật: không thấy bản ghi thì không xem được lịch sử của nó.
  if not app.can_see_note_target(p_entity_type, p_entity_id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lịch sử của bản ghi này.');
  end if;
  select table_name::text into v_table from app.note_target where entity_type = p_entity_type;

  return query
    with raw as (
      -- Thay đổi trên chính bản ghi.
      select l.id, l.at, l.actor, l.action::text as action,
             (select jsonb_object_agg(c.key, c.value)
                from jsonb_each(l.changes) as c
               where not exists (select from app.history_hidden_column h
                                  where h.table_name = v_table and h.column_name = c.key)) as changes
        from app.audit_log l
        join app.audited_table t on t.id = l.table_id
       where t.table_name = v_table and l.record_id = p_entity_id and l.action in ('I', 'U')
      union all
      -- Thay đổi vai trò của tài khoản: gán mới (I) hoặc bật/tắt (U).
      select l.id, l.at, l.actor, 'U',
             jsonb_build_object('role:' || r.name,
               case when l.action = 'I' then jsonb_build_array(false, true)
                    else l.changes -> 'is_active' end)
        from app.audit_log l
        join app.audited_table t on t.id = l.table_id
        join app.user_role ur on ur.id = l.record_id
        join app.role r on r.code = ur.role_code
       where p_entity_type = 'USER_ACCOUNT' and t.table_name = 'app.user_role' and ur.user_id = p_entity_id
         and (l.action = 'I' or (l.action = 'U' and l.changes ? 'is_active'))
    )
    select raw.id, raw.at, coalesce(a.display_name, 'Hệ thống'), raw.action, raw.changes
      from raw
      left join app.user_account a on a.id = raw.actor
     where (raw.action = 'I' or raw.changes is not null)
       and (p_before is null or raw.at < p_before)
     order by raw.at desc, raw.id desc
     limit least(coalesce(p_limit, app.get_setting_int('list_page_size')), app.get_setting_int('list_page_size'));
end;
$$;

-- ===========================================================================
-- 5. Bộ lọc yêu thích (CHUNG-19)
-- ===========================================================================
create table app.saved_filter (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references app.user_account (id),
  -- Mã màn danh sách trong docs/design/ban-do-man-hinh.md (vd QT-01).
  screen_code text not null check (screen_code ~ '^[A-Z]+-[0-9]+$'),
  name text not null check (btrim(name) <> ''),
  filters jsonb not null check (jsonb_typeof(filters) = 'object'),
  is_shared boolean not null default false,
  is_default boolean not null default false,
  is_cancelled boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.saved_filter is 'Bộ lọc đã lưu của từng người ở từng màn danh sách; có thể dùng chung.';
-- Luật: mỗi người, mỗi màn không có hai bộ lọc trùng tên; chỉ một bộ lọc mặc định.
create unique index saved_filter_name_uidx on app.saved_filter (owner_id, screen_code, lower(name))
  where not is_cancelled;
create unique index saved_filter_default_uidx on app.saved_filter (owner_id, screen_code)
  where is_default and not is_cancelled;
select app.apply_standard('app.saved_filter');

alter table app.saved_filter enable row level security;
revoke all on app.saved_filter from public, anon, authenticated;
-- Luật: thấy bộ lọc của mình và bộ lọc dùng chung; ghi chỉ qua hàm.
create policy saved_filter_read on app.saved_filter for select to authenticated
  using (not is_cancelled and app.current_user_ready() and app.mfa_satisfied()
         and (owner_id = auth.uid() or is_shared));
grant select on app.saved_filter to authenticated;

-- Lưu bộ lọc (tạo mới, hoặc ghi đè bộ lọc cùng tên của mình).
-- Ai gọi: nhân viên, giáo viên đã đăng nhập. Đầu vào: mã màn, tên, điều kiện lọc, dùng chung?, đặt mặc định?
-- Kết quả: id bộ lọc.
create or replace function app.save_filter(
  p_screen_code text, p_name text, p_filters jsonb, p_is_shared boolean, p_is_default boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if not app.current_user_is_staff() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền lưu bộ lọc.');
  end if;
  if btrim(coalesce(p_name, '')) = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Hãy đặt tên cho bộ lọc.');
  end if;
  -- Luật (tạm, chờ anh Trường chốt): chỉ quản trị viên tạo bộ lọc dùng chung cho mọi người.
  if coalesce(p_is_shared, false) and not app.has_permission('ADMIN', 'SUA') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên được lưu bộ lọc dùng chung.');
  end if;

  -- Luật: chỉ một bộ lọc mặc định cho mỗi người ở mỗi màn.
  if coalesce(p_is_default, false) then
    update app.saved_filter set is_default = false
     where owner_id = auth.uid() and screen_code = p_screen_code and is_default and not is_cancelled;
  end if;

  select id into v_id from app.saved_filter
   where owner_id = auth.uid() and screen_code = p_screen_code and lower(name) = lower(btrim(p_name))
     and not is_cancelled;
  if v_id is null then
    insert into app.saved_filter (owner_id, screen_code, name, filters, is_shared, is_default)
    values (auth.uid(), p_screen_code, btrim(p_name), p_filters, coalesce(p_is_shared, false), coalesce(p_is_default, false))
    returning id into v_id;
  else
    update app.saved_filter
       set filters = p_filters, is_shared = coalesce(p_is_shared, false), is_default = coalesce(p_is_default, false)
     where id = v_id;
  end if;
  return v_id;
end;
$$;

-- Bỏ bộ lọc đã lưu (huỷ, không xoá). Ai gọi: người tạo, hoặc quản trị viên với bộ lọc dùng chung.
create or replace function app.remove_filter(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not app.current_user_is_staff() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền bỏ bộ lọc.');
  end if;
  update app.saved_filter set is_cancelled = true, is_default = false
   where id = p_id and not is_cancelled
     and (owner_id = auth.uid() or (is_shared and app.has_permission('ADMIN', 'SUA')));
  if not found then
    perform app.raise_error('HMT_BO_LOC_KHONG_CO', 'Không tìm thấy bộ lọc, hoặc bộ lọc không phải của bạn.');
  end if;
end;
$$;

-- ===========================================================================
-- 6. Tìm kiếm toàn hệ thống (CHUNG-11)
-- ===========================================================================
-- Tìm bản ghi theo tên, mã mới, mã cũ, không cần gõ dấu (S03-15).
-- Ai gọi: người đã đăng nhập; chạy bằng quyền của người gọi nên chỉ ra bản ghi người đó xem được (RLS).
-- Đầu vào: chữ cần tìm (đủ số ký tự của tham số search_min_length). Kết quả: loại bản ghi, id, tiêu đề, dòng phụ, mã.
-- Giai đoạn 0 mới có tài khoản người dùng; mỗi giai đoạn sau nối thêm một nhánh UNION (học sinh, lead, đơn…).
create or replace function app.search_records(p_query text)
returns table (entity_type text, entity_id uuid, title text, subtitle text, code text)
language sql
stable
set search_path = ''
as $$
  select 'USER_ACCOUNT', a.id, a.display_name, a.login_name, coalesce(a.staff_code, a.student_code)
    from app.user_account a
   where length(btrim(p_query)) >= app.get_setting_int('search_min_length')
     and a.search_text like '%' || app.fold_text(btrim(p_query)) || '%'
   order by a.display_name
   limit app.get_setting_int('search_result_max');
$$;

-- Hàm mới mặc định không ai chạy được (migration 014): cấp rõ cho người đã đăng nhập.
grant execute on function
  app.mention_candidates(text),
  app.add_note_mentioning(text, uuid, text, uuid[]),
  app.mark_notifications_read(uuid, boolean),
  app.record_notes(text, uuid),
  app.record_history(text, uuid, integer, timestamptz),
  app.save_filter(text, text, jsonb, boolean, boolean),
  app.remove_filter(uuid),
  app.search_records(text),
  app.current_user_is_staff()
to authenticated;

select set_config('hmt.migration', '', false);
