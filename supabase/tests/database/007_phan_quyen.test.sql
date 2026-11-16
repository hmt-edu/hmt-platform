-- Kiểm thử phân quyền theo từng vai trò (spec 03 mục Phân quyền; docs/nghiep-vu/phan-quyen.md).
-- Mỗi người dùng giả đăng nhập bằng token sinh từ chính hook custom_access_token_hook.
begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
-- Migration 182 (QT-05): lưu ma trận qua API chỉ khi tham số permission_matrix_edit_enabled bật; các bài này thử luật lưu nên bật trong giao dịch của bài (hoàn tác khi kết thúc).
update app.setting_def set value = 'true' where key = 'permission_matrix_edit_enabled';

create function pg_temp.err(p_sql text) returns text language plpgsql as $$
declare v_hint text; v_state text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate;
  return case when v_hint like 'HMT\_%' then v_hint else v_state end;
end $$;

-- Đặt token như Supabase Auth cấp cho người dùng (qua hook). aal: 'aal1' hoặc 'aal2'.
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
insert into u (key) values ('admin'), ('bm1'), ('bm5'), ('sales5'), ('cskh1'), ('acc'), ('gv5'), ('hs'), ('khoa'), ('kiem'), ('noacc');
grant select on u to authenticated;

insert into auth.users (id, aud, role, email)
select id, 'authenticated', 'authenticated', key || '@test.hoamatoan.invalid' from u;

insert into app.user_account (id, display_name, login_name, branch_id, is_locked, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@test.hoamatoan.invalid',
       (select id from app.branch where code = v.cs), v.locked, v.mcp
  from u join (values
    ('admin', 'CS1', false, false), ('bm1', 'CS1', false, false), ('bm5', 'CS5', false, false),
    ('sales5', 'CS5', false, false), ('cskh1', 'CS1', false, false), ('acc', 'CS1', false, false),
    ('gv5', 'CS5', false, false), ('hs', 'CS5', false, true), ('khoa', 'CS5', true, false),
    ('kiem', 'CS5', false, false)
  ) as v (key, cs, locked, mcp) on v.key = u.key;

insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values
  ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'), ('sales5', 'SALES'),
  ('cskh1', 'CSKH'), ('acc', 'ACCOUNTANT'), ('gv5', 'TEACHER'), ('hs', 'STUDENT'), ('khoa', 'SALES'),
  ('kiem', 'BRANCH_MANAGER'), ('kiem', 'SALES')
) as v (key, role) on v.key = u.key;

-- Bài "ADMIN cuối cùng" cần biết chắc số ADMIN: tắt vai trò ADMIN của tài khoản ngoài bộ giả này
-- (vd tài khoản giả do db:seed-users tạo trên DB local). Cả bài chạy trong giao dịch, kết thúc thì hoàn tác.
update app.user_role set is_active = false
 where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

-- Dữ liệu để thử tách cơ sở: ghi chú gắn phòng P101 của CS1 và của CS5, sự kiện đăng nhập.
insert into app.room (branch_id, code, name) select id, 'TP1', 'Phòng thử' from app.branch where code in ('CS1', 'CS5');
insert into app.note (entity_type, entity_id, body)
select 'ROOM', r.id, 'Ghi chú phòng ' || b.code from app.room r join app.branch b on b.id = r.branch_id where r.code = 'TP1';
select app.login_record('bm1@test.hoamatoan.invalid', 'THANH_CONG', '10.0.0.1', 'thu');
select app.login_record('bm5@test.hoamatoan.invalid', 'THANH_CONG', '10.0.0.5', 'thu');

-- ================= Token (hook) =================
select is((app.custom_access_token_hook(jsonb_build_object('user_id', (select id from u where key = 'kiem'),
             'claims', '{}'::jsonb)) -> 'claims' -> 'hmt_roles'),
          '["BRANCH_MANAGER", "SALES"]'::jsonb, 'Token có đủ các vai trò của người nhiều vai trò');
select is((app.custom_access_token_hook(jsonb_build_object('user_id', (select id from u where key = 'sales5'),
             'claims', '{}'::jsonb)) -> 'claims' ->> 'hmt_branch_code'), 'CS5', 'Token có cơ sở của người dùng');
