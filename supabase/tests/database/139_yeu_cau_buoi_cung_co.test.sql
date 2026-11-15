-- Yêu cầu buổi củng cố (migration 139): BUOI-08 tạo, BUOI-10 duyệt. Luật: R-BUOI-04, R-BUOI-10, R-BUOI-01, R-LOP-08, R-HT-01, R-HT-04. Dữ liệu giả; ngày tính từ hôm nay.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d1c.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d1c.hoamatoan.invalid', (select id from app.branch where code = v.cs), false
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
grant execute on all functions in schema pg_temp to public;

-- Từ đây chạy với vai trò đăng nhập thật (RLS và quyền gọi hàm có hiệu lực).

-- Lớp tương lai đã duyệt (mkclass: thứ Hai, 3 buổi từ thứ Hai 2 tuần sau), giáo viên gv1.
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.mkclass('f', 'CB', pg_temp.fut(), 3);
create function pg_temp.req(p_key text) returns uuid language sql stable security definer as $$ select id from app.session_request where note = p_key $$;

-- ================= Cờ phân hệ YEU_CAU_BUOI mặc định tắt =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.save_session_request(null, pg_temp.c('f'), pg_temp.fut() + 3, '18:00', '19:30', null, 'a')$$), 'HMT_TINH_NANG_TAT', 'Cờ tắt: không tạo được yêu cầu buổi (mặc định tắt)');
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'YEU_CAU_BUOI', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

