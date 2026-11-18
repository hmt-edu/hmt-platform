-- QT-11 Nhật ký thao tác (Code F, 18/11/2026). Luật S03-12: ai, lúc nào, bảng nào, trường nào đổi từ gì sang gì; chỉ đọc.
-- Chỉ mục (CLAUDE.md, Hiệu năng): audit_log_at_idx để sắp xếp mới nhất trước và lọc theo khoảng ngày không quét cả bảng;
-- audit_log_actor_idx để lọc theo người thao tác. Lọc theo bảng/bản ghi đã có audit_log_record_idx (table_id, record_id, at).
create index if not exists audit_log_at_idx on app.audit_log (at desc, id desc);
create index if not exists audit_log_actor_idx on app.audit_log (actor, at desc);

-- app.list_audit_log(p_filters, p_limit, p_offset): một trang nhật ký thao tác, mới nhất trước.
-- Ai gọi: người có Quản trị · Xem (Admin, đã xác thực hai bước). Không ghi gì.
-- Bộ lọc (jsonb): table (tên bảng), action (I|U|D), actor (uuid người thao tác), record_id (uuid bản ghi), from, to (timestamptz, to là mốc loại trừ).
-- Kết quả: {total, rows:[{id, at, table_name, record_id, action, changes, actor_id, actor_name}]}.
create or replace function app.list_audit_log(
  p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_table text := nullif(p_filters ->> 'table', '');
  v_action text := nullif(p_filters ->> 'action', '');
  v_actor uuid := nullif(p_filters ->> 'actor', '')::uuid;
  v_record uuid := nullif(p_filters ->> 'record_id', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_result jsonb;
begin
  -- Luật S03-12: chỉ Admin đọc nhật ký thao tác.
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được xem nhật ký thao tác.');
  end if;
  -- Luật: loại thao tác chỉ là I, U hoặc D.
  if v_action is not null and v_action not in ('I', 'U', 'D') then
    perform app.raise_error('HMT_LOC_KHONG_HOP_LE', 'Loại thao tác phải là tạo, sửa hoặc xoá.');
  end if;
  with f as not materialized (
    select l.*, t.table_name
      from app.audit_log l
      join app.audited_table t on t.id = l.table_id
     where (v_table is null or t.table_name = v_table)
       and (v_action is null or l.action = v_action::char(1))
       and (v_actor is null or l.actor = v_actor)
       and (v_record is null or l.record_id = v_record)
       and (v_from is null or l.at >= v_from)
       and (v_to is null or l.at < v_to)
  ),
  page as (select * from f order by f.at desc, f.id desc limit v_limit offset v_offset)
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'at', p.at, 'table_name', p.table_name, 'record_id', p.record_id, 'action', p.action,
             'changes', p.changes, 'actor_id', p.actor, 'actor_name', app.staff_display_name(p.actor))
             order by p.at desc, p.id desc), '[]'::jsonb))
    into v_result
    from page p;
  return v_result;
end;
$$;
revoke execute on function app.list_audit_log(jsonb, integer, integer) from public, anon;
grant execute on function app.list_audit_log(jsonb, integer, integer) to authenticated;
