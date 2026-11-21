-- C96 (thư Chat 12:18; migration 606, rủi ro CAO theo quy ước: hàm danh sách, phạm vi quyền). Group By còn thiếu theo canvas 9933 cho các danh sách đã dùng khuôn K03 mà chưa có nút Group By (docs/nghiep-vu/doi-chieu-group-by.md):
-- KH-04 Học sinh, LOP-09 Học sinh của lớp, GD-06 Hàng chờ xếp lớp (anh chốt theo canvas), GD-07 Sắp hết giờ, BUOI-11 Điểm danh vận hành trong ngày, BUOI-12 Buổi chưa Done.
-- Mỗi màn: một hàm đếm nhóm (tối đa hai cấp khác nhau, Đ35), quyền và bộ lọc GIỐNG hàm danh sách; một hàm nhãn; hàm danh sách thêm bộ lọc để mở nhóm khi thiếu (LOP-09: branch_id; BUOI-12: teacher_id). Chỉ đọc, không đổi bảng, không thêm chỉ mục
-- (đếm trên cùng tập dòng mà hàm danh sách đã quét). GD-07: tách phần tính tình trạng ra expiring_enrollment_rows để danh sách và đếm không thể lệch nhau.
-- Không làm trong PR này: BUOI-10 (Yêu cầu buổi, chưa dùng khuôn K03), BUOI-13, BUOI-14, TC-09 (hộp thoại K08), LOP-08 (Lịch K05): không có danh sách để nhóm.
select set_config('hmt.migration', 'on', false);

