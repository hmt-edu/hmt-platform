-- F-23-54, migration 664: ĐỌC sổ tệp stored_file theo từng vai trò (RLS), trong và ngoài phạm vi. Dữ liệu giả.
-- Luật: một chính sách đọc theo quyền xem bài giao (cùng luật bảng LMS 597). Giáo viên dạy lớp và quản lý cơ sở thấy tệp của bài; giáo viên lớp khác,
-- người cơ sở khác thấy 0 dòng; học sinh và phụ huynh KHÔNG đọc trực tiếp bảng (đi qua Edge Function file-view, kiểm bằng hàm ở migration 665): 0 dòng.
-- Ghi: không vai trò nào ghi, sửa, xoá được trực tiếp (chỉ khoá dịch vụ của Edge Function).
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
insert into u (key) values ('hs1'), ('hs2'), ('ph1'), ('gv1'), ('gv2'), ('bm1'), ('gv3'), ('bm2');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.sid(p_code text) returns uuid language sql stable security definer as $$ select id from app.student where code = p_code $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
grant execute on all functions in schema pg_temp to public;

insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@f664.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, parent_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@f664.hoamatoan.invalid', (select id from app.branch where code = case when u.key in ('gv3', 'bm2') then 'CS2' else 'CS1' end),
       case u.key when 'hs1' then 'HS993001' when 'hs2' then 'HS993002' end, case u.key when 'ph1' then 'PH993001' end, false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('hs1', 'STUDENT'), ('hs2', 'STUDENT'), ('ph1', 'PARENT'), ('gv1', 'TEACHER'), ('gv2', 'TEACHER'), ('bm1', 'BRANCH_MANAGER'), ('gv3', 'TEACHER'), ('bm2', 'BRANCH_MANAGER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
insert into app.feature_flag (module_code, branch_id, enabled)
select m, b.id, true from app.branch b, (values ('VAN_HANH_LOP'), ('HOC_TAP')) as x (m) where b.code = 'CS1'
on conflict (module_code, branch_id) do update set enabled = true;
insert into app.parent (code, full_name, phone, branch_id) values ('PH993001', 'Phụ huynh giả F664', '0993100001', pg_temp.cs('CS1')), ('PH993002', 'Phụ huynh giả F664 b', '0993100002', pg_temp.cs('CS1'));
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = c.ph), c.name, 2012, pg_temp.cs('CS1')
  from (values ('HS993001', 'PH993001', 'Em giả F664 một'), ('HS993002', 'PH993002', 'Em giả F664 hai'), ('HS993003', 'PH993001', 'Em giả F664 ba')) as c (code, ph, name);

create temp table cl (id uuid);
grant all on cl to public;
create function pg_temp.a(p_title text) returns uuid language sql stable security definer as $$ select id from app.lms_assignment where title = p_title and class_id = (select id from cl) $$;
create function pg_temp.nsub(p_title text) returns integer language sql stable security definer as $$ select count(*)::int from app.lms_submission s join app.lms_assignment a on a.id = s.assignment_id where a.title = p_title and s.student_id = (select id from app.student where code = 'HS993001') $$;
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
  select a.id, pg_temp.sid(case a.title when 'A4' then 'HS993003' else 'HS993001' end) from app.lms_assignment a where a.class_id = (select id from cl)$$);
select pg_temp.sudo($$insert into app.lms_submission (assignment_id, student_id, attempt_count, submitted_at)
  select a.id, pg_temp.sid('HS993001'), 1, now() from app.lms_assignment a where a.title = 'A3'$$);
grant execute on all functions in schema pg_temp to public;


