-- Lead chỉ tạo được cơ hội khi ở C4C (luật mới 26/10, anh Trường chốt): C4C và C4D qua, các nhóm con khác bị chặn; luật quyền kiểm trước.
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
select app.create_lead(pg_temp.lead_data('0900007001', '{"parent_name": "Chị C4C Một", "student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900007002', '{"parent_name": "Chị C4C Hai", "student_name": "Em Hai", "student_birth_year": 2013}'));

-- ================= Lead chỉ tạo được cơ hội khi ở C4C =================
select is((select array[stage_code, substage_code] from app.lead where id = pg_temp.lid('0900007001')), array['C1', null], 'Lead mới ở C1, chưa có nhóm con (R-CRM-39)');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007001'))$$), 'HMT_LEAD_CHUA_DU_DIEU_KIEN', 'Lead ở C1: không tạo được cơ hội');
select ok(pg_temp.msg($$select app.create_opportunity(pg_temp.lid('0900007001'))$$) like '%C4C%Đủ điều kiện tạo cơ hội%', 'Câu lỗi nêu nhóm con C4C "Đủ điều kiện tạo cơ hội"');
select is(pg_temp.opps('0900007001'), 0, 'Bị chặn thì không sinh cơ hội');

select app.change_lead_stage(pg_temp.lid('0900007001'), 'C2', 'C2A');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007001'))$$), 'HMT_LEAD_CHUA_DU_DIEU_KIEN', 'Lead ở C2A: không tạo được');
select app.change_lead_stage(pg_temp.lid('0900007001'), 'C3', 'C3B');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007001'))$$), 'HMT_LEAD_CHUA_DU_DIEU_KIEN', 'Lead ở C3B: không tạo được');
select app.change_lead_stage(pg_temp.lid('0900007001'), 'C4', 'C4A');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007001'))$$), 'HMT_LEAD_CHUA_DU_DIEU_KIEN', 'Lead ở C4A "Cần gửi thêm thông tin": không tạo được');
select app.change_lead_stage(pg_temp.lid('0900007001'), 'C4', 'C4B');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007001'))$$), 'HMT_LEAD_CHUA_DU_DIEU_KIEN', 'Lead ở C4B "Cần trao đổi thêm": không tạo được');
select is(pg_temp.opps('0900007001'), 0, 'Vẫn chưa có cơ hội nào');
select app.change_lead_stage(pg_temp.lid('0900007001'), 'C4', 'C4C');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007001'))$$), null, 'Lead ở C4C: tạo được cơ hội');
select is(pg_temp.opps('0900007001'), 1, 'Có một cơ hội');
select is((select array[stage_code, substage_code] from app.lead where id = pg_temp.lid('0900007001')), array['C4', 'C4D'], 'R-CRM-09: tạo xong lead tự về C4D');

-- Lead đã ở C4D tạo thêm theo R-CRM-01: cảnh báo, xác nhận lần hai.
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007001'))$$), 'HMT_LEAD_DA_CO_CO_HOI', 'Lead ở C4D đã có cơ hội: cảnh báo kèm mã cũ (R-CRM-01)');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007001'), '{}'::jsonb, true)$$), null, 'Xác nhận lần hai: tạo thêm được ở C4D');
select is(pg_temp.opps('0900007001'), 2, 'Lead C4D tạo thêm: hai cơ hội');

-- Lead đã đổi về giai đoạn khác thì lại bị chặn dù từng có cơ hội.
select app.change_lead_stage(pg_temp.lid('0900007001'), 'C2', 'C2B');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007001'), '{}'::jsonb, true)$$), 'HMT_LEAD_CHUA_DU_DIEU_KIEN', 'Lead đã về C2: bị chặn, kể cả khi xác nhận lần hai');
select is(pg_temp.opps('0900007001'), 2, 'Không sinh thêm cơ hội khi bị chặn');

-- Luật quyền vẫn kiểm trước: người ngoài cơ sở nhận lỗi quyền, không lộ giai đoạn của lead.
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007002'))$$), 'HMT_KHONG_CO_QUYEN', 'Người cơ sở khác nhận lỗi quyền trước lỗi giai đoạn');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007002'))$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên nhận lỗi quyền');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007002'))$$), 'HMT_LEAD_CHUA_DU_DIEU_KIEN', 'CSKH cơ sở mình cũng bị chặn khi lead chưa ở C4C');
select app.change_lead_stage(pg_temp.lid('0900007002'), 'C4', 'C4C');
select is(pg_temp.err($$select app.create_opportunity(pg_temp.lid('0900007002'))$$), null, 'CSKH tạo được khi lead ở C4C');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.change_lead_stage(pg_temp.lid('0900007002'), 'C4', 'C4D')$$), 'HMT_C4D_HE_THONG', 'Không chọn tay C4D (hệ thống gắn)');

select * from finish();
rollback;
