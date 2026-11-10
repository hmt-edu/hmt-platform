-- Cụm Khách hàng (Code 2, 11/11/2026): hàm đọc cho KH-01 (danh sách phụ huynh), KH-02 (phụ huynh, bản ghi), KH-04 (danh sách học sinh), KH-05 (học sinh, hồ sơ 360°).
-- Luật: R-CRM-27 (không tạo tay, chỉ sửa), R-CRM-29 (xuất chỉ Admin), R-CRM-33 (phụ huynh không có mã cũ), R-GD-02, S02-TT-HS (tình trạng học sinh tính từ ghi danh).
-- Chỉ đọc. Phạm vi theo quyền: Phụ huynh · Xem (như chính sách parent_read: ai có quyền xem thì thấy mọi phụ huynh chưa gộp);
-- Học sinh · Xem (toàn hệ thống hoặc cơ sở mình, như chính sách student_read).
-- Quy tắc hiển thị tạm, chưa vào luật (Chat 10/11). Tình trạng học sinh (tính, không lưu): Đang học = có ghi danh Chờ xếp lớp, Đã xếp lớp hoặc Đang học;
-- Bảo lưu = không thuộc Đang học và có ghi danh Bảo lưu; Dừng học = không thuộc hai nhóm trên nhưng có ghi danh bất kỳ (Hoàn thành, Chuyển lớp, Dừng, Hoàn phí); Tiềm năng = chưa có ghi danh.

