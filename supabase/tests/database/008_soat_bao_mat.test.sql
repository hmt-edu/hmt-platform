-- Tái hiện các lỗ hổng tìm thấy khi soát bảo mật bước 3 (10/10/2026, PR #7), mỗi lỗi một nhóm bài.
-- Trước khi sửa: các bài này đỏ. Sau migration 20261010000014: xanh. Chi tiết: docs/nghiep-vu/phan-quyen.md.
begin;
-- D41 (migration 472): bài này kiểm luật «Admin, Kế toán phải qua hai bước»; luật chỉ áp khi tham số mfa_required_enabled bật (mặc định tắt), nên bật tham số ở đây.
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
-- 647 (A-23-27): bắt hai bước chỉ còn Admin; bài này vẫn kiểm luật aal2 cho Kế toán nên dựng lại cờ trong giao dịch của bài (hoàn tác khi kết thúc).
do $$ begin perform set_config('hmt.migration', 'on', true); update app.role set require_mfa = true where code = 'ACCOUNTANT'; perform set_config('hmt.migration', '', true); end $$;
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
-- Hàm mới mặc định không cấp quyền chạy cho ai (migration 014): cấp cho hàm trợ giúp của bài kiểm thử.
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('admin5'), ('acc'), ('bm5'), ('sales5'), ('nv5'), ('nv1');
grant select on u to authenticated;

insert into auth.users (id, aud, role, email, encrypted_password)
select id, 'authenticated', 'authenticated', key || '@soat.hoamatoan.invalid', '$2a$10$MaBamGiaChoKiemThu.' || key from u;

insert into app.user_account (id, display_name, login_name, branch_id)
select u.id, 'Giả ' || u.key, u.key || '@soat.hoamatoan.invalid', (select id from app.branch where code = v.cs)
  from u join (values ('admin', 'CS1'), ('admin5', 'CS5'), ('acc', 'CS5'), ('bm5', 'CS5'), ('sales5', 'CS5'), ('nv5', 'CS5'), ('nv1', 'CS1'))
    as v (key, cs) on v.key = u.key
 where u.key <> 'nv5';

insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values
  ('admin', 'ADMIN'), ('admin5', 'ADMIN'), ('acc', 'ACCOUNTANT'), ('bm5', 'BRANCH_MANAGER'), ('sales5', 'SALES'), ('nv1', 'SALES')
) as v (key, role) on v.key = u.key;

insert into app.room (branch_id, code, name) select id, 'SB1', 'Phòng soát' from app.branch where code in ('CS1', 'CS5');
insert into app.note (entity_type, entity_id, body)
select 'ROOM', r.id, 'Ghi chú soát ' || b.code from app.room r join app.branch b on b.id = r.branch_id where r.code = 'SB1';

-- ================= C1: mã băm mật khẩu tạm không lộ =================
select is((select count(*)::int
             from pg_attribute a join pg_class c on c.oid = a.attrelid join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'app' and a.attnum > 0 and not a.attisdropped and a.attname ilike '%password%hash%'
              and has_column_privilege('authenticated', c.oid, a.attnum, 'SELECT')), 0,
          'C1: không cột mã băm mật khẩu nào trong app cho người đăng nhập đọc');

-- Admin (đã xác thực hai bước) tạo nhân viên CS5, rồi đặt lại mật khẩu.
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select is(pg_temp.err($$select app.admin_create_account((select id from u where key = 'nv5'), 'Nhân viên 5',
            'nv5@soat.hoamatoan.invalid', 'CS5', '{SALES}')$$), null, 'C1: Admin tạo tài khoản được');
reset role;
update auth.users set encrypted_password = '$2a$10$MaBamMatKhauTamMoi.nv5' where id = (select id from u where key = 'nv5');
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select is(pg_temp.err($$select app.admin_mark_password_reset((select id from u where key = 'nv5'))$$), null,
          'C1: Admin đặt lại mật khẩu được');
reset role;

