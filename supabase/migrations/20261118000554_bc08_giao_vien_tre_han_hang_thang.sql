-- BC-08 «Giáo viên trễ hạn hằng tháng» PHẦN DB (Code F, 18/11/2026; thẻ F9). Mức CAO (báo cáo quyền theo cơ sở). Chỉ đọc, không bảng mới, không đổi hàm cũ.
-- Luật R-GV-05, R-GV-06: hệ thống đã đóng dấu Đúng hạn/Trễ hạn và số giờ trễ lúc Done (migration 135); giai đoạn đầu CHỈ báo cáo số buổi trễ, tổng giờ trễ của từng
-- giáo viên hoặc trợ giảng, KHÔNG tính vi phạm. R-GV-14: tháng theo NGÀY BUỔI DIỄN RA. R-BC-01: báo cáo này nằm trong app.
-- LỆCH CẦN CHAT CHỐT: R-GV-09 ghi «báo cáo trễ tính cho người lưu mục cuối cùng», nhưng DB chưa lưu người đóng dấu (migration 135 chỉ có completion_stamped_at,
-- completion_late, completion_late_hours). Bản này tính cho giáo viên VÀ trợ giảng của buổi, cùng cách GV-16 (app.teacher_my_hours) để số khớp màn «Giờ dạy của tôi».
-- Muốn đúng R-GV-09 cần thêm cột người đóng dấu ở app.mark_session_done (lane Code A/E).
-- Ai gọi: quyền Báo cáo · Xem. Toàn hệ thống: mọi cơ sở (hoặc chọn một); phạm vi hẹp hơn bị khoá vào cơ sở của mình.
select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- app.report_teacher_late(tháng, cơ sở, số dòng, bỏ qua): kết quả {month, total, rows[]}, mỗi dòng một giáo viên hoặc trợ giảng CÓ buổi trễ:
-- {user_id, name, branch_code, late_sessions, late_hours, done_sessions}. Xếp số giờ trễ giảm dần. Số dòng mặc định list_page_size_default, tối đa list_page_size_max.
-- Chỉ tính buổi Done có dấu trễ (completion_late). Buổi Done trước migration 135 không có dấu nên không tính.
-- ---------------------------------------------------------------------------
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
    select a.*, app.staff_display_name(a.user_id) as name, b.code as branch_code
      from agg a join app.branch b on b.id = a.branch_id
     where a.late_sessions > 0 -- CHỈ người có buổi trễ
  )
  select (select count(*) from late),
         coalesce((select jsonb_agg(jsonb_build_object('user_id', x.user_id, 'name', x.name, 'branch_code', x.branch_code, 'late_sessions', x.late_sessions,
                                                       'late_hours', x.late_hours, 'done_sessions', x.done_sessions)
                                    order by x.late_hours desc, x.late_sessions desc, x.name, x.user_id)
                     from (select * from late order by late_hours desc, late_sessions desc, name, user_id
                            limit v_limit offset greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('month', v_first, 'total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function app.report_teacher_late(date, uuid, integer, integer) from public, anon, authenticated;
grant execute on function app.report_teacher_late(date, uuid, integer, integer) to authenticated;
