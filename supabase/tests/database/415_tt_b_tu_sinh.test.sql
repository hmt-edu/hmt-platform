-- TT-B (migration 415): tự sinh, đối soát phiếu tái tục. Luật R-GD-13: ngưỡng giờ hoặc ngày, mỗi cặp một phiếu mở, L5 không sinh lại, bảo lưu dừng sinh, dừng học đóng phiếu,
-- chuyển lớp chuyển phiếu, cờ rủi ro vắng; cờ tắt mặc định. Dữ liệu giả.
begin;
-- D41 (migration 472): bài này kiểm luật «Admin, Kế toán phải qua hai bước»; luật chỉ áp khi tham số mfa_required_enabled bật (mặc định tắt), nên bật tham số ở đây.
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
-- 647 (A-23-27): bắt hai bước chỉ còn Admin; bài này vẫn kiểm luật aal2 cho Kế toán nên dựng lại cờ trong giao dịch của bài (hoàn tác khi kết thúc).
do $$ begin perform set_config('hmt.migration', 'on', true); update app.role set require_mfa = true where code = 'ACCOUNTANT'; perform set_config('hmt.migration', '', true); end $$;
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
create function pg_temp.tk(p_student text, p_class text default 'LOP411') returns app.upsale_ticket language sql stable security definer as $$
  select t from app.upsale_ticket t where t.student_id = pg_temp.sid(p_student) and t.class_id = (select id from app.class where code = p_class)
   order by t.created_at desc, t.id limit 1 $$;
create function pg_temp.nt() returns integer language sql stable security definer as $$ select count(*)::int from app.upsale_ticket $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p415.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p415.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code) select u.id, v.role from u join (values ('admin', 'ADMIN'), ('cskh1', 'CSKH')) as v (key, role) on v.key = u.key;
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'BAN_HANG', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- Dữ liệu: lớp LOP411 (một khung 1,5 giờ mỗi tuần), lớp LOP411B. Sáu học sinh.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PH411', 'Phụ huynh giả 411', '0900411001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select s.code, p.id, s.name, 2012, p.branch_id from app.parent p,
    (values ('HS411A', 'Em A'), ('HS411B', 'Em B'), ('HS411C', 'Em C'), ('HS411D', 'Em D'), ('HS411E', 'Em E'), ('HS411F', 'Em F')) s (code, name) where p.code = 'PH411'$$);
select pg_temp.sudo($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  select c.code, b.id, '2627', 'TOAN', 'K09', 'CB', 'A', current_date, 10 from app.branch b, (values ('LOP411'), ('LOP411B')) c (code) where b.code = 'CS1'$$);
select pg_temp.sudo($$insert into app.class_slot (class_id, branch_id, weekday, start_time, end_time, first_date)
  select c.id, c.branch_id, 1, '18:00', '19:30', date_trunc('week', current_date)::date from app.class c where c.code in ('LOP411', 'LOP411B')$$);
-- Ngày dự kiến hết giờ theo lịch buổi thật (R-GD-13, 28/11): mỗi tuần một buổi 1,5 giờ.
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time)
  select c.id, c.branch_id, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 7 * n, '18:00', '19:30' from app.class c, generate_series(1, 40) n where c.code in ('LOP411', 'LOP411B')$$);
-- Ghi danh: A giờ ít (sinh phiếu), B giờ nhiều (không), C giờ ít nhưng từng L5 (không sinh lại), D giờ ít nhưng Bảo lưu (không), E đã Dừng, F chuyển lớp.
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code)
  select 'GD411' || right(s.code, 1), s.id, s.parent_id, s.branch_id, v.st
    from app.student s join (values ('HS411A', 'DANG_HOC'), ('HS411B', 'DANG_HOC'), ('HS411C', 'DANG_HOC'), ('HS411D', 'BAO_LUU'), ('HS411E', 'DUNG'), ('HS411F', 'CHUYEN_LOP')) v (code, st) on v.code = s.code$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code)
  select 'GD411F2', s.id, s.parent_id, s.branch_id, 'DANG_HOC' from app.student s where s.code = 'HS411F'$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date, end_date, end_reason)
  select e.id, c.id, c.branch_id, current_date - 60, case when e.status_code in ('DUNG', 'CHUYEN_LOP') then current_date - 1 end,
         case e.status_code when 'DUNG' then 'DUNG' when 'CHUYEN_LOP' then 'CHUYEN_LOP' end
    from app.enrollment e, app.class c where c.code = 'LOP411' and e.code in ('GD411A', 'GD411B', 'GD411C', 'GD411D', 'GD411E', 'GD411F')$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date from app.enrollment e, app.class c where c.code = 'LOP411B' and e.code = 'GD411F2'$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours)
  select e.id, e.branch_id, 'CAP_MUA', v.h from app.enrollment e join (values ('GD411A', 5), ('GD411B', 50), ('GD411C', 5), ('GD411D', 3), ('GD411F2', 40)) v (code, h) on v.code = e.code$$);
