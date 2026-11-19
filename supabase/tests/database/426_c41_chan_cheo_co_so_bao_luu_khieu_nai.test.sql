-- C41 (R-CS-06, R-CS-07, R-GD-09): chặn chéo cơ sở cho phiếu Bảo lưu, Gia hạn, Tiếp tục học và Nâng cấp khiếu nại: người của cơ sở khác (CSKH, Trưởng cơ sở) không tạo, duyệt, thực hiện, nâng cấp, không lấy tuỳ chọn. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('cskh5'), ('cskh1'), ('gv5'), ('gv5b'), ('qlcs5'), ('qlcs1');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@as.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@as.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key in ('cskh1', 'qlcs1') then 'CS1' else 'CS5' end), false from u;
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


select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAO_LUU', id, true from app.branch where code in ('CS5', 'CS1')
  on conflict (module_code, branch_id) do update set enabled = true$$);
-- Ghi danh Đang học của học sinh CS5 có 5 giờ.
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, status_code)
  select 'GDC41', s.id, s.parent_id, s.branch_id, 'TOAN', 'DANG_HOC' from app.student s where s.code = 'HSAS501'$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) select e.id, e.branch_id, 'DAU_KY', 5 from app.enrollment e where e.code = 'GDC41'$$);
create function pg_temp.enr() returns uuid language sql stable security definer as $$ select id from app.enrollment where code = 'GDC41' $$;
grant execute on function pg_temp.enr() to public;
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
create temp table tk (key text primary key, id uuid);
grant all on tk to public;
create function pg_temp.k(p_key text) returns uuid language sql stable as $$ select id from tk where key = p_key $$;
grant execute on function pg_temp.k(text) to public;
create temp table tp (key text primary key, id uuid);
grant all on tp to public;
create function pg_temp.p(p_key text) returns uuid language sql stable as $$ select id from tp where key = p_key $$;
grant execute on function pg_temp.p(text) to public;
insert into tk select 'bl', (app.create_ticket(pg_temp.mk('DN', 'DN_01_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))))  ->> 'id')::uuid;
insert into tk select 'kn', (app.create_ticket(pg_temp.mk('KN', 'KN_02_02')) ->> 'id')::uuid;

-- ================= Phiếu Bảo lưu: người cơ sở khác bị chặn =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.get_task_form_options(pg_temp.k('bl'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn chéo cơ sở: CSKH CS1 không lấy tuỳ chọn biểu mẫu ticket CS5');
select is(pg_temp.err($$select app.create_ticket_task(pg_temp.k('bl'), 'BAO_LUU', 'Thử', jsonb_build_object('enrollment_id', pg_temp.enr(), 'months', 2, 'reason_code', 'BAN_THI'))$$),
          'HMT_KHONG_CO_QUYEN', 'Chặn chéo cơ sở: CSKH CS1 không tạo phiếu Bảo lưu cho ticket CS5');
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
insert into tp select 'bl', (app.create_ticket_task(pg_temp.k('bl'), 'BAO_LUU', 'Bận thi', jsonb_build_object('enrollment_id', pg_temp.enr(), 'months', 2, 'reason_code', 'BAN_THI')) ->> 'id')::uuid;
select app.submit_ticket_task(pg_temp.p('bl'));
select pg_temp.claims(pg_temp.uid('qlcs1'), 'aal1');
select is(pg_temp.err($$select app.approve_ticket_task(pg_temp.p('bl'), 'Thử')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn chéo cơ sở: Trưởng cơ sở CS1 không duyệt phiếu Bảo lưu của CS5 (R-CS-07)');
select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
select app.approve_ticket_task(pg_temp.p('bl'), 'Đồng ý');
select pg_temp.claims(pg_temp.uid('qlcs1'), 'aal1');
select is(pg_temp.err($$select app.execute_ticket_task(pg_temp.p('bl'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn chéo cơ sở: Trưởng cơ sở CS1 không thực hiện phiếu Bảo lưu của CS5');
select is((select status_code from app.enrollment where id = pg_temp.enr()), 'DANG_HOC', 'Nguyên vẹn: ghi danh vẫn Đang học sau các lần bị chặn');
select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
select app.execute_ticket_task(pg_temp.p('bl'));
select is((select status_code from app.enrollment where id = pg_temp.enr()), 'BAO_LUU', 'Đúng: người đúng cơ sở thực hiện được, ghi danh Bảo lưu');

-- ================= Gia hạn và Tiếp tục học: người cơ sở khác bị chặn =================
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
insert into tk select 'gh', (app.create_ticket(pg_temp.mk('DN', 'DN_01_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'))))  ->> 'id')::uuid;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err(format($f$select app.create_ticket_task(%L, 'BAO_LUU', 'Gia hạn', jsonb_build_object('enrollment_id', %L, 'months', 1, 'reason_code', 'BAN_THI', 'extends_hold_id', (select id from app.enrollment_hold where enrollment_id = %L and status_code = 'DANG_BAO_LUU')))$f$,
          pg_temp.k('gh'), pg_temp.enr(), pg_temp.enr())), 'HMT_KHONG_CO_QUYEN', 'Chặn chéo cơ sở: CSKH CS1 không tạo phiếu Gia hạn bảo lưu của CS5');
select is(pg_temp.err(format($f$select app.create_ticket_task(%L, 'BAO_LUU', 'Quay lại', jsonb_build_object('enrollment_id', %L, 'reason_code', 'BAN_THI', 'resume', true))$f$,
          pg_temp.k('gh'), pg_temp.enr())), 'HMT_KHONG_CO_QUYEN', 'Chặn chéo cơ sở: CSKH CS1 không tạo phiếu Tiếp tục học của CS5');
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
insert into tp select 'tt', (app.create_ticket_task(pg_temp.k('gh'), 'BAO_LUU', 'Quay lại', jsonb_build_object('enrollment_id', pg_temp.enr(), 'reason_code', 'BAN_THI', 'resume', true)) ->> 'id')::uuid;
select app.submit_ticket_task(pg_temp.p('tt'));
select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
select app.approve_ticket_task(pg_temp.p('tt'), 'Đồng ý');
select pg_temp.claims(pg_temp.uid('qlcs1'), 'aal1');
select is(pg_temp.err($$select app.execute_ticket_task(pg_temp.p('tt'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn chéo cơ sở: Trưởng cơ sở CS1 không thực hiện phiếu Tiếp tục học của CS5');
select is((select status_code from app.enrollment where id = pg_temp.enr()), 'BAO_LUU', 'Nguyên vẹn: ghi danh vẫn Bảo lưu, chưa về hàng chờ');

-- ================= Nâng cấp khiếu nại: người cơ sở khác bị chặn =================
select is(pg_temp.err($$select app.escalate_ticket(pg_temp.k('kn'), 'Thử')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn chéo cơ sở: Trưởng cơ sở CS1 không nâng cấp khiếu nại CS5 (R-CS-06)');
select is((select escalation_level from app.ticket where id = pg_temp.k('kn')), null, 'Nguyên vẹn: khiếu nại CS5 chưa bị nâng cấp');
select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
select is(app.escalate_ticket(pg_temp.k('kn'), 'Quản lý đúng cơ sở nâng cấp'), 'QUAN_LY_CO_SO', 'Đúng: Trưởng cơ sở CS5 nâng cấp được');

select * from finish();
rollback;
