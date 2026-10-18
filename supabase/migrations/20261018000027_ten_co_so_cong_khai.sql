-- PR 5a (đăng nhập): hàm công khai trả TÊN cơ sở dạy học cho cột giới thiệu của trang đăng nhập (CHUNG-01, 06).
-- Anh Trường chốt 12/10: hàm công khai chỉ trả tên các cơ sở dạy học (CS1, CS2, CS4, CS5), không trả Hội sở (cơ sở
-- văn phòng) và không trả địa chỉ, người dùng, hay bất kỳ dữ liệu nào khác.
-- Ai gọi: người chưa đăng nhập (anon) và đã đăng nhập. security definer vì bảng cơ sở không cho anon đọc.

create or replace function public.login_branch_names()
returns table (code text, name text)
language sql
stable
security definer
set search_path = ''
as $$
  select b.code, b.name
    from app.branch b
   where b.is_active and not b.is_office
   order by b.sort_order, b.code;
$$;

comment on function public.login_branch_names() is
  'Tên các cơ sở dạy học đang hoạt động (không gồm Hội sở) cho trang đăng nhập; chỉ mã và tên.';

revoke execute on function public.login_branch_names() from public;
grant execute on function public.login_branch_names() to anon, authenticated;
