-- PR 6e: tách phân hệ quyền Cấu hình, thêm Ngày nghỉ lễ và Lịch hẹn; hai luật bảo vệ ma trận.
-- Anh Trường chốt 12/10 (tách Quản trị / Cấu hình bán hàng / Cấu hình đào tạo) và 16/10 (bảng quyền TRƯỚC, SAU;
-- thêm phân hệ Ngày nghỉ lễ, Lịch hẹn). Quyền nạp bằng chính hàm lưu của PR 6d nên tạo một phiên bản mới có danh sách
-- từng ô đổi.

select set_config('hmt.migration', 'on', false);

-- ---------------------------------------------------------------------------
-- Bốn phân hệ quyền mới (danh mục hệ thống PERM_MODULE).
-- ---------------------------------------------------------------------------
insert into app.catalog_item (catalog_code, code, name, sort_order) values
  ('PERM_MODULE', 'CONFIG_SALES', 'Cấu hình bán hàng (gói, bảng giá, chiết khấu, điều khoản thanh toán, chiến dịch)', 21),
  ('PERM_MODULE', 'CONFIG_TRAINING', 'Cấu hình đào tạo (khung chương trình, rubric)', 22),
  ('PERM_MODULE', 'HOLIDAY', 'Ngày nghỉ lễ', 23),
  ('PERM_MODULE', 'APPOINTMENT', 'Lịch hẹn', 24);

-- ---------------------------------------------------------------------------
-- Lịch sử phiên bản quyền chỉ thêm: chặn cả xoá và xoá sạch (trước đây chỉ chặn sửa).
-- ---------------------------------------------------------------------------
create trigger permission_version_append_only_delete before delete on app.permission_version
  for each row execute function app.tg_permission_history_append_only();
create trigger permission_change_append_only_delete before delete on app.permission_change
  for each row execute function app.tg_permission_history_append_only();
create trigger permission_version_no_truncate before truncate on app.permission_version
  for each statement execute function app.tg_permission_history_append_only();
create trigger permission_change_no_truncate before truncate on app.permission_change
  for each statement execute function app.tg_permission_history_append_only();

-- ---------------------------------------------------------------------------
-- Luật: vai trò ADMIN luôn giữ đủ quyền phân hệ Quản trị (mọi hành động, toàn hệ thống). Lần lưu nào bỏ hoặc
-- thu hẹp thì báo HMT_ADMIN_GIU_QUYEN_QUAN_TRI và hoàn tác cả lần lưu.
-- ---------------------------------------------------------------------------
create or replace function app.tg_permission_admin_keeps_admin()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.role_code = 'ADMIN' and new.module_code = 'ADMIN'
     and (not new.is_active or new.scope_code <> 'TOAN_HE_THONG') then
    perform app.raise_error('HMT_ADMIN_GIU_QUYEN_QUAN_TRI',
      'Vai trò ADMIN luôn phải giữ đủ quyền phân hệ Quản trị (mọi hành động, toàn hệ thống).');
  end if;
  return new;
end;
$$;
create trigger permission_admin_keeps_admin before insert or update on app.permission
  for each row execute function app.tg_permission_admin_keeps_admin();

