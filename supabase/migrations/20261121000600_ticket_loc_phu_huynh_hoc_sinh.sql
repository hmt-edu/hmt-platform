-- KH-02, KH-05: tab «Ticket» ở hồ sơ phụ huynh và học sinh (canvas 9933: KH02_ticket; Chat duyệt #460, 21/11/2026).
-- app.ticket_filter_rows (nơi duy nhất định nghĩa bộ lọc ticket, dùng chung list_tickets, ticket_board, ticket_group_counts) thêm hai khoá: parent_id, student_id.
-- Không đổi bảng, không đổi quyền: vẫn chạy dưới RLS ticket của người gọi (người không có quyền Xem ticket thấy 0 dòng).
-- Chỉ mục: đã có ticket_parent_idx (parent_id) và ticket_student_idx (student_id) từ migration 157; không thêm.
-- Chữ ký và các khoá cũ giữ nguyên.

create or replace function app.ticket_filter_rows(p_filters jsonb default '{}'::jsonb)
returns setof app.ticket
language sql
stable
set search_path = ''
as $$
  select t.* from app.ticket t
   where (p_filters ->> 'ticket_type' is null or t.ticket_type = p_filters ->> 'ticket_type')
     and (p_filters ->> 'status_code' is null or t.status_code = p_filters ->> 'status_code')
     and (p_filters ->> 'category_code' is null or t.category_code = p_filters ->> 'category_code')
     and (p_filters ->> 'priority_code' is null or t.priority_code = p_filters ->> 'priority_code')
     and (p_filters ->> 'branch_id' is null or t.branch_id = (p_filters ->> 'branch_id')::uuid)
     and (p_filters ->> 'assignee_id' is null or t.assignee_id = (p_filters ->> 'assignee_id')::uuid)
     and (p_filters ->> 'parent_id' is null or t.parent_id = (p_filters ->> 'parent_id')::uuid)
     and (p_filters ->> 'student_id' is null or t.student_id = (p_filters ->> 'student_id')::uuid)
     and (coalesce((p_filters ->> 'no_assignee')::boolean, false) = false or t.assignee_id is null)
     and (p_filters ->> 'group_code' is null
          or exists (select from app.ticket_category c where c.code = t.category_code and coalesce(c.parent_code, c.code) = p_filters ->> 'group_code'))
     and (coalesce((p_filters ->> 'mine')::boolean, false) = false or t.created_by = auth.uid() or t.assignee_id = auth.uid())
     and (nullif(btrim(coalesce(p_filters ->> 'q', '')), '') is null
          or t.code ilike '%' || btrim(p_filters ->> 'q') || '%' or t.title ilike '%' || btrim(p_filters ->> 'q') || '%')
     and (nullif(p_filters ->> 'sla_state', '') is null or app.ticket_row(t) ->> 'sla_state' = p_filters ->> 'sla_state');
$$;
