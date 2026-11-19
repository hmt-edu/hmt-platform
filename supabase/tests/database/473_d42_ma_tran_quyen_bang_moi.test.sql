-- D42 (Code D): ma trận quyền cho bảng thêm mới từ 17/11 (curriculum_frame, curriculum_lesson, upsale_ticket, upsale_ticket_event, review_rubric_version): mọi vai trò đọc theo đúng phạm vi ma trận, không vai nào ghi thẳng bảng. Dữ liệu giả.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$ begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.sid(p_code text) returns uuid language sql stable security definer as $$ select id from app.student where code = p_code $$;
create function pg_temp.cid(p_code text) returns uuid language sql stable security definer as $$ select id from app.class where code = p_code $$;
create function pg_temp.tid(p_code text) returns uuid language sql stable security definer as $$ select id from app.upsale_ticket where code = p_code $$;
create function pg_temp.stage(p_code text) returns text language sql stable security definer as $$ select stage_code from app.upsale_ticket where code = p_code $$;
create function pg_temp.evs(p_code text) returns text language sql stable security definer as $$
  select string_agg(event_type, ',' order by seq) from app.upsale_ticket_event where ticket_id = pg_temp.tid(p_code) $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid(), role_code text not null, cs text not null);
-- Mỗi vai trò nhân viên một người ở CS1; thêm một CSKH và một Trưởng cơ sở ở CS5 để thử ngoài phạm vi.
insert into u (key, role_code, cs) select lower(r.code) || '1', r.code, 'CS1' from app.role r where r.code <> 'PARENT' and r.code <> 'STUDENT';
insert into u (key, role_code, cs) values ('cskh5', 'CSKH', 'CS5'), ('bm5', 'BRANCH_MANAGER', 'CS5');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d42.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d42.hoamatoan.invalid', (select id from app.branch where code = u.cs), false from u;
insert into app.user_role (user_id, role_code) select id, role_code from u;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code in ('CS1', 'CS5') on conflict (module_code, branch_id) do update set enabled = true$$);

-- Dữ liệu: một phiếu tái tục ở mỗi cơ sở (kèm nhật ký), một khung và hai bài; rubric đã có từ migration.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) select 'PH42' || b.code, 'Phụ huynh giả ' || b.code, '09004200' || right(b.code, 1), b.id from app.branch b where b.code in ('CS1', 'CS5')$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id) select 'HS42' || b.code, p.id, 'Em ' || b.code, 2012, b.id from app.branch b join app.parent p on p.branch_id = b.id and p.code = 'PH42' || b.code$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions) select 'LOP42' || b.code, b.id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10 from app.branch b where b.code in ('CS1', 'CS5')$$);
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, origin_code)
  select 'TT42' || b.code, b.id, s.id, s.parent_id, c.id, 'TAY' from app.branch b join app.student s on s.branch_id = b.id and s.code = 'HS42' || b.code join app.class c on c.branch_id = b.id and c.code = 'LOP42' || b.code$$);
select pg_temp.sudo($$insert into app.upsale_ticket_event (ticket_id, branch_id, event_type) select id, branch_id, 'TAO' from app.upsale_ticket where code like 'TT42%'$$);
select pg_temp.sudo($$insert into app.curriculum_frame (code, subject_code, grade_code, level_code, year_code) values ('TOAN-K09-CB-2627', 'TOAN', 'K09', 'CB', '2627')$$);
select pg_temp.sudo($$insert into app.curriculum_lesson (frame_id, position, code, title) select id, p, 'TOAN-K09-CB-2627-B0' || p, 'Bài ' || p from app.curriculum_frame, generate_series(1, 2) p where code = 'TOAN-K09-CB-2627'$$);

-- Số dòng ĐÚNG phải thấy, tính bằng quyền chủ từ ma trận (không từ chính sách RLS): không có quyền Xem thì 0; toàn hệ thống thì hết; cơ sở thì cùng cơ sở (bảng có branch_id).
create function pg_temp.jwt(p_user uuid) returns void language plpgsql security definer as $$
begin
  perform set_config('request.jwt.claims', (app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
    'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2'))) -> 'claims')::text, true);
