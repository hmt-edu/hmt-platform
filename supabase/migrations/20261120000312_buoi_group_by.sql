-- KHO dòng 17 (Group By Buổi học BUOI-01, Tester 2 / F65): (1) app.session_list giữ nguyên bản migration 123, chỉ thêm bộ lọc «type_code» (loại buổi) để mở một nhóm tải đúng dòng;
-- (2) app.session_group_counts(bộ lọc, trường nhóm): đếm buổi theo MỘT hoặc HAI trường khác nhau (date, class, branch, teacher, type, status), bộ lọc và phạm vi quyền GIỐNG session_list.
-- Kết quả {total, groups: [{k1, l1, k2, l2, count}]}; chỗ rỗng (chưa có giáo viên) là «Chưa có». Không thêm chỉ mục mới (đếm trên cùng tập buổi session_list đã quét, có chỉ mục ngày, lớp ở migration 100).
create or replace function app.session_list(
  p_filters jsonb default '{}'::jsonb, p_sort text default 'time_asc', p_limit integer default null, p_offset integer default 0)
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
  v_from date := nullif(p_filters ->> 'date_from', '')::date;
  v_to date := nullif(p_filters ->> 'date_to', '')::date;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_teacher uuid := nullif(p_filters ->> 'teacher_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_type text := nullif(p_filters ->> 'type_code', '');
  v_status text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'status', '[]'::jsonb)));
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_desc boolean := p_sort = 'time_desc';
  v_result jsonb;
begin
  with f as not materialized (
    select s.*
      from app.class_session s
      join app.class c on c.id = s.class_id
     where s.status_code <> 'DA_THAY'
       -- Luật phạm vi: không phải toàn hệ thống thì chỉ thấy cơ sở của mình.
       and (v_scope = 'TOAN_HE_THONG' or s.branch_id = v_my_branch)
       and (v_branch is null or s.branch_id = v_branch)
       and (v_from is null or s.session_date >= v_from)
       and (v_to is null or s.session_date <= v_to)
       and (v_class is null or s.class_id = v_class)
       and (v_teacher is null or s.teacher_id = v_teacher)
       and (v_type is null or s.type_code = v_type)
       and (cardinality(v_status) = 0 or s.status_code = any (v_status))
       and (v_q is null or c.search_text like '%' || v_q || '%')
  ), page as (
    select * from f
     order by case when v_desc then null else f.session_date end asc, case when v_desc then null else f.start_time end asc,
              case when v_desc then f.session_date end desc, case when v_desc then f.start_time end desc, f.id
     limit v_limit offset v_offset
  )
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'id', p.id, 'session_date', p.session_date, 'start_time', to_char(p.start_time, 'HH24:MI'), 'end_time', to_char(p.end_time, 'HH24:MI'),
                      'class_id', c.id, 'class_code', c.code, 'subject_name', sub.name, 'branch_code', b.code, 'session_no', p.session_no,
                      'type_code', p.type_code, 'type_name', ty.name, 'teacher_name', t.display_name, 'room_name', r.name,
                      'status_code', p.status_code, 'status_name', st.name,
                      'note', case when p.status_code = 'DA_CHOT' then app.session_pending_reason(p.id)
                                 when p.status_code in ('HUY_CO_PHI', 'HUY_KHONG_PHI') then
                                   (select ci.name || coalesce(' · ' || p.cancel_note, '') from app.catalog_item ci
                                     where ci.catalog_code = 'SESSION_CANCEL_REASON' and ci.code = p.cancel_reason_code) end)
                    order by case when v_desc then null else p.session_date end asc, case when v_desc then null else p.start_time end asc,
                             case when v_desc then p.session_date end desc, case when v_desc then p.start_time end desc, p.id)
               from page p
               join app.class c on c.id = p.class_id
               join app.branch b on b.id = p.branch_id
               join app.catalog_item sub on sub.catalog_code = c.subject_catalog and sub.code = c.subject_code
               join app.catalog_item ty on ty.catalog_code = p.type_catalog and ty.code = p.type_code
               join app.catalog_item st on st.catalog_code = p.status_catalog and st.code = p.status_code
               left join app.user_account t on t.id = p.teacher_id
               left join app.room r on r.id = p.room_id), '[]'::jsonb))
    into v_result;
  return v_result;
end;
$$;

