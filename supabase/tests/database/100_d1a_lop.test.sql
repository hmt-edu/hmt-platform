-- D1a (migration 100): Lớp, thời khoá biểu, nhóm lớp, duyệt lớp, sinh buổi.
-- Luật: R-LOP-01..06, 08, 09, 10, 12, 13, 14; R-GV-08 (giáo viên chỉ thấy lớp, buổi của mình).
-- Mỗi luật có ca đúng và ca bị chặn; vai đọc, ghi trong và ngoài phạm vi. Dữ liệu giả. Ngày tính từ hôm nay để bài không lỗi theo thời gian.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
create function pg_temp.op_status(p uuid) returns text language sql security definer as $$ select app.class_operating_status(p) $$;

-- Migration 577: hàm trợ giúp không cấp cho authenticated; bài kiểm gọi qua hàm bọc chạy bằng quyền chủ (pg_temp).
create function pg_temp.class_clash_warnings(p uuid) returns jsonb language sql security definer as $$ select app.class_clash_warnings(p) $$;
grant execute on function pg_temp.class_clash_warnings(uuid) to public;

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

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('bm5'), ('cskh1'), ('sales1'), ('gv1'), ('gv2');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d1a.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d1a.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('bm5', 'CS5'), ('cskh1', 'CS1'), ('sales1', 'CS1'), ('gv1', 'CS1'), ('gv2', 'CS1')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('cskh1', 'CSKH'),
  ('sales1', 'SALES'), ('gv1', 'TEACHER'), ('gv2', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;

grant execute on all functions in schema pg_temp to public;
-- Từ đây chạy với vai trò đăng nhập thật (RLS và quyền gọi hàm có hiệu lực).
set local role authenticated;
-- Ngày mẫu: thứ Hai cách hôm nay 2 tuần (date_trunc('week') cho thứ Hai).
create function pg_temp.mon() returns date language sql stable as $$ select (date_trunc('week', current_date) + interval '14 days')::date $$;
create temp table cl (key text primary key, id uuid);
grant all on cl to public;
create function pg_temp.c(p_key text) returns uuid language sql stable as $$ select id from cl where key = p_key $$;
-- Dữ liệu một lớp: CS1, 2627, TOAN K08 CB A, 6 buổi, một khung thứ Hai 18:00-19:30 hàng tuần, giáo viên gv1.
create function pg_temp.data(p_extra jsonb default '{}'::jsonb) returns jsonb language sql stable as $$
  select jsonb_build_object('branch_id', pg_temp.cs('CS1'), 'year_code', '2627', 'subject_code', 'TOAN', 'grade_code', 'K08',
    'class_type_code', 'CB', 'level_code', 'A', 'max_students', 15, 'start_date', pg_temp.mon(), 'total_sessions', 6,
    'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
                                                  'first_date', pg_temp.mon(), 'teacher_id', pg_temp.uid('gv1')))) || p_extra $$;
create function pg_temp.mk(p_key text, p_data jsonb) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  v := app.create_class(p_data);
  insert into cl values (p_key, (v ->> 'id')::uuid);
  return v;
end $$;
grant execute on all functions in schema pg_temp to public;

-- Ngày nghỉ lễ chung vào thứ Hai tuần thứ hai: buổi thứ hai phải nhảy sang tuần sau (R-LOP-09, R-LOP-12).
select pg_temp.sudo($$insert into app.holiday (holiday_date, name) values (pg_temp.mon() + 7, 'Nghỉ giả cho kiểm thử')$$);

-- ================= Tham số =================
select is(app.get_setting_int('class_slot_repeat_weeks_max')::integer, 4, 'Tham số class_slot_repeat_weeks_max mặc định 4 (R-LOP-13)');

-- ================= Tạo lớp: quyền, mã, thời khoá biểu =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select pg_temp.mk('x', pg_temp.data())$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Tuyển sinh không có quyền tạo lớp (R-LOP-02)');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select pg_temp.mk('x', pg_temp.data())$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở CS5 không mở lớp ở CS1 (R-LOP-06)');

