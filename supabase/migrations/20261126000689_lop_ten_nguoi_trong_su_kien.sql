-- D-26-09 (phần b): app.get_class_record trả thêm TÊN người làm ở mỗi sự kiện của lớp (events[].actor_name), để màn Sửa lớp
-- ghi được «Lớp bị từ chối bởi …» (khung LOP03_sua). Ai gọi, quyền xem và các trường khác giữ nguyên migration 574.

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
    'events', coalesce((select jsonb_agg(jsonb_build_object('event_code', z.event_code, 'created_at', z.created_at, 'note', z.note,
               'actor_name', app.staff_display_name(z.created_by)) order by z.created_at desc)
               from (select * from app.class_event ev where ev.class_id = c.id order by ev.created_at desc limit 20) z), '[]'::jsonb)); -- allow-number: 20 sự kiện mới nhất
end;
$$;

-- D-26-09 (phần a, anh Trường chốt 27/11): R-LOP-07 «khung chương trình bắt buộc với lớp chung» kiểm ở máy chủ lúc TRÌNH, sau tham số
-- class_curriculum_required_enabled, mặc định TẮT, Admin bật khi go-live (như migration 589). Không chặn lúc lưu nên lớp nháp không vỡ.
-- Khi BẬT: lớp chung nạp từ Sheet (import_one_class tự Trình) và dữ liệu mẫu không có khung sẽ bị chặn; hai hàm đó giữ nguyên.
select set_config('hmt.migration', 'on', false);

insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values ('class_curriculum_required_enabled', 'Bắt buộc khung chương trình khi trình lớp chung', 'BOOL', null, null, null, 'false', false, 'VAN_HANH_LOP', 'R-LOP-07',
        'Bật: lớp chung chưa chọn khung chương trình thì không trình được; lớp riêng được miễn. Tắt: máy chủ không kiểm.')
on conflict (key) do nothing;

-- app.assert_class_curriculum(lớp): chặn khi tham số bật, lớp không phải lớp riêng (LR) và chưa có khung chương trình.
-- Chỉ app.transition_class gọi (nội bộ, quyền đã kiểm ở đó). Đầu vào: mã lớp. Kết quả: không trả gì, lỗi HMT_LOP_THIEU_KHUNG_CHUONG_TRINH.
create or replace function app.assert_class_curriculum(p_class_id uuid)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  c app.class;
begin
  select * into c from app.class where id = p_class_id;
  -- Luật R-LOP-07: lớp riêng được miễn.
  if app.get_setting_bool('class_curriculum_required_enabled', c.branch_id)
     and c.class_type_code <> 'LR' and btrim(coalesce(c.curriculum_ref, '')) = '' then
    perform app.raise_error('HMT_LOP_THIEU_KHUNG_CHUONG_TRINH',
      'Lớp chung cần có khung chương trình mới trình được. Chọn khung ở màn Sửa lớp; chưa có khung thì tạo ở Cấu hình, Khung chương trình.');
  end if;
end;
$$;
revoke execute on function app.assert_class_curriculum(uuid) from public, anon, authenticated;

