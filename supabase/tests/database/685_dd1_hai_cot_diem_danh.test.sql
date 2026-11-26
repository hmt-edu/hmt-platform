-- Migration 685 (C-26-05, PR-DD1): hai cột điểm danh theo DD1. DD-02, DD-03, DD-04, C1; ca kiểm 1, 2, 12, 14 của DD1 mục 8. Dữ liệu giả.
-- Phần dựng dữ liệu giống bài 102.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@p685.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@p685.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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

-- Dòng điểm danh của em 1 ở buổi n: «ô giáo viên|ô vận hành|nguồn|lý do».
create function pg_temp.row(p_n integer) returns text language sql stable security definer as $$
  select concat_ws('|', coalesce(teacher_status_code, '-'), coalesce(ops_status_code, '-'), coalesce(ops_source, '-'), coalesce(contact_reason_code, '-'))
    from app.session_attendance where session_id = pg_temp.s('p', p_n) and student_id = pg_temp.st(1) $$;
create function pg_temp.opsby(p_n integer) returns uuid language sql stable security definer as $$
  select ops_marked_by from app.session_attendance where session_id = pg_temp.s('p', p_n) and student_id = pg_temp.st(1) $$;
create function pg_temp.gv(p_status text, p_n integer default 1) returns integer language sql as $$
  select app.set_attendance_teacher(pg_temp.s('p', p_n), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1), 'status_code', p_status))) $$;
create function pg_temp.vh(p_entry jsonb, p_n integer default 1) returns integer language sql as $$
  select app.set_attendance_ops(pg_temp.s('p', p_n), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(1)) || p_entry)) $$;
grant execute on all functions in schema pg_temp to public;

select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.close_session(pg_temp.s('p', 1));

-- ---------- Chép sang ô vận hành (DD-04, C1) ----------
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select pg_temp.gv('CO_MAT');
select is(pg_temp.row(1), 'CO_MAT|CO_MAT|GIAO_VIEN|-', 'DD-04: ô vận hành trống thì chép từ ô giáo viên');
select is(pg_temp.opsby(1), null::uuid, 'DD-04: ô chép không ghi người vận hành');
select pg_temp.gv('DI_MUON');
select is(pg_temp.row(1), 'DI_MUON|DI_MUON|GIAO_VIEN|-', 'C1: giáo viên đổi ý, ô do chép đi theo');
select pg_temp.gv(null);
select is(pg_temp.row(1), '-|-|-|-', 'C1: giáo viên bỏ trống, ô do chép trống theo');

-- ---------- Vận hành ghi từng phần (DD-03) ----------
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select pg_temp.vh('{"contact_reason_code": "DA_NHAC_VAO_LOP"}');
select is(pg_temp.row(1), '-|-|-|DA_NHAC_VAO_LOP', 'DD-03: chỉ ghi lý do liên hệ, ô trạng thái vẫn trống');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select pg_temp.gv('CO_MAT');
select is(pg_temp.row(1), 'CO_MAT|CO_MAT|GIAO_VIEN|DA_NHAC_VAO_LOP', 'DD-04: chép trạng thái, giữ lý do liên hệ');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select pg_temp.vh('{"status_code": "CO_MAT", "note": "Ghi chú giả"}');
select is(pg_temp.row(1), 'CO_MAT|CO_MAT|GIAO_VIEN|DA_NHAC_VAO_LOP', 'Gửi lại đúng trạng thái đang có thì nguồn giữ nguyên');
select pg_temp.vh('{"status_code": "VANG_KHONG_PHEP"}');
select is(pg_temp.row(1), 'CO_MAT|VANG_KHONG_PHEP|VAN_HANH|DA_NHAC_VAO_LOP', 'Vận hành tự tích, gửi riêng trạng thái không xoá lý do');
select is(pg_temp.opsby(1), pg_temp.uid('cskh1'), 'Ghi người vận hành tự tích');
select is((select ops_note from app.session_attendance where session_id = pg_temp.s('p', 1) and student_id = pg_temp.st(1)), 'Ghi chú giả', 'Ghi chú không bị xoá khi không gửi');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select pg_temp.gv('DI_MUON');
select is(pg_temp.row(1), 'DI_MUON|VANG_KHONG_PHEP|VAN_HANH|DA_NHAC_VAO_LOP', 'DD-04 chặn: ô vận hành đã tự tích không bị đè');
select pg_temp.gv(null);
select is(pg_temp.row(1), '-|VANG_KHONG_PHEP|VAN_HANH|DA_NHAC_VAO_LOP', 'Giáo viên bỏ trống không xoá ô vận hành tự tích');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select pg_temp.vh('{"status_code": null}');
select is(pg_temp.row(1), '-|-|-|DA_NHAC_VAO_LOP', 'Vận hành xoá ô của mình: trạng thái và nguồn trống, lý do còn');
select is(pg_temp.opsby(1), null::uuid, 'Xoá ô thì bỏ người ghi');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select pg_temp.gv('CO_MAT');
select is(pg_temp.row(1), 'CO_MAT|CO_MAT|GIAO_VIEN|DA_NHAC_VAO_LOP', 'Ô vận hành trống trở lại thì được chép tiếp');

