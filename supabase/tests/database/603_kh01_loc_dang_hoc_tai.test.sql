-- Migration 603: KH-01 bộ lọc «Đang học tại» (studying_branch_id) ở app.list_parents và app.parent_group_counts; parent_group_counts chỉ cho phạm vi Toàn hệ thống, Cơ sở.
-- Luật: R-CRM-26/27 (phạm vi Xem phụ huynh), «Đang học tại» = ghi danh Đã xếp lớp hoặc Đang học ở cơ sở. Dữ liệu giả.
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



set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
-- Phụ huynh A (CS1) có ghi danh Đang học ở CS1; B và C không có.
select is((app.list_parents(jsonb_build_object('search', 'gia 571', 'studying_branch_id', pg_temp.cs('CS1'))) ->> 'total')::int, 1, 'Lọc «Đang học tại» CS1: 1 phụ huynh (A)');
select is((app.list_parents(jsonb_build_object('search', 'gia 571', 'studying_branch_id', pg_temp.cs('CS5'))) ->> 'total')::int, 0, 'Lọc «Đang học tại» CS5: 0 phụ huynh');
select is((app.list_parents(jsonb_build_object('search', 'gia 571', 'studying_branch_id', pg_temp.cs('CS1'))) -> 'rows' -> 0 ->> 'code'), 'PHK19A', 'Phụ huynh lọc ra đúng là A');
select is((app.list_parents(jsonb_build_object('search', 'gia 571', 'studying_branch_id', pg_temp.cs('CS1'), 'status', jsonb_build_array('CHUA_DANG_HOC'))) ->> 'total')::int, 0, 'Lọc «Đang học tại» kết hợp Chưa có con đang học: 0 (mâu thuẫn)');
select is((app.list_parents(jsonb_build_object('search', 'gia 571', 'studying_branch_id', pg_temp.cs('CS1'), 'branch_id', pg_temp.cs('CS1'))) ->> 'total')::int, 1, 'Lọc «Đang học tại» kết hợp cơ sở tiếp nhận: 1');
select is((app.list_parents(jsonb_build_object('search', 'gia 571')) ->> 'total')::int, 3, 'Không lọc «Đang học tại»: vẫn 3 phụ huynh giả');
-- Đếm nhóm cùng điều kiện, tổng bằng danh sách.
select is((app.parent_group_counts(jsonb_build_object('search', 'gia 571', 'studying_branch_id', pg_temp.cs('CS1')), array['status']) ->> 'total')::int, 1, 'Đếm nhóm theo «Đang học tại» CS1: tổng 1');
select is((app.parent_group_counts(jsonb_build_object('search', 'gia 571', 'studying_branch_id', pg_temp.cs('CS5')), array['branch']) ->> 'total')::int, 0, 'Đếm nhóm theo «Đang học tại» CS5: tổng 0');
select is((app.parent_group_counts(jsonb_build_object('search', 'gia 571', 'studying_branch_id', pg_temp.cs('CS1')), array['branch']) ->> 'total')::int,
          (app.list_parents(jsonb_build_object('search', 'gia 571', 'studying_branch_id', pg_temp.cs('CS1'))) ->> 'total')::int, 'Tổng đếm nhóm bằng total danh sách khi lọc «Đang học tại»');
-- Chặn.
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$select app.list_parents('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không xem danh sách phụ huynh');
select is(pg_temp.err($$select app.parent_group_counts('{}', array['status'])$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không đếm nhóm phụ huynh');
reset role;
set local role anon;
select is(pg_temp.err($$select app.list_parents('{}')$$), '42501', 'Chặn: khách chưa đăng nhập không gọi được list_parents');
reset role;

select * from finish();
rollback;
