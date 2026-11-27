-- D-27-04 (migration 694; R-CRM-42, R-CRM-43): ghi nhận liên hệ trên hồ sơ phụ huynh, học sinh; lịch hẹn gắn PH/HS. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@lh.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@lh.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999994' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);




-- ---------- Hồ sơ giả ----------
insert into app.parent (code, full_name, phone, branch_id)
values ('PHD9401', 'Phụ huynh Giả Liên Hệ', '0991269401', (select id from app.branch where code = 'CS1')),
       ('PHD9402', 'Phụ huynh Giả Đã Gộp', '0991269402', (select id from app.branch where code = 'CS1'));
update app.parent set record_status = 'DA_GOP', merged_into_id = (select id from app.parent where code = 'PHD9401') where code = 'PHD9402';
insert into app.student (code, full_name, birth_year, parent_id, branch_id)
values ('HSD9401', 'Học sinh Giả Liên Hệ', 2012, (select id from app.parent where code = 'PHD9401'), (select id from app.branch where code = 'CS1'));
create temp table ids as
  select (select id from app.parent where code = 'PHD9401') as p, (select id from app.parent where code = 'PHD9402') as gop,
         (select id from app.student where code = 'HSD9401') as s;
grant select on ids to authenticated;

-- ================= R-CRM-43: ghi nhận liên hệ =================
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.log_contact('PARENT', (select p from ids), 'GOI_DIEN', 'NGHE_MAY', 'Hỏi thăm giả')$$), null,
  'R-CRM-43 đúng: CSKH cùng cơ sở ghi nhận liên hệ phụ huynh');
select is((select contact_channel || '|' || contact_result from app.record_notes('PARENT', (select p from ids)) where body = 'Hỏi thăm giả'),
  'Gọi điện|Nghe máy, đã trao đổi', 'R-CRM-43: ghi chú trả kèm tên kênh và kết quả');
select app.add_note('PARENT', (select p from ids), 'Ghi chú thường giả');
select is((select contact_channel from app.record_notes('PARENT', (select p from ids)) where body = 'Ghi chú thường giả'), null,
  'R-CRM-43: ghi chú thường không có kênh liên hệ');
select is((select count(*)::int from app.appointment where parent_id = (select p from ids)), 0, 'Không hẹn lần sau thì không tạo lịch hẹn');
select is(pg_temp.err($$select app.log_contact('LEAD', gen_random_uuid(), 'GOI_DIEN', 'NGHE_MAY', 'x')$$), 'HMT_LOAI_BAN_GHI_SAI',
  'R-CRM-43 chặn: chỉ hồ sơ phụ huynh, học sinh');
select is(pg_temp.err($$select app.log_contact('PARENT', (select p from ids), 'GOI_DIEN', 'NGHE_MAY', '   ')$$), 'HMT_THIEU_THONG_TIN',
  'R-CRM-43 chặn: thiếu nội dung');
select is(pg_temp.err($$select app.log_contact('PARENT', (select p from ids), null, 'NGHE_MAY', 'x')$$), 'HMT_THIEU_THONG_TIN',
  'R-CRM-43 chặn: thiếu kênh');
select isnt(pg_temp.err($$select app.log_contact('PARENT', (select p from ids), 'BO_CAU', 'NGHE_MAY', 'x')$$), null,
  'R-CRM-43 chặn: kênh ngoài danh mục');
select isnt(pg_temp.err($$select app.log_contact('PARENT', (select p from ids), 'ZALO', 'SAI_SO', 'x')$$), null,
  'R-CRM-43 chặn: kết quả ngoài danh mục liên hệ');
select is(pg_temp.err($$select app.log_contact('PARENT', (select gop from ids), 'ZALO', 'NGHE_MAY', 'x')$$), 'HMT_BAN_GHI_DA_GOP',
  'R-CRM-43 chặn: hồ sơ đã gộp');
select is(pg_temp.err($$select app.log_contact('PARENT', (select p from ids), 'ZALO', 'HEN_GOI_LAI', 'Hẹn quá khứ giả', now() - interval '1 hour')$$),
  'HMT_HEN_LAN_SAU_QUA_KHU', 'R-CRM-43 chặn: hẹn lần sau ở quá khứ');
select is((select count(*)::int from app.record_notes('PARENT', (select p from ids)) where body = 'Hẹn quá khứ giả'), 0,
  'Lỗi hẹn lần sau thì không lưu liên hệ');

