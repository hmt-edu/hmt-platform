-- QT-12 Nhật ký đăng nhập và xuất file (Code F, 18/11/2026). Luật S03-18, S03-21: Admin xem đăng nhập thành công/thất bại,
-- tạm khoá, các lần xuất file; mở khoá tạm cho người bị khoá do sai mật khẩu nhiều lần.
-- Chỉ mục: login_event_at_idx, login_event_login_idx, export_log_at_idx đã có (migration 011) cho sắp xếp theo thời gian và tìm theo tên đăng nhập.
-- Thêm login_event_result_idx (result, at desc) để lọc nhanh các lần thất bại/tạm khoá; export_log_user_idx (user_id, at desc) để lọc theo người xuất.
create index if not exists login_event_result_idx on app.login_event (result, at desc);
create index if not exists export_log_user_idx on app.export_log (user_id, at desc);

-- app.list_login_events(p_filters, p_limit, p_offset): một trang sự kiện đăng nhập, mới nhất trước. Ai gọi: Admin (đã hai bước).
-- Bộ lọc: q (chứa trong tên đăng nhập), result (một trong các kết quả), from, to (mốc to loại trừ). Kết quả {total, rows}.
create or replace function app.list_login_events(
  p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_q text := nullif(lower(btrim(coalesce(p_filters ->> 'q', ''))), '');
  v_result_f text := nullif(p_filters ->> 'result', '');
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_out jsonb;
begin
  -- Luật S03-18: chỉ Admin xem nhật ký đăng nhập.
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được xem nhật ký đăng nhập.');
  end if;
  with f as not materialized (
    select e.*
      from app.login_event e
     where (v_q is null or lower(e.login_name) like '%' || v_q || '%')
       and (v_result_f is null or e.result = v_result_f)
       and (v_from is null or e.at >= v_from)
       and (v_to is null or e.at < v_to)
  ),
  page as (select * from f order by f.at desc, f.id desc limit v_limit offset v_offset)
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'at', p.at, 'login_name', p.login_name, 'user_id', p.user_id,
             'branch_code', (select b.code from app.branch b where b.id = p.branch_id),
             'result', p.result, 'ip', host(p.ip), 'user_agent', p.user_agent,
             'temp_locked', coalesce((select u.temp_locked_until > now() from app.user_account u where u.id = p.user_id), false))
             order by p.at desc, p.id desc), '[]'::jsonb))
    into v_out
    from page p;
  return v_out;
end;
$$;
revoke execute on function app.list_login_events(jsonb, integer, integer) from public, anon;
grant execute on function app.list_login_events(jsonb, integer, integer) to authenticated;

-- app.list_export_log(p_filters, p_limit, p_offset): một trang nhật ký xuất file, mới nhất trước. Ai gọi: Admin (đã hai bước).
-- Bộ lọc: module (mã phân hệ), user (uuid người xuất), from, to (to loại trừ). Kết quả {total, rows}.
create or replace function app.list_export_log(
  p_filters jsonb default '{}'::jsonb, p_limit integer default null, p_offset integer default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, app.get_setting_int('list_page_size_default')), 1),
                           app.get_setting_int('list_page_size_max'));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_module text := nullif(p_filters ->> 'module', '');
  v_user uuid := nullif(p_filters ->> 'user', '')::uuid;
  v_from timestamptz := nullif(p_filters ->> 'from', '')::timestamptz;
  v_to timestamptz := nullif(p_filters ->> 'to', '')::timestamptz;
  v_out jsonb;
begin
  -- Luật S03-21: chỉ Admin xem nhật ký xuất file.
  if not app.has_permission('ADMIN', 'XEM') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Chỉ quản trị viên (đã xác thực hai bước) được xem nhật ký xuất file.');
  end if;
  with f as not materialized (
    select x.*
      from app.export_log x
     where (v_module is null or x.module_code = v_module)
       and (v_user is null or x.user_id = v_user)
       and (v_from is null or x.at >= v_from)
       and (v_to is null or x.at < v_to)
  ),
  page as (select * from f order by f.at desc, f.id desc limit v_limit offset v_offset)
  select jsonb_build_object(
           'total', (select count(*) from f),
           'rows', coalesce(jsonb_agg(jsonb_build_object(
             'id', p.id, 'at', p.at, 'user_id', p.user_id, 'user_name', app.staff_display_name(p.user_id),
             'branch_code', (select b.code from app.branch b where b.id = p.branch_id),
             'module_code', p.module_code, 'filters', p.filters, 'row_count', p.row_count)
             order by p.at desc, p.id desc), '[]'::jsonb))
    into v_out
    from page p;
  return v_out;
end;
$$;
revoke execute on function app.list_export_log(jsonb, integer, integer) from public, anon;
grant execute on function app.list_export_log(jsonb, integer, integer) to authenticated;

-- app.unlock_temp_login(p_user_id): mở khoá tạm (đã sai mật khẩu nhiều lần) để người đó đăng nhập lại ngay.
-- Ai gọi: Admin (Quản trị · Sửa, đã hai bước). Không đụng khoá hẳn (is_locked): khoá hẳn mở ở màn Người dùng.
create or replace function app.unlock_temp_login(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.assert_account_admin();
  -- Luật S03-18: tài khoản phải có thật.
  if not exists (select 1 from app.user_account where id = p_user_id) then
    perform app.raise_error('HMT_KHONG_TIM_THAY', 'Không tìm thấy tài khoản.');
  end if;
  -- Luật S03-18: xoá bộ đếm sai mật khẩu và mốc khoá tạm.
  update app.user_account set failed_login_count = 0, temp_locked_until = null where id = p_user_id;
end;
$$;
revoke execute on function app.unlock_temp_login(uuid) from public, anon;
grant execute on function app.unlock_temp_login(uuid) to authenticated;
