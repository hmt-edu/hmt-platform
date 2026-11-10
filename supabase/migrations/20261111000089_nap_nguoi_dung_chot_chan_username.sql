-- ===========================================================================
-- Nạp Người dùng: chốt chặn trùng tên đăng nhập với cột username (anh chốt 06/11, Q-24). Trước đây bước kiểm chỉ so với legacy_ref (tài khoản đã nạp);
-- tài khoản tạo bằng cách khác (Admin đầu tiên tạo bằng Bootstrap rồi đặt tên đăng nhập bằng set_username) không bị nhận ra và sẽ bị nạp thêm một tài khoản
-- thứ hai với email quy ước. Nay tên đăng nhập đã có (username hoặc legacy_ref) thì dòng thành TRUNG (bỏ qua, báo), không tạo tài khoản thứ hai.
-- Quản lý trực tiếp tra theo cả username lẫn legacy_ref. Chỉ đổi hai hàm; ràng buộc duy nhất của username (migration 074) vẫn là chốt cuối.
-- ===========================================================================
select set_config('hmt.migration', 'on', false);

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
        if not (v_manager = any (v_names)) and not exists (select from app.user_account where (legacy_ref = v_manager or lower(username) = v_manager) and student_code is null) then
          perform app.raise_error('HMT_QUAN_LY_SAI', 'Quản lý trực tiếp không có trong file hay hệ thống.');
        end if;
      end if;
      -- Luật: đã có tài khoản cùng tên đăng nhập thì bỏ qua (TRUNG), không ghi đè. Email đã thuộc người khác là LOI.
      -- Chốt chặn (anh chốt 06/11, Q-24): tên đăng nhập đã có trên hệ thống (cột username, ví dụ Admin đầu tiên tạo bằng Bootstrap rồi đặt set_username,
      -- hoặc tài khoản đã nạp lần trước theo legacy_ref) thì BỎ QUA và báo, không tạo tài khoản thứ hai.
      if exists (select from app.user_account where (legacy_ref = v_username or lower(username) = v_username) and student_code is null) then
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
  select id into v_manager from app.user_account where (legacy_ref = lower(p_manager_username) or lower(username) = lower(p_manager_username)) and student_code is null;
  if v_manager is null then
    perform app.raise_error('HMT_QUAN_LY_SAI', 'Quản lý trực tiếp không có trong hệ thống.');
  end if;
  perform app.set_manager(p_user_id, v_manager);
end;
$$;

revoke execute on function app.import_users_resolve(jsonb), app.import_user_set_manager(uuid, text) from public, anon;
grant execute on function app.import_users_resolve(jsonb), app.import_user_set_manager(uuid, text) to authenticated;

select set_config('hmt.migration', '', false);