-- ================= Tạo, gửi duyệt (BUOI-08) =================
select ok((app.save_session_request(null, pg_temp.c('f'), pg_temp.fut() + 3, '18:00', '19:30', null, 'a') ->> 'code') ~ '^YB-CS1-\d{4}-\d{4}$', 'Tạo yêu cầu: mã YB-CS1-YYMM-số');
select is((select status_code from app.session_request where note = 'a'), 'NHAP', 'Yêu cầu mới ở Nháp');
select is(pg_temp.err($$select app.save_session_request(null, pg_temp.c('f'), pg_temp.fut() + 3, '19:30', '18:00', null, 'x')$$), 'HMT_BUOI_GIO_SAI', 'Chặn: giờ kết thúc không sau giờ bắt đầu');
select is(pg_temp.err($$select app.save_session_request(null, pg_temp.c('f'), null, '18:00', '19:30', null, 'x')$$), 'HMT_THIEU_NGAY_GIO', 'Chặn: thiếu ngày');
select lives_ok($$select app.save_session_request(pg_temp.req('a'), pg_temp.c('f'), pg_temp.fut() + 3, '18:30', '20:00', null, 'a')$$, 'Sửa yêu cầu Nháp được');
select is((select start_time::text from app.session_request where note = 'a'), '18:30:00', 'Giờ đã sửa');
select lives_ok($$select app.submit_session_request(pg_temp.req('a'))$$, 'Gửi duyệt');
select is((select status_code from app.session_request where note = 'a'), 'CHO_DUYET', 'Chờ duyệt');
select is(pg_temp.err($$select app.submit_session_request(pg_temp.req('a'))$$), 'HMT_SAI_TRANG_THAI', 'Chặn: gửi duyệt lần hai');
select is(pg_temp.err($$select app.save_session_request(pg_temp.req('a'), pg_temp.c('f'), pg_temp.fut() + 3, '18:00', '19:30', null, 'a')$$), 'HMT_SAI_TRANG_THAI', 'Chặn: sửa yêu cầu đã gửi duyệt');
select is(pg_temp.err($$select app.approve_session_request(pg_temp.req('a'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH không duyệt (R-BUOI-10: quản lý cơ sở duyệt)');

-- ================= Duyệt: chèn buổi, đánh lại số buổi (R-BUOI-04) =================
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is(pg_temp.err($$select app.approve_session_request(pg_temp.req('a'))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở khác cơ sở không duyệt');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('f') and status_code <> 'DA_THAY'), 3, 'Trước duyệt: lớp có 3 buổi');
select ok((app.approve_session_request(pg_temp.req('a')) ->> 'session_id') is not null, 'Duyệt: trả mã buổi vừa chèn');
select is((select status_code from app.session_request where note = 'a'), 'DA_DUYET', 'Yêu cầu Đã duyệt');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('f') and status_code <> 'DA_THAY'), 4, 'Sau duyệt: lớp có 4 buổi');
select is((select type_code from app.class_session where id = (select created_session_id from app.session_request where note = 'a')), 'CUNG_CO', 'Buổi chèn là loại Củng cố (trừ giờ, R-BUOI-01)');
select is((select status_code from app.class_session where id = (select created_session_id from app.session_request where note = 'a')), 'NHAP', 'Buổi chèn ở Nháp, chờ chốt danh sách');
select is((select teacher_id from app.class_session where id = (select created_session_id from app.session_request where note = 'a')), pg_temp.uid('gv1'), 'Giáo viên lấy theo khung giờ của lớp');
select is((select array_agg(session_no order by session_date, start_time) from app.class_session where class_id = pg_temp.c('f') and status_code <> 'DA_THAY'), array[1, 2, 3, 4], 'Số buổi đánh lại liên tục theo ngày (nhãn bài dời)');
select is(pg_temp.err($$select app.approve_session_request(pg_temp.req('a'))$$), 'HMT_SAI_TRANG_THAI', 'Chặn: duyệt lần hai');

-- ================= Từ chối (R-HT-04) =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.submit_session_request((app.save_session_request(null, pg_temp.c('f'), pg_temp.fut() + 4, '18:00', '19:30', null, 'b') ->> 'id')::uuid);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.reject_session_request(pg_temp.req('b'), 'KHAC', null)$$), 'HMT_CAN_GHI_CHU', 'Chặn: lý do Khác bắt ghi chú');
select is(pg_temp.err($$select app.reject_session_request(pg_temp.req('b'), 'SAI_SO_TIEN', null)$$), 'HMT_LY_DO_KHONG_AP_DUNG', 'Chặn: lý do chỉ áp dụng cho phiếu thu');
select lives_ok($$select app.reject_session_request(pg_temp.req('b'), 'KHONG_XEP_DUOC_LICH', 'Phòng kín lịch')$$, 'Từ chối kèm lý do');
select is((select status_code from app.session_request where note = 'b'), 'TU_CHOI', 'Yêu cầu Từ chối');
select is((select count(*)::int from app.class_session where class_id = pg_temp.c('f') and status_code <> 'DA_THAY'), 4, 'Từ chối không chèn buổi');

-- ================= Ngày đã qua, huỷ =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.submit_session_request((app.save_session_request(null, pg_temp.c('f'), current_date - 1, '18:00', '19:30', null, 'c') ->> 'id')::uuid);
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is(pg_temp.err($$select app.approve_session_request(pg_temp.req('c'))$$), 'HMT_NGAY_BUOI_QUA_KHU', 'Chặn: duyệt buổi có ngày đã qua');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select lives_ok($$select app.cancel_session_request(pg_temp.req('c'))$$, 'Huỷ yêu cầu Chờ duyệt');
select is((select status_code from app.session_request where note = 'c'), 'HUY', 'Yêu cầu Huỷ');
select is(pg_temp.err($$select app.cancel_session_request(pg_temp.req('a'))$$), 'HMT_SAI_TRANG_THAI', 'Chặn: huỷ yêu cầu đã duyệt');

-- ================= Danh sách (BUOI-10) =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select is((app.list_session_requests('{}'::jsonb) ->> 'total')::int, 3, 'Danh sách: 3 yêu cầu của cơ sở');
select is((app.list_session_requests('{"status": ["TU_CHOI"]}'::jsonb) ->> 'total')::int, 1, 'Lọc theo tình trạng Từ chối');
select is((app.list_session_requests('{}'::jsonb) -> 'rows' -> 0 ->> 'code') ~ '^YB-CS1-', true, 'Dòng có mã YB');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.list_session_requests('{"status": ["DA_DUYET"]}'::jsonb) -> 'rows' -> 0 ->> 'can_approve', 'false', 'CSKH không có quyền duyệt: can_approve false');
select pg_temp.claims(pg_temp.uid('bm5'), 'aal1');
select is((app.list_session_requests('{}'::jsonb) ->> 'total')::int, 0, 'Trưởng cơ sở khác cơ sở không thấy yêu cầu của CS1');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.list_session_requests('{}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Giáo viên không xem yêu cầu buổi');
select is(has_function_privilege('anon', 'app.approve_session_request(uuid)', 'execute'), false, 'Người chưa đăng nhập không duyệt được');

select * from finish();
rollback;
