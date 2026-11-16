-- Migration 230 (Code D, 16/11/2026): view báo cáo ticket BC-10 (R-CS-12, AS-07), schema `report`, security_invoker.
-- Mỗi dòng một ticket với cờ đúng hạn và thời gian xử lý; Looker Studio hoặc màn BC-10 tự gộp theo loại, nhóm, cơ sở, tháng, người bị khiếu nại,
-- người phụ trách (Chat chốt 16/11: view trong schema report, đọc qua vai trò sẵn có, không tạo vai trò riêng cho Looker). Chỉ đọc, không bảng mới.
-- Đúng hạn phản hồi: phản hồi đầu trước hạn phản hồi đã chụp lúc tạo. Đúng hạn xử lý: đã xử lý (Đã xử lý, Đã đóng) và thời điểm xử lý trước hạn xử lý đã chụp.
-- Ticket đang mở quá hạn: chưa xử lý mà đã qua hạn xử lý (không tính ticket huỷ).

create view report.ticket_summary with (security_invoker = true) as
select t.id as ticket_id, t.code, t.ticket_type, t.branch_id, t.category_code,
       c.parent_code as group_code, c.business_type,
       t.priority_code, t.status_code,
       ((t.created_at at time zone 'Asia/Ho_Chi_Minh')::date - extract(day from (t.created_at at time zone 'Asia/Ho_Chi_Minh'))::int + 1) as month_start,
       t.assignee_id, t.accused_user_id, t.class_id, t.student_id,
       t.satisfaction,
       (t.first_response_at is not null and t.first_response_at <= t.response_due_at) as response_on_time,
       (t.first_response_at is null and t.status_code <> 'DA_HUY' and now() > t.response_due_at) as response_overdue_open,
       (t.resolved_at is not null and t.resolved_at <= t.resolve_due_at) as resolve_on_time,
       (t.resolved_at is null and t.status_code not in ('DA_HUY', 'DA_XU_LY', 'DA_DONG') and now() > t.resolve_due_at) as resolve_overdue_open,
       case when t.resolved_at is not null then extract(epoch from (t.resolved_at - t.created_at)) / 3600.0 end as resolve_hours -- allow-number: đổi giây sang giờ
  from app.ticket t
  join app.ticket_category c on c.code = t.category_code;
comment on view report.ticket_summary is 'BC-10 (R-CS-12): mỗi ticket một dòng, cờ đúng hạn phản hồi, đúng hạn xử lý, quá hạn đang mở, giờ xử lý. Gộp ở người đọc.';

revoke all on report.ticket_summary from public, anon, authenticated;
grant select on report.ticket_summary to authenticated;