select ok((app.custom_access_token_hook(jsonb_build_object('user_id', (select id from u where key = 'khoa'),
             'claims', '{}'::jsonb)) ? 'error'), 'Tài khoản bị khoá: hook từ chối cấp token');
select is((app.custom_access_token_hook(jsonb_build_object('user_id', (select id from u where key = 'noacc'),
             'claims', '{}'::jsonb)) -> 'claims' -> 'hmt_roles'), '[]'::jsonb,
          'Đăng nhập Supabase nhưng chưa có tài khoản HMT: token không có vai trò');

-- ================= SALES CS5 =================
set local role authenticated;
select pg_temp.claims((select id from u where key = 'sales5'), 'aal1');
select ok(app.has_permission('LEAD', 'TAO'), 'SALES: tạo được lead');
select ok(not app.has_permission('LEAD', 'HUY'), 'SALES: không huỷ được lead');
select ok(not app.has_permission('ADMIN', 'XEM'), 'SALES: không có quyền Quản trị');
select ok(app.can_see_branch('LEAD', 'XEM', (select id from app.branch where code = 'CS5')), 'SALES CS5: thấy dữ liệu CS5');
select ok(not app.can_see_branch('LEAD', 'XEM', (select id from app.branch where code = 'CS1')), 'SALES CS5: KHÔNG thấy dữ liệu CS1');
select is((select count(*)::int from app.user_account), 1, 'SALES: chỉ thấy tài khoản của chính mình');
select is((select count(*)::int from app.note where body = 'Ghi chú phòng CS1'), 0, 'Nhân viên CS5 không đọc được ghi chú phòng CS1');
select is((select count(*)::int from app.note where body = 'Ghi chú phòng CS5'), 1, 'Nhân viên CS5 đọc được ghi chú phòng CS5');
select is(pg_temp.err($$select app.add_note('ROOM', (select r.id from app.room r join app.branch b on b.id = r.branch_id
                                                     where r.code = 'TP1' and b.code = 'CS1'), 'Ghi lén')$$),
          'HMT_KHONG_CO_QUYEN', 'Nhân viên CS5 không ghi chú được vào phòng CS1 (kể cả gọi thẳng hàm)');
select is(pg_temp.err($$update app.room set name = 'Đổi' where code = 'TP1'$$), '42501', 'SALES: không sửa thẳng bảng phòng');
select is(pg_temp.err($$insert into app.user_account (id, display_name, login_name, branch_id)
                        values (gen_random_uuid(), 'x', 'x', (select id from app.branch where code = 'CS1'))$$),
          '42501', 'SALES: không tự tạo tài khoản');
select is(pg_temp.err($$select app.set_setting('quotation_validity_days', '20')$$), 'HMT_KHONG_CO_QUYEN', 'SALES: không sửa Cài đặt');
select is(pg_temp.err($$select app.save_permission_matrix(app.permission_current_version(), jsonb_build_array(jsonb_build_object('role', 'SALES', 'module', 'LEAD', 'action', 'HUY', 'scope', 'CO_SO')))$$), 'HMT_KHONG_CO_QUYEN', 'SALES: không tự cấp quyền');
select is(pg_temp.err($$select app.catalog_add_item('ACTIVITY_TYPE', 'X1', 'x')$$), 'HMT_KHONG_CO_QUYEN', 'SALES: không sửa danh mục');
select is(pg_temp.err($$select app.log_export('LEAD', '{}', 5)$$), 'HMT_KHONG_CO_QUYEN', 'SALES: không xuất file lead');
select is(pg_temp.err($$select app.admin_hard_delete('app.room', gen_random_uuid(), 'thử')$$), 'HMT_KHONG_CO_QUYEN',
          'SALES: không gọi được hàm xoá của Admin');
select is((select count(*)::int from app.audit_log), 0, 'SALES: không đọc nhật ký thao tác');
select is((select count(*)::int from app.login_event), 0, 'SALES: không đọc sự kiện đăng nhập');
select is(pg_temp.err($$select app.login_record('x', 'THANH_CONG', null, null)$$), '42501',
          'Người dùng không tự ghi sự kiện đăng nhập (chỉ Edge Function)');
select ok((select count(*) from app.catalog_item where catalog_code = 'SUBJECT') > 0, 'SALES: đọc được danh mục');
reset role;
select set_config('request.jwt.claims', '', true);

