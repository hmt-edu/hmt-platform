-- QT-16 Hồ sơ giáo viên, trợ giảng (Chat 23:05, anh Trường duyệt; docs/nghiep-vu/de-xuat-man-con-thieu-crm.md). Luật R-LOP-08 (khung giờ có giáo viên, trợ giảng), R-LOP-10 (giáo viên chọn khi tạo lớp).
-- Hồ sơ dạy của MỘT người dùng có vai Giáo viên (TEACHER) hoặc Trợ giảng (TA): môn dạy, khối dạy, cơ sở thường dạy, ghi chú, đang dạy hay ngừng. Mã GV/TG là mã nhân sự (staff_code) của tài khoản.
-- Hồ sơ là THÔNG TIN THAM KHẢO khi xếp lịch (gợi ý, không chặn): lớp vẫn chọn được mọi giáo viên đúng cơ sở (app.list_class_form_options không đổi ở bản này). Không xoá, chỉ Ngừng.
-- Danh mục môn, khối là danh mục SUBJECT, GRADE (không viết cứng). Ghi nhật ký qua app.apply_standard.

create table app.teaching_profile (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references app.user_account (id),
  kind text not null check (kind in ('GV', 'TG')),
  subject_codes text[] not null default '{}',
  grade_codes text[] not null default '{}',
  branch_ids uuid[] not null default '{}',
  note text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
comment on table app.teaching_profile is 'Hồ sơ dạy của giáo viên, trợ giảng (QT-16): môn, khối, cơ sở thường dạy; chỉ tham khảo khi xếp lịch, không chặn (R-LOP-08, R-LOP-10).';
-- Chỉ mục (lý do): lọc danh sách theo loại và tình trạng; unique(user_id) đã có chỉ mục tìm theo người.
create index teaching_profile_list_idx on app.teaching_profile (is_active, kind);
select app.apply_standard('app.teaching_profile');
alter table app.teaching_profile enable row level security;
grant select on app.teaching_profile to authenticated;
create policy teaching_profile_read on app.teaching_profile for select to authenticated
  using ((select app.permission_scope('CONFIG_TRAINING', 'XEM')) is not null);

-- app.list_teaching_candidates(): người dùng có vai Giáo viên hoặc Trợ giảng, đang hoạt động, CHƯA có hồ sơ dạy (ô chọn khi tạo hồ sơ). Ai gọi: Quản trị · Sửa.
create or replace function app.list_teaching_candidates()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform app.assert_can('ADMIN', 'SUA', null);
  return coalesce((
    select jsonb_agg(jsonb_build_object('user_id', u.id, 'name', u.display_name, 'staff_code', u.staff_code,
             'kind', case when exists (select from app.user_role r where r.user_id = u.id and r.is_active and r.role_code = 'TEACHER') then 'GV' else 'TG' end)
           order by u.display_name)
      from app.user_account u
     where not u.is_locked
       and not exists (select from app.teaching_profile p where p.user_id = u.id)
       and exists (select from app.user_role r where r.user_id = u.id and r.is_active and r.role_code in ('TEACHER', 'TA'))), '[]'::jsonb);
end;
$$;

-- app.list_teaching_profiles(bộ lọc, sắp xếp, giới hạn, vị trí) -> {total, rows}. Ai gọi: Cấu hình đào tạo · Xem (Trưởng cơ sở, CSKH, Admin...).
-- Bộ lọc: search (tên, mã nhân sự, không dấu), kind (GV|TG), subject, grade, branch_id (cơ sở thường dạy), active (true|false). Sắp: name_asc (mặc định), name_desc.
-- Phân trang ở máy chủ (mặc định theo tham số danh sách, tối đa theo tham số).
create or replace function app.list_teaching_profiles(p_filters jsonb default '{}'::jsonb, p_sort text default 'name_asc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_kind text := nullif(p_filters ->> 'kind', '');
  v_subject text := nullif(p_filters ->> 'subject', '');
  v_grade text := nullif(p_filters ->> 'grade', '');
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_active boolean := nullif(p_filters ->> 'active', '')::boolean;
  v_result jsonb;
begin
  if app.permission_scope('CONFIG_TRAINING', 'XEM') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem hồ sơ giáo viên, trợ giảng.');
  end if;
  with f as not materialized (
    select p.*, u.display_name, u.staff_code, u.login_name
      from app.teaching_profile p
      join app.user_account u on u.id = p.user_id
     where (v_q is null or app.fold_text(u.display_name || ' ' || coalesce(u.staff_code, '')) like '%' || v_q || '%')
       and (v_kind is null or p.kind = v_kind)
       and (v_subject is null or v_subject = any (p.subject_codes))
       and (v_grade is null or v_grade = any (p.grade_codes))
       and (v_branch is null or v_branch = any (p.branch_ids))
       and (v_active is null or p.is_active = v_active)
  ), page as (
    select * from f order by case when p_sort = 'name_desc' then f.display_name end desc, f.display_name, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'user_id', p.user_id, 'name', p.display_name, 'staff_code', p.staff_code, 'login_name', p.login_name,
             'kind', p.kind, 'is_active', p.is_active, 'note', p.note,
             'subject_codes', to_jsonb(p.subject_codes), 'grade_codes', to_jsonb(p.grade_codes), 'branch_ids', to_jsonb(p.branch_ids),
             'subject_names', coalesce((select jsonb_agg(ci.name order by ci.sort_order) from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = any (p.subject_codes)), '[]'::jsonb),
             'grade_names', coalesce((select jsonb_agg(ci.name order by ci.sort_order) from app.catalog_item ci where ci.catalog_code = 'GRADE' and ci.code = any (p.grade_codes)), '[]'::jsonb),
             'branch_codes', coalesce((select jsonb_agg(b.code order by b.code) from app.branch b where b.id = any (p.branch_ids)), '[]'::jsonb))
             order by case when p_sort = 'name_desc' then p.display_name end desc, p.display_name, p.id), '[]'::jsonb))
    into v_result
    from page p;
  return v_result;