-- ===== KH-04 Học sinh =====
-- app.student_group_counts(bộ lọc, trường nhóm): quyền «Học sinh · Xem» như list_students (R-GV-13: giáo viên chỉ thấy học sinh trong lớp của mình).
-- Trường nhóm: status (Tiềm năng, Đang học, Bảo lưu, Dừng học: tính từ ghi danh), grade (khối), branch (cơ sở tiếp nhận). Bộ lọc giống list_students: status (mảng), branch_id, grade, search.
create or replace function app.student_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('STUDENT', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_grade smallint := nullif(p_filters ->> 'grade', '')::smallint;
  v_search text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem học sinh.');
  end if;
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status', 'grade', 'branch'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, khối, cơ sở tiếp nhận).');
  end if;
  with f as not materialized (
    select s.grade, s.branch_id, app.student_status(s.id) as status_calc
      from app.student s
     where s.record_status = 'DANG_DUNG'
       and (v_scope = 'TOAN_HE_THONG'
            or (v_scope = 'DUOC_PHAN_CONG' and exists (select from app.enrollment e2 join app.enrollment_class ec2 on ec2.enrollment_id = e2.id
                                                        where e2.student_id = s.id and ec2.end_date is null and app.is_assigned_to_class(ec2.class_id)))
            or (v_scope not in ('TOAN_HE_THONG', 'DUOC_PHAN_CONG') and s.branch_id = v_my_branch))
       and (v_branch is null or s.branch_id = v_branch)
       and (v_grade is null or s.grade = v_grade)
       and (v_search is null or s.search_text like '%' || v_search || '%')
  ), g as (
    select * from f where cardinality(v_status) = 0 or f.status_calc = any (v_status)
  ), keyed as (
    select case v_f1 when 'status' then g.status_calc when 'grade' then g.grade::text when 'branch' then g.branch_id::text end as k1,
           case v_f2 when 'status' then g.status_calc when 'grade' then g.grade::text when 'branch' then g.branch_id::text end as k2
      from g
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.student_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.student_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

create or replace function app.student_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'status' then case p_key when 'DANG_HOC' then 'Đang học' when 'BAO_LUU' then 'Bảo lưu' when 'DUNG' then 'Dừng học' when 'TIEM_NANG' then 'Tiềm năng' else p_key end
    when p_field = 'grade' then 'Lớp ' || p_key
    when p_field = 'branch' then coalesce((select b.code || ' ' || b.name from app.branch b where b.id = p_key::uuid), p_key)
    else p_key end;
$$;


-- ===== LOP-09 Học sinh của lớp =====
-- list_class_students: như migration 477, thêm bộ lọc branch_id (cơ sở phụ trách của ghi danh) để mở một nhóm.
create or replace function app.list_class_students(
  p_class_id uuid, p_filters jsonb default '{}'::jsonb, p_sort text default 'name_asc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('CLASS', 'XEM');
  c app.class;
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_state text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'state', '[]'::jsonb)));
  v_delivery text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'delivery', '[]'::jsonb)));
  -- C96: cơ sở phụ trách của ghi danh (canvas LOP09); dùng để mở một nhóm Group By.
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_result jsonb;
begin
  select * into c from app.class where id = p_class_id;
  -- Luật quyền (như app.get_class_record): không thấy lớp thì như không có.
  if c.id is null
     or v_scope is null
     or (v_scope = 'CO_SO' and c.branch_id is distinct from app.current_branch_id())
     or (v_scope = 'DUOC_PHAN_CONG' and not app.is_assigned_to_class(c.id)) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lớp này hoặc lớp không tồn tại.');
  end if;
  with f as (
    select ec.id as ec_id, ec.start_date, ec.end_date, ec.end_reason,
           e.id as enrollment_id, e.code as enrollment_code, e.status_code as enrollment_status, e.branch_id as enrollment_branch_id,
           e.delivery_mode_code, st.id as student_id, st.code as student_code, st.full_name
      from app.enrollment_class ec
      join app.enrollment e on e.id = ec.enrollment_id
      join app.student st on st.id = e.student_id
     where ec.class_id = c.id
       and (v_q is null or app.fold_text(st.full_name || ' ' || st.code || ' ' || e.code) like '%' || v_q || '%')
       and (cardinality(v_state) = 0
            or ('DANG_HOC' = any (v_state) and ec.end_date is null)
            or ('DA_ROI' = any (v_state) and ec.end_date is not null))
       and (cardinality(v_delivery) = 0 or e.delivery_mode_code = any (v_delivery))
       and (v_branch is null or e.branch_id = v_branch)
  ),
  page as (
    select f.*, app.enrollment_hours_balance(f.enrollment_id) as hours_left
      from f
     order by case when p_sort = 'start_desc' then f.start_date end desc,
              case when p_sort = 'hours_asc' then app.enrollment_hours_balance(f.enrollment_id) end asc,
              f.full_name, f.ec_id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.ec_id, 'student_id', p.student_id, 'student_code', p.student_code, 'full_name', p.full_name,
             'enrollment_id', p.enrollment_id, 'enrollment_code', p.enrollment_code, 'enrollment_status', p.enrollment_status,
             'branch_code', (select b.code from app.branch b where b.id = p.enrollment_branch_id),
             'delivery_mode_code', p.delivery_mode_code,
             'start_date', p.start_date, 'end_date', p.end_date, 'end_reason', p.end_reason,
             'hours_left', p.hours_left)
             order by case when p_sort = 'start_desc' then p.start_date end desc,
                      case when p_sort = 'hours_asc' then p.hours_left end asc,
                      p.full_name, p.ec_id), '[]'::jsonb))
    into v_result
    from page p;
  return v_result;
end;
$$;

