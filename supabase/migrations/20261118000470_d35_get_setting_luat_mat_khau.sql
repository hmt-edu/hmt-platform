-- Migration 470 (Code D, 19/11/2026): KHẨN D35, sửa P1 của Soát S16. Migration 467 (R2b) chặn Học sinh đọc get_setting nhưng chặn luôn hai khoá luật mật khẩu
-- (password_min_length, password_require_letter_digit) mà màn đổi mật khẩu lần đầu (NewPasswordForm) cần: Học sinh không đổi được mật khẩu, màn im lặng.
-- Sửa: (1) cho phép hai khoá này; (2) R2c: điều kiện chặn là «có phiên người dùng (auth.uid() khác rỗng) và không phải nhân viên», thay vì «danh sách vai trò khác rỗng»,
-- để phiên không có vai trò cũng bị chặn. Chỉ đổi thân hàm.

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
  -- Sửa R2b, R2c (Soát), D35 KHẨN: phiên đăng nhập của người KHÔNG phải nhân viên (Học sinh, Phụ huynh, phiên không có vai trò) chỉ đọc vài khoá cổng cần;
  -- khoá khác báo không có quyền. Điều kiện «có phiên» là auth.uid() khác rỗng (không phải danh sách vai trò, để phiên không vai trò cũng bị chặn).
  -- Không áp dụng cho nơi gọi không có phiên người dùng (hook đăng nhập, pg_cron, migration): auth.uid() rỗng.
  -- Hai khoá luật mật khẩu được phép: màn đổi mật khẩu lần đầu của Học sinh cần đọc (CHUNG-07); đây là luật hiển thị cho người nhập, không phải bí mật.
  if (select auth.uid()) is not null and not app.is_staff()
     and p_key not in ('student_idle_logout_minutes', 'list_page_size', 'list_page_size_default', 'list_page_size_max',
                       'password_min_length', 'password_require_letter_digit') then
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
