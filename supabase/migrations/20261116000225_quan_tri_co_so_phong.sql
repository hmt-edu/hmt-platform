-- Code B (16/11/2026), QT-08 Cơ sở và phòng học, migration 225: hàm cho Admin sửa tên hiển thị, địa chỉ cơ sở; thêm, sửa, ngừng, dùng lại phòng học.
-- Luật: docs/nghiep-vu/doi-chieu-canvas-quan-tri-v2.md mục 12 (canvas dc47 QT08_*), spec 06 (cơ sở là danh mục khoá), R-V2-10 (CS3 là cơ sở dạy học).
-- Cơ sở: KHÔNG thêm, KHÔNG ngừng ở giao diện, mã không đổi (trigger sẵn); chỉ sửa tên hiển thị và địa chỉ (≤ 200 ký tự). Mở cơ sở mới làm bằng migration.
-- Phòng: thêm (mã chữ hoa/số/gạch dưới, không trùng trong cơ sở, không đổi sau khi tạo; tên không trùng trong cơ sở; sức chứa số lớn hơn 0); sửa tên và sức chứa;
-- Ngừng (không hiện ở ô chọn phòng mới, dữ liệu cũ giữ nguyên) và Dùng lại. Không xoá phòng. Mọi sửa ghi nhật ký qua trigger audit của apply_standard.
-- Quyền: Quản trị · Sửa (Admin). Bảng branch, room không cấp ghi trực tiếp cho người dùng (chỉ đọc), nên chỉ đi qua các hàm này.
select set_config('hmt.migration', 'on', false);

-- app.update_branch_info(mã cơ sở, tên hiển thị, địa chỉ): sửa tên hiển thị và địa chỉ của một cơ sở. Ai gọi: Quản trị · Sửa.
-- Luật: tên không rỗng; địa chỉ tối đa 200 ký tự (trống thì xoá địa chỉ); mã, trạng thái dùng, văn phòng/dạy học không đổi ở đây.
create or replace function app.update_branch_info(p_id uuid, p_name text, p_address text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
  v_address text := nullif(btrim(coalesce(p_address, '')), '');
begin
  perform app.assert_can('ADMIN', 'SUA', null);
  if not exists (select from app.branch where id = p_id) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ sở.');
  end if;
  -- Luật: tên hiển thị bắt buộc.
  if v_name is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập tên hiển thị của cơ sở.');
  end if;
  -- Luật: địa chỉ một dòng, tối đa 200 ký tự.
  if v_address is not null and char_length(v_address) > 200 then -- allow-number: giới hạn độ dài địa chỉ theo canvas QT08_sua_co_so
    perform app.raise_error('HMT_DIA_CHI_QUA_DAI', 'Địa chỉ tối đa 200 ký tự.');
  end if;
  update app.branch set name = v_name, address = v_address where id = p_id;
end;
$$;

-- app.save_room(dữ liệu): thêm phòng (không có id) hoặc sửa phòng (có id). Ai gọi: Quản trị · Sửa.
-- Dữ liệu (jsonb): id (sửa), branch_id và code (thêm), name, capacity. Mã phòng và cơ sở không đổi sau khi tạo (trigger sẵn có).
-- Luật: mã chỉ chữ hoa, số, gạch dưới, không trùng trong cơ sở; tên không rỗng và không trùng trong cơ sở (không phân biệt hoa thường, dấu);
-- sức chứa là số nguyên lớn hơn 0; cơ sở phải là cơ sở dạy học (trigger sẵn có). Kết quả {id, created}.
create or replace function app.save_room(p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := nullif(p_data ->> 'id', '')::uuid;
  v_name text := nullif(btrim(coalesce(p_data ->> 'name', '')), '');
  v_capacity integer;
  v_code text := nullif(btrim(coalesce(p_data ->> 'code', '')), '');
  v_branch uuid := nullif(p_data ->> 'branch_id', '')::uuid;
  r app.room;
  v_created boolean := false;
begin
  perform app.assert_can('ADMIN', 'SUA', null);
  -- Luật: tên và sức chứa bắt buộc.
  if v_name is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Nhập tên phòng.');
  end if;
  begin
    v_capacity := nullif(p_data ->> 'capacity', '')::integer;
  exception when others then
    v_capacity := null;
  end;
  if v_capacity is null or v_capacity <= 0 then
    perform app.raise_error('HMT_PHONG_SUC_CHUA_SAI', 'Nhập sức chứa, là số nguyên lớn hơn 0.');
  end if;
  if v_id is null then
    -- Thêm phòng.
    if v_branch is null or not exists (select from app.branch where id = v_branch) then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy cơ sở.');
    end if;
    if v_code is null or v_code !~ '^[A-Z0-9][A-Z0-9_]*$' then
      perform app.raise_error('HMT_PHONG_MA_SAI', 'Mã phòng chỉ gồm chữ viết hoa, số và dấu gạch dưới (ví dụ P101).');
    end if;
    if exists (select from app.room where branch_id = v_branch and code = v_code) then
      perform app.raise_error('HMT_PHONG_MA_TRUNG', 'Mã phòng này đã có trong cơ sở.');
    end if;
    if exists (select from app.room where branch_id = v_branch and app.fold_text(name) = app.fold_text(v_name)) then
      perform app.raise_error('HMT_PHONG_TEN_TRUNG', 'Tên phòng này đã có trong cơ sở.');
    end if;
    insert into app.room (branch_id, code, name, capacity) values (v_branch, v_code, v_name, v_capacity) returning * into r;
    v_created := true;
  else
    -- Sửa phòng: chỉ tên và sức chứa.
    select * into r from app.room where id = v_id for update;
    if r.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phòng.');
    end if;
    if exists (select from app.room where branch_id = r.branch_id and id <> r.id and app.fold_text(name) = app.fold_text(v_name)) then
      perform app.raise_error('HMT_PHONG_TEN_TRUNG', 'Tên phòng này đã có trong cơ sở.');
    end if;
    update app.room set name = v_name, capacity = v_capacity where id = r.id;
  end if;
  return jsonb_build_object('id', r.id, 'created', v_created);
end;
$$;

-- app.set_room_active(mã phòng, dùng hay ngừng): Ngừng hoặc Dùng lại một phòng. Ai gọi: Quản trị · Sửa.
-- Luật: ngừng thì không hiện ở ô chọn phòng mới; dữ liệu cũ (lớp, buổi đã gắn phòng) giữ nguyên. Không xoá phòng.
create or replace function app.set_room_active(p_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_can('ADMIN', 'SUA', null);
  if p_active is null then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chọn Ngừng hoặc Dùng lại.');
  end if;
  update app.room set is_active = p_active where id = p_id;
  if not found then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phòng.');
  end if;
end;
$$;

revoke execute on function app.update_branch_info(uuid, text, text), app.save_room(jsonb), app.set_room_active(uuid, boolean) from public, anon, authenticated;
grant execute on function app.update_branch_info(uuid, text, text), app.save_room(jsonb), app.set_room_active(uuid, boolean) to authenticated;

select set_config('hmt.migration', '', false);
