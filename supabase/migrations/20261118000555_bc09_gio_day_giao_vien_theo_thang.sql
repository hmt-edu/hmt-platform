-- BC-09 «Giờ dạy giáo viên» PHẦN ĐỌC (Code F, 18/11/2026; thẻ F10). Mức CAO (báo cáo căn cứ lương, quyền theo cơ sở). Chỉ đọc, không bảng mới.
-- Luật R-GV-14: giờ dạy tính lương = buổi Done, mọi loại buổi thực dạy (Chính, Củng cố, Học bù, Học bổ trợ), theo thời lượng buổi, tính cho người dạy thật,
-- cả giáo viên và trợ giảng; buổi huỷ (kể cả huỷ có tính phí) không tính; tháng theo NGÀY BUỔI DIỄN RA. R-BUOI-05: học bổ trợ không trừ giờ học sinh nhưng vẫn tính giờ dạy.
-- DỪNG Ở PHẦN ĐỌC: «Chốt tháng» (cả hệ thống một lần, khoá, không mở lại) CHƯA làm; cần luật chi tiết và bảng chốt (anh Trường chốt 18/11: chốt cả hệ thống).
-- Ai gọi: quyền Báo cáo · Xem. Toàn hệ thống: mọi cơ sở (hoặc chọn một); phạm vi hẹp hơn bị khoá vào cơ sở của mình.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- app.report_teaching_hours(tháng, cơ sở, số dòng, bỏ qua): kết quả {month, total, totals, rows[]}.
-- totals (toàn bộ tháng, không theo trang): {hours, teachers, assistants, by_type:{CHINH, CUNG_CO, HOC_BU, BO_TRO}}.
-- Mỗi dòng một giáo viên hoặc trợ giảng CÓ giờ dạy: {user_id, code, name, role (GIAO_VIEN hoặc TRO_GIANG), branch_code, hours, by_type:{...}}.
-- Người dạy nhiều cơ sở: tính theo từng cơ sở của buổi (mỗi cặp người, cơ sở một dòng); chọn «tất cả cơ sở» thì cộng các dòng khi hiển thị ở giao diện sau.
-- Số dòng mặc định list_page_size_default, tối đa list_page_size_max; xếp theo mã người dùng.
-- ---------------------------------------------------------------------------
create or replace function app.report_teaching_hours(p_month date default null, p_branch_id uuid default null, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_scope text := app.permission_scope('REPORT', 'XEM');
  v_branch uuid := p_branch_id;
  v_first date := date_trunc('month', coalesce(p_month, (now() at time zone 'Asia/Ho_Chi_Minh')::date))::date;
  v_next date := (date_trunc('month', coalesce(p_month, (now() at time zone 'Asia/Ho_Chi_Minh')::date)) + interval '1 month')::date;
  v_limit integer := least(coalesce(p_limit, app.get_setting_int('list_page_size_default')), app.get_setting_int('list_page_size_max'));
  v_totals jsonb;
  v_total bigint;
  v_rows jsonb;
begin
  -- Luật quyền: phải có quyền Báo cáo · Xem; phạm vi hẹp hơn Toàn hệ thống chỉ xem cơ sở của mình.
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem báo cáo.');
  end if;
  if v_scope <> 'TOAN_HE_THONG' then
    if v_branch is not null and v_branch <> (select app.current_branch_id()) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn chỉ xem được báo cáo của cơ sở mình.');
    end if;
    v_branch := (select app.current_branch_id());
  end if;
  -- Luật R-GV-14: buổi Done trong tháng (theo ngày buổi) cho giáo viên và trợ giảng của buổi, theo thời lượng buổi (app.session_hours); buổi huỷ không tính.
  with agg as materialized (
    select p.user_id, s.branch_id, s.type_code, sum(app.session_hours(s.id)) as hours
      from app.class_session s
      cross join lateral (values (s.teacher_id), (s.assistant_id)) as p (user_id)
     where p.user_id is not null
       and s.status_code = 'DONE'
       and s.session_date >= v_first and s.session_date < v_next
       and (v_branch is null or s.branch_id = v_branch)
     group by p.user_id, s.branch_id, s.type_code
  ), ta as (
    select distinct r.user_id from app.user_role r where r.role_code = 'TA' and r.is_active and r.user_id in (select user_id from agg)
  ), per as (
    select a.user_id, a.branch_id, sum(a.hours) as hours,
           coalesce(sum(a.hours) filter (where a.type_code = 'CHINH'), 0) as h_chinh,
           coalesce(sum(a.hours) filter (where a.type_code = 'CUNG_CO'), 0) as h_cung_co,
           coalesce(sum(a.hours) filter (where a.type_code = 'HOC_BU'), 0) as h_hoc_bu,
           coalesce(sum(a.hours) filter (where a.type_code = 'BO_TRO'), 0) as h_bo_tro
      from agg a group by a.user_id, a.branch_id
  ), named as (
    select p.*, u.staff_code, app.staff_display_name(p.user_id) as name, b.code as branch_code,
           case when p.user_id in (select user_id from ta) then 'TRO_GIANG' else 'GIAO_VIEN' end as role
      from per p join app.user_account u on u.id = p.user_id join app.branch b on b.id = p.branch_id
  )
  select jsonb_build_object(
           'hours', coalesce((select sum(hours) from agg), 0),
           'teachers', (select count(distinct user_id) from agg where user_id not in (select user_id from ta)),
           'assistants', (select count(*) from ta),
           'by_type', jsonb_build_object('CHINH', coalesce((select sum(hours) from agg where type_code = 'CHINH'), 0),
                                         'CUNG_CO', coalesce((select sum(hours) from agg where type_code = 'CUNG_CO'), 0),
                                         'HOC_BU', coalesce((select sum(hours) from agg where type_code = 'HOC_BU'), 0),
                                         'BO_TRO', coalesce((select sum(hours) from agg where type_code = 'BO_TRO'), 0))),
         (select count(*) from named),
         coalesce((select jsonb_agg(jsonb_build_object('user_id', x.user_id, 'code', x.staff_code, 'name', x.name, 'role', x.role, 'branch_code', x.branch_code, 'hours', x.hours,
                                                       'by_type', jsonb_build_object('CHINH', x.h_chinh, 'CUNG_CO', x.h_cung_co, 'HOC_BU', x.h_hoc_bu, 'BO_TRO', x.h_bo_tro))
                                    order by x.staff_code nulls last, x.name, x.user_id, x.branch_code)
                     from (select * from named order by staff_code nulls last, name, user_id, branch_code
                            limit v_limit offset greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb)
    into v_totals, v_total, v_rows;
  return jsonb_build_object('month', v_first, 'total', v_total, 'totals', v_totals, 'rows', v_rows);
end;
$$;

revoke execute on function app.report_teaching_hours(date, uuid, integer, integer) from public, anon, authenticated;
grant execute on function app.report_teaching_hours(date, uuid, integer, integer) to authenticated;
