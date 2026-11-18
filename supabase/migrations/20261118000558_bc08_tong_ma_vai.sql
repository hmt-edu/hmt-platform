-- BC-08 giao diện (Code F, 18/11/2026; thẻ F17): bổ sung cho app.report_teacher_late (migration 554) mã người, vai (giáo viên hay trợ giảng) và số tổng toàn tháng
-- (số buổi trễ, giờ trễ, số người), vì khung BC08 hiện Mã, nhãn Trợ giảng và ba thẻ tổng. `total` vẫn là số dòng (người × cơ sở) để phân trang; `totals.people` là số NGƯỜI (dạy nhiều cơ sở đếm một lần). Chỉ đọc.
select set_config('hmt.migration', 'on', false);

create or replace function app.report_teacher_late(p_month date default null, p_branch_id uuid default null, p_limit integer default null, p_offset integer default 0)
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
  v_total bigint;
  v_rows jsonb;
  v_totals jsonb;
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
  with per as (
    -- Mỗi buổi Done trong tháng (theo ngày buổi) tính cho giáo viên và trợ giảng của buổi (xem ghi chú lệch R-GV-09 ở đầu tệp).
    select p.user_id, s.branch_id, s.completion_late, s.completion_late_hours
      from app.class_session s
      cross join lateral (values (s.teacher_id), (s.assistant_id)) as p (user_id)
     where p.user_id is not null
       and s.status_code = 'DONE'
       and s.session_date >= v_first and s.session_date < v_next
       and (v_branch is null or s.branch_id = v_branch)
  ), agg as (
    select user_id, branch_id, count(*) as done_sessions,
           count(*) filter (where completion_late) as late_sessions,
           coalesce(sum(completion_late_hours) filter (where completion_late), 0) as late_hours
      from per group by user_id, branch_id
  ), late as (
    select a.*, app.staff_display_name(a.user_id) as name, b.code as branch_code, u.staff_code,
           case when exists (select from app.user_role r where r.user_id = a.user_id and r.role_code = 'TA' and r.is_active) then 'TRO_GIANG' else 'GIAO_VIEN' end as role
      from agg a join app.branch b on b.id = a.branch_id join app.user_account u on u.id = a.user_id
     where a.late_sessions > 0 -- CHỈ người có buổi trễ
  )
  select (select count(*) from late),
         jsonb_build_object('people', (select count(distinct user_id) from late), 'late_sessions', coalesce((select sum(late_sessions) from late), 0), 'late_hours', coalesce((select sum(late_hours) from late), 0)),
         coalesce((select jsonb_agg(jsonb_build_object('user_id', x.user_id, 'code', x.staff_code, 'role', x.role, 'name', x.name, 'branch_code', x.branch_code, 'late_sessions', x.late_sessions,
                                                       'late_hours', x.late_hours, 'done_sessions', x.done_sessions)
                                    order by x.late_hours desc, x.late_sessions desc, x.name, x.user_id)
                     from (select * from late order by late_hours desc, late_sessions desc, name, user_id
                            limit v_limit offset greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb)
    into v_total, v_totals, v_rows;
  return jsonb_build_object('month', v_first, 'total', v_total, 'totals', v_totals, 'rows', v_rows);
end;
$$;

revoke execute on function app.report_teacher_late(date, uuid, integer, integer) from public, anon, authenticated;
grant execute on function app.report_teacher_late(date, uuid, integer, integer) to authenticated;
