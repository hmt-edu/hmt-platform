-- Aftersale lát 4 (migration 222): đổi loại, nhóm con, mức độ; tính lại hạn từ lúc tạo, nhật ký, các luật chặn. Dữ liệu giả.
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

create function pg_temp.res_hours(p_id uuid) returns numeric language sql as $$
  select extract(epoch from (resolve_due_at - created_at)) / 3600 from app.ticket where id = p_id $$;
grant execute on function pg_temp.res_hours(uuid) to public;

-- ================= Đổi mức độ =================
select is(pg_temp.res_hours((select (j ->> 'id')::uuid from t1)), 24.0, 'Trước khi đổi: khiếu nại Khẩn, hạn xử lý 24 giờ');
select app.change_ticket_priority((select (j ->> 'id')::uuid from t1), 'THUONG');
select is((select priority_code from app.ticket where id = (select (j ->> 'id')::uuid from t1)), 'THUONG', 'Đổi mức độ: lưu mức độ mới');
select is(pg_temp.res_hours((select (j ->> 'id')::uuid from t1)), (select resolve_hours::numeric from app.ticket_sla_rule where ticket_type = 'KN' and priority_code = 'THUONG'), 'Đổi mức độ: hạn tính lại từ lúc tạo theo bảng loại × mức độ (AS-07)');
select is((select event_type from app.ticket_event where ticket_id = (select (j ->> 'id')::uuid from t1) order by seq desc limit 1), 'DOI_MUC_DO', 'Đổi mức độ: có dòng nhật ký');
select is(pg_temp.err($$select app.change_ticket_priority((select (j ->> 'id')::uuid from t1), 'SIEU_KHAN')$$) is not null, true, 'Chặn: mức độ không có trong danh mục');

-- ================= Đổi nhóm con =================
select app.change_ticket_category((select (j ->> 'id')::uuid from t1), 'KN_02_01');
select is((select category_code from app.ticket where id = (select (j ->> 'id')::uuid from t1)), 'KN_02_01', 'Đổi nhóm con: lưu nhóm mới');
select is(pg_temp.err($$select app.change_ticket_category((select (j ->> 'id')::uuid from t1), 'DN_01_01')$$), 'HMT_TICKET_NHOM_SAI', 'Chặn: nhóm con thuộc loại ticket khác');

-- ================= Đổi loại =================
select app.change_ticket_type((select (j ->> 'id')::uuid from t1), 'DN', 'DN_06_01');
select is((select ticket_type from app.ticket where id = (select (j ->> 'id')::uuid from t1)), 'DN', 'Đổi loại: Khiếu nại thành Đề nghị');
select is((select code from app.ticket where id = (select (j ->> 'id')::uuid from t1)), (select j ->> 'code' from t1), 'Đổi loại: mã ticket không đổi (AS-01)');
select is(pg_temp.err($$select app.change_ticket_type((select (j ->> 'id')::uuid from t1), 'GV', 'GV_02_01')$$), 'HMT_TICKET_LOAI_SAI', 'Chặn: không đổi sang Ticket giáo viên');
select is(pg_temp.err($$select app.change_ticket_type((select (j ->> 'id')::uuid from t1), 'KN', 'DN_06_01')$$), 'HMT_TICKET_NHOM_SAI', 'Chặn: đổi loại phải chọn nhóm con của loại mới');

-- Ghi nhật ký giữ độ lệch Chờ thông tin: giao, đang xử lý, chờ thông tin, rồi đổi mức độ
create temp table t2 (j jsonb);
grant all on t2 to public;
insert into t2 select app.create_ticket(pg_temp.mk('KN', 'KN_02_01'));
select pg_temp.sudo($$update app.ticket set team_code = 'CSKH', assignee_id = (select id from u where key = 'cskh5'), status_code = 'DANG_XU_LY' where code = (select j ->> 'code' from t2)$$);
select is(pg_temp.err($$select app.change_ticket_type((select (j ->> 'id')::uuid from t2), 'DN', 'DN_06_01')$$), 'HMT_TICKET_TRANG_THAI_SAI', 'Chặn: đang xử lý thì không đổi loại (AS-05)');
select pg_temp.sudo($$update app.ticket set resolve_due_at = resolve_due_at + interval '10 hours' where id = (select (j ->> 'id')::uuid from t2)$$);
select app.change_ticket_priority((select (j ->> 'id')::uuid from t2), 'THAP');
select is(pg_temp.res_hours((select (j ->> 'id')::uuid from t2)), (select resolve_hours::numeric + 10 from app.ticket_sla_rule where ticket_type = 'KN' and priority_code = 'THAP'), 'Đổi mức độ: giữ phần dời hạn do Chờ thông tin (+10 giờ)');

-- ================= Quyền và trạng thái =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.change_ticket_priority((select (j ->> 'id')::uuid from t2), 'CAO')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH cơ sở khác không đổi được');
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select app.change_ticket_status((select (j ->> 'id')::uuid from t2), 'DA_HUY', 'Rút');
select is(pg_temp.err($$select app.change_ticket_priority((select (j ->> 'id')::uuid from t2), 'CAO')$$), 'HMT_TICKET_TRANG_THAI_SAI', 'Chặn: ticket đã huỷ thì chỉ xem (AS-02)');

select * from finish();
rollback;