-- ================= R-CRM-42: lịch hẹn gắn phụ huynh, học sinh =================
select is(pg_temp.err($$select app.log_contact('PARENT', (select p from ids), 'KHAC', 'HEN_GOI_LAI', 'Hẹn PH giả', now() + interval '2 days')$$), null,
  'R-CRM-42 đúng: hẹn lần sau trên phụ huynh');
select is((select activity_code || '|' || title || '|' || (owner_id = pg_temp.uid('cskh1'))::text from app.appointment where parent_id = (select p from ids)),
  'GOI_DIEN|Liên hệ lại|true', 'R-CRM-42: kênh Khác hẹn bằng Gọi điện, người ghi phụ trách');
select is(pg_temp.err($$select app.log_contact('STUDENT', (select s from ids), 'ZALO', 'NGHE_MAY', 'Hẹn HS giả', now() + interval '2 days')$$), null,
  'R-CRM-42 đúng: hẹn lần sau trên học sinh');
select is((select activity_code from app.appointment where student_id = (select s from ids)), 'ZALO', 'Lịch của học sinh theo kênh liên hệ');
select is((app.list_appointments(jsonb_build_object('parent_id', (select p from ids))) ->> 'total')::int, 1, 'Danh sách lọc theo phụ huynh');
select is(app.list_appointments(jsonb_build_object('student_id', (select s from ids))) -> 'rows' -> 0 ->> 'record_code', 'HSD9401',
  'Danh sách trả mã hồ sơ học sinh');
select is(app.list_appointments(jsonb_build_object('parent_id', (select p from ids))) -> 'rows' -> 0 ->> 'record_label', 'Phụ huynh Giả Liên Hệ',
  'Danh sách trả tên phụ huynh');
select is((app.list_appointments('{"kind": ["STUDENT"], "q": "Học sinh Giả Liên Hệ"}'::jsonb) ->> 'total')::int, 1, 'Lọc theo loại hồ sơ và tìm theo tên');
select is((select count(*)::int from jsonb_array_elements(app.appointment_group_counts(
             jsonb_build_object('q', 'Giả Liên Hệ'), array['kind']) -> 'groups') g where g ->> 'l1' in ('Phụ huynh', 'Học sinh')), 2,
  'Group By loại hồ sơ có nhóm Phụ huynh, Học sinh');
select is(pg_temp.err($$select app.create_appointment(null, 'GOI_DIEN', now() + interval '1 day', 'Hai hồ sơ', null, null, null,
             (select p from ids), (select s from ids))$$), 'HMT_LICH_HEN_MO_COI', 'R-CRM-42 chặn: gắn hai hồ sơ');
select is(pg_temp.err($$select app.create_appointment(null, 'GOI_DIEN', now() + interval '1 day', 'Không hồ sơ')$$), 'HMT_LICH_HEN_MO_COI',
  'R-CRM-42 chặn: không gắn hồ sơ nào');
select is(pg_temp.err($$select app.complete_appointment((select id from app.appointment where parent_id = (select p from ids)),
             'HEN_GOI_LAI', null, now() + interval '5 days')$$), null, 'Hoàn thành lịch của phụ huynh kèm hẹn lần sau');
select is((select count(*)::int from app.appointment where parent_id = (select p from ids) and status = 'CHUA_LAM'), 1, 'Lịch kế gắn cùng phụ huynh');
select is((select count(*)::int from app.record_notes('PARENT', (select p from ids)) where body like 'Hoàn thành lịch hẹn "Liên hệ lại"%'), 1,
  'Ghi chú hệ thống nằm trên hồ sơ phụ huynh');

-- ================= Quyền theo cơ sở =================
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.log_contact('PARENT', (select p from ids), 'ZALO', 'NGHE_MAY', 'Không có quyền giả')$$), 'HMT_KHONG_CO_QUYEN',
  'R-CRM-43 chặn: người không xem được hồ sơ (giáo viên) không ghi được');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select isnt(pg_temp.err($$select app.log_contact('PARENT', (select p from ids), 'ZALO', 'HEN_GOI_LAI', 'Khác cơ sở giả', now() + interval '1 day')$$), null,
  'R-CRM-42 chặn: người cơ sở khác không đặt được lịch hẹn cho hồ sơ cơ sở này');
select is((select count(*)::int from app.record_notes('PARENT', (select p from ids)) where body = 'Khác cơ sở giả'), 0,
  'Không đặt được lịch thì không lưu liên hệ');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.log_contact('STUDENT', (select s from ids), 'ZALO', 'NGHE_MAY', 'Học sinh tự ghi giả')$$), 'HMT_KHONG_CO_QUYEN',
  'R-CRM-43 chặn: tài khoản học sinh không ghi được');

select * from finish();
rollback;