end $$;
create function pg_temp.expected(p_user uuid, p_module text, p_table text, p_by_branch boolean) returns bigint language plpgsql security definer as $$
declare v_scope text; v_branch uuid; v_n bigint;
begin
  perform pg_temp.jwt(p_user);
  v_scope := app.permission_scope(p_module, 'XEM'); v_branch := app.current_branch_id();
  perform set_config('request.jwt.claims', '', true);
  if v_scope is null then return 0; end if;
  execute format('select count(*) from app.%I %s', p_table,
    case when p_by_branch and v_scope <> 'TOAN_HE_THONG' then format('where branch_id = %L', v_branch) else '' end) into v_n;
  return v_n;
end $$;
-- Số dòng THẤY THẬT khi chạy bằng vai authenticated với phiên của người đó (RLS).
create function pg_temp.visible(p_user uuid, p_table text) returns bigint language plpgsql security definer as $$
declare v_n bigint;
begin
  perform pg_temp.jwt(p_user);
  set local role authenticated;
  execute format('select count(*) from app.%I', p_table) into v_n;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v_n;
end $$;
-- Ghi thẳng bảng (thêm, sửa, xoá) bằng vai authenticated: trả mã lỗi của lần đầu thất bại, hoặc null nếu có lần lọt.
create function pg_temp.direct_write(p_user uuid, p_table text) returns text language plpgsql security definer as $$
declare v_state text; v_sql text; v_out text := '42501';
begin
  perform pg_temp.jwt(p_user);
  set local role authenticated;
  foreach v_sql in array array[format('insert into app.%I default values', p_table), format('update app.%I set updated_by = null', p_table), format('delete from app.%I', p_table)] loop
    begin
      execute v_sql;
      v_out := null;
    exception when others then
      get stacked diagnostics v_state = returned_sqlstate;
      if v_state <> '42501' then v_out := v_state; end if;
    end;
  end loop;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v_out;
end $$;
grant execute on all functions in schema pg_temp to public;

select ok((select count(*) from u) >= 12, 'Dựng đủ người dùng giả mỗi vai trò nhân viên');
select ok((select count(*) from app.upsale_ticket where code like 'TT42%') = 2 and (select count(*) from app.curriculum_lesson) >= 2, 'Dữ liệu giả có phiếu hai cơ sở và bài học');

-- ================= Đọc: mỗi vai thấy đúng số dòng theo ma trận (Xem toàn hệ thống / cơ sở / không có) =================
select is(pg_temp.visible(u.id, t.tbl), pg_temp.expected(u.id, t.module, t.tbl, t.by_branch),
          format('Đọc %s: vai %s (%s) thấy đúng số dòng theo ma trận', t.tbl, u.role_code, u.cs))
  from u cross join (values ('upsale_ticket', 'UPSALE', true), ('upsale_ticket_event', 'UPSALE', true),
                            ('curriculum_frame', 'CONFIG_TRAINING', false), ('curriculum_lesson', 'CONFIG_TRAINING', false),
                            ('review_rubric_version', 'ATTENDANCE', false)) as t (tbl, module, by_branch)
 order by t.tbl, u.key;

-- Ngoài phạm vi: CSKH ở CS5 không thấy phiếu của CS1 (chỉ thấy phiếu CS5) nếu có quyền Xem theo cơ sở.
select is(pg_temp.visible(pg_temp.uid('cskh5'), 'upsale_ticket'), (select count(*) from app.upsale_ticket where branch_id = (select id from app.branch where code = 'CS5')), 'CSKH CS5 chỉ thấy phiếu tái tục của cơ sở mình');
select is(pg_temp.visible(pg_temp.uid('bm5'), 'upsale_ticket_event'), (select count(*) from app.upsale_ticket_event where branch_id = (select id from app.branch where code = 'CS5')), 'Trưởng cơ sở CS5 chỉ thấy nhật ký phiếu của cơ sở mình');

-- ================= Ghi: không vai nào ghi thẳng bảng (mọi thay đổi qua hàm nghiệp vụ) =================
select is(pg_temp.direct_write(u.id, t.tbl), '42501', format('Ghi thẳng %s bị chặn: vai %s', t.tbl, u.role_code))
  from u cross join (values ('upsale_ticket'), ('upsale_ticket_event'), ('curriculum_frame'), ('curriculum_lesson'), ('review_rubric_version')) as t (tbl)
 order by t.tbl, u.key;

select * from finish();
rollback;