-- Phiếu cũ: C đã L5; E có phiếu mở L2 (để dừng học đóng); F có phiếu mở L2 ở lớp cũ (để chuyển lớp).
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, origin_code, lost_reason_code, closed_at)
  select 'TT900001', s.branch_id, s.id, s.parent_id, c.id, 'L5', null, 'HE_THONG', 'HOC_PHI', now() from app.student s, app.class c where s.code = 'HS411C' and c.code = 'LOP411'$$);
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, origin_code)
  select 'TT900002', s.branch_id, s.id, s.parent_id, c.id, 'L2', null, 'HE_THONG' from app.student s, app.class c where s.code = 'HS411E' and c.code = 'LOP411'$$);
select pg_temp.sudo($$insert into app.upsale_ticket (code, branch_id, student_id, parent_id, class_id, stage_code, substage_code, origin_code)
  select 'TT900003', s.branch_id, s.id, s.parent_id, c.id, 'L2', null, 'HE_THONG' from app.student s, app.class c where s.code = 'HS411F' and c.code = 'LOP411'$$);

-- ---- Cờ tắt mặc định ----
select is((select value from app.setting_def where key = 'upsale_auto_generate_enabled'), 'false', 'Cờ upsale_auto_generate_enabled mặc định TẮT');
select is((select count(*)::int from app.upsale_candidates() where student_id = pg_temp.sid('HS411A')), 1, 'Ứng viên: em A có một dòng (hàm nội bộ)');
select is((select hours_left from app.upsale_candidates() where student_id = pg_temp.sid('HS411B')), 50::numeric, 'Giờ còn của em B = 50');
select is((select expected_end_date from app.upsale_candidates() where student_id = pg_temp.sid('HS411A')),
          ((now() at time zone 'Asia/Ho_Chi_Minh')::date + 28), 'Hết giờ dự kiến của em A: 5 giờ, mỗi buổi 1,5 giờ, hết ở buổi thứ tư (28 ngày)');
select is((select count(*)::int from app.upsale_candidates() where student_id = pg_temp.sid('HS411D')), 0, 'Em D bảo lưu: không phải ứng viên');
select is(app.generate_upsale_tickets() ->> 'created', '0', 'Cờ tắt: không sinh phiếu');
select is(pg_temp.nt(), 3, 'Cờ tắt: số phiếu giữ nguyên (3 phiếu cũ)');
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'upsale_auto_generate_enabled'$$);

