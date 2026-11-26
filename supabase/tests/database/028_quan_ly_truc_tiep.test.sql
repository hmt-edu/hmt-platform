-- R-HT-06: Quản lý trực tiếp, đường duyệt của người lập, người duyệt ở bước quản lý (đơn hàng, phiếu thu).
-- Mỗi luật có ca đúng và ca bị chặn; mỗi vai trò nhập trong và ngoài cơ sở.
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
-- Lấy câu lỗi tiếng Việt (MESSAGE) của một lệnh.
create function pg_temp.msg(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return null;
exception when others then
  return sqlerrm;
end $$;
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
-- Chạy một câu lệnh với quyền chủ DB (dựng dữ liệu thử khi đang đóng vai người dùng).
create function pg_temp.sudo(p_sql text) returns void language plpgsql security definer as $$
begin execute p_sql; end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
create function pg_temp.lead_data(p_phone text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('parent_name', 'Chị Thử Một', 'parent_phone', p_phone, 'student_name', 'Em Thử',
                            'source_type_code', 'MARKETING', 'source_code', 'FACEBOOK_ADS',
                            'channel_code', 'FACEBOOK_ADS_LEAD_FORM') || p_extra;
$$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Người dùng giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('bm1'), ('sales1'), ('sales1b'), ('sales5'), ('cskh1'), ('teacher1'), ('teacher5'), ('hs');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999999' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);


-- ================= Dựng dữ liệu =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
create function pg_temp.mgr(p_k text) returns uuid language sql stable as $$
  select manager_id from app.user_account where id = pg_temp.uid(p_k) $$;
create function pg_temp.route(p_k text) returns text language sql stable as $$
  select route || ':' || (select key from pg_temp.u where id = approver_id) from app.approval_route(pg_temp.uid(p_k)) $$;
grant execute on function pg_temp.mgr(text), pg_temp.route(text) to public;
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- ================= Đặt quản lý (chỉ Admin, có nhật ký) =================
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('bm1'));
select is(pg_temp.mgr('sales1'), pg_temp.uid('bm1'), 'R-HT-06: Admin đặt được quản lý trực tiếp');
select ok((select count(*) from app.audit_log l join app.audited_table a on a.id = l.table_id
            where a.table_name = 'app.user_account' and l.record_id = pg_temp.uid('sales1') and l.action = 'U'
              and l.changes ? 'manager_id') >= 1, 'R-HT-06: đổi quản lý ghi nhật ký');
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(pg_temp.err($$select app.set_manager(pg_temp.uid('sales1b'), pg_temp.uid('bm1'))$$), 'HMT_KHONG_CO_QUYEN', 'R-HT-06: Trưởng cơ sở không sửa được quản lý trực tiếp');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.err($$select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('sales1b'))$$), 'HMT_KHONG_CO_QUYEN', 'R-HT-06: nhân viên không tự đổi quản lý của mình');
select pg_temp.claims(pg_temp.uid('teacher1'), 'aal1');
select is(pg_temp.err($$select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('teacher1'))$$), 'HMT_KHONG_CO_QUYEN', 'R-HT-06: giáo viên không đổi được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(pg_temp.err($$select app.set_manager(pg_temp.uid('sales1b'), pg_temp.uid('bm1'))$$), 'HMT_KHONG_CO_QUYEN', 'R-HT-06: Admin chưa qua hai bước thì không sửa được');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
-- Ghi thẳng không qua hàm bị chặn (kể cả quyền máy chủ).
reset role;
select is(pg_temp.err($$update app.user_account set manager_id = (select id from pg_temp.u where key = 'bm1') where id = (select id from pg_temp.u where key = 'sales1b')$$), 'HMT_LUAT_LOI', 'R-HT-06: ghi thẳng cột manager_id không qua app.set_manager bị chặn');
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');

-- ================= Toàn vẹn: tự làm quản lý, vòng, học sinh, khoá =================
select is(pg_temp.err($$select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('sales1'))$$), 'HMT_QUAN_LY_TU_THAN', 'R-HT-06: cấm tự làm quản lý của chính mình');
select is(pg_temp.err($$select app.set_manager(pg_temp.uid('bm1'), pg_temp.uid('sales1'))$$), 'HMT_QUAN_LY_VONG', 'R-HT-06: cấm vòng trực tiếp (sales1 có quản lý bm1, bm1 không được có quản lý sales1)');
select app.set_manager(pg_temp.uid('sales1b'), pg_temp.uid('sales1'));
select is(pg_temp.err($$select app.set_manager(pg_temp.uid('bm1'), pg_temp.uid('sales1b'))$$), 'HMT_QUAN_LY_VONG', 'R-HT-06: cấm vòng qua chuỗi ba người');
select is(pg_temp.err($$select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('hs'))$$), 'HMT_QUAN_LY_SAI', 'R-HT-06: học sinh không làm quản lý được');
select is(pg_temp.err($$select app.set_manager(pg_temp.uid('hs'), pg_temp.uid('bm1'))$$), 'HMT_QUAN_LY_SAI', 'R-HT-06: học sinh không có quản lý');
reset role;
update app.user_account set is_locked = true where id = pg_temp.uid('cskh1');
set local role authenticated;
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(pg_temp.err($$select app.set_manager(pg_temp.uid('teacher5'), pg_temp.uid('cskh1'))$$), 'HMT_QUAN_LY_SAI', 'R-HT-06: quản lý phải đang hoạt động (tài khoản khoá không được chọn)');
select is(pg_temp.err($$select app.set_manager(gen_random_uuid(), pg_temp.uid('bm1'))$$), 'HMT_KHONG_TIM_THAY', 'Không có tài khoản: báo không tìm thấy');
select app.set_manager(pg_temp.uid('sales1b'), null);
select is(pg_temp.mgr('sales1b'), null, 'R-HT-06: bỏ quản lý được');
-- Quản lý nghỉ việc (khoá) sau khi gán: cột giữ nguyên.
select app.set_manager(pg_temp.uid('teacher5'), pg_temp.uid('bm1'));
reset role;
update app.user_account set is_locked = true where id = pg_temp.uid('bm1');
select is(pg_temp.mgr('teacher5'), pg_temp.uid('bm1'), 'Quản lý bị khoá sau khi gán: cột vẫn giữ (Admin duyệt thay)');
update app.user_account set is_locked = false where id = pg_temp.uid('bm1');
set local role authenticated;