-- ---------------------------------------------------------------------------
-- Nạp quyền theo bảng đã duyệt (anh Trường 16/10). X=XEM, T=TAO, S=SUA, H=HUY, D=DUYET, E=XUAT, G=GIAO_VIEC.
-- Cấu hình bán hàng, đào tạo: chỉ Admin sửa; các vai trò khác xem, toàn hệ thống (giá, chính sách như nhau mọi cơ sở).
-- Ngày nghỉ lễ: Trưởng cơ sở xem, tạo, sửa, huỷ phạm vi cơ sở mình; Tuyển sinh, CSKH xem cơ sở mình.
-- Lịch hẹn: Tuyển sinh, CSKH xem, tạo, sửa, huỷ cơ sở mình (mở lại tính là Sửa); Trưởng cơ sở đủ như Cơ hội.
-- ---------------------------------------------------------------------------
select app.save_permission_matrix(
  app.permission_current_version(),
  (select jsonb_agg(jsonb_build_object('role', v.role, 'module', v.module, 'action', v.action, 'scope', v.scope))
   from (
     -- ADMIN: đủ 7 hành động, toàn hệ thống, trên cả bốn phân hệ mới.
     select 'ADMIN' as role, m.module, a.action, 'TOAN_HE_THONG' as scope
       from (values ('CONFIG_SALES'), ('CONFIG_TRAINING'), ('HOLIDAY'), ('APPOINTMENT')) as m(module)
       cross join (values ('XEM'), ('TAO'), ('SUA'), ('HUY'), ('DUYET'), ('XUAT'), ('GIAO_VIEC')) as a(action)
     union all
     select * from (values
       -- Trưởng cơ sở
       ('BRANCH_MANAGER', 'CONFIG_SALES', 'XEM', 'TOAN_HE_THONG'),
       ('BRANCH_MANAGER', 'CONFIG_TRAINING', 'XEM', 'TOAN_HE_THONG'),
       ('BRANCH_MANAGER', 'HOLIDAY', 'XEM', 'CO_SO'),
       ('BRANCH_MANAGER', 'HOLIDAY', 'TAO', 'CO_SO'),
       ('BRANCH_MANAGER', 'HOLIDAY', 'SUA', 'CO_SO'),
       ('BRANCH_MANAGER', 'HOLIDAY', 'HUY', 'CO_SO'),
       ('BRANCH_MANAGER', 'APPOINTMENT', 'XEM', 'CO_SO'),
       ('BRANCH_MANAGER', 'APPOINTMENT', 'TAO', 'CO_SO'),
       ('BRANCH_MANAGER', 'APPOINTMENT', 'SUA', 'CO_SO'),
       ('BRANCH_MANAGER', 'APPOINTMENT', 'HUY', 'CO_SO'),
       ('BRANCH_MANAGER', 'APPOINTMENT', 'DUYET', 'CO_SO'),
       ('BRANCH_MANAGER', 'APPOINTMENT', 'XUAT', 'CO_SO'),
       ('BRANCH_MANAGER', 'APPOINTMENT', 'GIAO_VIEC', 'CO_SO'),
       -- Kế toán
       ('ACCOUNTANT', 'CONFIG_SALES', 'XEM', 'TOAN_HE_THONG'),
       -- Tuyển sinh
       ('SALES', 'CONFIG_SALES', 'XEM', 'TOAN_HE_THONG'),
       ('SALES', 'HOLIDAY', 'XEM', 'CO_SO'),
       ('SALES', 'APPOINTMENT', 'XEM', 'CO_SO'),
       ('SALES', 'APPOINTMENT', 'TAO', 'CO_SO'),
       ('SALES', 'APPOINTMENT', 'SUA', 'CO_SO'),
       ('SALES', 'APPOINTMENT', 'HUY', 'CO_SO'),
       -- CSKH
       ('CSKH', 'CONFIG_SALES', 'XEM', 'TOAN_HE_THONG'),
       ('CSKH', 'CONFIG_TRAINING', 'XEM', 'TOAN_HE_THONG'),
       ('CSKH', 'HOLIDAY', 'XEM', 'CO_SO'),
       ('CSKH', 'APPOINTMENT', 'XEM', 'CO_SO'),
       ('CSKH', 'APPOINTMENT', 'TAO', 'CO_SO'),
       ('CSKH', 'APPOINTMENT', 'SUA', 'CO_SO'),
       ('CSKH', 'APPOINTMENT', 'HUY', 'CO_SO'),
       -- Giáo viên, trợ giảng: xem Cấu hình đào tạo (khung chương trình, rubric)
       ('TEACHER', 'CONFIG_TRAINING', 'XEM', 'TOAN_HE_THONG'),
       ('TA', 'CONFIG_TRAINING', 'XEM', 'TOAN_HE_THONG')
     ) as r(role, module, action, scope)
   ) as v)
);

select set_config('hmt.migration', '', false);
