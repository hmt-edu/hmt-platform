-- Aftersale lát 3c (migration 221): phần riêng khiếu nại (update_ticket_complaint), ticket con và tính chất trong get_ticket. Dữ liệu giả.
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
insert into u (key) values ('admin'), ('cskh5'), ('cskh1'), ('gv5'), ('gv5b'), ('qlcs5');
grant select on u to authenticated;
create function pg_temp.uid(p_key text) returns uuid language sql stable as $$ select id from u where key = p_key $$;
insert into auth.users (id, aud, role, email) select id, 'authenticated', 'authenticated', key || '@as.hoamatoan.invalid' from u;
insert into app.user_account (id, display_name, login_name, branch_id, must_change_password)
select u.id, 'Giả ' || u.key, u.key || '@as.hoamatoan.invalid',
       (select id from app.branch where code = case when u.key = 'cskh1' then 'CS1' else 'CS5' end), false from u;
insert into app.user_role (user_id, role_code)
select id, case when key = 'admin' then 'ADMIN' when key like 'cskh%' then 'CSKH' when key like 'gv%' then 'TEACHER' else 'BRANCH_MANAGER' end from u;
update app.user_role set is_active = false where role_code = 'ADMIN' and is_active and user_id not in (select id from u);
select pg_temp.sudo($$insert into app.parent (code, full_name, phone, branch_id) values ('PHAS501', 'Phụ huynh giả ticket', '0900002001', (select id from app.branch where code = 'CS5'))$$);
select pg_temp.sudo($$insert into app.student (code, parent_id, full_name, birth_year, branch_id)
  values ('HSAS501', (select id from app.parent where code = 'PHAS501'), 'Học sinh giả ticket', 2013, (select id from app.branch where code = 'CS5'))$$);
grant execute on all functions in schema pg_temp to public;

create function pg_temp.mk(p_type text, p_cat text, p_extra jsonb default '{}'::jsonb) returns jsonb language sql as $$
  select jsonb_build_object('ticket_type', p_type, 'branch_id', (select id from app.branch where code = 'CS5'), 'title', 'Tiêu đề giả', 'description', 'Mô tả giả',
    'channel_code', 'GOI_DIEN', 'category_code', p_cat, 'parent_id', (select id from app.parent where code = 'PHAS501')) || p_extra $$;
grant execute on function pg_temp.mk(text, text, jsonb) to public;

select pg_temp.sudo($$insert into app.feature_flag (module_code, branch_id, enabled) select 'AFTERSALE', id, true from app.branch where code in ('CS5', 'CS1')
  on conflict (module_code, branch_id) do update set enabled = true$$);
set local role authenticated;
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
create temp table t1 (j jsonb);
grant all on t1 to public;
insert into t1 select app.create_ticket(pg_temp.mk('KN', 'KN_02_02'));

-- ================= Sửa phần riêng khiếu nại =================
select app.update_ticket_complaint((select (j ->> 'id')::uuid from t1), jsonb_build_object('complaint_date', '2026-11-05', 'customer_wish', ' Đổi giáo viên ', 'root_cause', 'Cách giảng', 'compensation_note', 'Học bù hai buổi', 'accused_user_id', pg_temp.uid('qlcs5')));
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'ticket' ->> 'customer_wish'), 'Đổi giáo viên', 'Khiếu nại: lưu mong muốn của khách đã cắt khoảng trắng');
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'ticket' ->> 'complaint_date'), '2026-11-05', 'Khiếu nại: lưu ngày xảy ra');
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'ticket' ->> 'accused_name'), 'Giả qlcs5', 'Khiếu nại: hiện tên người bị khiếu nại');
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'events' -> 1 ->> 'event_type'), 'SUA_KHIEU_NAI', 'Khiếu nại: sửa có ghi nhật ký');
select app.update_ticket_complaint((select (j ->> 'id')::uuid from t1), '{"root_cause": ""}'::jsonb);
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'ticket' ->> 'root_cause'), null, 'Khiếu nại: để trống thì xoá nguyên nhân gốc');
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'ticket' ->> 'customer_wish'), 'Đổi giáo viên', 'Khiếu nại: khoá không gửi thì giữ nguyên');
select is(pg_temp.err($$select app.update_ticket_complaint((select (j ->> 'id')::uuid from t1), jsonb_build_object('accused_user_id', pg_temp.uid('cskh1')))$$), 'HMT_NGUOI_PHU_TRACH_SAI', 'Chặn: người bị khiếu nại thuộc cơ sở khác (AS-09)');

-- ================= Ticket con =================
create temp table t2 (j jsonb);
grant all on t2 to public;
insert into t2 select app.create_ticket(pg_temp.mk('DN', 'DN_02_01', jsonb_build_object('student_id', (select id from app.student where code = 'HSAS501'), 'related_ticket_id', (select (j ->> 'id')::uuid from t1))));
select is((select jsonb_array_length(app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'children')), 1, 'Ticket con: khiếu nại thấy ticket đề nghị liên quan');
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'children' -> 0 ->> 'code'), (select j ->> 'code' from t2), 'Ticket con: đúng mã');

-- ================= Chặn =================
select is(pg_temp.err($$select app.update_ticket_complaint((select (j ->> 'id')::uuid from t2), '{"root_cause":"x"}'::jsonb)$$), 'HMT_TICKET_LOAI_SAI', 'Chặn: phần riêng chỉ có ở khiếu nại, đề nghị bị từ chối (AS-04)');
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.update_ticket_complaint((select (j ->> 'id')::uuid from t1), '{"root_cause":"x"}'::jsonb)$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH cơ sở khác không sửa được');
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select app.change_ticket_status((select (j ->> 'id')::uuid from t1), 'DA_HUY', 'Rút');
select is(pg_temp.err($$select app.update_ticket_complaint((select (j ->> 'id')::uuid from t1), '{"root_cause":"y"}'::jsonb)$$), 'HMT_TICKET_TRANG_THAI_SAI', 'Chặn: ticket đã huỷ thì chỉ xem (AS-02)');

-- ================= Tính chất ticket giáo viên =================
select pg_temp.claims(pg_temp.uid('gv5'), 'aal1');
create temp table t3 (j jsonb);
grant all on t3 to public;
insert into t3 select app.create_ticket(jsonb_build_object('ticket_type', 'GV', 'title', 'Giả', 'description', 'Giả', 'channel_code', 'GIAO_VIEN_BAO', 'category_code', 'GV_02_01'));
select is((select app.get_ticket((select (j ->> 'id')::uuid from t3)) -> 'ticket' ->> 'nature_code') in ('HO_TRO', 'PHAN_ANH'), true, 'Ticket giáo viên: trả tính chất theo nhóm con (AS-05)');

select * from finish();
rollback;
