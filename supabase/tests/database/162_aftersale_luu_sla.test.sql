-- Aftersale lát 5 (migration 162): save_ticket_sla: lưu bảng hạn, hạn riêng nhóm con, luật chặn, quyền Admin. Dữ liệu giả.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh5'), ('cskh1'), ('gv5'), ('gv5b'), ('qlcs5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@as.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@as.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' when key like 'cskh%' then 'CSKH' when key like 'gv%' then 'TEACHER' else 'BRANCH_MANAGER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHAS501', 'Phụ huynh giả ticket', '0900002001', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  values ('HSAS501', (select id from app.parent where code = 'PHAS501'), 'Học sinh giả ticket', 2013, (select id from app.branch where code = 'CS5'))$$);
grant execute on all functions in schema pg_temp to public;

create function pg_temp.mk(p_type text, p_cat text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('ticket_type', p_type, 'branch_id', (select id from app.branch where code = 'CS5'), 'title', 'Tiêu đề giả', 'description', 'Mô tả giả',
    'channel_code', 'GOI_DIEN', 'category_code', p_cat, 'parent_id', (select id from app.parent where code = 'PHAS501')) || p_extra $$;
grant execute on function pg_temp.mk(text, text, jsonb) to public;

select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code in ('CS5', 'CS1')
  on conflict (module_code, branch_id) do update set enabled = true$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
create temp table t1 (j jsonb);
grant all on t1 to public;
insert into t1 select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'));

-- ================= Quyền =================
select is(pg_temp.err($$select app.save_ticket_sla('[]'::jsonb, '[]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH không có quyền Quản trị · Sửa nên không lưu được SLA');
reset role;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;

-- ================= Lưu bảng hạn =================
select app.save_ticket_sla('[{"ticket_type":"KN","priority_code":"KHAN","response_hours":3,"resolve_hours":30}]'::jsonb, '[]'::jsonb);
select is((select response_hours || '/' || resolve_hours from app.ticket_sla_rule where ticket_type = 'KN' and priority_code = 'KHAN'), '3/30', 'Lưu: đổi hạn khiếu nại Khẩn thành 3 giờ phản hồi, 30 giờ xử lý');
select app.save_ticket_sla('[{"ticket_type":"KN","priority_code":"KHAN","resolve_hours":40}]'::jsonb, '[]'::jsonb);
select is((select response_hours || '/' || resolve_hours from app.ticket_sla_rule where ticket_type = 'KN' and priority_code = 'KHAN'), '3/40', 'Lưu: chỉ gửi một ô thì ô kia giữ nguyên');
select is(pg_temp.err($$select app.save_ticket_sla('[{"ticket_type":"KN","priority_code":"KHAN","response_hours":50,"resolve_hours":10}]'::jsonb, '[]'::jsonb)$$), 'HMT_SLA_GIO_SAI', 'Chặn: hạn xử lý nhỏ hơn hạn phản hồi (AS-07)');
select is(pg_temp.err($$select app.save_ticket_sla('[{"ticket_type":"KN","priority_code":"KHAN","response_hours":0}]'::jsonb, '[]'::jsonb)$$), 'HMT_SLA_GIO_SAI', 'Chặn: số giờ phải từ 1 trở lên');
select is(pg_temp.err($$select app.save_ticket_sla('[{"ticket_type":"XX","priority_code":"KHAN","response_hours":1}]'::jsonb, '[]'::jsonb)$$), 'HMT_SLA_DONG_SAI', 'Chặn: dòng hạn không có');
create temp table dn_khan_truoc as select resolve_hours from app.ticket_sla_rule where ticket_type = 'DN' and priority_code = 'KHAN';
grant select on dn_khan_truoc to public;
select is(pg_temp.err($$select app.save_ticket_sla('[{"ticket_type":"DN","priority_code":"KHAN","response_hours":2,"resolve_hours":20},{"ticket_type":"DN","priority_code":"CAO","response_hours":9,"resolve_hours":1}]'::jsonb, '[]'::jsonb)$$), 'HMT_SLA_GIO_SAI', 'Chặn: cả lô có một dòng sai');
select is((select resolve_hours from app.ticket_sla_rule where ticket_type = 'DN' and priority_code = 'KHAN'), (select resolve_hours from dn_khan_truoc), 'Cả lô một giao dịch: dòng sai thì dòng đúng đứng trước cũng không được lưu (DN Khẩn giữ nguyên)');

-- ================= Hạn riêng nhóm con =================
select app.save_ticket_sla('[]'::jsonb, '[{"category_code":"KN_02_01","resolve_hours":96}]'::jsonb);
select is((select resolve_hours_override from app.ticket_category where code = 'KN_02_01'), 96, 'Hạn riêng: đặt 96 giờ cho nhóm con');
select app.save_ticket_sla('[]'::jsonb, '[{"category_code":"KN_02_01","resolve_hours":null}]'::jsonb);
select is((select resolve_hours_override from app.ticket_category where code = 'KN_02_01'), null, 'Hạn riêng: «Bỏ hạn riêng» đưa về trống');
select is(pg_temp.err($$select app.save_ticket_sla('[]'::jsonb, '[{"category_code":"KHONG_CO","resolve_hours":5}]'::jsonb)$$), 'HMT_TICKET_NHOM_SAI', 'Chặn: nhóm con không có');
select is(pg_temp.err($$select app.save_ticket_sla('[]'::jsonb, '[{"category_code":"KN_02","resolve_hours":5}]'::jsonb)$$), 'HMT_TICKET_NHOM_SAI', 'Chặn: hạn riêng chỉ cho nhóm con, không cho nhóm cha');

-- ================= Ticket đã tạo giữ hạn đã chụp =================
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
create temp table t4 (j jsonb);
grant all on t4 to public;
insert into t4 select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'));
select is((select extract(epoch from resolve_due_at - created_at) / 3600 from app.ticket where id = (select (j ->> 'id')::uuid from t4)), 40.0, 'Ticket tạo sau khi lưu theo hạn mới (40 giờ)');
reset role;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select app.save_ticket_sla('[{"ticket_type":"KN","priority_code":"KHAN","response_hours":3,"resolve_hours":60}]'::jsonb, '[]'::jsonb);
select is((select extract(epoch from resolve_due_at - created_at) / 3600 from app.ticket where id = (select (j ->> 'id')::uuid from t4)), 40.0, 'Ticket đã tạo giữ hạn đã chụp, không đổi theo SLA mới (AS-07)');

select * from finish();
rollback;
