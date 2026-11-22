-- C96 (migration 614): Group By BUOI-12 Buổi chưa Done (session_pending_group_counts) và bộ lọc teacher_id của session_pending_list; phạm vi cơ sở; chặn trường lạ. Dựng theo test 123.
-- Luật: R-BUOI-06, R-BUOI-07, R-BUOI-09, R-LOP-08, R-GIO-06, R-GV-05, R-GV-08, R-HT-07. Dữ liệu giả.
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
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('gv1'), ('cskh1'), ('cskh2'), ('sales1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@bb.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@bb.hoamatoan.invalid',
       (select id from app.branch where code = case u.key when 'cskh2' then 'CS2' else 'CS1' end), false from u;
insert into app.user_role (user_id, role_code)
select u.id, case u.key when 'admin' then 'ADMIN' when 'gv1' then 'TEACHER' when 'sales1' then 'SALES' else 'CSKH' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'VAN_HANH_LOP', id, true from app.branch where code in ('CS1', 'CS2')
  on conflict (module_code, branch_id) do update set enabled = true$$);
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

create temp table cl (id uuid);
grant all on cl to public;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
insert into cl select (app.create_class(jsonb_build_object('branch_id', (select id from app.branch where code = 'CS1'), 'year_code', '2627',
  'subject_code', 'TOAN', 'grade_code', 'K08', 'class_type_code', 'CB', 'level_code', 'A', 'max_students', 0,
  'start_date', (date_trunc('week', current_date) + interval '14 days')::date, 'total_sessions', 5,
  'slots', jsonb_build_array(jsonb_build_object('weekday', 1, 'start_time', '18:00', 'end_time', '19:30', 'repeat_weeks', 1,
     'first_date', (date_trunc('week', current_date) + interval '14 days')::date, 'teacher_id', pg_temp.uid('gv1'))))) ->> 'id')::uuid;
reset role;
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHBB1', 'Phụ huynh giả BB', '0900106001', (select id from app.branch where code = 'CS1'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  select 'HSBB' || n, (select id from app.parent where code = 'PHBB1'), 'Em giả BB ' || n, 2012, (select id from app.branch where code = 'CS1') from generate_series(1, 5) n$$);

-- Phòng giả của CS1 để thử trùng phòng.
select pg_temp.sudo($$insert into app.room (branch_id, code, name) values ((select id from app.branch where code = 'CS1'), 'PBB1', 'Phòng giả BB1')$$);
create function pg_temp.room() returns uuid language sql stable security definer as $$ select id from app.room where code = 'PBB1' $$;

create function pg_temp.mk(p_no integer, p_date date, p_status text, p_start time, p_end time, p_room uuid default null) returns uuid language plpgsql security definer as $$
declare v_id uuid;
begin
  insert into app.class_session (class_id, branch_id, session_no, session_date, start_time, end_time, teacher_id, status_code, room_id)
  values ((select id from cl), (select id from app.branch where code = 'CS1'), p_no, p_date, p_start, p_end, pg_temp.uid('gv1'), p_status, p_room)
  returning id into v_id;
  return v_id;
