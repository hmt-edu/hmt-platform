-- Migration 686–688 (C-26-05, PR-DD2): điều kiện Done mới, dấu hạn, Done tay, Done hàng loạt, nhập thay. R-GIO-06, 09, 11, 12; R-GV-05; ca 3–5, 8–11, 13 của DD1 mục 8.
-- Dữ liệu giả; phần dựng dùng giống bài 685.
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

-- ---------- Buổi 1: điều kiện Done, danh sách thiếu, dấu hạn ----------
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.close_session(pg_temp.s('p', 1));
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select pg_temp.gvall(1, 'CO_MAT');
select is(app.finish_session(pg_temp.s('p', 1)) ->> 'done', 'false', 'R-GIO-09 chặn: thiếu thì Done tay không Done');
select is(app.finish_session(pg_temp.s('p', 1)) -> 'missing',
          '["Giáo viên chưa nhập nội dung buổi.", "Giáo viên chưa mở phần nhận xét của buổi."]'::jsonb, 'R-GIO-06: liệt kê mọi điều còn thiếu');
select is(pg_temp.ses(1), 'DA_CHOT|-|false|false|-', 'R-GV-05 chặn: phần giáo viên chưa đủ thì chưa đóng dấu');

select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select pg_temp.vhall(1, 'VANG_KHONG_PHEP');
select pg_temp.sudo($$select pg_temp.fillreview(pg_temp.s('p', 1))$$);
select pg_temp.sudo($$select app.complete_session_if_ready(pg_temp.s('p', 1))$$);
select is(pg_temp.ses(1), 'DA_CHOT|-|false|true|true', 'R-GV-05: phần giáo viên đủ thì đóng dấu dù hai cột còn lệch; quá hạn là trễ');
select is(pg_temp.session_pending_reason(pg_temp.s('p', 1)), 'Điểm danh giáo viên và vận hành chưa khớp ở 1 em.', 'R-GIO-06 chặn: lệch hai cột thì không Done');
select is(pg_temp.deducted(1), '0|0', 'Chưa Done thì chưa trừ giờ');
reset role;
create temp table stamp1 as select completion_stamped_at as at, completion_late_hours as h from app.class_session where id = pg_temp.s('p', 1);
set local role authenticated;
select pg_temp.vhall(1, 'CO_MAT');
select is(pg_temp.ses(1), 'DONE|TU_DONG|false|true|true', 'R-GIO-06: vận hành sửa cho khớp thì Done ngay');
select is(pg_temp.deducted(1), '1|1', 'R-GIO-01: trừ giờ đúng một lần');
reset role;
select ok((select s.completion_stamped_at = t.at and s.completion_late_hours = t.h from app.class_session s, stamp1 t where s.id = pg_temp.s('p', 1)),
          'R-GV-05: dấu đóng một lần, lúc Done không đổi');
set local role authenticated;

-- ---------- Khoá sau Done ----------
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select pg_temp.vhall(1, 'DI_MUON')$$), 'HMT_BUOI_CHUA_CHOT', 'R-GIO-07 chặn: sau Done khoá cột vận hành');
select is(pg_temp.err($$select app.finish_session(pg_temp.s('p', 1))$$), 'HMT_BUOI_DA_DONE', 'Chặn: Done tay buổi đã Done');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select pg_temp.gvall(1, 'DI_MUON')$$), 'HMT_BUOI_DA_DONE', 'R-GIO-07 chặn: sau Done khoá cột giáo viên');

-- ---------- Nhập thay (buổi 2) ----------
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.close_session(pg_temp.s('p', 2));
select is(pg_temp.err($$select pg_temp.gvall(2, 'CO_MAT')$$), 'HMT_CAN_NHAP_THAY', 'R-DD-05 chặn: vận hành không ghi thẳng cột giáo viên');
select is(pg_temp.err($$select app.enter_for_teacher(pg_temp.s('p', 2), 'DIEM_DANH', '{}', 'Lý do giả')$$), 'HMT_KHONG_CO_QUYEN', 'R-GIO-11 chặn: vận hành không nhập thay');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.enter_for_teacher(pg_temp.s('p', 2), 'DIEM_DANH', '{}', 'Lý do giả')$$), 'HMT_KHONG_CO_QUYEN', 'R-GIO-11 chặn: giáo viên khác không nhập thay');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.enter_for_teacher(pg_temp.s('p', 2), 'DIEM_DANH', '{}', 'Lý do giả')$$), 'HMT_KHONG_CO_QUYEN', 'R-GIO-11 chặn: quản lý cơ sở khác');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select pg_temp.gvall(2, 'CO_MAT')$$), 'HMT_CAN_NHAP_THAY', 'R-GIO-11 chặn: quản lý ghi thẳng, không lý do');
select is(pg_temp.err($$select app.enter_for_teacher(pg_temp.s('p', 2), 'DIEM_DANH', '{}', '  ')$$), 'HMT_CAN_LY_DO', 'R-GIO-11 chặn: không lý do');
select is(app.enter_for_teacher(pg_temp.s('p', 2), 'DIEM_DANH', jsonb_build_object('entries', pg_temp.all_entries(2, 'CO_MAT')), 'Giáo viên giả bị ốm'), 1,
          'R-GIO-11: quản lý cơ sở nhập thay điểm danh');
