-- GD-07 Sắp hết giờ (dự báo, chỉ đọc), ĐỀ XUẤT docs/spec/de-xuat-luat-a.md (Chat 01:00: làm mã sau cờ tắt theo đề xuất, ghi lệch nếu Chat đổi).
-- Luật: R-GD-07 (hạn gói chỉ để dự báo, không chặn gì), R-GD-13 phần ngưỡng (phần tự sinh phiếu đã bị R-V2-25 bỏ nên màn không sinh phiếu), R-TIEN-02 (không có nút tạo tay).
-- Thêm: phân hệ công tắc SAP_HET_GIO (tắt mặc định: không có dòng cờ = tắt), hàm app.list_expiring_enrollments.
select set_config('hmt.migration', 'on', false);
insert into app.catalog_item (catalog_code, code, name, sort_order)
select 'MODULE', 'SAP_HET_GIO', 'Sắp hết giờ (dự báo)', coalesce(max(sort_order), 0) + 1
  from app.catalog_item where catalog_code = 'MODULE'
on conflict (catalog_code, code) do nothing;

-- app.list_expiring_enrollments(bộ lọc, giới hạn, vị trí) -> {total, rows}
-- Mỗi dòng là một (học sinh, lớp) có ghi danh còn hiệu lực (Đã xếp lớp, Đang học; không tính Bảo lưu, Dừng, Hoàn thành, Hoàn phí), còn dòng ghi danh vào lớp chưa kết thúc.
-- Ai gọi: có quyền Ghi danh · Xem (phạm vi cơ sở hoặc toàn hệ thống; giáo viên theo phân công không dùng). Cần phân hệ SAP_HET_GIO bật.
-- Giờ còn = tổng giờ còn của mọi ghi danh còn hiệu lực của em ở lớp (kể cả giờ tặng). Hết giờ dự kiến = hôm nay + giờ còn / giờ học mỗi tuần của lớp (theo khung đang chạy).
-- Hạn gói (dự báo, R-GD-07) = ngày vào lớp + package_default_validity_months, lấy hạn MUỘN nhất khi một lớp có nhiều ghi danh; không chặn gì.
-- Tình trạng gợi ý (không lưu): HET_GIO khi giờ còn <= 0; SAP_HET_GIO khi giờ còn <= upsale_hours_left_threshold hoặc hết giờ dự kiến còn <= upsale_days_left_threshold ngày;
-- QUA_HAN_CON_GIO khi quá hạn gói mà còn giờ (vẫn học bình thường). Chỉ trả các dòng có tình trạng. Bộ lọc: status[], class_id, search (tên em, mã lớp). Phân trang ở máy chủ.
create or replace function app.list_expiring_enrollments(p_filters jsonb default '{}'::jsonb, p_limit integer default 50, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('ENROLLMENT', 'XEM');
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 100); -- allow-number: trần phân trang theo quy ước hiệu năng
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
           coalesce((select sum(extract(epoch from (s.end_time - s.start_time)) / 3600.0 / s.repeat_weeks)
                       from app.class_slot s where s.class_id = g.class_id and s.is_active), 0) as weekly_hours,
           (g.last_start + make_interval(months => app.get_setting_int('package_default_validity_months', g.branch_id)))::date as validity_date
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
           'projected_end', p.projected_end, 'validity_date', p.validity_date, 'status_code', p.status_code)
           order by p.projected_end nulls first, p.student_id), '[]'::jsonb)
    into v_total, v_rows
    from page p join app.student st on st.id = p.student_id join app.class c on c.id = p.class_id;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function app.list_expiring_enrollments(jsonb, integer, integer) from public, anon, authenticated;
grant execute on function app.list_expiring_enrollments(jsonb, integer, integer) to authenticated;
