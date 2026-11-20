-- Rà security definer (Code F, 20/11/2026), cụm 2: app.list_parents, app.get_parent_record chỉ kiểm "có quyền Xem phụ huynh" (bất kể phạm vi),
-- trong khi chính sách parent_read (migration 422, R-CRM-26) chỉ cho phạm vi Toàn hệ thống và Cơ sở đọc. Người có Xem phụ huynh ở phạm vi hẹp
-- (Của tôi, Được phân công...) gọi hàm security definer vẫn đọc được SĐT, địa chỉ, đơn, phiếu thu của mọi phụ huynh.
-- Sửa: hai hàm chỉ chạy khi phạm vi Xem là Toàn hệ thống hoặc Cơ sở (khớp RLS). Thân hàm giữ nguyên migration 117. Quyền gọi giữ nguyên.

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
  -- Luật R-CRM-26 và chính sách parent_read (migration 422): hồ sơ phụ huynh dùng chung cho Toàn hệ thống và Cơ sở; phạm vi hẹp hơn không đọc.
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
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
  -- Luật R-CRM-26 và chính sách parent_read (migration 422): chỉ phạm vi Toàn hệ thống, Cơ sở đọc được hồ sơ phụ huynh.
  if coalesce(app.permission_scope('PARENT', 'XEM'), '') not in ('TOAN_HE_THONG', 'CO_SO') then
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
