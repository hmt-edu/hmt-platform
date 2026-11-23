-- HT-06 / PH-05: app.portal_schedule (migration 638). Luật: lịch theo lớp đang học và buổi trong điểm danh (bù); không buổi bị thay;
-- quyền riêng theo học sinh/con; khoảng ngày hợp lệ.
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
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.sid(p_code text) returns uuid language plpgsql security definer as $$ begin return (select id from app.student where code = p_code); end $$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả: hs1, hs2 (học sinh), ph1, ph2 (phụ huynh), ph3 (phụ huynh bị khoá), nv (nhân viên) ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('hs1'), ('hs2'), ('ph1'), ('ph2'), ('ph3'), ('nv'), ('hs3');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ht1.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, parent_code, is_locked, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ht1.hoamatoan.invalid', (select id from app.branch where code = 'CS1'),
       case u.key when 'hs1' then 'HS992001' when 'hs2' then 'HS992003' when 'hs3' then 'HS992004' end,
       case u.key when 'ph1' then 'PH992001' when 'ph2' then 'PH992002' when 'ph3' then 'PH992003' end,
       u.key = 'ph3', false
  from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('hs1', 'STUDENT'), ('hs2', 'STUDENT'), ('hs3', 'STUDENT'), ('ph1', 'PARENT'), ('ph2', 'PARENT'), ('ph3', 'PARENT'), ('nv', 'SALES')) as v (key, role) on v.key = u.key;

-- ---------- Dữ liệu: PH992001 có 2 con; lớp LOPHT01 có buổi hôm qua, hôm nay, ngày mai, ngoài khoảng, buổi bị thay, buổi bù ----------
insert into app.parent (code, full_name, phone, branch_id)
select c.code, c.name, c.phone, (select id from app.branch where code = 'CS1')
  from (values ('PH992001', 'Phụ huynh Mẫu Ht Một', '0992100001'), ('PH992002', 'Phụ huynh Mẫu Ht Hai', '0992100002')) as c (code, name, phone);
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = c.ph), c.name, 2012, (select id from app.branch where code = 'CS1')
  from (values ('HS992001', 'PH992001', 'Em Ht Một'), ('HS992002', 'PH992001', 'Em Ht Hai'), ('HS992003', 'PH992002', 'Em Ht Ba')) as c (code, ph, name);
insert into app.feature_flag (module_code, branch_id, enabled)
select 'HOC_TAP', b.id, true from app.branch b where b.code = 'CS1'
on conflict (module_code, branch_id) do update set enabled = true;
insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
select 'LOPHT01', id, '2627', 'TOAN', 'K08', 'CB', 'A', current_date - 30, 10 from app.branch where code = 'CS1';
insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, delivery_mode_code, status_code, purchased_hours, gifted_hours)
select 'GDHT01', st.id, st.parent_id, st.branch_id, 'TOAN', 'OFF', 'DANG_HOC', 24, 0 from app.student st where st.code = 'HS992001';
insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, delivery_mode_code, status_code, purchased_hours, gifted_hours)
select 'GDHT03', st.id, st.parent_id, st.branch_id, 'TOAN', 'OFF', 'DANG_HOC', 24, 0 from app.student st where st.code = 'HS992003';
-- HS992001 học lớp từ 30 ngày trước; HS992003 học lớp khác (không có buổi nào ở LOPHT01).
insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
select e.id, (select id from app.class where code = 'LOPHT01'), e.branch_id, current_date - 30 from app.enrollment e where e.code = 'GDHT01';
insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, status_code, type_code)
select (select id from app.class where code = 'LOPHT01'), (select id from app.branch where code = 'CS1'), v.no, current_date + v.d, '18:00', '19:30', v.st, v.ty
  from (values (1, -1, 'DONE', 'CHINH'), (2, 0, 'DA_CHOT', 'CHINH'), (3, 1, 'NHAP', 'CHINH'), (4, 20, 'NHAP', 'CHINH'), (5, 2, 'DA_THAY', 'CHINH')) as v (no, d, st, ty);
