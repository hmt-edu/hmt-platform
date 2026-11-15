-- QT-14 Ngày nghỉ lễ (Code C, 16/11/2026): hàm thêm, sửa, ngừng ngày nghỉ và xem các buổi bị ảnh hưởng.
-- Luật: R-LOP-12 (ngày nghỉ áp cho mọi cơ sở hoặc từng cơ sở; thêm ngày nghỉ sau khi đã sinh buổi thì xem trước các buổi bị ảnh hưởng, việc dời buổi làm ở màn buổi),
-- R-LOP-09 (ngày nghỉ dùng để tính ngày kết thúc lớp, app.is_holiday). Quyền: module HOLIDAY (Admin toàn hệ thống; Trưởng cơ sở trong cơ sở mình: Tạo, Sửa, Huỷ).
-- Ngày nghỉ chung (mọi cơ sở, branch_id rỗng) chỉ người có HOLIDAY ở phạm vi toàn hệ thống (Admin) mới thêm, sửa, ngừng. Không xoá cứng: ngừng là is_active = false.

-- Chỉ mục (lý do): xem buổi bị ảnh hưởng theo ngày học (class_session.session_date) và trang danh sách ngày nghỉ theo ngày.
create index if not exists class_session_date_idx on app.class_session (session_date);
create index if not exists holiday_date_idx on app.holiday (holiday_date);

