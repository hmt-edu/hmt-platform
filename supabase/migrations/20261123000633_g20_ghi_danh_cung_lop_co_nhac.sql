-- A-23-19 / G20 (Chat 17:20, anh OK 23/11): hộp Xếp lớp NHẮC (không chặn) khi em đã có ghi danh khác cùng lớp.
-- app.enrollment_assign_options (thân giữ nguyên bản migration 591, chỉ thêm khoá same_class_enrollments vào từng lớp trong `classes`): mảng mã ghi danh khác của em còn trong lớp đó. CHỈ ĐỌC, quyền như cũ (Ghi danh · Sửa, cơ sở mình).
-- Không đổi bảng, không chỉ mục mới (tra theo enrollment_class(class_id) đã có chỉ mục lớp). Luật: R-GIO-04 (một em hai ghi danh cùng lớp hợp lệ), R-GD-05.
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
    -- GD-03 (canvas GD03_nhac_mem): nhắc mềm, KHÔNG chặn: em chỉ có ghi danh một trong hai môn Đại, Hình (Toán 7+) mà chưa có môn kia.
    'sibling_hint', (select jsonb_build_object('have_subject_code', e.subject_code, 'missing_subject_code', m.code,
                                               'have_subject_name', hv.name, 'missing_subject_name', m.name)
                       from (select case e.subject_code when 'DAI' then 'HINH' when 'HINH' then 'DAI' end as code) o
                       join app.catalog_item m on m.catalog_code = 'SUBJECT' and m.code = o.code
                       join app.catalog_item hv on hv.catalog_code = 'SUBJECT' and hv.code = e.subject_code
                      where o.code is not null
                        and not exists (select from app.enrollment x
                                         where x.student_id = e.student_id and x.branch_id = e.branch_id and x.id <> e.id and x.subject_code = o.code
                                           and x.status_code not in ('DUNG', 'HOAN_PHI', 'CHUYEN_LOP', 'HOAN_THANH'))),
    -- G20 (anh OK 23/11): mỗi lớp thêm `same_class_enrollments`: mã các ghi danh KHÁC của chính em đang còn trong lớp đó (Đã xếp lớp, Đang học). Giao diện chỉ NHẮC, không chặn (R-GIO-04: một em hai ghi danh cùng lớp vẫn hợp lệ).
    'classes', case when e.package_id is null then '[]'::jsonb else
      (select coalesce(jsonb_agg(c || jsonb_build_object('same_class_enrollments', coalesce((
                select jsonb_agg(x.code order by x.code)
                  from app.enrollment_class ec join app.enrollment x on x.id = ec.enrollment_id
                 where ec.class_id = (c ->> 'id')::uuid and ec.end_date is null and x.student_id = e.student_id and x.id <> e.id
                   and x.status_code in ('DA_XEP_LOP', 'DANG_HOC')), '[]'::jsonb)) order by ord), '[]'::jsonb)
         from jsonb_array_elements(app.enrollment_matching_classes(e.package_id, e.branch_id, e.student_id)) with ordinality as t (c, ord)) end,
    'groups', v_groups);
end;
$$;
