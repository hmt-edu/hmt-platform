-- R-CRM-41 (QĐ-Đ183, Đ185): lead đổi sang giai đoạn có nhóm con chọn tay (C2, C3, C4) thì bắt buộc chọn nhóm con; C1 không có; C4D chỉ hệ thống.
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



select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable security definer as 'select id from app.lead where parent_phone = p_phone order by code limit 1'$$);
select pg_temp.sudo($$create function pg_temp.opps(p_phone text) returns integer language sql stable security definer as 'select count(*)::int from app.opportunity o join app.lead l on l.id = o.lead_id where l.parent_phone = p_phone'$$);
select pg_temp.sudo($$grant execute on function pg_temp.lid(text), pg_temp.opps(text) to public$$);

-- ================= Dựng dữ liệu =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900008001', '{"parent_name": "Chị Nhóm Con Một", "student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900008002', '{"parent_name": "Chị Nhóm Con Hai", "student_name": "Em Hai", "student_birth_year": 2013}'));


-- ================= R-CRM-41 =================
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C2')$$), 'HMT_THIEU_NHOM_CON', 'R-CRM-41: sang C2 không chọn nhóm con thì chặn');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C3')$$), 'HMT_THIEU_NHOM_CON', 'R-CRM-41: sang C3 không chọn nhóm con thì chặn');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C4')$$), 'HMT_THIEU_NHOM_CON', 'R-CRM-41: sang C4 không chọn nhóm con thì chặn');
select ok(pg_temp.msg($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C4')$$) like '%C4%', 'R-CRM-41: câu lỗi nêu giai đoạn');
select is((select stage_code from app.lead where id = pg_temp.lid('0900008001')), 'C1', 'Bị chặn thì lead giữ giai đoạn cũ');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C2', 'C2B')$$), null, 'R-CRM-41: sang C2 kèm nhóm con thì được');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C3', 'C3C')$$), null, 'R-CRM-41: sang C3 kèm nhóm con thì được');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C4', 'C4A')$$), null, 'R-CRM-41: sang C4 kèm nhóm con thì được');
select is((select array[stage_code, substage_code] from app.lead where id = pg_temp.lid('0900008001')), array['C4', 'C4A'], 'Lead ghi đúng giai đoạn và nhóm con');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C4', 'C4B')$$), null, 'Đổi nhóm con cùng giai đoạn được');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C4')$$), 'HMT_THIEU_NHOM_CON', 'Bỏ trống nhóm con khi đã ở C4 cũng chặn');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C1')$$), null, 'R-CRM-41: C1 không có nhóm con nên không bắt chọn');
select is((select array[stage_code, substage_code] from app.lead where id = pg_temp.lid('0900008001')), array['C1', null], 'Về C1 không nhóm con');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C4', 'C4D')$$), 'HMT_C4D_HE_THONG', 'C4D vẫn chỉ hệ thống gắn (R-CRM-09)');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C3', 'C4A')$$), 'HMT_NHOM_CON_SAI', 'Nhóm con không thuộc giai đoạn thì chặn');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900008001'), 'C2')$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền kiểm trước: sale cơ sở khác bị chặn quyền');

select * from finish();
rollback;
