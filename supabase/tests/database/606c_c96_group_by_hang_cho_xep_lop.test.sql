-- C96 (migration 606): Group By GD-06 Hàng chờ xếp lớp (enrollment_queue_group_counts): lý do chờ, hình thức; khớp danh sách; phạm vi cơ sở; chặn trường lạ, Sale. Dựng theo test 113.
-- Luật: R-GD-05 (hàng chờ chỉ Chờ xếp lớp), R-GD-04 (sổ giờ chỉ thêm, hiện mọi dòng), R-GD-18 (chuyển phí kèm mã ticket), R-GV-13 (giáo viên không đọc),
-- phạm vi cơ sở. Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh1'), ('cskh5'), ('sales1'), ('gv1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@gd113.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@gd113.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh5' then 'CS5' else 'CS1' end), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'cskh1' then 'CSKH' when 'cskh5' then 'CSKH' when 'sales1' then 'SALES' else 'TEACHER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS5')
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.cs(p_code text) returns uuid language sql stable security definer as $$ select id from app.branch where code = p_code $$;
grant execute on all functions in schema pg_temp to public;

-- Hồ sơ giả: phụ huynh, 4 học sinh CS1 và 1 học sinh CS5.
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values
  ('PHG113A', 'Phụ huynh giả 113 A', '0900113001', pg_temp.cs('CS1')), ('PHG113B', 'Phụ huynh giả 113 B', '0900113002', pg_temp.cs('CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSG113' || n, (select id from app.parent where code = 'PHG113A'), 'Em giả 113 ' || chr(64 + n), 2012, pg_temp.cs('CS1') from generate_series(1, 4) n$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  values ('HSG1135', (select id from app.parent where code = 'PHG113B'), 'Em giả 113 E', 2012, pg_temp.cs('CS5'))$$);

-- Lớp CS1 (tạo bằng hàm nghiệp vụ) và một buổi để có dòng Trừ buổi.
create temp table cl (id uuid);
grant all on cl to public;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
insert into cl select (app.create_class(jsonb_build_object('branch_id', pg_temp.cs('CS1'), 'year_code', '2627', 'subject_code', 'TOAN', 'grade_code', 'K08',
  'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0, 'start_date', (date_trunc('week', current_date) + interval '14 days')::date, 'total_sessions', 5,
  'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
    'first_date', (date_trunc('week', current_date) + interval '14 days')::date)))) ->> 'id')::uuid;
reset role;
create temp table se (id uuid);
grant all on se to public;
select pg_temp.sudo($$with i as (insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, status_code, type_code)
  values ((select id from cl), pg_temp.cs('CS1'), 7, current_date - 1, '18:00', '19:30', 'DONE', 'CHINH') returning id) insert into se select id from i$$);

-- Ghi danh: A (Chờ xếp lớp, Em A), B (Đang học, có lớp, Em B, có sổ giờ đủ loại), C (Đã xếp lớp, Em C), D (Hoàn phí, Em D), E (CS5, Chờ xếp lớp, Em E).
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, subject_code, delivery_mode_code, status_code, purchased_hours, gifted_hours)
  select v.code, st.id, st.parent_id, st.branch_id, 'TOAN', 'OFF', v.status, v.purch, 0
    from (values ('GD113A', 'HSG1131', 'CHO_XEP_LOP', 24), ('GD113B', 'HSG1132', 'DANG_HOC', 48), ('GD113C', 'HSG1133', 'DA_XEP_LOP', 24),
                 ('GD113D', 'HSG1134', 'HOAN_PHI', 24), ('GD113E', 'HSG1135', 'CHO_XEP_LOP', 24)) v (code, student, status, purch)
    join app.student st on st.code = v.student$$);
create function pg_temp.en(p_code text) returns uuid language sql stable security definer as $$ select id from app.enrollment where code = p_code $$;
grant execute on all functions in schema pg_temp to public;
select pg_temp.sudo($$insert into app.enrollment_class (enrollment_id, class_id, branch_id, start_date)
  select pg_temp.en(c), (select id from cl), pg_temp.cs('CS1'), current_date - 30 from unnest(array['GD113B', 'GD113C']) c$$);