end $$;
create temp table se (key text primary key, id uuid);
grant all on se to public;
select pg_temp.sudo($$insert into se values
  -- Ngày hôm qua (giờ Việt Nam): đã kết thúc chắc chắn, kể cả chạy quanh nửa đêm.
  ('chot', pg_temp.mk(301, (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1, 'DA_CHOT', '00:00', '00:30')),
  ('chua_bd', pg_temp.mk(302, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 1, 'DA_CHOT', '18:00', '19:30')),
  ('nhap', pg_temp.mk(303, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 3, 'NHAP', '18:00', '19:30')),
  ('huy_tt', pg_temp.mk(304, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 5, 'DA_CHOT', '18:00', '19:30')),
  ('huy_hs', pg_temp.mk(305, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 6, 'NHAP', '18:00', '19:30')),
  ('done', pg_temp.mk(306, (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1, 'DONE', '18:00', '19:30')),
  ('phong_a', pg_temp.mk(307, (now() at time zone 'Asia/Ho_Chi_Minh')::date + 10, 'NHAP', '18:00', '19:30', pg_temp.room()))$$);
create function pg_temp.sid(p_key text) returns uuid language sql stable as $$ select id from se where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

-- ================= BUOI-04: huỷ buổi lưu lý do =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.cancel_session(pg_temp.sid('huy_hs'), 'HUY_KHONG_PHI', 'HS_OM', null)$$), 'HMT_HUY_BUOI_HS_CHI_LOP_RIENG',
  'R-BUOI-07: lý do của học sinh chỉ dùng cho lớp riêng (lớp này là CB)');
select is(app.session_cancel_preview(pg_temp.sid('huy_tt')) ->> 'added_date' is not null, true, 'BUOI-04: xem trước có ngày buổi thêm vào cuối lịch');
select is((app.session_cancel_preview(pg_temp.sid('huy_tt')) ->> 'added_session_no')::int >= 1, true, 'BUOI-04: xem trước có số buổi thêm');
select is(app.cancel_session(pg_temp.sid('huy_tt'), null, 'TT_THOI_TIET', 'Mưa lớn') ->> 'status', 'HUY_KHONG_PHI', 'R-BUOI-06: trung tâm huỷ: Huỷ không tính phí');
reset role;
select is((select cancel_reason_code from app.class_session where id = pg_temp.sid('huy_tt')), 'TT_THOI_TIET', 'BUOI-04: lý do huỷ được lưu') from (select 1) x;
select is((select cancel_note from app.class_session where id = pg_temp.sid('huy_tt')), 'Mưa lớn', 'BUOI-04: ghi chú huỷ được lưu');
select is((select count(*) from app.class_session where class_id = (select id from cl) and id not in (select id from se) and status_code <> 'DA_THAY'), 1::bigint,
  'R-BUOI-06: tự thêm đúng một buổi vào cuối lịch');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is(app.session_record(pg_temp.sid('huy_tt')) -> 'session' ->> 'cancel_reason_name', 'Thời tiết', 'BUOI-02: bản ghi hiện lý do huỷ');
select is(app.session_record(pg_temp.sid('huy_tt')) -> 'session' ->> 'cancel_note', 'Mưa lớn', 'BUOI-02: bản ghi hiện ghi chú huỷ');
select is((select r ->> 'note' from jsonb_array_elements(app.session_list(jsonb_build_object('class_id', (select id from cl), 'status', jsonb_build_array('HUY_KHONG_PHI'))) -> 'rows') r
            where r ->> 'session_no' = '304'), 'Thời tiết · Mưa lớn', 'BUOI-01: cột Ghi chú hiện lý do huỷ và ghi chú');
select is(pg_temp.err($$select app.cancel_session(pg_temp.sid('done'), null, 'TT_THOI_TIET', null)$$), 'HMT_BUOI_KHONG_HUY_DUOC', 'R-BUOI-09: buổi Done không huỷ được');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.cancel_session(pg_temp.sid('huy_hs'), null, 'TT_THOI_TIET', null)$$), 'HMT_KHONG_CO_QUYEN', 'R-BUOI-09: giáo viên không huỷ được');
reset role;

-- ================= BUOI-05: dời buổi, kiểm trùng =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is(jsonb_typeof(app.session_move_options(pg_temp.sid('nhap')) -> 'rooms'), 'array', 'BUOI-05: có danh sách phòng');
select is((select count(*) from jsonb_array_elements(app.session_move_options(pg_temp.sid('nhap')) -> 'rooms') r where r ->> 'code' = 'PBB1'), 1::bigint, 'BUOI-05: phòng của cơ sở có trong danh sách');
select is(jsonb_array_length(app.session_move_check(pg_temp.sid('nhap'), (now() at time zone 'Asia/Ho_Chi_Minh')::date + 10, '18:30', '19:00', pg_temp.room()) -> 'room_clash'), 1,
  'R-LOP-08: dời vào phòng đang có buổi cùng giờ: cảnh báo trùng phòng');
