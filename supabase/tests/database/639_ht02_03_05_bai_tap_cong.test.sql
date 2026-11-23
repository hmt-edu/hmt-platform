-- HT-02, HT-03, HT-05: app.portal_assignments, app.portal_assignment (migration 639). Luật: ba nhóm Cần làm/Đã nộp/Đã chấm; quá hạn ở Cần làm;
-- R-LMS-02 (nhận muộn hay khoá), R-LMS-03 (nộp lại theo công tắc, chấm rồi khoá); kết quả chỉ lộ sau khi chấm; quyền riêng theo con.
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
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.sid(p_code text) returns uuid language plpgsql security definer as $$ begin return (select id from app.student where code = p_code); end $$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả: hs1, hs2 (học sinh), ph1, ph2 (phụ huynh), ph3 (phụ huynh bị khoá), nv (nhân viên) ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('hs1'), ('hs2'), ('ph1'), ('ph2'), ('ph3'), ('nv'), ('hs3');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ht1.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, parent_code, is_locked, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ht1.hoamatoan.invalid', (select id from app.branch where code = 'CS1'),
       case u.key when 'hs1' then 'HS992001' when 'hs2' then 'HS992003' when 'hs3' then 'HS992004' end,
       case u.key when 'ph1' then 'PH992001' when 'ph2' then 'PH992002' when 'ph3' then 'PH992003' end,
       u.key = 'ph3', false
  from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('hs1', 'STUDENT'), ('hs2', 'STUDENT'), ('hs3', 'STUDENT'), ('ph1', 'PARENT'), ('ph2', 'PARENT'), ('ph3', 'PARENT'), ('nv', 'SALES')) as v (key, role) on v.key = u.key;

-- ---------- Dữ liệu: PH992001 có 2 con; lớp LOPHT01 có buổi hôm qua, hôm nay, ngày mai, ngoài khoảng, buổi bị thay, buổi bù ----------
insert into app.parent (code, full_name, phone, branch_id)
select c.code, c.name, c.phone, (select id from app.branch where code = 'CS1')
  from (values ('PH992001', 'Phụ huynh Mẫu Ht Một', '0992100001'), ('PH992002', 'Phụ huynh Mẫu Ht Hai', '0992100002')) as c (code, name, phone);
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = c.ph), c.name, 2012, (select id from app.branch where code = 'CS1')
  from (values ('HS992001', 'PH992001', 'Em Ht Một'), ('HS992002', 'PH992001', 'Em Ht Hai'), ('HS992003', 'PH992002', 'Em Ht Ba')) as c (code, ph, name);
insert into app.feature_flag (module_code, branch_id, enabled)
select 'HOC_TAP', b.id, true from app.branch b where b.code = 'CS1'
on conflict (module_code, branch_id) do update set enabled = true;
insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
select 'LOPHT01', id, '2627', 'TOAN', 'K08', 'CB', 'A', current_date - 30, 10 from app.branch where code = 'CS1';
insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, delivery_mode_code, status_code, purchased_hours, gifted_hours)
select 'GDHT01', st.id, st.parent_id, st.branch_id, 'TOAN', 'OFF', 'DANG_HOC', 24, 0 from app.student st where st.code = 'HS992001';
insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, delivery_mode_code, status_code, purchased_hours, gifted_hours)
select 'GDHT03', st.id, st.parent_id, st.branch_id, 'TOAN', 'OFF', 'DANG_HOC', 24, 0 from app.student st where st.code = 'HS992003';
-- HS992001 học lớp từ 30 ngày trước; HS992003 học lớp khác (không có buổi nào ở LOPHT01).
insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
select e.id, (select id from app.class where code = 'LOPHT01'), e.branch_id, current_date - 30 from app.enrollment e where e.code = 'GDHT01';
insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, status_code, type_code)
select (select id from app.class where code = 'LOPHT01'), (select id from app.branch where code = 'CS1'), v.no, current_date + v.d, '18:00', '19:30', v.st, v.ty
  from (values (1, -1, 'DONE', 'CHINH'), (2, 0, 'DA_CHOT', 'CHINH'), (3, 1, 'NHAP', 'CHINH'), (4, 20, 'NHAP', 'CHINH'), (5, 2, 'DA_THAY', 'CHINH')) as v (no, d, st, ty);
