-- GĐ0 bước 4b: tìm không dấu, ghi chú nhắc tên + thông báo, lịch sử bản ghi, bộ lọc yêu thích, tìm kiếm.
-- Các phép đếm chỉ tính dữ liệu của tài khoản tạm trong bài, để chạy được cả trên DB local đã có dữ liệu giả.
begin;
-- D41 (migration 472): bài này kiểm luật «Admin, Kế toán phải qua hai bước»; luật chỉ áp khi tham số mfa_required_enabled bật (mặc định tắt), nên bật tham số ở đây.
update app.setting_def set value = 'true' where key = 'mfa_required_enabled';
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

create function pg_temp.claims(p_user uuid, p_aal text default 'aal1') returns void language plpgsql security definer as $$
declare v_result jsonb;
begin
  v_result := app.custom_access_token_hook(jsonb_build_object('user_id', p_user,
                'claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', p_aal)));
  perform set_config('request.jwt.claims', (v_result -> 'claims')::text, true);
end $$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Dữ liệu giả ----------
create temp table u (key text primary key, id uuid not null default gen_random_uuid());
insert into u (key) values ('ad'), ('bm1'), ('bm5'), ('sale1'), ('gv5'), ('khoa'), ('hs');
grant select on u to authenticated;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@k.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, staff_code, student_code, legacy_ref)
select u.id, v.name, u.key || '@k.hoamatoan.invalid', (select id from app.branch where code = v.branch), v.staff, v.student, v.legacy
  from u join (values
    ('ad', 'Đặng Quốc Huy', 'CS3', 'NV9001', null, null),
    ('bm1', 'Nguyễn Hoàng Long', 'CS1', 'NV9002', null, null),
    ('bm5', 'Hoàng Minh Đức', 'CS5', 'NV9003', null, null),
    ('sale1', 'Trần Thu Hà', 'CS1', 'NV9004', null, 'NCT-0456'),
    ('gv5', 'Lê Văn Khánh', 'CS5', 'GV9005', null, null),
    ('khoa', 'Ngô Thị Lan', 'CS1', 'NV9006', null, null),
    ('hs', 'Học Sinh Giả', 'CS5', null, 'HS999001', null)
  ) as v(key, name, branch, staff, student, legacy) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('ad', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('bm5', 'BRANCH_MANAGER'),
  ('sale1', 'SALES'), ('gv5', 'TEACHER'), ('khoa', 'SALES'), ('hs', 'STUDENT')) as v(key, role) on v.key = u.key;
update app.user_account set is_locked = true, lock_reason = 'Nghỉ việc' where id = (select id from u where key = 'khoa');

create function pg_temp.uid(p_key text) returns uuid language sql as $$ select id from u where key = p_key $$;
grant execute on all functions in schema pg_temp to public;

-- ---------- Tìm không dấu (S03-15) ----------
select is(app.fold_text('Đặng Quốc Huy'), 'dang quoc huy', 'Gấp chữ: bỏ dấu, đổi đ thành d, về chữ thường');
select ok((select search_text from app.user_account where id = pg_temp.uid('sale1')) like '%tran thu ha%nv9004%nct-0456%',
          'Cột tìm kiếm của tài khoản gồm tên, mã, mã cũ đã gấp chữ');

set local role authenticated;
select pg_temp.claims(pg_temp.uid('ad'), 'aal2');
select is((select count(*)::int from app.search_records('dang quoc')), 1, 'Tìm kiếm: gõ không dấu vẫn ra người có dấu');
select is((select title from app.search_records('NCT-0456')), 'Trần Thu Hà', 'Tìm kiếm: tìm theo mã cũ');
select is((select code from app.search_records('nv9004')), 'NV9004', 'Tìm kiếm: tìm theo mã nhân viên');
select is((select count(*)::int from app.search_records('h')), 0, 'Tìm kiếm: dưới 2 ký tự thì không trả gì');
select pg_temp.claims(pg_temp.uid('bm1'));
select is((select count(*)::int from app.search_records('tran thu ha')), 1, 'Tìm kiếm: Trưởng cơ sở thấy tài khoản cơ sở mình');
select is((select count(*)::int from app.search_records('hoang minh duc')), 0, 'Tìm kiếm: Trưởng cơ sở KHÔNG thấy tài khoản cơ sở khác');
select pg_temp.claims(pg_temp.uid('sale1'));
select is((select count(*)::int from app.search_records('dang quoc')), 0, 'Tìm kiếm: người không có quyền Tài khoản không thấy người khác');
reset role;