-- Sổ giờ của B: cấp 48, điều chỉnh +2, trừ buổi -2, chuyển phí -4 (kèm mã ticket).
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) values (pg_temp.en('GD113B'), pg_temp.cs('CS1'), 'CAP_MUA', 48)$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, reason_code, note, created_by)
  values (pg_temp.en('GD113B'), pg_temp.cs('CS1'), 'DIEU_CHINH', 2, (select code from app.catalog_item where catalog_code = 'HOURS_ADJUST_REASON' order by sort_order limit 1),
          'Buổi điểm danh nhầm', pg_temp.uid('cskh1'))$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, session_id) values (pg_temp.en('GD113B'), pg_temp.cs('CS1'), 'TRU_BUOI', -2, (select id from se))$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours, source_ref) values (pg_temp.en('GD113B'), pg_temp.cs('CS1'), 'CHUYEN_PHI', -4, 'TK-TEST-0001')$$);
select pg_temp.sudo($$insert into app.hour_ledger (enrollment_id, branch_id, entry_type, hours) values (pg_temp.en('GD113A'), pg_temp.cs('CS1'), 'CAP_MUA', 24), (pg_temp.en('GD113C'), pg_temp.cs('CS1'), 'CAP_MUA', 24)$$);

-- ================= GD-01 danh sách =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((app.enrollment_list('{"q": "GD113"}') ->> 'total')::int, 4, 'Phạm vi cơ sở: CSKH CS1 thấy 4 ghi danh CS1, không thấy ghi danh CS5');
select is((select string_agg(r ->> 'code', ',' order by ord) from jsonb_array_elements(app.enrollment_list('{"q": "GD113"}') -> 'rows') with ordinality t(r, ord)),
  'GD113D,GD113C,GD113B,GD113A', 'Mặc định mới nhất trước (mã giảm dần)');
select is((select string_agg(r ->> 'code', ',' order by ord) from jsonb_array_elements(app.enrollment_list('{"q": "GD113"}', 'code_asc') -> 'rows') with ordinality t(r, ord)),
  'GD113A,GD113B,GD113C,GD113D', 'Sắp xếp theo mã tăng dần');
select is((app.enrollment_list('{"q": "GD113", "status": ["CHO_XEP_LOP"]}') ->> 'total')::int, 1, 'Lọc theo tình trạng Chờ xếp lớp');
select is((app.enrollment_list('{"q": "em giả 113 b"}') -> 'rows' -> 0 ->> 'code'), 'GD113B', 'Tìm theo tên học sinh (không phân biệt hoa thường, dấu)');
select is(jsonb_array_length(app.enrollment_list('{"q": "GD113"}', 'code_asc', 1, 1) -> 'rows'), 1, 'Phân trang: một dòng');
select is((app.enrollment_list('{"q": "GD113"}', 'code_asc', 1, 1) -> 'rows' -> 0 ->> 'code'), 'GD113B', 'Phân trang: bỏ qua một dòng ra dòng thứ hai');
select is((app.enrollment_list('{"q": "GD113"}', 'code_asc', 1, 1) ->> 'total')::int, 4, 'Phân trang: tổng không đổi theo trang');
select is((select (r ->> 'granted_hours')::numeric from jsonb_array_elements(app.enrollment_list('{"q": "GD113B"}') -> 'rows') r), 48.00, 'Giờ cấp = cấp mua + tặng + đầu kỳ (điều chỉnh, chuyển phí không tính)');
select is((select (r ->> 'used_hours')::numeric from jsonb_array_elements(app.enrollment_list('{"q": "GD113B"}') -> 'rows') r), 2.00, 'Đã học = tổng giờ trừ buổi đổi dấu');
select is((select (r ->> 'remaining_hours')::numeric from jsonb_array_elements(app.enrollment_list('{"q": "GD113B"}') -> 'rows') r), 44.00, 'Còn lại = tổng sổ giờ (48 + 2 - 2 - 4)');
select is((select r ->> 'class_code' from jsonb_array_elements(app.enrollment_list('{"q": "GD113B"}') -> 'rows') r), (select code from app.class where id = (select id from cl)),
  'Cột Lớp là lớp đang học');
