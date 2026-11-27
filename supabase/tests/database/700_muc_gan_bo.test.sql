-- D-27-06 (migration 700): Mức gắn bó của học sinh (R-CRM-44). Dữ liệu giả.
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
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@tg.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, student_code, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@tg.hoamatoan.invalid', (select id from app.branch where code = v.cs),
       case when u.key = 'hs' then 'HS999970' end, false
  from u join (values ('admin', 'CS1'), ('bm1', 'CS1'), ('sales1', 'CS1'), ('sales1b', 'CS1'), ('sales5', 'CS5'),
                      ('cskh1', 'CS1'), ('teacher5', 'CS5'), ('hs', 'CS5')) as v (key, cs) on v.key = u.key;
insert into app.user_role (user_id, role_code)
select u.id, v.role from u join (values ('admin', 'ADMIN'), ('bm1', 'BRANCH_MANAGER'), ('sales1', 'SALES'), ('sales1b', 'SALES'),
  ('sales5', 'SALES'), ('cskh1', 'CSKH'), ('teacher5', 'TEACHER'), ('hs', 'STUDENT')) as v (key, role) on v.key = u.key;
-- Chỉ bộ giả này có ADMIN (tài khoản giả khác trong DB local không ảnh hưởng bài).
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);




-- ---------- Hồ sơ giả ----------
insert into app.parent (code, full_name, phone, branch_id)
values ('PHD9701', 'Phụ huynh Giả Gắn Bó', '0991269701', (select id from app.branch where code = 'CS1'));
-- Lùi ngày tạo 40 ngày (trigger cột chuẩn giữ nguyên created_at nên tắt tạm trong giao dịch thử).
alter table app.parent disable trigger parent_fill_standard;
update app.parent set created_at = now() - interval '40 days' where code = 'PHD9701';
alter table app.parent enable trigger parent_fill_standard;
insert into app.student (code, full_name, birth_year, parent_id, branch_id)
values ('HSD9701', 'Học sinh Giả Gắn Bó', 2012, (select id from app.parent where code = 'PHD9701'), (select id from app.branch where code = 'CS1'));
-- Học sinh tạo cách đây 40 ngày, chưa ai ghi liên hệ.
set local session_replication_role = 'replica';
update app.student set created_at = now() - interval '40 days' where code = 'HSD9701';
set local session_replication_role = 'origin';
create temp table ids as
  select (select id from app.parent where code = 'PHD9701') as p, (select id from app.student where code = 'HSD9701') as s;
grant select on ids to authenticated;

-- Đơn giả đã duyệt ở CS5 có dòng của em, đợt quá hạn 5 ngày. Đơn đã duyệt bị khoá nên tắt trigger tạm trong giao dịch thử.
set local session_replication_role = 'replica';
insert into app.sales_order (code, branch_id, renewal_ticket_id, parent_id, status_code, priced_on, total_amount, created_by)
values ('DH-TG-700', (select id from app.branch where code = 'CS5'), gen_random_uuid(), (select p from ids), 'DA_DUYET',
        (now() at time zone 'Asia/Ho_Chi_Minh')::date, 400000, pg_temp.uid('admin'));
insert into app.sales_order_installment (order_id, branch_id, seq, due_days, amount, due_date)
select o.id, o.branch_id, 1, 0, 400000, (now() at time zone 'Asia/Ho_Chi_Minh')::date - 5
  from app.sales_order o where o.code = 'DH-TG-700';
insert into app.sales_order_line (order_id, branch_id, line_no, student_id, package_id, package_code, package_name, package_type_code,
                                  delivery_mode_code, unit_code, quantity, unit_price, gross_amount, line_total)
select o.id, o.branch_id, 1, (select s from ids), gen_random_uuid(), 'GOI-GIA', 'Gói giả', 'GIA', 'GIA', 'GIO', 1, 400000, 400000, 400000
  from app.sales_order o where o.code = 'DH-TG-700';
set local session_replication_role = 'origin';

set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(app.get_student_summary((select s from ids)) -> 'engagement', 'null'::jsonb, 'R-CRM-44: học sinh chưa Đang học thì không có Mức gắn bó');
select pg_temp.sudo($$set local session_replication_role = 'replica'$$);
select pg_temp.sudo($$insert into app.enrollment (code, student_id, parent_id, branch_id, status_code)
  select 'GD-TG-700', s.id, s.parent_id, s.branch_id, 'DANG_HOC' from app.student s where s.code = 'HSD9701'$$);
select pg_temp.sudo($$set local session_replication_role = 'origin'$$);
select is(app.get_student_summary((select s from ids)) -> 'engagement' ->> 'level', 'CAN_CHU_Y',
  'R-CRM-44: lâu chưa liên hệ (1 điểm) là Cần chú ý');
select is(app.get_student_summary((select s from ids)) -> 'engagement' -> 'reasons', '["LAU_CHUA_LIEN_HE"]'::jsonb,
  'R-CRM-44: mức luôn kèm lý do');
select is(app.get_student_summary((select s from ids)) -> 'overdue_days', 'null'::jsonb,
  'Chặn: nợ ở đơn ngoài quyền xem không hiện và không tính');
select pg_temp.claims(pg_temp.uid('admin'), 'aal2');
select is(app.get_student_summary((select s from ids)) ->> 'overdue_days', '5', 'Đúng: người xem được đơn thấy số ngày quá hạn');
select is(app.get_student_summary((select s from ids)) -> 'engagement' ->> 'score', '3', 'R-CRM-44: nợ quá hạn cộng 2 điểm');
select is(app.get_student_summary((select s from ids)) -> 'engagement' ->> 'level', 'NGUY_CO', 'R-CRM-44: từ 3 điểm là Nguy cơ');
select pg_temp.sudo($$update app.setting_def set value = 'false' where key = 'engagement_count_overdue_debt'$$);
select is(app.get_student_summary((select s from ids)) -> 'engagement' ->> 'score', '1', 'R-CRM-44: tắt cờ nợ thì không tính điểm');
select pg_temp.sudo($$update app.setting_def set value = '2' where key = 'engagement_warn_score'$$);
select is(app.get_student_summary((select s from ids)) -> 'engagement' ->> 'level', 'KHOE', 'R-CRM-44: ngưỡng là tham số chỉnh được');
select is(pg_temp.err($$select app.student_summary_base((select s from ids))$$), '42501', 'Chặn: hàm trong không gọi thẳng được');
select pg_temp.claims(pg_temp.uid('hs'), 'aal1');
select is(pg_temp.err($$select app.get_student_summary((select s from ids))$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: tài khoản học sinh');

select * from finish();
rollback;
