-- LOP-02/03 (anh Trường chốt 20/11, 4 quyết định): Hình thức học của lớp (Offline, Online, OMO) và hàm xem trước ngày kết thúc dự kiến.
-- Một migration: (1) danh mục CLASS_DELIVERY (OFF, ONL, OMO), tách khỏi STUDY_MODE là hình thức BÁN của ghi danh/bảng giá (không thêm OMO vào bán);
-- (2) cột app.class.delivery_mode_code (lớp cũ mặc định OFF); (3) create_class, save_class_info nhận cột; get_class_record trả cột;
-- (4) app.preview_class_end_date: tính ngày kết thúc dự kiến từ khung giờ đang nhập (chưa lưu). Xếp lớp lệch hình thức chỉ CẢNH BÁO ở giao diện, không chặn.
select set_config('hmt.migration', 'on', false);

insert into app.catalog (code, name, kind, description, sort_order)
select 'CLASS_DELIVERY', 'Hình thức học của lớp', 'HE_THONG',
       'Offline, Online, OMO của lớp. Khác STUDY_MODE (hình thức bán của ghi danh). Xếp lớp lệch hình thức chỉ cảnh báo, không chặn.',
       (select coalesce(max(sort_order), 0) + 1 from app.catalog)
 where not exists (select from app.catalog where code = 'CLASS_DELIVERY');

insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('CLASS_DELIVERY', 'OFF', 'Offline', 1),
  ('CLASS_DELIVERY', 'ONL', 'Online', 2),
  ('CLASS_DELIVERY', 'OMO', 'OMO', 3)
on conflict (catalog_code, code) do nothing;

-- Chỉ mục: không thêm. Cột có 3 giá trị, chỉ hiện ở hồ sơ lớp, chưa dùng để lọc; khi thêm lọc theo hình thức sẽ thêm chỉ mục cùng PR đó.
alter table app.class
  add column delivery_mode_catalog text not null default 'CLASS_DELIVERY' check (delivery_mode_catalog = 'CLASS_DELIVERY'),
  add column delivery_mode_code text not null default 'OFF',
  add constraint class_delivery_mode_fk foreign key (delivery_mode_catalog, delivery_mode_code) references app.catalog_item (catalog_code, code);

create or replace function app.create_class(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid := (p_data ->> 'branch_id')::uuid;
  v_branch_code text;
  v_code text;
  v_id uuid;
  v_start date := (p_data ->> 'start_date')::date;
  v_slots jsonb;
  v_group app.class_group;
  v_cskh uuid := nullif(p_data ->> 'cskh_id', '')::uuid;
  v_mode text := coalesce(nullif(p_data ->> 'delivery_mode_code', ''), 'OFF');
begin
  perform app.assert_can('CLASS', 'TAO', v_branch);
  perform app.require_feature('VAN_HANH_LOP', v_branch);
  if v_start is null or coalesce((p_data ->> 'total_sessions')::integer, 0) <= 0 then
    perform app.raise_error('HMT_LOP_THIEU_THONG_TIN', 'Lớp cần ngày khai giảng và số buổi lớn hơn 0.');
  end if;
  -- Hình thức học của lớp (Offline, Online, OMO): phải là mã đang dùng trong danh mục CLASS_DELIVERY.
  perform app.assert_catalog_code_active('CLASS_DELIVERY', v_mode);
  select code into v_branch_code from app.branch where id = v_branch;
  v_code := app.issue_class_code(v_branch_code, p_data ->> 'year_code', p_data ->> 'subject_code', p_data ->> 'grade_code',
                                 p_data ->> 'class_type_code', nullif(p_data ->> 'level_code', ''));
  -- Luật R-LOP-14: nhóm lớp cùng cơ sở, cùng khối, mỗi môn một lớp, chỉ môn DAI và HINH.
  if nullif(p_data ->> 'group_id', '') is not null then
    select * into v_group from app.class_group where id = (p_data ->> 'group_id')::uuid;
    if v_group.id is null or v_group.branch_id <> v_branch or v_group.grade_code <> p_data ->> 'grade_code'
       or p_data ->> 'subject_code' not in ('DAI', 'HINH') then
      perform app.raise_error('HMT_LOP_NHOM_SAI', 'Nhóm lớp phải cùng cơ sở, cùng khối và chỉ gồm lớp Đại hoặc Hình.');
    end if;
    if exists (select from app.class where group_id = v_group.id and subject_code = p_data ->> 'subject_code' and status_code <> 'HUY') then
      perform app.raise_error('HMT_LOP_NHOM_TRUNG_MON', 'Nhóm lớp này đã có một lớp cùng môn.');
    end if;
  end if;
  v_slots := app.class_normalize_slots(v_branch, v_start, coalesce(p_data -> 'slots', '[]'::jsonb));
  insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, max_students,
                         start_date, total_sessions, curriculum_ref, start_lesson, cskh_id, group_id, legacy_ref, delivery_mode_code)
  values (v_code, v_branch, p_data ->> 'year_code', p_data ->> 'subject_code', p_data ->> 'grade_code', p_data ->> 'class_type_code',
          nullif(p_data ->> 'level_code', ''), coalesce((p_data ->> 'max_students')::integer, 0), v_start,
          (p_data ->> 'total_sessions')::integer, nullif(p_data ->> 'curriculum_ref', ''), nullif(p_data ->> 'start_lesson', ''),
          v_cskh, nullif(p_data ->> 'group_id', '')::uuid, nullif(p_data ->> 'legacy_ref', ''), v_mode)
  returning id into v_id;
  perform app.class_replace_slots(v_id, v_branch, v_slots);
  perform app.class_add_event(v_id, 'TAO', null, 'NHAP');
  return jsonb_build_object('id', v_id, 'code', v_code, 'warnings', '[]'::jsonb);