-- app.save_holiday(id, ngày, tên, cơ sở): thêm (id rỗng) hoặc sửa một ngày nghỉ.
-- Ai gọi: HOLIDAY · Tạo (thêm) hoặc Sửa; trong cơ sở của ngày nghỉ, hoặc toàn hệ thống với ngày nghỉ chung. Không đổi cơ sở của ngày nghỉ đã có (ngừng rồi thêm mới).
-- Kết quả: {id, affected_sessions (số buổi chưa chốt, chưa huỷ trùng ngày này trong phạm vi), is_new}.
create or replace function app.save_holiday(p_id uuid, p_date date, p_name text, p_branch_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old app.holiday;
  v_id uuid;
  v_name text := btrim(coalesce(p_name, ''));
begin
  -- Luật: ngày và tên bắt buộc.
  if p_date is null then
    perform app.raise_error('HMT_THIEU_NGAY', 'Chọn ngày nghỉ.');
  end if;
  if v_name = '' then
    perform app.raise_error('HMT_THIEU_TEN', 'Nhập tên ngày nghỉ.');
  end if;
  if p_id is null then
    -- Thêm: quyền Tạo ở cơ sở (hoặc toàn hệ thống với ngày chung).
    if not app.can_see_branch('HOLIDAY', 'TAO', p_branch_id) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', case when p_branch_id is null then 'Chỉ Admin thêm ngày nghỉ chung cho mọi cơ sở.' else 'Bạn không thêm được ngày nghỉ của cơ sở này.' end);
    end if;
    -- Luật: mỗi (ngày, cơ sở) một dòng (unique); dòng đã Ngừng thì dùng lại thay vì thêm trùng.
    select * into v_old from app.holiday where holiday_date = p_date and branch_id is not distinct from p_branch_id for update;
    if v_old.id is not null and v_old.is_active then
      perform app.raise_error('HMT_NGAY_NGHI_TRUNG', 'Ngày này đã là ngày nghỉ' || case when p_branch_id is null then ' chung.' else ' của cơ sở.' end);
    end if;
    if v_old.id is not null then
      update app.holiday set name = v_name, is_active = true where id = v_old.id;
      v_id := v_old.id;
    else
      insert into app.holiday (holiday_date, name, branch_id) values (p_date, v_name, p_branch_id) returning id into v_id;
    end if;
  else
    select * into v_old from app.holiday where id = p_id for update;
    if v_old.id is null then
      perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ngày nghỉ.');
    end if;
    if not app.can_see_branch('HOLIDAY', 'SUA', v_old.branch_id) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không sửa được ngày nghỉ này.');
    end if;
    if p_branch_id is distinct from v_old.branch_id then
      perform app.raise_error('HMT_KHONG_DOI_CO_SO', 'Không đổi cơ sở của ngày nghỉ; ngừng ngày này rồi thêm ngày mới.');
    end if;
    if exists (select from app.holiday where holiday_date = p_date and branch_id is not distinct from v_old.branch_id and id <> p_id) then
      perform app.raise_error('HMT_NGAY_NGHI_TRUNG', 'Ngày này đã có trong bảng ngày nghỉ.');
    end if;
    update app.holiday set holiday_date = p_date, name = v_name where id = p_id;
    v_id := p_id;
  end if;
  return jsonb_build_object('id', v_id, 'is_new', p_id is null, 'affected_sessions', app.count_holiday_sessions(p_date, p_branch_id));
end;
$$;

-- app.set_holiday_active(id, bật): ngừng hoặc dùng lại một ngày nghỉ. Ai gọi: HOLIDAY · Huỷ (ngừng) hoặc Sửa (dùng lại), cùng phạm vi như save_holiday.
create or replace function app.set_holiday_active(p_id uuid, p_active boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v app.holiday;
begin
  select * into v from app.holiday where id = p_id for update;
  if v.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ngày nghỉ.');
  end if;
  if not app.can_see_branch('HOLIDAY', case when p_active then 'SUA' else 'HUY' end, v.branch_id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không đổi được ngày nghỉ này.');
  end if;
  update app.holiday set is_active = p_active where id = p_id;
  return jsonb_build_object('id', p_id, 'is_active', p_active, 'affected_sessions', app.count_holiday_sessions(v.holiday_date, v.branch_id));
end;
$$;

-- app.count_holiday_sessions(ngày, cơ sở): số buổi CHƯA diễn ra (Nháp, Đã chốt) trùng ngày này trong phạm vi (cơ sở rỗng = mọi cơ sở). Nội bộ.
create or replace function app.count_holiday_sessions(p_date date, p_branch_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from app.class_session s
   where s.session_date = p_date and s.status_code in ('NHAP', 'DA_CHOT')
     and (p_branch_id is null or s.branch_id = p_branch_id);
$$;

-- app.list_holiday_sessions(id ngày nghỉ): xem các buổi bị ảnh hưởng (R-LOP-12). Chỉ đọc; việc dời buổi làm ở màn buổi.
-- Ai gọi: HOLIDAY · Xem; chỉ thấy buổi của cơ sở mình (trừ toàn hệ thống). Tối đa `list_page_size_max` buổi (hộp xem trước), có tổng số.
create or replace function app.list_holiday_sessions(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v app.holiday;
  v_scope text := app.permission_scope('HOLIDAY', 'XEM');
  v_my_branch uuid := app.current_branch_id();
begin
  select * into v from app.holiday where id = p_id;
  if v.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy ngày nghỉ.');
  end if;
  if v_scope is null then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem ngày nghỉ.');
  end if;
  return (
    with f as (
      select s.id, s.session_date, s.start_time, s.end_time, s.status_code, c.id as class_id, c.code as class_code, b.code as branch_code
        from app.class_session s
        join app.class c on c.id = s.class_id
        join app.branch b on b.id = s.branch_id
       where s.session_date = v.holiday_date and s.status_code in ('NHAP', 'DA_CHOT')
         and (v.branch_id is null or s.branch_id = v.branch_id)
         and (v_scope = 'TOAN_HE_THONG' or s.branch_id = v_my_branch)
    )
    select jsonb_build_object(
      'total', (select count(*) from f),
      'rows', coalesce((select jsonb_agg(to_jsonb(x) order by x.start_time, x.class_code)
                          from (select * from f order by start_time, class_code limit app.get_setting_int('list_page_size_max')) x), '[]'::jsonb))
  );
end;
$$;

revoke execute on function app.save_holiday(uuid, date, text, uuid), app.set_holiday_active(uuid, boolean),
  app.count_holiday_sessions(date, uuid), app.list_holiday_sessions(uuid) from public, anon;
grant execute on function app.save_holiday(uuid, date, text, uuid), app.set_holiday_active(uuid, boolean),
  app.list_holiday_sessions(uuid) to authenticated;
