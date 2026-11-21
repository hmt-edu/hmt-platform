-- Migration 600: app.ticket_filter_rows thêm khoá parent_id, student_id (tab Ticket ở hồ sơ phụ huynh KH-02, học sinh KH-05) qua list_tickets, ticket_group_counts.
-- Luật: RLS ticket theo cơ sở (người không có quyền Xem thấy 0 dòng); bộ lọc cũ giữ nguyên. Dữ liệu giả.
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
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh1'), ('cskh5'), ('gv5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@k19.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@k19.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' when key like 'cskh%' then 'CSKH' else 'TEACHER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
grant execute on all functions in schema pg_temp to public;

-- Phụ huynh giả: A (CS1, có con đang học), B (CS1, chưa), C (CS5, chưa, có học sinh để mở ticket).
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values
  ('PHK19A', 'Phụ huynh giả 571 A', '0900571001', pg_temp.cs('CS1')), ('PHK19B', 'Phụ huynh giả 571 B', '0900571002', pg_temp.cs('CS1')),
  ('PHK19C', 'Phụ huynh giả 571 C', '0900571003', pg_temp.cs('CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id) values
  ('HSK19A', (select id from app.parent where code = 'PHK19A'), 'Em giả 571 A', 2012, pg_temp.cs('CS1')),
  ('HSK19C', (select id from app.parent where code = 'PHK19C'), 'Em giả 571 C', 2012, pg_temp.cs('CS5'))$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, delivery_mode_code, status_code, purchased_hours, gifted_hours)
  select 'GDK19A', st.id, st.parent_id, st.branch_id, 'TOAN', 'OFF', 'DANG_HOC', 24, 0 from app.student st where st.code = 'HSK19A'$$);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code in ('CS5', 'CS1')
  on conflict (module_code, branch_id) do update set enabled = true$$);

create function pg_temp.mk(p_type text, p_cat text, p_branch text, p_parent text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('ticket_type', p_type, 'branch_id', (select id from app.branch where code = p_branch), 'title', 'Tiêu đề giả 571', 'description', 'Mô tả giả',
    'channel_code', 'GOI_DIEN', 'category_code', p_cat, 'parent_id', (select id from app.parent where code = p_parent)) || p_extra $$;
grant execute on function pg_temp.mk(text, text, text, text, jsonb) to public;

-- Ticket giả: cskh5 tạo hai ticket ở CS5 (Khiếu nại, Đề nghị Cập nhật thông tin); cskh1 tạo một Khiếu nại ở CS1. Chưa ai được giao.
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select app.create_ticket(pg_temp.mk('KN', 'KN_02_02', 'CS5', 'PHK19C'));
select app.create_ticket(pg_temp.mk('DN', 'DN_04_01', 'CS5', 'PHK19C', jsonb_build_object('student_id', (select id from app.student where code = 'HSK19C'))));
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.create_ticket(pg_temp.mk('KN', 'KN_02_02', 'CS1', 'PHK19A'));


-- ================= Bộ lọc parent_id, student_id =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.list_tickets(jsonb_build_object('q', 'giả 571', 'parent_id', (select id from app.parent where code = 'PHK19C'))) ->> 'total')::int, 2, 'Lọc theo phụ huynh C: 2 ticket (cskh5 tạo)');
select is((app.list_tickets(jsonb_build_object('q', 'giả 571', 'parent_id', (select id from app.parent where code = 'PHK19A'))) ->> 'total')::int, 1, 'Lọc theo phụ huynh A: 1 ticket (cskh1 tạo)');
select is((app.list_tickets(jsonb_build_object('q', 'giả 571', 'parent_id', (select id from app.parent where code = 'PHK19B'))) ->> 'total')::int, 0, 'Lọc theo phụ huynh B chưa có ticket: 0 dòng');
select is((app.list_tickets(jsonb_build_object('q', 'giả 571', 'student_id', (select id from app.student where code = 'HSK19C'))) ->> 'total')::int, 1, 'Lọc theo học sinh C: 1 ticket (Đề nghị có học sinh)');
select is((app.list_tickets(jsonb_build_object('q', 'giả 571', 'student_id', (select id from app.student where code = 'HSK19A'))) ->> 'total')::int, 0, 'Lọc theo học sinh A chưa có ticket: 0 dòng');
select is((app.list_tickets(jsonb_build_object('q', 'giả 571', 'parent_id', (select id from app.parent where code = 'PHK19C'), 'ticket_type', 'KN')) ->> 'total')::int, 1, 'Lọc phụ huynh kết hợp loại ticket: 1 Khiếu nại');
select is((app.ticket_group_counts(jsonb_build_object('q', 'giả 571', 'parent_id', (select id from app.parent where code = 'PHK19C')), array['type']) ->> 'total')::int, 2, 'Đếm nhóm cũng theo bộ lọc phụ huynh');
select is(jsonb_array_length(app.list_tickets(jsonb_build_object('q', 'giả 571', 'parent_id', (select id from app.parent where code = 'PHK19C')), 1, 0) -> 'rows'), 1, 'Phân trang với bộ lọc phụ huynh: limit 1 chỉ một dòng');
select is((app.list_tickets(jsonb_build_object('q', 'giả 571', 'parent_id', (select id from app.parent where code = 'PHK19C')), 1, 0) ->> 'total')::int, 2, 'Phân trang vẫn báo tổng 2');
-- Phạm vi quyền (RLS): CSKH CS5 không thấy ticket của phụ huynh CS1; giáo viên không thấy ticket nào.
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is((app.list_tickets(jsonb_build_object('q', 'giả 571', 'parent_id', (select id from app.parent where code = 'PHK19A'))) ->> 'total')::int, 0, 'RLS: CSKH CS5 lọc theo phụ huynh CS1 thấy 0 ticket');
select is((app.list_tickets(jsonb_build_object('q', 'giả 571', 'parent_id', (select id from app.parent where code = 'PHK19C'))) ->> 'total')::int, 2, 'RLS: CSKH CS5 thấy 2 ticket của phụ huynh CS5');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is((app.list_tickets(jsonb_build_object('q', 'giả 571', 'parent_id', (select id from app.parent where code = 'PHK19C'))) ->> 'total')::int, 0, 'RLS: giáo viên không thấy ticket của phụ huynh');
reset role;
set local role anon;
select is(pg_temp.err($$select app.list_tickets('{}')$$), '42501', 'Chặn: khách chưa đăng nhập không gọi được list_tickets');
reset role;

select * from finish();
rollback;
