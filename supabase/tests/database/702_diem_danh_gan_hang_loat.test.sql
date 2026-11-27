-- Migration 702 (C-27-07 mục 4b): app.set_attendance_ops_bulk. R-DD-02: gán cùng lúc nhiều buổi, một giao dịch, quyền như ghi từng buổi.
-- Dữ liệu giả; phần dựng giống bài 686.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- Migration 577: hàm trợ giúp không cấp cho authenticated; bài kiểm gọi qua hàm bọc chạy bằng quyền chủ (pg_temp).
create function pg_temp.session_pending_reason(p uuid) returns text language sql security definer as $$ select app.session_pending_reason(p) $$;
grant execute on function pg_temp.session_pending_reason(uuid) to public;

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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p686.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p686.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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
create function pg_temp.st(p_n integer) returns uuid language sql stable security definer as $$ select id from app.student where code = 'HSD1C0' || p_n $$;
-- Ghi danh giả; p_old = true thì lùi ngày tạo 60 ngày (tắt tạm trigger điền cột chuẩn) để vào được danh sách buổi quá khứ (R-GIO-02).
create function pg_temp.mke(p_key text, p_n integer, p_old boolean, p_hours numeric) returns void language plpgsql security definer as $$
declare v_id uuid;
begin
  insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code)
  values ('GDC' || p_key, pg_temp.st(p_n), (select parent_id from app.student where id = pg_temp.st(p_n)), pg_temp.cs('CS1'), 'TOAN')
  returning id into v_id;
  if p_old then
    alter table app.enrollment disable trigger enrollment_fill_standard;
    update app.enrollment set created_at = now() - interval '60 days' where id = v_id;
    alter table app.enrollment enable trigger enrollment_fill_standard;
  end if;
  insert into en values (p_key, v_id);
  if p_hours <> 0 then
    perform app.add_opening_hours(v_id, p_hours, 'DOT-D1C');
  end if;
end $$;
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

-- Từ đây chạy với vai trò đăng nhập thật (RLS và quyền gọi hàm có hiệu lực).
set local role authenticated;
-- ---------- Hồ sơ giả ----------
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHD1C01', 'Phụ huynh giả D1c', '0900101002', pg_temp.cs('CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSD1C0' || n, (select id from app.parent where code = 'PHD1C01'), 'Em giả D1c ' || n, 2012, pg_temp.cs('CS1') from generate_series(1, 6) n$$);

