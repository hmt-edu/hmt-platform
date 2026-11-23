-- A-23-18 / G18 (migration 630): buổi học bù, bổ trợ mang nhãn riêng (session_no null), không chiếm số buổi chính; củng cố vẫn chiếm số. Dữ liệu giả.
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
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('bm5'), ('cskh1'), ('sales1'), ('gv1'), ('gv2');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@a2312.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@a2312.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm5', 'CS5'), ('cskh1', 'CS1'), ('sales1', 'CS1'), ('gv1', 'CS1'), ('gv2', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('cskh1', 'CSKH'),
  ('sales1', 'SALES'), ('gv1', 'TEACHER'), ('gv2', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
-- Q-198: đặt rõ nhánh Bật (không dựa vào mặc định): Done cần nhận xét, điểm.
select pg_temp.sudo($$update app.setting_def set value = 'true' where key = 'session_done_requires_review'$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
-- Thứ Hai 4 tuần trước (buổi quá khứ để Done được) và thứ Hai 2 tuần sau (buổi tương lai).
create function pg_temp.past() returns date language sql stable as $$ select (date_trunc('week', current_date) - interval '28 days')::date $$;
create function pg_temp.fut() returns date language sql stable as $$ select (date_trunc('week', current_date) + interval '14 days')::date $$;
create temp table cl (key text primary key, id uuid);
grant all on cl to public;
create function pg_temp.c(p_key text) returns uuid language sql stable as $$ select id from cl where key = p_key $$;
create function pg_temp.mkclass(p_key text, p_type text, p_first date, p_total integer, p_teacher text default 'gv1') returns void language plpgsql as $$
declare v jsonb;
begin
  v := app.create_class(jsonb_build_object('branch_id', pg_temp.cs('CS1'), 'year_code', '2627', 'subject_code', 'TOAN', 'grade_code', 'K08',
    'class_type_code', p_type, 'level_code', case when p_type = 'LR' then null else 'A' end, 'max_students', 0, 'start_date', p_first,
    'total_sessions', p_total,
    'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
                                                  'first_date', p_first, 'teacher_id', pg_temp.uid(p_teacher)))));
  insert into cl values (p_key, (v ->> 'id')::uuid);
  perform app.transition_class((v ->> 'id')::uuid, 'DA_TRINH');
  perform app.transition_class((v ->> 'id')::uuid, 'DA_XAC_NHAN');
  perform app.transition_class((v ->> 'id')::uuid, 'DA_DUYET');
end $$;
-- Buổi thứ n (theo ngày) của lớp.
create function pg_temp.s(p_key text, p_n integer) returns uuid language sql stable security definer as $$
  select id from app.class_session where class_id = pg_temp.c(p_key) and session_no = p_n and status_code not in ('HUY_KHONG_PHI', 'DA_THAY') $$;
create temp table en (key text primary key, id uuid);
grant all on en to public;
create function pg_temp.e(p_key text) returns uuid language sql stable as $$ select id from en where key = p_key $$;
create function pg_temp.st(p_n integer) returns uuid language sql stable security definer as $$ select id from app.student where code = 'HSA230' || p_n $$;
-- Ghi danh giả; p_old = true thì lùi ngày tạo 60 ngày (tắt tạm trigger điền cột chuẩn) để vào được danh sách buổi quá khứ (R-GIO-02).
create function pg_temp.mke(p_key text, p_n integer, p_old boolean, p_hours numeric) returns void language plpgsql security definer as $$
declare v_id uuid;
begin
  insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code)
  values ('GDA' || p_key, pg_temp.st(p_n), (select parent_id from app.student where id = pg_temp.st(p_n)), pg_temp.cs('CS1'), 'TOAN')
  returning id into v_id;
  if p_old then
    alter table app.enrollment disable trigger enrollment_fill_standard;
    update app.enrollment set created_at = now() - interval '60 days' where id = v_id;
    alter table app.enrollment enable trigger enrollment_fill_standard;
  end if;
  insert into en values (p_key, v_id);
  if p_hours <> 0 then
    perform app.add_opening_hours(v_id, p_hours, 'DOT-A230');
  end if;
end $$;
grant execute on all functions in schema pg_temp to public;

create function pg_temp.req(p_key text) returns uuid language sql stable security definer as $$ select id from app.session_request where coalesce(reason, note) = p_key $$;
grant execute on function pg_temp.req(text) to public;
-- Từ đây chạy với vai trò đăng nhập thật (RLS và quyền gọi hàm có hiệu lực).