end;
$$;

create or replace function app.save_class_info(p_id uuid, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.class;
begin
  select * into c from app.class where id = p_id for update;
  if c.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lớp.');
  end if;
  perform app.assert_can('CLASS', 'SUA', c.branch_id);
  if c.status_code in ('NHAP', 'TU_CHOI') then
    -- Hình thức học (Offline, Online, OMO) sửa được cùng thông tin lớp ở Nháp, Từ chối.
    if nullif(p_data ->> 'delivery_mode_code', '') is not null then
      perform app.assert_catalog_code_active('CLASS_DELIVERY', p_data ->> 'delivery_mode_code');
    end if;
    update app.class set
      max_students = coalesce((p_data ->> 'max_students')::integer, max_students),
      start_date = coalesce((p_data ->> 'start_date')::date, start_date),
      total_sessions = coalesce((p_data ->> 'total_sessions')::integer, total_sessions),
      curriculum_ref = case when p_data ? 'curriculum_ref' then nullif(p_data ->> 'curriculum_ref', '') else curriculum_ref end,
      start_lesson = case when p_data ? 'start_lesson' then nullif(p_data ->> 'start_lesson', '') else start_lesson end,
      cskh_id = case when p_data ? 'cskh_id' then nullif(p_data ->> 'cskh_id', '')::uuid else cskh_id end,
      legacy_ref = case when p_data ? 'legacy_ref' then nullif(p_data ->> 'legacy_ref', '') else legacy_ref end,
      delivery_mode_code = coalesce(nullif(p_data ->> 'delivery_mode_code', ''), delivery_mode_code)
     where id = p_id;
  elsif c.status_code = 'DA_DUYET' then
    -- Lớp Đã duyệt: chỉ CSKH phụ trách và sĩ số tối đa; mọi trường khác bị khoá.
    if exists (select from jsonb_object_keys(p_data) k where k not in ('max_students', 'cskh_id')) then
      perform app.raise_error('HMT_LOP_DA_KHOA', 'Lớp đã duyệt chỉ sửa được CSKH phụ trách và sĩ số tối đa.');
    end if;
    update app.class set
      max_students = coalesce((p_data ->> 'max_students')::integer, max_students),
      cskh_id = case when p_data ? 'cskh_id' then nullif(p_data ->> 'cskh_id', '')::uuid else cskh_id end
     where id = p_id;
  else
    perform app.raise_error('HMT_LOP_DA_KHOA', 'Chỉ sửa thông tin lớp ở Nháp hoặc Từ chối.');
  end if;
  perform app.class_add_event(p_id, 'SUA', c.status_code, c.status_code);
end;
$$;

create or replace function app.get_class_record(p_class_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('CLASS', 'XEM');
  c app.class;
begin
  select * into c from app.class where id = p_class_id;
  if c.id is null
     or v_scope is null
     or (v_scope = 'CO_SO' and c.branch_id is distinct from app.current_branch_id())
     or (v_scope = 'DUOC_PHAN_CONG' and not app.is_assigned_to_class(c.id)) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lớp này hoặc lớp không tồn tại.');
  end if;
  return jsonb_build_object(
    'id', c.id, 'code', c.code, 'legacy_ref', c.legacy_ref,
    'branch_code', (select b.code from app.branch b where b.id = c.branch_id), 'branch_id', c.branch_id,
    'year_code', c.year_code,
    'delivery_mode_code', c.delivery_mode_code,
    'delivery_mode_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_DELIVERY' and ci.code = c.delivery_mode_code),
    'subject_code', c.subject_code, 'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
    'grade_code', c.grade_code,
    'class_type_code', c.class_type_code, 'class_type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_TYPE' and ci.code = c.class_type_code),
    'level_code', c.level_code, 'level_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'LEVEL' and ci.code = c.level_code),
    'status_code', c.status_code, 'status_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_STATUS' and ci.code = c.status_code),
    'operating_status', app.class_operating_status(c.id),
    'max_students', c.max_students, 'seats_left', app.class_seats_left(c.id),
    'start_date', c.start_date, 'total_sessions', c.total_sessions, 'expected_end_date', c.expected_end_date,
    'curriculum_ref', c.curriculum_ref, 'start_lesson', c.start_lesson, 'cskh_id', c.cskh_id, 'group_id', c.group_id,
    'group_name', (select cg.display_name from app.class_group cg where cg.id = c.group_id),
    'slots', coalesce((select jsonb_agg(jsonb_build_object(
               'id', sl.id, 'weekday', sl.weekday, 'start_time', sl.start_time, 'end_time', sl.end_time,
               'repeat_weeks', sl.repeat_weeks, 'first_date', sl.first_date,
               'teacher_id', sl.teacher_id, 'assistant_id', sl.assistant_id, 'room_id', sl.room_id,
               'teacher_name', app.staff_display_name(sl.teacher_id), 'assistant_name', app.staff_display_name(sl.assistant_id),
               'room_name', (select r.name from app.room r where r.id = sl.room_id)) order by sl.weekday, sl.start_time)
               from app.class_slot sl where sl.class_id = c.id and sl.is_active), '[]'::jsonb),
    'students', coalesce((select jsonb_agg(jsonb_build_object(
               'enrollment_id', e.id, 'enrollment_code', e.code, 'student_id', st.id, 'student_code', st.code, 'full_name', st.full_name,
               'start_date', ec.start_date, 'enrollment_status', e.status_code, 'hours_left', app.enrollment_hours_balance(e.id)) order by st.full_name, st.id)
               from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id join app.student st on st.id = e.student_id
              where ec.class_id = c.id and ec.end_date is null), '[]'::jsonb),
    'session_counts', coalesce((select jsonb_object_agg(x.status_code, x.n) from (
               select s.status_code, count(*) as n from app.class_session s where s.class_id = c.id and s.status_code <> 'DA_THAY' group by s.status_code) x), '{}'::jsonb),
    'sessions', coalesce((select jsonb_agg(jsonb_build_object(
               'id', y.id, 'session_no', y.session_no, 'session_date', y.session_date, 'start_time', y.start_time, 'end_time', y.end_time,
               'status_code', y.status_code, 'type_code', y.type_code, 'teacher_name', app.staff_display_name(y.teacher_id)) order by y.session_date, y.start_time)
               from (select * from app.class_session s where s.class_id = c.id and s.status_code <> 'DA_THAY'
                      order by s.session_date desc, s.start_time desc limit 100) y), '[]'::jsonb), -- allow-number: tối đa 100 buổi hiện trên hồ sơ lớp
    'clash_warnings', app.class_clash_warnings(c.id),
    -- LOP-02 (canvas 9933): «Lớp còn lại của nhóm» = các lớp KHÁC cùng nhóm lớp (R-LOP-14), mỗi lớp độc lập; chỉ liệt kê lớp người xem được (RLS theo cơ sở như danh sách).
    'group_classes', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'code', o.code,
                                  'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = o.subject_code),
                                  'status_code', o.status_code,
                                  'status_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_STATUS' and ci.code = o.status_code),
                                  'teacher_names', (select string_agg(distinct app.staff_display_name(sl.teacher_id), ', ') from app.class_slot sl
                                                     where sl.class_id = o.id and sl.is_active and sl.teacher_id is not null)) order by o.code)
                                 from app.class o
                                where c.group_id is not null and o.group_id = c.group_id and o.id <> c.id
                                  and (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and o.branch_id = app.current_branch_id())
                                       or (v_scope = 'DUOC_PHAN_CONG' and app.is_assigned_to_class(o.id)))), '[]'::jsonb),
    'events', coalesce((select jsonb_agg(jsonb_build_object('event_code', z.event_code, 'created_at', z.created_at, 'note', z.note) order by z.created_at desc)
               from (select * from app.class_event ev where ev.class_id = c.id order by ev.created_at desc limit 20) z), '[]'::jsonb)); -- allow-number: 20 sự kiện mới nhất