-- ================= Trưởng cơ sở CS5 =================
set local role authenticated;
select pg_temp.claims((select id from u where key = 'bm5'), 'aal1');
select ok(app.has_permission('CLASS', 'DUYET'), 'BM: duyệt lớp được');
select ok(app.has_permission('LEAD', 'XUAT'), 'BM: xuất file được mọi phân hệ trong cơ sở (L1)');
select is((select count(*)::int from app.user_account a join app.branch b on b.id = a.branch_id where b.code = 'CS1'), 0,
          'BM CS5: không thấy tài khoản CS1');
select ok((select count(*) from app.user_account a join app.branch b on b.id = a.branch_id where b.code = 'CS5') >= 5,
          'BM CS5: thấy tài khoản CS5');
select is((select count(*)::int from app.login_event where login_name like 'bm1@%'), 0, 'BM CS5: không thấy sự kiện đăng nhập CS1');
select is((select count(*)::int from app.login_event where login_name like 'bm5@%'), 1, 'BM CS5: thấy sự kiện đăng nhập CS5');
select is(pg_temp.err($$select app.log_export('CLASS', '{"lop":"CS5-2627"}', 12)$$), null, 'BM: xuất file, có ghi nhật ký xuất');
select is(pg_temp.err($$select app.set_setting('quotation_validity_days', '20')$$), 'HMT_KHONG_CO_QUYEN', 'BM: không sửa Cài đặt (chỉ Admin)');
reset role;
select set_config('request.jwt.claims', '', true);
select is((select row_count from app.export_log where module_code = 'CLASS' order by id desc limit 1), 12,
          'Nhật ký xuất file ghi đúng số dòng');

-- ================= Nhiều vai trò: quyền là hợp =================
set local role authenticated;
select pg_temp.claims((select id from u where key = 'kiem'), 'aal1');
select ok(app.has_permission('CLASS', 'DUYET') and app.has_permission('STUDENT_TEST', 'GIAO_VIEC'),
          'BM kiêm SALES: có quyền của cả hai vai trò');
reset role;
select set_config('request.jwt.claims', '', true);

-- ================= Giáo viên =================
set local role authenticated;
select pg_temp.claims((select id from u where key = 'gv5'), 'aal1');
select is(app.permission_scope('ATTENDANCE', 'SUA'), 'DUOC_PHAN_CONG', 'Giáo viên: sửa điểm danh trong phạm vi được phân công');
select ok(not app.has_permission('ATTENDANCE', 'TAO'), 'Giáo viên: không tạo dòng điểm danh (R-GV-08)');
select ok(not app.has_permission('STUDENT_TEST', 'TAO'), 'Giáo viên: không tạo phiếu test; chỉ chấm phiếu được giao');
select ok(not app.has_permission('LEAD', 'XEM'), 'Giáo viên: không xem lead');
select ok(not app.can_see_branch('ATTENDANCE', 'XEM', (select id from app.branch where code = 'CS1')),
          'Giáo viên CS5: không thấy dữ liệu CS1 theo cơ sở');
reset role;
select set_config('request.jwt.claims', '', true);

-- ================= Xác thực hai bước: ADMIN, Kế toán =================
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal1');
select ok(not app.has_permission('ADMIN', 'XEM'), 'ADMIN chưa xác thực hai bước: không có quyền gì');
select is(pg_temp.err($$select app.set_setting('quotation_validity_days', '20')$$), 'HMT_KHONG_CO_QUYEN',
          'ADMIN chưa xác thực hai bước: không sửa Cài đặt được');
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select ok(app.has_permission('ADMIN', 'XEM'), 'ADMIN đã xác thực hai bước: có quyền Quản trị');
select ok(app.can_see_branch('LEAD', 'XEM', (select id from app.branch where code = 'CS5')), 'ADMIN: thấy mọi cơ sở');
select is(pg_temp.err($$select app.set_setting('quotation_validity_days', '20')$$), null, 'ADMIN: sửa Cài đặt được');
select ok((select count(*) from app.audit_log) > 0, 'ADMIN: đọc được nhật ký thao tác');
select ok((select count(*) from app.user_account) >= 10, 'ADMIN: thấy mọi tài khoản');
select is(pg_temp.err($$select app.save_permission_matrix(app.permission_current_version(), jsonb_build_array(jsonb_build_object('role', 'SALES', 'module', 'ADMIN', 'action', 'XEM', 'scope', 'CO_SO')))$$), 'HMT_QUYEN_QUAN_TRI',
          'Không cấp được phân hệ Quản trị cho vai trò khác ADMIN');
