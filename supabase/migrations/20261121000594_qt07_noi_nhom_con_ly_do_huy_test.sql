-- QT-07 (thẻ Chat 22:09, Design đợt 2; anh Trường duyệt 5 quyết định 20/11; migration 594): danh mục «Lý do huỷ test» (TEST_CANCEL_REASON): ô «Nối nhóm con» bắt buộc chọn.
-- Luật: R-CRM-06 (huỷ test nối một nhóm con L5, trừ «Tạo phiếu sai»), R-V2-02, spec 06 dòng 13.
--  (1) Thêm mục vào TEST_CANCEL_REASON: phải chọn một nhóm con của Giai đoạn cơ hội trong L5C đến L5O ĐANG DÙNG, hoặc chọn tường minh «Không nối nhóm con» (p_no_link = true,
--      chỉ dùng cho lý do không đổi giai đoạn, như «Tạo phiếu sai»). Thiếu cả hai, chọn cả hai, hoặc nhóm con ngoài L5C–L5O (L5A, L5B, L5P, L5Q) / đã Ngừng: bị chặn (kiểm ở DB, không chỉ ở giao diện).
--  (2) Không sửa mục nối sau khi tạo: trigger chặn đổi linked_item_id của mục TEST_CANCEL_REASON (trừ migration). Nối sai thì Ngừng mục và tạo mục mới; cơ hội đã huỷ giữ nhóm con cũ.
--  (3) app.list_test_cancel_link_options(): danh sách nhóm con cho ô chọn (Admin xem). (4) app.get_catalog_tree trả thêm linked_item_id, linked_code, linked_name cho cột «Nối nhóm con».
-- Không bảng mới, không chỉ mục mới (danh mục vài chục dòng, tra theo khoá chính và (catalog_code, code) có sẵn).

-- Nhóm con được phép nối với một lý do huỷ test: L5C đến L5O của Giai đoạn cơ hội (OPP_SUBSTAGE), đang dùng. Dùng chung cho ô chọn và kiểm ở catalog_add_item.
create or replace function app.is_test_cancel_link_allowed(p_item_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select from app.catalog_item i
                  where i.id = p_item_id and i.catalog_code = 'OPP_SUBSTAGE' and i.is_active
                    and i.code ~ '^L5[C-O]$');
$$;
revoke execute on function app.is_test_cancel_link_allowed(uuid) from public, anon, authenticated;

-- Danh sách nhóm con cho ô «Nối nhóm con». Ai gọi: Admin (Quản trị · Xem). Kết quả: mảng {id, code, name} theo thứ tự nhóm con.
create or replace function app.list_test_cancel_link_options()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên được xem danh mục.');
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'code', i.code, 'name', i.name) order by i.sort_order, i.code)
                     from app.catalog_item i
                    where i.catalog_code = 'OPP_SUBSTAGE' and i.is_active and i.code ~ '^L5[C-O]$'), '[]'::jsonb);
end;
$$;
revoke execute on function app.list_test_cancel_link_options() from public, anon;
grant execute on function app.list_test_cancel_link_options() to authenticated;

-- Thêm mục vào danh mục mở (thay bản 084: thêm tham số p_no_link và luật nối nhóm con của TEST_CANCEL_REASON). Ai gọi: Admin (assert_config_writer).
-- Đầu vào: danh mục, mã, tên, thứ tự (trống thì đặt cuối), mục cha, mục nối, p_no_link (chỉ cho Lý do huỷ test: «Không nối nhóm con»). Kết quả: id mục mới.
drop function if exists app.catalog_add_item(text, text, text, integer, uuid, uuid);
create or replace function app.catalog_add_item(
  p_catalog_code text, p_code text, p_name text,
  p_sort_order integer default null, p_parent_id uuid default null, p_linked_item_id uuid default null,
  p_no_link boolean default false)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_name text := btrim(coalesce(p_name, ''));