-- app.student_status(học sinh): tình trạng tính từ ghi danh (S02-TT-HS).
create or replace function app.student_status(p_student_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when exists (select from app.enrollment e where e.student_id = p_student_id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC')) then 'DANG_HOC'
           when exists (select from app.enrollment e where e.student_id = p_student_id and e.status_code = 'BAO_LUU') then 'BAO_LUU'
           when exists (select from app.enrollment e where e.student_id = p_student_id) then 'DUNG'
           else 'TIEM_NANG'
         end;
$$;

-- app.list_parents(bộ lọc, sắp xếp, limit, offset): KH-01. Bộ lọc: search (tên, SĐT, mã; không dấu), status[] ('DANG_HOC' = có con đang học, 'CHUA_DANG_HOC'), branch_id (cơ sở tiếp nhận).
-- Sắp xếp: code_asc (mặc định), name_asc, code_desc. Kết quả {total, rows[]}.
create or replace function app.list_parents(p_filters jsonb default '{}'::jsonb, p_sort text default 'code_asc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('PARENT', 'XEM');
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_search text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phụ huynh.');
  end if;
  with f as not materialized (
    select p.*,
           exists (select from app.enrollment e where e.parent_id = p.id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC')) as studying
      from app.parent p
     where p.record_status = 'DANG_DUNG'
       and (v_branch is null or p.branch_id = v_branch)
       and (v_search is null or p.search_text like '%' || v_search || '%')
  ), g as (
    select * from f
     where cardinality(v_status) = 0
        or ('DANG_HOC' = any (v_status) and f.studying)
        or ('CHUA_DANG_HOC' = any (v_status) and not f.studying)
  ), page as (
    select * from g
     order by case when p_sort = 'name_asc' then g.full_name end,
              case when p_sort = 'code_desc' then g.code end desc,
              g.code
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from g),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'full_name', p.full_name, 'phone', p.phone,
             'branch_code', b.code, 'is_studying', p.studying,
             'children_count', (select count(*) from app.student s where s.parent_id = p.id and s.record_status = 'DANG_DUNG'),
             'studying_at', coalesce((select jsonb_agg(distinct eb.code order by eb.code) from app.enrollment e join app.branch eb on eb.id = e.branch_id
                                       where e.parent_id = p.id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')), '[]'::jsonb))
             order by case when p_sort = 'name_asc' then p.full_name end, case when p_sort = 'code_desc' then p.code end desc, p.code), '[]'::jsonb))
    into v_result
    from page p join app.branch b on b.id = p.branch_id;
  return v_result;
end;
$$;

-- app.get_parent_record(phụ huynh): KH-02 bản ghi. Thông tin, các con, đơn hàng, phiếu thu (50 dòng mới nhất mỗi loại), số đếm cho nút liên kết.
-- Không có Tạo tay (R-CRM-27). Phụ huynh đã gộp: trả mã đích để giao diện chuyển hướng.
create or replace function app.get_parent_record(p_parent_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  p app.parent;
begin
  if app.permission_scope('PARENT', 'XEM') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phụ huynh.');
  end if;
  select * into p from app.parent where id = p_parent_id;
  if p.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phụ huynh.');
  end if;
  return jsonb_build_object(
    'id', p.id, 'code', p.code, 'full_name', p.full_name, 'phone', p.phone, 'phone_2', p.phone_2, 'relative_name', p.relative_name,
    'address', p.address,
    'ward_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'WARD' and ci.code = p.ward_code),
    'province_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'PROVINCE' and ci.code = p.province_code),
    'branch_code', (select b.code from app.branch b where b.id = p.branch_id),
    'record_status', p.record_status, 'merged_into_id', p.merged_into_id,
    'created_at', p.created_at,
    'is_studying', exists (select from app.enrollment e where e.parent_id = p.id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC')),
    'studying_at', coalesce((select jsonb_agg(distinct eb.code order by eb.code) from app.enrollment e join app.branch eb on eb.id = e.branch_id
                              where e.parent_id = p.id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')), '[]'::jsonb),
    'children', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'code', s.code, 'full_name', s.full_name, 'grade', s.grade, 'status', app.student_status(s.id)) order by s.full_name)
                            from app.student s where s.parent_id = p.id and s.record_status = 'DANG_DUNG'), '[]'::jsonb),
    'orders', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'code', o.code, 'status_code', o.status_code, 'total_amount', o.total_amount, 'created_at', o.created_at) order by o.created_at desc)
                          from (select * from app.sales_order x where x.parent_id = p.id order by x.created_at desc limit 50) o), '[]'::jsonb), -- allow-number: 50 dòng mới nhất mỗi loại trên bản ghi
    'receipts', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'code', r.code, 'status_code', r.status_code, 'amount', r.amount, 'paid_on', r.paid_on) order by r.created_at desc)
                            from (select * from app.receipt x where x.parent_id = p.id order by x.created_at desc limit 50) r), '[]'::jsonb), -- allow-number: 50 dòng mới nhất mỗi loại trên bản ghi
    'counts', jsonb_build_object(
      'children', (select count(*) from app.student s where s.parent_id = p.id and s.record_status = 'DANG_DUNG'),
      'opportunities', (select count(*) from app.opportunity o where o.parent_id = p.id and o.record_status = 'DANG_DUNG'),
      'tests', (select count(*) from app.student_test t join app.student s on s.id = t.student_id where s.parent_id = p.id),
      'enrollments', (select count(*) from app.enrollment e where e.parent_id = p.id),
      'orders', (select count(*) from app.sales_order o where o.parent_id = p.id),
      'receipts', (select count(*) from app.receipt r where r.parent_id = p.id)));
end;
$$;