-- ---------- Lớp quá khứ P (4 buổi thứ Hai), lớp tương lai F, lớp riêng L ----------
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('p', 'CB', pg_temp.past(), 4);
select pg_temp.mkclass('f', 'CB', pg_temp.fut(), 4);
select pg_temp.mkclass('l', 'LR', pg_temp.fut(), 3);
-- Ghi danh: ea (em 1, 4 giờ), ea2 (em 1, ghi danh thứ hai vào sau), eb (em 2, 0 giờ), ec (em 3, bảo lưu), ed (em 4, vào lớp muộn), ee (em 5, tạo hôm nay).
select pg_temp.sudo($$select pg_temp.mke('a', 1, true, 4)$$);
select pg_temp.sudo($$select pg_temp.mke('a2', 1, true, 4)$$);
select pg_temp.sudo($$select pg_temp.mke('b', 2, true, 0)$$);
select pg_temp.sudo($$select pg_temp.mke('c', 3, true, 4)$$);
select pg_temp.sudo($$select pg_temp.mke('d', 4, true, 4)$$);
select pg_temp.sudo($$select pg_temp.mke('e', 5, false, 4)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e('a'), pg_temp.c('p'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('a2'), pg_temp.c('p'), pg_temp.past() + 7);
select app.assign_enrollment_class(pg_temp.e('b'), pg_temp.c('p'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('c'), pg_temp.c('p'), pg_temp.past());
select app.assign_enrollment_class(pg_temp.e('d'), pg_temp.c('p'), pg_temp.past() + 14);
select app.assign_enrollment_class(pg_temp.e('e'), pg_temp.c('p'), pg_temp.past() + 7);
select pg_temp.sudo($$update app.enrollment set status_code = 'BAO_LUU' where id = pg_temp.e('c')$$);

-- Mọi em trong danh sách một buổi cùng một trạng thái.
create function pg_temp.all_entries(p_n integer, p_status text) returns jsonb language sql stable security definer as $$
  select jsonb_agg(jsonb_build_object('student_id', student_id, 'status_code', p_status))
    from app.session_attendance where session_id = pg_temp.s('p', p_n) and is_active $$;
create function pg_temp.gvall(p_n integer, p_status text) returns integer language sql as $$
  select app.set_attendance_teacher(pg_temp.s('p', p_n), pg_temp.all_entries(p_n, p_status)) $$;
create function pg_temp.vhall(p_n integer, p_status text) returns integer language sql as $$
  select app.set_attendance_ops(pg_temp.s('p', p_n), pg_temp.all_entries(p_n, p_status)) $$;
-- «tình trạng|cách Done|cờ thiếu nhận xét|đã đóng dấu|trễ hạn».
create function pg_temp.ses(p_n integer) returns text language sql stable security definer as $$
  select concat_ws('|', status_code, coalesce(done_mode, '-'), done_missing_review::text, (completion_stamped_at is not null)::text,
                   coalesce(completion_late::text, '-'))
    from app.class_session where id = pg_temp.s('p', p_n) $$;
-- Số dòng trừ giờ của buổi và số em được trừ.
create function pg_temp.deducted(p_n integer) returns text language sql stable security definer as $$
  select count(*)::text || '|' || count(distinct enrollment_id)::text from app.hour_ledger
   where session_id = pg_temp.s('p', p_n) and entry_type = 'TRU_BUOI' $$;
create function pg_temp.bulk(p_ns integer[], p_reason text) returns jsonb language sql as $$
  select app.bulk_finish_sessions((select array_agg(pg_temp.s('p', n)) from unnest(p_ns) n), p_reason) $$;
grant execute on all functions in schema pg_temp to public;

select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.close_session(pg_temp.s('p', 1));
select app.close_session(pg_temp.s('p', 2));
-- Mỗi em của buổi 1 và 2, cùng trạng thái. Chụp danh sách khi còn là người cơ sở CS1: hàm tạo sau «set role» chạy theo RLS của người gọi.
create temp table ds as select session_id, student_id from app.session_attendance
 where session_id in (pg_temp.s('p', 1), pg_temp.s('p', 2)) and is_active;
grant select on ds to authenticated;
create function pg_temp.hai_buoi(p_status text) returns jsonb language sql stable as $$
  select jsonb_agg(jsonb_build_object('session_id', session_id, 'student_id', student_id, 'status_code', p_status)) from ds $$;
create function pg_temp.vh(p_n integer) returns text language sql stable security definer as $$
  select count(*) filter (where ops_status_code = 'CO_MAT') || '/' || count(*)
    from app.session_attendance where session_id = pg_temp.s('p', p_n) and is_active $$;
grant execute on all functions in schema pg_temp to public;
create temp table n as select jsonb_array_length(pg_temp.hai_buoi('CO_MAT')) as total;
grant select on n to authenticated;

-- Chặn trước khi ghi.
select is(pg_temp.err($$select app.set_attendance_ops_bulk('[]')$$), 'HMT_CHUA_CHON_EM', 'Chặn: chưa chọn em');
select is(pg_temp.err($$select app.set_attendance_ops_bulk(pg_temp.hai_buoi(''))$$), 'HMT_THIEU_TRANG_THAI', 'Chặn: thiếu trạng thái');
select is(pg_temp.err($$select app.set_attendance_ops_bulk(
    (select jsonb_agg(pg_temp.hai_buoi('CO_MAT') -> 0) from generate_series(1, app.get_setting_int('list_page_size_max')::int + 1)))$$),
  'HMT_QUA_SO_DONG', 'Chặn: quá số dòng một lượt (tham số)');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.set_attendance_ops_bulk(pg_temp.hai_buoi('CO_MAT'))$$), 'HMT_KHONG_CO_QUYEN', 'R-DD-02 chặn: giáo viên không ghi cột Vận hành');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.set_attendance_ops_bulk(pg_temp.hai_buoi('CO_MAT'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: cơ sở khác');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.set_attendance_ops_bulk(pg_temp.hai_buoi('CO_MAT'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: vai chỉ xem');

-- Một dòng sai (em không trong buổi) thì không ghi dòng nào.
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select ok(pg_temp.err($$select app.set_attendance_ops_bulk(pg_temp.hai_buoi('CO_MAT')
  || jsonb_build_array(jsonb_build_object('session_id', pg_temp.s('p', 1), 'student_id', gen_random_uuid(), 'status_code', 'CO_MAT')))$$) = 'HMT_EM_KHONG_TRONG_DANH_SACH',
  'Chặn: có em không trong danh sách buổi');
select is(split_part(pg_temp.vh(1), '/', 1) || split_part(pg_temp.vh(2), '/', 1), '00', 'Cả lượt không ghi gì khi một dòng bị chặn');
-- Buổi chưa chốt trong lượt: từ chối cả lượt.
select is(pg_temp.err($$select app.set_attendance_ops_bulk(pg_temp.hai_buoi('CO_MAT')
  || jsonb_build_array(jsonb_build_object('session_id', pg_temp.s('f', 1), 'student_id', pg_temp.st(1), 'status_code', 'CO_MAT')))$$),
  'HMT_BUOI_CHUA_CHOT', 'Chặn: buổi chưa chốt hoặc đã Done');

select is(app.set_attendance_ops_bulk(pg_temp.hai_buoi('CO_MAT')), (select total from n)::int, 'R-DD-02: gán cùng lúc hai buổi');
select ok(split_part(pg_temp.vh(1), '/', 1) = split_part(pg_temp.vh(1), '/', 2) and split_part(pg_temp.vh(2), '/', 1) = split_part(pg_temp.vh(2), '/', 2),
  'Cột Vận hành của cả hai buổi đã ghi');

select * from finish();
rollback;
