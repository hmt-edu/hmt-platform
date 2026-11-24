-- F-23-49, migration 665: kiểm quyền tải lên và xem tệp (file_authorize_upload, file_authorize_view). Dữ liệu giả.
-- Luật: học sinh nộp bài của CHÍNH MÌNH (phụ huynh không nộp thay, em khác bị chặn, bài không giao cho em bị chặn); R-LMS-02 quá hạn; R-LMS-03 nộp lại;
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

insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@f2349.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, parent_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@f2349.hoamatoan.invalid', (select id from app.branch where code = 'CS1'),
       case u.key when 'hs1' then 'HS993001' when 'hs2' then 'HS993002' end, case u.key when 'ph1' then 'PH993001' end, false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('hs1', 'STUDENT'), ('hs2', 'STUDENT'), ('ph1', 'PARENT'), ('gv1', 'TEACHER'), ('gv2', 'TEACHER'), ('bm1', 'BRANCH_MANAGER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
insert into app.feature_flag (module_code, branch_id, enabled)
select m, b.id, true from app.branch b, (values ('VAN_HANH_LOP'), ('HOC_TAP')) as x (m) where b.code = 'CS1'
on conflict (module_code, branch_id) do update set enabled = true;
insert into app.parent (code, full_name, phone, branch_id) values ('PH993001', 'Phụ huynh giả F2349', '0993100001', pg_temp.cs('CS1')), ('PH993002', 'Phụ huynh giả F2349 b', '0993100002', pg_temp.cs('CS1'));
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = c.ph), c.name, 2012, pg_temp.cs('CS1')
  from (values ('HS993001', 'PH993001', 'Em giả F2349 một'), ('HS993002', 'PH993002', 'Em giả F2349 hai'), ('HS993003', 'PH993001', 'Em giả F2349 ba')) as c (code, ph, name);

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

