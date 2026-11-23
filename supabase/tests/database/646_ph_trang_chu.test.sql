-- PH-01 (migration 646): trang chủ cổng Phụ huynh. Dữ liệu giả.
-- Luật: phụ huynh chỉ thấy con, việc của mình (kể cả hồ sơ cùng SĐT); nhân viên không dùng; công tắc Học tập tắt thì không hiện con.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$ begin execute p_sql; end $$;
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('ph1'), ('ph1b'), ('ph2'), ('nv');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.sid(p_code text) returns uuid language plpgsql security definer as $$ begin return (select id from app.student where code = p_code); end $$;
create temp table k (key text primary key, id uuid);
grant all on k to public;
create function pg_temp.k(p_key text) returns uuid language sql stable as $$ select id from k where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@f646.hoamatoan.invalid' from u;
-- PH646001 và PH646002 CÙNG SĐT (một tài khoản ph1 thấy con của cả hai); PH646003 SĐT khác (ph2); ph1b là tài khoản của PH646002.
insert into app.parent (code, full_name, phone, branch_id)
select c.code, 'Phụ huynh giả ' || c.code, c.phone, (select id from app.branch where code = 'CS1')
  from (values ('PH646001', '0900646001'), ('PH646002', '0900646001'), ('PH646003', '0900646003')) c (code, phone);
insert into app.user_account (id, display_name, login_name, branch_id, parent_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@f646.hoamatoan.invalid', (select id from app.branch where code = 'CS1'),
       case u.key when 'ph1' then 'PH646001' when 'ph1b' then 'PH646002' when 'ph2' then 'PH646003' end, false
  from u;
insert into app.user_role (user_id, role_code) select u.id, case when u.key = 'nv' then 'SALES' else 'PARENT' end from u;
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = c.ph), c.name, 2012, (select id from app.branch where code = 'CS1')
  from (values ('HS646001', 'PH646001', 'Em 646 Một'), ('HS646002', 'PH646002', 'Em 646 Hai'), ('HS646003', 'PH646003', 'Em 646 Ba')) c (code, ph, name);
insert into app.feature_flag (module_code, branch_id, enabled)
select m, b.id, true from app.branch b, (values ('HOC_TAP'), ('AFTERSALE')) v (m) where b.code = 'CS1'
on conflict (module_code, branch_id) do update set enabled = true;

-- Ticket giả: ph1 có một đề nghị Mới (bước 1), một Đã xử lý (bước 3), một Đã đóng (không hiện); ph2 có một đề nghị Mới.
select pg_temp.sudo($$
  insert into app.ticket (code, ticket_type, branch_id, title, description, channel_code, category_code, priority_code, status_code, parent_id, student_id,
                          response_due_at, resolve_due_at)
  select c.code, 'DN', b.id, 'Giả ' || c.code, 'Nội dung', 'ZALO', 'DN_01_05', 'CAO', c.st,
         (select id from app.parent where code = c.ph), (select id from app.student where code = c.hs), now() + interval '1 day', now() + interval '2 days'
    from app.branch b, (values ('DN-F646-1', 'PH646001', 'HS646001', 'MOI'), ('DN-F646-2', 'PH646002', 'HS646002', 'DA_XU_LY'),
                               ('DN-F646-3', 'PH646001', 'HS646001', 'MOI'), ('DN-F646-9', 'PH646003', 'HS646003', 'MOI')) c (code, ph, hs, st) where b.code = 'CS1';
$$);
select pg_temp.sudo($$update app.ticket set status_code = 'DA_DONG', closed_at = now(), resolved_at = now(), resolution = 'Xong' where code = 'DN-F646-3'$$);

-- ===== Phụ huynh ph1 (cùng SĐT với PH646002) =====
select pg_temp.claims(pg_temp.uid('ph1'));
set local role authenticated;
select is(jsonb_array_length(app.ph_home() -> 'children'), 2, 'PH-2, PH-01: hai hồ sơ cùng SĐT, một tài khoản thấy con của cả hai');
select is(app.ph_home() #>> '{children,0,full_name}', 'Em 646 Hai', 'PH-01: các con xếp theo tên');
select is(jsonb_array_length(app.ph_home() -> 'attention'), 2, 'PH-01: việc cần chú ý chỉ đề nghị chưa đóng của mình (đề nghị đã đóng, của nhà khác không hiện)');
select ok(not exists (select 1 from jsonb_array_elements(app.ph_home() -> 'attention') a where a ->> 'title' like '%F646-9' or a ->> 'title' like '%F646-3'), 'Luật quyền riêng: không lộ ticket nhà khác, ticket đã đóng');
select is((select min((a ->> 'step')::int) from jsonb_array_elements(app.ph_home() -> 'attention') a), 1, 'PH-01: ticket Mới ở bước 1');
select is((select max((a ->> 'step')::int) from jsonb_array_elements(app.ph_home() -> 'attention') a), 3, 'PH-01: ticket Đã xử lý ở bước 3');
select ok(not (app.ph_home() #> '{children,0}' ? 'branch_id'), 'PH-01: không lộ cột nội bộ của học sinh');
reset role;

-- ===== Phụ huynh ph2 chỉ thấy con mình =====
select pg_temp.claims(pg_temp.uid('ph2'));
set local role authenticated;
select is(jsonb_array_length(app.ph_home() -> 'children'), 1, 'Luật quyền riêng: phụ huynh khác chỉ thấy con của mình');
select is(app.ph_home() #>> '{children,0,full_name}', 'Em 646 Ba', 'Luật quyền riêng: đúng con của mình');
reset role;

-- ===== Công tắc Học tập tắt: không hiện con =====
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'HOC_TAP' and branch_id = (select id from app.branch where code = 'CS1')$$);
select pg_temp.claims(pg_temp.uid('ph1'));
set local role authenticated;
select is(jsonb_array_length(app.ph_home() -> 'children'), 0, 'Công tắc Học tập tắt thì không hiện con');
reset role;

-- ===== Nhân viên không có gì ở cổng =====
select pg_temp.claims(pg_temp.uid('nv'));
set local role authenticated;
select is(jsonb_array_length(app.ph_home() -> 'children'), 0, 'Nhân viên gọi hàm phụ huynh: không có con');
select is(jsonb_array_length(app.ph_home() -> 'attention'), 0, 'Nhân viên gọi hàm phụ huynh: không có việc');
reset role;

select * from finish();
rollback;