-- Buổi bù của lớp khác: HS992002 có tên trong điểm danh (không thuộc lớp nào), HS992001 không.
insert into app.class (code, branch_id, year_code, subject_code, grade_code, class_type_code, level_code, start_date, total_sessions)
select 'LOPHT02', id, '2627', 'TOAN', 'K08', 'CB', 'A', current_date - 30, 10 from app.branch where code = 'CS1';
insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, status_code, type_code)
select (select id from app.class where code = 'LOPHT02'), (select id from app.branch where code = 'CS1'), 1, current_date + 1, '10:00', '11:30', 'NHAP', 'HOC_BU';
insert into app.session_attendance (session_id, class_id, branch_id, student_id)
select cs.id, cs.class_id, cs.branch_id, (select id from app.student where code = 'HS992002') from app.class_session cs where cs.type_code = 'HOC_BU';

-- ===== Luật: lịch của học sinh theo lớp đang học =====
select pg_temp.claims(pg_temp.uid('hs1'));
set local role authenticated;
select is(jsonb_array_length(app.portal_schedule(pg_temp.sid('HS992001'), current_date - 7, current_date + 7) -> 'rows'), 3, 'Lịch HS: ba buổi trong khoảng (hôm qua, hôm nay, mai); không có buổi ngoài khoảng, buổi bị thay, buổi bù của em khác');
select is(app.portal_schedule(pg_temp.sid('HS992001'), current_date - 7, current_date + 7) -> 'rows' -> 0 ->> 'class_code', 'LOPHT01', 'Lịch HS: có mã lớp, sắp theo ngày');
select is(jsonb_array_length(app.portal_schedule(pg_temp.sid('HS992001'), current_date + 10, current_date + 30) -> 'rows'), 1, 'Lịch HS: khoảng khác thấy buổi của khoảng đó');
select is(jsonb_array_length(app.portal_schedule(pg_temp.sid('HS992001'), current_date + 100, current_date + 120) -> 'rows'), 0, 'Lịch HS: khoảng không có buổi trả mảng rỗng');
select is(pg_temp.err($$select app.portal_schedule(pg_temp.sid('HS992001'), current_date, current_date - 1)$$), 'HMT_KHOANG_NGAY_SAI', 'Khoảng ngày đảo ngược bị chặn');
select is(pg_temp.err($$select app.portal_schedule(pg_temp.sid('HS992002'), current_date, current_date + 1)$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: học sinh xem lịch anh em bị chặn');
reset role;

-- ===== Luật: phụ huynh xem lịch con; buổi bù theo danh sách điểm danh =====
select pg_temp.claims(pg_temp.uid('ph1'));
set local role authenticated;
select is(jsonb_array_length(app.portal_schedule(pg_temp.sid('HS992001'), current_date - 7, current_date + 7) -> 'rows'), 3, 'Lịch PH: xem được lịch con thứ nhất');
select is((app.portal_schedule(pg_temp.sid('HS992002'), current_date - 7, current_date + 7) -> 'rows' -> 0 ->> 'is_makeup')::boolean, true, 'Lịch PH: buổi bù hiện khi con có tên trong điểm danh, đánh dấu is_makeup');
select is(jsonb_array_length(app.portal_schedule(pg_temp.sid('HS992002'), current_date - 7, current_date + 7) -> 'rows'), 1, 'Lịch PH: con chưa xếp lớp chỉ thấy buổi bù của mình');
select is(pg_temp.err($$select app.portal_schedule(pg_temp.sid('HS992003'), current_date, current_date + 1)$$), 'HMT_KHONG_CO_QUYEN', 'Luật quyền riêng: phụ huynh xem lịch con nhà khác bị chặn');
reset role;
select pg_temp.claims(pg_temp.uid('nv'));
set local role authenticated;
select is(pg_temp.err($$select app.portal_schedule(pg_temp.sid('HS992001'), current_date, current_date + 1)$$), 'HMT_KHONG_CO_QUYEN', 'Nhân viên gọi hàm lịch cổng bị chặn');
reset role;

select * from finish();
rollback;
