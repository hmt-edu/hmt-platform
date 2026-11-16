-- Migration 214 (Code D, 16/11/2026): view báo cáo cho Looker Studio và các màn báo cáo (R-BC-01; BC-02, 03, 04, 06).
-- Chat chốt 16/11 05:35: view trong schema `report`, security_invoker (RLS của bảng gốc áp theo người đọc), đọc qua vai trò sẵn có;
-- KHÔNG tạo vai trò DB riêng cho Looker (việc của anh Trường sau go-live, ghi VIEC-ANH). Chỉ đọc, không đổi bảng cũ.
-- Chưa làm: BC-05 tái tục (chưa có bảng phiếu tái tục), BC-07 BTVN, BC-10 ticket (chờ #18).
create schema if not exists report;
comment on schema report is 'View chỉ đọc cho báo cáo (security_invoker). Không chứa dữ liệu riêng; không ghi.';
grant usage on schema report to authenticated;

-- Đơn giá ghi nhận của từng ghi danh (R-BC-04, R-BC-05): tiền ĐÃ THU của dòng đơn ÷ (giờ mua + giờ tặng). Ghi danh không có dòng đơn: không có dòng.
create view report.enrollment_unit_price with (security_invoker = true) as
select e.id as enrollment_id,
       sum(a.amount)::numeric / nullif(e.purchased_hours + e.gifted_hours, 0) as unit_price
  from app.enrollment e
  join app.money_in_allocation a on a.order_line_id = e.order_line_id
 group by e.id, e.purchased_hours, e.gifted_hours;
comment on view report.enrollment_unit_price is 'Đơn giá ghi nhận (đồng mỗi giờ) của ghi danh có dòng đơn (R-BC-04). Tiền đã thu ÷ (giờ mua + giờ tặng).';

-- BC-02: phễu tuyển sinh theo tháng, cơ sở, nguồn, chiến dịch, người phụ trách (số lead, số cơ hội, số cơ hội chốt L8).
create view report.lead_funnel with (security_invoker = true) as
select l.branch_id,
       (l.created_at at time zone 'Asia/Ho_Chi_Minh')::date - extract(day from (l.created_at at time zone 'Asia/Ho_Chi_Minh'))::int + 1 as month_start,
       l.source_type_code, l.source_code, l.campaign_id, l.owner_id,
       count(distinct l.id) as leads,
       count(distinct o.id) as opportunities,
       count(distinct o.id) filter (where o.stage_code = 'L8') as opportunities_won
  from app.lead l
  left join app.opportunity o on o.lead_id = l.id
 group by 1, 2, 3, 4, 5, 6;
comment on view report.lead_funnel is 'BC-02: phễu lead → cơ hội → chốt (L8) theo tháng tạo lead, cơ sở, nguồn, chiến dịch, người phụ trách.';

-- BC-03: doanh thu ghi nhận theo từng dòng trừ giờ của buổi (R-BC-04): giờ trừ × đơn giá, tính cho cơ sở nơi buổi diễn ra (R-GD-10).
-- Học bù, học bổ trợ không trừ giờ nên không có dòng (0 đ). Ghi danh không có giá (nạp cũ): unit_price và revenue để trống.
create view report.revenue_by_session with (security_invoker = true) as
select s.session_date, s.branch_id, s.class_id, c.subject_code, s.type_code as session_type_code,
       g.enrollment_id, (-g.hours) as hours, p.unit_price,
       round((-g.hours) * p.unit_price)::bigint as revenue
  from app.hour_ledger g
  join app.class_session s on s.id = g.session_id
  join app.class c on c.id = s.class_id
  left join report.enrollment_unit_price p on p.enrollment_id = g.enrollment_id
 where g.entry_type = 'TRU_BUOI' and s.type_code in ('CHINH', 'CUNG_CO');
comment on view report.revenue_by_session is 'BC-03: doanh thu ghi nhận theo buổi (R-BC-04). revenue trống nghĩa là ghi danh chưa có giá.';

-- BC-04: tiền đã thu và quỹ giờ của từng ghi danh còn hiệu lực: giờ đã cấp, giờ còn, giờ còn quy ra tiền (R-BC-05).
create view report.hours_fund with (security_invoker = true) as
select e.id as enrollment_id, e.branch_id, e.status_code,
       coalesce(sum(g.hours) filter (where g.entry_type in ('CAP_MUA', 'CAP_TANG', 'DAU_KY')), 0) as hours_granted,
       coalesce(sum(g.hours), 0) as hours_left,
       p.unit_price,
       case when coalesce(sum(g.hours), 0) > 0 and p.unit_price is not null then round(sum(g.hours) * p.unit_price)::bigint end as value_left,
       (select coalesce(sum(a.amount), 0) from app.money_in_allocation a where a.order_line_id = e.order_line_id)::bigint as paid_amount
  from app.enrollment e
  left join app.hour_ledger g on g.enrollment_id = e.id
  left join report.enrollment_unit_price p on p.enrollment_id = e.id
 where e.status_code in ('DA_XEP_LOP', 'DANG_HOC', 'BAO_LUU')
 group by e.id, e.branch_id, e.status_code, e.order_line_id, p.unit_price;
comment on view report.hours_fund is 'BC-04: giờ đã cấp, giờ còn, giờ còn quy ra tiền, tiền đã thu của ghi danh còn hiệu lực (R-BC-05).';

-- BC-06: sĩ số so với tối đa và chuyên cần theo lớp (buổi Done). Trạng thái chính thức là ô của giáo viên, thiếu thì ô vận hành (R-DD-02).
create view report.class_attendance with (security_invoker = true) as
select c.id as class_id, c.branch_id, c.code as class_code, c.max_students,
       (select count(*) from app.enrollment_class ec where ec.class_id = c.id and ec.end_date is null) as active_students,
       count(a.id) filter (where coalesce(a.teacher_status_code, a.ops_status_code) is not null) as marked,
       count(a.id) filter (where coalesce(a.teacher_status_code, a.ops_status_code) in ('CO_MAT', 'DI_MUON')) as present,
       count(a.id) filter (where coalesce(a.teacher_status_code, a.ops_status_code) in ('VANG_CO_PHEP', 'VANG_KHONG_PHEP')) as absent
  from app.class c
  left join app.class_session s on s.class_id = c.id and s.status_code = 'DONE'
  left join app.session_attendance a on a.session_id = s.id and a.is_active and not a.is_trial
 group by c.id, c.branch_id, c.code, c.max_students;
comment on view report.class_attendance is 'BC-06: sĩ số hiện tại so với tối đa, số lượt có mặt và vắng ở các buổi Done (không tính học thử).';

revoke all on all tables in schema report from public, anon, authenticated;
grant select on all tables in schema report to authenticated;
