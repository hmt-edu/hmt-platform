-- Migration 591 (GD-02, GD-03): hàm đọc trả thêm hạn mức học trước (R-GD-12), ngày bảo lưu (R-GD-09), nhắc mềm thiếu môn Đại/Hình. Chỉ đọc, quyền giữ nguyên. Dữ liệu giả.
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
create function pg_temp.tk(p_student text, p_class text default 'LOP553') returns app.upsale_ticket language sql stable security definer as $$
  select t from app.upsale_ticket t where t.student_id = pg_temp.sid(p_student) and t.class_id = (select id from app.class where code = p_class)
   order by t.created_at desc, t.id limit 1 $$;
create function pg_temp.nt() returns integer language sql stable security definer as $$ select count(*)::int from app.upsale_ticket $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh1'), ('nobody');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p553.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p553.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code) select u.id, v.role from u join (values ('admin', 'ADMIN'), ('cskh1', 'CSKH')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- Dữ liệu: ba học sinh; em 1 chỉ có ghi danh HINH (chờ xếp lớp); em 2 học trước ở lớp có khung 1,5 giờ; em 3 đang bảo lưu 01-31/10/2026.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH591', 'Phụ huynh giả 591', '0900591001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select s.code, p.id, s.name, 2012, p.branch_id from app.parent p, (values ('HS591A', 'Em A'), ('HS591B', 'Em B'), ('HS591C', 'Em C')) s (code, name) where p.code = 'PH591'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select 'LOP591', id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10 from app.branch where code = 'CS1'$$);
select pg_temp.sudo($$insert into app.class_slot (class_id, branch_id, weekday, start_time, end_time, first_date)
  select c.id, c.branch_id, 1, '18:00', '19:30', date_trunc('week', current_date)::date from app.class c where c.code = 'LOP591'$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code, subject_code)
  select 'GD591A', s.id, s.parent_id, s.branch_id, 'CHO_XEP_LOP', 'HINH' from app.student s where s.code = 'HS591A'$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code, pay_later_enabled)
  select 'GD591B', s.id, s.parent_id, s.branch_id, 'DANG_HOC', true from app.student s where s.code = 'HS591B'$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date from app.enrollment e, app.class c where e.code = 'GD591B' and c.code = 'LOP591'$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code)
  select 'GD591C', s.id, s.parent_id, s.branch_id, 'BAO_LUU' from app.student s where s.code = 'HS591C'$$);
select pg_temp.sudo($$insert into app.enrollment_hold (enrollment_id, student_id, branch_id, kind_code, months, start_date, end_date, return_status_code, reason_code, status_code)
  select e.id, e.student_id, e.branch_id, 'MOI', 1, date '2026-10-01', date '2026-10-31', 'DANG_HOC', 'BAN_THI', 'DANG_BAO_LUU' from app.enrollment e where e.code = 'GD591C'$$);
create function pg_temp.eid(p_code text) returns uuid language sql stable security definer as $$ select id from app.enrollment where code = p_code $$;
grant execute on function pg_temp.eid(text) to public;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;

-- GD-02: hạn mức học trước = max_sessions_ahead buổi × giờ một buổi của lớp đang học (1,5 giờ).
select is((app.enrollment_record(pg_temp.eid('GD591B')) -> 'hours' ->> 'negative_limit_sessions')::int, 2, 'GD-02: ghi danh học trước có hạn mức theo số buổi (tham số max_sessions_ahead)');
select is((app.enrollment_record(pg_temp.eid('GD591B')) -> 'hours' ->> 'negative_limit_hours')::numeric, 3.0, 'GD-02: hạn mức theo giờ = số buổi × giờ một buổi của lớp');
select is(app.enrollment_record(pg_temp.eid('GD591A')) -> 'hours' -> 'negative_limit_hours', 'null'::jsonb, 'GD-02: ghi danh không học trước không có hạn mức âm');
-- GD-02: ngày bảo lưu đang chạy.
select is(app.enrollment_record(pg_temp.eid('GD591C')) -> 'enrollment' ->> 'hold_start', '2026-10-01', 'GD-02: bản ghi nêu ngày bắt đầu bảo lưu');
select is(app.enrollment_record(pg_temp.eid('GD591C')) -> 'enrollment' ->> 'hold_end', '2026-10-31', 'GD-02: bản ghi nêu ngày hết hạn bảo lưu');
select is(app.enrollment_record(pg_temp.eid('GD591B')) -> 'enrollment' -> 'hold_start', 'null'::jsonb, 'GD-02: không bảo lưu thì không có ngày');
select is(app.enrollment_record(pg_temp.eid('GD591B')) -> 'enrollment' -> 'refund_voucher_code', 'null'::jsonb, 'GD-02: chưa hoàn phí thì không có mã phiếu chi');
-- GD-03: nhắc mềm thiếu môn: em chỉ có HINH nên nhắc thiếu DAI; có đủ hai môn thì hết nhắc; môn khác không nhắc.
select is(app.enrollment_assign_options(pg_temp.eid('GD591A')) -> 'sibling_hint' ->> 'missing_subject_code', 'DAI', 'GD-03: em mới có ghi danh Hình thì nhắc chưa có Đại');
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code, subject_code)
  select 'GD591D', s.id, s.parent_id, s.branch_id, 'DANG_HOC', 'DAI' from app.student s where s.code = 'HS591A'$$);
select is(app.enrollment_assign_options(pg_temp.eid('GD591A')) -> 'sibling_hint', 'null'::jsonb, 'GD-03: đã có cả Đại và Hình thì không nhắc');
-- Nhắc mềm không chặn: ghi danh có hint vẫn đọc được danh sách lớp phù hợp (không lỗi).
select ok(app.enrollment_assign_options(pg_temp.eid('GD591A')) ? 'classes', 'GD-03: nhắc mềm không chặn, vẫn trả danh sách lớp');
-- Quyền: người không có quyền không đọc được.
reset role;
select pg_temp.claims(pg_temp.uid('nobody'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.enrollment_assign_options(pg_temp.eid('GD591A'))$$), 'HMT_KHONG_CO_QUYEN', 'GD-03 chặn: người không có quyền Ghi danh · Sửa');
reset role;
select * from finish();
rollback;
