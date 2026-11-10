-- Lịch tự chạy pg_cron (migration 104): tự chốt mỗi 30 phút, tự Done mỗi 15 phút. Luật: R-GIO-05, R-GIO-06, Q-180.
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
create function pg_temp.njobs() returns integer language sql security definer as $$ select count(*)::int from cron.job where jobname like 'hmt-auto-%' $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@cron.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select id, 'Giả ' || key, key || '@cron.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code) select id, case key when 'admin' then 'ADMIN' else 'CSKH' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

select is((select schedule from cron.job where jobname = 'hmt-auto-close-sessions'), '*/30 * * * *', 'Tự chốt chạy mỗi 30 phút (session_autoclose_before_minutes, R-GIO-05)');
select is((select schedule from cron.job where jobname = 'hmt-auto-complete-sessions'), '*/15 * * * *', 'Tự Done chạy mỗi 15 phút (session_autocomplete_minutes, Q-180)');
select is((select command from cron.job where jobname = 'hmt-auto-complete-sessions'), 'select app.auto_complete_sessions()', 'Lịch tự Done gọi đúng hàm (R-GIO-06)');
select is(app.get_setting_int('session_autocomplete_minutes')::int, 15, 'Tham số session_autocomplete_minutes mặc định 15');

set local role authenticated;
select pg_temp.claims((select id from u where key = 'cskh1'), 'aal1');
select is(pg_temp.err($$select app.sync_session_cron()$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: chỉ quản trị viên đổi lịch tự chạy');
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select pg_temp.sudo($$update app.setting_def set value = '20' where key = 'session_autocomplete_minutes'$$);
select is(app.sync_session_cron(), 'tự chốt: */30 * * * *; tự Done: */20 * * * *', 'Admin đồng bộ lịch sau khi đổi chu kỳ');
select pg_temp.sudo($$select app.sync_session_cron()$$);
select is(pg_temp.njobs(), 2, 'Đồng bộ lại nhiều lần không nhân đôi lịch');
select pg_temp.sudo($$update app.setting_def set value = '30' where key = 'session_autoclose_before_minutes'$$);
-- Chưa bật pg_cron (môi trường db push thiếu extension): hàm báo lỗi rõ, không lỗi lạ.
select pg_temp.sudo($$drop extension pg_cron$$);
select is(pg_temp.err($$select app.sync_session_cron()$$), 'HMT_PG_CRON_CHUA_BAT', 'Chưa bật pg_cron thì báo lỗi rõ ràng, không dừng migration');
select * from finish();
rollback;
