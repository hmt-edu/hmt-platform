-- QT-05 Ma trận quyền: chốt an toàn trước khi bật màn sửa ma trận ở bản chạy thật (Chat 16/11 07:00, mức CAO).
--  (1) Cờ tham số permission_matrix_edit_enabled, mặc định TẮT: hàm save_permission_matrix qua API chỉ chạy khi Admin bật ở Cài đặt tham số (HMT_TINH_NANG_TAT).
--  (2) Không tự khoá hệ thống: ĐÃ CÓ từ migration 022 (trigger tg_permission_admin_keeps_admin: ADMIN luôn giữ đủ quyền phân hệ Quản trị ở toàn hệ thống, lần lưu nào bỏ hoặc thu hẹp
--      thì báo HMT_ADMIN_GIU_QUYEN_QUAN_TRI và hoàn tác cả lần lưu). Migration này không thêm lại, chỉ thêm bài kiểm qua hàm lưu.
-- Các điều kiện còn lại đã có sẵn: kiểm quyền Quản trị · Sửa ở DB (assert_config_writer), lịch sử mỗi phiên bản (permission_version, permission_change: ai, lúc nào, trước, sau).

select set_config('hmt.migration', 'on', false);
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('permission_matrix_edit_enabled', 'Cho phép sửa ma trận quyền', 'BOOL', null, null, null, 'false', false, 'ADMIN', 'S03-07',
   'Tắt: màn Ma trận quyền chỉ xem, không lưu được. Bật: Admin (đã xác thực hai bước) lưu được phiên bản mới, có hiệu lực ngay. Mặc định tắt cho tới khi anh bật.');

-- Chốt (1): hàm lưu kiểm cờ (cùng thân với migration 026, thêm đoạn kiểm cờ sau kiểm quyền).
create or replace function app.save_permission_matrix(p_base_version integer, p_changes jsonb, p_note text default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current integer;
  v_new_no integer;
  v_version_id uuid;
  v_count integer;
  v_cell record;
  v_eff jsonb;
begin
  perform app.assert_config_writer();

  -- Luật (cờ, QT-05): qua API (giao diện) chỉ lưu được khi Admin đã bật tham số permission_matrix_edit_enabled (mặc định TẮT, đổi ở Cài đặt tham số).
  -- Chạy từ migration hoặc SQL Editor của chủ project (không JWT) thì không bị chặn.
  if nullif(auth.role(), '') is not null and not app.get_setting_bool('permission_matrix_edit_enabled') then
    perform app.raise_error('HMT_TINH_NANG_TAT',
      'Sửa ma trận quyền đang tắt. Bật tham số "Cho phép sửa ma trận quyền" ở Cài đặt tham số rồi thử lại.');
  end if;

  -- Chỉ một người lưu tại một thời điểm.
  perform pg_advisory_xact_lock(hashtext('app.permission_matrix'));

  -- Luật (1): phiên bản đang xem phải là hiện hành.
  v_current := app.permission_current_version();
  if p_base_version is distinct from v_current then
    perform app.raise_error('HMT_PHIEN_BAN_CU',
      format('Ma trận quyền vừa được lưu thành phiên bản %s. Hãy tải lại rồi sửa tiếp.', v_current));
  end if;

  if p_changes is null or jsonb_typeof(p_changes) <> 'array' or jsonb_array_length(p_changes) = 0 then
    perform app.raise_error('HMT_KHONG_CO_THAY_DOI', 'Chưa có ô quyền nào thay đổi.');
  end if;

  -- Luật (3): một ô không xuất hiện hai lần; vai trò, phân hệ, hành động, phạm vi phải có trong danh mục.
  if exists (select from jsonb_array_elements(p_changes) e
             group by e ->> 'role', e ->> 'module', e ->> 'action' having count(*) > 1) then
    perform app.raise_error('HMT_O_QUYEN_SAI', 'Một ô quyền xuất hiện hai lần trong cùng lần lưu.');
  end if;
  select e ->> 'role' as role, e ->> 'module' as module, e ->> 'action' as action into v_cell
  from jsonb_array_elements(p_changes) e
  where not exists (select from app.role where code = e ->> 'role')
     or not exists (select from app.catalog_item where catalog_code = 'PERM_MODULE' and code = e ->> 'module')
     or not exists (select from app.catalog_item where catalog_code = 'PERM_ACTION' and code = e ->> 'action')
     or (nullif(e ->> 'scope', '') is not null
         and not exists (select from app.catalog_item where catalog_code = 'PERM_SCOPE' and code = e ->> 'scope'))
  limit 1;
  if v_cell.role is not null or v_cell.module is not null or v_cell.action is not null then
    perform app.raise_error('HMT_O_QUYEN_SAI',
      format('Ô quyền không hợp lệ: vai trò %s, phân hệ %s, hành động %s.', v_cell.role, v_cell.module, v_cell.action));
  end if;

  -- Chỉ giữ ô đổi thật, kèm phạm vi cũ (rỗng nếu chưa có hoặc đang tắt).
  select coalesce(jsonb_agg(jsonb_build_object(
           'role', r.role_code, 'module', r.module_code, 'action', r.action_code,
           'from', case when p.is_active then p.scope_code end, 'to', r.scope_code)), '[]'::jsonb)
    into v_eff
  from (select e ->> 'role' as role_code, e ->> 'module' as module_code, e ->> 'action' as action_code,
               nullif(e ->> 'scope', '') as scope_code
        from jsonb_array_elements(p_changes) e) r
  left join app.permission p
    on p.role_code = r.role_code and p.module_code = r.module_code and p.action_code = r.action_code
  where (case when p.is_active then p.scope_code end) is distinct from r.scope_code;

  -- Luật (2): phải có ô đổi thật.
  v_count := jsonb_array_length(v_eff);
  if v_count = 0 then
    perform app.raise_error('HMT_KHONG_CO_THAY_DOI', 'Không có ô quyền nào khác với hiện tại.');
  end if;

  -- Áp ngay từng ô (luật 4 và luật ADMIN giữ quyền Quản trị nằm trong trigger bảng quyền); lỗi ở ô nào thì hoàn tác cả lần lưu.
  for v_cell in select e ->> 'role' as role, e ->> 'module' as module, e ->> 'action' as action, e ->> 'to' as to_scope
                from jsonb_array_elements(v_eff) e loop
    perform app.set_permission(v_cell.role, v_cell.module, v_cell.action, v_cell.to_scope);
  end loop;

  -- Ghi phiên bản (kèm ghi chú nếu có) và các ô đã đổi, cùng giao dịch.
  v_new_no := v_current + 1;
  insert into app.permission_version (version_no, saved_by, changed_count, note)
  values (v_new_no, auth.uid(), v_count, nullif(btrim(coalesce(p_note, '')), ''))
  returning id into v_version_id;

  insert into app.permission_change (version_id, role_code, module_code, action_code, from_scope, to_scope)
  select v_version_id, e ->> 'role', e ->> 'module', e ->> 'action', e ->> 'from', e ->> 'to'
  from jsonb_array_elements(v_eff) e;

  return v_new_no;
end;
$$;

revoke execute on function app.save_permission_matrix(integer, jsonb, text) from public, anon;
grant execute on function app.save_permission_matrix(integer, jsonb, text) to authenticated;
