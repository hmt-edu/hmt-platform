-- T2 mục 10 (Tester 2, báo cáo 19/11): danh sách Lớp gộp các thứ cùng giờ nên mất thông tin «thứ nào do giáo viên nào dạy» và không hiện phòng.
-- app.list_classes giữ nguyên bản ở migration 116, chỉ thêm hai khoá vào mỗi khung của «schedule»: teacher_name, room_name (chỉ đọc, không đổi luật, không đổi quyền).
create or replace function app.list_classes(p_filters jsonb default '{}'::jsonb, p_sort text default 'code_asc',
                                            p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('CLASS', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_operating text[] := array(select jsonb_array_elements_text(p_filters -> 'operating'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_subject text := nullif(p_filters ->> 'subject_code', '');
  v_grade text := nullif(p_filters ->> 'grade_code', '');
  v_type text := nullif(p_filters ->> 'class_type_code', '');
  v_search text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lớp học.');
  end if;
  with f as not materialized (
    select c.*, app.class_operating_status(c.id) as operating_status
      from app.class c
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and c.branch_id = v_my_branch)
            or (v_scope = 'DUOC_PHAN_CONG' and app.is_assigned_to_class(c.id)))
       and (cardinality(v_status) = 0 or c.status_code = any (v_status))
       and (v_branch is null or c.branch_id = v_branch)
       and (v_subject is null or c.subject_code = v_subject)
       and (v_grade is null or c.grade_code = v_grade)
       and (v_type is null or c.class_type_code = v_type)
       and (v_search is null or c.search_text like '%' || v_search || '%')
  ), g as (
    select * from f where cardinality(v_operating) = 0 or f.operating_status = any (v_operating)
  ), page as (
    select * from g
     order by case when p_sort = 'code_desc' then g.code end desc,
              case when p_sort = 'start_desc' then g.start_date end desc,
              g.code
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from g),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'legacy_ref', p.legacy_ref,
             'branch_id', p.branch_id, 'branch_code', b.code,
             'subject_code', p.subject_code, 'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = p.subject_code),
             'grade_code', p.grade_code,
             'class_type_code', p.class_type_code, 'class_type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_TYPE' and ci.code = p.class_type_code),
             'level_code', p.level_code, 'level_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'LEVEL' and ci.code = p.level_code),
             'status_code', p.status_code, 'status_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_STATUS' and ci.code = p.status_code),
             'operating_status', p.operating_status,
             'max_students', p.max_students,
             'enrolled', (select count(*) from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id
                           where ec.class_id = p.id and ec.end_date is null and e.status_code in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU')),
             'seats_left', app.class_seats_left(p.id),
             'start_date', p.start_date, 'expected_end_date', p.expected_end_date, 'total_sessions', p.total_sessions,
             'group_name', (select cg.display_name from app.class_group cg where cg.id = p.group_id),
             -- Lịch học và giáo viên theo khung giờ đang dùng (khung LOP-01: cột Lịch học, Giáo viên).
             'schedule', coalesce((select jsonb_agg(jsonb_build_object('weekday', sl.weekday, 'start_time', sl.start_time, 'end_time', sl.end_time,
                                                                         'teacher_name', app.staff_display_name(sl.teacher_id), 'room_name', (select r.name from app.room r where r.id = sl.room_id)) order by sl.weekday, sl.start_time)
                                     from app.class_slot sl where sl.class_id = p.id and sl.is_active), '[]'::jsonb),
             'teacher_names', (select string_agg(distinct app.staff_display_name(sl.teacher_id), ', ') from app.class_slot sl
                                where sl.class_id = p.id and sl.is_active and sl.teacher_id is not null))
             order by case when p_sort = 'code_desc' then p.code end desc, case when p_sort = 'start_desc' then p.start_date end desc, p.code), '[]'::jsonb))
    into v_result
    from page p join app.branch b on b.id = p.branch_id;
  return v_result;
end;
$$;