select is(pg_temp.err($$select app.save_permission_matrix(app.permission_current_version(), jsonb_build_array(jsonb_build_object('role', 'SALES', 'module', 'LEAD', 'action', 'HUY', 'scope', 'CO_SO')))$$), null, 'ADMIN: sửa ma trận quyền được');
select is(pg_temp.err($$select app.admin_hard_delete('app.room', (select id from app.room where code = 'TP1' limit 1), '')$$),
          'HMT_THIEU_LY_DO', 'Admin xoá nhập nhầm: bắt buộc lý do');
select is(pg_temp.err($$select app.admin_hard_delete('app.catalog_item', (select id from app.catalog_item limit 1), 'thử')$$),
          'HMT_KHONG_XOA', 'Admin xoá nhập nhầm: danh mục không bao giờ xoá được');
reset role;
select set_config('request.jwt.claims', '', true);
select ok(exists (select from app.audit_log l join app.audited_table t on t.id = l.table_id
                   where t.table_name = 'app.permission' and l.action in ('I', 'U')
                     and l.actor = (select id from u where key = 'admin')),
          'Sửa ma trận quyền có ghi nhật ký, đúng người sửa');

set local role authenticated;
select pg_temp.claims((select id from u where key = 'acc'), 'aal1');
select ok(not app.has_permission('RECEIPT', 'DUYET'), 'Kế toán chưa xác thực hai bước: không duyệt phiếu thu được');
select pg_temp.claims((select id from u where key = 'acc'), 'aal2');
select ok(app.has_permission('RECEIPT', 'DUYET'), 'Kế toán đã xác thực hai bước: duyệt phiếu thu được');
select ok(app.can_see_branch('RECEIPT', 'XEM', (select id from app.branch where code = 'CS5'))
          and app.can_see_branch('RECEIPT', 'XEM', (select id from app.branch where code = 'CS1')),
          'Kế toán: phạm vi toàn hệ thống');
reset role;
select set_config('request.jwt.claims', '', true);

-- ================= Học sinh phải đổi mật khẩu lần đầu =================
set local role authenticated;
select pg_temp.claims((select id from u where key = 'hs'), 'aal1');
select ok(not app.has_permission('LEARNING', 'XEM'), 'Học sinh chưa đổi mật khẩu lần đầu: chưa có quyền gì');
select is((select count(*)::int from app.catalog_item), 0, 'Học sinh chưa đổi mật khẩu: chưa đọc được dữ liệu');
select is((select count(*)::int from app.user_account), 1, 'Học sinh chưa đổi mật khẩu: vẫn xem được tài khoản của mình');
reset role;
select set_config('request.jwt.claims', '', true);

-- ================= Khoá tài khoản: token cũ mất tác dụng ngay =================
set local role authenticated;
select pg_temp.claims((select id from u where key = 'cskh1'), 'aal1');
select ok(app.has_permission('ATTENDANCE', 'SUA'), 'CSKH trước khi bị khoá: có quyền');
reset role;
update app.user_account set is_locked = true, lock_reason = 'Nghỉ việc (thử)' where id = (select id from u where key = 'cskh1');
set local role authenticated;
-- Dùng lại đúng token cũ (không gọi hook lại).
select ok(not app.has_permission('ATTENDANCE', 'SUA'), 'CSKH bị khoá: token cũ mất quyền ngay');
select is((select count(*)::int from app.catalog_item), 0, 'CSKH bị khoá: token cũ không đọc được dữ liệu');
reset role;
select set_config('request.jwt.claims', '', true);
select ok((select locked_at is not null from app.user_account where id = (select id from u where key = 'cskh1')),
          'Khoá tài khoản ghi lại lúc khoá');
select is(pg_temp.err($$delete from app.user_account where login_name like 'cskh1@%'$$), 'HMT_KHONG_XOA',
          'Không xoá tài khoản (khoá thay cho xoá)');