-- Tệp mẫu của bài A1 (lớp do gv1 dạy, cơ sở CS1): 2 đang dùng (ảnh học sinh, tệp đề giáo viên) và 1 đã xoá.
select pg_temp.sudo($$insert into app.stored_file (storage_key, thumb_storage_key, sha256, kind, branch_id, class_id, assignment_id, student_id, mime_type, size_bytes, delete_after, status)
  select 'drive-' || v.k, null, repeat(v.h, 64), v.kind, pg_temp.cs('CS1'), (select id from cl), pg_temp.a('A1'),
         case v.kind when 'BAI_NOP' then pg_temp.sid('HS993001') end, 'image/webp', 150000, current_date + 60, v.st
    from (values ('anh1', 'a', 'BAI_NOP', 'DANG_DUNG'), ('dm', 'b', 'DINH_KEM_GV', 'DANG_DUNG'), ('xoa', 'c', 'BAI_NOP', 'DA_XOA')) as v (k, h, kind, st)$$);
create function pg_temp.nfile() returns integer language sql stable as $$ select count(*)::int from app.stored_file $$;
grant execute on all functions in schema pg_temp to public;

-- ===== Đọc theo vai trò =====
select pg_temp.claims(pg_temp.uid('gv1'));
select is(pg_temp.nfile(), 3, 'Đọc trong phạm vi: giáo viên dạy lớp thấy cả 3 dòng tệp của bài mình');
select pg_temp.claims(pg_temp.uid('bm1'));
select is(pg_temp.nfile(), 3, 'Đọc trong phạm vi: quản lý cơ sở CS1 thấy tệp của bài trong cơ sở');
select pg_temp.claims(pg_temp.uid('gv2'));
select is(pg_temp.nfile(), 0, 'Đọc ngoài phạm vi: giáo viên lớp khác (không dạy lớp này) thấy 0 dòng');
select pg_temp.claims(pg_temp.uid('gv3'));
select is(pg_temp.nfile(), 0, 'Đọc ngoài phạm vi: giáo viên cơ sở khác (CS2) thấy 0 dòng');
select pg_temp.claims(pg_temp.uid('bm2'));
select is(pg_temp.nfile(), 0, 'Đọc ngoài phạm vi: quản lý cơ sở khác (CS2) thấy 0 dòng');
select pg_temp.claims(pg_temp.uid('hs1'));
select is(pg_temp.nfile(), 0, 'Học sinh chủ ảnh không đọc trực tiếp bảng: 0 dòng (xem ảnh đi qua file-view)');
select pg_temp.claims(pg_temp.uid('hs2'));
select is(pg_temp.nfile(), 0, 'Học sinh khác không đọc trực tiếp bảng: 0 dòng');
select pg_temp.claims(pg_temp.uid('ph1'));
select is(pg_temp.nfile(), 0, 'Phụ huynh không đọc trực tiếp bảng: 0 dòng (xem ảnh đi qua file-view)');

-- ===== Ghi trực tiếp bị chặn với mọi vai trò đăng nhập =====
select pg_temp.claims(pg_temp.uid('gv1'));
select is(pg_temp.err($$insert into app.stored_file (storage_key, sha256, kind, branch_id, class_id, assignment_id, mime_type, size_bytes, delete_after)
  select 'drive-gian', repeat('e', 64), 'DINH_KEM_GV', pg_temp.cs('CS1'), (select id from cl), pg_temp.a('A1'), 'image/webp', 1, current_date$$), '42501', 'Luật chỉ Edge Function ghi: giáo viên không thêm được dòng');
select is(pg_temp.err($$update app.stored_file set status = 'DA_XOA' where storage_key = 'drive-anh1'$$), '42501', 'Luật chỉ Edge Function ghi: giáo viên không sửa được dòng');
select is(pg_temp.err($$delete from app.stored_file where storage_key = 'drive-anh1'$$), '42501', 'Luật chỉ Edge Function ghi: giáo viên không xoá được dòng');
select pg_temp.claims(pg_temp.uid('hs1'));
select is(pg_temp.err($$update app.stored_file set status = 'DA_XOA' where storage_key = 'drive-anh1'$$), '42501', 'Luật chỉ Edge Function ghi: học sinh không sửa được dòng của chính mình');

select * from finish();
rollback;
