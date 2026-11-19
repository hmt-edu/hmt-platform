-- KH-03 Sửa phụ huynh, KH-06 Sửa học sinh (R-CRM-27, 28, 31; R-V2-04; Đ165): hai hàm sửa hồ sơ. Không có thao tác Tạo tay.
-- Cơ sở tiếp nhận chỉ Admin sửa (R-CRM-28). Hồ sơ «Đã gộp» chỉ đọc (R-CRM-25).
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- app.update_parent(p_id, p_data)
-- Làm gì: sửa thông tin liên hệ phụ huynh. Ai gọi: người có quyền Phụ huynh · Sửa ở cơ sở của hồ sơ.
-- Đầu vào: p_data có thể chứa full_name, phone, phone_2, relative_name, ward_code, province_code, address, branch_id (chỉ Admin).
--   Khoá nào không có trong p_data thì giữ nguyên.
-- Lỗi: HMT_KHONG_TIM_THAY, HMT_KHONG_CO_QUYEN, HMT_BAN_GHI_DA_GOP, HMT_THIEU_THONG_TIN, HMT_SDT_SAI, HMT_SDT_TRUNG,
--   HMT_CHI_ADMIN_DOI_CO_SO.
-- ---------------------------------------------------------------------------
create or replace function app.update_parent(p_id uuid, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old app.parent;
  v app.parent;
  v_other app.parent;
begin
  select * into v_old from app.parent where id = p_id;
  if v_old.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh.');
  end if;
  perform app.assert_can('PARENT', 'SUA', v_old.branch_id);
  -- Luật R-CRM-25: bản đã gộp chỉ đọc.
  if v_old.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Phụ huynh này đã gộp vào hồ sơ khác, chỉ xem được.');
  end if;

  v := jsonb_populate_record(v_old, coalesce(p_data, '{}'::jsonb));
  v.full_name := btrim(coalesce(v.full_name, ''));
  v.phone := app.normalize_phone(v.phone);
  v.phone_2 := nullif(app.normalize_phone(coalesce(v.phone_2, '')), '');
  v.relative_name := nullif(btrim(coalesce(v.relative_name, '')), '');
  v.address := nullif(btrim(coalesce(v.address, '')), '');

  -- Luật: họ tên bắt buộc.
  if v.full_name = '' then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Bắt buộc nhập họ tên.');
  end if;
  -- Luật R-V2-04: số chính và số thứ hai (nếu có) đúng 10 số, bắt đầu bằng 0.
  if v.phone !~ '^0[0-9]{9}$' or (v.phone_2 is not null and v.phone_2 !~ '^0[0-9]{9}$') then
    perform app.raise_error('HMT_SDT_SAI', 'Số điện thoại cần đủ 10 số, bắt đầu bằng 0.');
  end if;
  -- Luật R-CRM-27: một số điện thoại chỉ thuộc một phụ huynh (khớp theo số chính hoặc số thứ hai).
  if v.phone <> v_old.phone or v.phone_2 is distinct from v_old.phone_2 then
    select * into v_other from app.parent o
     where o.id <> p_id and o.record_status = 'DANG_DUNG'
       and (o.phone in (v.phone, coalesce(v.phone_2, '')) or o.phone_2 in (v.phone, coalesce(v.phone_2, '')))
     order by o.created_at limit 1;
    if v_other.id is not null then
      -- Chỉ nêu tên và mã khi người sửa xem được cơ sở của hồ sơ trùng; ngoài phạm vi thì báo chung, không lộ tên, mã, cơ sở.
      if app.can_see_branch('PARENT', 'XEM', v_other.branch_id) then
        perform app.raise_error('HMT_SDT_TRUNG',
          'Số điện thoại đã có ở phụ huynh khác: ' || v_other.full_name || ' (' || v_other.code || ').');
      end if;
      perform app.raise_error('HMT_SDT_TRUNG', 'Số điện thoại đã có ở phụ huynh khác.');
    end if;
  end if;
  -- Luật: phường, tỉnh phải là mục đang dùng trong danh mục.
  if v.ward_code is distinct from v_old.ward_code and v.ward_code is not null then
    perform app.assert_catalog_code_active('WARD', v.ward_code);
  end if;
  if v.province_code is distinct from v_old.province_code and v.province_code is not null then
    perform app.assert_catalog_code_active('PROVINCE', v.province_code);
  end if;
  -- Luật R-CRM-28: cơ sở tiếp nhận chỉ Admin sửa.
  if v.branch_id is distinct from v_old.branch_id and not ('ADMIN' = any (app.current_roles())) then
    perform app.raise_error('HMT_CHI_ADMIN_DOI_CO_SO', 'Chỉ Admin được sửa cơ sở tiếp nhận.');
  end if;

  update app.parent set full_name = v.full_name, phone = v.phone, phone_2 = v.phone_2, relative_name = v.relative_name,
         ward_code = v.ward_code, province_code = v.province_code, address = v.address, branch_id = v.branch_id
   where id = p_id;
  -- Ô tìm kiếm của phiếu có tên phụ huynh: tính lại cho các em của phụ huynh này.
  if v.full_name <> v_old.full_name then
    update app.student_test t set search_text = app.student_test_search_text(t)
     where t.student_id in (select s.id from app.student s where s.parent_id = p_id);
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- app.update_student(p_id, p_data)
-- Làm gì: sửa hồ sơ học sinh. Ai gọi: người có quyền Học sinh · Sửa ở cơ sở của hồ sơ.
-- Đầu vào: p_data có thể chứa full_name, birth_date, birth_year, grade, school, school_type, gender, goal, branch_id (chỉ Admin).
-- Lỗi: HMT_KHONG_TIM_THAY, HMT_KHONG_CO_QUYEN, HMT_BAN_GHI_DA_GOP, HMT_THIEU_HOC_SINH, HMT_NAM_SINH_SAI,
--   HMT_HOC_SINH_TRUNG, HMT_CHI_ADMIN_DOI_CO_SO.
-- ---------------------------------------------------------------------------
create or replace function app.update_student(p_id uuid, p_data jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old app.student;
  v app.student;
  v_other app.student;
begin
  select * into v_old from app.student where id = p_id;
  if v_old.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy học sinh.');
  end if;
  perform app.assert_can('STUDENT', 'SUA', v_old.branch_id);
  if v_old.record_status = 'DA_GOP' then
    perform app.raise_error('HMT_BAN_GHI_DA_GOP', 'Học sinh này đã gộp vào hồ sơ khác, chỉ xem được.');
  end if;

  v := jsonb_populate_record(v_old, coalesce(p_data, '{}'::jsonb));
  v.full_name := btrim(coalesce(v.full_name, ''));
  v.school := nullif(btrim(coalesce(v.school, '')), '');
  v.school_type := nullif(btrim(coalesce(v.school_type, '')), '');
  v.goal := nullif(btrim(coalesce(v.goal, '')), '');
  -- Có ngày sinh mà không gửi năm sinh thì lấy năm của ngày sinh (Đ165: năm sinh bắt buộc, ngày sinh không).
  if (p_data ? 'birth_date') and not (p_data ? 'birth_year') and v.birth_date is not null then
    v.birth_year := extract(year from v.birth_date)::integer;
  end if;

  -- Luật R-CRM-03: hồ sơ học sinh bắt buộc có họ tên và năm sinh.
  if v.full_name = '' or v.birth_year is null then
    perform app.raise_error('HMT_THIEU_HOC_SINH', 'Hồ sơ học sinh bắt buộc có họ tên và năm sinh.');
  end if;
  -- Luật: năm sinh hợp lý, và khớp ngày sinh nếu có ngày sinh.
  if v.birth_year < 1900 or v.birth_year > extract(year from now())::integer -- allow-number: 1900 là cận dưới của cột birth_year
     or (v.birth_date is not null and extract(year from v.birth_date)::integer <> v.birth_year) then
    perform app.raise_error('HMT_NAM_SINH_SAI', 'Năm sinh không hợp lệ hoặc không khớp ngày sinh.');
  end if;
  -- Luật R-CRM-27: cùng phụ huynh không có hai em trùng họ tên (không dấu) và năm sinh.
  if app.fold_text(v.full_name) <> app.fold_text(v_old.full_name) or v.birth_year <> v_old.birth_year then
    select * into v_other from app.student o
     where o.id <> p_id and o.parent_id = v_old.parent_id and o.record_status = 'DANG_DUNG'
       and app.fold_text(o.full_name) = app.fold_text(v.full_name) and o.birth_year = v.birth_year
     limit 1;
    if v_other.id is not null then
      -- Chỉ nêu tên và mã khi người sửa xem được cơ sở của em trùng; ngoài phạm vi thì báo chung.
      if app.can_see_branch('STUDENT', 'XEM', v_other.branch_id) then
        perform app.raise_error('HMT_HOC_SINH_TRUNG',
          'Phụ huynh này đã có học sinh trùng họ tên và năm sinh: ' || v_other.full_name || ' (' || v_other.code || ').');
      end if;
      perform app.raise_error('HMT_HOC_SINH_TRUNG', 'Phụ huynh này đã có học sinh trùng họ tên và năm sinh.');
    end if;
  end if;
  -- Luật R-CRM-28: cơ sở tiếp nhận chỉ Admin sửa.
  if v.branch_id is distinct from v_old.branch_id and not ('ADMIN' = any (app.current_roles())) then
    perform app.raise_error('HMT_CHI_ADMIN_DOI_CO_SO', 'Chỉ Admin được sửa cơ sở tiếp nhận.');
  end if;

  update app.student set full_name = v.full_name, birth_date = v.birth_date, birth_year = v.birth_year, grade = v.grade,
         school = v.school, school_type = v.school_type, gender = v.gender, goal = v.goal, branch_id = v.branch_id
   where id = p_id;
  -- Ô tìm kiếm của phiếu kiểm tra có tên học sinh: tính lại.
  if v.full_name <> v_old.full_name then
    update app.student_test t set search_text = app.student_test_search_text(t) where t.student_id = p_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- app.get_parent_edit_refs(p_id): mã phường, mã tỉnh của phụ huynh để màn Sửa (KH-03) đổ vào ô chọn.
-- get_parent_record chỉ trả tên phường, tỉnh. Ai gọi: người có quyền Phụ huynh · Xem ở cơ sở của hồ sơ.
-- ---------------------------------------------------------------------------
create or replace function app.get_parent_edit_refs(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  p app.parent;
begin
  select * into p from app.parent where id = p_id;
  if p.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh.');
  end if;
  perform app.assert_can('PARENT', 'XEM', p.branch_id);
  return jsonb_build_object('ward_code', p.ward_code, 'province_code', p.province_code);
end;
$$;

revoke execute on function app.update_parent(uuid, jsonb), app.update_student(uuid, jsonb), app.get_parent_edit_refs(uuid) from public, anon;
grant execute on function app.update_parent(uuid, jsonb), app.update_student(uuid, jsonb), app.get_parent_edit_refs(uuid) to authenticated;

select set_config('hmt.migration', '', false);
