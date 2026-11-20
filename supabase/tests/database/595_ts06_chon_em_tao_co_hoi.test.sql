begin;
-- Migration 595: chọn em khi tạo cơ hội từ lead (app.create_opportunity p_student_ids) và app.add_lead_students_to_opportunity (TS-06).
-- Luật: R-CRM-23 (mặc định chọn tất cả em, được chọn 0 em, tối đa prospect_max_students, em trùng gộp một dòng), R-CRM-01, R-CRM-03 (từ L5 mỗi em có tên và năm sinh). Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@em9.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@em9.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('sales1', 'CS1'), ('sales5', 'CS5'), ('teacher5', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('sales5', 'SALES'), ('teacher5', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);


-- ================= Dựng dữ liệu: sáu lead ở CS1 (sales1), mỗi lead có em đầu «Em Đầu» (2012) =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900589001'));
select app.create_lead(pg_temp.lead_data('0900589002'));
select app.create_lead(pg_temp.lead_data('0900589003'));
select app.create_lead(pg_temp.lead_data('0900589004'));
select app.create_lead(pg_temp.lead_data('0900589005'));
select app.create_lead(pg_temp.lead_data('0900589006'));
select pg_temp.sudo($$create temp table ids as select id, parent_phone from app.lead where parent_phone like '09005890%'$$);
select pg_temp.sudo($$grant select on ids to authenticated$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable as 'select id from ids where parent_phone = p_phone'$$);
select pg_temp.sudo($$create function pg_temp.oid(p_phone text, p_n integer default 1) returns uuid language sql stable security definer as
  'select x.id from (select o.id, row_number() over (order by o.created_at) n from app.opportunity o where o.lead_id = (select id from ids where parent_phone = p_phone)) x where x.n = p_n'$$);
select pg_temp.sudo($$create function pg_temp.emid(p_phone text, p_name text) returns uuid language sql stable security definer as
  'select ps.id from app.prospect_student ps where ps.full_name = p_name and ps.lead_id = (select id from ids where parent_phone = p_phone)'$$);
select pg_temp.sudo($$create function pg_temp.nem(p_opp uuid) returns integer language sql stable security definer as
  'select count(*)::int from app.prospect_student where opportunity_id = p_opp'$$);
select pg_temp.sudo($$grant execute on function pg_temp.lid(text), pg_temp.oid(text, integer), pg_temp.emid(text, text), pg_temp.nem(uuid) to public$$);
-- Lead 1: 3 em (Em Đầu, Em Hai, Em Ba chưa năm sinh). Lead 2: 3 em. Lead 3: 2 em. Lead 4: Em Đầu, Em Hai và một em trùng họ tên, năm sinh. Lead 5: 5 em (đủ tối đa). Lead 6: Em Đầu, Em Ba chưa năm sinh.
select app.add_prospect_student('LEAD', pg_temp.lid('0900589001'), '{"full_name": "Em Hai", "birth_year": 2014}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900589001'), '{"full_name": "Em Ba"}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900589002'), '{"full_name": "Em Hai", "birth_year": 2014}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900589002'), '{"full_name": "Em Ba", "birth_year": 2015}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900589003'), '{"full_name": "Em Hai", "birth_year": 2014}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900589004'), '{"full_name": "Em Hai", "birth_year": 2014}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900589004'), '{"full_name": "  em  HAI ", "birth_year": 2014}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900589005'), '{"full_name": "Em Hai", "birth_year": 2014}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900589005'), '{"full_name": "Em Ba", "birth_year": 2015}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900589005'), '{"full_name": "Em Tư", "birth_year": 2016}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900589005'), '{"full_name": "Em Năm", "birth_year": 2017}');
select app.add_prospect_student('LEAD', pg_temp.lid('0900589006'), '{"full_name": "Em Ba"}');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);

-- ================= create_opportunity: chọn em =================
select app.create_opportunity(pg_temp.lid('0900589001'));
select is(pg_temp.nem(pg_temp.oid('0900589001')), 3, 'Tạo cơ hội không chọn gì: mặc định chép TẤT CẢ em của lead (3 em)');
select app.create_opportunity(pg_temp.lid('0900589002'), '{}', false, array[pg_temp.emid('0900589002', 'Em Ba')]);
select is(pg_temp.nem(pg_temp.oid('0900589002')), 1, 'Chọn một em: cơ hội chỉ có em đó');
select is((select (e ->> 'full_name') from jsonb_array_elements(app.get_opportunity(pg_temp.oid('0900589002')) -> 'students') e), 'Em Ba', 'Em được chép đúng người đã chọn');
select app.create_opportunity(pg_temp.lid('0900589003'), '{}', false, array[]::uuid[]);
select is(pg_temp.nem(pg_temp.oid('0900589003')), 0, 'Chọn 0 em (mảng rỗng): cơ hội không có em, vẫn tạo được (R-CRM-23)');
select app.create_opportunity(pg_temp.lid('0900589004'));
select is(pg_temp.nem(pg_temp.oid('0900589004')), 2, 'Em trùng họ tên (không phân biệt hoa thường, khoảng trắng) và năm sinh chỉ chép một dòng');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900589005'), '{}', false, array[pg_temp.emid('0900589001', 'Em Hai')])$$), 'HMT_EM_KHONG_THUOC_LEAD', 'Chặn: em được chọn thuộc lead khác');
select is((select count(*)::int from app.opportunity where lead_id = pg_temp.lid('0900589005')), 0, 'Chặn thì không tạo cơ hội nào (cả giao dịch huỷ)');
-- Gọi kiểu cũ (ba tham số, ghi đè em đầu bằng p_data): vẫn chạy, em đầu mang tên mới.
select app.create_opportunity(pg_temp.lid('0900589006'), '{"student_name": "Tên đổi", "student_birth_year": 2013}');
select is((select (e ->> 'full_name') from jsonb_array_elements(app.get_opportunity(pg_temp.oid('0900589006')) -> 'students') e where e ->> 'position' = '1'), 'Tên đổi', 'Gọi kiểu cũ: p_data ghi đè em đầu');

