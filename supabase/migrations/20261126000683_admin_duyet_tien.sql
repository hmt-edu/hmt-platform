-- Migration E-26-05c (anh Trường chốt 26/11/2026 15:35): ADMIN HỆ THỐNG DUYỆT ĐƯỢC VIỆC TIỀN. Thay phần «Admin không duyệt tiền» của R-HT-01, mig 455.
-- Chỉ Admin hệ thống (đã qua hai bước khi luật hai bước bật): (1) duyệt phiếu thu, hoàn phí, dừng học, phiếu nghiệp vụ tiền ở mọi cấp;
-- (2) được duyệt cả bước quản lý và bước kế toán của cùng chứng từ; (3) được tự duyệt chứng từ mình lập. Mọi vai khác GIỮ NGUYÊN
-- hai người khác nhau và chặn tự duyệt. Lần Admin dùng ngoại lệ (2), (3) được ghi cờ vào app.admin_approval_log để tra cứu.

-- Bảng cờ ngoại lệ, chỉ thêm. Chỉ mục: (loại, id) tra theo chứng từ (khoá duy nhất); branch_id là khoá ngoại; actor_id lọc theo người.
create table app.admin_approval_log (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('RECEIPT', 'REFUND_REQUEST', 'ENROLLMENT_STOP', 'TICKET_TASK')),
  entity_id uuid not null,
  step text not null,
  flag text not null check (flag in ('TU_DUYET', 'HAI_BUOC')),
  actor_id uuid not null references app.user_account (id),
  branch_id uuid not null references app.branch (id),
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (entity_type, entity_id, step, flag)
);
comment on table app.admin_approval_log is 'Admin tự duyệt (TU_DUYET) hoặc duyệt hai bước (HAI_BUOC) một chứng từ. Chỉ thêm.';
create index admin_approval_log_branch_idx on app.admin_approval_log (branch_id);
create index admin_approval_log_actor_idx on app.admin_approval_log (actor_id, created_at desc);
select app.apply_standard('app.admin_approval_log');
alter table app.admin_approval_log enable row level security;
revoke all on app.admin_approval_log from public, anon, authenticated;
grant select on app.admin_approval_log to authenticated;
create policy admin_approval_log_read on app.admin_approval_log for select to authenticated
  using ((select app.has_permission('ADMIN', 'XEM')));

create function app.tg_admin_approval_log_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  perform app.raise_error('HMT_NHAT_KY_CHI_THEM', 'Nhật ký Admin duyệt chỉ thêm dòng, không sửa, không xoá.');
  return null;
end;
$$;
create trigger admin_approval_log_no_change before update or delete on app.admin_approval_log
  for each row execute function app.tg_admin_approval_log_append_only();

