-- KH-03 Sửa phụ huynh, KH-06 Sửa học sinh: app.update_parent, app.update_student (migration 570).
-- Luật: R-CRM-27 (không trùng SĐT, không trùng em), R-CRM-28 (cơ sở tiếp nhận chỉ Admin), R-CRM-25 (bản đã gộp chỉ đọc), R-V2-04, Đ165.
begin;
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
create function pg_temp.msg(p_sql text) returns text language plpgsql as $$
declare v_msg text;
begin
  execute p_sql;
  return null;
exception when others then
  get stacked diagnostics v_msg = message_text;
  return v_msg;
end $$;
create function pg_temp.claims(p_user uuid, p_aal text) returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
create function pg_temp.uid(p_key text) returns uuid language plpgsql stable as $$ begin return (select id from pg_temp.u where key = p_key); end $$;
grant execute on all functions in schema pg_temp to public;

create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('admin'), ('sales1'), ('sales2'), ('acct1');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@ts.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@ts.hoamatoan.invalid',
       (select id from app.branch where code = case u.key when 'sales2' then 'CS2' else 'CS1' end), false
  from u;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('sales1', 'SALES'), ('sales2', 'SALES'), ('acct1', 'ACCOUNTANT')) as v (key, role) on v.key = u.key;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);

insert into app.parent (code, full_name, phone, branch_id)
values ('PHKH36A', 'Phụ huynh Mẫu A', '0991360001', (select id from app.branch where code = 'CS1')),
       ('PHKH36B', 'Phụ huynh Mẫu B', '0991360002', (select id from app.branch where code = 'CS1'));
update app.parent set phone_2 = '0991360003' where code = 'PHKH36B';
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
select c.code, (select id from app.parent where code = 'PHKH36A'), c.name, c.y, (select id from app.branch where code = 'CS1')
  from (values ('HSKH361', 'Em Kamột', 2012), ('HSKH362', 'Em Kahai', 2013)) as c (code, name, y);
create temp table ids as select
  (select id from app.parent where code = 'PHKH36A') as pa, (select id from app.parent where code = 'PHKH36B') as pb,
  (select id from app.student where code = 'HSKH361') as s1, (select id from app.student where code = 'HSKH362') as s2,
  (select id from app.branch where code = 'CS2') as cs2;
grant select on ids to authenticated;

-- ===== Phụ huynh: Sale đúng cơ sở sửa được =====
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select lives_ok($$select app.update_parent((select pa from ids), '{"full_name":" Phụ huynh Mẫu A mới ","phone_2":"0991360009","relative_name":"Bà nội","address":"Số 1"}'::jsonb)$$,
                'Sale đúng cơ sở sửa được phụ huynh');
select is((select full_name || '|' || phone_2 || '|' || relative_name from app.parent where code = 'PHKH36A'),
          'Phụ huynh Mẫu A mới|0991360009|Bà nội', 'Sửa phụ huynh: tên được cắt khoảng trắng, các ô đổi đúng');
select is((select phone from app.parent where code = 'PHKH36A'), '0991360001', 'Khoá không gửi thì giữ nguyên (số chính)');
-- Luật R-V2-04
select is(pg_temp.err($$select app.update_parent((select pa from ids), '{"phone":"12345"}'::jsonb)$$), 'HMT_SDT_SAI', 'Luật R-V2-04: số chính không đủ 10 số bị chặn');
select is(pg_temp.err($$select app.update_parent((select pa from ids), '{"phone_2":"099"}'::jsonb)$$), 'HMT_SDT_SAI', 'Luật R-V2-04: số thứ hai sai bị chặn');
select is(pg_temp.err($$select app.update_parent((select pa from ids), '{"full_name":"  "}'::jsonb)$$), 'HMT_THIEU_THONG_TIN', 'Luật: họ tên rỗng bị chặn');
-- Luật R-CRM-27: trùng số chính hoặc số thứ hai của phụ huynh khác
select is(pg_temp.err($$select app.update_parent((select pa from ids), '{"phone":"0991360002"}'::jsonb)$$), 'HMT_SDT_TRUNG', 'Luật R-CRM-27: trùng số chính của phụ huynh khác bị chặn');
select is(pg_temp.err($$select app.update_parent((select pa from ids), '{"phone_2":"0991360003"}'::jsonb)$$), 'HMT_SDT_TRUNG', 'Luật R-CRM-27: trùng số thứ hai của phụ huynh khác bị chặn');
select lives_ok($$select app.update_parent((select pa from ids), '{"phone":"0991360001"}'::jsonb)$$, 'Giữ nguyên số của chính mình không bị báo trùng');
-- Luật R-CRM-28
select is(pg_temp.err(format($f$select app.update_parent((select pa from ids), '{"branch_id":"%s"}'::jsonb)$f$, (select cs2 from ids))), 'HMT_CHI_ADMIN_DOI_CO_SO', 'Luật R-CRM-28: Sale không đổi được cơ sở tiếp nhận');
select is(app.get_parent_edit_refs((select pa from ids)) ->> 'province_code', null, 'Mã tỉnh trả đúng (chưa có thì rỗng)');
select is(pg_temp.err($$select app.update_parent('00000000-0000-0000-0000-000000000000', '{}'::jsonb)$$), 'HMT_KHONG_TIM_THAY', 'Phụ huynh không có thật bị chặn');
reset role;

