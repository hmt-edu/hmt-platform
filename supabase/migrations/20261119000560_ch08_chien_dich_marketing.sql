-- CH-08 Chiến dịch marketing (Code F, 19/11/2026; thẻ F9; anh Trường chốt 19/11): MỌI vai trò vào được cổng CRM đều xem và TẠO được chiến dịch;
-- Ngừng và Dùng lại: Admin hoặc người tạo chiến dịch (đề xuất, chờ Chat xác nhận). Chiến dịch gắn vào lead (bảng app.campaign, migration 24); dùng chung mọi cơ sở.
-- Luật R-CRM-11 (giữ chiến dịch marketing như bản cũ). Mức vừa: có hàm ghi, quyền theo cổng chứ không theo ma trận quyền. Không xoá, chỉ Ngừng.
-- Làm gì: app.list_campaigns (phân trang máy chủ, lọc tên và tình trạng, số lead gắn), app.create_campaign, app.set_campaign_active.
select set_config('hmt.migration', 'on', false);

-- Người gọi là người dùng cổng CRM: đăng nhập, chưa khoá, có ít nhất một vai trò đang dùng được vào cổng crm (không tính giáo viên, trợ giảng, học sinh, phụ huynh).
create or replace function app.is_crm_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select app.current_user_ready()
         and exists (select from app.user_role ur join app.role r on r.code = ur.role_code
                      where ur.user_id = auth.uid() and ur.is_active and 'crm' = any (r.portals));
$$;
revoke execute on function app.is_crm_user() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- app.list_campaigns(bộ lọc, số dòng, bỏ qua): {total, rows[{id, name, starts_on, ends_on, is_active, lead_count, created_by_name, can_toggle}]}.
-- Bộ lọc (jsonb, tuỳ chọn): q (tên chứa), status (DANG_DUNG hoặc NGUNG). Mới tạo trước. Số dòng mặc định list_page_size_default, tối đa list_page_size_max.
-- Ai gọi: mọi người dùng cổng CRM.
-- ---------------------------------------------------------------------------
create or replace function app.list_campaigns(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(coalesce(p_limit, app.get_setting_int('list_page_size_default')), app.get_setting_int('list_page_size_max'));
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_status text := nullif(p_filters ->> 'status', '');
  v_admin boolean := 'ADMIN' = any (app.current_roles());
  v_total bigint;
  v_rows jsonb;
begin
  -- Luật quyền: mọi vai trò vào được cổng CRM.
  if not app.is_crm_user() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem chiến dịch.');
  end if;
  if v_status is not null and v_status not in ('DANG_DUNG', 'NGUNG') then
    perform app.raise_error('HMT_LOC_KHONG_HOP_LE', 'Tình trạng lọc không hợp lệ.');
  end if;
  with f as (
    select c.* from app.campaign c
     where (v_q is null or c.name ilike '%' || v_q || '%')
       and (v_status is null or c.is_active = (v_status = 'DANG_DUNG'))
  )
  select (select count(*) from f),
         coalesce((select jsonb_agg(jsonb_build_object(
                     'id', x.id, 'name', x.name, 'starts_on', x.starts_on, 'ends_on', x.ends_on, 'is_active', x.is_active,
                     'lead_count', (select count(*) from app.lead l where l.campaign_id = x.id),
                     'created_by_name', app.staff_display_name(x.created_by),
                     'can_toggle', v_admin or x.created_by = auth.uid())
                   order by x.created_at desc, x.id)
                     from (select * from f order by created_at desc, id limit v_limit offset greatest(coalesce(p_offset, 0), 0)) x), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- ---------------------------------------------------------------------------
-- app.create_campaign(tên, ngày bắt đầu, ngày kết thúc): tạo chiến dịch; ai gọi: mọi người dùng cổng CRM (anh Trường chốt 19/11). Kết quả {id}.
-- Luật: tên bắt buộc, không trùng (không phân biệt hoa thường); ngày kết thúc không trước ngày bắt đầu (cả hai tuỳ chọn).
-- ---------------------------------------------------------------------------
create or replace function app.create_campaign(p_name text, p_starts_on date default null, p_ends_on date default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
  v_id uuid;
begin
  if not app.is_crm_user() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền tạo chiến dịch.');
  end if;
  if v_name is null then
    perform app.raise_error('HMT_CHIEN_DICH_TEN', 'Nhập tên chiến dịch.');
  end if;
  if p_starts_on is not null and p_ends_on is not null and p_ends_on < p_starts_on then
    perform app.raise_error('HMT_CHIEN_DICH_NGAY_SAI', 'Ngày kết thúc không được trước ngày bắt đầu.');
  end if;
  if exists (select from app.campaign where lower(name) = lower(v_name)) then
    perform app.raise_error('HMT_CHIEN_DICH_TRUNG', 'Đã có chiến dịch trùng tên này.');
  end if;
  insert into app.campaign (name, starts_on, ends_on) values (v_name, p_starts_on, p_ends_on) returning id into v_id;
  return jsonb_build_object('id', v_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- app.set_campaign_active(id, true/false): Ngừng hoặc Dùng lại. Ai gọi: Admin hoặc người tạo chiến dịch. Lead cũ giữ chiến dịch đã gắn; chiến dịch Ngừng
-- không còn chọn được ở lead mới (hàm tạo, sửa lead kiểm is_active).
-- ---------------------------------------------------------------------------
create or replace function app.set_campaign_active(p_id uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c app.campaign;
begin
  if not app.is_crm_user() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền đổi tình trạng chiến dịch.');
  end if;
  select * into c from app.campaign where id = p_id for update;
  if c.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy chiến dịch.');
  end if;
  -- Luật: Admin hoặc người tạo.
  if not ('ADMIN' = any (app.current_roles()) or c.created_by = auth.uid()) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ Admin hoặc người tạo chiến dịch được ngừng hay dùng lại.');
  end if;
  update app.campaign set is_active = coalesce(p_active, true) where id = p_id;
end;
$$;

revoke execute on function app.list_campaigns(jsonb, integer, integer), app.create_campaign(text, date, date), app.set_campaign_active(uuid, boolean) from public, anon;
grant execute on function app.list_campaigns(jsonb, integer, integer), app.create_campaign(text, date, date), app.set_campaign_active(uuid, boolean) to authenticated;