-- app.log_admin_exception: ghi một cờ ngoại lệ của Admin đang thao tác. Hàm trong.
create function app.log_admin_exception(p_type text, p_id uuid, p_step text, p_flag text, p_branch uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into app.admin_approval_log (entity_type, entity_id, step, flag, actor_id, branch_id)
  values (p_type, p_id, p_step, p_flag, auth.uid(), p_branch)
  on conflict (entity_type, entity_id, step, flag) do nothing;
$$;
revoke execute on function app.log_admin_exception(text, uuid, text, text, uuid) from public, anon, authenticated;

-- Quyền: vai Admin được Kế toán · Duyệt và Phiếu thu · Duyệt (R-HT-01 mới). Vai khác không đổi: chốt chặn vẫn chỉ cho Kế toán và Admin.
create or replace function app.tg_permission_admin_no_money_approval()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Luật R-HT-01: ô Kế toán · Duyệt chỉ thuộc vai Kế toán và Admin hệ thống.
  if new.module_code = 'ACCOUNTING' and new.action_code = 'DUYET' and new.is_active and new.role_code not in ('ACCOUNTANT', 'ADMIN') then
    perform app.raise_error('HMT_CHI_KE_TOAN_DUYET_TIEN',
      'Chỉ vai trò Kế toán và Admin hệ thống được có quyền Kế toán · Duyệt. Gán vai trò Kế toán cho người cụ thể khi cần.');
  end if;
  return new;
end;
$$;
select set_config('hmt.migration', 'on', false);
insert into app.permission (role_code, module_code, action_code, scope_code)
values ('ADMIN', 'ACCOUNTING', 'DUYET', 'TOAN_HE_THONG'), ('ADMIN', 'RECEIPT', 'DUYET', 'TOAN_HE_THONG')
on conflict (role_code, module_code, action_code) do update set scope_code = excluded.scope_code, is_active = true;
select set_config('hmt.migration', '', false);

-- Phiếu thu: hai người khác nhau ở hai bước (R-TIEN-01), trừ Admin đang tự thao tác. Chỉ kiểm khi người duyệt ĐỔI,
-- để chứng từ Admin đã duyệt hai bước vẫn cập nhật được sau đó. Admin tự duyệt chứng từ mình lập: ghi cờ.
create or replace function app.tg_receipt_two_approvers()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_manager boolean := new.manager_approved_by is not null and (TG_OP = 'INSERT' or new.manager_approved_by is distinct from old.manager_approved_by);
  v_acc boolean := new.accountant_approved_by is not null and (TG_OP = 'INSERT' or new.accountant_approved_by is distinct from old.accountant_approved_by);
begin
  if (v_manager or v_acc) and new.accountant_approved_by = new.manager_approved_by then
    if new.accountant_approved_by is distinct from auth.uid() or not app.has_role_or_admin('{}') then
      perform app.raise_error('HMT_CUNG_NGUOI_DUYET_HAI_BUOC', 'Một người không duyệt cả bước quản lý và bước kế toán của cùng một phiếu thu.');
    end if;
    perform app.log_admin_exception('RECEIPT', new.id, 'KE_TOAN', 'HAI_BUOC', new.branch_id);
  end if;
  if v_manager and new.manager_approved_by = auth.uid() and auth.uid() in (new.created_by, new.submitted_by) and app.has_role_or_admin('{}') then
    perform app.log_admin_exception('RECEIPT', new.id, 'QUAN_LY', 'TU_DUYET', new.branch_id);
  end if;
  if v_acc and new.accountant_approved_by = auth.uid() and auth.uid() in (new.created_by, new.submitted_by) and app.has_role_or_admin('{}') then
    perform app.log_admin_exception('RECEIPT', new.id, 'KE_TOAN', 'TU_DUYET', new.branch_id);
  end if;
  return new;
end;
$$;

-- Hoàn phí và dừng học: như trên.
create or replace function app.tg_refund_two_approvers()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_type text := upper(TG_TABLE_NAME);
  v_manager boolean := new.manager_by is not null and (TG_OP = 'INSERT' or new.manager_by is distinct from old.manager_by);
  v_acc boolean := new.accountant_by is not null and (TG_OP = 'INSERT' or new.accountant_by is distinct from old.accountant_by);
begin
  if (v_manager or v_acc) and new.accountant_by = new.manager_by then
    if new.accountant_by is distinct from auth.uid() or not app.has_role_or_admin('{}') then
      perform app.raise_error('HMT_CUNG_NGUOI_DUYET_HAI_BUOC', 'Một người không duyệt cả bước quản lý và bước kế toán của cùng một yêu cầu.');
    end if;
    perform app.log_admin_exception(v_type, new.id, 'KE_TOAN', 'HAI_BUOC', new.branch_id);
  end if;
  if v_manager and new.manager_by = auth.uid() and new.created_by = auth.uid() and app.has_role_or_admin('{}') then
    perform app.log_admin_exception(v_type, new.id, 'QUAN_LY', 'TU_DUYET', new.branch_id);
  end if;
  if v_acc and new.accountant_by = auth.uid() and new.created_by = auth.uid() and app.has_role_or_admin('{}') then
    perform app.log_admin_exception(v_type, new.id, 'KE_TOAN', 'TU_DUYET', new.branch_id);
  end if;
  return new;
end;
$$;

-- app.can_approve_as_manager: chép nguyên bản 20261108000083, chỉ đổi Admin duyệt thay cả phiếu thu.
create or replace function app.can_approve_as_manager(
  p_creator_id uuid, p_kind text default 'DON', p_assigned_approver uuid default null,
  p_route text default null, p_branch_id uuid default null)
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
  -- Luật R-V2-12: route TRUONG_CS thì mọi Trưởng cơ sở của cơ sở chứng từ duyệt được (người chốt để trống).
  if p_route = 'TRUONG_CS' then
    if app.is_branch_manager_at(auth.uid(), case when p_kind = 'PHIEU_THU' then 'RECEIPT' else 'SALES_ORDER' end, p_branch_id) then
      return true;
    end if;
  elsif v_approver is null then
    -- Chưa chốt lúc trình: lấy theo hiện tại (Trưởng cơ sở là chính mình, còn lại là quản lý trực tiếp); không lỗi nếu chưa có.
    select case when exists (select from app.user_role ur
                              where ur.user_id = p_creator_id and ur.role_code = 'BRANCH_MANAGER' and ur.is_active)
                then p_creator_id else a.manager_id end
      into v_approver from app.user_account a where a.id = p_creator_id;
  end if;
  if v_approver = auth.uid() then
    return true;
  end if;
  -- Đơn hàng và phiếu thu: Admin duyệt thay (R-HT-01, anh chốt 26/11).
  return app.mfa_satisfied()
         and exists (select from app.user_role ur
                      where ur.user_id = auth.uid() and ur.role_code = 'ADMIN' and ur.is_active);
end;
$$;

-- app.approve_receipt_manager: chép nguyên bản 20261108000083, chỉ đổi câu báo lỗi.
create or replace function app.approve_receipt_manager(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu.');
  end if;
  perform app.assert_can('RECEIPT', 'DUYET', r.branch_id);
  if r.status_code <> 'DA_GUI' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt bước quản lý được phiếu thu Đã gửi.');
  end if;
  if not app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id, r.approval_route, r.branch_id) then
    perform app.raise_error('HMT_KHONG_PHAI_NGUOI_DUYET', 'Phiếu thu này do người duyệt đã chốt lúc gửi duyệt (hoặc Admin duyệt thay).');
  end if;
  perform app.receipt_manager_step_done(p_id, 'DUYET_QL');
end;
$$;

-- app.approve_refund_manager: chép nguyên bản 20261118000458, chỉ đổi Admin được tự duyệt.
create or replace function app.approve_refund_manager(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.refund_request;
begin
  r := app.refund_request_for_update(p_id, array['CHO_QL']);
  perform app.assert_can('ENROLLMENT', 'DUYET', r.branch_id);
  perform app.require_feature('HOAN_PHI', r.branch_id);
  -- Luật R-CS-07, R-HT-01 (T8): người tạo không tự duyệt, KHÔNG có ngoại lệ cho Admin.
  if r.created_by = (select auth.uid()) and not app.has_role_or_admin('{}') then
    perform app.raise_error('HMT_HOAN_PHI_TU_DUYET', 'Người tạo yêu cầu không tự duyệt yêu cầu của mình.');
  end if;
  update app.refund_request set status_code = 'CHO_KE_TOAN', manager_by = (select auth.uid()), manager_at = now() where id = r.id;
end;
$$;

-- app.approve_stop_manager: chép nguyên bản 20261118000458, chỉ đổi Admin được tự duyệt.
create or replace function app.approve_stop_manager(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s app.enrollment_stop;
begin
  s := app.enrollment_stop_for_update(p_id, array['CHO_QL']);
  perform app.assert_can('ENROLLMENT', 'DUYET', s.branch_id);
  perform app.require_feature('DUNG_HOC', s.branch_id);
  -- Luật R-CS-07, R-HT-01 (T8): người tạo không tự duyệt, KHÔNG có ngoại lệ cho Admin.
  if s.created_by = (select auth.uid()) and not app.has_role_or_admin('{}') then
    perform app.raise_error('HMT_DUNG_HOC_TU_DUYET', 'Người tạo yêu cầu không tự duyệt yêu cầu của mình.');
  end if;
  update app.enrollment_stop set status_code = 'CHO_KE_TOAN', manager_by = (select auth.uid()), manager_at = now() where id = s.id;
end;
$$;

-- app.approve_opening_debt_receipt: chép nguyên bản 20261119000421, chỉ đổi Admin được tự duyệt (cờ ghi ở trigger phiếu thu).
create or replace function app.approve_opening_debt_receipt(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r app.receipt;
  v_code text;
  v_money uuid;
  v_branch_code text;
begin
  select * into r from app.receipt where id = p_id for update;
  if r.id is null or not r.is_opening_debt then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu thu nợ đầu kỳ.');
  end if;
  perform app.assert_can('ACCOUNTING', 'DUYET', r.branch_id);
  perform app.require_feature('BAN_HANG', r.branch_id);
  if not app.get_setting_bool('opening_debt_receipt_enabled', r.branch_id) then
    perform app.raise_error('HMT_TINH_NANG_TAT', 'Thu nợ đầu kỳ chưa được bật cho cơ sở này.');
  end if;
  if r.status_code <> 'CHO_KE_TOAN' then
    perform app.raise_error('HMT_SAI_TRANG_THAI', 'Chỉ duyệt được phiếu thu Chờ kế toán.');
  end if;
  -- Luật N1 (Soát S14, R-V2-15, R-HT-01): phiếu nợ đầu kỳ không có bước quản lý, nên người lập hoặc người gửi KHÔNG tự duyệt phiếu của chính mình
  -- (Kế toán có cả quyền Tạo lẫn Duyệt: nếu không chặn thì một người lập, gửi, duyệt, nợ về 0 mà không ai khác biết).
  if (auth.uid() is not distinct from r.created_by or auth.uid() is not distinct from r.submitted_by) and not app.has_role_or_admin('{}') then
    perform app.raise_error('HMT_CUNG_NGUOI_DUYET_HAI_BUOC',
      'Người lập hoặc người gửi phiếu thu nợ đầu kỳ không tự duyệt phiếu của mình. Nhờ một Kế toán khác duyệt.');
  end if;
  -- Luật R-V2-15: không vượt nợ còn lại tại lúc duyệt.
  if r.amount > app.opening_debt_remaining(r.parent_id, r.id) then
    perform app.raise_error('HMT_SO_TIEN_VUOT', 'Số tiền vượt nợ đầu kỳ còn lại của phụ huynh.');
  end if;
  select code into v_branch_code from app.branch where id = r.branch_id;
  v_code := app.issue_document_number('KTV', v_branch_code);
  insert into app.money_in (code, receipt_id, order_id, is_opening_debt, opening_debt_student_id, parent_id, branch_id, amount)
  values (v_code, r.id, null, true, r.opening_debt_student_id, r.parent_id, r.branch_id, r.amount)
  returning id into v_money;
  insert into app.customer_balance_entry (parent_id, student_id, branch_id, entry_type, amount, entry_date, source_ref)
  values (r.parent_id, r.opening_debt_student_id, r.branch_id, 'THU_NO_DAU_KY', r.amount, current_date, v_code);
  update app.receipt set status_code = 'DA_DUYET', accountant_approved_at = now(), accountant_approved_by = auth.uid() where id = p_id;
  perform app.receipt_add_event(p_id, 'DUYET_KT', 'CHO_KE_TOAN', 'DA_DUYET', 'Thu nợ đầu kỳ');
  return jsonb_build_object('id', p_id, 'money_in_id', v_money, 'money_in_code', v_code,
                            'remaining', app.opening_debt_remaining(r.parent_id));
end;
$$;

-- app.approve_ticket_task: chép nguyên bản 20261126000678, chỉ đổi ngoại lệ Admin ở phiếu tiền.
create or replace function app.approve_ticket_task(p_id uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  k app.ticket_task;
  v_level text;
  v_last boolean;
  v_admin_money boolean;
begin
  select * into k from app.ticket_task where id = p_id for update;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  perform app.require_feature('AFTERSALE', k.branch_id);
  if k.status_code <> 'CHO_DUYET' then
    perform app.raise_error('HMT_PHIEU_TRANG_THAI_SAI', 'Chỉ duyệt phiếu đang Chờ duyệt.');
  end if;
  v_level := k.levels[k.current_level];
  if v_level = 'QUAN_LY_CO_SO_DICH' then
    -- CS-07: cấp quản lý cơ sở ĐẾN: đúng quản lý (vai trò Quản lý cơ sở) của cơ sở đích, và đã chọn lớp mới ở bước này.
    if k.dest_branch_id is null or not app.has_role_or_admin(array['BRANCH_MANAGER']) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho quản lý cơ sở đích.');
    end if;
    perform app.assert_can('TICKET', 'DUYET', k.dest_branch_id);
    if nullif(k.payload ->> 'to_class_id', '') is null or nullif(k.payload ->> 'start_date', '') is null then
      perform app.raise_error('HMT_PHIEU_CHUA_CHON_LOP', 'Chọn lớp mới và buổi bắt đầu ở cơ sở đích trước khi duyệt.');
    end if;
  elsif v_level = 'KE_TOAN' then
    -- Luật R-HT-01, R-TIEN-01: cấp kế toán chỉ vai trò Kế toán duyệt (Admin không duyệt tiền).
    if not app.has_role_or_admin(array['ACCOUNTANT']) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho kế toán.');
    end if;
    perform app.assert_can('TICKET', 'DUYET', null);
  else
    perform app.assert_can('TICKET', 'DUYET', k.branch_id);
    -- Luật R-CS-07 (anh chốt 24/11/2026, N0 #18): cấp Quản lý cơ sở do Trưởng cơ sở (đúng cơ sở, đã kiểm ở assert_can) hoặc Admin duyệt; Kế toán không duyệt cấp này.
    if not exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('BRANCH_MANAGER', 'ADMIN')) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho Trưởng cơ sở hoặc Admin.');
    end if;
    -- Luật R-HT-01, R-CS-07: phiếu có cấp kế toán là phiếu tiền; cấp quản lý cơ sở của phiếu tiền do quản lý cơ sở duyệt (không Admin, không kế toán thay).
    if 'KE_TOAN' = any (k.levels) and not app.has_role_or_admin(array['BRANCH_MANAGER']) then
      perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Cấp duyệt này dành cho quản lý cơ sở.');
    end if;
  end if;
  -- Ngoại lệ Admin chỉ ở phiếu TIỀN (có cấp Kế toán): được tự duyệt và duyệt nhiều cấp, có ghi cờ (E-26-05c).
  v_admin_money := 'KE_TOAN' = any (k.levels) and app.has_role_or_admin('{}');
  if k.created_by is not distinct from auth.uid() then
    if not v_admin_money then
      perform app.raise_error('HMT_PHIEU_TU_DUYET', 'Người tạo phiếu không tự duyệt phiếu của mình.');
    end if;
    perform app.log_admin_exception('TICKET_TASK', k.id, v_level, 'TU_DUYET', k.branch_id);
  end if;
  -- Luật R-TIEN-01: một người không duyệt hai cấp của cùng một phiếu.
  if exists (select from app.ticket_task_event ev where ev.task_id = k.id and ev.event_type = 'DUYET' and ev.created_by = auth.uid()) then
    if not v_admin_money then
      perform app.raise_error('HMT_PHIEU_MOT_NGUOI_HAI_CAP', 'Một người không duyệt hai cấp của cùng một phiếu.');
    end if;
    perform app.log_admin_exception('TICKET_TASK', k.id, v_level, 'HAI_BUOC', k.branch_id);
  end if;
  v_last := k.current_level >= cardinality(k.levels);
  update app.ticket_task set
    status_code = case when v_last then 'DA_DUYET' else 'CHO_DUYET' end,
    current_level = case when v_last then current_level else current_level + 1 end,
    approved_at = case when v_last then now() else approved_at end
   where id = k.id;
  perform app.ticket_task_log(k, 'DUYET', 'CHO_DUYET', case when v_last then 'DA_DUYET' else 'CHO_DUYET' end, nullif(btrim(coalesce(p_note, '')), ''));
end;
$$;

-- app.list_ticket_tasks: chép nguyên bản 20261124000646, chỉ đổi Admin thấy phiếu tiền chờ mình, kể cả phiếu mình tạo.
create or replace function app.list_ticket_tasks(p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1), app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := nullif(btrim(coalesce(p_filters ->> 'q', '')), '');
  v_status text := nullif(p_filters ->> 'status_code', '');
  v_type text := nullif(p_filters ->> 'task_type', '');
  v_branch uuid := nullif(p_filters ->> 'branch_id', '')::uuid;
  v_for_me boolean := coalesce((p_filters ->> 'cho_toi')::boolean, false);
  v_for_acc boolean := coalesce((p_filters ->> 'cho_ke_toan')::boolean, false);
  v_can_approve boolean := app.has_permission('TICKET', 'DUYET');
  v_is_acc boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('ACCOUNTANT', 'ADMIN'));
  -- Luật R-CS-07 (N0 #18): cấp Quản lý cơ sở chỉ Trưởng cơ sở hoặc Admin thấy trong «Chờ tôi duyệt».
  v_is_mgr boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('BRANCH_MANAGER', 'ADMIN'));
  v_total bigint;
  v_rows jsonb;
begin
  with f as (
    select k.id, k.created_at
      from app.ticket_task k
      join app.ticket t on t.id = k.ticket_id
     where (v_status is null or k.status_code = v_status)
       and (v_type is null or k.task_type = v_type)
       and (v_branch is null or k.branch_id = v_branch)
       and (v_q is null or k.code ilike '%' || v_q || '%' or t.code ilike '%' || v_q || '%')
       and (not v_for_me or (k.status_code = 'CHO_DUYET' and v_can_approve and (k.created_by is distinct from auth.uid() or ('KE_TOAN' = any (k.levels) and 'ADMIN' = any (app.current_roles())))
                             and case when k.levels[k.current_level] = 'KE_TOAN' then v_is_acc else v_is_mgr end))
       and (not v_for_acc or (k.status_code = 'CHO_DUYET' and k.levels[k.current_level] = 'KE_TOAN')))
  select (select count(*) from f),
         coalesce((select jsonb_agg(jsonb_build_object(
                    'id', k.id, 'code', k.code, 'task_type', k.task_type, 'status_code', k.status_code,
                    'level', k.current_level, 'level_total', cardinality(k.levels),
                    'next_role', case when k.status_code = 'CHO_DUYET' then k.levels[k.current_level] end,
                    'next_approver', case when k.status_code = 'CHO_DUYET' then app.ticket_task_next_approver(k.branch_id, k.levels[k.current_level]) end,
                    'ticket_id', k.ticket_id, 'ticket_code', t.code,
                    'student_name', (select s.full_name from app.student s where s.id = t.student_id),
                    'branch_code', (select b.code from app.branch b where b.id = k.branch_id),
                    'created_at', k.created_at, 'due_at', t.resolve_due_at) order by k.created_at desc, k.id)
                   from (select f.id from f order by f.created_at desc, f.id limit v_limit offset v_offset) x
                   join app.ticket_task k on k.id = x.id join app.ticket t on t.id = k.ticket_id), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

-- app.get_ticket_task: chép nguyên bản 20261124000646, chỉ đổi nút duyệt cho Admin ở phiếu tiền mình tạo.
create or replace function app.get_ticket_task(p_id uuid)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  k app.ticket_task;
  t app.ticket;
  v_is_acc boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('ACCOUNTANT', 'ADMIN'));
  -- Luật R-CS-07 (N0 #18): cấp Quản lý cơ sở chỉ Trưởng cơ sở hoặc Admin thấy nút Duyệt; Kế toán không.
  v_is_mgr boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('BRANCH_MANAGER', 'ADMIN'));
begin
  select * into k from app.ticket_task where id = p_id;
  if k.id is null then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy phiếu.');
  end if;
  select * into t from app.ticket where id = k.ticket_id;
  return jsonb_build_object(
    'task', jsonb_build_object(
      'id', k.id, 'code', k.code, 'task_type', k.task_type, 'status_code', k.status_code, 'reason', k.reason, 'payload', k.payload, 'result', k.result,
      'level', k.current_level, 'level_total', cardinality(k.levels), 'levels', to_jsonb(k.levels),
      'reject_reason', k.reject_reason, 'cancel_reason', k.cancel_reason, 'branch_id', k.branch_id,
      'branch_code', (select b.code from app.branch b where b.id = k.branch_id),
      'created_at', k.created_at, 'submitted_at', k.submitted_at, 'approved_at', k.approved_at, 'executed_at', k.executed_at,
      'created_by_name', app.staff_display_name(k.created_by),
      -- C60: người duyệt dự kiến của cấp đang chờ (CSN-05, CSN-06).
      'next_approver', case when k.status_code = 'CHO_DUYET' then app.ticket_task_next_approver(k.branch_id, k.levels[k.current_level]) end,
      'can_approve', k.status_code = 'CHO_DUYET' and (k.created_by is distinct from auth.uid() or ('KE_TOAN' = any (k.levels) and 'ADMIN' = any (app.current_roles()))) and app.has_permission('TICKET', 'DUYET')
                      and case when k.levels[k.current_level] = 'KE_TOAN' then v_is_acc else v_is_mgr end,
      'is_creator', k.created_by is not distinct from auth.uid()),
    'ticket', jsonb_build_object('id', t.id, 'code', t.code, 'title', t.title, 'status_code', t.status_code,
                                  'student_name', (select s.full_name from app.student s where s.id = t.student_id)),
    -- C-23-23 (CSN07_duyet_chuyen_lop): tóm tắt cho hộp Duyệt phiếu Chuyển lớp: lớp hiện tại, lớp mới, ngày bắt đầu, giờ còn lại (chỉ đọc, giờ do sổ giờ tính).
    'transfer', case when k.task_type = 'CHUYEN_LOP' then jsonb_build_object(
      'from_class', app.task_class_summary((select ec.class_id from app.enrollment_class ec
                                              where ec.enrollment_id = nullif(k.payload ->> 'enrollment_id', '')::uuid and ec.end_date is null limit 1)),
      'to_class', app.task_class_summary(nullif(k.payload ->> 'to_class_id', '')::uuid),
      'start_date', k.payload ->> 'start_date',
      'hours_left', coalesce((select sum(l.hours) from app.hour_ledger l where l.enrollment_id = nullif(k.payload ->> 'enrollment_id', '')::uuid), 0)::numeric(6, 2)) end,
    'events', coalesce((select jsonb_agg(jsonb_build_object(
        'id', e.id, 'event_type', e.event_type, 'from_status', e.from_status, 'to_status', e.to_status, 'note', e.note,
        'created_at', e.created_at, 'created_by_name', app.staff_display_name(e.created_by)) order by e.seq)
      from app.ticket_task_event e where e.task_id = k.id), '[]'::jsonb));
end;
$$;

-- app.my_approval_items: chép nguyên bản 20261124000646, chỉ đổi việc chờ Admin gồm phiếu tiền mình tạo.
create or replace function app.my_approval_items()
returns table (kind text, ref_id uuid, code text, subject_name text, subject_code text, detail text, level_no integer, level_total integer, level_label text,
               creator_id uuid, waiting_since timestamptz, branch_id uuid)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := auth.uid();
  v_admin boolean := 'ADMIN' = any (app.current_roles());
  -- Hiệu năng (F19): phạm vi quyền tính MỘT lần, không gọi hàm quyền từng dòng (cùng ý nghĩa app.can_see_branch).
  v_my_branch uuid := (select app.current_branch_id());
  v_s_acc text := app.permission_scope('ACCOUNTING', 'DUYET');
  v_s_class text := app.permission_scope('CLASS', 'DUYET');
  v_s_sess text := app.permission_scope('SESSION', 'DUYET');
  v_s_enr text := app.permission_scope('ENROLLMENT', 'DUYET');
  v_s_tk text := app.permission_scope('TICKET', 'DUYET');
  v_is_acc boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('ACCOUNTANT', 'ADMIN'));
  -- Luật R-CS-07 (N0 #18): phiếu nghiệp vụ cấp Quản lý cơ sở chỉ Trưởng cơ sở hoặc Admin thấy trong «Việc chờ tôi duyệt»; Kế toán không.
  v_is_mgr boolean := exists (select from app.user_role ur where ur.user_id = auth.uid() and ur.is_active and ur.role_code in ('BRANCH_MANAGER', 'ADMIN'));
begin
  -- Luật quyền: người gọi phải đăng nhập, đã sẵn sàng (không bị khoá, đã qua đổi mật khẩu lần đầu).
  if v_me is null or not app.current_user_ready() then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xem việc chờ duyệt.');
  end if;
  return query
  -- Đơn hàng chờ quản lý (R-V2-12).
  select 'DON_HANG', o.id, o.code, p.full_name, null::text, null::text, 1, 1,
         case o.approval_route when 'TRUONG_CS' then 'Trưởng cơ sở' else 'Quản lý trực tiếp' end, o.created_by, coalesce(o.submitted_at, o.created_at), o.branch_id
    from app.sales_order o join app.parent p on p.id = o.parent_id
   where o.status_code = 'DA_TRINH'
     and (v_admin or o.approval_route = 'TRUONG_CS' or o.assigned_approver_id is null or o.assigned_approver_id = v_me) -- lọc rẻ trước khi gọi hàm
     and app.can_approve_as_manager(o.created_by, 'DON', o.assigned_approver_id, o.approval_route, o.branch_id)
  union all
  -- Phiếu thu, cấp quản lý (R-V2-12); Admin không duyệt phiếu thu.
  select 'PHIEU_THU', r.id, r.code, p.full_name, null::text, null::text, 1, 2, -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
         case r.approval_route when 'TRUONG_CS' then 'Trưởng cơ sở → Kế toán' else 'Quản lý trực tiếp → Kế toán' end, r.created_by, coalesce(r.submitted_at, r.created_at), r.branch_id
    from app.receipt r join app.parent p on p.id = r.parent_id
   where r.status_code = 'DA_GUI'
     and (r.approval_route = 'TRUONG_CS' or r.assigned_approver_id is null or r.assigned_approver_id = v_me) -- lọc rẻ trước khi gọi hàm
     and app.can_approve_as_manager(r.created_by, 'PHIEU_THU', r.assigned_approver_id, r.approval_route, r.branch_id)
  union all
  -- Phiếu thu, cấp Kế toán.
  select 'PHIEU_THU', r.id, r.code, p.full_name, null::text, null::text, 2, 2, 'Kế toán', r.created_by, coalesce(r.manager_approved_at, r.submitted_at, r.created_at), r.branch_id -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
    from app.receipt r join app.parent p on p.id = r.parent_id
   where r.status_code = 'CHO_KE_TOAN' and (v_s_acc is not null and (v_s_acc = 'TOAN_HE_THONG' or r.branch_id is not distinct from v_my_branch))
  union all
  -- Lớp: Đã trình chờ Xác nhận, Đã xác nhận chờ Duyệt (R-LOP-02).
  select 'LOP', c.id, c.code, null::text, null::text, null::text, case c.status_code when 'DA_TRINH' then 1 else 2 end, 2, -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
         case c.status_code when 'DA_TRINH' then 'Xác nhận' else 'Duyệt' end, c.submitted_by,
         coalesce((select max(e.created_at) from app.class_event e where e.class_id = c.id and e.to_status = c.status_code), c.updated_at), c.branch_id
    from app.class c
   where c.status_code in ('DA_TRINH', 'DA_XAC_NHAN') and (v_s_class is not null and (v_s_class = 'TOAN_HE_THONG' or c.branch_id is not distinct from v_my_branch))
  union all
  -- Yêu cầu buổi (R-BUOI-03).
  select 'YEU_CAU_BUOI', q.id, q.code, null::text, null::text, c.code || ' · ' || to_char(q.session_date, 'DD/MM/YYYY'), 1, 1, 'Trưởng cơ sở', q.created_by,
         coalesce(q.submitted_at, q.created_at), q.branch_id
    from app.session_request q join app.class c on c.id = q.class_id
   where q.status_code = 'CHO_DUYET' and (v_s_sess is not null and (v_s_sess = 'TOAN_HE_THONG' or q.branch_id is not distinct from v_my_branch))
     and (q.created_by is distinct from v_me or v_admin)
  union all
  -- Hoàn phí hai cấp.
  select 'HOAN_PHI', f.id, e.code, s.full_name, s.code, null::text, case f.status_code when 'CHO_QL' then 1 else 2 end, 2, -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
         case f.status_code when 'CHO_QL' then 'Trưởng cơ sở' else 'Kế toán' end, f.created_by,
         case f.status_code when 'CHO_QL' then f.created_at else coalesce(f.manager_at, f.created_at) end, f.branch_id
    from app.refund_request f join app.enrollment e on e.id = f.enrollment_id join app.student s on s.id = f.student_id
   where (f.status_code = 'CHO_QL' and (v_s_enr is not null and (v_s_enr = 'TOAN_HE_THONG' or f.branch_id is not distinct from v_my_branch)) and (f.created_by is distinct from v_me or v_admin))
      or (f.status_code = 'CHO_KE_TOAN' and (v_s_acc is not null and (v_s_acc = 'TOAN_HE_THONG' or f.branch_id is not distinct from v_my_branch)))
  union all
  -- Dừng học hai cấp.
  select 'DUNG_HOC', d.id, e.code, s.full_name, s.code, null::text, case d.status_code when 'CHO_QL' then 1 else 2 end, 2, -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
         case d.status_code when 'CHO_QL' then 'Trưởng cơ sở' else 'Kế toán' end, d.created_by,
         case d.status_code when 'CHO_QL' then d.created_at else coalesce(d.manager_at, d.created_at) end, d.branch_id
    from app.enrollment_stop d join app.enrollment e on e.id = d.enrollment_id join app.student s on s.id = d.student_id
   where (d.status_code = 'CHO_QL' and (v_s_enr is not null and (v_s_enr = 'TOAN_HE_THONG' or d.branch_id is not distinct from v_my_branch)) and (d.created_by is distinct from v_me or v_admin))
      or (d.status_code = 'CHO_KE_TOAN' and (v_s_acc is not null and (v_s_acc = 'TOAN_HE_THONG' or d.branch_id is not distinct from v_my_branch)))
  union all
  -- Bảo lưu.
  select 'BAO_LUU', h.id, e.code, s.full_name, s.code, null::text, 1, 1, 'Trưởng cơ sở', h.created_by, h.created_at, h.branch_id
    from app.enrollment_hold h join app.enrollment e on e.id = h.enrollment_id join app.student s on s.id = h.student_id
   where h.status_code = 'CHO_DUYET' and (v_s_enr is not null and (v_s_enr = 'TOAN_HE_THONG' or h.branch_id is not distinct from v_my_branch)) and (h.created_by is distinct from v_me or v_admin)
  union all
  -- Chuyển lớp: duyệt ở cơ sở đi và cơ sở đến (mỗi cơ sở một lần).
  select 'CHUYEN_LOP', t.id, e.code, s.full_name, s.code, null::text, 1 + (t.approved_from_at is not null)::int + (t.approved_to_at is not null)::int,
         case when t.from_branch_id = t.to_branch_id then 1 else 2 end, 'Trưởng cơ sở', t.created_by, coalesce(t.approved_from_at, t.approved_to_at, t.created_at), t.from_branch_id -- allow-number: số cấp duyệt theo luật hai cấp, không phải tham số
    from app.class_transfer t join app.enrollment e on e.id = t.enrollment_id join app.student s on s.id = t.student_id
   where t.status_code = 'CHO_DUYET' and (t.created_by is distinct from v_me or v_admin)
     and ((t.approved_from_at is null and (v_s_enr is not null and (v_s_enr = 'TOAN_HE_THONG' or t.from_branch_id is not distinct from v_my_branch)))
          or (t.approved_to_at is null and (v_s_enr is not null and (v_s_enr = 'TOAN_HE_THONG' or t.to_branch_id is not distinct from v_my_branch))))
  union all
  -- Phiếu nghiệp vụ Aftersale có bước duyệt (R-CS-07, R-V2-24).
  select 'PHIEU_NGHIEP_VU', k.id, k.code, null::text, null::text, k.task_type, k.current_level, cardinality(k.levels),
         case k.levels[k.current_level] when 'KE_TOAN' then 'Kế toán' else 'Trưởng cơ sở' end, k.created_by, coalesce(k.submitted_at, k.created_at), k.branch_id
    from app.ticket_task k
   where k.status_code = 'CHO_DUYET' and (k.created_by is distinct from v_me or (v_admin and 'KE_TOAN' = any (k.levels)))
     and ((k.levels[k.current_level] = 'KE_TOAN'
           and v_is_acc and v_s_tk is not null)
          or (k.levels[k.current_level] is distinct from 'KE_TOAN' and v_is_mgr and (v_s_tk is not null and (v_s_tk = 'TOAN_HE_THONG' or k.branch_id is not distinct from v_my_branch))));
end;
$$;
