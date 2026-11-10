-- Cụm Ghi danh (BH-08, GD-03): chọn lớp và ngày vào lớp. Hàm ĐỌC lớp phù hợp, hàm xếp nhiều ghi danh một giao dịch, hàm gắn lớp cho dòng đơn Nháp.
-- Luật: R-GD-06 (xếp lớp đúng môn, loại lớp, cơ sở), R-GD-08 (chỉ lớp đã duyệt, còn chỗ), R-GD-14 (ngày vào lớp là buổi sắp tới của lớp; lớp chưa có
-- buổi thì ngày đúng thứ có lịch, không trước ngày khai giảng), R-GD-15 (lớp luân phiên cùng thứ, giờ nhưng không trùng buổi thì xếp được cả hai), R-LOP-14,
-- R-GD-05 (xếp lớp lần đầu chỉ với ghi danh Chờ xếp lớp). Mọi luật kiểm cuối cùng nằm ở hàm có sẵn (assert_class_fits, assert_enrol_start_date,
-- assert_no_time_clash, assign_enrollment_class); hàm đọc ở đây chỉ báo trước để giao diện hiện mờ kèm lý do.

-- Tên thứ trong tuần theo kiểu Việt (1 = Thứ 2 … 7 = Chủ nhật).
create or replace function app.weekday_label(p_isodow integer)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_isodow when 7 then 'Chủ nhật' else 'Thứ ' || (p_isodow + 1)::text end; -- allow-number: 7 là Chủ nhật (isodow); cộng 1 đổi thứ ISO sang tên "Thứ N"
$$;

-- app.enrollment_matching_classes(gói, cơ sở, học sinh): lớp phù hợp với một dòng đơn (BH-08) hoặc một ghi danh (GD-03).
-- Ai gọi: người có Đơn hàng · Sửa hoặc Ghi danh · Sửa (Sale, CSKH, Trưởng cơ sở, Admin). Không phải toàn hệ thống thì chỉ cơ sở của mình.
-- p_student_id (tuỳ chọn): có thì báo lớp trùng buổi với lớp em đang học (clash_sessions > 0).
-- Kết quả: mảng lớp {id, code, subject_name, class_type_name, level_name, grade_code, group_id, group_name, schedule_text, teacher_name, seats_left (null = không giới hạn),
--   has_sessions, class_start_date, weekdays[], upcoming[{date, session_no}], clash_sessions}. Sắp theo mã lớp.
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
               'group_id', c.group_id, 'group_name', g.display_name,
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