-- Buổi bù của lớp khác: HS992002 có tên trong điểm danh (không thuộc lớp nào), HS992001 không.
insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
select 'LOPHT02', id, '2627', 'TOAN', 'K08', 'CB', 'A', current_date - 30, 10 from app.branch where code = 'CS1';
insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, status_code, type_code)
select (select id from app.class where code = 'LOPHT02'), (select id from app.branch where code = 'CS1'), 1, current_date + 1, '10:00', '11:30', 'NHAP', 'HOC_BU';
insert into app.session_attendance (session_id, class_id, branch_id, student_id)
select cs.id, cs.class_id, cs.branch_id, (select id from app.student where code = 'HS992002') from app.class_session cs where cs.type_code = 'HOC_BU';

-- ---------- Bài giao (chụp em được giao): B1 còn hạn, B2 quá hạn nhận muộn, B3 quá hạn không nhận, B4 đã nộp, B5 đã chấm, B6 đã gỡ, B7 giao em khác ----------
insert into app.lms_assignment (class_id, session_id, branch_id, title, description, due_at, allow_resubmit, allow_late, audience, status)
select cs.class_id, cs.id, cs.branch_id, v.title, 'Mô tả ' || v.title, now() + v.due, v.resub, v.late, 'CHON_EM', v.st
  from (values ('B1', interval '2 days', true, false, 'DANG_GIAO'), ('B2', interval '-1 day', true, true, 'DANG_GIAO'),
               ('B3', interval '-1 day', true, false, 'DANG_GIAO'), ('B4', interval '1 day', false, false, 'DANG_GIAO'),
               ('B5', interval '1 day', true, false, 'DANG_GIAO'), ('B6', interval '1 day', true, false, 'DA_GO'),
               ('B7', interval '1 day', true, false, 'DANG_GIAO')) as v (title, due, resub, late, st)
  cross join lateral (select * from app.class_session where session_no = 1 and class_id = (select id from app.class where code = 'LOPHT01') limit 1) cs;
insert into app.lms_assignment_target (assignment_id, student_id)
select a.id, st.id from app.lms_assignment a, app.student st
 where st.code = 'HS992001' and a.title in ('B1', 'B2', 'B3', 'B4', 'B5', 'B6')
    or st.code = 'HS992003' and a.title = 'B7';
-- B4 đã nộp chưa chấm; B5 đã nộp và đã chấm 4 điểm.
insert into app.lms_submission (assignment_id, student_id, attempt_count, submitted_at, graded_at)
select a.id, (select id from app.student where code = 'HS992001'), 1, now() - interval '1 hour', case a.title when 'B5' then now() end
  from app.lms_assignment a where a.title in ('B4', 'B5');
insert into app.homework_result (session_id, branch_id, student_id, status_code, score, note)
select a.session_id, a.branch_id, (select id from app.student where code = 'HS992001'), 'DA_CHAM', 4, 'Làm tốt'
  from app.lms_assignment a where a.title = 'B5';
create function pg_temp.aid(p_title text) returns uuid language plpgsql security definer as $$ begin return (select id from app.lms_assignment where title = p_title); end $$;
grant execute on function pg_temp.aid(text) to public;

