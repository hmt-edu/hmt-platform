-- QT-07 Lịch sử thay đổi danh mục (Chat duyệt 20/11; canvas dc47 chỉ vẽ nút «Lịch sử thay đổi» mờ, không có khung hộp: dựng theo khuôn hộp lịch sử của QT-09).
-- Không đổi cấu trúc bảng. Không thêm chỉ mục: tra theo (table_id, record_id, at) dùng audit_log_record_idx; nối mục qua khoá chính, lọc danh mục bằng unique (catalog_code, code) sẵn có của catalog_item.

-- app.list_catalog_history(p_root_code, p_limit, p_offset): một trang lịch sử sửa mục của một danh mục (kể cả các cấp con), mới nhất trước.
-- Ai gọi: người có Quản trị · Xem (Admin, đã xác thực hai bước). Không ghi gì.
-- Đầu vào: p_root_code (mã danh mục gốc), p_limit/p_offset (phân trang, trần theo tham số list_page_size_max).
-- Kết quả: {total, rows:[{id, at, catalog_code, item_code, item_name, action, changes, actor_name}]}; changes chỉ giữ name, is_active, sort_order dạng {"cột":[cũ,mới]}.
-- Luật: mã mục không đổi, không xoá (không có dòng Xoá); chỉ hiện lần tạo mục và lần đổi tên, Ngừng/Dùng lại, đổi thứ tự.
create or replace function app.list_catalog_history(
  p_root_code text, p_limit integer default null, p_offset integer default 0)
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
  v_table smallint;
  v_result jsonb;
begin
  -- Luật S03-12: chỉ Admin đọc nhật ký cấu hình.
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được xem lịch sử thay đổi danh mục.');
  end if;
  -- Luật: danh mục phải có thật.
  if not exists (select from app.catalog where code = p_root_code) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy danh mục.');
  end if;
  select id into v_table from app.audited_table where table_name = 'app.catalog_item';

  with recursive tree as (
    select c.code from app.catalog c where c.code = p_root_code
    union all
    select c.code from app.catalog c join tree t on c.parent_catalog = t.code
  ),
  ev as not materialized (
    select l.id, l.at, l.actor, i.catalog_code, i.code as item_code, i.name as item_name, l.action::text as action,
           (select jsonb_object_agg(e.key, e.value) from jsonb_each(coalesce(l.changes, '{}'::jsonb)) e
             where e.key in ('name', 'is_active', 'sort_order')) as changes
      from app.audit_log l
      join app.catalog_item i on i.id = l.record_id
     where l.table_id = v_table
       and i.catalog_code in (select code from tree)
       and (l.action = 'I'
            or (l.action = 'U' and (l.changes ? 'name' or l.changes ? 'is_active' or l.changes ? 'sort_order')))
  ),
  page as (select * from ev order by ev.at desc, ev.id desc limit v_limit offset v_offset)
  select jsonb_build_object(
           'total', (select count(*) from ev),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'at', p.at, 'catalog_code', p.catalog_code, 'item_code', p.item_code,
             'item_name', p.item_name, 'action', p.action, 'changes', p.changes,
             'actor_name', app.staff_display_name(p.actor))
             order by p.at desc, p.id desc), '[]'::jsonb))
    into v_result
    from page p;
  return v_result;
end;
$$;
revoke execute on function app.list_catalog_history(text, integer, integer) from public, anon;
grant execute on function app.list_catalog_history(text, integer, integer) to authenticated;
