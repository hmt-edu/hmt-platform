-- GĐ0 bước 3: áp quyền cho các bảng bước 2, ghi sự kiện đăng nhập + khoá tạm, nhật ký xuất file,
-- Admin xoá bản ghi nhập nhầm, tham số đăng nhập. Chốt với anh Trường 10/10/2026.

-- ---------------------------------------------------------------------------
-- Sửa cấu hình (danh mục, Cài đặt, công tắc, ma trận quyền): migration/SQL Editor (không JWT)
-- hoặc người có quyền Quản trị · Sửa (ADMIN, đã xác thực hai bước).
-- ---------------------------------------------------------------------------
create or replace function app.assert_config_writer()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  -- Kết nối thẳng vào DB (migration, SQL Editor chủ project): được.
  if nullif(auth.role(), '') is null then
    return;
  end if;
  -- Luật: qua API phải có quyền Quản trị · Sửa.
  if not app.has_permission('ADMIN', 'SUA') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được sửa cấu hình.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Nhật ký thao tác: chỉ ADMIN đọc.
-- ---------------------------------------------------------------------------
create policy audit_log_read_admin on app.audit_log for select to authenticated
  using (app.has_permission('ADMIN', 'XEM'));
grant select on app.audit_log to authenticated;
create policy audited_table_read_admin on app.audited_table for select to authenticated
  using (app.has_permission('ADMIN', 'XEM'));
grant select on app.audited_table to authenticated;