set local role authenticated;
select pg_temp.claims((select id from u where key = 'bm5'), 'aal1');
select is(pg_temp.err($$select * from app.user_temp_password$$), '42501',
          'C1: Trưởng cơ sở KHÔNG đọc được mã băm mật khẩu tạm của nhân viên cùng cơ sở');
reset role;
select ok(not exists (select from app.audit_log where changes::text like '%$2a$%'),
          'C1: nhật ký thao tác không chứa mã băm mật khẩu');

-- Đổi mật khẩu lần đầu vẫn chạy đúng sau khi tách bảng.
set local role authenticated;
select pg_temp.claims((select id from u where key = 'nv5'), 'aal1');
select is(pg_temp.err($$select app.complete_first_password_change()$$), 'HMT_CHUA_DOI_MAT_KHAU',
          'C1: chưa đổi mật khẩu tạm thì chưa xong bước đổi lần đầu');
reset role;
update auth.users set encrypted_password = '$2a$10$MaBamMatKhauNguoiDungTuDat' where id = (select id from u where key = 'nv5');
set local role authenticated;
select pg_temp.claims((select id from u where key = 'nv5'), 'aal1');
select is(pg_temp.err($$select app.complete_first_password_change()$$), null, 'C1: đổi sang mật khẩu mới thì xong bước đổi lần đầu');
reset role;
select ok(not (select must_change_password from app.user_account where id = (select id from u where key = 'nv5')),
          'C1: hết bị bắt đổi mật khẩu');
select set_config('request.jwt.claims', '', true);

-- ================= C2: đang khoá tạm thì hook không cấp token =================
update app.user_account set temp_locked_until = now() + interval '10 minutes', failed_login_count = 10
 where id = (select id from u where key = 'sales5');
select ok((app.custom_access_token_hook(jsonb_build_object('user_id', (select id from u where key = 'sales5'),
             'claims', '{}'::jsonb)) ? 'error'),
          'C2: đang khoá tạm, gọi thẳng Supabase Auth đúng mật khẩu vẫn không được cấp token');
update app.user_account set temp_locked_until = now() - interval '1 second'
 where id = (select id from u where key = 'sales5');
select ok(not (app.custom_access_token_hook(jsonb_build_object('user_id', (select id from u where key = 'sales5'),
             'claims', '{}'::jsonb)) ? 'error'),
          'C2: hết hạn khoá tạm thì được cấp token');

-- ================= T1: ADMIN, Kế toán chưa xác thực hai bước không thấy ghi chú =================
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin5'), 'aal1');
select is((select count(*)::int from app.note where body like 'Ghi chú soát%'), 0,
          'T1: ADMIN chưa xác thực hai bước KHÔNG đọc được ghi chú (kể cả cơ sở khác)');
select is(pg_temp.err($$select app.add_note('ROOM', (select r.id from app.room r join app.branch b on b.id = r.branch_id
                                                     where r.code = 'SB1' and b.code = 'CS1'), 'Ghi khi chưa hai bước')$$),
          'HMT_KHONG_CO_QUYEN', 'T1: ADMIN chưa xác thực hai bước KHÔNG ghi chú được');
select pg_temp.claims((select id from u where key = 'acc'), 'aal1');
select is((select count(*)::int from app.note where body like 'Ghi chú soát%'), 0,
          'T1: Kế toán chưa xác thực hai bước KHÔNG đọc được ghi chú');
select pg_temp.claims((select id from u where key = 'admin5'), 'aal2');
select is((select count(*)::int from app.note where body like 'Ghi chú soát%'), 2,
          'T1: ADMIN đã xác thực hai bước đọc được ghi chú mọi cơ sở');
reset role;
select set_config('request.jwt.claims', '', true);

-- ================= T2: tài khoản bị khoá không huỷ được ghi chú của mình =================
set local role authenticated;
select pg_temp.claims((select id from u where key = 'sales5'), 'aal1');
create temp table n as
select app.add_note('ROOM', (select r.id from app.room r join app.branch b on b.id = r.branch_id
                              where r.code = 'SB1' and b.code = 'CS5'), 'Ghi chú của sales5') as id;
