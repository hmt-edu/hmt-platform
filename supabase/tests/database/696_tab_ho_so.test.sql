-- D-27-04 PR E (migration 696): lịch hẹn và phiếu tái tục trên hồ sơ phụ huynh, học sinh. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@tb.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@tb.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999994' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);




-- ---------- Hồ sơ giả ----------
insert into app.parent (code, full_name, phone, branch_id)
values ('PHD9601', 'Phụ huynh Giả Tab', '0991269601', (select id from app.branch where code = 'CS1')),
       ('PHD9602', 'Phụ huynh Giả Khác', '0991269602', (select id from app.branch where code = 'CS1'));
insert into app.student (code, full_name, birth_year, parent_id, branch_id)
values ('HSD9601', 'Học sinh Giả Tab', 2012, (select id from app.parent where code = 'PHD9601'), (select id from app.branch where code = 'CS1'));
create temp table ids as
  select (select id from app.parent where code = 'PHD9601') as p, (select id from app.parent where code = 'PHD9602') as khac,
         (select id from app.student where code = 'HSD9601') as s;
grant select on ids to authenticated;

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.log_contact('PARENT', (select p from ids), 'ZALO', 'HEN_GOI_LAI', 'Hẹn phụ huynh giả', now() + interval '2 days');
select app.log_contact('STUDENT', (select s from ids), 'ZALO', 'HEN_GOI_LAI', 'Hẹn học sinh giả', now() + interval '3 days');

select is((app.list_record_appointments(jsonb_build_object('parent_id', (select p from ids))) ->> 'total')::int, 2,
  'Tab Lịch hẹn phụ huynh: gồm lịch của phụ huynh và của con');
select is((app.list_record_appointments(jsonb_build_object('student_id', (select s from ids))) ->> 'total')::int, 1,
  'Tab Lịch hẹn học sinh: chỉ lịch của em');
select is(app.list_record_appointments(jsonb_build_object('student_id', (select s from ids))) -> 'rows' -> 0 ->> 'student_name', 'Học sinh Giả Tab',
  'Dòng lịch của em kèm tên học sinh');
select is((app.list_record_appointments(jsonb_build_object('parent_id', (select khac from ids))) ->> 'total')::int, 0,
  'Phụ huynh khác không thấy lịch của người này');
select is((app.list_record_appointments('{}'::jsonb) ->> 'total')::int, 0, 'Chặn: không nêu hồ sơ thì không trả lịch nào');
select is((app.list_record_appointments(jsonb_build_object('parent_id', (select p from ids), 'status', jsonb_build_array('HOAN_THANH'))) ->> 'total')::int, 0,
  'Lọc theo tình trạng');
select is((app.list_record_upsale(jsonb_build_object('parent_id', (select p from ids))) ->> 'total')::int, 0, 'Chưa có phiếu tái tục');

select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((app.list_record_appointments(jsonb_build_object('parent_id', (select p from ids))) ->> 'total')::int, 0,
  'Chặn: phạm vi Cơ sở ở cơ sở khác không thấy lịch');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.list_record_appointments(jsonb_build_object('student_id', (select s from ids)))$$), 'HMT_KHONG_CO_QUYEN',
  'Chặn: tài khoản học sinh không xem lịch hẹn');
select is(pg_temp.err($$select app.list_record_upsale(jsonb_build_object('student_id', (select s from ids)))$$), 'HMT_KHONG_CO_QUYEN',
  'Chặn: tài khoản học sinh không xem phiếu tái tục');

reset role;
select ok(position('ops_status_code' in pg_get_functiondef('app.list_record_upsale(jsonb,text,integer,integer)'::regprocedure)) = 0,
  'R-DD-02: số buổi vắng ở tab Tái tục chỉ đọc cột Giáo viên, không đọc cột vận hành');

select * from finish();
rollback;
