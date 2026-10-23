-- P3f-1: dữ liệu cho hộp Gộp trùng (TS-10): gợi ý bản trùng và danh sách mục sẽ chuyển (docs/spec/04 R-CRM-22, 37).
-- Không đổi luật gộp (merge_leads, merge_opportunities giữ nguyên từ migration 031). Thêm:
--   1. Tham số merge_preview_max_items (số mục tối đa hiện ở hộp xem trước và ở danh sách gợi ý).
--   2. app.merge_candidates: gợi ý "bản kia" cho lead (cùng SĐT) hoặc cơ hội (cùng phụ huynh). CHỈ trả bản người gọi được xem
--      (phạm vi cơ sở như RLS): người không phải Admin không thấy bản ở cơ sở khác, nên không lộ SĐT, tên.
--   3. app.merge_preview thay thân: thêm so sánh hai bên (sides) và danh sách lịch hẹn, ghi chú sẽ chuyển (items).

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Tham số: số mục tối đa hiện trong hộp Gộp trùng (danh sách gợi ý, lịch hẹn và ghi chú ở bước xem trước).
-- ---------------------------------------------------------------------------
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('merge_preview_max_items', 'Số mục tối đa hiện trong hộp Gộp trùng', 'INT', 'mục', 5, 100, '20', false, 'BAN_HANG', null,
   'Giới hạn danh sách bản trùng gợi ý, lịch hẹn và ghi chú liệt kê ở bước xem trước khi gộp lead, cơ hội (TS-10).');

-- ---------------------------------------------------------------------------
-- Gợi ý bản trùng (TS-10). Ai gọi: người có quyền Duyệt trên loại hồ sơ (R-CRM-22), xem được bản gốc.
-- Đầu vào: p_entity (LEAD hoặc OPPORTUNITY), p_id (hồ sơ đang mở).
-- Kết quả: tối đa merge_preview_max_items dòng, mới nhất trước: {id, code, label, branch_code, stage_code, created_at,
--   can_merge, blocker_code, blocker_message}. can_merge = false kèm mã và câu tiếng Việt khi không gộp được.
-- Luật:
--   - Lead trùng khi cùng SĐT đã chuẩn hoá; cơ hội trùng khi cùng phụ huynh. Bỏ chính nó và bản "Đã gộp".
--   - Phạm vi xem (như RLS): chỉ trả bản ở cơ sở người gọi được xem; người một cơ sở không thấy bản cơ sở khác.
--   - R-CRM-22: người không có phạm vi toàn hệ thống chỉ gộp khi cả hai ở cơ sở mình; cờ HMT_GOP_KHAC_CO_SO chỉ gặp ở người xem
--     được nhiều cơ sở mà không phải Admin.
--   - R-CRM-37a (cơ hội): khác học sinh thì gộp học sinh trước (HMT_GOP_KHAC_HOC_SINH). Báo giá, đơn của bản bị gộp phụ thuộc
--     chiều gộp nên để bước xem trước (merge_preview) báo sau khi chọn bản giữ lại.
-- ---------------------------------------------------------------------------
create or replace function app.merge_candidates(p_entity text, p_id uuid)
returns table (
  id uuid, code text, label text, branch_code text, stage_code text, created_at timestamptz,
  can_merge boolean, blocker_code text, blocker_message text)
language plpgsql
stable
security definer
set search_path = ''
as $$
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
    select o.parent_id, o.student_id, o.student_name, o.student_birth_year, o.branch_id, o.record_status
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
      select l.id, l.code, l.parent_name || coalesce(' · ' || nullif(l.student_name, ''), ''), b.code, l.stage_code, l.created_at,
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
      select o.id, o.code, p.full_name || coalesce(' · ' || nullif(o.student_name, ''), ''), b.code, o.stage_code, o.created_at,
             x.blocker is null, x.blocker, x.msg
        from app.opportunity o
        join app.parent p on p.id = o.parent_id
        join app.branch b on b.id = o.branch_id
        cross join lateral (
          -- Luật R-CRM-22 (cơ sở) rồi R-CRM-37a (khác học sinh thì gộp học sinh trước).
          select case
                   when v_scope <> 'TOAN_HE_THONG' and (v_branch is distinct from v_cur or o.branch_id is distinct from v_cur)
                     then case when v_branch is distinct from o.branch_id then 'HMT_GOP_KHAC_CO_SO' else 'HMT_KHONG_CO_QUYEN' end
                   when (v_student is not null and o.student_id is not null and v_student <> o.student_id)
                        or (v_student_name is not null and v_student_year is not null and o.student_name is not null
                            and o.student_birth_year is not null
                            and (app.normalize_person_name(v_student_name) <> app.normalize_person_name(o.student_name)
                                 or v_student_year <> o.student_birth_year))
                     then 'HMT_GOP_KHAC_HOC_SINH' end as blocker,
                 case
                   when v_scope <> 'TOAN_HE_THONG' and (v_branch is distinct from v_cur or o.branch_id is distinct from v_cur)
                     then case when v_branch is distinct from o.branch_id then 'Hai hồ sơ thuộc hai cơ sở khác nhau: chỉ Admin gộp được.'
                               else 'Bạn không có quyền gộp hồ sơ của cơ sở khác.' end
                   when (v_student is not null and o.student_id is not null and v_student <> o.student_id)
                        or (v_student_name is not null and v_student_year is not null and o.student_name is not null
                            and o.student_birth_year is not null
                            and (app.normalize_person_name(v_student_name) <> app.normalize_person_name(o.student_name)
                                 or v_student_year <> o.student_birth_year))
                     then 'Hai cơ hội khác học sinh: gộp học sinh trước.' end as msg) x
       where o.parent_id = v_parent and o.id <> p_id and o.record_status = 'DANG_DUNG'
         and app.can_see_branch('OPPORTUNITY', 'XEM', o.branch_id)
       order by o.created_at desc, o.id
       limit v_max;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Một bên của hộp so sánh (TS-10): thông tin ngắn của lead hoặc cơ hội. Hàm nội bộ (merge_preview đã kiểm quyền).
