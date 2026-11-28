-- Kho #19 (migration 585): Group By TT-04 Đối chiếu tái tục (cơ sở, campaign, lý do chưa có phiếu): đếm theo nhóm, bộ lọc lý do mở nhóm, quyền. Dữ liệu dựng như bài 553, giả.
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

-- Dữ liệu: lớp LOP553 (một khung 1,5 giờ mỗi tuần), lớp LOP553B. Sáu học sinh.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH553', 'Phụ huynh giả 553', '0900553001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select s.code, p.id, s.name, 2012, p.branch_id from app.parent p,
    (values ('HS553A', 'Em A'), ('HS553B', 'Em B'), ('HS553C', 'Em C'), ('HS553D', 'Em D'), ('HS553E', 'Em E'), ('HS553F', 'Em F')) s (code, name) where p.code = 'PH553'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select c.code, b.id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10 from app.branch b, (values ('LOP553'), ('LOP553B')) c (code) where b.code = 'CS1'$$);
select pg_temp.sudo($$insert into app.class_slot (class_id, branch_id, weekday, start_time, end_time, first_date)
  select c.id, c.branch_id, 1, '18:00', '19:30', date_trunc('week', current_date)::date from app.class c where c.code in ('LOP553', 'LOP553B')$$);
-- Ngày dự kiến hết giờ theo lịch buổi thật (R-GD-13, 28/11): mỗi tuần một buổi 1,5 giờ.
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time)
  select c.id, c.branch_id, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 7 * n, '18:00', '19:30' from app.class c, generate_series(1, 40) n where c.code in ('LOP553', 'LOP553B')$$);
-- Ghi danh: A giờ ít (sinh phiếu), B giờ nhiều (không), C giờ ít nhưng từng L5 (không sinh lại), D giờ ít nhưng Bảo lưu (không), E đã Dừng, F chuyển lớp.
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code)
  select 'GD553' || right(s.code, 1), s.id, s.parent_id, s.branch_id, v.st
    from app.student s join (values ('HS553A', 'DANG_HOC'), ('HS553B', 'DANG_HOC'), ('HS553C', 'DANG_HOC'), ('HS553D', 'BAO_LUU'), ('HS553E', 'DUNG'), ('HS553F', 'CHUYEN_LOP')) v (code, st) on v.code = s.code$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code)
  select 'GD553F2', s.id, s.parent_id, s.branch_id, 'DANG_HOC' from app.student s where s.code = 'HS553F'$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date, end_date, end_reason)
  select e.id, c.id, c.branch_id, current_date - 60, case when e.status_code in ('DUNG', 'CHUYEN_LOP') then current_date - 1 end,
         case e.status_code when 'DUNG' then 'DUNG' when 'CHUYEN_LOP' then 'CHUYEN_LOP' end
    from app.enrollment e, app.class c where c.code = 'LOP553' and e.code in ('GD553A', 'GD553B', 'GD553C', 'GD553D', 'GD553E', 'GD553F')$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date from app.enrollment e, app.class c where c.code = 'LOP553B' and e.code = 'GD553F2'$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours)
  select e.id, e.branch_id, 'CAP_MUA', v.h from app.enrollment e join (values ('GD553A', 5), ('GD553B', 50), ('GD553C', 5), ('GD553D', 3), ('GD553F2', 40)) v (code, h) on v.code = e.code$$);
-- Phiếu cũ: C đã L5; E có phiếu mở L2 (để dừng học đóng); F có phiếu mở L2 ở lớp cũ (để chuyển lớp).
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, origin_code, lost_reason_code, closed_at)
  select 'TT905301', s.branch_id, s.id, s.parent_id, c.id, 'L5', null, 'HE_THONG', 'HOC_PHI', now() from app.student s, app.class c where s.code = 'HS553C' and c.code = 'LOP553'$$);
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, origin_code)
  select 'TT905302', s.branch_id, s.id, s.parent_id, c.id, 'L2', null, 'HE_THONG' from app.student s, app.class c where s.code = 'HS553E' and c.code = 'LOP553'$$);
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, origin_code)
  select 'TT905303', s.branch_id, s.id, s.parent_id, c.id, 'L2', null, 'HE_THONG' from app.student s, app.class c where s.code = 'HS553F' and c.code = 'LOP553'$$);


-- Tháng của em A (5 giờ, 1,5 giờ mỗi tuần: hết giờ sau 24 ngày) và em B (50 giờ: tháng khác).
create function pg_temp.mon() returns date language sql stable as $$ select date_trunc('month', current_date + 24)::date $$;
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, origin_code, hours_left, expected_end_date)
  select 'TT905304', s.branch_id, s.id, s.parent_id, c.id, 'L2', null, 'TAY', 5, current_date + 24 from app.student s, app.class c where s.code = 'HS553A' and c.code = 'LOP553'$$);