-- ---------- Bị chặn ----------
select is(pg_temp.err($$select pg_temp.vh('{"status_code": "CO_MAT"}')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không ghi phía vận hành');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select pg_temp.vh('{"note": null}');
select is(pg_temp.err($$select pg_temp.vh('{"contact_reason_code": "KHAC"}')$$), 'HMT_CAN_GHI_CHU', 'Chặn: lý do "Khác" không có ghi chú');
select is(pg_temp.err($$select pg_temp.vh('{"status_code": "X"}')$$), 'HMT_DANH_MUC_KHONG_CO', 'Chặn: trạng thái ngoài danh mục');
select is(pg_temp.err($$select app.set_attendance_ops(pg_temp.s('p', 1), jsonb_build_array(jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'CO_MAT')))$$),
          'HMT_EM_KHONG_TRONG_DANH_SACH', 'Chặn: em không có trong danh sách');
select ok(not has_function_privilege('authenticated', 'app.write_attendance_ops(app.session_attendance, jsonb)', 'execute'), 'Chặn: hàm ghi nội bộ không gọi được từ ngoài');

-- ---------- Báo cáo, cờ vắng chỉ đọc cột giáo viên (DD-02) ----------
select pg_temp.sudo($$select pg_temp.fillreview(pg_temp.s('p', 1))$$);
select pg_temp.sudo($$select app.complete_session_if_ready(pg_temp.s('p', 1))$$);
select app.close_session(pg_temp.s('p', 2));
select pg_temp.vh('{"status_code": "VANG_KHONG_PHEP"}', 2);
select pg_temp.sudo($$update app.setting_def set value = '1' where key = 'absence_risk_sessions'$$);
select pg_temp.sudo($$update app.setting_def set value = '60' where key = 'absence_risk_window_days'$$);
-- Hàm nội bộ nên bài kiểm gọi qua hàm bọc do quyền chủ tạo.
select pg_temp.sudo($q$create function pg_temp.risk() returns boolean language sql stable security definer as
  'select risk_flag from app.upsale_candidates() where student_id = pg_temp.st(1) and class_id = pg_temp.c(''p'')'$q$);
select pg_temp.sudo('grant execute on function pg_temp.risk() to public');
select is(pg_temp.risk(), false, 'DD-02: chỉ vận hành ghi vắng, giáo viên chưa ghi thì không tính cờ vắng');
select pg_temp.sudo($$update app.class_session set status_code = 'DONE' where id = pg_temp.s('p', 2)$$);
reset role;
select is((select concat_ws('|', marked, present, absent) from report.class_attendance where class_id = pg_temp.c('p')), '1|1|0', 'DD-02: chuyên cần chỉ đếm cột giáo viên');
update app.session_attendance set teacher_status_code = 'VANG_CO_PHEP' where session_id = pg_temp.s('p', 2) and student_id = pg_temp.st(1);
select is(pg_temp.risk(), true, 'DD-02: giáo viên ghi vắng thì tính cờ vắng');
select is((select concat_ws('|', marked, present, absent) from report.class_attendance where class_id = pg_temp.c('p')), '2|1|1', 'DD-02: chuyên cần cộng lượt vắng theo cột giáo viên');
select ok(position('ops_status_code' in pg_get_functiondef('app.get_upsale_ticket(uuid)'::regprocedure)) = 0, 'DD-02: số buổi vắng trên phiếu tái tục không đọc cột vận hành');
select ok((select 'security_invoker=true' = any (reloptions) from pg_class where oid = 'report.class_attendance'::regclass), 'BC-06: view vẫn security_invoker');

select * from finish();
rollback;