select is(jsonb_array_length(app.session_move_check(pg_temp.sid('nhap'), (now() at time zone 'Asia/Ho_Chi_Minh')::date + 10, '18:30', '19:00', pg_temp.room()) -> 'teacher_clash'), 1,
  'R-LOP-08: cùng giáo viên cùng giờ: cảnh báo trùng giáo viên');
select is(jsonb_array_length(app.session_move_check(pg_temp.sid('nhap'), (now() at time zone 'Asia/Ho_Chi_Minh')::date + 10, '20:00', '21:00', pg_temp.room()) -> 'room_clash'), 0,
  'Giờ không giao nhau thì không trùng');
select is(jsonb_array_length(app.session_move_check(pg_temp.sid('nhap'), null, null, null) -> 'room_clash'), 0, 'Thiếu ngày giờ thì không báo trùng (hàm dời báo lỗi khi lưu)');
-- Cảnh báo không chặn: vẫn dời được.
select is(jsonb_typeof(app.move_session(pg_temp.sid('nhap'), (now() at time zone 'Asia/Ho_Chi_Minh')::date + 10, '18:30', '19:00', pg_temp.room()) -> 'warnings'), 'array', 'R-LOP-08: trùng chỉ cảnh báo, vẫn dời được');
reset role;
select pg_temp.claims(pg_temp.uid('cskh2'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.session_move_options(pg_temp.sid('nhap'))$$), 'HMT_KHONG_CO_QUYEN', 'Phạm vi cơ sở: cơ sở khác không mở được hộp dời');
select is(pg_temp.err($$select app.session_cancel_preview(pg_temp.sid('nhap'))$$), 'HMT_KHONG_CO_QUYEN', 'Phạm vi cơ sở: cơ sở khác không xem trước huỷ');
reset role;

-- ================= BUOI-12: buổi chưa hoàn tất =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((app.session_pending_list(jsonb_build_object('q', (select code from app.class where id = (select id from cl)))) ->> 'total')::int, 1,
  'BUOI-12: chỉ buổi Đã chốt đã kết thúc (buổi chưa bắt đầu, Nháp, Done, huỷ không hiện)');
select is(app.session_pending_list(jsonb_build_object('q', (select code from app.class where id = (select id from cl)))) -> 'rows' -> 0 ->> 'id', pg_temp.sid('chot')::text, 'BUOI-12: đúng buổi kẹt');
select ok(app.session_pending_list(jsonb_build_object('q', (select code from app.class where id = (select id from cl)))) -> 'rows' -> 0 ->> 'reason' is not null, 'R-GIO-06: có lý do chưa Done');
select ok(app.session_pending_list(jsonb_build_object('q', (select code from app.class where id = (select id from cl)))) -> 'rows' -> 0 ->> 'deadline' is not null, 'R-GV-05: có hạn giáo viên hoàn tất');
select is((app.session_pending_list(jsonb_build_object('q', (select code from app.class where id = (select id from cl)), 'kind', 'QUA_HAN')) ->> 'total')::int
          + (app.session_pending_list(jsonb_build_object('q', (select code from app.class where id = (select id from cl)), 'kind', 'CON_HAN')) ->> 'total')::int, 1,
  'Lọc quá hạn và còn hạn chia đủ, không trùng');