end;
$$;

-- app.save_teaching_profile(p_data) -> {id}: thêm hồ sơ (có user_id, không có id) hoặc sửa (có id). Ai gọi: Quản trị · Sửa.
-- Dữ liệu: id (sửa), user_id (thêm), subject_codes, grade_codes (mảng mã danh mục đang dùng), branch_ids (mảng cơ sở), note.
-- Luật: người được thêm phải đang hoạt động và có vai Giáo viên hoặc Trợ giảng (loại GV nếu có vai Giáo viên, không thì TG); mỗi người một hồ sơ; môn, khối phải là mã đang dùng của danh mục; cơ sở phải tồn tại.
create or replace function app.save_teaching_profile(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := nullif(p_data ->> 'id', '')::uuid;
  v_user uuid := nullif(p_data ->> 'user_id', '')::uuid;
  v_subjects text[] := array(select jsonb_array_elements_text(coalesce(p_data -> 'subject_codes', '[]'::jsonb)));
  v_grades text[] := array(select jsonb_array_elements_text(coalesce(p_data -> 'grade_codes', '[]'::jsonb)));
  v_branches uuid[] := array(select (jsonb_array_elements_text(coalesce(p_data -> 'branch_ids', '[]'::jsonb)))::uuid);
  v_note text := nullif(btrim(coalesce(p_data ->> 'note', '')), '');
  v_kind text;
begin
  perform app.assert_can('ADMIN', 'SUA', null);
  -- Luật: môn, khối là mã ĐANG DÙNG của danh mục (không viết cứng danh sách).
  if exists (select from unnest(v_subjects) s where not exists (select from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = s and ci.is_active)) then
    perform app.raise_error('HMT_MON_SAI', 'Có môn học không còn dùng hoặc không có trong danh mục.');
  end if;
  if exists (select from unnest(v_grades) g where not exists (select from app.catalog_item ci where ci.catalog_code = 'GRADE' and ci.code = g and ci.is_active)) then
    perform app.raise_error('HMT_KHOI_SAI', 'Có khối không còn dùng hoặc không có trong danh mục.');
  end if;
  if exists (select from unnest(v_branches) b where not exists (select from app.branch x where x.id = b)) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ sở đã chọn.');
  end if;
  if v_id is null then
    if v_user is null then
      perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn người dùng để lập hồ sơ dạy.');
    end if;
    if not exists (select from app.user_account u where u.id = v_user and not u.is_locked) then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy người dùng đang hoạt động.');
    end if;
    -- Luật R-LOP-08: chỉ người có vai Giáo viên hoặc Trợ giảng mới có hồ sơ dạy.
    select case when exists (select from app.user_role r where r.user_id = v_user and r.is_active and r.role_code = 'TEACHER') then 'GV'
                when exists (select from app.user_role r where r.user_id = v_user and r.is_active and r.role_code = 'TA') then 'TG' end
      into v_kind;
    if v_kind is null then
      perform app.raise_error('HMT_KHONG_PHAI_GIAO_VIEN', 'Người này không có vai Giáo viên hoặc Trợ giảng.');
    end if;
    if exists (select from app.teaching_profile where user_id = v_user) then
      perform app.raise_error('HMT_HO_SO_DA_CO', 'Người này đã có hồ sơ dạy.');
    end if;
    insert into app.teaching_profile (user_id, kind, subject_codes, grade_codes, branch_ids, note)
    values (v_user, v_kind, v_subjects, v_grades, v_branches, v_note) returning id into v_id;
  else
    update app.teaching_profile set subject_codes = v_subjects, grade_codes = v_grades, branch_ids = v_branches, note = v_note where id = v_id;
    if not found then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy hồ sơ dạy.');
    end if;
  end if;
  return jsonb_build_object('id', v_id);
end;
$$;

-- app.set_teaching_profile_active(id, active): Ngừng hoặc Dùng lại hồ sơ dạy (không xoá). Ai gọi: Quản trị · Sửa.
create or replace function app.set_teaching_profile_active(p_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_can('ADMIN', 'SUA', null);
  if p_active is null then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Cần chọn Ngừng hoặc Dùng lại.');
  end if;
  update app.teaching_profile set is_active = p_active where id = p_id;
  if not found then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy hồ sơ dạy.');
  end if;
end;
$$;

revoke execute on function app.list_teaching_candidates(), app.list_teaching_profiles(jsonb, text, integer, integer),
  app.save_teaching_profile(jsonb), app.set_teaching_profile_active(uuid, boolean) from public, anon;
grant execute on function app.list_teaching_candidates(), app.list_teaching_profiles(jsonb, text, integer, integer),
  app.save_teaching_profile(jsonb), app.set_teaching_profile_active(uuid, boolean) to authenticated;
