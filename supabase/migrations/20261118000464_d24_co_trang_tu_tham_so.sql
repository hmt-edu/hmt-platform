-- Migration 464 (Code D, 18/11/2026): thẻ D24, rà số nghiệp vụ viết cứng. Ba hàm danh sách ghi cứng cỡ trang 50 và trần 100 (kèm allow-number) thay vì đọc tham số
-- list_page_size_default, list_page_size_max như mọi hàm danh sách khác (CLAUDE.md, Cấu hình: «không viết cứng con số nghiệp vụ»). Chỉ đổi dòng tính v_limit, thân hàm giữ nguyên.
-- Lưu ý: giá trị mặc định 50 của tham số p_limit trong CHỮ KÝ giữ nguyên (đổi cần xoá và tạo lại hàm); giao diện luôn truyền cỡ trang.

-- app.list_expiring_enrollments: thân bản migration 000142, chỉ đổi cách tính v_limit.
create or replace function app.list_expiring_enrollments(p_filters jsonb default '{}'::jsonb, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ENROLLMENT', 'XEM');
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := case when jsonb_typeof(p_filters -> 'status') = 'array'
                          then array(select jsonb_array_elements_text(p_filters -> 'status')) end;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_search text := nullif(btrim(coalesce(p_filters ->> 'search', '')), '');
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_total bigint;
  v_rows jsonb;
begin
  if v_scope is null or v_scope = 'DUOC_PHAN_CONG' then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách sắp hết giờ.');
  end if;
  -- Cờ theo cơ sở: người có phạm vi cơ sở bị chặn rõ ràng khi tắt; Admin (toàn hệ thống) chỉ thấy các cơ sở đã bật (điều kiện ở base).
  if v_scope <> 'TOAN_HE_THONG' then
    perform app.require_feature('SAP_HET_GIO', app.current_branch_id());
  end if;
  with base as (
    -- Mỗi ghi danh còn hiệu lực gắn với lớp hiện tại (dòng ghi danh vào lớp chưa kết thúc), kèm giờ còn của chính ghi danh đó.
    select e.student_id, ec.class_id, e.id as enrollment_id, e.code as enrollment_code, e.branch_id, ec.start_date,
           coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = e.id), 0) as hours_left
      from app.enrollment e
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
     where e.status_code in ('DA_XEP_LOP', 'DANG_HOC')
       and (v_scope = 'TOAN_HE_THONG' or e.branch_id = app.current_branch_id())
       and app.feature_enabled('SAP_HET_GIO', e.branch_id)
       and (v_class is null or ec.class_id = v_class)
  ), grp as (
    select b.student_id, b.class_id, min(b.branch_id::text)::uuid as branch_id,
           sum(b.hours_left) as hours_left,
           array_agg(b.enrollment_code order by b.enrollment_code) as enrollment_codes,
           max(b.start_date) as last_start
      from base b group by b.student_id, b.class_id
  ), calc as (
    select g.*,
           coalesce((select sum(extract(epoch from (s.end_time - s.start_time)) / 3600.0 / s.repeat_weeks) -- allow-number: 3600 giây một giờ
                       from app.class_slot s where s.class_id = g.class_id and s.is_active), 0) as weekly_hours,
           (g.last_start + make_interval(months => app.get_setting_int('package_default_validity_months', g.branch_id)::integer))::date as validity_date
      from grp g
  ), est as (
    select c.*,
           case when c.hours_left > 0 and c.weekly_hours > 0
                then v_today + ceil(c.hours_left / c.weekly_hours * 7)::integer end as projected_end -- allow-number: 7 ngày một tuần
      from calc c
  ), tagged as (
    select e.*,
           case when e.hours_left <= 0 then 'HET_GIO'
                when e.hours_left <= app.get_setting_numeric('upsale_hours_left_threshold', e.branch_id)
                  or (e.projected_end is not null and e.projected_end - v_today <= app.get_setting_int('upsale_days_left_threshold', e.branch_id)) then 'SAP_HET_GIO'
                when e.validity_date < v_today then 'QUA_HAN_CON_GIO' end as status_code
      from est e
  ), f as (
    select t.* from tagged t
      join app.student st on st.id = t.student_id
      join app.class c on c.id = t.class_id
     where t.status_code is not null
       and (v_status is null or t.status_code = any (v_status))
       and (v_search is null or st.full_name ilike '%' || v_search || '%' or c.code ilike '%' || v_search || '%')
  ), page as (
    select * from f order by projected_end nulls first, student_id limit v_limit offset v_offset
  )
  select (select count(*) from f),
         coalesce(jsonb_agg(jsonb_build_object(
           'student_id', p.student_id, 'student_name', st.full_name, 'class_id', p.class_id, 'class_code', c.code,
           'enrollment_codes', to_jsonb(p.enrollment_codes), 'hours_left', p.hours_left,
           'projected_end', p.projected_end, 'validity_date', p.validity_date, 'status_code', p.status_code)
           order by p.projected_end nulls first, p.student_id), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.student st on st.id = p.student_id join app.class c on c.id = p.class_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.session_day_attendance: thân bản migration 000143, chỉ đổi cách tính v_limit.
create or replace function app.session_day_attendance(p_filters jsonb default '{}'::jsonb, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.session_read_scope();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_date date := coalesce(nullif(p_filters ->> 'date', '')::date, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_teacher uuid := nullif(p_filters ->> 'teacher_id', '')::uuid;
  v_state text[] := case when jsonb_typeof(p_filters -> 'state') = 'array' then array(select jsonb_array_elements_text(p_filters -> 'state')) end;
  v_notice boolean := (p_filters ->> 'has_notice')::boolean;
  v_total bigint;
  v_rows jsonb;
begin
  -- Cờ theo cơ sở: phạm vi cơ sở bị chặn rõ ràng khi tắt; Admin chỉ thấy cơ sở đã bật (điều kiện ở f).
  if v_scope <> 'TOAN_HE_THONG' then
    perform app.require_feature('DIEM_DANH_TRONG_NGAY', app.current_branch_id());
  end if;
  with f as (
    select s.id, s.class_id, s.branch_id, s.session_no, s.start_time, s.end_time, s.status_code, s.teacher_id, s.room_id,
           a.total, a.ops, a.teacher, a.notice
      from app.class_session s
      cross join lateral (
        select count(*) as total,
               jsonb_build_object('CO_MAT', count(*) filter (where x.ops_status_code = 'CO_MAT'), 'DI_MUON', count(*) filter (where x.ops_status_code = 'DI_MUON'),
                                  'VANG_CO_PHEP', count(*) filter (where x.ops_status_code = 'VANG_CO_PHEP'), 'VANG_KHONG_PHEP', count(*) filter (where x.ops_status_code = 'VANG_KHONG_PHEP'),
                                  'CHUA', count(*) filter (where x.ops_status_code is null)) as ops,
               jsonb_build_object('CO_MAT', count(*) filter (where x.teacher_status_code = 'CO_MAT'), 'DI_MUON', count(*) filter (where x.teacher_status_code = 'DI_MUON'),
                                  'VANG_CO_PHEP', count(*) filter (where x.teacher_status_code = 'VANG_CO_PHEP'), 'VANG_KHONG_PHEP', count(*) filter (where x.teacher_status_code = 'VANG_KHONG_PHEP'),
                                  'CHUA', count(*) filter (where x.teacher_status_code is null)) as teacher,
               count(*) filter (where x.contact_reason_code = 'XIN_NGHI_HOC') as notice
          from app.session_attendance x where x.session_id = s.id and x.is_active) a
     where s.session_date = v_date and s.status_code not in ('HUY_KHONG_PHI', 'HUY_CO_PHI', 'DA_THAY')
       and (v_scope = 'TOAN_HE_THONG' or s.branch_id = app.current_branch_id())
       and app.feature_enabled('DIEM_DANH_TRONG_NGAY', s.branch_id)
       and (v_branch is null or s.branch_id = v_branch)
       and (v_teacher is null or s.teacher_id = v_teacher)
       and (v_notice is null or (a.notice > 0) = v_notice)
       and (v_state is null or (case when s.status_code = 'NHAP' then 'CHUA_CO_DANH_SACH'
                                     when a.total = 0 or a.total = (a.teacher ->> 'CHUA')::bigint then 'CHUA_GHI'
                                     when (a.teacher ->> 'CHUA')::bigint = 0 then 'GHI_DU' else 'GHI_DO' end) = any (v_state))
  ), page as (
    select * from f order by start_time, id limit v_limit offset v_offset
  )
  select (select count(*) from f),
         coalesce(jsonb_agg(jsonb_build_object(
           'session_id', p.id, 'class_id', p.class_id, 'class_code', c.code, 'session_no', p.session_no, 'branch_code', b.code,
           'start_time', to_char(p.start_time, 'HH24:MI'), 'end_time', to_char(p.end_time, 'HH24:MI'),
           'room_name', (select rm.name from app.room rm where rm.id = p.room_id), 'teacher_name', app.staff_display_name(p.teacher_id),
           'status_code', p.status_code, 'total', p.total, 'ops', p.ops, 'teacher', p.teacher, 'notice', p.notice,
           'state', case when p.status_code = 'NHAP' then 'CHUA_CO_DANH_SACH'
                         when p.total = 0 or p.total = (p.teacher ->> 'CHUA')::bigint then 'CHUA_GHI'
                         when (p.teacher ->> 'CHUA')::bigint = 0 then 'GHI_DU' else 'GHI_DO' end)
           order by p.start_time, p.id), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.class c on c.id = p.class_id join app.branch b on b.id = p.branch_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.list_curriculum_frames: thân bản migration 000300, chỉ đổi cách tính v_limit.
create or replace function app.list_curriculum_frames(p_filters jsonb default '{}'::jsonb, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := case when jsonb_typeof(p_filters -> 'status') = 'array' then array(select jsonb_array_elements_text(p_filters -> 'status')) end;
  v_subject text := nullif(p_filters ->> 'subject', '');
  v_grade text := nullif(p_filters ->> 'grade', '');
  v_level text := nullif(p_filters ->> 'level', '');
  v_year text := nullif(p_filters ->> 'year', '');
  v_total bigint;
  v_rows jsonb;
begin
  -- Quyền xem: mọi vai trò có Cấu hình đào tạo · Xem.
  if app.permission_scope('CONFIG_TRAINING', 'XEM') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem khung chương trình.');
  end if;
  select count(*) into v_total from app.curriculum_frame f
   where (v_status is null or f.status_code = any (v_status))
     and (v_subject is null or f.subject_code = v_subject) and (v_grade is null or f.grade_code = v_grade)
     and (v_level is null or f.level_code = v_level) and (v_year is null or f.year_code = v_year);
  select coalesce(jsonb_agg(q.r order by q.sort_key), '[]'::jsonb) into v_rows
    from (
      select f.code as sort_key,
             jsonb_build_object(
               'id', f.id, 'code', f.code, 'subject_code', f.subject_code,
               'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = f.subject_code),
               'grade_code', f.grade_code,
               'grade_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'GRADE' and ci.code = f.grade_code),
               'level_code', f.level_code,
               'level_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_TYPE' and ci.code = f.level_code),
               'year_code', f.year_code, 'version', f.version, 'status_code', f.status_code,
               'lesson_count', (select count(*) from app.curriculum_lesson l where l.frame_id = f.id)) as r
        from app.curriculum_frame f
       where (v_status is null or f.status_code = any (v_status))
         and (v_subject is null or f.subject_code = v_subject) and (v_grade is null or f.grade_code = v_grade)
         and (v_level is null or f.level_code = v_level) and (v_year is null or f.year_code = v_year)
       order by f.code
       limit v_limit offset v_offset) q;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;
