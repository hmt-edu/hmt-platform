-- KHO dòng 17 (Tester 2, F65 docs/nghiep-vu/doi-chieu-group-by.md): Group By ở máy chủ cho danh sách Lớp (LOP-01, canvas 9933: nút Group By).
-- app.class_group_counts(bộ lọc, trường nhóm): đếm số lớp theo MỘT hoặc HAI trường (khác nhau), không tải cả bảng; bộ lọc và phạm vi quyền GIỐNG app.list_classes (migration 116).
-- p_fields: subject, grade, type, branch, status, operating. Kết quả {total, groups: [{k1, l1, k2, l2, count}]}; chỗ rỗng là «Chưa có». Mở một nhóm thì giao diện gọi list_classes với bộ lọc của nhóm.
-- Không thêm chỉ mục mới: đếm trên cùng tập lớp mà list_classes đã quét (cột nhóm đều là cột của app.class đã có chỉ mục theo cơ sở, môn, khối ở migration 100).

create or replace function app.class_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when p_key is null or p_key = '' then null
           when p_field = 'subject' then (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = p_key)
           when p_field = 'grade' then (select ci.name from app.catalog_item ci where ci.catalog_code = 'GRADE' and ci.code = p_key)
           when p_field = 'type' then (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_TYPE' and ci.code = p_key)
           when p_field = 'status' then (select ci.name from app.catalog_item ci where ci.catalog_code = 'CLASS_STATUS' and ci.code = p_key)
           when p_field = 'branch' then (select b.code || ' ' || b.name from app.branch b where b.id = p_key::uuid)
           when p_field = 'operating' then case p_key when 'CHUA_KHAI_GIANG' then 'Chưa khai giảng' when 'DANG_HOC' then 'Đang học' when 'DA_KET_THUC' then 'Đã kết thúc' end
         end;
$$;
revoke execute on function app.class_group_label(text, text) from public, anon, authenticated;

create or replace function app.class_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('CLASS', 'XEM');
  v_my_branch uuid := app.current_branch_id();
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_operating text[] := array(select jsonb_array_elements_text(p_filters -> 'operating'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_subject text := nullif(p_filters ->> 'subject_code', '');
  v_grade text := nullif(p_filters ->> 'grade_code', '');
  v_type text := nullif(p_filters ->> 'class_type_code', '');
  v_search text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lớp học.');
  end if;
  -- Luật: chỉ nhóm theo các trường cho phép, tối đa hai cấp, hai cấp khác nhau (Group By K1_nhom).
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('subject', 'grade', 'type', 'branch', 'status', 'operating'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (môn, khối, phân loại, cơ sở, tình trạng duyệt, vận hành).');
  end if;
  with f as not materialized (
    select c.*, app.class_operating_status(c.id) as operating_status
      from app.class c
     where (v_scope = 'TOAN_HE_THONG' or (v_scope = 'CO_SO' and c.branch_id = v_my_branch)
            or (v_scope = 'DUOC_PHAN_CONG' and app.is_assigned_to_class(c.id)))
       and (cardinality(v_status) = 0 or c.status_code = any (v_status))
       and (v_branch is null or c.branch_id = v_branch)
       and (v_subject is null or c.subject_code = v_subject)
       and (v_grade is null or c.grade_code = v_grade)
       and (v_type is null or c.class_type_code = v_type)
       and (v_search is null or c.search_text like '%' || v_search || '%')
  ), g as (
    select * from f where cardinality(v_operating) = 0 or f.operating_status = any (v_operating)
  ), keyed as (
    select case v_f1 when 'subject' then g.subject_code when 'grade' then g.grade_code when 'type' then g.class_type_code
                     when 'branch' then g.branch_id::text when 'status' then g.status_code when 'operating' then g.operating_status end as k1,
           case v_f2 when 'subject' then g.subject_code when 'grade' then g.grade_code when 'type' then g.class_type_code
                     when 'branch' then g.branch_id::text when 'status' then g.status_code when 'operating' then g.operating_status end as k2
      from g
  ), grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(x.k1, ''), 'l1', app.class_group_label(v_f1, x.k1),
             'k2', case when v_f2 is null then null else coalesce(x.k2, '') end,
             'l2', case when v_f2 is null then null else app.class_group_label(v_f2, x.k2) end,
             'count', x.n) order by x.k1 nulls first, x.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped x;
  return v_result;
end;
$$;
revoke execute on function app.class_group_counts(jsonb, text[]) from public, anon;
grant execute on function app.class_group_counts(jsonb, text[]) to authenticated;
