-- Migration 467 (Code D, 19/11/2026): sửa R2b của Soát (CAO). app.get_setting (security definer, cấp cho authenticated) cho tài khoản Học sinh gọi rpc đọc từng tham số
-- trong 73 tham số nội bộ, vòng qua chính sách RLS đã chặn ở migration 466. Chỉ đổi thân hàm (thêm một kiểm), chữ ký giữ nguyên; các hàm get_setting_int, _numeric, _bool gọi lại hàm này.
-- Phiên Học sinh (có vai trò, không phải nhân viên) chỉ đọc student_idle_logout_minutes và ba khoá cỡ trang; nhân viên và nơi gọi không có phiên đọc như cũ.
-- Phụ thuộc migration 466 (app.is_staff).
create or replace function app.get_setting(p_key text, p_branch_id uuid default null)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_value text;
begin
  -- Sửa R2b (Soát): phiên của người KHÔNG phải nhân viên (Học sinh) chỉ đọc được vài khoá cổng /hoc cần; mọi khoá khác báo không có quyền.
  -- Không áp dụng cho nơi gọi không có phiên (hook đăng nhập, pg_cron, migration): khi đó danh sách vai trò trong phiên rỗng.
  if cardinality(app.current_roles()) > 0 and not app.is_staff()
     and p_key not in ('student_idle_logout_minutes', 'list_page_size', 'list_page_size_default', 'list_page_size_max') then
    perform app.raise_error('HMT_KHONG_CO_QUYEN', 'Bạn không có quyền đọc tham số này.');
  end if;
  if not exists (select from app.setting_def where key = p_key) then
    perform app.raise_error('HMT_CAI_DAT_KHONG_CO', format('Chưa khai báo tham số "%s".', p_key));
  end if;
  select sb.value into v_value
    from app.setting_branch sb
   where sb.setting_key = p_key and sb.branch_id = p_branch_id and sb.is_active;
  if v_value is null then
    select value into v_value from app.setting_def where key = p_key;
  end if;
  return v_value;
end;
$$;