set local role authenticated;
-- ---- Quyền ----
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.generate_upsale_tickets()$$), 'HMT_KHONG_CO_QUYEN', 'CSKH không chạy tự sinh');
select is(pg_temp.err($$select app.sync_upsale_cron()$$), 'HMT_KHONG_CO_QUYEN', 'CSKH không đổi lịch cron (hoặc pg_cron chưa bật)');
select is(pg_temp.err($$select app.upsale_candidates()$$), '42501', 'Người dùng không gọi trực tiếp hàm ứng viên');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.generate_upsale_tickets()$$), 'HMT_KHONG_CO_QUYEN', 'Admin chưa hai bước không chạy tự sinh');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- ---- Sinh, đối soát ----
select is(app.generate_upsale_tickets() ->> 'created', '1', 'Admin chạy: sinh 1 phiếu (em A chạm ngưỡng giờ)');
select is((pg_temp.tk('HS411A')).origin_code, 'HE_THONG', 'Phiếu sinh tự động: nguồn hệ thống');
select is((pg_temp.tk('HS411A')).substage_code, 'L1A', 'Phiếu sinh tự động ở nhóm con L1A');
select is((pg_temp.tk('HS411A')).owner_id, null, 'Phiếu sinh tự động chưa có người phụ trách');
select is((pg_temp.tk('HS411A')).hours_left, 5::numeric, 'Phiếu chụp giờ còn 5');
select is((pg_temp.tk('HS411B')).id, null, 'Em B (50 giờ) chưa chạm ngưỡng: không sinh');
select is((select count(*)::int from app.upsale_ticket where student_id = pg_temp.sid('HS411C')), 1, 'R-GD-13: em C đã L5 không tự sinh lại');
select is((select count(*)::int from app.upsale_ticket where student_id = pg_temp.sid('HS411D')), 0, 'R-GD-13: em D bảo lưu dừng sinh');
select is((pg_temp.tk('HS411E')).stage_code, 'L5', 'R-GD-13: em E dừng học thì phiếu mở được đóng ở L5');
select is((pg_temp.tk('HS411E')).lost_reason_code || ':' || (pg_temp.tk('HS411E')).lost_note, 'KHAC:Học sinh đã dừng học (hệ thống đóng phiếu)', 'Phiếu đóng do dừng học ghi lý do Khác kèm ghi chú dừng học');
select is((pg_temp.tk('HS411F', 'LOP411B')).stage_code, 'L2', 'R-GD-13: em F chuyển lớp thì phiếu mở chuyển theo lớp mới (giữ giai đoạn)');
select is((pg_temp.tk('HS411F')).id, null, 'Phiếu em F không còn ở lớp cũ');
select is(pg_temp.nt(), 4, 'Tổng 4 phiếu sau lần chạy đầu');
select is(app.generate_upsale_tickets() ->> 'created', '0', 'Chạy lại: không sinh trùng');

-- ---- Cập nhật khi giờ đổi ----
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) select id, branch_id, 'CAP_MUA', 10 from app.enrollment where code = 'GD411A'$$);
select is(app.generate_upsale_tickets() ->> 'updated', '1', 'Giờ còn đổi: cập nhật 1 phiếu mở');
select is((pg_temp.tk('HS411A')).hours_left, 15::numeric, 'Phiếu cập nhật giờ còn 15');

-- ---- Cờ rủi ro vắng ----
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time)
  select c.id, c.branch_id, current_date - n, '18:00', '19:30' from app.class c, generate_series(1, 3) n where c.code = 'LOP411'$$);
select pg_temp.sudo($$insert into app.session_attendance (session_id, class_id, branch_id, student_id, enrollment_id, teacher_status_code)
  select s.id, s.class_id, s.branch_id, st.id, e.id, 'VANG_KHONG_PHEP' from app.class_session s, app.student st, app.enrollment e
   where s.class_id = (select id from app.class where code = 'LOP411') and st.code = 'HS411A' and e.code = 'GD411A'$$);
select is(app.generate_upsale_tickets() ->> 'updated', '1', 'Vắng 3 buổi trong 30 ngày: cập nhật cờ rủi ro');
select is((pg_temp.tk('HS411A')).risk_flag, true, 'Phiếu em A gắn cờ rủi ro vắng');
select is((pg_temp.tk('HS411B')).id, null, 'Em B không bị ảnh hưởng');

-- ---- Nhắc của Chat: học sinh khác cơ sở với lớp thì không tạo tay được ----
reset role;
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HS411G', p.id, 'Em G', 2012, (select id from app.branch where code = 'CS5') from app.parent p where p.code = 'PH411'$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code)
  select 'GD411G', s.id, s.parent_id, s.branch_id, 'DANG_HOC' from app.student s where s.code = 'HS411G'$$);
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select e.id, c.id, c.branch_id, current_date from app.enrollment e, app.class c where e.code = 'GD411G' and c.code = 'LOP411'$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.create_upsale_ticket(pg_temp.sid('HS411G'), (select id from app.class where code = 'LOP411'))$$), 'HMT_HOC_SINH_KHAC_CO_SO', 'Học sinh khác cơ sở với lớp: không tạo tay được');

select * from finish();
rollback;