select is((select concat_ws('|', kind, reason, (created_by = pg_temp.uid('bm1'))::text) from app.session_proxy_entry where session_id = pg_temp.s('p', 2)),
          'DIEM_DANH|Giáo viên giả bị ốm|true', 'R-GIO-11: nhật ký ghi người nhập thay và lý do');
select is(pg_temp.err($$select pg_temp.gvall(2, 'DI_MUON')$$), 'HMT_CAN_NHAP_THAY', 'Chặn: hết lượt nhập thay thì cờ không còn');

-- ---------- Done hàng loạt ----------
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.close_session(pg_temp.s('p', 3));
select is(pg_temp.err($$select pg_temp.bulk(array[2], 'Lý do giả')$$), 'HMT_KHONG_CO_QUYEN', 'R-GIO-12 chặn: vận hành');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select pg_temp.bulk(array[2], 'Lý do giả')$$), 'HMT_KHONG_CO_QUYEN', 'R-GIO-12 chặn: giáo viên');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select pg_temp.bulk(array[2], 'Lý do giả')$$), 'HMT_KHONG_CO_QUYEN', 'R-GIO-12 chặn: quản lý cơ sở khác');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select pg_temp.bulk(array[2], ' ')$$), 'HMT_CAN_LY_DO', 'R-GIO-12 chặn: không lý do');
select is(pg_temp.err($$select app.bulk_finish_sessions('{}', 'Lý do giả')$$), 'HMT_CHUA_CHON_BUOI', 'Chặn: chưa chọn buổi');
select is(pg_temp.err($$select pg_temp.bulk(array[2, 2], 'Lý do giả')$$), 'HMT_KHONG_TIM_THAY', 'Chặn: chọn trùng buổi');
select pg_temp.sudo($$update app.setting_def set value = '1' where key = 'session_bulk_done_max'$$);
select is(pg_temp.err($$select pg_temp.bulk(array[2, 3], 'Lý do giả')$$), 'HMT_QUA_SO_BUOI', 'Chặn: quá số buổi một lượt (tham số)');
select pg_temp.sudo($$update app.setting_def set value = '50' where key = 'session_bulk_done_max'$$);

-- Buổi 2 đủ điểm danh (thiếu nội dung, nhận xét), buổi 3 chưa điểm danh.
create temp table r1 as select pg_temp.bulk(array[2, 3], 'Chốt tháng giả') as v;
select is((select jsonb_array_length(v -> 'done') from r1), 1, 'R-GIO-12: buổi đủ điểm danh được Done');
select ok((select v -> 'skipped' -> 0 ->> 'reason' like 'Giáo viên chưa điểm danh % em.' and v -> 'skipped' -> 0 ->> 'session_no' = '3'
                  and v -> 'skipped' -> 0 ->> 'class_code' is not null from r1),
          'R-GIO-12 chặn: buổi chưa đủ điểm danh bị loại và báo tên');
select is(pg_temp.ses(2), 'DONE|HANG_LOAT|true|true|true', 'R-GIO-12: gắn cờ Thiếu nhận xét, ghi cách hoàn tất');
select is((select concat_ws('|', done_reason, (done_by = pg_temp.uid('bm1'))::text) from app.class_session where id = pg_temp.s('p', 2)),
          'Chốt tháng giả|true', 'R-GIO-12: ghi lý do và người bấm');
select is(pg_temp.deducted(2), '1|1', 'R-GIO-01: Done hàng loạt trừ giờ như mọi buổi');
select is(pg_temp.bulk(array[2], 'Lý do giả') -> 'skipped' -> 0 ->> 'reason', 'Buổi đã Done.', 'Chặn: buổi đã Done không trừ lại');
select is(pg_temp.deducted(2), '1|1', 'Không trừ lại');

-- Một buổi lỗi khi trừ giờ không chặn buổi khác (lỗi giả bằng trigger).
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select pg_temp.gvall(3, 'CO_MAT');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.close_session(pg_temp.s('p', 4));
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select pg_temp.gvall(4, 'CO_MAT');
reset role;
create function pg_temp.boom() returns trigger language plpgsql as $$
begin
  if new.status_code = 'DONE' and new.session_no = 3 then raise exception 'Lỗi giả của buổi 3'; end if;
  return new;
end $$;
create trigger zz_boom before update on app.class_session for each row execute function pg_temp.boom();
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
create temp table r2 as select pg_temp.bulk(array[3], 'Lý do giả') as v;
select is((select v -> 'skipped' -> 0 ->> 'reason' from r2), 'Lỗi giả của buổi 3', 'Buổi lỗi được báo riêng');
select is(pg_temp.ses(3) || ' / ' || pg_temp.deducted(3), 'DA_CHOT|-|false|false|- / 0|0', 'Buổi lỗi giữ Đã chốt: không trừ giờ, không đóng dấu nửa vời');
reset role;
drop trigger zz_boom on app.class_session;
set local role authenticated;

