-- KH-07 PR2 (DB): hộp so sánh khi gộp PHỤ HUYNH, HỌC SINH trên bản ghi (R-CRM-25, anh chốt 20/11/2026).
-- Thêm: app.merge_candidates_people (gợi ý bản trùng), app.merge_side_people (một bên của hộp so sánh); thay app.merge_preview
-- để trả thêm sides, move đầy đủ (mọi nhóm dữ liệu sẽ chuyển) và money (số dư sẽ chuyển) cho PARENT, STUDENT. LEAD, OPPORTUNITY giữ nguyên.
-- Quyền như gộp thật: hành động Duyệt trên phân hệ Phụ huynh, Học sinh; khác cơ sở chỉ Admin (R-CRM-22, 25).

-- ---------------------------------------------------------------------------
-- 1. app.merge_candidates_people(loại, id): gợi ý bản trùng cho phụ huynh (cùng SĐT hoặc SĐT 2) và học sinh (cùng phụ huynh, em cùng
--    tên và năm sinh xếp trước). Mỗi gợi ý kèm can_merge và lý do chặn đầu tiên (cơ sở, phụ huynh, cùng lớp, trùng giờ).
--    Ai gọi: người có quyền Duyệt loại hồ sơ. Hồ sơ gốc ngoài phạm vi Xem coi như không có (không lộ sự tồn tại).
-- ---------------------------------------------------------------------------
create or replace function app.merge_candidates_people(p_entity text, p_id uuid)
returns table (id uuid, code text, label text, branch_code text, stage_code text, created_at timestamptz, can_merge boolean,
               blocker_code text, blocker_message text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text;
  v_cur uuid := app.current_branch_id();
  v_max integer := app.get_setting_int('merge_preview_max_items');
  v_branch uuid;
  v_status text;
  v_phone text;
  v_phone2 text;
  v_parent uuid;
  v_name text;
  v_year integer;
begin
  if p_entity not in ('PARENT', 'STUDENT') then
    perform app.raise_error('HMT_LOAI_BAN_GHI_SAI', 'Chỉ gợi ý bản trùng cho phụ huynh và học sinh.');
  end if;
  -- Luật R-CRM-25: quyền Duyệt (gộp).
  v_scope := app.permission_scope(p_entity, 'DUYET');
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền gộp loại hồ sơ này.');
  end if;
  if p_entity = 'PARENT' then
    select p.branch_id, p.record_status, p.phone, p.phone_2 into v_branch, v_status, v_phone, v_phone2 from app.parent p where p.id = p_id;
  else
    select s.branch_id, s.record_status, s.parent_id, s.full_name, s.birth_year into v_branch, v_status, v_parent, v_name, v_year
      from app.student s where s.id = p_id;
  end if;
  -- Hồ sơ gốc ngoài phạm vi xem được coi như không có (không lộ sự tồn tại).
  if v_branch is null or not app.can_see_branch(p_entity, 'XEM', v_branch) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy hồ sơ.');
  end if;
  if v_status <> 'DANG_DUNG' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Hồ sơ này đã gộp vào bản khác, không gộp tiếp được.');
  end if;

  if p_entity = 'PARENT' then
    return query
      select p.id, p.code, p.full_name, b.code, ''::text, p.created_at, x.blocker is null, x.blocker, x.msg
        from app.parent p
        join app.branch b on b.id = p.branch_id
        cross join lateral (
          -- Luật R-CRM-25: khác cơ sở thì chỉ phạm vi toàn hệ thống gộp được.
          select case when v_scope <> 'TOAN_HE_THONG' and (v_branch is distinct from v_cur or p.branch_id is distinct from v_cur)
                      then case when v_branch is distinct from p.branch_id then 'HMT_GOP_KHAC_CO_SO' else 'HMT_KHONG_CO_QUYEN' end end as blocker,
                 case when v_scope <> 'TOAN_HE_THONG' and (v_branch is distinct from v_cur or p.branch_id is distinct from v_cur)
                      then case when v_branch is distinct from p.branch_id then 'Hai hồ sơ thuộc hai cơ sở khác nhau: chỉ Admin gộp được.'
                                else 'Bạn không có quyền gộp hồ sơ của cơ sở khác.' end end as msg) x
       where p.id <> p_id and p.record_status = 'DANG_DUNG'
         and ((v_phone is not null and (p.phone = v_phone or p.phone_2 = v_phone))
              or (v_phone2 is not null and (p.phone = v_phone2 or p.phone_2 = v_phone2)))
         and app.can_see_branch('PARENT', 'XEM', p.branch_id)
       order by p.created_at desc, p.id
       limit v_max;
  else
    return query
      select s.id, s.code, s.full_name || coalesce(' · ' || s.birth_year::text, ''), b.code, ''::text, s.created_at,
             x.blocker is null, x.blocker, x.msg
        from app.student s
        join app.branch b on b.id = s.branch_id
        cross join lateral (
          select case when v_scope <> 'TOAN_HE_THONG' and (v_branch is distinct from v_cur or s.branch_id is distinct from v_cur)
                      then case when v_branch is distinct from s.branch_id then 'HMT_GOP_KHAC_CO_SO' else 'HMT_KHONG_CO_QUYEN' end
                      else c.first_code end as blocker,
                 case when v_scope <> 'TOAN_HE_THONG' and (v_branch is distinct from v_cur or s.branch_id is distinct from v_cur)
                      then case when v_branch is distinct from s.branch_id then 'Hai hồ sơ thuộc hai cơ sở khác nhau: chỉ Admin gộp được.'
                                else 'Bạn không có quyền gộp hồ sơ của cơ sở khác.' end
                      else c.first_msg end as msg
            from (select (app.merge_check_students(p_id, s.id) -> 'blockers' -> 0 ->> 'code') as first_code,
                         (app.merge_check_students(p_id, s.id) -> 'blockers' -> 0 ->> 'message') as first_msg) c) x
       where s.parent_id = v_parent and s.id <> p_id and s.record_status = 'DANG_DUNG'
         and app.can_see_branch('STUDENT', 'XEM', s.branch_id)
       -- Em cùng tên (chuẩn hoá) và năm sinh xếp trước: thường là hồ sơ nhập trùng.
       order by (app.normalize_person_name(s.full_name) = app.normalize_person_name(v_name) and s.birth_year is not distinct from v_year) desc,
                s.created_at desc, s.id
       limit v_max;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. app.merge_side_people(loại, id): một bên của hộp so sánh (nội bộ, không cấp cho giao diện).
--    Giữ các khoá chung với lead, cơ hội (parent_name, phone, student_name, owner, branch_code, created_at, appointments, notes)
--    và thêm counts: số dòng theo nhóm dữ liệu sẽ chuyển.
-- ---------------------------------------------------------------------------
create or replace function app.merge_side_people(p_entity text, p_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when p_entity = 'PARENT' then
    (select jsonb_build_object(
        'code', p.code, 'parent_name', p.full_name, 'phone', p.phone, 'phone_2', p.phone_2, 'student_name', null, 'owner', null,
        'branch_code', (select b.code from app.branch b where b.id = p.branch_id), 'created_at', p.created_at,
        'appointments', 0, 'notes', (select count(*) from app.note n where n.entity_type = 'PARENT' and n.entity_id = p.id),
        'counts', jsonb_build_object(
          'students', (select count(*) from app.student s where s.parent_id = p.id and s.record_status = 'DANG_DUNG'),
          'leads', (select count(*) from app.lead l where l.parent_id = p.id),
          'opportunities', (select count(*) from app.opportunity o where o.parent_id = p.id),
          'orders', (select count(*) from app.sales_order o where o.parent_id = p.id),
          'receipts', (select count(*) from app.receipt r where r.parent_id = p.id),
          'enrollments', (select count(*) from app.enrollment e where e.parent_id = p.id)))
       from app.parent p where p.id = p_id)
  else
    (select jsonb_build_object(
        'code', s.code, 'parent_name', pp.full_name, 'phone', pp.phone, 'student_name', s.full_name, 'owner', null,
        'birth_year', s.birth_year, 'grade', s.grade,
        'branch_code', (select b.code from app.branch b where b.id = s.branch_id), 'created_at', s.created_at,
        'appointments', 0, 'notes', (select count(*) from app.note n where n.entity_type = 'STUDENT' and n.entity_id = s.id),
        'counts', jsonb_build_object(
          'enrollments', (select count(*) from app.enrollment e where e.student_id = s.id),
          'tests', (select count(*) from app.student_test t where t.student_id = s.id),
          'attendance', (select count(*) from app.session_attendance a where a.student_id = s.id)))
       from app.student s join app.parent pp on pp.id = s.parent_id where s.id = p_id)
  end;
$$;

-- ---------------------------------------------------------------------------
-- 3. app.merge_preview: thay thân hàm của migration 043. LEAD, OPPORTUNITY giữ nguyên. PARENT, STUDENT: thêm sides (hai bên),
--    move đầy đủ mọi nhóm dữ liệu sẽ chuyển (kể cả tiền) và money (tổng số dư của bản bị gộp, sẽ cộng vào bản giữ lại);
--    STUDENT dùng điều kiện chặn mới (cùng lớp, trùng giờ). Cùng kiểm quyền với gộp thật (merge_common).
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
      'opportunities', (select count(*) from app.prospect_student where student_id = p_merge and opportunity_id is not null),
      'tests', (select count(*) from app.student_test where student_id = p_merge),
      'enrollments', (select count(*) from app.enrollment where student_id = p_merge),
      'attendance', (select count(*) from app.session_attendance where student_id = p_merge),
      'balance_entries', (select count(*) from app.customer_balance_entry where student_id = p_merge),
      'notes', (select count(*) from app.note where entity_type = 'STUDENT' and entity_id = p_merge));
  else
    v_move := jsonb_build_object(
      'leads', (select count(*) from app.lead where parent_id = p_merge and record_status <> 'DA_HUY'),
      'opportunities', (select count(*) from app.opportunity where parent_id = p_merge),
      'students', (select count(*) from app.student where parent_id = p_merge),
      'quotations', (select count(*) from app.quotation where parent_id = p_merge),
      'orders', (select count(*) from app.sales_order where parent_id = p_merge),
      'receipts', (select count(*) from app.receipt where parent_id = p_merge),
      'enrollments', (select count(*) from app.enrollment where parent_id = p_merge),
      'balance_entries', (select count(*) from app.customer_balance_entry where parent_id = p_merge),
      'notes', (select count(*) from app.note where entity_type = 'PARENT' and entity_id = p_merge));
  end if;
  -- Hộp TS-10 (lead, cơ hội): so sánh hai bên và liệt kê mục sẽ chuyển.
  if p_entity in ('LEAD', 'OPPORTUNITY') then
    v_extra := jsonb_build_object(
      'sides', jsonb_build_object('keep', app.merge_side(p_entity, p_keep), 'merge', app.merge_side(p_entity, p_merge)),
      'items', app.merge_items(p_entity, p_merge));
  else
    -- Hộp KH-07 (phụ huynh, học sinh): so sánh hai bên; không liệt kê từng dòng, chỉ số dòng và số dư sẽ chuyển.
    v_extra := jsonb_build_object(
      'sides', jsonb_build_object('keep', app.merge_side_people(p_entity, p_keep), 'merge', app.merge_side_people(p_entity, p_merge)),
      'items', jsonb_build_object('appointments', '[]'::jsonb, 'notes', '[]'::jsonb),
      'money', jsonb_build_object('balance', (app.merge_totals(p_entity, array[p_merge]) ->> 'balance')::bigint));
  end if;
  return v_info || jsonb_build_object('move', v_move) || v_check || v_extra;
end;
$$;

revoke execute on function app.merge_side_people(text, uuid) from public, anon, authenticated;
revoke execute on function app.merge_candidates_people(text, uuid) from public, anon;
grant execute on function app.merge_candidates_people(text, uuid) to authenticated;