-- ================= Đăng nhập sai, khoá tạm =================
select is(app.login_precheck('khoa@test.hoamatoan.invalid'), 'TAI_KHOAN_KHOA', 'Tài khoản bị khoá: chặn trước khi gọi Auth');
select is(app.login_precheck('khongco@test.hoamatoan.invalid'), 'OK', 'Tài khoản không có: trả OK (không lộ ai có tài khoản)');
select app.login_record('sales5@test.hoamatoan.invalid', 'SAI_MAT_KHAU', '10.0.0.9', 'thu') from generate_series(1, 9);
select is(app.login_precheck('sales5@test.hoamatoan.invalid'), 'OK', 'Sai 9 lần: chưa khoá tạm');
select app.login_record('sales5@test.hoamatoan.invalid', 'SAI_MAT_KHAU', '10.0.0.9', 'thu');
select is(app.login_precheck('sales5@test.hoamatoan.invalid'), 'KHOA_TAM', 'Sai 10 lần liên tiếp: khoá tạm');
select ok((select temp_locked_until between now() + interval '14 minutes' and now() + interval '16 minutes'
             from app.user_account where login_name = 'sales5@test.hoamatoan.invalid'),
          'Khoá tạm 15 phút');
update app.user_account set temp_locked_until = now() - interval '1 second' where login_name = 'sales5@test.hoamatoan.invalid';
select app.login_record('sales5@test.hoamatoan.invalid', 'THANH_CONG', '10.0.0.9', 'thu');
select is((select failed_login_count from app.user_account where login_name = 'sales5@test.hoamatoan.invalid'), 0,
          'Đăng nhập đúng: xoá đếm sai');
select app.login_record('khongco@test.hoamatoan.invalid', 'SAI_MAT_KHAU', null, null);
select is((select result from app.login_event where login_name = 'khongco@test.hoamatoan.invalid'), 'KHONG_CO_TAI_KHOAN',
          'Đăng nhập tài khoản không có: ghi riêng loại sự kiện');
select ok(not exists (select from app.login_event where user_agent ilike '%password%' or login_name ilike '%password%'),
          'Sự kiện đăng nhập không chứa mật khẩu');
select is(pg_temp.err($$delete from app.login_event$$), 'HMT_NHAT_KY_CHI_THEM', 'Sự kiện đăng nhập không xoá được');

-- Tên không có tài khoản cũng bị khoá tạm như tên có (không lộ ai có tài khoản).
select app.login_record('ma@test.hoamatoan.invalid', 'SAI_MAT_KHAU', null, null) from generate_series(1, 9);
select is(app.login_precheck('ma@test.hoamatoan.invalid'), 'OK', 'Tên không có tài khoản, sai 9 lần: chưa khoá tạm');
select app.login_record('ma@test.hoamatoan.invalid', 'SAI_MAT_KHAU', null, null);
select is(app.login_precheck('ma@test.hoamatoan.invalid'), 'KHOA_TAM',
          'Tên không có tài khoản, sai 10 lần: khoá tạm giống tài khoản có');

-- ================= Tách quyền tiền (R-TIEN-01) =================
set local role authenticated;
select pg_temp.claims((select id from u where key = 'bm5'), 'aal1');
select ok(app.has_permission('RECEIPT', 'DUYET'), 'Trưởng cơ sở: duyệt phiếu thu bước quản lý (B2, R-TIEN-01); bước kế toán vẫn chỉ Kế toán');
select ok(not app.has_permission('ACCOUNTING', 'DUYET'), 'Trưởng cơ sở: KHÔNG duyệt khoản tiền vào, hoàn tiền, phiếu chi');
select ok(app.has_permission('SALES_ORDER', 'DUYET'), 'Trưởng cơ sở: vẫn duyệt đơn hàng (R-TIEN-01)');
select ok(app.has_permission('ACCOUNTING', 'XEM'), 'Trưởng cơ sở: xem phân hệ Kế toán được');
select ok(not app.has_permission('ACCOUNTING', 'TAO') and not app.has_permission('ACCOUNTING', 'SUA')
          and not app.has_permission('ACCOUNTING', 'HUY'), 'Trưởng cơ sở: KHÔNG tạo, sửa, huỷ ở phân hệ Kế toán');
select ok(app.has_permission('UPSALE', 'XEM') and app.has_permission('UPSALE', 'GIAO_VIEC'),
          'Trưởng cơ sở: xem, giao việc phiếu tái tục');
