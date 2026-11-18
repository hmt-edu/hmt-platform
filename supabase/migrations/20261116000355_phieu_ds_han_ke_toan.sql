-- Code B (18/11/2026), Aftersale B10 (CSN-05), migration 355: danh sách phiếu nghiệp vụ trả thêm due_at (hạn xử lý của ticket gốc) cho cột «Hạn» của canvas CSN05,
-- và «Chờ tôi duyệt» chỉ tính vai Kế toán cho cấp kế toán (Admin không duyệt tiền, R-HT-01; khớp migration 353).
-- Chỉ thêm khoá vào JSON và siết một điều kiện; quyền, RLS, phân trang giữ nguyên. Chỉ mục: không thêm (đã join theo khoá chính ticket).
select set_config('hmt.migration', 'on', false);

create or replace function app.list_ticket_tasks(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_status text := nullif(p_filters ->> 'status_code', '');
  v_type text := nullif(p_filters ->> 'task_type', '');
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_for_me boolean := coalesce((p_filters ->> 'cho_toi')::boolean, false);
  v_for_acc boolean := coalesce((p_filters ->> 'cho_ke_toan')::boolean, false);
  v_can_approve boolean := app.has_permission('TICKET', 'DUYET');
  v_is_acc boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code = 'ACCOUNTANT');
  v_total bigint;
  v_rows jsonb;
begin
  with f as (
    select k.id, k.created_at
      from app.ticket_task k
      join app.ticket t on t.id = k.ticket_id
     where (v_status is null or k.status_code = v_status)
       and (v_type is null or k.task_type = v_type)
       and (v_branch is null or k.branch_id = v_branch)
       and (v_q is null or k.code ilike '%' || v_q || '%' or t.code ilike '%' || v_q || '%')
       and (not v_for_me or (k.status_code = 'CHO_DUYET' and v_can_approve and k.created_by is distinct from auth.uid()
                             and (k.levels[k.current_level] <> 'KE_TOAN' or v_is_acc)))
       and (not v_for_acc or (k.status_code = 'CHO_DUYET' and k.levels[k.current_level] = 'KE_TOAN')))
  select (select count(*) from f),
         coalesce((select jsonb_agg(jsonb_build_object(
                    'id', k.id, 'code', k.code, 'task_type', k.task_type, 'status_code', k.status_code,
                    'level', k.current_level, 'level_total', cardinality(k.levels),
                    'next_role', case when k.status_code = 'CHO_DUYET' then k.levels[k.current_level] end,
                    'ticket_id', k.ticket_id, 'ticket_code', t.code,
                    'student_name', (select s.full_name from app.student s where s.id = t.student_id),
                    'branch_code', (select b.code from app.branch b where b.id = k.branch_id),
                    'created_at', k.created_at, 'due_at', t.resolve_due_at) order by k.created_at desc, k.id)
                   from (select f.id from f order by f.created_at desc, f.id limit v_limit offset v_offset) x
                   join app.ticket_task k on k.id = x.id join app.ticket t on t.id = k.ticket_id), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

select set_config('hmt.migration', '', false);
