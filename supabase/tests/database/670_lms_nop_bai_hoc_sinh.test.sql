-- F-24-05 PR-1, migration 670: hàm nộp bài của học sinh (app.lms_submit_assignment). Luật: R-LMS-02 (quá hạn, nộp muộn là nhãn), R-LMS-03 (nộp lại, đã chấm thì khoá),
-- R-LMS-04 (tối đa 20 trang), chỉ chính học sinh, công tắc HOC_TAP, tệp phải đúng bài nộp, đã tải xong, của em. Dữ liệu giả.
-- giáo viên của buổi đính kèm, giáo viên khác bị chặn; công tắc HOC_TAP; xem: nhân viên theo quyền bài giao, học sinh chủ ảnh, phụ huynh của em, người ngoài bị chặn; tệp đã dọn.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('hs1'), ('hs2'), ('ph1'), ('gv1'), ('gv2'), ('bm1');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.sid(p_code text) returns uuid language sql stable security definer as $$ select id from app.student where code = p_code $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
grant execute on all functions in schema pg_temp to public;

insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@f2450.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, parent_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@f2450.hoamatoan.invalid', (select id from app.branch where code = 'CS1'),
       case u.key when 'hs1' then 'HS994001' when 'hs2' then 'HS994002' end, case u.key when 'ph1' then 'PH994001' end, false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('hs1', 'STUDENT'), ('hs2', 'STUDENT'), ('ph1', 'PARENT'), ('gv1', 'TEACHER'), ('gv2', 'TEACHER'), ('bm1', 'BRANCH_MANAGER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
insert into app.feature_flag (module_code, branch_id, enabled)
select m, b.id, true from app.branch b, (values ('VAN_HANH_LOP'), ('HOC_TAP')) as x (m) where b.code = 'CS1'
on conflict (module_code, branch_id) do update set enabled = true;
insert into app.parent (code, full_name, phone, branch_id) values ('PH994001', 'Phụ huynh giả F2450', '0993100001', pg_temp.cs('CS1')), ('PH994002', 'Phụ huynh giả F2450 b', '0993100002', pg_temp.cs('CS1'));
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = c.ph), c.name, 2012, pg_temp.cs('CS1')
  from (values ('HS994001', 'PH994001', 'Em giả F2450 một'), ('HS994002', 'PH994002', 'Em giả F2450 hai'), ('HS994003', 'PH994001', 'Em giả F2450 ba')) as c (code, ph, name);

create temp table cl (id uuid);
grant all on cl to public;
create function pg_temp.a(p_title text) returns uuid language sql stable security definer as $$ select id from app.lms_assignment where title = p_title and class_id = (select id from cl) $$;
create function pg_temp.nsub(p_title text) returns integer language sql stable security definer as $$ select count(*)::int from app.lms_submission s join app.lms_assignment a on a.id = s.assignment_id where a.title = p_title and s.student_id = (select id from app.student where code = 'HS994001') $$;
create function pg_temp.f(p_k text) returns uuid language sql stable security definer as $$ select id from app.stored_file where storage_key = 'drive-' || p_k $$;
grant execute on all functions in schema pg_temp to public;
-- Lớp và buổi do gv1 dạy (cùng cách dựng của bài 597).
select pg_temp.claims(pg_temp.uid('bm1'));
set local role authenticated;
create function pg_temp.mkclass() returns void language plpgsql as $$
declare v jsonb; v_first date := (date_trunc('week', current_date) + interval '14 days')::date;
begin
  v := app.create_class(jsonb_build_object('branch_id', pg_temp.cs('CS1'), 'year_code', '2627', 'subject_code', 'TOAN', 'grade_code', 'K08',
    'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0, 'start_date', v_first, 'total_sessions', 3,
    'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
                                                  'first_date', v_first, 'teacher_id', pg_temp.uid('gv1')))));
  insert into cl values ((v ->> 'id')::uuid);
  perform app.transition_class((v ->> 'id')::uuid, 'DA_TRINH');
  perform app.transition_class((v ->> 'id')::uuid, 'DA_XAC_NHAN');
  perform app.transition_class((v ->> 'id')::uuid, 'DA_DUYET');
end $$;
grant execute on all functions in schema pg_temp to public;
select pg_temp.mkclass();
-- Một buổi của lớp do gv1 dạy (buổi sinh khi có ghi danh; ở đây dựng thẳng cho bài giao).
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, teacher_id)
  select cl.id, pg_temp.cs('CS1'), (date_trunc('week', current_date) + interval '14 days')::date, '18:00', '19:30', pg_temp.uid('gv1') from cl$$);

