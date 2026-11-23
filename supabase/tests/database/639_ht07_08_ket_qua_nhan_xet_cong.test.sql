-- HT-07 / HT-08 / PH-02: app.portal_results (639) và app.portal_reviews (640). Luật: chuyên cần theo ô giáo viên; BTVN ẩn khi lớp không giao (R-V2-35);
-- điểm ba nhóm theo buổi; nhận xét chỉ em có mặt và lời nhắn không trống (R-GV-04, R-V2-39); quyền riêng theo học sinh/con.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ht78.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, parent_code, is_locked, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ht78.hoamatoan.invalid', (select id from app.branch where code = 'CS1'),
       case u.key when 'hs1' then 'HS993001' when 'hs2' then 'HS993003' when 'hs3' then 'HS993004' end,
       case u.key when 'ph1' then 'PH993001' when 'ph2' then 'PH993002' when 'ph3' then 'PH993003' end,
       u.key = 'ph3', false
  from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('hs1', 'STUDENT'), ('hs2', 'STUDENT'), ('hs3', 'STUDENT'), ('ph1', 'PARENT'), ('ph2', 'PARENT'), ('ph3', 'PARENT'), ('nv', 'SALES')) as v (key, role) on v.key = u.key;

-- ---------- Dữ liệu: HS993001 (hs1) học LOPHT71 có BTVN, LOPHT72 không BTVN; HS993003 (hs2) của phụ huynh khác ----------
insert into app.parent (code, full_name, phone, branch_id)
select c.code, c.name, c.phone, (select id from app.branch where code = 'CS1')
  from (values ('PH993001', 'Phụ huynh Mẫu Ht Bảy', '0993100001'), ('PH993002', 'Phụ huynh Mẫu Ht Tám', '0993100002')) as c (code, name, phone);
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = c.ph), c.name, 2012, (select id from app.branch where code = 'CS1')
  from (values ('HS993001', 'PH993001', 'Em Ht Bảy'), ('HS993003', 'PH993002', 'Em Ht Chín')) as c (code, ph, name);
insert into app.feature_flag (module_code, branch_id, enabled)
select 'HOC_TAP', b.id, true from app.branch b where b.code = 'CS1'
on conflict (module_code, branch_id) do update set enabled = true;
insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
select v.code, b.id, '2627', 'TOAN', 'K08', 'CB', 'A', current_date - 30, 10 from app.branch b, (values ('LOPHT71'), ('LOPHT72')) as v (code) where b.code = 'CS1';
-- Lớp 71: 3 buổi (hôm kia, hôm qua, hôm nay chưa điểm danh); lớp 72: 1 buổi.
insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, status_code, type_code)
select (select id from app.class where code = v.cls), (select id from app.branch where code = 'CS1'), v.no, current_date + v.d, '18:00', '19:30', 'DONE', 'CHINH'
  from (values ('LOPHT71', 1, -2), ('LOPHT71', 2, -1), ('LOPHT71', 3, 0), ('LOPHT72', 1, -1)) as v (cls, no, d);
-- Điểm danh giáo viên: HS993001 có mặt buổi 1, VẮNG buổi 2, chưa điểm danh buổi 3; lớp 72 có mặt. HS993003 có mặt buổi 1 lớp 71.
insert into app.session_attendance (session_id, class_id, branch_id, student_id, teacher_status_code)
select cs.id, cs.class_id, cs.branch_id, st.id, v.status
  from (values ('LOPHT71', 1, 'HS993001', 'CO_MAT'), ('LOPHT71', 2, 'HS993001', 'VANG_KHONG_PHEP'), ('LOPHT71', 3, 'HS993001', null),
               ('LOPHT72', 1, 'HS993001', 'DI_MUON'), ('LOPHT71', 1, 'HS993003', 'CO_MAT')) as v (cls, no, stu, status)
  join app.class c on c.code = v.cls
  join app.class_session cs on cs.class_id = c.id and cs.session_no = v.no
  join app.student st on st.code = v.stu;