-- ---------- Ghi chú trên tài khoản người dùng ----------
set local role authenticated;
select pg_temp.claims(pg_temp.uid('ad'), 'aal1');
select is(pg_temp.err(format($$select app.add_note('USER_ACCOUNT', %L, 'x')$$, pg_temp.uid('sale1'))),
          'HMT_KHONG_CO_QUYEN', 'Ghi chú: Admin chưa xác thực hai bước thì không ghi được');
select pg_temp.claims(pg_temp.uid('sale1'));
select is(pg_temp.err(format($$select app.add_note('USER_ACCOUNT', %L, 'x')$$, pg_temp.uid('sale1'))),
          'HMT_KHONG_CO_QUYEN', 'Ghi chú: người không có quyền Tài khoản không ghi chú vào tài khoản');
select pg_temp.claims(pg_temp.uid('bm5'));
select is(pg_temp.err(format($$select app.add_note('USER_ACCOUNT', %L, 'x')$$, pg_temp.uid('sale1'))),
          'HMT_KHONG_CO_QUYEN', 'Ghi chú: Trưởng cơ sở khác không ghi chú vào tài khoản cơ sở này');
select pg_temp.claims(pg_temp.uid('bm1'));
select is(pg_temp.err(format($$select app.add_note('USER_ACCOUNT', %L, 'Chuyển ca sáng từ tuần sau')$$, pg_temp.uid('sale1'))),
          null, 'Ghi chú: Trưởng cơ sở ghi chú vào tài khoản cơ sở mình được');
select is((select count(*)::int from app.note where entity_type = 'USER_ACCOUNT' and entity_id = pg_temp.uid('sale1')), 1,
          'Ghi chú: Trưởng cơ sở đọc lại được');
select pg_temp.claims(pg_temp.uid('bm5'));
select is((select count(*)::int from app.note where entity_type = 'USER_ACCOUNT' and entity_id = pg_temp.uid('sale1')), 0,
          'Ghi chú: Trưởng cơ sở khác không đọc được');
reset role;

-- ---------- Gợi ý nhắc tên ----------
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'));
select is((select count(*)::int from app.mention_candidates('le van khanh')), 1, 'Nhắc tên: gợi ý cả đồng nghiệp cơ sở khác, gõ không dấu');
select is((select count(*)::int from app.mention_candidates('ngo thi lan')), 0, 'Nhắc tên: không gợi ý tài khoản đã khoá');
select is((select count(*)::int from app.mention_candidates('hoc sinh')), 0, 'Nhắc tên: không gợi ý học sinh');
select is((select count(*)::int from app.mention_candidates('nguyen hoang long')), 0, 'Nhắc tên: không gợi ý chính mình');
select pg_temp.claims(pg_temp.uid('hs'));
select is(pg_temp.err($$select * from app.mention_candidates('a')$$), 'HMT_KHONG_CO_QUYEN', 'Nhắc tên: học sinh không gọi được');
reset role;

-- ---------- Ghi chú có nhắc tên sinh thông báo ----------
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'));
select is(pg_temp.err(format($$select app.add_note_mentioning('USER_ACCOUNT', %L, 'Nhờ anh xem', array[%L]::uuid[])$$,
            pg_temp.uid('sale1'), pg_temp.uid('khoa'))),
          'HMT_NHAC_TEN_KHONG_HOP_LE', 'Nhắc tên: không nhắc được tài khoản đã khoá');
