-- P3c-3 (DB): list_appointments có bộ lọc tìm kiếm q và người phụ trách owner_id (TS-11; docs/spec/04 R-CRM-04, R-CRM-07).
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
insert into ld select 'A', (app.create_lead(pg_temp.lead_data('0900000901', '{"parent_name": "Chị Tìm Kiếm Alpha", "student_name": "Em Bông"}')) ->> 'id')::uuid;
insert into ld select 'B', (app.create_lead(pg_temp.lead_data('0900000902', '{"parent_name": "Anh Khác Beta", "student_name": "Em Sen"}')) ->> 'id')::uuid;
select app.create_appointment((select id from ld where k = 'A'), 'GOI_DIEN', now() + interval '2 days', 'Hẹn xem lớp Toán');
select app.create_appointment((select id from ld where k = 'B'), 'ZALO', now() + interval '3 days', 'Gửi báo giá');
create function pg_temp.n(p_filters jsonb) returns integer language sql stable as $$
  select (app.list_appointments(p_filters) ->> 'total')::int $$;
grant execute on function pg_temp.n(jsonb) to public;

-- ================= Tìm kiếm q =================
select is(pg_temp.n('{"q": "alpha"}'), 1, 'q: tìm theo tên phụ huynh (không phân biệt hoa thường)');
select is(pg_temp.n('{"q": "tim kiem"}'), 1, 'q: tìm không dấu');
select is(pg_temp.n('{"q": "em sen"}'), 1, 'q: tìm theo tên học sinh');
select is(pg_temp.n('{"q": "0900000901"}'), 1, 'q: tìm theo số điện thoại');
select is(pg_temp.n(jsonb_build_object('q', (select code from app.lead where id = (select id from ld where k = 'B')))), 1, 'q: tìm theo mã lead');
select is(pg_temp.n('{"q": "khong co ai ten the"}'), 0, 'q: không khớp thì rỗng');
select is(pg_temp.n('{}') >= 2, true, 'Không có q: không lọc');
select is(pg_temp.n('{"q": "   "}') >= 2, true, 'q chỉ có khoảng trắng: coi như không lọc');
-- ================= Người phụ trách owner_id =================
select is(pg_temp.n(jsonb_build_object('owner_id', pg_temp.uid('sales1'), 'q', 'khac beta')), 1, 'owner_id: đúng người phụ trách thì có');
select is(pg_temp.n(jsonb_build_object('owner_id', pg_temp.uid('sales1b'), 'q', 'khac beta')), 0, 'owner_id: người khác thì không');
-- ================= Phạm vi không đổi =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.n('{"q": "alpha"}'), 0, 'Tuyển sinh CS5 không tìm thấy lịch hẹn của CS1 dù khớp q');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.n('{"q": "alpha"}'), 1, 'Admin tìm thấy ở mọi cơ sở');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.list_appointments('{"q": "alpha"}')$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh không có quyền xem lịch hẹn');

select * from finish();
rollback;