-- ---------------------------------------------------------------------------
-- Ghi chú: đọc theo quyền thấy bản ghi được gắn.
-- Cơ sở, phòng: người đã sẵn sàng của đúng cơ sở (hoặc phạm vi toàn hệ thống); danh mục, tham số: ADMIN.
-- ---------------------------------------------------------------------------
create or replace function app.can_see_note_target(p_entity_type text, p_entity_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch_id uuid;
begin
  if not app.current_user_ready() then
    return false;
  end if;
  if app.has_permission('ADMIN', 'XEM') then
    return true;
  end if;
  if p_entity_type = 'BRANCH' then
    v_branch_id := p_entity_id;
  elsif p_entity_type = 'ROOM' then
    select branch_id into v_branch_id from app.room where id = p_entity_id;
  else
    return false;
  end if;
  return v_branch_id is not distinct from app.current_branch_id()
      or exists (select from app.role r where r.code = any (app.current_roles()) and r.default_scope = 'TOAN_HE_THONG');
end;
$$;

create policy note_read on app.note for select to authenticated
  using (app.can_see_note_target(entity_type, entity_id));
grant select on app.note to authenticated;

-- Thêm ghi chú: người thấy được bản ghi. Huỷ: người viết hoặc ADMIN.
create or replace function app.add_note(p_entity_type text, p_entity_id uuid, p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if nullif(auth.role(), '') is not null and not app.can_see_note_target(p_entity_type, p_entity_id) then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền ghi chú vào bản ghi này.');
  end if;
  insert into app.note (entity_type, entity_id, body) values (p_entity_type, p_entity_id, btrim(p_body))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function app.cancel_note(p_note_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if nullif(auth.role(), '') is not null
     and not exists (select from app.note where id = p_note_id and created_by = auth.uid())
     and not app.has_permission('ADMIN', 'HUY') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ người viết hoặc quản trị viên được huỷ ghi chú.');
  end if;
  update app.note set is_cancelled = true, cancel_reason = p_reason where id = p_note_id and not is_cancelled;
  if not found then
    perform app.raise_error('HMT_GHI_CHU_KHONG_CO', 'Không tìm thấy ghi chú, hoặc ghi chú đã huỷ.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Danh mục, Cài đặt, công tắc, cơ sở…: chỉ người đã sẵn sàng (không khoá, đã đổi mật khẩu lần đầu) đọc.
-- ---------------------------------------------------------------------------
alter policy catalog_read on app.catalog using (app.current_user_ready());
alter policy catalog_item_read on app.catalog_item using (app.current_user_ready());
alter policy branch_read on app.branch using (app.current_user_ready());
alter policy academic_year_read on app.academic_year using (app.current_user_ready());
alter policy room_read on app.room using (app.current_user_ready());
alter policy holiday_read on app.holiday using (app.current_user_ready());
alter policy setting_def_read on app.setting_def using (app.current_user_ready());
alter policy setting_branch_read on app.setting_branch using (app.current_user_ready());
alter policy feature_flag_read on app.feature_flag using (app.current_user_ready());
alter policy code_format_read on app.code_format using (app.current_user_ready());
alter policy note_target_read on app.note_target using (app.current_user_ready());
alter policy role_read on app.role using (app.current_user_ready());
alter policy permission_read on app.permission using (app.current_user_ready());

-- ---------------------------------------------------------------------------
-- Ma trận quyền: Admin sửa phạm vi hoặc bật/tắt một dòng (áp ngay, có nhật ký).
-- ---------------------------------------------------------------------------
create or replace function app.set_permission(p_role text, p_module text, p_action text, p_scope text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_config_writer();
  -- p_scope NULL = bỏ quyền (tắt dòng, không xoá).
  if p_scope is null then
    update app.permission set is_active = false
     where role_code = p_role and module_code = p_module and action_code = p_action;
    return;
  end if;
  insert into app.permission (role_code, module_code, action_code, scope_code)
  values (p_role, p_module, p_action, p_scope)
  on conflict (role_code, module_code, action_code)
    do update set scope_code = excluded.scope_code, is_active = true;
end;
$$;

-- ---------------------------------------------------------------------------
-- Nhật ký xuất file (L1: mỗi lần xuất ghi ai, phân hệ, bộ lọc, số dòng). Chỉ thêm.
-- ---------------------------------------------------------------------------
create table app.export_log (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  user_id uuid not null,
  branch_id uuid,
  module_code text not null,
  filters jsonb not null default '{}'::jsonb,
  row_count integer not null check (row_count >= 0)
);

comment on table app.export_log is 'Nhật ký xuất file (chỉ thêm).';
create index export_log_at_idx on app.export_log (at);
alter table app.export_log enable row level security;
revoke all on app.export_log from public, anon, authenticated, service_role;
create trigger export_log_no_update_delete before update or delete on app.export_log
  for each row execute function app.tg_audit_log_immutable();
create trigger export_log_no_truncate before truncate on app.export_log
  for each statement execute function app.tg_audit_log_immutable();
create policy export_log_read on app.export_log for select to authenticated
  using (app.has_permission('ADMIN', 'XEM')
         or (app.can_see_branch('REPORT', 'XEM', branch_id) and app.has_permission('REPORT', 'XEM')));
grant select on app.export_log to authenticated;

-- Ghi một lần xuất file; báo lỗi nếu không có quyền Xuất ở phân hệ đó.
create or replace function app.log_export(p_module text, p_filters jsonb, p_row_count integer)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not app.has_permission(p_module, 'XUAT') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền xuất file ở phân hệ này.');
  end if;
  insert into app.export_log (user_id, branch_id, module_code, filters, row_count)
  values (auth.uid(), app.current_branch_id(), p_module, coalesce(p_filters, '{}'::jsonb), p_row_count);
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin xoá bản ghi nhập nhầm (spec 03 "Không xoá cứng"): chỉ ADMIN đã xác thực hai bước,
-- bắt buộc lý do, chỉ bảng nghiệp vụ đã đăng ký; nhật ký chép cả dòng kèm lý do.
-- Danh mục, nhật ký, tài khoản không bao giờ nằm trong danh sách này.
-- ---------------------------------------------------------------------------
create table app.hard_delete_allowed (
  table_name regclass primary key
);

comment on table app.hard_delete_allowed is 'Bảng nghiệp vụ cho phép Admin xoá bản ghi nhập nhầm (đăng ký qua migration).';
alter table app.hard_delete_allowed enable row level security;
revoke all on app.hard_delete_allowed from anon, authenticated;

create or replace function app.tg_block_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  -- Ngoại lệ duy nhất: hàm admin_hard_delete đặt cờ trong giao dịch.
  if coalesce(current_setting('hmt.hard_delete', true), '') = 'on' then
    return old;
  end if;
  perform app.raise_error('HMT_KHONG_XOA',
    'Không xoá được bản ghi. Hãy chuyển sang trạng thái Huỷ hoặc Ngừng.');
  return null;
end;
$$;

-- Nhật ký xoá ghi kèm lý do.
create or replace function app.tg_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_table_id smallint := TG_ARGV[0]::smallint;
  v_old jsonb;
  v_new jsonb;
  v_changes jsonb;
begin
  if TG_OP = 'INSERT' then
    insert into app.audit_log (table_id, record_id, action, actor)
    values (v_table_id, new.id, 'I', app.current_actor());
    return new;
  end if;

  -- Luật: xoá chép cả dòng cũ, kèm lý do xoá.
  if TG_OP = 'DELETE' then
    insert into app.audit_log (table_id, record_id, action, changes, actor)
    values (v_table_id, old.id, 'D',
            jsonb_build_object('row', to_jsonb(old), 'reason', nullif(current_setting('hmt.hard_delete_reason', true), '')),
            app.current_actor());
    return old;
  end if;

  v_old := to_jsonb(old) - array['created_at', 'created_by', 'updated_at', 'updated_by'];
  v_new := to_jsonb(new) - array['created_at', 'created_by', 'updated_at', 'updated_by'];
  select jsonb_object_agg(n.key, jsonb_build_array(v_old -> n.key, n.value))
    into v_changes
    from jsonb_each(v_new) as n
   where (v_old -> n.key) is distinct from n.value;

  if v_changes is not null then
    insert into app.audit_log (table_id, record_id, action, changes, actor)
    values (v_table_id, new.id, 'U', v_changes, app.current_actor());
  end if;
  return new;
end;
$$;

-- SQL động bắt buộc (Quy ước SQL mục 6): bảng do Admin chọn, nhưng chỉ trong danh sách đăng ký.
create or replace function app.admin_hard_delete(p_table regclass, p_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin
  -- Luật: chỉ ADMIN (has_permission đã đòi xác thực hai bước).
  if not app.has_permission('ADMIN', 'HUY') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được xoá bản ghi nhập nhầm.');
  end if;
  -- Luật: bắt buộc lý do.
  if p_reason is null or btrim(p_reason) = '' then
    perform app.raise_error('HMT_THIEU_LY_DO', 'Phải ghi lý do xoá.');
  end if;
  -- Luật: chỉ bảng nghiệp vụ đã đăng ký.
  if not exists (select from app.hard_delete_allowed where table_name = p_table) then
    perform app.raise_error('HMT_KHONG_XOA', 'Bảng này không cho xoá; hãy huỷ hoặc Ngừng.');
  end if;

  perform set_config('hmt.hard_delete', 'on', true);
  perform set_config('hmt.hard_delete_reason', btrim(p_reason), true);
  execute format('delete from %s where id = $1', p_table) using p_id;
  get diagnostics v_count = row_count;
  perform set_config('hmt.hard_delete', '', true);
  perform set_config('hmt.hard_delete_reason', '', true);
  if v_count = 0 then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy bản ghi cần xoá.');
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Sự kiện đăng nhập (để bước 5 cảnh báo sai nhiều lần). Chỉ thêm. Không bao giờ ghi mật khẩu.
-- ---------------------------------------------------------------------------
create table app.login_event (
  id bigint generated always as identity primary key,
  at timestamptz not null default now(),
  login_name text not null,
  user_id uuid,
  branch_id uuid,
  result text not null check (result in ('THANH_CONG', 'SAI_MAT_KHAU', 'TAI_KHOAN_KHOA', 'KHOA_TAM', 'KHONG_CO_TAI_KHOAN', 'LOI')),
  ip inet,
  user_agent text
);

comment on table app.login_event is 'Sự kiện đăng nhập (chỉ thêm). Ghi bởi Edge Function login.';
create index login_event_at_idx on app.login_event (at);
create index login_event_login_idx on app.login_event (login_name, at);
alter table app.login_event enable row level security;
revoke all on app.login_event from public, anon, authenticated, service_role;
create trigger login_event_no_update_delete before update or delete on app.login_event
  for each row execute function app.tg_audit_log_immutable();
create trigger login_event_no_truncate before truncate on app.login_event
  for each statement execute function app.tg_audit_log_immutable();
create policy login_event_read on app.login_event for select to authenticated
  using (app.has_permission('ADMIN', 'XEM')
         or ('BRANCH_MANAGER' = any (app.current_roles()) and app.current_user_ready()
             and branch_id = app.current_branch_id()));
grant select on app.login_event to authenticated;

-- Trước khi gọi Supabase Auth: tài khoản này có đang bị khoá / khoá tạm không.
-- Trả về: 'OK', 'TAI_KHOAN_KHOA', 'KHOA_TAM'. Tài khoản chưa có cũng trả 'OK' (để không lộ ai có tài khoản).
-- Ai gọi: chỉ Edge Function login (service_role).
create or replace function app.login_precheck(p_login_name text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select case
             when a.is_locked then 'TAI_KHOAN_KHOA'
             when a.temp_locked_until is not null and a.temp_locked_until > now() then 'KHOA_TAM'
             else 'OK'
           end
      from app.user_account a where a.login_name = lower(btrim(p_login_name))), 'OK');
$$;

-- Ghi kết quả đăng nhập; sai liên tiếp đủ ngưỡng thì khoá tạm (tham số login_lock_*).
create or replace function app.login_record(p_login_name text, p_result text, p_ip text, p_user_agent text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_account app.user_account;
  v_name text := lower(btrim(p_login_name));
begin
  select * into v_account from app.user_account where login_name = v_name;

  insert into app.login_event (login_name, user_id, branch_id, result, ip, user_agent)
  values (v_name, v_account.id, v_account.branch_id,
          case when v_account.id is null and p_result = 'SAI_MAT_KHAU' then 'KHONG_CO_TAI_KHOAN' else p_result end,
          nullif(p_ip, '')::inet, left(p_user_agent, app.get_setting_int('login_user_agent_max_length')::integer));

  if v_account.id is null then
    return;
  end if;

  -- Luật: đăng nhập thành công → xoá đếm sai.
  if p_result = 'THANH_CONG' then
    update app.user_account
       set failed_login_count = 0, temp_locked_until = null, last_login_at = now()
     where id = v_account.id;
    return;
  end if;

  -- Luật: sai mật khẩu liên tiếp đủ login_lock_after_failures lần → khoá tạm login_lock_minutes phút.
  if p_result = 'SAI_MAT_KHAU' then
    update app.user_account
       set failed_login_count = failed_login_count + 1,
           temp_locked_until = case
             when failed_login_count + 1 >= app.get_setting_int('login_lock_after_failures', branch_id)
               then now() + make_interval(mins => app.get_setting_int('login_lock_minutes', branch_id)::integer)
             else temp_locked_until end
     where id = v_account.id;
  end if;
end;
$$;

revoke execute on function app.login_precheck(text), app.login_record(text, text, text, text)
  from public, anon, authenticated;
grant execute on function app.login_precheck(text), app.login_record(text, text, text, text) to service_role;

revoke execute on function app.set_permission(text, text, text, text), app.admin_hard_delete(regclass, uuid, text)
  from public, anon;
grant execute on function
  app.set_permission(text, text, text, text), app.admin_hard_delete(regclass, uuid, text),
  app.log_export(text, jsonb, integer), app.can_see_note_target(text, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Tham số đăng nhập (chốt 10/10/2026).
-- ---------------------------------------------------------------------------
select set_config('hmt.migration', 'on', false);
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, description)
values
  ('password_min_length', 'Mật khẩu: độ dài tối thiểu', 'INT', 'ký tự', 8, 64, '8', false, 'ADMIN',
   'Một chính sách cho mọi người. Supabase Auth (tự đặt lại qua email) cấu hình cùng giá trị.'),
  ('password_require_letter_digit', 'Mật khẩu: bắt có chữ và số', 'BOOL', null, null, null, 'true', false, 'ADMIN',
   'Bắt có ít nhất một chữ cái và một chữ số. Không bắt chữ hoa.'),
  ('staff_idle_logout_minutes', 'Nhân viên tự đăng xuất khi không dùng', 'INT', 'phút', 5, 1440, '60', false, 'ADMIN',
   'Áp cho Admin, Trưởng cơ sở, Sale, CSKH, Kế toán.'),
  ('teacher_idle_logout_minutes', 'Giáo viên, trợ giảng tự đăng xuất khi không dùng', 'INT', 'phút', 5, 20160, '10080', false, 'ADMIN',
   '7 ngày.'),
  ('student_idle_logout_minutes', 'Học sinh tự đăng xuất khi không dùng', 'INT', 'phút', 5, 20160, '10080', false, 'ADMIN',
   '7 ngày.'),
  ('login_lock_after_failures', 'Khoá tạm sau số lần đăng nhập sai liên tiếp', 'INT', 'lần', 3, 50, '10', false, 'ADMIN',
   'Đủ số lần sai liên tiếp thì tài khoản bị khoá tạm.'),
  ('login_lock_minutes', 'Thời gian khoá tạm', 'INT', 'phút', 1, 1440, '15', false, 'ADMIN',
   'Hết thời gian này thì đăng nhập lại được.'),
  ('login_fail_alert_count', 'Cảnh báo: số lần đăng nhập sai', 'INT', 'lần', 3, 50, '5', false, 'ADMIN',
   'Bước 5: sai từ số lần này trong khoảng thời gian dưới đây thì email Admin.'),
  ('login_fail_alert_window_minutes', 'Cảnh báo: khoảng thời gian tính số lần sai', 'INT', 'phút', 5, 1440, '15', false, 'ADMIN',
   'Đi cùng login_fail_alert_count.'),
  ('login_user_agent_max_length', 'Độ dài tối đa thông tin trình duyệt lưu khi đăng nhập', 'INT', 'ký tự', 50, 1000, '300', false, 'ADMIN',
   'Cắt bớt để nhật ký đăng nhập gọn.');
select set_config('hmt.migration', '', false);