select ok(not app.has_permission('UPSALE', 'DUYET'), 'Trưởng cơ sở: phiếu tái tục không có bước Duyệt');
reset role;
select set_config('request.jwt.claims', '', true);
select is((select array_agg(distinct role_code order by role_code) from app.permission
            where module_code in ('RECEIPT', 'ACCOUNTING') and action_code = 'DUYET' and is_active),
          '{ACCOUNTANT,BRANCH_MANAGER}'::text[], 'Duyệt phiếu thu: Kế toán (bước kế toán) và Trưởng cơ sở (bước quản lý, B2); ADMIN không');
select is((select count(*)::int from app.permission where module_code = 'UPSALE' and action_code = 'DUYET' and is_active), 0,
          'Phiếu tái tục: không vai trò nào có quyền Duyệt');

-- Kế toán vắng: Admin tạm gán vai trò ACCOUNTANT cho người làm thay (ở đây: chính Admin).
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select ok(not app.has_permission('RECEIPT', 'DUYET'), 'ADMIN: không duyệt phiếu thu');
select is(pg_temp.err($$select app.admin_set_roles((select id from u where key = 'admin'), '{ADMIN,ACCOUNTANT}')$$), null,
          'Kế toán vắng: Admin tạm gán vai trò ACCOUNTANT được');
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select ok(app.has_permission('RECEIPT', 'DUYET'), 'Người được gán tạm ACCOUNTANT: duyệt phiếu thu được');
reset role;
select set_config('request.jwt.claims', '', true);
select ok(exists (select from app.audit_log l join app.audited_table t on t.id = l.table_id
                   where t.table_name = 'app.user_role' and l.action = 'I'
                     and l.actor = (select id from u where key = 'admin')),
          'Gán tạm vai trò ACCOUNTANT có ghi nhật ký');

-- ================= Bỏ vai trò, đổi cơ sở, khoá: thu hồi mọi phiên =================
insert into auth.sessions (id, user_id) select gen_random_uuid(), id from u where key in ('kiem', 'sales5', 'bm1');
set local role authenticated;
select pg_temp.claims((select id from u where key = 'kiem'), 'aal1');
select ok(app.has_permission('CLASS', 'DUYET'), 'BM kiêm SALES trước khi bị bỏ vai trò BM: duyệt lớp được');
reset role;
-- Admin bỏ vai trò BM của "kiem" (giữ SALES).
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select is(pg_temp.err($$select app.admin_set_roles((select id from u where key = 'kiem'), '{SALES}')$$), null,
          'Admin bỏ bớt vai trò được');
reset role;
-- Dùng lại token cũ của "kiem": mất tác dụng ngay.
select set_config('request.jwt.claims',
  (select jsonb_build_object('sub', id, 'role', 'authenticated', 'aal', 'aal1', 'hmt_roles', '["BRANCH_MANAGER","SALES"]'::jsonb,
     'hmt_branch_id', (select id from app.branch where code = 'CS5'), 'hmt_session_version', 0)::text from u where key = 'kiem'), true);
set local role authenticated;
select ok(not app.has_permission('CLASS', 'DUYET'), 'Bỏ vai trò: token cũ mất quyền của vai trò bị bỏ ngay');
select ok(not app.has_permission('LEAD', 'TAO'), 'Bỏ vai trò: token cũ mất tác dụng hẳn (phải đăng nhập lại)');
select is((select count(*)::int from app.catalog_item), 0, 'Bỏ vai trò: token cũ không đọc được dữ liệu');
reset role;
select is((select count(*)::int from auth.sessions where user_id = (select id from u where key = 'kiem')), 0,
          'Bỏ vai trò: mọi phiên của người đó bị đăng xuất');
set local role authenticated;
select pg_temp.claims((select id from u where key = 'kiem'), 'aal1');
select ok(app.has_permission('LEAD', 'TAO') and not app.has_permission('CLASS', 'DUYET'),
          'Bỏ vai trò: đăng nhập lại chỉ còn quyền của vai trò còn lại');
reset role;

-- Chỉ thêm vai trò: không đăng xuất.
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select app.admin_set_roles((select id from u where key = 'sales5'), '{SALES,CSKH}');
reset role;
select is((select count(*)::int from auth.sessions where user_id = (select id from u where key = 'sales5')), 1,
          'Chỉ thêm vai trò: không đăng xuất phiên đang dùng');

