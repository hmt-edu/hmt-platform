-- D-27-06 (Chat chốt 27/11/2026 11:46; migration 700; rủi ro THẤP, chỉ đọc). «Mức gắn bó» của học sinh trên hồ sơ 360° (R-CRM-44):
-- suy ra từ chính các cờ ở thẻ tóm tắt, tính ở máy chủ, không lưu. Chỉ để nhìn: không đổi quyền, giờ, tiền; không gửi phụ huynh.
select set_config('hmt.migration', 'on', false);

insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('engagement_points_absent_streak', 'Mức gắn bó: điểm của cờ «Vắng liên tiếp»', 'INT', 'điểm', 0, 10, '2', true, 'CSKH', 'R-CRM-44',
   'Cờ «Vắng liên tiếp» đang bật thì cộng chừng này điểm vào Mức gắn bó của học sinh.'),
  ('engagement_count_absent_streak', 'Mức gắn bó: tính cờ «Vắng liên tiếp»', 'BOOL', null, null, null, 'true', true, 'CSKH', 'R-CRM-44',
   'Tắt thì cờ «Vắng liên tiếp» không tính vào Mức gắn bó (vẫn hiện ở «Cần chú ý»).'),
  ('engagement_points_overdue_debt', 'Mức gắn bó: điểm của cờ «Nợ quá hạn»', 'INT', 'điểm', 0, 10, '2', true, 'CSKH', 'R-CRM-44',
   'Cờ «Nợ quá hạn» đang bật thì cộng chừng này điểm vào Mức gắn bó của học sinh.'),
  ('engagement_count_overdue_debt', 'Mức gắn bó: tính cờ «Nợ quá hạn»', 'BOOL', null, null, null, 'true', true, 'CSKH', 'R-CRM-44',
   'Tắt thì cờ «Nợ quá hạn» không tính vào Mức gắn bó (vẫn hiện ở «Cần chú ý»).'),
  ('engagement_points_expiring', 'Mức gắn bó: điểm của cờ «Sắp hết giờ»', 'INT', 'điểm', 0, 10, '1', true, 'CSKH', 'R-CRM-44',
   'Cờ «Sắp hết giờ» đang bật thì cộng chừng này điểm vào Mức gắn bó của học sinh.'),
  ('engagement_count_expiring', 'Mức gắn bó: tính cờ «Sắp hết giờ»', 'BOOL', null, null, null, 'true', true, 'CSKH', 'R-CRM-44',
   'Tắt thì cờ «Sắp hết giờ» không tính vào Mức gắn bó (vẫn hiện ở «Cần chú ý»).'),
  ('engagement_points_ticket_overdue', 'Mức gắn bó: điểm của cờ «Ticket quá hạn»', 'INT', 'điểm', 0, 10, '1', true, 'CSKH', 'R-CRM-44',
   'Cờ «Ticket quá hạn» đang bật thì cộng chừng này điểm vào Mức gắn bó của học sinh.'),
  ('engagement_count_ticket_overdue', 'Mức gắn bó: tính cờ «Ticket quá hạn»', 'BOOL', null, null, null, 'true', true, 'CSKH', 'R-CRM-44',
   'Tắt thì cờ «Ticket quá hạn» không tính vào Mức gắn bó (vẫn hiện ở «Cần chú ý»).'),
  ('engagement_points_stale_contact', 'Mức gắn bó: điểm của cờ «Lâu chưa liên hệ»', 'INT', 'điểm', 0, 10, '1', true, 'CSKH', 'R-CRM-44',
   'Cờ «Lâu chưa liên hệ» đang bật thì cộng chừng này điểm vào Mức gắn bó của học sinh.'),
  ('engagement_count_stale_contact', 'Mức gắn bó: tính cờ «Lâu chưa liên hệ»', 'BOOL', null, null, null, 'true', true, 'CSKH', 'R-CRM-44',
   'Tắt thì cờ «Lâu chưa liên hệ» không tính vào Mức gắn bó (vẫn hiện ở «Cần chú ý»).'),
  ('engagement_points_missing_review', 'Mức gắn bó: điểm của cờ «Thiếu nhận xét»', 'INT', 'điểm', 0, 10, '1', true, 'CSKH', 'R-CRM-44',
   'Cờ «Thiếu nhận xét» đang bật thì cộng chừng này điểm vào Mức gắn bó của học sinh.'),
  ('engagement_count_missing_review', 'Mức gắn bó: tính cờ «Thiếu nhận xét»', 'BOOL', null, null, null, 'true', true, 'CSKH', 'R-CRM-44',
   'Tắt thì cờ «Thiếu nhận xét» không tính vào Mức gắn bó (vẫn hiện ở «Cần chú ý»).'),
  ('engagement_warn_score', 'Mức gắn bó: số điểm bắt đầu «Cần chú ý»', 'INT', 'điểm', 1, 60, '1', true, 'CSKH', 'R-CRM-44',
   'Tổng điểm từ mức này thì học sinh là «Cần chú ý»; thấp hơn là «Khoẻ».'),
  ('engagement_risk_score', 'Mức gắn bó: số điểm bắt đầu «Nguy cơ»', 'INT', 'điểm', 1, 60, '3', true, 'CSKH', 'R-CRM-44',
   'Tổng điểm từ mức này thì học sinh là «Nguy cơ».');

