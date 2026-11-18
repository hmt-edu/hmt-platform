-- CH-05, CH-06 Khung chương trình (migration 300): tạo khung, bản kế sao chép bài, thêm/sửa/đổi thứ tự bài, ngừng, quyền (Admin sửa, người khác chỉ xem). Dữ liệu giả.
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
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('cskh5'), ('qlcs5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@kc.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@kc.hoamatoan.invalid', (select id from app.branch where code = 'CS5'), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' when key like 'cskh%' then 'CSKH' else 'BRANCH_MANAGER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
grant execute on all functions in schema pg_temp to public;

set local role authenticated;
create temp table f1 (j jsonb);
create temp table f2 (j jsonb);
grant all on f1, f2 to public;

-- ================= Quyền =================
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select is(pg_temp.err($$select app.create_curriculum_frame('TOAN', 'K03', 'CB', '2627')$$), 'HMT_KHONG_CO_QUYEN', 'Quyền: CSKH không tạo được khung');
select is((app.list_curriculum_frames() ->> 'total')::int, 0, 'Quyền: CSKH xem được danh sách (đang trống)');

select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
select is(pg_temp.err($$select app.create_curriculum_frame('TOAN', 'K03', 'CB', '2627')$$), 'HMT_KHONG_CO_QUYEN', 'Quyền: Trưởng cơ sở chỉ xem, không tạo khung');

-- ================= Tạo khung (Admin) =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
insert into f1 select app.create_curriculum_frame('TOAN', 'K03', 'CB', '2627');
select is((select j ->> 'code' from f1), 'TOAN-K03-CB-2627', 'Tạo khung: bản đầu không hậu tố (spec 02)');
select is(pg_temp.err($$select app.create_curriculum_frame('TOAN', 'K03', 'CB', '2627')$$), 'HMT_KHUNG_DA_CO', 'Tạo khung: đã có thì báo, hướng dẫn Tạo bản mới');
select is(pg_temp.err($$select app.create_curriculum_frame('TOAN', 'K03', 'LR', '2627')$$), 'HMT_CAP_DO_KHONG_HOP_LE', 'Tạo khung: cấp độ chỉ CB, NC');
select is(pg_temp.err($$select app.create_curriculum_frame('TOAN', 'K03', 'CB', '2628')$$), 'HMT_NAM_HOC_KHONG_HOP_LE', 'Tạo khung: năm học phải hai năm liền nhau');
select is(pg_temp.err($$select app.create_curriculum_frame('KHONG_CO', 'K03', 'CB', '2627')$$) is not null, true, 'Tạo khung: môn không có trong danh mục bị chặn');

-- ================= Bài học =================
select is((select j ->> 'code' from (select app.save_curriculum_lesson((select (j ->> 'id')::uuid from f1), null, 'Ôn tập các số đến 1000', 'Đọc, viết số') j) x), 'TOAN-K03-CB-2627-B01', 'Thêm bài: mã bài -B01');
select is((select j ->> 'code' from (select app.save_curriculum_lesson((select (j ->> 'id')::uuid from f1), null, 'Cộng, trừ số có ba chữ số', null) j) x), 'TOAN-K03-CB-2627-B02', 'Thêm bài: mã bài -B02');
select is((select j ->> 'code' from (select app.save_curriculum_lesson((select (j ->> 'id')::uuid from f1), null, 'Bảng nhân 6', null) j) x), 'TOAN-K03-CB-2627-B03', 'Thêm bài: mã bài -B03');
select is(pg_temp.err($$select app.save_curriculum_lesson((select (j ->> 'id')::uuid from f1), null, '   ', null)$$), 'HMT_THIEU_TEN_BAI', 'Thêm bài: tên bắt buộc');
select app.save_curriculum_lesson((select (j ->> 'id')::uuid from f1), (select id from app.curriculum_lesson where code = 'TOAN-K03-CB-2627-B02'), 'Cộng, trừ có nhớ', 'Gợi ý mới');
select is((select title from app.curriculum_lesson where code = 'TOAN-K03-CB-2627-B02'), 'Cộng, trừ có nhớ', 'Sửa bài: đổi tên, giữ mã bài');

-- Đổi thứ tự: B03, B01, B02. Mã bài không đổi, chỉ đổi vị trí.
select app.reorder_curriculum_lessons((select (j ->> 'id')::uuid from f1),
  array[(select id from app.curriculum_lesson where code = 'TOAN-K03-CB-2627-B03'), (select id from app.curriculum_lesson where code = 'TOAN-K03-CB-2627-B01'), (select id from app.curriculum_lesson where code = 'TOAN-K03-CB-2627-B02')]);
select is((select string_agg(code, ',' order by position) from app.curriculum_lesson where frame_id = (select (j ->> 'id')::uuid from f1)),
  'TOAN-K03-CB-2627-B03,TOAN-K03-CB-2627-B01,TOAN-K03-CB-2627-B02', 'Đổi thứ tự: vị trí đổi, mã bài giữ nguyên');
select is(pg_temp.err($$select app.reorder_curriculum_lessons((select (j ->> 'id')::uuid from f1), array[(select id from app.curriculum_lesson where code = 'TOAN-K03-CB-2627-B01')])$$), 'HMT_THU_TU_BAI_SAI', 'Đổi thứ tự: thiếu bài thì chặn');
-- Thêm bài sau khi đổi thứ tự: mã tiếp theo không trùng, vào cuối.
select is((select j ->> 'code' from (select app.save_curriculum_lesson((select (j ->> 'id')::uuid from f1), null, 'Bảng nhân 7', null) j) x), 'TOAN-K03-CB-2627-B04', 'Thêm bài sau khi kéo: mã -B04, vào cuối');

-- ================= Tạo bản mới =================
insert into f2 select app.create_curriculum_version((select (j ->> 'id')::uuid from f1));
select is((select j ->> 'code' from f2), 'TOAN-K03-CB-2627-v2', 'Bản mới: mã -v2');
select is((select count(*)::int from app.curriculum_lesson where frame_id = (select (j ->> 'id')::uuid from f2)), 4, 'Bản mới: sao chép TOÀN BỘ bài từ bản trước (R-LOP-07)');
select is((select string_agg(code, ',' order by position) from app.curriculum_lesson where frame_id = (select (j ->> 'id')::uuid from f2)),
  'TOAN-K03-CB-2627-v2-B03,TOAN-K03-CB-2627-v2-B01,TOAN-K03-CB-2627-v2-B02,TOAN-K03-CB-2627-v2-B04', 'Bản mới: giữ thứ tự, đuôi mã bài, đổi tiền tố theo mã khung mới');
select is((select count(*)::int from app.curriculum_lesson where frame_id = (select (j ->> 'id')::uuid from f1)), 4, 'Bản mới: bản trước giữ nguyên bài');
select is((select j ->> 'code' from (select app.create_curriculum_version((select (j ->> 'id')::uuid from f2)) j) x), 'TOAN-K03-CB-2627-v3', 'Bản mới lần nữa: mã -v3');
select is((select prev_frame_id from app.curriculum_frame where code = 'TOAN-K03-CB-2627-v2'), (select (j ->> 'id')::uuid from f1), 'Bản mới: ghi bản trước');

-- ================= Ngừng, danh sách =================
select app.set_curriculum_frame_active((select (j ->> 'id')::uuid from f1), false);
select is((select status_code from app.curriculum_frame where code = 'TOAN-K03-CB-2627'), 'NGUNG', 'Ngừng: đổi trạng thái, không xoá');
select is((app.list_curriculum_frames('{"status":["NGUNG"]}'::jsonb) ->> 'total')::int, 1, 'Danh sách: lọc theo trạng thái Ngừng');
select is((app.list_curriculum_frames() ->> 'total')::int, 3, 'Danh sách: ba bản');
select is((app.list_curriculum_frames('{}'::jsonb, 1, 0) -> 'rows' -> 0 ->> 'lesson_count')::int, 4, 'Danh sách: số bài của từng khung');
select is(jsonb_array_length(app.get_curriculum_frame((select (j ->> 'id')::uuid from f2)) -> 'lessons'), 4, 'Xem khung: kèm các bài');
select app.set_curriculum_frame_active((select (j ->> 'id')::uuid from f1), true);
select is((select status_code from app.curriculum_frame where code = 'TOAN-K03-CB-2627'), 'DANG_DUNG', 'Dùng lại: về Đang dùng');

-- ================= Quyền sửa bài =================
select pg_temp.claims(pg_temp.uid('qlcs5'), 'aal1');
select is(pg_temp.err($$select app.save_curriculum_lesson((select (j ->> 'id')::uuid from f1), null, 'Bài trái quyền', null)$$), 'HMT_KHONG_CO_QUYEN', 'Quyền: Trưởng cơ sở không thêm được bài');
select is(pg_temp.err($$select app.set_curriculum_frame_active((select (j ->> 'id')::uuid from f1), false)$$), 'HMT_KHONG_CO_QUYEN', 'Quyền: Trưởng cơ sở không ngừng được khung');
select is(jsonb_array_length(app.get_curriculum_frame((select (j ->> 'id')::uuid from f1)) -> 'lessons'), 4, 'Quyền: Trưởng cơ sở xem được bài');

select * from finish();
rollback;