-- ===== Luật: ba nhóm bài tập =====
select pg_temp.claims(pg_temp.uid('hs1'));
set local role authenticated;
select is(app.portal_assignments(pg_temp.sid('HS992001'), 'CAN_LAM') -> 'counts', '{"CAN_LAM": 3, "DA_NOP": 1, "DA_CHAM": 1}'::jsonb, 'Luật nhóm: 3 bài cần làm (kể cả quá hạn), 1 đã nộp, 1 đã chấm; bài gỡ và bài em khác không tính');
select is((app.portal_assignments(pg_temp.sid('HS992001'), 'CAN_LAM') ->> 'total')::int, 3, 'Cần làm: tổng 3');
select is(app.portal_assignments(pg_temp.sid('HS992001'), 'CAN_LAM') -> 'rows' -> 0 ->> 'title', 'B2', 'Cần làm: hạn gần nhất (quá hạn) lên đầu');
select is((app.portal_assignments(pg_temp.sid('HS992001'), 'CAN_LAM') -> 'rows' -> 0 ->> 'is_overdue')::boolean, true, 'Cần làm: bài quá hạn đánh dấu is_overdue');
select is(app.portal_assignments(pg_temp.sid('HS992001'), 'DA_NOP') -> 'rows' -> 0 ->> 'title', 'B4', 'Nhóm Đã nộp: B4');
select is((app.portal_assignments(pg_temp.sid('HS992001'), 'DA_CHAM') -> 'rows' -> 0 ->> 'score')::int, 4, 'Nhóm Đã chấm: có điểm');
select is(app.portal_assignments(pg_temp.sid('HS992001'), 'DA_NOP') -> 'rows' -> 0 -> 'score', 'null'::jsonb, 'Luật lộ điểm: Đã nộp chưa chấm không lộ điểm trong danh sách, không lẫn điểm bài khác cùng buổi');
select is(app.portal_assignments(pg_temp.sid('HS992001'), 'DA_NOP') -> 'rows' -> 0 -> 'grade_status_code', 'null'::jsonb, 'Luật lộ điểm: Đã nộp chưa chấm không lộ trạng thái chấm');
select is(jsonb_array_length(app.portal_assignments(pg_temp.sid('HS992001'), 'CAN_LAM', 1, 0) -> 'rows'), 1, 'Phân trang ở máy chủ: một dòng một trang');
select is(pg_temp.err($$select app.portal_assignments(pg_temp.sid('HS992001'), 'KHAC')$$), 'HMT_THAM_SO_SAI', 'Nhóm không hợp lệ bị chặn');
select is(pg_temp.err($$select app.portal_assignments(pg_temp.sid('HS992003'), 'CAN_LAM')$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: xem bài tập học sinh khác bị chặn');

-- ===== Luật: chi tiết bài (R-LMS-02, R-LMS-03) =====
select is(app.portal_assignment(pg_temp.sid('HS992001'), pg_temp.aid('B1')) ->> 'window_state', 'CON_HAN', 'Chi tiết: còn hạn');
select is((app.portal_assignment(pg_temp.sid('HS992001'), pg_temp.aid('B1')) ->> 'can_submit')::boolean, true, 'Còn hạn: nộp được');
select is(app.portal_assignment(pg_temp.sid('HS992001'), pg_temp.aid('B2')) ->> 'window_state', 'QUA_HAN_NHAN_MUON', 'R-LMS-02: quá hạn, bật nhận muộn');
select is((app.portal_assignment(pg_temp.sid('HS992001'), pg_temp.aid('B2')) ->> 'can_submit')::boolean, true, 'R-LMS-02: quá hạn nhận muộn vẫn nộp được');
select is(app.portal_assignment(pg_temp.sid('HS992001'), pg_temp.aid('B3')) ->> 'window_state', 'QUA_HAN_KHONG_NHAN', 'R-LMS-02: quá hạn, tắt nhận muộn');
select is((app.portal_assignment(pg_temp.sid('HS992001'), pg_temp.aid('B3')) ->> 'can_submit')::boolean, false, 'R-LMS-02: quá hạn không nhận thì khoá nút');
select is((app.portal_assignment(pg_temp.sid('HS992001'), pg_temp.aid('B4')) ->> 'can_submit')::boolean, false, 'R-LMS-03: đã nộp, tắt cho nộp lại thì không nộp lại được');
select is((app.portal_assignment(pg_temp.sid('HS992001'), pg_temp.aid('B5')) ->> 'can_submit')::boolean, false, 'R-LMS-03: chấm rồi thì khoá');
select is(app.portal_assignment(pg_temp.sid('HS992001'), pg_temp.aid('B5')) -> 'result' ->> 'note', 'Làm tốt', 'HT-05: sau khi chấm thấy nhận xét và điểm');
select is(app.portal_assignment(pg_temp.sid('HS992001'), pg_temp.aid('B1')) -> 'result', 'null'::jsonb, 'Chưa chấm thì không có kết quả');
select is(pg_temp.err($$select app.portal_assignment(pg_temp.sid('HS992001'), pg_temp.aid('B6'))$$), 'HMT_KHONG_CO_QUYEN', 'Bài đã gỡ không xem được');
select is(pg_temp.err($$select app.portal_assignment(pg_temp.sid('HS992001'), pg_temp.aid('B7'))$$), 'HMT_KHONG_CO_QUYEN', 'Bài giao cho em khác không xem được dù biết mã');
reset role;

-- ===== Phụ huynh xem bài của con; nhân viên bị chặn =====
select pg_temp.claims(pg_temp.uid('ph1'));
set local role authenticated;
select is((app.portal_assignments(pg_temp.sid('HS992001'), 'DA_CHAM') ->> 'total')::int, 1, 'Phụ huynh xem được bài đã chấm của con');
select is(pg_temp.err($$select app.portal_assignments(pg_temp.sid('HS992003'), 'CAN_LAM')$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: phụ huynh xem bài con nhà khác bị chặn');
reset role;
select pg_temp.claims(pg_temp.uid('nv'));
set local role authenticated;
select is(pg_temp.err($$select app.portal_assignments(pg_temp.sid('HS992001'), 'CAN_LAM')$$), 'HMT_KHONG_CO_QUYEN', 'Nhân viên gọi hàm bài tập cổng bị chặn');
reset role;

select * from finish();
rollback;
