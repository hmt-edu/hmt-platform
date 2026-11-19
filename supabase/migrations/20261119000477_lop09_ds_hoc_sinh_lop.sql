-- Migration 477 (Code D, 19/11/2026): LOP-09 Học sinh của lớp (danh sách K03, canvas 9933 khung LOP09). Chỉ đọc, không đổi dữ liệu.
-- app.list_class_students(lớp, bộ lọc, sắp xếp, số dòng, bỏ qua): MỌI dòng xếp lớp của lớp (đang học và đã rời), phân trang ở máy chủ.
-- Ai gọi: người xem được lớp (cùng điều kiện app.get_class_record: Xem lớp theo phạm vi; Giáo viên chỉ lớp được phân công).
-- Bộ lọc (jsonb, tuỳ chọn): search (tên, mã học sinh, mã ghi danh), state ('DANG_HOC' = chưa rời lớp, 'DA_ROI' = đã rời; mảng), delivery (mảng hình thức học).
-- Sắp xếp: name_asc (mặc định), start_desc, hours_asc. Kết quả {total, rows[]}; mỗi dòng: mã học sinh, tên, mã ghi danh, cơ sở phụ trách (cơ sở của ghi danh),
-- hình thức học, ngày vào, ngày rời, lý do rời, tình trạng ghi danh, giờ còn. Giáo viên không thấy phụ huynh, SĐT (không có trong kết quả, R-GV-13).
-- Chỉ mục mới enrollment_class_class_idx (class_id, start_date): chỉ mục có sẵn của lớp là chỉ mục từng phần cho dòng đang mở (end_date is null), không phủ dòng đã rời mà màn này cũng liệt kê.
create index if not exists enrollment_class_class_idx on app.enrollment_class (class_id, start_date);

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
revoke execute on function app.list_class_students(uuid, jsonb, text, integer, integer) from public, anon;
grant execute on function app.list_class_students(uuid, jsonb, text, integer, integer) to authenticated;
