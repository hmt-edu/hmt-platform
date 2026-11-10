-- Cụm Buổi A (BUOI-01, BUOI-02, BUOI-03, BUOI-11) và "Ghi chú vận hành (chỉ xem)" của GV-05: các hàm ĐỌC cho giao diện, không đổi luật ghi.
-- Luật: R-BUOI-02 (tình trạng buổi: Nháp, Đã chốt, Done, Huỷ có/không tính phí; buổi DA_THAY là mã kỹ thuật, không hiện), R-GIO-02 (danh sách chốt khi buổi Đã chốt),
-- R-GIO-05 (tự chốt), R-GIO-06 (lý do chưa Done), R-GIO-08 (chưa Đã chốt thì chưa có danh sách), R-DD-01/02/03 (hai cột điểm danh, ô giáo viên là chính thức,
-- lý do liên hệ ghi cho mọi trạng thái), R-GV-05 (hạn giáo viên hoàn tất = giờ kết thúc + tham số teacher_session_complete_hours), R-HT-07 (ngày theo giờ Việt Nam).
-- Phân trang ở máy chủ: mặc định list_page_size_default, tối đa list_page_size_max (CLAUDE.md, Hiệu năng). Hàm ghi dùng lại hàm D1c: app.close_session, app.mark_session_done,
-- app.set_attendance_ops (migration 102).

-- Phạm vi đọc buổi học của người gọi: toàn hệ thống hoặc cơ sở của mình (vận hành). Giáo viên ("được phân công") không dùng các màn vận hành này.
create or replace function app.session_read_scope()
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('SESSION', 'XEM');
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem buổi học.');
  end if;
  return v_scope;
end;
$$;

-- app.session_list(bộ lọc, sắp xếp, số dòng, bỏ qua): BUOI-01. Bộ lọc: date_from, date_to (ngày học), class_id, teacher_id, branch_id, status (mảng mã tình trạng buổi),
-- q (mã lớp). Sắp xếp: time_asc (mặc định: ngày, giờ), time_desc. Buổi DA_THAY không hiện.
-- Kết quả: {total, rows: [{id, session_date, start_time, end_time, class_id, class_code, subject_name, branch_code, session_no, type_code, type_name, teacher_name,
--   room_name, status_code, status_name, note}]}. note: lý do chưa Done của buổi Đã chốt (R-GIO-06); buổi khác để trống.
create or replace function app.session_list(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'time_asc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.session_read_scope();
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_from date := nullif(p_filters ->> 'date_from', '')::date;
  v_to date := nullif(p_filters ->> 'date_to', '')::date;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_teacher uuid := nullif(p_filters ->> 'teacher_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_status text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'status', '[]'::jsonb)));
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_desc boolean := p_sort = 'time_desc';
  v_result jsonb;
begin
  with f as not materialized (
    select s.*
      from app.class_session s
      join app.class c on c.id = s.class_id
     where s.status_code <> 'DA_THAY'
       -- Luật phạm vi: không phải toàn hệ thống thì chỉ thấy cơ sở của mình.
       and (v_scope = 'TOAN_HE_THONG' or s.branch_id = v_my_branch)
       and (v_branch is null or s.branch_id = v_branch)
       and (v_from is null or s.session_date >= v_from)
       and (v_to is null or s.session_date <= v_to)
       and (v_class is null or s.class_id = v_class)
       and (v_teacher is null or s.teacher_id = v_teacher)
       and (cardinality(v_status) = 0 or s.status_code = any (v_status))
       and (v_q is null or c.search_text like '%' || v_q || '%')
  ), page as (
    select * from f
     order by case when v_desc then null else f.session_date end asc, case when v_desc then null else f.start_time end asc,
              case when v_desc then f.session_date end desc, case when v_desc then f.start_time end desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'id', p.id, 'session_date', p.session_date, 'start_time', to_char(p.start_time, 'HH24:MI'), 'end_time', to_char(p.end_time, 'HH24:MI'),
                      'class_id', c.id, 'class_code', c.code, 'subject_name', sub.name, 'branch_code', b.code, 'session_no', p.session_no,
                      'type_code', p.type_code, 'type_name', ty.name, 'teacher_name', t.display_name, 'room_name', r.name,
                      'status_code', p.status_code, 'status_name', st.name,
                      'note', case when p.status_code = 'DA_CHOT' then app.session_pending_reason(p.id) end)
                    order by case when v_desc then null else p.session_date end asc, case when v_desc then null else p.start_time end asc,
                             case when v_desc then p.session_date end desc, case when v_desc then p.start_time end desc, p.id)
               from page p
               join app.class c on c.id = p.class_id
               join app.branch b on b.id = p.branch_id
               join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
               join app.catalog_item ty on ty.catalog_code = p.type_catalog and ty.code = p.type_code
               join app.catalog_item st on st.catalog_code = p.status_catalog and st.code = p.status_code
               left join app.user_account t on t.id = p.teacher_id
               left join app.room r on r.id = p.room_id), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