-- BTVN: lớp 71 buổi 1 đã chấm 4 điểm; lớp 72 không có dòng nào.
insert into app.homework_result (session_id, branch_id, student_id, status_code, score)
select cs.id, cs.branch_id, st.id, 'DA_CHAM', 4
  from app.class_session cs join app.class c on c.id = cs.class_id and c.code = 'LOPHT71' and cs.session_no = 1, app.student st where st.code = 'HS993001';
-- Điểm ba nhóm buổi 1 lớp 71 của HS993001: Thái độ 4 và 2 (trung bình 3), Tiếp thu 5, Vận dụng chưa có.
insert into app.session_review_criterion (session_id, branch_id, criterion_id, group_code, name, sort_order)
select cs.id, cs.branch_id, rc.id, rc.group_code, rc.name, rc.sort_order
  from app.class_session cs join app.class c on c.id = cs.class_id and c.code = 'LOPHT71' and cs.session_no = 1
  join lateral (select * from app.review_criterion where group_code = 'THAI_DO' order by sort_order limit 2) rc on true;
insert into app.session_review_criterion (session_id, branch_id, criterion_id, group_code, name, sort_order)
select cs.id, cs.branch_id, rc.id, rc.group_code, rc.name, rc.sort_order
  from app.class_session cs join app.class c on c.id = cs.class_id and c.code = 'LOPHT71' and cs.session_no = 1
  join lateral (select * from app.review_criterion where group_code = 'TIEP_THU' order by sort_order limit 1) rc on true;
insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score)
select src.session_id, src.branch_id, src.id, a.id, 'DA_DANH_GIA',
       case when src.group_code = 'TIEP_THU' then 5 when src.sort_order = (select min(sort_order) from app.session_review_criterion where session_id = src.session_id and group_code = 'THAI_DO') then 4 else 2 end
  from app.session_review_criterion src
  join app.session_attendance a on a.session_id = src.session_id
  join app.student st on st.id = a.student_id and st.code = 'HS993001';
-- Nhận xét: buổi 1 lớp 71 có lời nhắn (hiện); buổi 2 em vắng có lời nhắn (KHÔNG hiện); lớp 72 lời nhắn trống (không hiện); HS993003 có lời nhắn riêng.
insert into app.session_student_review (attendance_id, session_id, branch_id, teacher_comment, improvement_note)
select a.id, a.session_id, a.branch_id, v.msg, v.note
  from (values ('LOPHT71', 1, 'HS993001', 'Em tập trung tốt.', 'GHI CHÚ NỘI BỘ'), ('LOPHT71', 2, 'HS993001', 'Nhận xét của buổi vắng.', null),
               ('LOPHT72', 1, 'HS993001', '   ', null), ('LOPHT71', 1, 'HS993003', 'Nhận xét em khác.', null)) as v (cls, no, stu, msg, note)
  join app.class c on c.code = v.cls
  join app.class_session cs on cs.class_id = c.id and cs.session_no = v.no
  join app.student st on st.code = v.stu
  join app.session_attendance a on a.session_id = cs.id and a.student_id = st.id;