-- Ba em giả (cần hồ sơ học sinh), hai em xếp vào lớp tương lai đã duyệt 'f' (giáo viên gv1).

-- D2 (migration 103): Done cần nhận xét 9 tiêu chí. Hàm giả này chụp tiêu chí, chấm mức 3 cho mọi em có mặt và thêm một dòng nội dung buổi (Q-231), để các bài D1c thử Done và trừ giờ.
create function pg_temp.fillreview(p_session uuid) returns void language plpgsql security definer as $$
begin
  insert into app.session_review_criterion (session_id, branch_id, criterion_id, group_code, name, sort_order)
  select s.id, s.branch_id, rc.id, rc.group_code, rc.name, rc.sort_order
    from app.class_session s join app.class c on c.id = s.class_id
    join lateral app.review_criteria_for_subject(c.subject_code) rc on true
   where s.id = p_session
  on conflict do nothing;
  insert into app.session_review_score (session_id, branch_id, session_criterion_id, attendance_id, state, score)
  select sa.session_id, sa.branch_id, rc.id, sa.id, 'DA_DANH_GIA', 3
    from app.session_attendance sa join app.session_review_criterion rc on rc.session_id = sa.session_id
   where sa.session_id = p_session and sa.is_active and sa.teacher_status_code in ('CO_MAT', 'DI_MUON')
  on conflict do nothing;
  -- GV (migration 107, Q-231): buổi thường cần ít nhất một dòng nội dung buổi mới Done được.
  insert into app.session_content_line (session_id, branch_id, sort_order, line_text)
  select s.id, s.branch_id, 1, 'Nội dung buổi giả' from app.class_session s where s.id = p_session
  on conflict do nothing;
end $$;
grant execute on all functions in schema pg_temp to public;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('g', 'CB', pg_temp.past(), 4);
select is((select array_agg(session_no order by session_date) from app.class_session where class_id = pg_temp.c('g')), array[1, 2, 3, 4], 'Lớp mới: bốn buổi chính đánh số 1 đến 4');

-- Học bù chen giữa buổi 1 và 2: không đẩy số buổi chính, tự mang số rỗng.
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, type_code, status_code, is_manual)
  select c.id, c.branch_id, pg_temp.past() + 3, '10:00', '11:00', 'HOC_BU', 'NHAP', true from app.class c where c.id = pg_temp.c('g')$$);
select pg_temp.sudo($$select app.renumber_class_sessions(pg_temp.c('g'))$$);
select is((select array_agg(session_no order by session_date) from app.class_session where class_id = pg_temp.c('g') and type_code not in ('HOC_BU', 'BO_TRO')), array[1, 2, 3, 4], 'G18: có buổi học bù chen giữa, các buổi chính vẫn Buổi 1 đến 4');
select is((select session_no from app.class_session where class_id = pg_temp.c('g') and type_code = 'HOC_BU'), null, 'G18: buổi học bù không có số (nhãn riêng)');

-- Bổ trợ cũng không chiếm số.
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, type_code, status_code, is_manual)
  select c.id, c.branch_id, pg_temp.past() + 10, '10:00', '11:00', 'BO_TRO', 'NHAP', true from app.class c where c.id = pg_temp.c('g')$$);
select pg_temp.sudo($$select app.renumber_class_sessions(pg_temp.c('g'))$$);
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('g') and session_no is null), 2, 'G18: học bù và bổ trợ đều không có số');
select is((select max(session_no) from app.class_session where class_id = pg_temp.c('g')), 4, 'G18: số buổi lớn nhất vẫn là 4');

-- Củng cố vẫn chiếm số (R-BUOI-04): chen giữa thì buổi sau dịch.
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, type_code, status_code, is_manual)
  select c.id, c.branch_id, pg_temp.past() + 4, '12:00', '13:00', 'CUNG_CO', 'NHAP', true from app.class c where c.id = pg_temp.c('g')$$);
select pg_temp.sudo($$select app.renumber_class_sessions(pg_temp.c('g'))$$);
select is((select max(session_no) from app.class_session where class_id = pg_temp.c('g')), 5, 'Củng cố vẫn chiếm số buổi (R-BUOI-04): lớp có 5 buổi được đánh số');

-- Chạy lại không đổi (idempotent).
select pg_temp.sudo($$select app.renumber_class_sessions(pg_temp.c('g'))$$);
select is((select max(session_no) from app.class_session where class_id = pg_temp.c('g')), 5, 'Đánh số lại lần hai không đổi');