select is((select r ->> 'class_code' from jsonb_array_elements(app.enrollment_list('{"q": "GD113A"}') -> 'rows') r), null, 'Chưa có lớp thì để trống');
select is((select r ->> 'status_name' from jsonb_array_elements(app.enrollment_list('{"q": "GD113D"}') -> 'rows') r), 'Hoàn phí', 'Tình trạng hiện tên từ danh mục');
select is((app.enrollment_list(('{"q": "GD113", "class_id": "' || (select id from cl) || '"}')::jsonb) ->> 'total')::int, 2, 'Lọc theo lớp hiện tại');
select is((select string_agg(r ->> 'code', ',' order by ord) from jsonb_array_elements(app.enrollment_list('{"q": "GD113"}', 'remaining_desc') -> 'rows') with ordinality t(r, ord)),
  'GD113B,GD113C,GD113A,GD113D', 'Sắp theo giờ còn lại giảm dần (44, 24, 24, 0; cùng số dư xếp mã giảm dần)');
reset role;

select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is((app.enrollment_list('{"q": "GD113"}') ->> 'total')::int, 5, 'Admin (toàn hệ thống) thấy cả ghi danh CS5');
reset role;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
set local role authenticated;
select is((app.enrollment_list('{"q": "GD113"}') ->> 'total')::int, 1, 'CSKH CS5 chỉ thấy ghi danh CS5');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.enrollment_list('{}')$$), 'HMT_KHONG_CO_QUYEN', 'R-GV-13: giáo viên không đọc danh sách ghi danh');
reset role;

-- ================= GD-06 hàng chờ =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((select string_agg(r ->> 'code', ',') from jsonb_array_elements(app.enrollment_queue('{"q": "GD113"}') -> 'rows') r), 'GD113A',
  'R-GD-05: hàng chờ CHỈ gồm Chờ xếp lớp của cơ sở mình (không có Đang học, Đã xếp lớp, Hoàn phí, ghi danh CS5)');
select is((app.enrollment_queue('{"q": "GD113"}') ->> 'total')::int, 1, 'Tổng hàng chờ');
select is((app.enrollment_queue('{"q": "GD113"}') -> 'rows' -> 0 ->> 'waiting_since'), ((now() at time zone 'Asia/Ho_Chi_Minh')::date)::text, 'Chờ từ = ngày tạo ghi danh (giờ Việt Nam)');
reset role;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select is((app.enrollment_queue('{"q": "GD113"}') ->> 'total')::int, 2, 'Admin thấy hàng chờ cả hai cơ sở');
reset role;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.enrollment_queue('{}')$$), 'HMT_KHONG_CO_QUYEN', 'Chỉ người có Ghi danh · Sửa xem hàng chờ (Sale chỉ xem ghi danh)');
reset role;