-- ===== Phụ huynh: ngoài phạm vi =====
select pg_temp.claims(pg_temp.uid('sales2'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.update_parent((select pa from ids), '{"address":"X"}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Sale cơ sở khác không sửa được phụ huynh');
reset role;
select pg_temp.claims(pg_temp.uid('acct1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.update_parent((select pa from ids), '{"address":"X"}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Kế toán không có quyền Sửa phụ huynh');
reset role;

-- ===== Admin đổi cơ sở tiếp nhận =====
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
set local role authenticated;
select lives_ok(format($f$select app.update_parent((select pa from ids), '{"branch_id":"%s"}'::jsonb)$f$, (select cs2 from ids)), 'Luật R-CRM-28: Admin đổi được cơ sở tiếp nhận');
select is((select branch_id from app.parent where code = 'PHKH36A'), (select cs2 from ids), 'Cơ sở tiếp nhận đã đổi');
reset role;
-- trả về CS1 cho các bài sau
update app.parent set branch_id = (select id from app.branch where code = 'CS1') where code = 'PHKH36A';

-- ===== Học sinh =====
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select lives_ok($$select app.update_student((select s1 from ids), '{"full_name":"Em Kamột Sửa","grade":7,"school":"THCS Mẫu","gender":"NAM","goal":"Vào lớp chọn"}'::jsonb)$$, 'Sale đúng cơ sở sửa được học sinh');
select is((select full_name || '|' || grade || '|' || school || '|' || gender || '|' || goal from app.student where code = 'HSKH361'),
          'Em Kamột Sửa|7|THCS Mẫu|NAM|Vào lớp chọn', 'Sửa học sinh: các ô đổi đúng');
select is((select birth_year from app.student where code = 'HSKH361'), 2012, 'Năm sinh giữ nguyên khi không gửi');
select lives_ok($$select app.update_student((select s1 from ids), '{"birth_date":"2012-05-06"}'::jsonb)$$, 'Gửi ngày sinh mà không gửi năm: lấy năm từ ngày sinh');
select is((select birth_year from app.student where code = 'HSKH361'), 2012, 'Năm sinh lấy từ ngày sinh');
select is(pg_temp.err($$select app.update_student((select s1 from ids), '{"birth_date":"2011-05-06","birth_year":2012}'::jsonb)$$), 'HMT_NAM_SINH_SAI', 'Luật Đ165: ngày sinh không khớp năm sinh bị chặn');
select is(pg_temp.err($$select app.update_student((select s1 from ids), '{"birth_year":1800}'::jsonb)$$), 'HMT_NAM_SINH_SAI', 'Luật: năm sinh quá cũ bị chặn');
select is(pg_temp.err($$select app.update_student((select s1 from ids), '{"full_name":""}'::jsonb)$$), 'HMT_THIEU_HOC_SINH', 'Luật R-CRM-03: thiếu họ tên bị chặn');
select is(pg_temp.err($$select app.update_student((select s1 from ids), '{"full_name":"em kahai","birth_date":null,"birth_year":2013}'::jsonb)$$), 'HMT_HOC_SINH_TRUNG', 'Luật R-CRM-27: trùng họ tên (không dấu) và năm sinh trong cùng phụ huynh bị chặn');
select lives_ok($$select app.update_student((select s1 from ids), '{"full_name":"Em Kahai","birth_date":null,"birth_year":2010}'::jsonb)$$, 'Cùng tên khác năm sinh thì không trùng');
select is(pg_temp.err(format($f$select app.update_student((select s1 from ids), '{"branch_id":"%s"}'::jsonb)$f$, (select cs2 from ids))), 'HMT_CHI_ADMIN_DOI_CO_SO', 'Luật R-CRM-28: Sale không đổi được cơ sở tiếp nhận của học sinh');
reset role;
select pg_temp.claims(pg_temp.uid('sales2'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.update_student((select s1 from ids), '{"school":"X"}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Sale cơ sở khác không sửa được học sinh');
reset role;

-- ===== Không lộ tên, mã của hồ sơ trùng ở cơ sở ngoài phạm vi (cùng loại lỗi E67) =====
insert into app.parent (code, full_name, phone, branch_id)
values ('PHKH36C', 'Phụ huynh Cơ sở Hai', '0991360004', (select id from app.branch where code = 'CS2'));
insert into app.student (code, parent_id, full_name, birth_year, branch_id)
values ('HSKH363', (select id from app.parent where code = 'PHKH36A'), 'Em Kaba', 2014, (select id from app.branch where code = 'CS2'));
-- Ma trận mặc định cho Sale xem toàn hệ thống (R-CRM-26); ở đây thu hẹp về cơ sở mình để thử trường hợp ngoài phạm vi.
update app.permission set scope_code = 'CO_SO' where role_code = 'SALES' and module_code in ('PARENT', 'STUDENT') and action_code = 'XEM' and is_active;
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.update_parent((select pb from ids), '{"phone":"0991360004"}'::jsonb)$$), 'HMT_SDT_TRUNG', 'Trùng SĐT với phụ huynh cơ sở khác vẫn bị chặn');
select is(pg_temp.msg($$select app.update_parent((select pb from ids), '{"phone":"0991360004"}'::jsonb)$$), 'Số điện thoại đã có ở phụ huynh khác.',
          'Luật phạm vi: trùng SĐT ở cơ sở ngoài phạm vi, thông báo chung, không lộ tên, mã');
select ok(pg_temp.msg($$select app.update_parent((select pb from ids), '{"phone":"0991360001"}'::jsonb)$$) like '%PHKH36A%',
          'Trong phạm vi: trùng SĐT ở cơ sở mình, thông báo có tên và mã');
select is(pg_temp.err($$select app.update_student((select s2 from ids), '{"full_name":"Em Kaba","birth_date":null,"birth_year":2014}'::jsonb)$$), 'HMT_HOC_SINH_TRUNG', 'Trùng em ở cơ sở khác vẫn bị chặn');
select is(pg_temp.msg($$select app.update_student((select s2 from ids), '{"full_name":"Em Kaba","birth_date":null,"birth_year":2014}'::jsonb)$$),
          'Phụ huynh này đã có học sinh trùng họ tên và năm sinh.', 'Luật phạm vi: em trùng ở cơ sở ngoài phạm vi, thông báo chung, không lộ tên, mã');
reset role;

-- ===== Bản đã gộp chỉ đọc (R-CRM-25) =====
update app.student set record_status = 'DA_GOP', merged_into_id = (select s2 from ids) where id = (select s1 from ids);
update app.parent set record_status = 'DA_GOP', merged_into_id = (select pb from ids) where id = (select pa from ids);
select pg_temp.claims(pg_temp.uid('sales1'), 'aal1');
set local role authenticated;
select is(pg_temp.err($$select app.update_student((select s1 from ids), '{"school":"X"}'::jsonb)$$), 'HMT_BAN_GHI_DA_GOP', 'Luật R-CRM-25: học sinh đã gộp chỉ đọc');
select is(pg_temp.err($$select app.update_parent((select pa from ids), '{"address":"X"}'::jsonb)$$), 'HMT_BAN_GHI_DA_GOP', 'Luật R-CRM-25: phụ huynh đã gộp chỉ đọc');
reset role;

select * from finish();
rollback;
