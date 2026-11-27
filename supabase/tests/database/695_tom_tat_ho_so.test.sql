-- D-27-04 PR C (migration 695): thẻ tóm tắt và cờ đầu hồ sơ phụ huynh, học sinh; tiền theo quyền. Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@tt.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@tt.hoamatoan.invalid', (select id from app.branch where code = v.cs),
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
values ('PHD9501', 'Phụ huynh Giả Tóm Tắt', '0991269501', (select id from app.branch where code = 'CS1'));
-- Lùi ngày tạo 40 ngày (trigger cột chuẩn giữ nguyên created_at nên tắt tạm trong giao dịch thử).
alter table app.parent disable trigger parent_fill_standard;
update app.parent set created_at = now() - interval '40 days' where code = 'PHD9501';
alter table app.parent enable trigger parent_fill_standard;
insert into app.student (code, full_name, birth_year, parent_id, branch_id)
values ('HSD9501', 'Học sinh Giả Tóm Tắt', 2012, (select id from app.parent where code = 'PHD9501'), (select id from app.branch where code = 'CS1'));
create temp table ids as
  select (select id from app.parent where code = 'PHD9501') as p, (select id from app.student where code = 'HSD9501') as s;
grant select on ids to authenticated;

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.get_parent_summary((select p from ids)) ->> 'children_total', '1', 'Thẻ Con: đếm con đang dùng');
select is(app.get_parent_summary((select p from ids)) -> 'last_contact', 'null'::jsonb, 'Chưa liên hệ lần nào thì thẻ trống');
select is(app.get_parent_summary((select p from ids)) ->> 'days_since_created', '40', 'Số ngày từ lúc tạo (tính cờ khi chưa liên hệ)');
select is(app.get_parent_summary((select p from ids)) ->> 'stale_days', '30', 'Ngưỡng lâu chưa liên hệ lấy từ tham số');
select app.log_contact('STUDENT', (select s from ids), 'ZALO', 'NGHE_MAY', 'Liên hệ giả qua con');
select is(app.get_parent_summary((select p from ids)) -> 'last_contact' ->> 'channel', 'Zalo',
  'Lần liên hệ cuối của phụ huynh tính cả liên hệ ghi trên hồ sơ con');
select is(app.get_student_summary((select s from ids)) -> 'last_contact' ->> 'days', '0', 'Học sinh: liên hệ hôm nay là 0 ngày');
select is(app.get_student_summary((select s from ids)) -> 'attendance' ->> 'absent_streak', '0', 'Chưa điểm danh thì không có vắng liên tiếp');
select is(app.get_student_summary((select s from ids)) ->> 'absence_limit', '3', 'Ngưỡng vắng liên tiếp lấy từ tham số');
select is(app.get_student_summary((select s from ids)) ->> 'expiring', 'false', 'Không có ghi danh thì không có cờ sắp hết giờ');

-- ================= Quyền xem tiền (R-CRM-26, như migration 684) =================
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select is(app.get_parent_summary((select p from ids)) -> 'money' -> 'debt', 'null'::jsonb,
  'Chặn: người cơ sở khác xem được phụ huynh nhưng không thấy ô Còn nợ');
select is(app.get_parent_summary((select p from ids)) -> 'money' -> 'paid_total', 'null'::jsonb, 'Chặn: không thấy ô Tổng đã đóng');
select is(app.get_parent_summary((select p from ids)) -> 'money' -> 'balance', 'null'::jsonb, 'Chặn: không thấy ô Số dư');
select is(app.get_parent_summary((select p from ids)) -> 'last_contact' ->> 'channel', 'Zalo',
  'Đúng: phạm vi Toàn hệ thống ở cơ sở khác vẫn thấy lần liên hệ (như đọc ghi chú)');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(app.get_parent_summary((select p from ids)) -> 'money' ->> 'debt', '0', 'Đúng: Admin thấy ô Còn nợ (0 đồng khi chưa có đơn)');
select pg_temp.claims(pg_temp.uid('sales5'), 'aal1');
select pg_temp.claims(pg_temp.uid('teacher5'), 'aal1');
select is(pg_temp.err($$select app.get_parent_summary((select p from ids))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không xem hồ sơ phụ huynh');
select is(pg_temp.err($$select app.get_student_summary((select s from ids))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: giáo viên không được phân công em này');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.get_student_summary((select s from ids))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: tài khoản học sinh');

select * from finish();
rollback;