-- Đổi cơ sở: đăng xuất (cơ sở nằm trong token).
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select app.admin_set_branch((select id from u where key = 'bm1'), 'CS5');
reset role;
select is((select count(*)::int from auth.sessions where user_id = (select id from u where key = 'bm1')), 0,
          'Đổi cơ sở: mọi phiên của người đó bị đăng xuất');

-- Khoá qua hàm quản trị: đăng xuất.
insert into auth.sessions (id, user_id) select gen_random_uuid(), id from u where key = 'sales5';
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select app.admin_set_locked((select id from u where key = 'sales5'), true, 'Nghỉ việc (thử)');
reset role;
select is((select count(*)::int from auth.sessions where user_id = (select id from u where key = 'sales5')), 0,
          'Khoá tài khoản: mọi phiên bị đăng xuất');

-- Người không phải Admin không gọi được hàm quản trị tài khoản.
set local role authenticated;
select pg_temp.claims((select id from u where key = 'bm5'), 'aal1');
select is(pg_temp.err($$select app.admin_set_roles((select id from u where key = 'gv5'), '{ADMIN}')$$), 'HMT_KHONG_CO_QUYEN',
          'Trưởng cơ sở: không đổi vai trò được');
select is(pg_temp.err($$select app.revoke_user_sessions((select id from u where key = 'gv5'))$$), '42501',
          'Người dùng không gọi thẳng được hàm thu hồi phiên');
reset role;
select set_config('request.jwt.claims', '', true);

-- ================= ADMIN cuối cùng còn hoạt động =================
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select is(pg_temp.err($$select app.admin_set_roles((select id from u where key = 'admin'), '{BRANCH_MANAGER}')$$),
          'HMT_ADMIN_CUOI_CUNG', 'Không bỏ được vai trò ADMIN của quản trị viên cuối cùng');
select is(pg_temp.err($$select app.admin_set_roles((select id from u where key = 'admin'), '{ACCOUNTANT}')$$),
          'HMT_ADMIN_CUOI_CUNG', 'ADMIN cuối cùng kiêm ACCOUNTANT: bỏ ADMIN giữ ACCOUNTANT vẫn bị chặn');
select is(pg_temp.err($$select app.admin_set_roles((select id from u where key = 'admin'), '{ADMIN}')$$), null,
          'ADMIN cuối cùng kiêm ACCOUNTANT: bỏ vai trò ACCOUNTANT tạm được (vẫn còn ADMIN)');
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
reset role;
select is(pg_temp.err($$update app.user_account set is_locked = true, lock_reason = 'thử'
                        where id = (select id from u where key = 'admin')$$),
          'HMT_ADMIN_CUOI_CUNG', 'Không khoá được quản trị viên cuối cùng (kể cả sửa thẳng bảng)');
-- Thêm ADMIN thứ hai: lúc đó bỏ vai trò ADMIN của người đầu được.
insert into app.user_role (user_id, role_code) select id, 'ADMIN' from u where key = 'acc';
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select is(pg_temp.err($$select app.admin_set_locked((select id from u where key = 'acc'), true, 'thử')$$), null,
          'Còn hai ADMIN: khoá một người được');
select is(pg_temp.err($$select app.admin_set_roles((select id from u where key = 'admin'), '{BRANCH_MANAGER}')$$),
          'HMT_ADMIN_CUOI_CUNG', 'ADMIN còn lại bị khoá thì không tính: vẫn chặn bỏ vai trò ADMIN cuối cùng');
reset role;
update app.user_account set is_locked = false where id = (select id from u where key = 'acc');
set local role authenticated;
select pg_temp.claims((select id from u where key = 'admin'), 'aal2');
select is(pg_temp.err($$select app.admin_set_roles((select id from u where key = 'admin'), '{BRANCH_MANAGER}')$$), null,
          'Còn ADMIN khác hoạt động: bỏ vai trò ADMIN được');
reset role;
select is(app.active_admin_count(), 1, 'Sau cùng còn đúng một ADMIN hoạt động');
select set_config('request.jwt.claims', '', true);

-- ================= Khách chưa đăng nhập =================
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is(pg_temp.err($$select count(*) from app.user_account$$), '42501', 'Khách: không đọc tài khoản');
select is(pg_temp.err($$select count(*) from app.permission$$), '42501', 'Khách: không đọc ma trận quyền');
reset role;
select set_config('request.jwt.claims', '', true);

select * from finish();
rollback;
