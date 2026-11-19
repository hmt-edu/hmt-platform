-- QT-09 Lịch sử thay đổi tham số (canvas dc47 QT09_lich_su; Chat duyệt 20/11). Mọi sửa cấu hình ghi nhật ký (CLAUDE.md, Cấu hình); màn chỉ đọc lại.
-- Không đổi cấu trúc bảng. Không thêm chỉ mục: tra theo (table_id, record_id, at) dùng audit_log_record_idx có sẵn; nhánh «tất cả tham số» dùng audit_log_at_idx (migration 550).

-- app.list_setting_history(p_key, p_limit, p_offset): một trang lịch sử đổi giá trị tham số, mới nhất trước.
-- Ai gọi: người có Quản trị · Xem (Admin). Không ghi gì.
-- Đầu vào: p_key (khoá tham số; để trống = mọi tham số), p_limit/p_offset (phân trang, trần theo tham số list_page_size_max).
-- Kết quả: {total, rows:[{id, at, setting_key, branch_code (null = giá trị chung), action, old_value, new_value, actor_name}]}.
-- Luật: chỉ hiện lần ĐỔI GIÁ TRỊ (cột value) hoặc bỏ/bật lại ghi đè (cột is_active) và lần tạo ghi đè; lần tạo ghi đè chỉ ghi «đã tạo» nên giá trị mới để trống (nhật ký không chép dữ liệu lúc tạo).
create or replace function app.list_setting_history(
  p_key text default null, p_limit integer default null, p_offset integer default 0)
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
  v_def_table smallint;
  v_branch_table smallint;
  v_result jsonb;
begin
  -- Luật S03-12: chỉ Admin đọc nhật ký cấu hình.
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được xem lịch sử thay đổi tham số.');
  end if;
  select id into v_def_table from app.audited_table where table_name = 'app.setting_def';
  select id into v_branch_table from app.audited_table where table_name = 'app.setting_branch';

  with ev as not materialized (
    -- Giá trị chung: lần đổi cột value của setting_def.
    select l.id, l.at, l.actor, d.key as setting_key, null::text as branch_code, l.action::text as action,
           l.changes -> 'value' ->> 0 as old_value, l.changes -> 'value' ->> 1 as new_value
      from app.audit_log l
      join app.setting_def d on d.id = l.record_id
     where l.table_id = v_def_table
       and l.action = 'U' and l.changes ? 'value'
       and (p_key is null or d.key = p_key)
    union all
    -- Ghi đè theo cơ sở: tạo, đổi giá trị, bỏ hoặc bật lại (is_active).
    select l.id, l.at, l.actor, b.setting_key, c.code, l.action::text,
           case when l.changes ? 'value' then l.changes -> 'value' ->> 0
                when (l.changes -> 'is_active' ->> 1) = 'false' then b.value end,
           case when l.changes ? 'value' then l.changes -> 'value' ->> 1
                when (l.changes -> 'is_active' ->> 1) = 'true' then b.value end
      from app.audit_log l
      join app.setting_branch b on b.id = l.record_id
      join app.branch c on c.id = b.branch_id
     where l.table_id = v_branch_table
       and (l.action = 'I' or (l.action = 'U' and (l.changes ? 'value' or l.changes ? 'is_active')))
       and (p_key is null or b.setting_key = p_key)
  ),
  page as (select * from ev order by ev.at desc, ev.id desc limit v_limit offset v_offset)
  select jsonb_build_object(
           'total', (select count(*) from ev),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'at', p.at, 'setting_key', p.setting_key, 'branch_code', p.branch_code,
             'action', p.action, 'old_value', p.old_value, 'new_value', p.new_value,
             'actor_name', app.staff_display_name(p.actor))
             order by p.at desc, p.id desc), '[]'::jsonb))
    into v_result
    from page p;
  return v_result;
end;
$$;
revoke execute on function app.list_setting_history(text, integer, integer) from public, anon;
grant execute on function app.list_setting_history(text, integer, integer) to authenticated;