-- ================= Đường duyệt chốt lúc trình =================
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(pg_temp.route('sales1'), 'QUAN_LY:bm1', 'R-HT-06: người lập có quản lý thì người duyệt là quản lý trực tiếp');
select is(pg_temp.route('bm1'), 'TU_DUYET:bm1', 'R-HT-06: Trưởng cơ sở lập thì tự duyệt (người duyệt là chính mình)');
select is(pg_temp.err($$select * from app.approval_route(pg_temp.uid('sales1b'))$$), 'HMT_KHONG_CO_QUAN_LY', 'R-HT-06: không có quản lý và không phải Trưởng cơ sở thì không trình được');
select is(pg_temp.err($$select * from app.approval_route(pg_temp.uid('hs'))$$), 'HMT_KHONG_TIM_THAY', 'Học sinh không lập đơn');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('bm1'), pg_temp.uid('admin'));
select is(pg_temp.route('bm1'), 'TU_DUYET:bm1', 'R-HT-06: Trưởng cơ sở có cả quản lý vẫn tự duyệt (xét Trưởng cơ sở trước)');
select app.set_manager(pg_temp.uid('bm1'), null);

-- ================= Ai duyệt được ở bước quản lý =================
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(app.can_approve_as_manager(pg_temp.uid('sales1')), true, 'Đơn: quản lý trực tiếp duyệt được');
select is(app.can_approve_as_manager(pg_temp.uid('bm1')), true, 'Đơn: Trưởng cơ sở tự duyệt đơn của mình');
select is(app.can_approve_as_manager(pg_temp.uid('sales1'), 'PHIEU_THU'), true, 'Phiếu thu: quản lý trực tiếp duyệt được');
select is(app.can_approve_as_manager(pg_temp.uid('bm1'), 'PHIEU_THU'), true, 'Phiếu thu: Trưởng cơ sở tự duyệt bước quản lý');
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is(app.can_approve_as_manager(pg_temp.uid('sales1')), false, 'Đơn: người khác (không phải quản lý) không duyệt được');
select is(app.can_approve_as_manager(pg_temp.uid('sales1'), 'PHIEU_THU'), false, 'Phiếu thu: người khác không duyệt được');
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
select is(app.can_approve_as_manager(pg_temp.uid('sales1')), false, 'Người lập không tự duyệt đơn của mình (khi có quản lý)');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(app.can_approve_as_manager(pg_temp.uid('sales1')), true, 'R-HT-01: Admin duyệt thay đơn khi quản lý vắng');
select is(app.can_approve_as_manager(pg_temp.uid('sales1'), 'PHIEU_THU'), true, 'R-HT-01: Admin duyệt thay được bước quản lý của phiếu thu (26/11)');
select is(app.can_approve_as_manager(pg_temp.uid('bm1'), 'PHIEU_THU'), true, 'Admin duyệt thay được phiếu thu của Trưởng cơ sở (26/11)');
select is(app.can_approve_as_manager(pg_temp.uid('sales1b')), true, 'R-HT-01: người lập chưa có quản lý thì Admin vẫn duyệt thay được đơn');
select pg_temp.claims(pg_temp.uid('admin'), 'aal1');
select is(app.can_approve_as_manager(pg_temp.uid('sales1')), false, 'Admin chưa qua hai bước thì chưa duyệt thay được');
select is(pg_temp.err($$select app.can_approve_as_manager(pg_temp.uid('sales1'), 'BAO_GIA')$$), 'HMT_LOAI_CHUNG_TU_SAI', 'Loại chứng từ lạ bị chặn');

-- ================= Người duyệt chốt lúc trình, quản lý đổi sau không đổi (Q-P5) =================
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select app.set_manager(pg_temp.uid('sales1'), pg_temp.uid('sales1b'));
select pg_temp.claims(pg_temp.uid('bm1'), 'aal2');
select is(app.can_approve_as_manager(pg_temp.uid('sales1'), 'DON', pg_temp.uid('bm1')), true, 'Q-P5: người duyệt đã chốt lúc trình (bm1) vẫn duyệt dù quản lý đã đổi');
select is(app.can_approve_as_manager(pg_temp.uid('sales1')), false, 'Chưa chốt thì tính theo quản lý hiện tại: bm1 không còn là quản lý của sales1');
select pg_temp.claims(pg_temp.uid('sales1b'), 'aal1');
select is(app.can_approve_as_manager(pg_temp.uid('sales1'), 'DON', pg_temp.uid('bm1')), false, 'Q-P5: quản lý mới không duyệt được đơn đã chốt người duyệt khác');
select is(app.can_approve_as_manager(pg_temp.uid('sales1')), true, 'Chưa chốt thì quản lý hiện tại (sales1b) duyệt được');

select * from finish();
rollback;
