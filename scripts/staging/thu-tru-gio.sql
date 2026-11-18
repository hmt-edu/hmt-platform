-- THỬ TRỪ GIỜ trên staging (phiếu dieu-phoi-kit#274, kịch bản T2/T8). Toàn bộ bọc trong một giao dịch và HOÀN TÁC ở cuối: không để lại gì.
-- Dữ liệu GIẢ dựng ngay trong giao dịch (người dùng, phụ huynh, học sinh, lớp, ghi danh, buổi); chỉ dùng cơ sở CS1 và danh mục có sẵn.
-- Chạy: psql "$STAGING_DB_URL" -X -v ON_ERROR_STOP=1 -f scripts/staging/thu-tru-gio.sql. Lệch luật thì dừng với lỗi (mã thoát khác 0), log in ĐẠT/KHÔNG ĐẠT.
-- Luật: R-GIO-01 (có tên trong danh sách + buổi Done thì trừ, dù vắng hay đi muộn), R-GIO-04 (trừ đúng một lần), R-GIO-06 (tự Done), R-BUOI-01, R-BUOI-03 (học bù không trừ).
-- Chỉ in số, mã, trạng thái và tên giả "Em giả"; không in chuỗi kết nối. Người dùng giả dùng miền .invalid.
\pset pager off
begin;

create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('cskh1'), ('gv1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', 'ktg-' || key || '@kiem-staging.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, 'ktg-' || u.key || '@kiem-staging.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('cskh1', 'CSKH'), ('gv1', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS1'
  on conflict (module_code, branch_id) do update set enabled = true$$);

create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs1() returns uuid language sql stable security definer as $$ select id from app.branch where code = 'CS1' $$;
create function pg_temp.past() returns date language sql stable as $$ select (date_trunc('week', current_date) - interval '28 days')::date $$;
create temp table cl (id uuid);
grant all on cl to public;
create temp table en (key text primary key, id uuid);
grant all on en to public;
create function pg_temp.e(p_key text) returns uuid language sql stable as $$ select id from en where key = p_key $$;
create function pg_temp.st(p_n integer) returns uuid language sql stable security definer as $$ select id from app.student where code = 'KTG0' || p_n $$;
create function pg_temp.s(p_n integer) returns uuid language sql stable security definer as $$
  select id from app.class_session where class_id = (select id from cl) and session_no = p_n and type_code = 'CHINH' and status_code not in ('HUY_KHONG_PHI', 'DA_THAY') $$;
-- Ghi danh giả: lùi ngày tạo 60 ngày (tắt tạm trigger điền cột chuẩn) để vào được danh sách buổi quá khứ (R-GIO-02); 10 giờ đầu kỳ.
create function pg_temp.mke(p_key text, p_n integer) returns void language plpgsql security definer as $$
declare v_id uuid;
begin
  insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code)
  values ('KTGGD' || p_key, pg_temp.st(p_n), (select parent_id from app.student where id = pg_temp.st(p_n)), pg_temp.cs1(), 'TOAN')
  returning id into v_id;
  alter table app.enrollment disable trigger enrollment_fill_standard;
  update app.enrollment set created_at = now() - interval '60 days' where id = v_id;
  alter table app.enrollment enable trigger enrollment_fill_standard;
  insert into en values (p_key, v_id);
  perform app.add_opening_hours(v_id, 10, 'DOT-KTG');
end $$;
create temp table truoc (buoi text, k text, h numeric, primary key (buoi, k));
grant all on truoc to public;
create temp table kq (muc text, dat boolean, ghi_chu text);
grant all on kq to public;
grant execute on all functions in schema pg_temp to public;

set local role authenticated;
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('KTGPH1', 'Phụ huynh giả', '0900990001', pg_temp.cs1())$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'KTG0' || n, (select id from app.parent where code = 'KTGPH1'), 'Em giả ' || n, 2012, pg_temp.cs1() from generate_series(1, 4) n$$);

-- Lớp 4 buổi thứ Hai bắt đầu 4 tuần trước (buổi quá khứ để Done được), 18:00 đến 19:30 = 1,5 giờ mỗi buổi.
select pg_temp.claims(pg_temp.uid('bm1'), 'aal1');
select pg_temp.sudo($$insert into cl select (app.create_class(jsonb_build_object('branch_id', pg_temp.cs1(), 'year_code', '2627', 'subject_code', 'TOAN', 'grade_code', 'K08',
    'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0, 'start_date', pg_temp.past(), 'total_sessions', 4,
    'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
                                                  'first_date', pg_temp.past(), 'teacher_id', pg_temp.uid('gv1'))))) ->> 'id')::uuid$$);
