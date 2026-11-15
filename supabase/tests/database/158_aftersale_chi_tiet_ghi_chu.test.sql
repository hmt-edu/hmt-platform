-- Aftersale lát 3a (migration 158): get_ticket (chi tiết, dòng thời gian, RLS) và add_ticket_note (ghi chú). Dữ liệu giả.
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

-- ================= Đọc chi tiết =================
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'ticket' ->> 'code'), (select j ->> 'code' from t1), 'Chi tiết: trả đúng ticket');
select is((select jsonb_array_length(app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'events')), 1, 'Chi tiết: dòng thời gian có sự kiện Tạo');
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'ticket' ->> 'description'), 'Mô tả giả', 'Chi tiết: có mô tả');
select is(pg_temp.err($$select app.get_ticket(gen_random_uuid())$$), 'HMT_KHONG_TIM_THAY', 'Chặn: mã ticket không có');

-- ================= Ghi chú =================
select app.add_ticket_note((select (j ->> 'id')::uuid from t1), '  Đã gọi phụ huynh  ');
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'events' -> 1 ->> 'note'), 'Đã gọi phụ huynh', 'Ghi chú: lưu đã cắt khoảng trắng, nằm cuối dòng thời gian');
select is((select app.get_ticket((select (j ->> 'id')::uuid from t1)) -> 'events' -> 1 ->> 'event_type'), 'GHI_CHU', 'Ghi chú: loại sự kiện GHI_CHU');
select is(pg_temp.err($$select app.add_ticket_note((select (j ->> 'id')::uuid from t1), '   ')$$), 'HMT_THIEU_THONG_TIN', 'Chặn: ghi chú rỗng');

-- ================= Quyền và cơ sở khác =================
select pg_temp.claims(pg_temp.uid('cskh1'), 'aal1');
select is(pg_temp.err($$select app.get_ticket((select (j ->> 'id')::uuid from t1))$$), 'HMT_KHONG_TIM_THAY', 'Chặn: CSKH cơ sở khác không thấy chi tiết (RLS theo cơ sở)');
select is(pg_temp.err($$select app.add_ticket_note((select (j ->> 'id')::uuid from t1), 'Ghi chú lạ')$$), 'HMT_KHONG_CO_QUYEN', 'Chặn: CSKH cơ sở khác không ghi chú được (quyền theo cơ sở)');
select pg_temp.claims(pg_temp.uid('gv5b'), 'aal1');
select is(pg_temp.err($$select app.get_ticket((select (j ->> 'id')::uuid from t1))$$), 'HMT_KHONG_TIM_THAY', 'Chặn: giáo viên không thấy ticket không phải của mình (AS-09)');

-- ================= Ticket đã huỷ =================
select pg_temp.claims(pg_temp.uid('cskh5'), 'aal1');
select app.change_ticket_status((select (j ->> 'id')::uuid from t1), 'DA_HUY', 'Phụ huynh rút');
select is(pg_temp.err($$select app.add_ticket_note((select (j ->> 'id')::uuid from t1), 'Sau khi huỷ')$$), 'HMT_TICKET_TRANG_THAI_SAI', 'Chặn: ticket đã huỷ không thêm ghi chú (AS-02)');

select * from finish();
rollback;