-- app.session_record(buổi): BUOI-02, bản ghi chỉ đọc. Ai xem được buổi theo quyền Buổi học · Xem (toàn hệ thống hoặc cơ sở; không phải giáo viên "được phân công").
-- Kết quả: {session: {...}, pending_reason, complete_deadline, listed, students: [...], excluded: [...], reviews: [...]}.
--   students: em trong danh sách (is_active) kèm điểm danh hai cột; mismatch = hai bên cùng ghi mà khác nhau (thẻ "Lệch", R-DD-02).
--   excluded: em có dòng bị loại khỏi danh sách kèm mã lý do (R-GIO-02). reviews: nhận xét của giáo viên cho từng em (rỗng khi chưa có).
--   complete_deadline: giờ kết thúc cộng teacher_session_complete_hours (R-GV-05); chỉ tính khi buổi Đã chốt.
create or replace function app.session_record(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_session jsonb;
  v_hours integer;
begin
  -- Luật phạm vi: thao tác của vận hành (giáo viên không mở bản ghi này).
  s := app.assert_session_access(p_id, 'SESSION', 'XEM', true);
  v_hours := app.get_setting_int('teacher_session_complete_hours', s.branch_id);

  select jsonb_build_object(
           'id', s.id, 'status_code', s.status_code, 'status_name', st.name, 'type_code', s.type_code, 'type_name', ty.name, 'session_no', s.session_no,
           'session_date', s.session_date, 'start_time', to_char(s.start_time, 'HH24:MI'), 'end_time', to_char(s.end_time, 'HH24:MI'),
           'class_id', c.id, 'class_code', c.code, 'subject_name', sub.name, 'branch_code', b.code, 'branch_name', b.name,
           'teacher_name', t.display_name, 'assistant_name', ta.display_name, 'room_name', r.name, 'start_lesson', c.start_lesson)
    into v_session
    from app.class c
    join app.branch b on b.id = s.branch_id
    join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
    join app.catalog_item ty on ty.catalog_code = s.type_catalog and ty.code = s.type_code
    join app.catalog_item st on st.catalog_code = s.status_catalog and st.code = s.status_code
    left join app.user_account t on t.id = s.teacher_id
    left join app.user_account ta on ta.id = s.assistant_id
    left join app.room r on r.id = s.room_id
   where c.id = s.class_id;

  return jsonb_build_object(
    'session', v_session,
    'pending_reason', case when s.status_code = 'DA_CHOT' then app.session_pending_reason(s.id) end,
    'complete_deadline', case when s.status_code = 'DA_CHOT' then app.session_ends_at(s.id) + make_interval(hours => v_hours) end,
    'listed', s.status_code in ('DA_CHOT', 'DONE'),
    -- Luật R-DD-02: hai cột; ô của giáo viên quyết định trạng thái chính thức, cột vận hành chỉ để đối chiếu.
    'students', coalesce((
      select jsonb_agg(jsonb_build_object(
               'student_id', st2.id, 'student_code', st2.code, 'full_name', st2.full_name, 'is_trial', sa.is_trial,
               'enrollment_code', e.code, 'ops_status_code', sa.ops_status_code, 'ops_status_name', os.name,
               'teacher_status_code', sa.teacher_status_code, 'teacher_status_name', ts.name,
               'mismatch', sa.ops_status_code is not null and sa.teacher_status_code is not null and sa.ops_status_code <> sa.teacher_status_code)
             order by st2.full_name, st2.id)
        from app.session_attendance sa
        join app.student st2 on st2.id = sa.student_id
        left join app.enrollment e on e.id = sa.enrollment_id
        left join app.catalog_item os on os.catalog_code = sa.ops_status_catalog and os.code = sa.ops_status_code
        left join app.catalog_item ts on ts.catalog_code = sa.teacher_status_catalog and ts.code = sa.teacher_status_code
       where sa.session_id = s.id and sa.is_active), '[]'::jsonb),
    -- Luật R-GIO-02: em không vào danh sách kèm lý do (chưa tới ngày vào lớp, bảo lưu, kết thúc, hết giờ).
    'excluded', coalesce((
      select jsonb_agg(jsonb_build_object('student_id', st2.id, 'student_code', st2.code, 'full_name', st2.full_name, 'reason_code', sa.excluded_reason)
             order by st2.full_name, st2.id)
        from app.session_attendance sa join app.student st2 on st2.id = sa.student_id
       where sa.session_id = s.id and not sa.is_active and sa.excluded_reason is not null), '[]'::jsonb),
    'reviews', coalesce((
      select jsonb_agg(jsonb_build_object('student_id', st2.id, 'full_name', st2.full_name, 'comment', rv.teacher_comment, 'teacher_status_code', sa.teacher_status_code)
             order by st2.full_name, st2.id)
        from app.session_attendance sa
        join app.student st2 on st2.id = sa.student_id
        left join app.session_student_review rv on rv.attendance_id = sa.id
       where sa.session_id = s.id and sa.is_active), '[]'::jsonb));
end;
$$;

-- app.session_ops_sheet(buổi): BUOI-03, bảng điểm danh phía vận hành của một buổi. Cần quyền Điểm danh · Sửa (vận hành: toàn hệ thống hoặc cơ sở).
-- Kết quả: {session: {...tiêu đề}, statuses: [{code, name}], reasons: [{code, name, requires_note}], listed, students: [{student_id, student_code, full_name,
--   ops_status_code, contact_reason_code, ops_note, teacher_status_code}]}. Buổi chưa Đã chốt/Done: listed = false (R-GIO-08). Ghi dùng app.set_attendance_ops.
create or replace function app.session_ops_sheet(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_session jsonb;
  v_statuses jsonb;
  v_reasons jsonb;
begin
  -- Luật R-DD-02, R-DD-03: chỉ vận hành ghi cột trung tâm và lý do liên hệ.
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'SUA', true);

  select jsonb_build_object(
           'id', s.id, 'status_code', s.status_code, 'session_no', s.session_no, 'session_date', s.session_date,
           'start_time', to_char(s.start_time, 'HH24:MI'), 'end_time', to_char(s.end_time, 'HH24:MI'), 'class_id', c.id, 'class_code', c.code,
           'subject_name', sub.name)
    into v_session
    from app.class c join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
   where c.id = s.class_id;

  select coalesce(jsonb_agg(jsonb_build_object('code', ci.code, 'name', ci.name) order by ci.sort_order), '[]'::jsonb) into v_statuses
    from app.catalog_item ci where ci.catalog_code = 'ATTENDANCE_STATUS' and ci.is_active;
  select coalesce(jsonb_agg(jsonb_build_object('code', ci.code, 'name', ci.name, 'requires_note', ci.requires_note) order by ci.sort_order), '[]'::jsonb) into v_reasons
    from app.catalog_item ci where ci.catalog_code = 'ATTENDANCE_CONTACT_REASON' and ci.is_active;

  if s.status_code not in ('DA_CHOT', 'DONE') then
    return jsonb_build_object('session', v_session, 'statuses', v_statuses, 'reasons', v_reasons, 'listed', false, 'students', '[]'::jsonb);
  end if;
  return jsonb_build_object('session', v_session, 'statuses', v_statuses, 'reasons', v_reasons, 'listed', true, 'students', coalesce((
    select jsonb_agg(jsonb_build_object(
             'student_id', st.id, 'student_code', st.code, 'full_name', st.full_name, 'ops_status_code', sa.ops_status_code,
             'contact_reason_code', sa.contact_reason_code, 'ops_note', sa.ops_note, 'teacher_status_code', sa.teacher_status_code)
           order by st.full_name, st.id)
      from app.session_attendance sa join app.student st on st.id = sa.student_id
     where sa.session_id = s.id and sa.is_active), '[]'::jsonb));
end;
$$;

-- app.absent_today_list(bộ lọc, số dòng, bỏ qua): BUOI-11, các em vắng hoặc chưa đến của buổi Đã chốt HÔM NAY (giờ Việt Nam) để CSKH gọi nhắc.
-- Trạng thái hiệu lực của em = ô giáo viên nếu có, không thì ô vận hành. "Vắng" = hiệu lực là Vắng có phép hoặc Vắng không phép.
-- "Chưa đến" = buổi đã bắt đầu mà chưa ai ghi trạng thái nào (cả hai ô trống). Em đã Có mặt, Đi muộn không hiện. Luật không định nghĩa chi tiết: chờ Chat xác nhận.
-- Cần quyền Điểm danh · Sửa (CSKH, Admin). Bộ lọc: branch_id, q (tên, mã học sinh hoặc mã lớp), kind ('VANG' hoặc 'CHUA_DEN').
-- Kết quả: {total, rows: [{session_id, student_id, student_name, class_code, subject_name, session_date, start_time, kind, ops_status_code, effective_status_code,
--   contact_reason_code, contact_reason_name, ops_note}]}.
create or replace function app.absent_today_list(
  p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ATTENDANCE', 'SUA');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date; -- Luật R-HT-07: ngày theo giờ Việt Nam.
  v_now_local time := (now() at time zone 'Asia/Ho_Chi_Minh')::time;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_kind text := nullif(p_filters ->> 'kind', '');
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_result jsonb;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền ghi điểm danh vận hành.');
  end if;
  with f as not materialized (
    select sa.*, s.session_date, s.start_time, c.code as class_code, c.subject_catalog, c.subject_code, st.full_name as student_name,
           coalesce(sa.teacher_status_code, sa.ops_status_code) as effective_status_code,
           case when coalesce(sa.teacher_status_code, sa.ops_status_code) in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP') then 'VANG' else 'CHUA_DEN' end as kind
      from app.session_attendance sa
      join app.class_session s on s.id = sa.session_id
      join app.class c on c.id = s.class_id
      join app.student st on st.id = sa.student_id
     where s.session_date = v_today and s.status_code = 'DA_CHOT' and sa.is_active
       and (v_scope = 'TOAN_HE_THONG' or s.branch_id = v_my_branch)
       and (v_branch is null or s.branch_id = v_branch)
       and (v_q is null or app.fold_text(st.full_name) like '%' || v_q || '%' or app.fold_text(st.code) like '%' || v_q || '%' or c.search_text like '%' || v_q || '%')
       and (coalesce(sa.teacher_status_code, sa.ops_status_code) in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')
            or (coalesce(sa.teacher_status_code, sa.ops_status_code) is null and s.start_time <= v_now_local))
  ), g as (
    select * from f where v_kind is null or f.kind = v_kind
  ), page as (
    select * from g order by g.start_time, g.student_name, g.id limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from g),
           'rows', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'session_id', p.session_id, 'student_id', p.student_id, 'student_name', p.student_name, 'class_code', p.class_code, 'subject_name', sub.name,
                      'session_date', p.session_date, 'start_time', to_char(p.start_time, 'HH24:MI'), 'kind', p.kind, 'ops_status_code', p.ops_status_code,
                      'effective_status_code', p.effective_status_code, 'contact_reason_code', p.contact_reason_code, 'contact_reason_name', rs.name, 'ops_note', p.ops_note)
                    order by p.start_time, p.student_name, p.id)
               from page p
               join app.catalog_item sub on sub.catalog_code = p.subject_catalog and sub.code = p.subject_code
               left join app.catalog_item rs on rs.catalog_code = p.contact_reason_catalog and rs.code = p.contact_reason_code), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

