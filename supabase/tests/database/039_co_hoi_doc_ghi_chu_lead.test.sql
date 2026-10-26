-- Cơ hội hiện ghi chú của lead gốc (lỗi 26/10): app.record_notes đọc xuyên, nhãn nguồn, quyền. Mỗi luật có ca đúng và ca bị chặn.
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



select pg_temp.sudo($$create function pg_temp.oid(p_phone text) returns uuid language sql stable security definer as 'select o.id from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone order by o.code limit 1'$$);
select pg_temp.sudo($$create function pg_temp.lid(p_phone text) returns uuid language sql stable security definer as 'select id from app.lead where parent_phone = p_phone order by code limit 1'$$);
select pg_temp.sudo($$grant execute on function pg_temp.oid(text), pg_temp.lid(text) to public$$);

-- ================= Dựng dữ liệu =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_lead(pg_temp.lead_data('0900006001', '{"parent_name": "Chị Ghi Chú Một", "student_name": "Em Một", "student_birth_year": 2012}'));
select app.create_lead(pg_temp.lead_data('0900006002', '{"parent_name": "Chị Ghi Chú Hai", "student_name": "Em Hai", "student_birth_year": 2013}'));
select app.add_note('LEAD', pg_temp.lid('0900006001'), 'Gọi lần 1: phụ huynh hẹn gọi lại');
select app.add_note('LEAD', pg_temp.lid('0900006002'), 'Ghi chú của lead khác');
select pg_temp.sudo($$update app.lead set stage_code = 'C4', substage_code = 'C4C' where stage_code = 'C1'$$);
select app.create_opportunity(pg_temp.lid('0900006001'));
select app.create_opportunity(pg_temp.lid('0900006002'));
select app.add_note('OPPORTUNITY', pg_temp.oid('0900006001'), 'Đã tư vấn lịch học');

-- ================= Cơ hội hiện ghi chú của lead gốc =================
select is((select count(*)::int from app.record_notes('OPPORTUNITY', pg_temp.oid('0900006001')) where body = 'Gọi lần 1: phụ huynh hẹn gọi lại'), 1,
          'Lỗi 26/10: cơ hội hiện ghi chú của lead gốc');
select is((select source_label from app.record_notes('OPPORTUNITY', pg_temp.oid('0900006001')) where body = 'Gọi lần 1: phụ huynh hẹn gọi lại'),
          'Lead ' || (select code from app.lead where parent_phone = '0900006001'), 'Ghi chú của lead có nhãn "Lead LD…"');
select is((select source_label from app.record_notes('OPPORTUNITY', pg_temp.oid('0900006001')) where body = 'Đã tư vấn lịch học'), null,
          'Ghi chú của chính cơ hội không có nhãn nguồn');
select is((select count(*)::int from app.record_notes('OPPORTUNITY', pg_temp.oid('0900006001'))), 2, 'Cơ hội hiện đủ ghi chú của mình và của lead gốc');
select is((select count(*)::int from app.record_notes('OPPORTUNITY', pg_temp.oid('0900006001')) where body = 'Ghi chú của lead khác'), 0,
          'Không hiện ghi chú của lead khác');

-- Ghi chú viết sau ở lead cũng hiện ở cơ hội; ghi chú viết ở cơ hội KHÔNG hiện ở lead.
select app.add_note('LEAD', pg_temp.lid('0900006001'), 'Ghi chú thêm ở lead sau khi có cơ hội');
select is((select count(*)::int from app.record_notes('OPPORTUNITY', pg_temp.oid('0900006001')) where body like 'Ghi chú thêm ở lead%'), 1,
          'Ghi chú viết thêm ở lead sau khi tạo cơ hội cũng hiện ở cơ hội');
select is((select count(*)::int from app.record_notes('LEAD', pg_temp.lid('0900006001')) where body = 'Đã tư vấn lịch học'), 0,
          'Ghi chú viết ở cơ hội không hiện ở lead');
select is((select count(*)::int from app.record_notes('LEAD', pg_temp.lid('0900006001')) where source_label is not null), 0,
          'Danh sách ghi chú của lead không có nhãn nguồn');

-- Ghi chú đã huỷ không hiện.
select pg_temp.sudo($$update app.note set is_cancelled = true where body = 'Gọi lần 1: phụ huynh hẹn gọi lại'$$);
select is((select count(*)::int from app.record_notes('OPPORTUNITY', pg_temp.oid('0900006001')) where body = 'Gọi lần 1: phụ huynh hẹn gọi lại'), 0,
          'Ghi chú lead đã huỷ không hiện ở cơ hội');

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(pg_temp.err($$select * from app.record_notes('OPPORTUNITY', pg_temp.oid('0900006001'))$$), 'HMT_KHONG_CO_QUYEN', 'Người cơ sở khác không đọc được ghi chú cơ hội');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select * from app.record_notes('OPPORTUNITY', pg_temp.oid('0900006001'))$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không đọc được ghi chú cơ hội');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select ok((select count(*) from app.record_notes('OPPORTUNITY', pg_temp.oid('0900006001'))) >= 2, 'Trưởng cơ sở cùng cơ sở đọc được, kèm ghi chú lead');

select * from finish();
rollback;