select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select pg_temp.mk('x', pg_temp.data(jsonb_build_object('total_sessions', 0)))$$), 'HMT_LOP_THIEU_THONG_TIN', 'Chặn: số buổi phải lớn hơn 0');
select is(pg_temp.err($$select pg_temp.mk('x', pg_temp.data(jsonb_build_object('class_type_code', 'LR')))$$), 'HMT_MA_LOP_SAI', 'Chặn: lớp riêng không có trình độ (spec 02)');
-- R-LOP-13: lặp mỗi N tuần, N từ 1 đến tham số.
select is(pg_temp.err($$select pg_temp.mk('x', pg_temp.data(jsonb_build_object('slots', jsonb_build_array(jsonb_build_object(
  'weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 5, 'first_date', pg_temp.mon())))))$$),
  'HMT_LOP_LAP_TUAN_SAI', 'Chặn: lặp mỗi 5 tuần vượt tham số (R-LOP-13)');
select is(pg_temp.err($$select pg_temp.mk('x', pg_temp.data(jsonb_build_object('slots', jsonb_build_array(jsonb_build_object(
  'weekday', 2, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1, 'first_date', pg_temp.mon())))))$$),
  'HMT_LOP_NGAY_DAU_SAI_THU', 'Chặn: ngày buổi đầu không đúng thứ của khung (R-LOP-13)');
select is(pg_temp.err($$select pg_temp.mk('x', pg_temp.data(jsonb_build_object('slots', jsonb_build_array(jsonb_build_object(
  'weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1, 'first_date', pg_temp.mon() - 7)))))$$),
  'HMT_LOP_NGAY_DAU_TRUOC_KHAI_GIANG', 'Chặn: ngày buổi đầu trước ngày khai giảng (R-LOP-13)');
select is(pg_temp.err($$select pg_temp.mk('x', pg_temp.data(jsonb_build_object('slots', jsonb_build_array(jsonb_build_object(
  'weekday', 1, 'start_time', '19:30', 'end_time', '18:00', 'repeat_weeks', 1, 'first_date', pg_temp.mon())))))$$),
  'HMT_LOP_KHUNG_GIO_SAI', 'Chặn: giờ kết thúc không sau giờ bắt đầu');

select ok(pg_temp.mk('a', pg_temp.data(jsonb_build_object('legacy_ref', '8A1'))) ->> 'code' ~ '^CS1-2627-TOAN-K08-CB-A-\d{3}$',
          'Đúng: CSKH tạo lớp ở cơ sở mình, mã đúng chuẩn spec 02');
select is((select status_code from app.class where id = pg_temp.c('a')), 'NHAP', 'Lớp mới ở Nháp');
select is((select count(*)::int from app.class_event where class_id = pg_temp.c('a') and event_code = 'TAO'), 1, 'Lịch sử lớp ghi sự kiện Tạo');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('a')), 0, 'Chưa duyệt thì chưa có buổi (R-LOP-03)');
-- R-LOP-15: tìm theo mã cũ.
select is((select count(*)::int from app.class where search_text like '%8a1%'), 1, 'Tìm được lớp bằng mã cũ (R-LOP-15)');

-- ================= Duyệt lớp (R-LOP-01, 02, 03, 04) =================
-- Lớp không có thời khoá biểu: không trình được.
select pg_temp.mk('ns', pg_temp.data(jsonb_build_object('slots', '[]'::jsonb)));
select is(pg_temp.err($$select app.transition_class(pg_temp.c('ns'), 'DA_TRINH')$$), 'HMT_LOP_THIEU_THOI_KHOA_BIEU', 'Chặn: trình lớp không có thời khoá biểu (R-LOP-03)');
-- Đường đi không có trong bảng.
select is(pg_temp.err($$select app.transition_class(pg_temp.c('a'), 'DA_DUYET')$$), 'HMT_LOP_CHUYEN_SAI', 'Chặn: Nháp không nhảy thẳng sang Đã duyệt (R-LOP-01)');
select is((app.transition_class(pg_temp.c('a'), 'DA_TRINH')) ->> 'to', 'DA_TRINH', 'Đúng: CSKH trình lớp');
select is(pg_temp.err($$select app.transition_class(pg_temp.c('a'), 'DA_XAC_NHAN')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH không xác nhận được (chỉ quản lý cơ sở duyệt, R-LOP-02)');
-- Đưa về Nháp: người trình bấm được, rồi trình lại.
select is((app.transition_class(pg_temp.c('a'), 'NHAP')) ->> 'to', 'NHAP', 'Đúng: người trình đưa lớp về Nháp (R-LOP-01, 26/10)');
select app.transition_class(pg_temp.c('a'), 'DA_TRINH');

select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.transition_class(pg_temp.c('a'), 'DA_XAC_NHAN')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: quản lý cơ sở khác không xác nhận lớp CS1');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.transition_class(pg_temp.c('a'), 'TU_CHOI')$$), 'HMT_LOP_CAN_LY_DO', 'Chặn: từ chối lớp không có lý do');
select is((app.transition_class(pg_temp.c('a'), 'TU_CHOI', 'Thiếu giáo viên trợ giảng')) ->> 'to', 'TU_CHOI', 'Đúng: quản lý cơ sở từ chối kèm lý do');
select is((select note from app.class_event where class_id = pg_temp.c('a') and event_code = 'TU_CHOI'), 'Thiếu giáo viên trợ giảng', 'Lịch sử giữ lý do từ chối');
select is((app.transition_class(pg_temp.c('a'), 'NHAP')) ->> 'to', 'NHAP', 'Đúng: Từ chối quay về Nháp được (R-LOP-01)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.transition_class(pg_temp.c('a'), 'DA_TRINH');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.transition_class(pg_temp.c('a'), 'DA_XAC_NHAN')) ->> 'to', 'DA_XAC_NHAN', 'Đúng: quản lý cơ sở xác nhận');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('a')), 0, 'Xác nhận chưa sinh buổi');

-- R-LOP-02: sửa thời khoá biểu khi Đã xác nhận thì lớp quay về Đã trình.
select app.save_class_timetable(pg_temp.c('a'), jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30',
  'repeat_weeks', 1, 'first_date', pg_temp.mon(), 'teacher_id', pg_temp.uid('gv1'))));
select is((select status_code from app.class where id = pg_temp.c('a')), 'DA_TRINH', 'Đúng: sửa Time Table khi Đã xác nhận thì lớp về Đã trình (R-LOP-02)');
select app.transition_class(pg_temp.c('a'), 'DA_XAC_NHAN');

-- Duyệt: tự sinh buổi (R-LOP-03), bỏ ngày nghỉ lễ (R-LOP-09, R-LOP-12).
select is((app.transition_class(pg_temp.c('a'), 'DA_DUYET')) ->> 'sessions_created', '6', 'Đúng: duyệt xong tự sinh đủ 6 buổi (R-LOP-03)');
select is((select array_agg(session_date order by session_date)::text from app.class_session where class_id = pg_temp.c('a')),
          (select array_agg(d order by d)::text from (values (pg_temp.mon()), (pg_temp.mon() + 14), (pg_temp.mon() + 21), (pg_temp.mon() + 28),
                                                             (pg_temp.mon() + 35), (pg_temp.mon() + 42)) as t (d)),
          'Đúng: buổi rơi vào ngày nghỉ lễ bị bỏ, lịch nhảy sang tuần sau (R-LOP-09)');
select is((select expected_end_date from app.class where id = pg_temp.c('a')), pg_temp.mon() + 42, 'Ngày kết thúc dự kiến = buổi cuối (R-LOP-09)');
select is((select array_agg(session_no order by session_date)::text from app.class_session where class_id = pg_temp.c('a')), '{1,2,3,4,5,6}', 'Số buổi đánh 1..6 theo ngày');
select is((select teacher_id from app.class_session where class_id = pg_temp.c('a') order by session_date limit 1), pg_temp.uid('gv1'), 'Buổi lấy giáo viên từ khung giờ');
select is(pg_temp.op_status(pg_temp.c('a')), 'CHUA_KHAI_GIANG', 'Tình trạng vận hành: Chưa khai giảng khi chưa có buổi Done (R-LOP-05)');
select is(pg_temp.op_status(pg_temp.c('ns')), null, 'Trước Đã duyệt tình trạng vận hành hiện "—" (R-LOP-05)');

-- R-LOP-02: lớp Đã duyệt chỉ sửa CSKH phụ trách và sĩ số.
select is(pg_temp.err($$select app.save_class_info(pg_temp.c('a'), '{"total_sessions": 10}')$$), 'HMT_LOP_DA_KHOA', 'Chặn: lớp đã duyệt không sửa số buổi (R-LOP-02)');
select lives_ok($$select app.save_class_info(pg_temp.c('a'), '{"max_students": 12}')$$, 'Đúng: lớp đã duyệt vẫn sửa được sĩ số tối đa (R-LOP-02)');
select is((select max_students from app.class where id = pg_temp.c('a')), 12, 'Sĩ số tối đa đã đổi');

-- R-LOP-10: đổi Time Table lớp Đã duyệt: ngày áp dụng không sớm hơn hôm nay; xem trước; sinh lại.
select is(pg_temp.err($$select app.save_class_timetable(pg_temp.c('a'), jsonb_build_array(jsonb_build_object('weekday', 3, 'start_time', '17:00',
  'end_time', '18:30', 'repeat_weeks', 1, 'first_date', pg_temp.mon() + 2)), current_date - 1)$$), 'HMT_LOP_NGAY_AP_DUNG_SAI', 'Chặn: ngày áp dụng sớm hơn hôm nay (R-LOP-10)');
-- Xem trước: 6 buổi Nháp từ mon()+28 trở đi là 3 buổi (mon+28, +35, +42); không ghi gì.
select is(app.save_class_timetable(pg_temp.c('a'), jsonb_build_array(jsonb_build_object('weekday', 3, 'start_time', '17:00',
  'end_time', '18:30', 'repeat_weeks', 1, 'first_date', pg_temp.mon() + 30)), pg_temp.mon() + 28, true) ->> 'replaced', '3', 'Xem trước: 3 buổi chưa diễn ra bị đổi (R-LOP-10)');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('a') and status_code = 'NHAP'), 6, 'Xem trước không ghi gì');
-- Một buổi đã chỉnh lẻ tay thì giữ nguyên.
select pg_temp.sudo($$update app.class_session set is_manual = true where class_id = pg_temp.c('a') and session_date = pg_temp.mon() + 35$$);
select is(app.save_class_timetable(pg_temp.c('a'), jsonb_build_array(jsonb_build_object('weekday', 3, 'start_time', '17:00',
  'end_time', '18:30', 'repeat_weeks', 1, 'first_date', pg_temp.mon() + 30)), pg_temp.mon() + 28) ->> 'created', '2',
  'Đúng: sinh lại 2 buổi mới (buổi chỉnh lẻ tay giữ nguyên, tổng vẫn 6 buổi, R-LOP-10)');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('a') and status_code in ('NHAP', 'DA_CHOT', 'DONE')), 6, 'Tổng số buổi đang sống vẫn đúng 6');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('a') and status_code = 'DA_THAY'), 2, 'Buổi cũ bị thay chuyển DA_THAY, không xoá cứng');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('a') and session_date = pg_temp.mon() + 35 and status_code = 'NHAP'), 1, 'Buổi chỉnh lẻ tay còn nguyên');
select is((select count(*)::int from app.class_slot where class_id = pg_temp.c('a') and is_active), 1, 'Chỉ còn một khung giờ đang dùng');

-- ================= Huỷ, đóng (R-LOP-04) =================
select pg_temp.sudo($$update app.class_session set status_code = 'DONE' where class_id = pg_temp.c('a') and session_no = 1$$);
select is(pg_temp.op_status(pg_temp.c('a')), 'DANG_HOC', 'Tình trạng vận hành: Đang học khi có buổi Done (R-LOP-05)');
select is(pg_temp.err($$select app.transition_class(pg_temp.c('a'), 'HUY')$$), 'HMT_LOP_DA_CO_BUOI_DONE', 'Chặn: huỷ lớp đã có buổi Done (R-LOP-04)');
select is((app.transition_class(pg_temp.c('a'), 'DA_DONG')) ->> 'to', 'DA_DONG', 'Đúng: đóng lớp khi không còn học sinh còn giờ (R-LOP-04)');
select is(pg_temp.op_status(pg_temp.c('a')), 'DA_KET_THUC', 'Tình trạng vận hành: Đã kết thúc khi lớp Đã đóng (R-LOP-05)');
select is(pg_temp.err($$select app.save_class_timetable(pg_temp.c('a'), '[]'::jsonb)$$), 'HMT_LOP_DA_KHOA', 'Chặn: lớp đã đóng không sửa Time Table');

-- Huỷ lớp chưa có buổi Done: các buổi chưa Done chuyển Huỷ không tính phí.
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select pg_temp.mk('h', pg_temp.data());
select is((app.transition_class(pg_temp.c('h'), 'HUY')) ->> 'to', 'HUY', 'Đúng: Nháp huỷ được, người có quyền Sửa bấm được');
select pg_temp.mk('h2', pg_temp.data());
select app.transition_class(pg_temp.c('h2'), 'DA_TRINH');
select is(pg_temp.err($$select app.transition_class(pg_temp.c('h2'), 'HUY')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH không huỷ lớp đã trình (cần quyền Huỷ)');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.transition_class(pg_temp.c('h2'), 'DA_XAC_NHAN');
select app.transition_class(pg_temp.c('h2'), 'DA_DUYET');
select is((app.transition_class(pg_temp.c('h2'), 'HUY')) ->> 'to', 'HUY', 'Đúng: quản lý cơ sở huỷ lớp đã duyệt chưa có buổi Done (R-LOP-04)');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('h2') and status_code <> 'HUY_KHONG_PHI'), 0, 'Huỷ lớp: các buổi chưa Done thành Huỷ không tính phí');

-- ================= Nhóm lớp (R-LOP-14) và lặp 2 tuần (R-LOP-13) =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
create temp table gr (id uuid);
grant all on gr to public;
insert into gr select app.create_class_group(pg_temp.cs('CS1'), 'K08', '8M1');
-- Hai lớp DAI và HINH cùng thứ, giờ, lặp mỗi 2 tuần, ngày buổi đầu cách nhau một tuần: luân phiên.
create function pg_temp.dh(p_subj text, p_first date) returns jsonb language sql stable as $$
  select pg_temp.data(jsonb_build_object('subject_code', p_subj, 'group_id', (select id from gr), 'total_sessions', 4,
    'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 2, 'first_date', p_first)))) $$;
grant execute on function pg_temp.dh(text, date) to public;
select lives_ok($$select pg_temp.mk('dai', pg_temp.dh('DAI', pg_temp.mon()))$$, 'Đúng: tạo lớp DAI gắn nhóm (R-LOP-14)');
select lives_ok($$select pg_temp.mk('hinh', pg_temp.dh('HINH', pg_temp.mon() + 7))$$, 'Đúng: tạo lớp HINH cùng nhóm (R-LOP-14)');
select is(pg_temp.err($$select pg_temp.mk('x', pg_temp.dh('DAI', pg_temp.mon()))$$), 'HMT_LOP_NHOM_TRUNG_MON', 'Chặn: nhóm đã có một lớp DAI (R-LOP-14)');
select is(pg_temp.err($$select pg_temp.mk('x', pg_temp.data(jsonb_build_object('group_id', (select id from gr))))$$), 'HMT_LOP_NHOM_SAI', 'Chặn: lớp TOAN không vào nhóm Đại, Hình (R-LOP-14)');
select is(pg_temp.err($$select pg_temp.mk('x', pg_temp.dh('DAI', pg_temp.mon()) || jsonb_build_object('grade_code', 'K09'))$$), 'HMT_LOP_NHOM_SAI', 'Chặn: lớp khác khối với nhóm (R-LOP-14)');
select is(pg_temp.err($$select app.create_class_group(pg_temp.cs('CS5'), 'K08')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH CS1 không tạo nhóm lớp ở CS5');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select app.transition_class(pg_temp.c('dai'), 'DA_TRINH');
select app.transition_class(pg_temp.c('dai'), 'DA_XAC_NHAN');
select app.transition_class(pg_temp.c('dai'), 'DA_DUYET');
select app.transition_class(pg_temp.c('hinh'), 'DA_TRINH');
select app.transition_class(pg_temp.c('hinh'), 'DA_XAC_NHAN');
select app.transition_class(pg_temp.c('hinh'), 'DA_DUYET');
-- Luân phiên: cách nhau 14 ngày mỗi lớp, hai lớp lệch một tuần: không có ngày nào trùng (không bị coi là trùng, R-LOP-08).
select is((select count(*)::int from app.class_session a join app.class_session b on a.session_date = b.session_date
            where a.class_id = pg_temp.c('dai') and b.class_id = pg_temp.c('hinh')), 0, 'Đúng: lớp luân phiên Đại, Hình không buổi nào trùng ngày (R-LOP-13)');
select is((select (array_agg(session_date order by session_date))[2] - (array_agg(session_date order by session_date))[1] from app.class_session where class_id = pg_temp.c('dai')),
          14, 'Lặp mỗi 2 tuần: hai buổi liên tiếp cách 14 ngày (R-LOP-13)');
select is(jsonb_array_length(pg_temp.class_clash_warnings(pg_temp.c('dai'))), 0, 'Hai lớp luân phiên không cảnh báo trùng (R-LOP-08)');

-- ================= RLS: đọc theo phạm vi, ghi chỉ qua hàm =================
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select ok((select count(*) from app.class where id = pg_temp.c('a')) = 1, 'Giáo viên được phân công thấy lớp của mình (R-GV-08)');
select ok((select count(*) from app.class_session where class_id = pg_temp.c('a')) > 0, 'Giáo viên được phân công thấy buổi của lớp mình');
select pg_temp.claims(pg_temp.uid('gv2'), 'aal1');
select is((select count(*)::int from app.class where id = pg_temp.c('a')), 0, 'Giáo viên không được phân công không thấy lớp (R-GV-08)');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('a')), 0, 'Giáo viên không được phân công không thấy buổi');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is((select count(*)::int from app.class where id = pg_temp.c('a')), 1, 'Tuyển sinh thấy lớp cơ sở mình');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((select count(*)::int from app.class where id = pg_temp.c('a')), 0, 'Trưởng cơ sở CS5 không thấy lớp CS1');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((select count(*)::int from app.class where id = pg_temp.c('a')), 1, 'Admin thấy lớp mọi cơ sở');
select is(pg_temp.err($$insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
  values ('X', pg_temp.cs('CS1'), '2627', 'TOAN', 'K08', 'CB', 'A', current_date, 1)$$), '42501', 'Chặn: không ghi thẳng vào bảng lớp, chỉ qua hàm nghiệp vụ');

select * from finish();
rollback;
