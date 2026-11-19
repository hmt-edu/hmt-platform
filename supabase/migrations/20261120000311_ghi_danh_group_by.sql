-- KHO dòng 17 (Group By Ghi danh GD-01, Tester 2 / F65): (1) app.enrollment_list giữ nguyên bản migration 113, chỉ thêm bộ lọc «delivery_mode_code» (hình thức học; giao diện GD-01 đã gửi khoá này nhưng hàm chưa đọc) để mở một nhóm tải đúng dòng;
-- (2) app.enrollment_group_counts(bộ lọc, trường nhóm): đếm ghi danh theo MỘT hoặc HAI trường khác nhau (status, class, delivery, branch), bộ lọc và phạm vi quyền GIỐNG enrollment_list.
-- Kết quả {total, groups: [{k1, l1, k2, l2, count}]}; chỗ rỗng (chưa xếp lớp) là «Chưa có». Không thêm chỉ mục: đếm trên cùng tập ghi danh enrollment_list đã quét.
create or replace function app.enrollment_list(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'code_desc', p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.enrollment_read_scope();
  v_my_branch uuid := app.current_branch_id();
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'status', '[]'::jsonb)));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_student uuid := nullif(p_filters ->> 'student_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_delivery text := nullif(p_filters ->> 'delivery_mode_code', '');
  v_result jsonb;
begin
  -- Luật phạm vi: không phải toàn hệ thống thì chỉ thấy cơ sở của mình.
  with f as not materialized (
    select e.*, st.full_name as student_name, st.code as student_code,
           (select ec.class_id from app.enrollment_class ec where ec.enrollment_id = e.id and ec.end_date is null limit 1) as cur_class_id
      from app.enrollment e
      join app.student st on st.id = e.student_id
     where (v_scope = 'TOAN_HE_THONG' or e.branch_id = v_my_branch)
       and (v_branch is null or e.branch_id = v_branch)
       and (cardinality(v_status) = 0 or e.status_code = any (v_status))
       and (v_student is null or e.student_id = v_student)
       and (v_parent is null or e.parent_id = v_parent)
       and (v_delivery is null or e.delivery_mode_code = v_delivery)
       and (v_q is null or e.search_text like '%' || v_q || '%' or app.fold_text(st.full_name) like '%' || v_q || '%')
  ), g as not materialized (
    select f.*, coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = f.id), 0)::numeric(6, 2) as remaining_hours
      from f where (v_class is null or f.cur_class_id = v_class)
  ), page as (
    select o.* from (
      select g.*, row_number() over (
        order by case p_sort when 'code_asc' then g.code end asc, case p_sort when 'student_asc' then g.student_name end asc,
                 case p_sort when 'student_desc' then g.student_name end desc, case p_sort when 'remaining_asc' then g.remaining_hours end asc,
                 case p_sort when 'remaining_desc' then g.remaining_hours end desc, g.code desc) as ord
        from g) o
     order by o.ord limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from g),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'code', p.code, 'student_id', p.student_id, 'student_name', p.student_name, 'student_code', p.student_code,
             'package_code', pk.code, 'package_name', pk.name, 'delivery_mode_code', p.delivery_mode_code, 'delivery_mode_name', dm.name,
             'class_id', p.cur_class_id, 'class_code', cl.code,
             'granted_hours', (select coalesce(sum(l.hours), 0) from app.hour_ledger l where l.enrollment_id = p.id and l.entry_type in ('CAP_MUA', 'CAP_TANG', 'DAU_KY')),
             'used_hours', (select coalesce(-sum(l.hours), 0) from app.hour_ledger l where l.enrollment_id = p.id and l.entry_type = 'TRU_BUOI'),
             'remaining_hours', p.remaining_hours, 'status_code', p.status_code, 'status_name', sn.name)
             order by p.ord), '[]'::jsonb))
    into v_result
    from page p
    left join app.sales_package pk on pk.id = p.package_id
    left join app.catalog_item dm on dm.catalog_code = 'STUDY_MODE' and dm.code = p.delivery_mode_code
    left join app.class cl on cl.id = p.cur_class_id
    left join app.catalog_item sn on sn.catalog_code = p.status_catalog and sn.code = p.status_code;
  return v_result;
end;
$$;

create or replace function app.enrollment_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when p_key is null or p_key = '' then null
           when p_field = 'status' then (select ci.name from app.catalog_item ci where ci.catalog_code = 'ENROLLMENT_STATUS' and ci.code = p_key)
           when p_field = 'delivery' then (select ci.name from app.catalog_item ci where ci.catalog_code = 'STUDY_MODE' and ci.code = p_key)
           when p_field = 'class' then (select c.code from app.class c where c.id = p_key::uuid)
           when p_field = 'branch' then (select b.code || ' ' || b.name from app.branch b where b.id = p_key::uuid)
         end;
$$;
revoke execute on function app.enrollment_group_label(text, text) from public, anon, authenticated;

create or replace function app.enrollment_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.enrollment_read_scope();
  v_my_branch uuid := app.current_branch_id();
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_status text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'status', '[]'::jsonb)));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_student uuid := nullif(p_filters ->> 'student_id', '')::uuid;
  v_parent uuid := nullif(p_filters ->> 'parent_id', '')::uuid;
  v_delivery text := nullif(p_filters ->> 'delivery_mode_code', '');
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  -- Luật: chỉ nhóm theo các trường cho phép, tối đa hai cấp, hai cấp khác nhau (Group By K1_nhom).
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status', 'class', 'delivery', 'branch'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, lớp, hình thức học, cơ sở).');
  end if;
  with f as not materialized (
    select e.*, (select ec.class_id from app.enrollment_class ec where ec.enrollment_id = e.id and ec.end_date is null limit 1) as cur_class_id
      from app.enrollment e
      join app.student st on st.id = e.student_id
     where (v_scope = 'TOAN_HE_THONG' or e.branch_id = v_my_branch)
       and (v_branch is null or e.branch_id = v_branch)
       and (cardinality(v_status) = 0 or e.status_code = any (v_status))
       and (v_student is null or e.student_id = v_student)
       and (v_parent is null or e.parent_id = v_parent)
       and (v_delivery is null or e.delivery_mode_code = v_delivery)
       and (v_q is null or e.search_text like '%' || v_q || '%' or app.fold_text(st.full_name) like '%' || v_q || '%')
  ), g as (
    select * from f where v_class is null or f.cur_class_id = v_class
  ), keyed as (
    select case v_f1 when 'status' then g.status_code when 'class' then g.cur_class_id::text when 'delivery' then g.delivery_mode_code
                     when 'branch' then g.branch_id::text end as k1,
           case v_f2 when 'status' then g.status_code when 'class' then g.cur_class_id::text when 'delivery' then g.delivery_mode_code
                     when 'branch' then g.branch_id::text end as k2
      from g
  ), grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(x.k1, ''), 'l1', app.enrollment_group_label(v_f1, x.k1),
             'k2', case when v_f2 is null then null else coalesce(x.k2, '') end,
             'l2', case when v_f2 is null then null else app.enrollment_group_label(v_f2, x.k2) end,
             'count', x.n) order by x.k1 nulls first, x.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped x;
  return v_result;
end;
$$;
revoke execute on function app.enrollment_group_counts(jsonb, text[]) from public, anon;
grant execute on function app.enrollment_group_counts(jsonb, text[]) to authenticated;