create or replace function app.session_group_label(p_field text, p_key text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
           when p_key is null or p_key = '' then null
           when p_field = 'date' then to_char(p_key::date, 'DD/MM/YYYY')
           when p_field = 'class' then (select c.code from app.class c where c.id = p_key::uuid)
           when p_field = 'branch' then (select b.code || ' ' || b.name from app.branch b where b.id = p_key::uuid)
           when p_field = 'teacher' then (select u.display_name from app.user_account u where u.id = p_key::uuid)
           when p_field = 'type' then (select ci.name from app.catalog_item ci where ci.catalog_code = 'SESSION_TYPE' and ci.code = p_key)
           when p_field = 'status' then (select ci.name from app.catalog_item ci where ci.catalog_code = 'SESSION_STATUS' and ci.code = p_key)
         end;
$$;
revoke execute on function app.session_group_label(text, text) from public, anon, authenticated;

create or replace function app.session_group_counts(p_filters jsonb default '{}'::jsonb, p_fields text[] default array[]::text[])
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.session_read_scope();
  v_my_branch uuid := app.current_branch_id();
  v_from date := nullif(p_filters ->> 'date_from', '')::date;
  v_to date := nullif(p_filters ->> 'date_to', '')::date;
  v_class uuid := nullif(p_filters ->> 'class_id', '')::uuid;
  v_teacher uuid := nullif(p_filters ->> 'teacher_id', '')::uuid;
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_type text := nullif(p_filters ->> 'type_code', '');
  v_status text[] := array(select jsonb_array_elements_text(coalesce(p_filters -> 'status', '[]'::jsonb)));
  v_q text := app.fold_text(nullif(btrim(coalesce(p_filters ->> 'q', '')), ''));
  v_f1 text := p_fields[1];
  v_f2 text := p_fields[2]; -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
  v_result jsonb;
begin
  -- Luật: chỉ nhóm theo các trường cho phép, tối đa hai cấp, hai cấp khác nhau (Group By K1_nhom).
  if coalesce(cardinality(p_fields), 0) not between 1 and 2 -- allow-number: luật Group By tối đa hai cấp (K1_nhom), không phải số nghiệp vụ cấu hình
     or exists (select from unnest(p_fields) x where x not in ('date', 'class', 'branch', 'teacher', 'type', 'status'))
     or (v_f2 is not null and v_f1 = v_f2) then
    perform app.raise_error('HMT_NHOM_SAI', 'Chọn một hoặc hai trường nhóm khác nhau (ngày, lớp, cơ sở, giáo viên, loại buổi, tình trạng).');
  end if;
  with f as not materialized (
    select s.*
      from app.class_session s
      join app.class c on c.id = s.class_id
     where s.status_code <> 'DA_THAY'
       and (v_scope = 'TOAN_HE_THONG' or s.branch_id = v_my_branch)
       and (v_branch is null or s.branch_id = v_branch)
       and (v_from is null or s.session_date >= v_from)
       and (v_to is null or s.session_date <= v_to)
       and (v_class is null or s.class_id = v_class)
       and (v_teacher is null or s.teacher_id = v_teacher)
       and (v_type is null or s.type_code = v_type)
       and (cardinality(v_status) = 0 or s.status_code = any (v_status))
       and (v_q is null or c.search_text like '%' || v_q || '%')
  ), keyed as (
    select case v_f1 when 'date' then f.session_date::text when 'class' then f.class_id::text when 'branch' then f.branch_id::text
                     when 'teacher' then f.teacher_id::text when 'type' then f.type_code when 'status' then f.status_code end as k1,
           case v_f2 when 'date' then f.session_date::text when 'class' then f.class_id::text when 'branch' then f.branch_id::text
                     when 'teacher' then f.teacher_id::text when 'type' then f.type_code when 'status' then f.status_code end as k2
      from f
  ), grouped as (select k1, k2, count(*) as n from keyed group by k1, k2)
  select jsonb_build_object(
           'total', (select coalesce(sum(n), 0) from grouped),
           'groups', coalesce(jsonb_agg(jsonb_build_object(
             'k1', coalesce(x.k1, ''), 'l1', app.session_group_label(v_f1, x.k1),
             'k2', case when v_f2 is null then null else coalesce(x.k2, '') end,
             'l2', case when v_f2 is null then null else app.session_group_label(v_f2, x.k2) end,
             'count', x.n) order by x.k1 nulls first, x.k2 nulls first), '[]'::jsonb))
    into v_result
    from grouped x;
  return v_result;
end;
$$;
revoke execute on function app.session_group_counts(jsonb, text[]) from public, anon;
grant execute on function app.session_group_counts(jsonb, text[]) to authenticated;
