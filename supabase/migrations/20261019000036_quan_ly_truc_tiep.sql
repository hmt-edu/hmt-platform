-- Quản lý trực tiếp (docs/spec/04 R-HT-06; anh chốt 19/10): trường "Quản lý trực tiếp" của hồ sơ nhân viên và hàm xác định
-- người duyệt đơn hàng (và bước quản lý của phiếu thu, R-TIEN-01). Chưa có bảng đơn, phiếu thu: các hàm này để P5 gọi.

-- Cột quản lý trực tiếp: một nhân viên khác (tuỳ chọn). Nghỉ việc thì tài khoản khoá, cột giữ nguyên (Admin duyệt thay).
alter table app.user_account add column manager_id uuid references app.user_account (id);
comment on column app.user_account.manager_id is
  'Quản lý trực tiếp (R-HT-06): người duyệt đơn hàng của nhân viên này. Chỉ đổi qua app.set_manager (Admin).';
-- Tìm cấp dưới của một người và đi ngược chuỗi quản lý khi kiểm vòng (set_manager, tg_user_account_manager).
create index user_account_manager_idx on app.user_account (manager_id) where manager_id is not null;

-- ---------------------------------------------------------------------------
-- Luật toàn vẹn của cột manager_id (chạy cả khi ghi bằng quyền máy chủ):
-- (a) chỉ đổi được qua app.set_manager (cờ hmt.manager trong giao dịch) để luật quyền không bị đi vòng;
-- (b) không tự làm quản lý của chính mình; (c) không tạo vòng (A quản lý B, B quản lý A, hoặc chuỗi dài hơn);
-- (d) quản lý phải là nhân viên (không phải học sinh), học sinh không có quản lý; (e) quản lý đang hoạt động lúc gán.
-- ---------------------------------------------------------------------------
create or replace function app.tg_user_account_manager()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_cursor uuid;
  v_hops integer := 0;
  v_limit integer := (select count(*) from app.user_account);
begin
  -- Không đụng đến quản lý (thêm tài khoản không có quản lý, hoặc sửa trường khác): bỏ qua.
  if tg_op = 'UPDATE' and new.manager_id is not distinct from old.manager_id then
    return new;
  end if;
  if tg_op = 'INSERT' and new.manager_id is null then
    return new;
  end if;
  -- (a) Chỉ đổi qua hàm có kiểm quyền Admin.
  if coalesce(current_setting('hmt.manager', true), '') <> 'on' then
    perform app.raise_error('HMT_LUAT_LOI', 'Quản lý trực tiếp chỉ đổi qua màn Người dùng của Admin.');
  end if;
  if new.manager_id is null then
    return new;
  end if;
  -- (b) Không tự làm quản lý của mình.
  if new.manager_id = new.id then
    perform app.raise_error('HMT_QUAN_LY_TU_THAN', 'Không đặt chính người đó làm quản lý trực tiếp của mình.');
  end if;
  -- (d), (e) Quản lý là nhân viên đang hoạt động; học sinh không có quản lý.
  if new.student_code is not null then
    perform app.raise_error('HMT_QUAN_LY_SAI', 'Học sinh không có quản lý trực tiếp.');
  end if;
  if not exists (select from app.user_account m
                  where m.id = new.manager_id and m.student_code is null and not m.is_locked) then
    perform app.raise_error('HMT_QUAN_LY_SAI', 'Quản lý trực tiếp phải là nhân viên đang hoạt động.');
  end if;
  -- (c) Đi ngược chuỗi quản lý của người được chọn: gặp lại chính tài khoản này là có vòng.
  v_cursor := new.manager_id;
  while v_cursor is not null and v_hops <= v_limit loop
    if v_cursor = new.id then
      perform app.raise_error('HMT_QUAN_LY_VONG', 'Không đặt được: người này đang là cấp trên của quản lý được chọn (tạo vòng).');
    end if;
    select manager_id into v_cursor from app.user_account where id = v_cursor;
    v_hops := v_hops + 1;
  end loop;
  return new;
end;
$$;

create trigger user_account_manager before insert or update of manager_id on app.user_account
  for each row execute function app.tg_user_account_manager();

