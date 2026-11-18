-- Code B (18/11/2026), Aftersale CS-01, migration 351: hàng ticket (app.ticket_row) thêm group_name (nhóm của nhóm con) và student_name, cho cột «Nhóm · Nhóm con», «Học sinh» của danh sách theo canvas CSN01.
-- Chỉ thêm khoá vào JSON; không đổi quyền (ticket_row vẫn chỉ gọi từ hàm đã kiểm quyền), không đổi bảng. Luật R-CS-01 (danh sách), R-V2-23 (phân loại hai cấp).
-- Chỉ mục: không thêm; tra theo khoá chính của nhóm con và học sinh (đã có chỉ mục), chạy trên tối đa 100 dòng mỗi trang.
create or replace function app.ticket_row(t app.ticket)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', t.id, 'code', t.code, 'title', t.title, 'ticket_type', t.ticket_type, 'branch_code', (select b.code from app.branch b where b.id = t.branch_id),
    'category_name', (select c.name from app.ticket_category c where c.code = t.category_code),
    -- Thêm cho danh sách theo khuôn CSN01: cột «Nhóm · Nhóm con» và «Học sinh».
    'group_name', (select g.name from app.ticket_category c join app.ticket_category g on g.code = c.parent_code where c.code = t.category_code),
    'student_name', (select st.full_name from app.student st where st.id = t.student_id),
    'priority_code', t.priority_code, 'status_code', t.status_code,
    'assignee_name', app.staff_display_name(t.assignee_id),
    'sender_name', coalesce((select p.full_name from app.parent p where p.id = t.parent_id), app.staff_display_name(t.sender_user_id)),
    'resolve_due_at', t.resolve_due_at, 'created_at', t.created_at,
    'sla_state', case
      when t.status_code = 'DA_XU_LY' and t.resolved_at < now() - make_interval(days => app.get_setting_int('as_close_wait_days')::integer) then 'CHO_DONG'
      when t.status_code in ('DA_XU_LY', 'DA_DONG', 'DA_HUY') then 'KHONG'
      when now() > t.resolve_due_at then 'QUA_HAN'
      when t.resolve_due_at - now() < (t.resolve_due_at - t.created_at) * (app.get_setting_int('as_sla_warn_percent') / 100.0)::double precision then 'SAP_QUA_HAN' -- allow-number: phần trăm chia 100
      else 'KHONG' end);
$$;