create function pg_temp.expect_n() returns integer language sql stable security definer as $$
  select count(*)::int from app.upsale_candidates() c where c.expected_end_date >= pg_temp.mon() and c.expected_end_date < (pg_temp.mon() + interval '1 month')::date $$;
grant execute on function pg_temp.mon(), pg_temp.expect_n() to public;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;


-- Nhóm theo lý do: tổng các nhóm bằng tổng của bảng; em A có phiếu vào nhóm «Đã có phiếu», em C (từng L5) vào nhóm CO_PHIEU_L5.
select is((app.upsale_reconcile_group_counts(pg_temp.mon(), '{}', array['reason']) ->> 'total')::int,
  (app.list_upsale_reconcile(pg_temp.mon()) ->> 'total')::int, 'TT-04 Group By: tổng số đếm bằng tổng danh sách');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.upsale_reconcile_group_counts(pg_temp.mon(), '{}', array['reason']) -> 'groups') g where g ->> 'k1' = 'DA_CO_PHIEU'),
  (select count(*)::int from jsonb_array_elements(app.list_upsale_reconcile(pg_temp.mon()) -> 'rows') r where r ->> 'ticket_id' is not null), 'TT-04 Group By: nhóm Đã có phiếu đếm đúng số dòng có phiếu');
select is((select g ->> 'l1' from jsonb_array_elements(app.upsale_reconcile_group_counts(pg_temp.mon(), '{}', array['reason']) -> 'groups') g where g ->> 'k1' = 'CO_PHIEU_L5'),
  'Có phiếu L5 gần đây', 'TT-04 Group By: nhãn nhóm lý do bằng tiếng Việt');
-- Bộ lọc `reason` mở từng nhóm: số dòng khớp số đếm.
select is(jsonb_array_length(app.list_upsale_reconcile(pg_temp.mon(), '{"reason": ["CO_PHIEU_L5"]}') -> 'rows'),
  (select (g ->> 'count')::int from jsonb_array_elements(app.upsale_reconcile_group_counts(pg_temp.mon(), '{}', array['reason']) -> 'groups') g where g ->> 'k1' = 'CO_PHIEU_L5'),
  'TT-04: lọc theo lý do CO_PHIEU_L5 ra đúng số dòng của nhóm');
select is((select count(*)::int from jsonb_array_elements(app.list_upsale_reconcile(pg_temp.mon(), '{"reason": ["DA_CO_PHIEU"]}') -> 'rows') r where r ->> 'ticket_id' is null), 0,
  'TT-04: lọc DA_CO_PHIEU không có dòng thiếu phiếu');
-- Nhóm theo cơ sở rồi lý do (hai cấp); campaign một nhóm duy nhất cho tháng đang xem.
select is((select count(*)::int from jsonb_array_elements(app.upsale_reconcile_group_counts(pg_temp.mon(), '{}', array['campaign']) -> 'groups')), 1, 'TT-04 Group By: campaign tháng đang xem là một nhóm');
select is((select g ->> 'l1' from jsonb_array_elements(app.upsale_reconcile_group_counts(pg_temp.mon(), '{}', array['campaign']) -> 'groups') g), 'Tái tục ' || to_char(pg_temp.mon(), 'MM/YYYY'), 'TT-04 Group By: nhãn campaign là tháng');
select ok((select bool_and(g ->> 'l1' is not null and g ->> 'l2' is not null) from jsonb_array_elements(app.upsale_reconcile_group_counts(pg_temp.mon(), '{}', array['branch', 'reason']) -> 'groups') g), 'TT-04 Group By: hai cấp cơ sở và lý do đều có nhãn');
-- Chặn: trường nhóm lạ, trùng hai cấp, quá hai cấp.
select is(pg_temp.err($$select app.upsale_reconcile_group_counts(pg_temp.mon(), '{}', array['status'])$$), 'HMT_NHOM_SAI', 'TT-04 Group By chặn: trường nhóm lạ');
select is(pg_temp.err($$select app.upsale_reconcile_group_counts(pg_temp.mon(), '{}', array['branch', 'branch'])$$), 'HMT_NHOM_SAI', 'TT-04 Group By chặn: hai cấp trùng nhau');
select is(pg_temp.err($$select app.upsale_reconcile_group_counts(pg_temp.mon(), '{}', array['branch', 'campaign', 'reason'])$$), 'HMT_NHOM_SAI', 'TT-04 Group By chặn: quá hai cấp');
-- Quyền: không có quyền Xem phiếu tái tục bị chặn.
reset role;
select pg_temp.claims(pg_temp.uid('nobody'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.upsale_reconcile_group_counts(date '2026-11-01', '{}', array['reason'])$$), 'HMT_KHONG_CO_QUYEN', 'TT-04 Group By chặn: người không có quyền Xem phiếu tái tục');
reset role;
select * from finish();
rollback;
