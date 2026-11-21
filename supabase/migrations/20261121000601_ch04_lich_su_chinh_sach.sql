-- CH-04 Lịch sử thay đổi chính sách chiết khấu, quà tặng (canvas 9933: nút «Lịch sử thay đổi» ở CH04_chinh; Chat duyệt #460, 21/11/2026).
-- Mọi sửa cấu hình ghi nhật ký (CLAUDE.md, Cấu hình); màn chỉ đọc lại, theo mẫu app.list_setting_history (QT-09) và app.list_catalog_history (QT-07).
-- Không đổi cấu trúc bảng. Không thêm chỉ mục: tra theo (table_id, record_id, at) dùng audit_log_record_idx; nối chính sách qua khoá chính; bảng chính sách chỉ vài chục dòng.

-- app.list_policy_history(p_kind, p_limit, p_offset): một trang lịch sử chính sách, mới nhất trước.
-- Ai gọi: người có quyền Cấu hình bán hàng · Xem (như đọc chính sách). Không ghi gì.
-- Đầu vào: p_kind ('DISCOUNT' = chiết khấu, 'GIFT' = quà tặng; để trống = cả hai), p_limit/p_offset (phân trang, trần theo list_page_size_max).
-- Kết quả: {total, rows:[{id, at, kind, code, name, action, changes, actor_name}]}; changes chỉ giữ cột cấu hình của chính sách dạng {"cột":[cũ,mới]}.
-- Luật: mã chính sách không đổi, không xoá (không có dòng Xoá); hiện lần tạo và lần đổi giá trị, hiệu lực, phạm vi, cần duyệt, Ngừng/Dùng lại (R-TIEN-14, R-TIEN-29, R-TIEN-30).
create or replace function app.list_policy_history(
  p_kind text default null, p_limit integer default null, p_offset integer default 0)
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
  v_discount smallint;
  v_gift smallint;
  v_result jsonb;
begin
  -- Luật: chỉ người có quyền Cấu hình bán hàng · Xem đọc nhật ký chính sách.
  if not app.has_permission('CONFIG_SALES', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem lịch sử thay đổi chính sách.');
  end if;
  if p_kind is not null and p_kind not in ('DISCOUNT', 'GIFT') then
    perform app.raise_error('HMT_LOAI_SAI', 'Loại chính sách phải là chiết khấu hoặc quà tặng.');
  end if;
  select id into v_discount from app.audited_table where table_name = 'app.discount_policy';
  select id into v_gift from app.audited_table where table_name = 'app.gift_policy';

  with ev as not materialized (
    select l.id, l.at, l.actor, 'DISCOUNT'::text as kind, d.code, d.name, l.action::text as action,
           (select jsonb_object_agg(e.key, e.value) from jsonb_each(coalesce(l.changes, '{}'::jsonb)) e
             where e.key in ('name', 'max_value', 'fixed_value', 'requires_approval', 'valid_from', 'valid_to',
                             'package_type_codes', 'branch_ids', 'applies_to', 'is_active')) as changes
      from app.audit_log l
      join app.discount_policy d on d.id = l.record_id
     where l.table_id = v_discount and (p_kind is null or p_kind = 'DISCOUNT')
       and (l.action = 'I' or (l.action = 'U' and l.changes ?| array['name', 'max_value', 'fixed_value', 'requires_approval',
            'valid_from', 'valid_to', 'package_type_codes', 'branch_ids', 'applies_to', 'is_active']))
    union all
    select l.id, l.at, l.actor, 'GIFT'::text, g.code, g.name, l.action::text,
           (select jsonb_object_agg(e.key, e.value) from jsonb_each(coalesce(l.changes, '{}'::jsonb)) e
             where e.key in ('name', 'max_quantity', 'requires_approval', 'valid_from', 'valid_to',
                             'package_type_codes', 'branch_ids', 'applies_to', 'is_active'))
      from app.audit_log l
      join app.gift_policy g on g.id = l.record_id
     where l.table_id = v_gift and (p_kind is null or p_kind = 'GIFT')
       and (l.action = 'I' or (l.action = 'U' and l.changes ?| array['name', 'max_quantity', 'requires_approval',
            'valid_from', 'valid_to', 'package_type_codes', 'branch_ids', 'applies_to', 'is_active']))
  ), page as (select * from ev order by ev.at desc, ev.id desc limit v_limit offset v_offset)
  select jsonb_build_object(
           'total', (select count(*) from ev),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'at', p.at, 'kind', p.kind, 'code', p.code, 'name', p.name, 'action', p.action,
             'changes', p.changes, 'actor_name', app.staff_display_name(p.actor))
             order by p.at desc, p.id desc), '[]'::jsonb))
    into v_result
    from page p;
  return v_result;
end;
$$;
revoke execute on function app.list_policy_history(text, integer, integer) from public, anon;
grant execute on function app.list_policy_history(text, integer, integer) to authenticated;
