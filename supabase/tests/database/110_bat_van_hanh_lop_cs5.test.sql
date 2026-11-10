-- Migration 110 (Q-262): công tắc VAN_HANH_LOP bật cho CS5, các cơ sở khác không đổi, chạy lại không lỗi, hàm nạp nhận dòng CS5.
-- Dữ liệu giả.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
grant execute on all functions in schema pg_temp to public;

-- Trạng thái ngay sau migration (seed không bật VAN_HANH_LOP).
select ok(app.feature_enabled('VAN_HANH_LOP', (select id from app.branch where code = 'CS5')), 'Sau migration 110: CS5 đã bật Vận hành lớp (Q-262)');
select is((select count(*)::int from app.feature_flag where module_code = 'VAN_HANH_LOP' and enabled), 1, 'Chỉ đúng một cơ sở bật Vận hành lớp');
select ok(not app.feature_enabled('VAN_HANH_LOP', (select id from app.branch where code = 'CS1')), 'CS1 không đổi (vẫn tắt)');
select ok(not app.feature_enabled('VAN_HANH_LOP', (select id from app.branch where code = 'CS2')), 'CS2 không đổi (vẫn tắt)');
select ok(not app.feature_enabled('VAN_HANH_LOP', (select id from app.branch where code = 'CS3')), 'CS3 không đổi (vẫn tắt)');
select ok(not app.feature_enabled('VAN_HANH_LOP', (select id from app.branch where code = 'CS4')), 'CS4 không đổi (vẫn tắt)');

-- Q-198: tham số chung session_done_requires_review là Tắt sau migration 110 (Tắt là giá trị chung; Bật lại cần migration mới).
select is(app.get_setting_bool('session_done_requires_review', (select id from app.branch where code = 'CS5')), false, 'Sau migration 110: Done buổi không cần nhận xét hoặc điểm (Tắt) ở CS5');
select is(app.get_setting_bool('session_done_requires_review', (select id from app.branch where code = 'CS1')), false, 'Giá trị chung Tắt áp cho mọi cơ sở (không đặt ghi đè theo cơ sở)');
select is((select value from app.setting_def where key = 'session_done_requires_review'), 'false', 'Giá trị lưu trong cài đặt là false');
select is((select count(*)::int from app.setting_branch where setting_key = 'session_done_requires_review'), 0, 'Không có ghi đè theo cơ sở cho tham số này');
select lives_ok($$update app.setting_def set value = 'false' where key = 'session_done_requires_review'$$, 'Chạy lại câu lệnh đặt Tắt không lỗi');

-- Chạy lại đúng câu lệnh của migration: không lỗi, không nhân đôi dòng.
select lives_ok($$
  insert into app.feature_flag (module_code, branch_id, enabled)
  select 'VAN_HANH_LOP', b.id, true from app.branch b where b.code = 'CS5'
  on conflict (module_code, branch_id) do update set enabled = true$$, 'Chạy lại migration 110 không lỗi');
select is((select count(*)::int from app.feature_flag where module_code = 'VAN_HANH_LOP' and branch_id = (select id from app.branch where code = 'CS5')), 1, 'Chạy lại không nhân đôi dòng công tắc');

-- Hàm nạp nhận dòng CS5 (không còn HMT_TINH_NANG_TAT). Admin giả; dữ liệu giả.
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@d110.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@d110.hoamatoan.invalid', (select id from app.branch where code = 'CS1'), false from u;
insert into app.user_role (user_id, role_code) select id, 'ADMIN' from u;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
set local role authenticated;
select is((app.import_training_records('LOP', '[{"row":2,"ma_lop_cu":"T110","loai_lop":"Lớp chung","mon":"Toán","khoi":"4","lich_hoc":"Thứ 7 (14h30-17h00)","thoi_luong_buoi":"2.5","ma_gv":"2001","ngay_khai_giang":"2026-07-18","si_so_toi_da":"12","tinh_trang":"Đang chạy","co_so":"CS5","phan_loai":"CB","trinh_do":"A","so_buoi":"20","nam_hoc":"2627"}]'::jsonb, false, 'kiem') -> 'rows' -> 0 ->> 'status'),
          'HOP_LE', 'Dòng lớp CS5 nạp được (xem trước), không còn HMT_TINH_NANG_TAT');
select is((app.import_training_records('LOP', '[{"row":3,"ma_lop_cu":"T110B","loai_lop":"Lớp chung","mon":"Toán","khoi":"4","lich_hoc":"Thứ 7 (14h30-17h00)","thoi_luong_buoi":"2.5","ma_gv":"2001","ngay_khai_giang":"2026-07-18","si_so_toi_da":"12","tinh_trang":"Đang chạy","co_so":"CS1","phan_loai":"CB","trinh_do":"A","so_buoi":"20","nam_hoc":"2627"}]'::jsonb, false, 'kiem') -> 'rows' -> 0 ->> 'error_code'),
          'HMT_TINH_NANG_TAT', 'Dòng lớp CS1 vẫn bị từ chối vì CS1 chưa bật');

select * from finish();
rollback;