-- ================= GD-02 bản ghi =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is(app.enrollment_record(pg_temp.en('GD113B')) -> 'enrollment' ->> 'student_name', 'Em giả 113 B', 'Bản ghi: học sinh');
select is(app.enrollment_record(pg_temp.en('GD113B')) -> 'enrollment' ->> 'status_name', 'Đang học', 'Bản ghi: tình trạng hiện tên');
select is((app.enrollment_record(pg_temp.en('GD113B')) -> 'hours' ->> 'remaining')::numeric, 44.00, 'Bản ghi: giờ còn lại');
select is((app.enrollment_record(pg_temp.en('GD113B')) -> 'hours' ->> 'used')::numeric, 2.00, 'Bản ghi: giờ đã học');
select is(jsonb_array_length(app.enrollment_record(pg_temp.en('GD113B')) -> 'classes'), 1, 'Bản ghi: một dòng xếp lớp');
select is((app.enrollment_record(pg_temp.en('GD113B')) -> 'classes' -> 0 ->> 'studied_hours')::numeric, 2.00, 'Bản ghi: giờ đã học tại lớp');
select is(app.enrollment_record(pg_temp.en('GD113B')) -> 'enrollment' -> 'expected_end_date', 'null'::jsonb, 'Ngày hết giờ dự kiến chưa tính (null)');
select is((app.enrollment_record(pg_temp.en('GD113B')) ->> 'tickets')::int, 0, 'Chưa có ticket');
select is(pg_temp.err(format($$select app.enrollment_record('%s')$$, pg_temp.en('GD113E'))), 'HMT_KHONG_TIM_THAY', 'Ghi danh cơ sở khác: như không tồn tại');
select is(pg_temp.err(format($$select app.enrollment_record('%s')$$, gen_random_uuid())), 'HMT_KHONG_TIM_THAY', 'Không có ghi danh: báo không tìm thấy');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err(format($$select app.enrollment_record('%s')$$, pg_temp.en('GD113B'))), 'HMT_KHONG_CO_QUYEN', 'R-GV-13: giáo viên không đọc bản ghi ghi danh');
reset role;

-- ================= GD-04 sổ giờ =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((app.enrollment_ledger(pg_temp.en('GD113B')) ->> 'total')::int, 4, 'Sổ giờ: đủ 4 dòng (chỉ thêm, hiện mọi dòng)');
select is((select string_agg(r ->> 'entry_type', ',' order by ord) from jsonb_array_elements(app.enrollment_ledger(pg_temp.en('GD113B')) -> 'rows') with ordinality t(r, ord)),
  'CHUYEN_PHI,TRU_BUOI,DIEU_CHINH,CAP_MUA', 'Mới nhất trước');
select is((select string_agg(((r ->> 'balance')::numeric)::int::text, ',' order by ord) from jsonb_array_elements(app.enrollment_ledger(pg_temp.en('GD113B')) -> 'rows') with ordinality t(r, ord)),
  '44,48,50,48', 'Số dư chạy sau mỗi dòng');
select is((select r ->> 'ticket_code' from jsonb_array_elements(app.enrollment_ledger(pg_temp.en('GD113B')) -> 'rows') r where r ->> 'entry_type' = 'CHUYEN_PHI'), 'TK-TEST-0001',
  'R-GD-18: dòng chuyển phí kèm mã ticket');
select is((select r ->> 'entry_name' from jsonb_array_elements(app.enrollment_ledger(pg_temp.en('GD113B')) -> 'rows') r where r ->> 'entry_type' = 'CHUYEN_PHI'), 'Phiếu chuyển phí',
  'R-GD-18: nguồn "Phiếu chuyển phí"');
select is((select r ->> 'adjusted_by' from jsonb_array_elements(app.enrollment_ledger(pg_temp.en('GD113B')) -> 'rows') r where r ->> 'entry_type' = 'DIEU_CHINH'), 'Giả admin',
  'Dòng điều chỉnh nêu người điều chỉnh (trigger chuẩn điền người đang đăng nhập lúc chèn: Admin tạo lớp)');
select is((select r ->> 'note' from jsonb_array_elements(app.enrollment_ledger(pg_temp.en('GD113B')) -> 'rows') r where r ->> 'entry_type' = 'DIEU_CHINH'), 'Buổi điểm danh nhầm', 'Dòng điều chỉnh nêu lý do');
select is((select r ->> 'class_code' from jsonb_array_elements(app.enrollment_ledger(pg_temp.en('GD113B')) -> 'rows') r where r ->> 'entry_type' = 'TRU_BUOI'), (select code from app.class where id = (select id from cl)),
  'Dòng trừ buổi nêu lớp');
