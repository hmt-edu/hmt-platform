-- Giai đoạn khởi đầu của lead (docs/spec/04 R-CRM-39): lead mới luôn ở C1, bỏ qua giai đoạn người gọi truyền vào.
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò nhập trong và ngoài cơ sở.
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
-- Lấy câu lỗi tiếng Việt (MESSAGE) của một lệnh.
create function pg_temp.msg(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
-- Chạy một câu lệnh với quyền chủ DB (dựng dữ liệu thử khi đang đóng vai người dùng).
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Thử Một', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1'), ('teacher1'), ('teacher5'), ('hs');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999999' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);


-- ================= Dựng dữ liệu =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
create temp table ld (k text primary key, id uuid);
grant select on ld to public;
insert into ld select 'tron', (app.create_lead(pg_temp.lead_data('0900000901', '{"parent_name": "Chị Khởi Đầu Một"}')) ->> 'id')::uuid;
-- Người gọi cố truyền giai đoạn, nhóm con (kể cả C4D do hệ thống gắn) vào dữ liệu tạo.
insert into ld select 'c4', (app.create_lead(pg_temp.lead_data('0900000902', '{"parent_name": "Chị Khởi Đầu Hai", "stage_code": "C4", "substage_code": "C4B"}')) ->> 'id')::uuid;
insert into ld select 'c4d', (app.create_lead(pg_temp.lead_data('0900000903', '{"parent_name": "Chị Khởi Đầu Ba", "stage_code": "C4", "substage_code": "C4D"}')) ->> 'id')::uuid;
insert into ld select 'rac', (app.create_lead(pg_temp.lead_data('0900000904', '{"parent_name": "Chị Khởi Đầu Bốn", "stage_code": "C9", "stage_catalog": "KHAC"}')) ->> 'id')::uuid;
create function pg_temp.stage(p_k text) returns text[] language sql stable as $$
  select array[stage_code, substage_code] from app.lead where id = (select id from ld where k = p_k) $$;
grant execute on function pg_temp.stage(text) to public;

-- ================= R-CRM-39 =================
select is(pg_temp.stage('tron'), array['C1', null], 'R-CRM-39: lead mới tạo bình thường ở C1, chưa có nhóm con');
select is(pg_temp.stage('c4'), array['C1', null], 'R-CRM-39: lead mới luôn ở C1, bỏ qua giai đoạn truyền vào (C4, C4B)');
select is(pg_temp.stage('c4d'), array['C1', null], 'R-CRM-39: không nhận C4D (do hệ thống gắn) từ người gọi, vẫn ở C1');
select is(pg_temp.stage('rac'), array['C1', null], 'R-CRM-39: giai đoạn không có trong danh mục cũng bị bỏ qua, lead vẫn ở C1');
-- Sau khi tạo, giai đoạn đổi theo R-CRM-09.
select app.change_lead_stage((select id from ld where k = 'tron'), 'C3', 'C3A');
select is(pg_temp.stage('tron'), array['C3', 'C3A'], 'Sau khi tạo, giai đoạn lead đổi được (R-CRM-09)');
-- Sửa lead không đổi được giai đoạn qua update_lead.
select app.update_lead((select id from ld where k = 'tron'), '{"stage_code": "C1", "need": "x"}');
select is(pg_temp.stage('tron'), array['C3', 'C3A'], 'update_lead không đổi giai đoạn (có hàm riêng)');
-- Mọi vai trò có quyền tạo đều bắt đầu ở C1.
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((select (app.create_lead(pg_temp.lead_data('0900000905', '{"parent_name": "Chị Khởi Đầu Năm", "stage_code": "C2"}')) ->> 'id')::uuid is not null), true, 'CSKH tạo lead');
select is((select stage_code from app.lead where parent_phone = '0900000905'), 'C1', 'R-CRM-39: CSKH truyền C2 vẫn bắt đầu ở C1');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select app.create_lead(pg_temp.lead_data('0900000906', '{"parent_name": "Chị Khởi Đầu Sáu", "stage_code": "C3"}'));
select is((select stage_code from app.lead where parent_phone = '0900000906'), 'C1', 'R-CRM-39: Trưởng cơ sở truyền C3 vẫn bắt đầu ở C1');

select * from finish();
rollback;
