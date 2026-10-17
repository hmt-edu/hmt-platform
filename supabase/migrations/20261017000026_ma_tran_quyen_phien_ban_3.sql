-- P3b1: ma trận quyền phiên bản 3 (anh Trường duyệt 17/10, "OK ĐƯA VÀO LUẬT"): 15 ô cho Tuyển sinh và CSKH.
--   - Giao việc trên Lead, Cơ hội (Tuyển sinh, CSKH): giao người phụ trách (TS-05).
--   - Huỷ trên Kiểm tra đầu vào (Tuyển sinh, CSKH): ai cũng huỷ được phiếu (R-CRM-06).
--   - Giao việc trên Kiểm tra đầu vào cho CSKH (Tuyển sinh đã có).
--   - Duyệt trên Lead, Cơ hội, Phụ huynh, Học sinh (Tuyển sinh, CSKH): "Duyệt" ở các phân hệ này nghĩa là gộp trùng (R-CRM-22).
-- Tất cả phạm vi cơ sở mình. Nạp bằng hàm lưu của PR 6d nên là phiên bản 3, có danh sách từng ô và ghi chú.

select set_config('hmt.migration', 'on', false);

-- Phiên bản có thêm ghi chú tuỳ chọn (cột note đã có từ PR 6d, trước đây chỉ phiên bản 1 dùng). Đổi chữ ký hàm lưu:
-- thêm tham số cuối p_note (mặc định rỗng), nên lời gọi hai tham số cũ vẫn chạy.
drop function app.save_permission_matrix(integer, jsonb);

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

-- Nạp 15 ô của phiên bản 3.
select app.save_permission_matrix(
  app.permission_current_version(),
  (select jsonb_agg(jsonb_build_object('role', v.role, 'module', v.module, 'action', v.action, 'scope', 'CO_SO'))
   from (values
     -- Tuyển sinh
     ('SALES', 'LEAD', 'GIAO_VIEC'), ('SALES', 'OPPORTUNITY', 'GIAO_VIEC'), ('SALES', 'STUDENT_TEST', 'HUY'),
     ('SALES', 'LEAD', 'DUYET'), ('SALES', 'OPPORTUNITY', 'DUYET'), ('SALES', 'PARENT', 'DUYET'), ('SALES', 'STUDENT', 'DUYET'),
     -- CSKH
     ('CSKH', 'LEAD', 'GIAO_VIEC'), ('CSKH', 'OPPORTUNITY', 'GIAO_VIEC'), ('CSKH', 'STUDENT_TEST', 'HUY'),
     ('CSKH', 'STUDENT_TEST', 'GIAO_VIEC'),
     ('CSKH', 'LEAD', 'DUYET'), ('CSKH', 'OPPORTUNITY', 'DUYET'), ('CSKH', 'PARENT', 'DUYET'), ('CSKH', 'STUDENT', 'DUYET')
   ) as v(role, module, action)),
  'Duyệt trên Lead, Cơ hội, Phụ huynh, Học sinh = gộp trùng (R-CRM-22)');

comment on table app.permission is
  'Ma trận quyền. Sửa chỉ qua app.save_permission_matrix (mỗi lần một phiên bản). Quy ước: Duyệt trên LEAD, OPPORTUNITY, PARENT, STUDENT = gộp trùng (R-CRM-22).';

select set_config('hmt.migration', '', false);
