-- Phiếu nghiệp vụ (migration 260): list_ticket_tasks (lọc, phân trang, chờ tôi duyệt, chờ kế toán, RLS) và get_ticket_task (chi tiết, can_approve). Dữ liệu giả.
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
insert into u (key) values ('admin'), ('cskh5'), ('cskh1'), ('gv5'), ('gv5b'), ('qlcs5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@as.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@as.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' when key like 'cskh%' then 'CSKH' when key like 'gv%' then 'TEACHER' else 'BRANCH_MANAGER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHAS501', 'Phụ huynh giả ticket', '0900002001', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  values ('HSAS501', (select id from app.parent where code = 'PHAS501'), 'Học sinh giả ticket', 2013, (select id from app.branch where code = 'CS5'))$$);
grant execute on all functions in schema pg_temp to public;

create function pg_temp.mk(p_type text, p_cat text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('ticket_type', p_type, 'branch_id', (select id from app.branch where code = 'CS5'), 'title', 'Tiêu đề giả', 'description', 'Mô tả giả',
    'channel_code', 'GOI_DIEN', 'category_code', p_cat, 'parent_id', (select id from app.parent where code = 'PHAS501')) || p_extra $$;
grant execute on function pg_temp.mk(text, text, jsonb) to public;

select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code in ('CS5', 'CS1')
  on conflict (module_code, branch_id) do update set enabled = true$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
create temp table t1 (j jsonb);
grant all on t1 to public;
insert into t1 select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'));

create temp table pt1 (j jsonb);
grant all on pt1 to public;
insert into pt1 select app.create_ticket(pg_temp.mk('DN', 'DN_04_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))));
create temp table pk1 (j jsonb);
grant all on pk1 to public;
insert into pk1 select app.create_ticket_task((select (j ->> 'id')::uuid from pt1), 'CAP_NHAT_HO_SO', 'Đổi trường', '{"entity":"STUDENT","changes":{"school":"Trường X"}}'::jsonb);
-- Phiếu hai cấp (Hoàn học phí)
create temp table pt2 (j jsonb);
grant all on pt2 to public;
insert into pt2 select app.create_ticket(pg_temp.mk('DN', 'DN_02_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))));
create temp table pk2 (j jsonb);
grant all on pk2 to public;
insert into pk2 select app.create_ticket_task((select (j ->> 'id')::uuid from pt2), 'HOAN_PHI', 'Chuyển nhà', '{}'::jsonb);
select app.submit_ticket_task((select (j ->> 'id')::uuid from pk2));
select app.submit_ticket_task((select (j ->> 'id')::uuid from pk1));
-- Trong một giao dịch mọi dòng cùng created_at (now()), và trigger khung chung giữ created_at không đổi khi sửa: thứ tự kế là id tăng dần (hàm sắp created_at giảm, rồi id).

-- ================= Danh sách =================
select is((app.list_ticket_tasks() ->> 'total')::int, 2, 'Danh sách: CSKH thấy hai phiếu của cơ sở');
select is((select r ->> 'code' from jsonb_array_elements(app.list_ticket_tasks('{}'::jsonb, 1, 0) -> 'rows') r), (select k.code from app.ticket_task k where k.id in ((select (j ->> 'id')::uuid from pk1), (select (j ->> 'id')::uuid from pk2)) order by k.id limit 1), 'Phân trang: một dòng, theo thứ tự sắp của danh sách');
select is((app.list_ticket_tasks('{}'::jsonb, 1, 1) -> 'rows' -> 0 ->> 'code'), (select k.code from app.ticket_task k where k.id in ((select (j ->> 'id')::uuid from pk1), (select (j ->> 'id')::uuid from pk2)) order by k.id desc limit 1), 'Phân trang: trang hai là phiếu còn lại');
select is((app.list_ticket_tasks('{"task_type":"HOAN_PHI"}'::jsonb) ->> 'total')::int, 1, 'Lọc theo loại phiếu');
select is((app.list_ticket_tasks('{"status_code":"DA_DUYET"}'::jsonb) ->> 'total')::int, 0, 'Lọc theo trạng thái: chưa có phiếu Đã duyệt');
select is((app.list_ticket_tasks(jsonb_build_object('q', (select j ->> 'code' from pt1))) ->> 'total')::int, 1, 'Tìm theo mã ticket gốc');
select is((app.list_ticket_tasks(jsonb_build_object('q', (select j ->> 'code' from pk2))) ->> 'total')::int, 1, 'Tìm theo mã phiếu');
select is((app.list_ticket_tasks('{"cho_toi":true}'::jsonb) ->> 'total')::int, 0, 'CSKH không có quyền duyệt: không có phiếu «Chờ tôi duyệt»');
select is((app.list_ticket_tasks('{"cho_ke_toan":true}'::jsonb) ->> 'total')::int, 0, 'Chưa phiếu nào ở cấp kế toán');
select is((select (r ->> 'level_total')::int from jsonb_array_elements(app.list_ticket_tasks() -> 'rows') r where r ->> 'code' = (select j ->> 'code' from pk2)), 2, 'Dòng có số cấp duyệt (Hoàn học phí hai cấp)');
select is((app.list_ticket_tasks() -> 'rows' -> 0 ->> 'student_name'), 'Học sinh giả ticket', 'Dòng có tên học sinh');

-- ================= Chờ tôi duyệt: quản lý cơ sở =================
select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
select is((app.list_ticket_tasks('{"cho_toi":true}'::jsonb) ->> 'total')::int, 2, 'Quản lý cơ sở: hai phiếu chờ tôi duyệt');
select app.approve_ticket_task((select (j ->> 'id')::uuid from pk2));
select is((app.list_ticket_tasks('{"cho_toi":true}'::jsonb) ->> 'total')::int, 1, 'Sau khi duyệt cấp 1, phiếu hai cấp không còn «chờ tôi» (cấp kế toán)');
select is((app.list_ticket_tasks('{"cho_ke_toan":true}'::jsonb) ->> 'total')::int, 1, 'Phiếu hai cấp nằm ở hàng chờ kế toán');
select is((select (app.get_ticket_task((select (j ->> 'id')::uuid from pk1)) -> 'task' ->> 'can_approve')::boolean), true, 'Chi tiết: quản lý cơ sở duyệt được phiếu cấp 1');
select is((select (app.get_ticket_task((select (j ->> 'id')::uuid from pk2)) -> 'task' ->> 'can_approve')::boolean), false, 'Chi tiết: cấp kế toán thì quản lý cơ sở không duyệt được');
select is((select jsonb_array_length(app.get_ticket_task((select (j ->> 'id')::uuid from pk2)) -> 'events')), 3, 'Chi tiết: dòng thời gian Tạo, Trình, Duyệt');
select is((select app.get_ticket_task((select (j ->> 'id')::uuid from pk1)) -> 'ticket' ->> 'student_name'), 'Học sinh giả ticket', 'Chi tiết: có tên học sinh của ticket');
select is(pg_temp.err($$select app.get_ticket_task(gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Chặn: phiếu không có');

-- ================= Người tạo không thấy mình «chờ tôi» + cơ sở khác =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((app.list_ticket_tasks() ->> 'total')::int, 0, 'CSKH cơ sở khác không thấy phiếu (RLS)');
select is(pg_temp.err($$select app.get_ticket_task((select (j ->> 'id')::uuid from pk1))$$), 'HMT_KHONG_TIM_THAY', 'Chặn: CSKH cơ sở khác không mở được chi tiết phiếu');
select is(has_function_privilege('anon', 'app.list_ticket_tasks(jsonb,integer,integer)', 'execute'), false, 'anon không gọi được hàm danh sách phiếu');

select * from finish();
rollback;