-- app.list_students(bộ lọc, sắp xếp, limit, offset): KH-04. Bộ lọc: search (tên, mã, mã cũ, không dấu), status[] ('DANG_HOC','BAO_LUU','DUNG','TIEM_NANG'), branch_id, grade (số khối).
-- Kết quả {total, rows[]}: tình trạng tính từ ghi danh, cơ sở đang học, lớp đang học, tên và SĐT phụ huynh.
create or replace function app.list_students(p_filters jsonb default '{}'::jsonb, p_sort text default 'code_asc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('STUDENT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_grade smallint := nullif(p_filters ->> 'grade', '')::smallint;
  v_search text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem học sinh.');
  end if;
  with f as not materialized (
    select s.*, app.student_status(s.id) as status_calc
      from app.student s
     where s.record_status = 'DANG_DUNG'
       -- Giáo viên, trợ giảng (phạm vi được phân công): chỉ học sinh đang xếp trong lớp của mình; không có số điện thoại phụ huynh (R-GV-13).
       and (v_scope = 'TOAN_HE_THONG'
            or (v_scope = 'DUOC_PHAN_CONG' and exists (select from app.enrollment e2 join app.enrollment_class ec2 on ec2.enrollment_id = e2.id
                                                        where e2.student_id = s.id and ec2.end_date is null and app.is_assigned_to_class(ec2.class_id)))
            or (v_scope not in ('TOAN_HE_THONG', 'DUOC_PHAN_CONG') and s.branch_id = v_my_branch))
       and (v_branch is null or s.branch_id = v_branch)
       and (v_grade is null or s.grade = v_grade)
       and (v_search is null or s.search_text like '%' || v_search || '%')
  ), g as (
    select * from f where cardinality(v_status) = 0 or f.status_calc = any (v_status)
  ), page as (
    select * from g
     order by case when p_sort = 'name_asc' then g.full_name end,
              case when p_sort = 'code_desc' then g.code end desc,
              g.code
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from g),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', s.id, 'code', s.code, 'legacy_ref', s.legacy_ref, 'full_name', s.full_name, 'grade', s.grade,
             'status', s.status_calc, 'branch_code', b.code,
             'parent_id', par.id, 'parent_name', par.full_name, 'parent_phone', case when v_scope = 'DUOC_PHAN_CONG' then null else par.phone end,
             'studying_at', coalesce((select jsonb_agg(distinct eb.code order by eb.code) from app.enrollment e join app.branch eb on eb.id = e.branch_id
                                       where e.student_id = s.id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')), '[]'::jsonb),
             'classes', coalesce((select jsonb_agg(c.code order by c.code) from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id join app.class c on c.id = ec.class_id
                                   where e.student_id = s.id and ec.end_date is null and e.status_code in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU')), '[]'::jsonb))
             order by case when p_sort = 'name_asc' then s.full_name end, case when p_sort = 'code_desc' then s.code end desc, s.code), '[]'::jsonb))
    into v_result
    from page s join app.branch b on b.id = s.branch_id join app.parent par on par.id = s.parent_id;
  return v_result;
end;
$$;

-- app.get_student_record(học sinh): KH-05 hồ sơ 360°. Thông tin, phụ huynh, ghi danh (mã, môn, tình trạng, lớp, giờ còn), tổng kết điểm danh,
-- 20 buổi điểm danh gần nhất, điểm kiểm tra gần nhất (20 dòng), phiếu kiểm tra đầu vào; số đếm cho nút liên kết. Ticket, khiếu nại, tài khoản học tập: chưa có dữ liệu (giai đoạn sau).
create or replace function app.get_student_record(p_student_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('STUDENT', 'XEM');
  s app.student;
begin
  select * into s from app.student where id = p_student_id;
  if s.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy học sinh.');
  end if;
  if v_scope is null
     or (v_scope = 'DUOC_PHAN_CONG' and not exists (select from app.enrollment e2 join app.enrollment_class ec2 on ec2.enrollment_id = e2.id
                                                     where e2.student_id = s.id and ec2.end_date is null and app.is_assigned_to_class(ec2.class_id)))
     or (v_scope not in ('TOAN_HE_THONG', 'DUOC_PHAN_CONG') and s.branch_id is distinct from app.current_branch_id()) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem học sinh này.');
  end if;
  return jsonb_build_object(
    'id', s.id, 'code', s.code, 'legacy_ref', s.legacy_ref, 'full_name', s.full_name, 'birth_date', s.birth_date, 'birth_year', s.birth_year,
    'grade', s.grade, 'school', s.school, 'goal', s.goal, 'gender', s.gender,
    'branch_code', (select b.code from app.branch b where b.id = s.branch_id),
    'status', app.student_status(s.id), 'record_status', s.record_status, 'merged_into_id', s.merged_into_id,
    'created_at', s.created_at, 'updated_at', s.updated_at,
    'parent', (select jsonb_build_object('id', p.id, 'code', p.code, 'full_name', p.full_name, 'phone', case when v_scope = 'DUOC_PHAN_CONG' then null else p.phone end) from app.parent p where p.id = s.parent_id),
    'studying_at', coalesce((select jsonb_agg(distinct eb.code order by eb.code) from app.enrollment e join app.branch eb on eb.id = e.branch_id
                              where e.student_id = s.id and e.status_code in ('DA_XEP_LOP', 'DANG_HOC')), '[]'::jsonb),
    'enrollments', coalesce((select jsonb_agg(jsonb_build_object(
                     'id', e.id, 'code', e.code, 'subject_code', e.subject_code,
                     'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = e.subject_code),
                     'status_code', e.status_code,
                     'status_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'ENROLLMENT_STATUS' and ci.code = e.status_code),
                     'class_id', c.id, 'class_code', c.code, 'hours_left', app.enrollment_hours_balance(e.id)) order by e.created_at desc)
                       from app.enrollment e
                       left join lateral (select c2.* from app.enrollment_class ec join app.class c2 on c2.id = ec.class_id
                                           where ec.enrollment_id = e.id and ec.end_date is null limit 1) c on true
                      where e.student_id = s.id), '[]'::jsonb),
    'attendance_summary', coalesce((select jsonb_object_agg(x.status, x.n) from (
                     select coalesce(sa.teacher_status_code, 'CHUA') as status, count(*) as n from app.session_attendance sa
                      where sa.student_id = s.id and sa.is_active group by 1) x), '{}'::jsonb),
    'attendance', coalesce((select jsonb_agg(jsonb_build_object(
                     'session_date', y.session_date, 'start_time', y.start_time, 'class_code', y.class_code, 'session_status', y.session_status, 'status', y.status) order by y.session_date desc, y.start_time desc)
                       from (select cs.session_date, cs.start_time, c.code as class_code, cs.status_code as session_status, sa.teacher_status_code as status
                               from app.session_attendance sa join app.class_session cs on cs.id = sa.session_id join app.class c on c.id = cs.class_id
                              where sa.student_id = s.id and sa.is_active order by cs.session_date desc, cs.start_time desc limit 20) y), '[]'::jsonb), -- allow-number: 20 buổi gần nhất trên hồ sơ
    'exam_scores', coalesce((select jsonb_agg(jsonb_build_object(
                     'session_date', z.session_date, 'class_code', z.class_code, 'total_score', z.total_score, 'max_score', z.max_score) order by z.session_date desc)
                       from (select cs.session_date, c.code as class_code, es.total_score, se.max_score
                               from app.exam_score es join app.session_attendance sa on sa.id = es.attendance_id join app.class_session cs on cs.id = es.session_id
                               join app.class c on c.id = cs.class_id left join app.session_exam se on se.session_id = es.session_id
                              where sa.student_id = s.id and es.graded order by cs.session_date desc limit 20) z), '[]'::jsonb), -- allow-number: 20 bài kiểm tra gần nhất
    'tests', coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'code', t.code, 'status_code', t.status_code, 'scheduled_at', t.scheduled_at, 'score', t.score) order by t.created_at desc)
                         from app.student_test t where t.student_id = s.id), '[]'::jsonb),
    'counts', jsonb_build_object(
      'enrollments', (select count(*) from app.enrollment e where e.student_id = s.id),
      'classes', (select count(*) from app.enrollment_class ec join app.enrollment e on e.id = ec.enrollment_id where e.student_id = s.id and ec.end_date is null),
      'tests', (select count(*) from app.student_test t where t.student_id = s.id)));
end;
$$;

revoke execute on function app.student_status(uuid), app.list_parents(jsonb, text, integer, integer), app.get_parent_record(uuid),
  app.list_students(jsonb, text, integer, integer), app.get_student_record(uuid) from public, anon, authenticated;
grant execute on function app.list_parents(jsonb, text, integer, integer), app.get_parent_record(uuid),
  app.list_students(jsonb, text, integer, integer), app.get_student_record(uuid) to authenticated;