-- GV-05 "Ghi chú vận hành (chỉ xem)": thêm lý do liên hệ của vận hành vào bảng điểm danh của giáo viên (canvas GV05, Chat 10/11). Chỉ tên lý do, KHÔNG ghi chú tự do
-- và không số điện thoại, phụ huynh (R-GV-13). Giữ nguyên mọi thứ khác của hàm ở migration 111; ghi cột này giáo viên không làm được (R-DD-02, R-DD-03).
create or replace function app.teacher_attendance_sheet(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s app.class_session;
  v_session jsonb;
  v_statuses jsonb;
begin
  -- Luật R-GV-08, R-GV-13: chỉ người được phân công vào buổi (hoặc người có quyền rộng hơn) xem được.
  s := app.assert_session_access(p_session_id, 'ATTENDANCE', 'XEM');

  select jsonb_build_object(
           'id', s.id, 'status_code', s.status_code, 'type_code', s.type_code, 'session_no', s.session_no,
           'session_date', s.session_date, 'start_time', to_char(s.start_time, 'HH24:MI'), 'end_time', to_char(s.end_time, 'HH24:MI'),
           'class_code', c.code, 'subject_name', sub.name, 'class_type_name', ct.name, 'level_name', lv.name)
    into v_session
    from app.class c
    join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
    join app.catalog_item ct on ct.catalog_code = c.class_type_catalog and ct.code = c.class_type_code
    left join app.catalog_item lv on lv.catalog_code = c.level_catalog and lv.code = c.level_code
   where c.id = s.class_id;

  -- Luật R-DD-01: các trạng thái lấy từ danh mục (đổi tên được), không viết cứng ở giao diện.
  select coalesce(jsonb_agg(jsonb_build_object('code', ci.code, 'name', ci.name) order by ci.sort_order), '[]'::jsonb) into v_statuses
    from app.catalog_item ci where ci.catalog_code = 'ATTENDANCE_STATUS' and ci.is_active;

  -- Luật R-GIO-08: chưa Đã chốt thì chưa có danh sách.
  if s.status_code not in ('DA_CHOT', 'DONE') then
    return jsonb_build_object('session', v_session, 'statuses', v_statuses, 'listed', false, 'students', '[]'::jsonb);
  end if;

  return jsonb_build_object('session', v_session, 'statuses', v_statuses, 'listed', true, 'students', coalesce((
    select jsonb_agg(jsonb_build_object(
             'student_id', st.id, 'student_code', st.code, 'full_name', st.full_name, 'is_trial', sa.is_trial,
             'teacher_status_code', sa.teacher_status_code, 'teacher_marked_at', sa.teacher_marked_at,
             'contact_reason_name', rs.name,
             'has_review', exists (select from app.session_review_score sc where sc.attendance_id = sa.id and sc.state = 'DA_DANH_GIA')
                           or exists (select from app.exam_score es where es.attendance_id = sa.id and es.graded))
           order by st.full_name, st.id)
      from app.session_attendance sa
      join app.student st on st.id = sa.student_id
      left join app.catalog_item rs on rs.catalog_code = sa.contact_reason_catalog and rs.code = sa.contact_reason_code
     where sa.session_id = s.id and sa.is_active), '[]'::jsonb));
end;
$$;

revoke all on function app.session_read_scope(), app.session_list(jsonb, text, integer, integer), app.session_record(uuid), app.session_ops_sheet(uuid),
  app.absent_today_list(jsonb, integer, integer), app.teacher_attendance_sheet(uuid) from public, anon;
grant execute on function app.session_list(jsonb, text, integer, integer), app.session_record(uuid), app.session_ops_sheet(uuid),
  app.absent_today_list(jsonb, integer, integer), app.teacher_attendance_sheet(uuid) to authenticated;

-- Chỉ mục: không thêm. Truy vấn dùng class_session_branch_date_idx (cơ sở, ngày), class_session_teacher_idx, class_session_class_idx (migration 100) và
-- unique (session_id, student_id) của app.session_attendance (migration 102).
