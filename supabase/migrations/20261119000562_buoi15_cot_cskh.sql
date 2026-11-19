-- BUOI-15 Điểm danh trong ngày: thêm cột «CSKH» theo canvas 9933 BUOI15 (Code F, 19/11/2026; thẻ F51). Mỗi dòng trả thêm cskh_name: người CSKH phụ trách lớp (class.cskh_id), hoặc null.
-- Thân hàm giữ nguyên bản 464 (v_limit đọc tham số); chỉ đọc, quyền và cờ DIEM_DANH_TRONG_NGAY giữ nguyên.
select set_config('hmt.migration', 'on', false);

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
           'status_code', p.status_code, 'cskh_name', app.staff_display_name(c.cskh_id), 'total', p.total, 'ops', p.ops, 'teacher', p.teacher, 'notice', p.notice,
           'state', case when p.status_code = 'NHAP' then 'CHUA_CO_DANH_SACH'
                         when p.total = 0 or p.total = (p.teacher ->> 'CHUA')::bigint then 'CHUA_GHI'
                         when (p.teacher ->> 'CHUA')::bigint = 0 then 'GHI_DU' else 'GHI_DO' end)
           order by p.start_time, p.id), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.class c on c.id = p.class_id join app.branch b on b.id = p.branch_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;