-- Bài giao: A1 giao cho em 1 (còn hạn, nộp lại được); A2 quá hạn không nhận muộn; A3 không cho nộp lại, em 1 đã nộp; A4 giao cho em 3 (không phải em 1); A5 đã gỡ.
select pg_temp.sudo($$insert into app.lms_assignment (class_id, session_id, branch_id, title, description, due_at, audience, allow_resubmit, allow_late, status)
  select cl.id, (select id from app.class_session where class_id = cl.id order by session_no limit 1), pg_temp.cs('CS1'), v.t, 'Mô tả', v.due, 'CHON_EM', v.re, false, v.st
    from cl, (values ('A1', now() + interval '3 days', true, 'DANG_GIAO'), ('A2', now() - interval '1 day', true, 'DANG_GIAO'),
                     ('A3', now() + interval '3 days', false, 'DANG_GIAO'), ('A4', now() + interval '3 days', true, 'DANG_GIAO'),
                     ('A5', now() + interval '3 days', true, 'DA_GO')) as v (t, due, re, st)$$);
select pg_temp.sudo($$insert into app.lms_assignment_target (assignment_id, student_id)
  select a.id, pg_temp.sid(case a.title when 'A4' then 'HS994003' else 'HS994001' end) from app.lms_assignment a where a.class_id = (select id from cl)$$);
select pg_temp.sudo($$insert into app.lms_submission (assignment_id, student_id, attempt_count, submitted_at)
  select a.id, pg_temp.sid('HS994001'), 1, now() from app.lms_assignment a where a.title = 'A3'$$);
grant execute on all functions in schema pg_temp to public;


-- Bài giao thêm: A6 quá hạn nhưng nhận bài muộn; A7 đã chấm. Bài nộp nháp và tệp giả cho từng bài (dựng bằng quyền chủ).
select pg_temp.sudo($$insert into app.lms_assignment (class_id, session_id, branch_id, title, description, due_at, audience, allow_resubmit, allow_late, status)
  select cl.id, (select id from app.class_session where class_id = cl.id order by session_no limit 1), pg_temp.cs('CS1'), v.t, 'Mô tả', v.due, 'CHON_EM', true, v.late, 'DANG_GIAO'
    from cl, (values ('A6', now() - interval '1 day', true), ('A7', now() + interval '3 days', false)) as v (t, due, late)$$);
select pg_temp.sudo($$insert into app.lms_assignment_target (assignment_id, student_id)
  select a.id, pg_temp.sid('HS994001') from app.lms_assignment a where a.class_id = (select id from cl) and a.title in ('A6', 'A7')$$);
select pg_temp.sudo($$insert into app.lms_submission (assignment_id, student_id, graded_at)
  select a.id, pg_temp.sid('HS994001'), case a.title when 'A7' then now() end from app.lms_assignment a where a.class_id = (select id from cl) and a.title in ('A1', 'A6', 'A7')
  on conflict (assignment_id, student_id) do nothing$$);
-- Tệp của em 1: p1..p3 và «cho» (A1), x (A1 nhưng của em 2), l1 (A6), g1 (A7), n1 (A3, bài không cho nộp lại).
select pg_temp.sudo($$insert into app.stored_file (storage_key, sha256, kind, branch_id, class_id, assignment_id, submission_id, student_id, mime_type, size_bytes, delete_after, status)
  select 'drive-' || v.k, repeat(v.h, 64), 'BAI_NOP', pg_temp.cs('CS1'), (select id from cl), pg_temp.a(v.asg),
         (select s.id from app.lms_submission s where s.assignment_id = pg_temp.a(v.asg) and s.student_id = pg_temp.sid('HS994001')),
         pg_temp.sid(case v.k when 'x' then 'HS994002' else 'HS994001' end), 'image/webp', 150000, current_date + 60, v.st
    from (values ('p1', 'a', 'A1', 'DANG_DUNG'), ('p2', 'b', 'A1', 'DANG_DUNG'), ('p3', 'c', 'A1', 'DANG_DUNG'), ('cho', 'd', 'A1', 'CHO_TAI'),
                 ('x', 'e', 'A1', 'DANG_DUNG'), ('l1', 'f', 'A6', 'DANG_DUNG'), ('g1', '1', 'A7', 'DANG_DUNG'), ('n1', '2', 'A3', 'DANG_DUNG')) as v (k, h, asg, st)$$);
grant execute on all functions in schema pg_temp to public;
-- Hàm đọc kết quả tạo bằng quyền chủ (security definer của người dùng thường vẫn chịu RLS).
reset role;
create function pg_temp.pages(p_title text, p_attempt integer) returns text language sql stable security definer as $$
  select string_agg(f.storage_key, ',' order by sf.page_no) from app.lms_submission_file sf join app.stored_file f on f.id = sf.stored_file_id
   where sf.attempt = p_attempt and sf.submission_id = (select s.id from app.lms_submission s where s.assignment_id = pg_temp.a(p_title) and s.student_id = pg_temp.sid('HS994001')) $$;
create function pg_temp.sub(p_title text) returns app.lms_submission language sql stable security definer as $$
  select s from app.lms_submission s where s.assignment_id = pg_temp.a(p_title) and s.student_id = pg_temp.sid('HS994001') $$;
grant execute on all functions in schema pg_temp to public;
set local role authenticated;