-- app.class_student_group_counts(lớp, bộ lọc, trường nhóm): quyền như list_class_students (xem được lớp). Trường nhóm: state (Đang học, Đã rời), branch (cơ sở phụ trách), delivery (hình thức học).
create or replace function app.class_student_group_counts(p_class_id uuid, p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('CLASS', 'XEM');
  c app.class;
  v_q text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_state text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'state', '[]'::jsonb)));
  v_delivery text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'delivery', '[]'::jsonb)));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  select * into c from app.class where id = p_class_id;
  -- Luật quyền (như list_class_students): không thấy lớp thì như không có.
  if c.id is null
     or v_scope is null
     or (v_scope = 'CO_SO' and c.branch_id is distinct from app.current_branch_id())
     or (v_scope = 'DUOC_PHAN_CONG' and not app.is_assigned_to_class(c.id)) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lớp này hoặc lớp không tồn tại.');
  end if;
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('state', 'branch', 'delivery'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, cơ sở phụ trách, hình thức học).');
  end if;
  with g as (
    select ec.end_date, e.branch_id, e.delivery_mode_code
      from app.enrollment_class ec
      join app.enrollment e on e.id = ec.enrollment_id
      join app.student st on st.id = e.student_id
     where ec.class_id = c.id
       and (v_q is null or app.fold_text(st.full_name || ' ' || st.code || ' ' || e.code) like '%' || v_q || '%')
       and (cardinality(v_state) = 0
            or ('DANG_HOC' = any (v_state) and ec.end_date is null)
            or ('DA_ROI' = any (v_state) and ec.end_date is not null))
       and (cardinality(v_delivery) = 0 or e.delivery_mode_code = any (v_delivery))
       and (v_branch is null or e.branch_id = v_branch)
  ), keyed as (
    select case v_f1 when 'state' then case when g.end_date is null then 'DANG_HOC' else 'DA_ROI' end when 'branch' then g.branch_id::text when 'delivery' then g.delivery_mode_code end as k1,
           case v_f2 when 'state' then case when g.end_date is null then 'DANG_HOC' else 'DA_ROI' end when 'branch' then g.branch_id::text when 'delivery' then g.delivery_mode_code end as k2
      from g
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.class_student_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.class_student_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

create or replace function app.class_student_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'state' then case p_key when 'DANG_HOC' then 'Đang học' when 'DA_ROI' then 'Đã rời' else p_key end
    when p_field = 'branch' then coalesce((select b.code || ' ' || b.name from app.branch b where b.id = p_key::uuid), p_key)
    when p_field = 'delivery' then coalesce((select c.name from app.catalog_item c where c.catalog_code = 'STUDY_MODE' and c.code = p_key), p_key)
    else p_key end;
$$;


-- ===== GD-06 Hàng chờ xếp lớp =====
-- app.enrollment_queue_group_counts(bộ lọc, trường nhóm): quyền như enrollment_queue (Ghi danh · Sửa, toàn hệ thống hoặc cơ sở). Bộ lọc giống enrollment_queue: branch_id, delivery_mode_code, q.
-- Trường nhóm (anh chốt 21/11: GD-06 theo canvas): reason (Lý do chờ: luôn «Chưa có lớp» theo R-GD-05 nên chỉ một nhóm), delivery (Hình thức học).
create or replace function app.enrollment_queue_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ENROLLMENT', 'SUA');
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_mode text := nullif(p_filters ->> 'delivery_mode_code', '');
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem hàng chờ xếp lớp.');
  end if;
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('reason', 'delivery'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (lý do chờ, hình thức học).');
  end if;
  with g as not materialized (
    select e.delivery_mode_code
      from app.enrollment e join app.student st on st.id = e.student_id
     where e.status_code = 'CHO_XEP_LOP'
       and (v_scope = 'TOAN_HE_THONG' or e.branch_id = v_my_branch)
       and (v_branch is null or e.branch_id = v_branch)
       and (v_mode is null or e.delivery_mode_code = v_mode)
       and (v_q is null or e.search_text like '%' || v_q || '%' or app.fold_text(st.full_name) like '%' || v_q || '%')
  ), keyed as (
    select case v_f1 when 'reason' then 'CHUA_CO_LOP' when 'delivery' then g.delivery_mode_code end as k1,
           case v_f2 when 'reason' then 'CHUA_CO_LOP' when 'delivery' then g.delivery_mode_code end as k2
      from g
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.queue_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.queue_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

create or replace function app.queue_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'reason' then 'Chưa có lớp'
    when p_field = 'delivery' then coalesce((select c.name from app.catalog_item c where c.catalog_code = 'STUDY_MODE' and c.code = p_key), p_key)
    else p_key end;
$$;


-- ===== BUOI-12 Buổi chưa Done =====
-- session_pending_list: như migration 123, thêm bộ lọc teacher_id để mở một nhóm.
create or replace function app.session_pending_list(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.session_read_scope();
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_kind text := nullif(p_filters ->> 'kind', '');
  -- C96: giáo viên phụ trách buổi (canvas BUOI12); dùng để mở một nhóm Group By.
  v_teacher uuid := nullif(p_filters ->> 'teacher_id', '')::uuid;
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_result jsonb;
begin
  with f as not materialized (
    select s.*, c.code as class_code, c.subject_catalog, c.subject_code, c.search_text,
           ((s.session_date + s.end_time)::timestamp at time zone 'Asia/Ho_Chi_Minh')
             + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', s.branch_id)::integer) as deadline
      from app.class_session s join app.class c on c.id = s.class_id
     where s.status_code = 'DA_CHOT'
       and ((s.session_date + s.end_time)::timestamp at time zone 'Asia/Ho_Chi_Minh') <= now()
       and (v_scope = 'TOAN_HE_THONG' or s.branch_id = v_my_branch)
       and (v_branch is null or s.branch_id = v_branch)
       and (v_teacher is null or s.teacher_id = v_teacher)
       and (v_q is null or c.search_text like '%' || v_q || '%')
  ), g as (
    select * from f where v_kind is null or (v_kind = 'QUA_HAN' and f.deadline < now()) or (v_kind = 'CON_HAN' and f.deadline >= now())
  ), page as (
    select * from g order by g.deadline, g.id limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from g),
           'rows', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'id', p.id, 'class_code', p.class_code, 'subject_name', sub.name, 'session_no', p.session_no, 'session_date', p.session_date,
                      'start_time', to_char(p.start_time, 'HH24:MI'), 'teacher_name', t.display_name, 'deadline', p.deadline,
                      'minutes_left', floor(extract(epoch from (p.deadline - now())) / 60)::integer, -- allow-number: 60 giây một phút
                      'reason', app.session_pending_reason(p.id)) order by p.deadline, p.id)
               from page p
               join app.catalog_item sub on sub.catalog_code = p.subject_catalog and sub.code = p.subject_code
               left join app.user_account t on t.id = p.teacher_id), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

-- app.session_pending_group_counts(bộ lọc, trường nhóm): quyền như session_pending_list (session_read_scope). Trường nhóm: teacher (giáo viên phụ trách; chưa có người thì nhóm «Chưa có»). Bộ lọc giống session_pending_list: branch_id, kind, q, teacher_id.
-- app.session_pending_group_counts(bộ lọc, trường nhóm): quyền như session_pending_list (session_read_scope). Trường nhóm: teacher (giáo viên phụ trách; chưa có người thì nhóm «Chưa có»). Bộ lọc giống session_pending_list: branch_id, kind, q, teacher_id.
create or replace function app.session_pending_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.session_read_scope();
  v_my_branch uuid := app.current_branch_id();
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_kind text := nullif(p_filters ->> 'kind', '');
  v_teacher uuid := nullif(p_filters ->> 'teacher_id', '')::uuid;
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('teacher'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (giáo viên).');
  end if;
  with f as not materialized (
    select s.teacher_id,
           ((s.session_date + s.end_time)::timestamp at time zone 'Asia/Ho_Chi_Minh')
             + make_interval(hours => app.get_setting_int('teacher_session_complete_hours', s.branch_id)::integer) as deadline
      from app.class_session s join app.class c on c.id = s.class_id
     where s.status_code = 'DA_CHOT'
       and ((s.session_date + s.end_time)::timestamp at time zone 'Asia/Ho_Chi_Minh') <= now()
       and (v_scope = 'TOAN_HE_THONG' or s.branch_id = v_my_branch)
       and (v_branch is null or s.branch_id = v_branch)
       and (v_teacher is null or s.teacher_id = v_teacher)
       and (v_q is null or c.search_text like '%' || v_q || '%')
  ), g as (
    select * from f where v_kind is null or (v_kind = 'QUA_HAN' and f.deadline < now()) or (v_kind = 'CON_HAN' and f.deadline >= now())
  ), keyed as (
    select case v_f1 when 'teacher' then g.teacher_id::text end as k1,
           case v_f2 when 'teacher' then g.teacher_id::text end as k2
      from g
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', coalesce((select u.display_name from app.user_account u where u.id = nullif(g.k1, '')::uuid), 'Chưa có'),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else coalesce((select u.display_name from app.user_account u where u.id = nullif(g.k2, '')::uuid), 'Chưa có') end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;


-- ===== BUOI-11 Điểm danh vận hành trong ngày =====
-- app.absent_today_group_counts(bộ lọc, trường nhóm): quyền như absent_today_list (Điểm danh · Sửa, toàn hệ thống hoặc cơ sở). Trường nhóm: status (Vắng, Chưa tới); bộ lọc giống absent_today_list: branch_id, kind, q. Mở một nhóm dùng bộ lọc kind có sẵn.
create or replace function app.absent_today_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ATTENDANCE', 'SUA');
  v_my_branch uuid := app.current_branch_id();
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date; -- Luật R-HT-07: ngày theo giờ Việt Nam.
  v_now_local time := (now() at time zone 'Asia/Ho_Chi_Minh')::time;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_kind text := nullif(p_filters ->> 'kind', '');
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền ghi điểm danh vận hành.');
  end if;
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng).');
  end if;
  with f as not materialized (
    select case when coalesce(sa.teacher_status_code, sa.ops_status_code) in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP') then 'VANG' else 'CHUA_DEN' end as kind
      from app.session_attendance sa
      join app.class_session s on s.id = sa.session_id
      join app.class c on c.id = s.class_id
      join app.student st on st.id = sa.student_id
     where s.session_date = v_today and s.status_code = 'DA_CHOT' and sa.is_active
       and (v_scope = 'TOAN_HE_THONG' or s.branch_id = v_my_branch)
       and (v_branch is null or s.branch_id = v_branch)
       and (v_q is null or app.fold_text(st.full_name) like '%' || v_q || '%' or app.fold_text(st.code) like '%' || v_q || '%' or c.search_text like '%' || v_q || '%')
       and (coalesce(sa.teacher_status_code, sa.ops_status_code) in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')
            or (coalesce(sa.teacher_status_code, sa.ops_status_code) is null and s.start_time <= v_now_local))
  ), g as (
    select * from f where v_kind is null or f.kind = v_kind
  ), keyed as (
    select case v_f1 when 'status' then g.kind end as k1,
           case v_f2 when 'status' then g.kind end as k2
      from g
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', case g.k1 when 'VANG' then 'Vắng' when 'CHUA_DEN' then 'Chưa tới' else g.k1 end,
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else case g.k2 when 'VANG' then 'Vắng' when 'CHUA_DEN' then 'Chưa tới' else g.k2 end end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;


-- ===== GD-07 Sắp hết giờ =====
-- app.expiring_enrollment_rows(lớp, phạm vi): HÀM TRONG, MỘT nơi định nghĩa «sắp hết giờ, hết hạn gói» (R-GD-07, anh chốt 20/11 theo canvas GD07) cho cả danh sách và đếm nhóm.
-- Trả mỗi cặp (học sinh, lớp) có tình trạng cảnh báo: status_code HET_GIO, SAP_HET_GIO, SAP_HET_HAN_GOI, QUA_HAN_CON_GIO. Không kiểm quyền (người gọi kiểm); lọc cơ sở theo p_scope và công tắc SAP_HET_GIO từng cơ sở.
create or replace function app.expiring_enrollment_rows(p_class uuid, p_scope text)
returns table (student_id uuid, class_id uuid, branch_id uuid, hours_left numeric, enrollment_codes text[], projected_end date, validity_date date, status_code text)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  return query
  with base as (
    -- Mỗi ghi danh còn hiệu lực gắn với lớp hiện tại (dòng ghi danh vào lớp chưa kết thúc), kèm giờ còn của chính ghi danh đó.
    select e.student_id, ec.class_id, e.id as enrollment_id, e.code as enrollment_code, e.branch_id, ec.start_date,
           coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = e.id), 0) as hours_left
      from app.enrollment e
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
     where e.status_code in ('DA_XEP_LOP', 'DANG_HOC')
       and (p_scope = 'TOAN_HE_THONG' or e.branch_id = app.current_branch_id())
       and app.feature_enabled('SAP_HET_GIO', e.branch_id)
       and (p_class is null or ec.class_id = p_class)
  ), grp as (
    select b.student_id, b.class_id, min(b.branch_id::text)::uuid as branch_id,
           sum(b.hours_left) as hours_left,
           array_agg(b.enrollment_code order by b.enrollment_code) as enrollment_codes,
           max(b.start_date) as last_start
      from base b group by b.student_id, b.class_id
  ), calc as (
    select g.*,
           coalesce((select sum(extract(epoch from (s.end_time - s.start_time)) / 3600.0 / s.repeat_weeks) -- allow-number: 3600 giây một giờ
                       from app.class_slot s where s.class_id = g.class_id and s.is_active), 0) as weekly_hours,
           (g.last_start + make_interval(months => app.get_setting_int('package_default_validity_months', g.branch_id)::integer))::date as validity_date
      from grp g
  ), est as (
    select c.*,
           case when c.hours_left > 0 and c.weekly_hours > 0
                then v_today + ceil(c.hours_left / c.weekly_hours * 7)::integer end as projected_end -- allow-number: 7 ngày một tuần
      from calc c
  ), tagged as (
    select e.*,
           case when e.hours_left <= 0 then 'HET_GIO'
                when e.hours_left <= app.get_setting_numeric('upsale_hours_left_threshold', e.branch_id)
                  or (e.projected_end is not null and e.projected_end - v_today <= app.get_setting_int('upsale_days_left_threshold', e.branch_id)) then 'SAP_HET_GIO'
                -- Anh Trường chốt 20/11 (theo canvas GD07): «Sắp hết hạn gói» khi giờ còn nhiều nhưng hạn gói (dự báo) còn trong ngưỡng ngày; chỉ để dự báo, KHÔNG chặn gì (R-GD-07).
                when e.validity_date >= v_today
                     and e.validity_date - v_today <= app.get_setting_int('upsale_days_left_threshold', e.branch_id) then 'SAP_HET_HAN_GOI'
                when e.validity_date < v_today then 'QUA_HAN_CON_GIO' end as status_code
      from est e

  )
  select t.student_id, t.class_id, t.branch_id, t.hours_left, t.enrollment_codes, t.projected_end, t.validity_date, t.status_code
    from tagged t where t.status_code is not null;
end;
$$;
revoke execute on function app.expiring_enrollment_rows(uuid, text) from public, anon, authenticated;

-- list_expiring_enrollments: như migration 590; phần tính tình trạng chuyển sang expiring_enrollment_rows (dùng chung với đếm nhóm), kết quả không đổi.
create or replace function app.list_expiring_enrollments(p_filters jsonb default '{}'::jsonb, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ENROLLMENT', 'XEM');
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_status text[] := case when jsonb_typeof(p_filters -> 'status') = 'array'
                          then array(select jsonb_array_elements_text(p_filters -> 'status')) end;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_search text := nullif(btrim(coalesce(p_filters ->> 'search', '')), '');
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_total bigint;
  v_rows jsonb;
begin
  if v_scope is null or v_scope = 'DUOC_PHAN_CONG' then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách sắp hết giờ.');
  end if;
  -- Cờ theo cơ sở: người có phạm vi cơ sở bị chặn rõ ràng khi tắt; Admin (toàn hệ thống) chỉ thấy các cơ sở đã bật (điều kiện ở base).
  if v_scope <> 'TOAN_HE_THONG' then
    perform app.require_feature('SAP_HET_GIO', app.current_branch_id());
  end if;
  with t as (
    select * from app.expiring_enrollment_rows(v_class, v_scope)
  ), f as (
    select t.* from t
      join app.student st on st.id = t.student_id
      join app.class c on c.id = t.class_id
     where t.status_code is not null
       and (v_status is null or t.status_code = any (v_status))
       and (v_search is null or st.full_name ilike '%' || v_search || '%' or c.code ilike '%' || v_search || '%')
  ), page as (
    select * from f order by projected_end nulls first, student_id limit v_limit offset v_offset
  )
  select (select count(*) from f),
         coalesce(jsonb_agg(jsonb_build_object(
           'student_id', p.student_id, 'student_name', st.full_name, 'class_id', p.class_id, 'class_code', c.code,
           'enrollment_codes', to_jsonb(p.enrollment_codes), 'hours_left', p.hours_left,
           'projected_end', p.projected_end, 'validity_date', p.validity_date, 'status_code', p.status_code,
           'upsale_id', (select u.id from app.upsale_ticket u where u.student_id = p.student_id and u.class_id = p.class_id and u.stage_code not in ('L5', 'L8')),
           'upsale_code', (select u.code from app.upsale_ticket u where u.student_id = p.student_id and u.class_id = p.class_id and u.stage_code not in ('L5', 'L8')))
           order by p.projected_end nulls first, p.student_id), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.student st on st.id = p.student_id join app.class c on c.id = p.class_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.expiring_group_counts(bộ lọc, trường nhóm): quyền như list_expiring_enrollments (Ghi danh · Xem, không phải phạm vi được phân công; công tắc SAP_HET_GIO). Trường nhóm: status (Hết giờ, Sắp hết giờ, Sắp hết hạn gói, Quá hạn gói còn giờ).
-- Bộ lọc giống list_expiring_enrollments: status (mảng), class_id, search.
create or replace function app.expiring_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ENROLLMENT', 'XEM');
  v_status text[] := case when jsonb_typeof(p_filters -> 'status') = 'array'
                          then array(select jsonb_array_elements_text(p_filters -> 'status')) end;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_search text := nullif(btrim(coalesce(p_filters ->> 'search', '')), '');
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null or v_scope = 'DUOC_PHAN_CONG' then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem danh sách sắp hết giờ.');
  end if;
  if v_scope <> 'TOAN_HE_THONG' then
    perform app.require_feature('SAP_HET_GIO', app.current_branch_id());
  end if;
  -- Luật Đ35: chỉ nhóm theo trường cho phép, tối đa hai cấp, hai cấp khác nhau.
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng).');
  end if;
  with g as (
    select t.status_code
      from app.expiring_enrollment_rows(v_class, v_scope) t
      join app.student st on st.id = t.student_id
      join app.class c on c.id = t.class_id
     where (v_status is null or t.status_code = any (v_status))
       and (v_search is null or st.full_name ilike '%' || v_search || '%' or c.code ilike '%' || v_search || '%')
  ), keyed as (
    select case v_f1 when 'status' then g.status_code end as k1,
           case v_f2 when 'status' then g.status_code end as k2
      from g
  ),
  grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(g.k1, ''), 'l1', app.expiring_group_label(v_f1, g.k1),
             'k2', case when v_f2 is null then null else coalesce(g.k2, '') end,
             'l2', case when v_f2 is null then null else app.expiring_group_label(v_f2, g.k2) end,
             'count', g.n) order by g.k1 nulls first, g.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped g;
  return v_result;
end;
$$;

create or replace function app.expiring_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(p_key, '') = '' then 'Chưa có'
    when p_field = 'status' then case p_key when 'HET_GIO' then 'Hết giờ' when 'SAP_HET_GIO' then 'Sắp hết giờ' when 'SAP_HET_HAN_GOI' then 'Sắp hết hạn gói' when 'QUA_HAN_CON_GIO' then 'Quá hạn gói, còn giờ' else p_key end
    else p_key end;
$$;

revoke execute on function app.student_group_label(text, text), app.class_student_group_label(text, text), app.queue_group_label(text, text), app.expiring_group_label(text, text) from public, anon, authenticated;
revoke execute on function app.student_group_counts(jsonb, text[]), app.class_student_group_counts(uuid, jsonb, text[]), app.enrollment_queue_group_counts(jsonb, text[]),
  app.expiring_group_counts(jsonb, text[]), app.session_pending_group_counts(jsonb, text[]), app.absent_today_group_counts(jsonb, text[]) from public, anon;
grant execute on function app.student_group_counts(jsonb, text[]), app.class_student_group_counts(uuid, jsonb, text[]), app.enrollment_queue_group_counts(jsonb, text[]),
  app.expiring_group_counts(jsonb, text[]), app.session_pending_group_counts(jsonb, text[]), app.absent_today_group_counts(jsonb, text[]) to authenticated;
select set_config('hmt.migration', '', false);