select is(pg_temp.err(format($$select app.add_note_mentioning('USER_ACCOUNT', %L, 'Nhờ em xem', array[%L]::uuid[])$$,
            pg_temp.uid('sale1'), pg_temp.uid('hs'))),
          'HMT_NHAC_TEN_KHONG_HOP_LE', 'Nhắc tên: không nhắc được học sinh');
select is(pg_temp.err(format($$select app.add_note_mentioning('USER_ACCOUNT', %L, 'x', array[%L]::uuid[])$$,
            pg_temp.uid('gv5'), pg_temp.uid('ad'))),
          'HMT_KHONG_CO_QUYEN', 'Nhắc tên: không thấy bản ghi thì không ghi chú, không nhắc tên được');
select is(pg_temp.err(format($$select app.add_note_mentioning('USER_ACCOUNT', %L, 'Nhờ anh Huy và chị Hà xem', array[%L, %L, %L, %L]::uuid[])$$,
            pg_temp.uid('sale1'), pg_temp.uid('ad'), pg_temp.uid('sale1'), pg_temp.uid('ad'), pg_temp.uid('bm1'))),
          null, 'Nhắc tên: ghi chú nhắc hai đồng nghiệp (kèm trùng và chính mình) lưu được');
reset role;
select is((select count(*)::int from app.notification where user_id in (select id from u)), 2,
          'Nhắc tên: mỗi người một thông báo, bỏ trùng, bỏ chính mình');
select is((select title from app.notification where user_id = pg_temp.uid('ad')),
          'Nguyễn Hoàng Long nhắc tên bạn trong một ghi chú (Tài khoản người dùng)', 'Thông báo ghi ai nhắc, ở loại bản ghi nào, không chép nội dung');
select is(pg_temp.err(format($$insert into app.notification (user_id, kind, title) values (%L, 'KHONG_CO', 'x')$$, pg_temp.uid('ad'))),
          'HMT_DANH_MUC_KHONG_CO', 'Thông báo: loại phải có trong danh mục');

-- Đọc ghi chú kèm tên người viết, người được nhắc.
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'));
select is((select author_name from app.record_notes('USER_ACCOUNT', pg_temp.uid('sale1')) where cardinality(mention_names) = 2),
          'Nguyễn Hoàng Long', 'Đọc ghi chú: có tên người viết');
select is((select mention_names from app.record_notes('USER_ACCOUNT', pg_temp.uid('sale1')) where cardinality(mention_names) = 2),
          array['Đặng Quốc Huy', 'Trần Thu Hà'], 'Đọc ghi chú: có tên người được nhắc');
select pg_temp.claims(pg_temp.uid('bm5'));
select is(pg_temp.err(format($$select * from app.record_notes('USER_ACCOUNT', %L)$$, pg_temp.uid('sale1'))),
          'HMT_KHONG_CO_QUYEN', 'Đọc ghi chú: không thấy bản ghi thì không đọc được');
reset role;

-- Giới hạn số người nhắc tên theo tham số.
update app.setting_def set value = '1' where key = 'note_mention_max';
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'));
select is(pg_temp.err(format($$select app.add_note_mentioning('USER_ACCOUNT', %L, 'x', array[%L, %L]::uuid[])$$,
            pg_temp.uid('sale1'), pg_temp.uid('ad'), pg_temp.uid('gv5'))),
          'HMT_NHAC_TEN_QUA_NHIEU', 'Nhắc tên: vượt tham số note_mention_max thì chặn');
reset role;

-- ---------- Thông báo: chỉ của mình ----------
create temp table n_ad as select id from app.notification where user_id = pg_temp.uid('ad');
grant select on n_ad to authenticated;
set local role authenticated;
select pg_temp.claims(pg_temp.uid('sale1'));
select is((select count(*)::int from app.notification), 1, 'Thông báo: người được nhắc thấy thông báo của mình');
select is(pg_temp.err(format($$update app.notification set read_at = now() where user_id = %L$$, pg_temp.uid('sale1'))),
          '42501', 'Thông báo: không sửa thẳng vào bảng được');
