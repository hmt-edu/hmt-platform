-- Dữ liệu GIẢ NHỎ riêng cho ảnh hướng dẫn (npm run chup-anh, E36): một lớp ở CS5 do giáo viên giả gv.cs5 dạy, có buổi HÔM NAY (Đã chốt danh sách) và ba em đang học.
-- KHÔNG chạy ở thử nghiệm hay chạy thật, KHÔNG dữ liệu thật: tên ghép giả, SĐT 0997xxxxxx giả. Cần: npm run db:reset rồi npm run db:seed-users. Chạy lại sẽ báo lỗi (đã có).
\set ON_ERROR_STOP on
begin;
do $$ begin
  if exists (select from app.class where code like 'LAH%') then raise exception 'Đã có dữ liệu ảnh hướng dẫn (LAH…). Dựng lại bằng npm run db:reset.'; end if;
end $$;

create function pg_temp.claims(p_login text) returns void language plpgsql security definer as $$
declare v_id uuid; v_result jsonb;
begin
  select id into v_id from app.user_account where login_name = p_login || '@thu.hoamatoan.invalid';
  if v_id is null then raise exception 'Không có tài khoản giả %: chạy npm run db:seed-users trước.', p_login; end if;
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', v_id, 'claims', jsonb_build_object('sub', v_id, 'role', 'authenticated', 'aal', 'aal1')));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
grant execute on function pg_temp.claims(text) to public;

-- Vận hành lớp bật ở CS5; phụ huynh và ba học sinh giả ở CS5.
insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code = 'CS5'
  on conflict (module_code, branch_id) do update set enabled = true;
insert into app.parent (code, full_name, phone, branch_id)
select 'PHAH01', 'Phụ huynh ảnh hướng dẫn', '0997000001', id from app.branch where code = 'CS5';
insert into app.student (code, parent_id, full_name, birth_year, branch_id, grade)
select 'HSAH0' || n, (select id from app.parent where code = 'PHAH01'), (array['Nguyễn Minh An', 'Trần Gia Bảo', 'Lê Thu Cúc'])[n], 2012, b.id, 8
  from generate_series(1, 3) n cross join (select id from app.branch where code = 'CS5') b;

-- Lớp: Trưởng cơ sở CS5 tạo và duyệt; giáo viên gv.cs5 dạy; buổi đầu là HÔM NAY (giờ Việt Nam).
create temp table cl (id uuid);
grant all on cl to public;
select pg_temp.claims('truongcs.cs5');
set local role authenticated;
insert into cl select ((app.create_class(jsonb_build_object(
  'branch_id', (select id from app.branch where code = 'CS5'), 'year_code', '2627', 'subject_code', 'TOAN', 'grade_code', 'K08',
  'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0, 'start_date', (now() at time zone 'Asia/Ho_Chi_Minh')::date, 'total_sessions', 4,
  'slots', jsonb_build_array(jsonb_build_object('weekday', extract(isodow from (now() at time zone 'Asia/Ho_Chi_Minh')::date)::int, 'start_time', '18:00', 'end_time', '19:30',
    'repeat_weeks', 1, 'first_date', (now() at time zone 'Asia/Ho_Chi_Minh')::date,
    'teacher_id', (select id from app.user_account where login_name = 'gv.cs5@thu.hoamatoan.invalid')))))) ->> 'id')::uuid;
select app.transition_class((select id from cl), 'DA_TRINH');
select app.transition_class((select id from cl), 'DA_XAC_NHAN');
select app.transition_class((select id from cl), 'DA_DUYET');
reset role;

-- Ghi danh ba em (lùi ngày tạo 60 ngày để vào được danh sách buổi, R-GIO-02), mỗi em 10 giờ; CSKH xếp vào lớp rồi chốt danh sách buổi hôm nay.
create temp table en (id uuid);
grant all on en to public;
do $$
declare s record; v_id uuid;
begin
  for s in select id, parent_id, code from app.student where code like 'HSAH0%' loop
    insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code)
    values ('GDAH' || right(s.code, 1), s.id, s.parent_id, (select id from app.branch where code = 'CS5'), 'TOAN') returning id into v_id;
    alter table app.enrollment disable trigger enrollment_fill_standard;
    update app.enrollment set created_at = now() - interval '60 days' where id = v_id;
    alter table app.enrollment enable trigger enrollment_fill_standard;
    insert into en values (v_id);
    perform app.add_opening_hours(v_id, 10, 'DOT-AH');
  end loop;
end $$;
select pg_temp.claims('cskh.cs5');
set local role authenticated;
select app.assign_enrollment_class(en.id, (select id from cl), (now() at time zone 'Asia/Ho_Chi_Minh')::date) from en;
select app.close_session((select s.id from app.class_session s where s.class_id = (select id from cl) and s.session_no = 1 and s.status_code not in ('HUY_KHONG_PHI', 'DA_THAY')));
reset role;
commit;
