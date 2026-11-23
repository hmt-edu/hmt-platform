-- HT-1 nền cổng Học tập/Phụ huynh: app.portal_student_ids, portal_require_student, portal_children (migration 637).
-- Luật: học sinh chỉ thấy chính mình; phụ huynh chỉ thấy con mình; nhân viên không dùng được hàm cổng; tài khoản khoá không thấy gì;
-- công tắc phân hệ Học tập (HOC_TAP) tắt ở cơ sở thì chặn.
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
create function pg_temp.claims(p_user uuid) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal1')));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.sid(p_code text) returns uuid language plpgsql security definer as $$ begin return (select id from app.student where code = p_code); end $$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả: hs1, hs2 (học sinh), ph1, ph2 (phụ huynh), ph3 (phụ huynh bị khoá), nv (nhân viên) ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('hs1'), ('hs2'), ('ph1'), ('ph2'), ('ph3'), ('nv'), ('hs3');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ht1.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, parent_code, is_locked, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ht1.hoamatoan.invalid', (select id from app.branch where code = 'CS1'),
       case u.key when 'hs1' then 'HS992001' when 'hs2' then 'HS992003' when 'hs3' then 'HS992004' end,
       case u.key when 'ph1' then 'PH992001' when 'ph2' then 'PH992002' when 'ph3' then 'PH992003' end,
       u.key = 'ph3', false
  from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('hs1', 'STUDENT'), ('hs2', 'STUDENT'), ('hs3', 'STUDENT'), ('ph1', 'PARENT'), ('ph2', 'PARENT'), ('ph3', 'PARENT'), ('nv', 'SALES')) as v (key, role) on v.key = u.key;

-- ---------- Dữ liệu: PH992001 có 2 con (HS992001, HS992002), PH992002 có 1 con (HS992003), PH992003 có 1 con; HS992004 ở CS2 (Học tập tắt) ----------
insert into app.parent (code, full_name, phone, branch_id)
select c.code, c.name, c.phone, (select id from app.branch where code = c.br)
  from (values ('PH992001', 'Phụ huynh Mẫu Ht Một', '0992100001', 'CS1'), ('PH992002', 'Phụ huynh Mẫu Ht Hai', '0992100002', 'CS1'),
               ('PH992003', 'Phụ huynh Mẫu Ht Ba', '0992100003', 'CS1'), ('PH992004', 'Phụ huynh Mẫu Ht Bốn', '0992100004', 'CS2')) as c (code, name, phone, br);
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = c.ph), c.name, 2012, (select id from app.branch where code = c.br)
  from (values ('HS992001', 'PH992001', 'Em Ht Một', 'CS1'), ('HS992002', 'PH992001', 'Em Ht Hai', 'CS1'),
               ('HS992003', 'PH992002', 'Em Ht Ba', 'CS1'), ('HS992004', 'PH992004', 'Em Ht Bốn', 'CS2'),
               ('HS992005', 'PH992003', 'Em Ht Năm', 'CS1')) as c (code, ph, name, br);
-- Công tắc Học tập: bật ở CS1, tắt ở CS2.
insert into app.feature_flag (module_code, branch_id, enabled)
select 'HOC_TAP', b.id, b.code = 'CS1' from app.branch b where b.code in ('CS1', 'CS2')
on conflict (module_code, branch_id) do update set enabled = excluded.enabled;
update app.user_account set branch_id = (select id from app.branch where code = 'CS2') where login_name = 'hs3@ht1.hoamatoan.invalid';

-- ===== Luật: học sinh chỉ thấy chính mình =====
select pg_temp.claims(pg_temp.uid('hs1'));
set local role authenticated;
select is((select count(*)::int from app.portal_student_ids()), 1, 'Luật quyền riêng: học sinh chỉ thấy đúng một học sinh (chính mình)');
select is((select jsonb_array_length(app.portal_children())), 1, 'Danh sách con của học sinh: chỉ chính mình');
select is(pg_temp.err($$select app.portal_require_student(pg_temp.sid('HS992001'))$$), null, 'Học sinh xem dữ liệu của chính mình được');
select is(pg_temp.err($$select app.portal_require_student(pg_temp.sid('HS992002'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: học sinh xem học sinh khác (anh em) bị chặn');
select is(pg_temp.err($$select app.portal_require_student(pg_temp.sid('HS992003'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: học sinh xem học sinh nhà khác bị chặn');
select is(pg_temp.err($$select app.portal_require_student(null)$$), 'HMT_KHONG_CO_QUYEN', 'Thiếu học sinh thì bị chặn');
reset role;

-- ===== Luật: phụ huynh chỉ thấy con mình =====
select pg_temp.claims(pg_temp.uid('ph1'));
set local role authenticated;
select is((select count(*)::int from app.portal_student_ids()), 2, 'Luật quyền riêng: phụ huynh có hai con thấy đúng hai em');
select is((select jsonb_array_length(app.portal_children())), 2, 'Danh sách con: hai em cho chip chọn con');
select is(app.portal_children() -> 0 ->> 'code', 'HS992002', 'Danh sách con sắp theo tên (Hai trước Một)');
select is(pg_temp.err($$select app.portal_require_student(pg_temp.sid('HS992002'))$$), null, 'Phụ huynh xem con thứ hai được');
select is(pg_temp.err($$select app.portal_require_student(pg_temp.sid('HS992003'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: phụ huynh xem con của phụ huynh khác bị chặn');
reset role;
select pg_temp.claims(pg_temp.uid('ph2'));
set local role authenticated;
select is((select jsonb_array_length(app.portal_children())), 1, 'Phụ huynh một con: một em (giao diện ẩn chip)');
select is(pg_temp.err($$select app.portal_require_student(pg_temp.sid('HS992001'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: phụ huynh khác xem con nhà PH992001 bị chặn');
reset role;

-- ===== Luật: tài khoản bị khoá và nhân viên không thấy gì =====
select pg_temp.claims(pg_temp.uid('ph3'));
set local role authenticated;
select is((select count(*)::int from app.portal_student_ids()), 0, 'Tài khoản phụ huynh bị khoá không thấy học sinh nào');
select is(pg_temp.err($$select app.portal_require_student(pg_temp.sid('HS992005'))$$), 'HMT_KHONG_CO_QUYEN', 'Tài khoản bị khoá gọi hàm cổng bị chặn');
reset role;
select pg_temp.claims(pg_temp.uid('nv'));
set local role authenticated;
select is((select count(*)::int from app.portal_student_ids()), 0, 'Nhân viên không có học sinh nào qua cổng');
select is(pg_temp.err($$select app.portal_require_student(pg_temp.sid('HS992001'))$$), 'HMT_KHONG_CO_QUYEN', 'Nhân viên gọi hàm cổng bị chặn');
select is(app.portal_children(), '[]'::jsonb, 'Nhân viên: danh sách con rỗng');
reset role;

-- ===== Luật: công tắc Học tập theo cơ sở =====
select pg_temp.claims(pg_temp.uid('hs3'));
set local role authenticated;
select is((select count(*)::int from app.portal_student_ids()), 1, 'Học sinh ở cơ sở tắt Học tập vẫn nhận ra chính mình');
select is(pg_temp.err($$select app.portal_require_student(pg_temp.sid('HS992004'))$$), 'HMT_TINH_NANG_TAT', 'Luật công tắc: cơ sở chưa bật Học tập thì chặn');
select is(app.portal_children(), '[]'::jsonb, 'Luật công tắc: danh sách con rỗng khi Học tập tắt');
reset role;

select * from finish();
rollback;
