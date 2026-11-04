-- Hội sở CS3 (văn phòng) và quyền Xuất file phiếu tái tục của Trưởng cơ sở (chốt 11/10/2026).
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
grant execute on all functions in schema pg_temp to public;

-- ---------- Hội sở ----------
select is((select name from app.branch where code = 'CS3'), 'Hội sở', 'CS3 vẫn tên Hội sở');
-- Từ 04/11/2026 (Đ286, R-V2-10): CS3 là cơ sở dạy học thường, có phòng, lớp, học sinh.
select ok(not (select is_office from app.branch where code = 'CS3'), 'CS3 là cơ sở dạy học thường (không còn là văn phòng)');
select is(pg_temp.err($$insert into app.room (branch_id, code, name) select id, 'P1', 'Phòng' from app.branch where code = 'CS3'$$),
          null, 'CS3 tạo được phòng học');
select is(pg_temp.err($$insert into app.room (branch_id, code, name) select id, 'PHS1', 'Phòng' from app.branch where code = 'CS1'$$),
          null, 'Cơ sở dạy học vẫn tạo phòng được');
select is(pg_temp.err($$update app.branch set is_office = true where code = 'CS1'$$),
          'HMT_CO_SO_VAN_PHONG', 'Không đổi cơ sở đang có phòng học thành văn phòng');
select is(pg_temp.err($$update app.branch set is_office = true where code = 'CS3'$$),
          'HMT_CO_SO_VAN_PHONG', 'Không đổi CS3 đã có phòng học thành văn phòng');

-- Nhân viên gắn vào Hội sở được; Kế toán ở Hội sở vẫn phạm vi toàn hệ thống.
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('kt'), ('bm5');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@hs.hoamatoan.invalid' from u;
select is(pg_temp.err($$insert into app.user_account (id, display_name, login_name, branch_id)
                         select id, 'Kế toán Hội sở', 'kt@hs.hoamatoan.invalid', (select id from app.branch where code = 'CS3')
                           from u where key = 'kt'$$),
          null, 'Gắn tài khoản nhân viên vào Hội sở được');
insert into app.user_account (id, display_name, login_name, branch_id)
select id, 'TCS 5', 'bm5@hs.hoamatoan.invalid', (select id from app.branch where code = 'CS5') from u where key = 'bm5';
insert into app.user_role (user_id, role_code) select id, 'ACCOUNTANT' from u where key = 'kt';
insert into app.user_role (user_id, role_code) select id, 'BRANCH_MANAGER' from u where key = 'bm5';

set local role authenticated;
select pg_temp.claims((select id from u where key = 'kt'));
select is((auth.jwt() ->> 'hmt_branch_code'), 'CS3', 'Token của nhân viên Hội sở ghi cơ sở CS3');
reset role;

-- ---------- Xuất file phiếu tái tục ----------
set local role authenticated;
select pg_temp.claims((select id from u where key = 'bm5'));
select ok(app.has_permission('UPSALE', 'XUAT'), 'Trưởng cơ sở: Xuất file phiếu tái tục được');
select ok(not app.has_permission('ACCOUNTING', 'XUAT'), 'Trưởng cơ sở: phân hệ Kế toán vẫn KHÔNG Xuất file');
select ok(not app.can_see_branch('UPSALE', 'XUAT', (select id from app.branch where code = 'CS1')),
          'Trưởng cơ sở CS5: không Xuất phiếu tái tục của CS1');
reset role;
select set_config('request.jwt.claims', '', true);

select * from finish();
rollback;
