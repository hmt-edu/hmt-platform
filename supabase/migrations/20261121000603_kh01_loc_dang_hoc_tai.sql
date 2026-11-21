-- KH-01 Phụ huynh: bộ lọc «Đang học tại» (một cơ sở) thay cho Group By «Đang học tại» (Chat chốt phương án A, #460, 21/11/2026).
-- Lý do không Group By: một phụ huynh học ở nhiều cơ sở lọt nhiều nhóm, tổng các nhóm lớn hơn số phụ huynh.
-- app.list_parents và app.parent_group_counts thêm khoá bộ lọc `studying_branch_id` (id cơ sở): phụ huynh có ghi danh Đã xếp lớp hoặc Đang học ở cơ sở đó;
-- hai hàm dùng CÙNG điều kiện để tổng nhóm luôn bằng total của danh sách. Bộ lọc cũ giữ nguyên.
-- Chỉ mục: không thêm; điều kiện `exists` đi qua enrollment_parent_idx (migration 101).
-- Nhân tiện sửa nhất quán quyền: app.parent_group_counts (migration 575) nay chỉ chạy với phạm vi Xem Toàn hệ thống hoặc Cơ sở như list_parents (migration 573), không để lộ số đếm ở phạm vi hẹp hơn.

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
  v_studying uuid := nullif(p_filters ->> 'studying_branch_id', '')::uuid; -- bộ lọc «Đang học tại» (một cơ sở)
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
       -- Luật KH-01 (canvas 9933): «Đang học tại» = có ghi danh Đã xếp lớp hoặc Đang học ở cơ sở đó (cùng nghĩa với cột «Đang học tại»).
       and (v_studying is null or exists (select from app.enrollment se where se.parent_id = p.id and se.branch_id = v_studying
                                           and se.status_code in ('DA_XEP_LOP', 'DANG_HOC')))
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

create or replace function app.parent_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('PARENT', 'XEM');
  v_status text[] := array(select jsonb_array_elements_text(p_filters -> 'status'));
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_search text := nullif(app.fold_text(btrim(coalesce(p_filters ->> 'search', ''))), '');
  v_studying uuid := nullif(p_filters ->> 'studying_branch_id', '')::uuid;
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  -- Luật R-CRM-26 và chính sách parent_read (migration 422, 573): chỉ phạm vi Toàn hệ thống, Cơ sở đọc (cùng điều kiện với list_parents).
  if v_scope is null or v_scope not in ('TOAN_HE_THONG', 'CO_SO') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem phụ huynh.');
  end if;
  -- Luật: chỉ nhóm theo các trường cho phép, tối đa hai cấp, hai cấp khác nhau (Group By K1_nhom).
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('status', 'branch'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (tình trạng, cơ sở tiếp nhận).');
  end if;
  with f as not materialized (
    select p.branch_id,
           exists (select from app.enrollment e where e.parent_id = p.id and e.status_code in ('CHO_XEP_LOP', 'DA_XEP_LOP', 'DANG_HOC')) as studying
      from app.parent p
     where p.record_status = 'DANG_DUNG'
       and (v_branch is null or p.branch_id = v_branch)
       and (v_search is null or p.search_text like '%' || v_search || '%')
       and (v_studying is null or exists (select from app.enrollment se where se.parent_id = p.id and se.branch_id = v_studying
                                           and se.status_code in ('DA_XEP_LOP', 'DANG_HOC')))
  ), g as (
    select * from f
     where cardinality(v_status) = 0
        or ('DANG_HOC' = any (v_status) and f.studying)
        or ('CHUA_DANG_HOC' = any (v_status) and not f.studying)
  ), keyed as (
    select case v_f1 when 'status' then case when g.studying then 'DANG_HOC' else 'CHUA_DANG_HOC' end when 'branch' then g.branch_id::text end as k1,
           case v_f2 when 'status' then case when g.studying then 'DANG_HOC' else 'CHUA_DANG_HOC' end when 'branch' then g.branch_id::text end as k2
      from g
  ), grouped as (select k1, k2, count(*) as n from keyed group by k1, k2), labeled as (
    select x.*,
           case when v_f1 = 'status' then case x.k1 when 'DANG_HOC' then 'Có con đang học' when 'CHUA_DANG_HOC' then 'Chưa có con đang học' end
                else (select b.code || ' ' || b.name from app.branch b where b.id = x.k1::uuid) end as l1,
           case when v_f2 = 'status' then case x.k2 when 'DANG_HOC' then 'Có con đang học' when 'CHUA_DANG_HOC' then 'Chưa có con đang học' end
                when v_f2 = 'branch' then (select b.code || ' ' || b.name from app.branch b where b.id = x.k2::uuid) end as l2
      from grouped x
  )
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(x.k1, ''), 'l1', x.l1,
             'k2', case when v_f2 is null then null else coalesce(x.k2, '') end,
             'l2', case when v_f2 is null then null else x.l2 end,
             'count', x.n) order by x.k1 nulls first, x.k2 nulls first), '[]'::jsonb))
    into v_result
    from labeled x;
  return v_result;
end;
$$;