-- ===== Tải lên: học sinh nộp bài =====
select pg_temp.claims(pg_temp.uid('hs1'));
select is(pg_temp.err($$select app.file_authorize_upload('BAI_NOP', pg_temp.a('A1'), pg_temp.sid('HS993001'))$$), null, 'Đúng: học sinh nộp bài của chính mình');
select is((app.file_authorize_upload('BAI_NOP', pg_temp.a('A1'), pg_temp.sid('HS993001')) ->> 'is_color')::boolean, false, 'Ảnh học sinh thang xám (không giữ màu)');
select is(pg_temp.nsub('A1'), 1, 'Tạo bài nộp nháp một lần dù gọi hai lần, không nhân đôi');
select is((app.file_authorize_upload('BAI_NOP', pg_temp.a('A1'), pg_temp.sid('HS993001')) -> 'limits' ->> 'max_count')::int, 10, 'Giới hạn đọc từ tham số: 10 tệp mỗi lần');
select is((app.file_authorize_upload('BAI_NOP', pg_temp.a('A1'), pg_temp.sid('HS993001')) -> 'limits' ->> 'max_bytes')::bigint, 20::bigint * 1048576, 'Giới hạn đọc từ tham số: 20 MB mỗi tệp');
select is((app.file_authorize_upload('BAI_NOP', pg_temp.a('A1'), pg_temp.sid('HS993001')) ->> 'delete_after')::date, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 60, 'Hạn giữ chụp lúc tải: 60 ngày (tham số), tính theo ngày Việt Nam');
select is(pg_temp.err($$select app.file_authorize_upload('BAI_NOP', pg_temp.a('A1'), pg_temp.sid('HS993002'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: học sinh nộp thay em khác bị chặn');
select is(pg_temp.err($$select app.file_authorize_upload('BAI_NOP', pg_temp.a('A4'), pg_temp.sid('HS993001'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật: bài không giao cho em này thì bị chặn');
select is(pg_temp.err($$select app.file_authorize_upload('BAI_NOP', pg_temp.a('A2'), pg_temp.sid('HS993001'))$$), 'HMT_LMS_QUA_HAN', 'R-LMS-02: quá hạn và bài không nhận muộn thì bị chặn');
select is(pg_temp.err($$select app.file_authorize_upload('BAI_NOP', pg_temp.a('A3'), pg_temp.sid('HS993001'))$$), 'HMT_LMS_KHONG_NOP_LAI', 'R-LMS-03: đã nộp mà bài không cho nộp lại thì bị chặn');
select is(pg_temp.err($$select app.file_authorize_upload('BAI_NOP', pg_temp.a('A5'), pg_temp.sid('HS993001'))$$), 'HMT_LMS_BAI_DA_GO', 'Bài đã gỡ thì không nộp được');
select is(pg_temp.err($$select app.file_authorize_upload('KHAC', pg_temp.a('A1'), pg_temp.sid('HS993001'))$$), 'HMT_TEP_LOAI_SAI', 'Loại tệp ngoài BAI_NOP, DINH_KEM_GV bị chặn');
select is(pg_temp.err($$select app.file_authorize_upload('DINH_KEM_GV', pg_temp.a('A1'))$$), 'HMT_KHONG_CO_QUYEN', 'Học sinh đính kèm tệp đề (việc của giáo viên) bị chặn');
select pg_temp.claims(pg_temp.uid('ph1'));
select is(pg_temp.err($$select app.file_authorize_upload('BAI_NOP', pg_temp.a('A1'), pg_temp.sid('HS993001'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật: phụ huynh xem được nhưng KHÔNG nộp thay con');

-- ===== Tải lên: giáo viên đính kèm =====
select pg_temp.claims(pg_temp.uid('gv1'));
select is(pg_temp.err($$select app.file_authorize_upload('DINH_KEM_GV', pg_temp.a('A1'))$$), null, 'Đúng: giáo viên của buổi giao đính kèm tệp đề');
select is((app.file_authorize_upload('DINH_KEM_GV', pg_temp.a('A1')) ->> 'is_color')::boolean, true, 'Ảnh giáo viên đính kèm giữ màu');
select pg_temp.claims(pg_temp.uid('gv2'));
select is(pg_temp.err($$select app.file_authorize_upload('DINH_KEM_GV', pg_temp.a('A1'))$$) is not null, true, 'Luật: giáo viên khác (không dạy buổi này) bị chặn');
select pg_temp.claims(pg_temp.uid('hs1'));
select pg_temp.sudo($$update app.feature_flag set enabled = false where module_code = 'HOC_TAP' and branch_id = pg_temp.cs('CS1')$$);
select is(pg_temp.err($$select app.file_authorize_upload('BAI_NOP', pg_temp.a('A1'), pg_temp.sid('HS993001'))$$), 'HMT_TINH_NANG_TAT', 'Công tắc: Học tập tắt ở cơ sở thì không nộp được');
select pg_temp.sudo($$update app.feature_flag set enabled = true where module_code = 'HOC_TAP' and branch_id = pg_temp.cs('CS1')$$);

-- ===== Xem tệp =====
select pg_temp.sudo($$insert into app.stored_file (storage_key, thumb_storage_key, sha256, kind, branch_id, class_id, assignment_id, student_id, mime_type, size_bytes, delete_after, status)
  select 'drive-' || v.k, 'thumb-' || v.k, repeat(v.h, 64), v.kind, pg_temp.cs('CS1'), (select id from cl), pg_temp.a('A1'),
         case v.kind when 'BAI_NOP' then pg_temp.sid('HS993001') end, 'image/webp', 150000, current_date + 90, v.st
    from (values ('anh1', 'a', 'BAI_NOP', 'DANG_DUNG'), ('dm', 'b', 'DINH_KEM_GV', 'DANG_DUNG'), ('xoa', 'c', 'BAI_NOP', 'DA_XOA'), ('dang_tai', 'd', 'BAI_NOP', 'CHO_TAI')) as v (k, h, kind, st)$$);
grant execute on all functions in schema pg_temp to public;
select pg_temp.claims(pg_temp.uid('hs1'));
select is(app.file_authorize_view(pg_temp.f('anh1')) ->> 'storage_key', 'drive-anh1', 'Đúng: học sinh chủ ảnh xem ảnh của mình');
select pg_temp.claims(pg_temp.uid('ph1'));
select is(app.file_authorize_view(pg_temp.f('anh1')) ->> 'storage_key', 'drive-anh1', 'Đúng: phụ huynh xem ảnh của con');
select is(app.file_authorize_view(pg_temp.f('dm')) ->> 'storage_key', 'drive-dm', 'Đúng: phụ huynh xem tệp đề của bài giao cho con');
select pg_temp.claims(pg_temp.uid('hs2'));
select is(pg_temp.err($$select app.file_authorize_view(pg_temp.f('anh1'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: học sinh khác không xem ảnh của em');
select is(pg_temp.err($$select app.file_authorize_view(pg_temp.f('dm'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật: em không được giao bài không xem tệp đề');
select is(pg_temp.err($$select app.file_authorize_view(gen_random_uuid())$$), 'HMT_KHONG_CO_QUYEN', 'Tệp không tồn tại báo cùng lỗi, không lộ');
select pg_temp.claims(pg_temp.uid('gv1'));
select is(app.file_authorize_view(pg_temp.f('anh1')) ->> 'thumb_storage_key', 'thumb-anh1', 'Đúng: giáo viên của lớp xem ảnh bài nộp, nhận cả khoá ảnh thu nhỏ');
select pg_temp.claims(pg_temp.uid('gv2'));
select is(pg_temp.err($$select app.file_authorize_view(pg_temp.f('anh1'))$$), 'HMT_KHONG_CO_QUYEN', 'Luật: giáo viên không dạy lớp này không xem được');
select pg_temp.claims(pg_temp.uid('hs1'));
select is(pg_temp.err($$select app.file_authorize_view(pg_temp.f('xoa'))$$), 'HMT_TEP_DA_DON', 'Tệp đã dọn: báo «Ảnh đã được dọn theo quy định lưu trữ»');
select is(pg_temp.err($$select app.file_authorize_view(pg_temp.f('dang_tai'))$$), 'HMT_KHONG_TIM_THAY', 'Tệp chưa tải xong chưa xem được');
select * from finish();
rollback;
