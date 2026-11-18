-- Migration 463 (Code D, 18/11/2026): sửa R1 của Soát, nhóm «lead, cơ hội, lịch hẹn». Viết lại chính sách đọc theo kiểu mới: phạm vi hẹp (Được phân công, Của tôi, Chính mình) KHÔNG còn đọc cả cơ sở.
-- Trước: «TOAN_HE_THONG, hoặc phạm vi KHÁC RỖNG và cùng cơ sở». Sau: «TOAN_HE_THONG, hoặc phạm vi CO_SO và cùng cơ sở». Giữ nguyên `(select ...)` (initplan). Chỉ đổi chính sách đọc, không đổi hàm.
-- Hôm nay không vai nào bị đổi kết quả (mọi ô Xem của phân hệ này là TOAN_HE_THONG hoặc CO_SO); chỉ chặn trường hợp Admin cấp phạm vi hẹp sau này (màn QT-05).

alter policy lead_read on app.lead
  using (((( SELECT app.permission_scope('LEAD'::text, 'XEM'::text) AS permission_scope) = 'TOAN_HE_THONG'::text) OR ((( SELECT app.permission_scope('LEAD'::text, 'XEM'::text) AS permission_scope) = 'CO_SO'::text) AND (branch_id = ( SELECT app.current_branch_id() AS current_branch_id)))));

alter policy prospect_student_read on app.prospect_student
  using ((((lead_id IS NOT NULL) AND ((( SELECT app.permission_scope('LEAD'::text, 'XEM'::text) AS permission_scope) = 'TOAN_HE_THONG'::text) OR ((( SELECT app.permission_scope('LEAD'::text, 'XEM'::text) AS permission_scope) = 'CO_SO'::text) AND (branch_id = ( SELECT app.current_branch_id() AS current_branch_id))))) OR ((opportunity_id IS NOT NULL) AND ((( SELECT app.permission_scope('OPPORTUNITY'::text, 'XEM'::text) AS permission_scope) = 'TOAN_HE_THONG'::text) OR ((( SELECT app.permission_scope('OPPORTUNITY'::text, 'XEM'::text) AS permission_scope) = 'CO_SO'::text) AND (branch_id = ( SELECT app.current_branch_id() AS current_branch_id)))))));

alter policy opportunity_read on app.opportunity
  using (((( SELECT app.permission_scope('OPPORTUNITY'::text, 'XEM'::text) AS permission_scope) = 'TOAN_HE_THONG'::text) OR ((( SELECT app.permission_scope('OPPORTUNITY'::text, 'XEM'::text) AS permission_scope) = 'CO_SO'::text) AND (branch_id = ( SELECT app.current_branch_id() AS current_branch_id)))));

alter policy appointment_read on app.appointment
  using (((( SELECT app.permission_scope('APPOINTMENT'::text, 'XEM'::text) AS permission_scope) = 'TOAN_HE_THONG'::text) OR ((( SELECT app.permission_scope('APPOINTMENT'::text, 'XEM'::text) AS permission_scope) = 'CO_SO'::text) AND (branch_id = ( SELECT app.current_branch_id() AS current_branch_id)))));