end;
$$;

-- app.preview_class_end_date(cơ sở, ngày bắt đầu, số buổi, khung giờ): ngày kết thúc dự kiến tính từ khung giờ ĐANG NHẬP, không ghi gì (R-LOP-09).
-- Ai gọi: người có quyền xem Lớp ở cơ sở đó (màn Tạo/Sửa lớp). Đầu vào: mảng khung như app.create_class (weekday, start_time, end_time, repeat_weeks, first_date...).
-- Kết quả: ngày của buổi cuối (đã bỏ ngày nghỉ lễ, R-LOP-12), hoặc null khi chưa có khung giờ hay số buổi. Khung sai thì báo lỗi có mã như lúc lưu.
create or replace function app.preview_class_end_date(p_branch_id uuid, p_start_date date, p_total_sessions integer, p_slots jsonb)
returns date
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_slots jsonb;
begin
  perform app.assert_can('CLASS', 'XEM', p_branch_id);
  if p_start_date is null or coalesce(p_total_sessions, 0) <= 0
     or p_slots is null or jsonb_typeof(p_slots) <> 'array' or jsonb_array_length(p_slots) = 0 then
    return null;
  end if;
  v_slots := app.class_normalize_slots(p_branch_id, p_start_date, p_slots);
  return (select max(s.session_date)
            from app.compute_class_schedule(p_branch_id, p_start_date, p_total_sessions, v_slots) s);
