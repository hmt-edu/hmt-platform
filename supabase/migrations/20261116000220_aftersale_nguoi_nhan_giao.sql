-- Code B (16/11/2026), Aftersale lát 3b, migration 220: danh sách người nhận giao ticket (hộp thoại Giao của CSN-03).
-- Luật: AS-09 (quyền Ticket · Sửa mới giao được, như app.assign_ticket). Không đụng app.list_assignable_staff (dùng chung cho Lead, Cơ hội).
select set_config('hmt.migration', 'on', false);

-- app.list_ticket_assignees(mã cơ sở): nhân viên CRM đang hoạt động của cơ sở, để chọn Người phụ trách khi giao ticket.
-- Ai gọi: Ticket · Sửa tại cơ sở đó (kiểm bằng app.assert_can). Số dòng tối đa list_page_size_max. Trả id, tên, vai trò.
create or replace function app.list_ticket_assignees(p_branch_id uuid default null)
returns table (id uuid, display_name text, role_names text[])
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch_id, app.current_branch_id());
begin
  perform app.assert_can('TICKET', 'SUA', v_branch);
  return query
    select u.id, u.display_name,
           array(select r.name from app.user_role ur join app.role r on r.code = ur.role_code
                  where ur.user_id = u.id and ur.is_active and 'crm' = any (r.portals) order by r.sort_order)
      from app.user_account u
     where u.branch_id = v_branch and not u.is_locked and u.student_code is null
       and exists (select from app.user_role ur join app.role r on r.code = ur.role_code
                    where ur.user_id = u.id and ur.is_active and 'crm' = any (r.portals))
     order by u.display_name, u.id
     limit app.get_setting_int('list_page_size_max');
end;
$$;
revoke execute on function app.list_ticket_assignees(uuid) from public, anon, authenticated;
grant execute on function app.list_ticket_assignees(uuid) to authenticated;

select set_config('hmt.migration', '', false);
