-- PR 5a: hàm công khai tên cơ sở dạy học cho trang đăng nhập (anh Trường chốt 12/10).
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;
grant execute on all functions in schema pg_temp to public;

-- Người chưa đăng nhập gọi được.
set local role anon;
select is((select array_agg(code order by code) from public.login_branch_names()), array['CS1', 'CS2', 'CS4', 'CS5'],
          'Chưa đăng nhập: thấy bốn cơ sở dạy học, không có Hội sở (CS3)');
select is((select array_agg(name order by code) from public.login_branch_names()),
          array['Nguyễn Chí Thanh', 'Đỗ Quang', 'Hà Đông', 'Mỹ Đình'], 'Chỉ trả tên cơ sở');
select is((select array_agg(a.attname order by a.attnum) from pg_proc p
           cross join lateral unnest(p.proargnames) with ordinality as a(attname, attnum)
           where p.proname = 'login_branch_names' and p.pronamespace = 'public'::regnamespace and p.proargmodes is not null
             and a.attnum <= 2), array['code', 'name'], 'Hàm chỉ có hai cột: mã và tên');
-- Bảng cơ sở thì anon vẫn không đọc được (hàm không mở thêm lối khác).
select is(pg_temp.err($$select * from app.branch$$), '42501', 'Chưa đăng nhập: không đọc thẳng bảng cơ sở');
reset role;

-- Cơ sở ngừng hoạt động không hiện.
update app.branch set is_active = false where code = 'CS4';
set local role anon;
select is((select count(*)::int from public.login_branch_names()), 3, 'Cơ sở đã Ngừng không hiện ở trang đăng nhập');
reset role;

-- Người đã đăng nhập cũng gọi được (trang đăng nhập có thể mở lại khi đã có phiên).
set local role authenticated;
select is((select count(*)::int from public.login_branch_names()), 3, 'Đã đăng nhập: cũng gọi được');

select * from finish();
rollback;