select app.transition_class((select id from cl), 'DA_TRINH');
select app.transition_class((select id from cl), 'DA_XAC_NHAN');
select app.transition_class((select id from cl), 'DA_DUYET');
select pg_temp.sudo($$select pg_temp.mke('a', 1)$$);
select pg_temp.sudo($$select pg_temp.mke('b', 2)$$);
select pg_temp.sudo($$select pg_temp.mke('c', 3)$$);
select pg_temp.sudo($$select pg_temp.mke('d', 4)$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.assign_enrollment_class(pg_temp.e(k), (select id from cl), pg_temp.past()) from (values ('a'), ('b'), ('c'), ('d')) v (k);

\echo === Cấu hình đang dùng trên staging
select app.get_setting('session_done_requires_review') as session_done_requires_review, app.session_hours(pg_temp.s(1)) as gio_moi_buoi_chinh;

\echo === 1. Buổi CHÍNH: 4 em Có mặt, Vắng có phép, Vắng không phép, Đi muộn
select app.close_session(pg_temp.s(1)) as so_em_trong_danh_sach;
select pg_temp.sudo($$insert into truoc select 'chinh', k, app.enrollment_hours_balance(pg_temp.e(k)) from (values ('a'), ('b'), ('c'), ('d')) v (k)$$);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select app.set_attendance_teacher(pg_temp.s(1), jsonb_build_array(
  jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT'),
  jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'VANG_CO_PHEP'),
  jsonb_build_object('student_id', pg_temp.st(3), 'status_code', 'VANG_KHONG_PHEP'),
  jsonb_build_object('student_id', pg_temp.st(4), 'status_code', 'DI_MUON'))) as so_dong_diem_danh;
select app.session_pending_reason(pg_temp.s(1)) as ly_do_chua_done_truoc_noi_dung;
-- Buổi thường cần ít nhất một dòng nội dung mới Done (Q-231).
select pg_temp.sudo($$insert into app.session_content_line (session_id, branch_id, sort_order, line_text) select s.id, s.branch_id, 1, 'Nội dung buổi giả' from app.class_session s where s.id = pg_temp.s(1)$$);
select pg_temp.sudo($$select app.auto_complete_sessions()$$);
select status_code as tinh_trang_buoi from app.class_session where id = pg_temp.s(1);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select v.k as em, sa.teacher_status_code as diem_danh, t.h as gio_truoc, app.enrollment_hours_balance(pg_temp.e(v.k)) as gio_sau,
       app.enrollment_hours_balance(pg_temp.e(v.k)) - t.h as chenh
  from (values ('a', 1), ('b', 2), ('c', 3), ('d', 4)) v (k, n)
  join truoc t on t.buoi = 'chinh' and t.k = v.k
  join app.session_attendance sa on sa.session_id = pg_temp.s(1) and sa.student_id = pg_temp.st(v.n)
 order by v.k;
select pg_temp.sudo($$insert into kq select 'Buổi chính: cả 4 em bị trừ đúng 1,5 giờ (R-GIO-01)',
  (select count(*) = 4 and bool_and(app.enrollment_hours_balance(pg_temp.e(t.k)) - t.h = -1.5) from truoc t where t.buoi = 'chinh'), null$$);
select pg_temp.sudo($$insert into kq select 'Buổi chính: đúng 4 dòng trừ buổi trong sổ giờ, mỗi em một dòng (R-GIO-04)',
  (select count(*) = 4 and count(distinct enrollment_id) = 4 from app.hour_ledger where session_id = pg_temp.s(1) and entry_type = 'TRU_BUOI'), null$$);
select pg_temp.sudo($$insert into kq select 'Buổi chính sang DONE bằng auto_complete_sessions (R-GIO-06)',
  (select status_code = 'DONE' from app.class_session where id = pg_temp.s(1)), null$$);

\echo === 2. Buổi HỌC BÙ (loại HOC_BU chèn vào lớp), cả 4 em Có mặt
select pg_temp.sudo($$insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, type_code, status_code)
  select class_id, branch_id, 99, session_date + 1, start_time, end_time, teacher_id, 'HOC_BU', 'NHAP' from app.class_session where id = pg_temp.s(1)$$);
