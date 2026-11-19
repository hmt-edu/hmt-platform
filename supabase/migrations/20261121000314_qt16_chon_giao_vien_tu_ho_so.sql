-- QT-16 PR2 (Chat 23:05: «giáo viên khi tạo lớp chọn từ hồ sơ dạy»): app.list_class_form_options giữ nguyên bản ở 20261111000116_cum_lop_doc_du_lieu.sql, chỉ thêm vào mỗi giáo viên, trợ giảng: has_profile, subject_names, grade_names (từ hồ sơ dạy đang dùng, app.teaching_profile).
-- Hồ sơ chỉ HIỆN GỢI Ý ở ô chọn (môn, khối), không chặn: người chưa có hồ sơ vẫn chọn được (ghi «chưa có hồ sơ dạy»), để không khoá việc tạo lớp khi hồ sơ chưa nhập đủ.
create or replace function app.list_class_form_options(p_branch_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := coalesce(app.permission_scope('CLASS', 'TAO'), app.permission_scope('CLASS', 'SUA'));
begin
  if v_scope is null or (v_scope = 'CO_SO' and p_branch_id is distinct from app.current_branch_id()) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền tạo hoặc sửa lớp ở cơ sở này.');
  end if;
  return jsonb_build_object(
    'teachers', coalesce((select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.display_name, 'staff_code', u.staff_code,
                                 'has_profile', exists (select from app.teaching_profile tp where tp.user_id = u.id and tp.is_active),
                                 'subject_names', coalesce((select jsonb_agg(ci.name order by ci.sort_order) from app.teaching_profile tp join app.catalog_item ci on ci.catalog_code = 'SUBJECT' and ci.code = any (tp.subject_codes) where tp.user_id = u.id and tp.is_active), '[]'::jsonb),
                                 'grade_names', coalesce((select jsonb_agg(ci.name order by ci.sort_order) from app.teaching_profile tp join app.catalog_item ci on ci.catalog_code = 'GRADE' and ci.code = any (tp.grade_codes) where tp.user_id = u.id and tp.is_active), '[]'::jsonb)) order by u.display_name)
                            from app.user_account u where u.branch_id = p_branch_id and not u.is_locked
                             and exists (select from app.user_role r where r.user_id = u.id and r.is_active and r.role_code = 'TEACHER')), '[]'::jsonb),
    'assistants', coalesce((select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.display_name, 'staff_code', u.staff_code,
                                 'has_profile', exists (select from app.teaching_profile tp where tp.user_id = u.id and tp.is_active),
                                 'subject_names', coalesce((select jsonb_agg(ci.name order by ci.sort_order) from app.teaching_profile tp join app.catalog_item ci on ci.catalog_code = 'SUBJECT' and ci.code = any (tp.subject_codes) where tp.user_id = u.id and tp.is_active), '[]'::jsonb),
                                 'grade_names', coalesce((select jsonb_agg(ci.name order by ci.sort_order) from app.teaching_profile tp join app.catalog_item ci on ci.catalog_code = 'GRADE' and ci.code = any (tp.grade_codes) where tp.user_id = u.id and tp.is_active), '[]'::jsonb)) order by u.display_name)
                            from app.user_account u where u.branch_id = p_branch_id and not u.is_locked
                             and exists (select from app.user_role r where r.user_id = u.id and r.is_active and r.role_code = 'TA')), '[]'::jsonb),
    'cskh', coalesce((select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.display_name, 'staff_code', u.staff_code) order by u.display_name)
                            from app.user_account u where u.branch_id = p_branch_id and not u.is_locked
                             and exists (select from app.user_role r where r.user_id = u.id and r.is_active and r.role_code = 'CSKH')), '[]'::jsonb),
    'rooms', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'name', r.name, 'capacity', r.capacity) order by r.sort_order, r.name)
                            from app.room r where r.branch_id = p_branch_id and r.is_active), '[]'::jsonb),
    'groups', coalesce((select jsonb_agg(jsonb_build_object('id', g.id, 'grade_code', g.grade_code, 'name', g.display_name) order by g.created_at desc)
                            from app.class_group g where g.branch_id = p_branch_id), '[]'::jsonb));
end;
$$;