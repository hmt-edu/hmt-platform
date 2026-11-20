begin;
-- Migration 599: tạo phiếu kiểm tra chọn em trong danh sách em của cơ hội (app.create_student_test, p_data.prospect_student_id; TS-15).
-- Luật: R-CRM-23 (phiếu chọn em trong danh sách của cơ hội), R-CRM-27 (hồ sơ học sinh tìm hoặc tạo từ em), R-CRM-05 (L5 trở đi). Dữ liệu giả.
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
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Em Thử', 'parent_phone', p_phone, 'student_name', 'Em Đầu', 'student_birth_year', 2012,
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1'), ('sales5'), ('teacher5');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@em90.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@em90.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('sales1', 'CS1'), ('sales5', 'CS5'), ('teacher5', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('sales5', 'SALES'), ('teacher5', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);


-- ================= Dựng dữ liệu: hai lead ở CS1 (sales1); lead 1 có 2 em (Em Đầu 2012, Em Hai 2014) và thành cơ hội L5; lead 2 là cơ hội khác =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900590001'));
select app.create_lead(pg_temp.lead_data('0900590002'));
select app.add_prospect_student('LEAD', (select id from app.lead where parent_phone = '0900590001'), '{"full_name": "Em Hai", "birth_year": 2014}');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity((select id from app.lead where parent_phone = '0900590001'));
select app.create_opportunity((select id from app.lead where parent_phone = '0900590002'));
select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as
  'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone'$$);
select pg_temp.sudo($$create function pg_temp.em(p_phone text, p_pos integer) returns uuid language sql stable security definer as
  'select ps.id from app.prospect_student ps where ps.opportunity_id = pg_temp.oid(p_phone) and ps.position = p_pos'$$);
select pg_temp.sudo($$create function pg_temp.td(p_extra jsonb default '{}'::jsonb) returns jsonb language sql stable as
  'select jsonb_build_object(''subject_code'', ''TOAN'', ''grade_code'', (select code from app.catalog_item where catalog_code = ''GRADE'' order by sort_order limit 1),
     ''mode_code'', ''OFFLINE'', ''level_code'', ''CO_BAN'', ''exam_name'', ''Toán cơ bản'', ''scheduled_at'', now() + interval ''3 days'') || p_extra'$$);
select pg_temp.sudo($$create function pg_temp.test_em(p_test_id uuid) returns uuid language sql security definer as
  'select prospect_student_id from app.student_test where id = p_test_id'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oid(text), pg_temp.em(text, integer), pg_temp.td(jsonb), pg_temp.test_em(uuid) to public$$);
select app.change_opportunity_stage(pg_temp.oid('0900590001'), 'L5');
select app.change_opportunity_stage(pg_temp.oid('0900590002'), 'L5');

-- ================= Chọn em khi tạo phiếu =================
select is(pg_temp.test_em(((app.create_student_test(pg_temp.oid('0900590001'), pg_temp.td()) ->> 'id'))::uuid), pg_temp.em('0900590001', 1), 'Không chọn em: phiếu gắn EM ĐẦU như cũ');
select is(pg_temp.test_em(((app.create_student_test(pg_temp.oid('0900590001'), pg_temp.td(jsonb_build_object('prospect_student_id', pg_temp.em('0900590001', 2)))) ->> 'id'))::uuid), pg_temp.em('0900590001', 2), 'Chọn Em Hai: phiếu gắn đúng em đã chọn');
select ok((select student_id is not null from app.prospect_student where id = pg_temp.em('0900590001', 2)), 'Tạo phiếu gắn hồ sơ học sinh vào dòng em đã chọn (R-CRM-27)');
select is((select count(*)::int from app.student_test where opportunity_id = pg_temp.oid('0900590001')), 2, 'Hai em, hai phiếu của cùng một cơ hội');
select is(pg_temp.test_em(((app.create_student_test(pg_temp.oid('0900590001'), pg_temp.td(jsonb_build_object('prospect_student_id', pg_temp.em('0900590001', 2)))) ->> 'id'))::uuid), pg_temp.em('0900590001', 2), 'Một em có thể có hai phiếu (TS15_hai_phieu)');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('0900590001'), pg_temp.td(jsonb_build_object('prospect_student_id', pg_temp.em('0900590002', 1))))$$), 'HMT_EM_KHONG_THUOC_CO_HOI', 'Chặn: em của cơ hội khác');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('0900590001'), pg_temp.td(jsonb_build_object('prospect_student_id', '00000000-0000-0000-0000-000000000001')))$$), 'HMT_EM_KHONG_THUOC_CO_HOI', 'Chặn: id em không có');
select is((select count(*)::int from app.student_test where opportunity_id = pg_temp.oid('0900590001')), 3, 'Chặn thì không thêm phiếu nào');

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('0900590001'), pg_temp.td(jsonb_build_object('prospect_student_id', pg_temp.em('0900590001', 2))))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: sale cơ sở khác không tạo phiếu cho cơ hội CS1');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('0900590001'), pg_temp.td())$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không có quyền Tạo phiếu kiểm tra');
reset role;
set local role anon;
select is(pg_temp.err($$select app.create_student_test(pg_temp.oid('0900590001'), pg_temp.td())$$), '42501', 'Chặn: khách chưa đăng nhập không tạo phiếu');
reset role;

select * from finish();
rollback;