-- ---------------------------------------------------------------------------
create or replace function app.merge_side(p_entity text, p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when p_entity = 'LEAD' then
    (select jsonb_build_object(
        'code', l.code, 'parent_name', l.parent_name, 'phone', l.parent_phone, 'student_name', l.student_name,
        'source', (select c.name from app.catalog_item c where c.catalog_code = l.source_catalog and c.code = l.source_code),
        'owner', (select u.display_name from app.user_account u where u.id = l.owner_id),
        'branch_code', (select b.code from app.branch b where b.id = l.branch_id), 'created_at', l.created_at,
        'opportunities', (select count(*) from app.opportunity o where o.lead_id = l.id),
        'appointments', (select count(*) from app.appointment a where a.lead_id = l.id),
        'notes', (select count(*) from app.note n where n.entity_type = 'LEAD' and n.entity_id = l.id))
       from app.lead l where l.id = p_id)
  else
    (select jsonb_build_object(
        'code', o.code, 'parent_name', p.full_name, 'phone', p.phone, 'student_name', o.student_name, 'stage_code', o.stage_code,
        'owner', (select u.display_name from app.user_account u where u.id = o.owner_id),
        'branch_code', (select b.code from app.branch b where b.id = o.branch_id), 'created_at', o.created_at,
        'tests', (select count(*) from app.student_test t where t.opportunity_id = o.id),
        'appointments', (select count(*) from app.appointment a where a.opportunity_id = o.id),
        'notes', (select count(*) from app.note n where n.entity_type = 'OPPORTUNITY' and n.entity_id = o.id))
       from app.opportunity o join app.parent p on p.id = o.parent_id where o.id = p_id)
  end;
$$;

-- ---------------------------------------------------------------------------
-- Danh sách lịch hẹn, ghi chú của bản bị gộp sẽ chuyển (TS-10, khung "Chuyển từ … sang …"). Tối đa merge_preview_max_items mục
-- mỗi loại (số thật nằm ở move). Hàm nội bộ. Kết quả: {appointments: [{title, scheduled_at, status}], notes: [{author, created_at, body}]}.
-- ---------------------------------------------------------------------------
create or replace function app.merge_items(p_entity text, p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'appointments', coalesce((
      select jsonb_agg(jsonb_build_object('title', a.title, 'scheduled_at', a.scheduled_at, 'status', a.status)
                       order by a.scheduled_at, a.id)
        from (select * from app.appointment x
               where (p_entity = 'LEAD' and x.lead_id = p_id) or (p_entity = 'OPPORTUNITY' and x.opportunity_id = p_id)
               order by x.scheduled_at, x.id limit app.get_setting_int('merge_preview_max_items')) a), '[]'::jsonb),
    'notes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'author', (select u.display_name from app.user_account u where u.id = n.created_by),
               'created_at', n.created_at, 'body', left(n.body, 200)) -- allow-number: độ dài hiển thị ghi chú trong hộp xem trước, không phải số nghiệp vụ
               order by n.created_at, n.id)
        from (select * from app.note x where x.entity_type = p_entity and x.entity_id = p_id
               order by x.created_at, x.id limit app.get_setting_int('merge_preview_max_items')) n), '[]'::jsonb));
$$;

-- ---------------------------------------------------------------------------
-- Xem trước gộp (TS-10, KH-07): thay thân hàm của migration 031, thêm sides và items cho lead, cơ hội.
-- Kết quả: {keep_code, merge_code, move: {…}, blockers: [{code, message}], warnings: [{code, message}],
--   sides: {keep, merge} và items: {appointments, notes} của bản bị gộp (chỉ lead, cơ hội)}.
-- Cùng kiểm quyền với gộp thật, không đổi gì.
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
  -- Hộp TS-10 (lead, cơ hội): so sánh hai bên và liệt kê mục sẽ chuyển.
  if p_entity in ('LEAD', 'OPPORTUNITY') then
    v_extra := jsonb_build_object(
      'sides', jsonb_build_object('keep', app.merge_side(p_entity, p_keep), 'merge', app.merge_side(p_entity, p_merge)),
      'items', app.merge_items(p_entity, p_merge));
  end if;
  return v_info || jsonb_build_object('move', v_move) || v_check || v_extra;
end;
$$;

revoke execute on function app.merge_side(text, uuid), app.merge_items(text, uuid) from public, anon, authenticated;
revoke execute on function app.merge_candidates(text, uuid) from public, anon;
grant execute on function app.merge_candidates(text, uuid) to authenticated;

select set_config('hmt.migration', '', false);