select is(app.mark_notifications_read((select id from n_ad)), 0, 'Thông báo: không đánh dấu đã đọc thông báo của người khác');
select is(app.mark_notifications_read(), 0, 'Thông báo: không truyền gì thì không đánh dấu gì');
select is(app.mark_notifications_read(null, true), 1, 'Thông báo: đánh dấu đã đọc mọi thông báo của mình');
select is((select count(*)::int from app.notification where read_at is null), 0, 'Thông báo: của mình đã đọc hết');
select pg_temp.claims(pg_temp.uid('gv5'));
select is((select count(*)::int from app.notification), 0, 'Thông báo: người khác không thấy thông báo của tôi');
select pg_temp.claims(pg_temp.uid('ad'), 'aal1');
select is((select count(*)::int from app.notification), 0, 'Thông báo: Admin chưa xác thực hai bước thì chưa thấy');
select pg_temp.claims(pg_temp.uid('ad'), 'aal2');
select is((select count(*)::int from app.notification where read_at is null), 1, 'Thông báo: của Admin vẫn chưa đọc');
select is((select count(*)::int from app.note_mention where user_id in (select id from u)), 2, 'Người thấy ghi chú thấy ai được nhắc tên');
reset role;

-- ---------- Lịch sử thay đổi của bản ghi ----------
update app.user_account set display_name = 'Trần Thu Hà (A)', failed_login_count = 3 where id = pg_temp.uid('sale1');
update app.user_account set failed_login_count = 4 where id = pg_temp.uid('sale1');
insert into app.user_role (user_id, role_code) values (pg_temp.uid('sale1'), 'CSKH');
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'));
select ok(exists (select from app.record_history('USER_ACCOUNT', pg_temp.uid('sale1'))
                   where changes -> 'display_name' = '["Trần Thu Hà", "Trần Thu Hà (A)"]'::jsonb),
          'Lịch sử: thấy đổi tên từ gì sang gì');
select ok(not exists (select from app.record_history('USER_ACCOUNT', pg_temp.uid('sale1'))
                       where changes ? 'failed_login_count' or changes ? 'search_text'),
          'Lịch sử: không hiện cột kỹ thuật (đếm sai mật khẩu, cột tìm kiếm)');
select ok(exists (select from app.record_history('USER_ACCOUNT', pg_temp.uid('sale1'))
                   where changes -> 'role:CSKH, vận hành lớp' = '[false, true]'::jsonb
                      or changes ?| array(select 'role:' || name from app.role where code = 'CSKH')),
          'Lịch sử tài khoản: gộp cả lần gán vai trò');
select is((select count(*)::int from app.record_history('USER_ACCOUNT', pg_temp.uid('sale1'), 1)), 1, 'Lịch sử: giới hạn số dòng');
select pg_temp.claims(pg_temp.uid('bm5'));
select is(pg_temp.err(format($$select * from app.record_history('USER_ACCOUNT', %L)$$, pg_temp.uid('sale1'))),
          'HMT_KHONG_CO_QUYEN', 'Lịch sử: không thấy bản ghi thì không xem được lịch sử');
select is((select count(*)::int from app.audit_log), 0, 'Nhật ký toàn hệ thống: Trưởng cơ sở vẫn không đọc thẳng được');
reset role;

-- ---------- Bộ lọc yêu thích ----------
set local role authenticated;
select pg_temp.claims(pg_temp.uid('bm1'));
select is(pg_temp.err($$select app.save_filter('QT-01', '  ', '{}', false, false)$$), 'HMT_THIEU_THONG_TIN', 'Bộ lọc: phải có tên');
select is(pg_temp.err($$select app.save_filter('QT-01', 'Chung', '{}', true, false)$$), 'HMT_KHONG_CO_QUYEN',
          'Bộ lọc: người không phải quản trị viên không lưu bộ lọc dùng chung');