reset role;
select pg_temp.claims(pg_temp.uid('cskh2'), 'aal1');
set local role authenticated;
select is((app.session_pending_list(jsonb_build_object('q', (select code from app.class where id = (select id from cl)))) ->> 'total')::int, 0, 'Phạm vi cơ sở: cơ sở khác không thấy');
reset role;
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.session_pending_list('{}')$$), 'HMT_KHONG_CO_QUYEN', 'R-GV-08: giáo viên không đọc danh sách theo dõi');
select is(pg_temp.err($$select app.remind_teacher_session(pg_temp.sid('chot'))$$), 'HMT_KHONG_CO_QUYEN', 'R-GV-08: giáo viên không tự nhắc');
reset role;

-- ================= Nhắc giáo viên =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is(app.remind_teacher_session(pg_temp.sid('chot')), true, 'BUOI-12: Nhắc GV thành công');
select is(pg_temp.err($$select app.remind_teacher_session(pg_temp.sid('nhap'))$$), 'HMT_BUOI_KHONG_CAN_NHAC', 'Chỉ nhắc buổi Đã chốt');
reset role;
select is((select count(*) from app.notification where user_id = pg_temp.uid('gv1') and kind = 'NHAC_HOAN_TAT_BUOI'), 1::bigint, 'Giáo viên nhận đúng một thông báo');
select is((select actor_id from app.notification where user_id = pg_temp.uid('gv1') and kind = 'NHAC_HOAN_TAT_BUOI'), pg_temp.uid('cskh1'), 'Thông báo ghi người nhắc');


-- ================= C96 (migration 614): Group By BUOI-12 Buổi chưa Done (session_pending_group_counts) =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
set local role authenticated;
select is((app.session_pending_group_counts(jsonb_build_object('q', (select code from app.class where id = (select id from cl))), array['teacher']) ->> 'total')::int, 1, 'BUOI-12 Group By giáo viên: tổng 1 buổi kẹt');
select is(jsonb_array_length(app.session_pending_group_counts(jsonb_build_object('q', (select code from app.class where id = (select id from cl))), array['teacher']) -> 'groups'), 1, 'Một nhóm giáo viên');
select is((select (app.session_pending_list(jsonb_build_object('q', (select code from app.class where id = (select id from cl)), 'teacher_id', nullif(g ->> 'k1', ''))) ->> 'total')::int
             from jsonb_array_elements(app.session_pending_group_counts(jsonb_build_object('q', (select code from app.class where id = (select id from cl))), array['teacher']) -> 'groups') g), 1,
  'Mở nhóm: session_pending_list lọc theo teacher_id ra đúng buổi của nhóm');
select is((app.session_pending_list(jsonb_build_object('q', (select code from app.class where id = (select id from cl)), 'teacher_id', gen_random_uuid())) ->> 'total')::int, 0, 'Lọc giáo viên khác ra 0 buổi');
select is((app.session_pending_group_counts(jsonb_build_object('q', (select code from app.class where id = (select id from cl)), 'kind', 'QUA_HAN'), array['teacher']) ->> 'total')::int
          + (app.session_pending_group_counts(jsonb_build_object('q', (select code from app.class where id = (select id from cl)), 'kind', 'CON_HAN'), array['teacher']) ->> 'total')::int, 1,
  'Bộ lọc hạn áp dụng cho số đếm, quá hạn và còn hạn chia đủ');
select is(pg_temp.err($$select app.session_pending_group_counts('{}'::jsonb, array['creator'])$$), 'HMT_NHOM_SAI', 'Chặn: trường nhóm không cho phép');
select is(pg_temp.err($$select app.session_pending_group_counts('{}'::jsonb, array['teacher', 'teacher'])$$), 'HMT_NHOM_SAI', 'Chặn: hai cấp giống nhau');
reset role;
select pg_temp.claims(pg_temp.uid('cskh2'), 'aal1');
set local role authenticated;
select is((app.session_pending_group_counts(jsonb_build_object('q', (select code from app.class where id = (select id from cl))), array['teacher']) ->> 'total')::int, 0, 'Phạm vi cơ sở: cơ sở khác không đếm được');
reset role;

select * from finish();
rollback;
