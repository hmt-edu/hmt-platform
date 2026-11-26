-- Migration 673 (C-26-02): lead «Đã gộp», «Đã huỷ» và cơ hội «Đã gộp» không vào số đếm của phễu (BC-02) và của chiến dịch (CH-08).
-- Lead «Không có nhu cầu» là lead thật, vẫn tính. Dữ liệu giả, một chiến dịch riêng để không lẫn dữ liệu khác.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p673.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p673.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code) select u.id, case u.key when 'admin' then 'ADMIN' else 'SALES' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true;
create temp table c (id uuid);
grant all on c to public;
grant execute on all functions in schema pg_temp to public;

set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
insert into c select (app.create_campaign('Chiến dịch giả 673') ->> 'id')::uuid;
-- Bốn lead cùng chiến dịch: A (giữ lại), B (sẽ gộp vào A), H (sẽ huỷ), K (không có nhu cầu).
select app.create_lead(jsonb_build_object('parent_name', 'Phụ huynh giả ' || v.k, 'parent_phone', v.phone, 'student_name', 'Em ' || v.k, 'student_birth_year', 2012,
         'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS', 'channel_code', 'FACEBOOK_ADS_LEAD_FORM', 'campaign_id', (select id from c)))
  from (values ('A', '0900673001'), ('B', '0900673002'), ('H', '0900673003'), ('K', '0900673004')) as v (k, phone);
reset role;
update app.lead set stage_code = 'C4', substage_code = 'C4C' where parent_phone = '0900673001';
update app.lead set stage_code = 'C3', substage_code = 'C3A' where parent_phone = '0900673004';
set local role authenticated;
select app.create_opportunity((select id from app.lead where parent_phone = '0900673001'));
reset role;
update app.opportunity set stage_code = 'L8', substage_code = 'L8A' where campaign_id = (select id from c);

create function pg_temp.funnel(p_col text) returns bigint language plpgsql as $$
declare v bigint;
begin
  execute format('select coalesce(sum(%I), 0)::bigint from report.lead_funnel where campaign_id = (select id from c)', p_col) into v;
  return v;
end $$;
create function pg_temp.campaign_leads() returns int language sql as $$
  select (x ->> 'lead_count')::int from jsonb_array_elements(app.list_campaigns('{"q": "Chiến dịch giả 673"}') -> 'rows') x $$;
grant execute on all functions in schema pg_temp to public;

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.funnel('leads'), 4::bigint, 'BC-02: trước khi gộp, huỷ: đủ 4 lead đang dùng');
select is(pg_temp.campaign_leads(), 4, 'CH-08: trước khi gộp, huỷ: chiến dịch có 4 lead');

-- Thêm cơ hội «Đã gộp» vào cơ hội đang dùng (cũng L8), rồi gộp lead B vào A, huỷ lead H.
insert into app.opportunity
select (jsonb_populate_record(o, jsonb_build_object('id', gen_random_uuid(), 'code', 'CO673GOP', 'record_status', 'DA_GOP', 'merged_into_id', o.id, 'student_info_missing', true))).*
  from app.opportunity o where o.campaign_id = (select id from c);
update app.lead set record_status = 'DA_GOP', merged_into_id = (select id from app.lead where parent_phone = '0900673001')
 where parent_phone = '0900673002';
update app.lead set record_status = 'DA_HUY', cancel_reason = 'Nhập nhầm (giả)', cancelled_at = now(), cancelled_by = pg_temp.uid('admin')
 where parent_phone = '0900673003';
select is((select count(*)::int from app.opportunity where campaign_id = (select id from c)), 2, 'Dữ liệu: một cơ hội đang dùng, một cơ hội đã gộp');

select is(pg_temp.funnel('leads'), 2::bigint, 'BC-02: lead Đã gộp, Đã huỷ không vào số lead; lead Không có nhu cầu vẫn tính');
select is(pg_temp.funnel('opportunities'), 1::bigint, 'BC-02: cơ hội Đã gộp không vào số cơ hội');
select is(pg_temp.funnel('opportunities_won'), 1::bigint, 'BC-02: cơ hội Đã gộp không vào số chốt L8');
set local role authenticated;
select is(pg_temp.campaign_leads(), 2, 'CH-08: số lead của chiến dịch không tính Đã gộp, Đã huỷ');
reset role;

-- Cơ hội đang dùng chuyển thành đã gộp thì lead của nó vẫn được đếm, chỉ cơ hội bị loại.
update app.opportunity set record_status = 'DA_GOP', merged_into_id = (select id from app.opportunity where code = 'CO673GOP')
 where campaign_id = (select id from c) and code <> 'CO673GOP';
select is(pg_temp.funnel('leads'), 2::bigint, 'BC-02: lead còn đó khi mọi cơ hội của nó đã gộp');
select is(pg_temp.funnel('opportunities'), 0::bigint, 'BC-02: không còn cơ hội đang dùng thì số cơ hội là 0');
select ok((select 'security_invoker=true' = any (reloptions) from pg_class where oid = 'report.lead_funnel'::regclass), 'BC-02: view vẫn security_invoker');
select ok(has_table_privilege('authenticated', 'report.lead_funnel', 'select'), 'BC-02: quyền đọc view giữ nguyên');
select * from finish();
rollback;