-- ===== Nộp bài đúng =====
select pg_temp.claims(pg_temp.uid('hs1'));
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A1'), array[pg_temp.f('p2'), pg_temp.f('p1')])$$), null, 'Đúng: học sinh nộp bài của mình với hai ảnh');
select is((pg_temp.sub('A1')).attempt_count, 1, 'Lần nộp đầu: attempt_count = 1');
select ok((pg_temp.sub('A1')).submitted_at is not null and not (pg_temp.sub('A1')).is_late, 'Nộp đúng hạn: có giờ nộp, không nhãn «Nộp muộn»');
select is(pg_temp.pages('A1', 1), 'drive-p2,drive-p1', 'Số trang theo đúng thứ tự danh sách gửi lên');
-- R-LMS-03: nộp lại không giới hạn trước khi chấm; bộ trang mới, bộ cũ giữ nguyên.
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A1'), array[pg_temp.f('p1'), pg_temp.f('p2'), pg_temp.f('p3')])$$), null, 'R-LMS-03: nộp lại được (bài cho nộp lại, chưa chấm)');
select is((pg_temp.sub('A1')).attempt_count, 2, 'Lần nộp thứ hai: attempt_count = 2');
select is(pg_temp.pages('A1', 2), 'drive-p1,drive-p2,drive-p3', 'Bộ trang lần 2 đủ ba ảnh');
select is(pg_temp.pages('A1', 1), 'drive-p2,drive-p1', 'Bộ trang lần 1 vẫn còn nguyên, không xoá cứng');
-- R-LMS-02: nộp muộn là nhãn.
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A6'), array[pg_temp.f('l1')])$$), null, 'R-LMS-02: quá hạn nhưng bài nhận bài muộn thì nộp được');
select ok((pg_temp.sub('A6')).is_late, 'R-LMS-02: có nhãn «Nộp muộn»');

-- ===== Bị chặn =====
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A2'), array[gen_random_uuid()])$$), 'HMT_LMS_QUA_HAN', 'R-LMS-02: quá hạn và tắt nhận bài muộn thì bị chặn');
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A3'), array[pg_temp.f('n1')])$$), 'HMT_LMS_KHONG_NOP_LAI', 'R-LMS-03: đã nộp, bài không cho nộp lại thì bị chặn');
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A7'), array[pg_temp.f('g1')])$$), 'HMT_LMS_DA_CHAM', 'R-LMS-03: bài đã chấm thì khoá');
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A5'), array[gen_random_uuid()])$$), 'HMT_LMS_BAI_DA_GO', 'Bài đã gỡ thì không nộp được');
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A4'), array[pg_temp.f('p1')])$$), 'HMT_KHONG_CO_QUYEN', 'Luật: bài không giao cho em này thì bị chặn');
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A1'), array[]::uuid[])$$), 'HMT_TEP_THIEU', 'Luật: không có ảnh nào thì không nộp');
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A1'), array(select gen_random_uuid() from generate_series(1, 21)))$$), 'HMT_TEP_QUA_NHIEU', 'R-LMS-04: quá 20 trang bị chặn');
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A1'), array[pg_temp.f('p1'), pg_temp.f('p1')])$$), 'HMT_TEP_KHONG_HOP_LE', 'Luật: ảnh lặp trong danh sách bị chặn');
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A1'), array[pg_temp.f('cho')])$$), 'HMT_TEP_KHONG_HOP_LE', 'Luật: ảnh chưa tải xong (CHO_TAI) không nộp được');
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A1'), array[pg_temp.f('x')])$$), 'HMT_TEP_KHONG_HOP_LE', 'Luật: ảnh của em khác không nộp được');
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A1'), array[pg_temp.f('l1')])$$), 'HMT_TEP_KHONG_HOP_LE', 'Luật: ảnh của bài khác không nộp được');
select is((pg_temp.sub('A1')).attempt_count, 2, 'Lần nộp bị chặn không làm tăng số lần nộp');

-- ===== Người khác, công tắc =====
select pg_temp.claims(pg_temp.uid('hs2'));
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A1'), array[pg_temp.f('p1')])$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: học sinh khác không nộp bài của em');
select pg_temp.claims(pg_temp.uid('ph1'));
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A1'), array[pg_temp.f('p1')])$$), 'HMT_KHONG_CO_QUYEN', 'Luật: phụ huynh không nộp thay con');
select pg_temp.claims(pg_temp.uid('gv1'));
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A1'), array[pg_temp.f('p1')])$$), 'HMT_KHONG_CO_QUYEN', 'Luật: giáo viên không nộp thay học sinh');
select pg_temp.claims(pg_temp.uid('hs1'));
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'HOC_TAP' and branch_id = pg_temp.cs('CS1')$$);
select is(pg_temp.err($$select app.lms_submit_assignment(pg_temp.a('A1'), array[pg_temp.f('p1')])$$), 'HMT_TINH_NANG_TAT', 'Công tắc: Học tập tắt ở cơ sở thì không nộp được');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'HOC_TAP' and branch_id = pg_temp.cs('CS1')$$);
select ok(not has_function_privilege('anon', 'app.lms_submit_assignment(uuid, uuid[])', 'execute'), 'Quyền: khách chưa đăng nhập không gọi được hàm nộp bài');

select * from finish();
rollback;
