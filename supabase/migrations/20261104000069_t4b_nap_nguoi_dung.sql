-- T4b: nạp Người dùng từ file mẫu (tab 00_NGUOIDUNG; docs/spec/04 R-V2-29, 30, 34; anh Trường trả lời 04/11, Đ285 và phân tích
-- docs/nghiep-vu/phan-tich-nap-nguoi-dung-co-hoi.md). Tạo tài khoản cần quyền máy chủ nên làm ở Edge Function `import-users`
-- (gọi các hàm DB dưới đây bằng chính token của Admin). Hàm DB kiểm từng dòng, tạo tài khoản, gắn quản lý, khoá người nghỉ, ghi nhật ký.
-- QUYỀN RIÊNG TƯ: kết quả, thông báo lỗi và nhật ký nạp không chứa họ tên, email, tên đăng nhập; chỉ số dòng và chữ cái đầu của tên.
-- Mật khẩu tạm KHÔNG nằm trong DB (trừ băm có sẵn của tài khoản như mọi tài khoản mới): Edge Function trả một lần về trình duyệt Admin.

select set_config('hmt.migration', 'on', false);

-- Tham số (không viết cứng): tên miền email quy ước (miền giả ở thử nghiệm; Admin đặt miền thật trong Cài đặt trên bản chạy thật) và
-- độ dài mật khẩu tạm.
insert into app.setting_def
  (key, name, value_type, unit, min_value, max_value, value, allow_branch_override, module, legacy_ref, description)
values
  ('import_user_email_domain', 'Tên miền email quy ước khi nạp người dùng', 'TEXT', null, null, null, 'tam.invalid', false, null, null,
   'Cột email của file nạp để trống thì email đăng nhập là tên đăng nhập@tên miền này. Giá trị mặc định là miền giả dùng cho thử nghiệm; bản chạy thật Admin đặt tên miền thật.'),
  ('import_temp_password_length', 'Độ dài mật khẩu tạm khi nạp người dùng', 'INT', 'ký tự', 8, 64, '14', false, null, null,
   'Mật khẩu tạm ngẫu nhiên sinh cho mỗi tài khoản nạp; không bao giờ nhỏ hơn độ dài tối thiểu mật khẩu chung.');

-- Nhật ký nạp thêm loại NGUOI_DUNG.
alter table app.import_log drop constraint import_log_kind_check;
alter table app.import_log add constraint import_log_kind_check check (kind in ('PHU_HUYNH', 'HOC_SINH', 'NGUOI_DUNG'));

-- ---------------------------------------------------------------------------
-- Danh sách cơ sở đầy đủ của người dùng nạp chưa áp được (DB mới có một cơ sở chính mỗi người). Ghi nguyên giá trị của file để áp lại
-- khi làm PR danh sách cơ sở theo người (anh Trường chốt 04/11). Liên kết bằng mã tài khoản, không chứa họ tên.
-- ---------------------------------------------------------------------------
create table app.import_user_branch_pending (
  id uuid primary key default gen_random_uuid(),
  import_log_id uuid not null references app.import_log (id),
  user_id uuid not null references app.user_account (id),
  raw_branches text not null check (btrim(raw_branches) <> ''),
  applied_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  unique (user_id)
);
comment on table app.import_user_branch_pending is 'Danh sách cơ sở nguyên văn của người dùng nạp có nhiều cơ sở hoặc ALL, chờ PR danh sách cơ sở theo người.';
-- Khoá ngoại tới lần nạp.
create index import_user_branch_pending_log_idx on app.import_user_branch_pending (import_log_id);
select app.apply_standard('app.import_user_branch_pending');
alter table app.import_user_branch_pending enable row level security;
revoke all on app.import_user_branch_pending from public, anon, authenticated;
grant select on app.import_user_branch_pending to authenticated;
create policy import_user_branch_pending_read on app.import_user_branch_pending for select to authenticated
  using ((select app.has_permission('ADMIN', 'XEM')));

