-- D-26-09 phần a (migration 689): R-LOP-07 chặn Trình lớp chung thiếu khung chương trình, sau tham số class_curriculum_required_enabled.
-- Dữ liệu giả; chèn thẳng lớp và thời khoá biểu với trigger tắt.
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
grant execute on all functions in schema pg_temp to public;

create temp table u (id uuid not null default gen_random_uuid());
insert into u default values;
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', 'bm1@d2609a.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả bm1', 'bm1@d2609a.hoamatoan.invalid', b.id, false from u, app.branch b where b.code = 'CS1';
insert into app.user_role (user_id, role_code) select id, 'BRANCH_MANAGER' from u;

create temp table ids (key text primary key, type_code text not null, curriculum text, id uuid not null default gen_random_uuid());
insert into ids (key, type_code, curriculum) values
  ('tat', 'CB', null), ('thieu', 'CB', null), ('trang', 'NC', '   '), ('du', 'CB', 'KHUNG-GIA'), ('rieng', 'LR', null);
grant select on ids to authenticated;

set local session_replication_role = 'replica';
insert into app.class (id, code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, status_code, start_date, total_sessions, curriculum_ref)
select i.id, 'CS1-D2609A-' || i.key, b.id, '2627', 'TOAN', 'K08', i.type_code, case when i.type_code = 'LR' then null else 'A' end,
       'NHAP', date '2027-01-05', 8, i.curriculum
  from ids i, app.branch b where b.code = 'CS1';
insert into app.class_slot (class_id, branch_id, weekday, start_time, end_time, first_date)
select i.id, b.id, 2, time '18:00', time '19:30', date '2027-01-05' from ids i, app.branch b where b.code = 'CS1';
set local session_replication_role = 'origin';

create function pg_temp.trinh(p_key text) returns text language plpgsql as $$
begin
  return pg_temp.err(format('select app.transition_class(%L, %L)', (select id from pg_temp.ids where key = p_key), 'DA_TRINH'));
end $$;
grant execute on function pg_temp.trinh(text) to public;

select is(app.get_setting_bool('class_curriculum_required_enabled'), false, 'R-LOP-07: tham số bắt buộc khung mặc định TẮT');
select pg_temp.claims((select id from u), 'aal1');
set local role authenticated;
select is(pg_temp.trinh('tat'), null, 'Tắt: lớp chung thiếu khung vẫn trình được');
reset role;

update app.setting_def set value = 'true' where key = 'class_curriculum_required_enabled';
select pg_temp.claims((select id from u), 'aal1');
set local role authenticated;
select is(pg_temp.trinh('thieu'), 'HMT_LOP_THIEU_KHUNG_CHUONG_TRINH', 'Bật: lớp chung chưa có khung bị chặn trình');
select is(pg_temp.trinh('trang'), 'HMT_LOP_THIEU_KHUNG_CHUONG_TRINH', 'Bật: khung chỉ có dấu cách cũng bị chặn');
select is(pg_temp.trinh('du'), null, 'Bật: lớp chung có khung trình được');
select is(pg_temp.trinh('rieng'), null, 'Bật: lớp riêng không cần khung');
reset role;
select is((select status_code from app.class where id = (select id from ids where key = 'thieu')), 'NHAP', 'Bị chặn thì lớp vẫn ở Nháp');

select * from finish();
rollback;
