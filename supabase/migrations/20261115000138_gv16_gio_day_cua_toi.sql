-- GV-16 Giờ dạy của tôi (căn cứ lương): MỘT hàm đọc cho cổng Giáo viên. Chạy sau migration 135 (dấu Đúng hạn/Trễ hạn ở class_session).
-- Luật: R-GV-14 (giờ dạy tính lương: buổi Done, mọi loại buổi thực dạy, theo thời lượng buổi, tính cho người dạy thật, cả giáo viên lẫn trợ giảng;
-- buổi huỷ không tính; tháng tính theo ngày buổi diễn ra), R-GV-05, R-GV-06 (buổi trễ hạn, giờ trễ lấy từ dấu hệ thống đóng lúc Done),
-- R-GV-08 (chỉ buổi của chính mình), R-BUOI-05 (học bổ trợ không trừ giờ học sinh nhưng vẫn tính giờ dạy).
--
-- app.teacher_my_hours(p_month date) -> jsonb
-- Ai được gọi: tài khoản có quyền xem điểm danh (giáo viên, trợ giảng); chỉ thấy buổi của chính mình (auth.uid() là giáo viên hoặc trợ giảng của buổi).
-- Đầu vào: một ngày bất kỳ trong tháng cần xem (để trống là tháng hiện tại, giờ Việt Nam).
-- Kết quả: {month: 'yyyy-mm-01', summary: {sessions, hours, late_sessions, late_hours}, by_type: [{type_code, type_name, sessions, hours}],
--           rows: [{session_id, class_code, subject_name, session_no, session_date, start_time, end_time, type_code, type_name, my_role, hours,
--                   late, late_hours}]}
-- Buổi Done trước migration 135 không có dấu: late là null (không tính vào buổi trễ hạn). Chưa có "chốt tháng" (Kế toán hoặc Admin chốt, R-GV-14; làm ở BC-09):
-- hàm chưa trả trạng thái chốt. Tối đa 200 buổi một tháng (trần hiển thị).
create or replace function app.teacher_my_hours(p_month date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_month date := date_trunc('month', coalesce(p_month, (now() at time zone 'Asia/Ho_Chi_Minh')::date))::date;
  v_next date := (date_trunc('month', coalesce(p_month, (now() at time zone 'Asia/Ho_Chi_Minh')::date)) + interval '1 month')::date;
begin
  if app.permission_scope('ATTENDANCE', 'XEM') is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem giờ dạy.');
  end if;
  return (
    with mine as (
      -- Luật R-GV-14: buổi Done trong tháng (theo ngày buổi diễn ra) mà mình là giáo viên hoặc trợ giảng; buổi huỷ, buổi bị thay không tính.
      select s.id, s.class_id, s.session_no, s.session_date, s.start_time, s.end_time, s.type_code,
             app.session_hours(s.id) as hours, s.completion_late, s.completion_late_hours,
             case when s.teacher_id = auth.uid() then 'GIAO_VIEN' else 'TRO_GIANG' end as my_role
        from app.class_session s
       where auth.uid() in (s.teacher_id, s.assistant_id)
         and s.status_code = 'DONE'
         and s.session_date >= v_month and s.session_date < v_next
    )
    select jsonb_build_object(
      'month', v_month,
      'summary', jsonb_build_object(
        'sessions', (select count(*) from mine),
        'hours', coalesce((select sum(hours) from mine), 0),
        'late_sessions', (select count(*) from mine where completion_late),
        'late_hours', coalesce((select sum(completion_late_hours) from mine where completion_late), 0)),
      'by_type', coalesce((select jsonb_agg(jsonb_build_object('type_code', t.type_code,
                    'type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SESSION_TYPE' and ci.code = t.type_code),
                    'sessions', t.n, 'hours', t.h) order by t.type_code)
                    from (select type_code, count(*) as n, sum(hours) as h from mine group by type_code) t), '[]'::jsonb),
      'rows', coalesce((select jsonb_agg(jsonb_build_object(
                    'session_id', m.id, 'class_code', c.code,
                    'subject_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SUBJECT' and ci.code = c.subject_code),
                    'session_no', m.session_no, 'session_date', m.session_date, 'start_time', m.start_time, 'end_time', m.end_time,
                    'type_code', m.type_code,
                    'type_name', (select ci.name from app.catalog_item ci where ci.catalog_code = 'SESSION_TYPE' and ci.code = m.type_code),
                    'my_role', m.my_role, 'hours', m.hours, 'late', m.completion_late, 'late_hours', m.completion_late_hours)
                    order by m.session_date desc, m.start_time desc, m.id)
                    from (select * from mine order by session_date desc, start_time desc, id
                           limit 200 -- allow-number: trần số buổi hiện trong một tháng (hiển thị, không phải luật nghiệp vụ)
                         ) m join app.class c on c.id = m.class_id), '[]'::jsonb)));
end;
$$;

revoke execute on function app.teacher_my_hours(date) from public, anon, authenticated;
grant execute on function app.teacher_my_hours(date) to authenticated;