begin
  perform app.assert_config_writer();
  -- Luật: tên hiển thị bắt buộc.
  if v_name = '' then
    perform app.raise_error('HMT_TEN_TRONG', 'Nhập tên hiển thị.');
  end if;
  -- Luật: mã viết hoa, không dấu (chữ A-Z, số, gạch dưới; không bắt đầu bằng gạch dưới).
  if v_code !~ '^[A-Z0-9][A-Z0-9_]*$' then
    perform app.raise_error('HMT_MA_SAI_DANG', 'Mã chỉ gồm chữ viết hoa không dấu, số và gạch dưới, không bắt đầu bằng gạch dưới.');
  end if;
  -- Luật: mã không trùng trong danh mục (mã Ngừng cũng tính, vì mã không đổi và không xoá).
  if exists (select from app.catalog_item where catalog_code = p_catalog_code and code = v_code) then
    perform app.raise_error('HMT_MA_TRUNG', format('Mã %s đã có trong danh mục này.', v_code));
  end if;
  -- Luật (anh Trường 20/11, spec 06 dòng 13): Lý do huỷ test bắt buộc chọn nhóm con L5C–L5O đang dùng, hoặc «Không nối nhóm con» tường minh.
  if p_catalog_code = 'TEST_CANCEL_REASON' then
    if p_no_link and p_linked_item_id is not null then
      perform app.raise_error('HMT_NOI_NHOM_CON_MAU_THUAN', 'Chọn một nhóm con hoặc «Không nối nhóm con», không chọn cả hai.');
    end if;
    if not p_no_link and p_linked_item_id is null then
      perform app.raise_error('HMT_THIEU_NOI_NHOM_CON', 'Chọn nhóm con cần nối, hoặc chọn «Không nối nhóm con».');
    end if;
    -- Mục không thuộc Giai đoạn cơ hội thì để trigger catalog_item_rules báo HMT_MUC_NOI_SAI như trước; mục thuộc giai đoạn nhưng ngoài L5C–L5O (hoặc đã Ngừng) thì báo ở đây.
    if p_linked_item_id is not null and not app.is_test_cancel_link_allowed(p_linked_item_id)
       and exists (select from app.catalog_item where id = p_linked_item_id and catalog_code = 'OPP_SUBSTAGE') then
      perform app.raise_error('HMT_NOI_NHOM_CON_SAI', 'Chỉ nối được nhóm con L5C đến L5O đang dùng.');
    end if;
  end if;
  insert into app.catalog_item (catalog_code, code, name, sort_order, parent_id, linked_item_id)
  values (p_catalog_code, v_code, v_name,
          coalesce(p_sort_order,
                   (select coalesce(max(sort_order), 0) + 1 from app.catalog_item
                     where catalog_code = p_catalog_code and parent_id is not distinct from p_parent_id)),
          p_parent_id, p_linked_item_id)
  returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function app.catalog_add_item(text, text, text, integer, uuid, uuid, boolean) from public, anon;
grant execute on function app.catalog_add_item(text, text, text, integer, uuid, uuid, boolean) to authenticated;

-- Luật: không sửa mục nối sau khi tạo (anh Trường 20/11). Nối sai thì Ngừng mục và tạo mục mới.
create or replace function app.tg_test_cancel_link_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.catalog_code = 'TEST_CANCEL_REASON' and new.linked_item_id is distinct from old.linked_item_id and not app.is_migration() then
    perform app.raise_error('HMT_NOI_NHOM_CON_KHONG_SUA', 'Không sửa nhóm con đã nối. Nối sai thì Ngừng mục này và tạo mục mới.');
  end if;
  return new;
end;
$$;
drop trigger if exists test_cancel_link_immutable on app.catalog_item;
create trigger test_cancel_link_immutable before update on app.catalog_item
  for each row execute function app.tg_test_cancel_link_immutable();

create or replace function app.get_catalog_tree(p_root_code text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_root app.catalog%rowtype;
begin
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên được xem danh mục.');
  end if;
  select * into v_root from app.catalog where code = p_root_code and parent_catalog is null;
  if v_root.code is null then
    perform app.raise_error('HMT_DANH_MUC_KHONG_CO', 'Không tìm thấy danh mục.');
  end if;
  return jsonb_build_object(
    'root', jsonb_build_object('code', v_root.code, 'name', v_root.name, 'kind', v_root.kind,
                               'is_read_only', v_root.is_read_only, 'description', v_root.description),
    'levels', (with recursive tree as (
                 select c.code, c.name, 0 as depth, c.sort_order from app.catalog c where c.code = v_root.code
                 union all
                 select c.code, c.name, t.depth + 1, c.sort_order from app.catalog c join tree t on c.parent_catalog = t.code)
               select jsonb_agg(jsonb_build_object('code', code, 'name', name) order by depth, sort_order) from tree),
    'items', coalesce((
      with recursive tree as (
        select c.code from app.catalog c where c.code = v_root.code
        union all
        select c.code from app.catalog c join tree t on c.parent_catalog = t.code)
      select jsonb_agg(jsonb_build_object('id', i.id, 'catalog_code', i.catalog_code, 'code', i.code, 'name', i.name,
                                          'sort_order', i.sort_order, 'is_active', i.is_active, 'is_locked', i.is_locked,
                                          'parent_id', i.parent_id,
                                          'linked_item_id', i.linked_item_id,
                                          'linked_code', l.code, 'linked_name', l.name)
                       order by i.sort_order, i.id)
        from app.catalog_item i left join app.catalog_item l on l.id = i.linked_item_id
         where i.catalog_code in (select code from tree)
    ), '[]'::jsonb));
end;
$$;

revoke execute on function app.get_catalog_tree(text) from public, anon;
grant execute on function app.get_catalog_tree(text) to authenticated;
