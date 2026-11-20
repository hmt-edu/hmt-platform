-- R-LOP-14 kiểm môn theo khối khi tạo lớp (Chat quyết 20/11 theo uỷ quyền của anh Trường; phương án A): tham số mới class_subject_grade_check_enabled, mặc định TẮT
-- (không vỡ dữ liệu giả và test cũ), Admin bật khi go-live. Bật thì app.create_class chặn: khối >= algebra_geometry_split_grade không tạo lớp chung TOAN; khối dưới không tạo DAI, HINH;
-- lớp riêng (LR) được miễn. Lỗi HMT_LOP_MON_SAI_KHOI có câu tiếng Việt. Thân hàm lấy từ migration 574, chỉ thêm khối kiểm. Không bảng mới, không chỉ mục mới.
select set_config('hmt.migration', 'on', false);

insert into app.setting_def (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values ('class_subject_grade_check_enabled', 'Kiểm môn theo khối khi tạo lớp', 'BOOL', null, null, null, 'false', false, 'VAN_HANH_LOP', 'R-LOP-14',
        'Bật: khối từ «Khối bắt đầu tách Đại/Hình» trở lên không tạo lớp chung Toán, khối dưới không tạo lớp Đại số hoặc Hình học; lớp riêng được miễn. Tắt: không kiểm.')
on conflict (key) do nothing;

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
  -- Luật R-LOP-14 (anh uỷ quyền Chat 20/11): kiểm môn theo khối khi tạo lớp, sau tham số class_subject_grade_check_enabled (mặc định TẮT, Admin bật khi go-live).
  -- Khối từ algebra_geometry_split_grade trở lên không tạo lớp chung TOAN (đã tách Đại, Hình); khối dưới không tạo DAI, HINH. Lớp riêng (LR) được miễn (spec 02: loại lớp riêng).
  if app.get_setting_bool('class_subject_grade_check_enabled', v_branch) and p_data ->> 'class_type_code' is distinct from 'LR' then
    if substring(p_data ->> 'grade_code' from 2)::integer >= app.get_setting_int('algebra_geometry_split_grade', v_branch) -- allow-number: vị trí ký tự thứ hai trong mã khối KNN, không phải số nghiệp vụ
       and p_data ->> 'subject_code' = 'TOAN' then
      perform app.raise_error('HMT_LOP_MON_SAI_KHOI', 'Từ khối này Toán đã tách thành Đại số và Hình học: không tạo lớp chung Toán (trừ lớp riêng).');
    end if;
    if substring(p_data ->> 'grade_code' from 2)::integer < app.get_setting_int('algebra_geometry_split_grade', v_branch) -- allow-number: vị trí ký tự thứ hai trong mã khối KNN, không phải số nghiệp vụ
       and p_data ->> 'subject_code' in ('DAI', 'HINH') then
      perform app.raise_error('HMT_LOP_MON_SAI_KHOI', 'Khối này chưa tách Đại số, Hình học: không tạo lớp Đại số hoặc Hình học (trừ lớp riêng).');
    end if;
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