-- app.transition_class(lớp, đích, ghi chú): đổi tình trạng duyệt. Mỗi đường đi một đoạn kiểm, theo R-LOP-01:
--   Nháp→[Đã trình, Huỷ]; Đã trình→[Đã xác nhận, Từ chối, Nháp, Huỷ]; Đã xác nhận→[Đã duyệt, Từ chối, Nháp, Huỷ];
--   Đã duyệt→[Đã đóng, Huỷ]; Từ chối→[Nháp, Huỷ].
-- Quyền: Trình, Từ chối→Nháp, Nháp→Huỷ: Lớp học · Sửa; Xác nhận, Duyệt, Từ chối, Đóng: Lớp học · Duyệt; Đưa về Nháp (từ Đã trình, Đã xác nhận):
--   người trình hoặc người có quyền Duyệt; Huỷ lớp đã trình trở đi: Lớp học · Huỷ.
-- Kết quả: {to, sessions_created, warnings[]}.
create or replace function app.transition_class(p_id uuid, p_to text, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.class;
  v_event text;
  v_created integer := 0;
  v_names text[];
begin
  select * into c from app.class where id = p_id for update;
  if c.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy lớp.');
  end if;
  -- Luật R-LOP-01: đường đi hợp lệ.
  if not ((c.status_code = 'NHAP' and p_to in ('DA_TRINH', 'HUY'))
       or (c.status_code = 'DA_TRINH' and p_to in ('DA_XAC_NHAN', 'TU_CHOI', 'NHAP', 'HUY'))
       or (c.status_code = 'DA_XAC_NHAN' and p_to in ('DA_DUYET', 'TU_CHOI', 'NHAP', 'HUY'))
       or (c.status_code = 'DA_DUYET' and p_to in ('DA_DONG', 'HUY'))
       or (c.status_code = 'TU_CHOI' and p_to in ('NHAP', 'HUY'))) then
    perform app.raise_error('HMT_LOP_CHUYEN_SAI', format('Lớp đang ở "%s" không chuyển được sang "%s".',
      (select name from app.catalog_item where catalog_code = 'CLASS_STATUS' and code = c.status_code),
      (select name from app.catalog_item where catalog_code = 'CLASS_STATUS' and code = p_to)));
  end if;

  -- Quyền theo từng đường đi (R-LOP-02).
  if p_to = 'DA_TRINH' or (c.status_code = 'TU_CHOI' and p_to = 'NHAP') or (c.status_code = 'NHAP' and p_to = 'HUY') then
    perform app.assert_can('CLASS', 'SUA', c.branch_id);
  elsif p_to = 'NHAP' then
    -- Đưa về Nháp từ Đã trình, Đã xác nhận: người trình hoặc quản lý cơ sở đều bấm được.
    if c.submitted_by is distinct from auth.uid() then
      perform app.assert_can('CLASS', 'DUYET', c.branch_id);
    else
      perform app.assert_can('CLASS', 'SUA', c.branch_id);
    end if;
  elsif p_to = 'HUY' then
    perform app.assert_can('CLASS', 'HUY', c.branch_id);
  else
    perform app.assert_can('CLASS', 'DUYET', c.branch_id);
  end if;

  -- Luật R-LOP-03: trình lớp bắt buộc có thời khoá biểu.
  if p_to = 'DA_TRINH' and not exists (select from app.class_slot where class_id = p_id and is_active) then
    perform app.raise_error('HMT_LOP_THIEU_THOI_KHOA_BIEU', 'Trình lớp cần có thời khoá biểu (ít nhất một khung giờ).');
  end if;
  -- Luật R-LOP-07: trình lớp chung phải có khung chương trình (sau tham số, xem app.assert_class_curriculum).
  if p_to = 'DA_TRINH' then
    perform app.assert_class_curriculum(p_id);
  end if;
  -- Từ chối bắt buộc nêu lý do.
  if p_to = 'TU_CHOI' and btrim(coalesce(p_note, '')) = '' then
    perform app.raise_error('HMT_LOP_CAN_LY_DO', 'Từ chối lớp cần ghi lý do.');
  end if;
  -- Luật R-LOP-04: đóng lớp bị chặn nếu còn học sinh còn giờ (liệt kê tên).
  if p_to = 'DA_DONG' then
    v_names := app.class_students_with_hours(p_id);
    if coalesce(array_length(v_names, 1), 0) > 0 then
      perform app.raise_error('HMT_LOP_CON_HOC_SINH_CON_GIO', 'Không đóng được lớp, còn học sinh còn giờ: ' || array_to_string(v_names, ', ') || '.');
    end if;
  end if;
  -- Luật R-LOP-04: huỷ lớp bị chặn nếu đã có buổi Done.
  if p_to = 'HUY' and exists (select from app.class_session where class_id = p_id and status_code = 'DONE') then
    perform app.raise_error('HMT_LOP_DA_CO_BUOI_DONE', 'Không huỷ được lớp đã có buổi Done.');
  end if;

  update app.class set status_code = p_to,
         submitted_by = case when p_to = 'DA_TRINH' then auth.uid() when p_to = 'NHAP' then null else submitted_by end
   where id = p_id;

  -- Luật R-LOP-03: duyệt xong thì tự sinh buổi từ thời khoá biểu.
  if p_to = 'DA_DUYET' then
    v_created := app.generate_class_sessions(p_id, c.start_date);
  end if;
  -- Huỷ lớp: các buổi chưa Done chuyển Huỷ không tính phí.
  if p_to = 'HUY' then
    update app.class_session set status_code = 'HUY_KHONG_PHI' where class_id = p_id and status_code in ('NHAP', 'DA_CHOT');
  end if;

  v_event := case p_to when 'DA_TRINH' then 'TRINH' when 'DA_XAC_NHAN' then 'XAC_NHAN' when 'DA_DUYET' then 'DUYET'
                       when 'TU_CHOI' then 'TU_CHOI' when 'NHAP' then 'VE_NHAP' when 'DA_DONG' then 'DONG' else 'HUY' end;
  perform app.class_add_event(p_id, v_event, c.status_code, p_to, p_note);
  return jsonb_build_object('to', p_to, 'sessions_created', v_created,
                            'warnings', case when p_to = 'DA_DUYET' then app.class_clash_warnings(p_id) else '[]'::jsonb end);
end;
$$;