-- Huỷ trung tâm: số buổi thêm cuối lịch chỉ đếm buổi chính (4 buổi chính + 1 củng cố, huỷ một buổi chính thì còn 4 sống + 1 = 5).
select is((app.session_cancel_preview(pg_temp.s('g', 2)) ->> 'added_session_no')::int, 5, 'G18: buổi thêm cuối lịch có số theo buổi chính (không đếm buổi bù, bổ trợ)');
select is(app.session_type_numbered('HOC_BU'), false, 'session_type_numbered: học bù không đánh số');
select is(app.session_type_numbered('BO_TRO'), false, 'session_type_numbered: bổ trợ không đánh số');
select is(app.session_type_numbered('CHINH'), true, 'session_type_numbered: buổi chính đánh số');

-- Lỗi tester2 17:32: generate_class_sessions đếm cả buổi học bù vào số buổi giữ lại nên sinh thiếu buổi chính (R-LOP-10, A-23-18).
select pg_temp.mkclass('h', 'CB', pg_temp.past(), 4);
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, type_code, status_code, is_manual)
  select c.id, c.branch_id, pg_temp.past() + 3, '10:00', '11:00', 'HOC_BU', 'NHAP', true from app.class c where c.id = pg_temp.c('h')$$);
select pg_temp.sudo($$update app.class_session set status_code = 'DA_THAY' where class_id = pg_temp.c('h') and type_code <> 'HOC_BU'$$);
select pg_temp.sudo($$select app.generate_class_sessions(pg_temp.c('h'), pg_temp.past())$$);
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('h') and type_code not in ('HOC_BU', 'BO_TRO') and status_code = 'NHAP'), 4,
  'G18: đổi lịch khi có học bù chen giữa, sinh lại đủ 4 buổi chính (học bù không chiếm số buổi giữ lại)');
select is((select array_agg(session_no order by session_date) from app.class_session where class_id = pg_temp.c('h') and type_code not in ('HOC_BU', 'BO_TRO') and status_code = 'NHAP'),
  array[1, 2, 3, 4], 'G18: sau khi sinh lại, buổi chính đánh số 1 đến 4');
select is((select expected_end_date from app.class where id = pg_temp.c('h')),
  (select max(session_date) from app.class_session where class_id = pg_temp.c('h') and type_code not in ('HOC_BU', 'BO_TRO') and status_code = 'NHAP'),
  'G18: ngày kết thúc dự kiến theo buổi chính cuối, không theo buổi học bù');

-- A-23-21: huỷ buổi học bù, bổ trợ (trung tâm huỷ) không thêm buổi Chính vào cuối lịch; huỷ buổi Chính vẫn thêm.
select pg_temp.mkclass('k', 'CB', pg_temp.fut(), 4);
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, type_code, status_code, is_manual)
  select c.id, c.branch_id, pg_temp.fut() + 3, '10:00', '11:00', 'HOC_BU', 'NHAP', true from app.class c where c.id = pg_temp.c('k')$$);
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_date, start_time, end_time, type_code, status_code, is_manual)
  select c.id, c.branch_id, pg_temp.fut() + 4, '10:00', '11:00', 'BO_TRO', 'NHAP', true from app.class c where c.id = pg_temp.c('k')$$);
select is((app.session_cancel_preview((select id from app.class_session where class_id = pg_temp.c('k') and type_code = 'HOC_BU')) ->> 'added_date'), null,
  'A-23-21: xem trước huỷ buổi học bù không có buổi thêm cuối lịch');
select is((select (app.cancel_session((select id from app.class_session where class_id = pg_temp.c('k') and type_code = 'HOC_BU'), 'HUY_KHONG_PHI', 'TT_THOI_TIET') ->> 'added_session_id')), null,
  'A-23-21: huỷ buổi học bù không thêm buổi');
select is((select (app.cancel_session((select id from app.class_session where class_id = pg_temp.c('k') and type_code = 'BO_TRO'), 'HUY_KHONG_PHI', 'TT_THOI_TIET') ->> 'added_session_id')), null,
  'A-23-21: huỷ buổi bổ trợ không thêm buổi');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('k') and type_code not in ('HOC_BU', 'BO_TRO') and status_code = 'NHAP'), 4,
  'A-23-21: sau khi huỷ bù và bổ trợ lớp vẫn đúng 4 buổi chính');
select isnt((app.cancel_session(pg_temp.s('k', 2), 'HUY_KHONG_PHI', 'TT_THOI_TIET') ->> 'added_session_id'), null,
  'A-23-21: huỷ buổi Chính (trung tâm huỷ) vẫn thêm một buổi cuối lịch (R-BUOI-06)');

select * from finish();
rollback;
