-- KHO #19 (migration 571): Group By ở máy chủ cho KH-01 Phụ huynh (app.parent_group_counts) và CS-01 Ticket (app.ticket_group_counts, app.ticket_filter_rows, bộ lọc mới của list_tickets).
-- Luật: R-CRM-27 (phụ huynh chỉ xem, quyền «Phụ huynh · Xem»), AS-07 (bộ lọc hạn xử lý), RLS ticket theo cơ sở, Group By tối đa hai cấp khác nhau (K1_nhom). Dữ liệu giả.
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

-- ================= KH-01 Phụ huynh: app.parent_group_counts =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((app.parent_group_counts('{"search":"gia 571"}', array['status']) ->> 'total')::int, 3, 'Phụ huynh: tổng đếm nhóm = tổng danh sách (3 phụ huynh giả)');
select is((app.parent_group_counts('{"search":"gia 571"}', array['status']) ->> 'total')::int, (app.list_parents('{"search":"gia 571"}') ->> 'total')::int,
          'Phụ huynh: tổng đếm nhóm bằng total của list_parents (cùng bộ lọc)');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.parent_group_counts('{"search":"gia 571"}', array['status']) -> 'groups') g where g ->> 'k1' = 'DANG_HOC'), 1,
          'Phụ huynh nhóm Tình trạng: 1 phụ huynh có con đang học');
select is((select g ->> 'l1' from jsonb_array_elements(app.parent_group_counts('{"search":"gia 571"}', array['status']) -> 'groups') g where g ->> 'k1' = 'CHUA_DANG_HOC'), 'Chưa có con đang học',
          'Phụ huynh nhóm Tình trạng: nhãn tiếng Việt');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.parent_group_counts('{"search":"gia 571"}', array['status']) -> 'groups') g where g ->> 'k1' = 'CHUA_DANG_HOC'), 2,
          'Phụ huynh nhóm Tình trạng: 2 phụ huynh chưa có con đang học');
select is(jsonb_array_length(app.parent_group_counts('{"search":"gia 571"}', array['branch']) -> 'groups'), 2, 'Phụ huynh nhóm Cơ sở: 2 cơ sở (CS1, CS5)');
select is(jsonb_array_length(app.parent_group_counts('{"search":"gia 571"}', array['branch', 'status']) -> 'groups'), 3, 'Phụ huynh hai cấp Cơ sở rồi Tình trạng: 3 nhóm lá');
select is((app.parent_group_counts('{"search":"gia 571","status":["DANG_HOC"]}', array['branch']) ->> 'total')::int, 1, 'Phụ huynh: bộ lọc nhanh Tình trạng áp dụng cho số đếm nhóm');
select is((app.parent_group_counts('{"search":"gia 571","branch_id":"' || pg_temp.cs('CS5') || '"}', array['status']) ->> 'total')::int, 1, 'Phụ huynh: điều kiện cơ sở áp dụng cho số đếm nhóm');
-- Mở một nhóm: bộ lọc của nhóm cho đúng số dòng.
select is((app.list_parents('{"search":"gia 571","status":["CHUA_DANG_HOC"]}') ->> 'total')::int, 2, 'Phụ huynh: mở nhóm Chưa có con đang học cho 2 dòng khớp số đếm');
select is(pg_temp.err($$select app.parent_group_counts('{}', array['studying_at'])$$), 'HMT_NHOM_SAI', 'Chặn: Đang học tại không phải trường nhóm (nhiều cơ sở cùng lúc)');
select is(pg_temp.err($$select app.parent_group_counts('{}', array['status', 'status'])$$), 'HMT_NHOM_SAI', 'Chặn: hai cấp nhóm trùng nhau');
select is(pg_temp.err($$select app.parent_group_counts('{}', array['status', 'branch', 'status'])$$), 'HMT_NHOM_SAI', 'Chặn: quá hai cấp nhóm');
select is(pg_temp.err($$select app.parent_group_counts('{}', array[]::text[])$$), 'HMT_NHOM_SAI', 'Chặn: không chọn trường nhóm');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$select app.parent_group_counts('{}', array['status'])$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không xem phụ huynh nên không đếm nhóm phụ huynh');
reset role;
set local role anon;
select is(pg_temp.err($$select app.parent_group_counts('{}', array['status'])$$), '42501', 'Chặn: khách chưa đăng nhập không gọi được parent_group_counts');
reset role;