-- app.enrollment_assign_options(ghi danh): GD-03. Kết quả: {enrollment, siblings, classes, groups}.
--   enrollment: ghi danh đang xếp (Chờ xếp lớp); siblings: các ghi danh Chờ xếp lớp khác của cùng học sinh (kể cả ghi danh đang xếp);
--   classes: lớp phù hợp với ghi danh này (xếp một lớp lẻ), kèm cờ clash_sessions;
--   groups: nhóm lớp (class_group) có lớp phù hợp với ít nhất một ghi danh chờ của em: mỗi nhóm kèm cặp (ghi danh, lớp) đầu tiên còn chỗ, không trùng buổi (R-GD-15).
-- Chỉ người có Ghi danh · Sửa ở cơ sở của ghi danh.
create or replace function app.enrollment_assign_options(p_enrollment_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ENROLLMENT', 'SUA');
  e app.enrollment;
  v_siblings jsonb;
  v_groups jsonb := '[]'::jsonb;
  v_pairs jsonb;
  g record;
  s record;
  v_pick jsonb;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xếp lớp.');
  end if;
  select * into e from app.enrollment where id = p_enrollment_id;
  if e.id is null or (v_scope = 'CO_SO' and e.branch_id is distinct from app.current_branch_id()) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ghi danh.');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'code', x.code, 'package_id', x.package_id, 'package_code', pk.code, 'package_name', pk.name,
           'delivery_mode_code', x.delivery_mode_code) order by x.created_at, x.code), '[]'::jsonb) into v_siblings
    from app.enrollment x left join app.sales_package pk on pk.id = x.package_id
   where x.student_id = e.student_id and x.branch_id = e.branch_id and x.status_code = 'CHO_XEP_LOP';

  -- Nhóm lớp: với từng nhóm, mỗi ghi danh chờ chọn lớp phù hợp đầu tiên thuộc nhóm.
  for g in select distinct c ->> 'group_id' as group_id, c ->> 'group_name' as group_name
             from app.enrollment x
             cross join lateral jsonb_array_elements(app.enrollment_matching_classes(x.package_id, x.branch_id, x.student_id)) c
            where x.student_id = e.student_id and x.branch_id = e.branch_id and x.status_code = 'CHO_XEP_LOP' and x.package_id is not null
              and c ->> 'group_id' is not null
            order by group_name, group_id
  loop
    v_pairs := '[]'::jsonb;
    for s in select x.id, x.code, x.package_id, x.package_id is not null as has_pkg from app.enrollment x
              where x.student_id = e.student_id and x.branch_id = e.branch_id and x.status_code = 'CHO_XEP_LOP' order by x.created_at, x.code loop
      select c into v_pick from jsonb_array_elements(app.enrollment_matching_classes(s.package_id, e.branch_id, e.student_id)) c
       where c ->> 'group_id' = g.group_id and (c ->> 'clash_sessions')::integer = 0 limit 1;
      if v_pick is not null then
        v_pairs := v_pairs || jsonb_build_array(jsonb_build_object('enrollment_id', s.id, 'enrollment_code', s.code, 'class', v_pick));
      end if;
    end loop;
    if jsonb_array_length(v_pairs) > 0 then
      v_groups := v_groups || jsonb_build_array(jsonb_build_object('group_id', g.group_id, 'group_name', g.group_name, 'pairs', v_pairs));
    end if;
  end loop;

  return jsonb_build_object(
    'enrollment', jsonb_build_object('id', e.id, 'code', e.code, 'status_code', e.status_code, 'student_id', e.student_id,
                    'student_name', (select full_name from app.student where id = e.student_id), 'package_id', e.package_id,
                    'delivery_mode_code', e.delivery_mode_code),
    'siblings', v_siblings,
    'classes', case when e.package_id is null then '[]'::jsonb else app.enrollment_matching_classes(e.package_id, e.branch_id, e.student_id) end,
    'groups', v_groups);
end;
$$;