-- app.student_overdue_days: số ngày quá hạn lâu nhất của đợt đóng tiền chưa đủ, trong các đơn đã duyệt có dòng của học sinh này.
-- Hàm trong. Chỉ tính đơn người gọi xem được (R-CRM-44: không có quyền xem tiền thì cờ nợ không tính, không hiện). Không trả số tiền.
-- Chia tiền đã vào theo thứ tự đợt như app.parent_money_summary. Chỉ mục dùng: sales_order_line_student_idx (đã có).
create function app.student_overdue_days(p_student_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  with ord as (
    select o.id, app.order_paid_amount(o.id) as paid
      from app.sales_order o
     where o.id in (select l.order_id from app.sales_order_line l where l.student_id = p_student_id)
       and o.status_code = 'DA_DUYET' and app.can_see_branch_wide('SALES_ORDER', 'XEM', o.branch_id)
  ), inst as (
    select i.due_date, i.amount,
           o.paid - coalesce(sum(i.amount) over (partition by i.order_id order by i.seq rows between unbounded preceding and 1 preceding), 0) as paid_left
      from ord o join app.sales_order_installment i on i.order_id = o.id
  )
  select (now() at time zone 'Asia/Ho_Chi_Minh')::date - min(i.due_date) from inst i
   where i.due_date < (now() at time zone 'Asia/Ho_Chi_Minh')::date and i.amount > greatest(i.paid_left, 0);
$$;

-- app.student_engagement: tổng điểm các cờ đang bật rồi xếp mức Khoẻ, Cần chú ý, Nguy cơ (R-CRM-44). Hàm trong.
-- Đầu vào: thẻ tóm tắt đã lọc theo quyền (cờ người gọi không thấy thì không tính), số ngày nợ quá hạn, cơ sở của học sinh.
-- Kết quả {level, score, reasons}: reasons là mã các cờ được tính, theo thứ tự cố định.
create function app.student_engagement(p_summary jsonb, p_overdue_days integer, p_branch_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with flag (seq, code, key, active) as (values
    (1, 'VANG_LIEN_TIEP', 'absent_streak', -- allow-number: thứ tự hiện lý do
     coalesce((p_summary -> 'attendance' ->> 'absent_streak')::integer >= (p_summary ->> 'absence_limit')::integer, false)),
    (2, 'NO_QUA_HAN', 'overdue_debt', -- allow-number: thứ tự hiện lý do
     p_overdue_days is not null),
    (3, 'SAP_HET_GIO', 'expiring', -- allow-number: thứ tự hiện lý do
     coalesce((p_summary ->> 'expiring')::boolean, false)),
    (4, 'TICKET_QUA_HAN', 'ticket_overdue', -- allow-number: thứ tự hiện lý do
     coalesce((p_summary -> 'tickets' ->> 'overdue')::integer, 0) > 0),
    (5, 'LAU_CHUA_LIEN_HE', 'stale_contact', -- allow-number: thứ tự hiện lý do
     coalesce((p_summary ->> 'contact_visible')::boolean, false)
        and coalesce((p_summary -> 'last_contact' ->> 'days')::integer, (p_summary ->> 'days_since_created')::integer)
            >= (p_summary ->> 'stale_days')::integer),
    (6, 'THIEU_NHAN_XET', 'missing_review', -- allow-number: thứ tự hiện lý do
     coalesce((p_summary ->> 'missing_review')::integer, 0) > 0)
  ), counted as (
    select f.seq, f.code, app.get_setting_int('engagement_points_' || f.key, p_branch_id) as points
      from flag f
     where f.active and app.get_setting_bool('engagement_count_' || f.key, p_branch_id)
  ), total as (
    select coalesce(sum(c.points), 0)::integer as score,
           coalesce(jsonb_agg(c.code order by c.seq) filter (where c.points > 0), '[]'::jsonb) as reasons
      from counted c
  )
  select jsonb_build_object(
           'level', case when t.score >= app.get_setting_int('engagement_risk_score', p_branch_id) then 'NGUY_CO'
                         when t.score >= app.get_setting_int('engagement_warn_score', p_branch_id) then 'CAN_CHU_Y'
                         else 'KHOE' end,
           'score', t.score, 'reasons', t.reasons)
    from total t;
$$;

-- Thẻ tóm tắt cũ (migration 695) thành hàm trong; hàm mới cùng tên thêm số ngày nợ quá hạn và Mức gắn bó.
alter function app.get_student_summary(uuid) rename to student_summary_base;

-- app.get_student_summary: thẻ tóm tắt đầu hồ sơ học sinh. Ai gọi: người xem được học sinh (kiểm trong app.student_summary_base). Chỉ đọc.
-- R-CRM-44: chỉ học sinh Đang học có Mức gắn bó; người chỉ có phạm vi «được phân công» không nhận (không thấy đủ cờ).
create function app.get_student_summary(p_student_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v jsonb := app.student_summary_base(p_student_id);
  s app.student;
  v_overdue integer;
begin
  select * into s from app.student where id = p_student_id;
  if app.permission_scope('STUDENT', 'XEM') = 'DUOC_PHAN_CONG' then
    return v || jsonb_build_object('overdue_days', null, 'engagement', null);
  end if;
  v_overdue := app.student_overdue_days(s.id);
  return v || jsonb_build_object(
    'overdue_days', v_overdue,
    'engagement', case when app.student_status(s.id) = 'DANG_HOC' then app.student_engagement(v, v_overdue, s.branch_id) end);
end;
$$;

revoke execute on function app.student_summary_base(uuid), app.student_overdue_days(uuid), app.student_engagement(jsonb, integer, uuid)
  from public, anon, authenticated;
revoke execute on function app.get_student_summary(uuid) from public, anon;
grant execute on function app.get_student_summary(uuid) to authenticated;
