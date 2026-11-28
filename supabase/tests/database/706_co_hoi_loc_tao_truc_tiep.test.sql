begin;
-- Migration 706 (E-27-14): lọc direct_only («Tạo trực tiếp», lead_id trống) ở bốn hàm Cơ hội.
-- Luật: R-CRM-01 (cơ hội tạo trực tiếp không có lead gốc); quyền và phạm vi cơ sở giữ nguyên. Dữ liệu giả.
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
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.branch(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
create function pg_temp.data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Trực Tiếp', 'parent_phone', p_phone, 'need', 'Cần học Toán',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
-- Gọi hàm tạo, trả về câu SQL để dùng với err/msg.
create function pg_temp.sql_tao(p_data jsonb, p_students jsonb default '[]'::jsonb, p_confirm boolean default false, p_parent uuid default null)
returns text language sql as $$
  select format('select app.create_opportunity_direct(%L::jsonb, %L::jsonb, %L, %L)', p_data, p_students, p_confirm, p_parent);
$$;
create function pg_temp.opp(p_phone text) returns app.opportunity language sql stable security definer as $$
  select o.* from app.opportunity o join app.parent p on p.id = o.parent_id where p.phone = p_phone order by o.code limit 1 $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1'), ('sales5'), ('cskh1'), ('bm1'), ('teacher1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@e706.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@e706.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('sales1', 'CS1'), ('sales5', 'CS5'), ('cskh1', 'CS1'), ('bm1', 'CS1'), ('teacher1', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('sales5', 'SALES'), ('cskh1', 'CSKH'),
                                        ('bm1', 'BRANCH_MANAGER'), ('teacher1', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');

-- Bộ lọc riêng theo người phụ trách giả sales1: 2 cơ hội trực tiếp, 1 cơ hội từ lead.
create function pg_temp.f(p_extra jsonb default '{}'::jsonb) returns jsonb language sql stable as $$
  select jsonb_build_object('owner_id', pg_temp.uid('sales1')) || p_extra $$;
create function pg_temp.tong_bang(p jsonb) returns integer language sql as $$
  select coalesce(sum((c ->> 'total')::int), 0)::int from jsonb_array_elements(app.opportunity_board(p)) c $$;
grant execute on all functions in schema pg_temp to public;

set local role authenticated;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select app.create_opportunity_direct(pg_temp.data('0900706001'));
select app.create_opportunity_direct(pg_temp.data('0900706002'));
-- Lead chỉ tạo được cơ hội khi ở C4C.
create temp table ld as select (app.create_lead(pg_temp.data('0900706003')) ->> 'id')::uuid as id;
select app.change_lead_stage((select id from ld), 'C4', 'C4C');
select app.create_opportunity((select id from ld));

-- ================= Danh sách =================
select is((app.list_opportunities(pg_temp.f()) ->> 'total')::int, 3, 'Không lọc: đủ cơ hội trực tiếp và từ lead');
select is((app.list_opportunities(pg_temp.f('{"direct_only": false}')) ->> 'total')::int, 3, 'direct_only = false: không lọc');
select is((app.list_opportunities(pg_temp.f('{"direct_only": true}')) ->> 'total')::int, 2, 'R-CRM-01: direct_only chỉ đếm cơ hội tạo trực tiếp');
select is((select count(*)::int from jsonb_array_elements(app.list_opportunities(pg_temp.f('{"direct_only": true}')) -> 'rows') r
            where r ->> 'lead_id' is not null), 0, 'Không trả dòng nào có lead gốc');
select is((app.list_opportunities(pg_temp.f('{"direct_only": true}'), 'created_desc', 1) ->> 'total')::int, 2,
  'Lấy một dòng vẫn đếm đủ tổng (số ở lựa chọn lọc nhanh)');

-- ================= Kanban, Group By =================
select is(pg_temp.tong_bang(pg_temp.f()), 3, 'Kanban không lọc: đủ ba thẻ');
select is(pg_temp.tong_bang(pg_temp.f('{"direct_only": true}')), 2, 'Kanban lọc direct_only');
select is((app.opportunity_group_counts(pg_temp.f(), array['stage']) ->> 'total')::int, 3, 'Group By không lọc: đủ ba');
select is((app.opportunity_group_counts(pg_temp.f('{"direct_only": true}'), array['stage']) ->> 'total')::int, 2, 'Group By lọc direct_only');

-- ================= Xuất, quyền và phạm vi =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.export_opportunities(pg_temp.f('{"direct_only": true}')) ->> 'total')::int, 2, 'Xuất lọc direct_only: đúng tổng');
select is((select count(*)::int from jsonb_array_elements(app.export_opportunities(pg_temp.f('{"direct_only": true}')) -> 'rows') r
            where r ->> 'lead' is not null), 0, 'File xuất không có dòng nào có lead gốc');

select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is((app.list_opportunities(pg_temp.f('{"direct_only": true}')) ->> 'total')::int, 0, 'Cơ sở khác: lọc direct_only không mở rộng phạm vi');
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is(pg_temp.err($$select app.list_opportunities('{"direct_only": true}')$$), 'HMT_KHONG_CO_QUYEN',
  'Không có quyền xem cơ hội thì vẫn bị chặn');

select * from finish();
rollback;