-- ---------- Done tay thành công (buổi 4) ----------
select pg_temp.sudo($$select pg_temp.fillreview(pg_temp.s('p', 4))$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.finish_session(pg_temp.s('p', 4)) ->> 'done', 'true', 'R-GIO-09: vận hành bấm Done tay khi đủ điều kiện');
select is(pg_temp.ses(4), 'DONE|TAY|false|true|true', 'R-GIO-09: ghi cách hoàn tất Done tay');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is(pg_temp.err($$select app.finish_session(pg_temp.s('p', 3))$$), 'HMT_KHONG_CO_QUYEN', 'R-GIO-09 chặn: giáo viên không dạy buổi này');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.finish_session(pg_temp.s('p', 3))$$), 'HMT_KHONG_CO_QUYEN', 'R-GIO-09 chặn: vai chỉ xem điểm danh');

-- ---------- Phạm vi hẹp không nhập thay, không Done hàng loạt (R-GIO-11, R-GIO-12) ----------
select pg_temp.sudo($$update app.permission set scope_code = 'DUOC_PHAN_CONG' where role_code = 'BRANCH_MANAGER' and module_code = 'ATTENDANCE' and action_code = 'DUYET' and is_active$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.enter_for_teacher(pg_temp.s('p', 3), 'DIEM_DANH', '{}', 'Lý do giả')$$), 'HMT_KHONG_CO_QUYEN', 'R-GIO-11 chặn: phạm vi Được phân công không nhập thay');
select is(pg_temp.err($$select pg_temp.bulk(array[3], 'Lý do giả')$$), 'HMT_KHONG_CO_QUYEN', 'R-GIO-12 chặn: phạm vi Được phân công không Done hàng loạt');
select pg_temp.sudo($$update app.permission set scope_code = 'CUA_TOI' where role_code = 'BRANCH_MANAGER' and module_code = 'ATTENDANCE' and action_code = 'DUYET' and is_active$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.enter_for_teacher(pg_temp.s('p', 3), 'DIEM_DANH', '{}', 'Lý do giả')$$), 'HMT_KHONG_CO_QUYEN', 'R-GIO-11 chặn: phạm vi Của tôi không nhập thay');
select is(pg_temp.err($$select pg_temp.bulk(array[3], 'Lý do giả')$$), 'HMT_KHONG_CO_QUYEN', 'R-GIO-12 chặn: phạm vi Của tôi không Done hàng loạt');

-- ---------- Thông tin Done cho BUOI-02 (mig 692) ----------
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(jsonb_array_length(app.session_done_info(pg_temp.s('p', 2)) -> 'proxies'), 0, 'R-GIO-11 chặn: phạm vi hẹp không thấy lượt nhập thay');
select pg_temp.sudo($$update app.permission set scope_code = 'CO_SO' where role_code = 'BRANCH_MANAGER' and module_code = 'ATTENDANCE' and action_code = 'DUYET' and is_active$$);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((select concat_ws('|', v ->> 'done_mode', v ->> 'done_by_name', v ->> 'missing_review', jsonb_array_length(v -> 'proxies'), v -> 'proxies' -> 0 ->> 'reason')
             from (select app.session_done_info(pg_temp.s('p', 2)) as v) x),
          'HANG_LOAT|Giả bm1|true|1|Giáo viên giả bị ốm', 'R-GIO-11, 12: đọc cách hoàn tất, người bấm, cờ và lượt nhập thay');
select ok(jsonb_array_length(app.session_done_info(pg_temp.s('p', 3)) -> 'missing') > 0, 'R-GIO-09: buổi Đã chốt trả danh sách còn thiếu');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((select concat_ws('|', v ->> 'done_mode', jsonb_array_length(v -> 'proxies')) from (select app.session_done_info(pg_temp.s('p', 2)) as v) x),
          'HANG_LOAT|0', 'R-GIO-11 chặn: vai chỉ xem buổi không thấy người và lý do nhập thay');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.session_done_info(pg_temp.s('p', 2))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: quản lý cơ sở khác không đọc');

-- ---------- Hàm nội bộ ----------
select ok(not has_function_privilege('authenticated', 'app.apply_session_done(uuid, text, text, boolean)', 'execute'), 'Chặn: hàm Done nội bộ không gọi được từ ngoài');
select ok(not has_function_privilege('authenticated', 'app.bulk_finish_one(uuid, text)', 'execute'), 'Chặn: hàm Done từng buổi không gọi được từ ngoài');
select ok(not has_function_privilege('authenticated', 'app.apply_proxy_entry(uuid, text, jsonb)', 'execute'), 'Chặn: hàm ghi thay nội bộ không gọi được từ ngoài');

select * from finish();
rollback;
