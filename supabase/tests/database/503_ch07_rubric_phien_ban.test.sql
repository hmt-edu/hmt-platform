-- CH-07 Rubric nhận xét, phần DB (migration 503). Luật: R-GV-01, R-V2-19, S03-10; canvas CH07_*.
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
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('gv1');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
create function pg_temp.crit(p_code text) returns uuid language sql stable security definer as $$ select id from app.review_criterion where code = p_code $$;
create function pg_temp.ver(p_set text, p_no integer) returns uuid language sql stable security definer as $$
  select id from app.review_rubric_version where subject_set = p_set and version_no = p_no $$;
grant execute on all functions in schema pg_temp to public;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ch07.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ch07.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('gv1', 'TEACHER')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- ---------- Dữ liệu nạp sẵn ----------
select is((select count(*)::int from app.review_rubric_version where status = 'DANG_DUNG'), 2, 'Mỗi bộ (TOAN, MON_PHU) có đúng một bản Đang dùng');
select is((select count(*)::int from app.review_level_desc d where d.version_id = pg_temp.ver('TOAN', 1)), 45, 'Bản Toán v1: 9 tiêu chí × 5 mức = 45 mô tả (9 tiêu chí × 5 mức)');

set local role authenticated;
-- ---------- Đọc: chỉ Admin ----------
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(jsonb_array_length(app.get_rubric('TOAN') -> 'criteria'), 9, 'Admin đọc rubric Toán: 9 tiêu chí');
select is(app.get_rubric('TOAN') -> 'version' ->> 'status', 'DANG_DUNG', 'Mặc định đọc bản Đang dùng');
select is(pg_temp.err($$select app.get_rubric('SAI')$$), 'HMT_THAM_SO_SAI', 'Chặn: bộ tiêu chí không hợp lệ');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(pg_temp.err($$select app.get_rubric('TOAN')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không xem rubric (chỉ Admin)');
select pg_temp.claims(pg_temp.uid('gv1'), 'aal1');
select is(pg_temp.err($$select app.get_rubric('TOAN')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không xem màn cấu hình rubric');

-- ---------- Sửa mô tả ----------
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(pg_temp.err($$select app.update_review_level_desc(pg_temp.ver('TOAN', 1), pg_temp.crit('TD_TAP_TRUNG'), 3, 'x')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không sửa mô tả');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.update_review_level_desc(pg_temp.ver('TOAN', 1), pg_temp.crit('TD_TAP_TRUNG'), 3, '  Mô tả mới mức 3  ')$$), null, 'Admin sửa mô tả một mức');
select is((select description from app.review_level_desc where version_id = pg_temp.ver('TOAN', 1) and criterion_id = pg_temp.crit('TD_TAP_TRUNG') and level = 3), 'Mô tả mới mức 3', 'Mô tả được cắt khoảng trắng');
select is(pg_temp.err($$select app.update_review_level_desc(pg_temp.ver('TOAN', 1), pg_temp.crit('TD_TAP_TRUNG'), 6, 'x')$$), 'HMT_THAM_SO_SAI', 'Chặn: mức ngoài 1 đến 5');
select is(pg_temp.err($$select app.update_review_level_desc(pg_temp.ver('TOAN', 1), pg_temp.crit('TD_TAP_TRUNG'), 3, '   ')$$), 'HMT_THIEU_THONG_TIN', 'Chặn: mô tả trống');
select is(pg_temp.err($$select app.update_review_level_desc(pg_temp.ver('TOAN', 1), pg_temp.crit('TT_NHAN_BIET'), 3, 'x')$$), 'HMT_RUBRIC_TIEU_CHI_SAI', 'Chặn: tiêu chí của bộ môn phụ không sửa trong bản Toán');

-- ---------- Tạo phiên bản ----------
select is(pg_temp.err($$select app.create_rubric_version('SAI')$$), 'HMT_THAM_SO_SAI', 'Chặn: tạo phiên bản cho bộ không có');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(pg_temp.err($$select app.create_rubric_version('TOAN')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không tạo phiên bản');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select pg_temp.sudo($$create temp table nv as select app.create_rubric_version('TOAN', 'Bản thử') as id$$);
select pg_temp.sudo($$grant select on nv to authenticated$$);
select is((select version_no from app.review_rubric_version where id = (select id from nv)), 2, 'Phiên bản mới có số 2');
select is((select status from app.review_rubric_version where id = pg_temp.ver('TOAN', 1)), 'NGUNG', 'Bản cũ chuyển Ngừng');
select is((select count(*)::int from app.review_rubric_version where subject_set = 'TOAN' and status = 'DANG_DUNG'), 1, 'Vẫn đúng một bản Đang dùng');
select is((select description from app.review_level_desc where version_id = (select id from nv) and criterion_id = pg_temp.crit('TD_TAP_TRUNG') and level = 3), 'Mô tả mới mức 3', 'Bản mới sao chép mô tả của bản trước (gồm chỗ vừa sửa)');
select is((select count(*)::int from app.review_level_desc where version_id = (select id from nv)), 45, 'Bản mới đủ 45 mô tả');
select is(pg_temp.err($$select app.update_review_level_desc(pg_temp.ver('TOAN', 1), pg_temp.crit('TD_TAP_TRUNG'), 3, 'sửa bản cũ')$$), 'HMT_RUBRIC_BAN_NGUNG', 'Chặn: sửa bản đã Ngừng');
select is((select description from app.review_level_desc where version_id = pg_temp.ver('TOAN', 1) and criterion_id = pg_temp.crit('TD_TAP_TRUNG') and level = 3), 'Mô tả mới mức 3', 'Bản cũ giữ nguyên');
select is(pg_temp.err($$select app.update_review_level_desc((select id from nv), pg_temp.crit('TD_TAP_TRUNG'), 3, 'Chỉ bản mới đổi')$$), null, 'Sửa ở bản mới được');
select is((select description from app.review_level_desc where version_id = pg_temp.ver('TOAN', 1) and criterion_id = pg_temp.crit('TD_TAP_TRUNG') and level = 3), 'Mô tả mới mức 3', 'Sửa bản mới không đổi bản cũ');
select is((select count(*)::int from app.review_rubric_version where subject_set = 'MON_PHU' and status = 'DANG_DUNG'), 1, 'Bộ môn phụ không bị ảnh hưởng');

-- ---------- Ngừng tiêu chí ----------
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(pg_temp.err($$select app.set_review_criterion_active(pg_temp.crit('TOAN_HIEU'), false)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không Ngừng tiêu chí');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.set_review_criterion_active(pg_temp.crit('TOAN_HIEU'), false)$$), null, 'Admin Ngừng một tiêu chí (còn tiêu chí khác cùng nhóm)');
select is((select is_active from app.review_criterion where code = 'TOAN_HIEU'), false, 'Tiêu chí chuyển Ngừng, không xoá');
select is(pg_temp.err($$select app.set_review_criterion_active(pg_temp.crit('TOAN_GHI_NHO'), false)$$), null, 'Ngừng tiêu chí thứ hai của nhóm Tiếp thu');
select is(pg_temp.err($$select app.set_review_criterion_active(pg_temp.crit('TOAN_NHAN_BIET'), false)$$), 'HMT_RUBRIC_NHOM_TRONG', 'Chặn: Ngừng nốt tiêu chí cuối của nhóm');
select is(pg_temp.err($$select app.set_review_criterion_active(pg_temp.crit('TOAN_HIEU'), true)$$), null, 'Dùng lại tiêu chí');
select is(pg_temp.err($$select app.set_review_criterion_active(gen_random_uuid(), false)$$), 'HMT_KHONG_TIM_THAY', 'Chặn: tiêu chí không có');

-- ---------- Lưu nhiều ô một lần (migration 504) ----------
select is(app.update_review_level_descs(pg_temp.ver('MON_PHU', 1), jsonb_build_array(
  jsonb_build_object('criterion_id', pg_temp.crit('TD_TAP_TRUNG'), 'level', 1, 'description', 'Một'),
  jsonb_build_object('criterion_id', pg_temp.crit('TD_TAP_TRUNG'), 'level', 2, 'description', 'Hai'))), 2, 'Lưu hai ô trong một lần gọi');
select is(pg_temp.err($$select app.update_review_level_descs(pg_temp.ver('MON_PHU', 1), jsonb_build_array(
  jsonb_build_object('criterion_id', pg_temp.crit('TD_TAP_TRUNG'), 'level', 1, 'description', 'Đổi'),
  jsonb_build_object('criterion_id', pg_temp.crit('TD_TAP_TRUNG'), 'level', 2, 'description', ' ')))$$), 'HMT_THIEU_THONG_TIN', 'Một ô trống thì cả lần lưu bị chặn');
select is((select description from app.review_level_desc where version_id = pg_temp.ver('MON_PHU', 1) and criterion_id = pg_temp.crit('TD_TAP_TRUNG') and level = 1), 'Một', 'Lần lưu lỗi không để lại ô nào đã đổi dở');
select is(pg_temp.err($$select app.update_review_level_descs(pg_temp.ver('MON_PHU', 1), '{}'::jsonb)$$), 'HMT_THAM_SO_SAI', 'Chặn: danh sách không phải mảng');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(pg_temp.err($$select app.update_review_level_descs(pg_temp.ver('MON_PHU', 1), '[]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không lưu mô tả');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- ---------- Câu mẫu lời nhắn phụ huynh (migration 506, R-V2-39) ----------
select is(jsonb_array_length(app.get_parent_phrases()), 24, 'Admin đọc đủ 24 câu mẫu (2 loại buổi × 4 mức × 3 câu)');
select is(app.update_parent_phrases(jsonb_build_array(jsonb_build_object('kind', 'THUONG', 'level', 1, 'seq', 1, 'phrase', '  Câu mới  '))), 1, 'Admin sửa một câu');
select is((select phrase from app.parent_phrase where kind = 'THUONG' and level = 1 and seq = 1), 'Câu mới', 'Câu được cắt khoảng trắng');
select is(pg_temp.err($$select app.update_parent_phrases(jsonb_build_array(jsonb_build_object('kind', 'THUONG', 'level', 1, 'seq', 1, 'phrase', ' ')))$$), 'HMT_THIEU_THONG_TIN', 'Chặn: câu trống');
select is(pg_temp.err($$select app.update_parent_phrases(jsonb_build_array(jsonb_build_object('kind', 'THUONG', 'level', 5, 'seq', 1, 'phrase', 'x')))$$), 'HMT_KHONG_TIM_THAY', 'Chặn: không thêm câu ngoài 24 câu (mức 5)');
select is((select count(*)::int from app.parent_phrase), 24, 'Vẫn đúng 24 câu');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(pg_temp.err($$select app.get_parent_phrases()$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không xem câu mẫu');
select is(pg_temp.err($$select app.update_parent_phrases('[]'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: Trưởng cơ sở không sửa câu mẫu');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- ---------- Chụp vào buổi ----------
select is((select count(*)::int from information_schema.columns where table_schema = 'app' and table_name = 'session_review_criterion' and column_name in ('rubric_version_id', 'level_descs')), 2, 'Buổi có cột chụp phiên bản và mô tả');
select * from finish();
rollback;