reset role;
grant select on n to authenticated;
update app.user_account set is_locked = true, lock_reason = 'Nghỉ việc (soát)' where id = (select id from u where key = 'sales5');
set local role authenticated;
-- Dùng lại token cũ.
select is(pg_temp.err($$select app.cancel_note((select id from n), 'xoá dấu vết')$$), 'HMT_KHONG_CO_QUYEN',
          'T2: tài khoản bị khoá KHÔNG huỷ được ghi chú của mình bằng token cũ');
reset role;
select ok(not (select is_cancelled from app.note where id = (select id from n)), 'T2: ghi chú vẫn còn');
select set_config('request.jwt.claims', '', true);

-- ================= T3: khách không chạy được hàm nào trong app =================
select is((select coalesce(array_agg(p.proname::text order by p.proname), '{}')
             from pg_proc p join pg_namespace n on n.oid = p.pronamespace
            where n.nspname = 'app' and has_function_privilege('anon', p.oid, 'execute')), '{}'::text[],
          'T3: khách (anon) không chạy được hàm nào trong schema app');
create function app.soat_ham_moi() returns int language sql as $$ select 1 $$;
select ok(not has_function_privilege('anon', 'app.soat_ham_moi()', 'execute')
          and not has_function_privilege('authenticated', 'app.soat_ham_moi()', 'execute'),
          'T3: hàm mới tạo mặc định không ai ngoài chủ chạy được (phải cấp rõ)');

-- ================= T4: khoá tạm không ghi nhật ký vô hạn =================
select app.login_record('khoatam@soat.hoamatoan.invalid', 'KHOA_TAM', '10.0.0.1', 'soat') from generate_series(1, 50);
select is((select count(*)::int from app.login_event where login_name = 'khoatam@soat.hoamatoan.invalid'), 1,
          'T4: gọi 50 lần khi đang khoá tạm chỉ ghi 1 dòng nhật ký');

-- ================= L1: quyền xem tài khoản theo ma trận, không viết cứng vai trò =================
select app.login_record('nv1@soat.hoamatoan.invalid', 'THANH_CONG', '10.0.0.1', 'soat');
select app.login_record('admin5@soat.hoamatoan.invalid', 'THANH_CONG', '10.0.0.5', 'soat');
set local role authenticated;
select pg_temp.claims((select id from u where key = 'bm5'), 'aal1');
select ok((select count(*) from app.user_account where login_name like '%@soat.%') > 1,
          'L1: Trưởng cơ sở (có quyền theo ma trận) thấy tài khoản cơ sở mình');
reset role;
select set_config('request.jwt.claims', '', true);
-- Admin bỏ quyền xem tài khoản của Trưởng cơ sở trong ma trận (ở đây: chủ DB, như migration).
select is(pg_temp.err($$select app.set_permission('BRANCH_MANAGER', 'ACCOUNT', 'XEM', null)$$), null,
          'L1: Admin bỏ được quyền xem tài khoản của Trưởng cơ sở');
set local role authenticated;
select pg_temp.claims((select id from u where key = 'bm5'), 'aal1');
select is((select count(*)::int from app.user_account where login_name like '%@soat.%'), 1,
          'L1: bỏ quyền trong ma trận thì Trưởng cơ sở chỉ còn thấy tài khoản của mình');
select is((select count(*)::int from app.user_role ur join app.user_account a on a.id = ur.user_id
            where a.login_name like '%@soat.%'), 1,
          'L1: bỏ quyền trong ma trận thì Trưởng cơ sở chỉ còn thấy vai trò của mình');
select is((select count(*)::int from app.login_event where login_name like '%@soat.%'), 0,
          'L1: bỏ quyền trong ma trận thì Trưởng cơ sở không thấy nhật ký đăng nhập');
reset role;
select set_config('request.jwt.claims', '', true);

select * from finish();
rollback;