-- ---------------------------------------------------------------------------
-- app.import_users_resolve(hàng): kiểm từng dòng, KHÔNG tạo gì (xem trước) và trả dữ liệu đã giải quyết cho Edge Function.
-- Làm gì: mỗi dòng ra HOP_LE | TRUNG | LOI kèm câu tiếng Việt (không chứa họ tên, email, tên đăng nhập) và danh sách cảnh báo.
-- Ai gọi: Admin (qua Edge Function `import-users`; kiểm app.assert_account_admin). Cột `resolved` (có email, tên đăng nhập) CHỈ cho
--   Edge Function dùng, Edge Function bỏ cột này trước khi trả về trình duyệt.
-- Đầu vào: p_rows mảng JSON, mỗi hàng: username, ho_ten, ma_nv, vai_tro, co_so_truy_cap, trang_thai, email, quan_ly (kèm "row" tuỳ chọn).
-- Luật: tên đăng nhập đúng dạng và duy nhất (trùng trong file là LOI; đã có tài khoản cùng tên đăng nhập là TRUNG, bỏ qua, không ghi đè);
--   vai trò có trong danh mục (không phải HS, PH); cơ sở là mã có thật, nhiều cơ sở hoặc ALL thì lấy cơ sở đầu làm cơ sở chính kèm
--   cảnh báo; email đúng dạng, trống thì tên đăng nhập@miền quy ước; email đã dùng cho người khác là LOI; quản lý là tên đăng nhập có
--   trong file hoặc đã có, không tự quản lý mình; trạng thái Đang làm / Nghỉ phép / Đã nghỉ (hai loại sau sẽ khoá). Mã nhân viên cấp mới
--   theo chuẩn mã; ma_nv của file cũ không lưu (không đúng chuẩn mã NV, GV, TG).
-- ---------------------------------------------------------------------------
create or replace function app.import_users_resolve(p_rows jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_max integer := app.get_setting_int('import_max_rows');
  v_domain text := lower(app.get_setting('import_user_email_domain'));
  v_total integer;
  v_i integer := 0;
  v_rown integer;
  v_row jsonb;
  v_result jsonb := '[]'::jsonb;
  v_ok integer := 0;
  v_dup integer := 0;
  v_err integer := 0;
  v_names text[];
  v_seen_users text[] := array[]::text[];
  v_seen_emails text[] := array[]::text[];
  v_username text;
  v_email text;
  v_name text;
  v_initial text;
  v_role text;
  v_raw_branch text;
  v_codes text[];
  v_code text;
  v_primary text;
  v_status text;
  v_state text;
  v_manager text;
  v_warnings text[];
  v_msg text;
  v_hint text;
  v_locked boolean;
begin
  perform app.assert_account_admin();
  if jsonb_typeof(p_rows) is distinct from 'array' or jsonb_array_length(p_rows) = 0 then
    perform app.raise_error('HMT_THIEU_THONG_TIN', 'Chưa có dòng nào để nạp.');
  end if;
  v_total := jsonb_array_length(p_rows);
  if v_total > v_max then
    perform app.raise_error('HMT_QUA_NHIEU_DONG', format('File có %s dòng, tối đa %s dòng mỗi lần nạp.', v_total, v_max));
  end if;
  if v_domain !~ '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$' then
    perform app.raise_error('HMT_CAI_DAT_SAI_KIEU', 'Tên miền email quy ước trong Cài đặt không đúng dạng.');
  end if;
  -- Tên đăng nhập có trong file (để kiểm quản lý trực tiếp).
  select coalesce(array_agg(lower(app.import_text(r ->> 'username'))), array[]::text[]) into v_names
    from jsonb_array_elements(p_rows) r where jsonb_typeof(r) = 'object';

  for v_row in select value from jsonb_array_elements(p_rows) loop
    v_i := v_i + 1;
    v_rown := case when jsonb_typeof(v_row) = 'object' and (v_row ->> 'row') ~ '^[0-9]{1,9}$' then (v_row ->> 'row')::integer else v_i end;
    v_initial := case when jsonb_typeof(v_row) = 'object' then app.import_initial(v_row ->> 'ho_ten') end;
    v_warnings := array[]::text[];
    v_status := 'HOP_LE';
    v_msg := null;
    v_locked := false;
    v_primary := null;
    begin
      if jsonb_typeof(v_row) <> 'object' then
        perform app.raise_error('HMT_DONG_SAI', 'Dòng không đúng định dạng.');
      end if;
      -- Luật: tên đăng nhập đúng dạng.
      v_username := lower(app.import_text(v_row ->> 'username'));
      if v_username is null or v_username !~ '^[a-z0-9][a-z0-9._-]{1,48}$' then
        perform app.raise_error('HMT_TEN_DANG_NHAP_SAI', 'Tên đăng nhập không đúng dạng (chữ thường không dấu, số, dấu chấm hoặc gạch).');
      end if;
      v_name := app.import_text(v_row ->> 'ho_ten');
      if v_name is null then
        perform app.raise_error('HMT_THIEU_HO_TEN', 'Thiếu họ tên.');
      end if;
      -- Luật: vai trò có trong danh mục, không phải học sinh hay phụ huynh.
      v_role := upper(app.import_text(v_row ->> 'vai_tro'));
      if v_role is null or v_role in ('STUDENT', 'PARENT') or not exists (select from app.role where code = v_role) then
        perform app.raise_error('HMT_VAI_TRO_SAI', 'Vai trò không có trong danh mục.');
      end if;
      -- Luật: cơ sở là mã có thật. Nhiều cơ sở hoặc ALL: lấy cơ sở đầu làm cơ sở chính, kèm cảnh báo (ghi nguyên văn vào nhật ký nạp).
      v_raw_branch := app.import_text(v_row ->> 'co_so_truy_cap');
      if v_raw_branch is null then
        perform app.raise_error('HMT_CO_SO_SAI', 'Thiếu cơ sở truy cập.');
      end if;
      if upper(v_raw_branch) = 'ALL' then
        select code into v_primary from app.branch where is_active and not is_office order by code limit 1;
        v_warnings := array_append(v_warnings, 'Cơ sở truy cập là ALL: tạm lấy cơ sở chính ' || coalesce(v_primary, '?') || ', chờ danh sách cơ sở theo người.');
      else
        v_codes := array(select upper(btrim(c)) from unnest(string_to_array(v_raw_branch, ',')) c where btrim(c) <> '');
        if cardinality(v_codes) = 0 then
          perform app.raise_error('HMT_CO_SO_SAI', 'Thiếu cơ sở truy cập.');
        end if;
        foreach v_code in array v_codes loop
          if not exists (select from app.branch where code = v_code and is_active) then
            perform app.raise_error('HMT_CO_SO_SAI', 'Mã cơ sở không có thật.');
          end if;
        end loop;
        v_primary := v_codes[1];
        if cardinality(v_codes) > 1 then
          v_warnings := array_append(v_warnings, 'Có nhiều cơ sở: tạm lấy cơ sở đầu ' || v_primary || ' làm cơ sở chính, chờ danh sách cơ sở theo người.');
        end if;
      end if;
      -- Luật: trạng thái Đang làm, Nghỉ phép, Đã nghỉ (người nghỉ vẫn nạp, tài khoản khoá).
      v_state := app.fold_text(coalesce(app.import_text(v_row ->> 'trang_thai'), 'dang lam'));
      if v_state not in ('dang lam', 'nghi phep', 'da nghi') then
        perform app.raise_error('HMT_TRANG_THAI_SAI', 'Trạng thái chỉ nhận Đang làm, Nghỉ phép hoặc Đã nghỉ.');
      end if;
      v_locked := v_state <> 'dang lam';
      -- Luật: email đúng dạng; trống thì tên đăng nhập@miền quy ước.
      v_email := lower(app.import_text(v_row ->> 'email'));
      if v_email is not null and v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
        perform app.raise_error('HMT_EMAIL_SAI', 'Email sai định dạng.');
      end if;
      v_email := coalesce(v_email, v_username || '@' || v_domain);
      -- Luật: trùng tên đăng nhập hoặc email ngay trong file là LOI.
      if v_username = any (v_seen_users) then
        perform app.raise_error('HMT_TRUNG_TRONG_FILE', 'Tên đăng nhập trùng với một dòng trước trong file.');
      end if;
      if v_email = any (v_seen_emails) then
        perform app.raise_error('HMT_TRUNG_TRONG_FILE', 'Email trùng với một dòng trước trong file.');
      end if;
      v_seen_users := array_append(v_seen_users, v_username);
      v_seen_emails := array_append(v_seen_emails, v_email);
      -- Luật: quản lý trực tiếp là tên đăng nhập có trong file hoặc đã có trong hệ thống, không phải chính mình.
      v_manager := lower(app.import_text(v_row ->> 'quan_ly'));
      if v_manager is not null then
        if v_manager = v_username then
          perform app.raise_error('HMT_QUAN_LY_TU_THAN', 'Không đặt chính người đó làm quản lý trực tiếp.');
        end if;
        if not (v_manager = any (v_names)) and not exists (select from app.user_account where legacy_ref = v_manager and student_code is null) then
          perform app.raise_error('HMT_QUAN_LY_SAI', 'Quản lý trực tiếp không có trong file hay hệ thống.');
        end if;
      end if;
      -- Luật: đã có tài khoản cùng tên đăng nhập thì bỏ qua (TRUNG), không ghi đè. Email đã thuộc người khác là LOI.
      if exists (select from app.user_account where legacy_ref = v_username and student_code is null) then
        v_status := 'TRUNG';
        v_msg := 'Đã có tài khoản cùng tên đăng nhập, bỏ qua';
      elsif exists (select from app.user_account where login_name = v_email) then
        perform app.raise_error('HMT_EMAIL_TRUNG', 'Email đã dùng cho tài khoản khác.');
      end if;
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint, v_msg = message_text, v_state = returned_sqlstate;
      v_status := 'LOI';
      if v_hint not like 'HMT\_%' then
        v_msg := format('Không kiểm được dòng này (lỗi hệ thống, mã %s).', v_state);
      end if;
    end;

    if v_status = 'HOP_LE' then
      v_ok := v_ok + 1;
    elsif v_status = 'TRUNG' then
      v_dup := v_dup + 1;
    else
      v_err := v_err + 1;
    end if;
    v_result := v_result || jsonb_build_object(
      'row', v_rown, 'label', format('Dòng %s (%s.)', v_rown, coalesce(v_initial, '?')), 'initial', v_initial,
      'status', v_status, 'code', null, 'message', v_msg, 'warnings', to_jsonb(v_warnings),
      'resolved', case when v_status = 'HOP_LE' then jsonb_build_object(
        'username', v_username, 'email', v_email, 'display_name', v_name, 'branch_code', v_primary, 'role', v_role,
        'raw_branches', v_raw_branch, 'multi_branch', (upper(v_raw_branch) = 'ALL' or position(',' in v_raw_branch) > 0),
        'locked', v_locked, 'manager_username', v_manager) end);
  end loop;
  return jsonb_build_object('total', v_total, 'imported', v_ok, 'duplicates', v_dup, 'errors', v_err, 'rows', v_result);
end;
$$;

-- ---------------------------------------------------------------------------
-- app.import_user_create(mã tài khoản Auth, dữ liệu đã giải quyết): tạo tài khoản qua app.admin_create_account (một vai trò, cơ sở
-- chính, mã nhân viên cấp mới theo vai trò: TEACHER → GV, TA → TG, còn lại NV), rồi ghi tên đăng nhập của file vào legacy_ref.
-- Ai gọi: Admin (Edge Function, sau khi tạo người dùng Auth). Mật khẩu tạm bắt đổi lần đầu (must_change_password do admin_create_account đặt).
-- ---------------------------------------------------------------------------
create or replace function app.import_user_create(p_user_id uuid, p_resolved jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_kind text;
begin
  perform app.assert_account_admin();
  -- Luật: mã nhân viên cấp mới theo chuẩn mã, theo loại vai trò.
  v_kind := case p_resolved ->> 'role' when 'TEACHER' then 'GV' when 'TA' then 'TG' else 'NV' end;
  perform app.admin_create_account(p_user_id, p_resolved ->> 'display_name', p_resolved ->> 'email', p_resolved ->> 'branch_code',
                                   array[p_resolved ->> 'role'], null, v_kind, null);
  -- Luật R-V2-30: tên đăng nhập cũ lưu ở legacy_ref (tra cứu, nạp các loại sau, bỏ qua khi nạp lại).
  update app.user_account set legacy_ref = p_resolved ->> 'username' where id = p_user_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- app.import_user_set_manager(mã tài khoản, tên đăng nhập quản lý): gắn quản lý trực tiếp bằng app.set_manager (kiểm đủ luật R-HT-06).
-- Làm sau khi tạo hết tài khoản để quản lý đứng sau người được quản lý cũng gắn được.
-- ---------------------------------------------------------------------------
create or replace function app.import_user_set_manager(p_user_id uuid, p_manager_username text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_manager uuid;
begin
  perform app.assert_account_admin();
  select id into v_manager from app.user_account where legacy_ref = lower(p_manager_username) and student_code is null;
  if v_manager is null then
    perform app.raise_error('HMT_QUAN_LY_SAI', 'Quản lý trực tiếp không có trong hệ thống.');
  end if;
  perform app.set_manager(p_user_id, v_manager);
end;
$$;

-- ---------------------------------------------------------------------------
-- app.import_user_lock(mã tài khoản): khoá người nghỉ phép hoặc đã nghỉ (lý do "Nạp dữ liệu cũ"); Edge Function cấm đăng nhập ở Auth.
-- Làm sau khi gắn quản lý (quản lý phải là nhân viên đang hoạt động lúc gắn).
-- ---------------------------------------------------------------------------
create or replace function app.import_user_lock(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_account_admin();
  perform app.admin_set_locked(p_user_id, true, 'Nạp dữ liệu cũ: người nghỉ phép hoặc đã nghỉ');
end;
$$;

-- ---------------------------------------------------------------------------
-- app.import_users_finish(...): ghi nhật ký nạp một dòng cho cả lô (chỉ số liệu) và danh sách cơ sở nguyên văn của người có nhiều
-- cơ sở hoặc ALL. p_pending: [{user_id, raw_branches}]. Không chứa họ tên, email, tên đăng nhập, mật khẩu.
-- ---------------------------------------------------------------------------
create or replace function app.import_users_finish(
  p_file_name text, p_total integer, p_imported integer, p_duplicates integer, p_errors integer, p_pending jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_log uuid;
begin
  perform app.assert_account_admin();
  insert into app.import_log (kind, importer_id, file_name, rows_total, imported_count, duplicate_count, error_count)
  values ('NGUOI_DUNG', auth.uid(), left(nullif(btrim(coalesce(p_file_name, '')), ''), 200), p_total, p_imported, p_duplicates, p_errors) -- allow-number: độ dài tối đa tên file ghi nhật ký
  returning id into v_log;
  insert into app.import_user_branch_pending (import_log_id, user_id, raw_branches)
  select v_log, (e ->> 'user_id')::uuid, e ->> 'raw_branches' from jsonb_array_elements(coalesce(p_pending, '[]'::jsonb)) e;
end;
$$;

revoke execute on function app.import_users_resolve(jsonb), app.import_user_create(uuid, jsonb), app.import_user_set_manager(uuid, text),
  app.import_user_lock(uuid), app.import_users_finish(text, integer, integer, integer, integer, jsonb) from public, anon;
grant execute on function app.import_users_resolve(jsonb), app.import_user_create(uuid, jsonb), app.import_user_set_manager(uuid, text),
  app.import_user_lock(uuid), app.import_users_finish(text, integer, integer, integer, integer, jsonb) to authenticated;

select set_config('hmt.migration', '', false);