select is((select (r ->> 'session_no') is not null from jsonb_array_elements(app.enrollment_ledger(pg_temp.en('GD113B')) -> 'rows') r where r ->> 'entry_type' = 'TRU_BUOI'), true, 'Dòng trừ buổi nêu số buổi');
select is((select r ->> 'ticket_code' from jsonb_array_elements(app.enrollment_ledger(pg_temp.en('GD113B')) -> 'rows') r where r ->> 'entry_type' = 'CAP_MUA'), null, 'Dòng khác không có mã ticket');
select is(jsonb_array_length(app.enrollment_ledger(pg_temp.en('GD113B'), 2, 0) -> 'rows'), 2, 'Phân trang sổ giờ');
select is((app.enrollment_ledger(pg_temp.en('GD113B'), 2, 2) -> 'rows' -> 0 ->> 'entry_type'), 'DIEU_CHINH', 'Trang 2 của sổ giờ');
select is(pg_temp.err(format($$select app.enrollment_ledger('%s')$$, pg_temp.en('GD113E'))), 'HMT_KHONG_TIM_THAY', 'Sổ giờ ghi danh cơ sở khác: không tìm thấy');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err(format($$select app.enrollment_ledger('%s')$$, pg_temp.en('GD113B'))), 'HMT_KHONG_CO_QUYEN', 'R-GV-13: giáo viên không đọc sổ giờ');
reset role;


-- ================= C96 (migration 606): Group By GD-06 Hàng chờ xếp lớp (enrollment_queue_group_counts) =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is((app.enrollment_queue_group_counts('{"q": "GD113"}'::jsonb, array['reason']) ->> 'total')::int, 2, 'GD-06 Group By lý do chờ: tổng 2 ghi danh chờ (hai cơ sở)');
select is((select (g ->> 'count')::int from jsonb_array_elements(app.enrollment_queue_group_counts('{"q": "GD113"}'::jsonb, array['reason']) -> 'groups') g where g ->> 'k1' = 'CHUA_CO_LOP'), 2, 'Lý do chờ luôn «Chưa có lớp» (R-GD-05): một nhóm 2 dòng');
select is((select g ->> 'l1' from jsonb_array_elements(app.enrollment_queue_group_counts('{"q": "GD113"}'::jsonb, array['reason']) -> 'groups') g limit 1), 'Chưa có lớp', 'Nhãn nhóm lý do chờ');
select is((select sum((g ->> 'count')::int) from jsonb_array_elements(app.enrollment_queue_group_counts('{"q": "GD113"}'::jsonb, array['delivery']) -> 'groups') g), 2::bigint, 'Group By hình thức: tổng các nhóm bằng 2');
select is((app.enrollment_queue_group_counts('{"q": "GD113"}'::jsonb, array['delivery']) ->> 'total')::int, (app.enrollment_queue('{"q": "GD113"}'::jsonb) ->> 'total')::int, 'Số đếm khớp tổng của danh sách');
select is(jsonb_array_length(app.enrollment_queue_group_counts('{"q": "GD113"}'::jsonb, array['reason', 'delivery']) -> 'groups') >= 1, true, 'Hai cấp lý do chờ, hình thức: có nhóm lá');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is((app.enrollment_queue_group_counts('{"q": "GD113"}'::jsonb, array['reason']) ->> 'total')::int, 1, 'Phạm vi cơ sở: CSKH CS1 chỉ đếm 1 ghi danh chờ');
select is(pg_temp.err($$select app.enrollment_queue_group_counts('{}'::jsonb, array['creator'])$$), 'HMT_NHOM_SAI', 'Chặn: trường nhóm không cho phép');
select is(pg_temp.err($$select app.enrollment_queue_group_counts('{}'::jsonb, array['reason', 'reason'])$$), 'HMT_NHOM_SAI', 'Chặn: hai cấp giống nhau');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.enrollment_queue_group_counts('{}'::jsonb, array['reason'])$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Sale chỉ xem ghi danh, không đếm được hàng chờ');
reset role;

select * from finish();
rollback;
