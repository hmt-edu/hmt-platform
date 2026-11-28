-- C69 (migration 437): Group By ở máy chủ cho danh sách Tái tục TT-01 (upsale_group_counts), bộ lọc owner_id, substage_code, vỏ bọc list_upsale_tickets_grouped: đếm theo tình trạng, cơ sở, hai cấp, bộ lọc; chặn trường lạ, trùng cấp, không quyền. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('gv5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@c69.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@c69.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code) select id, case when key = 'admin' then 'ADMIN' else 'TEACHER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

-- Phiếu tái tục giả (replica để khỏi dựng học sinh, lớp thật): ba phiếu CS5 (L1 hai phiếu, L2 một phiếu có người phụ trách là admin), một L1 CS1.
select pg_temp.sudo($$set local session_replication_role = 'replica'$$);
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, owner_id, origin_code, expected_end_date)
  select v.c, (select id from app.branch where code = v.b), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), v.s, v.ss,
         case when v.c = 'TTC69-3' then (select id from u where key = 'admin') end, 'TAY', date '2026-12-15'
    from (values ('TTC69-1', 'CS5', 'L1', 'L1B'), ('TTC69-2', 'CS5', 'L1', 'L1A'), ('TTC69-3', 'CS5', 'L2', 'L2B'), ('TTC69-4', 'CS1', 'L1', 'L1B')) v (c, b, s, ss)$$);
-- C-27-17: đợt tái tục tính lúc đọc, nên mỗi phiếu cần ghi danh đang học còn giờ và lớp có khung giờ (3 giờ, 1,5 giờ mỗi tuần).
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code)
  select 'GD-' || code, student_id, parent_id, branch_id, 'DANG_HOC' from app.upsale_ticket where code like 'TTC69%'$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, t.class_id, t.branch_id, current_date from app.upsale_ticket t join app.enrollment e on e.code = 'GD-' || t.code$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours)
  select id, branch_id, 'CAP_MUA', 3 from app.enrollment where code like 'GD-TTC69%'$$);
select pg_temp.sudo($$insert into app.class_slot (class_id, branch_id, weekday, start_time, end_time, first_date)
  select class_id, branch_id, extract(isodow from current_date)::int, '18:00', '19:30', current_date from app.upsale_ticket where code like 'TTC69%'$$);
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time)
  select t.class_id, t.branch_id, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 7 * n, '18:00', '19:30'
    from app.upsale_ticket t, generate_series(1, 2) n where t.code like 'TTC69%'$$);
select pg_temp.sudo($$set local session_replication_role = 'origin'$$);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.upsale_group_counts('{"q": "TTC69"}'::jsonb, array['stage']) ->> 'total')::int, 4, 'Group By giai đoạn: tổng 4 phiếu tái tục giả');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.upsale_group_counts('{"q": "TTC69"}'::jsonb, array['stage']) -> 'groups') g where g ->> 'k1' = 'L1'), 3, 'Nhóm L1 có 3 phiếu');
select is(jsonb_array_length(app.upsale_group_counts('{"q": "TTC69"}'::jsonb, array['stage', 'substage']) -> 'groups'), 3, 'Hai cấp giai đoạn, nhóm con: ba nhóm lá (L1·L1B, L1·L1A, L2·L2B)');
select is((select g ->> 'l1' from jsonb_array_elements(app.upsale_group_counts('{"q": "TTC69"}'::jsonb, array['campaign']) -> 'groups') g), 'Tái tục ' || to_char((now() at time zone 'Asia/Ho_Chi_Minh')::date + 14, 'MM/YYYY'), 'Nhãn nhóm đợt tái tục theo tháng hết giờ dự kiến');
select is((select g ->> 'l1' from jsonb_array_elements(app.upsale_group_counts('{"q": "TTC69"}'::jsonb, array['owner']) -> 'groups') g where g ->> 'k1' = (select id::text from u where key = 'admin')), 'Giả admin', 'Nhãn nhóm phụ trách là tên người');
select is((app.upsale_group_counts('{"q": "TTC69", "owner_id": null}'::jsonb, array['stage']) ->> 'total')::int, 4, 'Bộ lọc owner_id rỗng không lọc');
select is((app.upsale_group_counts(jsonb_build_object('q', 'TTC69', 'owner_id', (select id from u where key = 'admin')), array['stage']) ->> 'total')::int, 1, 'Bộ lọc owner_id áp dụng cho số đếm (mở nhóm phụ trách)');
select is((app.upsale_group_counts('{"q": "TTC69", "substage_code": "L1B"}'::jsonb, array['stage']) ->> 'total')::int, 2, 'Bộ lọc substage_code áp dụng cho số đếm');
select is((app.list_upsale_tickets_grouped('{"q": "TTC69", "stage_code": "L1"}'::jsonb, 'created_desc', 50, 0) ->> 'total')::int, 3, 'Vỏ bọc mở nhóm lá trả đúng 3 phiếu L1');
select is(pg_temp.err($$select app.upsale_group_counts('{}'::jsonb, array['student'])$$), 'HMT_NHOM_SAI', 'Chặn: trường nhóm không cho phép');
select is(pg_temp.err($$select app.upsale_group_counts('{}'::jsonb, array['stage', 'stage'])$$), 'HMT_NHOM_SAI', 'Chặn: hai cấp giống nhau');

select * from finish();
rollback;