-- ================= add_lead_students_to_opportunity (Thêm em vào cơ hội cũ) =================
select is(jsonb_array_length(app.add_lead_students_to_opportunity(pg_temp.oid('0900589003'), array[pg_temp.emid('0900589003', 'Em Hai')])), 1, 'Thêm em vào cơ hội cũ (0 em): thêm Em Hai, danh sách có 1 em');
select is(jsonb_array_length(app.add_lead_students_to_opportunity(pg_temp.oid('0900589003'), null)), 2, 'Không chọn (null): thêm hết em còn lại của lead, cơ hội có 2 em');
select is(jsonb_array_length(app.add_lead_students_to_opportunity(pg_temp.oid('0900589003'), null)), 2, 'Thêm lần nữa: em đã có bị bỏ qua, vẫn 2 em (không nhân đôi)');
select is(pg_temp.err($$select app.add_lead_students_to_opportunity(pg_temp.oid('0900589003'), array[pg_temp.emid('0900589001', 'Em Hai')])$$), 'HMT_EM_KHONG_THUOC_LEAD', 'Chặn: em của lead khác không thêm được vào cơ hội này');
-- Tối đa: cơ hội của lead 5 có 1 em riêng; lead 5 có 5 em; thêm hết thì vượt.
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where id = pg_temp.lid('0900589005')$$);
select app.create_opportunity(pg_temp.lid('0900589005'), '{}', false, array[pg_temp.emid('0900589005', 'Em Đầu')]);
select is(pg_temp.nem(pg_temp.oid('0900589005')), 1, 'Cơ hội của lead 5 bắt đầu với 1 em');
select pg_temp.sudo($$update app.prospect_student set full_name = 'Em riêng của cơ hội', birth_year = 2010 where opportunity_id = pg_temp.oid('0900589005')$$);
select is(pg_temp.err($$select app.add_lead_students_to_opportunity(pg_temp.oid('0900589005'), null)$$), 'HMT_EM_TOI_DA', 'Chặn (R-CRM-23): 1 em riêng + 5 em của lead vượt số em tối đa');
select is(pg_temp.nem(pg_temp.oid('0900589005')), 1, 'Chặn thì không thêm em nào (cả giao dịch huỷ)');
-- Từ L5: em thiếu năm sinh không chép được.
select app.create_opportunity(pg_temp.lid('0900589001'), '{}', true, array[pg_temp.emid('0900589001', 'Em Đầu')]);
select app.change_opportunity_stage(pg_temp.oid('0900589001', 2), 'L5');
select is(pg_temp.err($$select app.add_lead_students_to_opportunity(pg_temp.oid('0900589001', 2), array[pg_temp.emid('0900589001', 'Em Ba')])$$), 'HMT_THIEU_HOC_SINH', 'Chặn (R-CRM-03): cơ hội từ L5 không nhận em thiếu năm sinh');

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900589002'), '{}', true, array[]::uuid[])$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: sale cơ sở khác không tạo cơ hội từ lead CS1');
select is(pg_temp.err($$select app.add_lead_students_to_opportunity(pg_temp.oid('0900589003'), null)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: sale cơ sở khác không thêm em vào cơ hội CS1');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.add_lead_students_to_opportunity(pg_temp.oid('0900589003'), null)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không có quyền Sửa cơ hội');
reset role;
set local role anon;
select is(pg_temp.err($$select app.add_lead_students_to_opportunity(pg_temp.oid('0900589003'), null)$$), '42501', 'Chặn: khách chưa đăng nhập không gọi được add_lead_students_to_opportunity');
select is(pg_temp.err($$select app.prospect_copy_lines(pg_temp.lid('0900589001'), pg_temp.oid('0900589001'), null)$$), '42501', 'Chặn: hàm trong prospect_copy_lines không mở cho API');
reset role;

select * from finish();
rollback;