select is(pg_temp.err($$select app.save_filter('QT-01', 'Đang khoá', '{"status":"locked"}', false, true)$$), null, 'Bộ lọc: lưu bộ lọc riêng, đặt mặc định');
select is(pg_temp.err($$select app.save_filter('QT-01', 'Giáo viên', '{"role":"TEACHER"}', false, true)$$), null, 'Bộ lọc: lưu bộ lọc thứ hai, đặt mặc định');
select is((select string_agg(name, ',') from app.saved_filter where is_default), 'Giáo viên', 'Bộ lọc: chỉ một bộ lọc mặc định mỗi màn');
select is(pg_temp.err($$select app.save_filter('QT-01', 'đang khoá', '{"status":"temp"}', false, false)$$), null, 'Bộ lọc: lưu trùng tên là ghi đè');
select is((select count(*)::int from app.saved_filter), 2, 'Bộ lọc: ghi đè không sinh dòng mới');
select is((select filters ->> 'status' from app.saved_filter where lower(name) = 'đang khoá'), 'temp', 'Bộ lọc: nội dung đã được ghi đè');
select is(pg_temp.err($$insert into app.saved_filter (owner_id, screen_code, name, filters) values (auth.uid(), 'QT-01', 'x', '{}')$$),
          '42501', 'Bộ lọc: không ghi thẳng vào bảng được');
select pg_temp.claims(pg_temp.uid('ad'), 'aal2');
select is((select count(*)::int from app.saved_filter), 0, 'Bộ lọc riêng: người khác (kể cả Admin) không thấy');
select is(pg_temp.err($$select app.save_filter('QT-01', 'Tài khoản tạm khoá', '{"status":"temp"}', true, false)$$), null, 'Bộ lọc: Admin lưu bộ lọc dùng chung');
select is(pg_temp.err(format($$select app.remove_filter(%L)$$, (select id from app.saved_filter limit 1))), null, 'Bộ lọc: người tạo bỏ được');
select is(pg_temp.err($$select app.save_filter('QT-01', 'Tài khoản tạm khoá', '{"status":"temp"}', true, false)$$), null, 'Bộ lọc: bỏ rồi lưu lại tên cũ được');
select pg_temp.claims(pg_temp.uid('bm1'));
select is((select count(*)::int from app.saved_filter where is_shared), 1, 'Bộ lọc dùng chung: người khác thấy (bộ đã bỏ thì không)');
select is(pg_temp.err(format($$select app.remove_filter(%L)$$, (select id from app.saved_filter where is_shared))),
          'HMT_BO_LOC_KHONG_CO', 'Bộ lọc dùng chung: người không tạo không bỏ được');
select pg_temp.claims(pg_temp.uid('hs'));
select is(pg_temp.err($$select app.save_filter('QT-01', 'x', '{}', false, false)$$), 'HMT_KHONG_CO_QUYEN', 'Bộ lọc: học sinh không lưu được');
reset role;
select is(pg_temp.err($$delete from app.saved_filter$$), 'HMT_KHONG_XOA', 'Bộ lọc: không xoá cứng, chỉ huỷ');

-- ---------- Khách chưa đăng nhập ----------
set local role anon;
select is(pg_temp.err($$select * from app.search_records('dang')$$), '42501', 'Khách: không gọi được tìm kiếm');
select is(pg_temp.err($$select * from app.mention_candidates('dang')$$), '42501', 'Khách: không gọi được gợi ý nhắc tên');
select is(pg_temp.err($$select * from app.notification$$), '42501', 'Khách: không đọc được thông báo');
select is(pg_temp.err($$select * from app.saved_filter$$), '42501', 'Khách: không đọc được bộ lọc');
reset role;
select set_config('request.jwt.claims', '', true);

select * from finish();
rollback;