end;
$$;
revoke execute on function app.preview_class_end_date(uuid, date, integer, jsonb) from public, anon;
grant execute on function app.preview_class_end_date(uuid, date, integer, jsonb) to authenticated;

-- Hộp chọn lớp khi xếp lớp (BH-08, GD-03): thêm hình thức học của lớp vào mỗi lớp trả về; không đổi quyền, bộ lọc, sắp xếp.
-- app.enrollment_matching_classes(gói, cơ sở, học sinh): lớp phù hợp với một dòng đơn (BH-08) hoặc một ghi danh (GD-03).
-- Ai gọi: người có Đơn hàng · Sửa hoặc Ghi danh · Sửa (Sale, CSKH, Trưởng cơ sở, Admin). Không phải toàn hệ thống thì chỉ cơ sở của mình.
-- p_student_id (tuỳ chọn): có thì báo lớp trùng buổi với lớp em đang học (clash_sessions > 0).
-- Kết quả: mảng lớp {id, code, subject_name, class_type_name, level_name, grade_code, group_id, group_name, schedule_text, teacher_name, seats_left (null = không giới hạn),
--   delivery_mode_code (hình thức học của lớp: giao diện cảnh báo, không chặn, khi lệch hình thức ghi danh), has_sessions, class_start_date, weekdays[], upcoming[{date, session_no}], clash_sessions}. Sắp theo mã lớp.
create or replace function app.enrollment_matching_classes(p_package_id uuid, p_branch_id uuid default null, p_student_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text;
  v_branch uuid;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  p app.sales_package;
  v_result jsonb;
begin
  v_scope := coalesce(app.permission_scope('ENROLLMENT', 'SUA'), app.permission_scope('SALES_ORDER', 'SUA'));
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền chọn lớp.');
  end if;
  v_branch := case when v_scope = 'TOAN_HE_THONG' then coalesce(p_branch_id, app.current_branch_id()) else app.current_branch_id() end;
  select * into p from app.sales_package where id = p_package_id;
  if p.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy gói.');
  end if;

  select coalesce(jsonb_agg(x.j order by x.code), '[]'::jsonb) into v_result
    from (
      select c.code,
             jsonb_build_object(
               'id', c.id, 'code', c.code, 'subject_name', sub.name, 'class_type_name', ct.name, 'level_name', lv.name, 'grade_code', c.grade_code,
               'group_id', c.group_id, 'group_name', g.display_name, 'delivery_mode_code', c.delivery_mode_code,
               'schedule_text', (select string_agg(format('%s %s–%s', app.weekday_label(s.weekday::integer), to_char(s.start_time, 'HH24:MI'), to_char(s.end_time, 'HH24:MI')),
                                                         '; ' order by s.weekday, s.start_time)
                                   from app.class_slot s where s.class_id = c.id and s.is_active),
               'teacher_name', (select ua.display_name from app.class_slot s join app.user_account ua on ua.id = s.teacher_id
                                 where s.class_id = c.id and s.is_active order by s.weekday, s.start_time limit 1),
               'seats_left', app.class_seats_left(c.id),
               'has_sessions', exists (select from app.class_session x where x.class_id = c.id and x.status_code in ('NHAP', 'DA_CHOT', 'DONE')),
               'class_start_date', c.start_date,
               'weekdays', coalesce((select jsonb_agg(distinct s.weekday) from app.class_slot s where s.class_id = c.id and s.is_active), '[]'::jsonb),
               'upcoming', coalesce((select jsonb_agg(jsonb_build_object('date', u.session_date, 'session_no', u.session_no) order by u.session_date, u.start_time)
                                       from (select * from app.class_session x where x.class_id = c.id and x.status_code in ('NHAP', 'DA_CHOT')
                                                and x.session_date >= v_today order by x.session_date, x.start_time limit 8) u), '[]'::jsonb), -- allow-number: số buổi sắp tới gợi ý trong hộp chọn ngày vào lớp
               'clash_sessions', case when p_student_id is null then 0 else (
                 select count(*) from app.enrollment e
                   join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null and ec.class_id <> c.id
                   join app.class_session b on b.class_id = ec.class_id and b.status_code in ('NHAP', 'DA_CHOT')
                   join app.class_session a on a.class_id = c.id and a.status_code in ('NHAP', 'DA_CHOT') and a.session_date = b.session_date
                        and b.start_time < a.end_time and a.start_time < b.end_time
                  where e.student_id = p_student_id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC') and a.session_date >= v_today) end
             ) as j
        from app.class c
        join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
        join app.catalog_item ct on ct.catalog_code = c.class_type_catalog and ct.code = c.class_type_code
        left join app.catalog_item lv on lv.catalog_code = c.level_catalog and lv.code = c.level_code
        left join app.class_group g on g.id = c.group_id
       -- Luật R-GD-08: lớp đã duyệt, đúng cơ sở, còn chỗ; R-GD-06: đúng môn và khối của gói.
       where c.status_code = 'DA_DUYET' and c.branch_id = v_branch
         and app.package_matches_class_subject(p.subject_code, c.subject_code)
         and (p.grade_from_code is null or (c.grade_code >= p.grade_from_code and c.grade_code <= coalesce(p.grade_to_code, p.grade_from_code)))
         and coalesce(app.class_seats_left(c.id), 1) > 0
    ) x;
  return v_result;
end;
$$;