-- ---------------------------------------------------------------------------
-- Đặt hoặc bỏ quản lý trực tiếp. Ai gọi: Admin (quyền Quản trị · Sửa). Đầu vào: id nhân viên, id quản lý (rỗng = bỏ).
-- Luật kiểm trong trigger tg_user_account_manager. Mọi thay đổi ghi nhật ký (apply_standard của user_account).
-- ---------------------------------------------------------------------------
create or replace function app.set_manager(p_user_id uuid, p_manager_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Luật R-HT-06: chỉ Admin sửa Quản lý trực tiếp.
  if not app.has_permission('ADMIN', 'SUA') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ Admin sửa được quản lý trực tiếp.');
  end if;
  if not exists (select from app.user_account where id = p_user_id) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy tài khoản.');
  end if;
  perform set_config('hmt.manager', 'on', true);
  update app.user_account set manager_id = p_manager_id where id = p_user_id;
  perform set_config('hmt.manager', '', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Đường duyệt của một người lập (R-HT-06, R-TIEN-01). Gọi LÚC TRÌNH để chốt người duyệt (anh chốt 19/10: quản lý đổi sau
-- không đổi người duyệt). Kết quả: route 'QUAN_LY' (approver_id = quản lý trực tiếp lúc trình) hoặc 'TU_DUYET' (người lập là
-- Trưởng cơ sở, approver_id = chính người lập). Người lập không có quản lý và không phải Trưởng cơ sở: lỗi
-- HMT_KHONG_CO_QUAN_LY ("không trình được"). Trưởng cơ sở được xét trước: có quản lý hay không vẫn tự duyệt.
-- ---------------------------------------------------------------------------
create or replace function app.approval_route(p_creator_id uuid)
returns table (route text, approver_id uuid)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_manager uuid;
begin
  if not exists (select from app.user_account where id = p_creator_id and student_code is null) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy nhân viên lập.');
  end if;
  -- Luật R-HT-06: Trưởng cơ sở tự duyệt.
  if exists (select from app.user_role ur
              where ur.user_id = p_creator_id and ur.role_code = 'BRANCH_MANAGER' and ur.is_active) then
    return query select 'TU_DUYET'::text, p_creator_id;
    return;
  end if;
  select manager_id into v_manager from app.user_account where id = p_creator_id;
  -- Luật R-HT-06: không có quản lý trực tiếp (và không phải Trưởng cơ sở) thì không trình được.
  if v_manager is null then
    perform app.raise_error('HMT_KHONG_CO_QUAN_LY', 'Chưa có quản lý trực tiếp để duyệt. Nhờ Admin đặt Quản lý trực tiếp cho người lập rồi trình lại.');
  end if;
  return query select 'QUAN_LY'::text, v_manager;
end;
$$;

-- ---------------------------------------------------------------------------
-- Người đang đăng nhập có duyệt được ở bước quản lý không (dùng chung cho đơn và phiếu thu).
-- Đầu vào: loại chứng từ (p_kind: 'DON' hoặc 'PHIEU_THU'), người duyệt đã chốt lúc trình (p_assigned_approver; không có thì
-- tính theo quản lý hiện tại của người lập p_creator_id). Duyệt được khi:
--   (1) là người duyệt đã chốt (quản lý trực tiếp lúc trình, hoặc chính Trưởng cơ sở lập khi tự duyệt); hoặc
--   (2) CHỈ với đơn ('DON'): là Admin, duyệt thay khi vắng (R-HT-01).
-- Phiếu thu: bước quản lý Admin KHÔNG duyệt thay (R-HT-01: việc tiền Admin không duyệt trực tiếp); Admin vắng thì không có
-- đường thay ở bước này. (Chữ luật cho điểm này sẽ vào docs/spec sau.)
-- ---------------------------------------------------------------------------
create or replace function app.can_approve_as_manager(
  p_creator_id uuid, p_kind text default 'DON', p_assigned_approver uuid default null)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_approver uuid := p_assigned_approver;
begin
  if p_kind not in ('DON', 'PHIEU_THU') then
    perform app.raise_error('HMT_LOAI_CHUNG_TU_SAI', 'Chỉ có đơn hàng và phiếu thu có bước quản lý duyệt.');
  end if;
  if not app.current_user_ready() then
    return false;
  end if;
  if v_approver is null then
    -- Chưa chốt lúc trình: lấy theo hiện tại (Trưởng cơ sở là chính mình, còn lại là quản lý trực tiếp); không lỗi nếu chưa có.
    select case when exists (select from app.user_role ur
                              where ur.user_id = p_creator_id and ur.role_code = 'BRANCH_MANAGER' and ur.is_active)
                then p_creator_id else a.manager_id end
      into v_approver from app.user_account a where a.id = p_creator_id;
  end if;
  if v_approver = auth.uid() then
    return true;
  end if;
  -- Đơn hàng: Admin duyệt thay (R-HT-01). Phiếu thu: không.
  return p_kind = 'DON' and app.mfa_satisfied()
         and exists (select from app.user_role ur
                      where ur.user_id = auth.uid() and ur.role_code = 'ADMIN' and ur.is_active);
end;
$$;

revoke execute on function app.set_manager(uuid, uuid), app.approval_route(uuid), app.can_approve_as_manager(uuid, text, uuid)
  from public, anon;
grant execute on function app.set_manager(uuid, uuid), app.approval_route(uuid), app.can_approve_as_manager(uuid, text, uuid)
  to authenticated;