-- app.assign_enrollments_to_classes([{enrollment_id, class_id, start_date}]): xếp lớp một hoặc nhiều ghi danh trong MỘT giao dịch (GD-03: theo nhóm lớp
-- xếp mọi ghi danh của em một lần; một ghi danh lỗi thì không xếp ghi danh nào). Mọi luật nằm trong app.assign_enrollment_class. Trả số ghi danh đã xếp.
create or replace function app.assign_enrollments_to_classes(p_entries jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  e jsonb;
  v_n integer := 0;
begin
  if jsonb_typeof(p_entries) is distinct from 'array' or jsonb_array_length(p_entries) = 0 then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chưa chọn ghi danh nào để xếp lớp.');
  end if;
  for e in select * from jsonb_array_elements(p_entries) loop
    perform app.assign_enrollment_class((e ->> 'enrollment_id')::uuid, (e ->> 'class_id')::uuid, (e ->> 'start_date')::date);
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

-- app.set_order_line_class(đơn, số dòng, lớp, ngày vào lớp): BH-08 gắn lớp và ngày vào lớp cho một dòng đơn Nháp. Lớp trống (null) = chưa chọn lớp:
-- ghi danh sẽ ở Chờ xếp lớp, vận hành xếp sau (R-GD-06). Chỉ đơn Nháp; cần Đơn hàng · Sửa ở cơ sở của đơn; kiểm lớp đúng gói, cơ sở, còn chỗ
-- (app.check_order_line_class) và ngày vào lớp (app.assert_enrol_start_date). Ghi nhật ký đơn một dòng.
create or replace function app.set_order_line_class(p_order_id uuid, p_line_no integer, p_class_id uuid, p_start date)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
  l app.sales_order_line;
  v_class_code text;
begin
  select * into o from app.sales_order where id = p_order_id for update;
  if o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'SUA', o.branch_id);
  perform app.require_feature('BAN_HANG', o.branch_id);
  if o.status_code <> 'NHAP' then
    perform app.raise_error('HMT_DON_DA_KHOA', 'Đơn đã trình: không đổi lớp được. Nhờ người duyệt từ chối để đưa về Nháp.');
  end if;
  select * into l from app.sales_order_line where order_id = p_order_id and line_no = p_line_no;
  if l.id is null then
    perform app.raise_error('HMT_DONG_KHONG_CO', format('Không có dòng %s trong đơn.', p_line_no));
  end if;
  if l.line_kind = 'GIFT' then
    perform app.raise_error('HMT_DONG_QUA_TANG', 'Dòng quà tặng không xếp lớp.');
  end if;
  if p_class_id is null then
    update app.sales_order_line set class_id = null, enrol_start_date = null where id = l.id;
  else
    -- Luật R-GD-06, R-GD-08: đúng gói, cơ sở, còn chỗ; R-GD-14: ngày vào lớp hợp lệ.
    perform app.check_order_line_class(l.line_no, p_class_id, l.package_id, o.branch_id);
    perform app.assert_enrol_start_date(p_class_id, p_start, format('Dòng %s', l.line_no));
    update app.sales_order_line set class_id = p_class_id, enrol_start_date = p_start where id = l.id;
  end if;
  select code into v_class_code from app.class where id = p_class_id;
  perform app.order_add_event(p_order_id, 'SUA', 'NHAP', 'NHAP', null, null,
    case when p_class_id is null then format('Sửa đơn' || E'\n' || 'dòng %s (%s): bỏ lớp, ghi danh sẽ chờ xếp lớp', l.line_no, l.package_code)
         else format('Sửa đơn' || E'\n' || 'dòng %s (%s): lớp %s, ngày vào lớp %s', l.line_no, l.package_code, v_class_code, to_char(p_start, 'DD/MM/YYYY')) end);
end;
$$;

-- app.order_line_classes(đơn): mã lớp và ngày vào lớp của từng dòng đơn, cho cột "Mã lớp", "Ngày vào lớp" (BH-05, BH-08). Cần Đơn hàng · Xem ở cơ sở của đơn.
-- Kết quả: [{line_no, class_id, class_code, enrol_start_date}] (chỉ dòng đã chọn lớp).
create or replace function app.order_line_classes(p_order_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  o app.sales_order;
begin
  select * into o from app.sales_order where id = p_order_id;
  if o.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy đơn hàng.');
  end if;
  perform app.assert_can('SALES_ORDER', 'XEM', o.branch_id);
  return coalesce((select jsonb_agg(jsonb_build_object('line_no', l.line_no, 'class_id', l.class_id, 'class_code', c.code, 'enrol_start_date', l.enrol_start_date)
                          order by l.line_no)
                     from app.sales_order_line l join app.class c on c.id = l.class_id
                    where l.order_id = o.id and l.class_id is not null), '[]'::jsonb);
end;
$$;

revoke all on function app.weekday_label(integer), app.enrollment_matching_classes(uuid, uuid, uuid), app.enrollment_assign_options(uuid),
  app.assign_enrollments_to_classes(jsonb), app.set_order_line_class(uuid, integer, uuid, date), app.order_line_classes(uuid) from public, anon;
grant execute on function app.weekday_label(integer), app.enrollment_matching_classes(uuid, uuid, uuid), app.enrollment_assign_options(uuid),
  app.assign_enrollments_to_classes(jsonb), app.set_order_line_class(uuid, integer, uuid, date), app.order_line_classes(uuid) to authenticated;

-- Chỉ mục: không thêm. Truy vấn dùng class_slot theo lớp, class_session_class_idx (lớp, ngày, giờ), enrollment_class_class_open_idx (chỗ trống).