create temp table bu (id uuid);
grant all on bu to public;
select pg_temp.sudo($$insert into bu select id from app.class_session where class_id = (select id from cl) and type_code = 'HOC_BU'$$);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select app.close_session((select id from bu)) as so_em_trong_danh_sach_hoc_bu;
select pg_temp.sudo($$insert into truoc select 'hocbu', k, app.enrollment_hours_balance(pg_temp.e(k)) from (values ('a'), ('b'), ('c'), ('d')) v (k)$$);
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select app.set_attendance_teacher((select id from bu), jsonb_build_array(
  jsonb_build_object('student_id', pg_temp.st(1), 'status_code', 'CO_MAT'), jsonb_build_object('student_id', pg_temp.st(2), 'status_code', 'CO_MAT'),
  jsonb_build_object('student_id', pg_temp.st(3), 'status_code', 'CO_MAT'), jsonb_build_object('student_id', pg_temp.st(4), 'status_code', 'CO_MAT'))) as so_dong_diem_danh;
select pg_temp.sudo($$insert into app.session_content_line (session_id, branch_id, sort_order, line_text) select s.id, s.branch_id, 1, 'Học bù' from app.class_session s where s.id = (select id from bu)$$);
select pg_temp.sudo($$select app.auto_complete_sessions()$$);
select status_code as tinh_trang_buoi_hoc_bu from app.class_session where id = (select id from bu);
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select v.k as em, t.h as gio_truoc, app.enrollment_hours_balance(pg_temp.e(v.k)) as gio_sau, app.enrollment_hours_balance(pg_temp.e(v.k)) - t.h as chenh
  from (values ('a'), ('b'), ('c'), ('d')) v (k) join truoc t on t.buoi = 'hocbu' and t.k = v.k order by v.k;
select pg_temp.sudo($$insert into kq select 'Buổi học bù sang DONE và không trừ giờ ai (R-BUOI-03)',
  (select (select status_code = 'DONE' from app.class_session where id = (select id from bu))
      and (select count(*) = 4 and bool_and(app.enrollment_hours_balance(pg_temp.e(t.k)) = t.h) from truoc t where t.buoi = 'hocbu')
      and not exists (select from app.hour_ledger where session_id = (select id from bu) and entry_type = 'TRU_BUOI')), null$$);

\echo === 3. Tự Done chạy lần hai: không trừ thêm
select pg_temp.sudo($$select app.auto_complete_sessions()$$);
select pg_temp.sudo($$insert into kq select 'Chạy tự Done lần hai không trừ thêm giờ (R-GIO-04)',
  (select count(*) = 4 and bool_and(app.enrollment_hours_balance(pg_temp.e(t.k)) = t.h) from truoc t where t.buoi = 'hocbu')
  and (select count(*) = 4 from app.hour_ledger where session_id = pg_temp.s(1) and entry_type = 'TRU_BUOI'), null$$);

\echo === KẾT QUẢ
select case when dat then 'ĐẠT' else 'KHÔNG ĐẠT' end as ket_qua, muc from kq order by dat, muc;
select bool_and(dat) as tat_ca_dat from kq \gset
\if :tat_ca_dat
\echo KẾT LUẬN: ĐẠT (không lệch luật). Hoàn tác toàn bộ dữ liệu thử.
\else
\echo KẾT LUẬN: KHÔNG ĐẠT: có dòng lệch luật ở bảng trên. Hoàn tác toàn bộ dữ liệu thử.
\endif
rollback;

\echo === Kiểm sau hoàn tác: không còn dữ liệu thử
select (select count(*) from auth.users where email like 'ktg-%@kiem-staging.invalid') as nguoi_dung_thu_con_lai,
       (select count(*) from app.student where code like 'KTG0%') as hoc_sinh_thu_con_lai,
       (select count(*) from app.enrollment where code like 'KTGGD%') as ghi_danh_thu_con_lai;
\if :tat_ca_dat
\else
-- Cố ý gây lỗi để psql (ON_ERROR_STOP) thoát với mã khác 0: lượt chạy báo đỏ. Dữ liệu thử đã hoàn tác ở trên.
do $$ begin raise exception 'KHÔNG ĐẠT: có dòng lệch luật'; end $$;
\endif