-- ================= CS-01 Ticket: app.ticket_group_counts, bộ lọc mới của list_tickets =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.ticket_group_counts('{"q":"giả 571"}', array['type']) ->> 'total')::int, 3, 'Ticket: tổng đếm nhóm = 3 ticket giả (admin thấy mọi cơ sở)');
select is((app.ticket_group_counts('{"q":"giả 571"}', array['type']) ->> 'total')::int, (app.list_tickets('{"q":"giả 571"}') ->> 'total')::int, 'Ticket: tổng đếm nhóm bằng total của list_tickets (cùng bộ lọc)');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.ticket_group_counts('{"q":"giả 571"}', array['type']) -> 'groups') g where g ->> 'k1' = 'KN'), 2, 'Ticket nhóm Loại: 2 Khiếu nại');
select is((select g ->> 'l1' from jsonb_array_elements(app.ticket_group_counts('{"q":"giả 571"}', array['type']) -> 'groups') g where g ->> 'k1' = 'DN'), 'Đề nghị', 'Ticket nhóm Loại: nhãn Đề nghị');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.ticket_group_counts('{"q":"giả 571"}', array['status']) -> 'groups') g where g ->> 'k1' = 'MOI'), 3, 'Ticket nhóm Trạng thái: cả 3 ticket vừa tạo ở Mới');
select is((select g ->> 'l1' from jsonb_array_elements(app.ticket_group_counts('{"q":"giả 571"}', array['status']) -> 'groups') g where g ->> 'k1' = 'MOI'), 'Mới', 'Ticket nhóm Trạng thái: nhãn lấy từ danh mục');
select is(jsonb_array_length(app.ticket_group_counts('{"q":"giả 571"}', array['branch']) -> 'groups'), 2, 'Ticket nhóm Cơ sở: 2 cơ sở (CS1, CS5)');
select is((select sum((g ->> 'count')::int)::int from jsonb_array_elements(app.ticket_group_counts('{"q":"giả 571"}', array['group', 'priority']) -> 'groups') g), 3,
          'Ticket hai cấp Nhóm rồi Mức độ: tổng số đếm các nhóm lá bằng tổng danh sách');
select ok((select bool_and(g ->> 'l1' is not null) from jsonb_array_elements(app.ticket_group_counts('{"q":"giả 571"}', array['group']) -> 'groups') g), 'Ticket nhóm Nhóm: mọi nhóm có tên (nhóm cha của danh mục)');
-- Chưa giao: một nhóm khoá rỗng «Chưa có»; mở nhóm bằng no_assignee cho đúng 3 dòng.
select is((select g ->> 'k1' from jsonb_array_elements(app.ticket_group_counts('{"q":"giả 571"}', array['assignee']) -> 'groups') g), '', 'Ticket nhóm Người xử lý: chưa ai được giao nên chỉ có nhóm khoá rỗng');
select is((app.list_tickets('{"q":"giả 571","no_assignee":true}') ->> 'total')::int, 3, 'Ticket: bộ lọc no_assignee (mở nhóm Chưa có) cho 3 dòng');
select is((app.list_tickets('{"q":"giả 571","assignee_id":"' || pg_temp.uid('cskh5') || '"}') ->> 'total')::int, 0, 'Ticket: bộ lọc assignee_id không khớp người nào thì 0 dòng');
-- Mở nhóm: bộ lọc của từng nhóm khớp số đếm.
select is((app.list_tickets('{"q":"giả 571","ticket_type":"KN"}') ->> 'total')::int, 2, 'Ticket: mở nhóm Loại Khiếu nại cho 2 dòng khớp số đếm');
select is((app.list_tickets(jsonb_build_object('q', 'giả 571', 'group_code', (select g ->> 'k1' from jsonb_array_elements(app.ticket_group_counts('{"q":"giả 571"}', array['group']) -> 'groups') g
                                                                       order by (g ->> 'count')::int desc limit 1))) ->> 'total')::int,
          (select (g ->> 'count')::int from jsonb_array_elements(app.ticket_group_counts('{"q":"giả 571"}', array['group']) -> 'groups') g order by (g ->> 'count')::int desc limit 1),
          'Ticket: mở nhóm theo group_code cho số dòng bằng số đếm của nhóm đó');