-- ===== HT-07: học sinh xem kết quả của mình =====
select pg_temp.claims(pg_temp.uid('hs1'));
set local role authenticated;
select is(jsonb_array_length(app.portal_results(pg_temp.sid('HS993001')) -> 'classes'), 2, 'Kết quả HS: hai lớp có điểm danh giáo viên');
select is(app.portal_results(pg_temp.sid('HS993001')) -> 'classes' -> 0 -> 'attendance', '{"present": 1, "total": 2}'::jsonb, 'Chuyên cần: chỉ tính buổi giáo viên đã điểm danh (1 có mặt / 2), buổi chưa điểm danh không tính');
select is(app.portal_results(pg_temp.sid('HS993001')) -> 'classes' -> 0 -> 'homework' ->> 'has', 'true', 'BTVN: lớp có kết quả BTVN thì hiện');
select is(app.portal_results(pg_temp.sid('HS993001')) -> 'classes' -> 0 -> 'homework' ->> 'avg_score', '4.0', 'BTVN: điểm trung bình các buổi có điểm');
select is(app.portal_results(pg_temp.sid('HS993001')) -> 'classes' -> 1 -> 'homework' ->> 'has', 'false', 'Luật R-V2-35: lớp không giao BTVN thì has = false (ẩn phần BTVN)');
select is(jsonb_array_length(app.portal_results(pg_temp.sid('HS993001')) -> 'classes' -> 0 -> 'sessions'), 1, 'Điểm theo buổi: chỉ buổi em có mặt (buổi vắng không có dòng điểm)');
select is(app.portal_results(pg_temp.sid('HS993001')) -> 'classes' -> 0 -> 'sessions' -> 0 ->> 'thai_do', '3.0', 'Điểm nhóm Thái độ = trung bình các tiêu chí đã đánh giá');
select is(app.portal_results(pg_temp.sid('HS993001')) -> 'classes' -> 0 -> 'sessions' -> 0 ->> 'tiep_thu', '5.0', 'Điểm nhóm Tiếp thu');
select is(app.portal_results(pg_temp.sid('HS993001')) -> 'classes' -> 0 -> 'sessions' -> 0 -> 'van_dung', 'null'::jsonb, 'Nhóm chưa có điểm trả null');
select is(pg_temp.err($$select app.portal_results(pg_temp.sid('HS993003'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: học sinh xem kết quả em khác bị chặn');

-- ===== HT-08: nhận xét =====
select is((app.portal_reviews(pg_temp.sid('HS993001')) ->> 'total')::int, 1, 'Nhận xét: chỉ em có mặt và lời nhắn không trống (vắng và lời nhắn trống không hiện, R-GV-04)');
select is(app.portal_reviews(pg_temp.sid('HS993001')) -> 'rows' -> 0 ->> 'comment', 'Em tập trung tốt.', 'Nhận xét: hiện lời nhắn của giáo viên');
select is(app.portal_reviews(pg_temp.sid('HS993001')) -> 'rows' -> 0 ? 'improvement_note', false, 'Luật R-V2-39: không lộ ghi chú nội bộ');
select is(jsonb_array_length(app.portal_reviews(pg_temp.sid('HS993001'), 1, 5) -> 'rows'), 0, 'Nhận xét: trang vượt quá tổng trả rỗng');
select is(pg_temp.err($$select app.portal_reviews(pg_temp.sid('HS993003'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: học sinh xem nhận xét em khác bị chặn');
reset role;

-- ===== Phụ huynh xem con mình, chặn con nhà khác; nhân viên bị chặn =====
select pg_temp.claims(pg_temp.uid('ph1'));
set local role authenticated;
select is(jsonb_array_length(app.portal_results(pg_temp.sid('HS993001')) -> 'classes'), 2, 'Kết quả PH: xem được kết quả con');
select is((app.portal_reviews(pg_temp.sid('HS993001')) ->> 'total')::int, 1, 'Nhận xét PH: xem được nhận xét con');
select is(pg_temp.err($$select app.portal_results(pg_temp.sid('HS993003'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: phụ huynh xem kết quả con nhà khác bị chặn');
select is(pg_temp.err($$select app.portal_reviews(pg_temp.sid('HS993003'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: phụ huynh xem nhận xét con nhà khác bị chặn');
reset role;
select pg_temp.claims(pg_temp.uid('nv'));
set local role authenticated;
select is(pg_temp.err($$select app.portal_results(pg_temp.sid('HS993001'))$$), 'HMT_KHONG_CO_QUYEN', 'Nhân viên gọi hàm kết quả cổng bị chặn');
select is(pg_temp.err($$select app.portal_reviews(pg_temp.sid('HS993001'))$$), 'HMT_KHONG_CO_QUYEN', 'Nhân viên gọi hàm nhận xét cổng bị chặn');
reset role;

select * from finish();
rollback;
