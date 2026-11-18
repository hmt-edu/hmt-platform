-- CH-07: lưu nhiều mô tả mức trong MỘT giao dịch (màn Sửa lưu cả bảng một lần; không gọi lặp từng ô).
-- app.update_review_level_descs(p_version_id, p_items) -> integer
-- p_items: mảng {criterion_id, level, description}. Ai gọi: Admin (kiểm trong app.update_review_level_desc từng ô). Một ô sai thì cả lần lưu quay lại.
-- Trả về số ô đã lưu. Luật CH-07: chỉ bản Đang dùng; mô tả không rỗng; mức 1 đến 5; chỉ áp cho buổi mở nhận xét sau.
create or replace function app.update_review_level_descs(p_version_id uuid, p_items jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item jsonb;
  v_count integer := 0;
begin
  perform app.assert_config_writer();
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    perform app.raise_error('HMT_THAM_SO_SAI', 'Danh sách mô tả không hợp lệ.');
  end if;
  for v_item in select * from jsonb_array_elements(p_items) loop
    perform app.update_review_level_desc(p_version_id, (v_item ->> 'criterion_id')::uuid, (v_item ->> 'level')::integer, v_item ->> 'description');
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;
revoke execute on function app.update_review_level_descs(uuid, jsonb) from public, anon, authenticated;
grant execute on function app.update_review_level_descs(uuid, jsonb) to authenticated;
