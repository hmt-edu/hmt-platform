-- Code F (23/11/2026), thẻ PH-2 → PR-A, migration 644: phụ huynh đăng nhập bằng số điện thoại (DN11, CHUNG-23).
-- Làm gì: hàm app.login_parent_code_by_phone cho Edge Function login đổi số điện thoại thành mã phụ huynh của tài khoản, rồi đăng nhập như cũ (mã PH là khoá, SĐT chỉ là tên đăng nhập).
-- Luật (PH-2): một SĐT có thể ứng với nhiều hồ sơ phụ huynh; mọi hồ sơ cùng SĐT dùng MỘT tài khoản (tài khoản cấp sớm nhất còn dùng được), thấy các con ở PR-B.
select set_config('hmt.migration', 'on', false);

-- app.login_parent_code_by_phone(số điện thoại): trả mã PH của tài khoản phụ huynh dùng để đăng nhập, hoặc null nếu không có.
-- Ai gọi: chỉ Edge Function login (service_role). Không lộ ra giao diện: mọi trường hợp «không có» cùng một câu trả lời sai ở bước sau.
-- Chỉ mục: parent_phone_idx (migration 24) cho tra theo SĐT; user_account.parent_code đã unique.
create or replace function app.login_parent_code_by_phone(p_phone text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select ua.parent_code
    from app.parent p
    join app.user_account ua on ua.parent_code = p.code
   where p.phone = btrim(p_phone) and not ua.is_locked
   order by ua.created_at, ua.parent_code
   limit 1;
$$;
revoke execute on function app.login_parent_code_by_phone(text) from public, anon, authenticated;
grant execute on function app.login_parent_code_by_phone(text) to service_role;

select set_config('hmt.migration', '', false);
