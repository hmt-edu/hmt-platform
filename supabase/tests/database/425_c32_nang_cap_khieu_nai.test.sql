-- C32 (migration 425): nâng cấp khiếu nại thủ công (R-CS-06): Quản lý cơ sở rồi Ban giám đốc, lý do bắt buộc, chặn đúng, nhật ký. Dữ liệu giả.
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

-- ================= Nâng cấp khiếu nại =================
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'ticket' ->> 'escalation_level'), null, 'Trước: khiếu nại chưa nâng cấp');
select is(pg_temp.err($$select app.escalate_ticket((select (j ->> 'id')::uuid from t1), '  ')$$), 'HMT_LY_DO_BAT_BUOC', 'Chặn: lý do bắt buộc (R-CS-06)');
select is(app.escalate_ticket((select (j ->> 'id')::uuid from t1), 'Quá hạn phản hồi'), 'QUAN_LY_CO_SO', 'Đúng: lần một lên Quản lý cơ sở');
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'ticket' ->> 'escalation_level'), 'QUAN_LY_CO_SO', 'Đúng: ticket ghi mức Quản lý cơ sở');
select is((select e ->> 'event_type' from jsonb_array_elements(app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'events') e where e ->> 'event_type' = 'NANG_CAP'), 'NANG_CAP', 'Đúng: có dòng nhật ký NANG_CAP');
select is(app.escalate_ticket((select (j ->> 'id')::uuid from t1), 'Phụ huynh dọa báo chí'), 'BAN_GIAM_DOC', 'Đúng: lần hai lên Ban giám đốc');
select is(pg_temp.err($$select app.escalate_ticket((select (j ->> 'id')::uuid from t1), 'Thêm')$$), 'HMT_TICKET_DA_NANG_CAP_TOI_DA', 'Chặn: đã ở Ban giám đốc, không nâng thêm');
select is((select count(*)::int from app.ticket_event where ticket_id = (select (j ->> 'id')::uuid from t1) and event_type = 'NANG_CAP'), 2, 'Đúng: hai lần nâng cấp, hai dòng nhật ký');

-- ================= Chặn =================
create temp table t2 (j jsonb);
grant all on t2 to public;
insert into t2 select app.create_ticket(pg_temp.mk('DN', 'DN_02_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))));
select is(pg_temp.err($$select app.escalate_ticket((select (j ->> 'id')::uuid from t2), 'Thử')$$), 'HMT_TICKET_LOAI_SAI', 'Chặn: ticket đề nghị không có nâng cấp (R-CS-06)');
create temp table t3 (j jsonb);
grant all on t3 to public;
insert into t3 select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'));
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.escalate_ticket((select (j ->> 'id')::uuid from t3), 'Thử')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH cơ sở khác không nâng cấp');
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
select is(pg_temp.err($$select app.escalate_ticket((select (j ->> 'id')::uuid from t3), 'Thử')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không nâng cấp (Ticket · Sửa)');
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'AFTERSALE'$$);
select is(pg_temp.err($$select app.escalate_ticket((select (j ->> 'id')::uuid from t3), 'Thử')$$), 'HMT_TINH_NANG_TAT', 'Chặn: cờ AFTERSALE tắt');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'AFTERSALE'$$);
select app.change_ticket_status((select (j ->> 'id')::uuid from t3), 'DA_HUY', 'Rút');
select is(pg_temp.err($$select app.escalate_ticket((select (j ->> 'id')::uuid from t3), 'Thử')$$), 'HMT_TICKET_TRANG_THAI_SAI', 'Chặn: ticket đã huỷ không nâng cấp (AS-02)');
select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
insert into t2 select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'));
select is(app.escalate_ticket((select (j ->> 'id')::uuid from t2 offset 1 limit 1), 'Quản lý nâng lên'), 'QUAN_LY_CO_SO', 'Đúng: Trưởng cơ sở nâng cấp được');

select * from finish();
rollback;
