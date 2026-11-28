-- C-27-13 (migration 709): Trưởng cơ sở xử lý được phiếu tái tục cơ sở mình; email phụ huynh. Luật R-GD-13, R-CRM-28. Dữ liệu giả.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$ begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.tid(p_code text) returns uuid language sql stable security definer as $$ select id from app.upsale_ticket where code = p_code $$;
create function pg_temp.pid() returns uuid language sql stable security definer as $$ select id from app.parent where code = 'PH709' $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('bm1'), ('bm5');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p709.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p709.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('bm1', 'CS1'), ('bm5', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code) select id, 'BRANCH_MANAGER' from u;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH709', 'Phụ huynh giả 709', '0900709001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HS709A', p.id, 'Em A', 2012, p.branch_id from app.parent p where p.code = 'PH709'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select 'LOP709', id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10 from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, origin_code)
  select 'TT917091', s.branch_id, s.id, s.parent_id, c.id, 'L1', 'TAY' from app.student s, app.class c where s.code = 'HS709A' and c.code = 'LOP709'$$);

set local role authenticated;
-- ---- Trưởng cơ sở mình ----
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(app.get_upsale_ticket(pg_temp.tid('TT917091')) -> 'actions' @> '["giao", "doi_giai_doan", "sua_ghi_chu", "tao_bao_gia"]'::jsonb, true,
          'Trưởng cơ sở: Giao, Chuyển giai đoạn, Ghi chú, Tạo báo giá trên phiếu cơ sở mình');
select is(app.change_upsale_stage(pg_temp.tid('TT917091'), 'L2', p_substage => 'L2A') ->> 'stage_code', 'L2', 'Trưởng cơ sở chuyển được giai đoạn');
-- ---- Trưởng cơ sở khác ----
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.change_upsale_stage(pg_temp.tid('TT917091'), 'L3', p_substage => 'L3A')$$), 'HMT_KHONG_CO_QUYEN', 'Trưởng cơ sở khác không đổi được giai đoạn');

-- ---- Email phụ huynh ----
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.update_parent(pg_temp.pid(), '{"email": "  PhuHuynh.Gia@Example.INVALID "}');
select is(app.get_parent_record(pg_temp.pid()) ->> 'email', 'phuhuynh.gia@example.invalid', 'Email lưu chữ thường, bỏ khoảng trắng');
select is(app.get_upsale_ticket(pg_temp.tid('TT917091')) -> 'parent' ->> 'email', 'phuhuynh.gia@example.invalid', 'Phiếu tái tục trả đúng email');
select is(pg_temp.err($$select app.update_parent(pg_temp.pid(), '{"email": "khong-phai-email"}')$$), 'HMT_EMAIL_SAI', 'Email sai định dạng bị chặn');
select app.update_parent(pg_temp.pid(), '{"relative_name": "Bà"}');
select is(app.get_parent_record(pg_temp.pid()) ->> 'email', 'phuhuynh.gia@example.invalid', 'Sửa trường khác không mất email');
select app.update_parent(pg_temp.pid(), '{"email": ""}');
select is(app.get_parent_record(pg_temp.pid()) ->> 'email', null, 'Email không bắt buộc: xoá trống được');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.update_parent(pg_temp.pid(), '{"email": "a@b.invalid"}')$$), 'HMT_KHONG_CO_QUYEN', 'Cơ sở khác không sửa được email');

select * from finish();
rollback;
