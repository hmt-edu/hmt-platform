-- GD-07 Sắp hết giờ: thêm tình trạng «Sắp hết hạn gói» (SAP_HET_HAN_GOI) theo canvas 9933 GD07 (anh Trường chốt 20/11, Chat giao). Giờ còn nhiều (không Hết giờ, không Sắp hết giờ)
-- nhưng hạn gói (dự báo) còn trong upsale_days_left_threshold ngày kể từ hôm nay. Chỉ để dự báo và báo cáo, KHÔNG chặn gì: quá hạn gói mà còn giờ vẫn học (R-GD-07).
-- Thân hàm giữ nguyên bản 561, chỉ thêm một nhánh ở bước gắn tình trạng. Chỉ đọc, quyền giữ nguyên. Không tham số mới, không chỉ mục mới.
select set_config('hmt.migration', 'on', false);

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
  with base as (
    -- Mỗi ghi danh còn hiệu lực gắn với lớp hiện tại (dòng ghi danh vào lớp chưa kết thúc), kèm giờ còn của chính ghi danh đó.
    select e.student_id, ec.class_id, e.id as enrollment_id, e.code as enrollment_code, e.branch_id, ec.start_date,
           coalesce((select sum(h.hours) from app.hour_ledger h where h.enrollment_id = e.id), 0) as hours_left
      from app.enrollment e
      join app.enrollment_class ec on ec.enrollment_id = e.id and ec.end_date is null
     where e.status_code in ('DA_XEP_LOP', 'DANG_HOC')
       and (v_scope = 'TOAN_HE_THONG' or e.branch_id = app.current_branch_id())
       and app.feature_enabled('SAP_HET_GIO', e.branch_id)
       and (v_class is null or ec.class_id = v_class)
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
  ), f as (
    select t.* from tagged t
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
