-- Code B (16/11/2026), Aftersale lát 6, migration 163: thêm, sửa, ngừng nhóm và nhóm con ticket (canvas 9189: CSN08_ds, CSN08_form_nhom_con).
-- Luật: docs/spec/de-xuat-luat-aftersale.md AS-05 (tính chất ticket giáo viên), AS-07 (hạn riêng), AS-08 (mức độ, đội mặc định), AS-10 (phiếu nghiệp vụ đi kèm).
-- Danh mục cấu hình: mã (code) không đổi, KHÔNG xoá, chỉ Ngừng (CLAUDE.md «Cấu hình»); mọi sửa ghi nhật ký qua trigger audit.
select set_config('hmt.migration', 'on', false);

-- app.save_ticket_category(dữ liệu): tạo mới (có «code» chưa tồn tại) hoặc sửa (code đã có) một nhóm hoặc nhóm con. Ai gọi: Quản trị · Sửa (Admin).
-- Dữ liệu (jsonb): code, name, kind (GROUP, SUBGROUP; chỉ khi tạo), parent_code (nhóm con; chỉ khi tạo), ticket_type (nhóm cha; chỉ khi tạo),
-- default_priority, default_team, business_type, nature_code (nhóm con ticket giáo viên), requires_student, requires_class, sort_order, is_active.
-- Luật: mã, loại, cấp, nhóm cha không đổi sau khi tạo; nhóm con lấy loại ticket của nhóm cha; tính chất chỉ ở ticket giáo viên; đội mặc định phải là mục đang dùng của danh mục TICKET_TEAM.
-- Ngừng nhóm cha thì ngừng luôn các nhóm con (không tạo ticket mới vào nhóm đã ngừng; ticket cũ giữ nguyên). Bật lại nhóm cha không tự bật lại nhóm con.
-- Kết quả: {code, created}.
create or replace function app.save_ticket_category(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text := nullif(btrim(coalesce(p_data ->> 'code', '')), '');
  c app.ticket_category;
  v_parent app.ticket_category;
  v_created boolean := false;
  v_kind text;
  v_type text;
  v_team text;
  v_priority text;
  v_active boolean;
begin
  perform app.assert_can('ADMIN', 'SUA', null);
  if v_code is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Cần có mã nhóm.');
  end if;
  select * into c from app.ticket_category where code = v_code for update;
  if c.id is null then
    -- Luật: tạo mới. Nhóm con lấy loại từ nhóm cha đang dùng.
    v_created := true;
    v_kind := coalesce(nullif(p_data ->> 'kind', ''), 'SUBGROUP');
    if v_kind not in ('GROUP', 'SUBGROUP') then
      perform app.raise_error('HMT_NHOM_SAI', 'Cấp phải là Nhóm hoặc Nhóm con.');
    end if;
    if nullif(btrim(coalesce(p_data ->> 'name', '')), '') is null then
      perform app.raise_error('HMT_THIEU_THONG_TIN', 'Cần có tên nhóm.');
    end if;
    if v_kind = 'SUBGROUP' then
      select * into v_parent from app.ticket_category where code = p_data ->> 'parent_code' and kind = 'GROUP' and is_active;
      if v_parent.id is null then
        perform app.raise_error('HMT_NHOM_SAI', 'Nhóm con phải thuộc một nhóm đang dùng.');
      end if;
      v_type := v_parent.ticket_type;
    else
      v_type := p_data ->> 'ticket_type';
      if v_type is null or v_type not in ('DN', 'KN', 'GV') then
        perform app.raise_error('HMT_TICKET_LOAI_SAI', 'Nhóm phải thuộc một loại ticket: Đề nghị, Khiếu nại hoặc Ticket giáo viên.');
      end if;
    end if;
    insert into app.ticket_category (code, name, kind, parent_code, ticket_type, sort_order)
    values (v_code, btrim(p_data ->> 'name'), v_kind, case when v_kind = 'SUBGROUP' then v_parent.code end, v_type,
            coalesce(nullif(p_data ->> 'sort_order', '')::integer, 0))
    returning * into c;
  else
    -- Luật: mã, cấp, loại, nhóm cha không đổi.
    if (p_data ? 'kind' and p_data ->> 'kind' <> c.kind) or (p_data ? 'ticket_type' and p_data ->> 'ticket_type' <> c.ticket_type)
       or (p_data ? 'parent_code' and nullif(p_data ->> 'parent_code', '') is distinct from c.parent_code) then
      perform app.raise_error('HMT_NHOM_KHONG_DOI', 'Không đổi được cấp, loại ticket hay nhóm cha của nhóm đã tạo.');
    end if;
  end if;
  -- Luật: nhóm cha không có mức độ, tính chất, phiếu nghiệp vụ (ràng buộc của bảng); chỉ nhóm con mới đặt các ô này.
  if c.kind = 'GROUP' and (p_data ? 'default_priority' or p_data ? 'business_type' or p_data ? 'nature_code') then
    perform app.raise_error('HMT_NHOM_SAI', 'Mức độ, tính chất, phiếu nghiệp vụ chỉ đặt ở nhóm con.');
  end if;
  -- Luật AS-05: tính chất chỉ cho ticket giáo viên.
  if p_data ? 'nature_code' and nullif(p_data ->> 'nature_code', '') is not null and c.ticket_type <> 'GV' then
    perform app.raise_error('HMT_NHOM_SAI', 'Tính chất chỉ có ở ticket giáo viên.');
  end if;
  -- Luật AS-08: đội mặc định là mục đang dùng của danh mục đội.
  if p_data ? 'default_team' then
    v_team := nullif(p_data ->> 'default_team', '');
    if v_team is not null then
      perform app.assert_catalog_code_active('TICKET_TEAM', v_team);
    end if;
  else
    v_team := c.default_team;
  end if;
  if p_data ? 'default_priority' then
    v_priority := nullif(p_data ->> 'default_priority', '');
    if v_priority is not null then
      perform app.assert_catalog_code_active('TICKET_PRIORITY', v_priority);
    end if;
  else
    v_priority := c.default_priority;
  end if;
  v_active := coalesce(nullif(p_data ->> 'is_active', '')::boolean, c.is_active);
  update app.ticket_category set
    name = coalesce(nullif(btrim(coalesce(p_data ->> 'name', '')), ''), name),
    default_priority = v_priority,
    default_team = v_team,
    business_type = case when p_data ? 'business_type' then nullif(p_data ->> 'business_type', '') else business_type end,
    nature_code = case when p_data ? 'nature_code' then nullif(p_data ->> 'nature_code', '') else nature_code end,
    requires_student = coalesce(nullif(p_data ->> 'requires_student', '')::boolean, requires_student),
    requires_class = coalesce(nullif(p_data ->> 'requires_class', '')::boolean, requires_class),
    sort_order = coalesce(nullif(p_data ->> 'sort_order', '')::integer, sort_order),
    is_active = v_active
   where id = c.id;
  -- Luật: ngừng nhóm cha thì ngừng các nhóm con.
  if c.kind = 'GROUP' and c.is_active and not v_active then
    update app.ticket_category set is_active = false where parent_code = c.code and is_active;
  end if;
  return jsonb_build_object('code', c.code, 'created', v_created);
end;
$$;
revoke execute on function app.save_ticket_category(jsonb) from public, anon, authenticated;
grant execute on function app.save_ticket_category(jsonb) to authenticated;

select set_config('hmt.migration', '', false);