-- Bộ lọc cũ của list_tickets giữ nguyên sau khi chuyển sang app.ticket_filter_rows.
select is((app.list_tickets('{"q":"giả 571","sla_state":"QUA_HAN"}') ->> 'total')::int, 0, 'Ticket: bộ lọc hạn xử lý Quá hạn vẫn chạy (ticket mới chưa quá hạn)');
select is((app.list_tickets('{"q":"giả 571","branch_id":"' || pg_temp.cs('CS1') || '"}') ->> 'total')::int, 1, 'Ticket: bộ lọc cơ sở vẫn chạy');
select is((select count(*)::int from app.ticket_board('{"q":"giả 571"}') b, jsonb_array_elements(b -> 'rows')), 3, 'Ticket: Kanban (ticket_board) vẫn dùng bộ lọc chung, đủ 3 ticket');
select is(jsonb_array_length(app.list_tickets('{"q":"giả 571"}', 2, 0) -> 'rows'), 2, 'Ticket: phân trang limit 2 chỉ hai dòng');
select is((app.list_tickets('{"q":"giả 571"}', 2, 0) ->> 'total')::int, 3, 'Ticket: phân trang vẫn báo tổng 3');
-- Phạm vi quyền (RLS): người gọi chỉ đếm ticket mình thấy, số đếm nhóm luôn bằng total của danh sách.
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is((app.ticket_group_counts('{"q":"giả 571"}', array['type']) ->> 'total')::int, (app.list_tickets('{"q":"giả 571"}') ->> 'total')::int, 'RLS: CSKH CS5, số đếm nhóm bằng total danh sách (cùng phạm vi cơ sở)');
select is((app.list_tickets('{"q":"giả 571","mine":true}') ->> 'total')::int, 2, 'Ticket: bộ lọc Của tôi vẫn chạy (cskh5 tạo 2 ticket)');
select ok((app.ticket_group_counts('{"q":"giả 571"}', array['type']) ->> 'total')::int < 3, 'RLS: CSKH CS5 không đếm ticket của cơ sở CS1');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is((app.ticket_group_counts('{"q":"giả 571"}', array['type']) ->> 'total')::int, (app.list_tickets('{"q":"giả 571"}') ->> 'total')::int, 'RLS: giáo viên, số đếm nhóm bằng total danh sách (không thấy ticket của người khác)');
select ok((app.ticket_group_counts('{"q":"giả 571"}', array['type']) ->> 'total')::int = 0, 'RLS: giáo viên không có ticket nào của mình nên đếm 0');
-- Bị chặn.
select is(pg_temp.err($$select app.ticket_group_counts('{}', array['sla'])$$), 'HMT_NHOM_SAI', 'Chặn: SLA không phải trường nhóm của ticket');
select is(pg_temp.err($$select app.ticket_group_counts('{}', array['type', 'type'])$$), 'HMT_NHOM_SAI', 'Chặn: hai cấp nhóm trùng nhau');
select is(pg_temp.err($$select app.ticket_group_counts('{}', array['type', 'status', 'branch'])$$), 'HMT_NHOM_SAI', 'Chặn: quá hai cấp nhóm');
select is(pg_temp.err($$select app.ticket_group_counts('{}', array[]::text[])$$), 'HMT_NHOM_SAI', 'Chặn: không chọn trường nhóm');
reset role;
set local role anon;
select is(pg_temp.err($$select app.ticket_group_counts('{}', array['type'])$$), '42501', 'Chặn: khách chưa đăng nhập không gọi được ticket_group_counts');
select is(pg_temp.err($$select app.ticket_filter_rows('{}')$$), '42501', 'Chặn: khách chưa đăng nhập không gọi được ticket_filter_rows');
reset role;

select * from finish();
rollback;
